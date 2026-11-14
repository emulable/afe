"""Turn a hum, a sung line or a beatbox take into an instrument track.

    hum_to_track.py RECORDING [RECORDING ...] [-p "PROMPT"] [options]

The prompt says what the recording is and, optionally, what should play it.
If you leave it out you are asked for each file.

    "this is the melody"                  synth lead (the default; never piano unless you ask)
    "melody on a duduk"                   a duduk-like double reed (also: ney, santur, lyre, oud, chant)
    "this is the bass line"               synth bass, moved down into the bass range
    "bass line, slap bass"                slap bass
    "these are chords, dark pad"          keeps every note (for recordings with several notes at once)
    "this is the beat"                    beatbox -> drum kit (kick / snare / hi-hat)
    "the beat, 808 kit"                   TR-808 kit (also: electronic, jazz, brush, rock, room)

For each recording NAME it writes, into music\\out:

    NAME_<part>_<instrument>.mid                 the notes, editable in any music program
    NAME_<part>_<instrument>.wav                 the notes played by the instrument
    NAME_<part>_<instrument>_with_original.wav   the same with your recording quietly underneath

For a fully produced version, load the .wav into ACE-Step as the source audio
(Cover or Repaint) and describe the style you want.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "music" / "out"
SOUNDFONT = ROOT / "models" / "soundfonts" / "GeneralUser-GS.sf2"

# (regex, General MIDI program, name, comfortable centre pitch as a MIDI note)
# More specific names come first ("slap bass" before "bass", "temple bells" before "bells").
# Ancient instruments map to the closest General MIDI sound; piano is only ever used when
# asked for by name, and it is checked last so "thumb piano" still means kalimba.
INSTRUMENTS = [
    # ancient and folk instruments of the Near East and beyond
    (r"duduk|zurna|shawm|shanai|shehnai|sorna|surnay|mizmar|double.?reed|balaban", 111, "double reed (duduk-like)", 62),
    (r"\bney\b|\bnay\b|kaval|shakuhachi|end.?blown|reed flute", 77, "breathy reed flute (ney-like)", 72),
    (r"santur|santoor|hammered dulcimer|dulcimer|cimbalom|qanun|kanun|psaltery|zither", 15, "hammered strings (santur-like)", 67),
    (r"lyre|chang\b|kinnor|ancient harp|harp", 46, "harp / lyre", 67),
    (r"\boud\b|setar|tanbur|tambur|saz\b|baglama|bouzouki|\blute\b|sitar", 104, "plucked lute", 62),
    (r"kamancheh|kemenche|rebab|rebec|erhu|spike fiddle|gadulka", 110, "bowed spike fiddle", 70),
    (r"oktavist|basso|low choir|male choir|monks?\b|gregorian|orthodox|chant", 52, "low male choir", 45),
    (r"choir|aahs|voices", 52, "choir", 60),
    (r"temple bells?|church bells?|tubular bells?|bell tower", 14, "tubular bells", 67),
    (r"bagpipe", 109, "bagpipes", 67),
    (r"koto", 107, "koto", 67),
    (r"kalimba|thumb piano|mbira", 108, "kalimba", 72),
    (r"pan ?flute|pan ?pipes", 75, "pan flute", 76),
    (r"ocarina", 79, "ocarina", 79),
    # synths
    (r"slap bass", 36, "slap bass", 40),
    (r"synth ?bass|sub ?bass|808 bass|moog bass|analog bass", 38, "synth bass", 36),
    (r"dark pad|halo|ominous pad", 94, "halo pad", 55),
    (r"sweep pad|sweeping", 95, "sweep pad", 58),
    (r"drone|bowed pad", 92, "bowed pad (drone)", 50),
    (r"glass pad|metallic pad|metallic", 93, "metallic pad", 64),
    (r"space voice|choir pad|vocal pad", 91, "space voice pad", 60),
    (r"polysynth|poly synth", 90, "polysynth", 60),
    (r"pad", 89, "warm pad", 60),
    (r"square|chiptune|8.?bit", 80, "square lead", 72),
    (r"synth lead|lead synth|sawtooth|synth", 81, "synth lead", 70),
    # everything else
    (r"fretless", 35, "fretless bass", 40),
    (r"upright bass|double bass|acoustic bass|jazz bass", 32, "upright bass", 40),
    (r"picked bass", 34, "picked bass", 40),
    (r"electric bass|finger bass|bass guitar", 33, "electric bass", 40),
    (r"organ", 16, "organ", 64),
    (r"accordion", 21, "accordion", 65),
    (r"harmonica", 22, "harmonica", 67),
    (r"nylon|classical guitar|spanish guitar", 24, "nylon guitar", 62),
    (r"acoustic guitar", 25, "acoustic guitar", 62),
    (r"distort|overdrive|rock guitar|metal guitar", 30, "distorted guitar", 60),
    (r"electric guitar|guitar", 27, "electric guitar", 62),
    (r"violin|fiddle", 40, "violin", 74),
    (r"viola", 41, "viola", 65),
    (r"cello", 42, "cello", 52),
    (r"pizzicato", 45, "pizzicato strings", 64),
    (r"strings|string section|orchestra", 48, "strings", 64),
    (r"trumpet", 56, "trumpet", 70),
    (r"trombone", 57, "trombone", 55),
    (r"tuba", 58, "tuba", 38),
    (r"french horn", 60, "french horn", 60),
    (r"brass|horns", 61, "brass section", 64),
    (r"horn", 60, "french horn", 60),
    (r"soprano sax", 64, "soprano sax", 72),
    (r"alto sax", 65, "alto sax", 67),
    (r"baritone sax|bari sax", 67, "baritone sax", 50),
    (r"tenor sax|sax", 66, "tenor sax", 60),
    (r"oboe", 68, "oboe", 72),
    (r"bassoon", 70, "bassoon", 48),
    (r"clarinet", 71, "clarinet", 67),
    (r"piccolo", 72, "piccolo", 84),
    (r"flute", 73, "flute", 79),
    (r"whistl", 78, "whistle", 84),
    (r"glockenspiel|glock|bells", 9, "glockenspiel", 84),
    (r"music box", 10, "music box", 84),
    (r"vibraphone|vibes", 11, "vibraphone", 69),
    (r"marimba", 12, "marimba", 67),
    (r"xylophone", 13, "xylophone", 79),
    (r"steel ?drums?|steel ?pan", 114, "steel drums", 67),
    (r"banjo", 105, "banjo", 64),
    # only when asked for by name
    (r"electric piano|e-piano|rhodes|wurlitzer", 4, "electric piano", 64),
    (r"piano", 0, "piano", 64),
]
# No piano unless you ask for it: a plain melody gets a synth lead, chords a warm pad,
# a bass line a synth bass.
DEFAULT_INSTRUMENT = {"melody": (81, "synth lead", 70), "chords": (89, "warm pad", 60), "bass": (38, "synth bass", 36)}
# Drum kits in the GeneralUser GS SoundFont, chosen with a program change on the drum channel.
KITS = [
    (r"ancient|ritual|war ?drums?|taiko|tribal|frame ?drums?|temple", 48, "big ritual drums (orchestral kit)"),
    (r"808|trap|hip.?hop|\brap\b", 25, "808 kit"),
    (r"909|techno|house|edm|electro|dance", 24, "electronic kit"),
    (r"jazz", 32, "jazz kit"),
    (r"brush", 40, "brush kit"),
    (r"rock|power|metal", 16, "rock kit"),
    (r"room", 8, "room kit"),
    (r"orchestra", 48, "orchestral kit"),
]
KICK, SNARE, HIHAT = 36, 38, 42           # General MIDI drum notes

MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
MAJOR_SCALE = {0, 2, 4, 5, 7, 9, 11}
MINOR_SCALE = {0, 2, 3, 5, 7, 8, 10, 11}  # natural minor plus the raised 7th
NOTE_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

MIN_NOTE = 0.08            # seconds; shorter blips from the pitch tracker are dropped


@dataclass
class Note:
    start: float
    end: float
    pitch: int
    velocity: int

    @property
    def length(self) -> float:
        return self.end - self.start


# -- reading the prompt ----------------------------------------------------------

def detect_part(prompt: str) -> str:
    p = re.sub(r"\b(bass|kick) ?drums?\b", " kick ", prompt.lower())   # "bass drum" is a drum
    if re.search(r"\b(chords?|harmony|harmonies|polyphonic)\b", p):
        return "chords"
    if re.search(r"\bbass\b|\bbassline\b|\blow end\b", p):
        return "bass"
    if re.search(r"\b(beats?|drums?|drumbeat|beatbox\w*|percussion|kick|snare|hi.?hats?)\b", p):
        return "beat"
    return "melody"


def pick_instrument(prompt: str, part: str) -> tuple[int, str, int]:
    p = prompt.lower()
    for pattern, program, name, centre in INSTRUMENTS:
        if re.search(rf"\b(?:{pattern})", p):
            if part == "bass" and name in ("synth lead", "square lead"):
                return 38, "synth bass", 36            # "bass line, synth" means a synth bass
            return program, name, centre
    return DEFAULT_INSTRUMENT[part]


def pick_kit(prompt: str) -> tuple[int, str]:
    p = prompt.lower()
    for pattern, program, name in KITS:
        if re.search(pattern, p):
            return program, name
    return 0, "standard kit"


# -- melody, bass and chords -------------------------------------------------------

def transcribe(wav: Path, part: str, args) -> list[Note]:
    import logging
    # Basic Pitch warns about every model backend that isn't installed (CoreML,
    # TFLite, TensorFlow); only its ONNX backend is used here.
    logging.getLogger().setLevel(logging.ERROR)
    from basic_pitch import ICASSP_2022_MODEL_PATH
    from basic_pitch.inference import predict

    voice_range = part in ("melody", "bass")
    _, _, events = predict(
        str(wav), ICASSP_2022_MODEL_PATH,
        onset_threshold=args.onset_threshold,
        frame_threshold=args.frame_threshold,
        minimum_note_length=MIN_NOTE * 1000,
        # A voice sits roughly between 60 Hz and 1.2 kHz; limiting the search avoids harmonics.
        minimum_frequency=60.0 if voice_range else None,
        maximum_frequency=1200.0 if voice_range else None,
        multiple_pitch_bends=False,
        melodia_trick=True,
    )
    notes = [Note(float(s), float(e), int(p), int(max(1, min(127, 50 + 77 * float(a)))))
             for s, e, p, a, _bends in events]
    return sorted(notes, key=lambda n: (n.start, n.pitch))


def make_monophonic(notes: list[Note]) -> list[Note]:
    """Keep one note at a time, preferring the stronger one where two overlap."""
    out: list[Note] = []
    for n in sorted(notes, key=lambda n: (n.start, -n.velocity)):
        if out and n.start < out[-1].end:
            prev = out[-1]
            if n.velocity * n.length > prev.velocity * prev.length:
                prev.end = n.start                    # the new note wins; cut the old one short
                if prev.length < MIN_NOTE:
                    out.pop()
                out.append(n)
            elif n.end - prev.end >= MIN_NOTE:         # the old note wins; keep the new note's tail
                n.start = prev.end
                out.append(n)
            continue
        out.append(n)
    out.sort(key=lambda n: n.start)
    for a, b in zip(out, out[1:]):                     # final guard against overlaps
        if a.end > b.start:
            a.end = b.start
    return [n for n in out if n.length >= MIN_NOTE]


def fix_octave_jumps(notes: list[Note]) -> int:
    """Move notes an octave when the pitch tracker latched onto a harmonic."""
    import numpy as np

    pitches = [n.pitch for n in notes]
    fixed = 0
    for i, n in enumerate(notes):
        neighbours = pitches[max(0, i - 2):i] + pitches[i + 1:i + 3]
        if len(neighbours) < 2:
            continue
        ref = float(np.median(neighbours))
        jump = n.pitch - ref
        if abs(jump) >= 10:
            candidate = n.pitch - 12 * round(jump / 12)
            if abs(candidate - ref) <= 7:
                n.pitch = candidate
                fixed += 1
    return fixed


def tidy_line(notes: list[Note]) -> list[Note]:
    """Join same-pitch fragments split by a tiny gap and close small gaps (legato)."""
    out: list[Note] = []
    for n in notes:
        if out and n.pitch == out[-1].pitch and n.start - out[-1].end < 0.03:
            out[-1].end = max(out[-1].end, n.end)
            out[-1].velocity = max(out[-1].velocity, n.velocity)
            continue
        out.append(n)
    for a, b in zip(out, out[1:]):
        if 0 < b.start - a.end < 0.05:
            a.end = b.start
    return out


def detect_key(notes: list[Note]):
    """Krumhansl-Schmuckler key estimate from how long each pitch class sounds."""
    import numpy as np

    weights = np.zeros(12)
    for n in notes:
        weights[n.pitch % 12] += n.length
    if np.count_nonzero(weights) < 3:
        return None
    best = None
    for tonic in range(12):
        for mode, profile in (("major", MAJOR_PROFILE), ("minor", MINOR_PROFILE)):
            r = float(np.corrcoef(weights, np.roll(profile, tonic))[0, 1])
            if best is None or r > best[0]:
                best = (r, tonic, mode)
    return best


def snap_to_key(notes: list[Note], tonic: int, mode: str) -> int:
    """Move notes that fall outside the key to the nearest note inside it."""
    scale = {(tonic + s) % 12 for s in (MAJOR_SCALE if mode == "major" else MINOR_SCALE)}
    moved = 0
    for i, n in enumerate(notes):
        if n.pitch % 12 in scale:
            continue
        options = [p for p in (n.pitch - 1, n.pitch + 1) if p % 12 in scale]
        if not options:
            continue
        # Between two candidates, go toward the previous note (smoother line).
        ref = notes[i - 1].pitch if i else n.pitch
        n.pitch = min(options, key=lambda p: abs(p - ref))
        moved += 1
    return moved


def move_to_range(notes: list[Note], centre: int, low: int | None = None, high: int | None = None) -> int:
    """Shift the whole line by octaves so it sits around the instrument's centre pitch."""
    import numpy as np

    median = float(np.median([n.pitch for n in notes]))
    shift = 12 * round((centre - median) / 12) if abs(centre - median) > 7 else 0
    for n in notes:
        n.pitch += shift
        while low is not None and n.pitch < low:
            n.pitch += 12
        while high is not None and n.pitch > high:
            n.pitch -= 12
        n.pitch = max(0, min(127, n.pitch))
    return shift


