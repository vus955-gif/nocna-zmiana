#!/usr/bin/env bash
# Stage 3 art in the game: the Gatling and the flare gun in the guard's
# hands, the raptor pack on its rigs (and in the dark by a flare), the
# gallery's portraits (eyes, out of the wall, telegraph, taser, gibs), the
# chained Gatling exhibit, the fire cabinet and the new pickups, rendered
# 1920x1080 offscreen to tests/_out/artint2/ (a small silent window mirrors
# it; only while nobody is using the PC).
#   bash tools/run_artint2.sh                                   all shots
#   bash tools/run_artint2.sh --shots=weapons,raptors,portraits,props   some groups
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --windowed --disable-vsync --path . res://tests/scenarios/artint2_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
