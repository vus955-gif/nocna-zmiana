extends TestCase
## The Centaur from the metope in the real Parthenon gallery of Floor I: it
## stands in its metope, wakes when the guard steps in and tears free (the
## slab bursts), gallops round him within the gallery announcing every
## attack at least 0.6 s ahead, takes full damage only in its marble chest;
## its javelins come down on their marks; it rears only up close; a charge
## into a plinth stuns it; it calls Lapiths in phase 2 and throws two
## javelins in phase 3; its fall leaves marble, the seal and the shard, for
## good; the guard fleeing calms it back into its metope.

const A := CentaurBrain.Attack
const S := CentaurBrain.State
const ROOM := &"greece_parthenon"

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


func _centaur() -> Centaur:
	return museum.floor_game.guardians.guardians.get(&"centaur") as Centaur


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


## A gallery floor point [param along] m east of the post's line and
## [param across] m south of it (the gallery runs east-west).
func _hall(centaur: Centaur, along: float, across: float = 0.0) -> Vector3:
	return centaur.home.origin + Vector3(along, 0.0, across)


## Wakes it with the guard at the arena's start line and waits out the waking.
func _awake(centaur: Centaur) -> void:
	_put_guard(_hall(centaur, -15.0))
	await _seconds(0.3)
	assert_true(centaur.is_fighting(), "awake")
	await _seconds(CentaurBrain.WAKE_TIME + 0.1)


## Waits until it roams (an attack under way runs out), keeping the guard at
## [param at].
func _roaming(centaur: Centaur, at: Vector3) -> void:
	for i in 60 * 6:
		if centaur.brain.state == S.ROAM:
			return
		_put_guard(at)
		museum.player.heal(1000.0)
		await get_tree().physics_frame


func _hit(centaur: Centaur, zone: StringName, amount: float, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, museum.player)
	info.weapon = &"pistol"
	info.position = centaur.global_position + Vector3.UP * 2.0
	centaur.take_zone_damage(info, zone)
	return info


func test_it_stands_in_its_metope_in_the_middle_of_the_gallery() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	assert_not_null(centaur, "the real Centaur, not the stand-in")
	if centaur == null:
		return
	assert_eq(GuardianKeeper.script_for(&"centaur"), load("res://src/game/floor1/guardians/centaur.gd"))
	var post: Transform3D = museum.floor_level.markers[&"guardian_centaur"]
	assert_lt(centaur.global_position.distance_to(post.origin), 0.1, "on its post")
	assert_eq(centaur.state, Guardian.State.DORMANT)
	assert_eq(centaur.arena_room, ROOM)
	assert_not_null(centaur.metope)
	assert_lt(centaur.metope.global_position.distance_to(post.origin), 0.05, "in its metope")
	assert_false(centaur.metope.broken)
	assert_eq(get_tree().get_nodes_in_group(CentaurMetope.GROUP).size(), 1)
	assert_eq((centaur.points.get(&"lapith", []) as Array).size(), 4, "the Lapiths' places by the pediments")
	await _seconds(1.0)
	assert_lt(centaur.global_position.distance_to(post.origin), 0.1, "it stands still")


func test_it_wakes_tears_free_and_announces_every_attack_in_time_never_leaving_the_gallery() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(-70.0, 0.0, 44.0))   # the Metope room: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside the gallery")
	var freed := watch(centaur.broke_free)
	_put_guard(_hall(centaur, -15.0))
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake past the start line")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_CENTAUR").to_upper()), museum.hud.boss_name_text())
	assert_eq(centaur.brain.state, S.WAKING)
	await _seconds(CentaurBrain.WAKE_TIME)
	assert_eq(freed.size(), 1, "it tore free")
	assert_true(centaur.metope.broken, "the slab burst")
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	var seen := {}
	centaur.telegraphed.connect(func(kind: StringName) -> void:
		started[kind] = clock[0]
		seen[kind] = true)
	centaur.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append([kind, clock[0] - float(started[kind])]))
	var spots: Array[Vector3] = [_hall(centaur, -12.0), _hall(centaur, 9.0, 3.0), _hall(centaur, -6.0, -4.0), _hall(centaur, 14.0, 2.0)]
	var outside := 0
	var top_speed := 0.0
	for i in 60 * 45:
		clock[0] += 1.0 / 60.0
		if i % 300 == 0:
			_put_guard(spots[(i / 300) % spots.size()])
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		top_speed = maxf(top_speed, centaur.gait.speed)
		if museum.floor_level.room_at(centaur.global_position + Vector3.UP) != ROOM:
			outside += 1
	assert_gt(gaps.size(), 6, "it attacked")
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "%s announced %.2f s ahead" % [gap[0], gap[1]])
	for kind: StringName in [&"throw", &"charge"]:
		assert_true(seen.has(kind), "%s in phase 1: %s" % [kind, str(seen.keys())])
	assert_eq(outside, 0, "never out of the gallery")
	assert_gt(top_speed, 8.5, "it galloped faster than the guard sprints")


