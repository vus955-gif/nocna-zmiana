extends TestCase


func _peak(recoil: Recoil, channel: int, seconds: float = 1.0) -> float:
	var top := 0.0
	for i in roundi(seconds * 240.0):
		recoil.step(1.0 / 240.0)
		top = maxf(top, recoil.value(channel))
	return top


func test_a_kick_peaks_where_it_was_asked_to() -> void:
	for damping in [0.45, 0.6, 0.8, 1.0, 1.4]:
		var recoil := Recoil.new(1, 6.0, damping)
		recoil.kick(0, 2.0)
		assert_almost_eq(_peak(recoil, 0), 2.0, 0.12, "damping %.2f" % damping)


func test_it_always_comes_back_to_rest() -> void:
	var recoil := Recoil.new(3, 4.0, 0.5)
	recoil.kick(0, 0.1)
	recoil.kick(1, -3.0)
	recoil.kick(2, 12.0)
	for i in 240:
		recoil.step(1.0 / 60.0)
	assert_true(recoil.resting(1e-3), "values %.5f %.5f %.5f" % [recoil.value(0), recoil.value(1), recoil.value(2)])


## Seconds until [param recoil]'s channel 0, kicked to 1, stays within 5 %.
func _settle_time(recoil: Recoil) -> float:
	recoil.kick(0, 1.0)
	var last_out := 0.0
	for i in 480:
		recoil.step(1.0 / 240.0)
		if absf(recoil.value(0)) > 0.05:
			last_out = (i + 1) / 240.0
	return last_out


func test_a_faster_spring_settles_sooner() -> void:
	var quick := _settle_time(Recoil.new(1, 9.0, 0.75))
	var slow := _settle_time(Recoil.new(1, 2.2, 0.58))
	assert_lt(quick, 0.12, "the pistol's spring is home at once (%.3f s)" % quick)
	assert_gt(slow, 0.25, "the rifle's takes its time (%.3f s)" % slow)
	assert_lt(slow, 0.6, "but not forever")


func test_any_frame_rate_gives_the_same_kick() -> void:
	var smooth := Recoil.new(1, 3.0, 0.55)
	var choppy := Recoil.new(1, 3.0, 0.55)
	smooth.kick(0, 1.0)
	choppy.kick(0, 1.0)
	for i in 6:
		choppy.step(1.0 / 30.0)
		for j in 8:
			smooth.step(1.0 / 240.0)
	assert_almost_eq(choppy.value(0), smooth.value(0), 0.001)


func test_kicks_add_up_but_the_limit_holds() -> void:
	var recoil := Recoil.new(1, 6.0, 1.0)
	for i in 20:
		recoil.kick(0, 0.5)
		recoil.step(1.0 / 60.0)
		recoil.limit(0, 1.5)
		assert_true(recoil.value(0) <= 1.5 + 1e-6, "frame %d: %.3f" % [i, recoil.value(0)])
	assert_gt(recoil.value(0), 0.9, "a burst climbs")
