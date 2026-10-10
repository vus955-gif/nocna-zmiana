extends TestCase
## The hub of Floor I built and walked (workstream W2; plan
## docs/superpowers/plans/2026-10-03-p1-w2-hub.md): with every gate open
## (the secrets' zone gates too) the navmesh reaches from the staff corridor
## to every hub room, every exhibit post, loot spot, patrol point and every
## marker outside the haven (haven floors are a navmesh of their own);
## with the gates shut the first night reaches the entrance hall, the court
## and the balcony but not the Reading Room, the north corridor, the crypt
## or the secret rooms, and the Owl Seal opens the Reading Room. The
## landmarks are in sight where the design wants them.

const NavProbe := preload("res://tests/support/nav_probe.gd")
const HUB_ZONES: Array[StringName] = [&"booth", &"entrance", &"court", &"north_hall"]
## The staff corridor, just outside the start haven.
const START := Vector3(22, 0, 41.5)
const REACH := 1.0
const LAYERS := LevelNavigation.WALK_LAYER

var level: MuseumFloorLevel


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _build(open_gates: bool) -> void:
	level = MuseumFloorLevel.new()
	if open_gates:
		for gate in level.layout.gates:
			level.gates_open.append(gate.id)
	add_child(level)
	level.build()
	await physics_frames(4)


func _is_hub_room(room_id: StringName) -> bool:
	var room := level.layout.room(room_id)
	return room != null and HUB_ZONES.has(room.zone)


func _map() -> RID:
	return level.walk_region.get_navigation_map()


## True when the navmesh leads from START to within REACH of [param target]
## (the target itself within REACH of the mesh; a goal on a sealed island,
## like a prop's top, is not asked for: NavProbe).
func _reaches(target: Vector3) -> bool:
	var map := _map()
	var goal := NavigationServer3D.map_get_closest_point(map, target)
	if goal.distance_to(target) > REACH:
		return false
	var start := NavigationServer3D.map_get_closest_point(map, START)
	if not NavProbe.connected(map, start, goal, LAYERS):
		return false
	var path := NavigationServer3D.map_get_path(map, start, goal, true, LAYERS)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) < 0.5


## A marker is reached at its point or beside it (up to 3.5 m in front,
## behind or to a side: big props like the pedestal), at its own height or
## on its room's floor.
func _marker_reached(id: StringName) -> bool:
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
			if _reaches(q):
				return true
	return false


## A floor point of [param room] on the navmesh, nearest its first part's
## middle, never over a flight or a solid piece of the room.
func _floor_point(room: RoomSpec) -> Vector3:
	var map := _map()
	var part := room.parts[0]
	var middle := part.get_center()
	var candidates: Array[Vector3] = []
	var x := part.position.x + 0.5
	while x < part.end.x:
		var z := part.position.y + 0.5
		while z < part.end.y:
			candidates.append(Vector3(x, room.floor_y, z))
			z += 1.0
		x += 1.0
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x, a.z).distance_squared_to(middle) < Vector2(b.x, b.z).distance_squared_to(middle))
	var blocked: Array[Rect2] = []
	for flight in level.layout.stairs:
		blocked.append(flight.rect.grow(0.5))
	for piece in level.layout.pieces:
		if piece.collide and piece.room == room.id:
			blocked.append(piece.footprint().grow(0.5))
	for point in candidates:
		if blocked.any(func(area: Rect2) -> bool: return area.has_point(Vector2(point.x, point.z))):
			continue
		var snapped := NavigationServer3D.map_get_closest_point(map, point)
		if snapped.distance_to(point) < 0.6 and level.room_at(snapped + Vector3.UP * 0.5) == room.id:
			return snapped
	return Vector3(middle.x, room.floor_y, middle.y)


