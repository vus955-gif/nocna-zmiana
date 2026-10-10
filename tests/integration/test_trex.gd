extends TestCase
## The T-Rex boss in a small hall: damage zones, phases, charge and stun,
## tail, roar summons, taser stagger, death, dormancy and steering.

const S := TRexBrain.State

var trex: TRex
var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(90, 1, 90), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -12)
	add_child(target)
	trex = TRex.new()
	trex.position = Vector3(0, 0.05, 0)
	trex.target = target
	add_child(trex)


## Awake and hunting at once (skips the wake roar), no charge for a while.
func _hunting() -> void:
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 99.0


func _hit(amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, target)
	info.direction = Vector3(0, 0, 1)
	info.position = trex.global_position + Vector3.UP * 3.0
	return info


func _crystal(amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := _hit(amount, kind)
	trex.take_zone_damage(info, TRexBrain.Zone.CRYSTAL)
	return info


func _bone(amount: float) -> DamageInfo:
	var info := _hit(amount)
	trex.take_zone_damage(info, TRexBrain.Zone.BONE)
	return info


func _wait_for(state: TRexBrain.State, max_frames: int) -> bool:
	for i in max_frames:
		if trex.brain.state == state:
			return true
		await get_tree().physics_frame
	return trex.brain.state == state


func _count_rigid(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is RigidBody3D:
			count += 1
	return count


func test_sleeps_on_its_feet_until_woken_and_ignores_shots() -> void:
	target.position = Vector3(0, 0, -6)
	var awakened := watch(Events.boss_awakened)
	await physics_frames(30)
	_bone(50.0)
	_crystal(50.0)
	await physics_frames(30)
	assert_eq(trex.brain.state, S.DORMANT)
	assert_eq(trex.health.current, 1200.0, "a sleeping exhibit takes no damage")
	assert_false(trex.skeleton.crystal_present, "no crystal yet")
	trex.wake()
	assert_eq(trex.brain.state, S.WAKING)
	assert_true(trex.skeleton.crystal_present)
	assert_eq(awakened.size(), 1)
	if awakened.size() == 1:
		assert_eq(awakened[0][0], trex)


func _hurtbox_transforms() -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	for hurtbox in trex.skeleton.hurtboxes:
		found.append(hurtbox.global_transform)
	return found


func _moved_since(before: Array[Transform3D]) -> int:
	var now := _hurtbox_transforms()
	var moved := 0
	for i in now.size():
		if not now[i].is_equal_approx(before[i]):
			moved += 1
	return moved


## Asleep it holds its museum pose without re-posing 91 bones and 45 hit
## zones every frame; awake it moves again.
func test_a_sleeping_boss_holds_still_until_woken() -> void:
	target.position = Vector3(0, 0, -30)
	await physics_frames(30)   # settled on the floor
	var asleep := _hurtbox_transforms()
	await physics_frames(20)
	assert_eq(_moved_since(asleep), 0, "not a bone moves")
	trex.wake()
	await physics_frames(20)
	assert_gt(_moved_since(asleep), 10, "the wake roar moves them")


func test_bones_take_a_tenth_the_crystal_all_of_it() -> void:
	_hunting()
	var bone := _bone(20.0)
	assert_almost_eq(trex.health.current, 1198.0, 0.001)
	assert_true(bone.blocked, "grey hit marker")
	var gem := _crystal(20.0)
	assert_almost_eq(trex.health.current, 1178.0, 0.001)
	assert_true(gem.weak_point, "gold hit marker")
	assert_false(gem.blocked)


func test_bullets_find_the_crystal_through_the_open_chest_and_between_ribs() -> void:
	trex.wake()
	await physics_frames(3)
	var space := trex.get_world_3d().direct_space_state
	var gem := trex.skeleton.crystal_position()
	var front := Hitscan.ray(space, gem + Vector3(0, 0, -10), gem + Vector3(0, 0, 10))
	assert_true(front.get("hurtbox") != null and (front["hurtbox"] as Hurtbox).receiver is TRexZone)
	if front.get("hurtbox") != null:
		assert_eq(((front["hurtbox"] as Hurtbox).receiver as TRexZone).zone, TRexBrain.Zone.CRYSTAL, "open chest from the front")
	var crystal_hits := 0
	var rib_hits := 0
	for i in 15:
		var z := gem.z - 0.35 + i * 0.05
		var side := Hitscan.ray(space, Vector3(10, gem.y, z), Vector3(-10, gem.y, z))
		var hurtbox: Hurtbox = side.get("hurtbox")
		if hurtbox == null:
			continue
		if (hurtbox.receiver as TRexZone).zone == TRexBrain.Zone.CRYSTAL:
			crystal_hits += 1
		else:
			rib_hits += 1
	assert_gt(crystal_hits, 0, "gaps between the ribs")
	assert_gt(rib_hits, 0, "the ribs shield part of it")


func test_a_killing_blow_on_the_bones_shows_the_kill_marker() -> void:
	_hunting()
	_crystal(1195.0)
	var markers := watch(Events.hit_landed)
	var last := _bone(60.0)
	assert_true(trex.is_dead())
	assert_eq(markers.size(), 1)
	if markers.size() == 1:
		assert_true(markers[0][2], "killed")
	assert_false(last.blocked, "no grey marker over the kill")


## A shotgun blast on ribs and crystal arrives as two hits (one per zone):
## whichever comes last, the guard sees the gold marker.
func test_one_blast_on_ribs_and_crystal_shows_the_gold_marker() -> void:
	_hunting()
	var markers := watch(Events.hit_landed)
	_crystal(10.0)
	_bone(30.0)
	assert_true((markers.back()[1] as DamageInfo).weak_point, "crystal first")
	await get_tree().process_frame
	_bone(30.0)
	_crystal(10.0)
	assert_true((markers.back()[1] as DamageInfo).weak_point, "crystal last")
	await get_tree().process_frame
	_bone(30.0)
	assert_true((markers.back()[1] as DamageInfo).blocked, "bones alone: grey")


func test_phases_change_at_66_and_33_percent() -> void:
	_hunting()
	var phases := watch(trex.phase_changed)
	_crystal(400.0)
	assert_eq(trex.phase, 1, "800 of 1200 is still phase 1")
	_crystal(10.0)
	assert_eq(trex.phase, 2)
	_crystal(395.0)
	assert_eq(trex.phase, 3)
	assert_eq(phases.size(), 2)


func test_a_charge_into_a_wall_stuns_it_and_exposes_the_crystal() -> void:
	Greybox.box(self, Vector3(0, 4, -18), Vector3(20, 8, 1), Color.GRAY)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	assert_true(await _wait_for(S.CHARGE, 120), "charges after its windup")
	assert_true(await _wait_for(S.STUNNED, 90), "slams into the wall")
	assert_eq(target.hits.size(), 1, "runs the guard over once")
	if target.hits.size() > 0:
		assert_eq(target.hits[0].amount, TRex.CHARGE_DAMAGE)
		assert_gt(target.hits[0].knockback, 10.0)
	_crystal(20.0)
	assert_almost_eq(trex.health.current, 1170.0, 0.001, "x1.5 while stunned")
	await physics_frames(40)
	assert_gt(trex.skeleton.crystal_position().y, 0.9)
	assert_lt(trex.skeleton.crystal_position().y, 2.2, "sags within reach")
	await physics_frames(int(TRexBrain.STUN_TIME * 60.0))
	assert_ne(trex.brain.state, S.STUNNED, "gets up again")


func test_a_charge_that_misses_every_wall_ends_in_a_skid() -> void:
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var states: Array = []
	trex.state_changed.connect(func(_from: int, to: int) -> void: states.append(to))
	await physics_frames(240)
	assert_true(states.has(S.CHARGE))
	assert_true(states.has(S.SKID))
	assert_false(states.has(S.STUNNED))


func test_tail_swipes_a_guard_behind_it() -> void:
	target.position = Vector3(1.0, 0, 4.5)
	_hunting()
	assert_true(await _wait_for(S.TAIL_WINDUP, 10))
	assert_eq(target.hits.size(), 0, "telegraph first")
	await physics_frames(60)
	assert_eq(target.hits.size(), 1)
	if target.hits.size() == 1:
		assert_eq(target.hits[0].amount, TRex.TAIL_DAMAGE)
		assert_eq(target.hits[0].knockback, TRex.TAIL_KNOCKBACK)


func test_no_tail_for_a_guard_in_front_or_at_its_side() -> void:
	target.position = Vector3(0, 0, -5)
	_hunting()
	var states: Array = []
	trex.state_changed.connect(func(_from: int, to: int) -> void: states.append(to))
	await physics_frames(60)
	target.position = Vector3(5, 0, -1)
	trex.rotation.y = 0.0
	await physics_frames(20)
	assert_false(states.has(S.TAIL_WINDUP))
	assert_eq(target.hits.size(), 0)


## The guard moves [param speed] m/s along [param direction] from
## [param reaction] s after the tail windup starts, for [param duration] s
## (a real walk, no teleport). Returns the hits he took.
func _dodge_tail(start: Vector3, direction: Vector3, speed: float, reaction: float, duration: float = 5.0) -> int:
	target.position = start
	_hunting()
	if not await _wait_for(S.TAIL_WINDUP, 10):
		fail("no tail windup")
		return -1
	var step := direction.normalized() * speed / 60.0
	for i in 90:
		var t := (i + 1) / 60.0
		if t > reaction and t <= reaction + duration:
			target.position += step
		await get_tree().physics_frame
	return target.hits.size()


## The intended answers to the tail: the 0.75 s telegraph is enough to walk
## out of the tail's band (away, in under its base, or aside) after a normal
## reaction; after a late one a sprint or a dash still makes it, while
## walking the way the whip sweeps does not.
func test_walking_away_during_the_tail_windup_dodges_it() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.5), Vector3(0, 0, 1), 5.5, 0.3), 0)


