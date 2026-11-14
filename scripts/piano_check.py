"""Listen for piano (and other keyboards / orchestra) in music files.

    piano_check.py FILE_OR_FOLDER [...] [--cpu]

Uses an AudioSet sound-recognition model (AST, about 350 MB, downloaded on first
use) to score every 10 seconds of each file, and prints the highest score per
instrument family. Scores run 0-1. Clean tracks score about 0.01-0.03 for piano;
0.08 and up usually means a piano or a piano-like sound (Rhodes, santur, dulcimer). Run it with the Transcribe environment's Python.
"""
from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")

MODEL = "MIT/ast-finetuned-audioset-10-10-0.4593"
AUDIO = {".wav", ".mp3", ".flac", ".m4a", ".ogg", ".opus"}
FAMILIES = {
    "piano": ["Piano", "Electric piano", "Keyboard (musical)", "Harpsichord"],
    "organ": ["Organ", "Electronic organ", "Hammond organ"],
    "orchestra": ["Orchestra", "String section", "Bowed string instrument", "Brass instrument", "Violin, fiddle", "Cello"],
    "synth": ["Synthesizer", "Electronic music", "Ambient music", "Drone"],
    "voices": ["Choir", "Chant", "Mantra", "Singing", "Male singing"],
    "ancient/folk": ["Harp", "Zither", "Sitar", "Plucked string instrument", "Bagpipes", "Flute", "Wind instrument, woodwind instrument", "Drum", "Gong", "Bell"],
}
PIANO_LIMIT = 0.08


def load_model(device: str):
    import torch
    from transformers import ASTFeatureExtractor, ASTForAudioClassification
    extractor = ASTFeatureExtractor.from_pretrained(MODEL)
    model = ASTForAudioClassification.from_pretrained(MODEL).to(device).eval()
    labels = model.config.id2label
    index = {name: i for i, name in labels.items()}
    return extractor, model, index, torch


def score_file(path: Path, extractor, model, index, torch, device: str) -> dict:
    from whisperx.audio import load_audio      # ffmpeg decode to 16 kHz mono
    y, sr = load_audio(str(path)), 16000
    window = 10 * sr
    best = {fam: 0.0 for fam in FAMILIES}
    worst_piano_at = 0.0
    for start in range(0, max(1, len(y) - sr), window):
        chunk = y[start:start + window]
        if len(chunk) < sr:
            break
        feats = extractor(chunk, sampling_rate=sr, return_tensors="pt").to(device)
        with torch.no_grad():
            probs = torch.sigmoid(model(**feats).logits)[0].cpu()
        for fam, names in FAMILIES.items():
            s = max(float(probs[index[n]]) for n in names if n in index)
            if s > best[fam]:
                best[fam] = s
                if fam == "piano":
                    worst_piano_at = start / sr
    best["_piano_at"] = worst_piano_at
    return best


def main() -> int:
    p = argparse.ArgumentParser(description="Listen for piano in music files.")
    p.add_argument("paths", nargs="+", type=Path)
    p.add_argument("--cpu", action="store_true", help="don't use the graphics card")
    args = p.parse_args()
    files = []
    for path in args.paths:
        if path.is_dir():
            files += sorted(f for f in path.iterdir() if f.suffix.lower() in AUDIO)
        elif path.is_file():
            files.append(path)
    if not files:
        print("No audio files found.")
        return 2
    import torch
    device = "cpu" if args.cpu or not torch.cuda.is_available() else "cuda"
    extractor, model, index, torch = load_model(device)
    for f in files:
        s = score_file(f, extractor, model, index, torch, device)
        verdict = "PIANO" if s["piano"] >= PIANO_LIMIT else "clean"   # 0.08+ = piano or piano-like
        fams = "  ".join(f"{fam} {s[fam]:.2f}" for fam in FAMILIES)
        where = f" (loudest around {s['_piano_at']:.0f} s)" if verdict == "PIANO" else ""
        print(f"{verdict:5}  {f.name}: {fams}{where}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
