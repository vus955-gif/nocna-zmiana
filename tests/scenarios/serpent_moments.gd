class_name SerpentMoments
extends RefCounted
## The Two-headed Serpent's fight staged moment by moment in the dev arena
## (tests/scenarios/guardian_scenario.gd: `bash tools/run_guardian.sh
## serpent --dry` checks every moment headless, `--shots` photographs them):
## asleep coiled on its ring, both heads on the north flight's upper steps;
## the waking (the eyes, the rattle, the heads rise); it pours down the
## flights; it glides the floor weaving; the spit (the rear and the glow,
## the marks, the shards' flight and burst); the lunge (the S-coil and its
## lane, the bite, the spent head); the sweep (the windup, the tail coming
## round); the turn-round; phase 2's light running down the body; a plate
## shot off; phase 3's slide onto the ring, the ring closed with the heads
## at the gate, the travelling arches, an attack from the gate; its fall
## (the tremble, the cascade and the skulls, the bared body and the shard).
## Every moment goes through the scenario's _shot (logged, checked, and in
## --shots photographed).

const Scenario := preload("res://tests/scenarios/guardian_scenario.gd")
const S := SerpentBrain.State
const A := SerpentBrain.Attack
const END := SerpentBody.End
const TELL := SerpentBrain.Stage.TELEGRAPH
const HIT := SerpentBrain.Stage.STRIKE
const RECOVER := SerpentBrain.Stage.RECOVER
## Outside the arena (the canoe deck over the pit); the arena's start line;
## the foot of the flights in front of the gate.
const DECK := Vector3(-27.75, 0.0, -79.0)
const START := Vector3(-22.5, 0.0, -79.0)
const FOOT := Vector3(-14.25, 0.0, -83.0)
## The north flight up to the altar's terrace (where the heads rest), the
## lower one down to the floor (it pours down it).
const N2 := Rect2(-15.75, -79, 3.0, 4.0)
const N1 := Rect2(-15.75, -83, 3.0, 4.0)
## The dressed temple (19.10: the cameras of the greybox missed): the heads
## rising over the north flight from the floor's north-east corner, clear of
## the fire bowl's smoke (only 3 m of floor before the flight's foot); the
## closed ring from high over the north wall's foot, down onto the terraces.
const RISE_EYE := Vector3(-10.0, 4.5, -85.4)
const RING_EYE := Vector3(-14.25, 9.5, -85.2)


