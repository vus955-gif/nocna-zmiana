extends TestCase
## The Lamassu in the real palace courtyard of Floor I: it sleeps on its
## plinth against the north wall, wakes when the guard crosses the start
## line and walks down off the plinth, announces every attack at least
## 0.6 s ahead and never leaves the court; only its face and crown take
## full damage; a charge into a genius's base stuns it with its face low,
## a charge in the open runs down who stays and skids short of a wall; the
## gust throws the guard back in the open but not behind cover; the
## stomp's ring hurts who stands, not who jumps.

const A := LamassuBrain.Attack
const S := LamassuBrain.State
const ROOM := &"assyria_courtyard"
## The west-east line between the two rows of genii (nothing in the way).
const OPEN_Z := -66.5

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


func _lamassu() -> Lamassu:
	return museum.floor_game.guardians.guardians.get(&"lamassu") as Lamassu


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


## A court floor point [param ahead] m south of the plinth and [param aside]
## m to the bull's left (east).
func _court(lamassu: Lamassu, ahead: float, aside: float = 0.0) -> Vector3:
	var at := lamassu.home.origin - lamassu.home.basis.z * ahead - lamassu.home.basis.x * aside
	at.y = 0.0
	return at


## Wakes it with the guard on the start line and waits out the waking.
func _awake(lamassu: Lamassu) -> void:
	_put_guard((museum.floor_level.markers[&"arena_lamassu_start"] as Transform3D).origin)
	await _seconds(0.3)
	assert_true(lamassu.is_fighting(), "awake")
	await _seconds(LamassuBrain.WAKE_TIME + 0.1)


## Waits until it idles (an attack under way runs out), keeping the guard
## at [param at].
func _idling(lamassu: Lamassu, at: Vector3) -> void:
	for i in 60 * 8:
		if lamassu.brain.state == S.IDLE:
			return
		_put_guard(at)
		museum.player.heal(1000.0)
		await get_tree().physics_frame


## Puts it at [param at] facing [param yaw] (its hooves under it).
func _place(lamassu: Lamassu, at: Vector3, yaw: float) -> void:
	lamassu.global_position = at
	lamassu.rotation.y = yaw
	lamassu.speed = 0.0
	lamassu.velocity = Vector3.ZERO
	lamassu.reset_physics_interpolation()
	lamassu.gait.place(lamassu.global_transform)


func _hit(lamassu: Lamassu, zone: StringName, amount: float) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"pistol"
	info.position = lamassu.global_position + Vector3.UP * 2.0
	lamassu.take_zone_damage(info, zone)
	return info


func test_it_sleeps_on_its_plinth_against_the_north_wall() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	assert_not_null(lamassu, "the real Lamassu, not the stand-in")
	if lamassu == null:
		return
	assert_eq(GuardianKeeper.script_for(&"lamassu"), load("res://src/game/floor1/guardians/lamassu.gd"))
	var post: Transform3D = museum.floor_level.markers[&"guardian_lamassu"]
	assert_lt(Vector2(lamassu.global_position.x - post.origin.x, lamassu.global_position.z - post.origin.z).length(), 0.1, "on its post")
	assert_almost_eq(lamassu.global_position.y, post.origin.y + LamassuPlinth.HEIGHT, 0.05, "up on the plinth")
	assert_eq(lamassu.state, Guardian.State.DORMANT)
	assert_eq(lamassu.arena_room, ROOM)
	assert_not_null(lamassu.plinth)
	assert_lt(lamassu.plinth.global_position.distance_to(post.origin), 0.05, "the plinth under it")
	assert_eq(get_tree().get_nodes_in_group(LamassuPlinth.GROUP).size(), 1)
	assert_eq((lamassu.points.get(&"cover", []) as Array).size(), 6, "four genii and two cedars as cover")
	for leg in 4:
		assert_almost_eq(lamassu.rig.contact(leg).y, LamassuPlinth.HEIGHT, 0.05, "hoof %d on the plinth's top" % leg)
	await _seconds(1.0)
	assert_almost_eq(lamassu.global_position.y, post.origin.y + LamassuPlinth.HEIGHT, 0.05, "it stands still up there")


