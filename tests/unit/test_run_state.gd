extends TestCase
## State of one night: Dust, multipliers, the night's random generator.

var run: NightState


func before_each() -> void:
	run = NightState.new()
	add_child(run)


func test_begin_night_resets_and_seeds_the_rng() -> void:
	run.add_dust(40)
	run.artifacts.append(&"coin")
	run.fuses_carried = 1
	run.begin_night(12345)
	assert_eq(run.dust, 0)
	assert_eq(run.artifacts.size(), 0)
	assert_eq(run.fuses_carried, 0)
	assert_eq(run.crystal_phase, NightState.CrystalPhase.DORMANT)
	assert_true(run.running)
	var first := [run.rng.randi(), run.rng.randi(), run.rng.randi()]
	run.begin_night(12345)
	assert_eq([run.rng.randi(), run.rng.randi(), run.rng.randi()], first, "same seed, same night")


func test_add_dust_applies_multipliers_rounding_up() -> void:
	run.set_multiplier(&"full_moon", 1.5)
	assert_eq(run.add_dust(3), 5)
	assert_eq(run.add_dust(8), 12)
	assert_eq(run.dust, 17)


func test_multipliers_stack() -> void:
	run.set_multiplier(&"full_moon", 1.5)
	run.set_multiplier(&"coin", 1.5)
	assert_almost_eq(run.dust_multiplier(), 2.25)
	assert_eq(run.scaled_dust(4), 9)
	run.clear_multiplier(&"coin")
	assert_eq(run.scaled_dust(4), 6)


func test_raw_dust_ignores_multipliers() -> void:
	run.set_multiplier(&"full_moon", 1.5)
	assert_eq(run.add_dust(10, false), 10)
	assert_eq(run.dust, 10)


func test_spend_dust_refuses_when_short() -> void:
	run.add_dust(20)
	assert_false(run.spend_dust(25))
	assert_eq(run.dust, 20)
	assert_true(run.spend_dust(20))
	assert_eq(run.dust, 0)
	assert_false(run.spend_dust(-1))


func test_dust_changed_reports_total_and_delta() -> void:
	var calls := watch(run.dust_changed)
	run.add_dust(7)
	run.spend_dust(3)
	assert_eq(calls.size(), 2)
	if calls.size() == 2:
		assert_eq(calls[0][0], 7)
		assert_eq(calls[0][1], 7)
		assert_eq(calls[1][0], 4)
		assert_eq(calls[1][1], -3)


func test_time_runs_only_during_a_night() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(run.time, 0.0, "no night, no clock")
	run.begin_night(1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(run.time, 0.0)
	var unsaved := run.take_unsaved_time()
	assert_almost_eq(unsaved, run.time, 0.0001)
	assert_eq(run.take_unsaved_time(), 0.0)
	run.end_night()
	var stopped := run.time
	await get_tree().process_frame
	assert_eq(run.time, stopped)
