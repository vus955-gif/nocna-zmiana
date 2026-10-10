extends TestCase
## The Great Orrery as pure logic (OrreryBrain): it wakes, turns its tiers at
## a cruise that reverses with each phase, surges one tier, sends a planet
## round on an orbit, fires the sun's flares from phase 2; every warning at
## least Guardian.MIN_TELEGRAPH ahead and the tiers' drives change only
## after it; its phases count the planets shot off (two each), and with the
## sixth gone the sun opens.

const A := OrreryBrain.Attack
const S := OrreryBrain.State
const ST := OrreryBrain.Stage

var brain: OrreryBrain


func before_each() -> void:
	brain = OrreryBrain.new()
	brain.seed_with(11)


func _run(seconds: float, distance: float) -> void:
	for i in roundi(seconds * 60.0):
		brain.update(1.0 / 60.0, distance)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(distance: float, limit: float = 8.0) -> A:
	for i in roundi(limit * 60.0):
		brain.update(1.0 / 60.0, distance)
		if brain.state == S.ATTACK and brain.stage == ST.TELEGRAPH and brain.stage_time() <= 1.0 / 60.0 + 0.0001:
			return brain.attack
	return A.NONE


func _finish(distance: float = 7.0) -> void:
	for i in 60 * 12:
		if brain.state == S.IDLE:
			return
		brain.update(1.0 / 60.0, distance)


func _awake() -> void:
	brain.wake()
	_run(OrreryBrain.WAKE_TIME + 0.05, 7.0)


## Shoots planets off until [param lost] are gone, and lets the shifts play.
func _lose(lost: int) -> void:
	var k := 0
	while 6 - brain.planets_left() < lost:
		if brain.planets_on[k]:
			brain.planet_lost(k)
		k += 1
	_finish()
	for i in 60 * 8:
		if brain.state == S.IDLE:
			break
		brain.update(1.0 / 60.0, 7.0)


func test_it_sleeps_until_woken_then_its_gears_catch() -> void:
	_run(2.0, 7.0)
	assert_eq(brain.state, S.DORMANT)
	for tier in 3:
		assert_almost_eq(brain.tier_target(tier), 0.0, 0.0001, "still, asleep")
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(OrreryBrain.WAKE_TIME * OrreryBrain.WAKE_SPIN * 0.9, 7.0)
	assert_almost_eq(brain.tier_target(OrreryGeometry.LOW), 0.0, 0.0001, "the gears catch first")
	_run(OrreryBrain.WAKE_TIME * 0.5, 7.0)
	assert_almost_eq(brain.tier_target(OrreryGeometry.LOW), OrreryBrain.CRUISE[0][0], 0.0001, "then the tiers turn")
	assert_true(OrreryBrain.WAKE_TIME * OrreryBrain.WAKE_SPIN >= Guardian.MIN_TELEGRAPH, "the waking is the warning")
	_run(OrreryBrain.WAKE_TIME, 7.0)
	assert_ne(brain.state, S.WAKING)


func test_phase_one_surges_and_launches_and_flares_come_later() -> void:
	_awake()
	var seen := {}
	for i in 30:
		seen[_next_attack(7.0)] = true
		_finish()
	assert_true(seen.has(A.SURGE), str(seen.keys()))
	assert_true(seen.has(A.LAUNCH), str(seen.keys()))
	assert_false(seen.has(A.FLARE), "no flares while the sun is shut")
	_lose(2)
	assert_eq(brain.phase, 2)
	seen.clear()
	for i in 30:
		seen[_next_attack(8.0)] = true
		_finish()
	assert_true(seen.has(A.FLARE), "the sun opens a crack: flares %s" % str(seen.keys()))


func test_near_the_axis_it_surges_far_off_it_launches_and_flares() -> void:
	_awake()
	_lose(2)
	var near := 0
	var far := 0
	for i in 80:
		if _next_attack(3.0) == A.SURGE:
			near += 1
		_finish(3.0)
	for i in 80:
		if _next_attack(8.5) == A.SURGE:
			far += 1
		_finish(8.5)
	assert_gt(near, far * 1.8, "surges where the arms reach the guard (%d near, %d far)" % [near, far])


func test_every_warning_is_long_enough_in_every_phase() -> void:
	for kind: A in [A.SURGE, A.LAUNCH, A.FLARE]:
		for level in 4:
			var warning := OrreryBrain.stage_length(kind, ST.TELEGRAPH, level)
			assert_true(warning >= Guardian.MIN_TELEGRAPH, "%s at level %d: %.2f s" % [A.keys()[kind], level, warning])
	assert_true(OrreryBrain.SHIFT_TIME * OrreryBrain.SHIFT_BRAKE >= Guardian.MIN_TELEGRAPH, "a phase's new speeds come after its warning")


