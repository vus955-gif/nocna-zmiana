extends TestCase
## The Samurai General as pure logic (GeneralBrain): he wakes (the armour
## assembles, the sword is drawn), holds his guard and picks a dash cut at
## a distance or a close cut up close, announces every attack at least
## Guardian.MIN_TELEGRAPH ahead with the blade's glint at least 0.7 s before
## a dash lands, recovers longer after a miss than after a hit, is stunned
## by the taser (then immune for a while) and finished off once per stun,
## goes up on the tea house roof in phase 2 (two volleys, or down after a
## hit in the face), feints with a phantom only in phase 3, never picks the
## same attack thrice running (he advances instead), and fights the same
## fight from the same seed.

const A := GeneralBrain.Attack
const S := GeneralBrain.State
const T := GeneralBrain.Stage
const STEP := 1.0 / 60.0

var brain: GeneralBrain


func before_each() -> void:
	brain = GeneralBrain.new()
	brain.seed_with(11)


func _run(seconds: float, distance: float, bearing: float = 0.0) -> void:
	for i in roundi(seconds / STEP):
		brain.update(STEP, distance, bearing)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(distance: float, bearing: float = 0.0, limit: float = 6.0) -> A:
	for i in roundi(limit / STEP):
		brain.update(STEP, distance, bearing)
		if brain.state == S.ATTACK and brain.stage == T.TELEGRAPH and brain.stage_time() <= STEP + 0.0001:
			return brain.attack
	return A.NONE


## Lets the attack under way run out.
func _finish(distance: float = 12.0, bearing: float = 0.0) -> void:
	for i in 900:
		if brain.state != S.ATTACK:
			return
		brain.update(STEP, distance, bearing)


func _awake() -> void:
	brain.wake()
	_run(GeneralBrain.WAKE_TIME + 0.05, 12.0)


func test_he_sleeps_until_woken_then_assembles_and_draws_for_a_while() -> void:
	_run(2.0, 6.0)
	assert_eq(brain.state, S.DORMANT, "asleep without wake()")
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(GeneralBrain.ASSEMBLE_TIME * 0.5, 6.0)
	assert_almost_eq(brain.assemble_progress(), 0.5, 0.02, "the armour half assembled")
	assert_almost_eq(brain.draw_progress(), 0.0, 0.001, "the sword still in its scabbard")
	_run(GeneralBrain.ASSEMBLE_TIME * 0.5 + GeneralBrain.DRAW_TIME * 0.5, 6.0)
	assert_almost_eq(brain.assemble_progress(), 1.0, 0.001)
	assert_almost_eq(brain.draw_progress(), 0.5, 0.02, "the blade half out")
	assert_eq(brain.state, S.WAKING, "the waking takes its time")
	_run(GeneralBrain.DRAW_TIME * 0.5 + 0.1, 6.0)
	assert_eq(brain.state, S.GUARD)
	assert_true(brain.blocking(), "in his guard he blocks")
	assert_true(GeneralBrain.WAKE_TIME >= 3.0, "a readable entrance")


func test_at_a_distance_he_dashes_up_close_he_cuts() -> void:
	_awake()
	var far := _next_attack(12.0, 0.2)
	assert_eq(far, A.DASH, "far away: the dash cut")
	_finish()
	assert_eq(_next_attack(2.5, 0.3), A.CLOSE, "close in front: the close cut")
	_finish(2.5)
	var behind := _next_attack(2.5, 2.9)
	assert_ne(behind, A.CLOSE, "close behind him: no close cut (he turns first)")
	_finish(2.5)
	assert_eq(GeneralBrain.CLOSE_RANGE, 3.2)


