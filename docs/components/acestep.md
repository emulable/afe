# ACE-Step music

**The job:** make a song from a written description and optional lyrics, and restyle existing audio.

## Why this tool
**ACE-Step 1.5** was the strongest music model that runs on a home graphics card when the kit was built, and it does more than text-to-song: covers, repainting a section, copying a reference track's sound, and training a personal style. Its paper places it between two generations of the leading commercial service in listening tests. Newer open models were checked in November 2026 and none clearly beat it on a 16 GB card.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| ACE-Step 1.5 | https://github.com/ace-step/ACE-Step-1.5 | commit `ca1e85fe9430`, branch main | MIT |
| Models | Hugging Face, organisation `ACE-Step` | fetched by its own `acestep-download` | see each model's page |

**Models the installer fetches:** the 2B turbo music model, the 2B base model, the 1.7B planner, the text encoder and the VAE. **Optional:** XL turbo (18.6 GB). **By hand:** XL SFT, the slower highest-detail model (18.6 GB).

## How the kit uses it
- **Environment:** `tools\ACE-Step-1.5\.venv`, Python 3.11. It's built from the project's own `uv.lock` with `uv sync --frozen`, not from the kit's lock files.
- **Settings file:** `tools\ACE-Step-1.5\.env`, copied from `setup\overlays`.
- **Launchers:** both run `acestep.exe` on port 7860.
  - `ACE-Step (music).bat`: `--config_path acestep-v15-xl-turbo --lm_model_path acestep-5Hz-lm-1.7B --offload_dit_to_cpu true --init_service true`
  - `ACE-Step (music, fast).bat`: `--config_path acestep-v15-turbo`, without the offload.
- **Driving it from a script:** start it with `--enable-api`, then POST to `/release_task` and collect from `/query_result`. Give tempo, key and time signature in their own fields (`bpm`, `key_scale`, `time_signature`); written in the description they're only hints.
- **Folders:** results in `tools\ACE-Step-1.5\gradio_outputs`; models in `tools\ACE-Step-1.5\checkpoints`.
- **Memory:** the 2B model fits 8 GB. XL needs 12 GB or more; on 16 GB it peaks at about 15.6 GB.

## Quick test
Start the fast launcher, wait for the browser page, type a short description with `[Instrumental]` as the lyrics, and generate. A player with the result should appear in under a minute.

## Known problems
- **XL on a 16 GB card** needs `--offload_dit_to_cpu true`. Close other programs using the card first.
- **Only one launcher at a time:** both use port 7860.
- **Covers through `/release_task` failed in an early test.** `cli.py -c job.toml` with `task_type = "cover"` works. Re-test the API before relying on it.
- **Time taken (16 GB card, 90 seconds of music):** XL turbo about 27 s, XL SFT about 41 s.
- **XL SFT brought in piano-like sounds** on an instrumental prompt where XL turbo didn't, in one comparison.
- **The negative prompt only works with "Think" on.**

## If it dies
A successor must: run on the graphics card people have, take a description plus optional lyrics, lock tempo and key, accept a source track to restyle, and be drivable from a script.
- **Search for:** "open source music generation model", "text to music local", "song generation open weights".
- **Seen in November 2026:** YuE2 (writes a score first), MiniMax Music 3 (wants 20–24 GB), Stable Audio 3 (instrumental only), StepAudio 3 Music (not released).
- **Check by ear:** the same prompt and settings through both, for mix quality, how well it follows the description, and whether it sounds generic.
