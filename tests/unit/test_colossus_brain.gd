extends TestCase
## The Colossus of Ramesses as pure logic (ColossusBrain, ColossusGait): it
## wakes, picks attacks by the guard's distance and bearing, announces each
## at least Guardian.MIN_TELEGRAPH ahead, never repeats one thrice, sheds
## its plates in phase 2, stands up in phase 3, walks with stomps.

const A := ColossusBrain.Attack
const S := ColossusBrain.State

var brain: ColossusBrain


func before_each() -> void:
	brain = ColossusBrain.new()
	brain.seed_with(7)


func _run(seconds: float, distance: float, bearing: float = 0.0) -> void:
	var steps := roundi(seconds * 60.0)
	for i in steps:
		brain.update(1.0 / 60.0, distance, bearing)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(distance: float, bearing: float = 0.0, limit: float = 6.0) -> A:
	for i in roundi(limit * 60.0):
		brain.update(1.0 / 60.0, distance, bearing)
		if brain.state == S.ATTACK and brain.stage == ColossusBrain.Stage.TELEGRAPH and brain.stage_time() <= 1.0 / 60.0 + 0.0001:
			return brain.attack
	return A.NONE


func _awake() -> void:
	brain.wake()
	_run(ColossusBrain.WAKE_TIME + 0.05, 20.0)


func test_it_sleeps_until_woken_then_rises_for_a_while() -> void:
	_run(2.0, 6.0)
	assert_eq(brain.state, S.DORMANT, "asleep without wake()")
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(ColossusBrain.WAKE_TIME - 0.1, 6.0)
	assert_eq(brain.state, S.WAKING, "the waking takes its time")
	_run(0.2, 6.0)
	assert_ne(brain.state, S.WAKING)
	assert_ne(brain.state, S.DORMANT)


func test_close_by_it_strikes_with_its_hands_far_off_it_beams() -> void:
	_awake()
	var near := {}
	for i in 30:
		var picked := _next_attack(6.0)
		near[picked] = true
		_finish()
	assert_true(near.has(A.SLAM), "slams close by: %s" % str(near.keys()))
	assert_true(near.has(A.SWEEP), "sweeps close by")
	var far := {}
	for i in 12:
		far[_next_attack(16.0)] = true
		_finish()
	assert_eq(far.keys(), [A.BEAM], "only the beam reaches 16 m")


func test_nothing_but_swarms_reaches_a_guard_behind_it() -> void:
	_awake()
	assert_eq(_next_attack(7.0, deg_to_rad(150.0), 5.0), A.NONE, "no attack at his back")
	brain.set_phase(2)
	_finish()
	_run(ColossusBrain.PHASE_SHIFT_TIME + 0.1, 7.0, deg_to_rad(150.0))
	assert_eq(_next_attack(7.0, deg_to_rad(150.0), ColossusBrain.SWARM_FIRST + 3.0), A.SWARM, "a swarm finds him anywhere")


func test_no_slam_when_its_arm_cannot_reach_through() -> void:
	_awake()
	brain.slam_clear = false
	for i in 20:
		var picked := _next_attack(10.0)
		assert_ne(picked, A.SLAM, "the line from the shoulder is blocked")
		_finish()


func test_never_the_same_attack_three_times_running() -> void:
	_awake()
	var history: Array[A] = []
	for i in 200:
		var picked := _next_attack(6.0 + float(i % 3))
		assert_ne(picked, A.NONE)
		history.append(picked)
		_finish()
	for i in range(2, history.size()):
		assert_false(history[i] == history[i - 1] and history[i] == history[i - 2], "thrice %s at %d" % [history[i], i])


func test_every_attack_is_announced_at_least_the_minimum_ahead() -> void:
	for attack: A in [A.SLAM, A.SWEEP, A.BEAM, A.SWARM, A.BEAM_SWEEP]:
		for phase in [1, 2, 3]:
			assert_true(ColossusBrain.stage_length(attack, ColossusBrain.Stage.TELEGRAPH, phase) >= Guardian.MIN_TELEGRAPH,
					"%s in phase %d: %.2f s" % [attack, phase, ColossusBrain.stage_length(attack, ColossusBrain.Stage.TELEGRAPH, phase)])
	assert_true(ColossusGait.SWING_TIME >= Guardian.MIN_TELEGRAPH, "a stomp: the foot is up long enough")
	# measured: from telegraphed to struck
	_awake()
	var clock := [0.0]
	var started := {}
	var gaps: Array[float] = []
	brain.telegraphed.connect(func(attack: A) -> void: started[attack] = clock[0])
	brain.struck.connect(func(attack: A) -> void: gaps.append(clock[0] - float(started.get(attack, -10.0))))
	for i in 60 * 40:
		clock[0] += 1.0 / 60.0
		brain.update(1.0 / 60.0, 5.0 + float(i / 300 % 4) * 3.0, 0.0)
	assert_gt(gaps.size(), 5)
	for gap in gaps:
		assert_true(gap >= Guardian.MIN_TELEGRAPH - 0.001, "gap %.3f" % gap)


