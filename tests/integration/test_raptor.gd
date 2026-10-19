extends TestCase
## The raptor skeleton: pack flanking, the 0.6 s crouch-and-hiss before a
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
	assert_eq(raptor.brain.windup, 0.6)
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
	# the driver (the nearest) runs straight in; the flankers split, so the
	# average of each side's flankers (not half the pack) is measured
	var right: Array[float] = []
	var left: Array[float] = []
	for raptor in pack:
		if raptor.flank_side > 0.0:
			right.append(raptor.global_position.x)
		elif raptor.flank_side < 0.0:
			left.append(raptor.global_position.x)
	assert_false(right.is_empty() or left.is_empty(), "flankers on both sides: %s / %s" % [right, left])
	var right_x: float = 0.0 if right.is_empty() else right.reduce(func(sum: float, x: float) -> float: return sum + x, 0.0) / right.size()
	var left_x: float = 0.0 if left.is_empty() else left.reduce(func(sum: float, x: float) -> float: return sum + x, 0.0) / left.size()
	# the target "faces" the pack (-Z): its right is +X
	assert_gt(right_x, 1.5, "the right flankers swing right: %.2f" % right_x)
	assert_lt(left_x, -1.5, "the left flankers swing left: %.2f" % left_x)
	var drivers := 0
	for raptor in pack:
		if raptor.driver():
			drivers += 1
			assert_false(raptor.flanking(), "the driver goes straight in")
		else:
			assert_true(raptor.flanking() or raptor.global_position.length() <= Raptor.FLANK_UNTIL + 0.5, "flanking while far")
	assert_eq(drivers, 1, "one driver, the rest flank")


func test_close_in_they_go_straight_for_the_guard() -> void:
	var raptor := _raptor(Vector3(0, 0, -5.5))
	raptor.flank_side = 1.0
	await physics_frames(2)
	raptor.brain.wake()
	await physics_frames(24)
	assert_false(raptor.flanking(), "inside 6 m: no more flanking")


func test_the_leap_is_telegraphed_by_a_0_6_s_crouch() -> void:
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
	assert_almost_eq(windup_frames / 60.0, 0.6, 1.5 / 60.0, "0.6 s of crouch and hiss")
	assert_gt(crouched, 0.8, "it visibly crouches")


func test_leaps_4_m_and_bites_for_8() -> void:
	var raptor := _raptor(Vector3(0, 0, -4.0))
	await physics_frames(2)
	raptor.brain.wake()
	await physics_frames(110)   # (a 0.6 s suspicion, a 0.6 s crouch, the leap)
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


func test_the_pack_picks_the_nearest_as_its_driver_and_replaces_a_fallen_one() -> void:
	var pack := RaptorPack.spawn(self, Vector3(0, 0, -20), 4, target, false)
	pack[2].position = Vector3(0, 0, -14)   # the nearest to the guard
	await physics_frames(2)
	for raptor in pack:
		raptor.summoned = true
	pack[0].brain.wake()
	await physics_frames(60)   # the suspicion, the rally
	assert_true(pack[2].driver(), "the nearest drives")
	var sides: Array = pack.map(func(r: Raptor) -> float: return r.flank_side)
	assert_eq(sides.count(0.0), 1, "one driver: %s" % [sides])
	assert_true(sides.has(1.0) and sides.has(-1.0), "flankers on both sides: %s" % [sides])
	var info := DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC, target)
	info.position = pack[2].global_position + Vector3.UP
	pack[2].take_damage(info)
	var drivers: Array = []
	for i in 360:   # the next rally (an attack's end, a mate's hunt) hands the part on
		await get_tree().physics_frame
		# (untyped: a freed raptor is no Raptor any more)
		var left: Array = pack.filter(func(r: Variant) -> bool: return is_instance_valid(r) and not (r as Raptor).is_queued_for_deletion())
		drivers = left.filter(func(r: Variant) -> bool: return (r as Raptor).driver())
		if not drivers.is_empty():
			break
	assert_eq(drivers.size(), 1, "a new driver took over")


## Review 19.10: the driver of one hunt kept its part for every hunt after
## it (a living driver counted as "the pack has one"); every new hunt, with
## nobody of the pack hunting yet, hands the parts out anew.
func test_a_second_hunt_picks_its_driver_again() -> void:
	var pack := RaptorPack.spawn(self, Vector3(0, 0, -20), 4, target, false)
	pack[2].position = Vector3(0, 0, -14)   # the nearest to the guard
	await physics_frames(2)
	for raptor in pack:
		raptor.summoned = true
	pack[0].brain.wake()
	await physics_frames(60)
	assert_true(pack[2].driver(), "the first hunt: the nearest drives")
	# the guard got away; the pack is at its posts again - and finds him again
	# from the other side, a different raptor now the nearest
	var posts: Array[Vector3] = [Vector3(6, 0, -22), Vector3(0, 0, -12), Vector3(-6, 0, -22), Vector3(0, 0, -26)]
	for i in pack.size():
		var raptor: Raptor = pack[i]
		raptor.brain.state = EnemyBrain.State.DORMANT
		raptor.global_position = posts[i]
		raptor.velocity = Vector3.ZERO
	target.position = Vector3.ZERO
	await physics_frames(2)
	pack[0].brain.wake()
	await physics_frames(60)
	assert_true(pack[1].driver(), "the second hunt: the raptor nearest him now drives")
	assert_false(pack[2].driver(), "the old driver is a flanker again")
	var sides: Array = pack.map(func(r: Raptor) -> float: return r.flank_side)
	assert_eq(sides.count(0.0), 1, "still one driver: %s" % [sides])
	assert_true(sides.has(1.0) and sides.has(-1.0), "flankers on both sides: %s" % [sides])