static func fight(scene: Scenario, serpent: Serpent) -> void:
	var gate := serpent.course.gate_center()
	var gate_eye := gate + Vector3(0.0, 2.6, 0.0)
	var room := serpent.arena_room
	# 1. the museum piece: asleep, coiled on its ring round the altar's
	# terrace, both heads lying on the upper steps of the north flight
	scene._put_guard(DECK, gate_eye)
	var heads_on_steps := N2.has_point(_flat2(serpent.body.head_point(END.A))) and N2.has_point(_flat2(serpent.body.head_point(END.B)))
	await scene._shot("dormant", gate + Vector3(0.0, 2.4, -8.0), gate_eye, serpent.state == Guardian.State.DORMANT and heads_on_steps)
	# 2. the guard crosses the start line: the eyes light, the plates rattle
	scene._put_guard(START, gate_eye)
	await scene._until(func() -> bool: return serpent.brain.state == S.WAKING and serpent.brain.state_progress() > 0.3, 3.0)
	await scene._shot("waking", gate + Vector3(-3.5, 2.4, -6.5), gate_eye, serpent.brain.state == S.WAKING and serpent.moves.pose.eyes > 0.5)
	# 3. the heads rise off the steps
	await scene._until(func() -> bool: return serpent.brain.state != S.WAKING or serpent.brain.state_progress() > 0.9, 3.0)
	var raised := serpent.body.head_point(END.A).y > serpent.body.joints[SerpentBody.NECK].y + 0.4
	await scene._shot("heads_rise", RISE_EYE, gate_eye, serpent.brain.state == S.WAKING and raised)
	# 4. it pours down the flights toward the guard
	await scene._until(func() -> bool:
		scene._put_guard(START, serpent.body.leader() + Vector3.UP)
		return serpent.body.leader().y < 1.2, 8.0)
	var on_flight := _joints_in(serpent, N1) >= 3
	await scene._shot("pouring_down", START + Vector3(3.0, 1.8, -3.0), serpent.body.leader() + Vector3.UP * 0.5, serpent.body.leader().y < 1.2 and on_flight)
	# 5. gliding the floor, weaving
	await _roaming(scene, serpent, START)
	await scene._until(func() -> bool:
		scene._put_guard(START, serpent.body.leader() + Vector3.UP)
		return serpent.body.leader().y < 0.6 and serpent.brain.wanted_speed() > 0.5, 6.0)
	await scene._shot("gliding", _view(serpent.body.leader(), START, 6.0, 2.2), serpent.body.leader() + Vector3.UP * 0.5, serpent.brain.state == S.ROAM and serpent.body.leader().y < 0.6)
	# 6. the spit: the glowing head rears, its mouth glows, the marks spread
	# round the guard
	await _roaming(scene, serpent, START)
	var spitter := serpent.brain.spitter
	var spot := _in_arena(scene, room, _out_from(serpent, spitter, 10.0), START)
	scene._put_guard(spot, serpent.body.head_point(spitter))
	serpent.brain.force_attack(A.SPIT)
	await scene._seconds(SerpentBrain.stage_length(A.SPIT, TELL, serpent.brain.phase) * 0.8)
	var spit_head := serpent.body.head_point(spitter)
	await scene._shot("spit_rear", _view(spit_head, spot, 4.5, 2.0), spit_head,
			serpent.brain.attack == A.SPIT and serpent.brain.stage == TELL and serpent._spit_marks.size() == SerpentBrain.SHARDS[0] and serpent.moves.pose.head_glow[spitter] > 0.3)
	# 7. the shards leave on their arcs toward the marks
	await scene._until(func() -> bool: return serpent.brain.stage == HIT, 1.0)
	await scene._seconds(0.3)
	var flying := 0
	var shard_at := spot + Vector3.UP
	for shard in serpent.shards:
		if is_instance_valid(shard) and (shard as Node3D).global_position.y > spot.y + 0.5:
			flying += 1
			shard_at = (shard as Node3D).global_position
	await scene._shot("spit_flight", _view(shard_at, spit_head, 5.0, 2.0), shard_at, flying >= 1)
	# 8. a shard bursts on its mark (the splash round it)
	await scene._until(func() -> bool:
		for shard in serpent.shards:
			if is_instance_valid(shard) and (shard as SerpentShard)._splashed:
				return true
			if not is_instance_valid(shard):
				return true
		return false, 2.0)
	var burst := false
	for shard in serpent.shards:
		if not is_instance_valid(shard) or (shard as SerpentShard)._splashed:
			burst = true
	await scene._shot("spit_burst", _seen(scene, room, spot + Vector3(3.0, 1.8, 3.0), spot), spot, burst)
	# 9. the lunge: the biting head draws back in an S, hissing, the lane on
	# the floor toward the guard
	await _roaming(scene, serpent, spot)
	var biter := serpent.brain.biter()
	var in_lane := _in_arena(scene, room, _out_from(serpent, biter, 3.6), spot)
	scene._put_guard(in_lane, serpent.body.head_point(biter))
	await scene._seconds(0.1)
	serpent.brain.force_attack(A.LUNGE)
	await scene._seconds(SerpentBrain.stage_length(A.LUNGE, TELL, serpent.brain.phase) * 0.8)
	var root := serpent.body.joints[serpent._neck_root(biter)]
	await scene._shot("lunge_coil", _view(root, in_lane, 4.5, 1.8), serpent.body.head_point(biter),
			serpent.brain.attack == A.LUNGE and serpent.brain.stage == TELL and serpent._lane != null)
	# 10. the bite: the head shoots out low to its neck's full reach (the
	# strike eases out: full extension as it lands)
	await scene._until(func() -> bool: return serpent.brain.stage == RECOVER, 1.5)
	var reach := serpent.body.head_point(biter).distance_to(serpent.body.joints[serpent._neck_root(biter)])
	await scene._shot("lunge_bite", _view(root, in_lane, 4.5, 1.6), serpent.body.head_point(biter), serpent.brain.attack == A.LUNGE and reach > 2.3)
	# 11. spent: the head hangs out, its weak point counting half again
	await scene._seconds(0.3)
	await scene._shot("lunge_spent", _view(root, in_lane, 4.0, 1.6), serpent.body.head_point(biter),
			serpent.brain.attack == A.LUNGE and serpent.brain.stage == RECOVER and serpent.brain.weak_factor(biter) > 1.0)
	# 12. the sweep: the plates rattle, the arc on the floor, the tail winds
	# up the other way
	var by_tail: Vector3 = await _guard_by_tail(scene, serpent, spot)
	serpent.brain.force_attack(A.SWEEP)
	await scene._seconds(SerpentBrain.stage_length(A.SWEEP, TELL, serpent.brain.phase) * 0.85)
	var base := serpent._sweep_base
	var wound := serpent.body.sweep
	await scene._shot("sweep_windup", _view(base, by_tail, 6.5, 2.4), base + Vector3.UP * 0.5,
			serpent.brain.attack == A.SWEEP and serpent.brain.stage == TELL and serpent._arc != null and absf(wound) > 0.2)
	# 13. it comes round across where the guard stood
	await scene._until(func() -> bool: return serpent.brain.stage == HIT, 1.0)
	await scene._seconds(0.35)
	var came_round := serpent.body.sweep * signf(wound if absf(wound) > 0.01 else 1.0) < -0.2
	await scene._shot("sweep_round", _view(base, by_tail, 6.5, 2.4), base + Vector3.UP * 0.5, serpent.brain.attack == A.SWEEP and came_round)
	# 14. the guard keeping to its tail: it turns round and leads with the
	# other head
	await _roaming(scene, serpent, spot)
	var lead_before := serpent.brain.lead
	await scene._until(func() -> bool:
		var tail := serpent.body.joints[serpent.body.trailer_joint()]
		var out := serpent.body.root_direction(serpent.brain.trailer())
		var behind := _in_arena(scene, room, _floored(serpent, tail + Vector3(out.x, 0.0, out.z).normalized() * 3.5), _floored(serpent, tail + Vector3(out.x, 0.0, out.z).normalized() * 1.5))
		scene._put_guard(behind, tail + Vector3.UP)
		return serpent.brain.lead != lead_before, 14.0)
	var leader := serpent.body.leader()
	await scene._shot("turned", _seen(scene, room, _view(leader, scene.museum.player.global_position, 7.0, 2.6), leader + Vector3.UP * 0.5), leader + Vector3.UP * 0.5, serpent.brain.lead != lead_before)
	# 15. phase 2: the heads turn to each other, the light runs down the body
	await _roaming(scene, serpent, spot)
	var spitter_before := serpent.brain.spitter
	_wound(scene, serpent, 0.6)
	await scene._until(func() -> bool:
		scene._put_guard(spot, serpent.body.head_point(END.A))
		return serpent.brain.state == S.PHASE_SHIFT and serpent.brain.state_progress() > 0.45, 8.0)
	var mid := serpent.body.joints[serpent.body.count >> 1]
	# (high: the altar house's merlons are no collider, they hid the body)
	await scene._shot("phase_shift", _seen(scene, room, mid + Vector3(5.0, 6.0, 5.0), mid + Vector3.UP * 0.5), mid + Vector3.UP * 0.5,
			serpent.brain.state == S.PHASE_SHIFT and serpent.moves.pose.light_s > 0.05 and serpent.moves.pose.light_s < 0.95)
	# 16. the roles swapped: the other head glows and spits now
	await scene._until(func() -> bool: return serpent.brain.state != S.PHASE_SHIFT, 3.0)
	var glowing := serpent.body.head_point(serpent.brain.spitter)
	await scene._shot("roles_swapped", _view(glowing, spot, 4.0, 1.8), glowing, serpent.brain.spitter != spitter_before and serpent.phase == 2)
	# 17. a plate shot off a segment: the bared core glows under the mosaic
	var k := serpent.body.count >> 1
	_hit(scene, serpent, StringName("seg_%d" % k), 40.0, serpent.body.joints[k])
	await scene._seconds(0.1)
	await scene._shot("plate_off", _seen(scene, room, serpent.body.joints[k] + Vector3(3.0, 3.5, 3.0), serpent.body.joints[k]), serpent.body.joints[k], not serpent.rig.plate_on(k))
	# 18. phase 3: it slides onto the ring round the altar's terrace
	await _roaming(scene, serpent, spot)
	var circled := [false]
	serpent.encircled.connect(func() -> void: circled[0] = true)
	_wound(scene, serpent, 0.3)
	await scene._until(func() -> bool:
		scene._put_guard(spot, serpent.body.leader() + Vector3.UP)
		return serpent.brain.state == S.ENCIRCLE and serpent.brain.wanted_speed() > 4.0, 8.0)
	await scene._shot("encircling", _view(serpent.body.leader(), spot, 7.0, 3.0), serpent.body.leader() + Vector3.UP * 0.5, serpent.brain.state == S.ENCIRCLE)
	# 19. the ring closed but for the gate: both neck roots at its posts (as
	# it closes - the arches then take their slack from the trailing end,
	# which creeps along the ring a little), then the heads rising over the
	# north flight on their springs
	await scene._until(func() -> bool:
		scene._put_guard(spot, gate_eye)
		return circled[0], 40.0)
	var posts := serpent.course.gate_posts()
	var at_posts := true
	for end in 2:
		var neck := serpent.body.joints[serpent._neck_root(end as END)]
		var to_post := minf(Vector2(neck.x - posts[0].x, neck.z - posts[0].z).length(), Vector2(neck.x - posts[1].x, neck.z - posts[1].z).length())
		at_posts = at_posts and to_post < 1.5
	await scene._shot("ring_closed", RING_EYE, _ring_centre(serpent), serpent.brain.in_ring() and at_posts)
	await scene._seconds(1.5)
	var heads_up := true
	for end in 2:
		var neck := serpent.body.joints[serpent._neck_root(end as END)]
		heads_up = heads_up and serpent.body.head_point(end as END).y > neck.y + 0.8
	await scene._shot("heads_at_gate", gate + Vector3(0.0, 2.2, -7.0), gate_eye, serpent.brain.in_ring() and heads_up)
	# 20. the arches travel round the ring: high places, low ones to jump
	await scene._seconds(1.5)
	var highest := 0.0
	var lowest := INF
	var ground := serpent.body.ground_joints()
	var high_at := gate
	for j in range(ground.x, ground.y + 1):
		var over := serpent.body.joints[j].y - serpent._ground_at(serpent.body.joints[j])
		if over > highest:
			highest = over
			high_at = serpent.body.joints[j]
		lowest = minf(lowest, over)
	var centre := _ring_centre(serpent)
	await scene._shot("arches", _outside_ring(scene, room, high_at, centre), high_at.lerp(centre, 0.25), highest > 1.2 and lowest < 0.65)
	# 21. both heads fight from the gate: the guard at the flights' foot
	var told := [StringName()]
	serpent.telegraphed.connect(func(attack: StringName) -> void: told[0] = attack)
	await scene._until(func() -> bool:
		scene._put_guard(FOOT, gate_eye)
		return told[0] != StringName(), 10.0)
	await scene._seconds(0.3)
	await scene._shot("gate_attack", FOOT + Vector3(4.0, 1.8, -1.0), gate_eye, (told[0] == &"spit" or told[0] == &"lunge") and serpent.brain.state == S.ATTACK)
	# 22. its fall: the eyes flare, the plates rattle, the heads sag
	var keeper := scene.museum.floor_game.guardians
	var info := DamageInfo.make(serpent.health.current + 1.0, DamageInfo.Kind.BALLISTIC, scene.museum.player)
	info.position = serpent.body.head_point(END.A)
	serpent.take_zone_damage(info, &"head_a")
	await scene._seconds(SerpentFall.TREMBLE * 0.6)
	var falls := keeper.find_children("*", "SerpentFall", false, false)
	var fall: SerpentFall = falls[0] as SerpentFall if not falls.is_empty() else null
	await scene._shot("fall_tremble", gate + Vector3(0.0, 3.0, -8.0), gate_eye, fall != null and not is_instance_valid(serpent))
	# 23. the mosaic cascades off segment by segment from the end that was
	# hit; the skulls break off and roll down the steps
	await scene._seconds(SerpentFall.TREMBLE * 0.4 + SerpentFall.CASCADE_STEP * SerpentBody.SEGMENTS * 0.55)
	var cascading := fall != null and fall._rig.plates_left() < SerpentBody.SEGMENTS >> 1 and fall.pieces.size() == 2
	await scene._shot("cascade", gate + Vector3(5.0, 3.5, -7.0), gate + Vector3(0.0, 0.5, 3.0), cascading)
	# 24. fallen: the bared wooden body lies on the ring for the night, the
	# shard of the Americas in the moon's shaft on the summit
	await scene._seconds(SerpentFall.CASCADE_STEP * SerpentBody.SEGMENTS * 0.5 + 1.5)
	var pickups := keeper.find_children("*", "ProgressPickup", false, false)
	var reward: Vector3 = (scene.museum.floor_level.markers[&"arena_serpent_reward"] as Transform3D).origin
	await scene._shot("fallen", reward + Vector3(6.0, 3.0, -8.0), reward + Vector3.UP * 0.5,
			fall != null and fall._rig.plates_left() == 0 and GameState.is_guardian_defeated(&"serpent") and pickups.size() == 1)


