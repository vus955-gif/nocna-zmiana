#!/usr/bin/env bash
# Lobby tools (stage 2b). Silent by default (the owner works on this machine
# meanwhile); SOUND=1 enables audio.
#   bash tools/run_lobby.sh play [--seed=N --night=N]  walk the lobby (window)
#   bash tools/run_lobby.sh shots                      screenshots -> tests/_out/lobby/ (window)
#   bash tools/run_lobby.sh perf                       ~30 awake exhibits, FPS -> tests/_out/lobby/perf.json (window)
#   bash tools/run_lobby.sh plan                       floor plan PNG + room table, headless
#   bash tools/run_lobby.sh dry                        stages shots + perf headless (no window, no images)
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
MODE="${1:-play}"
shift
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"$GODOT" --headless --path . --import > /dev/null 2>&1
case "$MODE" in
	play)
		"$GODOT" "${AUDIO[@]}" --path . res://src/level/lobby_dev.tscn -- "$@"
		;;
	shots|perf)
		OUT=$("$GODOT" "${AUDIO[@]}" --path . res://tests/scenarios/lobby_scenario.tscn -- --scenario="$MODE" 2>&1)
		echo "$OUT" | grep -vE "^\s*$"
		if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
			echo "ENGINE/SCRIPT ERRORS DETECTED"
			exit 1
		fi
		;;
	plan)
		"$GODOT" --headless --path . -s res://tests/support/lobby_plan.gd
		;;
	dry)
		for SCENARIO in shots perf; do
			OUT=$("$GODOT" --headless --audio-driver Dummy --path . res://tests/scenarios/lobby_scenario.tscn -- --scenario="$SCENARIO" 2>&1)
			echo "$OUT" | grep -vE "^\s*$"
			if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
				echo "ENGINE/SCRIPT ERRORS DETECTED"
				exit 1
			fi
		done
		;;
	*)
		echo "usage: bash tools/run_lobby.sh play|shots|perf|plan|dry"
		exit 2
		;;
esac
