#!/usr/bin/env bash
# Gameplay screenshots for the README: the real Floor I museum through the
# guard's eyes, HUD up, a different weapon in hand each time - the shotgun
# into wax figures, the General's dash, the Lamassu's charge and gust, the
# fire-arrow chest into a book flock, the harpoon on a mummy, the T-Rex
# under the gatling (tests/scenarios/promo_scenario.gd).
#   bash tools/run_promo.sh dry [--only=trex,books]
#       no window (--headless): stages every shot and checks its state
#       (the subject in the guard's clear sight), captures nothing
#       -> tests/_out/promo/dry.json; exit 1 on a MISSED
#   bash tools/run_promo.sh shots [--only=trex,books] [--lang=pl]
#       silent 1920x1080 window: screenshots + brightness metrics
#       -> tests/_out/promo/<name>.png, metrics.json
# Groups for --only: shotgun, general, lamassu, books, egypt, trex.
# The windowed mode only while nobody uses the PC (one window at a time).
# A script that fails to load would leave an empty scene (or window) open
# for good: the run is watched and killed on that, or after HARD_LIMIT s.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-dry}"
shift
HARD_LIMIT=720
"$GODOT" --headless --path . --import > /dev/null 2>&1
SCENARIO=res://tests/scenarios/promo_scenario.tscn
LOG="$(mktemp)"
if [ "$MODE" = "dry" ]; then
	"$GODOT" --headless --fixed-fps 60 --audio-driver Dummy --path . "$SCENARIO" -- --mode=dry "$@" > "$LOG" 2>&1 &
else
	"$GODOT" --windowed --audio-driver Dummy --path . "$SCENARIO" -- --mode="$MODE" "$@" > "$LOG" 2>&1 &
fi
PID=$!
STARTED=$(date +%s)
KILLED=""
while kill -0 "$PID" 2>/dev/null; do
	sleep 2
	if grep -qE "Failed to load script|Parse Error|Compile Error" "$LOG"; then
		KILLED="the scenario script did not load"
	elif [ $(( $(date +%s) - STARTED )) -gt "$HARD_LIMIT" ]; then
		KILLED="over $HARD_LIMIT s"
	fi
	if [ -n "$KILLED" ]; then
		taskkill //PID "$PID" //T //F > /dev/null 2>&1
		break
	fi
done
wait "$PID" 2>/dev/null
CODE=$?
OUT=$(cat "$LOG")
rm -f "$LOG"
echo "$OUT" | grep -vE "^\s*$" | grep -vE "^WARNING|push_warning|GDScript backtrace|^\s+\[[0-9]+\]|^\s+at: (push_warning|warn_once)"
if [ -n "$KILLED" ]; then
	echo "RUN KILLED: $KILLED"
	exit 1
fi
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
exit $CODE
