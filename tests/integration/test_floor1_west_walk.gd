extends TestCase
## Floor I west wings on the built floor (P1 / W3; plan
## docs/superpowers/plans/2026-10-03-p1-w3-egipt-grecja.md). Two builds:
## - every gate open: from each wing's way in, the navmesh reaches every
##   room of Egypt and Greece (secrets too; havens have their own region),
##   the mezzanines and
##   the stair tower join their levels, every exhibit slot and floor loot
##   spot stands on the navmesh in the clear (a 0.42 x 2 m capsule);
## - every gate shut (night 1): the shotgun is seen from the court door (a
##   physics ray) and walked to from the court, the Colossus is reached, and
##   the shut gates cut off Greece and the secret rooms.

const NavProbe := preload("res://tests/support/nav_probe.gd")
## A navmesh path must end this close to its target to count.
const REACH := 1.5
const EYE := 1.6
const WEST: Array[StringName] = [&"egypt", &"greece"]

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
	await physics_frames(4)   # the navigation map syncs after the bake


func _path_length(from: Vector3, to: Vector3, layers: int = LevelNavigation.WALK_LAYER) -> float:
	var map := level.walk_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	# a goal on a sealed island (a prop's top) is not reached; asking the
	# server for it would print an engine error (NavProbe)
	if not NavProbe.connected(map, start, NavigationServer3D.map_get_closest_point(map, to), layers):
		return INF
	var path := NavigationServer3D.map_get_path(map, start, to, true, layers)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > REACH or start.distance_to(from) > REACH:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## A floor point 2.5 m into the room behind junction [param id] on
## [param zone]'s side.
func _beyond(id: StringName, zone: StringName) -> Vector3:
	var j := Floor1Plan.junction(id)
	return j.point_in(zone, 2.5, 0.0)


func _west_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if WEST.has(room.zone):
			found.append(room)
	return found


## A navmesh point on [param room]'s own floor, near the middle of its
## parts if possible (never over a flight or inside a solid piece standing
## on that floor: Recast leaves sealed islands inside a stair ramp or a
## landing block; never on top of a crate or a plinth).
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
	var flights: Array[Rect2] = []
	for flight in level.layout.stairs:
		flights.append(flight.rect.grow(0.5))
	for piece in level.layout.pieces:
		if piece.collide and piece.position.y <= room.floor_y + 0.1 and piece.position.y + piece.size.y > room.floor_y + 0.3:
			flights.append(piece.footprint().grow(0.5))
	for point in candidates:
		if flights.any(func(area: Rect2) -> bool: return area.has_point(Vector2(point.x, point.z))):
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


func test_with_every_gate_open_the_west_wings_walk_end_to_end() -> void:
	await _build(true)
	var ways_in := {
		&"egypt": [_beyond(&"j_court_egypt", &"egypt"), _beyond(&"j_egypt_assyria", &"egypt"), _beyond(&"j_basement_egypt", &"egypt")],
		&"greece": [_beyond(&"j_egypt_greece", &"greece"), _beyond(&"j_assyria_greece", &"greece"), _beyond(&"j_entrance_greece", &"greece"), _beyond(&"j_basement_greece", &"greece")],
	}
	for zone: StringName in ways_in:
		var main: Vector3 = ways_in[zone][0]
		for way: Vector3 in ways_in[zone]:
			assert_lt(_path_length(way, main), INF, "%s: from %s to the main way in" % [zone, way])
		for room in _west_rooms():
			# havens bake into their own region (the exhibits' navmesh never
			# enters them): the room graph checks their doors
			if room.zone != zone or room.haven:
				continue
			var target := _floor_point(room)
			assert_ne(target, Vector3.INF, "%s has walkable floor" % room.id)
			if target == Vector3.INF:
				continue
			assert_lt(_path_length(main, target), INF, "%s reached from %s's way in" % [room.id, zone])
	# the vertical loop and the tower's three floors
	var podium := _floor_point(level.layout.room(&"greece_nereid_podium"))
	var mezzanine := _floor_point(level.layout.room(&"greece_bassae_gallery"))
	assert_lt(_path_length(podium, mezzanine), 40.0, "the Nereid podium and the Bassae mezzanine join at the same height")
	var bottom := Vector3(-22.0, Floor1Plan.BASEMENT_Y, 51.5)
	var top := Vector3(-19.0, Floor1Plan.LANDING_Y, 51.5)
	assert_lt(_path_length(_floor_point(level.layout.room(&"greece_parthenon")), top), INF, "the tower climbs to the landing")
	assert_lt(_path_length(top, bottom), INF, "and down to the basement door")


