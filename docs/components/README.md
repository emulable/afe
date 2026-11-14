# Component pages

One page per component of AI Audio. Each page is written so that a person or a language model can understand, test or replace that one tool without reading the rest of the project.

| Page | Job |
|---|---|
| [core.md](core.md) | The folder, private Pythons, control panel and installer everything else stands on |
| [transcribe.md](transcribe.md) | Speech to text, with timings and speakers |
| [narrate.md](narrate.md) | Documents read aloud, with subtitles and video |
| [abogen.md](abogen.md) | Whole books to audiobooks with chapters |
| [acestep.md](acestep.md) | Music from a description; restyling songs |
| [hum.md](hum.md) | Humming, singing or beatboxing to an instrument track |
| [separate.md](separate.md) | Splitting a song into its parts |
| [applio.md](applio.md) | Changing a recorded voice into another voice |
| [comfyui.md](comfyui.md) | Voice cloning, voice design and the other voice engines |

## How each page is laid out
1. **The job:** what it's for, in one line.
2. **Why this tool:** what it was chosen over.
3. **Where it comes from:** the source, the exact pinned version, the licence.
4. **How the kit uses it:** the install step, what the launcher runs, the folders and ports. A replacement has to fit this.
5. **Quick test:** how to tell it works.
6. **Known problems.**
7. **If it dies:** how to find and choose a successor.

## Rules for replacing a tool
- **Keep the job, change the tool.** The launcher's name, the folders and the control-panel row stay; what runs behind them changes.
- **Compare by ear first.** Run the same material through the old tool and the candidate, and let a person choose.
- **It must fit the graphics card** people actually have. Check the memory it needs.
- **Check the licence** against how the person uses the results. Non-commercial licences are fine for private use only.
- **Pin what you install,** then run `setup\freeze_locks.ps1` and update the tool's page and `setup\components.json`.

The pinned versions on these pages were recorded on 14 November 2026. The authoritative pins are in `setup\locks\manifest.json` and the files beside it.
