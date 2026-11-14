# How to use each tool

A beginner's walkthrough of every program in AI Audio: what to click, what to type, where the results go.
For what each tool *is*, see [README.md](README.md). For prompts and tips, see [Tips and prompts.md](Tips%20and%20prompts.md).

---

## First, the control panel
Double-click the **AI Audio** icon on your desktop. Everything starts from here.

- **Each row is one tool.**
  - The coloured dot shows whether it's stopped (grey), starting up (orange) or running (green).
- **Start** opens a tool.
  - The browser apps (ACE-Step, ComfyUI, Applio) take 1–3 minutes the first time, then open in your web browser by themselves.
  - Once a tool is running, the same button says **Open** and brings it back up.
- **Choose files…** or **drag files onto a button**, for the tools that work on files.
- **Results** opens the folder where that tool saves its work.
- **Stop** closes one tool. **Stop everything** (red, bottom left) closes them all and frees the graphics card in a couple of seconds.
- **Leave "Stop everything when this panel closes" ticked.** Closing the panel then cleans up for you, which is good before gaming.
- **Graphics memory** (top) shows how full the card is. Windows and your other apps use about 4–6 GB on their own. Run **one big tool at a time**.
- **Only installed tools are listed.** Add or remove one and the list follows within a few seconds.
- **Components** (bottom) opens the window for adding, repairing and removing tools:
  - A tick means installed. Tick what you want, untick what you don't, then click **Apply changes**.
  - **Graphics memory** (top) shows what it found on your PC. It assumes 16 GB if it can't tell, and you can change it. Tools too big for the chosen size are still listed, but unticked, with a note saying what they need.
  - **Quick picks:** **Recommended** ticks the kit's suggested line-up, **Select all** and **Select none** do what they say. You can still tick or untick anything afterwards.
  - Before removing anything it shows what will go and how much space that is, and asks first.
  - Removing a tool never deletes your own results, voices, trained voice models or settings.
  - **Repair ticked** puts the ticked tools back to their tested versions.
- **Theme** (bottom right) switches the look. Each click moves on to the next: **Dark** (the default), **Light**, then **Match Windows**, which follows your Windows colour setting and changes along with it. The installer window uses the same choice.
- **Text too small or too big?** The windows already follow your display scaling. They also follow Windows' own text size: *Settings → Accessibility → Text size*. Reopen the panel after changing it.

Each tool also opens a small black window (minimized on the taskbar). That's the engine; you can ignore it. Closing it stops that tool.

---

## ACE-Step: making music
Start **ACE-Step music (best sound)**, or **(fast)** to try ideas quickly. It opens a page called **ACE-Step V1.5 Playground** in your browser.

### The four modes (buttons near the top, "Generation Mode")
| Mode | Use it to… |
|---|---|
| **Simple** | Describe a song in a sentence; it writes the details for you |
| **Custom** | Write the exact style description and lyrics yourself (most control) |
| **Remix** | Restyle an existing song, such as your track redone as dark ritual music |
| **Repaint** | Regenerate just one section of a song |

### Your first song (Custom mode)
1. Click **Custom**.
2. In **Music Caption**, paste a description, for example from [Tips and prompts.md](Tips%20and%20prompts.md):
   > pitch-black sacred drone, Gregorian monks and Russian Orthodox basso profundo chanting low, massive analog synth drones, sub-bass swells, no drums, cavernous stone reverb, synths and voices only, 50 BPM
3. In **Lyrics**, type `[Instrumental]` for no singing, or put chant words under a `[Chant]` line.
4. Open **⚙️ Optional Parameters** to set:
   - **Audio Duration (seconds):** 60–180 is a good range.
   - **Batch Size:** 2–4 versions at once.
   - **To keep it dark and unhurried, not jaunty:** untick **BPM Auto** and **Key Auto**, then set a slow BPM (60–72) and a **minor** key such as `D minor`. Tempo or key written only in the caption is just a hint, and the planner may ignore it.
5. Click **🎵 Generate Music**.
   - The best-sound version takes about 25–60 seconds per song on a 16 GB card.
6. The results appear under **🎵 Results** as players (Sample 1, Sample 2…). Listen and click **💾 Save** on the ones you like.

### Keeping the piano out
- Open **⚙️ Settings** (top) → **🤖 LM Generation** → **LM Negative Prompt**, and replace `NO USER INPUT` with:
  `piano, grand piano, electric piano, Rhodes, keys, keyboard, organ, orchestra, strings, brass`
- Leave **Think** ticked, next to the Generate button.
- The full list of piano-dragging words to avoid is in Tips and prompts.md.

### Remix (restyle a song)
1. Click **Remix**.
2. Drop the song into **Source Audio**.
3. In **Music Caption**, describe only the *new* style.
4. Set the two sliders:
   - **Cover Strength (Melody Retention):** about 0.5 keeps the chords and tempo; lower reinvents more.
   - **Remix Strength:** how far the sound moves from the original.