def quantize(notes: list[Note], bpm: float, division: int) -> None:
    step = 60.0 / bpm * 4 / division
    for n in notes:
        start = round(n.start / step) * step
        end = max(start + step, round(n.end / step) * step)
        n.start, n.end = start, end


# -- beatbox -------------------------------------------------------------------------

def beatbox_to_drums(wav: Path, args) -> tuple[list[Note], float]:
    """Find each hit, then sort hits into kick / snare / hi-hat by their sound."""
    import librosa
    import numpy as np

    y, sr = librosa.load(str(wav), sr=22050, mono=True)
    hop = 512
    envelope = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    peaks = librosa.onset.onset_detect(onset_envelope=envelope, sr=sr, hop_length=hop, units="frames",
                                       delta=args.hit_sensitivity, wait=max(1, int(0.06 * sr / hop)))
    if len(peaks) == 0:
        return [], 120.0
    times = _refine_onsets(y, sr, librosa.frames_to_time(peaks, sr=sr, hop_length=hop))
    strength = envelope[peaks]

    features = []
    for i, t in enumerate(times):
        a = int(t * sr)
        nxt = int(times[i + 1] * sr) if i + 1 < len(times) else len(y)
        b = min(nxt, a + int(0.08 * sr))
        seg = y[a:max(b, a + int(0.03 * sr))]
        if len(seg) < 32:
            seg = np.pad(seg, (0, 32 - len(seg)))
        spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
        freqs = np.fft.rfftfreq(len(seg), 1 / sr)
        total = spec.sum() + 1e-12
        centroid = float((freqs * spec).sum() / total)
        features.append([np.log(centroid + 1.0),
                         spec[freqs < 150].sum() / total,          # body of a kick
                         spec[freqs > 5000].sum() / total])        # hiss of a hi-hat
    feats = np.array(features)

    labels = _cluster_hits(feats)
    tempo = float(np.atleast_1d(librosa.beat.beat_track(onset_envelope=envelope, sr=sr, hop_length=hop)[0])[0])
    lo, hi = float(strength.min()), float(strength.max())
    notes = []
    for t, label, s in zip(times, labels, strength):
        velocity = int(70 + 57 * ((s - lo) / (hi - lo) if hi > lo else 1.0))
        length = 0.05 if label == HIHAT else 0.12
        notes.append(Note(float(t), float(t) + length, label, velocity))
    return notes, tempo if tempo > 0 else 120.0


