#!/usr/bin/env bash
# The enemy ecology's poses (the knight's wake, a wolf on the scent, a
# mummy back in its coffin) in the style sample room under the real
# lighting: 1920x1080 screenshots land in tests/_out/ecology_poses/.
# Opens a small window (only while nobody is using the PC); always silent
# (Dummy audio).
# Usage: bash tools/run_ecology_poses.sh [--shots=knight_ready,wolf_sniff]
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --audio-driver Dummy --path . res://tests/scenarios/ecology_poses_runner.tscn -- "$@" 2>&1)
echo "$OUT" | grep -vE "^\s*$"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED"
	exit 1
fi
