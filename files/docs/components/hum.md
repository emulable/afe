# Hum to track

**The job:** turn a hummed, sung or beatboxed recording into notes, and play them on an instrument.

## Why these tools
It's a chain of three ordinary tools, not one AI model that does everything:
- **Basic Pitch** listens to the recording and writes down the notes. It was chosen because it's light, accurate on a single voice, and runs without a graphics card.
- **FluidSynth** plays those notes with real instrument samples. It was chosen because it's exact and instant: the notes you hummed are the notes you hear.
- **GeneralUser GS** is the instrument sample set.

Exact notes come from this chain. A produced, realistic version comes from feeding its output into the music model.

## Where it comes from
| Piece | Source | Pinned | Licence |
|---|---|---|---|
| Basic Pitch | https://github.com/spotify/basic-pitch (PyPI) | 0.4.0 | Apache-2.0 |
| FluidSynth | https://github.com/FluidSynth/fluidsynth | 2.6.2 | LGPL-2.1 |
| GeneralUser GS sound set | https://github.com/mrbumpy409/GeneralUser-GS | commit `684543d5…` | its own free licence, in the file beside it |

## How the kit uses it
- **Environment:** `tools\humtools\.venv`, on Python 3.10 so that Basic Pitch uses its light ONNX model and not TensorFlow.
- **Script:** `scripts\hum_to_track.py`. It asks what the recording is ("this is the bass line"), tidies off-key notes and octave slips, and writes three files: a `.mid`, a `.wav` of the instrument, and a check copy with your recording underneath.
- **Launcher:** `Hum to track.bat` passes dropped files to the script.
- **Folders:** out `music\out`. FluidSynth in `tools\fluidsynth`; the sound set in `models\soundfonts`.
- **Instruments** are chosen from words in what you type. The table is `INSTRUMENTS` near the top of the script, and `DEFAULT_INSTRUMENT` sets what a plain "melody", "chords" or "bass" gets.
- **On other systems** the script uses the FluidSynth installed by the system.

## Quick test
Drop any short recording of humming onto `Hum to track.bat` and answer "this is the melody". Three files should appear in `music\out`.

## Known problems
- **It needs `setuptools` below version 80:** two of its libraries still import an old helper.
- **Separated "doo" or "dah" syllables** give cleaner notes than a smooth hum.
- **One part per recording.** Chords work only loosely.

## If it dies
Each link can be replaced separately.
- **Notes from audio:** search "audio to MIDI", "pitch transcription", "melody transcription". The replacement must give note, start time and length for a single voice.
- **Playing MIDI:** any sampler or software synth that renders a MIDI file to audio from a command line.
- **Sound sets:** search "free SoundFont sf2".
