extends TestCase
## The Two-headed Serpent in the real Temple of the Serpent on Floor I: it
## sleeps coiled on its ring round the altar's terrace with both heads
## over the north flight, wakes when the guard steps in, lies still while
## it wakes and then glides off its tracks within the arena; every attack
## is announced at least 0.6 s ahead and lands where it was shown (the
## spit's shards on their marks, the lunge in its lane, the sweep in its
## arc - and over a jumping guard it misses); the heads are the weak
## points and a segment's plate comes off under fire, baring a segment
## that takes full hits; phase 3 closes the ring round the altar's terrace
## with its gate over the north flight and arches travelling round it; the
## guard fleeing calms it back onto its ring; its fall leaves the shard on
## the summit, for good.

const A := SerpentBrain.Attack
const S := SerpentBrain.State
const END := SerpentBody.End
const ROOM := &"americas_temple"
const T1 := Rect2(-20, -79, 11.5, 13.5)
const T2 := Rect2(-18, -75, 7.5, 5.5)
const N2 := Rect2(-15.75, -79, 3.0, 4.0)
const START := Vector3(-22.5, 0.0, -79.0)

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


## The Serpent, its dice seeded (which attack it picks next): the same
## fight every run.
func _serpent() -> Serpent:
	var serpent := museum.floor_game.guardians.guardians.get(&"serpent") as Serpent
	if serpent != null:
		serpent.brain.seed_with(7)
	return serpent


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## The guard (tough enough for any test) at [param at] (feet).
func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	if guard.health.max_health < 10000.0:
		guard.health.max_health = 100000.0
		guard.health.reset()
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


## Wakes it with the guard at the arena's start line and waits out the waking.
func _awake(serpent: Serpent) -> void:
	_put_guard(START)
	await _seconds(0.3)
	assert_true(serpent.is_fighting(), "awake")
	await _seconds(SerpentBrain.WAKE_TIME + 0.1)


## Waits until it roams (an attack under way runs out), the guard kept at
## [param at].
func _roaming(serpent: Serpent, at: Vector3) -> void:
	for i in 60 * 8:
		if serpent.brain.state == S.ROAM:
			return
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame


func _hit_zone(serpent: Serpent, zone: StringName, amount: float, at: Vector3) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"pistol"
	info.position = at
	serpent.take_zone_damage(info, zone)


## A floor point [param ahead] m out from head [param end]'s neck root
## along its line, [param aside] m to its right (flat, on the ground).
func _out_from(serpent: Serpent, end: END, ahead: float, aside: float = 0.0) -> Vector3:
	var frame := serpent.body.root_frame(end)
	var at := frame * Vector3(aside, 0.0, -ahead)
	return Vector3(at.x, serpent._ground_at(at), at.z)


func _inside_by(at: Vector3, rect: Rect2) -> float:
	var p := Vector2(at.x, at.z)
	return minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y))


## A floor spot beside the trailing tail for its sweep to come round over:
## 1.8 m to the side of it, on the tail's own ground, with the rest of the
## body clear of it (the body may lie coiled on the other side); INF when
## neither side is clear - let it glide on and ask again.
func _by_tail(serpent: Serpent) -> Vector3:
	var base_j := serpent._tail_base()
	var tip_j := serpent.body.trailer_joint()
	var base := serpent.body.joints[base_j]
	var tip := serpent.body.joints[tip_j]
	var along := Vector3(tip.x - base.x, 0.0, tip.z - base.z).normalized()
	var across := along.cross(Vector3.UP)
	var floor_y := serpent._ground_at(base)
	for side: float in [1.0, -1.0]:
		var at := base + along * 3.5 + across * side * 1.8
		var clear := INF
		for j in serpent.body.joints.size():
			# (the tail itself and its head do not count)
			if (tip_j > base_j and j >= base_j - 1) or (tip_j < base_j and j <= base_j + 1):
				continue
			clear = minf(clear, Vector2(at.x - serpent.body.joints[j].x, at.z - serpent.body.joints[j].z).length())
		at.y = serpent._ground_at(at)
		if clear > 1.6 and absf(at.y - floor_y) < 0.3 and museum.floor_level.room_at(at + Vector3.UP * 0.5) == ROOM:
			return at
	return Vector3.INF


