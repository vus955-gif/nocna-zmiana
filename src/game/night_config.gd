class_name NightConfig
extends RefCounted
## One night as drawn by NightDirector from the night seed: the modifier,
## where the crystal lies, which door is locked, which exhibits stand where,
## what loot lies where and which fuse points hold the fuses.

## One exhibit to place: an index into the level's spawn_slots, the kind
## drawn from the slot's kinds, and whether it waits dormant.
class Spawn:
	var slot: int = 0
	var kind: StringName = &""
	var dormant: bool = true

	func _init(slot_index: int, exhibit_kind: StringName, is_dormant: bool) -> void:
		slot = slot_index
		kind = exhibit_kind
		dormant = is_dormant


var night_seed: int = 0
var night: int = 1
## &"none", &"blackout", &"full_moon" or &"calm".
var modifier: StringName = &"none"
## Marker id of the crystal candidate case holding the crystal.
var crystal_case: StringName = &""
## Id of the door locked tonight, &"" for none.
var locked_door: StringName = &""
## Room id -> chosen encounter set id.
var encounter_sets: Dictionary = {}
var spawns: Array[Spawn] = []
## Loot spot index -> item (&"bullets", &"shells", &"medkit" or an
## artifact id). Spots not listed stay empty.
var loot: Dictionary = {}
## Artifacts placed tonight (also in [member loot]).
var artifacts: Array[StringName] = []
## Wing id (&"A", &"B") -> fuse point marker id.
var fuses: Dictionary = {}
## Painting spots (marker ids) whose painting is a portrait tonight.
var portraits: Array[StringName] = []


## Plain-data copy (for comparing nights, logs and bug reports).
func to_dict() -> Dictionary:
	var placed: Array = []
	for spawn in spawns:
		placed.append([spawn.slot, String(spawn.kind), spawn.dormant])
	var items := {}
	for spot: int in loot:
		items[spot] = String(loot[spot])
	return {
		"seed": night_seed,
		"night": night,
		"modifier": String(modifier),
		"crystal_case": String(crystal_case),
		"locked_door": String(locked_door),
		"encounter_sets": encounter_sets.duplicate(),
		"spawns": placed,
		"loot": items,
		"artifacts": artifacts.map(func(id: StringName) -> String: return String(id)),
		"fuses": fuses.duplicate(),
		"portraits": portraits.map(func(id: StringName) -> String: return String(id)),
	}


## Number of placed exhibits in [param room] (needs the level's slots).
func spawn_count(room: StringName, slots: Array[SpawnSlot]) -> int:
	return spawns.filter(func(s: Spawn) -> bool: return slots[s.slot].room == room).size()
