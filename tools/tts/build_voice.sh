#!/usr/bin/env bash
# Voice lines: Kokoro -> build/audio_src/voice/*.wav -> assets/voice/*.ogg (+ manifest, .import), Godot import.
#   bash tools/tts/build_voice.sh          changed lines only
#   bash tools/tts/build_voice.sh --all    every line again
set -euo pipefail
cd "$(dirname "$0")/../.."
. tools/dev_env.sh
BLENDER="D:/Program Files/Blender Foundation/Blender 5.1/blender.exe"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
(cd tools/tts && .venv/Scripts/python.exe generate_voice.py "$@")
"$BLENDER" -b --factory-startup --python tools/music/encode_ogg.py -- voice 2>&1 | grep -E " MB|Error|nothing" || true
"$GODOT" --headless --path . --import > /dev/null 2>&1
