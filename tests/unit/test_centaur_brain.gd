extends TestCase
## The Centaur as pure logic (CentaurBrain): it wakes, picks javelins or a
## charge at a distance and its hooves up close (a rearing kick in front, a
## buck behind), announces every attack at least Guardian.MIN_TELEGRAPH
## ahead, never repeats one thrice, reels after a charge into something,
## calls the Lapiths in phase 2 (again once they fell), tears the metope's
## piece off and throws in pairs in phase 3.

const A := CentaurBrain.Attack
const S := CentaurBrain.State
const STEP := 1.0 / 60.0

var brain: CentaurBrain


func before_each() -> void:
	brain = CentaurBrain.new()
	brain.seed_with(11)


func _run(seconds: float, distance: float, bearing: float = 0.0) -> void:
	for i in roundi(seconds / STEP):
		brain.update(STEP, distance, bearing)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(distance: float, bearing: float = 0.0, limit: float = 6.0) -> A:
	for i in roundi(limit / STEP):
		brain.update(STEP, distance, bearing)
		if brain.state == S.ATTACK and brain.stage == CentaurBrain.Stage.TELEGRAPH and brain.stage_time() <= STEP + 0.0001:
			return brain.attack
	return A.NONE


## Lets the attack under way run out (a charge runs on to its end).
func _finish(distance: float = 12.0) -> void:
	for i in 600:
		if brain.state != S.ATTACK:
			return
		brain.update(STEP, distance, 0.0)


func _awake() -> void:
	brain.wake()
	_run(CentaurBrain.WAKE_TIME + 0.05, 14.0)


func test_it_sleeps_until_woken_then_tears_itself_free_for_a_while() -> void:
	_run(2.0, 6.0)
	assert_eq(brain.state, S.DORMANT, "asleep without wake()")
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(CentaurBrain.WAKE_TIME - 0.1, 6.0)
	assert_eq(brain.state, S.WAKING, "tearing free takes its time")
	_run(0.2, 14.0)
	assert_eq(brain.state, S.ROAM)
	assert_gt(brain.wanted_speed(), 8.5, "it gallops faster than the guard sprints")


func test_at_a_distance_javelins_and_charges_never_hooves() -> void:
	_awake()
	var seen := {}
	for i in 40:
		var picked := _next_attack(14.0, 0.4)
		seen[picked] = true
		_finish()
	assert_true(seen.has(A.THROW), "javelins: %s" % str(seen.keys()))
	assert_true(seen.has(A.CHARGE), "charges")
	assert_false(seen.has(A.KICK), "no kick out there")
	assert_false(seen.has(A.BUCK), "no buck out there")


func test_up_close_it_rears_in_front_and_bucks_behind() -> void:
	_awake()
	assert_eq(_next_attack(3.0, 0.2), A.KICK, "close in front: the rearing kick")
	_finish(3.0)
	assert_eq(_next_attack(3.0, 2.8), A.BUCK, "close behind: the buck")
	_finish(3.0)
	var side := _next_attack(3.0, PI * 0.5, 3.0)
	assert_true(side != A.KICK and side != A.BUCK, "at its flank neither hoof reaches")


func test_charges_keep_their_distance_in_time() -> void:
	_awake()
	var clock := [0.0]
	var starts: Array[float] = []
	brain.telegraphed.connect(func(kind: A) -> void:
		if kind == A.CHARGE:
			starts.append(clock[0]))
	for i in 60 * 120:
		brain.update(STEP, 20.0, 0.0)
		clock[0] += STEP
	var gaps: Array[float] = []
	for i in range(1, starts.size()):
		gaps.append(starts[i] - starts[i - 1])
	assert_gt(gaps.size(), 3, "it charges again and again")
	for gap in gaps:
		assert_gt(gap, CentaurBrain.CHARGE_COOLDOWN, "never sooner than the cooldown")


func test_never_the_same_attack_three_times_running() -> void:
	_awake()
	var picks: Array[A] = []
	for i in 200:
		picks.append(_next_attack(12.0, 0.3, 12.0))
		_finish()
	for i in range(2, picks.size()):
		assert_false(picks[i] == picks[i - 1] and picks[i] == picks[i - 2] and picks[i] != A.NONE, "three in a row at %d" % i)


func test_every_attack_is_announced_in_time_in_every_phase() -> void:
	for kind: A in [A.THROW, A.KICK, A.BUCK, A.CHARGE, A.CALL, A.TEAR]:
		for in_phase in [1, 2, 3]:
			var warning := CentaurBrain.stage_length(kind, CentaurBrain.Stage.TELEGRAPH, in_phase)
			assert_true(warning >= Guardian.MIN_TELEGRAPH, "%s in phase %d: %.2f s" % [A.keys()[kind], in_phase, warning])
	# and in the running brain: telegraphed -> struck
	_awake()
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	brain.telegraphed.connect(func(kind: A) -> void: started[kind] = clock[0])
	brain.struck.connect(func(kind: A) -> void: gaps.append([kind, clock[0] - float(started.get(kind, -10.0))]))
	for spot: Array in [[14.0, 0.2], [3.0, 0.1], [3.0, 3.0], [22.0, -0.4]]:
		for i in 60 * 10:
			clock[0] += STEP
			brain.update(STEP, spot[0], spot[1])
	assert_gt(gaps.size(), 6)
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.001, "%s announced %.2f s ahead" % [A.keys()[gap[0]], gap[1]])


