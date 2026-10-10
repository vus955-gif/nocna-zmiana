class_name Level
extends Node3D
## A playable level (shared contract of stages 2a/2b). The Museum game scene
## adds the level to the tree, calls build(), then reads the fields below to
## place the guard, havens, exhibits and loot. Subclasses: SandboxLevel (2a
## stand-in built on SandboxArena), LobbyLevel (2b, the real museum lobby).

## Where and how the guard starts a night when no other haven is chosen.
var player_start := Transform3D.IDENTITY
## Haven id (&"security", &"closet", ...) -> transform of its upgrade terminal
## spot (origin on the floor, -Z facing into the room).
var haven_spots: Dictionary = {}
## Haven id -> AABB of its safe zone in world space (optional; without it
## the Museum makes a 6 x 3 x 6 m zone in front of the terminal spot).
var haven_zones: Dictionary = {}
## Every place an exhibit may appear; NightDirector picks from these.
var spawn_slots: Array[SpawnSlot] = []
## Every place ammo, medkits or artifacts may appear.
var loot_spots: Array[LootSpot] = []
## Anything that falls below this height fell out of the level (exhibits
## are removed there).
var kill_plane_y: float = DEFAULT_KILL_PLANE

const DEFAULT_KILL_PLANE := -30.0

## Kill plane of the level in the scene (the default without one).
static var _active_kill_plane: float = DEFAULT_KILL_PLANE


static func kill_plane() -> float:
	return _active_kill_plane


func _enter_tree() -> void:
	_active_kill_plane = kill_plane_y


func _exit_tree() -> void:
	if is_equal_approx(_active_kill_plane, kill_plane_y):
		_active_kill_plane = DEFAULT_KILL_PLANE


## Builds geometry, lights and navigation. Call once, after entering the tree.
func build() -> void:
	pass
