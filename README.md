# AI Audio

> **This is an afternoon project, shared as-is.** It's a hobbyist's kit for making music, narration and voices with AI on your own computer, with no accounts and nothing sent to the cloud. There's no support, no roadmap and no promises. It's MIT-licensed: take it, change it, break it, build something better out of it.
>
> **To try it** (Windows with an NVIDIA graphics card): press the green **Code** button, choose **Download ZIP**, unzip it anywhere, and double-click `Install or repair AI Audio.bat`. You pick what to install; everything stays inside that one folder.
>
> **Mac or Linux:** see [other-systems](other-systems). Linux has an installer that hasn't been run on Linux yet. Mac has a guide and no installer.
>
> **Have an AI assistant that can read files?** Point it at this folder and ask it to read `CLAUDE.md`, then `VISION.md`. They explain what the kit is for and how to rebuild or adapt it, including on a different computer.

Everything runs locally on your own PC. Everything lives in this folder: tools, models, Python, and download caches.
**Start here: the "AI Audio" shortcut on your desktop** if you made one during install (or `AI Audio control panel.bat` in this folder). It opens one window with every tool:
- **Start** each tool, or drop files onto its button.
- **See what's running:** a status light per tool, plus a graphics-memory meter.
- **Stop** one tool, or **Stop everything** to free the graphics card in a couple of seconds.
- **"Stop everything when this panel closes"** is on by default, so closing the panel cleans up too.
- **It lists only the tools that are installed.** The **Components** link opens the window for adding, repairing and removing tools: a tick means installed, and **Apply changes** makes it so. Removing a tool frees its disk space and keeps your own results, voices and settings.
- **Theme:** dark by default. The **Theme** link switches between Dark, Light and Match Windows. Text follows your display scaling and Windows' *Text size* setting.

Stopping only ever touches programs from this folder. Your browser, games and anything else are left alone.

`Stop everything.bat` does the same clean-up without opening the panel, which is handy before launching a game.

The individual launchers are still in the **`launchers`** folder if you prefer them. Each sets up its own environment, so nothing needs installing system-wide.

**New here? Read [How to use each tool.md](How%20to%20use%20each%20tool.md)**: a beginner's walkthrough of every program, covering what to click, what to type and where results go. The panel's **How-to guide** link opens it too.

**[Tips and prompts.md](Tips%20and%20prompts.md)** collects music prompts worth keeping (dark synths, ancient instruments, low chant, no piano), voice and humming tips, and where to find add-ons. It's a living notebook, so add to it as things change.

**`My PC notes.md`**, if you keep one, is for what's specific to your own PC: its hardware, other software to leave alone, your tastes, and which of your own results to listen to. It's never put into a shared kit.

> **GPU note:** these tools take over the graphics card while they run. Close them before gaming. Each one frees the GPU when its window is closed. The drop-folder tools (Transcribe, Narrate) hand it back completely after 90 seconds idle, even with their window left open; their AI runs in a helper program that exits when there's nothing to do.

## What to use for what

| I want to… | Launcher | Where results go |
|---|---|---|
| Hum / sing / beatbox a part and get an instrument playing it | `Hum to track.bat` (drag a recording onto it) | `music\out` |
| Make a full song, or restyle one ("reggae version") | `ACE-Step (music).bat` (best sound) or `ACE-Step (music, fast).bat` | `tools\ACE-Step-1.5\gradio_outputs` |
| Pull a song apart into vocals / drums / bass / other | `Separate stems (…).bat` or `Separate vocals.bat` | `music\stems` |
| Sound like someone else **while keeping my own delivery** | `Applio (voice changer).bat` | shown in the app |
| Clone a voice from a short clip and have it read text | `ComfyUI (voices).bat` | `tools\ComfyUI\output` |
| Narrate a document, with subtitles (and optionally a video) | `Narrate.bat` / `Narrate to video.bat` | `narrate\out` |
| Turn a whole book into an audiobook with chapters | `Abogen (audiobooks).bat` | chosen in the app |
| Transcribe audio/video, split by speaker | `Transcribe.bat` | `transcribe\out` |

The drop-folder tools (Transcribe, Narrate) work two ways:
- **Double-click** to watch their `in` folder. Drop files into it; finished files move to `in\done`.
- **Drag files onto the launcher** to process just those files.

---

## The tools

### Hum to track: hum, sing or beatbox → instrument
Drag a recording onto `Hum to track.bat`. A phone voice memo is fine. It asks what the recording is:

- `this is the melody` → a synth lead. **Never a piano unless you type "piano".** Name an instrument to change it, from about 60:
  - ancient: `duduk`, `ney`, `santur`, `lyre` / `chang`, `oud` / `setar`, `kamancheh`, `temple bells`, `gregorian chant` (a low male choir sings it)
  - synth: `dark pad`, `drone`, `sweep pad`, `synth lead`
- `this is the bass line` → a synth bass, moved down into the bass range. Also: `slap bass`, `upright bass`.
- `this is the beat` → beatbox becomes kick / snare / hi-hat on a drum kit. Also: `ritual frame drums` (big ritual drums), `808 kit`, `electronic`, `jazz`, `rock`.
- `these are chords` → a warm pad that keeps every note, for recordings with several notes at once.

For each recording you get three files:
- a **.mid**, editable in any music program;
- a **.wav** of the instrument;
- a **…_with_original.wav** with your recording underneath, for checking.

It nudges off-key notes into the detected key and fixes octave slips. To turn those corrections off, use `--keep-chromatic` and `--no-transpose`.

To snap the timing to a grid, run it from a terminal with `--bpm 90`.

**For a produced version:** open ACE-Step, load the .wav as the Source Audio (Remix mode), and describe the style you want.

### ACE-Step 1.5: music generation
- **Two launchers, same app.** Run only one at a time; both use the same address.
  - `ACE-Step (music).bat` uses the **XL (4B) music model**: the best sound, but somewhat slower. On 16 GB it runs at 8-bit and steps off the card while the planner thinks.
  - `ACE-Step (music, fast).bat` uses the 2B model, for quick idea testing.
  - **Other models can be added** with one command (see the notes at the top of `setup\install.ps1`). The one most worth having is **XL SFT**: the same big model, run for 50 steps where the fast version takes 8. Its makers call it their highest-quality, most detailed model, and it's several times slower. To use it, start `ACE-Step (music).bat`, open the app's settings, choose `acestep-v15-xl-sft` under **Main Model Path**, and load it.
  - Both use the 1.7B planner. That's the largest ACE-Step allows on a 16 GB card; the 4B planner needs about 12 GB on its own.
- **Text → song:** describe the style, add lyrics or `[Instrumental]`.
- **Cover:** restyle existing audio, e.g. *"reggae, one-drop drums, skank guitar"* over a song.
  - Higher *cover strength* follows the original's structure more closely.
  - It does **not** keep the melody note for note. Its developers say so too.
  - **Tested:** at strength 0.5, a dark synth track became reggae with the same chords and tempo and a completely different sound.
  - **Hum → produced track:** feed a hum-to-track .wav in as the source. It keeps the melody's shape only loosely, so for exact notes keep the MIDI.
- **Repaint:** regenerate just one section of a song.
- **Add backing music to a vocal (Vocal2BGM):** give it a vocal and it builds the accompaniment.
- **Extract / lego / complete modes:** these need the `acestep-v15-base` model. It is already downloaded; switch to it in the UI's model settings.
- **Settings:** in `tools\ACE-Step-1.5\.env`. The GPU-related settings (offload, memory) are auto-detected for your card.
- **How long things take** (measured on a 16 GB card, 90 seconds of music with the planner on):

  | | Start-up | First song | After that | Peak graphics memory |
  |---|---|---|---|---|
  | XL launcher | about 1.5 min (3.5 min the very first time) | 61 s | 23–26 s | 15.6 GB of 16 |
  | Fast launcher | about 1.5 min | 16 s | 14 s | 13.6 GB |

  XL runs close to the card's limit, so close other GPU-hungry apps (games, streaming or recording tools) before using it.

### Stem separation
- **4 stems** uses Demucs (htdemucs_ft): vocals, drums, bass, other.
- **Vocals** uses a BS-RoFormer model and gives the cleanest vocal / instrumental split. It's also the best way to get a clean reference clip for voice cloning.
- The models are already downloaded into `models\separator`.
- A 90-second song takes about 15–25 seconds on the GPU.
- One harmless warning line appears: "CUDAExecutionProvider not available in ONNXruntime". It only affects a different family of models the launchers don't use; separation itself runs on the GPU.

### Applio: speech-to-speech voice conversion (RVC)
This route keeps **your** timing, accent and inflection, and changes only the voice's sound. You perform; it re-voices.

