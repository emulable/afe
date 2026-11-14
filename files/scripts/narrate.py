"""Turn a document into natural-sounding narration, with subtitles.

Run with the narration environment's Python (the launcher does this for you):

    narrate.py FILE [FILE ...]     narrate the given files
    narrate.py --watch             narrate whatever is dropped into narrate\\in

Reads .txt .md .docx .pdf .epub .html. For each input NAME it writes, into
narrate\\out (or --out):

    NAME.mp3    the narration (or .m4a / .wav / .flac)
    NAME.srt    subtitles timed to the audio
    NAME.mp4    a video with the subtitles burned in (only with --video / "make_video")

Defaults live in narrate\\settings.json, which is created on first run.
Command-line options override it.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import traceback
import warnings
from pathlib import Path

from subtitles import tidy_cues, words_to_cues, write_srt   # scripts\subtitles.py

ROOT = Path(__file__).resolve().parent.parent
IN_DIR = ROOT / "narrate" / "in"
OUT_DIR = ROOT / "narrate" / "out"
SETTINGS_FILE = ROOT / "narrate" / "settings.json"

DOCUMENTS = {".txt", ".md", ".markdown", ".docx", ".pdf", ".epub", ".html", ".htm"}
IDLE_UNLOAD_SECONDS = 90

# Designed or cloned voices: NAME.wav (+ NAME.txt, the words spoken in it) in voices\reference.
VOICE_DIR = ROOT / "voices" / "reference"
COMFY_DIR = ROOT / "tools" / "ComfyUI"
# a tool's own Python: Windows keeps it in .venv\Scripts, other systems in .venv/bin
COMFY_PY = COMFY_DIR / ".venv" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
COMFY_URL = "http://127.0.0.1:8189"
NARRATOR = "wise_old_narrator"

DEFAULTS = {
    "_help": "voice: either the name of a voice clip in voices\\reference (such as wise_old_narrator), "
             "spoken by clone_engine in ComfyUI voices, or a Kokoro preset voice such as bm_george, "
             "bm_fable, am_michael, af_heart (blend two with a comma). clone_engine: vibevoice "
             "(unhurried storyteller pace, about real time), chatterbox (about real time) or qwen3 "
             "(about 3x slower). speed: 1.0 is "
             "normal (Kokoro voices only). audio_format: mp3, m4a, wav or flac. make_video: true also "
             "writes an MP4 with burned-in subtitles; put a picture at narrate\\background.jpg (or .png) "
             "to use it as the backdrop. Pauses are in seconds.",
    "voice": NARRATOR if (VOICE_DIR / f"{NARRATOR}.wav").is_file() else "bm_george",
    "clone_engine": "vibevoice",
    "speed": 1.0,
    "audio_format": "mp3",
    "make_video": False,
    "video_size": "1280x720",
    "paragraph_pause": 0.45,
    "heading_pause": 0.9,
}


# -- reading documents ---------------------------------------------------------
# Every reader returns a list of (kind, text) blocks, kind being "heading" or "para".

def _read_text_file(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            return data.decode(encoding)
        except UnicodeError:
            continue
    return data.decode("utf-8", errors="replace")


def read_txt(path: Path) -> list[tuple[str, str]]:
    text = _read_text_file(path).replace("\r\n", "\n").replace("\r", "\n")
    if "\n\n" in text:
        # Blank lines separate paragraphs; single newlines inside one are just hard wraps.
        parts = [re.sub(r"\s*\n\s*", " ", p) for p in re.split(r"\n\s*\n", text)]
    else:
        parts = text.split("\n")           # one paragraph per line
    return [("para", p) for p in parts]


def read_markdown(path: Path) -> list[tuple[str, str]]:
    text = _read_text_file(path).replace("\r\n", "\n")
    text = re.sub(r"(?s)^---\n.*?\n---\n", "", text)                 # front matter
    text = re.sub(r"(?s)```.*?```", "", text)                        # code blocks are not read aloud
    blocks: list[tuple[str, str]] = []
    for chunk in re.split(r"\n\s*\n", text):
        lines = []
        for line in chunk.split("\n"):
            heading = re.match(r"\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$", line)
            if heading:
                if lines:
                    blocks.append(("para", " ".join(lines)))
                    lines = []
                blocks.append(("heading", _strip_inline_markdown(heading.group(1))))
                continue
            if re.fullmatch(r"\s*[-*_=|:\s]{3,}\s*", line):             # rules and table separators
                continue
            line = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+", "", line)         # list markers
            line = re.sub(r"^\s*>+\s?", "", line)                        # block quotes
            line = line.strip().strip("|").replace("|", ", ")            # table rows
            if line.strip():
                lines.append(_strip_inline_markdown(line))
        if lines:
            blocks.append(("para", " ".join(lines)))
    return blocks


def _strip_inline_markdown(s: str) -> str:
    s = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", s)                        # images
    s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)                    # links keep their text
    s = re.sub(r"<[^>]+>", "", s)                                     # inline HTML
    s = re.sub(r"(\*\*|__|\*|_|~~|`)", "", s)                         # emphasis and code marks
    return s.strip()


def read_docx(path: Path) -> list[tuple[str, str]]:
    import docx
    blocks = []
    for p in docx.Document(str(path)).paragraphs:
        style = (p.style.name or "").lower() if p.style is not None else ""
        kind = "heading" if style.startswith(("heading", "title")) else "para"
        blocks.append((kind, p.text))
    return blocks


def _html_blocks(markup: bytes | str) -> list[tuple[str, str]]:
    from bs4 import BeautifulSoup, XMLParsedAsHTMLWarning
    # EPUB chapters are XHTML; the HTML parser reads them fine but warns at length.
    warnings.filterwarnings("ignore", category=XMLParsedAsHTMLWarning)
    soup = BeautifulSoup(markup, "lxml")
    for junk in soup(["script", "style", "nav", "header", "footer", "aside", "figure", "table"]):
        junk.decompose()
    wanted = ["h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "blockquote", "dd", "dt"]
    blocks = []
    for el in soup.find_all(wanted):
        if el.find(wanted):                 # a container; its children are picked up on their own
            continue
        text = el.get_text(" ", strip=True)
        if text:
            blocks.append(("heading" if el.name[0] == "h" else "para", text))
    if not blocks:                          # markup without paragraph tags
        blocks = [("para", t) for t in soup.get_text("\n").split("\n")]
    return blocks


def read_html(path: Path) -> list[tuple[str, str]]:
    return _html_blocks(path.read_bytes())


def read_epub(path: Path) -> list[tuple[str, str]]:
    import ebooklib
    from ebooklib import epub
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        book = epub.read_epub(str(path))
    blocks = []
    for idref, _linear in book.spine:
        item = book.get_item_with_id(idref)
        if item is None or item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue
        blocks += _html_blocks(item.get_content())
    return blocks


def read_pdf(path: Path) -> list[tuple[str, str]]:
    import fitz  # PyMuPDF

    pages = []       # per page: list of (is_margin, text)
    with fitz.open(str(path)) as pdf:
        for page in pdf:
            height = page.rect.height or 1.0
            entries = []
            for x0, y0, x1, y1, text, _no, kind in page.get_text("blocks", sort=True):
                if kind != 0 or not text.strip():
                    continue
                in_margin = y1 < 0.09 * height or y0 > 0.91 * height
                entries.append((in_margin, text.strip()))
            pages.append(entries)

    # Running headers/footers: short margin text that repeats (ignoring digits) on many pages.
    def key(s: str) -> str:
        return re.sub(r"\d+", "#", re.sub(r"\s+", " ", s)).lower()

    counts: dict[str, int] = {}
    for entries in pages:
        for k in {key(t) for margin, t in entries if margin and len(t) < 120}:
            counts[k] = counts.get(k, 0) + 1
    repeated = {k for k, n in counts.items() if len(pages) >= 4 and n >= 0.4 * len(pages)}

    blocks: list[tuple[str, str]] = []
    for entries in pages:
        for margin, text in entries:
            if margin and (key(text) in repeated
                           or re.fullmatch(r"(?i)(page\s+)?\d{1,4}(\s*(of|/)\s*\d{1,4})?", text)):
                continue
            text = re.sub(r"(\w)-\n(\w)", r"\1\2", text)       # re-join words hyphenated at line ends
            text = re.sub(r"\s*\n\s*", " ", text)
            # A paragraph that runs across a column or page break arrives as two blocks: re-join them.
            if blocks and blocks[-1][0] == "para" and re.search(r"[a-z,;]$", blocks[-1][1]) \
                    and re.match(r"[a-z]", text):
                blocks[-1] = ("para", blocks[-1][1] + " " + text)
            else:
                blocks.append(("para", text))
    return blocks


READERS = {".txt": read_txt, ".md": read_markdown, ".markdown": read_markdown, ".docx": read_docx,
           ".pdf": read_pdf, ".epub": read_epub, ".html": read_html, ".htm": read_html}


def clean_for_speech(text: str) -> str:
    text = text.replace("­", "")                                 # soft hyphens
    text = re.sub(r"https?://\S+|www\.\S+", "", text)                 # nobody wants a URL read out
    text = re.sub(r"\[\d+(?:\s*[,–-]\s*\d+)*\]", "", text)            # citation marks like [12] or [3, 4]
    return re.sub(r"\s+", " ", text).strip()


def read_document(path: Path) -> list[tuple[str, str]]:
    reader = READERS.get(path.suffix.lower())
    if reader is None:
        raise ValueError(f"Unsupported file type '{path.suffix}'. Supported: {', '.join(sorted(DOCUMENTS))}")
    blocks = [(kind, clean_for_speech(text)) for kind, text in reader(path)]
    blocks = [(kind, text) for kind, text in blocks if re.search(r"\w", text)]
    if not blocks:
        raise ValueError("No readable text found in this file (a scanned PDF needs OCR first).")
    return blocks


# -- speech engine ---------------------------------------------------------------

class KokoroEngine:
    """Kokoro-82M: small, fast, natural-sounding preset voices."""

    sample_rate = 24000

    def __init__(self, voice: str, speed: float):
        warnings.filterwarnings("ignore", category=UserWarning)
        warnings.filterwarnings("ignore", category=FutureWarning)
        import torch
        from kokoro import KPipeline

        self.voice, self.speed = voice, speed
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        # Voice names start with their language letter: a = American English, b = British English, ...
        language = voice.strip()[0]
        print(f"Loading Kokoro voice '{voice}' on {self.device} ...", flush=True)
        self.pipeline = KPipeline(lang_code=language, repo_id="hexgrad/Kokoro-82M", device=self.device)

    def speak(self, text: str):
        """Yield (audio, words) for each chunk Kokoro cuts the text into.

        audio is float32 mono at sample_rate; words carry timings relative to the
        start of that chunk.
        """
        for result in self.pipeline(text, voice=self.voice, speed=self.speed, split_pattern=None):
            if result.audio is None:
                continue
            audio = result.audio.detach().cpu().numpy().astype("float32")
            seconds = len(audio) / self.sample_rate
            words = _words_from_tokens(getattr(result, "tokens", None)) \
                or _spread_evenly(result.graphemes, seconds)
            yield audio, words

    def close(self) -> None:
        pass


def find_voice_clip(voice: str) -> Path | None:
    """A voice clip by name (voices\\reference\\NAME.wav) or by path, if there is one."""
    voice = voice.strip().strip('"')
    as_path = Path(voice)
    if as_path.suffix.lower() in (".wav", ".flac", ".mp3", ".ogg") and as_path.is_file():
        return as_path
    for ext in (".wav", ".flac", ".mp3"):
        clip = VOICE_DIR / f"{voice}{ext}"
        if clip.is_file():
            return clip
    return None


class ComfyCloneEngine:
    """Speaks in the voice of a reference clip, using an engine in ComfyUI (voices).

    Uses ComfyUI if it is already open on port 8189; otherwise starts it in the
    background for the job and stops it again in close(). Text goes over in
    sentence groups, so each subtitle lines up with its own piece of audio.
    """

    ENGINES = {"qwen3": "Qwen3TTSEngineNode", "vibevoice": "VibeVoiceEngineNode",
               "chatterbox": "ChatterBoxEngineNode"}
    MAX_CHARS = 280

    def __init__(self, clip: Path, engine: str):
        import uuid
        if engine not in self.ENGINES:
            raise ValueError(f"Unknown clone_engine '{engine}'. Use one of: {', '.join(self.ENGINES)}")
        if not (COMFY_PY).is_file():
            raise FileNotFoundError("This voice needs the ComfyUI voices component, which isn't installed. "
                                    "Install it, or set a Kokoro voice such as bm_george in narrate\\settings.json.")
        self.clip, self.engine = clip, engine
        transcript = clip.with_suffix(".txt")
        self.ref_text = transcript.read_text(encoding="utf-8").strip() if transcript.is_file() else ""
        self.client = uuid.uuid4().hex
        self.server = None
        self._info: dict = {}
        print(f"Using the voice '{clip.stem}' through ComfyUI ({engine}) ...", flush=True)
        self._ensure_server()
        (COMFY_DIR / "input").mkdir(parents=True, exist_ok=True)
        self.ref_name = f"narrate_voice_{clip.stem}{clip.suffix}"
        shutil.copyfile(clip, COMFY_DIR / "input" / self.ref_name)
        self.sample_rate = 24000
        warm, rate = self._generate("Let us begin.")      # loads the model and learns its sample rate
        self.sample_rate = rate

    # -- talking to ComfyUI --------------------------------------------------
    def _request(self, path: str, body: dict | None = None, timeout: float = 30):
        import urllib.request
        data = None if body is None else json.dumps(body).encode("utf-8")
        req = urllib.request.Request(COMFY_URL + path, data=data,
                                     headers={"Content-Type": "application/json"} if data else {})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))

    def _alive(self) -> bool:
        try:
            self._request("/system_stats", timeout=3)
            return True
        except Exception:
            return False

    def _ensure_server(self) -> None:
        if self._alive():
            return
        print("  starting ComfyUI in the background (about a minute) ...", flush=True)
        log = open(ROOT / "logs" / "narrate-comfyui.log", "w", encoding="utf-8", errors="replace")
        self.server = subprocess.Popen(
            [str(COMFY_PY), "main.py", "--listen", "127.0.0.1",
             "--port", "8189", "--disable-auto-launch"],
            cwd=str(COMFY_DIR), stdout=log, stderr=subprocess.STDOUT,
            # same as the ComfyUI launcher: no PyTorch self-compiling (it needs a compiler Windows lacks)
            env={**os.environ, "TORCHDYNAMO_DISABLE": "1"},
            start_new_session=(os.name != "nt"),      # its own process group, so close() can stop all of it
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        deadline = time.time() + 400
        while time.time() < deadline:
            if self.server.poll() is not None:
                raise RuntimeError("ComfyUI stopped while starting; see logs\\narrate-comfyui.log")
            if self._alive():
                return
            time.sleep(3)
        raise RuntimeError("ComfyUI did not start within a few minutes; see logs\\narrate-comfyui.log")

    def _inputs(self, node: str, **overrides) -> dict:
        """All required inputs of a node at their defaults, plus the given overrides."""
        if node not in self._info:
            self._info[node] = self._request(f"/object_info/{node}")[node]
        inputs = {}
        spec_all = self._info[node]["input"]
        # optional settings too: some nodes validate them as if they were required
        for name, spec in list(spec_all.get("required", {}).items()) + list(spec_all.get("optional", {}).items()):
            kind = spec[0]
            extra = spec[1] if len(spec) > 1 and isinstance(spec[1], dict) else {}
            if isinstance(kind, list):
                inputs[name] = extra.get("default", kind[0] if kind else "")
            elif kind in ("STRING", "INT", "FLOAT", "BOOLEAN"):
                inputs[name] = extra.get("default", {"STRING": "", "INT": 0, "FLOAT": 0.0, "BOOLEAN": False}[kind])
        inputs.update(overrides)
        return inputs

    def _engine_inputs(self) -> dict:
        node = self.ENGINES[self.engine]
        settings = {}
        if self.engine == "qwen3":
            # pick the 1.7B Base (cloning) checkpoint, whatever the menu calls it
            for name, spec in self._request(f"/object_info/{node}")[node]["input"]["required"].items():
                if isinstance(spec[0], list):
                    base = [o for o in spec[0] if "base" in str(o).lower() and "1.7b" in str(o).lower()]
                    if base:
                        settings[name] = base[0]
                    if "English" in spec[0] and name == "language":
                        settings[name] = "English"
        elif self.engine == "vibevoice":
            settings["multi_speaker_mode"] = "Custom Character Switching"
        elif self.engine == "chatterbox":
            settings["language"] = "English"
        return self._inputs(node, **settings)

    def _generate(self, text: str):
        import soundfile as sf
        graph = {
            "1": {"class_type": "LoadAudio", "inputs": {"audio": self.ref_name}},
            "2": {"class_type": "CharacterVoicesNode", "inputs": self._inputs(
                "CharacterVoicesNode", voice_name="none", reference_text=self.ref_text,
                opt_audio_input=["1", 0])},
            "3": {"class_type": self.ENGINES[self.engine], "inputs": self._engine_inputs()},
            "4": {"class_type": "UnifiedTTSTextNode", "inputs": self._inputs(
                "UnifiedTTSTextNode", TTS_engine=["3", 0], text=text, narrator_voice="none", seed=7,
                opt_narrator=["2", 0], enable_chunking=True, max_chars_per_chunk=400,
                enable_audio_cache=False)},
            "5": {"class_type": "SaveAudio", "inputs": {"audio": ["4", 0], "filename_prefix": "narrate_tmp/chunk"}},
        }
        reply = self._request("/prompt", {"prompt": graph, "client_id": self.client})
        prompt_id = reply["prompt_id"]
        deadline = time.time() + 1800
        while time.time() < deadline:
            history = self._request(f"/history/{prompt_id}")
            if prompt_id in history:
                entry = history[prompt_id]
                status = entry.get("status", {})
                if status.get("status_str") == "error":
                    messages = [m for m in status.get("messages", []) if m[0] == "execution_error"]
                    detail = messages[0][1].get("exception_message", "") if messages else "unknown error"
                    raise RuntimeError(f"ComfyUI could not speak this text: {detail.strip()}")
                saved = entry.get("outputs", {}).get("5", {}).get("audio", [])
                if saved:
                    f = saved[0]
                    path = COMFY_DIR / "output" / f.get("subfolder", "") / f["filename"]
                    audio, rate = sf.read(str(path), dtype="float32", always_2d=True)
                    path.unlink(missing_ok=True)
                    return audio.mean(axis=1), rate
            time.sleep(0.5)
        raise RuntimeError("ComfyUI took too long to speak a piece of text.")

    # -- the engine interface ------------------------------------------------
    def speak(self, text: str):
        sentences = re.split(r"(?<=[.!?;:])\s+", text.strip())
        groups, current = [], ""
        for s in sentences:
            if current and len(current) + len(s) + 1 > self.MAX_CHARS:
                groups.append(current)
                current = s
            else:
                current = f"{current} {s}".strip()
        if current:
            groups.append(current)
        for g in groups:
            audio, rate = self._generate(g)
            if rate != self.sample_rate:          # keep one rate for the whole file
                import numpy as np
                n = int(round(len(audio) * self.sample_rate / rate))
                audio = np.interp(np.linspace(0, len(audio) - 1, n), np.arange(len(audio)), audio).astype("float32")
            yield audio, _spread_evenly(g, len(audio) / self.sample_rate)

    def close(self) -> None:
        if self.server is not None and self.server.poll() is None:
            # The venv launcher starts the real Python as a child; stop both.
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(self.server.pid), "/T", "/F"], capture_output=True)
            else:
                import signal
                try:
                    os.killpg(os.getpgid(self.server.pid), signal.SIGTERM)
                except OSError:
                    self.server.terminate()
        self.server = None


def make_engine(settings: dict):
    clip = find_voice_clip(str(settings["voice"]))
    if clip and not (COMFY_PY).is_file():
        # the clip voices are spoken through ComfyUI voices; without it, use a built-in voice
        print(f"The voice '{settings['voice']}' needs the ComfyUI voices component, which isn't installed.\n"
              "Using the built-in voice bm_george instead. (Add ComfyUI voices in the Components window,\n"
              "or set another built-in voice in narrate\\settings.json.)")
        return KokoroEngine("bm_george", settings["speed"])
    if clip:
        return ComfyCloneEngine(clip, str(settings.get("clone_engine", "vibevoice")).lower())
    return KokoroEngine(settings["voice"], settings["speed"])


def _words_from_tokens(tokens) -> list[dict] | None:
    """Kokoro's English voices report when each token is spoken; fold tokens into words."""
    if not tokens:
        return None
    words, text, start, end = [], "", None, None
    for tok in tokens:
        text += tok.text
        if tok.start_ts is not None and start is None:
            start = float(tok.start_ts)
        if tok.end_ts is not None:
            end = float(tok.end_ts)
        if tok.whitespace:
            if text.strip():
                words.append({"text": text, "start": start, "end": end})
            text, start, end = "", None, None
    if text.strip():
        words.append({"text": text, "start": start, "end": end})
    if not any(w["start"] is not None for w in words):
        return None
    # Punctuation-only or unvoiced tokens have no timing; pin them to their neighbours.
    previous_end = 0.0
    for w in words:
        if w["start"] is None:
            w["start"] = previous_end
        if w["end"] is None or w["end"] < w["start"]:
            w["end"] = w["start"]
        previous_end = w["end"]
    return words


