extends TestCase
## The Colossus of Ramesses in the real Colossus hall of Floor I: he sits
## on his throne among seven papyrus columns, wakes when the guard steps
## in, announces every attack at least 0.6 s ahead, takes damage only
## through his weak points, sheds his plates and pours scarabs in phase 2,
## stands up and walks in phase 3; his beam is stopped by the columns,
## which break on the third beam; his fall leaves stone, the seal and the
## shard, for good; the guard fleeing calms him back onto his throne.

const A := ColossusBrain.Attack
const S := ColossusBrain.State
const Egypt := preload("res://src/level/floor1/zones/egypt.gd")

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


func _colossus() -> Colossus:
	return museum.floor_game.guardians.guardians.get(&"colossus") as Colossus


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


## A floor point [param ahead] m in front of the seated Colossus,
## [param aside] m to his left.
func _in_front(colossus: Colossus, ahead: float, aside: float = 0.0) -> Vector3:
	var home := colossus.home
	return home.origin - home.basis.z * ahead - home.basis.x * aside


## Wakes him with the guard [param ahead] m in front and waits out the waking.
func _awake(colossus: Colossus, ahead: float = 10.0) -> void:
	_put_guard(_in_front(colossus, ahead))
	await _seconds(0.3)
	assert_true(colossus.is_fighting(), "awake")
	await _seconds(ColossusBrain.WAKE_TIME)


## A hit of [param amount] through his zone [param zone].
func _hit(colossus: Colossus, zone: StringName, amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, museum.player)
	info.weapon = &"pistol"
	info.position = colossus.global_position + Vector3.UP * 6.0
	colossus.take_zone_damage(info, zone)
	return info


func test_he_sits_on_his_throne_among_seven_columns() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	assert_not_null(colossus, "the real Colossus, not the stand-in")
	if colossus == null:
		return
	assert_eq(GuardianKeeper.script_for(&"colossus"), load("res://src/game/floor1/guardians/colossus.gd"))
	var seat: Transform3D = museum.floor_level.markers[&"guardian_colossus"]
	assert_lt(colossus.global_position.distance_to(seat.origin), 0.05, "on his post")
	assert_eq(colossus.state, Guardian.State.DORMANT)
	assert_eq(colossus.arena_room, &"egypt_colossus")
	assert_not_null(colossus.throne)
	assert_lt(colossus.throne.global_position.distance_to(seat.origin), 0.05, "on his throne")
	var columns := get_tree().get_nodes_in_group(ColossusColumn.GROUP)
	assert_eq(columns.size(), Egypt.COLUMNS.size(), "the hall's papyrus columns")
	for column: ColossusColumn in columns:
		assert_eq(museum.floor_level.room_at(column.global_position + Vector3.UP), &"egypt_colossus")
	assert_almost_eq(colossus.max_health, 1100.0, 0.01)
	await _seconds(1.0)
	assert_lt(colossus.global_position.distance_to(seat.origin), 0.05, "he does not slide off his throne")


func test_he_wakes_as_the_guard_steps_in_and_announces_every_attack_in_time() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	# the dice fixed, so the fight repeats (his picks are weighted dice: left
	# to chance, now and then a run never rolls one of the three in 48 s)
	colossus.brain.seed_with(7)
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(-43.0, 0.0, -8.0))   # the gallery: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside his hall")
	_put_guard(_in_front(colossus, 15.5))
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake past the start line")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_COLOSSUS").to_upper()), museum.hud.boss_name_text())
	assert_eq(colossus.brain.state, S.WAKING)
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	var seen := {}
	colossus.telegraphed.connect(func(kind: StringName) -> void:
		started[kind] = clock[0]
		seen[kind] = true)
	colossus.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append([kind, clock[0] - float(started[kind])]))
	var spots: Array[Vector3] = [_in_front(colossus, 6.5), _in_front(colossus, 10.0, 3.0), _in_front(colossus, 16.0, -2.0), _in_front(colossus, 7.0, -2.5)]
	for i in 60 * 48:
		clock[0] += 1.0 / 60.0
		if i % 240 == 0:
			_put_guard(spots[(i / 240) % spots.size()])
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_gt(gaps.size(), 6, "he attacked")
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "%s announced %.2f s ahead" % [gap[0], gap[1]])
	for kind: StringName in [&"slam", &"sweep", &"beam"]:
		assert_true(seen.has(kind), "%s in phase 1: %s" % [kind, str(seen.keys())])