func test_walking_in_under_the_tail_base_dodges_it() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.5), Vector3(0, 0, -1), 5.5, 0.3), 0)


func test_walking_aside_after_a_normal_reaction_dodges_it() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.0), Vector3(1, 0, 0), 5.5, 0.3), 0)


func test_walking_aside_too_late_gets_whipped() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.0), Vector3(1, 0, 0), 5.5, 0.5), 1)


func test_sprinting_aside_after_a_late_reaction_dodges_it() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.0), Vector3(1, 0, 0), 8.5, 0.5), 0)


func test_a_late_dash_aside_dodges_it() -> void:
	assert_eq(await _dodge_tail(Vector3(0.3, 0, 4.0), Vector3(1, 0, 0), 15.0, 0.6, 0.16), 0)


func test_roar_calls_four_exhibits_but_never_more_than_six_alive() -> void:
	_hunting()
	var calls: Array[int] = []
	var made: Array[Node] = []
	trex.summon = func(count: int) -> Array:
		calls.append(count)
		var spawned: Array = []
		for i in count:
			var node := Node3D.new()
			add_child(node)
			spawned.append(node)
			made.append(node)
		return spawned
	for attempt in 3:
		trex.brain.roar(true, false)
		await physics_frames(45)
		trex.brain.force(S.STALK)
	assert_eq(calls, [4, 2] as Array[int])
	assert_eq(trex.alive_summoned(), 6)
	for i in 3:
		made[i].free()
	trex.brain.roar(true, false)
	await physics_frames(45)
	assert_eq(calls.size(), 3)
	if calls.size() == 3:
		assert_eq(calls[2], 3)


