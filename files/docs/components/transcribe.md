# Transcribe

**The job:** turn audio or video into text with timings for every word, labelled by speaker.

## Why this tool
**WhisperX** wraps the Whisper speech model with two things plain Whisper lacks: accurate per-word timing, and working out who spoke when. It was chosen over plain Whisper for those two, and over cloud services because it's offline.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| WhisperX | https://github.com/m-bain/whisperX (installed from PyPI) | 3.8.6 | BSD-2-Clause |
| faster-whisper | PyPI | 1.2.1 | MIT |
| Whisper large-v3 model | Hugging Face `Systran/faster-whisper-large-v3` | revision `edaa852e…` | MIT |
| Word-timing model (wav2vec2) | download.pytorch.org | fixed file | MIT |
| Offline speaker models | sherpa-onnx releases (pyannote segmentation 3.0, NeMo TitaNet) | fixed files | each model's own; check its page before any commercial use |
| pyannote (optional, better speakers) | PyPI | 4.0.7 | MIT, with gated models |

## How the kit uses it
- **Environment:** `tools\whisperx\.venv`, Python 3.12, PyTorch 2.8.0 for CUDA 12.9.
- **The kit's own script** does the work: `scripts\transcribe.py`. It writes `.txt`, `.srt` and `.json` for each file.
- **Launcher:** `Transcribe.bat` runs `transcribe.py` with any files dropped on it, or watches `transcribe\in` when started with none.
- **Folders:** in `transcribe\in`, out `transcribe\out`. Models in `models\huggingface`, `models\torch` and `models\diarization`.
- **Speakers:** offline by default (sherpa-onnx). With a free Hugging Face token saved in `models\huggingface\token`, it uses pyannote instead.
- **The piano checker** (`scripts\piano_check.py`) borrows this environment.
- **Memory:** about 6 GB of graphics memory.

## Quick test
Drop any short recording of speech onto `Transcribe.bat`. A `.txt` with the words should appear in `transcribe\out` within a minute.

## Known problems
- **A torchcodec warning at start** is harmless; audio is decoded by ffmpeg.
- **`faster_whisper` can't open files directly in this environment** (a version mismatch in a helper library). Load audio with `whisperx.audio.load_audio` and pass that in, as `transcribe.py` does.
- **The drop-folder watcher** runs the model in a helper program that exits after 90 seconds idle, to give the graphics card back.

## If it dies
A successor must give: text, per-word start and end times, and a speaker label per stretch of speech, from a command line, offline.
- **Search for:** "Whisper word timestamps diarization", "speech to text speaker diarization open source".
- **Likely candidates:** newer Whisper wrappers; Parakeet-based tools; on a Mac, `whispermlx`.
- **Check:** accuracy on a real two-person recording, word timing against the audio, and memory needed.
