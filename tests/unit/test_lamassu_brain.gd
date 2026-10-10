extends TestCase
## The Lamassu as pure logic (LamassuBrain): it wakes off its plinth, picks
## its attacks by the guard's distance and bearing (the charge from afar,
## the stomp close by, the gust in between; hops in phase 3), announces each
## at least Guardian.MIN_TELEGRAPH ahead, never repeats one thrice, is
## stunned when a charge ends in cover, shifts phases only between attacks.

const A := LamassuBrain.Attack
const S := LamassuBrain.State
const TELL := LamassuBrain.Stage.TELEGRAPH

var brain: LamassuBrain


func before_each() -> void:
	brain = LamassuBrain.new()
	brain.seed_with(11)


func _run(seconds: float, distance: float, bearing: float = 0.0) -> void:
	for i in roundi(seconds * 60.0):
		brain.update(1.0 / 60.0, distance, bearing)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(distance: float, bearing: float = 0.0, limit: float = 6.0) -> A:
	for i in roundi(limit * 60.0):
		brain.update(1.0 / 60.0, distance, bearing)
		if brain.state == S.ATTACK and brain.stage == TELL and brain.stage_time() <= 1.0 / 60.0 + 0.0001:
			return brain.attack
	return A.NONE


## Lets the attack under way run out (a charge skids to a stop).
func _finish() -> void:
	for i in 60 * 8:
		if brain.state != S.ATTACK and brain.state != S.STUNNED:
			return
		brain.update(1.0 / 60.0, 30.0, PI)


func _awake() -> void:
	brain.wake()
	_run(LamassuBrain.WAKE_TIME + 0.05, 30.0, PI)


func test_it_stands_still_until_woken_then_steps_down_for_a_while() -> void:
	_run(2.0, 6.0)
	assert_eq(brain.state, S.DORMANT, "a statue without wake()")
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(LamassuBrain.WAKE_TIME - 0.1, 6.0)
	assert_eq(brain.state, S.WAKING, "stepping off the plinth takes its time")
	_run(0.2, 6.0)
	assert_eq(brain.state, S.IDLE)
	assert_eq(_next_attack(6.0, 0.0, LamassuBrain.FIRST_PAUSE + 0.2) != A.NONE, true, "an attack soon after")


func test_far_off_it_charges_close_by_it_stomps_and_in_between_it_gusts() -> void:
	_awake()
	var far := {}
	for i in 12:
		far[_next_attack(18.0)] = true
		_finish()
	assert_eq(far.keys(), [A.CHARGE], "only the charge reaches 18 m: %s" % str(far.keys()))
	var near := {}
	for i in 24:
		near[_next_attack(4.5)] = true
		_finish()
	assert_true(near.has(A.STOMP), "stomps close by: %s" % str(near.keys()))
	assert_true(near.has(A.GUST), "gusts close by")
	assert_false(near.has(A.CHARGE), "no room to charge at 4.5 m")
	var mid := {}
	for i in 24:
		mid[_next_attack(10.0)] = true
		_finish()
	assert_true(mid.has(A.CHARGE) and mid.has(A.GUST), "charges and gusts at 10 m: %s" % str(mid.keys()))
	assert_false(mid.has(A.STOMP), "the stomp is for close by")


func test_nothing_reaches_a_guard_at_its_back_before_it_flies() -> void:
	_awake()
	assert_eq(_next_attack(9.0, deg_to_rad(150.0), 5.0), A.NONE, "it must turn round first")
	assert_eq(_next_attack(16.0, deg_to_rad(40.0), 5.0), A.NONE, "a charge needs him dead ahead")
	brain.set_phase(3)
	_run(LamassuBrain.shift_time(3) + 0.1, 9.0, deg_to_rad(150.0))
	assert_eq(_next_attack(9.0, deg_to_rad(150.0), 5.0), A.HOP, "phase 3: it leaps round at him")


func test_no_hop_when_there_is_nowhere_to_land() -> void:
	_awake()
	brain.set_phase(3)
	_run(LamassuBrain.shift_time(3) + 0.1, 30.0, PI)
	brain.hop_clear = false
	for i in 20:
		var picked := _next_attack(12.0, deg_to_rad(120.0), 1.5)
		assert_ne(picked, A.HOP, "no landing spot")
		_finish()