func test_only_his_weak_points_hurt_him() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus)
	var full := colossus.health.current
	var granite := _hit(colossus, &"body", 100.0)
	assert_almost_eq(colossus.health.current, full - 10.0, 0.01, "granite: a tenth")
	assert_true(granite.blocked, "a grey marker")
	var cobra := _hit(colossus, &"uraeus", 50.0)
	assert_almost_eq(colossus.health.current, full - 60.0, 0.01, "the uraeus: all of it")
	assert_true(cobra.weak_point, "a gold marker")
	_hit(colossus, &"plate_1", 100.0)
	assert_almost_eq(colossus.health.current, full - 70.0, 0.01, "a plate is granite too")
	assert_true(colossus.rig.plates_on[0], "bullets do not break a plate")
	_hit(colossus, &"plate_1", 45.0, DamageInfo.Kind.FIRE)
	assert_false(colossus.rig.plates_on[0], "an explosion does")
	var health := colossus.health.current
	_hit(colossus, &"crack_1", 30.0)
	assert_almost_eq(colossus.health.current, health - 30.0, 0.01, "the crack under it is a weak point")
	# the weapons' own path: a ray from the guard's eyes finds the uraeus
	# before the crown, and the open crack before the chest
	await physics_frames(2)
	var space := colossus.get_world_3d().direct_space_state
	var eye := _in_front(colossus, 9.0) + Vector3.UP * 1.6
	for spot: Array in [[colossus.rig.part("uraeus").global_position + Vector3.UP * 0.1, &"uraeus"], [colossus.rig.part("crack_1").global_position, &"crack_1"]]:
		var aim: Vector3 = spot[0]
		var hit := Hitscan.ray(space, eye, eye + (aim - eye) * 1.5)
		assert_false(hit.is_empty(), "a hit on %s" % spot[1])
		if not hit.is_empty():
			var hurtbox := hit["hurtbox"] as Hurtbox
			assert_not_null(hurtbox, "a zone, not a wall")
			if hurtbox != null:
				assert_eq((hurtbox.receiver as GuardianZone).zone, spot[1])
				assert_true(hurtbox.weak_point, "%s is a weak point for the weapons" % spot[1])


func test_phase_two_sheds_his_plates_and_pours_out_scarabs() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 9.0)
	var phases := watch(colossus.phase_changed)
	_hit(colossus, &"uraeus", colossus.max_health * 0.4)
	assert_eq(colossus.phase, 2)
	assert_eq(phases.size(), 1)
	var shifted := false
	for i in 60 * 8:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if colossus.brain.state == S.PHASE_SHIFT:
			shifted = true
		if shifted and colossus.brain.state != S.PHASE_SHIFT:
			break
	assert_true(shifted, "he rears back, the plates burst")
	assert_eq(colossus.rig.plates_on, [false, false, false] as Array[bool], "every plate is off")
	var swarm: ScarabSwarm = null
	for i in 60 * 6:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if colossus.alive_swarms() > 0:
			swarm = colossus.swarms[0] as ScarabSwarm
			break
	assert_not_null(swarm, "a swarm pours out of the throne")
	if swarm != null:
		assert_almost_eq(swarm.max_health, 40.0, 0.01)
		assert_lt(swarm.global_position.distance_to(colossus.throne.global_position), 4.0, "out of his throne")
		var health := museum.player.health.current
		for i in 63:
			_put_guard(swarm.global_position)
			await get_tree().physics_frame
		assert_lt(museum.player.health.current, health - 4.0, "it bites while it is on him")
		var buckshot := DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC, museum.player)
		buckshot.weapon = &"shotgun"
		swarm.take_damage(buckshot)
		assert_almost_eq(swarm.health.current, 20.0, 0.01, "buckshot tears it twice as fast")


func test_a_column_shields_the_guard_from_the_beam_and_breaks_on_the_third() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 9.0)
	# the guard right behind a column, as seen from the eyes
	var column: ColossusColumn = null
	var best := INF
	var eyes := colossus.rig.eyes_point()
	for node: ColossusColumn in get_tree().get_nodes_in_group(ColossusColumn.GROUP):
		var off := node.global_position - colossus.global_position
		var ahead := -off.dot(colossus.home.basis.z)
		if ahead > 0.0 and absf(off.length() - 11.7) < best:
			best = absf(off.length() - 11.7)
			column = node
	assert_not_null(column)
	var away := Vector3(column.global_position.x - eyes.x, 0.0, column.global_position.z - eyes.z).normalized()
	var hiding := column.global_position + away * 2.2
	var health := 0.0
	for burst in 3:
		_put_guard(hiding)
		health = museum.player.health.current
		await _beam(colossus, hiding)
		assert_almost_eq(museum.player.health.current, health, 0.01, "beam %d: the column takes it" % (burst + 1))
		assert_eq(column.hits, burst + 1, "one hit a beam")
	assert_eq(column.stage, ColossusColumn.Stage.BROKEN, "the third beam breaks it")
	assert_almost_eq(column.cover_height(), ColossusColumn.STUMP_HEIGHT, 0.01)
	# in the open he burns
	var open := _in_front(colossus, 9.0, 0.5)
	_put_guard(open)
	health = museum.player.health.current
	await _beam(colossus, open)
	assert_lt(museum.player.health.current, health - 20.0, "a guard standing in the open burns")


