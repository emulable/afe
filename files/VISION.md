# AI Audio: the vision

This is the brief for anyone, person or language model, who is about to change, extend or rebuild this project. It says what the project is for and how it makes decisions. It doesn't say how to install anything: for that, see "Where to read next" at the end.

## What it is
**An offline, all-in-one audio suite for one person's own computer.** It installs a set of open AI audio tools into a single folder and wraps them so that someone who isn't a programmer can use them: start a tool, drop a file in, get a result.

It's for people who care how things sound. It's a personal workshop, not a product: built by a hobbyist for the things they and people like them want to do with local audio. It may become a public project. Until then, it's tuned to real use, not to a market.

## What it does
| Job | In plain words |
|---|---|
| Narration | A document or typed text becomes natural speech, with subtitles and an optional video |
| Voices | Clone a voice from a short clip, or design a new one from a written description |
| Voice change | Re-voice a recording as someone else, keeping the original timing and delivery |
| Voice clean-up | Remove music, noise and echo from a voice recording |
| Music | Make a song from a description, or restyle an existing one |
| Humming to music | A hummed, sung or beatboxed line becomes an instrument track, MIDI and sheet music |
| Splitting songs | Pull a song apart into vocals, drums, bass and the rest |
| Sound design | Sound effects and background ambience from a description |
| Transcription | Who said what, with timings |

Not every job is built yet. The table near the end says which are.

## How it decides things
These are the project's rules of judgement. When a choice comes up that this document doesn't cover, decide by these.

1. **Quality is judged by ear.** Benchmarks and leaderboards pick candidates. A person listening to the same material through each candidate picks the winner. A language model can't hear, so it sets up the comparison and reports measurements; it doesn't declare a winner.
2. **Only the front-runners stay installed.** One tool per job when there's a clear best. Up to three when they clearly suit different uses. Whatever loses a comparison is removed.
3. **Simple first.** Complexity is welcome when it buys audible quality, and only then. A simple thing that works beats an elaborate thing that might.
4. **Each kind of tool does what it's good at:**

   | Who | Does |
   |---|---|
   | The person | Performance, taste, the final call |
   | A language model | Music theory and history, arrangement, scores, prompt writing, driving the tools |
   | Generative audio models | Timbre and performance: turning a plan or score into sound |
   | Ordinary audio tools | Anything exact: timing, edits, loops, effects, mixing, loudness, file conversion |

   Don't make a language model improvise what an audio program does exactly.
5. **It avoids the generic.** Results that sound overwrought, machine-made or like everything else are failures even when they're technically clean. The levers:
   - reference audio and a trained style instead of adjectives
   - locked tempo and key
   - several takes with a person choosing
   - building from layers instead of one-shot generation
6. **It's honest about itself.** Guides say what was tested and what wasn't. A tool that fails says so plainly.

## How it's built, and why
- **Everything lives in one folder.** No system-wide installs, no changes to the computer's settings. The folder can be moved, copied to another drive, or deleted, and nothing is left behind.
- **Each tool gets its own environment.** Tools never share Python packages, so updating or removing one can't break another.
- **Versions are pinned.** A fresh install gets exactly what was tested. Projects in this field change weekly; pinning is what keeps the kit working.
- **One list describes everything.** `setup\components.json` names every component, what it's for, how big it is, what it needs, and how it appears in the control panel. The installer and the control panel both read it. Adding, removing or regrouping a tool starts there.
- **The interface adapts.** It shows only what's installed, and it offers only what the computer can run.
- **The graphics card is shared.** People use the same card for games and other work. Nothing starts heavy work on it without the person's say-so, and every tool frees it when it stops.
- **It works offline.** Once installed, nothing needs the internet.
- **Nothing personal is shared.** Details about one person's computer stay in a private notes file that is never packed into the shareable kit.

## The design stance
The interface is designed for reading, not for looking designed.

- **Plain words.** Every tool and section says in one sentence what it does.
- **Guidance is built in.** Example text is already in the boxes. Longer help sits folded underneath, with where to find more.
- **Little decoration.** Dark by default. One emoji per major section and none elsewhere.
- **It matches the screen.** It follows the display's scaling and the system's text size.
- **It never loses the person's work.** Removing a tool keeps their results, voices, trained models and settings.
- **It asks before anything that can't be undone.**

## Who it's for, and tailoring it
The first user has a trained ear and no programming background. Someone else may differ on both counts. Before changing the installation for a new person, ask them:
- what they want to make
- how much they know about audio
- whether they want quick-and-simple or elaborate-and-high-fidelity
- what computer they have

The full list of questions is in the installer's notes (`setup\install.ps1`, "Helping a user change or tailor the installation").

**Taste is not part of this brief.** The prompt library and a few defaults reflect one person's preferences. Treat them as worked examples of how to direct these models in detail, and replace them freely. The installer's notes list where those defaults live.

## Extending it
- **A new tool for an existing job:** compare it by ear against the current one first. If it wins, it replaces the old tool; it doesn't join it.
- **A new job:** add a component and its control-panel row to `setup\components.json`, an install step, a launcher, and a short guide. The installer's notes list the exact places.
- **A whole new category:** the control panel's groups come from the same list file, so regrouping there is an edit to that file. The installer window isn't grouped yet.
- **Keep the documents in step.** A change isn't finished until the guide, the component's page and the pinned versions match it.

## Rebuilding it elsewhere
- **Another Windows PC with an NVIDIA card:** unzip the kit and run the installer. This is the only path that has been tested, and only on the PC it was built on.
- **Linux:** `other-systems\linux` has a terminal installer translated from the Windows one. It has never been run on Linux.
- **Mac:** `other-systems\mac` is a researched guide to what works there and what to use in place of what doesn't. There's no installer.
- **When a tool has died or moved on:** each component's page in `docs\components` says what the tool is for, exactly how the kit talks to it, and how to choose a successor. Replace the tool, keep the job.

## What's built, and what's planned
| | Status |
|---|---|
| Installer with a component list, repair and removal | Built |
| Graphics-memory detection and quick picks in the installer | Built |
| Control panel that starts, stops and shows only installed tools | Built |
| Narration, transcription, music, humming to instrument, song splitting, voice conversion, voice cloning and design | Built, as separate tools |
| Portable folder that repairs itself after a move | Built |
| Beginner's guide and prompt library | Built |
| One page with a side menu covering every job | Planned |
| Voice clean-up, sound design, sheet music | Planned |
| One shared output folder | Planned |
| An audio workstation driven by a language model | Planned: ready for an audio program with known-good language-model control; REAPER is the current pick |
| Linux | Written, untested |
| Mac | Guide only |

## Where to read next
| To do this | Read |
|---|---|
| Work on the project with an AI assistant | `CLAUDE.md` (short rules and a map) |
| Use the tools | `README.md`, then `How to use each tool.md` |
| Write better prompts | `Tips and prompts.md` |
| Install, repair, remove, or fix something broken | The notes at the top of `setup\install.ps1` (the technical manual) |
| Understand, test or replace one tool | Its page in `docs\components` |
| Run it on Linux or a Mac | `other-systems` |
