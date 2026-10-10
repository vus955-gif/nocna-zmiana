#!/usr/bin/env bash
# The wing guardians' dev arena: Floor I as the game builds it, the guard in
# the guardian's own arena (tests/scenarios/guardian_scenario.gd).
#   bash tools/run_guardian.sh colossus          play it (window; silent
#                                                unless SOUND=1) - for the
#                                                controller's night sessions
#   bash tools/run_guardian.sh colossus --shots  silent 1280x720 window,
#                                                screenshots -> tests/_out/guardian_colossus/
#   bash tools/run_guardian.sh colossus --dry    no window (--headless): stages
#                                                every moment of the fight and
#                                                checks it (MISSED = failed)
#   bash tools/run_guardian.sh colossus --bot    no window: a scripted guard
#                                                shoots the weak points without
#                                                dodging: the fight's length
#   bash tools/run_guardian.sh centaur --poses   no window: the guardian's poses
#                                                as Blender filmstrips (background)
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
ID="${1:-colossus}"
FLAG="${2:-}"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"$GODOT" --headless --path . --import > /dev/null 2>&1
SCENARIO=res://tests/scenarios/guardian_scenario.tscn
case "$FLAG" in
	--poses)
		# (the Centaur's: its poses written headless, drawn as filmstrips by
		# Blender in the background -> tests/_out/guardian_<id>/poses_*.png)
		"$GODOT" --headless --fixed-fps 60 --audio-driver Dummy --path . "res://tests/scenarios/${ID}_poses.tscn" 2>&1 | grep -vE "^\s*$"
		BLENDER="${BLENDER:-D:/Program Files/Blender Foundation/Blender 5.1/blender.exe}"
		"$BLENDER" -b --factory-startup -t 4 --python tools/art/guardian_poses.py -- --model "$ID" 2>&1 | grep -E "Saved|rendered|Error"
		;;
	--shots|--dry|--bot)
		MODE="${FLAG#--}"
		WINDOW=(--windowed)
		[ "$MODE" != "shots" ] && WINDOW=(--headless --fixed-fps 60)
		OUT=$("$GODOT" "${WINDOW[@]}" --audio-driver Dummy --path . "$SCENARIO" -- --guardian="$ID" --mode="$MODE" 2>&1)
		echo "$OUT" | grep -vE "^\s*$" | grep -vE "^WARNING|push_warning|GDScript backtrace|^\s+\[[0-9]+\]|^\s+at: (push_warning|warn_once)"
		if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|MISSED"; then
			echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
			exit 1
		fi
		;;
	*)
		"$GODOT" "${AUDIO[@]}" --windowed --path . "$SCENARIO" -- --guardian="$ID" --mode=play
		;;
esac
