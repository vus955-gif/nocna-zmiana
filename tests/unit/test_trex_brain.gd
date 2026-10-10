extends TestCase
## T-Rex boss rules as pure logic: states, phases, attack choice, damage.

const S := TRexBrain.State
const BEHIND := PI
const STEP := 1.0 / 60.0

var brain: TRexBrain


func before_each() -> void:
	brain = TRexBrain.new()


## Wakes the boss and runs it into STALK with every cooldown cleared.
func _awake() -> void:
	brain.wake()
	_run(TRexBrain.WAKE_TIME + 0.05, INF, 0.0)   # no guard yet: it just stands
	_clear_cooldowns()


func _clear_cooldowns() -> void:
	brain.charge_cooldown = 0.0
	brain.tail_cooldown = 0.0
	brain.summon_cooldown = 0.0
	brain.debris_cooldown = 0.0
	brain.stagger_cooldown = 0.0


func _run(seconds: float, distance: float, angle: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		brain.update(STEP, distance, angle)
		t += STEP


func test_sleeps_until_woken() -> void:
	_run(5.0, 3.0, 0.0)
	assert_eq(brain.state, S.DORMANT)
	brain.wake()
	assert_eq(brain.state, S.WAKING)
	_run(TRexBrain.WAKE_TIME + 0.05, 30.0, 0.0)
	assert_eq(brain.state, S.STALK)


func test_phase_thresholds() -> void:
	assert_eq(TRexBrain.phase_for(1.0), 1)
	assert_eq(TRexBrain.phase_for(0.67), 1)
	assert_eq(TRexBrain.phase_for(0.66), 2)
	assert_eq(TRexBrain.phase_for(0.34), 2)
	assert_eq(TRexBrain.phase_for(0.33), 3)
	assert_eq(TRexBrain.phase_for(0.0), 3)


func test_phases_only_go_up_and_announce_themselves_once() -> void:
	var changes := watch(brain.phase_changed)
	brain.set_health_fraction(0.9)
	brain.set_health_fraction(0.6)
	brain.set_health_fraction(0.5)
	brain.set_health_fraction(0.2)
	brain.set_health_fraction(0.7)
	assert_eq(brain.phase, 3)
	assert_eq(changes.size(), 2)
	if changes.size() == 2:
		assert_eq(changes[0][0], 2)
		assert_eq(changes[1][0], 3)


func test_damage_rule() -> void:
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.BONE, S.STALK), 0.1)
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.CRYSTAL, S.STALK), 1.0)
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.CRYSTAL, S.STUNNED), 1.5)
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.BONE, S.STUNNED), 0.1)
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.CRYSTAL, S.DORMANT), 0.0)
	assert_almost_eq(TRexBrain.damage_multiplier(TRexBrain.Zone.CRYSTAL, S.DEAD), 0.0)


func test_tail_only_when_the_guard_is_behind_and_close() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	for angle in [0.0, 0.6, PI * 0.5, -PI * 0.5, 2.2]:
		brain.update(STEP, 5.0, angle)
		assert_eq(brain.state, S.STALK, "no tail at angle %.2f" % angle)
	brain.update(STEP, 6.5, BEHIND)
	assert_eq(brain.state, S.STALK, "beyond the tail's reach")
	brain.update(STEP, 5.0, -2.5)
	assert_eq(brain.state, S.TAIL_WINDUP)


func test_tail_windup_then_one_strike() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	var strikes := watch(brain.tail_strike)
	brain.update(STEP, 4.0, BEHIND)
	assert_eq(brain.state, S.TAIL_WINDUP)
	_run(TRexBrain.TAIL_WINDUP_TIME - 0.05, 4.0, BEHIND)
	assert_eq(strikes.size(), 0, "nothing during the telegraph")
	_run(0.3, 4.0, BEHIND)
	assert_eq(brain.state, S.TAIL_SWIPE)
	assert_eq(strikes.size(), 1)
	_run(1.0, 4.0, BEHIND)
	assert_eq(strikes.size(), 1)
	assert_eq(brain.state, S.STALK)