func test_the_clip_time_follows_the_stages() -> void:
	_awake()
	brain.force_attack(A.SLAM)
	assert_almost_eq(brain.clip_time(), 0.0, 0.02)
	_run(ColossusBrain.stage_length(A.SLAM, ColossusBrain.Stage.TELEGRAPH, 1) * 0.5, 6.0)
	assert_almost_eq(brain.clip_time(), 0.5, 0.03, "halfway through the telegraph")
	_run(ColossusBrain.stage_length(A.SLAM, ColossusBrain.Stage.TELEGRAPH, 1) * 0.5 + 0.01, 6.0)
	assert_eq(brain.stage, ColossusBrain.Stage.STRIKE)
	assert_almost_eq(brain.clip_time(), 1.0, 0.03, "the strike begins at 1")


func test_phase_two_sheds_the_plates_after_the_attack_then_swarms() -> void:
	_awake()
	var picked := _next_attack(6.0)
	assert_ne(picked, A.NONE)
	brain.set_phase(2)
	assert_eq(brain.state, S.ATTACK, "the attack under way finishes first")
	_finish()
	assert_eq(brain.state, S.PHASE_SHIFT, "then the plates")
	_run(ColossusBrain.PHASE_SHIFT_TIME + 0.05, 6.0)
	assert_eq(brain.state, S.IDLE)
	assert_eq(_next_attack(6.0, 0.0, ColossusBrain.SWARM_FIRST + 2.5), A.SWARM, "the first swarm soon after")
	_finish()
	brain.swarms_alive = ColossusBrain.MAX_SWARMS[1]
	for i in 15:
		assert_ne(_next_attack(6.0), A.SWARM, "no more than the limit alive")
		_finish()


func test_phase_three_stands_it_up_and_changes_its_moves() -> void:
	_awake()
	brain.set_phase(3)
	assert_eq(brain.state, S.PHASE_SHIFT, "a jump past phase 2 still sheds the plates first")
	_run(ColossusBrain.PHASE_SHIFT_TIME + 0.05, 6.0)
	assert_eq(brain.state, S.STAND_UP)
	assert_false(brain.standing)
	_run(ColossusBrain.STAND_UP_TIME + 0.05, 6.0)
	assert_true(brain.standing, "standing after the rise")
	var seen := {}
	brain.swarms_alive = 99
	for i in 30:
		seen[_next_attack(9.0)] = true
		_finish()
	assert_false(seen.has(A.SWEEP), "no low forearm sweep standing")
	assert_true(seen.has(A.BEAM_SWEEP), "the beam sweeps")
	assert_false(seen.has(A.BEAM), "no tracking beam in phase 3")


func test_walking_only_between_attacks_in_phase_three() -> void:
	_awake()
	assert_false(brain.wants_to_walk(15.0), "seated")
	brain.set_phase(3)
	_run(ColossusBrain.PHASE_SHIFT_TIME + ColossusBrain.STAND_UP_TIME + 0.2, 15.0)
	assert_true(brain.standing)
	assert_true(brain.wants_to_walk(15.0), "far: it walks to the guard")
	assert_false(brain.wants_to_walk(ColossusBrain.KEEP_DISTANCE - 0.5), "close enough: it stands")
	brain.force_attack(A.BEAM_SWEEP)
	assert_false(brain.wants_to_walk(15.0), "not during an attack")


func test_reset_puts_it_back_to_sleep_on_its_throne() -> void:
	_awake()
	brain.set_phase(3)
	_run(ColossusBrain.PHASE_SHIFT_TIME + ColossusBrain.STAND_UP_TIME + 0.2, 8.0)
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_false(brain.standing)
	assert_eq(brain.attack, A.NONE)


func test_the_same_seed_picks_the_same_fight() -> void:
	var first := _sequence(11)
	var second := _sequence(11)
	assert_eq(first, second)


func test_a_dead_colossus_does_nothing() -> void:
	_awake()
	brain.die()
	_run(5.0, 6.0)
	assert_eq(brain.state, S.DEAD)


func test_the_gait_lifts_each_foot_well_before_it_lands() -> void:
	var gait := ColossusGait.new()
	var clock := [0.0]
	var lifted := {}
	var landings: Array = []
	gait.lifted.connect(func(side: int) -> void: lifted[side] = clock[0])
	gait.planted.connect(func(side: int) -> void: landings.append([side, clock[0] - float(lifted.get(side, -10.0))]))
	var covered := 0.0
	for i in 60 * 8:
		clock[0] += 1.0 / 60.0
		covered += gait.update(1.0 / 60.0, true)
	assert_gt(landings.size(), 3)
	for i in landings.size():
		assert_true(float(landings[i][1]) >= Guardian.MIN_TELEGRAPH, "foot up %.2f s" % float(landings[i][1]))
		if i > 0:
			assert_ne(landings[i][0], landings[i - 1][0], "the feet take turns")
	assert_almost_eq(covered / 8.0, ColossusGait.STEP_LENGTH / ColossusGait.STEP_TIME, 0.15, "its walking speed")
	# stopping: the foot in the air comes down, then it stands
	var before := landings.size()
	for i in 60 * 3:
		clock[0] += 1.0 / 60.0
		gait.update(1.0 / 60.0, false)
	assert_false(gait.swinging(), "both feet down")
	assert_true(landings.size() <= before + 1)


func _finish() -> void:
	for i in 60 * 8:
		if brain.state != S.ATTACK:
			return
		brain.update(1.0 / 60.0, 6.0, 0.0)


func _sequence(seed_value: int) -> Array:
	brain = ColossusBrain.new()
	brain.seed_with(seed_value)
	_awake()
	var picks := []
	for i in 20:
		picks.append(_next_attack(5.0 + (i % 4) * 2.5))
		_finish()
	return picks
