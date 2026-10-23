#!/usr/bin/env bash
# The full no-cheat playthrough of Floor I (owner's #60; plan
# docs/superpowers/plans/2026-10-21-przejscie-bota.md): a headless bot plays
# the real game from a fresh save, night after night, through the input
# actions only, until it walks down into the crypt after the T-Rex.
# No window, no sound. One Godot at a time, seed after seed.
#   bash tools/run_playthrough.sh                 seed 1
#   bash tools/run_playthrough.sh 1 2 3           three seeds
#   bash tools/run_playthrough.sh 5 --time-scale=1 --nights=8 --grey --minutes=90 --until=colossus
# Output per seed in tests/_out/playthrough/<seed>/: report.html (Polish,
# for the owner), report.json, log.jsonl, stdout.txt. The run fails (exit 1)
# on any engine/script ERROR line; a seed that did not finish exits 2.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import > /dev/null 2>&1
SEEDS=()
ARGS=()
for a in "$@"; do
	case "$a" in
		--*) ARGS+=("$a") ;;
		*) SEEDS+=("$a") ;;
	esac
done
[ ${#SEEDS[@]} -eq 0 ] && SEEDS=(1)
STATUS=0
for S in "${SEEDS[@]}"; do
	OUTDIR="tests/_out/playthrough/$S"
	mkdir -p "$OUTDIR"
	"$GODOT" --headless --fixed-fps 60 --audio-driver Dummy --path . res://tests/scenarios/playthrough_scenario.tscn -- --seed="$S" "${ARGS[@]}" 2>&1 \
		| tee "$OUTDIR/stdout.txt" | grep --line-buffered -E "^PLAYTHROUGH|^\s+\[n[0-9]|^(USER |SCRIPT |SHADER )?ERROR"
	CODE=${PIPESTATUS[0]}
	if grep -qE "^(USER |SCRIPT |SHADER )?ERROR|leaked at exit" "$OUTDIR/stdout.txt"; then
		echo "seed $S: ENGINE/SCRIPT ERRORS (see $OUTDIR/stdout.txt)"
		STATUS=1
	elif [ "$CODE" != "0" ] && [ "$STATUS" = "0" ]; then
		STATUS=$CODE
	fi
done
exit $STATUS
