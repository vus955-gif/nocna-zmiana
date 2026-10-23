extends TestCase
## How each first-person weapon moves as a whole (plan 2026-10-21-animacje-fpp):
## its grip class, how quickly it is put away and drawn, and the keyed curves
## the gestures are made of.


func test_every_weapon_has_a_grip_class() -> void:
	for id in WeaponHolder.SLOT_ORDER:
		assert_true(ViewmodelMotion.HANDLING.has(id), "%s has its handling" % id)
	assert_eq(ViewmodelMotion.grip_of(&"pistol"), ViewmodelMotion.Grip.ONE_HAND)
	assert_eq(ViewmodelMotion.grip_of(&"taser"), ViewmodelMotion.Grip.ONE_HAND)
	assert_eq(ViewmodelMotion.grip_of(&"flare"), ViewmodelMotion.Grip.ONE_HAND)
	assert_eq(ViewmodelMotion.grip_of(&"shotgun"), ViewmodelMotion.Grip.LONG)
	assert_eq(ViewmodelMotion.grip_of(&"rifle_hunt"), ViewmodelMotion.Grip.LONG)
	assert_eq(ViewmodelMotion.grip_of(&"harpoon"), ViewmodelMotion.Grip.LONG)
	assert_eq(ViewmodelMotion.grip_of(&"gatling"), ViewmodelMotion.Grip.HEAVY)
	assert_eq(ViewmodelMotion.grip_of(&"hwacha"), ViewmodelMotion.Grip.HEAVY)
	assert_eq(ViewmodelMotion.grip_of(&"unknown"), ViewmodelMotion.Grip.ONE_HAND, "a weapon without handling is a light one")


func test_heavier_weapons_are_slower_to_put_away_and_draw() -> void:
	var pistol := ViewmodelMotion.draw_time(&"pistol")
	var shotgun := ViewmodelMotion.draw_time(&"shotgun")
	var gatling := ViewmodelMotion.draw_time(&"gatling")
	assert_lt(pistol, shotgun, "a handgun comes up quicker than a long gun")
	assert_lt(shotgun, gatling, "and a long gun quicker than the gatling")
	assert_lt(ViewmodelMotion.holster_time(&"pistol"), ViewmodelMotion.holster_time(&"gatling"))
	for id in WeaponHolder.SLOT_ORDER:
		var down := ViewmodelMotion.holster_time(id)
		var up := ViewmodelMotion.draw_time(id)
		assert_lt(down, up, "%s: put away quicker than drawn" % id)
		assert_lt(down + up, 0.65, "%s: a whole switch stays snappy (%.2f s)" % [id, down + up])
		assert_gt(down + up, 0.3, "%s: but it reads as a motion (%.2f s)" % [id, down + up])
		var settle := ViewmodelMotion.draw_damping(id)
		assert_true(settle > 0.6 and settle < 1.0, "%s: the draw settles with a touch of weight" % id)
	assert_gt(ViewmodelMotion.draw_damping(&"gatling"), ViewmodelMotion.draw_damping(&"pistol"), "a heavy gun bounces less")


func test_the_wall_reach_grows_with_the_weapon() -> void:
	var one := ViewmodelMotion.wall_start(ViewmodelMotion.Grip.ONE_HAND)
	var long := ViewmodelMotion.wall_start(ViewmodelMotion.Grip.LONG)
	var heavy := ViewmodelMotion.wall_start(ViewmodelMotion.Grip.HEAVY)
	assert_gt(one, WallProbe.FULL_AT + 0.2)
	assert_lt(one, long)
	assert_true(long <= heavy)


