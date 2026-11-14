# AI Audio: notes for Claude

An offline AI audio suite for a Windows PC with an NVIDIA graphics card. Assume the user is a hobbyist, not a programmer, so explain things plainly.

## Start here: what to read for what
Read only what the task needs.

| The task | Read |
|---|---|
| Picking up where the last chat stopped | The "Where we left off" section at the top of `My PC notes.md`, if it exists |
| Anything on this particular PC | `My PC notes.md`, if it exists: hardware, other software to leave alone, tastes, local results. Never shared. |
| Deciding or designing something | `VISION.md`: what the project is for and how it decides things |
| Understanding, testing or replacing one tool | Its page in `docs\components\` |
| Installing, repairing, removing, or fixing a failure | The notes at the top of `setup\install.ps1` (the technical manual, with a long list of known problems and fixes) |
| Tailoring the kit to a different person | "Helping a user change or tailor the installation" in those same notes |
| Explaining how to use a tool | `README.md`, then `How to use each tool.md` |
| Writing prompts | `Tips and prompts.md`. Its examples share one person's taste; treat them as examples of method, not as rules. |
| What's planned next | `plans\`, if it exists. Never shared. |
| Linux or Mac | `other-systems\` |

## Rules
- **The GPU is usually shared with games and other apps.** Don't start GPU work without checking that the user is OK with it right now. That includes servers, model loading, generation, training and smoke tests. Installing, downloading and writing code are fine.
- **Quality is judged by the user's ear.** Set up side-by-side comparisons and report measurements; don't declare a winner from benchmarks.
- **Keep everything inside this folder.** No global installs, no PATH or registry edits, no system Python. Always load `scripts\env.ps1` (or `scripts\env.bat`) first: it points uv, Hugging Face and torch caches into the folder.
- **Each tool has its own `.venv` under `tools\`**, built with uv from `setup\locks\`. After changing any environment, run `setup\freeze_locks.ps1` so a fresh install still matches.
- **PowerShell scripts must be ASCII-only.** Windows PowerShell 5.1 reads BOM-less files as ANSI.
- **Don't touch any other ComfyUI on the PC** (ComfyUI's usual port is 8188). This setup's ComfyUI uses port 8189.
- **Stop tools with the control panel or `Stop everything.bat`.** They never kill browsers.
- **Keep the kit portable.** Never hard-code the kit's path; derive it from the script's own location (`$PSScriptRoot`, `%~dp0`, `__file__`).
  - Create new environments with `uv venv --relocatable`. `uv sync` ignores the relocatable setting, so create the `.venv` relocatable first, then sync.
  - `setup\relocate.ps1` fixes a moved kit. `setup\kit-location.txt` records where it was last set up.
- **Keep the kit free of personal details.** Everything except `My PC notes.md` and `plans\` is shared. Write "your PC" or "a 16 GB card", never this PC's specs, drives, other installs or the owner's habits; put those in `My PC notes.md`.
- **`setup\components.json` is the one list of components, control-panel rows and installer presets.** The Components window (`setup\install.ps1`) and the control panel (`scripts\panel_core.ps1`) both read it. Removing a component deletes its `remove` and `models` paths and never its `keep` paths (the user's own work). Never test removal on the real install: use a scratch copy and `-DryRun`.
- **Keep the documents in step.** When a tool, version or behaviour changes, update its page in `docs\components\`, the guide, and the installer's notes in the same piece of work.
- **The shareable kit is built by `setup\make_kit.ps1`** into `dist\`: a zip plus a single readable `AI Audio Setup.ps1`. Rebuild it after changing scripts, guides or locks. It refuses to build if a kit file contains this PC's user folder, the kit's own path, or a word listed in `setup\private-words.txt` (which isn't shared).

## Entry points
- **Control panel:** `AI Audio control panel.bat`, or the "AI Audio" shortcut on the desktop. It lists only installed tools.
- **Components window (add, repair, remove):** `Install or repair AI Audio.bat`, or the panel's Components link. From the command line it's `setup\install.ps1`, with `-List`, `-DryRun`, `-Components` (keys, `all`, or a preset such as `recommended`), `-Remove`, `-KeepModels`, `-Repair`, `-SkipModels`, `-GpuGB` and `-Relocate`.
- **Fix after moving:** `setup\relocate.ps1`. It runs automatically from `env.bat`, the panel and the installer.
- **Share:** `setup\make_kit.ps1` writes `dist\AI Audio kit.zip` and `dist\AI Audio Setup.ps1`. For a language model, the zip (separate files) is the form to read; the single script is far too large to read whole.
- **Other systems:** `other-systems\linux\aia.sh` (a terminal installer and launcher, translated from the Windows one and not yet run on Linux) and `other-systems\mac\` (a guide, no installer). They share `setup\components.json`, `setup\locks\` and `scripts\*.py` with Windows: fix those in one place.