func test_it_wakes_past_the_start_line_steps_down_and_announces_every_attack_in_time() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(-79.0, 0.0, -48.0))   # the Nimrud gallery: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside the court")
	var down := watch(lamassu.stepped_down)
	var thuds := [0]
	lamassu.gait.landed.connect(func(_leg: int) -> void: thuds[0] += 1)
	_put_guard((museum.floor_level.markers[&"arena_lamassu_start"] as Transform3D).origin)
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake past the start line")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_LAMASSU").to_upper()), museum.hud.boss_name_text())
	assert_eq(lamassu.brain.state, S.WAKING)
	await _seconds(LamassuBrain.WAKE_TIME)
	assert_eq(lamassu.brain.state, S.IDLE, "down and ready")
	assert_lt(lamassu.global_position.y, 0.1, "on the court's floor")
	assert_gt(lamassu.home.origin.distance_to(lamassu.global_position), 3.0, "walked off the front of the plinth")
	assert_true(thuds[0] >= 4, "hooves came down stepping off (%d)" % thuds[0])
	var settled := false
	for i in 60:
		settled = true
		for leg in 4:
			if absf(lamassu.rig.contact(leg).y) > 0.1:
				settled = false
		if settled:
			break
		_put_guard(_court(lamassu, 16.0))
		await get_tree().physics_frame
	assert_true(settled, "every hoof on the floor within a second")
	for i in 60 * 6:
		_put_guard(_court(lamassu, 16.0))
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if not down.is_empty():
			break
	assert_eq(down.size(), 1, "clear of its plinth")
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	var seen := {}
	lamassu.telegraphed.connect(func(kind: StringName) -> void:
		started[kind] = clock[0]
		seen[kind] = true)
	lamassu.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append([kind, clock[0] - float(started[kind])]))
	# far down the court and close by in turn (the court is 27 m deep: 19 m
	# south of the plinth is its door); the dice fixed, so the fight repeats
	lamassu.brain.seed_with(7)
	var spots: Array[Vector3] = [_court(lamassu, 19.0), _court(lamassu, 6.0, 3.0), _court(lamassu, 17.0, -6.0), _court(lamassu, 5.0, 1.0),
		_court(lamassu, 8.0, -5.0), _court(lamassu, 19.0, 2.0), _court(lamassu, 6.0, -2.0), _court(lamassu, 16.0, 5.0)]
	var outside := 0
	for i in 60 * 40:
		clock[0] += 1.0 / 60.0
		if i % 300 == 0:
			_put_guard(spots[(i / 300) % spots.size()])
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if museum.floor_level.room_at(lamassu.global_position + Vector3.UP) != ROOM:
			outside += 1
	assert_gt(gaps.size(), 6, "it attacked (%d)" % gaps.size())
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "%s announced %.2f s ahead" % [gap[0], gap[1]])
	for kind: StringName in [&"charge", &"gust", &"stomp"]:
		assert_true(seen.has(kind), "%s in phase 1: %s" % [kind, str(seen.keys())])
	assert_false(seen.has(&"hop"), "no hops before phase 3")
	assert_eq(outside, 0, "never out of the court")