func test_charge_windup_counts_only_while_facing_the_guard() -> void:
	_awake()
	brain.update(STEP, 12.0, 0.8)
	assert_eq(brain.state, S.CHARGE_WINDUP)
	_run(1.5, 12.0, 0.8)   # still turning toward the guard
	assert_eq(brain.state, S.CHARGE_WINDUP)
	var started := watch(brain.charge_started)
	_run(TRexBrain.CHARGE_WINDUP_TIME + 0.05, 12.0, 0.1)
	assert_eq(brain.state, S.CHARGE)
	assert_eq(started.size(), 1)


func test_windup_locks_its_aim_at_the_end() -> void:
	_awake()
	brain.update(STEP, 12.0, 0.0)
	assert_true(brain.is_tracking())
	_run(TRexBrain.CHARGE_WINDUP_TIME - TRexBrain.CHARGE_LOCK_TIME + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE_WINDUP)
	assert_false(brain.is_tracking())


func test_charge_into_a_wall_stuns_for_the_damage_window() -> void:
	_awake()
	brain.update(STEP, 12.0, 0.0)
	_run(TRexBrain.CHARGE_WINDUP_TIME + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE)
	brain.hit_wall()
	assert_eq(brain.state, S.STUNNED)
	_run(TRexBrain.STUN_TIME - 0.1, 12.0, 0.0)
	assert_eq(brain.state, S.STUNNED)
	_run(0.2, 12.0, 0.0)
	assert_eq(brain.state, S.STALK)


func test_a_charge_that_misses_the_walls_skids_to_a_halt() -> void:
	_awake()
	brain.update(STEP, 12.0, 0.0)
	_run(TRexBrain.CHARGE_WINDUP_TIME + 0.05, 12.0, 0.0)
	assert_almost_eq(brain.charge_time, (12.0 + TRexBrain.CHARGE_OVERSHOOT) / TRexBrain.CHARGE_SPEED, 0.05)
	_run(brain.charge_time + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.SKID)
	_run(TRexBrain.SKID_TIME + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.STALK)
	assert_gt(brain.charge_cooldown, 5.0, "a fresh cooldown after the charge")


func test_phase_three_charges_twice_unless_the_first_hits_a_wall() -> void:
	_awake()
	brain.set_health_fraction(0.2)
	brain.pending_phase_roar = false
	brain.update(STEP, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE_WINDUP)
	_run(TRexBrain.CHARGE_WINDUP_TIME + 0.05, 12.0, 0.0)
	_run(brain.charge_time + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE_WINDUP, "second charge")
	_run(TRexBrain.FOLLOWUP_WINDUP_TIME + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE)
	_run(brain.charge_time + 0.05, 12.0, 0.0)
	assert_eq(brain.state, S.SKID, "only two")
	# a wall ends the double charge at once
	_clear_cooldowns()
	_run(TRexBrain.SKID_TIME + 0.05, 12.0, 0.0)
	brain.debris_cooldown = 99.0
	brain.summon_cooldown = 99.0
	brain.charge_cooldown = 0.0
	brain.update(STEP, 12.0, 0.0)
	_run(TRexBrain.CHARGE_WINDUP_TIME + 0.05, 12.0, 0.0)
	brain.hit_wall()
	_run(TRexBrain.STUN_TIME + 0.05, 30.0, 0.0)
	assert_eq(brain.state, S.STALK)


func test_charge_cooldown_runs_faster_with_the_guard_under_its_chin() -> void:
	_awake()
	brain.charge_cooldown = 6.0
	brain.tail_cooldown = 99.0
	_run(2.0, 20.0, 0.0)
	var far := brain.charge_cooldown
	brain.charge_cooldown = 6.0
	_run(2.0, 3.0, 0.0)
	assert_almost_eq(far, 4.0, 0.05)
	assert_almost_eq(brain.charge_cooldown, 2.0, 0.05)


