extends TestCase
## The Samurai General in the real Japanese garden of Floor I: the armour
## hangs on its stand behind the post; he wakes once the guard crosses the
## start line (the HUD's bar), assembles and draws, then announces every
## attack at least 0.6 s ahead and never leaves the garden; in his guard a
## hit from the front glances off and from behind his back takes it, his
## face takes all of it once the guard is open; the taser stuns him and a
## fist finishes the stun once; the dash's lane follows the guard then
## locks, the lunge cuts whoever stays in it and a miss leaves his back
## open; a hit from outside the garden does nothing.

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const ROOM := &"asia_garden"
const POST := Vector3(17.5, 0.0, -75.0)
const START := Vector3(8.0, 0.0, -65.5)

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	GameState.new_game()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _general() -> General:
	return museum.floor_game.guardians.guardians.get(&"general") as General


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


## A garden floor point [param ahead] m in front of the post (toward the
## broken wall) and [param aside] m to the General's left.
func _front(general: General, ahead: float, aside: float = 0.0) -> Vector3:
	return general.home.origin - general.home.basis.z * ahead - general.home.basis.x * aside


## Wakes him with the guard at the start line and waits out the waking.
func _awake(general: General) -> void:
	_put_guard(START)
	await _seconds(0.3)
	assert_true(general.is_fighting(), "awake")
	await _seconds(GeneralBrain.WAKE_TIME + 0.15)


## Waits until he stands in his guard, keeping the guard at [param at].
func _guarding(general: General, at: Vector3) -> void:
	for i in 60 * 8:
		if general.brain.state == S.GUARD:
			return
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame


func _hit(general: General, zone: StringName, amount: float, direction: Vector3, kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC, finish: bool = false) -> DamageInfo:
	var info := DamageInfo.make(amount, kind, museum.player)
	info.weapon = &"fists" if finish else &"pistol"
	info.can_finish = finish
	info.direction = direction.normalized()
	info.position = general.global_position + Vector3.UP * 2.0
	general.take_zone_damage(info, zone)
	return info


## A hit travelling from the guard's side toward him ([param from_behind]:
## from behind his back).
func _toward(general: General, from_behind: bool = false) -> Vector3:
	return -general.global_basis.z if from_behind else general.global_basis.z


func test_the_armour_hangs_on_its_stand_behind_the_post_in_the_garden() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	assert_not_null(general, "the real General, not the stand-in")
	if general == null:
		return
	assert_eq(GuardianKeeper.script_for(&"general"), load("res://src/game/floor1/guardians/general.gd"))
	assert_lt(general.global_position.distance_to(POST), 0.1, "on his post")
	assert_eq(general.state, Guardian.State.DORMANT)
	assert_eq(general.arena_room, ROOM)
	assert_not_null(general.stand)
	assert_eq(get_tree().get_nodes_in_group(&"general_stand").size(), 1, "one stand, the keeper's")
	var behind := general.home.origin + general.home.basis.z * General.STAND_BACK
	assert_lt(general.stand.global_position.distance_to(behind), 0.1, "the stand behind the post")
	assert_eq(museum.floor_level.room_at(behind + Vector3.UP), ROOM, "in the garden")
	# asleep: the helmet hangs on the stand, not over the post; the eyes dark
	var head := general.rig.part("head").global_position
	assert_lt(Vector2(head.x - behind.x, head.z - behind.z).length(), 0.6, "the helmet on the stand (%s)" % str(head))
	assert_almost_eq(general.moves.pose.eyes, 0.0, 0.001)
	assert_almost_eq(general.max_health, 1000.0 * DifficultyRules.HEALTH[DifficultyRules.index(museum.game.difficulty)], 0.01)
	await _seconds(1.0)
	assert_lt(general.global_position.distance_to(POST), 0.1, "he stays")