def _refine_onsets(y, sr, peak_times):
    """Move each detected hit to where its attack really starts.

    The onset detector reports hits a little late (it works in ~23 ms frames), so
    look just before each one for the moment the sound jumps up fastest. A falling
    tail from the previous hit never wins, because only rises count.
    """
    import numpy as np

    win = max(1, int(0.003 * sr))
    env = np.convolve(np.abs(y), np.ones(win) / win, mode="same")
    lag = max(1, int(0.002 * sr))
    rise = np.zeros_like(env)
    rise[lag:] = env[lag:] - env[:-lag]
    out, last = [], None
    for p in peak_times:
        a = max(0, int((p - 0.06) * sr))
        if last is not None:
            a = max(a, int((last + 0.03) * sr))        # never step back onto the previous hit
        b = min(len(y), int((p + 0.02) * sr))
        t = float(p) if b - a < 2 * lag else max(0.0, (a + int(np.argmax(rise[a:b])) - lag) / sr)
        out.append(t)
        last = t
    return np.array(out)


def _cluster_hits(feats):
    """Group hits into up to three sounds with k-means, then name the groups:
    darkest = kick, brightest = hi-hat, the one in between = snare."""
    import numpy as np

    n = len(feats)
    k = min(3, n)
    z = (feats - feats.mean(axis=0)) / (feats.std(axis=0) + 1e-9)
    order = np.argsort(feats[:, 0])
    centres = z[[order[int(q * (n - 1))] for q in np.linspace(0, 1, k)]]
    for _ in range(50):
        assign = np.argmin(((z[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2), axis=1)
        new = np.array([z[assign == c].mean(axis=0) if np.any(assign == c) else centres[c] for c in range(k)])
        if np.allclose(new, centres):
            break
        centres = new
    brightness = [feats[assign == c, 0].mean() if np.any(assign == c) else 0.0 for c in range(k)]
    ranked = list(np.argsort(brightness))          # cluster ids, darkest first
    if k == 3:
        names = {ranked[0]: KICK, ranked[1]: SNARE, ranked[2]: HIHAT}
    elif k == 2:
        bright = feats[assign == ranked[1], 0].mean()
        names = {ranked[0]: KICK, ranked[1]: HIHAT if np.exp(bright) > 3500 else SNARE}
    else:
        names = {ranked[0]: KICK}
    return [names[c] for c in assign]


# -- output ----------------------------------------------------------------------------

def run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout).strip().splitlines()[-3:]
        raise RuntimeError(f"{Path(cmd[0]).name} failed: " + " | ".join(tail))


def find_fluidsynth() -> Path:
    found = sorted((ROOT / "tools" / "fluidsynth").glob("**/bin/fluidsynth.exe"))
    if found:
        return found[-1]
    # other systems (Linux, Mac): the fluidsynth installed by the system's package manager
    import shutil
    system_one = shutil.which("fluidsynth")
    if system_one:
        return Path(system_one)
    raise FileNotFoundError("FluidSynth not found under tools\\fluidsynth (run scripts\\install_music_tools.ps1)")


def write_midi(notes: list[Note], path: Path, program: int, name: str, drums: bool, tempo: float) -> None:
    import pretty_midi

    pm = pretty_midi.PrettyMIDI(initial_tempo=tempo)
    inst = pretty_midi.Instrument(program=program, is_drum=drums, name=name)
    for n in notes:
        inst.notes.append(pretty_midi.Note(velocity=n.velocity, pitch=n.pitch,
                                           start=n.start, end=max(n.end, n.start + 0.03)))
    pm.instruments.append(inst)
    pm.write(str(path))


def render(midi: Path, wav: Path) -> None:
    if not SOUNDFONT.is_file():
        raise FileNotFoundError(f"SoundFont missing: {SOUNDFONT}")
    run([str(find_fluidsynth()), "-ni", "-q", "-g", "0.8", "-r", "44100", "-T", "wav",
         "-F", str(wav), str(SOUNDFONT), str(midi)])


def mix_with_original(track: Path, original: Path, out: Path) -> None:
    fmt = "aformat=sample_rates=44100:channel_layouts=stereo"
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(track), "-i", str(original),
         "-filter_complex", f"[0:a]{fmt}[t];[1:a]{fmt},volume=0.4[o];[t][o]amix=inputs=2:duration=longest:normalize=0[m]",
         "-map", "[m]", str(out)])


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def process(path: Path, prompt: str, args) -> None:
    part = args.part or detect_part(prompt)
    print(f"\n{path.name}: treating it as the {part}", flush=True)
    args.out.mkdir(parents=True, exist_ok=True)

    # Decode anything ffmpeg can read (mp3, m4a, even video) into a plain mono WAV first.
    temp = args.out / f"_{path.stem}.hum-to-track-input.wav"
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path), "-vn", "-ac", "1", "-ar", "44100", str(temp)])
    try:
        tempo = args.bpm or 120.0
        if part == "beat":
            program, name = pick_kit(prompt)
            notes, detected = beatbox_to_drums(temp, args)
            tempo = args.bpm or round(detected)
            if not notes:
                raise ValueError("No drum hits found. Try a louder, closer recording or --hit-sensitivity 0.03")
            counts = {label: sum(n.pitch == drum for n in notes)
                      for label, drum in (("kick", KICK), ("snare", SNARE), ("hi-hat", HIHAT))}
            print(f"  {len(notes)} hits: " + ", ".join(f"{v} {k}" for k, v in counts.items() if v)
                  + f"; about {tempo:.0f} BPM; {name}")
        else:
            program, name, centre = pick_instrument(prompt, part)
            print("  finding the notes ...", flush=True)
            notes = transcribe(temp, part, args)
            if part != "chords":
                notes = make_monophonic(notes)
                fixed = fix_octave_jumps(notes)
                notes = tidy_line(notes)
                if fixed:
                    print(f"  corrected {fixed} octave slip(s)")
            if not notes:
                raise ValueError("No notes found. Try humming louder or closer to the mic, "
                                 "or lower --onset-threshold.")
            if part != "chords" and not args.keep_chromatic:
                key = detect_key(notes)
                if key and key[0] >= 0.6:
                    moved = snap_to_key(notes, key[1], key[2])
                    print(f"  key looks like {NOTE_NAMES[key[1]]} {key[2]}; "
                          f"{moved} off-key note(s) nudged into it (use --keep-chromatic to skip)")
                elif key:
                    print("  key unclear, so notes were left as sung")
            if not args.no_transpose:
                if part == "bass":
                    shift = move_to_range(notes, min(centre, 45), low=28, high=60)
                else:
                    shift = move_to_range(notes, centre)
                if shift:
                    print(f"  moved {abs(shift) // 12} octave(s) {'up' if shift > 0 else 'down'} to suit the {name}")
            if args.octave:
                for n in notes:
                    n.pitch = max(0, min(127, n.pitch + 12 * args.octave))
            print(f"  {len(notes)} notes; {name}")
        if args.bpm:
            quantize(notes, args.bpm, args.grid)
            if part not in ("chords", "beat"):
                for a, b in zip(notes, notes[1:]):
                    if a.end > b.start:
                        a.end = b.start
                notes = [n for n in notes if n.end > n.start]

        base = args.out / f"{path.stem}_{part}_{slug(name)}"
        midi, wav, mix = base.with_suffix(".mid"), base.with_suffix(".wav"), Path(f"{base}_with_original.wav")
        write_midi(notes, midi, program, name, part == "beat", tempo)
        render(midi, wav)
        mix_with_original(wav, temp, mix)
        for f in (midi, wav, mix):
            print(f"  -> {f}")
    finally:
        temp.unlink(missing_ok=True)


