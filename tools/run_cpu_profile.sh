#!/usr/bin/env bash
# CPU profile of a night, headless (no window, no sound): builds the dressed
# Floor I museum, plays a scripted night through the real game's code and
# reports the script and physics time per tick, total and per subsystem
# (enemies, perception, music, voice, fx, level, HUD...).
#   bash tools/run_cpu_profile.sh                 the whole profile (~2-3 min)
#   bash tools/run_cpu_profile.sh --quick         every segment a quarter as long
#   bash tools/run_cpu_profile.sh --only=walk,trex
# Segments: hub_idle, walk, fight_hall, colossus, trex.
# Result: tests/_out/cpu_profile.json (+ the table on stdout). --fixed-fps 60
# makes every frame one 1/60 s tick, frames run flat out. GPU time cannot be
# measured without a renderer: the F3 overlay shows it in a window.
# How it counts: tests/scenarios/cpu_profile.gd, src/dev/cpu_sections.gd.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --fixed-fps 60 --audio-driver Dummy --path . res://tests/scenarios/cpu_profile.tscn -- "$@" 2>&1)
CODE=$?
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
exit $CODE
