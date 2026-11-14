# Applio voice changer

**The job:** re-voice a recording as another voice while keeping the original timing, accent and delivery. Also: train a model of a voice, and change a voice live.

## Why this tool
**Applio** is the most actively kept app for RVC, the standard open method for voice conversion. It was chosen because it covers training, conversion and a real-time mode in one window, and because the large public collection of RVC character voices works in it.

RVC needs a trained model of the target voice. For converting with only a short clip and no training, see the voice engines in the ComfyUI component.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| Applio | https://github.com/IAHispano/Applio | commit `6d5d9511b7e7`, branch main | MIT, plus its own terms of use |
| Its base models | fetched by `core.py prerequisites` (about 2.1 GB) | whatever that step fetches | see Applio's documentation |

## How the kit uses it
- **Environment:** `tools\Applio\.venv`, Python 3.12, PyTorch 2.11.0 for CUDA 12.8.
- **Launcher:** `Applio (voice changer).bat` runs `app.py --open` on port 6969.
- **The drive-letter trick:** Applio refuses to start from a folder path containing a space. The launcher maps the Applio folder to a spare drive letter (B, R, S, T, U, V or W), runs it from there, and removes the letter afterwards. The control panel and "Stop everything" remove it too.
- **Folders:**
  - trained voice models: `tools\Applio\logs\<name>` (kept when the component is removed)
  - converted audio: `tools\Applio\assets\audios` (kept)
  - base models: `tools\Applio\rvc\models`
- **Memory:** about 6 GB of graphics memory.

## Quick test
Start it from the launcher. Its page should open in the browser with Inference and Train tabs.

## Known problems
- **A stuck drive letter** after a crash: `subst B: /d` removes it (use the letter that's stuck).
- **Training takes one to a few hours** for a good model: 10–30 minutes of clean speech, a couple of hundred rounds.
- **The real-time tab** needs a virtual audio cable driver to feed other programs such as chat or games. That driver is a system-wide install and isn't part of the kit.
- **`core.py` commands** (train, infer, prerequisites) work from the real path; only `app.py` checks for spaces.

## If it dies
A successor must convert a recording to a target voice keeping timing and pitch movement, and should read existing RVC `.pth` and `.index` models, since those are what people have.
- **Search for:** "RVC WebUI", "voice conversion open source", "singing voice conversion".
- **Seen in November 2026:** Seed-VC (no training needed, handles singing; archived), and the RVC node inside the ComfyUI voice add-on, which reads the same models.
- **Check by ear:** how close the voice is, whether the words stay clear, and whether sung notes hold.
