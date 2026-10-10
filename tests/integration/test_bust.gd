extends TestCase
## Floating marble bust: hover, keeping its distance, telegraphed shards
## only with line of sight, taser drop and fist finisher.

var target: TargetDummy
var bust: Bust


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	target = TargetDummy.new()
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _spawn(at: Vector3 = Vector3.ZERO, awake: bool = true) -> Bust:
	bust = Bust.new()
	bust.position = at
	bust.target = target
	add_child(bust)
	bust.face(target.global_position)
	if awake:
		bust.brain.wake()
	return bust


func _flat_distance() -> float:
	var to := target.global_position - bust.global_position
	return Vector2(to.x, to.z).length()


func _shards() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child in get_children():
		var shot := child as Projectile
		if shot != null and not shot.is_queued_for_deletion():
			found.append(shot)
	return found


func test_is_a_45_health_marble_bust() -> void:
	_spawn(Vector3.ZERO, false)
	assert_eq(Bust.KIND, &"bust")
	assert_eq(bust.health.max_health, 45.0)
	assert_eq(bust.material_kind, ExhibitMaterial.Kind.MARBLE)


func test_hovers_about_one_point_six_metres_above_the_floor() -> void:
	target.position = Vector3(0, 0, -11)
	_spawn()
	var lowest := INF
	var highest := -INF
	await physics_frames(90)
	for i in 150:
		await get_tree().physics_frame
		lowest = minf(lowest, bust.global_position.y)
		highest = maxf(highest, bust.global_position.y)
	assert_gt(lowest, 1.35)
	assert_lt(highest, 1.85)
	assert_gt(highest - lowest, 0.1, "it bobs")


func test_backs_off_from_a_close_guard() -> void:
	target.position = Vector3(0, 0, -3)
	_spawn()
	await physics_frames(180)   # (its suspicion: 0.8 s, then the first shard)
	assert_gt(_flat_distance(), 6.0)


func test_approaches_a_distant_guard() -> void:
	target.position = Vector3(0, 0, -22)
	_spawn()
	await physics_frames(150)
	assert_lt(_flat_distance(), 19.0)


func test_keeps_a_middle_distance() -> void:
	target.position = Vector3(0, 0, -11)
	_spawn()
	for i in 4:
		await physics_frames(60)
		assert_gt(_flat_distance(), 7.5)
		assert_lt(_flat_distance(), 14.5)


func test_fires_a_slow_shard_at_a_guard_in_view() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(95)
	var shards := _shards()
	assert_eq(shards.size(), 1)
	if shards.size() == 1:
		assert_almost_eq(shards[0].velocity.length(), 9.0, 0.01)
		assert_eq(shards[0].damage.amount, 12.0)
		assert_lt(shards[0].velocity.z, 0.0, "flies toward the guard")


func test_fires_every_two_point_four_seconds() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	var fired := 0
	var shots_seen: Dictionary = {}
	for i in 390:   # 6.5 s: reaction 0.5 + windup 0.7 -> shots at ~1.2, 3.6, 6.0 s
		await get_tree().physics_frame
		for shot in _shards():
			if not shots_seen.has(shot):
				shots_seen[shot] = true
				fired += 1
	assert_eq(fired, 3)


func test_does_not_fire_without_line_of_sight() -> void:
	Greybox.box(self, Vector3(0, 2, -5), Vector3(12, 4, 0.3), Color.GRAY)
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(200)
	assert_eq(_shards().size(), 0)


func test_holds_fire_when_the_guard_hides_during_the_windup() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	for i in 120:
		if bust.brain.state == EnemyBrain.State.ATTACK:
			break
		await get_tree().physics_frame
	assert_eq(bust.brain.state, EnemyBrain.State.ATTACK)
	Greybox.box(self, Vector3(0, 2, -5), Vector3(12, 4, 0.3), Color.GRAY)
	await physics_frames(60)
	assert_eq(_shards().size(), 0)


func test_holds_fire_when_the_guard_reaches_a_haven_during_the_windup() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	for i in 120:
		if bust.brain.state == EnemyBrain.State.ATTACK:
			break
		await get_tree().physics_frame
	assert_eq(bust.brain.state, EnemyBrain.State.ATTACK)
	add_child(Haven.make(&"booth", AABB(Vector3(-2, 0, -12), Vector3(4, 3, 4))))
	await physics_frames(60)
	assert_eq(_shards().size(), 0)


func test_cracks_glow_during_the_windup() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(30)
	var calm := bust.crack_glow()
	for i in 120:
		if bust.brain.windup_progress() > 0.8:
			break
		await get_tree().physics_frame
	assert_gt(bust.crack_glow(), calm + 2.0)


