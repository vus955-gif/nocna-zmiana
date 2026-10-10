#!/usr/bin/env bash
# Windowless previews of the paper museum map (W6): Godot (headless, no
# sound) records the map's drawing for a few moments of a game and each
# floor tab into tests/_out/map/*.json, then pycairo turns them into PNGs
# (*_sheet.png: the whole sheet, *_screen.png: what the guard sees on
# opening it, *_close.png: zoomed in, poster.png: the wall poster).
# Usage: bash tools/run_map_preview.sh [name-filter]
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 180 "$GODOT" --headless --path . res://tests/support/map_preview.tscn 2>&1 | grep -E "ERROR|error|map previews|map open"
python tools/map/render_preview.py tests/_out/map "$@"
