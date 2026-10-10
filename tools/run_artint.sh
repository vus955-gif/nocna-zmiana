#!/usr/bin/env bash
# Art integration check: exhibits (lit, dark corner, blackout), kills and
# gibs, the T-Rex in the hall, first-person weapons and pickups, rendered
# 1920x1080 offscreen to tests/_out/artint/ (a small silent window mirrors
# it; only while nobody is using the PC).
#   bash tools/run_artint.sh                          all shots
#   bash tools/run_artint.sh --shots=exhibits,trex    some groups
#   bash tools/run_artint.sh --perf                   ~30 exhibits: models vs greybox FPS (uncapped)
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --windowed --disable-vsync --path . res://tests/scenarios/artint_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
