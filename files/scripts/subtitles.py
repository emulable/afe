"""Subtitle shaping shared by transcribe.py and narrate.py. Standard library only.

A "word" is a dict with "text", "start" and "end" (seconds). A "cue" is one
subtitle: a dict with "start", "end" and "text".
"""
from __future__ import annotations

from pathlib import Path

# Two lines of about 42 characters, on screen for at most 7 seconds.
CUE_MAX_CHARS = 84
CUE_MAX_SECONDS = 7.0

SENTENCE_END = (".", "?", "!", "。", "？", "！", '."', '?"', '!"', ".”", "?”", "!”")
CLAUSE_END = (",", ";", ":", "，", "；", "：", "、", "—", "–")


def srt_time(seconds: float) -> str:
    ms = int(round(max(0.0, seconds) * 1000))
    return f"{ms // 3600000:02d}:{ms % 3600000 // 60000:02d}:{ms % 60000 // 1000:02d},{ms % 1000:03d}"


def _chars(words: list[dict]) -> int:
    return sum(len(w["text"].strip()) + 1 for w in words)


def _split_long(words: list[dict]) -> list[list[dict]]:
    """Split an over-long sentence into evenly sized pieces, cutting after commas where possible."""
    seconds = words[-1]["end"] - words[0]["start"]
    by_length = -(-_chars(words) // CUE_MAX_CHARS)
    by_time = -(-int(seconds * 10) // int(CUE_MAX_SECONDS * 10))
    pieces = max(by_length, by_time)
    if pieces <= 1 or len(words) < 2:
        return [words]
    target = _chars(words) / pieces
    out, current = [], []
    for i, w in enumerate(words):
        current.append(w)
        if len(out) >= pieces - 1 or i == len(words) - 1:
            continue                      # last piece takes whatever is left
        size = _chars(current)
        at_clause = w["text"].rstrip().endswith(CLAUSE_END)
        # Cut early at a comma once most of the target is used; otherwise cut at the target.
        if (at_clause and size >= 0.7 * target) or size >= target:
            out.append(current)
            current = []
    if current:
        out.append(current)
    return out


def words_to_cues(words: list[dict], joiner: str = " ", prefix: str = "") -> list[dict]:
    """Cut a run of timed words into subtitle-sized cues: whole sentences where
    they fit, evenly split (at commas if possible) where they do not."""
    # 1) sentences: cut after sentence-ending punctuation or a pause of more than a second
    sentences: list[list[dict]] = []
    for w in words:
        if sentences:
            prev = sentences[-1][-1]
            if not (prev["text"].rstrip().endswith(SENTENCE_END) or w["start"] - prev["end"] > 1.0):
                sentences[-1].append(w)
                continue
        sentences.append([w])
    # 2) glue a very short sentence onto the next one when both fit in one cue
    groups: list[list[dict]] = []
    for s in sentences:
        if groups:
            g = groups[-1]
            fits = (_chars(g) + _chars(s) <= CUE_MAX_CHARS
                    and s[-1]["end"] - g[0]["start"] <= CUE_MAX_SECONDS
                    and s[0]["start"] - g[-1]["end"] <= 0.6)
            if fits and _chars(g) < 30:
                g.extend(s)
                continue
        groups.append(list(s))
    # 3) split whatever is still too long for one cue
    cues = []
    for g in groups:
        for piece in _split_long(g):
            text = joiner.join(x["text"].strip() for x in piece).strip()
            if text:
                cues.append({"start": piece[0]["start"], "end": piece[-1]["end"], "text": prefix + text})
    return cues


def tidy_cues(cues: list[dict]) -> list[dict]:
    """Give every cue a readable minimum duration without overlapping the next one."""
    for i, cue in enumerate(cues):
        cue["end"] = max(cue["end"], cue["start"] + 0.4)
        if i + 1 < len(cues):
            cue["end"] = min(cue["end"], max(cue["start"] + 0.1, cues[i + 1]["start"]))
    return cues


def write_srt(cues: list[dict], path: Path) -> None:
    lines = []
    for i, cue in enumerate(cues, 1):
        lines += [str(i), f"{srt_time(cue['start'])} --> {srt_time(cue['end'])}", cue["text"], ""]
    Path(path).write_text("\n".join(lines), encoding="utf-8")
