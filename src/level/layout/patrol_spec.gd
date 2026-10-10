class_name PatrolSpec
extends RefCounted
## A patrol route inside one room (or across its territory): the exhibit of
## every spawn slot whose SpawnSlot.patrol names this id walks the points in
## order (Enemy.patrol_route) instead of keeping its post.

var id: StringName = &""
## Room the route starts in (the walker's home room).
var room: StringName = &""
## Floor points (y = the floor under each), at least two.
var points := PackedVector3Array()
## True: after the last point back to the first; false: there and back.
var loop: bool = true


static func make(patrol_id: StringName, room_id: StringName, route: PackedVector3Array, is_loop: bool = true) -> PatrolSpec:
	var patrol := PatrolSpec.new()
	patrol.id = patrol_id
	patrol.room = room_id
	patrol.points = route
	patrol.loop = is_loop
	return patrol


## Length of one round (m).
func length() -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	if loop and points.size() > 2:
		total += points[points.size() - 1].distance_to(points[0])
	return total
