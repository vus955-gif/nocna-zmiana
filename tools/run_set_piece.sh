#!/usr/bin/env bash
# The Great Court's set-piece ("Baba Jaga patrzy", plan 2026-10-22-set-piece)
# in the real game with the art: four shots of one game -> tests/_out/set-piece/.
# Silent 1920x1080 window; only while nobody uses the PC, through the lock:
#   bash tools/agents/with_window.sh bash tools/run_set_piece.sh
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --windowed --audio-driver Dummy --path . res://tests/scenarios/set_piece_scenario.tscn 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|MISSED"; then
	echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
	exit 1
fi
