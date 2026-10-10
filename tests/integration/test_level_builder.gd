extends TestCase

var walk: Node3D
var havens: Node3D
var structure: Node3D
var builder: LevelBuilder


## A low room joined by a doorway to a tall room with a skylight, a
## balcony (y = 4) reached by stairs along the west wall, and a haven off
## the low room.
static func small_layout() -> LevelLayout:
	var layout := LevelLayout.new()
	layout.id = &"test_small"
	layout.add_room(&"low", [Rect2(0, 0, 10, 10)] as Array[Rect2], 0.0, 4.0, Color(0.5, 0.5, 0.5))
	var tall := layout.add_room(&"tall", [Rect2(12, 0, 12, 12)] as Array[Rect2], 0.0, 9.0, Color(0.6, 0.55, 0.5))
	tall.skylights.append(Rect2(18, 6, 4, 4))
	var loft := layout.add_room(&"loft", [Rect2(12, 0, 12, 4)] as Array[Rect2], 4.0, 9.0, Color(0.6, 0.55, 0.5))
	loft.carved = false
	var safe := layout.add_room(&"safe", [Rect2(0, 11, 4, 4)] as Array[Rect2], 0.0, 3.0, Color(0.5, 0.5, 0.4))
	safe.haven = true
	layout.add_opening(&"door", Rect2(10, 3, 2, 4), 0.0, 3.0, &"low", &"tall", OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.LOCKABLE)
	layout.add_opening(&"safe_door", Rect2(1, 10, 2, 1), 0.0, 2.5, &"low", &"safe", OpeningSpec.DoorStyle.SWING)
	layout.add_opening(&"arch", Rect2(10, 0.5, 2, 1.5), 0.0, 2.5, &"low", &"tall")
	layout.add_piece(&"balcony", Vector3(18, 3.6, 2), Vector3(12, 0.4, 4), &"loft")
	layout.add_piece(&"railing", Vector3(19, 4, 4), Vector3(10, 1.1, 0.15), &"loft")
	layout.add_piece(&"desk", Vector3(2, 0, 13), Vector3(1.6, 0.8, 0.8), &"safe")
	var stairs := layout.add_stairs(&"stairs", Rect2(12, 4, 2, 7.5), 0.0, 4.0, Vector2(0, -1), &"tall", &"loft")
	stairs.rail_left = false
	return layout


func before_each() -> void:
	walk = Node3D.new()
	havens = Node3D.new()
	structure = Node3D.new()
	add_child(walk)
	add_child(havens)
	add_child(structure)
	builder = LevelBuilder.new(small_layout(), walk, havens, structure)
	builder.build()
	await physics_frames(2)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_viewport().get_world_3d().direct_space_state.intersect_ray(query)


func _floor_height(x: float, z: float, from_y: float = 20.0) -> float:
	var hit := _ray(Vector3(x, from_y, z), Vector3(x, -5, z))
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


func test_floors_balcony_and_ceilings_stand_at_their_heights() -> void:
	assert_almost_eq(_floor_height(5, 5, 3), 0.0, 0.01, "low room floor")
	assert_almost_eq(_floor_height(18, 2, 8), 4.0, 0.01, "balcony top")
	assert_almost_eq(_floor_height(22, 9, 8), 0.0, 0.01, "tall room floor")
	var low_ceiling := _ray(Vector3(5, 1, 5), Vector3(5, 20, 5))
	assert_almost_eq(low_ceiling.get("position", Vector3.ZERO).y, 4.0, 0.01)
	var tall_ceiling := _ray(Vector3(22, 5, 10.5), Vector3(22, 30, 10.5))
	assert_almost_eq(tall_ceiling.get("position", Vector3.ZERO).y, 9.0, 0.01)
	assert_true(_ray(Vector3(20, 5, 8), Vector3(20, 40, 8)).is_empty(), "open sky through the skylight")


func test_doorway_lets_a_ray_through_and_walls_stop_the_rest() -> void:
	assert_true(_ray(Vector3(5, 1, 3.5), Vector3(20, 1, 3.5)).is_empty(), "through the door under the balcony")
	var wall := _ray(Vector3(5, 1, 2.5), Vector3(20, 1, 2.5))
	assert_almost_eq(wall.get("position", Vector3.ZERO).x, 10.0, 0.01, "west face of the dividing wall")
	var lintel := _ray(Vector3(5, 3.5, 5), Vector3(20, 3.5, 5))
	assert_almost_eq(lintel.get("position", Vector3.ZERO).x, 10.0, 0.01, "above the door")


func test_every_piece_is_a_tagged_kit_piece() -> void:
	var pieces := get_tree().get_nodes_in_group(&"level_kit")
	assert_gt(pieces.size(), 10)
	var kits := {}
	for piece in pieces:
		assert_true(piece.has_meta(&"kit") and piece.has_meta(&"kit_size"), str(piece))
		kits[piece.get_meta(&"kit")] = true
	for kit in [&"floor", &"wall", &"ceiling", &"threshold", &"lintel", &"balcony", &"railing", &"stairs", &"stair_ramp", &"skylight", &"desk"]:
		assert_true(kits.has(kit), "has %s" % kit)


