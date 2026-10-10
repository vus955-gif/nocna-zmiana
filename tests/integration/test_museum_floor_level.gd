extends TestCase
## MuseumFloorLevel (stage P1 part A skeleton): the whole Floor I greybox
## builds, fills the Level contract, bakes navigation and connects: with
## every gate open, an exhibit can walk from the entrance hall to every
## zone, and through each junction; a shut gate cuts its way. The build and
## bake times are printed and kept in tests/_out/floor1_build.json.
## One build per test (a full floor is a few seconds), so few tests.

const NavProbe := preload("res://tests/support/nav_probe.gd")
const REPORT := "res://tests/_out/floor1_build.json"
## A navmesh path must end this close to its target to count.
const REACH := 1.5

var level: MuseumFloorLevel


func after_each() -> void:
	if is_instance_valid(level):
		level.free()


func _build(open_gates: bool) -> MuseumFloorLevel:
	level = MuseumFloorLevel.new()
	if open_gates:
		for gate in level.layout.gates:
			level.gates_open.append(gate.id)
	add_child(level)
	level.build()
	await physics_frames(4)   # the navigation map syncs after the bake
	return level


## Length of the navmesh path between two points on [param layers]; INF when
## it does not get there.
func _path_length(from: Vector3, to: Vector3, layers: int = LevelNavigation.WALK_LAYER) -> float:
	var map := level.walk_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, from)
	# no query to a sealed island (an engine error) and no polygon budget:
	# the whole floor's mesh is bigger than the default search (NavProbe)
	if not NavProbe.connected(map, start, NavigationServer3D.map_get_closest_point(map, to), layers):
		return INF
	var path := NavProbe.path(map, start, to, layers)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > REACH or start.distance_to(from) > REACH:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## A floor point 2.5 m into the room behind [param j] on [param zone]'s side.
func _beyond(j: Floor1Plan.Junction, zone: StringName) -> Vector3:
	return j.point_in(zone, 2.5, 1.0) + Vector3.DOWN


func test_the_floor_builds_fills_the_contract_and_reports_its_times() -> void:
	# the pure parts on their own: data, then the shell carving (uncached)
	var started := Time.get_ticks_msec()
	var data := Floor1Layout.create()
	var layout_msec := Time.get_ticks_msec() - started
	var volumes := LevelBuilder.new(data, null, null, null).shell_volumes()
	started = Time.get_ticks_msec()
	var boxes := ShellCarver._carve(volumes)
	var carve_msec := Time.get_ticks_msec() - started
	await _build(true)
	assert_eq(level.haven_spots.size(), 6, "six havens")
	assert_eq(level.haven_zones.size(), 6, "six safe zones")
	for id in level.haven_spots:
		var zone: AABB = level.haven_zones[id]
		assert_true(zone.grow(0.5).has_point((level.haven_spots[id] as Transform3D).origin), "%s terminal in its zone" % id)
	assert_true((level.haven_zones[&"security"] as AABB).has_point(level.player_start.origin), "the night starts in the booth")
	assert_eq(level.zone_at(level.player_start.origin + Vector3.UP), &"booth")
	assert_gt(level.spawn_slots.size(), 30)
	assert_gt(level.loot_spots.size(), 20)
	assert_eq(level.doors.size(), level.layout.openings.filter(func(o: OpeningSpec) -> bool: return o.door_style != OpeningSpec.DoorStyle.NONE).size(), "a door for every styled opening")
	assert_gt(level.navigation.polygon_count(), 500, "the walkable navmesh is baked")
	assert_eq(level.navigation.regions.size(), MuseumFloorLevel.baking_boxes().size(), "a region per tile")
	var report := {
		"rooms": level.layout.rooms.size(),
		"openings": level.layout.openings.size(),
		"pieces": level.layout.pieces.size(),
		"stairs": level.layout.stairs.size(),
		"spawn_slots": level.spawn_slots.size(),
		"loot_spots": level.loot_spots.size(),
		"gates": level.layout.gates.size(),
		"layout_msec": layout_msec,
		"carve_msec": carve_msec,
		"shell_boxes": boxes.size(),
		"build_msec": level.build_msec,
		"bake_msec": level.bake_msec,
		"nav_polygons": level.navigation.polygon_count(),
		"nav_regions": level.navigation.regions.size(),
	}
	print("Floor I skeleton: %s" % JSON.stringify(report))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))


func test_with_every_gate_open_exhibits_walk_everywhere() -> void:
	await _build(true)
	# through every junction, both ways round
	for j in Floor1Plan.junctions():
		var a := _beyond(j, j.zone_a)
		var b := _beyond(j, j.zone_b)
		assert_lt(_path_length(a, b), 12.0, "through %s (%s -> %s)" % [j.id, a, b])
	# from the entrance hall into every non-haven room's middle
	var hall := Vector3(0, 0, 36)
	var reached := 0
	for room in level.layout.rooms:
		if room.haven:
			continue
		var target := _floor_point(room)
		var length := _path_length(hall, target)
		assert_lt(length, INF, "%s reachable from the entrance hall (%s)" % [room.id, target])
		if length < INF:
			reached += 1
	print("Floor I skeleton: %d rooms reached on foot from the entrance hall" % reached)


func test_shut_gates_cut_their_way() -> void:
	await _build(false)
	var j := Floor1Plan.junction(&"j_egypt_assyria")
	assert_eq(_path_length(_beyond(j, &"egypt"), _beyond(j, &"assyria")), INF, "the Khorsabad Gate is shut")
	var court := Floor1Plan.junction(&"j_court_egypt")
	assert_lt(_path_length(_beyond(court, &"court"), _beyond(court, &"egypt")), 12.0, "an open junction stays open")
	var started := Time.get_ticks_msec()
	level.open_gate(&"seal_khorsabad", true)
	await level.navigation.rebaked
	var waited := Time.get_ticks_msec() - started
	await physics_frames(4)
	assert_lt(_path_length(_beyond(j, &"egypt"), _beyond(j, &"assyria")), 12.0, "open for good")
	var tiles := level.navigation.rebaked_boxes
	assert_lt(tiles, 5, "only the tiles round the gate are rebaked (%d)" % tiles)
	print("Floor I gate rebake: %d tiles of %d, %d ms off the main thread (%d ms to the signal)" % [tiles, level.navigation.boxes.size(), level.navigation.rebake_msec, waited])
	assert_true(level.is_gate_open(&"seal_khorsabad"))


## A floor point of [param room] on the navmesh, near the middle of its
## first part if possible: a 1 m grid over the part, closest to the middle
## first, never over a flight or a solid piece (Recast leaves a sealed
## island inside a stair ramp's hull; nobody walks there).
func _floor_point(room: RoomSpec) -> Vector3:
	var map := level.walk_region.get_navigation_map()
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
