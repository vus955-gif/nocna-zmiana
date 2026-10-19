#!/usr/bin/env bash
# The night visual QA (plan docs/superpowers/plans/2026-10-19-qa-wizualne.md):
# the views no other scenario stages, in the real Floor I museum at night -
# the first-person weapons (two-handed idles, the rifle's reload frame by
# frame, the shotgun's break, the gatling's crank, the secrets' finishes and
# mods), the east enemies (totem, jaguar, Fu dog, samurai armour), the
# pickups at 5 / 10 / 15 m in three lights, the secrets' displays, the HUD's
# top edge at 1920x1080 and 1280x1024, the fire-arrow sparks at the lens,
# the subtitle bar and the voice props (tests/scenarios/visual_qa_scenario.gd).
#   bash tools/run_visual_qa.sh dry [--only=viewmodel,east]
#       no window (--headless): stages every view and checks it, captures
#       nothing -> tests/_out/visual_qa/dry.json; exit 1 on a MISSED
#   bash tools/run_visual_qa.sh shots [--only=hud] [--lang=pl]
#       silent 1920x1080 window -> tests/_out/visual_qa/<group>/<view>.png
# Groups for --only: viewmodel, looks, east, pickups, secrets, hud, voice.
# The windowed mode only while nobody uses the PC (one window at a time).
# A script that fails to load would leave an empty scene (or window) open
# for good: the run is watched and killed on that, or after HARD_LIMIT s.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-dry}"
shift
HARD_LIMIT=600
"$GODOT" --headless --path . --import > /dev/null 2>&1
SCENARIO=res://tests/scenarios/visual_qa_scenario.tscn
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