func test_a_surge_changes_the_drive_only_after_its_warning() -> void:
	_awake()
	_lose(2)
	var clock := 0.0
	var warned := -1.0
	var changed := -1.0
	var tier := -1
	var cruise := 0.0
	for i in 60 * 40:
		brain.update(1.0 / 60.0, 3.0)
		clock += 1.0 / 60.0
		if warned < 0.0 and brain.state == S.ATTACK and brain.attack == A.SURGE:
			warned = clock
			tier = brain.surge_tier
			cruise = brain.tier_target(tier)
		if warned >= 0.0 and changed < 0.0 and not is_equal_approx(brain.tier_target(tier), cruise):
			changed = clock
			break
	assert_gt(warned, 0.0, "a surge came")
	assert_gt(changed - warned, Guardian.MIN_TELEGRAPH - 0.02, "the drive changes %.2f s after the warning" % (changed - warned))
	var surged := brain.tier_target(tier)
	assert_true(absf(surged) > absf(cruise) * 1.5, "faster (%.2f -> %.2f)" % [cruise, surged])


func test_a_launch_takes_a_planet_still_on_its_arm() -> void:
	_awake()
	for k in 5:
		brain.planet_lost(k)
	_finish()
	for i in 60 * 10:
		brain.update(1.0 / 60.0, 8.0)
		if brain.state == S.IDLE:
			break
	for i in 12:
		var picked := _next_attack(8.5, 10.0)
		if picked == A.LAUNCH:
			assert_eq(brain.launch_planet, 5, "only Saturn is left")
		_finish(8.5)
	brain.planet_lost(5)
	_finish()
	for i in 12:
		assert_ne(_next_attack(8.5, 10.0), A.LAUNCH, "no planet left to send round")
		_finish(8.5)


func test_its_phases_count_the_planets_shot_off() -> void:
	_awake()
	assert_eq(brain.phase, 1)
	brain.planet_lost(0)
	assert_eq(brain.phase, 1, "one planet")
	brain.planet_lost(4)
	assert_eq(brain.phase, 2, "two planets: phase 2")
	assert_eq(brain.planets_on, [false, true, true, true, false, true] as Array[bool])
	var reversed := brain.tier_target(OrreryGeometry.LOW)
	var entered := false
	for i in 60 * 12:
		brain.update(1.0 / 60.0, 7.0)
		if brain.state == S.SHIFT:
			entered = true
		if entered and brain.state != S.SHIFT:
			break
	assert_true(entered, "the shift")
	assert_almost_eq(brain.tier_target(OrreryGeometry.LOW), OrreryBrain.CRUISE[0][1], 0.0001, "the low tier turns the other way now")
	assert_true(signf(reversed) != signf(brain.tier_target(OrreryGeometry.LOW)))
	brain.planet_lost(1)
	brain.planet_lost(2)
	assert_eq(brain.phase, 3, "four planets: phase 3")
	brain.planet_lost(3)
	assert_false(brain.exposed)
	brain.planet_lost(5)
	assert_eq(brain.planets_left(), 0)
	var unveiled := false
	for i in 60 * 14:
		brain.update(1.0 / 60.0, 7.0)
		if brain.state == S.UNVEIL:
			unveiled = true
			break
	assert_true(unveiled, "the sixth planet gone: the sun opens")
	assert_true(brain.exposed, "its core bared")
	assert_eq(brain.level(), 3, "the final turn of the screw")


func test_a_launched_planet_shot_off_ends_its_orbit() -> void:
	_awake()
	brain.force_attack(A.LAUNCH)
	var planet := brain.launch_planet
	_run(OrreryBrain.stage_length(A.LAUNCH, ST.TELEGRAPH, 0) + 0.5, 8.0)
	assert_eq(brain.stage, ST.STRIKE)
	brain.planet_lost(planet)
	assert_eq(brain.stage, ST.RECOVER, "no orbit without its planet")


func test_never_the_same_attack_thrice_running() -> void:
	_awake()
	_lose(2)
	var history: Array[A] = []
	for i in 60:
		history.append(_next_attack(5.0))
		_finish(5.0)
	for i in range(2, history.size()):
		assert_false(history[i] == history[i - 1] and history[i] == history[i - 2], "thrice %s at %d" % [A.keys()[history[i]], i])


func test_the_same_seed_gives_the_same_fight() -> void:
	var picks: Array = []
	for run in 2:
		brain = OrreryBrain.new()
		brain.seed_with(3)
		_awake()
		var seq: Array = []
		for i in 12:
			seq.append(_next_attack(6.0))
			seq.append(brain.surge_tier)
			_finish(6.0)
		picks.append(seq)
	assert_eq(picks[0], picks[1])


func test_reset_puts_it_to_sleep_whole() -> void:
	_awake()
	_lose(4)
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_eq(brain.planets_left(), 6)
	assert_false(brain.exposed)
	for tier in 3:
		assert_almost_eq(brain.tier_target(tier), 0.0, 0.0001)
