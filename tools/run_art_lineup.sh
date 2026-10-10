#!/usr/bin/env bash
# Stage 2 models in the style sample room under the real lighting: 1920x1080
# screenshots land in tests/_out/art_lineup/. Opens a small window (only
# while nobody is using the PC); always silent (Dummy audio).
# Usage: bash tools/run_art_lineup.sh [--shots=enemies,trex,props,vm_shotgun]
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --path . res://tests/scenarios/art_lineup_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
