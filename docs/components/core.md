# Core

**The job:** the folder layout, private Pythons, the installer, the control panel and "Stop everything". Every other component stands on it.

## Why it's built this way
- **uv** creates each tool's private Python environment and downloads the Pythons themselves. It was chosen because it's fast, needs no admin rights and can keep everything inside one folder.
- **Windows PowerShell 5.1 and Windows Forms** draw the installer and the control panel. Every Windows PC already has them, so nothing extra is installed.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| uv | https://github.com/astral-sh/uv | 0.12.5 | MIT or Apache-2.0 |
| Pythons | downloaded by uv | 3.10.21, 3.11.16, 3.12.14 | PSF |
| git (only if the PC has none) | Git for Windows, MinGit | 2.53.0.2 | GPL-2.0 |
| ffmpeg (only if the PC has none) | https://github.com/GyanD/codexffmpeg | 8.0.1 essentials | GPL |
| ffmpeg as shared libraries | same source | 8.0.1 full, shared | GPL |

## How the kit uses it
- **`scripts\env.bat` and `scripts\env.ps1`** are loaded first by every launcher and script. They point uv, Hugging Face and PyTorch at folders inside the kit, and add `tools\_bin` to PATH for that window only.
- **`setup\install.ps1`** is the installer and the Components window. Its opening notes are the technical manual.
- **`setup\components.json`** is the one list of components and control-panel rows.
- **`setup\locks\`** holds the exact package versions of every tool, written by `setup\freeze_locks.ps1`.
- **`scripts\control_panel.ps1`, `panel_core.ps1`, `ui_theme.ps1`** are the control panel, its logic and its look.
- **`setup\relocate.ps1`** repairs the tools after the folder is moved. It runs automatically.
- **`setup\make_kit.ps1`** builds the shareable zip and single setup file, and refuses if a file contains personal details.

## Quick test
```
setup\install.ps1 -List
```
It should print the graphics card it found and every component's status. The control panel should open from `AI Audio control panel.bat`.

## Known problems
- **PowerShell scripts must stay plain ASCII.** Windows PowerShell 5.1 misreads other characters in files without a byte-order mark.
- **Batch files need Windows line endings**, or their jumps break.
- **Long paths:** some packages have very deep folders. If an install fails with path errors, Windows long paths need switching on, which needs admin rights. The installer warns when they're off.

## If it dies
- **uv** could be replaced by Python's own `venv` plus `pip`, at the cost of speed and of the shared package cache. The portability trick (`uv venv --relocatable`) would need another answer.
- **The windows** could be redrawn in anything. The plan is a browser page served by ComfyUI. `other-systems\linux\aia.py` shows the same logic with no window at all.
