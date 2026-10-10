"""Voice lines as data: text from locale/strings.csv, rules from data/voice/*.json."""
import csv
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class VoiceData:
    lines: dict
    speakers: dict
    fx_version: int
    lexicon: dict
    text_en: dict

    def settings(self, key):
        """(voice, speed, level) of one line."""
        line = self.lines[key]
        speaker = self.speakers[line["speaker"]]
        return speaker["voice"], float(line.get("speed", speaker["speed"])), int(line.get("level", 0))

    def hash_of(self, key):
        voice, speed, level = self.settings(key)
        return line_hash(voice, speed, level, self.fx_version, self.text_en[key])


def line_hash(voice, speed, level, fx_version, text):
    return hashlib.sha256(f"{voice}|{speed:.3f}|{level}|{fx_version}|{text}".encode("utf-8")).hexdigest()


def load(root=ROOT):
    lines = json.loads((root / "data/voice/lines.json").read_text(encoding="utf-8"))["lines"]
    sp = json.loads((root / "data/voice/speakers.json").read_text(encoding="utf-8"))
    lexicon = json.loads((root / "data/voice/lexicon.json").read_text(encoding="utf-8"))
    with open(root / "locale/strings.csv", encoding="utf-8", newline="") as f:
        text = {row["keys"]: row["en"] for row in csv.DictReader(f)}
    missing = [k for k in lines if not text.get(k)]
    if missing:
        raise SystemExit(f"no English text in locale/strings.csv for: {missing}")
    return VoiceData(lines, sp["speakers"], int(sp["fx_version"]), lexicon, {k: text[k] for k in lines})
