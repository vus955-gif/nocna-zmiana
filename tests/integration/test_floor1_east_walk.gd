extends TestCase
## Floor I east wings on the built floor (P1 / W5a; plan
## docs/superpowers/plans/2026-10-03-p1-w5a-oswiecenie-azja.md):
## - every gate open: from each wing's way in, the navmesh reaches every
##   room of the Enlightenment and Asia (havens have their own region), the
##   library's floor and its upper gallery join by both flights, the roof
##   stairs climb from the gallery to the observers' gallery and the loft,
##   the service stairs join the basement doors to the ground floor; every
##   exhibit slot and floor loot spot stands on the navmesh in the clear;
## - every gate shut (night 1): the rifle is seen from the Great Court (a
##   physics ray) and walked to, the observers' gallery is reached and sees
##   the Planetarium's rope across open air, the rotunda stays shut; in Asia
##   the cracked wall keeps the garden shut, the secrets stay shut;
## - one gate at a time: the cut rope lets the guard into the rotunda, the
##   blasted wall into the garden.

const NavProbe := preload("res://tests/support/nav_probe.gd")
## A navmesh path must end this close to its target to count.
const REACH := 1.5
const EYE := 1.6
const EAST: Array[StringName] = [&"enlightenment", &"asia"]
const Enlightenment := preload("res://src/level/floor1/zones/enlightenment.gd")

var level: MuseumFloorLevel


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _build(open: Array[StringName]) -> void:
	level = MuseumFloorLevel.new()
	for id in open:
		level.gates_open.append(id)
	add_child(level)
	level.build()
	await physics_frames(4)   # the navigation map syncs after the bake


func _all_gates() -> Array[StringName]:
	var ids: Array[StringName] = []
	for gate in Floor1Layout.create().gates:
		ids.append(gate.id)
	return ids


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
	# (sampled 1 m up: on a floor shared with the zone below, the zone
	# listed first would claim the point)
	return Floor1Plan.junction(id).point_in(zone, 2.5, 1.0) + Vector3.DOWN


func _east_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if EAST.has(room.zone):
			found.append(room)
	return found


func _marker(id: StringName) -> Vector3:
	return (level.markers[id] as Transform3D).origin


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


