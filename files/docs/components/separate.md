# Stem separation

**The job:** split a song into its parts: vocals and instrumental, or vocals, drums, bass and the rest.

## Why this tool
**audio-separator** is a thin command-line wrapper around the separation models that the community keeps improving. It was chosen because one tool gives access to many models, so the model can be swapped without changing anything else.

Two models are installed:
- **BS-RoFormer** for vocals against instrumental. It gives the cleanest vocal, which also makes it the way to get a clean clip for voice cloning.
- **Demucs (htdemucs_ft)** for four parts.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| audio-separator | https://github.com/nomadkaraoke/python-audio-separator (PyPI) | 0.48.0 | MIT |
| BS-RoFormer model | fetched by the tool | `model_bs_roformer_ep_317_sdr_12.9755.ckpt` | see the model's page |
| Demucs model | fetched by the tool | `htdemucs_ft.yaml` and its four files | MIT |

## How the kit uses it
- **Environment:** `tools\separator\.venv`, Python 3.12, PyTorch 2.8.0 for CUDA 12.8.
- **Launchers:** both run `audio-separator.exe` on the dropped files with `--model_file_dir models\separator --output_dir music\stems --output_format WAV`.
  - `Separate vocals.bat` adds `-m model_bs_roformer_ep_317_sdr_12.9755.ckpt`
  - `Separate stems (vocals, drums, bass, other).bat` adds `-m htdemucs_ft.yaml`
- **Folders:** models in `models\separator`, results in `music\stems`.
- **Memory:** about 6 GB of graphics memory. A 90-second song takes 15–25 seconds.

## Quick test
Drop a song onto `Separate vocals.bat`. Two files, vocals and instrumental, should appear in `music\stems`.

## Known problems
- **Install the plain `[cpu]` variant, not `[gpu]`.** The GPU variant pulls a library built for a different CUDA version and fails to load. The models still run on the graphics card through PyTorch.
- **A warning "CUDAExecutionProvider not available"** is harmless for these two models.
- **It also needs the `audioread` package.**
- **Its default model folder is `C:\tmp`,** which is why the launchers always pass `--model_file_dir`.

## If it dies
A successor must take a song file and write separate files per part, from a command line.
- **Search for:** "stem separation open source", "UVR models", "vocal remover model leaderboard".
- **Newer models usually drop straight into this tool:** try a new model name with `-m` before replacing the tool.
- **Check by ear:** bleed between parts, and watery artefacts in the vocal.
