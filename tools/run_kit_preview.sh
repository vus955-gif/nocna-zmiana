#!/usr/bin/env bash
# Renders the lobby architecture kit on the real lobby layout (LobbyKitPreview:
# ArtKit dressing + LobbyLightRecipe): screenshots at 1920x1080 land in
# tests/_out/kit/, plus the scene statistics and the frame rate. Always
# silent (Dummy audio) and windowed (a small window mirrors the offscreen
# view; run it only while nobody is using the PC).
# Usage: bash tools/run_kit_preview.sh [--shots=wide,stair,doorway] [--perf=0]
#        [--preset=low] [--dressing=0]
# Walk around it instead (Esc frees the mouse):
#   tools/godot/Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --path . res://src/style/lobby_kit_preview.tscn
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --windowed --disable-vsync --path . res://tests/scenarios/kit_preview_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
