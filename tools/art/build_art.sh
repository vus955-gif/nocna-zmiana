#!/usr/bin/env bash
# Rebuilds all generated art headless (no window opens), then imports it:
#   1. tileable textures      tools/art/build_textures.py   -> assets/textures/
#   2. models + atlases       tools/art/build_models.py     -> assets/models/, assets/textures/
#                             (+ EEVEE previews in tests/_out/art/)
#   3. Godot import presets   tools/art/import_settings.py  (crisp pixels, mipmaps)
#   4. Godot import           --headless --import
# Usage: bash tools/art/build_art.sh [model names...]   (names limit step 2 and
#        skip step 1 unless TEXTURES=1). FAST=1 skips ambient-occlusion rays,
#        PREVIEW=0 skips the renders.
cd "$(dirname "$0")/../.." || exit 1
BLENDER="D:/Program Files/Blender Foundation/Blender 5.1/blender.exe"
PY="D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe"
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
FLAGS=()
[ "${FAST:-0}" = "1" ] && FLAGS+=(--fast)
[ "${PREVIEW:-1}" = "0" ] && FLAGS+=(--no-preview)
set -e
if [ $# -eq 0 ] || [ "${TEXTURES:-0}" = "1" ]; then
	"$PY" tools/art/build_textures.py
fi
"$BLENDER" -b --factory-startup --python tools/art/build_models.py -- "$@" "${FLAGS[@]}" 2>&1 \
	| grep -E "^(model|  atlas|  part|  marker)|Error|Traceback|File \"" || true
"$PY" tools/art/import_settings.py
"$GODOT" --headless --path . --import > /dev/null 2>&1
"$PY" tools/art/import_settings.py
"$GODOT" --headless --path . --import > /dev/null 2>&1
echo "art build done"
