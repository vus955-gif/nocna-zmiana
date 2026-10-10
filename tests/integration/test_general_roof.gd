extends TestCase
## The General's phase 2 in the real garden: under two thirds of his health
## he leaps onto the tea house eave (the perch), shoots two volleys of
## ember arrows onto their marks (the first mark leads the guard, the others
## stand round it; the arrows fly at least 0.75 s and hurt whoever stays in
## a mark) and leaps down onto a marked spot (announced all through the
## crouch and the flight; 20 within 1.5 m); a hit in his face up there
## brings him down after the volley under way; fleeing while he is up there
## calms him back onto his stand.

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const ROOM := &"asia_garden"
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


func _put_guard(at: Vector3) -> void:
	var guard := museum.player
	if guard.health.max_health < 10000.0:
		guard.health.max_health = 100000.0
		guard.health.reset()
	guard.global_position = at + Vector3.UP * 0.05
	guard.velocity = Vector3.ZERO


func _front(general: General, ahead: float, aside: float = 0.0) -> Vector3:
	return general.home.origin - general.home.basis.z * ahead - general.home.basis.x * aside


func _awake(general: General) -> void:
	_put_guard(START)
	await _seconds(0.3)
	await _seconds(GeneralBrain.WAKE_TIME + 0.15)


## Hits his back down to [param fraction] of his health.
func _wound(general: General, fraction: float) -> void:
	var amount := (general.health.current - general.max_health * fraction + 1.0) / General.BACK
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.direction = -general.global_basis.z
	info.position = general.rig.part("back").global_position
	general.take_zone_damage(info, &"back")


## Keeps the guard at [param at] until [param condition] holds (or
## [param limit] s pass).
func _until(condition: Callable, at: Vector3, limit: float) -> bool:
	for i in roundi(limit * 60.0):
		if condition.call():
			return true
		_put_guard(at)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
	return condition.call()


func test_under_two_thirds_he_leaps_onto_the_eave_shoots_two_volleys_and_comes_down_on_his_mark() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	assert_true(general.has_perch, "the perch on the eave")
	assert_true(general.brain.can_roof)
	var perch: Transform3D = museum.floor_level.markers[&"arena_general_perch"]
	assert_lt(general.perch.origin.distance_to(perch.origin), 0.05)
	await _awake(general)
	var spot := _front(general, 8.0)
	_wound(general, 0.6)
	assert_eq(general.phase, 2)
	var told := []
	general.telegraphed.connect(func(kind: StringName) -> void: told.append(kind))
	assert_true(await _until(func() -> bool: return general.brain.attack == A.LEAP_UP, spot, 10.0), "he goes for the roof")
	var from := general.global_position
	# the crouch, then the flight
	await _seconds(GeneralBrain.LEAP_CROUCH + 0.3)
	assert_true(general.kinematic, "flying")
	assert_gt(general.global_position.y, from.y + 0.5, "off the ground")
	assert_true(await _until(func() -> bool: return general.brain.state == S.ROOF, spot, 3.0), "up on the roof")
	assert_lt(general.global_position.distance_to(perch.origin), 0.1, "on the perch")
	assert_true(general.brain.on_roof)
	assert_true(general.moves.pose.bow_in_hand, "the bow in his fist")
	# the first volley: a mark per arrow, the first on the guard
	assert_true(await _until(func() -> bool: return general.brain.attack == A.VOLLEY, spot, 3.0), "a volley")
	assert_eq(general.volley_spots.size(), GeneralBrain.ARROWS[1], "four marks in phase 2")
	await physics_frames(3)
	assert_lt(Vector2(general.volley_spots[0].x - spot.x, general.volley_spots[0].z - spot.z).length(), 1.0, "the first mark on the guard")
	for i in range(1, general.volley_spots.size()):
		var apart := Vector2(general.volley_spots[i].x - general.volley_spots[0].x, general.volley_spots[i].z - general.volley_spots[0].z).length()
		assert_almost_eq(apart, General.VOLLEY_RING, 0.3, "mark %d on the ring" % i)
		assert_eq(museum.floor_level.room_at(general.volley_spots[i] + Vector3.UP), ROOM, "in the garden")
	var health := museum.player.health.current
	var loosed := watch(general.struck)
	assert_true(await _until(func() -> bool: return general.brain.stage == T.STRIKE, spot, 2.0), "loosed")
	await physics_frames(2)
	assert_eq(general.arrows.size(), GeneralBrain.ARROWS[1], "four arrows in the air")
	var first := general.arrows[0] as GeneralArrow
	assert_not_null(first)
	var landed: Array[Vector3] = []
	first.landed.connect(func(at: Vector3) -> void: landed.append(at))
	var mark := general.volley_spots[0]
	var flight := 0.0
	while landed.is_empty() and flight < 3.0:
		_put_guard(mark)
		await get_tree().physics_frame
		flight += 1.0 / 60.0
	assert_eq(landed.size(), 1, "it came down")
	assert_true(flight >= 0.7, "a flight of at least 0.75 s (%.2f)" % flight)
	if landed.size() == 1:
		assert_lt(Vector2(landed[0].x - mark.x, landed[0].z - mark.z).length(), 0.4, "on its mark")
	assert_lt(museum.player.health.current, health - GeneralBrain.ARROW_DAMAGE + 0.5, "the guard who stayed in the mark is hit")
	# the second volley, then down onto a marked spot
	assert_true(await _until(func() -> bool: return general.brain.attack == A.VOLLEY and general.brain.stage == T.STRIKE and loosed.size() >= 2, spot, 6.0), "a second volley")
	assert_true(await _until(func() -> bool: return general.brain.attack == A.LEAP_DOWN, spot, 6.0), "two volleys: down")
	var landing := general.landing
	assert_eq(museum.floor_level.room_at(landing + Vector3.UP), ROOM, "the landing in the garden")
	assert_lt(Vector2(landing.x - spot.x, landing.z - spot.z).length(), 4.0, "near the guard")
	assert_almost_eq(landing.y, 0.0, 0.05)
	museum.player.heal(100000.0)
	health = museum.player.health.current
	var warned := general.brain.current_stage_length()
	assert_true(warned >= 1.3, "the landing announced %.2f s ahead" % warned)
	assert_true(await _until(func() -> bool: return general.brain.stage == T.STRIKE, landing, 3.0), "landed")
	assert_lt(general.global_position.distance_to(landing), 0.5, "on his mark (the guard under him shoved aside)")
	assert_lt(museum.player.health.current, health - GeneralBrain.LAND_DAMAGE + 0.5, "the guard under him is struck")
	await _seconds(0.3)
	assert_false(general.kinematic, "on his feet")
	assert_false(general.brain.on_roof)
	assert_true(await _until(func() -> bool: return general.brain.state == S.GUARD, spot, 3.0))
	assert_true(general.moves.pose.hands_on[0] > 0.99 and general.moves.pose.hands_on[1] > 0.99, "both fists on the hilt again")
	assert_false(general.moves.pose.bow_in_hand)