func test_a_summon_batch_with_freed_nodes_counts_only_the_living() -> void:
	_hunting()
	var keeper: Array[Node] = []
	trex.summon = func(_count: int) -> Array:
		var gone := Node3D.new()
		add_child(gone)
		var leaving := Node3D.new()
		add_child(leaving)
		var staying := Node3D.new()
		add_child(staying)
		keeper.append(staying)
		var batch: Array = [gone, leaving, staying, null, "not a node"]
		gone.free()
		leaving.queue_free()
		return batch
	trex.brain.roar(true, false)
	await physics_frames(45)
	assert_eq(trex.summoned.size(), 1)
	assert_eq(trex.alive_summoned(), 1)
	if trex.summoned.size() == 1:
		assert_eq(trex.summoned[0], keeper[0])


func test_phase_two_roar_summons_on_its_own() -> void:
	_hunting()
	var calls: Array[int] = []
	trex.summon = func(count: int) -> Array:
		calls.append(count)
		return []
	_crystal(420.0)
	await physics_frames(60)
	assert_eq(calls, [4] as Array[int])


func test_phase_three_roar_marks_three_spots_for_falling_debris() -> void:
	_hunting()
	_crystal(820.0)
	await physics_frames(45)
	var drops := 0
	for child in get_children():
		if child is DebrisDrop:
			drops += 1
	assert_eq(drops, 3)


