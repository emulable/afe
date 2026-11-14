# AI Audio on Linux

**Status: written, never run on Linux.** `aia.py` is a careful translation of the Windows installer and launchers, made on a Windows PC. Only its dry run was checked (every command it would run was printed and read). The first real install will need fixes. It's built so that a language model can make them quickly.

## What you need
- **An NVIDIA graphics card with its driver.** `nvidia-smi` should work in a terminal.
- **From your package manager:** `git`, `ffmpeg`, `fluidsynth`, and `curl`. On Debian or Ubuntu:

```bash
sudo apt install git ffmpeg fluidsynth curl
```

- **A folder path without spaces.** Put the kit somewhere like `~/ai-audio`, not `~/AI Audio`: one tool (Applio) refuses paths with spaces.
- **Disk space:** about the same as on Windows, 80 GB or more with everything.

## Using it
Run these from this folder (`other-systems/linux`):

```bash
chmod +x aia.sh
```

```bash
./aia.sh list
```

```bash
./aia.sh install recommended --dry-run
```

```bash
./aia.sh install recommended
```

```bash
./aia.sh start narrate my-document.pdf
```

```bash
./aia.sh stop
```

- `install` takes component keys (`narrate,transcribe`), `all`, or a preset name such as `recommended`.
- Add `--with-xl` for the big ACE-Step music model (needs a 12 GB card or more), `--skip-models` to leave the model downloads for later, `--repair` to redo a tool.
- `start` takes one of: `ace_xl`, `ace_fast`, `comfy`, `applio`, `abogen`, `transcribe`, `narrate`, `narrate_video`, `hum`, `sep_vocals`, `sep_stems`. With no files, Transcribe and Narrate watch their drop folders.
- Nothing is installed system-wide. `uv`, its Pythons and all caches go into the kit folder.

## What's the same as Windows, and what isn't
| | Windows | Linux |
|---|---|---|
| The component list, version pins, the kit's own scripts and guides | shared | shared |
| Installer | a window (`setup\install.ps1`) | `aia.sh install` in a terminal |
| Control panel | a window | `aia.sh list`, `start`, `stop` |
| git, ffmpeg, FluidSynth | private copies downloaded into the kit | from your package manager |
| Removing a component | the Components window | not written yet; delete the tool's folder under `tools/` |
| Fixing a moved folder | automatic | not written; rebuild the tool with `--repair` |

## For a language model fixing the first run
- **Read first:** the notes at the top of `aia.py`, then the long notes at the top of `setup/install.ps1` (the technical manual: every component, every known problem and its fix).
- **Most likely trouble spots, in order:**
  1. **Package lists.** They were frozen on Windows. `aia.py` installs PyTorch first with its dependencies (on Linux that brings the `nvidia-*` libraries), then everything else exactly as pinned with `--no-deps`. A package that exists only for Windows goes in `WINDOWS_ONLY`; one that Linux needs and Windows didn't gets installed by hand into that tool's `.venv`.
  2. **ComfyUI's voice add-on** runs its own `install.py`, which builds a few packages from source and may want compilers (`build-essential`).
  3. **Abogen** is a desktop (Qt) app and may want system libraries for Qt and audio.
  4. **Applio's** `core.py prerequisites` step downloads its own models and tools.
- **Keep one source of truth.** Fix `aia.py`; don't fork `setup/components.json`, the locks or `scripts/*.py`. If a kit script has a Windows-only line, make that line work on both systems.
- **When it works,** change the status line at the top of this file and of `aia.py`, and say what was tested.
