extends TestCase
## The mummy (design pietro-1-projekt 5.1) on a flat grey floor: its
## numbers and model, the exhibit's crossed arms and the suspicious head
## turn, the dragging shamble, the bandage lash (telegraph, pull, slow,
## the tip on its mark, a dodge, the cooldown), fire panic, stun and
## finisher, and falling apart.

var mummy: Mummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _spawn(at: Vector3, target: Node3D, awake: bool = true) -> Mummy:
	mummy = Mummy.new()
	mummy.position = at
	mummy.target = target
	add_child(mummy)
	if target != null:
		mummy.face(target.global_position)
	if awake:
		mummy.summoned = true
		mummy.brain.wake()
	return mummy


func _guard(at: Vector3) -> Player:
	var guard := Player.new()
	guard.position = at
	add_child(guard)
	return guard


func _dummy(at: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


## Waits until the mummy's brain strikes (at most [param frames]); true
## when it did.
func _until_strike(frames: int) -> bool:
	var struck := watch(mummy.brain.strike)
	for i in frames:
		await get_tree().physics_frame
		if not struck.is_empty():
			return true
	return false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_is_a_110_health_linen_mummy_on_its_model() -> void:
	_spawn(Vector3.ZERO, null, false)
	assert_eq(Mummy.KIND, &"mummy")
	assert_eq(mummy.health.max_health, 110.0)
	assert_eq(mummy.move_speed, 1.9)
	assert_eq(mummy.dust_value, 6)
	assert_eq(mummy.material_kind, ExhibitMaterial.Kind.LINEN)
	assert_true(mummy.rig is MummyRig, "the Blender model is on")
	var weak := 0
	for child in mummy.get_children():
		if child is Hurtbox and (child as Hurtbox).weak_point:
			weak += 1
	assert_eq(weak, 1, "the head is the weak point")
	var made := NightSpawner.make(&"mummy")
	assert_true(made is Mummy, "the spawner builds it")
	made.free()


func test_asleep_its_arms_are_crossed_on_its_chest() -> void:
	_spawn(Vector3.ZERO, null, false)
	await physics_frames(30)
	var rig := mummy.rig
	var left_hand := rig.part_transform("forearm_l") * Vector3(0, -0.4, -0.03)
	var right_hand := rig.part_transform("forearm_r") * Vector3(0, -0.4, -0.03)
	var left_shoulder := rig.part_transform("arm_l").origin
	var right_shoulder := rig.part_transform("arm_r").origin
	assert_lt(left_hand.distance_to(right_shoulder), left_hand.distance_to(left_shoulder), "the left hand rests at the right shoulder")
	assert_lt(right_hand.distance_to(left_shoulder), right_hand.distance_to(right_shoulder), "the right hand at the left shoulder")
	assert_lt(left_hand.z, -0.1, "in front of the chest")
	assert_eq((rig as MummyRig).eye_energy(), 0.0, "dark eyes")


func test_suspicious_it_turns_its_head_before_its_body() -> void:
	_spawn(Vector3.ZERO, null, false)
	await physics_frames(10)
	var noise := Vector3(-8, 0, -1)   # to its left
	mummy.hear(noise)
	assert_eq(mummy.brain.state, EnemyBrain.State.SUSPICIOUS)
	await physics_frames(20)
	var to_noise := (noise - mummy.global_position).normalized()
	var body := -mummy.global_basis.z
	var head := -(mummy.global_transform * mummy.rig.part_transform("head")).basis.z
	head.y = 0.0
	var body_off := body.angle_to(Vector3(to_noise.x, 0, to_noise.z))
	var head_off := head.normalized().angle_to(Vector3(to_noise.x, 0, to_noise.z))
	assert_lt(head_off, body_off - 0.4, "the head is well ahead of the body")
	assert_gt((mummy.rig as MummyRig).eye_energy(), 0.6, "its eyes light up")


func test_shambles_at_under_two_metres_a_second_dragging_its_right_foot() -> void:
	var dummy := _dummy(Vector3(0, 0, -30))
	_spawn(Vector3.ZERO, dummy)
	await physics_frames(90)
	var start := mummy.global_position
	var rig := mummy.rig
	var rest_l := rig.part_transform("leg_l").origin.x
	var rest_r := rig.part_transform("leg_r").origin.x
	var out_l := 0.0
	var out_r := 0.0
	for i in 180:
		await get_tree().physics_frame
		var foot_l := rig.part_transform("leg_l") * Vector3(0, -0.88, 0)
		var foot_r := rig.part_transform("leg_r") * Vector3(0, -0.88, 0)
		out_l = maxf(out_l, rest_l - foot_l.x)
		out_r = maxf(out_r, foot_r.x - rest_r)
	var speed := _flat(mummy.global_position, start) / 3.0
	assert_gt(speed, 1.6)
	assert_lt(speed, 2.0)
	assert_gt(out_r, out_l + 0.05, "the dragging foot swings out in an arc")


func test_the_lash_pulls_the_guard_in_and_slows_him() -> void:
	var guard := _guard(Vector3(0, 0.05, -3.6))
	_spawn(Vector3.ZERO, guard)
	var before := guard.global_position
	assert_true(await _until_strike(240), "it lashed")
	assert_eq(mummy.move, MummyMoves.Move.LASH)
	assert_eq(mummy.lash_result, Mummy.Lash.HIT)
	await physics_frames(20)
	var pulled := _flat(before, guard.global_position)
	assert_almost_eq(pulled, 2.4, 0.25, "3.6 m - 1.2 m")
	assert_gt(guard.global_position.z, before.z, "toward the mummy")
	assert_eq(guard.health.current, guard.health.max_health - 8.0)
	assert_almost_eq(guard.speed_factor(), 0.5, 0.01, "slowed")
	await physics_frames(50)
	assert_almost_eq(guard.speed_factor(), 0.5, 0.01, "still slowed just under 1 s after the pull")
	await physics_frames(20)
	assert_almost_eq(guard.speed_factor(), 1.0, 0.01, "free again")


func test_from_further_off_the_pull_is_three_metres() -> void:
	var guard := _guard(Vector3(0, 0.05, -4.2))
	_spawn(Vector3.ZERO, guard)
	var before := guard.global_position
	assert_true(await _until_strike(240))
	await physics_frames(20)
	assert_almost_eq(_flat(before, guard.global_position), 3.0, 0.25)


func test_the_telegraph_lasts_0_6_s_and_raises_the_unrolled_bandage() -> void:
	var dummy := _dummy(Vector3(0, 0, -3.5))
	_spawn(Vector3.ZERO, dummy)
	var frames := 0
	for i in 240:
		await get_tree().physics_frame
		if mummy.brain.state == EnemyBrain.State.ATTACK:
			break
	assert_eq(mummy.brain.state, EnemyBrain.State.ATTACK)
	assert_eq(mummy.move, MummyMoves.Move.LASH)
	var struck := watch(mummy.brain.strike)
	var rig := mummy.rig as MummyRig
	var rest_span := 4 * MummyRig.SEGMENT
	var high := false
	var long := false
	while struck.is_empty() and frames < 120:
		await get_tree().physics_frame
		frames += 1
		if frames == 30:
			var shoulder := (mummy.global_transform * rig.part_transform("arm_r")).origin
			high = rig.whip_tip().y > shoulder.y
			long = rig.whip.span() > rest_span * 1.2
	assert_almost_eq(frames / 60.0, 0.6, 0.04, "0.6 s from the windup to the strike")
	assert_true(high, "the bandage rises over its shoulder")
	assert_true(long, "and unrolls")


func test_the_tip_flies_to_the_guard() -> void:
	var guard := _guard(Vector3(0, 0.05, -3.6))
	_spawn(Vector3.ZERO, guard)
	assert_true(await _until_strike(240))
	var closest := INF
	for i in 14:
		await get_tree().physics_frame
		var chest := guard.global_position + Vector3.UP * Mummy.GUARD_CHEST
		closest = minf(closest, (mummy.rig as MummyRig).whip_tip().distance_to(chest))
	assert_lt(closest, 0.5, "the bandage reaches him")


func test_stepping_aside_at_the_last_moment_dodges_the_lash() -> void:
	var guard := _guard(Vector3(0, 0.05, -3.6))
	_spawn(Vector3.ZERO, guard)
	for i in 240:
		await get_tree().physics_frame
		if mummy.brain.state == EnemyBrain.State.ATTACK and mummy.brain.windup_progress() > 0.85:
			break
	assert_true(mummy.brain.windup_progress() > 0.85, "in the last moments of the telegraph")
	guard.global_position += mummy.global_basis.x * 1.7
	var before := guard.global_position
	assert_true(await _until_strike(30))
	await physics_frames(15)
	assert_eq(mummy.lash_result, Mummy.Lash.MISSED)
	assert_eq(guard.health.current, guard.health.max_health, "no damage")
	assert_lt(_flat(before, guard.global_position), 0.2, "no pull")


func test_after_a_lash_only_the_claws_for_a_while() -> void:
	var guard := _guard(Vector3(0, 0.05, -3.6))
	_spawn(Vector3.ZERO, guard)
	var hurt := watch(Events.player_damaged)
	for i in 4 * 60:
		await get_tree().physics_frame
		if hurt.size() >= 2:
			break
	assert_eq(hurt.size(), 2, "the lash, then a blow")
	if hurt.size() == 2:
		assert_eq(hurt[0][0], MummyMoves.LASH_DAMAGE)
		assert_eq(hurt[1][0], 16.0, "the claws")
	assert_eq(mummy.move, MummyMoves.Move.CLAW)


func test_fire_burns_double_and_sends_it_running_in_panic() -> void:
	var dummy := _dummy(Vector3(0, 0, -1.4))
	_spawn(Vector3.ZERO, dummy)
	await physics_frames(60)
	var before := mummy.health.current
	Blast.explode(self, mummy.global_position + Vector3(0, 0.9, -0.5), 1.2, 10.0, 0.0, DamageInfo.Kind.FIRE, null)
	assert_almost_eq(before - mummy.health.current, 20.0, 0.01, "linen takes fire double")
	var burning := false
	for child in mummy.get_children():
		if child is Burn:
			burning = true
	assert_true(burning, "its bandages burn")
	assert_true(mummy.panicking())
	var hits := dummy.hits.size()
	for i in 115:
		await get_tree().physics_frame
	assert_eq(dummy.hits.size(), hits, "no attacks in panic")
	assert_gt(_flat(mummy.global_position, dummy.global_position), 2.5, "it ran away from him")
	for i in 300:
		await get_tree().physics_frame
		if dummy.hits.size() > hits:
			break
	assert_false(mummy.panicking())
	assert_gt(dummy.hits.size(), hits, "back on the attack after the panic")


func test_stunned_it_can_be_finished_with_a_fist() -> void:
	var dummy := _dummy(Vector3(0, 0, -6))
	_spawn(Vector3.ZERO, dummy)
	await physics_frames(10)
	var stun := DamageInfo.make(5.0, DamageInfo.Kind.ELECTRIC)
	stun.stun_time = 3.0
	mummy.take_damage(stun)
	assert_true(mummy.brain.is_stunned())
	var finished := watch(Events.enemy_destroyed)
	var fist := DamageInfo.make(10.0, DamageInfo.Kind.BLUNT)
	fist.can_finish = true
	mummy.take_damage(fist)
	assert_eq(finished.size(), 1)
	if finished.size() == 1:
		assert_true(finished[0][2], "a finisher")


func test_it_falls_apart_into_parts_bones_rags_and_dust() -> void:
	_spawn(Vector3.ZERO, null, false)
	await physics_frames(5)
	var parts := (mummy.rig as MummyRig).meshes.size()
	var before := Fx.chunk_count()
	var kill := DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC)
	kill.direction = Vector3.FORWARD
	mummy.take_damage(kill)
	assert_gt(Fx.chunk_count() - before, parts + 4, "its parts plus bones and rags")


func test_heavy_hits_tear_off_rags() -> void:
	_spawn(Vector3.ZERO, null, false)
	await physics_frames(5)
	var before := Fx.chunk_count()
	var hit := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC)
	hit.direction = Vector3.FORWARD
	hit.position = mummy.global_position + Vector3(0, 1.2, 0.2)
	mummy.take_damage(hit)
	assert_eq(Fx.chunk_count() - before, 1, "one rag")
	var light := DamageInfo.make(6.0, DamageInfo.Kind.BALLISTIC)
	light.position = hit.position
	mummy.take_damage(light)
	assert_eq(Fx.chunk_count() - before, 1, "a light hit only puffs dust")