func test_only_its_face_and_crown_take_full_damage() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var full := lamassu.health.current
	var stone := _hit(lamassu, &"body", 100.0)
	assert_almost_eq(lamassu.health.current, full - 10.0, 0.01, "the stone: a tenth")
	assert_true(stone.blocked, "a grey marker")
	var wing := _hit(lamassu, &"wing_l", 100.0)
	assert_almost_eq(lamassu.health.current, full - 20.0, 0.01, "a wing: a tenth")
	assert_true(wing.blocked)
	assert_almost_eq(lamassu.wing_damage[0], 100.0, 0.01, "but it chips")
	var crown := _hit(lamassu, &"crown", 40.0)
	assert_almost_eq(lamassu.health.current, full - 60.0, 0.01, "the crown: all of it")
	assert_true(crown.weak_point, "a gold marker")
	var face := _hit(lamassu, &"face", 40.0)
	assert_almost_eq(lamassu.health.current, full - 120.0, 0.01, "the face: half again")
	assert_true(face.weak_point)
	# the crown breaks off after enough and the stump still counts
	_hit(lamassu, &"crown", Lamassu.CROWN_HEALTH)
	assert_false(lamassu.rig.crown_on, "the crown shot off")
	var before := lamassu.health.current
	var stump := _hit(lamassu, &"crown", 10.0)
	assert_almost_eq(lamassu.health.current, before - 10.0, 0.01, "the stump is still a weak point")
	assert_true(stump.weak_point)
	# a wing tip breaks off after enough
	_hit(lamassu, &"wing_l", Lamassu.WING_HEALTH)
	assert_false(lamassu.rig.tips_on[0], "the left tip broken off")
	assert_true(lamassu.rig.tips_on[1])
	# the weapons' own path: a ray from the guard's eyes finds the face
	# before the beard
	await _idling(lamassu, _court(lamassu, 12.0))
	lamassu.brain.force_attack(A.STOMP)   # it stands still a moment
	await physics_frames(2)
	var space := lamassu.get_world_3d().direct_space_state
	var aim := lamassu.rig.face_point()
	var eye := lamassu.global_position - lamassu.global_basis.z * 7.0 + Vector3.UP * 1.6
	var hit := Hitscan.ray(space, eye, eye + (aim - eye) * 1.5)
	assert_false(hit.is_empty(), "a hit on the face")
	if not hit.is_empty():
		var hurtbox := hit["hurtbox"] as Hurtbox
		assert_not_null(hurtbox, "a zone, not a wall")
		if hurtbox != null:
			assert_eq((hurtbox.receiver as GuardianZone).zone, &"face")
			assert_true(hurtbox.weak_point)


func test_a_charge_into_a_genius_base_stuns_it_with_its_face_low() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	# the guard hides west of the north-west genius; the bull east of it on
	# the same line, facing west
	var genius := Vector3(-87.0, 0.0, -71.0)
	var hiding := genius + Vector3(-2.6, 0.0, 0.0)
	await _idling(lamassu, hiding)
	_place(lamassu, Vector3(-76.0, 0.0, -71.0), PI * 0.5)
	var crashed := watch(lamassu.crashed)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	lamassu.brain.force_attack(A.CHARGE)
	for i in 60 * 5:
		_put_guard(hiding)
		await get_tree().physics_frame
		if lamassu.brain.state == S.STUNNED:
			break
	assert_eq(crashed.size(), 1, "it ran into the base")
	assert_eq(lamassu.brain.state, S.STUNNED, "and reels")
	assert_true(lamassu.cover_hit(genius + Vector3(1.3, 0.5, 0.0)), "the base counts as cover")
	assert_lt(Vector2(lamassu.global_position.x - genius.x, lamassu.global_position.z - genius.z).length(), 4.0, "at the base")
	assert_almost_eq(museum.player.health.current, health, 0.01, "the guard behind it is untouched")
	await _seconds(0.5)
	assert_lt(lamassu.rig.face_point().y, 2.4, "its face hangs within a shot's reach")
	await _seconds(LamassuBrain.STUN_TIME[0])
	assert_ne(lamassu.brain.state, S.STUNNED, "it gathers itself")


