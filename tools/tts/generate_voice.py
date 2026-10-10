"""Voice lines -> build/audio_src/voice/<speaker>/<key>.wav + assets/voice/manifest.json.

Only lines whose hash changed (text, voice, speed, level, fx_version) are made
again; lines gone from data/voice/lines.json lose their .ogg and manifest entry.
Then tools/music/encode_ogg.py -- voice encodes the WAVs (tools/tts/build_voice.sh).
    tools/tts/.venv/Scripts/python.exe tools/tts/generate_voice.py [--all]
"""
import hashlib
import json
import sys

import numpy as np
import soundfile as sf

from kokoro_tts import SR, Kokoro
from system_fx import process
from voice_data import ROOT, load

SRC = ROOT / "build/audio_src/voice"
DST = ROOT / "assets/voice"
MANIFEST = DST / "manifest.json"
TARGET_DB, PEAK_DB = -20.0, -1.0        # RMS of the speech (frames above the gate), peak ceiling
HEAD, TAIL = 0.06, 0.12                 # s of silence around a line


def normalize(wav):
    frames = wav[: len(wav) // 480 * 480].reshape(-1, 480)
    energy = np.sqrt(np.mean(frames ** 2, axis=1))
    speech = energy[energy > energy.max() * 10 ** (-45 / 20)]
    rms = float(np.sqrt(np.mean(speech ** 2))) if len(speech) else float(np.sqrt(np.mean(wav ** 2)))
    gain = min(10 ** (TARGET_DB / 20) / max(rms, 1e-6), 10 ** (PEAK_DB / 20) / max(float(np.abs(wav).max()), 1e-6))
    return wav * gain


def remove(key):
    """A line gone from the data: its .ogg (+ .import) and its source WAV go too."""
    for path in list(DST.glob(f"*/{key}.ogg*")) + list(SRC.glob(f"*/{key}.wav")):
        path.unlink()


def main(force):
    (SRC.parent).mkdir(parents=True, exist_ok=True)
    (SRC.parent / ".gdignore").touch()          # Godot must not import the WAV intermediates
    data = load()
    tts = Kokoro(data.lexicon)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for key in sorted(data.lines):
        speaker = data.lines[key]["speaker"]
        h = data.hash_of(key)
        ogg = DST / speaker / f"{key}.ogg"
        if not force and manifest.get(key, {}).get("hash") == h and ogg.exists():
            continue
        if len(data.text_en[key]) < 25:
            print(f"warning: {key} is short ({len(data.text_en[key])} chars) - Kokoro is weak on very short lines")
        voice, speed, level = data.settings(key)
        wav = tts.synth(data.text_en[key], voice, speed)
        seed = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
        wav = normalize(process(wav, SR, level, seed))
        wav = np.concatenate([np.zeros(int(HEAD * SR)), wav, np.zeros(int(TAIL * SR))]).astype(np.float32)
        (SRC / speaker).mkdir(parents=True, exist_ok=True)
        sf.write(SRC / speaker / f"{key}.wav", wav, SR, subtype="PCM_16")
        manifest[key] = {"hash": h, "speaker": speaker, "seconds": round(len(wav) / SR, 3)}
        print(f"{key}: {voice} x{speed:.2f} level {level}, {len(wav) / SR:.2f} s")
    for key in [k for k in manifest if k not in data.lines]:
        remove(key)
        del manifest[key]
        print(f"{key}: removed")
    DST.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main("--all" in sys.argv)