1. **Train tab:**
   - Give it 10–30 minutes of clean speech from the target voice. Run `Separate vocals` first if the audio has music under it.
   - **Measured on a 16 GB card**, with 100 seconds of audio:
     - Preparing the audio and extracting features: about a minute.
     - Training warm-up: about 1.5 minutes.
     - Each training round (epoch): about 5 seconds.
   - Rounds get longer in proportion to how much audio you give it, roughly a minute each for 20 minutes of audio.
   - A good model usually needs a couple of hundred rounds, so budget one to a few hours.
2. **Inference tab:** pick the model and convert your recording. A 12-second clip converts in about 25 seconds.

Notes:
- Ready-made `.pth` + `.index` voice models go in `tools\Applio\logs\<model name>\`.
- Applio refuses to start from a folder with a space in its path. The launcher works around this by giving it a temporary drive letter (B: or the next free one) while it runs.
- There is a real-time tab. Using it with Discord or games would also need a virtual audio cable driver, which isn't installed.

### ComfyUI (voices): voice cloning text-to-speech and more
If you already have a ComfyUI (for images, say, or through Stability Matrix), this is a separate one. It runs on **port 8189** instead of the usual 8188, so the two never clash.

Open **Workflows** in the left sidebar; ready-made graphs are numbered 1–8:
1. Clone a voice (ChatterBox). A 10–30 s clip is enough.
2. Voice changer (RVC or ChatterBox).
3. Expressive long-form and multi-speaker (VibeVoice). Good for natural, acted delivery.
4. Emotion-controlled cloning (IndexTTS-2).
5. Narrate a subtitle file (SRT).
6. Clean up a voice recording.
7. Design a new voice from a description.
8. Train an RVC voice model.

Engine models download the first time a workflow uses them, so the first run is slow.
- **Already downloaded:** ChatterBox and VibeVoice 1.5B.
- **Download on first use:** the others (IndexTTS-2, the voice designer, and so on), a few GB each.

**Your reference voices** go in `tools\ComfyUI\models\voices\`. Clips there show up in the voice pickers. Or load a clip with a *Load Audio* box, as workflow 1 does.

**Speed, measured:**
- A sentence or two of cloned speech takes about 8 seconds once the engine is loaded.
- Converting a 12-second clip into another voice takes about 19 seconds.

More example graphs from the voice suite are under the **Templates** menu.

### Narrate: document → natural narration + subtitles
- **Reads:** .txt .md .docx .pdf .epub .html. PDFs have page numbers and running headers stripped.
- **Settings:** `narrate\settings.json` (created on first run):
  - **voice:** either a voice clip from `voices\reference` or a Kokoro preset.
    - **A clip:** `wise_old_narrator` is the designed narrator voice. Put your own `NAME.wav`, plus `NAME.txt` with its exact words, in that folder to use it too.
    - **A Kokoro preset:** e.g. `bm_george`, `bm_fable`, `am_michael`, `af_heart`. Mix two with a comma.
  - **clone_engine** (clips only): `vibevoice` (default; unhurried storyteller pace, about real time), `chatterbox` (about real time) or `qwen3` (about 3× slower).
  - **speed** (Kokoro only), **audio format**, **make_video**.
- **Video:** `Narrate to video.bat` also makes an MP4 with burned-in subtitles. Put a picture at `narrate\background.jpg` to use it as the backdrop.
- **Speed:**
  - Kokoro presets: about 4–16× faster than real time.
  - Voice clips: much slower. They run through ComfyUI, which Narrate starts in the background if it isn't open and stops again when done.
- **Subtitle timing:** Kokoro times subtitles word by word; voice clips time them sentence by sentence.

### Abogen: audiobooks
Desktop app for whole books: chapter detection, M4B audiobooks with chapters, and subtitle files.
- It uses the same Kokoro voices.
- Non-English books may need espeak-ng, a Windows installer from the espeak-ng GitHub releases. It isn't installed.
- Use the launcher (the desktop app). Abogen's `abogen-cli` and `abogen-web` commands start a web server that other devices on your network can reach.

### Transcribe: who said what
WhisperX (large-v3) with word-level timing, plus speaker detection. For each file you get:
- `.txt`: paragraphs labelled *Speaker 1 / Speaker 2…*
- `.srt`: subtitles labelled by speaker
- `.json`: everything, word by word

Options:
- If you know how many people are talking, `--speakers 3` helps.
- `--model large-v3-turbo` is faster.
- **Better speaker separation (optional):** create a free Hugging Face account, accept the terms of `pyannote/speaker-diarization-community-1`, make a *read* token, and paste it as the only line of `models\huggingface\token`. Transcribe then uses pyannote automatically; without the token it uses the offline engine.

---

## Test results (November 2026)
Every tool was run for real when this kit was built, on a 16 GB graphics card, and all ten launcher files were started.

The test inputs in `samples\` are synthetic: Windows' built-in voices and computer-made hums and beats. So these results prove each tool works and does the right thing; they don't measure how good it sounds. Judge quality with your own recordings and your own ears.

| Tool | Result |
|---|---|
| Transcribe | ✅ A two-person dialogue split correctly into 2 speakers, and a monologue came out as 1. Word-accurate on every clip tested, including a video (MP4). The drop folder works and releases the GPU when idle. |
| Narrate (+ video) | ✅ Document → MP3 + SRT + MP4, 4–16× faster than real time with presets. The designed narrator voice works through all three engines, including from the drop folder; Narrate starts and stops ComfyUI by itself. All six document types read correctly (.txt .md .docx .pdf .epub .html); PDF page numbers and headers, and web-page menus and footers, were left out. The drop folder works and releases the GPU when idle. |
| ACE-Step | ✅ Both launchers start and generate (timings above). Cover mode restyles songs. |
| Separate stems / vocals | ✅ Both launchers work. The vocal split pulled the chant out of a generated hymn. |
| Applio | ✅ The UI starts through its drive-letter launcher. A throwaway model trained and converted a female test voice into the male one: pitch went from 180 Hz to 91 Hz, against a 90 Hz target. |
| ComfyUI (voices) | ✅ Every add-on loads. Tested: ChatterBox cloning (word-perfect, pitch matched the reference), ChatterBox voice conversion, subtitle narration (each line spoken within 0.3 s of its cue), and VibeVoice expressive cloning (word-perfect). |
| Hum to track | ✅ **Melody:** all 19 notes of a test hum found, correct pitches, within 5 ms. **Beat:** all 32 hits of a test beat found and correctly sorted into kick / snare / hi-hat, within 1 ms. |
| Control panel | ✅ Started three tools from its buttons, including the fast ACE-Step. **Stop everything** stopped them all in 2 s and freed the 9 GB they held on the graphics card; the web browser was untouched. Closing the panel stopped the tools still running. A second panel doesn't open twice. `Stop everything.bat` works. |
| Abogen | ✅ The desktop app opens. A full audiobook conversion wasn't clicked through, but it uses the same Kokoro voices as Narrate. |

**The narrator voices** are in `voices\reference`: `wise_old_narrator` (Narrate's default) and two alternatives, `…_deeper` and `wise_old_scholar`.

**Not tested, because they need you:**
- The higher-quality speaker detection needs your Hugging Face token (see Transcribe).
- The real-time voice changer needs a virtual audio cable driver, which isn't installed.
- How good any of it sounds needs your ears.

**Measured on a reggae cover:** it kept the original's chord progression (0.75 harmony match over time, against 0.36 for an unrelated track) and its tempo, while becoming more than twice as bright and much more up-front in the stereo.

**The narrator voice:**
- Designed from a written description, so it isn't cloned from any real person.
- All six candidates read their script word-perfectly, at 81–101 Hz (deep). One that came out at 192 Hz was discarded.
- In Narrate, all three engines read the demo accurately and matched the voice's 90 Hz pitch. VibeVoice was the slowest, most unhurried reader (2.1 words a second) at about real-time speed; Qwen3 was about 3× slower.

**The prompt library:** 20 takes of five dark prompts were checked with the piano detector, and 16 were clean. The megacity prompt still produced a piano in 2 of its 4 takes, even with the negative prompt, so always make several takes of it.

## Moving, copying or sharing AI Audio
**It's portable.** Move or copy the whole folder anywhere: another drive, a USB disk, a different name.
- The first launcher you start afterwards, or the control panel, notices the move and fixes the tools for the new place by itself. It's offline and takes a few seconds; the first time can take a couple of minutes.
- To run the fix by hand: `setup\relocate.ps1`, or `setup\install.ps1 -Relocate`.
- Paths with spaces are fine. Avoid non-English characters in the folder path, because Applio refuses them.
- The desktop shortcut is the one thing outside the folder. It's updated automatically when the folder moves.
- **Tested:** a kit was unpacked, installed, renamed and started. It fixed itself in 2 seconds and Hum to track worked from the new place.

**Giving it to someone else:** run `setup\make_kit.ps1`. It writes two equivalent things into `dist\`:
- **`AI Audio Setup.ps1`** (about 4.5 MB): one file with the whole kit inside as readable text. That's every script, launcher, guide, prompt, the installer and its version locks, plus the three narrator voices.
  - They right-click it and choose **Run with PowerShell**.
  - It asks where to unpack. The default is an "AI Audio" folder next to the file, which is portable.
  - Then it opens the installer, where they tick the tools they want.
- **`AI Audio kit.zip`** (about 2 MB): the same files as a normal zip, for when an antivirus program distrusts the script. Unzip it and run `Install or repair AI Audio.bat`.
- **Neither contains** the tools, models, caches or anything you generated; the installer downloads the tools fresh.
- **Nothing about your PC goes in.** Keep personal notes (your hardware, other software, tastes) in `My PC notes.md`, which is never packed. To make the build refuse certain words, list them in `setup\private-words.txt`, one per line; that file stays behind too. Running the setup again over an existing kit updates the scripts and guides. It keeps their music, voices and settings, and saves a new copy of an edited prompt notebook alongside the old one.

## For anyone changing or rebuilding it
- **[VISION.md](VISION.md):** what the project is for and how it decides things.
- **`docs\components\`:** one page per tool. Each says what the tool does, where it comes from, exactly how the kit uses it, how to test it, and how to replace it if its project dies.
- **`CLAUDE.md`:** a one-page map for an AI assistant, saying which file to read for which task.

## Other systems
AI Audio was built and tested on Windows with an NVIDIA graphics card. The `other-systems` folder is for everything else:
- **Linux** (`other-systems\linux`): a terminal installer and launcher, `aia.sh`, that mirrors the Windows one and uses the same component list and version pins. It has **never been run on Linux**; its own Read me says what to expect.
- **Mac** (`other-systems\mac`): no installer. A guide to what runs on a Mac, what doesn't, and what to use in its place, written for you or for an AI assistant building the equivalent there.

## Reference
- **Disk:** about 80 GB with everything installed, 19 GB of it the ACE-Step XL model. Identical packages are shared between the tool environments.
- **Folder layout:**
  - `scripts\`: the drop-folder scripts, plus `env.bat` / `env.ps1`, which keep every download inside this folder.
  - `tools\<name>\.venv`: each tool's private Python environment.
  - `models\`: shared model caches.
  - `logs\`: install and test logs.
- **One list of components:** `setup\components.json` describes every component and every control-panel row. The Components window and the control panel both read it, so a tool added there shows up in both.
- **Install, repair, remove or rebuild:** `Install or repair AI Audio.bat` (or the panel's Components link) opens the Components window: tick components, and it downloads and configures them exactly as built here (pinned versions, all the fixes). Its header (`setup\install.ps1`) documents the whole project for AI assistants, including a "what to do if things go wrong" list.
- **Check a song for piano:** `scripts\piano_check.py` scores tracks for piano, organ, orchestra, synth, voices and ancient instruments:
  ```
  "tools\whisperx\.venv\Scripts\python.exe" scripts\piano_check.py music\out
  ```
- **Reinstall the music helpers only:** `scripts\install_music_tools.ps1`.
- **Control panel files:**
  - `scripts\control_panel.ps1`: the window.
  - `scripts\panel_core.ps1`: the tool list and the start/stop logic. Add a tool here and it appears in the panel.
  - `scripts\ui_theme.ps1`: the look shared by the panel and the installer window (themes, text size).
  - `scripts\control_panel.settings.json`: remembers the stop-on-close checkbox and the theme.
- **Advanced: scripting ComfyUI.** `scripts\comfy_run_workflow.py` runs a saved job on a running ComfyUI (voices), with ComfyUI's own Python.
  - Four ready, tested jobs are in `scripts\comfy_workflows\`: `tts_clone_chatterbox`, `voice_convert`, `srt_tts` and `tts_expressive_vibevoice`.
  - Example:
    ```
    "tools\ComfyUI\.venv\Scripts\python.exe" scripts\comfy_run_workflow.py scripts\comfy_workflows\tts_clone_chatterbox.json ref=myvoice.wav "text=Hello there"
    ```
  - Other overrides: `source=`, `srt=`, `prefix=`, `seed=`.
  - To script a workflow of your own, save it in ComfyUI with *Workflow → Export (API)*.
- **Voices of real people:** cloning them is fine for private fun. Publishing it, or using it commercially, runs into right-of-publicity law.