## One beam aimed at a guard kept standing at [param spot], from its
## charge to its end.
func _beam(colossus: Colossus, spot: Vector3) -> void:
	while colossus.brain.state != S.IDLE:
		_put_guard(spot)
		await get_tree().physics_frame
	colossus.brain.force_attack(A.BEAM)
	while colossus.brain.attack == A.BEAM:
		_put_guard(spot)
		await get_tree().physics_frame


func test_a_guard_running_across_outpaces_the_beam() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 12.0)
	while colossus.brain.state != S.IDLE:
		await get_tree().physics_frame
	var health := museum.player.health.current
	colossus.brain.force_attack(A.BEAM)
	# round him at 12 m, a run of 6 m/s (the beam turns slower)
	var angle := deg_to_rad(-55.0)
	while colossus.brain.attack == A.BEAM:
		angle += 0.5 / 60.0
		_put_guard(_in_front(colossus, 12.0 * cos(angle), 12.0 * sin(angle)))
		await get_tree().physics_frame
	assert_almost_eq(museum.player.health.current, health, 0.01, "running across, he leaves the beam behind")


func test_phase_three_stands_him_up_and_he_walks_with_stomps() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 9.0)
	var seat := colossus.home.origin
	var stood := watch(colossus.stood_up)
	_hit(colossus, &"uraeus", colossus.max_health * 0.7)
	assert_eq(colossus.phase, 3)
	for i in 60 * 14:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if colossus.standing:
			break
	assert_eq(stood.size(), 1, "he stood up")
	assert_true(colossus.standing)
	var stride := colossus.global_position.distance_to(seat)
	assert_almost_eq(stride, -ColossusMoves.STAND_PELVIS.z, 0.2, "a stride off his throne")
	assert_almost_eq(colossus.rig.part("pelvis").global_position.y, ColossusMoves.STAND_HIPS, 0.25, "his hips at a standing height")
	# the guard at the far end: he walks to him, every footfall announced
	var far := _in_front(colossus, 17.0)
	var start := Vector2(colossus.global_position.x - far.x, colossus.global_position.z - far.z).length()
	var clock := [0.0]
	var lifted := [-10.0]
	var stomps: Array[float] = []
	colossus.telegraphed.connect(func(kind: StringName) -> void:
		if kind == &"stomp":
			lifted[0] = clock[0])
	colossus.struck.connect(func(kind: StringName) -> void:
		if kind == &"stomp":
			stomps.append(clock[0] - lifted[0]))
	for i in 60 * 12:
		clock[0] += 1.0 / 60.0
		_put_guard(far)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	var now := Vector2(colossus.global_position.x - far.x, colossus.global_position.z - far.z).length()
	assert_lt(now, start - 2.0, "he came closer (%.1f -> %.1f m)" % [start, now])
	assert_gt(stomps.size(), 1, "footfalls")
	for gap in stomps:
		assert_true(gap >= Guardian.MIN_TELEGRAPH - 0.02, "a foot up %.2f s before it lands" % gap)
	assert_eq(museum.floor_level.room_at(colossus.global_position + Vector3.UP), &"egypt_colossus", "never out of his hall")


func test_his_fall_leaves_stone_and_his_seal_and_shard_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var colossus := _colossus()
	await _awake(colossus, 9.0)
	var fell := watch(Events.guardian_defeated)
	_hit(colossus, &"uraeus", colossus.health.current + 1.0)
	await physics_frames(2)
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"colossus"))
	var falls := keeper.find_children("*", "ColossusFall", false, false)
	assert_eq(falls.size(), 1, "his fall plays out")
	if falls.size() == 1:
		# his hit zones go with him: their receivers are freed with him (a
		# ray on the falling stone met a freed receiver - the playthrough
		# bot's run, 22.10)
		assert_eq((falls[0] as Node).find_children("*", "Hurtbox", true, false).size(), 0, "nothing left to shoot on the falling stone")
	await _seconds(ColossusFall.TREMBLE + ColossusFall.TOPPLE + 0.3)
	if falls.size() == 1:
		assert_gt((falls[0] as ColossusFall).pieces.size(), 20, "he broke into stone")
	var spot: Vector3 = (museum.floor_level.markers[&"arena_colossus_reward"] as Transform3D).origin
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2, "the seal and the shard")
	for pickup: ProgressPickup in rewards:
		assert_lt(Vector2(pickup.global_position.x - spot.x, pickup.global_position.z - spot.z).length(), 1.5, "in the moonlight")
	for pickup: ProgressPickup in rewards:
		pickup.interact(museum.player)
	assert_true(GameState.seals.has(&"seal_sun"))
	assert_true(GameState.shards.has(&"shard_egypt"))
	museum.free()
	RunState.reset()
	GameState.night += 1
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"colossus"), "he stays fallen")
	assert_eq(get_tree().get_nodes_in_group(ColossusThrone.GROUP).size(), 1, "his empty throne")
	assert_eq(get_tree().get_nodes_in_group(ColossusColumn.GROUP).size(), Egypt.COLUMNS.size(), "the columns stand again")