func test_every_attack_is_announced_in_time_and_the_glint_comes_early_in_every_phase() -> void:
	for kind: A in [A.DASH, A.CLOSE, A.FEINT, A.LEAP_UP, A.VOLLEY, A.LEAP_DOWN]:
		for in_phase in [1, 2, 3]:
			var warning := GeneralBrain.stage_length(kind, T.TELEGRAPH, in_phase)
			assert_true(warning >= Guardian.MIN_TELEGRAPH, "%s in phase %d: %.2f s" % [A.keys()[kind], in_phase, warning])
	for in_phase in [1, 2, 3]:
		for kind: A in [A.DASH, A.FEINT]:
			var lead := GeneralBrain.stage_length(kind, T.TELEGRAPH, in_phase) - GeneralBrain.glint_at(kind, in_phase)
			assert_true(lead >= 0.7 - 0.001, "%s phase %d: the glint %.2f s before the cut" % [A.keys()[kind], in_phase, lead])
		# the volley's arrows fly at least 0.75 s: the mark shows even longer
		assert_true(GeneralBrain.ARROW_FLIGHT.x >= 0.75)
	# and in the running brain: telegraphed -> struck
	_awake()
	var clock := [0.0]
	var started := {}
	var gaps: Array = []
	brain.telegraphed.connect(func(kind: A) -> void: started[kind] = clock[0])
	brain.struck.connect(func(kind: A) -> void: gaps.append([kind, clock[0] - float(started.get(kind, -10.0))]))
	for spot: Array in [[12.0, 0.2], [2.5, 0.1], [9.0, -0.4], [2.0, 0.3]]:
		for i in 60 * 8:
			clock[0] += STEP
			brain.update(STEP, spot[0], spot[1])
	assert_gt(gaps.size(), 6)
	for gap: Array in gaps:
		assert_true(float(gap[1]) >= Guardian.MIN_TELEGRAPH - 0.001, "%s announced %.2f s ahead" % [A.keys()[gap[0]], gap[1]])


func test_a_missed_dash_leaves_him_open_longer_than_a_hit() -> void:
	_awake()
	brain.force_attack(A.DASH)
	_run(GeneralBrain.stage_length(A.DASH, T.TELEGRAPH, 1) + 0.05, 12.0)
	assert_eq(brain.stage, T.STRIKE, "the dash")
	assert_true(brain.dashing(), "through the guard's place")
	assert_false(brain.can_be_stunned(), "not in flight")
	_run(GeneralBrain.stage_length(A.DASH, T.STRIKE, 1), 12.0)
	assert_eq(brain.stage, T.RECOVER)
	assert_false(brain.landed, "he missed")
	assert_true(brain.back_open(), "his back to the guard: the punishment window")
	var miss := brain.current_stage_length()
	assert_almost_eq(miss, GeneralBrain.stage_length(A.DASH, T.RECOVER, 1), 0.001)
	_finish()
	# a dash that lands: a short chiburi, no open back
	_run(GeneralBrain.PAUSE[0] + 0.1, 12.0)
	brain.force_attack(A.DASH)
	_run(GeneralBrain.stage_length(A.DASH, T.TELEGRAPH, 1) + 0.05, 12.0)
	brain.dash_landed()
	_run(GeneralBrain.stage_length(A.DASH, T.STRIKE, 1), 12.0)
	assert_eq(brain.stage, T.RECOVER)
	assert_true(brain.landed)
	assert_false(brain.back_open())
	var hit := brain.current_stage_length()
	assert_lt(hit, miss, "a hit recovers faster (%.2f < %.2f)" % [hit, miss])
	for in_phase in [1, 2, 3]:
		assert_lt(GeneralBrain.per_phase(GeneralBrain.DASH_HIT_RECOVER, in_phase), GeneralBrain.stage_length(A.DASH, T.RECOVER, in_phase))
		assert_true(GeneralBrain.stage_length(A.DASH, T.RECOVER, in_phase) >= 0.9, "the miss window is readable")


func test_the_taser_stuns_him_from_his_guard_then_he_is_immune_for_a_while() -> void:
	_awake()
	assert_true(brain.can_be_stunned(), "in his guard")
	var hits := watch(brain.stunned)
	assert_true(brain.shock())
	assert_eq(brain.state, S.STUNNED)
	assert_eq(hits.size(), 1)
	assert_false(brain.blocking(), "no guard while he reels")
	_run(GeneralBrain.STUN_TIME[0] - 0.1, 5.0)
	assert_eq(brain.state, S.STUNNED, "for the phase's stun time")
	_run(0.2, 5.0)
	assert_eq(brain.state, S.GUARD)
	assert_false(brain.can_be_stunned(), "immune for a while")
	assert_false(brain.shock())
	_run(GeneralBrain.STUN_IMMUNITY, 5.0)
	_finish(5.0)
	assert_true(brain.can_be_stunned() or brain.state == S.ATTACK and brain.stage == T.STRIKE)
	# the telegraph and the recovery are open to it, the strike is not
	_run(1.0, 12.0)
	_finish()
	brain.force_attack(A.DASH)
	_run(0.2, 12.0)
	assert_true(brain.can_be_stunned(), "in the telegraph")
	var cancelled := watch(brain.finished)
	assert_true(brain.shock())
	assert_eq(brain.state, S.STUNNED)
	assert_eq(cancelled.size(), 1, "the dash is called off")
	assert_eq(brain.attack, A.NONE)
	for in_phase in [1, 2, 3]:
		assert_true(GeneralBrain.per_phase(GeneralBrain.STUN_TIME, in_phase) >= 1.5)