func test_a_hit_in_the_face_on_the_roof_brings_him_down_after_one_volley() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 7.0)
	_wound(general, 0.6)
	assert_true(await _until(func() -> bool: return general.brain.state == S.ROOF, spot, 12.0), "up on the roof")
	assert_true(await _until(func() -> bool: return general.brain.attack == A.VOLLEY and general.brain.stage == T.TELEGRAPH, spot, 3.0))
	var full := general.health.current
	var info := DamageInfo.make(40.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.direction = (general.global_position - museum.player.global_position).normalized()
	info.position = general.rig.part("face").global_position
	general.take_zone_damage(info, &"face")
	assert_almost_eq(general.health.current, full - 40.0, 0.01, "no guard up there: the face takes all of it")
	assert_eq(general.brain.attack, A.VOLLEY, "the volley under way goes on")
	var volleys := [0]
	general.struck.connect(func(kind: StringName) -> void:
		if kind == &"volley":
			volleys[0] += 1)
	assert_true(await _until(func() -> bool: return general.brain.attack == A.LEAP_DOWN, spot, 6.0), "then down")
	assert_eq(volleys[0], 1, "after that one volley")


func test_fleeing_while_he_is_on_the_roof_calms_him_back_onto_his_stand() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 7.0)
	_wound(general, 0.6)
	assert_true(await _until(func() -> bool: return general.brain.state == S.ROOF, spot, 12.0), "up on the roof")
	var calmed := watch(general.calmed)
	_put_guard(Vector3(13.5, 0.0, -50.0))   # the China hall
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1, "calmed")
	assert_eq(general.state, Guardian.State.DORMANT)
	assert_lt(general.global_position.distance_to(general.home.origin), 0.1, "on his post")
	assert_false(general.kinematic)
	assert_false(general.brain.on_roof)
	assert_almost_eq(general.health.current, general.max_health, 0.01, "whole again")
	assert_eq(general.arrows.size(), 0, "no arrows left")


