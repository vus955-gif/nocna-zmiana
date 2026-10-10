#!/usr/bin/env bash
# Runs one windowed visual scenario; screenshots + state land in tests/_out/.
# Usage: bash tools/run_scenario.sh overview|shotgun_gib|taser_finisher|knight_block|wolf_pounce|perf|ui_2a
# Silent by default (the owner works on this machine meanwhile); SOUND=1 enables audio.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
NAME="${1:-overview}"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" "${AUDIO[@]}" --windowed --path . res://tests/scenarios/scenario_runner.tscn -- --scenario="$NAME" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