func test_a_fist_finishes_him_once_per_stun_and_he_reels_back_to_his_guard() -> void:
	_awake()
	assert_false(brain.finish(), "no finisher on a standing General")
	brain.shock()
	var done := watch(brain.finished_off)
	assert_true(brain.finish())
	assert_eq(done.size(), 1)
	assert_eq(brain.state, S.REEL, "he staggers")
	assert_false(brain.finish(), "once per stun")
	_run(GeneralBrain.REEL_TIME + 0.05, 3.0)
	assert_eq(brain.state, S.GUARD, "and comes back to his guard")
	assert_false(brain.can_be_stunned(), "immune after it")
	assert_almost_eq(GeneralBrain.FINISH_FRACTION, 0.14, 0.001)


func test_phase_two_sends_him_up_on_the_roof_after_the_attack_for_two_volleys() -> void:
	_awake()
	brain.force_attack(A.DASH)
	brain.set_phase(2)
	assert_eq(brain.attack, A.DASH, "the dash goes on")
	_finish()
	assert_eq(_next_attack(12.0), A.LEAP_UP, "then up he goes")
	_finish()
	assert_eq(brain.state, S.ROOF)
	assert_true(brain.on_roof)
	assert_false(brain.can_be_stunned(), "no taser up there")
	assert_false(brain.blocking(), "no guard up there")
	assert_eq(_next_attack(12.0), A.VOLLEY)
	assert_eq(brain.arrows(), 4, "four arrows in phase 2")
	_finish()
	assert_eq(brain.state, S.ROOF)
	assert_eq(_next_attack(12.0), A.VOLLEY, "a second volley")
	_finish()
	assert_eq(_next_attack(12.0), A.LEAP_DOWN, "two volleys: down")
	_finish()
	assert_eq(brain.state, S.GUARD)
	assert_false(brain.on_roof)
	assert_true(brain.roof_cooldown > 15.0, "he comes back up later (%.1f s)" % brain.roof_cooldown)
	# meanwhile he fights on the ground (three dashes: some 12 s)
	for i in 3:
		var picked := _next_attack(12.0, 0.1, 8.0)
		assert_ne(picked, A.LEAP_UP, "not yet")
		_finish()
	assert_true(brain.roof_cooldown > 0.0 and brain.roof_cooldown < GeneralBrain.ROOF_RETURN, "the cooldown runs on the ground (%.1f s)" % brain.roof_cooldown)
	brain.roof_cooldown = 0.0
	var leaps := false
	for i in 4:
		if _next_attack(12.0, 0.1, 8.0) == A.LEAP_UP:
			leaps = true
			break
		_finish()
	assert_true(leaps, "back up once the cooldown ran out")


func test_a_hit_in_the_face_on_the_roof_brings_him_down_after_the_volley() -> void:
	_awake()
	brain.set_phase(2)
	_finish()
	assert_eq(_next_attack(12.0), A.LEAP_UP)
	_finish()
	assert_eq(_next_attack(12.0), A.VOLLEY)
	brain.hit_face()
	assert_eq(brain.attack, A.VOLLEY, "the volley under way goes on")
	_finish()
	assert_eq(_next_attack(12.0), A.LEAP_DOWN, "then down")
	_finish()
	assert_eq(brain.state, S.GUARD)
	# a face hit on the ground changes nothing
	brain.hit_face()
	assert_eq(brain.state, S.GUARD)


