extends TestCase

var target: TargetDummy
var wolf: Wolf


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -5)
	add_child(target)
	wolf = Wolf.new()
	wolf.target = target
	add_child(wolf)


func test_pounce_covers_the_distance_and_bites() -> void:
	await physics_frames(2)
	wolf.brain.wake()
	await physics_frames(90)
	assert_lt(wolf.global_position.distance_to(target.global_position), 2.0)
	assert_gt(target.hits.size(), 0)


func test_two_pistol_shots_kill_a_wolf() -> void:
	var destroyed := watch(Events.enemy_destroyed)
	for i in 2:
		wolf.take_damage(DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target))
	assert_eq(destroyed.size(), 1)


func test_one_bite_per_pounce() -> void:
	var strikes := watch(wolf.brain.strike)
	await physics_frames(2)
	wolf.brain.wake()
	for i in 180:
		if strikes.size() == 1 and wolf.brain.state == EnemyBrain.State.HUNT:
			break
		await get_tree().physics_frame
	assert_eq(strikes.size(), 1, "one pounce")
	assert_eq(target.hits.size(), 1)


func test_no_bite_while_recovering_from_a_missed_pounce() -> void:
	await physics_frames(2)
	wolf.brain.wake()
	for i in 180:
		if wolf.brain.has_struck() and not wolf.is_on_floor():
			break
		await get_tree().physics_frame
	target.position = Vector3(15, 0, 0)   # dodges while the wolf is in the air
	for i in 120:
		if wolf.is_on_floor():
			break
		await get_tree().physics_frame
	await physics_frames(3)
	assert_true(wolf.brain.has_struck(), "still recovering")
	target.position = wolf.global_position + wolf.global_transform.basis.z * 1.2   # steps in behind it
	await physics_frames(3)
	assert_eq(target.hits.size(), 0)


func test_no_bite_through_the_floor_above() -> void:
	Greybox.box(self, Vector3(0, 3.5, -17.5), Vector3(20, 0.5, 9), Color.GRAY)
	target.position = Vector3(0, 3.75, -14)
	wolf.position = Vector3(0, 0, -12.5)
	await physics_frames(2)
	wolf.brain.wake()
	await physics_frames(120)
	assert_eq(target.hits.size(), 0)
