extends TestCase
## The free left hand's gestures (owner's note 45, plan
## 2026-10-21-animacje-fpp): the jab on an arc, the long gun's bash, the
## heavy piece's shove (never a second left hand next to the one on a
## fore-end), the reach of an interaction; every one eased, none jumping.

const DT := 1.0 / 60.0
const ONE := ViewmodelMotion.Grip.ONE_HAND
const LONG := ViewmodelMotion.Grip.LONG
const HEAVY := ViewmodelMotion.Grip.HEAVY


## Runs [param gesture] to its end; returns [the widest fist step (m), the
## widest weapon offset step (m), the widest weapon turn step (rad), the
## widest weapon_lower step].
func _run(gesture: ViewmodelGesture) -> Array:
	var widest := [0.0, 0.0, 0.0, 0.0]
	var fist: Array = gesture.fist()
	var weapon: Array = gesture.weapon()
	var lower := gesture.weapon_lower()
	var guard := 0
	while gesture.active() and guard < 200:
		guard += 1
		gesture.step(DT)
		var f: Array = gesture.fist()
		var w: Array = gesture.weapon()
		if f[0] and fist[0]:
			widest[0] = maxf(widest[0], (f[1] as Vector3).distance_to(fist[1]))
		widest[1] = maxf(widest[1], (w[0] as Vector3).distance_to(weapon[0]))
		widest[2] = maxf(widest[2], (w[1] as Vector3).distance_to(weapon[1]))
		widest[3] = maxf(widest[3], absf(gesture.weapon_lower() - lower))
		fist = f
		weapon = w
		lower = gesture.weapon_lower()
	return widest


