extends TestCase

var knight: Knight


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	knight = Knight.new()
	add_child(knight)


## A 20-damage hit travelling along [param travel].
func _shot(kind: DamageInfo.Kind, travel: Vector3) -> DamageInfo:
	var info := DamageInfo.make(20.0, kind, null)
	info.direction = travel
	info.position = knight.global_position + Vector3.UP
	if kind == DamageInfo.Kind.ELECTRIC:
		info.stun_time = 3.0
	return info


func test_frontal_shot_is_blocked() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_true(info.blocked)
	assert_eq(knight.health.current, 180.0)


func test_shot_from_behind_lands() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1)))
	assert_eq(knight.health.current, 160.0)


func test_taser_from_the_front_stuns_and_opens_the_guard() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.ELECTRIC, Vector3(0, 0, 1)))
	assert_true(knight.brain.is_stunned())
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_false(info.blocked)
	assert_eq(knight.health.current, 140.0)


func test_steep_shot_from_a_balcony_gets_past_the_shield() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, -0.8, 0.6))
	knight.take_damage(info)
	assert_false(info.blocked)
	assert_eq(knight.health.current, 160.0)


func test_heavy_armour_resists_knockback() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1))
	info.knockback = 10.0
	knight.take_damage(info)
	assert_almost_eq(knight._external.length(), 3.0, 0.01)


func test_no_strike_through_a_thin_wall() -> void:
	Greybox.box(self, Vector3(0, 1.5, -0.85), Vector3(6, 3, 0.2), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, -1.55)
	add_child(target)
	knight.target = target
	await physics_frames(2)
	knight.brain.wake()
	await physics_frames(150)
	assert_eq(target.hits.size(), 0)


# --- standing guard (ecology) --------------------------------------------------------

func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _guard_on_a_beat() -> Knight:
	var sentry := Knight.new()
	sentry.position = Vector3(10, 0, 10)
	sentry.patrol_route = PackedVector3Array([Vector3(10, 0, 10), Vector3(10, 0, 2)])
	sentry.starts_awake = true
	sentry.brain.rng.seed = 3
	add_child(sentry)
	sentry.face(Vector3(10, 0, -10))   # its post looks down -Z
	return sentry


func test_a_knight_holds_its_post_facing_its_way_then_walks_its_beat() -> void:
	var sentry := _guard_on_a_beat()
	await physics_frames(2)
	assert_eq(sentry.brain.patrol_dwell.size(), 2, "a tank's route is a beat with posts")
	assert_gt(sentry.brain.patrol_dwell[0], Enemy.POST_DWELL.x - 0.01)
	assert_almost_eq(sentry.brain.patrol_yaw[0], sentry.home_yaw, 0.001, "at home it faces the way it stood")
	await _seconds(1.0)
	assert_eq(sentry.brain.state, EnemyBrain.State.PATROL)
	assert_false(sentry.brain.walking(), "it holds its post")
	await _seconds(4.5)
	assert_false(sentry.brain.walking(), "still (a post is held at least %.0f s)" % Enemy.POST_DWELL.x)
	assert_lt(sentry.global_position.distance_to(Vector3(10, 0, 10)), 0.3)
	var facing := -sentry.global_transform.basis.z
	assert_gt(facing.dot(Vector3(0, 0, -1)), 0.95, "facing its post's way")
	await _seconds(5.0)
	assert_true(sentry.brain.walking() or sentry.global_position.distance_to(Vector3(10, 0, 2)) < 1.5, "then it walks its beat")


func test_a_knight_answers_a_door_and_comes_back_to_its_beat() -> void:
	var sentry := _guard_on_a_beat()
	var spec := OpeningSpec.make(&"test_door", Rect2(-1, -0.25, 2, 0.5), 0.0, 2.5, &"a", &"b", OpeningSpec.DoorStyle.SWING, RoomGraph.Kind.LOCKABLE)
	spec.start_open = false
	var door := Door.make(spec, Transform3D(Basis.IDENTITY, Vector3(10, 0, 16)), Color(0.5, 0.45, 0.4))
	add_child(door)
	await physics_frames(2)
	await _seconds(1.0)
	door.open()
	assert_eq(sentry.brain.state, EnemyBrain.State.SUSPICIOUS, "the creak of a door")
	await _seconds(1.2)
	assert_eq(sentry.brain.state, EnemyBrain.State.INVESTIGATE, "the guard goes to see")
	assert_lt(Vector2(sentry.brain.goal.x - 10.0, sentry.brain.goal.z - 16.0).length(), 1.0, "to the doorway")
	for i in 40 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		if sentry.brain.state == EnemyBrain.State.PATROL:
			break
	assert_eq(sentry.brain.state, EnemyBrain.State.PATROL, "nothing there: back on its beat")


## A part's pose on top of its rest (radians, as the rig posed it).
func _posed(rig: KnightRig, part_name: String) -> Vector3:
	var rest: Transform3D = rig.rest[part_name]
	return (rest.basis.inverse() * rig.part(part_name).transform.basis).get_euler()


func test_woken_the_suit_comes_to_the_ready() -> void:
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, 10)
	add_child(dummy)
	var sentry := Knight.new()
	sentry.position = Vector3(0, 0, -6)
	sentry.target = dummy
	add_child(sentry)
	sentry.face(Vector3(0, 0, -20))   # its back to the guard: it only hears
	var rig := sentry.rig as KnightRig
	assert_not_null(rig, "the knight's model")
	if rig == null:
		return
	await physics_frames(10)
	assert_almost_eq(_posed(rig, "arm_r").x, 0.0, 0.05, "asleep: the sword hangs at rest")
	sentry.hear(Vector3(0, 0, -12))
	assert_eq(sentry.brain.state, EnemyBrain.State.SUSPICIOUS)
	var twists: Array[float] = []
	for i in roundi(KnightRig.RATTLE_TIME * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		twists.append(_posed(rig, "torso").y)
	assert_gt(twists.max() - twists.min(), KnightRig.RATTLE * 0.5, "the suit shivers awake")
	assert_gt(_posed(rig, "arm_r").x, KnightRig.READY_SWORD * 0.7, "the sword drawn back to the ready")
	assert_gt(_posed(rig, "arm_l").x, 0.2, "the shield lifted before it")
