#!/usr/bin/env bash
# Content dev arena (the 1.10 expansion): every weapon incl. the gatling and
# the flare gun, the chained display, the fire cabinet, a gallery wall with
# live portraits among paintings, raptor packs, belt and flare pickups.
#   bash tools/run_content.sh            play it (window; silent unless SOUND=1)
#   bash tools/run_content.sh --shots    silent window, screenshots -> tests/_out/content/
#   bash tools/run_content.sh --dry      no window (--headless): stages every
#                                        screenshot moment, checks the states
# Keys in the arena: 4 gatling, 5 flare gun, F9 raptor pack, P new portraits,
# G all weapons + full ammo, L lights on/off, F5/F6/F7 wax/wolves/knight,
# F8 clear (plus the usual guard controls, F1 help).
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64_console.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"$GODOT" --headless --path . --import > /dev/null 2>&1
SCENARIO=res://tests/scenarios/content_scenario.tscn
case "${1:-}" in
	--shots|--dry)
		MODE="${1#--}"
		# a window, never fullscreen (the project default): the owner works here
		WINDOW=(--windowed)
		[ "$MODE" = "dry" ] && WINDOW=(--headless)
		OUT=$("$GODOT" "${WINDOW[@]}" --audio-driver Dummy --path . "$SCENARIO" -- --mode="$MODE" 2>&1)
		echo "$OUT" | grep -vE "^\s*$"
		if echo "$OUT" | grep -qE "^(USER |SCRIPT )?ERROR|MISSED"; then
			echo "ENGINE/SCRIPT ERRORS OR MISSED MOMENTS DETECTED"
			exit 1
		fi
		;;
	*)
		"$GODOT" "${AUDIO[@]}" --path . res://src/dev/content_dev.tscn
		;;
esac