func test_taser_drops_it_to_the_floor_and_a_punch_finishes_it() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(90)
	assert_gt(bust.global_position.y, 1.2)
	var zap := DamageInfo.make(4.0, DamageInfo.Kind.ELECTRIC, target)
	zap.stun_time = 3.0
	zap.direction = Vector3(0, 0, 1)
	bust.take_damage(zap)
	await physics_frames(60)
	assert_true(bust.brain.is_stunned())
	assert_lt(bust.global_position.y, 0.15, "lies on the floor")
	var destroyed := watch(Events.enemy_destroyed)
	var punch := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, target)
	punch.can_finish = true
	punch.direction = Vector3(0, 0, 1)
	bust.take_damage(punch)
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_true(destroyed[0][2], "finisher")


## Knockback on a hovering bust dies down in the air as quickly as it would
## on the ground (no friction up there otherwise: a shotgun blast slid it
## tens of metres).
func test_a_punched_hovering_bust_drifts_less_than_a_metre() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(100)
	# only the punch moves it here: its own circling (a random side, a
	# random time to turn) would add to the drift or take from it
	bust.move_speed = 0.0
	await physics_frames(2)
	var start := bust.global_position
	var punch := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, target)
	punch.direction = Vector3(0, 0, 1)   # straight away from the guard: it only circles sideways
	punch.knockback = 6.0
	punch.position = bust.global_position + Vector3.UP
	bust.take_damage(punch)
	await physics_frames(120)
	var pushed := bust.global_position.z - start.z
	assert_gt(pushed, 0.15, "the punch still shoves it")
	assert_lt(pushed, 1.0)


func test_rises_again_after_the_stun() -> void:
	target.position = Vector3(0, 0, -10)
	_spawn()
	await physics_frames(60)
	var zap := DamageInfo.make(4.0, DamageInfo.Kind.ELECTRIC, target)
	zap.stun_time = 3.0
	bust.take_damage(zap)
	await physics_frames(300)
	assert_false(bust.brain.is_stunned())
	assert_gt(bust.global_position.y, 1.2)


func test_shards_start_at_the_muzzle_under_a_turned_parent() -> void:
	var room := Node3D.new()
	room.position = Vector3(6, 0, -4)
	room.rotation.y = 1.1
	add_child(room)
	target.position = Vector3(0, 0, -10)
	bust = Bust.new()
	bust.position = room.to_local(Vector3.ZERO)
	bust.target = target
	room.add_child(bust)
	bust.brain.wake()
	var shard: Projectile = null
	var muzzle := Vector3.ZERO
	for i in 150:
		await get_tree().physics_frame
		muzzle = bust.global_transform * Bust.MUZZLE
		for child in room.get_children():
			if child is Projectile:
				shard = child
		if shard != null:
			break
	assert_not_null(shard, "it fired")
	if shard == null:
		return
	assert_lt(shard.global_position.distance_to(muzzle), 0.4, "from its own muzzle")
	assert_gt((-shard.global_basis.z).dot(shard.velocity.normalized()), 0.99, "facing its flight")
	var to_guard := (target.global_position + Vector3.UP * Bust.AIM_HEIGHT - shard.global_position).normalized()
	assert_gt(shard.velocity.normalized().dot(to_guard), 0.98, "at the guard")


func test_shard_hurts_the_guard() -> void:
	target.queue_free()
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, -9)
	add_child(guard)
	bust = Bust.new()
	bust.target = guard
	add_child(bust)
	bust.face(guard.global_position)
	bust.brain.wake()
	await physics_frames(160)
	assert_eq(guard.health.current, 88.0)


func test_face_is_the_weak_point() -> void:
	_spawn(Vector3.ZERO, false)
	await physics_frames(2)
	var head_y := bust.global_position.y + bust.eye_height
	var space := bust.get_world_3d().direct_space_state
	var front := Hitscan.ray(space, Vector3(0, head_y, -5), Vector3(0, head_y, 5))
	var back := Hitscan.ray(space, Vector3(0, head_y, 5), Vector3(0, head_y, -5))
	assert_not_null(front.get("hurtbox"))
	assert_not_null(back.get("hurtbox"))
	if front.get("hurtbox") != null and back.get("hurtbox") != null:
		assert_true((front["hurtbox"] as Hurtbox).weak_point, "the face")
		assert_false((back["hurtbox"] as Hurtbox).weak_point, "the back of the head")


func test_dormant_bust_rests_on_its_plinth() -> void:
	Greybox.box(self, Vector3(4, 0.5, 0), Vector3(0.8, 1.0, 0.8), Color.GRAY)
	target.position = Vector3(4, 0, -40)
	Greybox.box(self, Vector3(4, 2, -3), Vector3(6, 4, 0.3), Color.GRAY)   # out of sight
	_spawn(Vector3(4, 1.3, 0), false)
	await physics_frames(60)
	assert_eq(bust.brain.state, EnemyBrain.State.DORMANT)
	assert_almost_eq(bust.global_position.y, 1.0, 0.08)