## Lets it roam (the guard at [param at]) until a clear spot beside its
## tail turns up, and puts the guard there.
func _guard_by_tail(serpent: Serpent, at: Vector3) -> Vector3:
	var spot := Vector3.INF
	for i in 60 * 12:
		await _roaming(serpent, at)
		spot = _by_tail(serpent)
		if spot.is_finite():
			break
		_put_guard(at)
		await get_tree().physics_frame
	assert_true(spot.is_finite(), "a clear spot beside the tail")
	if not spot.is_finite():
		spot = at
	_put_guard(spot)
	await _seconds(0.1)
	return spot


## Where the drawn arc says the tail comes round: in it, a third of the way.
func _in_arc(serpent: Serpent) -> Vector3:
	var at := serpent._sweep_base + serpent._sweep_axis * 3.5 + Vector3.UP.cross(serpent._sweep_axis) * serpent._sweep_side * 1.8
	at.y = serpent._ground_at(at)
	return at


func test_it_sleeps_coiled_on_its_ring_and_wakes_when_the_guard_steps_in() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	assert_not_null(serpent, "the real Serpent stands in for the stub")
	if serpent == null:
		return
	assert_eq(serpent.state, Guardian.State.DORMANT)
	assert_eq(serpent.arena_room, ROOM)
	assert_true(serpent.kinematic)
	var ground := serpent.body.ground_joints()
	for j in range(ground.x, ground.y + 1):
		var joint := serpent.body.joints[j]
		assert_gt(_inside_by(joint, T1), 0.2, "joint %d lies on the lower terrace (%s)" % [j, joint])
		assert_lt(_inside_by(joint, T2), -0.4, "joint %d keeps off the altar's terrace (%s)" % [j, joint])
		assert_gt(joint.y, 1.5 + 0.3, "joint %d rides on the terrace (%.2f)" % [j, joint.y])
		assert_lt(joint.y, 3.7, "joint %d not in the air (%.2f)" % [j, joint.y])
	for end in 2:
		var head := serpent.body.head_point(end as END)
		assert_true(N2.has_point(Vector2(head.x, head.z)), "head %d lies over the north flight (%s)" % [end, head])
		assert_gt(head.y, 2.2, "head %d on the upper steps (%.2f)" % [end, head.y])
	assert_eq(serpent.rig.plates_left(), SerpentBody.SEGMENTS, "whole")
	# the guard steps in: it wakes, lies still while it does, then glides
	var rest := serpent.body.leader()
	_put_guard(START)
	await _seconds(0.3)
	assert_true(serpent.is_fighting())
	assert_eq(serpent.brain.state, S.WAKING)
	await _seconds(1.0)
	assert_lt(serpent.body.leader().distance_to(rest), 0.1, "still while it wakes")
	await _seconds(SerpentBrain.WAKE_TIME)
	assert_true(serpent.brain.state == S.ROAM or serpent.brain.state == S.ATTACK, "awake and about")
	for i in 60 * 3:
		_put_guard(START)
		await get_tree().physics_frame
	var leader := serpent.body.leader()
	assert_gt(leader.distance_to(rest), 2.5, "off its ring toward the guard (%.2f m)" % leader.distance_to(rest))
	assert_eq(museum.floor_level.room_at(leader + Vector3.UP * 0.5), ROOM, "in its arena")
	for j in range(ground.x, ground.y + 1):
		var joint := serpent.body.joints[j]
		assert_eq(museum.floor_level.room_at(joint + Vector3.UP * 0.5), ROOM, "joint %d in the arena" % j)
		var floor_y := serpent._ground_at(joint)
		# (where it bridges off the south flight's side - 1.24 m of ramp over
		# the terrace, and its own radius - the belly hangs for a metre)
		assert_gt(joint.y - floor_y, -0.15, "joint %d rides over the ground (%.2f)" % [j, joint.y - floor_y])
		assert_lt(joint.y - floor_y, 1.85, "joint %d not far over it (%.2f)" % [j, joint.y - floor_y])
	# a low body: its solid boxes top out where the guard's jump clears them
	# (measured over the belly under the box's middle: a segment on a slope
	# rises along its length)
	for k in range(ground.x, ground.y):
		var top := (serpent._colliders[k].global_transform * Vector3(0.0, Serpent.COLLIDER_HEIGHT * 0.5, 0.0)).y
		var belly := (serpent.body.joints[k].y + serpent.body.joints[k + 1].y) * 0.5 - serpent.body.radii[k]
		assert_lt(top - belly, 0.8, "segment %d's box is jumpable (%.2f over the belly)" % [k, top - belly])


