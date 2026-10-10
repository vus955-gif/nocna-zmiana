#!/usr/bin/env bash
# Audio check: music states, ambience zones, footsteps and bus levels
# through nights in the real Museum, reached by real scene swaps
# (tests/scenarios/audio_scenario.gd); fails on a MISSED check.
# Headless and silent by default (Dummy driver, the mixer still runs);
# SOUND=1 plays it through the speakers in a window.
# The table lands in tests/_out/audio/report.txt.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
if [ "${SOUND:-0}" = "1" ]; then
	OUT=$("$GODOT" --windowed --path . res://tests/scenarios/audio_scenario.tscn 2>&1)
else
	OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/audio_scenario.tscn 2>&1)
fi
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|leaked at exit|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED CHECKS DETECTED"
	exit 1
fi
