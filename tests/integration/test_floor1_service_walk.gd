extends TestCase
## The basement and the roof on the built floor (P1 / W5b; plan
## docs/superpowers/plans/2026-10-03-p1-w5b-podziemia-dach.md):
## - every gate open: from the workshop's door the navmesh reaches beyond
##   every wing's bolted basement door (the shortcut hub), every basement
##   and roof room (secrets too; the haven bakes into its own region), the
##   boiler gantry under the fuse and every marker the game reads; the roof
##   walk climbs from the entrance hall's landing up the tower and over the
##   catwalks to the Enlightenment's door; every exhibit post, floor loot
##   spot and patrol stands on the navmesh in the clear (a 0.42 x 2 m
##   capsule) and every patrol leg is a straight walk;
## - only the booth's boards (and the roof's rope) open: from the foot of
##   the staff stairs the workshop, the fuse and the switchboard are
##   reached, but no wing through its bolted door and no secret; on the roof
##   the Enlightenment's bolt holds.

const NavProbe := preload("res://tests/support/nav_probe.gd")
## A navmesh path must end this close to its target to count.
const REACH := 1.5
const SERVICE: Array[StringName] = [&"basement", &"roof"]
const WINGS := {
	&"j_basement_egypt": &"egypt", &"j_basement_assyria": &"assyria", &"j_basement_greece": &"greece",
	&"j_basement_enlightenment": &"enlightenment", &"j_basement_americas": &"americas", &"j_basement_asia": &"asia",
}
## In the crossing, just outside the workshop's north door.
const WORKSHOP_DOOR := Vector3(0, -6, -4.0)
## The foot of the booth's staff stairs, on the booth's side of the boards.
const STAFF_STAIRS := Vector3(18.0, -6, 37.75)
## In front of the switchboard.
const SWITCHBOARD := Vector3(20.25, -6, -31.5)
## The freight bay at the tunnel's west end.
const FREIGHT_BAY := Vector3(-52.0, -6, -34.6)

var level: MuseumFloorLevel


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _build(open: Array, every_gate: bool = false) -> void:
	level = MuseumFloorLevel.new()
	if every_gate:
		for gate in level.layout.gates:
			level.gates_open.append(gate.id)
	else:
		for id: StringName in open:
			level.gates_open.append(id)
	add_child(level)
	level.build()
	await physics_frames(4)   # the navigation map syncs after the bake


func _is_service_room(room_id: StringName) -> bool:
	var room := level.layout.room(room_id)
	return room != null and SERVICE.has(room.zone)


## Length of the navmesh path from [param from] to [param to]; INF when it
## does not get there. A goal on a sealed island (a prop's top) is not
## asked for, and the search has no polygon budget: the basement to the
## roof is a long climb (NavProbe).
func _path_length(from: Vector3, to: Vector3) -> float:
	var map := level.walk_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	if not NavProbe.connected(map, start, NavigationServer3D.map_get_closest_point(map, to), LevelNavigation.WALK_LAYER):
		return INF
	var path := NavProbe.path(map, start, to, LevelNavigation.WALK_LAYER)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > REACH or start.distance_to(from) > REACH:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## A floor point 2.5 m beyond junction [param id] on [param zone]'s side
## (found 1 m over the floor: the roof's side of a doorway at y 22.5 would
## otherwise lie on the court's box, which ends there).
func _beyond(id: StringName, zone: StringName) -> Vector3:
	return Floor1Plan.junction(id).point_in(zone, 2.5, 1.0) + Vector3.DOWN