func test_never_the_same_attack_three_times_running() -> void:
	_awake()
	var history: Array[A] = []
	for i in 300:
		var picked := _next_attack(4.0 + float(i % 4) * 2.4)
		assert_ne(picked, A.NONE)
		history.append(picked)
		_finish()
	for i in range(2, history.size()):
		assert_false(history[i] == history[i - 1] and history[i] == history[i - 2], "thrice %s at %d" % [history[i], i])


func test_every_attack_is_announced_at_least_the_minimum_ahead() -> void:
	for attack: A in [A.CHARGE, A.GUST, A.STOMP, A.HOP]:
		for phase in [1, 2, 3]:
			var tell := LamassuBrain.stage_length(attack, TELL, phase)
			assert_true(tell >= Guardian.MIN_TELEGRAPH, "%s in phase %d: %.2f s" % [attack, phase, tell])
			assert_true(tell - (LamassuBrain.CHARGE_LOCK if attack == A.CHARGE else 0.0) >= 0.5, "%s tracks long enough" % attack)
	for phase in [1, 2, 3]:
		assert_true(LamassuBrain.stage_length(A.HOP, TELL, phase) >= 1.0, "the landing's shadow shows 1 s ahead")
	# measured: from telegraphed to struck
	_awake()
	var clock := [0.0]
	var started := {}
	var gaps: Array[float] = []
	brain.telegraphed.connect(func(attack: A) -> void: started[attack] = clock[0])
	brain.struck.connect(func(attack: A) -> void: gaps.append(clock[0] - float(started.get(attack, -10.0))))
	for i in 60 * 50:
		clock[0] += 1.0 / 60.0
		if i == 60 * 25:
			brain.set_phase(3)
		brain.update(1.0 / 60.0, 4.0 + float(i / 300 % 4) * 4.0, 0.0)
	assert_gt(gaps.size(), 8)
	for gap in gaps:
		assert_true(gap >= Guardian.MIN_TELEGRAPH - 0.001, "gap %.3f" % gap)


func test_the_clip_time_follows_the_stages() -> void:
	_awake()
	brain.force_attack(A.GUST)
	assert_almost_eq(brain.clip_time(), 0.0, 0.02)
	_run(LamassuBrain.stage_length(A.GUST, TELL, 1) * 0.5, 6.0)
	assert_almost_eq(brain.clip_time(), 0.5, 0.04)
	_run(LamassuBrain.stage_length(A.GUST, TELL, 1) * 0.5 + LamassuBrain.stage_length(A.GUST, LamassuBrain.Stage.STRIKE, 1) * 0.5, 6.0)
	assert_almost_eq(brain.clip_time(), 1.5, 0.05)


func test_a_charge_locks_its_aim_shortly_before_the_run() -> void:
	_awake()
	brain.force_attack(A.CHARGE)
	var tell := LamassuBrain.stage_length(A.CHARGE, TELL, 1)
	_run(tell - LamassuBrain.CHARGE_LOCK - 0.05, 12.0)
	assert_false(brain.charge_locked(), "still tracking him")
	_run(0.1, 12.0)
	assert_true(brain.charge_locked(), "locked")
	_run(LamassuBrain.CHARGE_LOCK, 12.0)
	assert_eq(brain.stage, LamassuBrain.Stage.STRIKE, "running")


func test_a_charge_into_cover_stuns_it_and_one_into_nothing_skids() -> void:
	_awake()
	var done := watch(brain.finished)
	brain.force_attack(A.CHARGE)
	_run(LamassuBrain.stage_length(A.CHARGE, TELL, 1) + 0.3, 12.0)
	assert_eq(brain.stage, LamassuBrain.Stage.STRIKE)
	brain.end_charge(true)
	assert_eq(brain.state, S.STUNNED, "it ran into a genius's base")
	assert_eq(done.size(), 1, "the charge is over")
	_run(LamassuBrain.STUN_TIME[0] - 0.1, 6.0)
	assert_eq(brain.state, S.STUNNED, "dazed for a while")
	_run(0.2, 6.0)
	assert_eq(brain.state, S.IDLE)
	brain.force_attack(A.CHARGE)
	_run(LamassuBrain.stage_length(A.CHARGE, TELL, 1) + 0.3, 12.0)
	brain.end_charge(false)
	assert_eq(brain.state, S.ATTACK)
	assert_eq(brain.stage, LamassuBrain.Stage.RECOVER, "a wall ahead: it skids to a stop")
	brain.end_charge(true)
	assert_eq(brain.state, S.ATTACK, "only a running charge can end")