def _spread_evenly(text: str, seconds: float) -> list[dict]:
    """Fallback when an engine gives no word timings: share the time out by word length."""
    parts = text.split()
    total = sum(len(p) for p in parts) or 1
    words, t = [], 0.0
    for p in parts:
        d = seconds * len(p) / total
        words.append({"text": p, "start": t, "end": t + d})
        t += d
    return words


# -- producing the files ---------------------------------------------------------

def run_ffmpeg(args: list[str], cwd: Path | None = None) -> None:
    proc = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args],
                          cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError("ffmpeg failed: " + (proc.stderr.strip().splitlines() or ["unknown error"])[-1])


AUDIO_CODECS = {
    "mp3": ["-c:a", "libmp3lame", "-q:a", "2"],
    "m4a": ["-c:a", "aac", "-b:a", "128k"],
    "flac": ["-c:a", "flac"],
}


def make_video(audio: Path, srt: Path, out: Path, size: str) -> None:
    """Burn the subtitles onto a plain backdrop (or narrate\\background.jpg/.png if present)."""
    width, height = size.lower().split("x")
    # The subtitles filter has its own escaping rules for paths, so give it a plain
    # file name in the working directory instead of an arbitrary Windows path.
    temp_srt = out.parent / "_narrate_subtitles.srt"
    shutil.copyfile(srt, temp_srt)
    background = next((p for p in (ROOT / "narrate" / "background.jpg", ROOT / "narrate" / "background.png")
                       if p.is_file()), None)
    style = "FontName=Segoe UI,BorderStyle=1,Outline=1.2,Shadow=0,MarginL=40,MarginR=40"
    if background:
        source = ["-loop", "1", "-framerate", "24", "-i", str(background)]
        chain = (f"scale={width}:{height}:force_original_aspect_ratio=increase,crop={width}:{height},"
                 f"subtitles={temp_srt.name}:force_style='{style},FontSize=20,Alignment=2,MarginV=28'")
    else:
        source = ["-f", "lavfi", "-i", f"color=c=0x14181f:s={width}x{height}:r=24"]
        chain = f"subtitles={temp_srt.name}:force_style='{style},FontSize=22,Alignment=5'"
    try:
        run_ffmpeg([*source, "-i", str(audio), "-vf", chain,
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "26", "-tune", "stillimage",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-shortest", str(out)],
                   cwd=out.parent)
    finally:
        temp_srt.unlink(missing_ok=True)


def clock(seconds: float) -> str:
    s = int(seconds)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}"