func test_a_charge_in_the_open_runs_down_who_stays_and_skids_short_of_a_wall() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var guard := Vector3(-80.0, 0.0, OPEN_Z)
	await _idling(lamassu, guard)
	_place(lamassu, Vector3(-70.0, 0.0, OPEN_Z), PI * 0.5)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	var crashed := watch(lamassu.crashed)
	lamassu.brain.force_attack(A.CHARGE)
	var top := 0.0
	while lamassu.brain.attack == A.CHARGE:
		_put_guard(guard)
		top = maxf(top, lamassu.gait.speed)
		await get_tree().physics_frame
	assert_lt(museum.player.health.current, health - LamassuBrain.CHARGE_DAMAGE + 0.5, "run down")
	assert_gt(top, 10.0, "at a gallop")
	assert_eq(crashed.size(), 0, "nothing in its way")
	assert_ne(lamassu.brain.state, S.STUNNED)
	# toward the west wall, the guard stepping aside as it runs: it sees the
	# wall and skids to a stop short of it
	var far := Vector3(-92.5, 0.0, OPEN_Z)
	await _idling(lamassu, far)
	_place(lamassu, Vector3(-70.0, 0.0, OPEN_Z), PI * 0.5)
	lamassu.brain.force_attack(A.CHARGE)
	var skidded := false
	var outside := 0
	for i in 60 * 6:
		_put_guard(far if lamassu.brain.stage == LamassuBrain.Stage.TELEGRAPH else far + Vector3(0.0, 0.0, 5.0))
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if lamassu.brain.attack == A.CHARGE and lamassu.brain.stage == LamassuBrain.Stage.RECOVER:
			skidded = true
		if museum.floor_level.room_at(lamassu.global_position + Vector3.UP) != ROOM:
			outside += 1
		if lamassu.brain.attack != A.CHARGE:
			break
	assert_true(skidded, "it skidded")
	assert_eq(crashed.size(), 0, "without hitting the wall")
	assert_ne(lamassu.brain.state, S.STUNNED, "and is not stunned by a wall")
	assert_gt(lamassu.global_position.x, -94.0 + 0.3, "stopped short of the wall")
	assert_lt(lamassu.global_position.x, -84.0, "but ran most of the way")
	assert_eq(outside, 0, "never out of the court")


func test_the_gust_throws_the_guard_back_in_the_open_but_not_behind_cover() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var open := Vector3(-78.75, 0.0, -60.5)
	await _idling(lamassu, open)
	_place(lamassu, Vector3(-78.75, 0.0, OPEN_Z), PI)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	lamassu.brain.force_attack(A.GUST)
	while lamassu.brain.stage == LamassuBrain.Stage.TELEGRAPH:
		_put_guard(open)
		await get_tree().physics_frame
	await _seconds(0.8)
	var thrown := museum.player.global_position - open
	assert_gt(Vector2(thrown.x, thrown.z).length(), 3.0, "thrown back (%.1f m)" % Vector2(thrown.x, thrown.z).length())
	assert_gt(thrown.z, 0.0, "away from it")
	assert_lt(museum.player.health.current, health - LamassuBrain.GUST_DAMAGE + 0.5, "and peppered with grit")
	# behind a genius: the base stops the wind
	var genius := Vector3(-87.0, 0.0, -71.0)
	var hiding := genius + Vector3(0.0, 0.0, 2.6)
	await _idling(lamassu, hiding)
	_place(lamassu, Vector3(-87.0, 0.0, -76.0), PI)
	_put_guard(hiding)
	museum.player.heal(100000.0)
	health = museum.player.health.current
	lamassu.brain.force_attack(A.GUST)
	while lamassu.brain.stage == LamassuBrain.Stage.TELEGRAPH:
		_put_guard(hiding)
		await get_tree().physics_frame
	await _seconds(0.8)
	var moved := museum.player.global_position - hiding
	assert_lt(Vector2(moved.x, moved.z).length(), 0.5, "behind the base he stays put")
	assert_almost_eq(museum.player.health.current, health, 0.01, "untouched")


func test_the_stomps_ring_hurts_who_stands_and_not_who_jumps() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := Vector3(-78.75, 0.0, -61.5)
	await _idling(lamassu, spot)
	_place(lamassu, Vector3(-78.75, 0.0, OPEN_Z), PI)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	lamassu.brain.force_attack(A.STOMP)
	while lamassu.brain.attack == A.STOMP:
		_put_guard(spot)
		await get_tree().physics_frame
	assert_lt(museum.player.health.current, health - LamassuBrain.STOMP_RING.x + 0.5, "the ring caught him standing")
	assert_gt(museum.player.health.current, health - LamassuBrain.STOMP_DAMAGE - LamassuBrain.STOMP_RING.x + 1.0, "but not the hooves, 5 m off")
	# and one who jumps the ring
	await _idling(lamassu, spot)
	_place(lamassu, Vector3(-78.75, 0.0, OPEN_Z), PI)
	museum.player.heal(100000.0)
	health = museum.player.health.current
	lamassu.brain.force_attack(A.STOMP)
	while lamassu.brain.attack == A.STOMP:
		var in_air := lamassu.brain.stage != LamassuBrain.Stage.TELEGRAPH
		_put_guard(spot + (Vector3.UP * 1.0 if in_air else Vector3.ZERO))
		await get_tree().physics_frame
	assert_almost_eq(museum.player.health.current, health, 0.01, "jumped it")


