#!/usr/bin/env bash
# The lobby's world content (secrets, notes, artifacts, CCTV) on screen.
# Silent by default (the owner works on this machine meanwhile); SOUND=1
# enables audio.
#   bash tools/run_world.sh        screenshots -> tests/_out/world/ (window)
#   bash tools/run_world.sh dry    the same staging headless (no window, no images)
cd "$(dirname "$0")/.." || exit 1
MODE="${1:-shots}"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"$GODOT" --headless --path . --import > /dev/null 2>&1
case "$MODE" in
	shots)
		OUT=$("$GODOT" "${AUDIO[@]}" --windowed --path . res://tests/scenarios/world_scenario.tscn 2>&1)
		;;
	dry)
		OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/world_scenario.tscn 2>&1)
		;;
	*)
		echo "usage: bash tools/run_world.sh [shots|dry]"
		exit 2
		;;
esac
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
