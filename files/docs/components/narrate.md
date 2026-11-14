# Narrate

**The job:** read a document aloud naturally, and produce subtitles and an optional subtitled video.

## Why this tool
Narrate is the kit's own script. It has two ways of speaking:
- **Kokoro**, a small, fast speech model with 54 built-in voices. It was chosen as the quick option: it runs many times faster than real time and needs almost no graphics memory.
- **A voice clip**, spoken through one of the engines in the ComfyUI voices component. This is slower and sounds more human. It was added because built-in voices can't give a particular voice or delivery.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| Kokoro | https://github.com/hexgrad/kokoro (PyPI) | 0.9.4 | Apache-2.0 |
| Kokoro model and voices | Hugging Face `hexgrad/Kokoro-82M` | revision `f3ff3571…` | Apache-2.0 |
| Document readers | PyPI: pymupdf 2.1, ebooklib 0.21, python-docx 1.2.0 | as listed | AGPL-3.0 (first two), MIT |
| English text model | spaCy `en_core_web_sm` 3.8.0 | from its GitHub release | MIT |

## How the kit uses it
- **Environment:** `tools\narrate\.venv`, Python 3.12, PyTorch 2.8.0 for CUDA 12.8.
- **Script:** `scripts\narrate.py`, with `scripts\subtitles.py` for subtitle timing.
- **Launchers:** `Narrate.bat` and `Narrate to video.bat`. With files, they narrate those. With none, they watch `narrate\in`.
- **Reads:** .txt .md .docx .pdf .epub .html. The function `read_document()` returns the text in sections; other parts of the kit can reuse it.
- **Settings:** `narrate\settings.json`. `voice` is either a clip name from `voices\reference` (with a `.txt` beside it holding the clip's exact words) or a Kokoro voice name. `clone_engine` picks the engine for clips.
- **Clip voices** go through ComfyUI on port 8189. Narrate uses one that's already running, or starts one in the background and stops it afterwards.
- **Without the ComfyUI component,** a clip voice falls back to the Kokoro voice `bm_george`, with a message.
- **Folders:** in `narrate\in`, out `narrate\out`.

## Quick test
Drop `samples\sample_document.md` onto `Narrate.bat`. An `.mp3` and an `.srt` should appear in `narrate\out`.

## Known problems
- **Clip voices are slow to start,** about a minute, because ComfyUI has to start.
- **Subtitle timing** is word by word with Kokoro and sentence by sentence with clip voices.
- **The two document readers under AGPL** matter only if the kit's code is ever distributed as part of a closed product.

## If it dies
The script is the kit's own, so the question is which speech engine it drives.
- **A replacement for Kokoro** must speak text quickly from Python and report word timings.
- **Search for:** "open source TTS", "local text to speech", and the names on current listening leaderboards.
- **Check by ear:** a long paragraph for naturalness and steadiness, plus wrong words by transcribing the result back.