func test_only_its_chest_takes_full_damage() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	var full := centaur.health.current
	var horse := _hit(centaur, &"body", 100.0)
	assert_almost_eq(centaur.health.current, full - 25.0, 0.01, "the horse: a quarter")
	assert_true(horse.blocked, "a grey marker")
	_hit(centaur, &"torso", 100.0)
	assert_almost_eq(centaur.health.current, full - 75.0, 0.01, "the human torso: a half")
	_hit(centaur, &"head", 40.0)
	assert_almost_eq(centaur.health.current, full - 125.0, 0.01, "the head: x1.25")
	var chest := _hit(centaur, &"chest", 40.0)
	assert_almost_eq(centaur.health.current, full - 165.0, 0.01, "the chest: all of it")
	assert_true(chest.weak_point, "a gold marker")
	# the weapons' own path: a ray from the guard's eyes finds the chest
	# before the torso
	centaur.brain.force_attack(A.KICK)   # it stands still a moment
	await physics_frames(2)
	var space := centaur.get_world_3d().direct_space_state
	var aim := centaur.rig.part("chest").global_position
	var eye := centaur.global_position - centaur.global_basis.z * 6.0 + Vector3.UP * 1.6
	var hit := Hitscan.ray(space, eye, eye + (aim - eye) * 1.5)
	assert_false(hit.is_empty(), "a hit on the chest")
	if not hit.is_empty():
		var hurtbox := hit["hurtbox"] as Hurtbox
		assert_not_null(hurtbox, "a zone, not a wall")
		if hurtbox != null:
			assert_eq((hurtbox.receiver as GuardianZone).zone, &"chest")
			assert_true(hurtbox.weak_point)


func test_a_javelin_comes_down_on_its_mark_and_hurts_who_stays_there() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	var spot := _hall(centaur, -12.0, 1.0)
	await _roaming(centaur, spot)
	var health := museum.player.health.current
	var landed: Array[Vector3] = []
	var marks: Array[Vector3] = []
	centaur.brain.force_attack(A.THROW)
	while centaur.brain.attack == A.THROW and centaur.brain.stage == CentaurBrain.Stage.TELEGRAPH:
		_put_guard(spot)
		await get_tree().physics_frame
	marks.append(centaur.throw_marks[1])
	var javelin := centaur.javelins.back() as CentaurJavelin
	assert_not_null(javelin, "a javelin thrown")
	if javelin == null:
		return
	javelin.landed.connect(func(at: Vector3) -> void: landed.append(at))
	for i in 120:
		_put_guard(spot)
		await get_tree().physics_frame
		if not landed.is_empty():
			break
	assert_eq(landed.size(), 1, "it came down")
	if landed.size() == 1:
		assert_lt(Vector2(landed[0].x - marks[0].x, landed[0].z - marks[0].z).length(), 0.35, "on its mark")
	assert_lt(museum.player.health.current, health - 10.0, "the guard who stayed on the mark is hit")
	assert_true(javelin.stuck, "it sticks in the floor")
	# one he walks away from as it flies
	await _roaming(centaur, spot)
	museum.player.heal(100000.0)
	health = museum.player.health.current
	centaur.brain.force_attack(A.THROW)
	while centaur.brain.attack == A.THROW and centaur.brain.stage == CentaurBrain.Stage.TELEGRAPH:
		_put_guard(spot)
		await get_tree().physics_frame
	for i in 90:
		_put_guard(spot + Vector3(0.0, 0.0, 5.0))
		await get_tree().physics_frame
	assert_almost_eq(museum.player.health.current, health, 0.01, "off the mark, untouched")
	await _seconds(CentaurJavelin.STUCK_TIME)
	assert_false(is_instance_valid(javelin), "the javelin crumbles away")