func test_keyed_curves_hold_their_keys_and_ease_between_them() -> void:
	var keys := [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.5, Vector3(0.1, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)],
		[1.0, Vector3.ZERO, Vector3.ZERO],
	]
	var at_key: Array = ViewmodelMotion.keyed(keys, 0.5)
	assert_lt((at_key[0] as Vector3).distance_to(Vector3(0.1, 0.0, 0.0)), 1e-6)
	assert_lt((at_key[1] as Vector3).distance_to(Vector3(0.0, 1.0, 0.0)), 1e-6)
	var before: Array = ViewmodelMotion.keyed(keys, -1.0)
	var after: Array = ViewmodelMotion.keyed(keys, 2.0)
	assert_eq(before[0], Vector3.ZERO, "before the first key: the first")
	assert_eq(after[1], Vector3.ZERO, "after the last: the last")
	var quarter: Array = ViewmodelMotion.keyed(keys, 0.25)
	assert_almost_eq((quarter[0] as Vector3).x, 0.05, 1e-6, "half-way between two keys")
	# eased: slow out of a key, slow into the next
	var near_key: Array = ViewmodelMotion.keyed(keys, 0.05)
	assert_lt((near_key[0] as Vector3).x, 0.005, "slow out of a key")
	var last := 0.0
	var widest := 0.0
	for i in 101:
		var x: float = (ViewmodelMotion.keyed(keys, i / 100.0)[0] as Vector3).x
		if i > 0:
			widest = maxf(widest, absf(x - last))
		last = x
	assert_lt(widest, 0.0035, "no jumps between samples")


func test_the_holster_pose_takes_the_weapon_down_and_turns_the_muzzle_away() -> void:
	for grip in [ViewmodelMotion.Grip.ONE_HAND, ViewmodelMotion.Grip.LONG, ViewmodelMotion.Grip.HEAVY]:
		var pose: Array = ViewmodelMotion.holster_pose(grip)
		assert_lt((pose[0] as Vector3).y, -0.2, "down out of the frame")
		assert_lt((pose[1] as Vector3).x, -0.3, "muzzle down")
		var sprint: Array = ViewmodelMotion.sprint_pose(grip)
		assert_lt((sprint[0] as Vector3).y, -0.03, "the run carries it lower")
		var wall: Array = ViewmodelMotion.wall_pose(grip)
		assert_gt((wall[0] as Vector3).z, 0.06, "a wall pushes it back toward the chest")
		assert_lt((wall[1] as Vector3).x, -0.1, "muzzle down off the wall")


func test_the_spring_starts_gently_settles_and_never_overshoots() -> void:
	var dt := 1.0 / 60.0
	var omega := 20.0
	var state := Vector2(0.0, 0.0)
	var steps: Array[float] = []
	var last := 0.0
	for i in 30:
		state = ViewmodelMotion.follow(state.x, state.y, 1.0, omega, dt)
		assert_lt(state.x, 1.0 + 1e-6, "critically damped: no overshoot")
		steps.append(state.x - last)
		last = state.x
	assert_lt(steps[0], 0.05, "the first frame barely moves (%.3f): no snap" % steps[0])
	assert_lt(steps.max(), omega / exp(1.0) * dt + 1e-4, "its fastest frame (%.3f)" % steps.max())
	assert_gt(state.x, 0.98, "settled within half a second")
	# exact for any step: two half steps land where one whole step does
	var whole := ViewmodelMotion.follow(0.3, 2.0, 1.0, omega, dt)
	var half := ViewmodelMotion.follow(0.3, 2.0, 1.0, omega, dt * 0.5)
	half = ViewmodelMotion.follow(half.x, half.y, 1.0, omega, dt * 0.5)
	assert_lt(absf(whole.x - half.x) + absf(whole.y - half.y), 1e-5)
	# the Vector3 one is the same spring on every axis
	var moved: Array = ViewmodelMotion.follow3(Vector3(0.3, 0.0, -1.0), Vector3(2.0, 0.0, 0.0), Vector3(1.0, 0.0, -1.0), omega, dt)
	assert_lt(absf((moved[0] as Vector3).x - whole.x), 1e-6)
	assert_eq((moved[0] as Vector3).z, -1.0, "at its target and still: stays")
