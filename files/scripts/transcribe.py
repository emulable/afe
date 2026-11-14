"""Transcribe audio or video to text, broken down by speaker.

Run with the WhisperX environment's Python (the launcher does this for you):

    transcribe.py FILE [FILE ...]     transcribe the given files
    transcribe.py --watch             process whatever is dropped into transcribe\\in

For each input NAME.ext it writes, into transcribe\\out (or --out):

    NAME.txt    readable transcript, one paragraph per speaker turn
    NAME.srt    subtitles, each cue labelled with its speaker
    NAME.json   everything, including word-level timings

Speaker detection has two engines:

    pyannote   best quality. Used automatically once a Hugging Face token is
               saved and the model's terms are accepted (see README.md).
    local      needs no account. Uses the two ONNX models in models\\diarization.

"auto" (the default) tries pyannote and falls back to local.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import traceback
from pathlib import Path

from subtitles import tidy_cues, words_to_cues, write_srt   # scripts\subtitles.py

ROOT =Path(__file__).resolve().parent.parent
IN_DIR = ROOT / "transcribe" / "in"
OUT_DIR = ROOT / "transcribe" / "out"
DIAR_DIR = ROOT / "models" / "diarization"

MEDIA = {".wav", ".mp3", ".m4a", ".flac", ".ogg", ".opus", ".aac", ".wma", ".aiff",
         ".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v"}

# Languages written without spaces between words.
NO_SPACE_LANGS = {"zh", "ja", "th", "lo", "my", "km", "yue"}

# Seconds of GPU idleness after which --watch unloads the models to free VRAM.
IDLE_UNLOAD_SECONDS = 90


def find_hf_token() -> str | None:
    """Token from the environment, or from where `hf auth login` stores it."""
    token = os.environ.get("HF_TOKEN")
    if token:
        return token.strip()
    hf_home = os.environ.get("HF_HOME") or str(Path.home() / ".cache" / "huggingface")
    token_file = Path(hf_home) / "token"
    if token_file.is_file():
        return token_file.read_text(encoding="utf-8").strip() or None
    return None


class Transcriber:
    """Holds the loaded models so several files can share them."""

    def __init__(self, args: argparse.Namespace):
        import warnings
        # pyannote warns at import that torchcodec cannot decode files here. Audio is
        # decoded by ffmpeg and passed in memory, so that decoder is never used.
        warnings.filterwarnings("ignore", message=r"(?s).*torchcodec.*")
        import torch
        import whisperx

        self.args = args
        self.whisperx = whisperx
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        compute_type = "float16" if self.device == "cuda" else "int8"
        print(f"Loading Whisper model '{args.model}' on {self.device} ...", flush=True)
        self.model = whisperx.load_model(
            args.model, self.device, compute_type=compute_type, language=args.language)
        self._align = {}          # language code -> (model, metadata), or None if unavailable
        self._pyannote = None
        self._pyannote_unavailable = False
        self._local = {}          # number of speakers -> sherpa-onnx diarizer

    # -- speaker detection -------------------------------------------------

    def _diarize_pyannote(self, audio):
        if self._pyannote_unavailable:
            return None
        if self._pyannote is None:
            token = find_hf_token()
            if not token:
                self._pyannote_unavailable = True
                if self.args.speaker_engine == "pyannote":
                    print("  No Hugging Face token found, so pyannote cannot be used (see README.md).")
                return None
            try:
                from whisperx.diarize import DiarizationPipeline
                print("  Loading pyannote speaker model ...", flush=True)
                self._pyannote = DiarizationPipeline(token=token, device=self.device)
            except Exception as exc:  # gated model, bad token, no network ...
                self._pyannote_unavailable = True
                reason = str(exc).strip().splitlines()[0] if str(exc).strip() else type(exc).__name__
                print(f"  Could not load the pyannote speaker model: {reason}")
                print("  Usually this means its terms have not been accepted on Hugging Face yet (see README.md).")
                return None
        a = self.args
        return self._pyannote(audio, num_speakers=a.speakers,
                              min_speakers=a.min_speakers, max_speakers=a.max_speakers)

    def _diarize_local(self, audio):
        import pandas as pd
        import sherpa_onnx

        n = self.args.speakers or -1          # -1 = decide from the clustering threshold
        if n not in self._local:
            seg_model = DIAR_DIR / "segmentation" / "model.onnx"
            emb_model = DIAR_DIR / "embedding" / "nemo_en_titanet_large.onnx"
            for f in (seg_model, emb_model):
                if not f.is_file():
                    raise FileNotFoundError(f"Missing speaker model: {f}")
            threads = max(1, min(8, (os.cpu_count() or 4) // 2))
            config = sherpa_onnx.OfflineSpeakerDiarizationConfig(
                segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
                    pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(
                        model=str(seg_model)),
                    num_threads=threads),
                embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(
                    model=str(emb_model), num_threads=threads),
                clustering=sherpa_onnx.FastClusteringConfig(
                    num_clusters=n, threshold=self.args.speaker_threshold),
                min_duration_on=0.3,
                min_duration_off=0.5)
            self._local[n] = sherpa_onnx.OfflineSpeakerDiarization(config)
        segments = self._local[n].process(audio).sort_by_start_time()
        return pd.DataFrame(
            [{"start": s.start, "end": s.end, "speaker": f"SPEAKER_{s.speaker:02d}"} for s in segments],
            columns=["start", "end", "speaker"])

    # -- main --------------------------------------------------------------

    def run(self, path: Path) -> dict:
        wx, a = self.whisperx, self.args
        audio = wx.load_audio(str(path))           # 16 kHz mono float32, via ffmpeg
        duration = len(audio) / 16000.0

        result = self.model.transcribe(audio, batch_size=a.batch_size, language=a.language)
        language = result.get("language") or a.language or "en"

        # Word-level timings (needed to split text accurately between speakers).
        if language not in self._align:
            try:
                self._align[language] = wx.load_align_model(language_code=language, device=self.device)
            except Exception as exc:
                print(f"  No word-alignment model for language '{language}' ({exc}); using sentence timings.")
                self._align[language] = None
        if self._align[language] is not None and result.get("segments"):
            model_a, metadata = self._align[language]
            result = wx.align(result["segments"], model_a, metadata, audio, self.device,
                              return_char_alignments=False)

        engine = None
        if not a.no_speakers and result.get("segments"):
            frame = None
            if a.speaker_engine in ("auto", "pyannote"):
                frame = self._diarize_pyannote(audio)
                engine = "pyannote" if frame is not None else None
            if frame is None and a.speaker_engine in ("auto", "local"):
                frame = self._diarize_local(audio)
                engine = "local"
            if frame is not None and len(frame):
                result = wx.assign_word_speakers(frame, result, fill_nearest=True)
            else:
                engine = None

        words = collect_words(result)
        if engine:
            smooth_speakers(words)
        return build_document(path, language, duration, engine, words)


# -- turning words into a document ---------------------------------------------

def collect_words(result: dict) -> list[dict]:
    """Flatten WhisperX output into one list of timed words with speakers."""
    words: list[dict] = []
    for seg in result.get("segments", []):
        seg_speaker = seg.get("speaker")
        seg_words = seg.get("words") or []
        if not seg_words:      # no alignment: keep the whole segment as one unit
            text = (seg.get("text") or "").strip()
            if text:
                words.append({"text": text, "start": float(seg.get("start", 0.0)),
                              "end": float(seg.get("end", 0.0)), "speaker": seg_speaker})
            continue
        last_end = float(seg.get("start", 0.0))
        for w in seg_words:
            # Tokens such as digits can come back without timings; pin them to the previous word.
            start = float(w.get("start", last_end))
            end = float(w.get("end", start))
            words.append({"text": w.get("word", ""), "start": start, "end": end,
                          "speaker": w.get("speaker") or seg_speaker})
            last_end = end
    # Fill any words the speaker model did not cover from their neighbours.
    previous = None
    for w in words:
        if w["speaker"] is None:
            w["speaker"] = previous
        previous = w["speaker"]
    following = None
    for w in reversed(words):
        if w["speaker"] is None:
            w["speaker"] = following
        following = w["speaker"]
    return words


def smooth_speakers(words: list[dict]) -> None:
    """Relabel one- or two-word blips sandwiched inside another speaker's turn.

    Speaker boundaries from the model rarely land exactly between words, which
    otherwise produces stray single-word "turns".
    """
    i, n = 0, len(words)
    while i < n:
        j = i
        while j + 1 < n and words[j + 1]["speaker"] == words[i]["speaker"]:
            j += 1
        run_len = j - i + 1
        run_dur = words[j]["end"] - words[i]["start"]
        if 0 < i and j < n - 1 and run_len <= 2 and run_dur < 0.8 \
                and words[i - 1]["speaker"] == words[j + 1]["speaker"]:
            for k in range(i, j + 1):
                words[k]["speaker"] = words[i - 1]["speaker"]
        i = j + 1


def build_document(path: Path, language: str, duration: float, engine: str | None,
                   words: list[dict]) -> dict:
    joiner = "" if language in NO_SPACE_LANGS else " "

    # Friendly names in order of first appearance: SPEAKER_03 -> "Speaker 1".
    names: dict[str, str] = {}
    if engine:
        for w in words:
            if w["speaker"] is not None and w["speaker"] not in names:
                names[w["speaker"]] = f"Speaker {len(names) + 1}"
    for w in words:
        w["speaker"] = names.get(w["speaker"]) if engine else None

    # A turn is a run of words by one speaker. Long single-speaker stretches are
    # also broken into paragraphs at a sentence end after a pause or ~700 characters.
    turns: list[dict] = []
    for w in words:
        new_turn = not turns or turns[-1]["speaker"] != w["speaker"]
        if not new_turn:
            current = turns[-1]
            prev = current["words"][-1]
            sentence_end = prev["text"].rstrip().endswith((".", "?", "!", "。", "？", "！"))
            length = sum(len(x["text"]) + 1 for x in current["words"])
            if sentence_end and (w["start"] - prev["end"] > 2.0 or length > 700):
                new_turn = True
        if new_turn:
            turns.append({"speaker": w["speaker"], "start": w["start"], "end": w["end"], "words": [w]})
        else:
            turns[-1]["words"].append(w)
            turns[-1]["end"] = max(turns[-1]["end"], w["end"])
    for t in turns:
        t["text"] = joiner.join(x["text"].strip() for x in t["words"]).strip()

    return {
        "file": path.name,
        "language": language,
        "duration": round(duration, 2),
        "speaker_engine": engine,
        "speakers": list(names.values()),
        "turns": turns,
        "joiner": joiner,
    }


# -- writers -------------------------------------------------------------------

def clock(seconds: float) -> str:
    s = int(seconds)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}"



def make_cues(doc: dict) -> list[dict]:
    """Subtitle cues for the whole document, labelled by speaker when there are several."""
    many_speakers = len(doc["speakers"]) > 1
    cues: list[dict] = []
    for turn in doc["turns"]:
        prefix = f"{turn['speaker']}: " if many_speakers and turn["speaker"] else ""
        cues += words_to_cues(turn["words"], joiner=doc["joiner"], prefix=prefix)
    return tidy_cues(cues)


def write_outputs(doc: dict, out_dir: Path, stem: str) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)

    speakers = doc["speakers"]
    header = [f"Transcript of {doc['file']}",
              f"Language: {doc['language']}   Length: {clock(doc['duration'])}   "
              + (f"Speakers: {len(speakers)} (detected by the {doc['speaker_engine']} engine)"
                 if doc["speaker_engine"] else "Speakers: not separated"),
              ""]
    body = []
    for t in doc["turns"]:
        label = f"[{clock(t['start'])}]" + (f" {t['speaker']}" if t["speaker"] else "")
        body += [label, t["text"], ""]
    txt = out_dir / f"{stem}.txt"
    txt.write_text("\n".join(header + body), encoding="utf-8")

    srt = out_dir / f"{stem}.srt"
    write_srt(make_cues(doc), srt)

    data = {k: doc[k] for k in ("file", "language", "duration", "speaker_engine", "speakers")}
    data["turns"] = [{"speaker": t["speaker"], "start": round(t["start"], 3), "end": round(t["end"], 3),
                      "text": t["text"]} for t in doc["turns"]]
    data["words"] = [{"text": w["text"], "start": round(w["start"], 3), "end": round(w["end"], 3),
                      "speaker": w["speaker"]} for t in doc["turns"] for w in t["words"]]
    js = out_dir / f"{stem}.json"
    js.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return [txt, srt, js]


# -- running -------------------------------------------------------------------

def process(transcriber: Transcriber, path: Path, out_dir: Path) -> None:
    started = time.time()
    print(f"\n{path.name}", flush=True)
    doc = transcriber.run(path)
    outputs = write_outputs(doc, out_dir, path.stem)
    took = time.time() - started
    speakers = f"{len(doc['speakers'])} speakers ({doc['speaker_engine']})" if doc["speaker_engine"] else "speakers not separated"
    print(f"  {clock(doc['duration'])} of audio, {speakers}, done in {took:.0f} s")
    for o in outputs:
        print(f"  -> {o}")


def unique_destination(folder: Path, name: str) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / name
    if target.exists():
        target = folder / f"{Path(name).stem} ({time.strftime('%Y-%m-%d %H%M%S')}){Path(name).suffix}"
    return target


def pending_files() -> bool:
    return any(p.is_file() and p.suffix.lower() in MEDIA for p in IN_DIR.iterdir())


def watch(args: argparse.Namespace, out_dir: Path) -> None:
    """Watch transcribe\\in.

    The models live in a separate worker process that quits after
    IDLE_UNLOAD_SECONDS without work. Only a process exit gives every byte of GPU
    memory back (the speech libraries keep their own memory pools), and this
    watcher itself never touches the GPU, so an idle watcher costs games nothing.
    """
    IN_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Watching {IN_DIR}")
    print(f"Drop audio or video files there; transcripts appear in {out_dir}")
    print("Finished files move to in\\done. Press Ctrl+C to stop.\n", flush=True)
    worker_cmd = [sys.executable, str(Path(__file__).resolve()), "--worker",
                  *[a for a in sys.argv[1:] if a != "--watch"]]      # same options as this run
    worker = None
    try:
        while True:
            if worker is not None and worker.poll() is not None:
                if worker.returncode == 0:
                    print("(idle: models unloaded, GPU memory released)", flush=True)
                else:
                    print(f"(worker stopped with error code {worker.returncode}; "
                          "it restarts when new files arrive)", flush=True)
                worker = None
            if worker is None and pending_files():
                worker = subprocess.Popen(worker_cmd)
            time.sleep(2)
    finally:
        if worker is not None and worker.poll() is None:
            worker.terminate()


def work_until_idle(args: argparse.Namespace, out_dir: Path) -> None:
    """Worker: transcribe whatever arrives in transcribe\\in, then quit after a quiet spell."""
    transcriber = None
    last_work = time.time()
    seen_sizes: dict[Path, int] = {}
    while time.time() - last_work < IDLE_UNLOAD_SECONDS:
        for path in sorted(IN_DIR.iterdir()):
            if not path.is_file() or path.suffix.lower() not in MEDIA:
                continue
            size = path.stat().st_size
            if seen_sizes.get(path) != size:      # still being copied in; check again next round
                seen_sizes[path] = size
                continue
            seen_sizes.pop(path, None)
            try:
                if transcriber is None:
                    transcriber = Transcriber(args)
                process(transcriber, path, out_dir)
                shutil.move(str(path), str(unique_destination(IN_DIR / "done", path.name)))
            except Exception:
                error = traceback.format_exc()
                print(f"  FAILED: {error.strip().splitlines()[-1]}")
                failed = IN_DIR / "failed"
                target = unique_destination(failed, path.name)
                shutil.move(str(path), str(target))
                (failed / f"{target.stem}.error.txt").write_text(error, encoding="utf-8")
            last_work = time.time()
        time.sleep(3)


def main() -> int:
    p = argparse.ArgumentParser(description="Transcribe audio/video to text, broken down by speaker.")
    p.add_argument("files", nargs="*", type=Path, help="audio or video files")
    p.add_argument("--watch", action="store_true", help="watch transcribe\\in and process files dropped there")
    p.add_argument("--out", type=Path, default=OUT_DIR, help="output folder (default: transcribe\\out)")
    p.add_argument("--model", default="large-v3",
                   help="Whisper model: large-v3 (most accurate, default), large-v3-turbo (faster), medium, small ...")
    p.add_argument("--language", default=None, help="language code such as en, es, de (default: detect)")
    p.add_argument("--speakers", type=int, default=None, help="exact number of speakers, if you know it")
    p.add_argument("--min-speakers", type=int, default=None, help="pyannote engine only")
    p.add_argument("--max-speakers", type=int, default=None, help="pyannote engine only")
    p.add_argument("--no-speakers", action="store_true", help="skip speaker detection")
    p.add_argument("--speaker-engine", choices=("auto", "pyannote", "local"), default="auto")
    # 0.7 sits in the middle of the range (0.6-0.9) that separated the test clips correctly;
    # 0.5 split one voice in two and 1.0 merged everyone.
    p.add_argument("--speaker-threshold", type=float, default=0.7,
                   help="local engine, when --speakers is not given: higher = fewer speakers (default 0.7)")
    p.add_argument("--batch-size", type=int, default=16, help="lower this if the GPU runs out of memory")
    p.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)   # started by --watch
    args = p.parse_args()

    if args.worker:
        try:
            work_until_idle(args, args.out)
        except KeyboardInterrupt:
            pass
        return 0

    if args.watch or not args.files:
        try:
            watch(args, args.out)
        except KeyboardInterrupt:
            print("\nStopped.")
        return 0

    missing = [f for f in args.files if not f.is_file()]
    if missing:
        print("Not found: " + ", ".join(str(m) for m in missing))
        return 2
    transcriber = Transcriber(args)
    failures = 0
    for f in args.files:
        try:
            process(transcriber, f, args.out)
        except Exception:
            failures += 1
            traceback.print_exc()
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