## A navmesh point on [param room]'s own floor, near the middle of its
## first part if possible (never over a flight or inside a solid piece
## standing on that floor: Recast leaves sealed islands in stair ramps and
## solid blocks).
func _floor_point(room: RoomSpec) -> Vector3:
	var map := level.walk_region.get_navigation_map()
	var candidates: Array[Vector3] = []
	for part in room.parts:
		var x := part.position.x + 0.25
		while x < part.end.x:
			var z := part.position.y + 0.25
			while z < part.end.y:
				candidates.append(Vector3(x, room.floor_y, z))
				z += 0.5
			x += 0.5
	var middle := room.parts[0].get_center()
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x, a.z).distance_squared_to(middle) < Vector2(b.x, b.z).distance_squared_to(middle))
	var blocked: Array[Rect2] = []
	for flight in level.layout.stairs:
		blocked.append(flight.rect.grow(0.5))
	for piece in level.layout.pieces:
		if piece.collide and piece.position.y <= room.floor_y + 0.1 and piece.position.y + piece.size.y > room.floor_y + 0.3:
			blocked.append(piece.footprint().grow(0.5))
	for point in candidates:
		if blocked.any(func(area: Rect2) -> bool: return area.has_point(Vector2(point.x, point.z))):
			continue
		var snapped := NavigationServer3D.map_get_closest_point(map, point)
		if Vector2(snapped.x - point.x, snapped.z - point.z).length() < 0.3 and absf(snapped.y - room.floor_y) < 0.3 and level.room_at(snapped + Vector3.UP * 0.5) == room.id:
			return snapped
	return Vector3.INF


func _capsule_clear(at: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.05)
	return level.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_navmesh(at: Vector3) -> bool:
	var snapped := NavigationServer3D.map_get_closest_point(level.walk_region.get_navigation_map(), at)
	return Vector2(snapped.x - at.x, snapped.z - at.z).length() < 0.5 and absf(snapped.y - at.y) < 0.4


## A marker is reached at its point or beside it (up to 3.5 m in front,
## behind or to a side), at its own height or on its room's floor.
func _marker_reached(id: StringName, from: Vector3) -> bool:
	var at: Transform3D = level.layout.markers[id]
	var room := level.layout.room(level.layout.marker_rooms[id])
	var front := -at.basis.z
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	var side := front.cross(Vector3.UP)
	var probes: Array[Vector3] = [at.origin]
	for distance in [1.0, 2.0, 3.5]:
		for way in [front, -front, side, -side]:
			probes.append(at.origin + way * distance)
	for p in probes:
		for q in [p, Vector3(p.x, room.floor_y, p.z)]:
			if _path_length(from, q) < INF:
				return true
	return false


func test_with_every_gate_open_the_workshop_reaches_every_wing() -> void:
	await _build([], true)
	var lengths := {}
	for j_id: StringName in WINGS:
		var length := _path_length(WORKSHOP_DOOR, _beyond(j_id, WINGS[j_id]))
		lengths[WINGS[j_id]] = roundf(length)
		# Assyria is the farthest: its door is at the end of a 25 m tunnel
		assert_lt(length, 90.0, "from the workshop through %s's bolted door (%.0f m)" % [WINGS[j_id], length])
	print("  workshop -> wings: %s" % lengths)
	for room in level.layout.rooms:
		if not SERVICE.has(room.zone) or room.haven:
			continue
		var target := _floor_point(room)
		assert_ne(target, Vector3.INF, "%s has walkable floor" % room.id)
		if target != Vector3.INF:
			assert_lt(_path_length(WORKSHOP_DOOR, target), INF, "%s reached from the workshop" % room.id)
	var fuse: Vector3 = (level.markers[&"fuse_basement"] as Transform3D).origin
	var gantry := level.layout.room(&"basement_boiler_catwalk")
	assert_lt(_path_length(WORKSHOP_DOOR, Vector3(fuse.x, gantry.floor_y, fuse.z - 0.8)), 80.0, "up the gantry to the fuse (at its far end)")
	for id: StringName in level.layout.markers:
		if not _is_service_room(level.layout.marker_rooms.get(id, &"")) or String(id).begins_with("cctv_"):
			continue
		assert_true(_marker_reached(id, WORKSHOP_DOOR), "marker %s reachable" % id)
	# the roof walk: from the entrance hall's landing up the tower, over the
	# catwalks to the Enlightenment's stair tower
	var landing := _beyond(&"j_entrance_roof", &"entrance")
	var top := Vector3(35.7, Floor1Plan.ROOF_Y, 49.0)
	assert_lt(_path_length(landing, top), 80.0, "the tower climbs from the landing to the roof")
	var walk := _path_length(landing, _beyond(&"j_roof_enlightenment", &"enlightenment"))
	assert_lt(walk, 200.0, "from the landing over the roof into the Enlightenment (%.0f m)" % walk)
	print("  roof walk landing -> Enlightenment: %.0f m" % walk)
	# round the dome and out along each catwalk
	for point in [Vector3(0, 22.5, -21), Vector3(0, 22.5, 21), Vector3(-21, 22.5, 0), Vector3(21, 22.5, 0), Vector3(-13.9, 22.5, 0), Vector3(-28.25, 22.5, -23)]:
		assert_lt(_path_length(top, point), INF, "the roof walk reaches %s" % point)


