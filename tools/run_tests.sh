#!/usr/bin/env bash
# Imports the project, then runs the headless tests. Extra arguments go to
# the runner, e.g.:  bash tools/run_tests.sh --filter=stamina
#
#   bash tools/run_tests.sh                  all tests, one Godot process
#   bash tools/run_tests.sh --parallel       ... in N processes (auto: a quarter
#                                            of the CPU threads, 2..6)
#   bash tools/run_tests.sh -j 4             ... in 4 processes
#   bash tools/run_tests.sh --quick          only the quick subset (tests/quick_tests.txt)
#   bash tools/run_tests.sh --filter=a,b     only files whose name contains a or b
#   NZ_TEST_JOBS=4 bash tools/run_tests.sh   same as -j 4 (an option wins)
#   bash tools/run_tests.sh --no-import      skip the project import (about 13 s): only
#                                            when no resource, no class_name and no
#                                            .import file changed since the last run
#   GODOT_BIN=/path/to/godot                 another engine binary (CI on Linux)
#   NZ_TEST_SLACK=3                          wall-clock budgets in tests x3 (slow machine; the
#                                            default is 1, and 2 with several processes)
#
# Fails if any test fails OR Godot prints an ERROR line (incl. leaks at exit).
# With several processes a shard that crashed (no summary line) fails too.
# --fixed-fps 60: every frame advances the game by exactly 1/60 s (physics
# steps stay 1/60 s) but frames run flat out instead of waiting for the wall
# clock, so the suite takes minutes instead of an hour. Timers and waits in
# tests count game time; only the runner's final wait uses real time.
# (Scenarios and perf runs stay real-time: they do not use this script.)
#
# Parallel runs: the runner splits the test files into N groups of about equal
# recorded wall time (tests/test_durations.tsv), one Godot process each
# (--shards=N --shard=k); every shard keeps its saves in tests/_out/saves_k and
# its output in tests/_out/shards/k.log, and the logs are printed one after
# the other at the end. The processes run at below-normal priority on
# Windows, so the PC stays usable. Memory: about 3 GB per process.
# Refresh the recorded times after big changes of the suite (the file is
# only rewritten by a complete green run; use an otherwise idle PC):
#   bash tools/run_tests.sh --parallel --timings=tests/test_durations.tsv
cd "$(dirname "$0")/.." || exit 1

case "$(uname -s)" in
	MINGW* | MSYS* | CYGWIN*)
		. tools/dev_env.sh
		DEFAULT_GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
		WINDOWS=1
		;;
	*)
		DEFAULT_GODOT="$(command -v godot || echo godot)"
		WINDOWS=0
		;;
esac
GODOT="${GODOT_BIN:-$DEFAULT_GODOT}"

JOBS="${NZ_TEST_JOBS:-1}"
ARGS=()
TIMINGS=""
IMPORT=1
while [ $# -gt 0 ]; do
	case "$1" in
		-j | --jobs)
			JOBS="$2"
			shift
			;;
		-j[0-9]*) JOBS="${1#-j}" ;;
		--jobs=*) JOBS="${1#--jobs=}" ;;
		--parallel | --parallel=auto) JOBS=auto ;;
		--parallel=*) JOBS="${1#--parallel=}" ;;
		--timings=*) TIMINGS="${1#--timings=}" ;;
		--no-import) IMPORT=0 ;;
		*) ARGS+=("$1") ;;
	esac
	shift
done
if [ "$JOBS" = "auto" ]; then
	THREADS="$(nproc 2> /dev/null || echo 4)"
	JOBS=$((THREADS / 4))
	[ "$JOBS" -lt 2 ] && JOBS=2
	[ "$JOBS" -gt 6 ] && JOBS=6
fi
case "$JOBS" in
	'' | *[!0-9]* | 0)
		echo "bad number of processes: '$JOBS'"
		exit 2
		;;
esac

[ "$IMPORT" -eq 1 ] && "$GODOT" --headless --path . --import > /dev/null 2>&1

# The engine's error lines (also leaks at exit).
ENGINE_ERRORS='^(USER |SCRIPT |SHADER )?ERROR|leaked at exit'

