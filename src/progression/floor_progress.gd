class_name FloorProgress
extends RefCounted
## A plain snapshot of Floor I progress for ProgressRules (pure, no nodes):
## what the guard owns and what the museum has opened for good. Built from
## the save with from_game(); tests build their own.

## Weapon ids found (fists and the taser are always there, never listed).
var weapons: Array[StringName] = []
## Key items: &"pistol_key", &"fuse_basement", &"fuse_assyria".
var items: Array[StringName] = []
var seals: Array[StringName] = []
var shards: Array[StringName] = []
## Guardian ids defeated (and &"trex").
var guardians: Array[StringName] = []
## Gate ids opened for good.
var gates_open: Array[StringName] = []
## World flags: &"power_north", &"astrolabe", &"floor1_complete".
var flags: Array[StringName] = []


static func from_game(game: PersistentState) -> FloorProgress:
	var progress := FloorProgress.new()
	progress.weapons = game.weapons.duplicate()
	progress.items = game.items.duplicate()
	if game.pistol_key and not progress.items.has(&"pistol_key"):
		progress.items.append(&"pistol_key")
	progress.seals = game.seals.duplicate()
	progress.shards = game.shards.duplicate()
	progress.guardians = game.guardians_defeated.duplicate()
	progress.gates_open = game.gates_open.duplicate()
	progress.flags = game.flags.duplicate()
	return progress


func copy() -> FloorProgress:
	var other := FloorProgress.new()
	other.weapons = weapons.duplicate()
	other.items = items.duplicate()
	other.seals = seals.duplicate()
	other.shards = shards.duplicate()
	other.guardians = guardians.duplicate()
	other.gates_open = gates_open.duplicate()
	other.flags = flags.duplicate()
	return other


## True when [param entry] is in any list (a weapon, item, seal, shard,
## guardian, gate or flag id).
func has(entry: StringName) -> bool:
	return weapons.has(entry) or items.has(entry) or seals.has(entry) or shards.has(entry) \
		or guardians.has(entry) or gates_open.has(entry) or flags.has(entry)


static func add_to(list: Array[StringName], entry: StringName) -> void:
	if entry != &"" and not list.has(entry):
		list.append(entry)
