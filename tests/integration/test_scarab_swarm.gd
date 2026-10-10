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