func test_debris_still_falling_when_it_dies_hurts_no_one() -> void:
	_hunting()
	trex.brain.roar(false, true)
	await physics_frames(32)   # past the peak: three rocks in the air
	var drops := 0
	for child in get_children():
		if child is DebrisDrop:
			drops += 1
	assert_eq(drops, 3)
	_crystal(5000.0)
	assert_true(trex.is_dead())
	await physics_frames(75)
	assert_eq(target.hits.size(), 0)


func test_taser_on_the_crystal_staggers_it_with_a_cooldown() -> void:
	_hunting()
	var zap := _crystal(4.0, DamageInfo.Kind.ELECTRIC)
	assert_eq(trex.brain.state, S.STAGGER)
	assert_true(zap.weak_point)
	await physics_frames(70)
	assert_eq(trex.brain.state, S.STALK)
	_crystal(4.0, DamageInfo.Kind.ELECTRIC)
	assert_ne(trex.brain.state, S.STAGGER, "8 s cooldown")
	assert_almost_eq(trex.health.current, 1192.0, 0.001, "the zap still hurts")


func test_taser_on_bones_does_not_stagger() -> void:
	_hunting()
	var info := _hit(4.0, DamageInfo.Kind.ELECTRIC)
	trex.take_zone_damage(info, TRexBrain.Zone.BONE)
	assert_eq(trex.brain.state, S.STALK)


func test_death_bursts_the_crystal_and_leaves_a_pile_of_bones() -> void:
	_hunting()
	var defeated := watch(trex.defeated)
	var global := watch(Events.boss_defeated)
	var kills := watch(Events.hit_landed)
	_crystal(1190.0)
	_crystal(20.0)
	assert_eq(defeated.size(), 1)
	assert_eq(global.size(), 1)
	assert_true(trex.is_dead())
	assert_false(trex.skeleton.crystal_present)
	var killing := kills.filter(func(entry: Array) -> bool: return entry[2] == true)
	assert_eq(killing.size(), 1)
	_crystal(20.0)
	assert_eq(defeated.size(), 1, "only once")
	var parent := trex.get_parent()
	await get_tree().create_timer(TRex.DEATH_COLLAPSE_DELAY + 0.4).timeout
	var remains := parent.get_node_or_null(^"TRexRemains")
	assert_not_null(remains)
	if remains != null:
		assert_gt(_count_rigid(remains), 60)
	assert_false(is_instance_valid(trex) and not trex.is_queued_for_deletion(), "the boss node is gone")


func test_shots_pass_through_the_dying_skeleton() -> void:
	_hunting()
	await physics_frames(5)
	var space := trex.get_world_3d().direct_space_state
	# through the hips and thighs (the model's ribs leave gaps a shot may miss)
	var from := trex.global_position + Vector3(8, 3.9, 0.0)
	var before := Hitscan.ray(space, from, from + Vector3(-16, 0, 0))
	assert_not_null(before.get("hurtbox"), "the living skeleton takes the shot")
	_crystal(5000.0)
	await physics_frames(10)
	var after := Hitscan.ray(space, from, from + Vector3(-16, 0, 0))
	assert_eq(after.get("hurtbox"), null, "no silent absorption while it trembles")


