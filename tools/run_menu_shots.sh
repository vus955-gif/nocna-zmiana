#!/usr/bin/env bash
# The live main menu (stage "menu zywa scena"): the title screen over the
# dressed Great Court, shot by shot.
#   bash tools/run_menu_shots.sh shots [--preset=high] [--only=lattice,drum,trex,egypt,dip]
#       silent 1920x1080 window: the static fallback, each shot at three moments
#       with the menu on top (and once without it), the cut through black
#       -> tests/_out/menu/<shot>_<n>.png, metrics_<preset>.json
#   bash tools/run_menu_shots.sh perf [--preset=high]
#       frame rate in the middle of each shot, the loop running -> perf_<preset>.json
#   bash tools/run_menu_shots.sh dry
#       no window (headless): the menu builds its scene, every shot is checked
#       against the built floor, the lamps / shadows / motes left on by the
#       culling are counted -> dry_<preset>.json; exit 1 on a problem
# The windowed modes only while nobody uses the PC (one window at a time).
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-shots}"
shift
"$GODOT" --headless --path . --import > /dev/null 2>&1
if [ "$MODE" = "dry" ]; then
	OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/menu_scenario.tscn -- --mode=dry "$@" 2>&1)
else
	OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/menu_scenario.tscn -- --mode="$MODE" "$@" 2>&1)
fi
CODE=$?
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED|^PROBLEM"; then
	echo "ENGINE/SCRIPT ERRORS, MISSED MOMENTS OR PROBLEMS DETECTED"
	exit 1
fi
exit $CODE