# --- phases 2 and 3 -------------------------------------------------------------------

## Hits it through its face down to [param fraction] of its health.
## Its plinth is in the exhibits' navigation (QA Q4): no navmesh runs
## through the stone at the court's floor, so the relief warriors it calls
## walk round it, not into it.
func test_its_plinth_is_a_stone_the_exhibits_walk_round() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(4)
	var level := museum.floor_level
	while level.navigation.is_baking():
		await get_tree().physics_frame
	await physics_frames(2)
	var plinth := _lamassu().plinth
	var map := level.walk_region.get_navigation_map()
	var half := LamassuPlinth.SIZE * 0.5 - Vector3(0.2, 0.0, 0.2)
	var inside := 0
	for ix in 5:
		for iz in 9:
			var local := Vector3(lerpf(-half.x, half.x, ix / 4.0), 0.05, lerpf(-half.z, half.z, iz / 8.0))
			var at := plinth.to_global(local)
			var near := NavigationServer3D.map_get_closest_point(map, at)
			var on_floor := near.y < plinth.global_position.y + 0.3
			var under := plinth.to_local(near)
			if on_floor and absf(under.x) < LamassuPlinth.SIZE.x * 0.5 and absf(under.z) < LamassuPlinth.SIZE.z * 0.5:
				inside += 1
	assert_eq(inside, 0, "no navmesh on the court's floor under the plinth")


func _wound(lamassu: Lamassu, fraction: float) -> void:
	var amount := (lamassu.health.current - lamassu.max_health * fraction + 1.0) / Lamassu.FACE
	_hit(lamassu, &"face", amount)


func test_phase_two_blazes_its_cracks_and_calls_the_relief_warriors() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := _court(lamassu, 12.0)
	await _idling(lamassu, spot)
	var before := museum.exhibits().size()
	assert_false(lamassu.rig.cracked)
	_wound(lamassu, 0.6)
	assert_eq(lamassu.phase, 2)
	var reliefs := (lamassu.points.get(&"relief", []) as Array).size()
	assert_eq(reliefs, 6, "six relief slabs")
	var called := museum.exhibits().slice(before)
	assert_eq(called.size(), reliefs, "one warrior off each relief")
	for exhibit: Enemy in called:
		assert_true(exhibit.summoned)
		assert_eq(museum.floor_level.room_at(exhibit.global_position + Vector3.UP * 0.5), ROOM, "in the court")
	var shifted := false
	var attacked := [0]
	lamassu.telegraphed.connect(func(_kind: StringName) -> void: attacked[0] += 1)
	for i in 60 * 6:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if lamassu.brain.state == S.PHASE_SHIFT:
			shifted = true
			assert_eq(attacked[0], 0, "no attacks while it shifts")
			if lamassu.brain.state_progress() > 0.6:
				break
	assert_true(shifted, "it played the shift")
	assert_true(lamassu.rig.cracked, "the cracks blaze")
	assert_gt(lamassu.moves.pose.cracks, 0.5, "and glow")
	await _idling(lamassu, spot)
	assert_true(lamassu.rig.cracked, "for good")
	assert_eq(lamassu.brain.phase, 2)