func test_it_rears_only_up_close_and_its_hooves_hurt_on_the_mark() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	var kicks := [0]
	centaur.telegraphed.connect(func(kind: StringName) -> void:
		if kind == &"kick" or kind == &"buck":
			kicks[0] += 1)
	for i in 60 * 12:
		_put_guard(centaur.global_position + Vector3(14.0, 0.0, 0.0) if centaur.global_position.x < -44.0 else centaur.global_position - Vector3(14.0, 0.0, 0.0))
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_eq(kicks[0], 0, "no hooves at a distance")
	await _roaming(centaur, centaur.global_position - centaur.global_basis.z * 12.0)
	var health := museum.player.health.current
	centaur.brain.force_attack(A.KICK)
	var mark := centaur.to_global(Vector3(0.0, 0.0, -CentaurBrain.KICK_REACH))
	while centaur.brain.attack == A.KICK:
		_put_guard(Vector3(mark.x, centaur.global_position.y, mark.z))
		await get_tree().physics_frame
	assert_lt(museum.player.health.current, health - CentaurBrain.KICK_DAMAGE + 0.5, "under the hooves")


func test_a_charge_into_a_plinth_stuns_it() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	# the guard before the east plinth of the south row, the centaur west of
	# him on the same line (past the middle plinth); he steps aside as it runs
	var plinth := Vector3(-35.0, 0.0, 48.5)
	var guard := plinth + Vector3(-2.6, 0.0, 0.0)
	await _roaming(centaur, guard)
	_place(centaur, Vector3(-42.0, 0.0, 48.5), -PI * 0.5)
	var stunned := watch(centaur.crashed)
	centaur.brain.force_attack(A.CHARGE)
	var dodged := guard + Vector3(0.0, 0.0, -4.0)
	for i in 60 * 4:
		_put_guard(guard if centaur.brain.stage == CentaurBrain.Stage.TELEGRAPH else dodged)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if centaur.brain.state == S.STUNNED:
			break
	assert_eq(stunned.size(), 1, "it ran into the plinth")
	assert_eq(centaur.brain.state, S.STUNNED, "and reels")
	assert_lt(Vector2(centaur.global_position.x - plinth.x, centaur.global_position.z - plinth.z).length(), 2.6, "at the plinth")
	var health := centaur.health.current
	_hit(centaur, &"chest", 20.0)
	assert_almost_eq(centaur.health.current, health - 20.0 * CentaurBrain.STUN_WEAK_FACTOR, 0.01, "its chest open")
	await _seconds(CentaurBrain.STUN_TIME[0] + 0.2)
	assert_ne(centaur.brain.state, S.STUNNED, "it gathers itself")


func test_the_charge_runs_down_who_stays_in_its_lane() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	# north of the metope's stump, between the plinth rows
	var guard := Vector3(-36.0, 0.0, 39.6)
	await _roaming(centaur, guard)
	_place(centaur, Vector3(-50.0, 0.0, 39.6), -PI * 0.5)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	centaur.brain.force_attack(A.CHARGE)
	while centaur.brain.attack == A.CHARGE:
		_put_guard(guard)
		await get_tree().physics_frame
	assert_lt(museum.player.health.current, health - CentaurBrain.CHARGE_DAMAGE + 0.5, "trampled")


## Puts it at [param at] facing [param yaw] (its hooves under it).
func _place(centaur: Centaur, at: Vector3, yaw: float) -> void:
	centaur.global_position = at
	centaur.rotation.y = yaw
	centaur.speed = 0.0
	centaur.reset_physics_interpolation()
	centaur.gait.place(centaur.global_transform)


