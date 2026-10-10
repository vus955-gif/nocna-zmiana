#!/usr/bin/env bash
# Renders the stage 1b style sample: screenshots at 1920x1080 land in
# tests/_out/style/, plus the frame rate. Always silent (Dummy audio),
# windowed (the game's default is fullscreen; the runner sizes the window).
# Usage: bash tools/run_style.sh [--shots=wide,figure] [--gi=sdfgi|voxel|none] [--perf=0]
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --windowed --path . res://tests/scenarios/style_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