# --- staging --------------------------------------------------------------------------

## Waits until it roams (an attack under way runs out), the guard at [param at].
static func _roaming(scene: Scenario, serpent: Serpent, at: Vector3) -> void:
	await scene._until(func() -> bool:
		scene._put_guard(at, serpent.body.leader() + Vector3.UP)
		return serpent.brain.state == S.ROAM, 10.0)


## The guard hits it through head A down to [param fraction] of its health.
static func _wound(scene: Scenario, serpent: Serpent, fraction: float) -> void:
	_hit(scene, serpent, &"head_a", serpent.health.current - serpent.max_health * fraction + 1.0, serpent.body.head_point(END.A))


static func _hit(scene: Scenario, serpent: Serpent, zone: StringName, amount: float, at: Vector3) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, scene.museum.player)
	info.weapon = &"pistol"
	info.position = at
	serpent.take_zone_damage(info, zone)


## A floor point [param ahead] m out from head [param end]'s neck root along
## its line, [param aside] m to its right.
static func _out_from(serpent: Serpent, end: END, ahead: float, aside: float = 0.0) -> Vector3:
	var frame := serpent.body.root_frame(end)
	return _floored(serpent, frame * Vector3(aside, 0.0, -ahead))


static func _floored(serpent: Serpent, at: Vector3) -> Vector3:
	return Vector3(at.x, serpent._ground_at(at), at.z)


