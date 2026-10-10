extends TestCase
## The night's clock: 23:00 to 6:00 at three minutes an hour, the witching
## hour at 3:00, dawn at 6:00, and a minute's rest per haven visit.


func test_the_shift_runs_from_eleven_to_six_three_minutes_an_hour() -> void:
	var clock := NightClock.new()
	assert_eq(clock.text(), "23:00")
	clock.advance(90.0, false)
	assert_eq(clock.text(), "23:30")
	clock.advance(90.0, false)
	assert_eq(clock.text(), "0:00")
	clock.advance(NightClock.SECONDS_PER_HOUR * 2.0 + 45.0, false)
	assert_eq(clock.text(), "2:15")
	assert_almost_eq(NightClock.seconds_to_dawn(), 21.0 * 60.0, 0.001, "a night is 21 minutes")


func test_the_witching_hour_and_dawn_come_once() -> void:
	var clock := NightClock.new()
	assert_eq(clock.advance(NightClock.seconds_to_witching() - 1.0, false), [] as Array[StringName])
	assert_false(clock.is_witching())
	assert_eq(clock.advance(2.0, false), [&"witching"] as Array[StringName])
	assert_eq(clock.text(), "3:00")
	assert_eq(clock.advance(10.0, false), [] as Array[StringName], "rung once")
	assert_eq(clock.advance(NightClock.seconds_to_dawn(), false), [&"dawn"] as Array[StringName])
	assert_true(clock.is_dawn())
	assert_eq(clock.text(), "6:00", "it stops at six")
	assert_eq(clock.advance(30.0, false), [] as Array[StringName])
	var jump := NightClock.new()
	assert_eq(jump.advance(NightClock.seconds_to_dawn() + 5.0, false), [&"witching", &"dawn"] as Array[StringName])


func test_a_haven_stops_the_clock_for_a_minute_a_visit() -> void:
	var clock := NightClock.new()
	clock.advance(40.0, true)
	assert_almost_eq(clock.elapsed, 0.0, 0.001, "resting")
	clock.advance(30.0, true)
	assert_almost_eq(clock.elapsed, 10.0, 0.001, "a minute's rest, then it runs")
	clock.advance(5.0, true)
	assert_almost_eq(clock.elapsed, 15.0, 0.001)
	for i in 25:
		clock.advance(1.0, false)
	assert_almost_eq(clock.elapsed, 40.0, 0.001)
	clock.advance(50.0, true)
	assert_almost_eq(clock.elapsed, 40.0, 0.001, "a new visit, a new minute")


func test_stepping_out_of_the_door_and_back_is_the_same_visit() -> void:
	var clock := NightClock.new()
	clock.advance(NightClock.HAVEN_ALLOWANCE, true)
	assert_almost_eq(clock.haven_left, 0.0, 0.001)
	# a wiggle in the doorway does not buy another minute
	for i in 10:
		clock.advance(1.0, false)
		clock.advance(1.0, true)
	assert_almost_eq(clock.elapsed, 20.0, 0.001, "the clock ran all the time")
	# a real round outside does
	clock.advance(NightClock.HAVEN_REFILL_AFTER - 0.5, false)
	clock.advance(1.0, true)
	assert_almost_eq(clock.elapsed, 39.5 + 1.0, 0.001, "not quite long enough outside")
	clock.advance(NightClock.HAVEN_REFILL_AFTER, false)
	var before := clock.elapsed
	clock.advance(30.0, true)
	assert_almost_eq(clock.elapsed, before, 0.001, "a new visit after a while outside")
