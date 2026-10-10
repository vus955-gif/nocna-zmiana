extends TestCase

## Longest any door animation takes, in physics frames.
const ANIMATION_FRAMES := 170


func _door(style: OpeningSpec.DoorStyle, kind: RoomGraph.Kind = RoomGraph.Kind.LOCKABLE, depth: float = 0.5) -> Door:
	# passage across z at the origin: 2 m wide (x), [depth] deep (z)
	var spec := OpeningSpec.make(&"test_door", Rect2(-1, -depth * 0.5, 2, depth), 0.0, 2.5, &"a", &"b", style, kind)
	var door := Door.make(spec, Transform3D.IDENTITY, Color(0.5, 0.45, 0.4))
	add_child(door)
	return door


## True when a waist-high ray through the doorway (x = 0.3) gets through.
func _passes() -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0.3, 1.0, 3.0), Vector3(0.3, 1.0, -3.0), Layers.WORLD)
	return get_viewport().get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _lamps_lit(door: Door) -> bool:
	var lamps := door.get_children().filter(func(n: Node) -> bool: return n.is_in_group(&"lock_lights"))
	return lamps.size() == 2 and lamps.all(func(n: Node3D) -> bool: return n.visible)


func test_an_open_door_lets_things_through() -> void:
	var door := _door(OpeningSpec.DoorStyle.SWING)
	await physics_frames(2)
	assert_true(door.is_open)
	assert_false(door.blocks_navigation())
	assert_true(_passes())
	assert_false(_lamps_lit(door))


func test_a_locked_door_blocks_and_shows_its_red_lamps() -> void:
	var door := _door(OpeningSpec.DoorStyle.SWING)
	var locks := watch(door.lock_changed)
	var blocking := watch(door.nav_blocking_changed)
	door.lock(true)
	await physics_frames(2)
	assert_true(door.locked)
	assert_false(door.is_open)
	assert_true(door.blocks_navigation())
	assert_false(_passes())
	assert_true(_lamps_lit(door))
	assert_eq(locks.size(), 1)
	assert_eq(blocking.size(), 1)


func test_a_locked_door_refuses_to_open() -> void:
	var door := _door(OpeningSpec.DoorStyle.DOUBLE_SWING)
	door.lock(true)
	var refused := watch(door.open_refused)
	assert_false(door.try_open())
	door.open()
	await physics_frames(2)
	assert_eq(refused.size(), 1)
	assert_false(door.is_open)
	assert_false(_passes())


func test_unlocking_then_opening_frees_the_passage_once_the_leaves_rest() -> void:
	var door := _door(OpeningSpec.DoorStyle.DOUBLE_SWING, RoomGraph.Kind.LOCKABLE, 2.0)
	door.lock(true)
	var locks := watch(door.lock_changed)
	var opened := watch(door.opened)
	var blocking := watch(door.nav_blocking_changed)
	door.unlock()
	assert_eq(locks.size(), 1)
	if locks.size() == 1:
		assert_false(locks[0][1])
	assert_false(door.is_open, "unlocking alone keeps it shut")
	assert_true(door.try_open())
	await physics_frames(3)
	assert_true(door.is_moving())
	assert_eq(blocking.size(), 0, "no rebake while the leaves still swing")
	await physics_frames(ANIMATION_FRAMES)
	assert_false(door.is_moving())
	assert_eq(opened.size(), 1)
	assert_eq(blocking.size(), 1)
	assert_true(_passes(), "leaves fold into the 2 m deep passage")
	assert_false(_lamps_lit(door))


## True when nothing solid fills the doorway's cross-section (1.6 m wide,
## waist to head): a body could walk through.
func _body_passes(depth: float = 2.0) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, depth)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = Layers.WORLD
	query.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0))
	return get_viewport().get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func test_every_style_closes_and_opens() -> void:
	for style in [OpeningSpec.DoorStyle.SWING, OpeningSpec.DoorStyle.DOUBLE_SWING, OpeningSpec.DoorStyle.SLIDE, OpeningSpec.DoorStyle.PANEL, OpeningSpec.DoorStyle.GATE]:
		var door := _door(style, RoomGraph.Kind.OPEN, 2.0)
		door.close(true)
		await physics_frames(2)
		assert_false(_body_passes(), "style %d closed" % style)
		if style != OpeningSpec.DoorStyle.GATE:
			assert_false(_passes(), "style %d closed to rays" % style)
		door.open(true)
		await physics_frames(2)
		assert_true(_passes(), "style %d open" % style)
		assert_true(_body_passes(), "style %d open to bodies" % style)
		door.free()