func test_leaves_a_guard_in_a_haven_alone() -> void:
	var haven := Haven.make(&"booth", AABB(Vector3(-3, 0, -15), Vector3(6, 3, 6)))
	add_child(haven)
	target.position = Vector3(0, 0, -12)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var states: Array = []
	trex.state_changed.connect(func(_from: int, to: int) -> void: states.append(to))
	var start := trex.global_position
	await physics_frames(180)
	assert_false(states.has(S.CHARGE_WINDUP), "no charge at a sheltered guard")
	assert_lt(trex.global_position.distance_to(start), 0.5, "no stalking either")
	assert_eq(target.hits.size(), 0)
	target.position = Vector3(0, 0, -7)   # he steps out
	assert_true(await _wait_for(S.CHARGE_WINDUP, 30), "hunts him again")


func test_a_charge_stops_at_the_haven_walls() -> void:
	var haven := Haven.make(&"booth", AABB(Vector3(-4, 0, -20), Vector3(8, 3, 8)))
	add_child(haven)
	target.position = Vector3(0, 0, -7)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var entered := false
	for i in 240:
		await get_tree().physics_frame
		entered = entered or haven.contains(trex.global_position)
	assert_true(trex.collision_mask & Layers.ENEMY_BLOCK != 0)
	assert_eq(target.hits.size(), 1, "the charge ran him over")
	assert_false(entered, "and stopped at the booth's exhibit-only walls")


func test_walks_around_a_column_to_reach_the_guard() -> void:
	Greybox.box(self, Vector3(0, 7, -9), Vector3(2, 14, 2), Color.GRAY)
	target.position = Vector3(0, 0, -24)
	_hunting()
	var closest := INF
	for i in 600:
		await get_tree().physics_frame
		closest = minf(closest, trex.global_position.distance_to(target.global_position))
		if closest < 6.0:
			break
	assert_lt(closest, 6.0)


func test_does_not_stay_stuck_against_a_wall_between_it_and_the_guard() -> void:
	Greybox.box(self, Vector3(0, 4, -7), Vector3(9, 8, 1), Color.GRAY)
	target.position = Vector3(0, 0, -16)
	_hunting()
	var closest := INF
	for i in 900:
		await get_tree().physics_frame
		closest = minf(closest, trex.global_position.distance_to(target.global_position))
		if closest < 7.0:
			break
	assert_lt(closest, 7.0)


func _facing_target() -> float:
	var to := target.global_position - trex.global_position
	var facing := -trex.global_basis.z
	return Vector2(facing.x, facing.z).normalized().dot(Vector2(to.x, to.z).normalized())


## Only what stands between the boss and the guard counts as in the way: a
## wall at the guard's back must not turn it aside. It walks up until its
## snout nearly touches that wall, stands facing him, and charges.
func test_engages_a_guard_with_his_back_to_a_wall() -> void:
	Greybox.box(self, Vector3(0, 4, -13.5), Vector3(20, 8, 1), Color.GRAY)
	target.position = Vector3(0, 0, -12.4)
	_hunting()
	await physics_frames(240)
	var closest := INF
	var worst_facing := INF
	for i in 120:
		await get_tree().physics_frame
		closest = minf(closest, trex.global_position.distance_to(target.global_position))
		worst_facing = minf(worst_facing, _facing_target())
	assert_lt(closest, TRex.SNOUT_REACH + 0.3, "comes up as close as its skull allows")
	assert_gt(worst_facing, 0.95, "and keeps facing him instead of turning away")
	trex.brain.charge_cooldown = 0.0
	assert_true(await _wait_for(S.STUNNED, 180), "charges him into the wall")
	assert_eq(target.hits.size(), 1)


## The boss inside a moved and turned container (like the rooms of 2b),
## [param at] in world space. The old boss of before_each() is removed.
func _boss_in_a_turned_room(at: Vector3) -> Node3D:
	trex.free()
	var room := Node3D.new()
	room.position = Vector3(6, 0, -4)
	room.rotation.y = 1.1
	add_child(room)
	trex = TRex.new()
	trex.position = room.to_local(at)
	trex.target = target
	room.add_child(trex)
	return room