func _ray_clear(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return level.get_world_3d().direct_space_state.intersect_ray(ray)


func test_with_every_gate_open_the_east_wings_walk_end_to_end() -> void:
	await _build(_all_gates())
	var ways_in := {
		&"enlightenment": [_beyond(&"j_court_enlightenment", &"enlightenment"), _beyond(&"j_basement_enlightenment", &"enlightenment"), _beyond(&"j_roof_enlightenment", &"enlightenment"), _beyond(&"j_asia_enlightenment", &"enlightenment")],
		&"asia": [_beyond(&"j_north_asia", &"asia"), _beyond(&"j_basement_asia", &"asia"), _beyond(&"j_asia_enlightenment", &"asia")],
	}
	for zone: StringName in ways_in:
		var main: Vector3 = ways_in[zone][0]
		for way: Vector3 in ways_in[zone]:
			assert_lt(_path_length(way, main), INF, "%s: from %s to the main way in" % [zone, way])
		for room in _east_rooms():
			# havens bake into their own region: the room graph checks their doors
			if room.zone != zone or room.haven:
				continue
			var target := _floor_point(room)
			assert_ne(target, Vector3.INF, "%s has walkable floor" % room.id)
			if target == Vector3.INF:
				continue
			assert_lt(_path_length(main, target), INF, "%s reached from %s's way in" % [room.id, zone])
	# the library's loop: up one flight, along the gallery, down the other
	var gallery_n := Vector3(Enlightenment.AXIS, Enlightenment.UPPER, -34.5)
	var gallery_s := Vector3(Enlightenment.AXIS, Enlightenment.UPPER, 32.5)
	var foot_n := Vector3(Enlightenment.AXIS, 0, -20.5)
	var foot_s := Vector3(Enlightenment.AXIS, 0, 19.0)
	assert_lt(_path_length(foot_n, gallery_n), 18.0, "the north flight climbs to the gallery")
	assert_lt(_path_length(foot_s, gallery_s), 18.0, "the south flight climbs to the gallery")
	assert_lt(_path_length(gallery_n, gallery_s), INF, "the gallery runs round the hall")
	# the roof stairs: gallery -> observers' gallery -> loft -> the roof door
	var lookout := _floor_point(level.layout.room(&"enlightenment_observatory"))
	var loft := _floor_point(level.layout.room(&"enlightenment_attic"))
	assert_lt(_path_length(Vector3(43.3, Enlightenment.UPPER, -13.4), lookout), INF, "up to the observers' gallery")
	assert_lt(_path_length(lookout, loft), INF, "on up to the loft")
	assert_lt(_path_length(loft, _beyond(&"j_roof_enlightenment", &"roof")), INF, "and out on the roof")


func test_slots_and_floor_loot_stand_on_the_navmesh_in_the_clear() -> void:
	await _build(_all_gates())
	for slot in level.spawn_slots:
		if not EAST.has(slot.zone):
			continue
		assert_true(_on_navmesh(slot.position), "slot %s in %s is on the navmesh" % [slot.position, slot.room])
		assert_true(_capsule_clear(slot.position), "slot %s in %s is clear" % [slot.position, slot.room])
	for spot in level.loot_spots:
		var room := level.layout.room(spot.room)
		if room == null or not EAST.has(room.zone) or spot.container:
			continue
		assert_true(_on_navmesh(spot.position), "loot %s in %s is on the navmesh" % [spot.position, spot.room])
		assert_true(_capsule_clear(spot.position), "loot %s in %s is clear" % [spot.position, spot.room])
	for patrol in level.layout.patrols:
		var room := level.layout.room(patrol.room)
		if room == null or not EAST.has(room.zone):
			continue
		var count := patrol.points.size() if patrol.loop else patrol.points.size() - 1
		for i in count:
			var a := patrol.points[i]
			var b := patrol.points[(i + 1) % patrol.points.size()]
			assert_lt(_path_length(a, b), a.distance_to(b) * 1.6, "%s leg %d is a straight walk" % [patrol.id, i + 1])
	# the arenas' supplies land on walkable floor
	for id: StringName in level.markers:
		if String(id).begins_with("arena_planetarium_supply_") or String(id).begins_with("arena_general_supply_"):
			assert_true(_on_navmesh(_marker(id)), "%s on the navmesh" % id)


func test_on_night_one_the_rifle_is_seen_and_reached_and_the_gates_hold() -> void:
	await _build([])
	var j := Floor1Plan.junction(&"j_court_enlightenment")
	var rifle := _marker(&"weapon_rifle_hunt")
	for from: Vector3 in [j.point_in(&"court", 2.5, EYE), j.point_in(&"enlightenment", 0.5, EYE)]:
		var hit := _ray_clear(from, rifle + Vector3.UP * 0.15)
		assert_true(hit.is_empty(), "the rifle is in plain view from %s (hit %s)" % [from, hit.get("position", "")])
	var court := j.point_in(&"court", 2.5, 1.0) + Vector3.DOWN
	assert_lt(_path_length(court, rifle + Vector3(-1.4, -rifle.y, 0.0)), 50.0, "from the court to the rifle's table, no gate on the way")
	# the rope: out of reach, in sight from the observers' gallery
	var library := Vector3(40.5, 0, -26.5)
	var orrery := _marker(&"guardian_planetarium")
	assert_eq(_path_length(library, orrery + Vector3(-7.0, 0, 0)), INF, "the portcullis holds the Planetarium shut")
	var lookout := _floor_point(level.layout.room(&"enlightenment_observatory"))
	assert_lt(_path_length(library, lookout), INF, "the observers' gallery is open on night 1")
	var rope := _marker(&"planetarium_counterweight") + Vector3.UP * 4.5
	var eye := Vector3(51.5, lookout.y + EYE, -16.5)
	var hit := _ray_clear(eye, rope)
	assert_true(hit.is_empty(), "the observers' gallery sees the rope (hit %s)" % [hit.get("position", "")])
	assert_gt(eye.distance_to(rope), 15.0, "a rifle shot, not a pistol shot")
	# Asia: inside the shutter, the fire chest is open, the garden is not
	var china := _beyond(&"j_north_asia", &"asia")
	assert_lt(_path_length(china, _marker(&"weapon_hwacha") + Vector3(-2.0, -0.9, 0.0)), INF, "the hwacha needs no gate inside Asia")
	assert_eq(_path_length(china, _floor_point(level.layout.room(&"asia_garden"))), INF, "the cracked wall keeps the garden shut")
	for room in _east_rooms():
		if not room.secret:
			continue
		var target := _floor_point(room)
		if target == Vector3.INF:
			continue   # a shut room's floor may be cut off from every region
		var inside := china if room.zone == &"asia" else library
		assert_eq(_path_length(inside, target), INF, "%s stays shut behind its gate" % room.id)


func test_the_rope_and_the_blast_open_their_arenas() -> void:
	var open: Array[StringName] = [&"rope_planetarium"]
	await _build(open)
	var orrery := _marker(&"guardian_planetarium")
	var start := _marker(&"arena_planetarium_start")
	assert_lt(_path_length(Vector3(40.5, 0, -26.5), start), 15.0, "through the risen portcullis")
	assert_lt(_path_length(start, orrery + Vector3(7.0, 0, 0)), INF, "round the orrery's ring")
	var china := _beyond(&"j_north_asia", &"asia")
	var garden := _floor_point(level.layout.room(&"asia_garden"))
	assert_eq(_path_length(china, garden), INF, "the garden still waits")
	level.open_gate(&"cracked_garden", true)
	await level.navigation.rebaked
	await physics_frames(4)
	garden = _floor_point(level.layout.room(&"asia_garden"))
	assert_lt(_path_length(china, garden), INF, "the blast opens the garden")
	assert_lt(_path_length(_marker(&"arena_general_start"), _marker(&"guardian_general") + Vector3(0, 0, 4.0)), INF, "the General waits in the middle")