if [ "$JOBS" -eq 1 ]; then
	[ -n "$TIMINGS" ] && ARGS+=("--timings=$TIMINGS")
	OUT=$("$GODOT" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- "${ARGS[@]}" 2>&1)
	CODE=$?
	echo "$OUT"
	if echo "$OUT" | grep -qE "$ENGINE_ERRORS"; then
		echo "ENGINE/SCRIPT ERRORS DETECTED -> run treated as failed"
		exit 1
	fi
	exit $CODE
fi

# --- several processes -----------------------------------------------------
# budgets in wall-clock time (TestCase.slack) are doubled: the processes share the CPU
export NZ_TEST_SLACK="${NZ_TEST_SLACK:-2}"
if [ "$WINDOWS" -eq 1 ]; then
	# the shards inherit the priority of this shell
	powershell.exe -NoProfile -Command "(Get-Process -Id $(cat /proc/$$/winpid)).PriorityClass = 'BelowNormal'" > /dev/null 2>&1
fi
LOGS="tests/_out/shards"
rm -rf "$LOGS"
mkdir -p "$LOGS"
START=$SECONDS
PIDS=()
# no Godot process is left behind when the run is interrupted
trap 'kill "${PIDS[@]}" 2> /dev/null' INT TERM
for ((K = 0; K < JOBS; K++)); do
	# every shard measures its own files; the times are merged afterwards
	SHARD_ARGS=("${ARGS[@]}" --shards="$JOBS" --shard="$K")
	[ -n "$TIMINGS" ] && SHARD_ARGS+=("--timings=$LOGS/$K.tsv")
	"$GODOT" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- "${SHARD_ARGS[@]}" > "$LOGS/$K.log" 2>&1 &
	PIDS+=($!)
done

FAILED=0
PASSED_TOTAL=0
FAILED_TOTAL=0
for ((K = 0; K < JOBS; K++)); do
	wait "${PIDS[$K]}"
	CODE=$?
	LOG="$LOGS/$K.log"
	sed -i 's/\r$//' "$LOG"
	echo "=== shard $((K + 1))/$JOBS (done $((SECONDS - START)) s into the run) ==="
	sed -E "s/^([0-9]+ passed, [0-9]+ failed)\$/shard $((K + 1)): \1/" "$LOG"
	SUMMARY=$(grep -E '^[0-9]+ passed, [0-9]+ failed$' "$LOG" | tail -1)
	if [ -z "$SUMMARY" ]; then
		echo "SHARD $((K + 1)) PRODUCED NO SUMMARY (crashed or aborted, exit code $CODE) -> run treated as failed"
		FAILED=1
		continue
	fi
	PASSED_TOTAL=$((PASSED_TOTAL + $(echo "$SUMMARY" | cut -d' ' -f1)))
	FAILED_TOTAL=$((FAILED_TOTAL + $(echo "$SUMMARY" | cut -d' ' -f3)))
	[ "$CODE" -ne 0 ] && FAILED=1
	if grep -qE "$ENGINE_ERRORS" "$LOG"; then
		echo "ENGINE/SCRIPT ERRORS DETECTED in shard $((K + 1)) -> run treated as failed"
		FAILED=1
	fi
done
[ "$FAILED_TOTAL" -gt 0 ] && FAILED=1
if [ "$PASSED_TOTAL" -eq 0 ]; then
	echo "NO TESTS RAN"
	FAILED=1
fi
# a complete, green run refreshes the recorded times
if [ -n "$TIMINGS" ] && [ "$FAILED" -eq 0 ]; then
	{
		echo "# Wall milliseconds per test file: name, ms, tests (tab-separated). Only the proportions matter:"
		echo "# tools/run_tests.sh --parallel balances the shards by them. Refresh after big changes of the suite:"
		echo "#   bash tools/run_tests.sh --parallel --timings=tests/test_durations.tsv"
		echo "# (a complete green run rewrites this file; the numbers of a parallel run are larger than a single process's)."
		cat "$LOGS"/*.tsv | sort
	} > "$TIMINGS"
fi
echo
echo "$PASSED_TOTAL passed, $FAILED_TOTAL failed"
echo "TOTAL  $((SECONDS - START)) s wall in $JOBS processes"
exit $FAILED
