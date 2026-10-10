#!/usr/bin/env bash
# Runs the stage-1a combat sandbox (dev scene) in a window, bypassing the
# main menu. Silent by default; SOUND=1 enables audio.
# Usage: bash tools/run_sandbox.sh
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import > /dev/null 2>&1
"$GODOT" "${AUDIO[@]}" --path . res://src/arena/sandbox.tscn
