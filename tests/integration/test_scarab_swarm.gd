extends TestCase
## The scarab swarm as the Egyptian wing's own exhibit (design 5.1): a
## sleeping heap that rises into a humming cloud, the cloud's flow, its
## bite, buckshot and fire, hits and its death in dead beetles.

var swarm: ScarabSwarm


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _spawn(target: Node3D, awake: bool) -> ScarabSwarm:
	swarm = ScarabSwarm.new()
	swarm.target = target
	add_child(swarm)
	if awake:
		swarm.summoned = true
		swarm.brain.wake()
	return swarm


func _dummy(at: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


func test_the_wing_spawns_swarms_where_its_slots_ask() -> void:
	var made := NightSpawner.make(&"scarabs")
	assert_true(made is ScarabSwarm)
	made.free()
	var kinds: Array[StringName] = [&"wolf", &"scarabs"]
	assert_eq(NightSpawner.preferred(kinds, &"wolf"), &"scarabs")


func test_asleep_it_is_a_silent_heap() -> void:
	var dummy := _dummy(Vector3(0, 0, 12))
	_spawn(dummy, false)
	await physics_frames(20)
	assert_eq(swarm.risen(), 0.0)
	for i in ScarabSwarm.CRAWLERS:
		var at := swarm.crawler(i)
		assert_lt(Vector2(at.x, at.z).length(), 0.4, "in the heap")
		assert_lt(at.y, 0.06, "on the floor")
	var hum := swarm.get_node("Hum") as AudioStreamPlayer3D
	assert_false(hum.playing, "silent")
	var cloud := swarm.find_child("Cloud", true, false) as Node3D
	assert_not_null(cloud)
	if cloud != null:
		assert_false(cloud.visible, "no cloud yet")


func test_woken_it_rises_into_a_humming_cloud() -> void:
	var dummy := _dummy(Vector3(0, 0, -15))
	_spawn(dummy, false)
	await physics_frames(10)
	swarm.summoned = true
	swarm.brain.wake()
	await physics_frames(int(ScarabSwarm.EMERGE_TIME * 60.0) + 5)
	assert_almost_eq(swarm.risen(), 1.0, 0.01)
	var height := 0.0
	for i in ScarabSwarm.COUNT:
		height += swarm.beetle(i).y / ScarabSwarm.COUNT
	assert_gt(height, 0.4, "the beetles are up in the air")
	assert_true((swarm.get_node("Hum") as AudioStreamPlayer3D).playing, "the hum swells in")


func test_on_the_move_the_cloud_trails_behind() -> void:
	var dummy := _dummy(Vector3(0, 0, -30))
	_spawn(dummy, true)
	await physics_frames(120)
	var forward := swarm.global_basis.orthonormalized().inverse() * (dummy.global_position - swarm.global_position)
	forward.y = 0.0
	forward = forward.normalized()
	var tail := 0.0
	for i in range(ScarabSwarm.COUNT / 2, ScarabSwarm.COUNT):
		tail += swarm.beetle(i).dot(forward)
	assert_lt(tail / (ScarabSwarm.COUNT / 2), -0.3, "the second half of the cloud streams behind")


func test_it_bites_six_a_second_and_buckshot_and_fire_tear_it_double() -> void:
	var dummy := _dummy(Vector3(0, 0, -0.5))
	_spawn(dummy, true)
	for i in 120:
		dummy.position = swarm.global_position
		await get_tree().physics_frame
	var bitten := 0.0
	for hit in dummy.hits:
		bitten += hit.amount
	assert_almost_eq(bitten, ScarabSwarm.BITE_PER_SECOND * 2.0, 2.0, "about 6 a second")
	var buckshot := DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC)
	buckshot.weapon = &"shotgun"
	swarm.take_damage(buckshot)
	assert_almost_eq(swarm.health.current, 30.0, 0.01)
	swarm.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.FIRE))
	assert_almost_eq(swarm.health.current, 20.0, 0.01)


