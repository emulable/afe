# AI Audio on a Mac

**There is no Mac installer.** This is a guide to building the equivalent on a Mac, for you or for an AI assistant working on that Mac.

**How far to trust it:** it comes from a web survey on 14 November 2026 of each project's own pages and issue lists. **Nothing here was run on a Mac.** "Unverified" means no first-hand source was found.

## First, find out what the Mac is
- **Apple Silicon (M1 or later)** is what this guide assumes. On a Mac, graphics memory and ordinary memory are the same pool, so "how much RAM" is the question. The graphics side can use roughly 70–75% of it by default.
- **Intel Mac:** only the light tools are realistic (see the end).
- **macOS 14 or later** is assumed by several of these tools.

**What fits in how much memory** (an estimate from the survey, not official figures):

| Memory | Realistic |
|---|---|
| 8 GB | Kokoro narration, humming to MIDI, FluidSynth, small transcription models, stem separation |
| 16 GB | adds ACE-Step's smaller music model (tight), ChatterBox, RVC voice conversion, sound effects, Qwen3 voice design |
| 24–32 GB | adds ACE-Step XL turbo, Higgs Audio v3, VibeVoice, IndexTTS-2 |
| 64 GB | everything, with room for two models at once |

## The recommended Mac line-up
| Job | Use on a Mac | Confidence |
|---|---|---|
| Narration | Kokoro, through **Abogen** or through **mlx-audio** | works |
| Voice cloning | **mlx-audio** (ChatterBox, Qwen3-TTS; Higgs v3 on 24 GB+); second choice: ChatterBox inside ComfyUI's voice add-on | works with caveats |
| Voice conversion | **Applio**, a build from after 11 October 2026 | works with caveats |
| Music | **ACE-Step 1.5** with its own macOS start scripts, turbo models | works with caveats |
| Splitting songs | **audio-separator** | works |
| Humming to MIDI | **Basic Pitch** on Python 3.10, FluidSynth to hear it | works |
| Transcription with speakers | **whispermlx** (a Mac version of WhisperX); or the WhisperKit command-line tool | works with caveats |
| Sound effects | Stable Audio 3 Small-SFX, or a standalone Mac build of MOSS-SoundEffect v2 | unverified |
| Audio workstation | **REAPER** (it has a native Mac version) | works |

**mlx-audio** is the Mac-native package to prefer for voices. It has Mac builds of most of the voice engines this kit uses on Windows, including Kokoro, ChatterBox, VibeVoice, IndexTTS, Higgs Audio v3, Qwen3-TTS and Fish Audio S2 Pro.

## Tool by tool
**ACE-Step 1.5 (music): works with caveats.**
- Python 3.11–3.12. Get `uv`, clone the project, run `uv sync`, then start it with `./start_gradio_ui_macos.sh` (there is also `start_api_server_macos.sh`). A ready-made Apple Silicon download is linked from its `docs/en/INSTALL.md`.
- The Mac scripts use Apple's MLX for the planner and default to the smaller 2B turbo model with the small 0.6B planner.
- The XL model runs on a Mac; turbo sounded right, and a bug that garbled the other XL models was fixed in August 2026.
- No official memory figures. One M1 Pro user ran out of memory with the smaller model.
- Training your own style on a Mac: unverified.

**Transcription: don't use WhisperX as it is.**
- WhisperX on a Mac runs on the processor only, which is slow.
- Use **whispermlx**: the same idea rebuilt on MLX, with word timing and speaker detection. Speaker detection still needs a free Hugging Face token.
- The engine under WhisperX gained an experimental Mac graphics mode on 10 November 2026. Whether it works with Whisper is unverified.

**Kokoro (narration voices): works well.**
- Set `PYTORCH_ENABLE_MPS_FALLBACK=1`, and install `espeak-ng` with Homebrew.

**Abogen (audiobooks): works.** It has official Mac instructions: `brew install espeak-ng`, then install it with `uv tool install`. Its page gives conflicting Python versions (3.13 in one place, 3.10–3.12 in another).

**Applio (voice conversion and training): works with caveats.**
- There is a Mac app download, or install from source with its `run-install.sh`.
- Before 11 October 2026, training on a Mac silently ran on the processor. Use a newer build; its author measured about 10 times faster on the graphics side.
- Real-time voice changing on a Mac: unverified.

