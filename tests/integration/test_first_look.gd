extends TestCase
## The first look at a found weapon (owner's note 44, plan
## 2026-10-21-animacje-fpp): taken from its pickup, a weapon is looked over
## for about a second once it is up in the hands and all is calm - never
## with an exhibit hunting the guard close by - and a shot, a blow or a
## switch cuts the look short smoothly. A weapon carried from the start of
## a night is not looked over.

class Hunter:
	extends Node3D
	var brain := EnemyBrain.new()


var guard: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 0)
	add_child(guard)


func _find(id: StringName) -> ViewmodelRig:
	guard.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	guard.weapons.select_id(id)
	guard.weapons.found(id)
	return guard.weapons.view_of(id) as ViewmodelRig


func _hunter(at: Vector3, hunting: bool = true) -> Hunter:
	var hunter := Hunter.new()
	hunter.position = at
	hunter.add_to_group(&"enemies")
	hunter.brain.state = EnemyBrain.State.HUNT if hunting else EnemyBrain.State.DORMANT
	add_child(hunter)
	return hunter


## Seconds (process frames) until [param rig] starts its first look; -1 when
## it does not within [param limit] s.
func _until_look(rig: ViewmodelRig, limit: float) -> float:
	var t := 0.0
	while t < limit:
		await get_tree().process_frame
		t += 1.0 / 60.0
		if rig.looking_over() > 0.0:
			return t
	return -1.0


func test_a_found_weapon_is_looked_over_once_it_is_up() -> void:
	var rig := _find(&"shotgun")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_true(guard.weapons.first_look_waiting(&"shotgun"))
	var started := await _until_look(rig, 1.5)
	assert_gt(started, ViewmodelMotion.draw_time(&"shotgun") * 0.6, "not before it is up (%.2f s)" % started)
	assert_lt(started, 1.0, "but soon (%.2f s)" % started)
	assert_false(guard.weapons.first_look_waiting(&"shotgun"), "looked over once")
	var most_yaw := 0.0
	var least_yaw := 0.0
	var frames := 0
	while rig.looking_over() > 0.0 and frames < 200:
		await get_tree().process_frame
		frames += 1
		var yaw := rig.model.rotation.y - rig._framing_turn().y
		most_yaw = maxf(most_yaw, yaw)
		least_yaw = minf(least_yaw, yaw)
	assert_almost_eq(frames / 60.0, rig.first_look_time(), 0.1, "about a second (%.2f s)" % (frames / 60.0))
	assert_gt(most_yaw, 0.5, "turned to show its side (%.2f rad)" % most_yaw)
	assert_lt(least_yaw, -0.15, "and swung across to show the other (%.2f rad)" % least_yaw)
	await get_tree().process_frame
	assert_lt(rig.model.transform.origin.distance_to(rig._framing_xform.origin), 0.002, "back in the hands")


func test_a_handgun_is_rolled_right_over_in_the_hand() -> void:
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.0), 0.0)
	var least_roll := 0.0
	var frames := 0
	while rig.looking_over() > 0.0 and frames < 200:
		await get_tree().process_frame
		frames += 1
		least_roll = minf(least_roll, rig.model.rotation.z - rig._framing_turn().z)
	assert_lt(least_roll, -0.3, "rolled over to show its other side (%.2f rad)" % least_roll)


func test_a_weapon_carried_from_the_start_of_the_night_is_not_looked_over() -> void:
	Loadout.grant(guard, &"pistol", GameState)
	guard.weapons.select_id(&"pistol")
	var rig := guard.weapons.view_of(&"pistol") as ViewmodelRig
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_lt(await _until_look(rig, 1.5), 0.0)


func test_never_with_a_hunter_close_by_it_waits_for_the_calm() -> void:
	var hunter := _hunter(Vector3(0, 0, -8))
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_lt(await _until_look(rig, 2.0), 0.0, "a hunter 8 m off: no look")
	assert_true(guard.weapons.first_look_waiting(&"pistol"), "still to be looked over")
	hunter.brain.state = EnemyBrain.State.SEARCH
	var started := await _until_look(rig, 1.0)
	assert_gt(started, 0.0, "the hunt is off: looked over at once")


func test_a_far_hunter_or_a_sleeping_exhibit_is_no_fight() -> void:
	_hunter(Vector3(0, 0, -25))
	_hunter(Vector3(2, 0, -2), false)
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.0), 0.0)


