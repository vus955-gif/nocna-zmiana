class_name SpawnSlot
extends RefCounted
## One exhibit spawn point. Slots sharing a room and set_id form an encounter
## set; NightDirector chooses one set per room each night.

## set_id of slots placed every night whatever set the room draws (ambushes,
## patrols the design needs). Floor I only; the NightDirector learns it in
## stage P1 part B (W1).
const ALWAYS_SET := -1

var position := Vector3.ZERO
var yaw: float = 0.0
var room: StringName = &""
var set_id: int = 0
## Exhibit kinds allowed here (&"wax", &"wolf", &"knight", &"bust").
var kinds: Array[StringName] = []
## Dormant exhibits wait for the guard; awake ones patrol/chase at once.
var dormant: bool = true
## Floor I zone of the slot's room (filled in by Floor1Layout).
var zone: StringName = &""
## PatrolSpec id this exhibit walks (&"" = it keeps its post).
var patrol: StringName = &""


static func make(at: Vector3, room_id: StringName, set_index: int, allowed: Array[StringName], is_dormant: bool = true, facing: float = 0.0) -> SpawnSlot:
	var slot := SpawnSlot.new()
	slot.position = at
	slot.room = room_id
	slot.set_id = set_index
	slot.kinds = allowed
	slot.dormant = is_dormant
	slot.yaw = facing
	return slot
