# Tips and prompts

These are living notes: prompts worth keeping, tips that worked, and where to find add-ons. Add to them, cross things out, and rewrite them as the setup changes.
For which launcher does what, see [README.md](README.md).

---

## Writing music prompts (ACE-Step)
- **The examples here share one palette: dark analog synths, ancient instruments and low chant, with no piano.** That's one person's taste, kept because it shows how to steer these models in detail. The method works for any style; swap in your own.
  - To see how a detailed prompt is put together, read "Anatomy of a detailed prompt" just below.
  - If a result sneaks in an instrument you didn't want, "Keeping the piano out" shows how to keep any instrument out.
- **Made-up genres are fine.** ACE-Step's planner turns loose descriptions into a proper music brief before the music model starts. Try "syntho-cosmic-tyrant" and see what happens.
- **Mix the weird with two or three real anchors** if you want some control: a tempo (`66 BPM`), a few instruments, a mood.
- **Words it understands well, in this palette:**
  - **synths:** analog synth drone, deep synth pads, modular synth pulse, glassy synth arpeggios, sub-bass, Moog-style bass
  - **ancient instruments:** frame drums, daf, war drums, bronze gongs, temple bells, ram's horn, lyre, harp, double-reed pipe (duduk), reed flute (ney), santur, setar, oud, kamancheh
  - **voices:** Gregorian chant, Byzantine chant, Russian Orthodox choir, basso profundo, low male chant, a cappella
  - **moods and spaces:** ominous, solemn, sacred, ritual, stone temple reverb, cavernous, vast
- **Rare words are hit or miss** ("oktavist", "cannonade"). Describe the sound as well as naming it.
- **Contradictions blend or one side wins.** "Tyrant" + "sleep" might give you a villain's lullaby.
- **Make four versions, keep the best.** The same prompt gives very different results each time.
- **Found one you love? Note its seed number.** Rerun with the same seed and a tweaked prompt for variations on that track.
- **Change one word at a time** to learn what each word does.
- **`[Instrumental]` in the lyrics box** means nobody sings. For sleep music, also pick a longer length.
- **Let a bigger AI write the brief.** Give a wild idea to Claude, or to a local model in Ollama, and paste the detailed version into ACE-Step. It beats what the built-in planner can do on a 16 GB card.
- **XL vs fast:** use `ACE-Step (music, fast).bat` to try ideas quickly, then rerun the winners in `ACE-Step (music).bat` for the best sound.

### Anatomy of a detailed prompt
A music model responds to concrete things it can hear: instruments, textures, spaces, tempo. It responds poorly to instructions ("make it better") and to anything that needs judgement ("tasteful"). A detailed prompt gives it one item from each of these, in roughly this order:

| Part | What to write | In the example below |
|---|---|---|
| **Style and era** | A genre or two, and a period if it matters | "retro-futuristic 1980s analog synthesizer score" |
| **The picture** | The scene or subject, in a few words | "vast interstellar exploration, awe and wonder at an immense galaxy" |
| **Instruments** | Named, with a word on how each is played | "slow shimmering arpeggiated sequencer patterns, lush warm analog pads, CS-80 style brass synth swells, deep sub-bass drone" |
| **Voices** | Who sings and how, or that nobody does | "distant wordless choir pad" |
| **Space** | The room and the distance | "huge spacious reverb" |
| **Mood** | Two or three feeling words | "majestic, mysterious" |
| **Limits** | What the palette is restricted to | "synths only, instrumental" |

The whole example, which is "Galaxy map" from further down:
> retro-futuristic 1980s analog synthesizer score, vast interstellar exploration, awe and wonder at an immense galaxy, slow shimmering arpeggiated sequencer patterns, lush warm analog pads, CS-80 style brass synth swells, deep sub-bass drone, distant wordless choir pad, huge spacious reverb, nebulae and starlight, majestic, mysterious, synths only, instrumental

