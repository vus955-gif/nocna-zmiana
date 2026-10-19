#!/usr/bin/env bash
# Rebuilds the game's music and ambience:
#  1. renders WAV intermediates to build/audio_src/ (gitignored, .gdignore)
#     and the footstep WAVs to assets/sfx/steps/,
#  2. encodes the intermediates to Ogg Vorbis in assets/music/ and
#     assets/ambience/ with Blender's bundled audio module (+ .import files),
#  3. reimports, decodes every loop through Godot around its loop point and
#     compares it with the intermediate (length, alignment, clicks).
#   bash tools/build_audio.sh           everything (about an hour: the nine Floor I
#                                       zones take 4-8 min each; gen_music.py
#                                       zone_<z> / guardian_<w> in parallel is faster)
#   bash tools/build_audio.sh encode    steps 2-3 (intermediates exist)
#   bash tools/build_audio.sh check     step 3 only
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
PY="D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe"
BLENDER="D:/Program Files/Blender Foundation/Blender 5.1/blender.exe"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
STEP="${1:-all}"
if [ "$STEP" = "all" ]; then
	"$PY" tools/music/gen_music.py || exit 1
	"$PY" tools/music/gen_ambience.py || exit 1
	"$PY" tools/music/gen_foley.py || exit 1
fi
if [ "$STEP" = "all" ] || [ "$STEP" = "encode" ]; then
	"$BLENDER" -b --factory-startup --python tools/music/encode_ogg.py 2>&1 | grep -E " MB|Error|nothing"
fi
"$GODOT" --headless --path . --import > /dev/null 2>&1
"$GODOT" --headless --audio-driver Dummy --path . -s res://tests/support/decode_loops.gd 2>&1 | grep -vE "^\s*$|^Godot Engine"
"$PY" tools/music/analyze.py --seams
