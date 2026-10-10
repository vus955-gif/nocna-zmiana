#!/usr/bin/env bash
# A whole night in the game, staged through test hooks (integration stage).
#   bash tools/run_night.sh shots   silent 1920x1080 window, screenshots ->
#                                   tests/_out/night/ (+ night.json)
#   bash tools/run_night.sh perf    silent window, the fight in the hall:
#                                   average/worst frame time -> perf.json
#   bash tools/run_night.sh dry     no window (--headless): stages every
#                                   moment, captures nothing, then times
#                                   the fight by script ms per physics tick
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-shots}"
"$GODOT" --headless --path . --import > /dev/null 2>&1
WINDOW=(--windowed)
[ "$MODE" = "dry" ] && WINDOW=(--headless)
[ "$MODE" = "dry" ] && MODE=shots
OUT=$("$GODOT" "${WINDOW[@]}" --audio-driver Dummy --path . res://tests/scenarios/night_scenario.tscn -- --mode="$MODE" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