func test_every_attack_is_announced_and_lands_where_it_was_shown() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	var guard := museum.player
	var told := watch(serpent.telegraphed)
	var struck := watch(serpent.struck)
	# the spit: marks round the guard, the shards onto them
	await _roaming(serpent, START)
	var spot := _out_from(serpent, serpent.brain.spitter, 10.0)
	if museum.floor_level.room_at(spot + Vector3.UP * 0.5) != ROOM:
		spot = START
	_put_guard(spot)
	serpent.brain.force_attack(A.SPIT)
	assert_eq(told.size(), 1)
	assert_eq(told[0][0], &"spit")
	assert_eq(serpent._spit_marks.size(), SerpentBrain.SHARDS[0], "a mark per shard")
	var marks: Array[Vector3] = []
	var warned := 0.0
	while struck.is_empty() and warned < 2.0:
		_put_guard(spot)
		for mark: GroundMark in serpent._spit_marks:
			if is_instance_valid(mark):
				marks.append(mark.global_position)
		await get_tree().physics_frame
		warned += 1.0 / Engine.physics_ticks_per_second
	assert_true(warned >= Guardian.MIN_TELEGRAPH - 0.02, "announced %.2f s ahead" % warned)
	assert_eq(struck.size(), 1)
	assert_eq(serpent.shards.size(), SerpentBrain.SHARDS[0], "the shards left")
	for shard: SerpentShard in serpent.shards:
		if not is_instance_valid(shard):
			continue
		var nearest := INF
		for at in marks:
			nearest = minf(nearest, Vector2(at.x - shard.landing.x, at.z - shard.landing.z).length())
		assert_lt(nearest, 0.6, "a shard aimed at a mark (%.2f m off)" % nearest)
		assert_lt(Vector2(shard.landing.x - spot.x, shard.landing.z - spot.z).length(), 4.0, "round the guard")
	# the lunge: the lane, the bite in it, nothing beside it
	await _roaming(serpent, spot)
	var biter := serpent.brain.biter()
	var before_hp := guard.health.current
	var in_lane := _out_from(serpent, biter, 3.6)
	_put_guard(in_lane)
	await _seconds(0.1)
	serpent.brain.force_attack(A.LUNGE)
	assert_eq(told[told.size() - 1][0], &"lunge")
	assert_not_null(serpent._lane, "a lane on the floor")
	var landed := struck.size()
	for i in 60 * 3:
		if struck.size() > landed:
			break
		_put_guard(in_lane)
		await get_tree().physics_frame
	assert_eq(struck.size(), landed + 1, "the lunge struck")
	await _seconds(0.3)
	assert_lt(guard.health.current, before_hp - 1.0, "bitten in the lane (%.0f)" % (before_hp - guard.health.current))
	assert_almost_eq(before_hp - guard.health.current, SerpentBrain.LUNGE_DAMAGE * serpent.damage_scale, 0.5)
	await _roaming(serpent, spot)
	before_hp = guard.health.current
	var beside := _out_from(serpent, serpent.brain.biter(), 3.0, 3.5)
	_put_guard(beside)
	await _seconds(0.1)
	serpent.brain.force_attack(A.LUNGE)
	for i in 60 * 3:
		if serpent.brain.state != S.ATTACK:
			break
		_put_guard(beside)
		await get_tree().physics_frame
	assert_almost_eq(guard.health.current, before_hp, 0.5, "beside the lane: missed")
	# the sweep: the arc, the blow on the floor, a jump over it
	await _guard_by_tail(serpent, spot)
	before_hp = guard.health.current
	serpent.brain.force_attack(A.SWEEP)
	assert_eq(told[told.size() - 1][0], &"sweep")
	assert_not_null(serpent._arc, "an arc on the floor")
	var by_tail := _in_arc(serpent)
	var hit_at := -1.0
	for i in 60 * 3:
		if serpent.brain.state != S.ATTACK:
			break
		if hit_at < 0.0 and guard.health.current < before_hp - 1.0:
			hit_at = serpent.brain.stage_time()
			assert_eq(serpent.brain.stage, SerpentBrain.Stage.STRIKE, "hit as the tail comes round, not as the warning ends")
			assert_gt(hit_at, 0.05, "the tail had to travel to him (%.2f s into the strike)" % hit_at)
		_put_guard(by_tail)
		await get_tree().physics_frame
	assert_almost_eq(before_hp - guard.health.current, SerpentBrain.SWEEP_DAMAGE * serpent.damage_scale, 0.5, "swept off his feet")
	await _guard_by_tail(serpent, spot)
	before_hp = guard.health.current
	serpent.brain.force_attack(A.SWEEP)
	by_tail = _in_arc(serpent)
	for i in 60 * 3:
		if serpent.brain.state != S.ATTACK:
			break
		# in the air over it from the end of the warning through the strike
		var airborne := serpent.brain.stage == SerpentBrain.Stage.STRIKE or (serpent.brain.stage == SerpentBrain.Stage.TELEGRAPH and serpent.brain.stage_time() > 0.4) or (serpent.brain.stage == SerpentBrain.Stage.RECOVER and serpent.brain.stage_time() < 0.5)
		_put_guard(by_tail + Vector3.UP * (0.75 if airborne else 0.0))
		await get_tree().physics_frame
	assert_almost_eq(guard.health.current, before_hp, 0.5, "jumped over it")


