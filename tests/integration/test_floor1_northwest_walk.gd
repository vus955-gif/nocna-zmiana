extends TestCase
## Floor I north-west wings on the built floor (P1 / W4; plan
## docs/superpowers/plans/2026-10-03-p1-w4-asyria-ameryki.md). Two builds:
## - every gate open: from each wing's ways in, the navmesh reaches every
##   room of Assyria and the Americas (secrets, the gap's floor and the
##   temple's terraces too), the Lion Hunt gallery, its pit and the freight
##   stairs join their three levels, the stair tower its two, the gap's
##   floor walks out through the store under the totems; every exhibit slot
##   and floor loot spot stands on the navmesh in the clear (a 0.42 x 2 m
##   capsule) and every patrol leg is a straight walk;
## - the guard's first visit (only the Khorsabad Gate, the Balawat doors and
##   the Americas' shutter open): the Black Obelisk is seen through the gate
##   and the canoe from the harpoon (physics rays), the fuse and the Lamassu
##   are walked to from Egypt, the harpoon from the north corridor and from
##   Assyria; the temple, the secrets and the bolted doors stay shut until
##   the harpoon brings the canoe down (open_gate) and the temple opens.

const NavProbe := preload("res://tests/support/nav_probe.gd")
## A navmesh path must end this close to its target to count.
const REACH := 1.5
const EYE := 1.6
const WINGS: Array[StringName] = [&"assyria", &"americas"]
## The gates open on the guard's first visit to the two wings.
const ARRIVAL: Array[StringName] = [&"seal_khorsabad", &"seal_balawat", &"shutter_americas"]

var level: MuseumFloorLevel


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _build(open: Array[StringName] = [], every_gate: bool = false) -> void:
	level = MuseumFloorLevel.new()
	if every_gate:
		for gate in level.layout.gates:
			level.gates_open.append(gate.id)
	else:
		level.gates_open.append_array(open)
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
	return Floor1Plan.junction(id).point_in(zone, 2.5, 0.0)


func _wing_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if WINGS.has(room.zone):
			found.append(room)
	return found


func _origin(marker: StringName) -> Vector3:
	return (level.markers[marker] as Transform3D).origin


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