## [param at] when it lies in the arena, else [param fallback].
static func _in_arena(scene: Scenario, room: StringName, at: Vector3, fallback: Vector3) -> Vector3:
	return at if scene.museum.floor_level.room_at(at + Vector3.UP * 0.5) == room else fallback


## A floor spot beside the trailing tail with the rest of the body clear of
## it; INF when neither side is clear.
static func _by_tail(scene: Scenario, serpent: Serpent) -> Vector3:
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
			if (tip_j > base_j and j >= base_j - 1) or (tip_j < base_j and j <= base_j + 1):
				continue
			clear = minf(clear, Vector2(at.x - serpent.body.joints[j].x, at.z - serpent.body.joints[j].z).length())
		at.y = serpent._ground_at(at)
		if clear > 1.6 and absf(at.y - floor_y) < 0.3 and scene.museum.floor_level.room_at(at + Vector3.UP * 0.5) == serpent.arena_room:
			return at
	return Vector3.INF


## Lets it roam (the guard at [param at]) until a clear spot beside its tail
## turns up, and puts the guard there (looking at the tail).
static func _guard_by_tail(scene: Scenario, serpent: Serpent, at: Vector3) -> Vector3:
	var spot := Vector3.INF
	for i in 60 * 12:
		await _roaming(scene, serpent, at)
		spot = _by_tail(scene, serpent)
		if spot.is_finite():
			break
		scene._put_guard(at, serpent.body.leader() + Vector3.UP)
		await scene.get_tree().physics_frame
	if not spot.is_finite():
		spot = at
	scene._put_guard(spot, serpent.body.joints[serpent.body.trailer_joint()] + Vector3.UP * 0.5)
	await scene._seconds(0.1)
	return spot


