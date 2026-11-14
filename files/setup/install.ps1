<#
===============================================================================================
 AI AUDIO - INSTALL OR REPAIR
 An all-round, offline audio hub for a Windows PC with an NVIDIA graphics card.
===============================================================================================

 READ THIS FIRST (written for language models working on this project, and for curious humans)

 WHAT THIS PROJECT IS
   One folder (the "kit", any name, any drive) that holds a set of local AI audio tools, their
   private Python installs, their models and a control panel. Everything runs offline on the
   user's own PC once installed. It was built around these goals:
     - hum / sing / beatbox a part + say what it is ("this is the bass line") -> instrument track
     - sound like someone else while keeping their own delivery (RVC voice conversion)
     - clone a voice from a short recording and have it read text
     - restyle songs ("a reggae version of ...") and generate music from text prompts
     - drop in a document -> natural narration + subtitles (+ optional subtitled video)
     - transcribe audio/video, broken down by speaker
     - later: AI video / animation (not installed; ComfyUI is the intended hub for it)
   Assume the user is a hobbyist, not a programmer: explain things plainly. If the kit folder
   has "My PC notes.md", read it: it describes that particular PC and its owner (hardware,
   other software to leave alone, tastes). It is private and never packed into a shared kit.

 THE GPU RULE (important)
   The graphics card is usually shared with games and other apps. Never start GPU work (servers,
   model loading, generation, training, smoke tests) without checking that the user is OK with
   it right now. Installing, downloading and writing scripts are fine. Every tool frees the GPU
   when its window closes; "Stop everything.bat" and the control panel stop all of them.

 HOW TO USE THIS INSTALLER
   GUI (default):           double-click "Install or repair AI Audio.bat" in the kit folder
   Unattended:              install.ps1 -Components narrate,transcribe -Yes
   Everything:              install.ps1 -Components all -Yes [-WithXL] [-DesktopShortcut]
   Environments only:       add -SkipModels (no big model downloads; tools fetch them later)
   Status:                  install.ps1 -List
   Plan without doing it:   install.ps1 -Components all -DryRun
   Reset to the pinned state: add -Repair (re-checks out the pinned commits and makes each
                            Python environment match its lock file exactly)
   A preset by name:        install.ps1 -Components recommended -Yes     (presets: components.json)
   Graphics memory:         detected with nvidia-smi and rounded to 8 / 12 / 16 / 24 / 32 GB; 16 is
                            assumed when nothing is found. -GpuGB 8 (or 0 = no NVIDIA card) overrides
                            it, and the window's menu remembers the choice in setup\gpu-memory.txt
                            (never shared). Each component's "min_gb" in components.json decides
                            whether it starts ticked; the XL music model needs 12 GB.
   Remove:                  install.ps1 -Remove abogen,applio -Yes [-KeepModels]
                            (-DryRun lists exactly what would be deleted and kept, with sizes)
   The window ("AI Audio components") shows a tick for what is installed: tick or untick,
   then Apply changes adds and removes to match. The control panel's Components link opens it.
   Component keys: core, transcribe, narrate, abogen, acestep, hum, separate, applio, comfyui.
   "core" is always included. An installed component is skipped unless -Repair is given.
   The installer works in whatever folder the kit is in (it uses its own location).

 FOLDER LAYOUT AND CONVENTIONS
   launchers\          one .bat per tool (double-click or drag files onto them)
   scripts\            the project's own code: transcribe.py, narrate.py, hum_to_track.py,
                       subtitles.py, comfy_run_workflow.py, control_panel.ps1, panel_core.ps1,
                       ui_theme.ps1 (look of the panel + installer window),
                       env.ps1 / env.bat (MUST be loaded first by every launcher/script)
   setup\components.json  THE one list of components and control-panel rows. This installer
                       reads it for the window and for removal; scripts\panel_core.ps1 reads
                       it for the panel, which shows a tool only when the files under its
                       "needs" exist. To add a tool: add a component and a tool entry there,
                       an Install-<key> function and a Get-ComponentState case here, a
                       launcher .bat, and a line in Resolve-AIAToolKey (panel_core.ps1) so
                       its running programs are recognised.
   VISION.md           what the project is for and how it decides things (read before designing)
   LICENSE             MIT, for the kit's own scripts and guides (downloaded tools keep their own)
   .gitattributes, .gitignore   for keeping the kit in git: files are stored byte-for-byte (batch
                       files need CRLF), and tools, models, results and private notes stay out
   docs\components\    one page per component: purpose, source and pinned version, exactly how
                       the kit uses it, a quick test, and how to choose a successor. Update the
                       page whenever that component changes.
   other-systems\      linux\aia.sh + aia.py: a terminal installer and launcher for Linux,
                       translated from this file and the launchers but NEVER RUN on Linux yet;
                       mac\: what works on a Mac and how to build the equivalent there.
                       Both share components.json, the locks and scripts\*.py with Windows.
   setup\              this installer, freeze_locks.ps1, locks\ (frozen package lists +
                       manifest.json with pinned git commits and Python versions), overlays\
                       (config files copied into cloned tools)
   tools\<name>\       each tool with its own .venv (never a shared environment)
   tools\_bin\         portable uv / git / ffmpeg, only when the PC lacks them
   python\             uv-managed Pythons 3.10 / 3.11 / 3.12 (the system Python is NOT used)
   models\             shared model caches (HF_HOME=models\huggingface, TORCH_HOME=models\torch),
                       diarization ONNX models, separator models, SoundFont
   .cache\uv           uv package cache; same drive as tools\, so environments hard-link files
   transcribe\in|out, narrate\in|out, music\in|out|stems, voices\reference|out, samples\, logs\
   README.md (user guide), "How to use each tool.md" (beginner instructions per program),
   "Tips and prompts.md" (prompt notebook), CLAUDE.md (pointer for Claude sessions),
   "My PC notes.md" (optional, private: this PC's specifics; make_kit.ps1 never packs it)
   Rules: keep EVERYTHING inside the kit folder (no global installs, no PATH/registry edits; the
   only thing outside is an optional desktop shortcut). env.ps1 sets UV_PYTHON_INSTALL_BIN=0 and
   UV_PYTHON_INSTALL_REGISTRY=0 so uv does not add shims or py-launcher entries.
   PowerShell scripts must be ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
   Ports: ACE-Step 7860, Applio 6969, ComfyUI (voices) 8189. Many users also have another
   ComfyUI (default port 8188, e.g. from Stability Matrix) - never touch it.

 COMPONENTS (what each installs, where; pinned commits/versions live in setup\locks\manifest.json)
   core        folders, uv, Pythons (3.10.21, 3.11.16, 3.12.14), portable git/ffmpeg/uv if missing,
               optional desktop shortcut "AI Audio" -> control panel. The control panel
               (scripts\control_panel.ps1) and "Stop everything.bat" ship with the kit.
   transcribe  tools\whisperx\.venv (WhisperX + sherpa-onnx, torch cu129); models: Whisper large-v3
               (Systran/faster-whisper-large-v3), wav2vec2 alignment (torch hub), offline speaker
               detection ONNX (pyannote segmentation 3.0 + NeMo TitaNet) in models\diarization.
   narrate     tools\narrate\.venv (Kokoro 82M TTS, document readers, torch cu128, spaCy
               en_core_web_sm); model: hexgrad/Kokoro-82M with all 54 voices.
               Narrate also speaks in a VOICE CLIP: settings.json "voice" = NAME of
               voices\reference\NAME.wav (+ NAME.txt = exact words in it). Default is
               "wise_old_narrator", a voice DESIGNED (not cloned from anyone) with Qwen3-TTS
               VoiceDesign 1.7B from a text description (ComfyUI workflow 7). Clip voices are spoken
               by an engine inside ComfyUI (voices): "clone_engine" vibevoice (default, ~real time,
               slow storyteller pace), chatterbox (~real time) or qwen3 (~3x slower). narrate.py
               reuses a running ComfyUI on 8189 or starts one headless and kills it when done, so
               the clip voices need the comfyui component; Kokoro presets do not.
   abogen      tools\abogen\.venv (Abogen 1.3.1 audiobook app, CPU torch swapped for cu128).
               Uses the same Kokoro model as narrate.
   acestep     tools\ACE-Step-1.5 (git, pinned commit), env from ITS OWN uv.lock (uv sync --frozen,
               Python 3.11), .env from setup\overlays; models in tools\ACE-Step-1.5\checkpoints:
               main (2B turbo DiT, VAE, Qwen3 text encoder, 1.7B planner LM) + 2B base;
               optional XL turbo (4B, 18.6 GB). Not fetched by this installer, but one command
               adds any other model ("acestep-download --list" shows them), e.g. the slower
               50-step, highest-detail XL SFT (18.6 GB):
                 .venv\Scripts\acestep-download.exe --model acestep-v15-xl-sft --skip-main
                     --dir checkpoints      (run in tools\ACE-Step-1.5 after scripts\env.ps1)
               It then appears under "Main Model Path" in the app's settings.
   hum         tools\humtools\.venv (Basic Pitch on Python 3.10 so it uses ONNX, not TensorFlow),
               tools\fluidsynth (FluidSynth 2.6.2), models\soundfonts\GeneralUser-GS.sf2.
   separate    tools\separator\.venv (audio-separator, torch cu128); models in models\separator:
               htdemucs_ft (4 stems) and BS-RoFormer ep317 (vocals).
   applio      tools\Applio (git, pinned), .venv (torch cu128); "core.py prerequisites" downloads
               pretrained RVC models, embedders, pitch predictors and ffmpeg.exe (~2.1 GB).
   comfyui     tools\ComfyUI (git, pinned) + custom_nodes\TTS-Audio-Suite (git, pinned),
               .venv (torch cu130, ComfyUI-Manager as a pip package, venv made with --seed because
               the suite's install.py runs "python -m pip"); then the suite's install.py (adds
               fish-speech); example workflows copied into user\default\workflows with friendly
               names; voices\reference\* copied into models\voices; models: ChatterBox English
               and VibeVoice 1.5B (+ Qwen2.5 tokenizer) in models\TTS.

 PORTABLE BY DESIGN (moving or copying the kit)
   Every script, launcher and setting finds things relative to its own folder (env.ps1 /
   env.bat derive AIA_ROOT from their location; Python scripts use their __file__). The kit
   can live anywhere, including a USB drive or a path with spaces (Applio needs its subst trick;
   avoid non-English characters in the path). What remembers absolute paths is only the tools'
   Python plumbing:
     - python\cpython-3.xx-*  junctions pointing at the full Python folders
     - each .venv's python.exe launcher and pyvenv.cfg (uv embeds the base Python's path)
     - program launchers (*.exe in .venv\Scripts) of environments NOT created --relocatable
     - .pth files of editable installs (ACE-Step), TTS-Audio-Suite caches, its nested runtime
   setup\relocate.ps1 fixes all of these offline, from the package cache: it re-links the
   junctions, runs "uv venv --allow-existing --relocatable" on each environment (keeps the
   packages), rewrites the old path in small text files, and reinstalls (--no-deps, --offline)
   only the packages whose launchers still hold an absolute path (ACE-Step: uv sync --reinstall).
   It also updates the desktop shortcut and writes setup\kit-location.txt.
   It runs automatically: env.bat (so every launcher), the control panel and this installer
   compare kit-location.txt with the current folder. By hand: install.ps1 -Relocate, which also
   converts old-style environments so later moves take seconds. New environments are created
   with --relocatable ("uv sync" ignores UV_VENV_RELOCATABLE, so ACE-Step's .venv is created
   relocatable before syncing).
   Sharing: setup\make_kit.ps1 builds dist\AI Audio Setup.ps1 (one readable file with the whole
   kit inside) and dist\AI Audio kit.zip; neither contains tools, models or generated audio.

 HOW THE LOCKS WORK
   setup\freeze_locks.ps1 runs "uv pip freeze" on every working environment and writes
   setup\locks\<env>.txt plus manifest.json (Python version, PyTorch CUDA index, git commits).
   Lines that point at this PC's disk are dropped and recorded in manifest.json ("dropped"):
   fish-speech (re-created by the suite's install.py) and ACE-Step's own editable packages
   (re-created by uv sync). A fresh environment is made with "uv pip sync" (exact, no
   dependency resolution, so even environments with --no-deps packages reproduce). An existing
   environment is topped up with "uv pip install --no-deps -r" (keeps extra packages) unless
   -Repair, which uses "uv pip sync" (removes anything not in the lock). RE-RUN
   freeze_locks.ps1 AFTER CHANGING ANY ENVIRONMENT, or a fresh install will not match.

 WHAT TO DO IF THINGS GO WRONG (known issues and their fixes)
   General: read logs\install-*.log (this installer) and the tool's own log in logs\. Re-run
   the installer with Repair for the broken component. If one environment is badly broken,
   delete that tool's .venv folder and install the component again. "Out of memory" on the GPU
   almost always means another tool or a game is still running: use Stop everything.
   - Applio refuses to start from a path containing a space ("AI Audio"). Its launcher maps the
     Applio folder to a temporary drive letter (subst, first free of B R S T U V W) and runs from
     there; the control panel / Stop everything remove the letter. Manual fix: "subst B: /d".
     Applio's core.py command line (train/infer/prerequisites) works from the real path.
   - audio-separator[gpu] pulls an onnxruntime-gpu built for CUDA 13 that fails next to the
     CUDA 12.8 torch ("Failed to load cublas64_13.dll"). Use the plain onnxruntime ([cpu] extra);
     the Demucs/RoFormer models run on the GPU through torch anyway. A remaining warning
     "CUDAExecutionProvider not available" is harmless. The separator also needs "audioread".
     Its default model folder is C:\tmp, so launchers pass --model_file_dir models\separator.
   - humtools needs setuptools<80 (pretty_midi/resampy still import pkg_resources).
   - Abogen's package installs a CPU-only torch; the lock replaces it with torch 2.8.0+cu128.
     Abogen's "abogen-cli"/"abogen-web" commands start a Flask web server on 0.0.0.0:8808 that
     other devices can reach - use the desktop app (the launcher) instead.
   - spaCy's en_core_web_sm is needed by narrate and abogen (installed from its GitHub wheel).
   - WhisperX prints a torchcodec warning at import: harmless (audio is decoded by ffmpeg).
     Better speaker separation (pyannote) needs a free Hugging Face read token in
     models\huggingface\token and the model terms accepted; without it the offline sherpa-onnx
     engine is used (clustering threshold 0.7, tuned on test clips). The token is optional.
   - ACE-Step XL on a 16 GB card needs --offload_dit_to_cpu true (the XL launcher passes it) and
     still peaks at ~15.6 GB: close games and other GPU-hungry apps first. First XL start ~3.5 min.
     ACE-Step's REST API (/release_task) cannot do covers/repaint: use "cli.py -c file.toml" with
     task_type = "cover", src_audio, caption, audio_cover_strength (0.5 = keep chords + tempo).
     release_task returns only a task id; /query_result returns the file paths.
   - uv adds python shims to %USERPROFILE%\.local\bin and py-launcher registry keys unless
     UV_PYTHON_INSTALL_BIN=0 / UV_PYTHON_INSTALL_REGISTRY=0 (set in env.ps1/env.bat).
   - Windows PowerShell 5.1 turns anything a native program prints on stderr into an error
     record; with $ErrorActionPreference='Stop' that aborts the script. Run native tools with
     ErrorActionPreference 'Continue' and check $LASTEXITCODE (see Invoke-Native below).
   - Running a .bat that starts a long-lived program (e.g. the control panel) from a script that
     captures output hangs, because the child inherits the output handle: use Start-Process.
   - The drop-folder watchers (Transcribe, Narrate) run their AI in a worker subprocess that
     exits after 90 s idle; only a process exit returns every byte of GPU memory.
   - The control panel and Stop everything only stop programs from this folder plus known
     helpers (ffmpeg, conhost, git...). They never stop a web browser, even one a tool opened.
   - Long paths: some packages have deep paths. If installs fail with path errors, ask the user
     to enable Windows long paths (needs admin: registry LongPathsEnabled=1). This installer
     warns when it is off.
   - Hugging Face prints "unauthenticated requests" warnings: harmless.
   - Model downloads are pinned to exact revisions and refs\main is written, so the tools find
     the models offline.
   - WinForms windows made from PowerShell show their controls to UI Automation only as panes;
     to script a button, post BM_CLICK to its window handle.
   - Removing a component (-Remove, or unticking it in the window): deletes its "remove" folders
     and "models" from components.json, never its "keep" paths (trained Applio voices in
     tools\Applio\logs, ComfyUI's output/input/user/models\voices, ACE-Step's gradio_outputs) and
     never a model that a component which stays also lists (Kokoro: Narrate + Abogen). Only
     paths under tools\ and models\ are accepted. Junctions and links are removed as links,
     never followed (AIATree.Delete; cmd "rd /s /q \\?\..." finishes paths over 260 chars).
     Running tools of that component are stopped first. Environments hard-link their files from
     .cache\uv, so space only returns once "uv cache clean <packages no remaining lock lists>"
     has run; that step is skipped with -CacheDir (a borrowed cache is never cleaned). A package
     name that another tool still uses in a different version stays cached. Removing ComfyUI:
     narrate.py then falls back from clip voices to the Kokoro voice bm_george.
   - Fish Audio S2 Pro (ComfyUI voices) needs three things its own installer leaves out:
     the "natsort" package, "torchcodec" (torchaudio.load uses it), and ffmpeg as shared
     libraries: tools\_bin\ffmpeg-shared\bin, put at the END of PATH by env.ps1/env.bat.
     Without them it fails quietly and saves a near-empty file. At full size it does not fit
     a 16 GB card (it spills over and takes ~8 s per token): use quantization "bnb_int8" on the
     engine node. Even then a 25 s passage took about 5 minutes on a 16 GB card.
     VibeVoice 7B fits a 16 GB card with "quantize_llm_4bit" on.
   - Window look: scripts\ui_theme.ps1, used by the control panel and this installer's window.
     Themes "dark" (default), "light", "system" (follows Windows' AppsUseLightTheme, re-checked
     every 2 s by the panel); stored as "Theme" in scripts\control_panel.settings.json, set with
     the panel's Theme link or this installer's -Theme. WinForms has no dark mode of its own, so
     every control is coloured by hand (Set-AIARole marks dim/gray/status/danger/line labels),
     the title bar via DwmSetWindowAttribute 20 (19 on old Windows 10), scroll bars via
     SetWindowTheme "DarkMode_Explorer", tooltips owner-drawn, and the progress bars are plain
     panels (the Windows ProgressBar can't be recoloured). Message boxes and file dialogs are
     drawn by Windows and stay in its own style. A high-contrast Windows theme always wins.
     Sizes: the processes are DPI-aware (fonts in points follow display scaling) and fonts and
     Px() sizes are multiplied by Windows' Text size (HKCU\Software\Microsoft\Accessibility
     TextScaleFactor; AIA_TEXT_SCALE=1.5 overrides it for testing). -SnapshotPng (both windows)
     with -Theme draws the window, title bar included, to a PNG without saving anything.
   - Any other ComfyUI on the PC (e.g. Stability Matrix's, port 8188) is separate: never modify it.
   - ffmpeg must be on PATH (narrate, hum to track, WhisperX). env.ps1/env.bat add tools\_bin.
   - Logs: logs\install-*.log (installer), logs\*.log (earlier installs/tests). ComfyUI's own
     log is in tools\ComfyUI\user\comfyui.log; ACE-Step prints to its console window.
     Narrate's background ComfyUI logs to logs\narrate-comfyui.log.
   - Driving ComfyUI over its API (POST /prompt): fill a node's OPTIONAL inputs with their
     /object_info defaults too. Qwen3TTSEngineNode's validation otherwise fails with "missing 1
     required positional argument: 'runtime_mode'" (HTTP 400). narrate.py and
     comfy_run_workflow.py do this. The Qwen3-TTS models (VoiceDesign 1.7B, Base 1.7B, ~4 GB
     each) are NOT pre-downloaded by this installer; they download on first use.
   - NO PIANO BY DESIGN. Music defaults avoid it: hum_to_track.py maps a plain melody to a
     synth lead, chords to a pad, bass to a synth bass (piano only when typed by name); the
     prompt library uses dark analog synths + ancient instruments + low chant. Hammered strings
     (santur, dulcimer, cimbalom) sound piano-like and were the "piano" in early samples.
     scripts\piano_check.py (run with tools\whisperx\.venv) scores tracks with an AudioSet model
     (MIT/ast-finetuned-audioset, downloads on first use): piano >= 0.08 means piano or
     piano-like; clean tracks score ~0.01-0.03. In ACE-Step, the LM negative prompt
     "piano, grand piano, electric piano, Rhodes, keys, keyboard, organ, orchestra, strings,
     brass" (needs Think on) helps but does not guarantee it: generate several and check.

 FOR A LANGUAGE MODEL ABOUT TO CHANGE THINGS
   Read README.md (user guide, test results), "Tips and prompts.md" (prompt library),
   CLAUDE.md and, if present, "My PC notes.md". Keep the GPU rule and the user's tastes in
   mind. After changing an environment, run setup\freeze_locks.ps1. Keep shared files free of
   personal details (this PC's specs, drives, other installs): those go in "My PC notes.md".

 HELPING A USER CHANGE OR TAILOR THE INSTALLATION (for language models)
   This kit was shaped by its first user's goals and taste. Someone else may want something
   quite different, so ask before choosing for them. Ask a few questions at a time, in plain
   words, and skip whatever the user has already told you or "My PC notes.md" already says.

   Questions worth asking
     1. What do you want to make or do? (narrate documents or books; make music; restyle or
        cover songs; turn humming into instruments; change or clone a voice; clean up
        recordings; transcribe; sound effects...) Install only what serves that.
     2. How much do you know about audio? (new to it / hobbyist / musician, engineer or
        narrator) This decides how much to explain, which words to use and how many controls
        to show. An experienced ear wants side-by-side samples and real settings, not
        reassurance.
     3. Quick and simple, or elaborate and high fidelity? Quick: fast models, presets, one
        button, drop folders. High fidelity: the largest models that fit, voice cloning and
        design, several takes, building in stages, finishing in an audio editor.
     4. What is the PC? Graphics card memory (run "nvidia-smi"), free disk space, and whether
        the card is shared with games or other work (then: ask before every GPU job).
     5. Fully offline? And is anything going to be sold or published? Some models here are
        research-only or non-commercial; that is fine for private use only.
     6. What should it sound like? Genres, instruments to favour or avoid, the kind of narrator
        voice, languages spoken. Ask for examples of things they like.
     7. Whose voices? Their own recordings, designed voices, or other people's. Cloning real
        people is for private fun only; publishing it runs into right-of-publicity law.
     8. How do they like to work? Double-click launchers and drop folders, the control panel,
        ComfyUI, an audio editor, or mostly by asking an AI assistant to do it.
     9. Stable or newest? Pinned, tested versions (the default) or chasing new releases.
   If the user would rather not answer questions: ask only what they want to do, then pick
   the components yourself and say what you picked and why.

   Then
     - Propose a short plan first: which components, how much disk, what it will not do.
       One tool per job when there is a clear best, up to three when they suit clearly
       different uses. Remove what loses a comparison.
     - Let the user's ears decide between engines: make the same short sample with each
       candidate and let them pick. Do not declare a winner from benchmarks alone.
     - Use each kind of tool for what it does well: the user for performance, taste and the
       final call; a language model for theory, arrangement, prompts and driving tools;
       generative models for sound; ordinary audio tools (ffmpeg, an audio editor) for
       anything exact such as timing, edits, loudness and mixing.
     - Component keys by goal: narration -> narrate (+ comfyui for cloned or designed
       voices, abogen for whole books); music -> acestep (+ hum, separate); voice changing
       -> applio (+ comfyui); voice cloning or design -> comfyui; transcription ->
       transcribe; splitting songs -> separate. "core" always.
     - Sizes: on 8 GB cards prefer the small models and warn about the rest; 12-16 GB runs
       everything here with offloading; 24 GB+ can use the largest models unquantized.
       ACE-Step's own docs\en\GPU_COMPATIBILITY.md lists its tiers.

   OPTIONAL: AN AUDIO WORKSTATION WITH AI HOOKS (REAPER) - not installed by this kit yet
     Why: exact work (lining tracks up by bar, edits, effects, mixing, loudness, rendering,
     playing MIDI through virtual instruments) belongs in an audio workstation, driven by the
     user or by an AI assistant, not improvised with a language model. REAPER was chosen over
     Audacity because Audacity 4.0 (Sept 2026) removed the scripting pipe; REAPER has deep
     scripting (ReaScript: Lua built in, Python optional) and can be fully portable.
     It is commercial: a free evaluation with every feature, then a personal licence
     (about 60 USD) bought by the user from its makers. Never bundle or redistribute it;
     download it from https://www.reaper.fm/download.php only when the user asks.
     How to integrate it (check each step against current versions before relying on it):
       1. Portable install inside the kit, e.g. tools\REAPER: the installer has a
          "Portable install" option (silent: reaper-install.exe /S /PORTABLE /D=<folder>).
          A portable copy keeps its settings and scripts in its own folder, so it moves
          with the kit. Add a component + tool entry in setup\components.json (unticked by
          default, with the licence note), an Install-reaper function, a launcher .bat and
          a Resolve-AIAToolKey line, as for any other tool.
       2. Driving it: (a) from scripts - "reaper.exe -renderproject <file.rpp>" renders
          without clicking, and a ReaScript given on the command line runs at start;
          (b) from an AI assistant - an MCP server with a small bridge script loaded in
          REAPER. Candidates seen in Nov 2026: TwelveTake-Studios/reaper-mcp (uvx
          twelvetake-reaper-mcp --install-bridge), reaper-mcp-server on PyPI, xdarkzx/
          reaper-mcp. Pick one, pin its version, keep its files inside the kit, and
          register it for the assistant in the kit folder's own .mcp.json (project scope),
          never in the user's global settings.
       3. Hooks the rest of the kit should offer when tools\REAPER exists: a "Send to
          REAPER" action on every result (new track, item at the cursor or at a given
          bar), stems and staged takes as separate aligned tracks, MIDI from Hum to track
          on an instrument track. Hide these when REAPER is not installed.
       4. "Regenerate track 3, smoother" = re-run the generator for that stem or section
          (ACE-Step repaint / lego, or a new take), then replace the item in the project
          at the same position; do not try to "edit" audio with a language model.
     Plain fixed jobs (trim, fade, loudness, convert, time-stretch) need no workstation:
     ffmpeg from tools\_bin does them.

   Where this kit's taste lives (change these for a different user; the rest is structure)
     - "Tips and prompts.md": the prompt library (dark synths, ancient instruments, chant).
     - scripts\hum_to_track.py: INSTRUMENTS and DEFAULT_INSTRUMENT (no piano by default).
     - scripts\narrate.py DEFAULTS and voices\reference\: the default narrator voice.
     - scripts\ui_theme.ps1 and the panel's Theme link: dark by default.
   Write what you learn about the user and their PC into "My PC notes.md" (never shared),
   not into the shared guides. After changes: setup\freeze_locks.ps1 if an environment
   changed, then setup\make_kit.ps1.
===============================================================================================
#>
param(
    [string[]]$Components,          # keys (or "all"); omit to open the window
    [switch]$Yes,                   # don't ask for confirmation
    [switch]$Repair,                # re-check out pinned commits, make environments match locks exactly
    [string[]]$Remove,              # keys to REMOVE (frees the disk space; the user's own work is kept)
    [switch]$KeepModels,            # with -Remove: keep the downloaded AI models
    [switch]$SkipModels,            # environments only, no big model downloads
    [switch]$WithXL,                # also download the ACE-Step XL model (~19 GB)
    [switch]$DesktopShortcut,       # create the "AI Audio" desktop shortcut
    [switch]$List,                  # print component status and exit
    [switch]$DryRun,                # print what would be done and exit
    [switch]$NoGui,                 # command-line mode even without -Components
    [string]$Select,                # window: tick only these components at start (e.g. "narrate,hum")
    [switch]$Relocate,              # fix the tools after the folder was moved (and make old ones movable)
    [string]$SnapshotPng,           # testing aid: draw the window to this PNG and exit
    [string]$CacheDir,              # testing aid: use another uv package cache (e.g. an existing kit's)
    [ValidateSet('', 'dark', 'light', 'system')]
    [string]$Theme = '',            # window look; default: the control panel's choice, else dark
    [ValidateSet(-1, 0, 8, 12, 16, 24, 32)]
    [int]$GpuGB = -1                # plan for this much graphics memory (0 = no NVIDIA card); default: detect, else 16
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'      # Invoke-WebRequest is very slow with progress in PS 5.1
$SetupDir = $PSScriptRoot
$Root = Split-Path -Parent $SetupDir
$LockDir = Join-Path $SetupDir 'locks'
. (Join-Path $Root 'scripts\env.ps1')
if ($CacheDir) { $env:UV_CACHE_DIR = $CacheDir }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Manifest = Get-Content (Join-Path $LockDir 'manifest.json') -Raw | ConvertFrom-Json

# ---- downloads pinned by this installer (environments and git commits come from manifest.json) ----
$Urls = @{
    uv        = 'https://github.com/astral-sh/uv/releases/download/0.12.5/uv-x86_64-pc-windows-msvc.zip'
    git       = 'https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.2/MinGit-2.53.0.2-64-bit.zip'
    ffmpeg    = 'https://github.com/GyanD/codexffmpeg/releases/download/8.0.1/ffmpeg-8.0.1-essentials_build.zip'
    ffmpegShared = 'https://github.com/GyanD/codexffmpeg/releases/download/8.0.1/ffmpeg-8.0.1-full_build-shared.zip'
    fluid     = 'https://github.com/FluidSynth/fluidsynth/releases/download/v2.6.2/fluidsynth-v2.6.2-win10-x64-cpp11.zip'
    sf2       = 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/684543d5e5efaef08d02be50dcda8d552478fa60/GeneralUser-GS.sf2'
    sf2readme = 'https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/684543d5e5efaef08d02be50dcda8d552478fa60/README.md'
    diarSeg   = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2'
    diarEmb   = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/nemo_en_titanet_large.onnx'
    wav2vec2  = 'https://download.pytorch.org/torchaudio/models/wav2vec2_fairseq_base_ls960_asr_ls960.pth'
}
$ModelPins = @{
    kokoro     = 'f3ff3571791e39611d31c381e3a41a3af07b4987'   # hexgrad/Kokoro-82M
    whisper    = 'edaa852ec7e145841d8ffdb056a99866b5f0a478'   # Systran/faster-whisper-large-v3
    chatterbox = '5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18'   # ResembleAI/chatterbox
    vibevoice  = 'c00898d257e6b46004e3e2866a47534085fb685a'   # microsoft/VibeVoice-1.5B
    qwen       = '8faed761d45a263340a0528343f099c05c9a4323'   # Qwen/Qwen2.5-1.5B (tokenizer only)
}

# ---- the component list: setup\components.json, shared with the control panel ----
# Each entry: Key, Name, Size, Desc (shown in the window) and what removing it deletes.
$Registry = Get-Content -LiteralPath (Join-Path $SetupDir 'components.json') -Raw | ConvertFrom-Json
$Catalog = @($Registry.components)
$AllKeys = @($Catalog | ForEach-Object { $_.Key })

# ---- small helpers ----------------------------------------------------------------------
function AiaPath([string]$Rel) { Join-Path $Root $Rel }
$script:LogFile = $null
function Write-Log([string]$Text) {
    [Console]::Out.WriteLine($Text)
    [Console]::Out.Flush()
    if ($script:LogFile) { try { Add-Content -LiteralPath $script:LogFile -Value $Text -Encoding UTF8 } catch {} }
}
function Test-AllPaths([string[]]$Rel) {
    foreach ($p in $Rel) { if (-not (Test-Path -LiteralPath (AiaPath $p))) { return $false } }
    return $true
}
function Test-AnyPaths([string[]]$Rel) {
    foreach ($p in $Rel) { if (Test-Path -LiteralPath (AiaPath $p)) { return $true } }
    return $false
}
function Test-HasFiles([string]$Rel, [string]$Filter = '*', [int]$Min = 1) {
    $p = AiaPath $Rel
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    return (@(Get-ChildItem -LiteralPath $p -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue).Count -ge $Min)
}
function Test-HfModel([string]$Repo, [string]$File) {
    $dir = AiaPath ('models\huggingface\hub\models--' + $Repo.Replace('/', '--') + '\snapshots')
    if (-not (Test-Path -LiteralPath $dir)) { return $false }
    return [bool](Get-ChildItem -LiteralPath $dir -Recurse -File -Filter $File -ErrorAction SilentlyContinue | Select-Object -First 1)
}
function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Invoke-Native {
    # Runs a program, streams its output to the log, and throws on a non-zero exit code.
    # (Windows PowerShell 5.1 would otherwise treat stderr progress lines as errors.)
    param([string]$Exe, [string[]]$ArgList = @(), [string]$WorkDir)
    Write-Log ('  > ' + (Split-Path $Exe -Leaf) + ' ' + ($ArgList -join ' '))
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($WorkDir) { Push-Location -LiteralPath $WorkDir }
    try {
        & $Exe @ArgList 2>&1 | ForEach-Object { $t = "$_"; if ($t.Trim()) { Write-Log ('    ' + $t) } }
        $code = $LASTEXITCODE
    } finally {
        if ($WorkDir) { Pop-Location }
        $ErrorActionPreference = $old
    }
    if ($code -ne 0) { throw "$(Split-Path $Exe -Leaf) failed with exit code $code" }
}

function Get-File([string]$Url, [string]$Dest) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
    $tmp = "$Dest.partial"
    for ($try = 1; $try -le 3; $try++) {
        try {
            Write-Log "  downloading $Url"
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $tmp
            Move-Item -LiteralPath $tmp -Destination $Dest -Force
            return
        } catch {
            Write-Log "    attempt $try failed: $($_.Exception.Message)"
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
            if ($try -eq 3) { throw }
            Start-Sleep -Seconds (5 * $try)
        }
    }
}

function Expand-Zip([string]$Zip, [string]$Dest) {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    $tar = Join-Path $env:WINDIR 'System32\tar.exe'
    if (Test-Path $tar) { Invoke-Native $tar @('-xf', $Zip, '-C', $Dest) }
    else { Expand-Archive -LiteralPath $Zip -DestinationPath $Dest -Force }
}

function Invoke-PythonCode([string]$Py, [string]$Code, [string]$WorkDir) {
    $tmp = AiaPath ('logs\_installer_' + [guid]::NewGuid().ToString('N') + '.py')
    Set-Content -LiteralPath $tmp -Value $Code -Encoding ascii
    try { Invoke-Native $Py @($tmp) $WorkDir } finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

function Venv-Py([string]$ToolDir) { AiaPath "$ToolDir\.venv\Scripts\python.exe" }

# ---- graphics memory ---------------------------------------------------------------------
# The kit plans around a few card sizes. What is detected is the default; the user's own choice
# (Components window, or -GpuGB) is remembered in setup\gpu-memory.txt, which is never shared.
# If nothing can be detected the kit assumes 16 GB.
$GpuSizes = @(0, 8, 12, 16, 24, 32)
$GpuFile = Join-Path $SetupDir 'gpu-memory.txt'
function Get-GpuDetected {
    # name and memory (GB) of the first NVIDIA card, or $null
    try {
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $line = @(& nvidia-smi.exe --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null)[0]
        $ErrorActionPreference = $old
        if ($line -match '^(.+),\s*(\d+)\s*$') { return [pscustomobject]@{ Name = $Matches[1].Trim(); GB = [double]$Matches[2] / 1024 } }
    } catch {}
    return $null
}
function ConvertTo-GpuTier([double]$GB) {
    if ($GB -lt 10) { return 8 } elseif ($GB -lt 14) { return 12 } elseif ($GB -lt 20) { return 16 } elseif ($GB -lt 28) { return 24 }
    return 32
}
$GpuDetected = Get-GpuDetected
function Get-GpuTier {
    if ($GpuGB -ge 0) { return $GpuGB }
    try { if (Test-Path $GpuFile) { $v = [int]([IO.File]::ReadAllText($GpuFile).Trim()); if ($GpuSizes -contains $v) { return $v } } } catch {}
    if ($GpuDetected) { return (ConvertTo-GpuTier $GpuDetected.GB) }
    return 16
}
function Get-GpuLabel([int]$Tier) { if ($Tier -eq 0) { 'No NVIDIA card' } elseif ($Tier -ge 32) { '32 GB or more' } else { "$Tier GB" } }
$XLMinGB = 12      # the ACE-Step XL models need a 12 GB card or more

# ---- component status ------------------------------------------------------------------
function Get-ComponentState([string]$Key) {
    $envOk = $false; $models = $false; $any = $false
    switch ($Key) {
        'core' {
            $pys = @($Manifest.pythons | Where-Object { -not (Test-Path (AiaPath "python\cpython-$_-windows-x86_64-none\python.exe")) })
            $envOk = ($pys.Count -eq 0) -and (Test-Command 'uv') -and (Test-Command 'git') -and (Test-Command 'ffmpeg')
            $models = $true
            $any = (@(Get-ChildItem (AiaPath 'python') -Directory -Filter 'cpython-*' -ErrorAction SilentlyContinue).Count -gt 0)
        }
        'transcribe' {
            $envOk = Test-AllPaths @('tools\whisperx\.venv\Scripts\python.exe', 'tools\whisperx\.venv\Lib\site-packages\whisperx', 'tools\whisperx\.venv\Lib\site-packages\sherpa_onnx')
            $models = (Test-AllPaths @('models\diarization\segmentation\model.onnx', 'models\diarization\embedding\nemo_en_titanet_large.onnx', 'models\torch\hub\checkpoints\wav2vec2_fairseq_base_ls960_asr_ls960.pth')) -and (Test-HfModel 'Systran/faster-whisper-large-v3' 'model.bin')
            $any = Test-AnyPaths @('tools\whisperx', 'models\diarization\segmentation\model.onnx')
        }
        'narrate' {
            $envOk = Test-AllPaths @('tools\narrate\.venv\Scripts\python.exe', 'tools\narrate\.venv\Lib\site-packages\kokoro', 'tools\narrate\.venv\Lib\site-packages\en_core_web_sm')
            $models = Test-HfModel 'hexgrad/Kokoro-82M' 'kokoro-v1_0.pth'
            $any = Test-AnyPaths @('tools\narrate')
        }
        'abogen' {
            $envOk = Test-AllPaths @('tools\abogen\.venv\Scripts\abogen.exe', 'tools\abogen\.venv\Lib\site-packages\en_core_web_sm')
            $models = Test-HfModel 'hexgrad/Kokoro-82M' 'kokoro-v1_0.pth'
            $any = Test-AnyPaths @('tools\abogen')
        }
        'acestep' {
            $envOk = Test-AllPaths @('tools\ACE-Step-1.5\.git', 'tools\ACE-Step-1.5\.venv\Scripts\acestep.exe', 'tools\ACE-Step-1.5\.env')
            $models = (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-turbo' '*.safetensors') -and
                      (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-base' '*.safetensors') -and
                      (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-1.7B' '*.safetensors') -and
                      (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\vae' '*.safetensors') -and
                      (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\Qwen3-Embedding-0.6B' '*.safetensors')
            $any = Test-AnyPaths @('tools\ACE-Step-1.5')
        }
        'hum' {
            $envOk = (Test-AllPaths @('tools\humtools\.venv\Scripts\python.exe', 'tools\humtools\.venv\Lib\site-packages\basic_pitch')) -and (Test-HasFiles 'tools\fluidsynth' 'fluidsynth.exe')
            $models = Test-AllPaths @('models\soundfonts\GeneralUser-GS.sf2')
            $any = Test-AnyPaths @('tools\humtools', 'tools\fluidsynth')
        }
        'separate' {
            $envOk = Test-AllPaths @('tools\separator\.venv\Scripts\audio-separator.exe', 'tools\separator\.venv\Lib\site-packages\audioread')
            $models = (Test-AllPaths @('models\separator\htdemucs_ft.yaml', 'models\separator\model_bs_roformer_ep_317_sdr_12.9755.ckpt')) -and (Test-HasFiles 'models\separator' '*.th' 4)
            $any = Test-AnyPaths @('tools\separator')
        }
        'applio' {
            $envOk = Test-AllPaths @('tools\Applio\.git', 'tools\Applio\core.py', 'tools\Applio\.venv\Scripts\python.exe', 'tools\Applio\.venv\Lib\site-packages\torch')
            $models = (Test-AllPaths @('tools\Applio\rvc\models\predictors\rmvpe.pt', 'tools\Applio\rvc\models\pretraineds\hifi-gan\f0G40k.pth')) -and (Test-HasFiles 'tools\Applio\rvc\models\embedders\contentvec')
            $any = Test-AnyPaths @('tools\Applio')
        }
        'comfyui' {
            $envOk = Test-AllPaths @('tools\ComfyUI\.git', 'tools\ComfyUI\.venv\Scripts\python.exe', 'tools\ComfyUI\custom_nodes\TTS-Audio-Suite\.git',
                                     'tools\ComfyUI\.venv\Lib\site-packages\fish_speech', 'tools\ComfyUI\user\default\workflows\1 - Clone a voice (ChatterBox).json')
            $models = Test-AllPaths @('tools\ComfyUI\models\TTS\chatterbox\English\s3gen.safetensors', 'tools\ComfyUI\models\TTS\chatterbox\English\t3_cfg.pt',
                                      'tools\ComfyUI\models\TTS\vibevoice\vibevoice-1.5B\model-00003-of-00003.safetensors')
            $any = Test-AnyPaths @('tools\ComfyUI')
        }
    }
    if ($any -and -not $envOk) {
        # A removed tool can leave the user's own work behind (trained voices, results...).
        # That alone does not make it "partly installed".
        $c = Get-Comp $Key
        $keep = @($c.keep | Where-Object { $_ } | ForEach-Object { Resolve-InKit $_ })
        if ($keep.Count) {
            $more = $false
            foreach ($r in @($c.remove)) { if ($r -and (Test-KitHasMore (Resolve-InKit $r) $keep)) { $more = $true } }
            $any = $more
        }
    }
    $xl = Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-xl-turbo' '*.safetensors' 4
    $status = 'Not installed'
    if ($envOk -and $models) { $status = 'Installed' } elseif ($envOk -or $any) { $status = 'Partly installed' }
    if ($status -eq 'Installed' -and $Key -eq 'acestep' -and $xl) { $status = 'Installed (with XL)' }
    return [pscustomobject]@{ Env = [bool]$envOk; Models = [bool]$models; Any = [bool]$any; XL = $xl; Status = $status }
}

function Test-ComponentDone([string]$Key) {
    $s = Get-ComponentState $Key
    $done = $s.Env -and ($s.Models -or $SkipModels)
    if ($Key -eq 'acestep' -and $WithXL -and -not $SkipModels -and -not $s.XL) { $done = $false }
    if ($Key -eq 'core' -and $DesktopShortcut -and -not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'AI Audio.lnk'))) { $done = $false }
    return $done
}

# ---- building blocks -------------------------------------------------------------------
function Install-Prereqs {
    $bin = AiaPath 'tools\_bin'
    $dl = AiaPath 'tools\_bin\_download'
    if (-not (Test-Command 'uv')) {
        Write-Log 'uv not found: downloading a portable copy into tools\_bin'
        Get-File $Urls.uv "$dl\uv.zip"
        Expand-Zip "$dl\uv.zip" "$dl\uv"
        Get-ChildItem "$dl\uv" -Recurse -File -Include 'uv.exe', 'uvx.exe', 'uvw.exe' | ForEach-Object { Copy-Item $_.FullName $bin -Force }
    }
    if (-not (Test-Command 'git')) {
        Write-Log 'git not found: downloading portable MinGit into tools\_bin\git'
        Get-File $Urls.git "$dl\mingit.zip"
        Expand-Zip "$dl\mingit.zip" (Join-Path $bin 'git')
    }
    if (-not (Test-Command 'ffmpeg')) {
        Write-Log 'ffmpeg not found: downloading a portable copy into tools\_bin\ffmpeg'
        Get-File $Urls.ffmpeg "$dl\ffmpeg.zip"
        Expand-Zip "$dl\ffmpeg.zip" "$dl\ffmpeg"
        $src = Get-ChildItem "$dl\ffmpeg" -Recurse -Directory -Filter 'bin' | Select-Object -First 1
        New-Item -ItemType Directory -Force -Path (Join-Path $bin 'ffmpeg') | Out-Null
        Copy-Item $src.FullName (Join-Path $bin 'ffmpeg') -Recurse -Force
    }
    if (Test-Path $dl) { Remove-Item $dl -Recurse -Force -ErrorAction SilentlyContinue }
    . (Join-Path $Root 'scripts\env.ps1')          # picks up tools\_bin on PATH
    if ($CacheDir) { $env:UV_CACHE_DIR = $CacheDir }
    foreach ($c in 'uv', 'git', 'ffmpeg') { if (-not (Test-Command $c)) { throw "$c is still not available after the download" } }
    if (-not (Test-Command 'nvidia-smi')) {
        Write-Log 'WARNING: nvidia-smi was not found. These tools need an NVIDIA graphics card and driver to run at a usable speed.'
    }
    try {
        $lp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled
        if ($lp -ne 1) { Write-Log 'WARNING: Windows long paths are off. If an install fails with a path error, turn them on (needs admin): Settings > System > For developers > "Enable long paths".' }
    } catch {}
}

function Install-Pythons {
    $missing = @($Manifest.pythons | Where-Object { $Repair -or -not (Test-Path (AiaPath "python\cpython-$_-windows-x86_64-none\python.exe")) })
    if ($missing.Count) { Invoke-Native 'uv' (@('python', 'install') + $missing) }
    else { Write-Log '  Pythons already installed' }
}

function Install-Folders {
    foreach ($d in 'tools', 'python', 'logs', 'models\huggingface', 'models\torch', 'models\separator', 'models\diarization\segmentation',
                   'models\diarization\embedding', 'models\soundfonts', 'transcribe\in', 'transcribe\out', 'narrate\in', 'narrate\out',
                   'music\in', 'music\out', 'music\stems', 'voices\reference', 'voices\out', 'samples') {
        New-Item -ItemType Directory -Force -Path (AiaPath $d) | Out-Null
    }
}

function Install-Shortcut {
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AI Audio.lnk'
    if ((Test-Path $lnk) -and -not $Repair) { Write-Log '  desktop shortcut already exists'; return }
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (AiaPath 'scripts\control_panel.ps1') + '"'
    $s.WorkingDirectory = $Root
    $s.WindowStyle = 7
    $s.IconLocation = "$env:WINDIR\System32\SndVol.exe,0"
    $s.Description = 'AI Audio control panel: start, watch and stop the AI audio tools'
    $s.Save()
    Write-Log "  created $lnk"
}

function Install-Repo([string]$Name) {
    # Clone (or bring back) a tool repository at its pinned commit.
    $r = $Manifest.repos.$Name
    $dir = AiaPath $r.dir
    if (-not (Test-Path (Join-Path $dir '.git'))) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Invoke-Native 'git' @('-C', $dir, 'init', '--quiet')
        Invoke-Native 'git' @('-C', $dir, 'remote', 'add', 'origin', $r.url)
        $needCheckout = $true
    } else {
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $head = (& git -C $dir rev-parse --verify --quiet HEAD 2>$null)
        $ErrorActionPreference = $old
        $needCheckout = ($head -ne $r.commit)
        if (-not $head) { Write-Log "  $Name clone was never finished; completing it" }
        elseif ($needCheckout -and -not $Repair) {
            Write-Log "  $Name is at $head (pinned: $($r.commit)); leaving it as it is. Use Repair to go back to the pinned version."
            return
        }
    }
    if ($needCheckout -or $Repair) {
        Invoke-Native 'git' @('-C', $dir, 'fetch', '--filter=blob:none', '--quiet', 'origin')
        if ($r.branch) {
            Invoke-Native 'git' @('-C', $dir, '-c', 'advice.detachedHead=false', 'checkout', '--force', '-B', $r.branch, $r.commit)
            $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            & git -C $dir branch --set-upstream-to "origin/$($r.branch)" 2>$null | Out-Null
            $ErrorActionPreference = $old
        } else {
            Invoke-Native 'git' @('-C', $dir, '-c', 'advice.detachedHead=false', 'checkout', '--force', $r.commit)
        }
    } else { Write-Log "  $Name already at the pinned commit" }
}

function Install-LockedEnv([string]$Name) {
    # Create / align a tool's private Python environment from setup\locks\<name>.txt
    $e = $Manifest.envs.$Name
    $venv = AiaPath "$($e.dir)\.venv"
    $py = Join-Path $venv 'Scripts\python.exe'
    $lock = Join-Path $LockDir $e.lock
    $fresh = -not (Test-Path $py)
    if ($fresh) {
        # --relocatable: launchers use relative paths, so the whole kit can be moved later
        $a = @('venv', $venv, '--python', $e.python, '--clear', '--relocatable')
        if ($e.seed) { $a += '--seed' }
        Invoke-Native 'uv' $a
    }
    $common = @('--python', $py, '--index-strategy', 'unsafe-best-match')
    foreach ($ix in @($e.indexes)) { if ($ix) { $common += @('--extra-index-url', $ix) } }
    if ($fresh -or $Repair) { Invoke-Native 'uv' (@('pip', 'sync', $lock) + $common) }
    else { Invoke-Native 'uv' (@('pip', 'install', '--no-deps', '-r', $lock) + $common) }
}

function Install-Kokoro([string]$Py) {
    if ((Test-HfModel 'hexgrad/Kokoro-82M' 'kokoro-v1_0.pth') -and -not $Repair) { Write-Log '  Kokoro voices already downloaded'; return }
    $code = @"
import os
from huggingface_hub import snapshot_download
rev = '$($ModelPins.kokoro)'
path = snapshot_download('hexgrad/Kokoro-82M', revision=rev, allow_patterns=['config.json', 'kokoro-v1_0.pth', 'voices/*.pt'])
refs = os.path.join(os.environ['HF_HOME'], 'hub', 'models--hexgrad--Kokoro-82M', 'refs')
os.makedirs(refs, exist_ok=True)
open(os.path.join(refs, 'main'), 'w').write(rev)
print('Kokoro model and voices in', path)
"@
    Invoke-PythonCode $Py $code
}

# ---- components ----------------------------------------------------------------------
function Install-Core {
    Install-Folders
    Install-Prereqs
    Install-Pythons
    if ($DesktopShortcut) { Install-Shortcut }
}

function Install-Transcribe {
    Install-LockedEnv 'whisperx'
    if ($SkipModels) { return }
    $seg = AiaPath 'models\diarization\segmentation\model.onnx'
    if (-not (Test-Path $seg) -or $Repair) {
        $dl = AiaPath 'models\diarization\_download'
        Get-File $Urls.diarSeg "$dl\seg.tar.bz2"
        Invoke-Native (Join-Path $env:WINDIR 'System32\tar.exe') @('-xjf', "$dl\seg.tar.bz2", '-C', $dl,
            'sherpa-onnx-pyannote-segmentation-3-0/model.onnx', 'sherpa-onnx-pyannote-segmentation-3-0/LICENSE')
        Move-Item "$dl\sherpa-onnx-pyannote-segmentation-3-0\model.onnx" $seg -Force
        Move-Item "$dl\sherpa-onnx-pyannote-segmentation-3-0\LICENSE" (AiaPath 'models\diarization\segmentation\LICENSE') -Force
        Remove-Item $dl -Recurse -Force
    }
    $emb = AiaPath 'models\diarization\embedding\nemo_en_titanet_large.onnx'
    if (-not (Test-Path $emb) -or $Repair) { Get-File $Urls.diarEmb $emb }
    $w2v = AiaPath 'models\torch\hub\checkpoints\wav2vec2_fairseq_base_ls960_asr_ls960.pth'
    if (-not (Test-Path $w2v) -or $Repair) { Get-File $Urls.wav2vec2 $w2v }
    if (-not (Test-HfModel 'Systran/faster-whisper-large-v3' 'model.bin') -or $Repair) {
        $code = @"
import os
from huggingface_hub import snapshot_download
rev = '$($ModelPins.whisper)'
path = snapshot_download('Systran/faster-whisper-large-v3', revision=rev)
refs = os.path.join(os.environ['HF_HOME'], 'hub', 'models--Systran--faster-whisper-large-v3', 'refs')
os.makedirs(refs, exist_ok=True)
open(os.path.join(refs, 'main'), 'w').write(rev)
print('Whisper large-v3 in', path)
"@
        Invoke-PythonCode (Venv-Py 'tools\whisperx') $code
    }
}

function Install-Narrate {
    Install-LockedEnv 'narrate'
    if (-not $SkipModels) { Install-Kokoro (Venv-Py 'tools\narrate') }
}

function Install-Abogen {
    Install-LockedEnv 'abogen'
    if (-not $SkipModels) { Install-Kokoro (Venv-Py 'tools\abogen') }
}

function Install-AceStep {
    Install-Repo 'ACE-Step-1.5'
    $dir = AiaPath 'tools\ACE-Step-1.5'
    $e = $Manifest.envs.'ACE-Step-1.5'
    if (-not (Test-Path (Join-Path $dir '.venv\Scripts\acestep.exe')) -or $Repair) {
        # ACE-Step pins its environment in its own uv.lock (PyTorch cu128, flash-attn and triton wheels for Windows).
        # "uv sync" ignores UV_VENV_RELOCATABLE, so make the environment relocatable first; sync then keeps it so.
        if (-not (Test-Path (Join-Path $dir '.venv\pyvenv.cfg'))) {
            Invoke-Native 'uv' @('venv', (Join-Path $dir '.venv'), '--python', $e.python, '--relocatable', '--prompt', 'ace-step')
        }
        Invoke-Native 'uv' @('sync', '--frozen', '--python', $e.python) $dir
    } else { Write-Log '  environment already present' }
    $overlay = Join-Path $SetupDir 'overlays\ACE-Step-1.5\.env'
    if ((Test-Path $overlay) -and (-not (Test-Path (Join-Path $dir '.env')) -or $Repair)) { Copy-Item $overlay (Join-Path $dir '.env') -Force; Write-Log '  wrote .env' }
    if ($SkipModels) { return }
    $dlExe = Join-Path $dir '.venv\Scripts\acestep-download.exe'
    $ck = Join-Path $dir 'checkpoints'
    if (-not (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-turbo' '*.safetensors') -or $Repair) {
        Invoke-Native $dlExe @('--dir', $ck) $dir          # 2B turbo, VAE, text encoder, 1.7B planner
    }
    if (-not (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-base' '*.safetensors') -or $Repair) {
        Invoke-Native $dlExe @('--model', 'acestep-v15-base', '--skip-main', '--dir', $ck) $dir
    }
    if ($WithXL -and (-not (Test-HasFiles 'tools\ACE-Step-1.5\checkpoints\acestep-v15-xl-turbo' '*.safetensors' 4) -or $Repair)) {
        Invoke-Native $dlExe @('--model', 'acestep-v15-xl-turbo', '--skip-main', '--dir', $ck) $dir
    }
}

function Install-Hum {
    Install-LockedEnv 'humtools'
    if (-not (Test-HasFiles 'tools\fluidsynth' 'fluidsynth.exe') -or $Repair) {
        $zip = AiaPath 'tools\fluidsynth\fluidsynth.zip'
        Get-File $Urls.fluid $zip
        Expand-Zip $zip (AiaPath 'tools\fluidsynth')
        Remove-Item $zip -Force
    }
    if ($SkipModels) { return }
    $sf = AiaPath 'models\soundfonts\GeneralUser-GS.sf2'
    if (-not (Test-Path $sf) -or $Repair) {
        Get-File $Urls.sf2 $sf
        Get-File $Urls.sf2readme (AiaPath 'models\soundfonts\GeneralUser-GS README.md')
    }
}

function Install-Separate {
    Install-LockedEnv 'separator'
    if ($SkipModels) { return }
    $exe = AiaPath 'tools\separator\.venv\Scripts\audio-separator.exe'
    $dir = AiaPath 'models\separator'
    if (-not (Test-Path (Join-Path $dir 'htdemucs_ft.yaml')) -or -not (Test-HasFiles 'models\separator' '*.th' 4) -or $Repair) {
        Invoke-Native $exe @('--download_model_only', '-m', 'htdemucs_ft.yaml', '--model_file_dir', $dir)
    }
    if (-not (Test-Path (Join-Path $dir 'model_bs_roformer_ep_317_sdr_12.9755.ckpt')) -or $Repair) {
        Invoke-Native $exe @('--download_model_only', '-m', 'model_bs_roformer_ep_317_sdr_12.9755.ckpt', '--model_file_dir', $dir)
    }
}

function Install-Applio {
    Install-Repo 'Applio'
    Install-LockedEnv 'Applio'
    if ($SkipModels) { return }
    if (-not (Test-Path (AiaPath 'tools\Applio\rvc\models\predictors\rmvpe.pt')) -or $Repair) {
        # pretrained models, embedders, pitch predictors and ffmpeg.exe (~2.1 GB). core.py has no
        # "no spaces in the path" check (only app.py does), so it runs from the real folder.
        Invoke-Native (Venv-Py 'tools\Applio') @('core.py', 'prerequisites') (AiaPath 'tools\Applio')
    }
}

function Install-ComfyUI {
    Install-Repo 'ComfyUI'
    $freshEnv = -not (Test-Path (Venv-Py 'tools\ComfyUI'))
    Install-LockedEnv 'ComfyUI'
    Install-Repo 'TTS-Audio-Suite'
    $py = Venv-Py 'tools\ComfyUI'
    $suite = AiaPath 'tools\ComfyUI\custom_nodes\TTS-Audio-Suite'
    if ($freshEnv -or $Repair -or -not (Test-Path (AiaPath 'tools\ComfyUI\.venv\Lib\site-packages\fish_speech'))) {
        # The suite's own installer adds what can't come from a lock (fish-speech from git, patched)
        Invoke-Native $py @('install.py') $suite
    }
    # Fish Audio S2 loads reference audio through torchcodec, which needs ffmpeg as shared
    # libraries (DLLs). The kit's normal ffmpeg is a single program without them.
    if (-not (Test-Path (AiaPath 'tools\_bin\ffmpeg-shared\bin\avcodec-62.dll'))) {
        $sh = AiaPath 'tools\_bin\ffmpeg-shared'
        New-Item -ItemType Directory -Force -Path $sh | Out-Null
        Get-File $Urls.ffmpegShared "$sh\_dl.zip"
        Expand-Zip "$sh\_dl.zip" "$sh\_x"
        $bin = Get-ChildItem "$sh\_x" -Recurse -Directory -Filter 'bin' | Select-Object -First 1
        Move-Item -LiteralPath $bin.FullName -Destination "$sh\bin"
        Remove-Item "$sh\_x", "$sh\_dl.zip" -Recurse -Force
    }
    # Ready-made workflows in ComfyUI's workflow browser, with plain names
    $wfDir = AiaPath 'tools\ComfyUI\user\default\workflows'
    New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
    $map = [ordered]@{
        'Chatterbox integration.json'                     = '1 - Clone a voice (ChatterBox).json'
        '*Voice Changer - RVC X ChatterBox.json'          = '2 - Voice changer (RVC or ChatterBox).json'
        'VibeVoice integration.json'                      = '3 - Expressive long-form and multi-speaker (VibeVoice).json'
        '*IndexTTS-2 integration.json'                    = '4 - Emotion-controlled cloning (IndexTTS-2).json'
        'Unified*TTS SRT.json'                            = '5 - Narrate a subtitle file (SRT).json'
        'Voice Cleaning*Noise or Vocal Removal*Voice Fixer.json' = '6 - Clean up a voice recording.json'
        'Unified*Voice Designer.json'                     = '7 - Design a new voice from a description.json'
        'RVC*Model Training.json'                         = '8 - Train an RVC voice model.json'
    }
    $examples = @(Get-ChildItem (Join-Path $suite 'example_workflows') -File -Filter '*.json' -ErrorAction SilentlyContinue)
    foreach ($pattern in $map.Keys) {
        $target = Join-Path $wfDir $map[$pattern]
        if ((Test-Path -LiteralPath $target) -and -not $Repair) { continue }
        $src = $examples | Where-Object { $_.Name -like $pattern } | Select-Object -First 1
        if ($src) { Copy-Item -LiteralPath $src.FullName -Destination $target -Force; Write-Log "  workflow: $($map[$pattern])" }
        else { Write-Log "  (example workflow matching '$pattern' not found in this suite version)" }
    }
    # Reference voices from voices\reference (e.g. the narrator) show up in the suite's voice pickers
    $voiceDir = AiaPath 'tools\ComfyUI\models\voices'
    New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null
    foreach ($f in @(Get-ChildItem (AiaPath 'voices\reference') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.wav', '.mp3', '.flac', '.txt' })) {
        $target = Join-Path $voiceDir $f.Name
        if (-not (Test-Path -LiteralPath $target) -or $Repair) { Copy-Item -LiteralPath $f.FullName $target -Force; Write-Log "  voice: $($f.Name)" }
    }
    if ($SkipModels) { return }
    $code = @"
import os
from huggingface_hub import hf_hub_download
tts = os.path.join(os.environ['AIA_ROOT'], 'tools', 'ComfyUI', 'models', 'TTS')
def get(repo, rev, files, dest):
    os.makedirs(dest, exist_ok=True)
    for f in files:
        if not os.path.exists(os.path.join(dest, f)):
            hf_hub_download(repo, f, revision=rev, local_dir=dest)
            print('downloaded', repo, f)
get('ResembleAI/chatterbox', '$($ModelPins.chatterbox)',
    ['conds.pt', 's3gen.pt', 's3gen.safetensors', 't3_cfg.pt', 'tokenizer.json', 've.pt'],
    os.path.join(tts, 'chatterbox', 'English'))
vv = os.path.join(tts, 'vibevoice', 'vibevoice-1.5B')
get('microsoft/VibeVoice-1.5B', '$($ModelPins.vibevoice)',
    ['config.json', 'preprocessor_config.json', 'model.safetensors.index.json',
     'model-00001-of-00003.safetensors', 'model-00002-of-00003.safetensors', 'model-00003-of-00003.safetensors'], vv)
get('Qwen/Qwen2.5-1.5B', '$($ModelPins.qwen)', ['tokenizer.json'], vv)
get('Qwen/Qwen2.5-1.5B', '$($ModelPins.qwen)', ['tokenizer.json', 'tokenizer_config.json'],
    os.path.join(tts, 'vibevoice', 'Qwen_Qwen2.5-1.5B', 'tokenizer'))
print('ChatterBox and VibeVoice models ready')
"@
    Invoke-PythonCode $py $code
}

$Installers = @{
    core = { Install-Core }; transcribe = { Install-Transcribe }; narrate = { Install-Narrate }; abogen = { Install-Abogen }
    acestep = { Install-AceStep }; hum = { Install-Hum }; separate = { Install-Separate }; applio = { Install-Applio }; comfyui = { Install-ComfyUI }
}

# ---- command-line mode ---------------------------------------------------------------
function Resolve-Keys([string[]]$Requested) {
    $keys = @()
    foreach ($k in @($Requested | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })) {
        if ($k -eq 'all') { $keys += $AllKeys; continue }
        if ($Registry.presets -and $Registry.presets.$k) { $keys += @($Registry.presets.$k.keys); continue }      # e.g. "recommended"
        if ($AllKeys -notcontains $k) { throw "Unknown component '$k'. Choose from: $($AllKeys -join ', '), all, $(@($Registry.presets.PSObject.Properties.Name) -join ', ')" }
        $keys += $k
    }
    if ($keys -notcontains 'core') { $keys = @('core') + $keys }
    return @($AllKeys | Where-Object { $keys -contains $_ })      # catalog order, no duplicates
}

function Show-List {
    $t = Get-GpuTier
    Write-Log ('Graphics memory: ' + $(if ($GpuDetected) { '{0} with {1:N0} GB detected' -f $GpuDetected.Name, $GpuDetected.GB } else { 'no NVIDIA card detected' }) + "; planning for '$(Get-GpuLabel $t)'")
    foreach ($c in $Catalog) {
        $s = Get-ComponentState $c.Key
        Write-Log ('{0,-11} {1,-22} {2,-20} {3}' -f $c.Key, $c.Name, $s.Status, $c.Size)
    }
}

function Invoke-Install([string[]]$Keys) {
    New-Item -ItemType Directory -Force -Path (AiaPath 'logs') | Out-Null
    if (-not $DryRun) { $script:LogFile = AiaPath ('logs\install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log') }
    $mode = 'install'; if ($Repair) { $mode = 'repair' }
    Write-Log "AI Audio $mode in $Root"
    Write-Log ("Components: $($Keys -join ', ')" + $(if ($SkipModels) { '  (environments only, no models)' } else { '' }) + $(if ($WithXL) { '  (+ ACE-Step XL)' } else { '' }))
    if (-not $DryRun) {
        # If this folder was moved since the last run, fix the tools for the new place first
        # (a no-op that just records the location otherwise).
        $oldEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $relocOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SetupDir 'relocate.ps1') 2>&1
        $ErrorActionPreference = $oldEap
        foreach ($line in @($relocOut)) { Write-Log "  $line" }
    }
    $failed = @()
    $i = 0
    foreach ($k in $Keys) {
        $i++
        $c = $Catalog | Where-Object { $_.Key -eq $k }
        Write-Log "##STEP $i/$($Keys.Count) $($c.Name)"
        Write-Log ''
        Write-Log "=== $($c.Name) ==="
        if (-not $Repair -and (Test-ComponentDone $k)) { Write-Log '  already installed - skipped (use Repair to redo it)'; continue }
        if ($DryRun) { Write-Log "  would run: Install-$k (status now: $((Get-ComponentState $k).Status))"; continue }
        $t0 = Get-Date
        try {
            & $Installers[$k]
            Write-Log ("  done in {0:N0} s - status: {1}" -f ((Get-Date) - $t0).TotalSeconds, (Get-ComponentState $k).Status)
        } catch {
            $failed += $k
            Write-Log "  FAILED: $($_.Exception.Message)"
            Write-Log "  (details: $($_.InvocationInfo.PositionMessage -replace '\r?\n', ' '))"
            if ($k -eq 'core') { Write-Log 'Core failed, so nothing else can be installed.'; break }
        }
    }
    Write-Log ''
    if ($failed.Count) { Write-Log "Finished with problems in: $($failed -join ', '). Log: $script:LogFile"; Write-Log '##RESULT failed'; return 1 }
    Write-Log "All done. Log: $script:LogFile"
    Write-Log '##RESULT ok'
    return 0
}

# ---- removing components ---------------------------------------------------------------
# What gets deleted comes from setup\components.json: a component's "remove" folders and its
# "models", minus its "keep" paths (the user's own work) and minus models that a component
# which stays installed also lists. Only paths under tools\ and models\ are ever touched.
Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class AIATree {
    // Deletes a file or a folder tree. A junction or link is removed as a link:
    // whatever it points at is never touched.
    public static void Delete(string path) {
        if (File.Exists(path)) { DeleteFile(path); return; }
        if (!Directory.Exists(path)) return;
        var di = new DirectoryInfo(path);
        if ((di.Attributes & FileAttributes.ReparsePoint) != 0) { Directory.Delete(path, false); return; }
        foreach (var f in Directory.GetFiles(path)) DeleteFile(f);
        foreach (var d in Directory.GetDirectories(path)) Delete(d);
        if ((di.Attributes & FileAttributes.ReadOnly) != 0) di.Attributes = FileAttributes.Directory;
        Directory.Delete(path, false);
    }
    static void DeleteFile(string f) {
        var a = File.GetAttributes(f);
        if ((a & FileAttributes.ReadOnly) != 0) File.SetAttributes(f, a & ~FileAttributes.ReadOnly);
        File.Delete(f);
    }
    // Size in bytes, not following junctions or links.
    public static long Size(string path) {
        if (File.Exists(path)) return new FileInfo(path).Length;
        if (!Directory.Exists(path)) return 0;
        var di = new DirectoryInfo(path);
        if ((di.Attributes & FileAttributes.ReparsePoint) != 0) return 0;
        long n = 0;
        try {
            foreach (var f in di.GetFiles()) n += f.Length;
            foreach (var d in di.GetDirectories()) n += Size(d.FullName);
        } catch (Exception) { }
        return n;
    }
}
'@

function Get-Comp([string]$Key) { $Catalog | Where-Object { $_.Key -eq $Key } | Select-Object -First 1 }
function Test-CompPresent([string]$Key) { $s = Get-ComponentState $Key; return ($s.Env -or $s.Any) }

function Resolve-InKit([string]$Rel) {
    # Full path of a kit-relative path. Refuses anything not strictly inside tools\ or models\.
    if ($Rel -notmatch '^(tools|models)\\[^\\]+' -or $Rel -match '\.\.' -or $Rel -match '[*?]') { throw "components.json: '$Rel' is not a removable path" }
    $base = $Root.TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $base $Rel)).TrimEnd('\')
    if (-not $full.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "refusing to touch a path outside the kit: $Rel" }
    return $full
}

function Remove-KitTree([string]$Full) {
    if (-not (Test-Path -LiteralPath $Full)) { return }
    try { [AIATree]::Delete($Full) }
    catch {
        $why = $_.Exception.Message
        # very long paths: let cmd finish the job (rd removes links without following them)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$env:WINDIR\System32\cmd.exe"
        $psi.Arguments = '/d /c rd /s /q "\\?\' + $Full + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        if (Test-Path -LiteralPath $Full) { throw "could not delete $Full ($why). Close any program that is using it and try again." }
    }
}

function Remove-KitTreeExcept([string]$Full, [string[]]$Keep) {
    # Deletes $Full but leaves every existing $Keep path (and the folders leading to it).
    if (-not (Test-Path -LiteralPath $Full)) { return }
    foreach ($k in $Keep) { if ($k -ieq $Full) { return } }
    $inside = @($Keep | Where-Object { $_.StartsWith($Full + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $_) })
    if ($inside.Count -eq 0) { Remove-KitTree $Full; return }
    foreach ($child in @(Get-ChildItem -LiteralPath $Full -Force)) { Remove-KitTreeExcept $child.FullName $Keep }
}

function Test-KitHasMore([string]$Full, [string[]]$Keep) {
    # Is there anything under $Full besides the $Keep paths (and the folders leading to them)?
    if (-not (Test-Path -LiteralPath $Full)) { return $false }
    foreach ($k in $Keep) { if ($k -ieq $Full) { return $false } }
    $inside = @($Keep | Where-Object { $_.StartsWith($Full + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $_) })
    if ($inside.Count -eq 0) { return $true }
    foreach ($child in @(Get-ChildItem -LiteralPath $Full -Force)) { if (Test-KitHasMore $child.FullName $Keep) { return $true } }
    return $false
}

function Get-KitSizeExcept([string]$Full, [string[]]$Keep) {
    if (-not (Test-Path -LiteralPath $Full)) { return [long]0 }
    foreach ($k in $Keep) { if ($k -ieq $Full) { return [long]0 } }
    $inside = @($Keep | Where-Object { $_.StartsWith($Full + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $_) })
    if ($inside.Count -eq 0) { return [AIATree]::Size($Full) }
    $n = [long]0
    foreach ($child in @(Get-ChildItem -LiteralPath $Full -Force)) { $n += Get-KitSizeExcept $child.FullName $Keep }
    return $n
}

function Get-RemovePlan([string[]]$Keys, [bool]$KeepTheModels) {
    # Per component: what to delete and what stays. A model that a component which remains
    # installed also lists (e.g. the Kokoro voices of Narrate and Abogen) stays.
    $remaining = @($AllKeys | Where-Object { $Keys -notcontains $_ -and $_ -ne 'core' -and (Test-CompPresent $_) })
    $stillNeeded = @()
    foreach ($k in $remaining) { $stillNeeded += @((Get-Comp $k).models) }
    $plan = @()
    foreach ($k in $Keys) {
        $c = Get-Comp $k
        $del = @(); $keep = @()
        foreach ($r in @($c.keep)) { if ($r) { $keep += (Resolve-InKit $r) } }
        foreach ($r in @($c.models)) {
            if (-not $r) { continue }
            if ($KeepTheModels -or ($stillNeeded -contains $r)) { $keep += (Resolve-InKit $r) } else { $del += (Resolve-InKit $r) }
        }
        foreach ($r in @($c.remove)) { if ($r) { $del += (Resolve-InKit $r) } }
        # a path inside another path on the list goes with it: list (and count) it once
        $del = @($del | Where-Object { $d = $_; -not @($del | Where-Object { $d.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }).Count })
        $plan +=[pscustomobject]@{ Key = $k; Name = $c.Name; Delete = @($del | Select-Object -Unique); Keep = @($keep | Select-Object -Unique) }
    }
    return [pscustomobject]@{ Items = $plan; Remaining = $remaining }
}

function Get-RemoveBytes($Plan) {
    $n = [long]0
    $seen = @{}
    foreach ($it in $Plan.Items) { foreach ($d in $it.Delete) { if (-not $seen[$d]) { $seen[$d] = $true; $n += Get-KitSizeExcept $d $it.Keep } } }
    return $n
}

function Get-LockPackages([string[]]$LockFiles) {
    $names = @{}
    foreach ($f in $LockFiles) {
        $p = Join-Path $LockDir $f
        if (-not $f -or -not (Test-Path -LiteralPath $p)) { continue }
        foreach ($l in [IO.File]::ReadAllLines($p)) {
            $l = $l.Trim()
            if (-not $l -or $l.StartsWith('#') -or $l.StartsWith('-')) { continue }
            $n = (($l -split '==| @ ')[0]).Trim().ToLower() -replace '[_.]', '-'
            if ($n -match '^[a-z0-9][a-z0-9-]*$') { $names[$n] = $true }
        }
    }
    return $names
}

function Resolve-RemoveKeys([string[]]$Raw) {
    $keys = @()
    foreach ($r in $Raw) { foreach ($k in ($r -split ',')) { $k = $k.Trim().ToLower(); if ($k) { $keys += $k } } }
    foreach ($k in $keys) {
        if ($AllKeys -notcontains $k) { throw "Unknown component '$k'. Known: $($AllKeys -join ', ')" }
        if ($k -eq 'core') { throw "Core can't be removed: everything else needs it. To remove AI Audio completely, delete its folder." }
    }
    return @($AllKeys | Where-Object { $keys -contains $_ })
}

function Invoke-Remove([string[]]$Keys, [bool]$MoreFollows) {
    New-Item -ItemType Directory -Force -Path (AiaPath 'logs') | Out-Null
    if (-not $DryRun) { $script:LogFile = AiaPath ('logs\remove-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log') }
    Write-Log "AI Audio remove in $Root"
    Write-Log ("Components: $($Keys -join ', ')" + $(if ($KeepModels) { '  (keeping the downloaded models)' } else { '' }))
    $plan = Get-RemovePlan $Keys ([bool]$KeepModels)
    if ($DryRun) {
        foreach ($it in $plan.Items) {
            Write-Log "=== $($it.Name) ==="
            foreach ($d in $it.Delete) { if (Test-Path -LiteralPath $d) { Write-Log ('  would delete  {0}  ({1:N1} GB)' -f $d, ((Get-KitSizeExcept $d $it.Keep) / 1GB)) } }
            foreach ($k in $it.Keep) { if (Test-Path -LiteralPath $k) { Write-Log "  would keep    $k" } }
        }
        Write-Log ('Total: about {0:N1} GB on disk (less is freed where tools share files).' -f ((Get-RemoveBytes $plan) / 1GB))
        return 0
    }
    $drive = New-Object System.IO.DriveInfo ([IO.Path]::GetPathRoot($Root))
    $before = $drive.AvailableFreeSpace
    $planBytes = Get-RemoveBytes $plan

    # stop the tools that are about to go (never anything else)
    . (Join-Path $Root 'scripts\panel_core.ps1')
    $self = @(Get-AIASelfChain)
    $toolKeys = @($Registry.tools | Where-Object { $Keys -contains $_.component } | ForEach-Object { $_.key })
    foreach ($k in $Keys) { $toolKeys += @((Get-Comp $k).also_stop) }
    foreach ($tk in @($toolKeys | Where-Object { $_ } | Select-Object -Unique)) {
        try { if ((Stop-AIATool -Key $tk -Exclude $self) -gt 0) { Write-Log "  stopped the running tool: $tk" } } catch {}
    }

    $failed = @()
    $i = 0
    foreach ($it in $plan.Items) {
        $i++
        Write-Log "##STEP $i/$($plan.Items.Count) removing $($it.Name)"
        Write-Log ''
        Write-Log "=== Removing $($it.Name) ==="
        try {
            foreach ($d in $it.Delete) {
                if (-not (Test-Path -LiteralPath $d)) { continue }
                Write-Log "  deleting $d"
                Remove-KitTreeExcept $d $it.Keep
            }
            foreach ($k in $it.Keep) { if (Test-Path -LiteralPath $k) { Write-Log "  kept     $k" } }
            Write-Log "  status: $((Get-ComponentState $it.Key).Status)"
        } catch {
            $failed += $it.Key
            Write-Log "  FAILED: $($_.Exception.Message)"
        }
    }

    # Tools share identical package files through the package cache, so space only comes
    # back once the cache lets go of packages no remaining tool uses.
    if (-not $CacheDir -and (Test-Command 'uv')) {
        $gone = Get-LockPackages @($Keys | ForEach-Object { @((Get-Comp $_).locks) })
        $stay = Get-LockPackages @($plan.Remaining | ForEach-Object { @((Get-Comp $_).locks) })
        $names = @($gone.Keys | Where-Object { -not $stay[$_] } | Sort-Object)
        if ($names.Count) {
            Write-Log ''
            Write-Log "Trimming the package cache ($($names.Count) packages no remaining tool uses)..."
            try {
                for ($n = 0; $n -lt $names.Count; $n += 40) {
                    $chunk = @($names[$n..([math]::Min($n + 39, $names.Count - 1))])
                    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
                    & uv cache clean @chunk 2>&1 | Out-Null
                    $ErrorActionPreference = $old
                }
            } catch { Write-Log "  (cache trim skipped: $($_.Exception.Message))" }
        }
    }
    $freed = ($drive.AvailableFreeSpace - $before) / 1GB
    Write-Log ''
    # Windows can be slow to report freed space, so fall back to the size of what was deleted
    if ($freed -ge 0.05) { Write-Log ('Freed about {0:N1} GB.' -f $freed) }
    else { Write-Log ('Removed about {0:N1} GB of files.' -f ($planBytes / 1GB)) }
    if ($failed.Count) {
        Write-Log "Could not fully remove: $($failed -join ', '). Log: $script:LogFile"
        if (-not $MoreFollows) { Write-Log '##RESULT failed' }
        return 1
    }
    Write-Log "Removed. Log: $script:LogFile"
    if (-not $MoreFollows) { Write-Log '##RESULT ok' }
    return 0
}

if ($Relocate) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SetupDir 'relocate.ps1') -Convert
    exit $LASTEXITCODE
}
if ($List) { Show-List; exit 0 }
if ($Components -or $Remove -or $NoGui) {
    if (-not $Components -and -not $Remove) { Write-Log 'Give -Components (e.g. -Components narrate,transcribe or all) or -Remove (e.g. -Remove abogen), or run without arguments for the window.'; Show-List; exit 2 }
    $rc = 0
    $removeKeys = @()
    if ($Remove) { $removeKeys = @(Resolve-RemoveKeys $Remove) }
    $keys = @()
    if ($Components) {
        $keys = Resolve-Keys $Components
        $both = @($removeKeys | Where-Object { $keys -contains $_ })
        if ($both.Count) { Write-Log "Asked to both install and remove: $($both -join ', '). Pick one."; exit 2 }
    }
    if ($removeKeys.Count) {
        if (-not $Yes -and -not $DryRun) {
            Write-Log "About to REMOVE: $($removeKeys -join ', ')  (your own results, voices and settings are kept)"
            $answer = Read-Host 'Continue? [y/N]'
            if ($answer -notmatch '^(y|yes)$') { exit 3 }
        }
        $rc = [int](@(Invoke-Remove $removeKeys ([bool]$Components))[-1])
    }
    if ($Components) {
        if ($WithXL -and (Get-GpuTier) -lt $XLMinGB) {
            Write-Log "Leaving out the ACE-Step XL model: it needs a $XLMinGB GB graphics card, and this install is planned for '$(Get-GpuLabel (Get-GpuTier))'. (Override with -GpuGB.)"
            $WithXL = $false
        }
        if (-not $Yes -and -not $DryRun) {
            Write-Log "About to $(if ($Repair) { 'repair' } else { 'install' }): $($keys -join ', ')"
            $answer = Read-Host 'Continue? [Y/n]'
            if ($answer -and $answer -notmatch '^(y|yes)$') { exit 3 }
        }
        $codes = @(Invoke-Install $keys)
        $rc2 = [int]$codes[-1]
        if ($rc -ne 0 -and $rc2 -eq 0) { Write-Log 'The removal had problems (see above).'; Write-Log '##RESULT failed'; $rc2 = 1 }
        $rc = $rc2
    }
    exit $rc
}

# ===================================================================================== GUI
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
try {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AIAInstNative {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[void][AIAInstNative]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()
# the look (dark by default, or what the control panel's Theme link last chose) and text size
. (Join-Path $Root 'scripts\ui_theme.ps1')

# Sizes follow the display scaling (DPI) and Windows' Text size setting ($AIATextScale).
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $Scale = $g.DpiX / 96.0 * $AIATextScale; $g.Dispose()
function Px([double]$v) { [int][math]::Round($v * $Scale) }
function New-Pad($l, $t, $r, $b) { New-Object System.Windows.Forms.Padding((Px $l), (Px $t), (Px $r), (Px $b)) }

$FontBase  = New-AIAFont 'Segoe UI' 9.5
$FontName  = New-AIAFont 'Segoe UI Semibold' 10
$FontSmall = New-AIAFont 'Segoe UI' 8.75
$FontTitle = New-AIAFont 'Segoe UI Semibold' 15
$FontState = New-AIAFont 'Segoe UI Semibold' 9.5
$FontMono  = New-AIAFont 'Consolas' 8.5
$Dot = [string][char]0x25CF

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AI Audio components'
$form.Font = $FontBase
$form.AutoScaleMode = 'None'
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Padding = New-Pad 16 12 16 12
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:WINDIR\System32\SndVol.exe") } catch {}

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.AutoSize = $true
$main.AutoSizeMode = 'GrowAndShrink'
$main.ColumnCount = 1
$form.Controls.Add($main)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'AI Audio components: add, repair or remove'
$title.Font = $FontTitle
$title.AutoSize = $true
$main.Controls.Add($title)
$hint = New-Object System.Windows.Forms.Label
$hint.Text = "A tick means installed. Tick the tools you want, untick the ones you don't, then click Apply changes. Everything goes into $Root - nothing is installed system-wide. Removing a tool frees its disk space and keeps your own results, voices and settings. Sizes overlap: the tools share one package cache, so the real total is much smaller than the sum."
Set-AIARole $hint 'dim'
$hint.AutoSize = $true
$hint.MaximumSize = New-Object System.Drawing.Size((Px 900), 0)
$hint.Margin = New-Pad 0 2 0 8
$main.Controls.Add($hint)

# graphics memory + quick picks
$picks = New-Object System.Windows.Forms.FlowLayoutPanel
$picks.AutoSize = $true
$picks.WrapContents = $false
$picks.Margin = New-Pad 0 0 0 6
$gpuLabel = New-Object System.Windows.Forms.Label
$gpuLabel.Text = 'Graphics memory'
$gpuLabel.AutoSize = $true
$gpuLabel.Margin = New-Pad 0 7 8 0
$gpuBox = New-Object System.Windows.Forms.ComboBox
$gpuBox.Name = 'gpuMemory'
$gpuBox.DropDownStyle = 'DropDownList'
foreach ($t in $GpuSizes) { [void]$gpuBox.Items.Add((Get-GpuLabel $t)) }
$gpuBox.Width = Px 150
$gpuBox.Margin = New-Pad 0 3 8 0
$script:GpuTier = Get-GpuTier
$gpuBox.SelectedIndex = [array]::IndexOf($GpuSizes, $script:GpuTier)
$gpuFound = New-Object System.Windows.Forms.Label
$gpuFound.AutoSize = $true
Set-AIARole $gpuFound 'dim'
$gpuFound.Margin = New-Pad 0 7 24 0
$gpuFound.Text = if ($GpuDetected) { 'found: {0}, {1:N0} GB' -f $GpuDetected.Name, $GpuDetected.GB } else { "none found, so 16 GB is assumed; change it if that's wrong" }
$pickLabel = New-Object System.Windows.Forms.Label
$pickLabel.Text = 'Quick picks'
$pickLabel.AutoSize = $true
$pickLabel.Margin = New-Pad 0 7 8 0
$picks.Controls.AddRange(@($gpuLabel, $gpuBox, $gpuFound, $pickLabel))
function New-PickButton([string]$Text, [string]$Name, [string]$Tip) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Name = $Name
    $b.AutoSize = $true
    $b.MinimumSize = New-Object System.Drawing.Size((Px 96), (Px 28))
    $b.Margin = New-Pad 0 2 6 0
    $picks.Controls.Add($b)
    return $b
}
$PickButtons = @{}
if ($Registry.presets) {
    foreach ($pp in $Registry.presets.PSObject.Properties) { $PickButtons[$pp.Name] = New-PickButton $pp.Value.name "pick_$($pp.Name)" $pp.Value.desc }
}
$btnAll = New-PickButton 'Select all' 'pick_all' ''
$btnNone = New-PickButton 'Select none' 'pick_none' ''
$main.Controls.Add($picks)

$grid = New-Object System.Windows.Forms.TableLayoutPanel
$grid.AutoSize = $true
$grid.AutoSizeMode = 'GrowAndShrink'
$grid.ColumnCount = 4
for ($c = 0; $c -lt 4; $c++) { [void]$grid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) }
$main.Controls.Add($grid)

$Rows = @{}
foreach ($comp in $Catalog) {
    $grid.RowCount += 1
    [void]$grid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    $r = $grid.RowCount - 1
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.AutoSize = $true
    $chk.Margin = New-Pad 0 8 8 0
    $chk.Anchor = 'Left'
    $chk.Tag = $comp.Key
    $grid.Controls.Add($chk, 0, $r)

    $text = New-Object System.Windows.Forms.FlowLayoutPanel
    $text.FlowDirection = 'TopDown'
    $text.WrapContents = $false
    $text.AutoSize = $true
    $text.Margin = New-Pad 0 2 14 2
    $n = New-Object System.Windows.Forms.Label
    $n.Text = $comp.Name
    $n.Font = $FontName
    $n.AutoSize = $true
    $n.Margin = New-Pad 0 0 0 0
    $n.Tag = $chk
    $n.Add_Click({ param($s, $e) if ($s.Tag.Enabled) { $s.Tag.Checked = -not $s.Tag.Checked } })
    $d = New-Object System.Windows.Forms.Label
    $d.Text = $comp.Desc
    $d.Font = $FontSmall
    Set-AIARole $d 'dim'
    $d.AutoSize = $true
    $d.MaximumSize = New-Object System.Drawing.Size((Px 520), 0)
    $d.Margin = New-Pad 0 1 0 0
    $g = New-Object System.Windows.Forms.Label
    $g.Font = $FontSmall
    Set-AIARole $g 'status'              # coloured by Update-GpuNotes
    $g.AutoSize = $true
    $g.Margin = New-Pad 0 1 0 0
    $g.Visible = $false
    $text.Controls.AddRange(@($n, $d, $g))
    $grid.Controls.Add($text, 1, $r)

    $size = New-Object System.Windows.Forms.Label
    $size.Text = $comp.Size
    $size.Font = $FontSmall
    Set-AIARole $size 'dim'
    $size.AutoSize = $true
    $size.Anchor = 'Left'
    $size.Margin = New-Pad 0 3 14 3
    $grid.Controls.Add($size, 2, $r)

    $st = New-Object System.Windows.Forms.Label
    $st.Font = $FontState
    Set-AIARole $st 'status'
    $st.AutoSize = $true
    $st.MinimumSize = New-Object System.Drawing.Size((Px 170), 0)
    $st.Anchor = 'Left'
    $st.Margin = New-Pad 0 3 0 3
    $grid.Controls.Add($st, 3, $r)
    $Rows[$comp.Key] = @{ Check = $chk; Status = $st; GpuNote = $g; MinGB = [int]$comp.min_gb }
}

$opts = New-Object System.Windows.Forms.FlowLayoutPanel
$opts.AutoSize = $true
$opts.FlowDirection = 'TopDown'
$opts.WrapContents = $false
$opts.Margin = New-Pad 0 10 0 4
$optModels = New-Object System.Windows.Forms.CheckBox
$optModels.Text = 'Download the AI models too (untick for environments only; the tools then fetch models on first use)'
$optModels.AutoSize = $true
$optModels.Checked = $true
$optXL = New-Object System.Windows.Forms.CheckBox
$optXL.Text = 'Include the ACE-Step XL music model (best sound, +19 GB)'
$optXL.AutoSize = $true
$optXL.Checked = $true       # set properly in Update-Statuses (not pre-ticked when ACE-Step is there without XL)
$optLnk = New-Object System.Windows.Forms.CheckBox
$optLnk.Text = 'Put an "AI Audio" shortcut on the desktop (opens the control panel)'
$optLnk.AutoSize = $true
$ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AI Audio.lnk'
$optLnk.Checked = (Test-Path $ShortcutPath)     # on a fresh kit Update-Statuses ticks it
$optKeep = New-Object System.Windows.Forms.CheckBox
$optKeep.Text = 'When removing a tool, keep its downloaded AI models (quicker to add back, but frees much less space)'
$optKeep.AutoSize = $true
$optKeep.Checked = $false
$opts.Controls.AddRange(@($optModels, $optXL, $optLnk, $optKeep))
$main.Controls.Add($opts)

# what Apply will do, kept up to date as boxes are ticked and unticked
$changesLabel = New-Object System.Windows.Forms.Label
$changesLabel.AutoSize = $true
$changesLabel.Font = $FontName
$changesLabel.MaximumSize = New-Object System.Drawing.Size((Px 900), 0)
$changesLabel.Margin = New-Pad 0 6 0 2
$changesLabel.Text = ' '
$main.Controls.Add($changesLabel)

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.AutoSize = $true
$buttons.WrapContents = $false
$buttons.Margin = New-Pad 0 6 0 6
function New-Btn([string]$Text, [int]$W = 150) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.AutoSize = $true
    $b.MinimumSize = New-Object System.Drawing.Size((Px $W), (Px 34))
    $b.Margin = New-Pad 0 0 10 0
    return $b
}
$btnInstall = New-Btn 'Apply changes'
$btnRepair = New-Btn 'Repair ticked'
$btnCancel = New-Btn 'Cancel' 100
$btnCancel.Enabled = $false
$btnClose = New-Btn 'Close' 100
$buttons.Controls.AddRange(@($btnInstall, $btnRepair, $btnCancel, $btnClose))
$main.Controls.Add($buttons)

$progress = New-AIABar (Px 900) (Px 14)
$progress.Margin = New-Pad 0 4 0 2
$main.Controls.Add($progress)
function Set-Progress([int]$Done, [int]$Total) { Set-AIABar $progress ($Done / [math]::Max(1, $Total)) }
$progressText = New-Object System.Windows.Forms.Label
$progressText.AutoSize = $true
Set-AIARole $progressText 'dim'
$progressText.Text = 'Ready.'
$main.Controls.Add($progressText)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.WordWrap = $true
$log.Font = $FontMono
$log.Size = New-Object System.Drawing.Size((Px 900), (Px 140))
$log.Margin = New-Pad 0 6 0 0
$main.Controls.Add($log)

$XLText = $null
function Test-GpuFits([string]$Key) { return ($Rows[$Key].MinGB -le $script:GpuTier) }
function Update-GpuNotes([switch]$AdjustTicks) {
    # Mark what the chosen card is too small for. With -AdjustTicks (the size was just changed, or
    # the window just opened) such tools are unticked unless they are already installed.
    $script:Syncing = $true
    foreach ($comp in $Catalog) {
        $row = $Rows[$comp.Key]
        if ($comp.Key -eq 'core') { continue }
        $fits = Test-GpuFits $comp.Key
        if ($fits) { $row.GpuNote.Visible = $false }
        else {
            $row.GpuNote.Text = if ($script:GpuTier -eq 0) { 'Needs an NVIDIA graphics card. Without one it is unticked by default.' } else { "Needs a $($row.MinGB) GB graphics card. Unticked by default for a $($script:GpuTier) GB card." }
            $row.GpuNote.ForeColor = $AIAPalette.Amber
            $row.GpuNote.Visible = $true
            $s = $script:States[$comp.Key]
            if ($AdjustTicks -and $s -and -not ($s.Env -or $s.Any)) { $row.Check.Checked = $false }
        }
    }
    if (-not $script:XLText) { $script:XLText = $optXL.Text }
    $ace = $script:States['acestep']
    if ($script:GpuTier -lt $XLMinGB) {
        $optXL.Text = $script:XLText + "  - needs a $XLMinGB GB card, so it is left out"
        if ($AdjustTicks -and $ace -and -not $ace.XL) { $optXL.Checked = $false }
    } else { $optXL.Text = $script:XLText }
    $script:Syncing = $false
}
function Set-Picks([string[]]$Keys, [switch]$RespectGpu) {
    $script:Syncing = $true
    foreach ($comp in $Catalog) {
        if ($comp.Key -eq 'core') { continue }
        $on = ($Keys -contains $comp.Key)
        if ($on -and $RespectGpu -and -not (Test-GpuFits $comp.Key)) { $on = $false }
        $Rows[$comp.Key].Check.Checked = $on
    }
    $script:Syncing = $false
    Update-Summary
}
$script:States = @{}
$script:Syncing = $false
function Get-Changes {
    # What Apply would do: add ticked tools that are not (fully) there, remove unticked ones that are.
    $add = @(); $del = @()
    foreach ($comp in $Catalog) {
        $k = $comp.Key
        $s = $script:States[$k]
        if (-not $s) { continue }
        if ($k -eq 'core') {
            if (-not $s.Env -or ($optLnk.Checked -and -not (Test-Path $ShortcutPath))) { $add += $k }
            continue
        }
        if ($Rows[$k].Check.Checked) {
            $done = $s.Env -and ($s.Models -or -not $optModels.Checked)
            if ($k -eq 'acestep' -and $optXL.Checked -and $optModels.Checked -and -not $s.XL) { $done = $false }
            if (-not $done) { $add += $k }
        } elseif ($s.Env -or $s.Any) { $del += $k }
    }
    return [pscustomobject]@{ Add = $add; Remove = $del }
}
function Get-CompNames([string[]]$Keys) { (@($Catalog | Where-Object { $Keys -contains $_.Key } | ForEach-Object { $_.Name }) -join ', ') }
function Update-Summary {
    if ($script:Syncing) { return }
    $ch = Get-Changes
    $parts = @()
    if ($ch.Add.Count) { $parts += "add $(Get-CompNames $ch.Add)" }
    if ($ch.Remove.Count) { $parts += "REMOVE $(Get-CompNames $ch.Remove)" }
    if ($parts.Count) { $changesLabel.Text = 'Apply changes will: ' + ($parts -join '; ') + '.' }
    else { $changesLabel.Text = 'Nothing to change: what is ticked is installed.' }
    if (-not $script:Proc) { $btnInstall.Enabled = ($parts.Count -gt 0) }
}

function Update-Statuses([switch]$SetChecks) {
    $script:Syncing = $true
    foreach ($comp in $Catalog) {
        $row = $Rows[$comp.Key]
        $s = Get-ComponentState $comp.Key
        $script:States[$comp.Key] = $s
        $row.Status.Text = "$Dot $($s.Status)"
        if ($s.Status -like 'Installed*') { $row.Status.ForeColor = $AIAPalette.Green }
        elseif ($s.Status -eq 'Partly installed') { $row.Status.ForeColor = $AIAPalette.Amber }
        else { $row.Status.ForeColor = $AIAPalette.Gray }
        if ($comp.Key -eq 'core') { $row.Check.Checked = $true; $row.Check.Enabled = $false }
        elseif ($SetChecks -and $Select) { $row.Check.Checked = (@($Select -split ',' | ForEach-Object { $_.Trim().ToLower() }) -contains $comp.Key) }
        elseif ($SetChecks) { $row.Check.Checked = ($s.Env -or $s.Any) }       # a tick means installed
    }
    if ($SetChecks) {
        Update-GpuNotes -AdjustTicks
        $script:Syncing = $true
        $ace = $script:States['acestep']
        $optXL.Checked = ($ace.XL -or -not ($ace.Env -or $ace.Any))             # don't spring a 19 GB download on an existing install
        if (-not $script:States['core'].Any) { $optLnk.Checked = $true }        # fresh kit: offer the shortcut
        if ($script:GpuTier -lt $XLMinGB -and -not $ace.XL) { $optXL.Checked = $false }
    }
    $script:Syncing = $false
    Update-Summary
}

$script:Proc = $null
$script:Reader = $null
$script:ReaderHandle = $null
$script:Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$script:Result = $null

function Set-Running([bool]$On) {
    $btnInstall.Enabled = -not $On
    $btnRepair.Enabled = -not $On
    $btnCancel.Enabled = $On
    foreach ($row in $Rows.Values) { if ($row.Check.Tag -ne 'core') { $row.Check.Enabled = -not $On } }
    $optModels.Enabled = -not $On; $optXL.Enabled = -not $On; $optLnk.Enabled = -not $On; $optKeep.Enabled = -not $On
    $gpuBox.Enabled = -not $On; $btnAll.Enabled = -not $On; $btnNone.Enabled = -not $On
    foreach ($b in $PickButtons.Values) { $b.Enabled = -not $On }
    $form.UseWaitCursor = $On
}

function Start-Run([bool]$IsRepair) {
    # Repair: redo the ticked tools. Otherwise: make the PC match the ticks (add and remove).
    $work = ''
    if ($IsRepair) {
        $keys = @($Catalog | Where-Object { $Rows[$_.Key].Check.Checked } | ForEach-Object { $_.Key })
        $work = ' -Repair -Components ' + ($keys -join ',')
    } else {
        $ch = Get-Changes
        if ($ch.Remove.Count) { $work += ' -Remove ' + ($ch.Remove -join ','); if ($optKeep.Checked) { $work += ' -KeepModels' } }
        if ($ch.Add.Count) { $work += ' -Components ' + ($ch.Add -join ',') }
        if (-not $work) { return }
    }
    $flags = ''
    if (-not $optModels.Checked) { $flags += ' -SkipModels' }
    if ($optXL.Checked) { $flags += ' -WithXL' }
    if ($optLnk.Checked) { $flags += ' -DesktopShortcut' }
    if ($CacheDir) { $flags += ' -CacheDir "' + $CacheDir + '"' }
    $flags += ' -GpuGB ' + $script:GpuTier
    $psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    # cmd merges the child's stderr into stdout, so one reader sees everything in order
    $inner = '"' + $psExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -NoGui -Yes' + $work + $flags + ' 2>&1'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:WINDIR\System32\cmd.exe"
    $psi.Arguments = '/d /s /c "' + $inner + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $Root
    $log.Clear()
    Set-Progress 0 1
    $progressText.Text = 'Starting...'
    $script:Result = $null
    $script:Proc = [System.Diagnostics.Process]::Start($psi)
    # A background runspace reads the output so the window stays responsive.
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $script:Reader = [powershell]::Create()
    $script:Reader.Runspace = $rs
    [void]$script:Reader.AddScript({
        param($stream, $queue)
        while ($true) { $line = $stream.ReadLine(); if ($null -eq $line) { break }; $queue.Enqueue($line) }
    }).AddArgument($script:Proc.StandardOutput).AddArgument($script:Queue)
    $script:ReaderHandle = $script:Reader.BeginInvoke()
    Set-Running $true
}

function Receive-Output {
    $line = $null
    $sb = New-Object System.Text.StringBuilder
    while ($script:Queue.TryDequeue([ref]$line)) {
        if ($line -match '^##STEP (\d+)/(\d+) (.*)$') {
            Set-Progress ([math]::Max(0, [int]$Matches[1] - 1)) ([int]$Matches[2])
            $progressText.Text = "Working on $($Matches[3]) ($($Matches[1]) of $($Matches[2]))..."
            continue
        }
        if ($line -match '^##RESULT (\w+)') { $script:Result = $Matches[1]; continue }
        [void]$sb.AppendLine($line)
    }
    if ($sb.Length) {
        if ($log.TextLength -gt 400000) { $log.Text = $log.Text.Substring(200000) }
        $log.AppendText($sb.ToString())
    }
    if ($script:Proc -and $script:Proc.HasExited -and $script:ReaderHandle -and $script:ReaderHandle.IsCompleted -and $script:Queue.IsEmpty) {
        $ok = ($script:Result -eq 'ok')
        Set-Progress 1 1
        if ($ok) { $progressText.Text = 'Finished.' } elseif ($script:Result -eq 'failed') { $progressText.Text = 'Finished with problems - see the log above.' } else { $progressText.Text = 'Stopped.' }
        try { $script:Reader.Dispose() } catch {}
        $script:Proc = $null; $script:Reader = $null; $script:ReaderHandle = $null
        Set-Running $false
        Update-Statuses
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({ Receive-Output })

$btnInstall.Add_Click({
    $ch = Get-Changes
    if ($ch.Remove.Count) {
        # say exactly what goes and what stays, and how much space it is, before deleting anything
        $form.UseWaitCursor = $true; $form.Refresh()
        try {
            $plan = Get-RemovePlan $ch.Remove $optKeep.Checked
            $gb = (Get-RemoveBytes $plan) / 1GB
        } finally { $form.UseWaitCursor = $false }
        $msg = "Remove these tools?`n"
        foreach ($k in $ch.Remove) {
            $c = Get-Comp $k
            $msg += "`n   - $($c.Name)"
            if ($c.remove_note) { $msg += "`n     $($c.remove_note)" }
        }
        $msg += ("`n`nThey take about {0:N1} GB on disk" -f $gb)
        if ($optKeep.Checked) { $msg += ' (their downloaded AI models are kept)' }
        $msg += ". Somewhat less is freed where other tools share the same files."
        $msg += "`n`nKept: your own results, voices, trained voice models and settings."
        $msg += "`nYou can add a tool again later; it downloads again."
        if ($ch.Add.Count) { $msg += "`n`nAfterwards this adds: $(Get-CompNames $ch.Add)." }
        $answer = [System.Windows.Forms.MessageBox]::Show($form, $msg, 'Remove tools', 'YesNo', 'Warning', 'Button2')
        if ($answer -ne 'Yes') { return }
    }
    Start-Run $false
})
foreach ($row in $Rows.Values) { $row.Check.Add_CheckedChanged({ Update-Summary }) }
$gpuBox.Add_SelectedIndexChanged({
    $script:GpuTier = $GpuSizes[$gpuBox.SelectedIndex]
    if (-not $SnapshotPng) { try { [IO.File]::WriteAllText($GpuFile, [string]$script:GpuTier) } catch {} }
    Update-GpuNotes -AdjustTicks
    Update-Summary
})
foreach ($name in @($PickButtons.Keys)) {
    $PickButtons[$name].Tag = $name
    $PickButtons[$name].Add_Click({ param($s, $e) Set-Picks @($Registry.presets.($s.Tag).keys) -RespectGpu })
}
$btnAll.Add_Click({ Set-Picks $AllKeys })
$btnNone.Add_Click({ Set-Picks @() })
foreach ($o in @($optModels, $optXL, $optLnk)) { $o.Add_CheckedChanged({ Update-Summary }) }
$btnRepair.Add_Click({
    $answer = [System.Windows.Forms.MessageBox]::Show($form, "Repair puts the ticked tools back to the tested versions and makes their Python environments match exactly (extra packages you added are removed). Models are kept. Continue?", 'Repair', 'YesNo', 'Question')
    if ($answer -eq 'Yes') { Start-Run $true }
})
$btnCancel.Add_Click({
    if ($script:Proc -and -not $script:Proc.HasExited) {
        & "$env:WINDIR\System32\taskkill.exe" /PID $script:Proc.Id /T /F 2>$null | Out-Null
        $log.AppendText("`r`nCancelled. Run Install again to continue where it stopped.`r`n")
    }
})
$btnClose.Add_Click({ $form.Close() })
$form.Add_FormClosing({
    param($s, $e)
    if ($script:Proc -and -not $script:Proc.HasExited) {
        $answer = [System.Windows.Forms.MessageBox]::Show($form, 'An install is still running. Stop it and close?', 'AI Audio', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { $e.Cancel = $true; return }
        & "$env:WINDIR\System32\taskkill.exe" /PID $script:Proc.Id /T /F 2>$null | Out-Null
    }
    $timer.Stop()
})

function Set-FitToScreen {
    $work = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $maxH = $work.Height - (Px 16)
    $maxW = $work.Width - (Px 16)
    if ($form.Height -gt $maxH -or $form.Width -gt $maxW) {
        $w = [math]::Min($form.Width + [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + (Px 6), $maxW)
        $h = [math]::Min($form.Height, $maxH)
        $form.AutoSize = $false
        if ($w -lt $maxW) {
            # it fits sideways: scroll up and down only
            $form.HorizontalScroll.Maximum = 0
            $form.HorizontalScroll.Enabled = $false
            $form.HorizontalScroll.Visible = $false
        }
        $form.AutoScroll = $true
        $form.Size = New-Object System.Drawing.Size($w, $h)
        $form.Location = New-Object System.Drawing.Point(($work.Left + [int](($work.Width - $form.Width) / 2)), ($work.Top + [int](($work.Height - $form.Height) / 2)))
        $form.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)   # start at the top, not at the focused button
    }
}
$form.Add_Shown({ Set-FitToScreen })

if (-not $Theme) { $Theme = Get-AIAThemeSetting (Join-Path $Root 'scripts\control_panel.settings.json') }
Set-AIATheme $form (Test-AIADark $Theme)
Update-Statuses -SetChecks

if ($SnapshotPng) {
    $log.Text = "(The install log appears here.)"
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point(-4000, -4000)
    $form.ShowInTaskbar = $false
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    Save-AIAWindowShot $form $SnapshotPng
    "saved $SnapshotPng ($($form.Width)x$($form.Height), scale $Scale, text $AIATextScale, theme $Theme, dark $AIAIsDark)"
    $form.Close()
    return
}

$timer.Start()
[System.Windows.Forms.Application]::Run($form)

} catch {
    [void][System.Windows.Forms.MessageBox]::Show("The installer hit a problem:`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'AI Audio', 'OK', 'Error')
}