func test_phase_two_calls_lapiths_and_phase_three_throws_in_pairs() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	var spot := _hall(centaur, -12.0)
	_hit(centaur, &"chest", centaur.max_health * 0.4)
	assert_eq(centaur.phase, 2)
	for i in 60 * 8:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if centaur.alive_lapiths() > 0:
			break
	assert_eq(centaur.alive_lapiths(), CentaurBrain.LAPITHS[1], "Lapiths step out")
	var kind := &"hoplite" if ResourceLoader.exists(Centaur.LAPITH_PATH) else &"knight"
	var lapith := centaur.lapiths[0] as Enemy
	var model := NightSpawner.make(kind)
	assert_eq(lapith.get_script(), model.get_script(), "a %s" % kind)
	model.free()
	var ends := {}
	for node: Node3D in centaur.lapiths:
		ends[node.global_position.x < centaur.home.origin.x] = true
		assert_eq(museum.floor_level.room_at(node.global_position + Vector3.UP), ROOM, "in the gallery")
	assert_eq(ends.size(), 2, "from both pediment ends")
	_hit(centaur, &"chest", centaur.health.current - centaur.max_health * 0.3)
	assert_eq(centaur.phase, 3)
	for i in 60 * 10:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if centaur.brain.pair:
			break
	assert_true(centaur.brain.pair, "the metope's piece torn off, a javelin in each hand")
	assert_false(centaur.rig.part("slab").visible)
	await _roaming(centaur, spot)
	var before := centaur.javelins.size()
	centaur.brain.force_attack(A.THROW)
	while centaur.brain.attack == A.THROW:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_eq(centaur.javelins.size(), before + 2, "two javelins at once")


func test_its_fall_leaves_marble_and_its_seal_and_shard_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var centaur := _centaur()
	await _awake(centaur)
	var fell := watch(Events.guardian_defeated)
	_hit(centaur, &"chest", centaur.health.current + 1.0)
	await physics_frames(2)
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"centaur"))
	var falls := keeper.find_children("*", "CentaurFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	await _seconds(CentaurFall.TREMBLE + CentaurFall.COLLAPSE + 0.3)
	if falls.size() == 1:
		assert_gt((falls[0] as CentaurFall).pieces.size(), 15, "it broke into marble")
	var spot: Vector3 = (museum.floor_level.markers[&"arena_centaur_reward"] as Transform3D).origin
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2, "the seal and the shard")
	for pickup: ProgressPickup in rewards:
		assert_lt(Vector2(pickup.global_position.x - spot.x, pickup.global_position.z - spot.z).length(), 1.5, "in the moonlight")
	for pickup: ProgressPickup in rewards:
		pickup.interact(museum.player)
	assert_true(GameState.seals.has(&"seal_owl"))
	assert_true(GameState.shards.has(&"shard_greece"))
	museum.free()
	RunState.reset()
	GameState.night += 1
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"centaur"), "it stays fallen")
	var slabs := get_tree().get_nodes_in_group(CentaurMetope.GROUP)
	assert_eq(slabs.size(), 1)
	if slabs.size() == 1:
		assert_true((slabs[0] as CentaurMetope).broken, "its metope empty")


func test_fleeing_calms_it_back_into_its_metope() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var centaur := _centaur()
	await _awake(centaur)
	_hit(centaur, &"chest", centaur.max_health * 0.4)
	for i in 60 * 8:
		_put_guard(_hall(centaur, -12.0))
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if centaur.alive_lapiths() > 0:
			break
	var lapiths := centaur.lapiths.duplicate()
	var calmed := watch(centaur.calmed)
	_put_guard(Vector3(-70.0, 0.0, 44.0))
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_eq(centaur.state, Guardian.State.DORMANT)
	assert_lt(centaur.global_position.distance_to(centaur.home.origin), 0.1, "back on its post")
	assert_false(centaur.metope.broken, "in its metope again")
	assert_almost_eq(centaur.health.fraction(), 1.0, 0.001)
	assert_eq(centaur.alive_lapiths(), 0, "its Lapiths gone")
	await physics_frames(2)
	for node in lapiths:
		assert_false(is_instance_valid(node), "freed")
	await _seconds(1.0)
	assert_lt(centaur.global_position.distance_to(centaur.home.origin), 0.1, "and it stays there")