func test_turns_to_the_guard_under_a_turned_parent() -> void:
	_boss_in_a_turned_room(Vector3(0, 0.05, 0))
	target.position = Vector3(-9, 0, -8)
	_hunting()
	await physics_frames(240)
	assert_gt(_facing_target(), 0.95)


func test_bones_collapse_where_it_stood_under_a_turned_parent() -> void:
	var room := _boss_in_a_turned_room(Vector3(2, 0.05, 3))
	target.position = Vector3(2, 0, -25)
	_hunting()
	await physics_frames(5)
	var stood := trex.global_position
	var collapsed := watch(trex.collapsed)
	_crystal(5000.0)
	for i in 90:
		if not collapsed.is_empty():
			break
		await get_tree().physics_frame
	var remains := room.get_node_or_null(^"TRexRemains") as Node3D
	assert_not_null(remains)
	assert_eq(collapsed.size(), 1)
	if collapsed.size() == 1:
		assert_eq(collapsed[0][0], remains)
	if remains == null:
		return
	var sum := Vector3.ZERO
	var count := 0
	for body in remains.get_children():
		sum += (body as Node3D).global_position
		count += 1
	var middle := sum / maxi(count, 1)
	assert_lt(Vector2(middle.x - stood.x, middle.z - stood.z).length(), 2.5, "the pile lies where it stood")
	assert_gt(middle.y, 0.5, "and not under the floor")


func test_debris_falls_around_the_guard_under_a_turned_parent() -> void:
	_boss_in_a_turned_room(Vector3(0, 0.05, 0))
	target.position = Vector3(-3, 0, -12)
	_hunting()
	await physics_frames(2)
	trex.brain.roar(false, true)
	await physics_frames(32)
	var closest := INF
	var drops := 0
	for drop in find_children("*", "DebrisDrop", true, false):
		drops += 1
		var at := (drop as Node3D).global_position
		closest = minf(closest, Vector2(at.x - target.position.x, at.z - target.position.z).length())
	assert_eq(drops, 3)
	assert_lt(closest, 0.2, "one right under the guard")


func test_stands_on_the_floor_about_five_metres_tall() -> void:
	await physics_frames(30)
	assert_true(trex.is_on_floor())
	var top := -INF
	var front := INF
	var back := -INF
	for piece in trex.skeleton.pieces:
		var box: AABB = piece.global_transform * (piece.get_meta(&"aabb") as AABB)
		top = maxf(top, box.end.y)
		front = minf(front, box.position.z)
		back = maxf(back, box.end.z)
	assert_almost_eq(top, 5.0, 0.4, "height")
	assert_almost_eq(back - front, 11.2, 0.8, "snout to tail tip")


func test_debris_never_lands_on_the_far_side_of_a_wall() -> void:
	Greybox.box(self, Vector3(2, 4, -12), Vector3(0.4, 8, 20), Color.GRAY)
	target.position = Vector3(1, 0, -12)
	_hunting()
	await physics_frames(2)
	var seen: Dictionary = {}
	for attempt in 4:
		trex.brain.roar(false, true)
		await physics_frames(32)
		trex.brain.force(S.STALK)
		for child in get_children():
			if child is DebrisDrop and not seen.has(child):
				seen[child] = true
				assert_lt((child as DebrisDrop).global_position.x, 1.8, "stays in the guard's room")
	assert_eq(seen.size(), 12)


## World spots of the debris of [param rounds] phase-3 roars, one Array per
## roar.
func _debris_batches(rounds: int) -> Array:
	var batches: Array = []
	var seen: Dictionary = {}
	for attempt in rounds:
		trex.brain.roar(false, true)
		await physics_frames(32)
		trex.brain.force(S.STALK)
		var batch: Array[Vector3] = []
		for child in get_children():
			if child is DebrisDrop and not seen.has(child):
				seen[child] = true
				batch.append((child as DebrisDrop).global_position)
		batches.append(batch)
	return batches