func test_hits_knock_out_dead_beetles_and_it_dies_in_a_rain_of_them() -> void:
	var dummy := _dummy(Vector3(0, 0, -15))
	_spawn(dummy, true)
	await physics_frames(30)
	var before := Fx.chunk_count()
	var hit := DamageInfo.make(12.0, DamageInfo.Kind.BALLISTIC)
	hit.position = swarm.global_position + Vector3.UP
	swarm.take_damage(hit)
	assert_eq(Fx.chunk_count() - before, 2, "two dead beetles fall out")
	var destroyed := watch(Events.enemy_destroyed)
	before = Fx.chunk_count()
	var kill := DamageInfo.make(100.0, DamageInfo.Kind.BALLISTIC)
	kill.position = hit.position
	swarm.take_damage(kill)
	assert_eq(destroyed.size(), 1)
	assert_gt(Fx.chunk_count() - before, 12, "a rain of beetles and wing cases")


# --- the stream along the walls (ecology) -----------------------------------------------

func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## A 10 x 10 m room of four walls round the origin.
func _room() -> void:
	for wall: Array in [[Vector3(5.5, 1.5, 0), Vector3(1, 3, 12)], [Vector3(-5.5, 1.5, 0), Vector3(1, 3, 12)],
			[Vector3(0, 1.5, 5.5), Vector3(12, 3, 1)], [Vector3(0, 1.5, -5.5), Vector3(12, 3, 1)]]:
		Greybox.box(self, wall[0], wall[1], Color.DIM_GRAY)


func _nearest_wall(point: Vector3) -> float:
	return minf(minf(absf(5.0 - absf(point.x)), absf(5.0 - absf(point.z))), 99.0)


func test_a_disturbed_swarm_streams_along_the_walls_of_its_room() -> void:
	_room()
	var dummy := _dummy(Vector3(0, 0, 40))
	_spawn(dummy, false)
	await physics_frames(3)
	var route := swarm.stream()
	assert_gt(route.size(), 3, "a route round the room's walls (%d points)" % route.size())
	for point in route:
		assert_lt(_nearest_wall(point), 0.6, "hugging a wall: %s" % point)
		assert_gt(_nearest_wall(point), 0.2, "not in it: %s" % point)
	assert_eq(swarm.brain.state, EnemyBrain.State.DORMANT, "a heap until something disturbs it")
	swarm.hear(Vector3(2, 0, 2))
	await _seconds(1.0)
	# (the point is 3 m off: a quick swarm may be there already, searching)
	assert_true(swarm.brain.state == EnemyBrain.State.INVESTIGATE or swarm.brain.state == EnemyBrain.State.SEARCH, "it goes to look (%s)" % EnemyBrain.State.keys()[swarm.brain.state])
	var frames := 0
	while swarm.brain.state != EnemyBrain.State.PATROL and frames < 40 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		frames += 1
	assert_eq(swarm.brain.state, EnemyBrain.State.PATROL, "disturbed once, it never heaps up again: it streams")
	var start := swarm.global_position
	await _seconds(4.0)
	assert_gt(swarm.global_position.distance_to(start), 1.0, "on the move along the walls")
	assert_gt(swarm.risen(), 0.9, "the cloud is up")


func test_a_swarm_gathers_on_a_fallen_exhibit() -> void:
	var dummy := _dummy(Vector3(0, 0, 40))
	_spawn(dummy, false)
	swarm.brain.rng.seed = 5
	var fallen := WaxFigure.new()
	fallen.position = Vector3(0, 0, 6)
	fallen.target = dummy
	add_child(fallen)
	await physics_frames(3)
	var info := DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC, dummy)
	info.position = fallen.global_position + Vector3.UP
	fallen.take_damage(info)
	await _seconds(1.0)
	assert_eq(swarm.brain.state, EnemyBrain.State.INVESTIGATE, "the beetles swarm the fallen")
	assert_lt(swarm.brain.goal.distance_to(Vector3(0, 0, 6)), 0.5)
