#!/usr/bin/env bash
# Hitches of a night (silent 1920x1080 window, vsync off): the first 5 s
# of a night and the first fight in the hall (frame times, pipeline
# compilations), plus the script cost of the physics tick in a hall fight.
#   bash tools/run_hitch.sh           the night as it starts now
#   bash tools/run_hitch.sh --warm    with Fx.warm_up() after the build
# Result: tests/_out/hitch/hitch[_warm].json. Compare the DRAW pipeline
# compilations (each stalls its frame) more than the frame times: Godot's
# and the driver's pipeline caches make a second run faster either way.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/hitch_scenario.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