**ComfyUI and its voice add-on (TTS Audio Suite): works with caveats, engine by engine.**
- ComfyUI supports Apple Silicon. The add-on needs `brew install portaudio ffmpeg`. Its author can't test on a Mac, so Mac fixes arrive untested.
- **Offer the Mac's graphics side:** ChatterBox, VibeVoice, IndexTTS-2, RVC. Only ChatterBox has user reports confirming it.
- **Only offer NVIDIA or the processor:** Fish Audio S2 Pro, Higgs Audio v3, Qwen3-TTS, MOSS-SoundEffect. On the processor these are described as very slow. Use mlx-audio for these voices instead.
- The squeezed 4-bit and 8-bit modes need an NVIDIA card there.

**audio-separator (splitting songs): works well.** `pip install "audio-separator[cpu]"`, and `audio-separator --env_info` shows what acceleration it found.

**Basic Pitch (humming to notes): works.** On Apple Silicon it supports Python 3.10 only.

**FluidSynth: works.** `brew install fluid-synth`.

**Seed-VC: works with caveats.** It has a Mac requirements file, but the project was archived in November 2025.

**Stable Audio 3, YuE2, SheetSage2 in ComfyUI: unverified on a Mac.**

**REAPER and its AI bridges: works.** One bridge (total-reaper-mcp) was developed mainly on a Mac.

## Things that don't exist on a Mac
- NVIDIA-only speed-ups: `torch.compile`, flash-attn, vLLM. Leave them off.
- 64-bit floating point on the graphics side. Tools must use 32-bit.
- An x86 Python under Rosetta gets no current PyTorch. Use native arm64 Python.

## What carries over from this kit unchanged
- **The kit's own scripts** in `scripts\`: `narrate.py`, `transcribe.py`, `hum_to_track.py`, `subtitles.py`. They're plain Python. `narrate.py` and `hum_to_track.py` already cope with non-Windows systems.
- **The guides and the prompt library.**
- **The component list** (`setup\components.json`), as the map of what does what.
- **The rules:** everything in one folder, one environment per tool, nothing installed system-wide. `uv` works the same way on a Mac; point `UV_PYTHON_INSTALL_DIR` and `UV_CACHE_DIR` into the folder.

## What has to be rebuilt
- **The installer and control panel.** They're Windows-only. `other-systems\linux\aia.py` is the closest starting point: a terminal installer and launcher in plain Python. Its package steps assume NVIDIA and would need the Mac choices above.
- **The package lists** in `setup\locks`. They pin NVIDIA builds of PyTorch. On a Mac, let each tool resolve its own packages.

## For an AI assistant building this on a Mac
1. Ask which Mac it is and how much memory it has.
2. Ask what the person wants to do, and install only that (see "Helping a user change or tailor the installation" in `setup\install.ps1`).
3. Start with the tools marked "works": Kokoro, audio-separator, Basic Pitch and FluidSynth. Then add ACE-Step and a transcription tool.
4. Prefer mlx-audio for voices over forcing the Windows line-up.
5. Test each tool before adding the next, and write down what worked. This guide's "unverified" items are the ones to check first.

## Intel Macs
PyTorch stopped making Intel Mac builds after version 2.2, so most of this kit can't install current versions. Realistic: Kokoro and Abogen on the processor, Basic Pitch, FluidSynth, REAPER and whisper.cpp. Not practical: music generation, the large voice models, and training.

## Sources
- ACE-Step: https://github.com/ace-step/ACE-Step-1.5 (INSTALL.md, GPU_COMPATIBILITY.md, issues 1259 and 1336)
- Transcription: https://github.com/m-bain/whisperX · https://pypi.org/project/whispermlx/ · https://github.com/OpenNMT/CTranslate2/releases · https://github.com/argmaxinc/WhisperKit
- Kokoro and mlx-audio: https://github.com/hexgrad/kokoro · https://github.com/Blaizzy/mlx-audio
- Abogen: https://github.com/denizsafak/abogen
- Applio: https://github.com/IAHispano/Applio (pull request 1310) · https://docs.applio.org/getting-started/installation
- ComfyUI: https://docs.comfy.org/installation/manual_install
- TTS Audio Suite: https://github.com/diodiogod/TTS-Audio-Suite (issues 160, 245, 252, 312, 345)
- MOSS-SoundEffect for Mac: https://github.com/VladimirTalyzin/MOSS-SoundEffect_v2.0_MPS_ROCm
- audio-separator: https://github.com/nomadkaraoke/python-audio-separator
- Basic Pitch: https://github.com/spotify/basic-pitch
- FluidSynth: https://formulae.brew.sh/formula/fluid-synth
- uv: https://docs.astral.sh/uv/reference/storage/
- Seed-VC: https://github.com/Plachtaa/seed-vc
- REAPER bridges: https://github.com/TwelveTake-Studios/reaper-mcp · https://glama.ai/mcp/servers/shiehn/total-reaper-mcp
- PyTorch on Macs: https://docs.pytorch.org/docs/2.15/notes/mps.html
