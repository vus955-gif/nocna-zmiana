class_name LootSpot
extends RefCounted
## One place loot may appear. [member container] marks display cases,
## sarcophagi and secret rooms (artifacts prefer those).

var position := Vector3.ZERO
var room: StringName = &""
var container: bool = false


static func make(at: Vector3, room_id: StringName, is_container: bool = false) -> LootSpot:
	var spot := LootSpot.new()
	spot.position = at
	spot.room = room_id
	spot.container = is_container
	return spot
