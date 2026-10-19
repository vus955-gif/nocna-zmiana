"""Numbers instead of ears for the voice lines: loudness, peaks and lengths.

    tools/tts/.venv/Scripts/python.exe tools/tts/loudness.py      (after build_voice.sh)

Reads the WAVs build_voice.sh leaves in build/audio_src/voice/<speaker>/ and
prints per speaker the spread of integrated loudness (BS.1770, the music
tools' dsp.lufs at 24 kHz, mono counted as dual-mono), sample peaks and
lengths, then every line more than SPREAD dB off its speaker's median, any
peak over -1 dBFS and the longest lines. Nothing is played.
"""
import statistics
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "music"))
import dsp  # noqa: E402

SRC = ROOT / "build/audio_src/voice"
SPREAD = 2.0          # dB off the speaker's median loudness worth a look
PEAK_CEILING = -1.0   # dBFS (generate_voice.normalize)


def measure(path):
    x, sr = sf.read(path, dtype="float64")
    dsp.SR = sr       # the K filter and the 400 ms blocks follow the file's rate
    peak = 20.0 * np.log10(max(float(np.abs(x).max()), 1e-9))
    return {"key": path.stem, "lufs": dsp.lufs(x), "peak": peak, "seconds": len(x) / sr}


def main():
    groups = {}
    for path in sorted(SRC.glob("*/*.wav")):
        groups.setdefault(path.parent.name, []).append(measure(path))
    if not groups:
        raise SystemExit(f"no WAVs in {SRC} (run tools/tts/build_voice.sh)")
    flagged = 0
    for speaker, lines in groups.items():
        loud = [m["lufs"] for m in lines]
        mid = statistics.median(loud)
        secs = [m["seconds"] for m in lines]
        print(f"{speaker}: {len(lines)} lines, {sum(secs) / 60:.1f} min; loudness median {mid:.1f} LUFS, "
              f"range {min(loud):.1f} .. {max(loud):.1f}, stdev {statistics.pstdev(loud):.2f} dB; "
              f"peak max {max(m['peak'] for m in lines):.1f} dBFS; length {min(secs):.1f} .. {max(secs):.1f} s")
        for m in sorted(lines, key=lambda m: abs(m["lufs"] - mid), reverse=True):
            if abs(m["lufs"] - mid) > SPREAD or m["peak"] > PEAK_CEILING + 0.05:
                flagged += 1
                print(f"  look: {m['key']:<32} {m['lufs']:6.1f} LUFS ({m['lufs'] - mid:+.1f})  peak {m['peak']:5.1f}  {m['seconds']:.1f} s")
        for m in sorted(lines, key=lambda m: m["seconds"], reverse=True)[:3]:
            print(f"  longest: {m['key']:<29} {m['seconds']:.1f} s")
    print(f"{flagged} line(s) to look at")


if __name__ == "__main__":
    main()