5. Click **🎵 Generate Music**.

### Simple mode (lazy and fun)
Type a sentence into **Song Description**, such as "a tyrant's lullaby played on ancient instruments and synths". Click **Create Sample**; it fills in a caption and lyrics. Check them, then **🎵 Generate Music**.

### Good to know
- **Variations of a song you love:** **⚙️ Settings → 🎛️ DiT Diffusion** has a **Seed** box; untick **Random Seed** and reuse a number to get variations.
- **Results are saved** in `tools\ACE-Step-1.5\gradio_outputs` (the panel's **Results** button opens it).
- **Feed it your hum:** use the "Hum to track" .wav as **Source Audio** in Remix.

---

## ComfyUI voices: cloning and designing voices
Start **ComfyUI voices**. Your browser opens a page with a big dark canvas.

### Finding your way around
- **The canvas** is made of **boxes (nodes)** joined by **wires**. Each box does one job, for example "load a voice clip", "speak this text" or "save the audio". Data flows along the wires, left to right.
- **Scroll** to zoom. **Drag the empty background** to move around. **Drag a box's title** to move it.
- **The left sidebar** has a **Workflows** button. Open it to see the ready-made graphs:
  1. Clone a voice (ChatterBox)
  2. Voice changer (RVC or ChatterBox)
  3. Expressive long-form and multi-speaker (VibeVoice)
  4. Emotion-controlled cloning (IndexTTS-2)
  5. Narrate a subtitle file (SRT)
  6. Clean up a voice recording
  7. Design a new voice from a description
  8. Train an RVC voice model
- **The blue Run button** (top right) runs the graph. Results appear in a **player box** on the canvas and are saved in `tools\ComfyUI\output`.

### Make a voice say something (workflow 1)
1. Open **Workflows → 1 - Clone a voice (ChatterBox)**.
2. Find the box with a big text field and replace the text with what you want said.
3. Choose who says it. In a **Character Voices** box, pick a voice from its **voice_name** list.
   - Your own clips, and the designed narrator voice, show up there. They live in `tools\ComfyUI\models\voices`.
4. Click **Run**. The first run downloads the engine (a few GB), so wait a minute. After that it's a few seconds per sentence.
5. Play the result in the preview box. Right-click the player to save it, or find it in `tools\ComfyUI\output`.

### Design a brand-new voice (workflow 7)
1. Open **7 - Design a new voice from a description**.
2. In the **Voice Designer** box:
   - **voice_instruction:** describe the voice. Age, pitch, texture, accent, pace, mood, as in "an elderly English man, deep and warm, slightly gravelly, speaks slowly with gentle authority".
   - **reference_text:** what it should say: 10+ seconds, with a question in it.
3. Click **Run** and listen. Not right? Change the description or the **seed** number and run again.
4. When you love it, the **Save Character Voice** box stores it under the name you give it, so it appears in every voice list from then on.

### If something goes wrong
- **A box turns red:** something it needs is missing. Read the message; usually an input isn't connected or a file isn't chosen.
- **"Missing nodes" message:** click **Manager → Install Missing Custom Nodes**, then restart from the panel.
- **Out of memory:** close the other big tools (Stop in the panel) and run again.

---

## Applio: become another voice (keeping your own acting)
Applio swaps the *sound* of a voice but keeps your timing, accent and emotion. You perform, it re-voices. Start **Applio voice changer**.

The left sidebar has sections: **Voice** (Convert Audio, Realtime, Text to Speech), **Models & Training** (Models, Training, Voice Blender…), **Tools & Extras**, and **System**.

### Converting a recording
1. **Get a voice model.**
   - Train one (below), or open **Models**, paste a link into **Model Link** and click **Download Model**.
   - A voice model is a `.pth` file plus a `.index` file.
2. Open **Convert Audio**.
3. Pick the voice in **Voice Model**; its **Index File** fills in. Click the refresh arrow if a new model doesn't appear.
4. Drop your recording into **Upload Audio**.
5. Set **Pitch:** 0 for the same range, about **+12** for male to female, about **-12** for female to male.
6. Click **Convert** and listen to the result. It's saved in `tools\Applio\assets\audios`.

### Training your own voice model
1. Collect **10–30 minutes** of clean speech from one voice: no music, no echo. Run songs through **Separate vocals** first.
2. Open **Training** and type a **Model Name**.
3. Point **Dataset Path** at the folder of clips (or use **Upload Audio Dataset**), then click **Preprocess Dataset**.
4. Click **Extract Features**.
5. Set **Total Epoch** to about 200 for a start, then click **Start Training**.
   - Each round takes a few seconds per minute of audio, so expect one to a few hours.
   - You can stop anytime with **Stop Training**.
6. Click **Generate Index**. The model now shows up in **Convert Audio**.

While Applio runs, a temporary drive letter (usually B:) appears in Explorer. That's normal; it's how Applio copes with the space in "AI Audio".

---

## Narrate: documents read aloud
1. In the panel, click **Watch folder** on **Narrate** (or **Narrate to video**). The `narrate\in` folder opens.
2. Drop in a document: .txt, .md, .docx, .pdf, .epub or .html.
3. Wait. When it's done, the file moves to `in\done`, and the results are in `narrate\out`:
   - **an .mp3** of the narration
   - **an .srt** subtitle file
   - **an .mp4** video with the subtitles burned in (the **to video** version)
   - **Video background:** put a picture at `narrate\background.jpg` to use it behind the subtitles.

**Choosing the voice:** open `narrate\settings.json` in Notepad and change `"voice"`:
- **`"wise_old_narrator"`** (the default): the designed wise-old-man voice, spoken through ComfyUI. The most human-sounding option.
  - Hear it first: play `voices\reference\wise_old_narrator.wav`.
  - Alternatives: `"wise_old_narrator_deeper"` and `"wise_old_scholar"`.
  - `"clone_engine"` picks how it's spoken: `vibevoice` (default; unhurried, about real time), `chatterbox` (about real time) or `qwen3` (about 3× slower).
  - It takes about a minute longer to get going, because Narrate starts ComfyUI in the background. It closes ComfyUI again when done.
- **A preset voice:** fast, good quality. For example `bm_george`, `bm_fable`, `bm_lewis` (British men) or `am_michael`, `af_heart`.
- **Any clip of your own:** put `NAME.wav` (plus `NAME.txt` with the exact words spoken in it) into `voices\reference` and set `"voice": "NAME"`.

---

## Transcribe: who said what
1. Click **Watch folder** on **Transcribe** and drop in audio or video, or drag files onto the button.
2. Results in `transcribe\out`:
   - **.txt:** paragraphs labelled Speaker 1, Speaker 2…
   - **.srt:** subtitles
   - **.json:** everything, word by word

Tip: if you know how many people talk, the speaker split is better when you run it from a terminal with `--speakers 3`.

---

## Hum to track
1. Record yourself humming, singing or beatboxing (a phone voice memo is fine).
2. Drag the recording onto **Hum to track**. A black window asks what it is. Type something like:
   - `this is the melody`: a synth lead
   - `melody on a duduk`: also ney, santur, lyre, oud, kamancheh, chant
   - `this is the bass line`: a synth bass
   - `the beat, ritual frame drums`
   - `these are chords, dark pad`
3. Results in `music\out`:
   - **a .mid**, editable notes
   - **a .wav**, the instrument playing them
   - **a _with_original.wav**, to check it followed you

Hum on "doo" or "dah" rather than "mmm" for cleaner notes.

---

## Separate vocals / Separate stems
Drag songs onto the button. Results go to `music\stems`:
- **Separate vocals:** a vocals file and an instrumental file.
- **Separate stems:** vocals, drums, bass and "other".

Great for getting a clean voice clip to clone, or a backing track.

---

## Abogen: whole audiobooks
1. Start **Abogen audiobooks**.
2. Drag a book (.epub, .pdf, .txt…) onto its window.
3. Pick a voice under **Select voice:** and a **Speed:**.
4. Pick a subtitle style under **Generate subtitles:**.
5. Pick a format under **Output voice format:**. M4B makes an audiobook with chapters.
6. Pick a **Save location:**, then click **Start**.

Abogen uses the preset voices only (not the designed narrator). For the narrator voice, use **Narrate**.

---

## Moving the folder, or giving it to a friend
- **Moving:** just move or copy the whole AI Audio folder. The next time you start something, a black window says the folder has moved and fixes the tools for the new place. That takes a few seconds, and then the tool starts as normal.
- **Sharing:** run `setup\make_kit.ps1` (right-click → Run with PowerShell). In the `dist` folder you get **AI Audio Setup.ps1**, one file with everything except the big downloads.
  - Your friend right-clicks it and chooses **Run with PowerShell**.
  - They pick a folder, and the installer opens.
  - If their antivirus complains about the script, give them **AI Audio kit.zip** from the same folder instead.

## When something goes wrong
| Problem | Fix |
|---|---|
| Nothing seems to happen after Start | Big tools take 1–3 minutes to load. Watch the dot: orange means still starting. |
| "Out of memory" or a crash | Click **Stop everything**, then start just the one tool you need. Close games first. |
| The browser didn't open | Click **Open** in the panel once the dot is green. |
| A tool seems stuck | **Stop** it in the panel and start it again. |
| Files in `in\failed` | Open the `.error.txt` next to the file; it says what went wrong. |
| Anything stranger | Ask Claude in this folder. The installer's notes (`setup\install.ps1`) and `CLAUDE.md` explain how everything is built. |
