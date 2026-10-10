extends TestCase
## The raptor skeleton: pack flanking, the 0.3 s crouch-and-hiss before a
## 4 m leap, the bite, fragility, bones, and the T-Rex summon factory.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(90, 1, 90), Color.GRAY)
	target = TargetDummy.new()
	add_child(target)


func _raptor(at: Vector3) -> Raptor:
	var raptor := Raptor.new()
	raptor.position = at
	raptor.target = target
	add_child(raptor)
	return raptor


func test_numbers_follow_the_design() -> void:
	var raptor := _raptor(Vector3(0, 0, -10))
	assert_eq(raptor.max_health, 25.0)
	assert_eq(raptor.move_speed, 7.5)
	assert_eq(raptor.attack_damage, 8.0)
	assert_eq(raptor.brain.attack_range, 4.0)
	assert_eq(raptor.brain.windup, 0.3)
	assert_eq(raptor.dust_value, 3)
	assert_eq(raptor.material_kind, ExhibitMaterial.Kind.BONE)


func test_two_pistol_shots_break_it_into_little_bones() -> void:
	var raptor := _raptor(Vector3(0, 0, -10))
	var destroyed := watch(Events.enemy_destroyed)
	raptor.take_damage(DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target))
	assert_eq(destroyed.size(), 0)
	raptor.take_damage(DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target))
	assert_eq(destroyed.size(), 1)
	var bones := GibPlanner.plan(ExhibitMaterial.Kind.BONE, 0.0, 25.0, false)
	var marble := GibPlanner.plan(ExhibitMaterial.Kind.MARBLE, 0.0, 25.0, false)
	assert_gt(bones.chunks, marble.chunks, "more pieces")
	assert_lt(bones.chunk_size, marble.chunk_size * 0.5, "little bones")


func test_pack_members_alternate_sides() -> void:
	var pack := RaptorPack.spawn(self, Vector3(0, 0, -20), 4, target, false)
	assert_eq(pack.size(), 4)
	var sides: Array = pack.map(func(r: Raptor) -> float: return r.flank_side)
	assert_eq(sides, [1.0, -1.0, 1.0, -1.0])


func test_pack_splits_to_the_guards_left_and_right() -> void:
	var pack := RaptorPack.spawn(self, Vector3(0, 0, -22), 4, target, true)
	await physics_frames(108)   # a 0.6 s suspicion, then about a second of the run
	var right := 0.0
	var left := 0.0
	for raptor in pack:
		if raptor.flank_side > 0.0:
			right += raptor.global_position.x * 0.5
		else:
			left += raptor.global_position.x * 0.5
	# the target "faces" the pack (-Z): its right is +X
	assert_gt(right, 1.5, "one half swings right: %.2f" % right)
	assert_lt(left, -1.5, "the other half left: %.2f" % left)
	for raptor in pack:
		assert_true(raptor.flanking() or raptor.global_position.length() <= Raptor.FLANK_UNTIL + 0.5, "flanking while far")


func test_close_in_they_go_straight_for_the_guard() -> void:
	var raptor := _raptor(Vector3(0, 0, -5.5))
	raptor.flank_side = 1.0
	await physics_frames(2)
	raptor.brain.wake()
	await physics_frames(24)
	assert_false(raptor.flanking(), "inside 6 m: no more flanking")


func test_the_leap_is_telegraphed_by_a_0_3_s_crouch() -> void:
	var raptor := _raptor(Vector3(0, 0, -3.6))
	var strikes := watch(raptor.brain.strike)
	await physics_frames(2)
	raptor.brain.wake()
	var windup_frames := 0
	var crouched := 0.0
	for i in 120:
		await get_tree().physics_frame
		if raptor.brain.state == EnemyBrain.State.ATTACK and strikes.is_empty():
			windup_frames += 1
			crouched = maxf(crouched, raptor.crouch())
			assert_eq(target.hits.size(), 0, "no bite during the telegraph")
		if not strikes.is_empty():
			break
	assert_almost_eq(windup_frames / 60.0, 0.3, 1.5 / 60.0, "0.3 s of crouch and hiss")
	assert_gt(crouched, 0.8, "it visibly crouches")


func test_leaps_4_m_and_bites_for_8() -> void:
	var raptor := _raptor(Vector3(0, 0, -4.0))
	await physics_frames(2)
	raptor.brain.wake()
	await physics_frames(75)
	assert_eq(target.hits.size(), 1, "one bite per leap")
	if target.hits.size() == 1:
		assert_eq(target.hits[0].amount, 8.0)
	assert_lt(raptor.global_position.distance_to(target.global_position), 2.0, "it landed on him")


func test_summoner_brings_raptors_or_falls_back() -> void:
	var spots: Array[Vector3] = [Vector3(10, 0, 0)]
	var always := RaptorPack.summoner(self, spots, target, Callable(), 1.0)
	var called: Array = always.call(4)
	assert_eq(called.size(), 4)
	for node in called:
		assert_true(node is Raptor)
		assert_ne((node as Raptor).brain.state, EnemyBrain.State.DORMANT, "they come awake")
	var capped: Array = always.call(6)
	assert_eq(capped.size(), RaptorPack.MAX_SIZE, "a pack is at most 4")
	var fallback_calls: Array = []
	var fallback := func(count: int) -> Array:
		fallback_calls.append(count)
		return []
	var never := RaptorPack.summoner(self, spots, target, fallback, 0.0)
	assert_eq((never.call(3) as Array).size(), 0)
	assert_eq(fallback_calls, [3], "the fallback answered")


## Done flanking (close to the guard), a raptor plans for the guard
## himself at once: whether it can reach him is known before it leaps.
func test_leaving_the_flank_plans_for_the_guard_at_once() -> void:
	var raptor := _raptor(Vector3(0, 0, -20))
	raptor.flank_side = 1.0
	raptor.brain.wake()
	await physics_frames(40)
	assert_true(raptor.flanking(), "far off: it runs for the flank")
	target.position = raptor.global_position + Vector3(0, 0, 4.5)
	await physics_frames(2)
	assert_false(raptor.flanking(), "close in: straight for him")
	assert_lt(Vector2(raptor.nav.target_position.x - target.position.x, raptor.nav.target_position.z - target.position.z).length(), 0.01,
			"the path now leads to the guard")


func _shadow_casters(raptor: Raptor) -> int:
	var casters := 0
	for node in raptor.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
	return casters


## A pack of four must not cost hundreds of shadow draws: only the big
## bones cast shadows, on the model and on the greybox alike.
func test_only_the_big_bones_cast_shadows() -> void:
	var model := _raptor(Vector3(0, 0, -10))
	assert_lt(_shadow_casters(model), 9, "the model")
	ArtLibrary.models_enabled = false
	var greybox := _raptor(Vector3(3, 0, -10))
	ArtLibrary.models_enabled = true
	assert_eq(greybox.rig, null)
	assert_gt(greybox.find_children("*", "MeshInstance3D", true, false).size(), 40, "a greybox of many little bones")
	assert_lt(_shadow_casters(greybox), 9, "the greybox")