func test_fleeing_calms_him_back_onto_his_throne() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 9.0)
	_hit(colossus, &"uraeus", colossus.max_health * 0.7)
	for i in 60 * 14:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if colossus.standing:
			break
	assert_true(colossus.standing)
	var calmed := watch(colossus.calmed)
	_put_guard(Floor1Plan.junction(&"j_court_egypt").point_in(&"egypt", 2.5, 0.0))
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_eq(colossus.state, Guardian.State.DORMANT)
	assert_false(colossus.standing, "seated again")
	assert_lt(colossus.global_position.distance_to(colossus.home.origin), 0.05, "on his throne")
	assert_eq(colossus.rig.plates_on, [true, true, true] as Array[bool], "whole again")
	assert_almost_eq(colossus.health.fraction(), 1.0, 0.001)
	assert_eq(colossus.alive_swarms(), 0, "his swarms are gone")
	await _seconds(1.0)
	assert_lt(colossus.global_position.distance_to(colossus.home.origin), 0.05, "and he stays there")


func test_the_palm_hurts_who_stays_in_its_shadow_and_its_wave_spares_who_jumps() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 8.0)
	var spot := _in_front(colossus, 8.0, 1.0)
	# he stays in the shadow: the palm
	await _strike(colossus, A.SLAM, func(_t: float) -> Vector3: return spot)
	var hurt: float = _taken
	assert_true(hurt >= ColossusBrain.SLAM_DAMAGE - 0.01 and hurt < ColossusBrain.SLAM_DAMAGE + ColossusBrain.SLAM_RING.x - 0.01,
			"the palm, not the wave as well: %.1f" % hurt)
	# he steps out of the shadow while it grows, and jumps the wave
	var aside := _in_front(colossus, 8.0, 5.0)
	await _strike(colossus, A.SLAM, func(t: float) -> Vector3: return spot if t < 0.3 else aside + Vector3.UP * 0.6)
	assert_almost_eq(_taken, 0.0, 0.01, "out of the shadow, over the wave")
	# he steps out but stays on the floor: the wave catches him
	await _strike(colossus, A.SLAM, func(t: float) -> Vector3: return spot if t < 0.3 else aside)
	assert_almost_eq(_taken, ColossusBrain.SLAM_RING.x, 0.01, "the wave")


func test_the_low_sweep_is_jumped() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus := _colossus()
	await _awake(colossus, 6.0)
	var spot := _in_front(colossus, 6.0, 0.5)
	await _strike(colossus, A.SWEEP, func(_t: float) -> Vector3: return spot)
	assert_almost_eq(_taken, ColossusBrain.SWEEP_DAMAGE, 0.01, "standing in its band")
	await _strike(colossus, A.SWEEP, func(t: float) -> Vector3:
		var telegraph := ColossusBrain.stage_length(A.SWEEP, ColossusBrain.Stage.TELEGRAPH, 1)
		return spot + (Vector3.UP * 0.6 if t > telegraph else Vector3.ZERO))
	assert_almost_eq(_taken, 0.0, 0.01, "jumping it")


var _taken: float = 0.0


## Forces [param kind] and keeps the guard where [param place] (seconds
## into the attack -> feet) puts him until it is over; _taken = what he
## lost.
func _strike(colossus: Colossus, kind: A, place: Callable) -> void:
	_put_guard(place.call(0.0))
	await get_tree().physics_frame
	while colossus.brain.state != S.IDLE:
		_put_guard(place.call(0.0))
		await get_tree().physics_frame
	var guard := museum.player
	guard.heal(1000000.0)
	var before := guard.health.current
	colossus.brain.force_attack(kind)
	var time := 0.0
	while colossus.brain.attack == kind:
		var at: Vector3 = place.call(time)
		guard.global_position = at + Vector3.UP * 0.05
		guard.velocity = Vector3.ZERO
		await get_tree().physics_frame
		time += 1.0 / Engine.physics_ticks_per_second
	for i in 60:   # the wave rolls on after the attack
		var at: Vector3 = place.call(time)
		guard.global_position = at + Vector3.UP * 0.05
		guard.velocity = Vector3.ZERO
		await get_tree().physics_frame
		time += 1.0 / Engine.physics_ticks_per_second
	_taken = before - guard.health.current
