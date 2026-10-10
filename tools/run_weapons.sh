#!/usr/bin/env bash
# Floor I weapons and gate locks dev arena: all eight weapons (the rifle,
# the harpoon gun and the fire-arrow chest included, ammo full), their ammo
# boxes, every gate lock in a doorway under the mezzanine, the canoe on its
# hook, wolves before the west wall (pin them), heavier wax figures (pull
# them). Nothing is saved.
#   bash tools/run_weapons.sh     play it (window; silent unless SOUND=1)
# Keys: 6 rifle, 7 harpoon, 8 fire-arrow chest, G all weapons + full ammo,
# K fresh locks and exhibits, U every upgrade (master finish), J none,
# F5/F6/F7 wax/wolves/knight, F8 clear, F9 raptor pack, L lights, F1 help.
cd "$(dirname "$0")/.." || exit 1
. tools/dev_env.sh
GODOT="tools/godot/Godot_v4.7.2-stable_win64.exe"
AUDIO=(--audio-driver Dummy)
[ "${SOUND:-0}" = "1" ] && AUDIO=()
"tools/godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import > /dev/null 2>&1
"$GODOT" "${AUDIO[@]}" --path . res://src/dev/weapons_dev.tscn
