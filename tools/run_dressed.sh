#!/usr/bin/env bash
# The real game in the dressed lobby (lobby kit + light recipe), staged
# through test hooks, at a graphics preset. Silent 1920x1080 window; run it
# only while nobody uses the PC.
#   bash tools/run_dressed.sh shots [--preset=high] [--only=hall_wide,trex]
#       screenshots -> tests/_out/dressed/
#   bash tools/run_dressed.sh perf [--preset=low|medium|high|ultra]
#       frame rate of the hall (lit, then the boss fight with ~40 exhibits)
#       -> tests/_out/dressed/perf_<preset>.json
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-shots}"
shift
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/dressed_scenario.tscn -- --mode="$MODE" "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