def narrate(path: Path, out_dir: Path, settings: dict, engine) -> None:
    import numpy as np
    import soundfile as sf

    started = time.time()
    print(f"\n{path.name}", flush=True)
    blocks = read_document(path)
    characters = sum(len(t) for _k, t in blocks)
    print(f"  {len(blocks)} paragraphs, {characters:,} characters", flush=True)

    out_dir.mkdir(parents=True, exist_ok=True)
    rate = engine.sample_rate
    temp_wav = out_dir / f"{path.stem}.narration-in-progress.wav"
    cues: list[dict] = []
    position = 0.0                    # seconds of audio written so far
    last_report = time.time()
    try:
        # Audio is streamed to disk so a whole book never has to fit in memory.
        with sf.SoundFile(str(temp_wav), "w", samplerate=rate, channels=1, subtype="PCM_16") as wav:
            for index, (kind, text) in enumerate(blocks, 1):
                block_words = []
                for audio, words in engine.speak(text):
                    block_words += [{"text": w["text"], "start": position + w["start"],
                                     "end": position + w["end"]} for w in words]
                    wav.write(audio)
                    position += len(audio) / rate
                cues += words_to_cues(block_words)
                pause = settings["heading_pause"] if kind == "heading" else settings["paragraph_pause"]
                wav.write(np.zeros(int(pause * rate), dtype="float32"))
                position += pause
                if time.time() - last_report > 15:
                    print(f"  paragraph {index}/{len(blocks)}, {clock(position)} of audio so far", flush=True)
                    last_report = time.time()
        if not cues:
            raise ValueError("The speech engine produced no audio for this text.")

        srt = out_dir / f"{path.stem}.srt"
        write_srt(tidy_cues(cues), srt)
        outputs = [srt]

        fmt = settings["audio_format"].lower().lstrip(".")
        audio_out = out_dir / f"{path.stem}.{fmt}"
        if fmt == "wav":
            shutil.copyfile(temp_wav, audio_out)
        elif fmt in AUDIO_CODECS:
            run_ffmpeg(["-i", str(temp_wav), *AUDIO_CODECS[fmt], "-metadata", f"title={path.stem}", str(audio_out)])
        else:
            raise ValueError(f"Unknown audio_format '{fmt}'. Use mp3, m4a, wav or flac.")
        outputs.insert(0, audio_out)

        if settings["make_video"]:
            video = out_dir / f"{path.stem}.mp4"
            print("  rendering video ...", flush=True)
            make_video(temp_wav, srt, video, settings["video_size"])     # from the lossless audio
            outputs.append(video)
    finally:
        temp_wav.unlink(missing_ok=True)

    took = time.time() - started
    ratio = position / max(took, 0.1)
    print(f"  {clock(position)} of narration in {took:.0f} s ({ratio:.1f}x real time)" if ratio < 10
          else f"  {clock(position)} of narration in {took:.0f} s ({ratio:.0f}x real time)")
    for o in outputs:
        print(f"  -> {o}")