func test_with_everything_open_the_whole_hub_is_walkable() -> void:
	await _build(true)
	for room in level.layout.rooms:
		if not HUB_ZONES.has(room.zone) or room.haven:
			continue
		var target := _floor_point(room)
		assert_true(_reaches(target), "%s walkable from the staff corridor (%s)" % [room.id, target])
	for slot in level.layout.spawn_slots:
		if _is_hub_room(slot.room):
			assert_true(_reaches(slot.position), "exhibit post %s in %s on the navmesh" % [slot.position, slot.room])
	for spot in level.layout.loot_spots:
		if _is_hub_room(spot.room) and spot.position.y <= level.layout.room(spot.room).floor_y + 0.01:
			assert_true(_reaches(spot.position), "loot %s in %s reachable" % [spot.position, spot.room])
	for patrol in level.layout.patrols:
		if _is_hub_room(patrol.room):
			for point in patrol.points:
				assert_true(_reaches(point), "patrol %s point %s on the navmesh" % [patrol.id, point])
	for id: StringName in level.layout.markers:
		if not _is_hub_room(level.layout.marker_rooms[id]) or level.layout.room(level.layout.marker_rooms[id]).haven:
			continue
		if String(id).begins_with("crystal_path_") or (String(id).begins_with("cctv_") and id != &"cctv_wall"):
			continue   # in the air
		assert_true(_marker_reached(id), "marker %s reachable" % id)
	# the balcony runs round the drum's north from landing to landing
	var west_foot := Vector3(-16.5, 7, -1.5)
	var east_top := Vector3(16.5, 7, -1.5)
	var map := _map()
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, west_foot), NavigationServer3D.map_get_closest_point(map, east_top), true, LAYERS)
	var climbs := false
	for point in path:
		if point.y > 6.5 and point.z < -12.0:
			climbs = true
	assert_true(climbs, "from the west landing round the north of the balcony to the east landing")


func test_landmarks_are_in_sight() -> void:
	await _build(true)
	var space := level.get_world_3d().direct_space_state
	# stepping out of the staff door: the till and the fire cabinet
	var door := Vector3(15.6, 1.7, 42.0)
	var drawer: Transform3D = level.layout.markers[&"ticket_drawer"]
	var cabinet: Transform3D = level.layout.markers[&"flare_cabinet"]
	for target in [drawer.origin - drawer.basis.z * 0.3, cabinet.origin - cabinet.basis.z * 0.3]:
		assert_true(_clear(space, door, target), "seen from the staff door: %s" % target)
	# the drum through the court's arch from the entrance hall
	assert_true(_clear(space, Vector3(0, 1.7, 44), Vector3(0, 6, 12.9)), "the drum seen from the entrance hall")
	# the T-Rex from the Enlightenment's doorway
	var trex: Transform3D = level.layout.markers[Floor1Plan.TREX_MARKER]
	assert_true(_clear(space, Vector3(29, 1.7, 0), trex.origin + Vector3.UP * 3.0), "the T-Rex seen from the east door")
	# the gatling from the Reading Room's door, past the astrolabe
	var gatling: Transform3D = level.layout.markers[&"gatling_case"]
	assert_true(_clear(space, Vector3(0.9, 1.7, -10.6), gatling.origin + Vector3(1.0, 1.4, -0.7)), "the gatling seen from the north door")


func test_shut_gates_keep_the_first_night_in_the_south() -> void:
	await _build(false)
	for room_id: StringName in [&"entrance_hall", &"entrance_gallery", &"court_balcony", &"booth_stairs", &"booth_staff"]:
		assert_true(_reaches(_floor_point(level.layout.room(room_id))), "%s open on the first night" % room_id)
	for point in [Vector3(0, 0, 16), Vector3(-22, 0, -22), Vector3(22, 0, -22), Vector3(0, 0, -27.5)]:
		assert_true(_reaches(point), "the court round the drum open on the first night (%s)" % point)
	for room_id: StringName in [&"court_reading", &"north_hall", &"north_hall_crypt", &"booth_watch", &"entrance_coat_store", &"north_hall_lodge"]:
		assert_false(_reaches(_floor_point(level.layout.room(room_id))), "%s shut on the first night" % room_id)
	level.open_gate(&"gate_reading_room", true)
	await level.navigation.rebaked
	await physics_frames(4)
	assert_true(_reaches(_floor_point(level.layout.room(&"court_reading"))), "the Owl Seal opens the Reading Room")


func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		print("  sight %s -> %s blocked at %s by %s" % [from, to, hit["position"], (hit["collider"] as Node).name])
	return hit.is_empty()