func test_he_wakes_past_the_start_line_assembles_draws_and_announces_every_attack_in_the_garden() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(13.5, 0.0, -50.0))   # the China hall: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside the garden")
	_put_guard(START)
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake past the start line")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_GENERAL").to_upper()), museum.hud.boss_name_text())
	assert_eq(general.brain.state, S.WAKING)
	await _seconds(GeneralBrain.ASSEMBLE_TIME * 0.5)
	assert_true(general.moves.pose.assembly > 0.3 and general.moves.pose.assembly < 0.7, "assembling (%.2f)" % general.moves.pose.assembly)
	await _seconds(GeneralBrain.ASSEMBLE_TIME * 0.5 + 0.1)
	var head := general.rig.part("head").global_position
	assert_lt(Vector2(head.x - POST.x, head.z - POST.z).length(), 0.5, "the helmet over the post now")
	assert_almost_eq(general.moves.pose.eyes, 1.0, 0.01, "the eyes lit")
	await _seconds(GeneralBrain.DRAW_TIME + 0.1)
	assert_eq(general.brain.state, S.GUARD, "drawn, in chudan")
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	var seen := {}
	general.telegraphed.connect(func(kind: StringName) -> void:
		started[kind] = clock[0]
		seen[kind] = true)
	general.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append([kind, clock[0] - float(started[kind])]))
	var spots: Array[Vector3] = [_front(general, 9.0), _front(general, 6.0, 4.0), _front(general, 2.4, 0.5), _front(general, 10.0, -5.0)]
	var outside := 0
	for i in 60 * 40:
		clock[0] += 1.0 / 60.0
		if i % 420 == 0:
			_put_guard(spots[(i / 420) % spots.size()])
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if museum.floor_level.room_at(general.global_position + Vector3.UP) != ROOM:
			outside += 1
	assert_gt(gaps.size(), 5, "he attacked (%d)" % gaps.size())
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.02, "%s announced %.2f s ahead" % [gap[0], gap[1]])
	assert_true(seen.has(&"dash"), "the dash cut: %s" % str(seen.keys()))
	assert_eq(outside, 0, "never out of the garden")


func test_his_guard_turns_hits_from_the_front_his_back_and_face_take_them() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	await _guarding(general, _front(general, 7.0))
	var full := general.health.current
	var blocks := watch(general.blocked_hit)
	var front := _hit(general, &"armour", 100.0, _toward(general))
	assert_true(front.blocked, "a grey marker")
	assert_eq(blocks.size(), 1, "it glanced off")
	assert_almost_eq(general.health.current, full, 0.01, "nothing got through his guard")
	var face_front := _hit(general, &"face", 100.0, _toward(general))
	assert_true(face_front.blocked and general.health.current == full, "the blade covers his face in chudan")
	var back := _hit(general, &"back", 100.0, _toward(general, true))
	assert_almost_eq(general.health.current, full - 75.0, 0.01, "the agemaki on his back: x0.75")
	assert_true(back.weak_point, "a gold marker")
	_hit(general, &"armour", 100.0, _toward(general, true))
	assert_almost_eq(general.health.current, full - 90.0, 0.01, "the armour from behind: x0.15")
	# open in a telegraph: the face from the front takes all of it
	general.brain.force_attack(A.DASH)
	await physics_frames(2)
	var face := _hit(general, &"face", 40.0, _toward(general))
	assert_false(face.blocked)
	assert_almost_eq(general.health.current, full - 130.0, 0.01, "the face: all of it")
	assert_true(face.weak_point)
	# the weapons' own path: a ray from the front finds the face hurtbox
	var space := general.get_world_3d().direct_space_state
	var aim := general.rig.part("face").global_position
	var eye := general.global_position - general.global_basis.z * 5.0 + Vector3.UP * 2.3
	var hit := Hitscan.ray(space, eye, eye + (aim - eye) * 1.5)
	assert_false(hit.is_empty(), "a hit on the face")
	if not hit.is_empty():
		var hurtbox := hit["hurtbox"] as Hurtbox
		assert_not_null(hurtbox, "a zone, not a wall")
		if hurtbox != null:
			assert_eq((hurtbox.receiver as GuardianZone).zone, &"face")
			assert_true(hurtbox.weak_point)


func test_the_taser_opens_him_and_a_fist_finishes_the_stun_once() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	await _guarding(general, _front(general, 3.0))
	var full := general.health.current
	var stuns := watch(general.stunned)
	var finishes := watch(general.finished_off)
	var blocks := watch(general.blocked_hit)
	_hit(general, &"armour", 10.0, _toward(general), DamageInfo.Kind.ELECTRIC)
	assert_eq(blocks.size(), 0, "the taser conducts through the blade")
	assert_eq(stuns.size(), 1, "stunned")
	assert_eq(general.brain.state, S.STUNNED)
	assert_almost_eq(general.health.current, full - 1.5, 0.01, "its own damage through the armour")
	await physics_frames(3)
	_hit(general, &"armour", 20.0, _toward(general), DamageInfo.Kind.BLUNT, true)
	assert_eq(finishes.size(), 1, "the finisher")
	assert_almost_eq(general.health.current, full - 1.5 - GeneralBrain.FINISH_FRACTION * general.max_health, 0.01, "a share of his health")
	assert_eq(general.brain.state, S.REEL, "he reels")
	var after := general.health.current
	_hit(general, &"armour", 20.0, _toward(general), DamageInfo.Kind.BLUNT, true)
	assert_eq(finishes.size(), 1, "once a stun")
	assert_almost_eq(general.health.current, after - 3.0, 0.01, "a plain fist on the armour now")
	await _guarding(general, _front(general, 3.0))
	assert_false(general.brain.can_be_stunned(), "immune for a while")
	_hit(general, &"armour", 10.0, _toward(general), DamageInfo.Kind.ELECTRIC)
	assert_eq(blocks.size(), 0, "nor is it blocked now")
	assert_eq(stuns.size(), 1, "no second stun yet")


