#!/usr/bin/env bash
# The HUD and the in-game UI, every piece on screen over the real Floor I
# (tests/scenarios/hud_gallery.gd): the live HUD at its fullest, the
# notices (a secret's banner, a subtitle, a hint, the night's card), F1
# help, the pause menu, options, the map, the upgrade terminal, a note, the
# dawn and death cards - in English and Polish, 1920x1080 and 1280x1024.
#   bash tools/run_hud_gallery.sh dry
#       no window (--headless): stages every view, checks it -> tests/_out/hud_style/dry.json
#   bash tools/run_hud_gallery.sh shots [--tag=after] [--views=hud,notice]
#       silent window -> tests/_out/hud_style/<tag>_<view>_<lang>_<w>x<h>.png
# The windowed mode only while nobody uses the PC (one window at a time).
# A script that fails to load would leave an empty window open for good:
# the run is watched and killed on that, or after HARD_LIMIT s.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
MODE="${1:-dry}"
shift
HARD_LIMIT=600
"$GODOT" --headless --path . --import > /dev/null 2>&1
SCENARIO=res://tests/scenarios/hud_gallery.tscn
LOG="$(mktemp)"
if [ "$MODE" = "dry" ]; then
	"$GODOT" --headless --fixed-fps 60 --audio-driver Dummy --path . "$SCENARIO" -- "$@" > "$LOG" 2>&1 &
else
	"$GODOT" --windowed --audio-driver Dummy --path . "$SCENARIO" -- "$@" > "$LOG" 2>&1 &
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
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|^PROBLEM"; then
	echo "ENGINE/SCRIPT ERRORS OR PROBLEMS DETECTED"
	exit 1
fi
exit $CODE
