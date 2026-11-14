# ComfyUI voices

**The job:** clone a voice from a short clip, design a new voice from a description, convert voices without training, narrate subtitle files, and make sound effects. It's also the engine room for Narrate's clip voices.

## Why these tools
- **ComfyUI** is a general workbench for AI models, drawn as boxes joined by wires. It was chosen as the hub because new models tend to arrive there first, and because it can be driven from a script.
- **TTS Audio Suite** is an add-on that puts about twenty voice engines behind the same few boxes. It was chosen because switching engine means changing one box, not learning a new program.

This is a second, separate ComfyUI. It runs on port 8189 so it never clashes with one you already have on the usual port, 8188.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| ComfyUI | https://github.com/comfyanonymous/ComfyUI | commit `102350eb949b`, branch master | GPL-3.0 |
| TTS Audio Suite | https://github.com/diodiogod/TTS-Audio-Suite | commit `2245cd7e8588`, branch main | MIT |
| ChatterBox model | Hugging Face `ResembleAI/chatterbox` | revision `5bb1f6ee…` | MIT |
| VibeVoice 1.5B model | Hugging Face `microsoft/VibeVoice-1.5B` | revision `c00898d2…` | MIT, stated as research use |
| Other engines' models | downloaded on first use, into `tools\ComfyUI\models\TTS` | not pinned | each its own; several are research-only or non-commercial |

## How the kit uses it
- **Environment:** `tools\ComfyUI\.venv`, Python 3.12, PyTorch 2.14.1 for CUDA 13.0. It's made with pip available, because the add-on's own installer needs it.
- **Install steps:** clone both projects, build the environment from the lock, run the add-on's `install.py`, copy eight example workflows under plain names, copy the voices from `voices\reference` into `tools\ComfyUI\models\voices`, download ChatterBox and VibeVoice.
- **Launcher:** `ComfyUI (voices).bat` runs `main.py --listen 127.0.0.1 --port 8189 --enable-manager`, with `TORCHDYNAMO_DISABLE=1` set.
- **Driving it from a script:** POST a job to `/prompt`, then read `/history/<id>`. Fill every input of a box, optional ones included, with the defaults from `/object_info`. `scripts\narrate.py` and `scripts\comfy_run_workflow.py` both do this.
- **Voices:** a clip plus a `.txt` holding its exact words, in `tools\ComfyUI\models\voices`.
- **Folders kept when the component is removed:** `output`, `input`, `user` and `models\voices`.
- **Memory:** 8 GB runs the smaller engines. The larger ones need 12–16 GB.

## Engines tried on a 16 GB card (November 2026)
| Engine | Result |
|---|---|
| ChatterBox | Works. About 24 s for a 25-second passage. Also converts voices. |
| VibeVoice 1.5B | Works. About 36 s. Narrate's default for clip voices. |
| IndexTTS 2.5 | Works. About 34 s. Emotion amounts in square brackets. |
| Higgs Audio v3 | Works. About 48 s. Emotion and style tags. |
| Fish Audio S2 Pro | Works only with `quantization` set to `bnb_int8`, and takes about 5 minutes. |
| VibeVoice 7B | Fits only with `quantize_llm_4bit`, and then speaks nonsense. Not usable. |
| Qwen3-TTS VoiceDesign | Works. Designs a voice from a description. |
| MOSS-SoundEffect v2 | Works for sound effects, with the launcher's setting above. |

## Quick test
Start it from the launcher, open **Workflows** in the left bar, load "1 - Clone a voice (ChatterBox)" and run it.

## Known problems
- **Fish Audio S2 Pro** needs the `natsort` and `torchcodec` packages and ffmpeg as shared libraries (`tools\_bin\ffmpeg-shared`). Without them it fails quietly and saves a near-empty file. All three are in the kit's install.
- **"Cannot find a working triton installation":** PyTorch is trying to compile itself, which Windows can't do here. The launcher's `TORCHDYNAMO_DISABLE=1` prevents it.
- **A box rejecting a job with "missing required positional argument":** an optional input was left out. Fill them all.
- **Converting a voice garbles the words** if the source was pitch-shifted or stretched first. Convert the natural recording, then fit it.

## If it dies
- **If the add-on dies:** each engine is its own open project and most have their own ComfyUI boxes. The jobs to keep are: speak text in a given voice, design a voice from a description, convert a voice from a clip.
- **If ComfyUI itself is the problem:** each engine can be run from its own project's Python code, at the cost of one environment per engine.
- **Search for:** "ComfyUI TTS nodes", "open source voice cloning", and current listening leaderboards for speech.
- **Check by ear:** the same passage in the same voice through each engine, plus wrong words by transcribing the result back.
