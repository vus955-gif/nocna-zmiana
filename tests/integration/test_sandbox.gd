extends TestCase

var sandbox: Sandbox


func before_each() -> void:
	GameInput.capture_allowed = false
	sandbox = (load("res://src/arena/sandbox.tscn") as PackedScene).instantiate() as Sandbox
	add_child(sandbox)


func after_each() -> void:
	GameInput.capture_allowed = true


func test_starts_with_an_armed_guard_and_six_exhibits() -> void:
	await physics_frames(5)
	assert_not_null(sandbox.player)
	assert_eq(sandbox.enemies_root.get_child_count(), 6)
	assert_eq(sandbox.player.weapons.owned.size(), 3)
	assert_eq(sandbox.player.weapons.current_state().data.id, &"pistol")


func test_spawn_groups_and_clear() -> void:
	sandbox.clear_enemies()
	await physics_frames(1)
	sandbox.spawn_group(&"wax")
	sandbox.spawn_group(&"wolf")
	sandbox.spawn_group(&"knight")
	assert_eq(sandbox.enemies_root.get_child_count(), 6)


func test_guard_stands_on_the_floor() -> void:
	await physics_frames(30)
	assert_true(sandbox.player.is_on_floor())


func test_dead_guard_respawns_at_the_start() -> void:
	await physics_frames(5)
	sandbox.player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	assert_false(sandbox.player.alive)
	await get_tree().create_timer(Sandbox.RESPAWN_DELAY + 0.3).timeout
	assert_true(sandbox.player.alive)
	assert_eq(sandbox.player.health.current, 100.0)
	assert_lt(sandbox.player.global_position.distance_to(Sandbox.PLAYER_START), 0.5)


func test_spawn_points_leave_room_for_a_whole_group() -> void:
	await physics_frames(2)
	var capsule := CapsuleShape3D.new()   # the widest exhibit: the knight
	capsule.radius = 0.42
	capsule.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	var space := sandbox.get_world_3d().direct_space_state
	var s := Sandbox.GROUP_SCATTER
	for base in Sandbox.SPAWN_POINTS:
		for offset in [Vector3.ZERO, Vector3(s, 0, s), Vector3(s, 0, -s), Vector3(-s, 0, s), Vector3(-s, 0, -s)]:
			var at: Vector3 = base + offset
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
			assert_true(space.intersect_shape(query, 1).is_empty(), "blocked spawn at %s" % at)