func test_stairs_ramp_has_no_step_taller_than_the_climb_limit_and_meets_the_balcony() -> void:
	var previous := _floor_height(13, 11.95, 6)
	assert_lt(previous, 0.25, "starts at the floor")
	var z := 11.85
	var steepest := 0.0
	while z > 3.5:
		var height := _floor_height(13, z, 6)
		steepest = maxf(steepest, height - previous)
		previous = height
		z -= 0.1
	assert_lt(steepest, 0.15)
	assert_almost_eq(_floor_height(13, 4.1, 6), 4.0, 0.02, "top of the flight")
	assert_almost_eq(_floor_height(13, 3.9, 6), 4.0, 0.02, "balcony behind it")


func test_stairs_have_a_railing_on_the_open_side_only() -> void:
	var open_side := _ray(Vector3(15, 3.5, 7), Vector3(13, 3.5, 7))
	assert_false(open_side.is_empty(), "rail on the east side")
	if not open_side.is_empty():
		assert_gt((open_side["position"] as Vector3).x, 13.8)
	var steps_seen := 0
	for child in structure.get_children():
		if child.get_meta(&"kit", &"") == &"stairs":
			steps_seen += 1
			assert_false(child is CollisionObject3D, "visual steps do not collide")
	assert_eq(steps_seen, 1)


func test_drawn_steps_follow_the_ramp_underfoot() -> void:
	var flight: StairsSpec = builder.layout.stairs[0]
	var look: Node3D = null
	for child in structure.get_children():
		if child.get_meta(&"kit", &"") == &"stairs":
			look = child
	assert_not_null(look)
	if look == null:
		return
	var steps: int = look.get_meta(&"kit_steps", 0)
	assert_eq(steps, flight.step_count(), "the look has the ramp's step count")
	var rise := (flight.top_y - flight.bottom_y) / steps
	var tread := flight.run() / steps
	var front := flight.rect.end.y   # the flight climbs towards -Z from here
	var worst := 0.0
	var z := front - 0.05
	while z > flight.rect.position.y + 0.05:
		var ramp := _floor_height(13, z, 6)
		var step := int(floor((front - z) / tread))
		var drawn := rise * (step + 1)
		worst = maxf(worst, absf(ramp - drawn))
		z -= 0.1
	assert_lt(worst, rise + 0.01, "the foot never floats a riser above or below a drawn tread")


func test_balcony_railing_stops_a_waist_high_ray() -> void:
	var hit := _ray(Vector3(19, 4.8, 2), Vector3(19, 4.8, 6))
	assert_almost_eq(hit.get("position", Vector3.ZERO).z, 3.925, 0.01)


func test_pieces_go_under_the_parent_of_their_role() -> void:
	var roles := {}
	for parent in [walk, havens, structure]:
		for child in parent.get_children():
			var kit: StringName = child.get_meta(&"kit", &"")
			if not roles.has(kit):
				roles[kit] = {}
			roles[kit][parent] = true
	assert_eq(roles[&"ceiling"].keys(), [structure], "ceilings are not navigation sources")
	assert_true(roles[&"floor"].has(havens), "the haven floor")
	assert_true(roles[&"floor"].has(walk), "the other floors")
	assert_eq(roles[&"desk"].keys(), [havens], "haven furniture shapes the haven navmesh")
	assert_eq(roles[&"stair_ramp"].keys(), [walk])
	assert_eq(roles[&"skylight"].keys(), [structure])


func test_floors_stop_particles() -> void:
	var stops := 0
	for child in walk.get_children():
		if child.get_meta(&"kit", &"") == &"floor":
			for grandchild in child.get_children():
				if grandchild is GPUParticlesCollisionBox3D:
					stops += 1
	assert_gt(stops, 0)


func test_doors_are_built_facing_from_room_a_to_room_b() -> void:
	assert_eq(builder.doors.keys(), [&"door", &"safe_door"])
	var door: Door = builder.doors[&"door"]
	var forward := door.global_transform.basis * Vector3.FORWARD
	assert_true(forward.is_equal_approx(Vector3(1, 0, 0)), "low (west) -> tall (east): %s" % forward)
	assert_true(door.is_open)
	var safe: Door = builder.doors[&"safe_door"]
	assert_true((safe.global_transform.basis * Vector3.FORWARD).is_equal_approx(Vector3(0, 0, 1)))
	var frames := structure.get_children().filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"door_frame")
	assert_eq(frames.size(), 1, "the arch gets a plain frame")


func test_locking_the_double_door_closes_the_doorway() -> void:
	var door: Door = builder.doors[&"door"]
	door.lock(true)
	await physics_frames(2)
	var hit := _ray(Vector3(5, 1, 4.5), Vector3(20, 1, 4.5))
	assert_false(hit.is_empty())
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).x, 10.0, 0.02, "leaves shut in the room-A face")