## His last hit: in the back, from behind.
func _slay(general: General) -> void:
	var info := DamageInfo.make((general.health.current + 1.0) / General.BACK, DamageInfo.Kind.BALLISTIC, museum.player)
	info.direction = -general.global_basis.z
	info.position = general.rig.part("back").global_position
	general.take_zone_damage(info, &"back")


func test_a_volley_loosed_just_before_his_fall_does_not_outlive_him() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	_wound(general, 0.6)
	assert_true(await _until(func() -> bool: return general.brain.attack == A.VOLLEY and general.brain.stage == T.STRIKE, spot, 14.0), "a volley is loosed")
	await physics_frames(2)
	var shot: Array = general.arrows.duplicate()
	assert_gt(shot.size(), 0, "arrows in the air")
	museum.player.heal(100000.0)
	var health := museum.player.health.current
	_slay(general)
	await physics_frames(2)
	assert_false(is_instance_valid(general), "he fell")
	for arrow in shot:
		assert_false(is_instance_valid(arrow), "an arrow of his is gone with him")
	await _seconds(2.0)
	assert_almost_eq(museum.player.health.current, health, 0.01, "none of them hurt the guard after the fight")


func test_dying_in_mid_leap_he_kneels_on_the_gravel_not_in_the_air() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	_wound(general, 0.6)
	assert_true(await _until(func() -> bool: return general._flying and general.global_position.y > 1.0, spot, 14.0), "in the air on the way to the eave")
	var high := general.global_position.y
	_slay(general)
	await physics_frames(2)
	var falls := museum.floor_game.guardians.find_children("*", "GeneralFall", false, false)
	assert_eq(falls.size(), 1, "his fall")
	if falls.is_empty():
		return
	var fall := falls[0] as GeneralFall
	assert_gt(high, 1.0)
	assert_almost_eq(fall._at.origin.y, 0.0, 0.05, "the kneel starts on the floor")
	assert_lt(fall._rig.model.global_position.y, 0.5, "and the model with it (%.2f)" % fall._rig.model.global_position.y)


func test_dying_on_the_eave_he_kneels_on_the_eave() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 7.0)
	_wound(general, 0.6)
	assert_true(await _until(func() -> bool: return general.brain.state == S.ROOF, spot, 14.0), "up on the roof")
	var up := general.global_position.y
	_slay(general)
	await physics_frames(2)
	var falls := museum.floor_game.guardians.find_children("*", "GeneralFall", false, false)
	assert_eq(falls.size(), 1)
	if not falls.is_empty():
		assert_almost_eq((falls[0] as GeneralFall)._at.origin.y, up, 0.05, "on the eave where he stood")


func test_only_a_roof_perch_of_the_level_takes_over_the_greybox_perch() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	var greybox := general.perch
	var decoy := Node3D.new()
	decoy.name = "roof_perch"
	museum.add_child(decoy)   # a stray node outside the level
	decoy.global_position = general.home.origin + Vector3(3.0, 5.0, 0.0)
	general._search_roof_perch()
	assert_lt(general.perch.origin.distance_to(greybox.origin), 0.001, "the stray node outside the level is not searched")
	general._perch_searched = false
	var spot := Node3D.new()
	spot.name = "roof_perch"
	museum.floor_level.add_child(spot)
	spot.global_position = general.home.origin + Vector3(-3.0, 4.0, 0.0)
	general._search_roof_perch()
	assert_lt(general.perch.origin.distance_to(spot.global_position), 0.001, "the dressed tea house's own perch (under the level) takes over")
	decoy.free()


func test_in_the_leaps_his_feet_hang_under_him_within_the_legs_reach() -> void:
	_museum()
	await physics_frames(2)
	var general := _general()
	await _awake(general)
	var spot := _front(general, 8.0)
	_wound(general, 0.6)
	var worst := -INF
	var flying := 0
	# up onto the eave, then (the volleys over) down onto the marked spot
	for i in 60 * 40:
		if general.brain.attack == A.LEAP_DOWN and general.brain.stage == T.STRIKE:
			break
		_put_guard(spot)
		museum.player.heal(100000.0)
		await get_tree().physics_frame
		if general._flying:
			flying += 1
			for leg in 2:
				var hip := general.global_transform * general.rig.hip_at(general.moves.pose, leg)
				worst = maxf(worst, hip.distance_to(general.feet.foot(leg)) - general.rig.leg_reach(leg))
	assert_gt(flying, 60, "both flights seen (%d frames)" % flying)
	assert_lt(worst, 0.05, "no ankle left behind in the air: %.2f m past the leg's reach" % worst)