func test_phase_three_hops_onto_the_guards_shadow_and_never_onto_cover() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := _court(lamassu, 12.0)
	await _idling(lamassu, spot)
	_wound(lamassu, 0.3)
	assert_eq(lamassu.phase, 3)
	await _idling(lamassu, spot)
	assert_eq(lamassu.brain.phase, 3)
	assert_true(lamassu.rig.cracked, "the cracks blaze from the first shift")
	# a hop: the shadow where he stands, a second and more before it lands
	var clock := [0.0]
	var told := [-1.0]
	var landed := [-1.0]
	lamassu.telegraphed.connect(func(kind: StringName) -> void:
		if kind == &"hop":
			told[0] = clock[0])
	lamassu.struck.connect(func(kind: StringName) -> void:
		if kind == &"hop":
			landed[0] = clock[0])
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	lamassu.brain.force_attack(A.HOP)
	var shadow := lamassu.hop_to
	assert_lt(Vector2(shadow.x - spot.x, shadow.z - spot.z).length(), 1.5, "the shadow under the guard")
	assert_eq(museum.floor_level.room_at(shadow + Vector3.UP), ROOM, "in the court")
	var top := 0.0
	while lamassu.brain.attack == A.HOP and lamassu.brain.stage != LamassuBrain.Stage.RECOVER:
		clock[0] += 1.0 / 60.0
		_put_guard(spot)
		top = maxf(top, lamassu.global_position.y)
		await get_tree().physics_frame
	assert_true(told[0] >= 0.0 and landed[0] > told[0], "told and landed")
	assert_true(landed[0] - told[0] >= 1.0, "the shadow shows %.2f s before it lands" % (landed[0] - told[0]))
	assert_gt(top, 1.5, "it flew")
	assert_lt(Vector2(lamassu.global_position.x - shadow.x, lamassu.global_position.z - shadow.z).length(), 1.0, "down on its shadow")
	assert_lt(lamassu.global_position.y, 0.1, "on the floor")
	assert_lt(museum.player.health.current, health - LamassuBrain.HOP_DAMAGE + 0.5, "the guard under it is crushed")
	var rings := museum.floor_game.guardians.find_children("*", "ShockwaveRing", true, false)
	assert_gt(rings.size(), 0, "a ring rolls out")
	# behind a genius: it never lands on the base
	var genius := Vector3(-87.0, 0.0, -71.0)
	var hiding := genius + Vector3(0.0, 0.0, 2.2)
	await _idling(lamassu, hiding)
	_place(lamassu, Vector3(-87.0, 0.0, -58.0), 0.0)
	lamassu.brain.force_attack(A.HOP)
	var landing := lamassu.hop_to
	assert_gt(Vector2(landing.x - genius.x, landing.z - genius.z).length(), Lamassu.COVER_REACH + 1.0, "clear of the base")
	assert_eq(museum.floor_level.room_at(landing + Vector3.UP), ROOM)
	while lamassu.brain.attack == A.HOP:
		_put_guard(hiding)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_eq(museum.floor_level.room_at(lamassu.global_position + Vector3.UP), ROOM, "landed in the court")


# --- the fall, the leash, shots from outside ------------------------------------------

func test_its_fall_leaves_alabaster_and_its_seal_and_shard_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var lamassu := _lamassu()
	await _awake(lamassu)
	var fell := watch(Events.guardian_defeated)
	_hit(lamassu, &"face", lamassu.health.current + 1.0)
	await physics_frames(2)
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"lamassu"))
	var falls := keeper.find_children("*", "LamassuFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	await _seconds(LamassuFall.TREMBLE + LamassuFall.KNEEL * 0.7)
	if falls.size() == 1:
		assert_eq((falls[0] as LamassuFall).wings.size(), 4, "the wings broke off whole")
	await _seconds(LamassuFall.KNEEL * 0.3 + 0.3)
	if falls.size() == 1:
		assert_gt((falls[0] as LamassuFall).pieces.size(), 15, "it broke into alabaster")
	var spot: Vector3 = (museum.floor_level.markers[&"arena_lamassu_reward"] as Transform3D).origin
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2, "the seal and the shard")
	for pickup: ProgressPickup in rewards:
		assert_lt(Vector2(pickup.global_position.x - spot.x, pickup.global_position.z - spot.z).length(), 1.5, "in the moonlight")
	for pickup: ProgressPickup in rewards:
		pickup.interact(museum.player)
	assert_true(GameState.seals.has(&"seal_wing"))
	assert_true(GameState.shards.has(&"shard_assyria"))
	museum.free()
	RunState.reset()
	GameState.night += 1
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"lamassu"), "it stays fallen")
	assert_eq(get_tree().get_nodes_in_group(LamassuPlinth.GROUP).size(), 1, "its plinth stands empty")


