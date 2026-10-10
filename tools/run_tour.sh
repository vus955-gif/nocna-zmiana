#!/usr/bin/env bash
# "Wycieczka" (design 12): the dressed hub and Egypt of Floor I (stage P2),
# the Greek and Enlightenment wings and the basement (stage P3) in the real
# game, viewpoint by viewpoint - at night, in a blackout, during the
# Colossus and T-Rex fights.
#   bash tools/run_tour.sh shots --only=greece_parthenon_long,library_from_court,basement_boiler_fires
#   bash tools/run_tour.sh shots [--preset=high] [--only=court_wide_sw,egypt_camp]
#       silent 1920x1080 window: screenshots + brightness metrics
#       -> tests/_out/tour/<view>[_<preset>].png, metrics_<preset>.json
#   bash tools/run_tour.sh perf [--preset=high]
#       silent window: frame rate at the twelve heaviest views -> perf_<preset>.json
#   bash tools/run_tour.sh dry
#       no window (headless): every viewpoint checked, lamps / shadows / motes
#       left on by the room-graph culling -> dry_high.json; exit 1 on a bad view
# The windowed modes only while nobody uses the PC (one window at a time).
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-shots}"
shift
"$GODOT" --headless --path . --import > /dev/null 2>&1
if [ "$MODE" = "dry" ]; then
	OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/tour_scenario.tscn -- --mode=dry "$@" 2>&1)
else
	OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/tour_scenario.tscn -- --mode="$MODE" "$@" 2>&1)
fi
CODE=$?
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
exit $CODE