func test_the_heads_are_the_weak_points_and_the_plates_come_off_the_body() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	var lost := watch(serpent.plate_lost)
	var hp := serpent.health.current
	_hit_zone(serpent, &"head_a", 100.0, serpent.body.head_point(END.A))
	assert_almost_eq(hp - serpent.health.current, 100.0, 0.01, "a head takes the whole hit")
	hp = serpent.health.current
	_hit_zone(serpent, &"seg_20", 20.0, serpent.body.joints[20])
	assert_almost_eq(hp - serpent.health.current, 20.0 * SerpentBrain.PLATE_FACTOR, 0.01, "a plate takes a tenth")
	assert_true(serpent.rig.plate_on(20), "and holds under 30 raw damage")
	assert_eq(lost.size(), 0)
	hp = serpent.health.current
	_hit_zone(serpent, &"seg_20", 20.0, serpent.body.joints[20])
	assert_eq(lost.size(), 1, "the plate came off")
	assert_false(serpent.rig.plate_on(20))
	assert_eq(serpent.rig.plates_left(), SerpentBody.SEGMENTS - 1)
	hp = serpent.health.current
	_hit_zone(serpent, &"seg_20", 50.0, serpent.body.joints[20])
	assert_almost_eq(hp - serpent.health.current, 50.0 * SerpentBrain.BARE_FACTOR, 0.01, "the bared segment takes it all")
	# the biting head counts half again while it hangs out after a lunge
	await _roaming(serpent, START)
	var biter := serpent.brain.biter()
	_put_guard(_out_from(serpent, biter, 3.5))
	serpent.brain.force_attack(A.LUNGE)
	for i in 600:
		if serpent.brain.stage == SerpentBrain.Stage.RECOVER:
			break
		await get_tree().physics_frame
	assert_eq(serpent.brain.stage, SerpentBrain.Stage.RECOVER)
	hp = serpent.health.current
	_hit_zone(serpent, &"head_a" if biter == END.A else &"head_b", 100.0, serpent.body.head_point(biter))
	assert_almost_eq(hp - serpent.health.current, 100.0 * SerpentBrain.LUNGE_RECOVER_WEAK, 0.01, "x1.5 spent")
	# a hit from outside the arena does nothing and wakes nothing
	serpent.reset_fight()
	_put_guard(Vector3(-27.75, 0.0, -79.0))   # on the canoe deck over the pit
	await _seconds(0.2)
	assert_ne(museum.floor_level.room_at(museum.player.global_position + Vector3.UP * 0.5), ROOM)
	hp = serpent.health.current
	_hit_zone(serpent, &"head_a", 100.0, serpent.body.head_point(END.A))
	assert_almost_eq(serpent.health.current, hp, 0.01, "shrugged off")
	assert_eq(serpent.state, Guardian.State.DORMANT)