def main() -> int:
    import warnings
    warnings.filterwarnings("ignore", message=".*pkg_resources is deprecated.*")
    p = argparse.ArgumentParser(description="Turn a hum, a sung line or a beatbox take into an instrument track.")
    p.add_argument("files", nargs="+", type=Path, help="recordings (wav, mp3, m4a, ... or video)")
    p.add_argument("-p", "--prompt", help='what it is, e.g. "this is the bass line, slap bass"')
    p.add_argument("--part", choices=("melody", "bass", "chords", "beat"), help="override what the prompt implies")
    p.add_argument("--out", type=Path, default=OUT_DIR, help="output folder (default: music\\out)")
    p.add_argument("--bpm", type=float, help="snap notes to a grid at this tempo (default: keep your timing)")
    p.add_argument("--grid", type=int, default=16, help="grid for --bpm: 8 = eighth notes, 16 = sixteenths (default)")
    p.add_argument("--octave", type=int, default=0, help="extra octave shift, e.g. -1 or 1")
    p.add_argument("--no-transpose", action="store_true", help="keep the octave you sang in")
    p.add_argument("--keep-chromatic", action="store_true", help="do not nudge off-key notes into the detected key")
    p.add_argument("--onset-threshold", type=float, default=0.5, help="lower finds more note starts (default 0.5)")
    p.add_argument("--frame-threshold", type=float, default=0.3, help="lower keeps quieter notes (default 0.3)")
    p.add_argument("--hit-sensitivity", type=float, default=0.07, help="beat: lower finds more drum hits (default 0.07)")
    args = p.parse_args()

    failures = 0
    for f in args.files:
        if not f.is_file():
            print(f"Not found: {f}")
            failures += 1
            continue
        prompt = args.prompt
        if prompt is None:
            if not sys.stdin.isatty():
                print("Give a prompt with -p, e.g. -p \"this is the bass line\"")
                return 2
            prompt = input(f'\nWhat is "{f.name}"?  e.g. "this is the bass line, slap bass" or "the beat, 808 kit"\n> ')
        try:
            process(f, prompt, args)
        except Exception as exc:
            failures += 1
            print(f"  FAILED: {exc}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
