extends TestCase

var target: TargetDummy
var wax: WaxFigure


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)
	wax = WaxFigure.new()
	wax.target = target
	add_child(wax)


func _hit(amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, target)
	info.direction = Vector3(0, 0, 1)
	info.position = wax.global_position + Vector3.UP
	return info


func test_three_pistol_shots_destroy_it() -> void:
	var destroyed := watch(Events.enemy_destroyed)
	for i in 3:
		wax.take_damage(_hit(20.0))
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_false(destroyed[0][2], "not a finisher")
	assert_true(wax.is_queued_for_deletion())


func test_hits_wake_it_up_and_melt_it() -> void:
	wax.take_damage(_hit(30.0))
	assert_eq(wax.brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_eq(wax.brain.last_known, target.global_position, "it knows where the hit came from")
	assert_lt(wax.visual.scale.y, 1.0)


func test_melting_lowers_the_head_hit_zone_with_the_head() -> void:
	var head := _weak_point()
	var rest_y := head.position.y
	wax.take_damage(_hit(45.0))
	assert_almost_eq(head.position.y, rest_y * wax.visual.scale.y, 0.001)
	assert_lt(head.position.y, rest_y - 0.1)


func test_taser_stuns() -> void:
	var zap := _hit(4.0, DamageInfo.Kind.ELECTRIC)
	zap.stun_time = 3.0
	wax.take_damage(zap)
	assert_true(wax.brain.is_stunned())


func test_fist_on_a_stunned_figure_is_a_finisher_that_heals_the_guard() -> void:
	var guard := Player.new()
	guard.position = Vector3(5, 0, 5)
	add_child(guard)
	guard.health.apply_damage(40.0)
	var destroyed := watch(Events.enemy_destroyed)
	var zap := _hit(4.0, DamageInfo.Kind.ELECTRIC)
	zap.stun_time = 3.0
	wax.take_damage(zap)
	var punch := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, guard)
	punch.can_finish = true
	wax.take_damage(punch)
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_true(destroyed[0][2], "finisher")
	assert_eq(guard.health.current, 75.0)


func test_awake_figure_walks_toward_the_target() -> void:
	await physics_frames(2)
	var start := wax.global_position.distance_to(target.global_position)
	wax.brain.wake()
	await physics_frames(90)
	assert_lt(wax.global_position.distance_to(target.global_position), start - 1.0)


func test_strike_hurts_a_target_in_reach() -> void:
	target.position = Vector3(0, 0, -1.4)
	await physics_frames(2)
	wax.brain.wake()
	await physics_frames(90)
	assert_gt(target.hits.size(), 0)
	if target.hits.size() > 0:
		assert_eq(target.hits[0].amount, 12.0)


func test_a_figure_stuck_at_a_wall_steps_aside() -> void:
	Greybox.box(self, Vector3(0, 1.5, -1.5), Vector3(8, 3, 0.2), Color.GRAY)
	await physics_frames(2)
	wax.summoned = true   # it knows where the target is behind the wall
	wax.brain.wake()
	var widest := 0.0
	for i in 165:   # (a 0.8 s suspicion first)
		await get_tree().physics_frame
		widest = maxf(widest, absf(wax.global_position.x))
	assert_gt(widest, 0.6)


func test_stepping_back_during_the_windup_avoids_the_strike() -> void:
	target.position = Vector3(0, 0, -1.4)
	await physics_frames(2)
	wax.brain.wake()
	for i in 120:
		if wax.brain.state == EnemyBrain.State.ATTACK:
			break
		await get_tree().physics_frame
	assert_eq(wax.brain.state, EnemyBrain.State.ATTACK)
	target.position = Vector3(0, 0, -6)
	await physics_frames(50)
	assert_eq(target.hits.size(), 0)


func test_waking_one_wakes_its_group_but_not_distant_ones() -> void:
	var near := WaxFigure.new()
	near.position = Vector3(2, 0, 0)
	near.target = target
	add_child(near)
	var far := WaxFigure.new()
	far.position = Vector3(20, 0, 0)
	far.target = target
	add_child(far)
	wax.brain.wake()
	assert_ne(near.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(far.brain.state, EnemyBrain.State.DORMANT)


func test_group_wake_does_not_pass_through_walls() -> void:
	target.position = Vector3(0, 0, -40)   # out of sight: only the group can wake them
	Greybox.box(self, Vector3(1, 1.5, 0), Vector3(0.2, 3, 6), Color.GRAY)
	var behind_wall := _figure_at(Vector3(2, 0, 0))
	var in_view := _figure_at(Vector3(-2, 0, 0))
	await physics_frames(2)
	wax.brain.wake()
	assert_ne(in_view.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(behind_wall.brain.state, EnemyBrain.State.DORMANT)


func test_only_the_first_of_a_group_calls_out() -> void:
	var camera := Camera3D.new()   # the listener, next to the group
	add_child(camera)
	camera.current = true
	_figure_at(Vector3(2, 0, 0))
	_figure_at(Vector3(-2, 0, 0))
	Sfx.stop_all()
	wax.brain.wake()
	var notices := Sfx.get_children().filter(func(node: Node) -> bool:
		var player := node as AudioStreamPlayer3D
		return player != null and player.stream.resource_path.get_file() == "notice.wav")
	assert_eq(notices.size(), 1)


func test_stats_set_before_entering_the_tree_are_kept() -> void:
	var tough := WaxFigure.new()
	tough.max_health = 90.0
	tough.move_speed = 5.0
	tough.position = Vector3(4, 0, 0)
	add_child(tough)
	assert_eq(tough.health.max_health, 90.0)
	assert_eq(tough.move_speed, 5.0)


func test_leaves_a_dead_guard_alone() -> void:
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, -1.4)
	add_child(guard)
	wax.target = guard
	var strikes := watch(wax.brain.strike)
	await physics_frames(2)
	guard.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	wax.brain.wake()
	await physics_frames(90)
	assert_eq(strikes.size(), 0)


func test_finds_the_guard_again_after_losing_its_target() -> void:
	target.queue_free()
	var guard := Player.new()
	guard.position = Vector3(0, 0.05, -6)
	add_child(guard)
	await physics_frames(20)
	assert_eq(wax.target, guard)


func _weak_point() -> Hurtbox:
	for child in wax.get_children():
		var hurtbox := child as Hurtbox
		if hurtbox != null and hurtbox.weak_point:
			return hurtbox
	return null


func _figure_at(at: Vector3) -> WaxFigure:
	var figure := WaxFigure.new()
	figure.position = at
	figure.target = target
	add_child(figure)
	return figure