func test_phase_three_closes_the_ring_round_the_altars_terrace() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	await _awake(serpent)
	# let it come off the ring first
	for i in 60 * 5:
		_put_guard(START)
		await get_tree().physics_frame
	var floor_spot := Vector3(-22.0, 0.0, -72.0)
	var circled := watch(serpent.encircled)
	_hit_zone(serpent, &"head_a", serpent.health.current - serpent.max_health * 0.3 + 1.0, serpent.body.head_point(END.A))
	assert_eq(serpent.phase, 3)
	for i in 60 * 40:
		if circled.size() > 0:
			break
		_put_guard(floor_spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	assert_eq(circled.size(), 1, "it closed its ring")
	assert_eq(serpent.brain.state, S.RING)
	var ground := serpent.body.ground_joints()
	for j in range(ground.x, ground.y + 1):
		var joint := serpent.body.joints[j]
		assert_gt(_inside_by(joint, T1), 0.2, "joint %d on the lower terrace (%s)" % [j, joint])
		assert_lt(_inside_by(joint, T2), -0.4, "joint %d round the altar's terrace (%s)" % [j, joint])
	var posts := serpent.course.gate_posts()
	for end in 2:
		# the necks rise at the gate's posts
		var root := serpent.body.joints[serpent._neck_root(end as END)]
		var to_post := minf(Vector2(root.x - posts[0].x, root.z - posts[0].z).length(), Vector2(root.x - posts[1].x, root.z - posts[1].z).length())
		assert_lt(to_post, 1.5, "neck %d rises at a gate post (%s)" % [end, root])
	# the heads rise over the gate on their springs (a beat before the first
	# attack: FIRST_PAUSE) and turn toward the guard
	for i in 90:
		_put_guard(floor_spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	for end in 2:
		var root := serpent.body.joints[serpent._neck_root(end as END)]
		assert_gt(serpent.body.head_point(end as END).y, root.y + 0.8, "head %d raised over the gate" % end)
	# the arches travel round: high places and low ones to jump
	for i in 60 * 3:
		_put_guard(floor_spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	var highest := 0.0
	var lowest := INF
	for j in range(ground.x, ground.y + 1):
		var over := serpent.body.joints[j].y - serpent._ground_at(serpent.body.joints[j])
		highest = maxf(highest, over)
		lowest = minf(lowest, over)
	assert_gt(highest, 1.2, "an arch stands over the terrace (%.2f)" % highest)
	assert_lt(lowest, 0.65, "and the body lies low elsewhere (%.2f)" % lowest)
	# from the gate both heads fight: no sweep in the ring
	var told := watch(serpent.telegraphed)
	for i in 60 * 10:
		_put_guard(Vector3(-14.25, 0.0, -83.0))   # at the foot of the flights, in front of the gate
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	assert_gt(told.size(), 0, "it attacked from the gate")
	for entry in told:
		assert_ne(entry[0], &"sweep", "no sweep from the ring")
	assert_eq(serpent.brain.state == S.RING or serpent.brain.state == S.ATTACK, true)


func test_fleeing_calms_it_onto_its_ring_and_its_fall_leaves_the_shard_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	var rest := serpent.body.leader()
	await _awake(serpent)
	for i in 60 * 4:
		_put_guard(START)
		await get_tree().physics_frame
	assert_gt(serpent.body.leader().distance_to(rest), 2.0)
	_hit_zone(serpent, &"seg_12", 40.0, serpent.body.joints[12])
	assert_false(serpent.rig.plate_on(12))
	var calmed := watch(serpent.calmed)
	_put_guard(Vector3(-27.75, 0.0, -79.0))   # out onto the canoe deck
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1, "the guard fled: calmed")
	assert_eq(serpent.state, Guardian.State.DORMANT)
	assert_lt(serpent.body.leader().distance_to(rest), 0.3, "back on its ring")
	assert_true(serpent.rig.plate_on(12), "whole again")
	assert_almost_eq(serpent.health.fraction(), 1.0, 0.001)
	# its fall
	await _awake(serpent)
	var keeper := museum.floor_game.guardians
	var info := DamageInfo.make(serpent.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = serpent.body.head_point(END.A)
	serpent.take_zone_damage(info, &"head_a")
	await physics_frames(2)
	assert_false(is_instance_valid(serpent) and serpent.is_inside_tree(), "gone")
	assert_true(GameState.is_guardian_defeated(&"serpent"), "for good")
	var falls := keeper.find_children("*", "SerpentFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	var reward: Vector3 = (museum.floor_level.markers[&"arena_serpent_reward"] as Transform3D).origin
	var pickups := keeper.find_children("*", "ProgressPickup", false, false)
	assert_eq(pickups.size(), 1, "the shard of the Americas (no seal)")
	if pickups.size() == 1:
		assert_lt((pickups[0] as Node3D).global_position.distance_to(reward), 1.5, "on the summit, in the moon's shaft")
	await _seconds(SerpentFall.TREMBLE + SerpentFall.CASCADE_STEP * SerpentBody.SEGMENTS + 0.5)
	var fall := falls[0] as SerpentFall
	assert_eq(fall._rig.plates_left(), 0, "every plate cascaded off")
	assert_eq(fall.pieces.size(), 2, "both skulls broke off")
	assert_true(is_instance_valid(keeper) and keeper.is_inside_tree(), "(the keeper lives on)")
	assert_false(keeper.guardians.has(&"serpent"))


## A probe among the rig's nodes: remembers where [member watched] stood
## each time physics interpolation was reset beneath it.
class ResetProbe:
	extends Node3D
	var watched: Node3D
	var seen: Array[Vector3] = []

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESET_PHYSICS_INTERPOLATION and watched != null:
			seen.append(watched.global_position)


func test_after_a_turn_round_and_a_reset_it_rests_as_it_first_lay_with_a_fresh_interpolation() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	var rest_leader := serpent.body.leader()
	var rest_heads: Array[Vector3] = [serpent.body.head_point(END.A), serpent.body.head_point(END.B)]
	assert_eq(serpent.body.lead, END.A, "end A leads asleep")
	await _awake(serpent)
	for i in 60 * 3:
		_put_guard(START)
		await get_tree().physics_frame
	# the guard kept to its tail: it turns round and the other head leads
	serpent.brain.reverse()
	assert_eq(serpent.brain.lead, END.B)
	assert_eq(serpent.body.lead, END.B, "the body follows the brain")
	var probe := ResetProbe.new()
	probe.watched = serpent.rig.segments[0]
	serpent.rig.model.add_child(probe)
	serpent.reset_fight()
	assert_eq(serpent.brain.lead, END.A)
	assert_eq(serpent.body.lead, serpent.brain.lead, "back asleep, end A leads in the body too")
	assert_lt(serpent.body.leader().distance_to(rest_leader), 0.3, "the same end anchors the ring")
	for end in 2:
		assert_lt(serpent.body.head_point(end as END).distance_to(rest_heads[end]), 0.6, "head %d where it first lay (the heads do not swap)" % end)
	assert_eq(serpent.body.trailer_joint(), serpent.body.count - SerpentBody.NECK, "end B trails (the sweep is anchored there)")
	# the segments moved after the guardian's own reset: the interpolation is
	# reset once more, with the segments already in place
	assert_gt(probe.seen.size(), 0, "the rig's interpolation was reset")
	if not probe.seen.is_empty():
		assert_lt(probe.seen[probe.seen.size() - 1].distance_to(serpent.rig.segments[0].global_position), 0.001, "after the segments were laid back")


func test_only_the_temples_own_railings_are_left_out_of_the_ground_rays() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var serpent := _serpent()
	assert_gt(serpent._rail_bodies.size(), 0, "the flights' railings are found")
	var temple := 0
	var elsewhere := 0
	for node in museum.get_tree().get_nodes_in_group(&"level_kit"):
		if node.get_meta(&"kit", &"") != &"railing" or not (node is StaticBody3D):
			continue
		if node.get_meta(&"kit_room", &"") == ROOM:
			temple += 1
		else:
			elsewhere += 1
	assert_gt(elsewhere, 20, "the museum has many railings beyond the temple (%d)" % elsewhere)
	assert_eq(serpent._rail_bodies.size(), temple, "exactly the temple's own")
	assert_eq(serpent._rail_rids.size(), serpent._rail_bodies.size())
	for rail in serpent._rail_bodies:
		assert_eq(museum.floor_level.room_at(rail.global_position + Vector3.UP * 0.5), ROOM, "%s stands in the temple" % rail.get_path())