func test_a_charge_into_something_stuns_it_one_past_the_guard_skids() -> void:
	_awake()
	brain.force_attack(A.CHARGE)
	_run(CentaurBrain.stage_length(A.CHARGE, CentaurBrain.Stage.TELEGRAPH, 1) + 0.05, 14.0)
	assert_eq(brain.stage, CentaurBrain.Stage.STRIKE, "running")
	assert_almost_eq(brain.wanted_speed(), CentaurBrain.CHARGE_SPEED, 0.01)
	var done := watch(brain.finished)
	brain.crash()
	assert_eq(brain.state, S.STUNNED, "it reels")
	assert_eq(done.size(), 1, "the charge is over")
	assert_almost_eq(brain.weak_factor(), CentaurBrain.STUN_WEAK_FACTOR, 0.001, "its chest open")
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001)
	_run(CentaurBrain.STUN_TIME[0] - 0.1, 14.0)
	assert_eq(brain.state, S.STUNNED, "for the phase's stun time")
	_run(0.2, 14.0)
	assert_eq(brain.state, S.ROAM)
	assert_almost_eq(brain.weak_factor(), 1.0, 0.001)
	# past the guard: a skid, no stun
	_run(CentaurBrain.CHARGE_COOLDOWN, 14.0)
	_finish()
	brain.force_attack(A.CHARGE)
	_run(CentaurBrain.stage_length(A.CHARGE, CentaurBrain.Stage.TELEGRAPH, 1) + 0.05, 14.0)
	brain.charge_done()
	assert_eq(brain.stage, CentaurBrain.Stage.RECOVER, "a skid")
	_finish()
	assert_eq(brain.state, S.ROAM)


func test_phase_two_calls_the_lapiths_after_the_attack_and_again_once_they_fell() -> void:
	_awake()
	brain.force_attack(A.THROW)
	brain.set_phase(2)
	assert_eq(brain.attack, A.THROW, "the throw goes on")
	_finish()
	assert_eq(_next_attack(12.0), A.CALL, "then the call")
	var struck := watch(brain.struck)
	_run(CentaurBrain.stage_length(A.CALL, CentaurBrain.Stage.TELEGRAPH, 2) + 0.05, 12.0)
	assert_eq(struck.size(), 1, "the Lapiths step out")
	_finish()
	brain.lapiths_alive = 2
	for i in 20:
		assert_ne(_next_attack(12.0, 0.2), A.CALL, "not while they fight")
		_finish()
	brain.lapiths_alive = 0
	var called := false
	for i in 40:
		if _next_attack(12.0, 0.2, 8.0) == A.CALL:
			called = true
			break
		_finish()
	assert_true(called, "again once they fell")
	assert_eq(CentaurBrain.per_phase(CentaurBrain.LAPITHS, 2), 2)
	assert_eq(CentaurBrain.per_phase(CentaurBrain.LAPITHS, 3), 3)


func test_phase_three_tears_off_the_piece_and_throws_in_pairs() -> void:
	_awake()
	brain.set_phase(3)
	assert_eq(_next_attack(12.0), A.CALL, "it calls first (it skipped phase 2)")
	_finish()
	assert_eq(_next_attack(12.0), A.TEAR, "then tears the metope's piece off")
	assert_false(brain.pair, "one javelin while it tears")
	_finish()
	assert_true(brain.pair, "a javelin in each hand")
	var warning := CentaurBrain.stage_length(A.THROW, CentaurBrain.Stage.TELEGRAPH, 3)
	assert_lt(warning, CentaurBrain.stage_length(A.THROW, CentaurBrain.Stage.TELEGRAPH, 1), "a shorter wind-up")
	assert_true(warning >= Guardian.MIN_TELEGRAPH, "but never under 0.6 s")
	assert_true(CentaurBrain.stage_length(A.THROW, CentaurBrain.Stage.STRIKE, 3) > CentaurBrain.PAIR_GAP, "room for the second javelin")


func test_reset_puts_it_back_to_sleep_with_one_javelin() -> void:
	_awake()
	brain.set_phase(3)
	_run(10.0, 12.0)
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_false(brain.pair)
	_run(1.0, 3.0)
	assert_eq(brain.state, S.DORMANT, "and it sleeps")


func test_the_same_seed_fights_the_same_fight() -> void:
	var picks: Array = []
	for run in 2:
		brain = CentaurBrain.new()
		brain.seed_with(5)
		_awake()
		var these: Array = []
		for i in 12:
			these.append(_next_attack(13.0, 0.3))
			_finish()
		picks.append(these)
	assert_eq(picks[0], picks[1])
