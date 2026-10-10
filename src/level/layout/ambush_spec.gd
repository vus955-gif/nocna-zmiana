class_name AmbushSpec
extends RefCounted
## Dormant exhibits that wake together when the guard walks into a trigger
## area or takes the item at a marker (the mummies in the sarcophagi round
## the shotgun). The woken exhibits start INVESTIGATE / HUNT as the
## perception module decides; the ambush only wakes them.

enum Trigger {
	## the guard enters [member area] between [member y_min] and [member y_max]
	AREA,
	## the guard takes the pickup standing at [member marker]
	PICKUP,
}

var id: StringName = &""
var room: StringName = &""
var trigger: Trigger = Trigger.AREA
## AREA: floor-plan rectangle (x, z).
var area := Rect2()
var y_min: float = -INF
var y_max: float = INF
## PICKUP: marker id of the pickup.
var marker: StringName = &""
## Indices into LevelLayout.spawn_slots of the exhibits it wakes.
var slots: Array[int] = []


static func on_area(ambush_id: StringName, room_id: StringName, zone_rect: Rect2, low: float, high: float, woken: Array[int]) -> AmbushSpec:
	var ambush := AmbushSpec.new()
	ambush.id = ambush_id
	ambush.room = room_id
	ambush.trigger = Trigger.AREA
	ambush.area = zone_rect
	ambush.y_min = low
	ambush.y_max = high
	ambush.slots = woken
	return ambush


static func on_pickup(ambush_id: StringName, room_id: StringName, pickup_marker: StringName, woken: Array[int]) -> AmbushSpec:
	var ambush := AmbushSpec.new()
	ambush.id = ambush_id
	ambush.room = room_id
	ambush.trigger = Trigger.PICKUP
	ambush.marker = pickup_marker
	ambush.slots = woken
	return ambush


## AREA: true when [param point] sets the ambush off.
func triggered_by(point: Vector3) -> bool:
	if trigger != Trigger.AREA or point.y < y_min or point.y > y_max:
		return false
	return area.has_point(Vector2(point.x, point.z))
