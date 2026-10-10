class_name CrystalRoute
## Where the woken crystal flies (design 7.3): out of its case, up to a
## cruising height over the room's exhibits, through the doors of the
## shortest way to the boss's room (room graph, doors kept open), then to
## a point beside the skeleton and in between its ribs. Pure data from the
## layout, so it can be checked without a scene.

## Cruising height over a room's floor (never closer than CEILING_GAP to
## its ceiling): over busts, racks, rocks and the gallery's 4.5 m figure.
const CRUISE := 5.0
const CEILING_GAP := 1.2
## Height over a doorway's floor while passing it (at least DOOR_GAP under
## its top).
const DOOR_HEIGHT := 2.4
const DOOR_GAP := 0.8
## Waypoints this far in front of and behind a doorway's wall.
const DOOR_LEAD := 1.6
## The crystal first lifts this far straight up out of its case.
const LIFT := 1.2
## The last approach to the socket starts here (beside the ribs, south).
const APPROACH := Vector3(0.0, 0.6, 5.0)


## The flight from the crystal lying at [param start] in [param start_room]
## to [param socket] in [param target_room] (doors in [param closed] are
## avoided; gates and panels in [param opened] count as open). The first
## point is straight above the case.
static func build(layout: LevelLayout, start: Vector3, start_room: StringName, target_room: StringName, socket: Vector3, closed: Array[StringName] = [], opened: Array[StringName] = []) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.append(start + Vector3.UP * LIFT)
	var room := layout.room(start_room)
	points.append(Vector3(start.x, cruise_height(room, start.y), start.z))
	var builder := LevelBuilder.new(layout, null, null, null)
	var current := start_room
	for door in layout.graph().route(start_room, target_room, closed, opened):
		var passage := layout.opening(door)
		if passage == null:
			# a flight of stairs (the balcony over the hall): nothing to thread
			current = _other_side(layout, door, current)
			continue
		var frame := builder.passage_frame(passage)
		var ahead := -frame.basis.z   # from room A to room B
		if current == passage.room_b:
			ahead = -ahead
		var height := passage.floor_y + minf(DOOR_HEIGHT, passage.height() - DOOR_GAP)
		var middle := Vector3(frame.origin.x, height, frame.origin.z)
		var lead := passage.depth() * 0.5 + DOOR_LEAD
		var before := middle - ahead * lead
		var after := middle + ahead * lead
		var next := passage.room_b if current == passage.room_a else passage.room_a
		# over the room at cruising height, down in front of the doorway,
		# through it, and up again on the other side
		points.append(Vector3(before.x, points[points.size() - 1].y, before.z))
		points.append(before)
		points.append(after)
		points.append(Vector3(after.x, cruise_height(layout.room(next), after.y), after.z))
		current = next
	points.append(socket + APPROACH)
	points.append(socket)
	return points


## Cruising height in [param room] (for a crystal found at [param from_y]
## when the room is unknown).
static func cruise_height(room: RoomSpec, from_y: float) -> float:
	if room == null:
		return from_y + LIFT
	return minf(room.floor_y + CRUISE, room.ceiling_y - CEILING_GAP)


## Length of the whole flight (m).
static func length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func _other_side(layout: LevelLayout, link: StringName, from: StringName) -> StringName:
	var rooms := layout.graph().door_rooms(link)
	if rooms.size() != 2:
		return from
	return rooms[1] if rooms[0] == from else rooms[0]
