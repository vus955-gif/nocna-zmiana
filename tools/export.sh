#!/usr/bin/env bash
# Builds the standalone game: build/NocnaZmiana.exe (one file, game data
# embedded), then smoke-runs it headless with a throw-away save folder
# (never the build's own save/). Needs the 4.7.2 Windows export templates
# in tools/godot/editor_data/export_templates/4.7.2.stable/.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
mkdir -p build
rm -f build/NocnaZmiana.exe
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --path . --export-release "Windows Desktop" build/NocnaZmiana.exe 2>&1)
if [ ! -f build/NocnaZmiana.exe ] || echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR"; then
	echo "$OUT" | grep -E "ERROR|WARNING"
	echo "EXPORT FAILED"
	exit 1
fi
ls -l build/NocnaZmiana.exe
SMOKE_SAVES="build/smoke_saves"
rm -rf "$SMOKE_SAVES"
SMOKE=$(build/NocnaZmiana.exe --headless --quit-after 120 -- --save-dir="$(pwd -W)/$SMOKE_SAVES" 2>&1)
rm -rf "$SMOKE_SAVES"
if echo "$SMOKE" | grep -qE "SCRIPT ERROR|Parse Error"; then
	echo "$SMOKE"
	echo "EXPORTED GAME HAS SCRIPT ERRORS"
	exit 1
fi
echo "OK: build/NocnaZmiana.exe"
