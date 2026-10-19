extends TestCase
## The Two-headed Serpent as pure logic (SerpentBrain): it sleeps until
## woken, wakes for a while, then glides and picks its attacks by reach -
## the glowing head spits at a distance, the other bites up close, the
## tail sweeps whoever stands by it - announcing each at least
## Guardian.MIN_TELEGRAPH ahead and never thrice running; it turns round to
## lead with the other head when the guard keeps to its tail; phase 2 passes
## the light from one head to the other after the attack under way; phase 3
## sends it to encircle the altar's terrace and fight from the ring's gate.

const A := SerpentBrain.Attack
const S := SerpentBrain.State
const END := SerpentBody.End
const STEP := 1.0 / 60.0

var brain: SerpentBrain


func before_each() -> void:
	brain = SerpentBrain.new()
	brain.seed_with(7)


## What the brain sees: the guard [param spit] m from the spitting head,
## [param bite] m from the biting one, [param tail] m from the tail's root.
func _sight(spit: float, bite: float, tail: float, nearer_tail: bool = false, spit_bearing: float = 0.0, bite_bearing: float = 0.0) -> SerpentBrain.Sight:
	var sight := SerpentBrain.Sight.new()
	sight.spit_distance = spit
	sight.spit_bearing = spit_bearing
	sight.bite_distance = bite
	sight.bite_bearing = bite_bearing
	sight.tail_distance = tail
	sight.nearer_tail = nearer_tail
	return sight


func _run(seconds: float, sight: SerpentBrain.Sight) -> void:
	for i in roundi(seconds / STEP):
		brain.update(STEP, sight)


## Runs until an attack starts (or [param limit] s pass); returns it.
func _next_attack(sight: SerpentBrain.Sight, limit: float = 8.0) -> A:
	for i in roundi(limit / STEP):
		brain.update(STEP, sight)
		if brain.state == S.ATTACK and brain.stage == SerpentBrain.Stage.TELEGRAPH and brain.stage_time() <= STEP + 0.0001:
			return brain.attack
	return A.NONE


func _finish(sight: SerpentBrain.Sight) -> void:
	for i in 600:
		if brain.state != S.ATTACK:
			return
		brain.update(STEP, sight)


func _awake() -> void:
	brain.wake()
	_run(SerpentBrain.WAKE_TIME + 0.05, _sight(12.0, 14.0, 20.0))


func test_it_sleeps_until_woken_then_wakes_for_a_while_and_glides() -> void:
	_run(2.0, _sight(6.0, 6.0, 10.0))
	assert_eq(brain.state, S.DORMANT, "asleep without wake()")
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001)
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(SerpentBrain.WAKE_TIME - 0.1, _sight(6.0, 6.0, 10.0))
	assert_eq(brain.state, S.WAKING, "waking takes its time")
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001, "and it lies still meanwhile")
	_run(0.2, _sight(12.0, 14.0, 20.0))
	assert_eq(brain.state, S.ROAM)
	assert_almost_eq(brain.wanted_speed(), SerpentBrain.SPEED[0], 0.001, "it glides at phase 1's pace")
	assert_eq(brain.lead, END.A, "head A leads")
	assert_eq(brain.spitter, END.A, "and glows: it spits")
	assert_eq(brain.biter(), END.B)