func _assert_spread(batches: Array, apart: float) -> void:
	for batch: Array[Vector3] in batches:
		assert_eq(batch.size(), 3)
		for a in batch.size():
			for b in range(a + 1, batch.size()):
				var gap := Vector2(batch[a].x - batch[b].x, batch[a].z - batch[b].z).length()
				assert_gt(gap, apart, "the shadows do not pile up")


func test_debris_by_a_wall_spreads_along_it_instead_of_piling_on_the_guard() -> void:
	Greybox.box(self, Vector3(2, 4, -12), Vector3(0.4, 8, 30), Color.GRAY)   # face at x = 1.8
	target.position = Vector3(1.2, 0, -12)
	_hunting()
	await physics_frames(2)
	var batches := await _debris_batches(8)
	_assert_spread(batches, 2.5)
	for batch: Array[Vector3] in batches:
		for spot in batch:
			assert_lt(spot.x, 1.8, "on the guard's side")


func test_debris_in_a_corner_still_spreads_out() -> void:
	Greybox.box(self, Vector3(2, 4, -12), Vector3(0.4, 8, 30), Color.GRAY)   # face at x = 1.8
	Greybox.box(self, Vector3(-8, 4, -14), Vector3(20, 8, 0.4), Color.GRAY)   # face at z = -13.8
	target.position = Vector3(1.2, 0, -13.2)
	_hunting()
	await physics_frames(2)
	var batches := await _debris_batches(8)
	_assert_spread(batches, 2.0)
	for batch: Array[Vector3] in batches:
		for spot in batch:
			assert_true(spot.x < 1.8 and spot.z > -13.8, "in the guard's corner of the room")


func test_a_charge_does_not_climb_a_stair_ramp() -> void:
	Greybox.ramp(self, Vector3(0, 0, -9), Vector3(0, 6, -21), 6.0, Color.GRAY)
	target.position = Vector3(0, 0, -8)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var highest := -INF
	for i in 240:
		await get_tree().physics_frame
		highest = maxf(highest, trex.global_position.y)
	assert_lt(highest, 1.0, "stays on the hall floor")


func test_walking_aside_once_the_aim_locks_escapes_even_a_close_charge() -> void:
	target.position = Vector3(0, 0, -4)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var walked := false
	for i in 150:
		await get_tree().physics_frame
		if trex.brain.state == S.CHARGE_WINDUP and not trex.brain.is_tracking() or walked:
			walked = true
			target.position.x += 5.5 / 60.0   # the guard's walking speed
	assert_true(walked)
	assert_eq(target.hits.size(), 0)


func test_a_charge_runs_away_from_a_guard_hugging_its_hip() -> void:
	target.position = Vector3(0, 0, -10)
	trex.wake()
	trex.brain.force(S.STALK)
	trex.brain.charge_cooldown = 0.0
	var dodged := false
	for i in 200:
		await get_tree().physics_frame
		if not dodged and trex.brain.state == S.CHARGE_WINDUP and not trex.brain.is_tracking():
			dodged = true
			# he dashed past its flank and now stands half a metre behind the hips
			target.global_position = trex.to_global(Vector3(1.45, 0.0, 0.5))
		if trex.brain.state == S.CHARGE and trex.brain.state_time() > 0.3:
			break
	assert_true(dodged)
	assert_eq(target.hits.size(), 0)


func test_the_tail_whips_over_a_guard_tucked_under_its_base() -> void:
	target.position = Vector3(0.3, 0, 1.2)
	_hunting()
	assert_true(await _wait_for(S.TAIL_WINDUP, 10), "still reacts to him")
	await physics_frames(60)
	assert_eq(target.hits.size(), 0)


func test_the_swipe_brings_the_tail_down_to_the_guard() -> void:
	target.position = Vector3(1.0, 0, 4.5)
	_hunting()
	assert_true(await _wait_for(S.TAIL_SWIPE, 60))
	await physics_frames(15)
	var lowest := INF
	for bone in trex.skeleton.tail.slice(6):
		lowest = minf(lowest, bone.global_position.y)
	assert_lt(lowest, 1.6, "the outer tail sweeps at head height or lower")
	for point in trex.skeleton.tail_points():
		assert_gt(point.y, 0.05, "but never through the floor")
