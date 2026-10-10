"""Fetches Kokoro voice styles (510 x 256 float32 = 522 240 bytes each) from the
official ONNX export into tools/tts/models/voices/. Already present = skipped."""
import sys
import urllib.request
from pathlib import Path

URL = "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/voices/{}.bin"
SIZE = 522240
DST = Path(__file__).resolve().parent / "models" / "voices"
# audition candidates per role (docs/superpowers/specs/2026-10-08-glos-projekt.md §5.4)
CANDIDATES = {
    "heniek": ["am_michael", "am_fenrir", "am_puck", "bm_george", "bm_fable", "bm_lewis"],
    "system": ["af_heart", "af_bella", "af_nicole", "bf_emma", "bf_isabella"],
}


def fetch(names):
    DST.mkdir(parents=True, exist_ok=True)
    for name in names:
        path = DST / f"{name}.bin"
        if path.exists() and path.stat().st_size == SIZE:
            continue
        data = urllib.request.urlopen(URL.format(name), timeout=60).read()
        if len(data) != SIZE:
            raise SystemExit(f"{name}: {len(data)} bytes, expected {SIZE}")
        path.write_bytes(data)
        print("voice", name)


if __name__ == "__main__":
    fetch(sys.argv[1:] or sorted({v for vs in CANDIDATES.values() for v in vs}))