**What goes outside the prompt:**
- **Tempo, key and time signature** go in their own fields (72 BPM, D minor, 4 for this one). Written in the prompt they're only hints.
- **Things to keep out** go in the LM Negative Prompt, never in the prompt itself. Naming an instrument, even after "no", tends to bring it in.
- **Lyrics or `[Instrumental]`** go in the lyrics box. Section tags such as `[Verse]`, `[Chorus]` or `[Chant]` shape the structure.
- **A reference track** carries what words can't: the sound of a mix, a voice or an era.

**Direction that works, and direction that doesn't:**
| Works | Doesn't |
|---|---|
| "slow evolving pads", "plucked", "bowed", "muted" (how it's played) | "play it with feeling" |
| "far away", "close and dry", "cathedral reverb" (where it is) | "good mix", "professional" |
| "sparse, long silences between phrases" (how full it is) | "not too busy" |
| "builds to a climax in the last third" (shape over time) | "make it interesting" |
| A named real instrument or synth | A vague family ("some strings") |

**For a voice instead of music,** the same idea applies. Describe what can be heard: age, pitch, texture, accent, pace and mood. The narrator description under "Voice tips" is a worked example.

### Keeping it dark, not jaunty
**Tempo and key written in the prompt are only hints**, so the planner is free to pick something brighter. Lock them in ACE-Step's own fields instead:
1. Open **⚙️ Optional Parameters**.
2. Untick **BPM Auto** and set the **BPM**: 60–72 for slow and vast, 110–125 for battle music.
3. Untick **Key Auto** and type a **minor** key, such as `D minor`, `A minor` or `C minor`. Major keys sound bright and happy.
4. Untick **TimeSig Auto** and set `4`. Three- and six-beat feels tend to sway or bounce.

Also:
- **Add `happy, upbeat, cheerful` to the LM Negative Prompt** (see below).
- **For drones, don't ask for "pulsing" or "bouncing" parts.** Ask for "slow evolving" or "swelling" instead.

### Keeping the piano out
1. **Never write "piano" in the prompt, not even "no piano".** Music models tend to latch onto any instrument they see named, even with "no" in front.
2. **Avoid words that tend to drag a piano along:** cinematic, emotional, melancholic, sad, ballad, film score, soundtrack, neo-classical, lo-fi, new age, relaxing, meditation, hymn, and "ambient" on its own (say "dark ambient drone" instead). They're piano-heavy styles in general, so the model may add one.
3. **Watch out for piano-like instruments:** santur, hammered dulcimer, cimbalom and celesta are struck with hammers, just like a piano, and can sound like one. A santur in a prompt is a common cause of a "piano" that nobody asked for. Plucked (setar, oud, lyre, harp) and bowed (kamancheh) instruments are safe.
4. **Name the instruments you do want,** so the arrangement is already full. Ending with `a cappella` or `synths and ancient instruments only` also helps.
5. **Use the LM Negative Prompt:** in ACE-Step open **Settings → LM Generation → LM Negative Prompt** and paste:
   `piano, grand piano, electric piano, Rhodes, keys, keyboard, organ, orchestra, strings, brass section, acoustic guitar, happy, upbeat, cheerful`
   It steers the planner away from those words. It only works with **Think** ticked (the default) and LM CFG Scale above 1 (also the default).
6. **Still there?** Generate four and keep the clean ones. Or run the track through `Separate stems` and leave out the "Other" stem, where keyboards usually end up.
7. **Check a track for piano:** `scripts\piano_check.py` scores any song for piano, organ, orchestra, synth, voices and ancient instruments, and prints PIANO or clean. Run it with the Transcribe environment (see the README).

### Restyling a song (Remix mode)
- Load the song as **Source Audio**, choose **Remix**, and describe only the new style.
  - For example, dark-ancient: `dark analog synth drones, ritual frame drums, duduk lead, low monk chant, sub-bass, slow`
  - Or reggae: `roots reggae, one-drop drums, offbeat skank guitar, deep warm dub bassline, laid-back groove, instrumental`
- **Cover Strength (Melody Retention)** sets how much of the original survives:
  - **About 0.5:** keeps the chords and tempo while changing the whole sound. This was tested: a dark orchestral track came out as recognizable reggae.
  - **Lower (0.2–0.4):** looser and more reinvented. ACE-Step's own notes suggest about 0.2 for pure style transfer.
  - **Higher (0.7–1.0):** sticks closer to the original arrangement.
- **It keeps the shape of the melody, not the exact notes.** If the tune must stay exact, run your hum through hum-to-track first and keep the MIDI.
- **Hum → full production:** drag a hum onto `Hum to track.bat`, then load the resulting .wav in ACE-Step as the Remix source with a style prompt, at strength about 0.6.

### Making it feel vast and distant
Your ears judge distance from four clues, and each one has prompt words:

| Clue | Why it works | Prompt words |
|---|---|---|
| More echo than direct sound | Far away, you hear the room more than the instrument | `long natural reverb`, `echoing through enormous empty halls` |
| Softer treble | Air soaks up high frequencies over distance | `soft rolled-off highs`, `warm`, `muted` |
| Gentle attacks | Sharp edges blur at a distance | `gentle attacks`, `soft`, `swelling` |
| Small sources in a huge space | Vastness comes from a big room, not big instruments | `instruments small and far away`, `very wide stereo field`, `spacious` |

- **For music under visuals,** add `underscore`, `sparse`, `long silences between phrases` and `not busy`.
- **Fewer instruments means more space.** Cut the list if the result sounds crowded.
- **ACE-Step can't place sounds precisely.** These words nudge it; they don't control it.
- **To push it further afterwards,** open the result in Audacity (already installed):
  1. Add its **Reverb** effect with a large room and more "wet" than "dry".
  2. Gently cut the treble with an EQ above about 8 kHz.
  3. Leave it in stereo.

## Prompt library
Copy the caption into ACE-Step's **Music Caption** box (Custom mode). Where there are lyrics, they go in the **Lyrics** box. Every one of these is synths, ancient instruments and voices only.

Where a prompt lists **BPM / Key**, set those in **⚙️ Optional Parameters** with Auto unticked (see "Keeping it dark, not jaunty"). That's what makes them come out as written.

### Space synth: retro-futuristic sci-fi score
*In the spirit of late-2000s space-opera game scores (think the first Mass Effect): 80s-style analog synths, slow sequencer arpeggios, huge reverb, a sense of wonder and scale. ACE-Step doesn't know composers or games by name, so these describe the sound instead.*

**Galaxy map** (wonder and scale). BPM **72**, Key **D minor**, Time Signature **4**:
> retro-futuristic 1980s analog synthesizer score, vast interstellar exploration, awe and wonder at an immense galaxy, slow shimmering arpeggiated sequencer patterns, lush warm analog pads, CS-80 style brass synth swells, deep sub-bass drone, distant wordless choir pad, huge spacious reverb, nebulae and starlight, majestic, mysterious, synths only, instrumental

**Vigil** (alone among ancient stars). BPM **66**, Key **A minor**, Time Signature **4**:
> haunting ambient synth score, alone on an ancient dead world under alien stars, slow evolving analog pads, a lonely singing analog synth lead melody, soft gated synth pulse underneath, deep sub-bass, glassy shimmering textures, cavernous reverb, vast, yearning, slowly building to quiet grandeur, synths only, instrumental

This one drew a piano in 2 of 4 takes, so make four and keep the clean ones.

**Reaper attack** (epic and dangerous). BPM **120**, Key **E minor**, Time Signature **4**:
> epic dark synth battle score, driving pulsing analog synth bass ostinato, relentless sequencer arpeggios, huge distorted synth brass stabs, thunderous electronic drums and deep taiko hits, colossal sub-bass impacts, rising dread, heroic and menacing, wide stereo, synths and drums only, instrumental

Lyrics for all three: `[Instrumental]`.

**Words that pull toward this sound:** retro-futuristic, analog synthesizer, CS-80 style brass, sequencer arpeggios, warm pads, sub-bass, huge reverb, interstellar, nebulae, alien, ancient world, majestic, vast.

### The black liturgy
*Pitch-black sacred drone: monks and Orthodox basses chanting low under a wall of analog synth.* Set BPM **60**, Key **C minor**, Time Signature **4**. The first version, made without those, came out too bright.
> pitch-black sacred drone, Gregorian monks and Russian Orthodox basso profundo chanting low, massive analog synth drones, sub-bass swells, slow pulsing modular synth, bronze bells tolling far away, no drums, cavernous stone reverb, ominous, holy, ancient and futuristic, synths and voices only, 50 BPM

Lyrics (Latin, "Day of wrath, that day"):
```
[Chant]
Dies irae, dies illa
solvet saeclum in favilla
```

### Cannonade cosmic tyrant (war)
*A space emperor's armada: ancient war drums like cannon fire, synth thunder, a choir of giants.* Set BPM **72**, Key **C minor**, Time Signature **4**. Even then only about 1 take in 4 came out properly dark, so make several.
> dark synth and ancient ritual war music, cosmic tyrant, colossal frame drums and bronze war gongs like distant cannon fire, deep analog sub-bass impacts, distorted analog synth drones, low Russian Orthodox basso profundo choir chanting, ram's horn blasts, minor key, slow processional march, 72 BPM, menacing, building to a crushing climax

### Cannonade cosmic tyrant (for sleep)
*Falling asleep on a starship while the fleet fights three solar systems away.*
> dark drone, deep analog synth drones, distant muffled booms like thunder far away, low male voices humming a chant far off, very slow, no drums, 50 BPM, still, ominous but calm, for sleep

Lyrics: `[Instrumental]`

### Syntho-cosmic-tyrant, to sleep to
*The "weird plus anchors" example.*
> syntho-cosmic-tyrant, 60 BPM, deep analog synth drones, low monk chant far away, no drums, slow, for sleeping

Lyrics: `[Instrumental]`

### Neo-Babylonian, year 15,000: temple chant
*A chant to Marduk in a temple orbiting a dying star.* Set BPM **66**, Key **D minor**, Time Signature **4**.
> ancient Mesopotamian temple chant meets dark analog synths, year 15000, deep male chant over a low drone, ancient lyre, slow frame drums, double-reed pipe, bronze temple bells, deep analog synth pads, sub-bass swells, vast stone temple reverb, slow, reverent, ominous, dark, mysterious, minor key

This prompt often lands in the **Hijaz** scale: a major third with a flattened 2nd and 6th, the classic "ancient Middle East" sound. It's exotic and tense rather than cheerful. For plain dark minor, keep the minor-sounding takes. Earlier wording ("majestic", "Phrygian dominant") pulled it brighter.

Lyrics, a chant in real Akkadian ("Marduk, great lord / mighty king, king of Babylon"):
```
[Chant]
Marduk, belu rabu
sharru dannu, shar Babili
Marduk, belu rabu
```

### The silent megacity (ancient Iran, far future)
*A futuristic planet with ancient Persian bones. Set BPM **60**, Key **G minor**, Time Signature **4**. Towers so tall you can't see where they end, intact but untouched for a couple of hundred years. Dust, still air, no wind. Underscore for visuals that carry the scene: grand but subtly distant, sparse, meaningful.*
> vast dark ambient drone underscore, ancient Persian atmosphere, futuristic abandoned megacity of impossible scale, distant and spacious, very wide stereo field, instruments small and far away echoing through enormous empty halls, long natural reverb, soft rolled-off highs, gentle attacks, sparse and slow, long silences between phrases, kamancheh and ney melodies in Persian Shur mode, gentle plucked setar, low duduk drone, ancient chang harp, soft distant daf heartbeat, faint wordless low male chant far in the distance, deep analog synth drone and slow sub-bass swells underneath, weathered grandeur, still air, dust, awe, synths and ancient instruments only, 60 BPM

Lyrics: start with `[Instrumental]`. If you want the faint distant singer and he doesn't show up, try lyrics in Old Persian, the language of Darius's inscriptions. They mean "I am Darius, the great king, king of kings":
```
[Chant]
adam Darayavaush
khshayathiya vazraka
khshayathiya khshayathiyanam
```
Notes:
- Run this one in the XL launcher. Sparse, quiet music shows off the better sound.
- **This one is piano-prone.** In testing, 2 of 4 takes still had a piano despite the negative prompt. Make four and keep the clean ones.
- If it comes out too busy, delete the instruments you can live without; fewer instruments means more space.
- For more distance afterwards, see "Making it feel vast and distant" above.

### Old-world sacred dark
*The real roots of "epic and hellish", minus the organ: chant, bells and stone.*
> Gregorian chant, Byzantine ison drone, Russian Orthodox basso profundo, Dies irae, bronze bells tolling, a cappella male voices over a deep analog synth drone, vast stone cathedral reverb, slow, solemn, awe-inspiring

### Oktavist choir (contrabass voices)
*Russian Orthodox-style basso profundo singers, an octave below a normal bass, and nothing else.* Set BPM **60**, Key **D minor**, Time Signature **4**. All four test takes came out dark.
> Russian Orthodox oktavist choir, basso profundo, extremely deep male voices, a cappella, sub-bass vocal drone, stone cathedral reverb, slow

Expect a convincingly deep bass choir, not the true rattling floor below it; these models are weakest at extremes. To go lower:
1. Pull the vocal out with `Separate vocals.bat`.
2. Pitch it down in Applio. RVC moves pitch without changing the voice's character, so it drops without sounding slowed down.

### 1983 analog synth horror
*In the spirit of the Beyond the Black Rainbow soundtrack: all synth. Best heard with the lights off and something red glowing.*
> 1983 analog synthesizer score, retro sci-fi horror, slow hypnotic arpeggios, warm Moog-style bass drones, glassy pads, tape hiss and wobble, cold and ominous, dreamlike, minimal, analog synths only, 70 BPM, instrumental

Lyrics: `[Instrumental]`

*(Add new favorites here: name, one-line idea, caption, lyrics, and a note on what worked.)*

---
## Voice tips
- **Clean reference audio matters more than anything.** One voice only, no music, no echo.
  - Voice cloning in ComfyUI: 10–30 seconds is enough.
  - Training an RVC model in Applio: 10–30 minutes of speech.
  - Run songs or noisy clips through `Separate vocals.bat` first.
- **Applio keeps your delivery and changes only the sound of the voice,** so act it out. Use its Pitch setting when crossing genders: about +12 for male to female, about −12 for female to male.
- **For acted, natural delivery from text,** try ComfyUI workflow 3 (VibeVoice) or 4 (IndexTTS-2, which has emotion control).
- **The wise old narrator** (`voices\reference\wise_old_narrator.wav`) was designed in ComfyUI workflow 7 from this description:
  > An elderly English man in his late seventies. A deep, warm, slightly gravelly voice with a soft rasp of age. Refined southern English accent. He speaks slowly and gently, with calm authority and kindness, like a wise old storyteller by the fire. Thoughtful pauses between phrases, a low resonant pitch, never rushed, a faint smile in his voice.
  - The delivery (slow, pausing, gentle authority) is part of the description, and the voice carries it into everything it reads.
  - To make your own, describe age, pitch, texture, accent, pace and mood the same way.
  - Try a few **seeds**; each gives a different voice from the same description.
  - Save the one you like with **Save Character Voice**.
- **Real people's voices:** fine for private fun. Publishing them, or using them commercially, runs into right-of-publicity law.

## Hum-to-track tips
- **Hum on "doo" or "dah"** rather than a smooth "mmm"; separated syllables give cleaner notes.
- **Record close to the mic** in a quiet room. A phone voice memo is fine.
- **Example prompts:**
  - `this is the melody`: a synth lead, the default
  - `this is the melody, on a duduk`: also ney, santur, lyre, oud, setar, kamancheh
  - `low gregorian chant melody`: a low male choir sings your line
  - `bass line, synth bass`
  - `these are chords, dark pad`: also drone, sweep pad, metallic pad
  - `the beat, ritual frame drums`: big ritual drums (also: 808 kit, electronic)
- **No piano unless you type "piano".** The defaults are synth lead, warm pad and synth bass.
- **The `_with_original.wav` file** plays your recording under the instrument, so you can check it followed you.
- **To keep exactly what you sang,** run it from a terminal with `--keep-chromatic` (no snapping off-key notes into the key) and `--no-transpose` (no octave changes).
- **To snap the timing to a grid,** add `--bpm 90` (use your song's tempo).
- **For a produced version,** load the .wav into ACE-Step as source audio (Remix mode) and describe the style.

---

## Finding add-ons

| Want | Search for | Where it goes |
|---|---|---|
| New ComfyUI abilities | "ComfyUI custom nodes" plus what you want | ComfyUI: **Manager** button → search → Install |
| Ready-made ComfyUI setups | "ComfyUI workflow" plus a topic (voice clone, lip sync, Wan 2.2) | Drag the .json file onto the ComfyUI canvas |
| Character voices for Applio | "RVC v2 model" plus the character's name | Applio's Download tab, or `tools\Applio\logs\<name>` |
| Music styles for ACE-Step | "ACE-Step 1.5 LoRA" | ACE-Step's LoRA setting. It can also train one from about 8 songs. |
| More narration voices | "Kokoro voices list" | The voice name in `narrate\settings.json` |
| Better instrument sounds | "free SoundFont sf2" | Ask Claude to add a switch to hum-to-track |
| Other ways to split songs | "UVR models" (Ultimate Vocal Remover) | The stem separator can use most of these |

**Where to look:**
- Models: Hugging Face and Civitai.
- Workflows: comfy.org.
- Reddit: r/comfyui and r/StableDiffusion.
- YouTube: "Applio tutorial", "ACE-Step 1.5 tutorial", "ComfyUI TTS Audio Suite".

**Words worth knowing:**
- **Checkpoint / model:** the main AI file.
- **LoRA:** a small add-on that teaches a model a style or voice.
- **Custom node:** a ComfyUI plug-in.
- **Workflow:** a saved ComfyUI graph.
- **Reference audio:** the voice clip being cloned.
- **Stems:** a song split into separate parts.
- **Diarization:** working out who spoke when.
- **Quant / quantized:** a compressed copy of a model, stored in fewer bits.

**ComfyUI basics:**
- A red box usually means a missing input, or a missing add-on (Manager → **Install Missing Custom Nodes** fixes that).
- Ctrl+S saves your workflow.
- Drag any workflow file onto the canvas to load it.

---

## Keeping things running well
- **One GPU tool at a time.** Graphics memory fills up fast. On an "out of memory" error, close the other tools' black windows.
- **Keep a tool open for the whole session** rather than closing and reopening it. ACE-Step and ComfyUI keep their models in RAM after first use, so switching back is quick.
- **Close everything before gaming.** Each tool frees the graphics card when its black window closes. Transcribe and Narrate also free it after 90 seconds idle.
- **Free up graphics memory before big jobs.** Desktop apps can hold several GB of the card (the browser, game launchers, streaming tools), so closing the ones you don't need gives the AI more room.
- **Don't update everything at once.** These projects change weekly and updates break things. If it works, leave it, and update one tool at a time when you want a new feature.
- **Prefer `.safetensors` model files.** Older formats (`.pth`, `.ckpt`) can contain hidden code, so download those only from popular, well-reviewed pages.
- **Check sizes and free space before downloading.** Video models are 10–30 GB each.
- **RAM:**
  - 32 GB is comfortable for audio work, and 64 GB is plenty. More only matters for heavy video work.
  - Windows already keeps recently used models in spare RAM automatically, so preloading them yourself isn't worth the bother.
- **Wear and tear:** none to worry about. RAM doesn't wear out from use, and SSDs wear from writing, not reading.