func test_the_dash_lane_follows_then_locks_the_lunge_cuts_who_stays_a_miss_opens_his_back() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	await _guarding(general, spot)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	general.brain.force_attack(A.DASH)
	await physics_frames(3)
	var lane := general.dash_lane()
	assert_not_null(lane, "the lane on the gravel")
	var first_target := general.dash_target
	# the guard steps aside early: the lane follows him
	var aside := spot + general.home.basis.x * 2.5
	for i in 12:
		_put_guard(aside)
		await get_tree().physics_frame
	assert_gt(general.dash_target.distance_to(first_target), 1.0, "the lane follows the guard")
	# until the lock: from then on it stays
	while general.brain.stage == T.TELEGRAPH and not general.dash_locked:
		_put_guard(aside)
		await get_tree().physics_frame
	var locked := general.dash_target
	var away := aside + general.home.basis.x * 2.5
	for i in 8:
		_put_guard(away)
		await get_tree().physics_frame
	assert_lt(general.dash_target.distance_to(locked), 0.05, "locked")
	_put_guard(locked)
	var from := general.global_position
	var dashes := watch(general.struck)
	while general.brain.stage != T.RECOVER and general.brain.state == S.ATTACK:
		await get_tree().physics_frame
	assert_eq(dashes.size(), 1)
	assert_true(general.brain.landed, "the blade found him")
	assert_lt(museum.player.health.current, health - GeneralBrain.DASH_DAMAGE + 1.0, "cut (%.0f)" % (health - museum.player.health.current))
	var run := general.global_position - from
	assert_gt(run.length(), locked.distance_to(from) - 0.3, "through his place (and on, where the gravel is clear)")
	assert_false(general.brain.back_open(), "a hit: no stumble")
	assert_eq(museum.floor_level.room_at(general.global_position + Vector3.UP), ROOM, "still in the garden")
	assert_false(general.kinematic or general.collision_layer == 0, "on his feet, solid again")
	# a miss: the guard steps out of the locked lane
	museum.player.heal(100000.0)
	health = museum.player.health.current
	spot = general.global_position - general.global_basis.z * 7.0
	await _guarding(general, spot)
	general.brain.force_attack(A.DASH)
	while general.brain.stage == T.TELEGRAPH and not general.dash_locked:
		_put_guard(spot)
		await get_tree().physics_frame
	var dodge := general.dash_target + general.global_basis.x * 3.0
	while general.brain.stage != T.RECOVER and general.brain.state == S.ATTACK:
		_put_guard(dodge)
		await get_tree().physics_frame
	assert_almost_eq(museum.player.health.current, health, 0.01, "stepped out of the lane: untouched")
	assert_true(general.brain.back_open(), "the miss leaves his back open")
	assert_gt(general.brain.current_stage_length(), GeneralBrain.per_phase(GeneralBrain.DASH_HIT_RECOVER, 1), "longer than after a hit")
	assert_eq(museum.floor_level.room_at(general.global_position + Vector3.UP), ROOM)
	var space := general.get_world_3d().direct_space_state
	var clear := INF
	for angle in 8:
		var dir := Vector3(cos(angle * TAU / 8.0), 0.0, sin(angle * TAU / 8.0))
		var from_ := general.global_position + Vector3.UP * 0.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from_, from_ + dir * 3.0, Layers.WORLD, [general.get_rid()]))
		if not hit.is_empty():
			clear = minf(clear, from_.distance_to(hit["position"]))
	assert_gt(clear, 0.6, "he stopped clear of walls and rocks (%.2f)" % clear)


