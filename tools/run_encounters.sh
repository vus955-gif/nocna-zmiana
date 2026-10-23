#!/usr/bin/env bash
# The three gold rooms' fight scenarios (plan 2026-10-22-projekt-starc)
# played live in the dressed Floor I, the guard's view shot at their beats.
#   bash tools/agents/with_window.sh bash tools/run_encounters.sh shots
#       silent 1600x900 window -> tests/_out/encounters/<room>_<moment>.png
#   bash tools/run_encounters.sh dry
#       headless: the same walk without shots; exit 1 when a beat did not play
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-shots}"
"$GODOT" --headless --path . --import > /dev/null 2>&1
if [ "$MODE" = "dry" ]; then
	OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/encounters_scenario.tscn -- --mode=dry 2>&1)
else
	OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/encounters_scenario.tscn -- --mode="$MODE" 2>&1)
fi
CODE=$?
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED|PROBLEM"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED BEATS DETECTED"
	exit 1
fi
exit $CODE