func test_a_hunter_coming_near_cuts_the_look() -> void:
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.0), 0.0)
	_hunter(Vector3(0, 0, -6))
	# seen at the next check (FirstLook.CHECK_EVERY), let go of in LOOK_LET_GO
	for i in roundi((FirstLook.CHECK_EVERY + ViewmodelRig.LOOK_LET_GO) * 60.0) + 6:
		await get_tree().process_frame
	assert_eq(rig.looking_over(), 0.0, "the fight comes first")


func test_a_shot_cuts_the_look_short_smoothly() -> void:
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.0), 0.0)
	for i in 20:
		await get_tree().process_frame
	assert_true(guard.weapons.try_fire())
	var cut := await _widest_step(rig, 22)
	assert_eq(rig.looking_over(), 0.0, "let go quickly")
	# the same shot with no look: what the shot's own kick (gun-feel)
	# moves; letting go of the look adds no jump of its own to it
	await physics_frames(60)
	assert_true(guard.weapons.try_fire())
	var kick := await _widest_step(rig, 22)
	assert_lt(cut, kick + 0.02, "without a jump (%.3f m; the shot alone %.3f m)" % [cut, kick])


## The widest move of any part of [param rig] between two frames over
## [param frames] process frames.
func _widest_step(rig: ViewmodelRig, frames: int) -> float:
	var last := FpCheck.snapshot(guard.weapons, rig)
	var widest := 0.0
	for i in frames:
		await get_tree().process_frame
		var now := FpCheck.snapshot(guard.weapons, rig)
		widest = maxf(widest, float(FpCheck.moved(last, now, rig)[0]))
		last = now
	return widest


func test_switched_away_it_is_looked_over_when_drawn_again() -> void:
	guard.weapons.give(load("res://src/weapons/data/pistol.tres"))
	var rig := _find(&"shotgun")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	guard.weapons.select_id(&"pistol")
	for i in 60:
		await get_tree().process_frame
	assert_eq(rig.looking_over(), 0.0)
	assert_true(guard.weapons.first_look_waiting(&"shotgun"))
	guard.weapons.select_id(&"shotgun")
	assert_gt(await _until_look(rig, 1.2), 0.0)


func test_taking_a_weapon_from_its_pickup_looks_it_over() -> void:
	var pickup := WeaponPickup.make(&"shotgun", Vector3(0, 0, -1.5))
	add_child(pickup)
	await physics_frames(2)
	pickup.interact(guard)
	var rig := guard.weapons.view_of(&"shotgun") as ViewmodelRig
	assert_eq(guard.weapons.current_state().data.id, &"shotgun", "in hand")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.5), 0.0, "looked over")


## (Review L4.) A weapon the guard already carries, picked up again (its
## pickup, the fire cabinet, the chained case), is no news: no second look.
func test_a_weapon_already_carried_and_picked_up_again_is_not_looked_over_again() -> void:
	Loadout.grant(guard, &"shotgun", GameState)
	var pickup := WeaponPickup.make(&"shotgun", Vector3(0, 0, -1.5))
	add_child(pickup)
	await physics_frames(2)
	pickup.interact(guard)
	assert_false(guard.weapons.first_look_waiting(&"shotgun"), "picked up again: no look")
	Loadout.grant(guard, &"pistol", GameState)
	assert_true(FoundWeapon.give(guard, &"pistol", false))
	assert_false(guard.weapons.first_look_waiting(&"pistol"), "found again: no look")
	assert_true(FoundWeapon.give(guard, &"flare", false))
	assert_true(guard.weapons.first_look_waiting(&"flare"), "a new one is looked over")


## (Review L5.) Being hurt or dazed is a fight: the look lets go at once,
## and none starts until it is calm again.
func test_being_hurt_or_dazed_cuts_the_look() -> void:
	var rig := _find(&"pistol")
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	assert_gt(await _until_look(rig, 1.0), 0.0)
	Events.player_damaged.emit(5.0, Vector3(0, 1, -3))
	for i in roundi(ViewmodelRig.LOOK_LET_GO * 60.0) + 3:
		await get_tree().process_frame
	assert_eq(rig.looking_over(), 0.0, "hurt: the look lets go")
	guard.weapons.found(&"pistol")
	Events.player_damaged.emit(5.0, Vector3(0, 1, -3))
	assert_lt(await _until_look(rig, FirstLook.QUIET_AFTER * 0.8), 0.0, "no look right after a hit")
	assert_gt(await _until_look(rig, 1.0), 0.0, "calm again: looked over")
	guard.weapons.daze(0.5)
	for i in roundi(ViewmodelRig.LOOK_LET_GO * 60.0) + 3:
		await get_tree().process_frame
	assert_eq(rig.looking_over(), 0.0, "dazed: the look lets go")