func test_a_jab_rises_on_an_arc_into_the_hit_and_drops_back_out() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.punch(ONE, true)
	assert_eq(gesture.kind, ViewmodelGesture.Kind.JAB)
	var start: Array = gesture.fist()
	assert_true(start[0], "the fist is out")
	assert_false(FpCheck.on_screen(start[1]), "it starts under the frame")
	# half-way through the strike the fist is above the straight line
	# from the cock to the hit: it rises first, then drives in
	gesture.t = (ViewmodelGesture.JAB_COCKED_AT + ViewmodelGesture.JAB_HIT_AT) * 0.5
	var mid: Vector3 = gesture.fist()[1]
	var a := ViewmodelGesture.JAB_COCK
	var b := ViewmodelGesture.JAB_HIT
	var along := clampf((mid - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	assert_gt(mid.y, a.lerp(b, along).y + 0.02, "an arc, not a straight shove (%.3f over the line)" % (mid.y - a.lerp(b, along).y))
	gesture.t = ViewmodelGesture.JAB_HIT_AT
	assert_lt((gesture.fist()[1] as Vector3).distance_to(WeaponHolder.FIST_HIT), 0.002, "it lands on the hit")
	assert_true(FpCheck.on_screen(gesture.fist()[1], 0.1), "in plain sight")
	var weapon: Array = gesture.weapon()
	assert_gt((weapon[0] as Vector3).z, 0.02, "the handgun is pulled back as the shoulders turn")
	gesture.t = ViewmodelGesture.JAB_TIME - 0.01
	assert_false(FpCheck.on_screen(gesture.fist()[1]), "it drops back out under the frame")
	gesture.t = 0.0
	var widest := _run(gesture)
	# the strike is the one motion allowed to be this quick: about a fist's
	# width a frame at most, so it still reads as a motion, not a jump
	assert_lt(float(widest[0]), 0.11, "quick, but a motion (%.3f m a frame)" % widest[0])
	assert_lt(float(widest[1]), 0.012)
	assert_lt(ViewmodelGesture.JAB_HIT_AT, 0.15, "the blow lands at once")
	assert_false(gesture.active())
	assert_false(gesture.fist()[0], "and is gone")
	assert_eq(gesture.weapon()[0], Vector3.ZERO)


func test_with_no_weapon_up_the_blow_is_a_jab() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.punch(LONG, false)
	assert_eq(gesture.kind, ViewmodelGesture.Kind.JAB, "a long gun on its way up: the free fist")


func test_a_long_gun_bashes_and_a_heavy_piece_shoves_with_no_free_fist() -> void:
	for grip in [LONG, HEAVY]:
		var gesture := ViewmodelGesture.new()
		gesture.punch(grip, true)
		assert_eq(gesture.kind, ViewmodelGesture.Kind.BASH if grip == LONG else ViewmodelGesture.Kind.SHOVE)
		var strongest := Vector3.ZERO
		var turned := 0.0
		var showed := false
		while gesture.active():
			gesture.step(DT)
			showed = showed or gesture.fist()[0]
			var w: Array = gesture.weapon()
			if (w[0] as Vector3).z < strongest.z:
				strongest = w[0]
			turned = maxf(turned, (w[1] as Vector3).length())
		assert_false(showed, "grip %d: no second left hand" % grip)
		assert_lt(strongest.z, -0.08, "grip %d: driven forward (%.3f)" % [grip, strongest.z])
		if grip == LONG:
			assert_gt(turned, 0.4, "the bash swings across with a twist")
		gesture.punch(grip, true)
		var widest := _run(gesture)
		assert_lt(float(widest[1]), 0.06, "grip %d: no jump (%.3f m a frame)" % [grip, widest[1]])
		assert_lt(float(widest[2]), 0.2, "grip %d: (%.3f rad a frame)" % [grip, widest[2]])
		assert_eq(gesture.weapon()[1], Vector3.ZERO, "back in the hands")
	for grip in [LONG, HEAVY]:
		var gesture := ViewmodelGesture.new()
		gesture.punch(grip, true)
		assert_lt(gesture.length(), 0.4, "over before the fists can strike again (cooldown 0.4 s)")


func test_a_reach_goes_out_under_the_crosshair_and_comes_back() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.reach(ONE, true)
	assert_eq(gesture.kind, ViewmodelGesture.Kind.REACH)
	assert_false(FpCheck.on_screen(gesture.fist()[1]), "from under the frame")
	gesture.t = (ViewmodelGesture.REACH_HOLD + ViewmodelGesture.REACH_BACK) * 0.5
	var at: Vector3 = gesture.fist()[1]
	assert_lt(at.distance_to(ViewmodelGesture.REACH_AT), 0.015, "out under the crosshair")
	assert_true(FpCheck.on_screen(at, 0.2))
	assert_lt((gesture.fist()[2] as Vector3).z, -0.4, "the wrist turned over as it takes hold")
	assert_gt((gesture.weapon()[0] as Vector3).x, 0.015, "the handgun makes way")
	assert_eq(gesture.weapon_lower(), 0.0, "and stays in the frame")
	gesture.t = 0.0
	var widest := _run(gesture)
	assert_lt(float(widest[0]), 0.06, "(%.3f m a frame)" % widest[0])
	assert_false(gesture.active())


func test_a_two_handed_weapon_goes_out_of_the_frame_before_the_left_hand_reaches() -> void:
	for grip in [LONG, HEAVY]:
		var gesture := ViewmodelGesture.new()
		gesture.reach(grip, true)
		assert_eq(gesture.kind, ViewmodelGesture.Kind.REACH_TWO)
		var reached := false
		while gesture.active():
			gesture.step(DT)
			var fist: Array = gesture.fist()
			if fist[0] and FpCheck.on_screen(fist[1], -0.15):
				reached = true
				assert_gt(gesture.weapon_lower(), WeaponSwitch.HIDE_AT, "grip %d at %.2f s: the weapon (and its left hand) is out of sight while the free hand shows" % [grip, gesture.t])
		assert_true(reached, "the hand did reach out")
		gesture.reach(grip, true)
		var widest := _run(gesture)
		assert_lt(float(widest[3]), 0.15, "the weapon goes and comes without a jump (%.3f)" % widest[3])
		assert_eq(gesture.weapon_lower(), 0.0, "back in the hands")


func test_a_reach_waits_for_a_blow_a_blow_takes_over_from_a_reach() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.punch(LONG, true)
	gesture.reach(LONG, true)
	assert_eq(gesture.kind, ViewmodelGesture.Kind.BASH, "the bash goes on")
	gesture = ViewmodelGesture.new()
	gesture.reach(ONE, true)
	gesture.t = ViewmodelGesture.REACH_HOLD + 0.02
	var out: Vector3 = gesture.fist()[1]
	gesture.punch(ONE, true)
	assert_eq(gesture.kind, ViewmodelGesture.Kind.JAB)
	assert_lt((gesture.fist()[1] as Vector3).distance_to(out), 0.001, "the jab starts from where the hand is")
	var widest := _run(gesture)
	assert_lt(float(widest[0]), 0.11)


func test_hurry_plays_the_rest_quickly() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.reach(LONG, true)
	gesture.step(0.2)
	gesture.hurry()
	var steps := 0
	while gesture.active():
		gesture.step(DT)
		steps += 1
	assert_lt(steps * DT, (ViewmodelGesture.TWO_TIME - 0.2) / 3.0, "a shot brings the weapon back quickly (%.2f s)" % (steps * DT))


## Runs [param gesture] for [param seconds], calling [param events] (time ->
## Callable) when their time comes; returns the per-frame steps [fist (m),
## weapon offset (m), weapon_lower] and whether a free fist ever showed in
## the frame while the weapon was not out of sight ([param two_handed]).
func _script(gesture: ViewmodelGesture, seconds: float, events: Dictionary, two_handed: bool = false) -> Array:
	var steps := [[], [], []]
	var fist: Array = gesture.fist()
	var weapon: Array = gesture.weapon()
	var lower := gesture.weapon_lower()
	var two_hands := false
	var now := 0.0
	var pending := events.keys()
	pending.sort()
	while now < seconds:
		while not pending.is_empty() and float(pending[0]) <= now + 1e-6:
			(events[pending.pop_front()] as Callable).call()
		gesture.step(DT)
		now += DT
		var f: Array = gesture.fist()
		var w: Array = gesture.weapon()
		(steps[0] as Array).append((f[1] as Vector3).distance_to(fist[1]) if f[0] and fist[0] else 0.0)
		(steps[1] as Array).append((w[0] as Vector3).distance_to(weapon[0]))
		(steps[2] as Array).append(absf(gesture.weapon_lower() - lower))
		if two_handed and f[0] and FpCheck.on_screen(f[1], -0.15) and gesture.weapon_lower() <= WeaponSwitch.HIDE_AT:
			two_hands = true
		fist = f
		weapon = w
		lower = gesture.weapon_lower()
	return [steps, two_hands]


func _assert_smooth(result: Array, what: String) -> void:
	var steps: Array = result[0]
	for k in 3:
		var spike := FpCheck.spike(steps[k])
		assert_eq(spike, -1, "%s: %s jumps at frame %d" % [what, ["the fist", "the weapon", "the lowering"][k], spike])


func test_pressing_e_again_during_a_reach_keeps_the_hand_out() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.reach(ONE, true)
	var result := _script(gesture, 1.2, {0.3: func() -> void: gesture.reach(ONE, true)})
	_assert_smooth(result, "a handgun's reach, E again at 0.3 s")
	assert_false(gesture.active(), "and it ends")
	# the second E during the hold keeps the hand out longer, not a restart
	var again := ViewmodelGesture.new()
	again.reach(ONE, true)
	for i in roundi(0.3 / DT):
		again.step(DT)
	var held: Vector3 = again.fist()[1]
	again.reach(ONE, true)
	for i in roundi(0.1 / DT):
		again.step(DT)
	assert_lt((again.fist()[1] as Vector3).distance_to(held), 0.02, "still holding")


func test_pressing_e_again_while_the_hand_comes_back_sends_it_out_smoothly() -> void:
	for grip in [ONE, LONG]:
		for at in [0.45, 0.62, 0.8]:
			var gesture := ViewmodelGesture.new()
			gesture.reach(grip, true)
			var result := _script(gesture, 2.2, {at: func() -> void: gesture.reach(grip, true)}, grip == LONG)
			_assert_smooth(result, "grip %d, E again at %.2f s" % [grip, at])
			assert_false(result[1], "grip %d, E again at %.2f s: never a free hand beside the weapon's" % [grip, at])
			assert_false(gesture.active(), "grip %d: and it ends" % grip)
			assert_eq(gesture.weapon_lower(), 0.0)


func test_a_two_handed_reach_and_e_twice_keeps_the_weapon_down() -> void:
	var gesture := ViewmodelGesture.new()
	gesture.reach(LONG, true)
	var result := _script(gesture, 2.2, {0.3: func() -> void: gesture.reach(LONG, true)}, true)
	_assert_smooth(result, "a long gun's reach, E again at 0.3 s")
	assert_false(result[1], "never a free hand beside the weapon's")


func test_a_blow_during_a_two_handed_reach_comes_from_the_free_hand() -> void:
	for at in [0.1, 0.5, 0.75]:
		var gesture := ViewmodelGesture.new()
		gesture.reach(LONG, true)
		var result := _script(gesture, 2.0, {at: func() -> void: gesture.punch(LONG, true)}, true)
		_assert_smooth(result, "a blow %.2f s into a long gun's reach" % at)
		assert_false(result[1], "a blow at %.2f s: never a free hand beside the weapon's" % at)
		assert_false(gesture.active(), "and it settles")
		assert_eq(gesture.weapon_lower(), 0.0, "the weapon back in the hands")
		assert_eq(gesture.weapon()[0], Vector3.ZERO)


func test_a_blow_during_a_handgun_reach_starts_where_the_hand_is() -> void:
	for at in [0.1, 0.3, 0.45]:
		var gesture := ViewmodelGesture.new()
		gesture.reach(ONE, true)
		var result := _script(gesture, 1.2, {at: func() -> void: gesture.punch(ONE, true)})
		_assert_smooth(result, "a jab %.2f s into a reach" % at)