func test_slots_loot_and_patrols_stand_on_the_navmesh_in_the_clear() -> void:
	await _build([], true)
	for slot in level.spawn_slots:
		if not SERVICE.has(slot.zone):
			continue
		assert_true(_on_navmesh(slot.position), "slot %s in %s is on the navmesh" % [slot.position, slot.room])
		assert_true(_capsule_clear(slot.position), "slot %s in %s is clear" % [slot.position, slot.room])
	for spot in level.loot_spots:
		var room := level.layout.room(spot.room)
		if room == null or not SERVICE.has(room.zone) or spot.container:
			continue
		assert_true(_on_navmesh(spot.position), "loot %s in %s is on the navmesh" % [spot.position, spot.room])
		assert_true(_capsule_clear(spot.position), "loot %s in %s is clear" % [spot.position, spot.room])
	for patrol in level.layout.patrols:
		if not _is_service_room(patrol.room):
			continue
		for i in range(1, patrol.points.size()):
			assert_lt(_path_length(patrol.points[i - 1], patrol.points[i]), patrol.points[i - 1].distance_to(patrol.points[i]) * 1.6, "%s leg %d is a straight walk" % [patrol.id, i])


func test_after_the_boards_the_basement_opens_but_the_bolts_hold() -> void:
	await _build([&"boards_staff_stairs", &"rope_roof_hatch"])
	for target in [WORKSHOP_DOOR, SWITCHBOARD, FREIGHT_BAY]:
		assert_lt(_path_length(STAFF_STAIRS, target), INF, "the first descent reaches %s" % target)
	var fuse: Vector3 = (level.markers[&"fuse_basement"] as Transform3D).origin
	var gantry := level.layout.room(&"basement_boiler_catwalk")
	assert_lt(_path_length(STAFF_STAIRS, Vector3(fuse.x, gantry.floor_y, fuse.z - 0.8)), INF, "and the fuse on the gantry")
	# no wing through its bolted door (round the long way, over the ground
	# floor, at best)
	for j_id: StringName in WINGS:
		var through := _path_length(_beyond(j_id, &"basement"), _beyond(j_id, WINGS[j_id]))
		assert_gt(through, 20.0, "%s's bolt holds (%.0f m)" % [WINGS[j_id], through])
	for room in level.layout.rooms:
		if not SERVICE.has(room.zone) or not room.secret:
			continue
		var target := _floor_point(room)
		if target == Vector3.INF:
			continue   # a shut room's floor may be cut off from every region
		assert_eq(_path_length(STAFF_STAIRS, target), INF, "%s stays shut behind its gate" % room.id)
	# the roof: up from the landing past the rope, but not through the bolt
	var landing := _beyond(&"j_entrance_roof", &"entrance")
	assert_lt(_path_length(landing, Vector3(28.25, Floor1Plan.ROOF_Y, 0)), INF, "the rope down, the roof is open")
	var roof_side := _beyond(&"j_roof_enlightenment", &"roof")
	assert_lt(_path_length(landing, roof_side), INF, "the roof's side of the Enlightenment's door")
	var bolt := _path_length(roof_side, _beyond(&"j_roof_enlightenment", &"enlightenment"))
	assert_gt(bolt, 20.0, "the Enlightenment's roof door stays bolted (%.0f m)" % bolt)