func test_a_charge_runs_out_on_its_own() -> void:
	_awake()
	brain.force_attack(A.CHARGE)
	_run(LamassuBrain.stage_length(A.CHARGE, TELL, 1) + LamassuBrain.stage_length(A.CHARGE, LamassuBrain.Stage.STRIKE, 1) + 0.05, 12.0)
	assert_eq(brain.stage, LamassuBrain.Stage.RECOVER, "the longest run ends in a skid")


func test_phases_change_between_attacks_and_after_a_stun() -> void:
	_awake()
	var phases: Array[int] = []
	brain.state_changed.connect(func(_from: S, to: S) -> void:
		if to == S.PHASE_SHIFT:
			phases.append(brain.shift_phase))
	brain.force_attack(A.STOMP)
	brain.set_phase(2)
	assert_eq(brain.state, S.ATTACK, "the stomp first")
	_finish()
	assert_eq(brain.state, S.PHASE_SHIFT, "then it rears and bellows")
	assert_eq(brain.shift_phase, 2)
	_run(LamassuBrain.shift_time(2) - 0.1, 6.0)
	assert_eq(brain.state, S.PHASE_SHIFT, "no attack while it shifts")
	_run(0.2, 6.0)
	assert_eq(brain.state, S.IDLE)
	brain.force_attack(A.CHARGE)
	_run(LamassuBrain.stage_length(A.CHARGE, TELL, 2) + 0.2, 12.0)
	brain.end_charge(true)
	brain.set_phase(3)
	assert_eq(brain.state, S.STUNNED, "the stun first")
	_run(LamassuBrain.STUN_TIME[2] + 0.1, 6.0)
	assert_eq(brain.state, S.PHASE_SHIFT)
	assert_eq(brain.shift_phase, 3)
	assert_eq(phases, [2, 3] as Array[int])


func test_phase_three_gusts_more_often_and_hops() -> void:
	_awake()
	var counts: Array = [{}, {}]
	var slot := [0]
	brain.telegraphed.connect(func(attack: A) -> void:
		var tally: Dictionary = counts[slot[0]]
		tally[attack] = int(tally.get(attack, 0)) + 1)
	_run(120.0, 9.0)
	brain.set_phase(3)
	_finish()
	_run(LamassuBrain.shift_time(3) + 0.1, 30.0, PI)
	slot[0] = 1
	_run(120.0, 9.0)
	var early: Dictionary = counts[0]
	var late: Dictionary = counts[1]
	assert_true(late.has(A.HOP), "it leaps: %s" % str(late))
	assert_gt(float(late.get(A.GUST, 0)), float(early.get(A.GUST, 0)) * 1.3, "gusts more often: %s vs %s" % [str(late), str(early)])


func test_it_walks_up_to_the_guard_between_attacks() -> void:
	_awake()
	assert_true(brain.wants_to_walk(14.0), "too far: it closes in")
	assert_false(brain.wants_to_walk(5.0), "close enough")
	assert_gt(brain.walk_speed(), 1.0)
	assert_gt(brain.turn_speed(), 0.5)
	brain.force_attack(A.GUST)
	assert_false(brain.wants_to_walk(14.0), "not while it attacks")


func test_reset_puts_it_back_on_its_plinth_asleep() -> void:
	_awake()
	brain.set_phase(3)
	brain.force_attack(A.CHARGE)
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_eq(brain.attack, A.NONE)
	assert_true(brain.hop_clear)
	_run(1.0, 6.0)
	assert_eq(brain.state, S.DORMANT)


func test_the_same_seed_fights_the_same_way() -> void:
	var picks: Array = [[], []]
	for run in 2:
		brain = LamassuBrain.new()
		brain.seed_with(99)
		_awake()
		for i in 20:
			picks[run].append(_next_attack(5.0 + float(i % 3) * 3.0))
			_finish()
	assert_eq(picks[0], picks[1])