## How many lying joints lie over [param rect] (floor plan).
static func _joints_in(serpent: Serpent, rect: Rect2) -> int:
	var n := 0
	var ground := serpent.body.ground_joints()
	for j in range(ground.x, ground.y + 1):
		if rect.has_point(_flat2(serpent.body.joints[j])):
			n += 1
	return n


## The middle of the phase-3 ring (the altar's terrace), at the ring's height.
static func _ring_centre(serpent: Serpent) -> Vector3:
	var path := serpent.course.ring_path()
	var sum := Vector3.ZERO
	for point in path:
		sum += point
	return sum / maxf(1.0, float(path.size()))


## A camera point outside the ring looking in across [param arch] (an arch of
## the body), 3 m over it and up to 6 m out from the ring's [param centre],
## pulled in until it stands in the arena [param room] (the walls are near).
static func _outside_ring(scene: Scenario, room: StringName, arch: Vector3, centre: Vector3) -> Vector3:
	var out := Vector3(arch.x - centre.x, 0.0, arch.z - centre.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	for i in 12:
		var eye := arch + out * (6.0 - i * 0.5) + Vector3.UP * 3.0
		if scene.museum.floor_level.room_at(eye) == room:
			return eye
	return arch + Vector3.UP * 3.0


## [param eye] when it stands in the arena [param room] and sees
## [param subject] (no wall, terrace or altar house between: the dressed
## temple hides much of the body from a fixed side view), else the nearest
## such point round the subject at about the same distance and height.
static func _seen(scene: Scenario, room: StringName, eye: Vector3, subject: Vector3) -> Vector3:
	if _sees(scene, room, eye, subject):
		return eye
	var away := Vector3(eye.x - subject.x, 0.0, eye.z - subject.z)
	var reach := maxf(4.0, away.length())
	var rise := maxf(2.0, eye.y - subject.y)
	var start := atan2(away.x, away.z)
	for step in 16:
		var turn := start + floorf((step + 1) / 2.0) * PI / 8.0 * (1.0 if step % 2 == 0 else -1.0)
		for scale: float in [1.0, 0.75, 1.25]:
			var at := subject + Vector3(sin(turn), 0.0, cos(turn)) * reach * scale + Vector3.UP * rise
			if _sees(scene, room, at, subject):
				return at
	return eye


static func _sees(scene: Scenario, room: StringName, eye: Vector3, subject: Vector3) -> bool:
	if scene.museum.floor_level.room_at(eye) != room:
		return false
	var space := scene.get_viewport().find_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.position = eye
	point.collision_mask = Layers.WORLD
	if not space.intersect_point(point).is_empty():
		return false
	# (to a hand short of it: the floor a subject lies on is no wall)
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, subject + (eye - subject).normalized() * 0.25, Layers.WORLD)).is_empty()


## A camera point for a side view of [param subject] with [param toward] in
## frame: [param back] m off the line between them, [param up] m up.
static func _view(subject: Vector3, toward: Vector3, back: float, up: float) -> Vector3:
	var line := Vector3(toward.x - subject.x, 0.0, toward.z - subject.z)
	line = line.normalized() if line.length() > 0.01 else Vector3.FORWARD
	var middle := (subject + toward) * 0.5
	return middle + line.cross(Vector3.UP) * back + Vector3.UP * up


static func _flat2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