func test_the_gate_jams_half_a_metre_up_and_still_bars_the_way() -> void:
	var gate := _door(OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE, 0.5)
	var jams := watch(gate.jammed)
	var blocking := watch(gate.nav_blocking_changed)
	await physics_frames(2)
	var low := (gate.get_child(0) as Node3D).position.y
	gate.jam()
	await physics_frames(ANIMATION_FRAMES)
	assert_eq(jams.size(), 1)
	assert_true(gate.is_jammed)
	assert_false(gate.is_open)
	assert_true(gate.blocks_navigation())
	assert_eq(blocking.size(), 0, "a jammed gate changes nothing for the navmesh")
	for leaf in gate.get_children().filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"grate"):
		assert_almost_eq((leaf as Node3D).position.y - low, Door.JAM_LIFT, 0.01)
	assert_false(_body_passes(0.5), "nobody squeezes under it")


func test_the_open_gate_rolls_its_leaves_aside_and_shots_fly_between_its_bars() -> void:
	var gate := _door(OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE, 0.5)
	await physics_frames(2)
	assert_true(_passes(), "a shot at x = 0.3 slips between two bars")
	gate.jam(true)
	gate.open()
	await physics_frames(ANIMATION_FRAMES)
	assert_true(gate.is_open)
	assert_false(gate.is_jammed)
	for leaf in gate.get_children().filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"grate"):
		assert_gt(absf((leaf as Node3D).position.x), 1.0 + 0.49, "the leaf rolled into the wall beside the opening")
	assert_true(_body_passes(0.5))


func test_a_door_waits_for_its_doorway_to_clear_before_shutting() -> void:
	var door := _door(OpeningSpec.DoorStyle.SLIDE, RoomGraph.Kind.LOCKABLE, 0.5)
	var body := CharacterBody3D.new()
	body.collision_layer = Layers.PLAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.position = Vector3(0.2, 0, 0)
	add_child(body)
	await physics_frames(2)
	var shut := watch(door.closed)
	door.close()
	await physics_frames(60)
	assert_true(door.is_open, "not on the guard")
	assert_true(door.is_waiting_to_close())
	assert_eq(shut.size(), 0)
	body.position = Vector3(0.2, 0, 4.0)
	await physics_frames(ANIMATION_FRAMES)
	assert_false(door.is_open)
	assert_false(door.is_waiting_to_close())
	assert_eq(shut.size(), 1)


func test_instant_poses_are_silent() -> void:
	var door := _door(OpeningSpec.DoorStyle.DOUBLE_SWING)
	var moves := watch(door.moving)
	door.close(true)
	door.open(true)
	door.lock(true)
	assert_eq(moves.size(), 0, "no door sound while the level is set up")
	door.unlock()
	door.open()
	assert_eq(moves.size(), 1)


func test_open_swing_leaves_lie_inside_the_passage() -> void:
	for style in [OpeningSpec.DoorStyle.SWING, OpeningSpec.DoorStyle.DOUBLE_SWING]:
		var door := _door(style, RoomGraph.Kind.OPEN, 2.0)
		door.open(true)
		await physics_frames(2)
		for leaf in door.get_children().filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"door_leaf"):
			for node in (leaf as Node).get_children():
				var collider := node as CollisionShape3D
				if collider == null:
					continue
				var box := (collider.shape as BoxShape3D).size * 0.5
				for corner in [Vector3(-1, -1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(1, -1, -1)]:
					var at: Vector3 = collider.global_transform * (box * corner)
					assert_true(absf(at.x) <= 1.0 + 0.001, "style %d leaf corner %s inside the jambs" % [style, at])
		door.free()


func test_false_panels_and_gates_start_closed_and_the_panel_looks_like_its_wall() -> void:
	var panel := _door(OpeningSpec.DoorStyle.PANEL, RoomGraph.Kind.SECRET)
	var gate := _door(OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	await physics_frames(2)
	assert_false(panel.is_open)
	assert_false(gate.is_open)
	var kits := panel.get_children().map(func(n: Node) -> StringName: return n.get_meta(&"kit", &""))
	assert_true(kits.has(&"false_panel"))
	assert_false(kits.has(&"door_frame"), "no frame gives the panel away")
	assert_true(gate.get_children().any(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"grate"))


func test_closing_twice_or_opening_an_open_door_changes_nothing() -> void:
	var door := _door(OpeningSpec.DoorStyle.SLIDE)
	var blocking := watch(door.nav_blocking_changed)
	door.open(true)
	assert_eq(blocking.size(), 0)
	door.close(true)
	door.close(true)
	assert_eq(blocking.size(), 1)