func test_a_killing_blow_in_the_arc_of_a_hop_still_kneels_on_the_floor() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := _court(lamassu, 12.0)
	await _idling(lamassu, spot)
	_wound(lamassu, 0.3)
	await _idling(lamassu, spot)
	assert_eq(lamassu.brain.phase, 3)
	museum.player.heal(100000.0)
	lamassu.brain.force_attack(A.HOP)
	for i in 60 * 4:
		_put_guard(spot)
		await get_tree().physics_frame
		if lamassu.global_position.y > 1.5:
			break
	assert_gt(lamassu.global_position.y, 1.5, "in the air")
	await _killed_in_the_air(lamassu)


func test_a_killing_blow_while_it_hovers_through_the_phase_three_shift_still_kneels_on_the_floor() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := _court(lamassu, 12.0)
	await _idling(lamassu, spot)
	_wound(lamassu, 0.3)
	for i in 60 * 4:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if lamassu.global_position.y > 0.6:
			break
	assert_eq(lamassu.brain.state, S.PHASE_SHIFT)
	assert_gt(lamassu.global_position.y, 0.6, "hovering")
	await _killed_in_the_air(lamassu)


## Kills it where it hangs and checks that its fall starts on the court's
## floor, the hooves under it.
func _killed_in_the_air(lamassu: Lamassu) -> void:
	var keeper := museum.floor_game.guardians
	_hit(lamassu, &"face", lamassu.health.current + 1.0)
	await physics_frames(2)
	var falls := keeper.find_children("*", "LamassuFall", false, false)
	assert_eq(falls.size(), 1, "its fall plays out")
	if falls.size() != 1:
		return
	var fall := falls[0] as LamassuFall
	var pivot := fall.get_node("Pivot") as Node3D
	assert_lt(absf(pivot.global_position.y), 0.1, "it kneels on the floor, not in mid-air")
	var lowest := INF
	for leg in 4:
		lowest = minf(lowest, fall.get("_rig").contact(leg).y)
	assert_lt(absf(lowest), 0.3, "its hooves stand on the floor")


func test_fleeing_calms_it_back_onto_its_plinth_whole() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	await _awake(lamassu)
	var spot := _court(lamassu, 12.0)
	await _idling(lamassu, spot)
	_hit(lamassu, &"crown", Lamassu.CROWN_HEALTH + 1.0)
	_hit(lamassu, &"wing_r", Lamassu.WING_HEALTH + 1.0)
	_wound(lamassu, 0.6)
	assert_false(lamassu.rig.crown_on)
	assert_false(lamassu.rig.tips_on[1])
	for i in 60 * 4:
		_put_guard(spot)
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if lamassu.rig.cracked:
			break
	assert_true(lamassu.rig.cracked)
	var calmed := watch(lamassu.calmed)
	_put_guard(Vector3(-79.0, 0.0, -48.0))   # the Nimrud gallery
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_eq(lamassu.state, Guardian.State.DORMANT)
	assert_lt(lamassu.global_position.distance_to(lamassu.home.origin), 0.1, "back on its plinth")
	assert_almost_eq(lamassu.health.fraction(), 1.0, 0.001)
	assert_true(lamassu.rig.crown_on, "its crown back")
	assert_true(lamassu.rig.tips_on[1], "its wing whole")
	assert_false(lamassu.rig.cracked, "the clean stone")
	assert_eq(lamassu.brain.state, S.DORMANT)
	await _seconds(1.0)
	assert_lt(lamassu.global_position.distance_to(lamassu.home.origin), 0.1, "and it stays there")
	for leg in 4:
		assert_almost_eq(lamassu.rig.contact(leg).y, LamassuPlinth.HEIGHT, 0.05, "hoof %d on the plinth" % leg)


func test_a_hit_from_outside_the_court_does_nothing_and_does_not_wake_it() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _lamassu()
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(-79.0, 0.0, -48.0))   # the Nimrud gallery, through its door
	await _seconds(0.3)
	var full := lamassu.health.current
	_hit(lamassu, &"face", 50.0)
	await physics_frames(2)
	assert_almost_eq(lamassu.health.current, full, 0.001, "it shrugs the shot off")
	assert_eq(lamassu.state, Guardian.State.DORMANT)
	assert_eq(woke.size(), 0, "and sleeps on")