func test_phase_three_transforms_him_then_he_feints_with_a_phantom() -> void:
	_awake()
	for i in 12:
		assert_ne(_next_attack(10.0, 0.2, 8.0), A.FEINT, "no feint in phase 1")
		_finish(10.0)
	brain.set_phase(3)
	_finish()
	_run(0.05, 10.0)
	assert_eq(brain.state, S.TRANSFORM, "he plants the sword, the petals fly")
	_run(GeneralBrain.TRANSFORM_TIME - 0.1, 10.0)
	assert_eq(brain.state, S.TRANSFORM)
	assert_false(brain.can_be_stunned(), "not while he transforms")
	_run(0.2, 10.0)
	assert_ne(brain.state, S.TRANSFORM)
	# he skipped phase 2: the roof visit comes after the transformation
	var first := _next_attack(10.0)
	assert_eq(first, A.LEAP_UP, "the roof visit he owes")
	_finish()
	while _next_attack(10.0) != A.LEAP_DOWN:
		_finish()
	_finish()
	var seen := {}
	for i in 30:
		var picked := _next_attack(10.0, 0.2, 8.0)
		seen[picked] = true
		_finish(10.0)
	assert_true(seen.has(A.FEINT), "the feint in phase 3: %s" % str(seen.keys()))
	assert_true(seen.has(A.DASH), "and honest dashes too")
	assert_almost_eq(GeneralBrain.FEINT_PHANTOM_LEAD, 0.25, 0.001, "the phantom moves first")
	assert_eq(brain.arrows(), 5)


func test_never_the_same_attack_three_times_running_he_advances_instead() -> void:
	_awake()
	assert_eq(_next_attack(12.0), A.DASH)
	_finish()
	assert_eq(_next_attack(12.0), A.DASH)
	_finish()
	assert_false(brain.advancing)
	var third := _next_attack(12.0, 0.0, 3.0)
	assert_eq(third, A.NONE, "no third dash")
	assert_true(brain.advancing, "he closes in with suri-ashi instead")
	assert_gt(brain.wanted_speed(), 1.5, "walking")
	assert_eq(_next_attack(2.5, 0.1), A.CLOSE, "up close: the close cut")
	assert_false(brain.advancing)
	_finish(2.5)
	# in phase 3 the feint takes turns with the dash
	brain.set_phase(3)
	_finish(2.5)
	_run(GeneralBrain.TRANSFORM_TIME + 0.2, 12.0)
	var picks: Array[A] = []
	for i in 40:
		var picked := _next_attack(11.0, 0.2, 8.0)
		if picked == A.LEAP_UP or picked == A.VOLLEY or picked == A.LEAP_DOWN:
			_finish()
			continue
		picks.append(picked)
		_finish(11.0)
	for i in range(2, picks.size()):
		assert_false(picks[i] == picks[i - 1] and picks[i] == picks[i - 2] and picks[i] != A.NONE, "three in a row at %d: %s" % [i, str(picks)])


func test_he_holds_his_ground_near_and_walks_up_when_far() -> void:
	_awake()
	brain.update(STEP, 5.0, 0.0)
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001, "within reach he stands")
	brain.update(STEP, 12.0, 0.0)
	assert_gt(brain.wanted_speed(), 1.0, "far off he presses in")
	assert_lt(brain.wanted_speed(), 4.0, "at a walk")


func test_reset_puts_him_back_to_sleep_on_the_ground() -> void:
	_awake()
	brain.set_phase(2)
	_finish()
	_next_attack(12.0)
	_finish()
	assert_true(brain.on_roof)
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_false(brain.on_roof)
	assert_eq(brain.attack, A.NONE)
	_run(1.0, 3.0)
	assert_eq(brain.state, S.DORMANT, "and he sleeps")
	brain.wake()
	_run(GeneralBrain.WAKE_TIME + 0.05, 12.0)
	assert_eq(brain.state, S.GUARD)


func test_the_same_seed_fights_the_same_fight() -> void:
	var picks: Array = []
	for run in 2:
		brain = GeneralBrain.new()
		brain.seed_with(5)
		_awake()
		brain.set_phase(3)
		_finish()
		_run(GeneralBrain.TRANSFORM_TIME + 0.2, 12.0)
		var these: Array = []
		for i in 14:
			these.append(_next_attack(11.0, 0.3, 8.0))
			_finish(11.0)
		picks.append(these)
	assert_eq(picks[0], picks[1])