# -- running -------------------------------------------------------------------

def load_settings(args: argparse.Namespace) -> dict:
    settings = dict(DEFAULTS)
    if SETTINGS_FILE.is_file():
        try:
            settings.update(json.loads(SETTINGS_FILE.read_text(encoding="utf-8")))
        except json.JSONDecodeError as exc:
            print(f"Ignoring {SETTINGS_FILE} (not valid JSON: {exc}); using defaults.")
    else:
        SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_FILE.write_text(json.dumps(DEFAULTS, indent=2), encoding="utf-8")
    for name, value in (("voice", args.voice), ("clone_engine", args.clone_engine), ("speed", args.speed), ("audio_format", args.format),
                        ("video_size", args.video_size)):
        if value is not None:
            settings[name] = value
    if args.video:
        settings["make_video"] = True
    return settings


def unique_destination(folder: Path, name: str) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / name
    if target.exists():
        target = folder / f"{Path(name).stem} ({time.strftime('%Y-%m-%d %H%M%S')}){Path(name).suffix}"
    return target


def pending_files() -> bool:
    return any(p.is_file() and p.suffix.lower() in DOCUMENTS for p in IN_DIR.iterdir())


def watch(args: argparse.Namespace, out_dir: Path) -> None:
    """Watch narrate\\in.

    The voice model lives in a separate worker process that quits after
    IDLE_UNLOAD_SECONDS without work. Only a process exit gives every byte of GPU
    memory back, and this watcher itself never touches the GPU, so an idle
    watcher costs games nothing.
    """
    IN_DIR.mkdir(parents=True, exist_ok=True)
    load_settings(args)               # creates settings.json on first run
    print(f"Watching {IN_DIR}")
    print(f"Drop documents there ({', '.join(sorted(DOCUMENTS))}); narration appears in {out_dir}")
    print(f"Voice, speed, format and video are set in {SETTINGS_FILE}")
    print("Finished files move to in\\done. Press Ctrl+C to stop.\n", flush=True)
    worker_cmd = [sys.executable, str(Path(__file__).resolve()), "--worker",
                  *[a for a in sys.argv[1:] if a != "--watch"]]      # same options as this run
    worker = None
    try:
        while True:
            if worker is not None and worker.poll() is not None:
                if worker.returncode == 0:
                    print("(idle: voice model unloaded, GPU memory released)", flush=True)
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
    """Worker: narrate whatever arrives in narrate\\in, then quit after a quiet spell."""
    engine, engine_key = None, None
    last_work = time.time()
    seen_sizes: dict[Path, int] = {}
    try:
        while time.time() - last_work < IDLE_UNLOAD_SECONDS:
            for path in sorted(IN_DIR.iterdir()):
                if not path.is_file() or path.suffix.lower() not in DOCUMENTS:
                    continue
                size = path.stat().st_size
                if seen_sizes.get(path) != size:      # still being copied in; check again next round
                    seen_sizes[path] = size
                    continue
                seen_sizes.pop(path, None)
                try:
                    settings = load_settings(args)    # re-read so edits apply to the next file
                    key = (settings["voice"], settings["speed"], settings.get("clone_engine"))
                    if engine is None or key != engine_key:
                        if engine is not None:
                            engine.close()
                        engine, engine_key = make_engine(settings), key
                    narrate(path, out_dir, settings, engine)
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
    finally:
        if engine is not None:
            engine.close()          # also stops a ComfyUI this worker started

