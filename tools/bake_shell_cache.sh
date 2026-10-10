#!/usr/bin/env bash
# Carves Floor I and the lobby and writes the shipped shell caches
# (res://data/shell_cache, ShellCache). Run after changing rooms or openings.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
"$GODOT" --headless --path . res://tools/bake_shell_cache.tscn 2>&1 | grep -vE "^\s*$"
