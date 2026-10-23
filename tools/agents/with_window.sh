#!/usr/bin/env bash
# Runs ONE windowed command while holding the PC-wide window lock, so parallel
# agents never open Godot windows at the same time. From a worktree or the main
# checkout:   bash tools/agents/with_window.sh bash tools/run_tour.sh shots --only=a,b
# Audio stays muted (the tools use --audio-driver Dummy by default; SOUND is unset).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# one lock for every worktree: the main checkout's .claude folder (git ignores it)
MAIN="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
LOCK="${MAIN%/.git}/.claude/window.lock"
mkdir -p "$(dirname "$LOCK")"
while ! mkdir "$LOCK" 2>/dev/null; do
	# a lock older than 25 minutes is stale (its holder died)
	if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +25 2>/dev/null)" ]; then
		rm -rf "$LOCK"; continue
	fi
	sleep 10
done
echo "$$ $(date +%H:%M:%S) $*" > "$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT INT TERM
unset SOUND
"$@"