def main() -> int:
    p = argparse.ArgumentParser(description="Narrate documents with subtitles.")
    p.add_argument("files", nargs="*", type=Path, help="documents to narrate")
    p.add_argument("--watch", action="store_true", help="watch narrate\\in and narrate files dropped there")
    p.add_argument("--out", type=Path, default=OUT_DIR, help="output folder (default: narrate\\out)")
    p.add_argument("--voice", default=None,
                   help="a voice clip name from voices\\reference (e.g. wise_old_narrator) or a Kokoro voice (e.g. bm_george)")
    p.add_argument("--clone-engine", default=None, help="for voice clips: vibevoice (default), chatterbox or qwen3")
    p.add_argument("--speed", type=float, default=None, help="speaking speed, 1.0 = normal")
    p.add_argument("--format", default=None, help="mp3 (default), m4a, wav or flac")
    p.add_argument("--video", action="store_true", help="also make an MP4 with burned-in subtitles")
    p.add_argument("--video-size", default=None, help="e.g. 1280x720 (default) or 1920x1080")
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
    settings = load_settings(args)
    engine = make_engine(settings)
    failures = 0
    try:
        for f in args.files:
            try:
                narrate(f, args.out, settings, engine)
            except Exception:
                failures += 1
                traceback.print_exc()
    finally:
        engine.close()              # also stops a ComfyUI this run started
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