func test_slots_and_floor_loot_stand_on_the_navmesh_in_the_clear() -> void:
	await _build(true)
	for slot in level.spawn_slots:
		if not WEST.has(slot.zone):
			continue
		assert_true(_on_navmesh(slot.position), "slot %s in %s is on the navmesh" % [slot.position, slot.room])
		assert_true(_capsule_clear(slot.position), "slot %s in %s is clear" % [slot.position, slot.room])
	for spot in level.loot_spots:
		var room := level.layout.room(spot.room)
		if room == null or not WEST.has(room.zone) or spot.container:
			continue
		assert_true(_on_navmesh(spot.position), "loot %s in %s is on the navmesh" % [spot.position, spot.room])
		assert_true(_capsule_clear(spot.position), "loot %s in %s is clear" % [spot.position, spot.room])
	for patrol in level.layout.patrols:
		var room := level.layout.room(patrol.room)
		if room == null or not WEST.has(room.zone):
			continue
		for i in range(1, patrol.points.size()):
			assert_lt(_path_length(patrol.points[i - 1], patrol.points[i]), patrol.points[i - 1].distance_to(patrol.points[i]) * 1.6, "%s leg %d is a straight walk" % [patrol.id, i])


func test_on_night_one_the_shotgun_is_seen_and_reached_and_the_gates_hold() -> void:
	await _build(false)
	var j := Floor1Plan.junction(&"j_court_egypt")
	var gun: Vector3 = (level.markers[&"weapon_shotgun"] as Transform3D).origin
	var space := level.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(j.point_in(&"egypt", 2.5, EYE), gun + Vector3.UP * 0.15, Layers.WORLD)
	var hit := space.intersect_ray(ray)
	assert_true(hit.is_empty(), "the shotgun is in plain view from the court door (hit %s)" % [hit.get("position", "")])
	var court := j.point_in(&"court", 2.5, 0.0)
	assert_lt(_path_length(court, gun + Vector3(1.4, -gun.y, 0.0)), 50.0, "from the court to the camp table, no gate on the way")
	var seat: Vector3 = (level.markers[&"guardian_colossus"] as Transform3D).origin
	assert_lt(_path_length(court, seat + Vector3(0, 0, 4.5)), INF, "the Colossus waits on night 1")
	# shut gates hold: the boards to Greece, the secrets
	assert_eq(_path_length(_beyond(&"j_egypt_greece", &"egypt"), _beyond(&"j_egypt_greece", &"greece")), INF, "the boards keep Greece shut")
	var inside := {&"egypt": court, &"greece": _floor_point(level.layout.room(&"greece_nereid"))}
	for room in _west_rooms():
		if not room.secret:
			continue
		var target := _floor_point(room)
		if target == Vector3.INF:
			# a shut room's floor may be cut off from every region: then it is
			# certainly not reached
			continue
		assert_eq(_path_length(inside[room.zone], target), INF, "%s stays shut behind its gate" % room.id)
	# Greece's insides do not need its junction gates
	var nereid: Vector3 = inside[&"greece"]
	for id: StringName in [&"greece_parthenon", &"greece_bassae_gallery", &"greece_service_corridor", &"greece_metopes"]:
		assert_lt(_path_length(nereid, _floor_point(level.layout.room(id))), INF, "%s reached inside Greece" % id)