func test_a_rock_in_the_way_ends_the_lane_short() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	# the rock south-west of the post at (13.5, -78): the guard hides behind it
	var rock := Vector3(13.5, 0.0, -78.0)
	var hide := rock + (rock - POST).normalized() * 2.2
	await _guarding(general, hide)
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	general.brain.force_attack(A.DASH)
	while general.brain.state == S.ATTACK and general.brain.stage != T.RECOVER:
		_put_guard(hide)
		await get_tree().physics_frame
	assert_almost_eq(museum.player.health.current, health, 0.01, "the rock is cover")
	assert_gt(general.global_position.distance_to(hide), 1.5, "he stopped short, before the rock")


func test_a_hit_from_outside_the_garden_does_nothing() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	_put_guard(Vector3(13.5, 0.0, -50.0))   # the China hall
	await physics_frames(2)
	var full := general.health.current
	_hit(general, &"face", 100.0, Vector3.FORWARD)
	assert_almost_eq(general.health.current, full, 0.01, "it glances off")
	assert_eq(general.state, Guardian.State.DORMANT, "and does not wake him")


func test_in_a_lunge_his_feet_go_with_him_and_stay_within_the_legs_reach() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 9.0)
	await _guarding(general, spot)
	museum.player.heal(100000.0)
	general.brain.force_attack(A.DASH)
	var from := general.global_position
	var lunging := 0
	var carried := 0
	var worst := -INF
	while general.brain.state == S.ATTACK and general.brain.stage != T.RECOVER:
		_put_guard(spot)
		await get_tree().physics_frame
		if not general.kinematic:
			continue
		lunging += 1
		carried += int(general.feet.carried)
		for leg in 2:
			var hip := general.global_transform * general.rig.hip_at(general.moves.pose, leg)
			worst = maxf(worst, hip.distance_to(general.feet.foot(leg)) - general.rig.leg_reach(leg))
	assert_gt(lunging, 5, "he lunged (%d frames)" % lunging)
	assert_gt(general.global_position.distance_to(from), 5.0, "a real lunge")
	assert_gt(carried, lunging / 2, "the feet are carried along (%d of %d)" % [carried, lunging])
	assert_lt(worst, 0.05, "no ankle left behind: %.2f m past the leg's reach" % worst)


func test_a_guard_who_falls_in_the_telegraph_leaves_no_lane_lit_and_no_new_attack_comes() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	await _guarding(general, spot)
	general.brain.force_attack(A.DASH)
	await physics_frames(10)
	assert_not_null(general.dash_lane(), "the lane is lit")
	museum.player.alive = false
	var told := watch(general.telegraphed)
	await _seconds(0.3)
	assert_true(general.dash_lane() == null, "the lane went out with the guard")
	await _seconds(3.0)
	assert_eq(general.brain.state, S.GUARD, "the attack ran out and he stands in his guard")
	assert_false(general.kinematic, "on his feet")
	assert_eq(told.size(), 0, "nothing new is announced to a fallen guard")
	assert_true(general.dash_lane() == null)


func test_a_guard_who_falls_mid_lunge_sees_him_finish_it_on_his_feet() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	await _guarding(general, spot)
	general.brain.force_attack(A.DASH)
	while general.brain.stage != T.STRIKE:
		_put_guard(spot)
		await get_tree().physics_frame
	await physics_frames(3)
	assert_true(general.kinematic, "lunging")
	assert_not_null(general.dash_lane())
	var mid := general.global_position
	museum.player.alive = false
	await physics_frames(2)
	assert_true(general.dash_lane() == null, "the lane went out")
	await _seconds(1.0)
	assert_gt(general.global_position.distance_to(mid), 0.5, "he flew his lunge to its end, not hung mid-lane")
	assert_false(general.kinematic, "then on his feet")
	assert_eq(general.collision_layer, Layers.ENEMY, "solid again")
	assert_almost_eq(general.global_position.y, 0.0, 0.05, "on the gravel")
	await _seconds(3.0)
	assert_eq(general.brain.state, S.GUARD, "the recovery over, in his guard")
	assert_lt(general.feet.foot(0).distance_to(general.global_position), 1.0, "his feet beside him")


func test_dawn_puts_out_his_eyes() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	await _seconds(0.2)
	assert_gt(general._eye_light.light_energy, 0.1, "the ember eyes light the helmet")
	general.freeze()
	assert_almost_eq(general._eye_light.light_energy, 0.0, 0.0001, "the stone General has no eye-glow")
	assert_almost_eq(general._glint_light.light_energy, 0.0, 0.0001)