func test_phase_two_roars_to_summon_help() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	var peaks := watch(brain.roar_peak)
	brain.set_health_fraction(0.6)
	brain.update(STEP, 20.0, 0.0)
	assert_eq(brain.state, S.ROAR)
	_run(TRexBrain.ROAR_TIME + 0.05, 20.0, 0.0)
	assert_eq(peaks.size(), 1)
	if peaks.size() == 1:
		assert_true(peaks[0][0], "summons")
		assert_false(peaks[0][1], "no debris before phase 3")
	assert_eq(brain.state, S.STALK)
	_run(TRexBrain.SUMMON_INTERVAL - 3.0, 20.0, 0.0)
	assert_eq(peaks.size(), 1, "not again before the interval")
	_run(3.0, 20.0, 0.0)
	assert_eq(peaks.size(), 2)


## The taser may cut a roar short, but only delays the summons: the
## cooldowns start at the roar's peak, so an interrupted roar comes again.
func test_a_stagger_before_the_roar_peak_only_delays_the_summons() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	var peaks := watch(brain.roar_peak)
	brain.set_health_fraction(0.6)
	_run(TRexBrain.ROAR_PEAK_AT * 0.5, 20.0, 0.0)
	assert_eq(brain.state, S.ROAR)
	assert_true(brain.stagger())
	assert_eq(peaks.size(), 0)
	_run(TRexBrain.STAGGER_TIME + TRexBrain.ROAR_TIME, 20.0, 0.0)
	assert_eq(peaks.size(), 1, "roars again after the stagger")
	if peaks.size() == 1:
		assert_true(peaks[0][0], "and summons")
	assert_gt(brain.summon_cooldown, TRexBrain.SUMMON_INTERVAL - TRexBrain.ROAR_TIME)


func test_a_stagger_after_the_roar_peak_keeps_the_cooldown() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	var peaks := watch(brain.roar_peak)
	brain.set_health_fraction(0.6)
	_run(TRexBrain.ROAR_PEAK_AT + 0.1, 20.0, 0.0)
	assert_eq(peaks.size(), 1)
	assert_true(brain.stagger())
	_run(TRexBrain.STAGGER_TIME + TRexBrain.ROAR_TIME, 20.0, 0.0)
	assert_eq(peaks.size(), 1, "no second summon")


func test_no_summon_roar_while_the_hall_is_full() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	brain.set_health_fraction(0.6)
	brain.pending_phase_roar = false
	brain.can_summon = false
	var peaks := watch(brain.roar_peak)
	_run(3.0, 20.0, 0.0)
	assert_eq(peaks.size(), 0)
	brain.can_summon = true
	_run(TRexBrain.SUMMON_RETRY + TRexBrain.ROAR_TIME, 20.0, 0.0)
	assert_eq(peaks.size(), 1)


func test_phase_three_roar_brings_down_debris() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	brain.set_health_fraction(0.3)
	var peaks := watch(brain.roar_peak)
	_run(TRexBrain.ROAR_TIME + 0.05, 20.0, 0.0)
	assert_eq(peaks.size(), 1)
	if peaks.size() == 1:
		assert_true(peaks[0][1], "debris")


func test_taser_stagger_has_a_cooldown() -> void:
	_awake()
	brain.charge_cooldown = 99.0
	assert_true(brain.stagger())
	assert_eq(brain.state, S.STAGGER)
	_run(TRexBrain.STAGGER_TIME + 0.05, 20.0, 0.0)
	assert_eq(brain.state, S.STALK)
	assert_false(brain.stagger(), "still cooling down")
	_run(TRexBrain.STAGGER_COOLDOWN, 20.0, 0.0)
	assert_true(brain.stagger())


func test_stagger_breaks_a_charge_windup_but_not_a_stun() -> void:
	_awake()
	brain.update(STEP, 12.0, 0.0)
	assert_eq(brain.state, S.CHARGE_WINDUP)
	assert_true(brain.stagger())
	assert_eq(brain.state, S.STAGGER)
	_clear_cooldowns()
	brain.force(S.STUNNED)
	assert_false(brain.stagger())
	assert_eq(brain.state, S.STUNNED)


func test_no_stagger_while_dormant_or_waking() -> void:
	assert_false(brain.stagger())
	brain.wake()
	assert_false(brain.stagger())


func test_death_is_final() -> void:
	_awake()
	brain.die()
	assert_eq(brain.state, S.DEAD)
	brain.wake()
	_run(5.0, 3.0, PI)
	assert_eq(brain.state, S.DEAD)
	assert_false(brain.stagger())
