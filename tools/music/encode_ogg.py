"""Encodes the WAV intermediates in build/audio_src/ to Ogg Vorbis in assets/.

Runs inside Blender (its bundled audio module `aud` wraps FFmpeg's
libvorbis; nothing else to install):

    "D:/Program Files/Blender Foundation/Blender 5.1/blender.exe" -b --factory-startup --python tools/music/encode_ogg.py

build/audio_src/music/<name>.wav            -> assets/music/<name>.ogg
build/audio_src/ambience/bed_<layer>.wav    -> assets/ambience/bed_<layer>.ogg
build/audio_src/ambience/oneshots/<n>.wav   -> assets/ambience/oneshots/<n>.ogg
build/audio_src/voice/<speaker>/<key>.wav   -> assets/voice/<speaker>/<key>.ogg
    (mono 24 kHz, 64 kbit/s; "-- voice" after the script encodes only these)
Each .ogg gets a fixed stream serial (ogg_serial.py: the encoder picks a
random one, so the same WAV would give a different file every time) and
its .import (godot_import.py): loops (music except the stings, beds) with
loop=true, the rest without. Vorbis keeps the exact
sample count (the last page's granule position), so a loop still ends on
its last sample; check_loops.gd + analyze.py --seams verify it after import.
"""
import sys
import wave
from pathlib import Path

import aud

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import godot_import  # noqa: E402
import ogg_serial  # noqa: E402

ROOT = HERE.parents[1]
SRC = ROOT / "build" / "audio_src"
DST = ROOT / "assets"
# bits per second (average) by channel count and kind; Floor I's music
# (the wings' walks, the guardians' theme, its stings) at 128 kbit/s
BITRATE = {("music", 2): 160000, ("music_floor1", 2): 128000, ("ambience", 2): 112000, ("ambience", 1): 80000,
           ("oneshot", 1): 80000, ("voice", 1): 64000}
FLOOR1_MUSIC = ("explore_egypt", "explore_assyria", "explore_greece", "explore_enlightenment", "explore_asia",
                "explore_americas", "guardian", "seal_sting", "gate_sting", "wing_sting")


def music_kind(stem):
    return "music_floor1" if stem.startswith(FLOOR1_MUSIC) else "music"


def channels_of(path):
    with wave.open(str(path), "rb") as src:
        return src.getnchannels()


def encode(src, dst, kind, loop):
    channels = channels_of(src)
    dst.parent.mkdir(parents=True, exist_ok=True)
    sound = aud.Sound(str(src))
    sound.write(str(dst), rate=24000 if kind == "voice" else 44100, channels=aud.CHANNELS_STEREO if channels == 2 else aud.CHANNELS_MONO,
                format=aud.FORMAT_FLOAT32, container=aud.CONTAINER_OGG, codec=aud.CODEC_VORBIS,
                bitrate=BITRATE[(kind, channels)])
    ogg_serial.fix_serial(dst)
    godot_import.mark_ogg(dst, loop)
    print(f"  {dst.relative_to(ROOT)}  {src.stat().st_size / 1e6:6.2f} MB -> {dst.stat().st_size / 1e6:5.2f} MB")


def main():
    voice_only = sys.argv[sys.argv.index("--") + 1:] == ["voice"] if "--" in sys.argv else False
    jobs = []
    if not voice_only:
        for src in sorted((SRC / "music").glob("*.wav")):
            jobs.append((src, DST / "music" / (src.stem + ".ogg"), music_kind(src.stem), "sting" not in src.stem))
        for src in sorted((SRC / "ambience").glob("bed_*.wav")):
            jobs.append((src, DST / "ambience" / (src.stem + ".ogg"), "ambience", True))
        for src in sorted((SRC / "ambience" / "oneshots").glob("*.wav")):
            jobs.append((src, DST / "ambience" / "oneshots" / (src.stem + ".ogg"), "oneshot", False))
        if not jobs:
            print("nothing in build/audio_src: run gen_music.py and gen_ambience.py first")
    for src in sorted((SRC / "voice").glob("*/*.wav")):
        dst = DST / "voice" / src.parent.name / (src.stem + ".ogg")
        if not (dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime):   # only lines made again
            jobs.append((src, dst, "voice", False))
    if voice_only and not jobs:
        print("voice: nothing to encode" if any((SRC / "voice").glob("*/*.wav"))
              else "nothing in build/audio_src/voice: run tools/tts/generate_voice.py first")
    for src, dst, kind, loop in jobs:
        encode(src, dst, kind, loop)


main()
