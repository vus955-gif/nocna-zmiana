#!/usr/bin/env bash
# Imports the project, then runs all headless tests. Extra arguments go to
# the runner, e.g.:  bash tools/run_tests.sh --filter=stamina
# Fails if any test fails OR Godot prints an ERROR line (incl. leaks at exit).
# --fixed-fps 60: every frame advances the game by exactly 1/60 s (physics
# steps stay 1/60 s) but frames run flat out instead of waiting for the wall
# clock, so the suite takes seconds instead of minutes. Timers and waits in
# tests count game time; only the runner's final wait uses real time.
# (Scenarios and perf runs stay real-time: they do not use this script.)
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
OUT=$("$GODOT" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- "$@" 2>&1)
CODE=$?
echo "$OUT"
if echo "$OUT" | grep -qE "^(USER |SCRIPT |SHADER )?ERROR|leaked at exit"; then
	echo "ENGINE/SCRIPT ERRORS DETECTED -> run treated as failed"
	exit 1
fi
exit $CODE