func _sees(from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return level.get_world_3d().direct_space_state.intersect_ray(ray)


func test_with_every_gate_open_the_wings_walk_end_to_end() -> void:
	await _build([], true)
	var ways_in := {
		&"assyria": [_beyond(&"j_egypt_assyria", &"assyria"), _beyond(&"j_assyria_greece", &"assyria"), _beyond(&"j_basement_assyria", &"assyria"), _beyond(&"j_assyria_americas", &"assyria")],
		&"americas": [_beyond(&"j_north_americas", &"americas"), _beyond(&"j_assyria_americas", &"americas"), _beyond(&"j_basement_americas", &"americas")],
	}
	for zone: StringName in ways_in:
		var main: Vector3 = ways_in[zone][0]
		for way: Vector3 in ways_in[zone]:
			assert_lt(_path_length(way, main), INF, "%s: from %s to the main way in" % [zone, way])
		for room in _wing_rooms():
			if room.zone != zone or room.haven:
				continue
			var target := _floor_point(room)
			assert_ne(target, Vector3.INF, "%s has walkable floor" % room.id)
			if target == Vector3.INF:
				continue
			assert_lt(_path_length(main, target), INF, "%s reached from %s's way in" % [room.id, zone])
	# the Lion Hunt hall's three levels: the gallery, the pit, the freight stairs' foot
	var gallery := _floor_point(level.layout.room(&"assyria_lions_gallery"))
	var pit := _floor_point(level.layout.room(&"assyria_lions"))
	var freight_foot := Vector3(-60.0, Floor1Plan.BASEMENT_Y, -36.25)
	assert_lt(_path_length(gallery, pit), 60.0, "down from the gallery into the pit")
	assert_lt(_path_length(pit, freight_foot), 40.0, "through the lions' gate down to the basement door")
	assert_lt(_path_length(_beyond(&"j_assyria_greece", &"assyria"), _beyond(&"j_egypt_assyria", &"assyria")), 90.0, "the gallery's Greek door to the Khorsabad Gate")
	# the Americas' tower and the way out of the gap
	var tower_foot := Vector3(-27.0, Floor1Plan.BASEMENT_Y, -40.5)
	var tower_top := Vector3(-25.75, 0.0, -40.25)
	assert_lt(_path_length(tower_foot, tower_top), 40.0, "the tower climbs from the basement door to the ground floor")
	var gap_floor := _floor_point(level.layout.room(&"americas_pit"))
	assert_lt(_path_length(gap_floor, tower_foot), 60.0, "whoever falls in walks out under the totem hall")
	# over the canoe's deck and up the temple's terraces
	var top_terrace := Vector3(-16.5, 3.0, -72.25)
	assert_lt(_path_length(Vector3(-36.0, 0, -79.0), top_terrace), 50.0, "from the Pacific gallery over the gap and up the stepped platform")


func test_slots_and_floor_loot_stand_on_the_navmesh_in_the_clear() -> void:
	await _build([], true)
	for slot in level.spawn_slots:
		if not WINGS.has(slot.zone):
			continue
		assert_true(_on_navmesh(slot.position), "slot %s in %s is on the navmesh" % [slot.position, slot.room])
		assert_true(_capsule_clear(slot.position), "slot %s in %s is clear" % [slot.position, slot.room])
	for spot in level.loot_spots:
		var room := level.layout.room(spot.room)
		if room == null or not WINGS.has(room.zone) or spot.container:
			continue
		assert_true(_on_navmesh(spot.position), "loot %s in %s is on the navmesh" % [spot.position, spot.room])
		assert_true(_capsule_clear(spot.position), "loot %s in %s is clear" % [spot.position, spot.room])
	for patrol in level.layout.patrols:
		var room := level.layout.room(patrol.room)
		if room == null or not WINGS.has(room.zone):
			continue
		var legs := patrol.points.size() if patrol.loop else patrol.points.size() - 1
		for i in legs:
			var a := patrol.points[i]
			var b := patrol.points[(i + 1) % patrol.points.size()]
			assert_lt(_path_length(a, b), a.distance_to(b) * 1.6, "%s leg %d is a straight walk" % [patrol.id, i + 1])


func test_on_arrival_the_keys_are_reached_and_the_canoe_holds() -> void:
	await _build(ARRIVAL)
	# the views: through the Khorsabad Gate to the obelisk, from the harpoon
	# to the canoe over the gap
	var khorsabad := Floor1Plan.junction(&"j_egypt_assyria")
	var hit := _sees(khorsabad.point_in(&"egypt", 2.5, EYE), _origin(&"black_obelisk") + Vector3(0, 2.0, 0.65))
	assert_true(hit.is_empty(), "the Black Obelisk closes the axis from the Colossus hall (hit %s)" % [hit.get("position", "")])
	hit = _sees(_origin(&"weapon_harpoon") + Vector3.UP * 0.6, _origin(&"americas_canoe"))
	assert_true(hit.is_empty(), "the canoe hangs in view of the harpoon (hit %s)" % [hit.get("position", "")])
	# the keys of both wings on foot
	var egypt := _beyond(&"j_egypt_assyria", &"egypt")
	assert_lt(_path_length(egypt, Vector3(-95.0, 0, -44.0)), 90.0, "from the Colossus hall to the fuse on the trolley")
	assert_lt(_path_length(egypt, Vector3(-78.75, 0, -70.0)), 90.0, "and to the Lamassu")
	var harpoon := Vector3(-39.2, 0, -79.0)
	assert_lt(_path_length(_beyond(&"j_north_americas", &"north_hall"), harpoon), 90.0, "from the north corridor to the harpoon")
	assert_lt(_path_length(_beyond(&"j_assyria_americas", &"assyria"), harpoon), 60.0, "from the Balawat Gates to the harpoon")
	# shut: the temple, every secret, the bolted shortcuts
	var temple := _floor_point(level.layout.room(&"americas_temple"))
	if temple != Vector3.INF:
		assert_eq(_path_length(harpoon, temple), INF, "the temple waits beyond the gap")
	var inside := {&"assyria": egypt, &"americas": harpoon}
	for room in _wing_rooms():
		if not room.secret:
			continue
		var target := _floor_point(room)
		if target == Vector3.INF:
			continue   # a shut room's floor cut off from every region is not reached
		assert_eq(_path_length(inside[room.zone], target), INF, "%s stays shut behind its gate" % room.id)
	for id: StringName in [&"j_assyria_greece", &"j_basement_assyria", &"j_basement_americas"]:
		var j := Floor1Plan.junction(id)
		var wing := j.zone_a if WINGS.has(j.zone_a) else j.zone_b
		assert_eq(_path_length(_beyond(id, wing), _beyond(id, j.other(wing))), INF, "%s is bolted" % id)
	# the harpoon pulls the canoe down: the temple opens over the gap
	level.open_gate(&"hook_canoe", true)
	await level.navigation.rebaked
	await physics_frames(4)
	assert_lt(_path_length(harpoon, Vector3(-16.5, 3.0, -72.25)), 50.0, "over the canoe to the Serpent's terrace")
	assert_true(level.is_gate_open(&"hook_canoe"))