func test_every_attack_is_announced_long_enough_in_every_phase() -> void:
	for kind: A in [A.SPIT, A.LUNGE, A.SWEEP]:
		for phase in [1, 2, 3]:
			assert_true(SerpentBrain.stage_length(kind, SerpentBrain.Stage.TELEGRAPH, phase) >= Guardian.MIN_TELEGRAPH,
					"%s phase %d telegraph" % [A.keys()[kind], phase])
			assert_gt(SerpentBrain.stage_length(kind, SerpentBrain.Stage.STRIKE, phase), 0.1)
	_awake()
	var told := watch(brain.telegraphed)
	var struck := watch(brain.struck)
	var done := watch(brain.finished)
	brain.force_attack(A.SPIT)
	assert_eq(told.size(), 1)
	assert_eq(brain.attack_end(), END.A, "the glowing head spits")
	_run(SerpentBrain.stage_length(A.SPIT, SerpentBrain.Stage.TELEGRAPH, 1) - 0.05, _sight(12.0, 14.0, 20.0))
	assert_eq(struck.size(), 0, "nothing lands before the telegraph is over")
	_run(0.1, _sight(12.0, 14.0, 20.0))
	assert_eq(struck.size(), 1)
	assert_almost_eq(brain.clip_time(), 1.0, 0.2, "the clip stands at the strike")
	_finish(_sight(12.0, 14.0, 20.0))
	assert_eq(done.size(), 1)
	assert_eq(brain.state, S.ROAM)


func test_it_picks_by_reach_spit_far_bite_close_sweep_by_the_tail() -> void:
	_awake()
	for i in 6:
		var picked := _next_attack(_sight(12.0, 13.0, 20.0))
		assert_eq(picked, A.SPIT, "far off: only the spit reaches (%s)" % A.keys()[picked])
		_finish(_sight(12.0, 13.0, 20.0))
	for i in 4:
		var picked := _next_attack(_sight(20.0, 4.0, 20.0))
		assert_eq(picked, A.LUNGE, "close to the biting head: the lunge (%s)" % A.keys()[picked])
		assert_eq(brain.attack_end(), END.B, "head B bites")
		_finish(_sight(20.0, 4.0, 20.0))
	for i in 4:
		var picked := _next_attack(_sight(22.0, 24.0, 3.0))
		assert_eq(picked, A.SWEEP, "by the tail: the sweep (%s)" % A.keys()[picked])
		assert_eq(brain.attack_end(), END.B, "the trailing end sweeps (head A leads)")
		_finish(_sight(22.0, 24.0, 3.0))
	assert_eq(_next_attack(_sight(30.0, 30.0, 30.0), 3.0), A.NONE, "nothing in reach: it waits")
	assert_eq(brain.state, S.ROAM)
	assert_eq(_next_attack(_sight(12.0, 13.0, 20.0, false, 2.6), 3.0), A.NONE, "the guard behind the spitting head: no spit")
	assert_eq(_next_attack(_sight(20.0, 4.0, 20.0, false, 0.0, 2.6), 3.0), A.NONE, "behind the biting head: no lunge")


func test_it_never_repeats_an_attack_thrice_when_another_fits() -> void:
	_awake()
	var sight := _sight(12.0, 20.0, 4.0)   # the spit and the sweep both fit
	var history: Array[A] = []
	for i in 12:
		var picked := _next_attack(sight)
		assert_ne(picked, A.NONE)
		history.append(picked)
		_finish(sight)
	for i in range(2, history.size()):
		assert_false(history[i] == history[i - 1] and history[i] == history[i - 2], "thrice %s at %d" % [A.keys()[history[i]], i])
	assert_true(history.has(A.SPIT) and history.has(A.SWEEP), "both were used")


