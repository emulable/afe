# Abogen

**The job:** turn a whole book into an audiobook with chapters, in a desktop app.

## Why this tool
Abogen is a ready-made app for exactly this: it finds chapters, writes M4B audiobooks with chapter marks, and makes subtitle files. It was chosen so that whole-book work has a proper window with a queue. Narrate handles single documents.

It isn't in the installer's Recommended pick, because Narrate covers the core of its job.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| Abogen | https://github.com/denizsafak/abogen (PyPI) | 1.3.1 | MIT |
| Kokoro model and voices | shared with Narrate | same revision | Apache-2.0 |
| PyQt6 (its window toolkit) | PyPI | 6.12.0 | GPL-3.0 |

## How the kit uses it
- **Environment:** `tools\abogen\.venv`, Python 3.12. Its package installs a processor-only PyTorch; the kit's lock swaps in PyTorch 2.8.0 for CUDA 12.8.
- **Launcher:** `Abogen (audiobooks).bat` runs `tools\abogen\.venv\Scripts\abogen.exe`.
- **Models:** it uses the same Kokoro download as Narrate. Removing one of the two keeps the model for the other.
- **Output:** wherever you choose in the app.

## Quick test
Start it from the launcher. Its window should open and list the Kokoro voices.

## Known problems
- **Use the desktop app, not `abogen-cli` or `abogen-web`.** Those start a web server that other devices on the network can reach.
- **Non-English books** may need `espeak-ng`, which isn't installed.
- **A full book conversion was never clicked through** during testing; only opening the app was.

## If it dies
A successor must take an EPUB or PDF and produce an audiobook file with chapter marks.
- **Search for:** "epub to audiobook", "audiobook generator TTS open source".
- **Or drop it:** extend `scripts\narrate.py` to split by chapter and write chapter marks. It already reads the same book formats.