func test_it_turns_round_when_the_guard_keeps_to_its_tail() -> void:
	_awake()
	var turned := watch(brain.reversed)
	_run(SerpentBrain.REVERSE_AFTER - 0.3, _sight(25.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 0, "not yet")
	_run(0.5, _sight(25.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 1, "the other head leads now")
	assert_eq(brain.lead, END.B)
	assert_eq(brain.spitter, END.A, "the roles stay: head A still spits")
	_run(SerpentBrain.REVERSE_AFTER + 0.5, _sight(25.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 1, "not again within the cooldown")
	_run(SerpentBrain.REVERSE_COOLDOWN, _sight(25.0, 25.0, 25.0, false))
	_run(SerpentBrain.REVERSE_AFTER + 0.2, _sight(25.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 2, "and again once it may")
	assert_eq(brain.lead, END.A)
	# never in the middle of an attack
	_run(SerpentBrain.REVERSE_COOLDOWN + 0.1, _sight(25.0, 25.0, 25.0, false))
	brain.force_attack(A.SPIT)
	var spit := 0.0
	for stage: SerpentBrain.Stage in [SerpentBrain.Stage.TELEGRAPH, SerpentBrain.Stage.STRIKE, SerpentBrain.Stage.RECOVER]:
		spit += SerpentBrain.stage_length(A.SPIT, stage, 1)
	assert_gt(spit, SerpentBrain.REVERSE_AFTER - 1.0, "(a spit lasts about as long as the turning takes)")
	_run(spit - 0.1, _sight(12.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 2, "a spit under way is not interrupted")
	assert_eq(brain.state, S.ATTACK)
	_run(SerpentBrain.REVERSE_AFTER + 0.3, _sight(12.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 3, "once it is over, it turns")


func test_phase_two_passes_the_light_to_the_other_head_after_the_attack_under_way() -> void:
	_awake()
	var swapped := watch(brain.roles_swapped)
	brain.force_attack(A.SPIT)
	brain.set_phase(2)
	assert_eq(brain.phase, 2)
	assert_eq(brain.state, S.ATTACK, "the spit finishes first")
	_finish(_sight(12.0, 14.0, 20.0))
	assert_eq(brain.state, S.PHASE_SHIFT, "then the heads turn to each other")
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001, "lying still")
	_run(SerpentBrain.SHIFT_TIME * 0.5, _sight(12.0, 14.0, 20.0))
	assert_almost_eq(brain.state_progress(), 0.5, 0.05)
	assert_eq(swapped.size(), 0, "the light is still travelling")
	_run(SerpentBrain.SHIFT_TIME * 0.5 + 0.1, _sight(12.0, 14.0, 20.0))
	assert_eq(swapped.size(), 1)
	assert_eq(brain.spitter, END.B, "head B glows now")
	assert_eq(brain.biter(), END.A)
	assert_eq(brain.state, S.ROAM)
	assert_almost_eq(brain.wanted_speed(), SerpentBrain.SPEED[1], 0.001, "faster now")
	assert_eq(_next_attack(_sight(20.0, 4.0, 20.0)), A.LUNGE)
	assert_eq(brain.attack_end(), END.A, "head A bites now")


func test_phase_three_sends_it_to_the_ring_where_it_fights_from_the_gate() -> void:
	_awake()
	brain.set_phase(2)
	_run(SerpentBrain.SHIFT_TIME + 0.3, _sight(12.0, 14.0, 20.0))
	assert_eq(brain.state, S.ROAM)
	brain.force_attack(A.SWEEP)
	brain.set_phase(3)
	assert_eq(brain.state, S.ATTACK)
	_finish(_sight(22.0, 24.0, 3.0))
	assert_eq(brain.state, S.ENCIRCLE, "it slides to the ring")
	assert_almost_eq(brain.wanted_speed(), SerpentBrain.SLIDE_SPEED, 0.001)
	assert_eq(_next_attack(_sight(5.0, 4.0, 3.0), 3.0), A.NONE, "no attack on the way")
	var turned := watch(brain.reversed)
	_run(SerpentBrain.REVERSE_AFTER + 1.0, _sight(5.0, 4.0, 3.0, true))
	assert_eq(turned.size(), 0, "and no turning round")
	brain.encircled()
	assert_eq(brain.state, S.RING)
	assert_almost_eq(brain.wanted_speed(), 0.0, 0.001, "the ring lies still")
	var picks := {}
	for i in 8:
		var picked := _next_attack(_sight(12.0, 4.0, 2.0))
		picks[picked] = true
		assert_ne(picked, A.SWEEP, "the tail is a neck in the ring: no sweep")
		_finish(_sight(12.0, 4.0, 2.0))
	assert_true(picks.has(A.LUNGE) and picks.has(A.SPIT), "both heads fight from the gate")
	_run(SerpentBrain.REVERSE_COOLDOWN + SerpentBrain.REVERSE_AFTER + 1.0, _sight(25.0, 25.0, 25.0, true))
	assert_eq(turned.size(), 0, "the ring never turns round")
	assert_eq(brain.state, S.RING)
	# phase 3 straight from phase 1 passes the light on the way too
	var fresh := SerpentBrain.new()
	fresh.wake()
	for i in roundi((SerpentBrain.WAKE_TIME + 0.1) / STEP):
		fresh.update(STEP, _sight(12.0, 14.0, 20.0))
	fresh.set_phase(3)
	for i in roundi(0.4 / STEP):
		fresh.update(STEP, _sight(12.0, 14.0, 20.0))
	assert_eq(fresh.state, S.PHASE_SHIFT, "the light passes first")
	for i in roundi((SerpentBrain.SHIFT_TIME + 0.1) / STEP):
		fresh.update(STEP, _sight(12.0, 14.0, 20.0))
	assert_eq(fresh.state, S.ENCIRCLE)
	assert_eq(fresh.spitter, END.B)


func test_the_biting_head_counts_more_while_it_recovers_from_a_lunge() -> void:
	_awake()
	assert_almost_eq(brain.weak_factor(END.A), 1.0, 0.001)
	assert_almost_eq(brain.weak_factor(END.B), 1.0, 0.001)
	brain.force_attack(A.LUNGE)
	assert_almost_eq(brain.weak_factor(END.B), 1.0, 0.001, "not while it coils")
	_run(SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.TELEGRAPH, 1) + SerpentBrain.stage_length(A.LUNGE, SerpentBrain.Stage.STRIKE, 1) + 0.05, _sight(20.0, 4.0, 20.0))
	assert_eq(brain.stage, SerpentBrain.Stage.RECOVER)
	assert_almost_eq(brain.weak_factor(END.B), SerpentBrain.LUNGE_RECOVER_WEAK, 0.001, "its head hangs out: x1.5")
	assert_almost_eq(brain.weak_factor(END.A), 1.0, 0.001, "the other head as ever")
	_finish(_sight(20.0, 4.0, 20.0))
	assert_almost_eq(brain.weak_factor(END.B), 1.0, 0.001)


func test_reset_puts_it_back_to_sleep_and_the_dice_are_deterministic() -> void:
	_awake()
	brain.set_phase(2)
	_run(SerpentBrain.SHIFT_TIME + 0.2, _sight(12.0, 14.0, 20.0))
	brain.reverse()
	brain.reset()
	assert_eq(brain.state, S.DORMANT)
	assert_eq(brain.phase, 1)
	assert_eq(brain.lead, END.A)
	assert_eq(brain.spitter, END.A)
	assert_eq(brain.attack, A.NONE)
	var twin := SerpentBrain.new()
	twin.seed_with(3)
	var other := SerpentBrain.new()
	other.seed_with(3)
	for b: SerpentBrain in [twin, other]:
		b.wake()
		for i in roundi((SerpentBrain.WAKE_TIME + 0.1) / STEP):
			b.update(STEP, _sight(12.0, 20.0, 4.0))
	for round in 6:
		var a := A.NONE
		var c := A.NONE
		for i in 600:
			twin.update(STEP, _sight(12.0, 20.0, 4.0))
			if twin.state == S.ATTACK:
				a = twin.attack
				break
		for i in 600:
			other.update(STEP, _sight(12.0, 20.0, 4.0))
			if other.state == S.ATTACK:
				c = other.attack
				break
		assert_eq(a, c, "round %d" % round)
		for b: SerpentBrain in [twin, other]:
			for i in 600:
				if b.state != S.ATTACK:
					break
				b.update(STEP, _sight(12.0, 20.0, 4.0))
	brain.die()
	assert_eq(brain.state, S.DEAD)
	brain.wake()
	assert_eq(brain.state, S.DEAD, "dead is final")
