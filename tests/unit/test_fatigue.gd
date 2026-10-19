extends TestCase
## Fatigue (plan 2026-10-10-kawiarnia-zmeczenie, section 2.1): the night's
## curve, exertion and rest, the threshold under which nothing happens, the
## effects' caps, the three coffees and the save.

const STEP := 1.0 / 60.0

var fatigue: Fatigue


func before_each() -> void:
	fatigue = Fatigue.new()


## Plays [param seconds] of the night from [param from] s (the clock's
## fraction follows), sprinting or resting all the while.
func _night(from: float, seconds: float, sprinting: bool = false, resting: bool = false) -> void:
	var t := from
	var end := from + seconds
	while t < end - STEP * 0.5:
		fatigue.night_fraction = clampf(t / Fatigue.NIGHT_SECONDS, 0.0, 1.0)
		fatigue.tick(STEP, sprinting, resting)
		t += STEP


func test_a_whole_night_of_time_alone_gives_sixty_hundredths() -> void:
	_night(0.0, Fatigue.NIGHT_SECONDS)
	assert_almost_eq(fatigue.level, Fatigue.TIME_TOTAL, 0.01, "23:00 to 6:00 without a step")
	assert_lt(fatigue.level, 1.0, "never the whole bar from time alone")


func test_the_first_half_of_the_night_stays_under_the_threshold() -> void:
	_night(0.0, Fatigue.NIGHT_SECONDS * 0.5)
	assert_lt(fatigue.level, Fatigue.THRESHOLD, "x^1.5: slow at first")
	assert_eq(fatigue.effect(), 0.0, "nothing happens yet")
	assert_eq(fatigue.capacity_factor(), 1.0)
	assert_eq(fatigue.regen_factor(), 1.0)


func test_the_curve_accelerates_after_midnight() -> void:
	var early := Fatigue.time_rate(0.1)
	var late := Fatigue.time_rate(0.9)
	assert_gt(late, early * 2.5, "the circadian dip: three times the rate late in the night")
	assert_eq(Fatigue.time_rate(0.0), 0.0, "fresh at 23:00")


func test_the_effect_runs_from_the_threshold_to_the_top() -> void:
	fatigue.level = Fatigue.THRESHOLD
	assert_eq(fatigue.effect(), 0.0)
	fatigue.level = (Fatigue.THRESHOLD + 1.0) * 0.5
	assert_almost_eq(fatigue.effect(), 0.5)
	fatigue.level = 1.0
	assert_eq(fatigue.effect(), 1.0)
	assert_almost_eq(fatigue.capacity_factor(), 1.0 - Fatigue.CAPACITY_LOSS, 0.0001, "at most 30% of the bar")
	assert_almost_eq(fatigue.regen_factor(), 1.0 - Fatigue.REGEN_LOSS, 0.0001, "at most 35% of the regen")
	assert_almost_eq(fatigue.sway_factor(), 1.0 + Fatigue.SWAY_GAIN, 0.0001)


func test_sprinting_and_dashing_add_exertion() -> void:
	fatigue.tick(10.0, true, false)
	assert_almost_eq(fatigue.level, 10.0 * Fatigue.SPRINT_PER_SEC, 0.0001, "no clock running: sprint only")
	fatigue.add_dash()
	assert_almost_eq(fatigue.level, 10.0 * Fatigue.SPRINT_PER_SEC + Fatigue.DASH, 0.0001)


func test_rest_in_a_haven_brings_it_down_and_never_below_zero() -> void:
	fatigue.level = 0.1
	fatigue.tick(60.0, false, true)
	assert_almost_eq(fatigue.level, 0.1 - 60.0 * Fatigue.REST_PER_SEC, 0.0001, "a minute's rest")
	fatigue.tick(600.0, false, true)
	assert_eq(fatigue.level, 0.0)


func test_the_level_never_passes_one() -> void:
	fatigue.level = 0.999
	for i in 100:
		fatigue.add_dash()
	fatigue.tick(1000.0, true, false)
	assert_eq(fatigue.level, 1.0)
	assert_eq(fatigue.effect(), 1.0)


func test_espresso_is_short_and_strong() -> void:
	fatigue.level = 0.8
	assert_true(fatigue.drink(&"espresso"))
	assert_almost_eq(fatigue.level, 0.5, 0.0001, "30 hundredths at once")
	assert_true(fatigue.caffeinated())
	assert_eq(fatigue.buff, &"espresso")
	assert_almost_eq(fatigue.buff_left, 90.0)
	fatigue.level = 0.0
	assert_almost_eq(fatigue.regen_factor(), 1.25, 0.0001, "+25% regen while it lasts")
	assert_false(fatigue.blocks_rise(), "the night goes on rising")
	fatigue.tick(89.0, false, false)
	assert_true(fatigue.caffeinated())
	fatigue.tick(1.5, false, false)
	assert_false(fatigue.caffeinated(), "90 s and it is gone")
	assert_eq(fatigue.buff, &"")
	assert_almost_eq(fatigue.regen_factor(), 1.0, 0.0001)


func test_the_large_coffee_is_long_and_weak_and_holds_the_night_still() -> void:
	fatigue.level = 0.5
	fatigue.drink(&"large")
	assert_almost_eq(fatigue.level, 0.35, 0.0001, "15 hundredths at once")
	assert_almost_eq(fatigue.buff_left, 240.0)
	assert_almost_eq(fatigue.regen_factor(), 1.1, 0.0001)
	assert_true(fatigue.blocks_rise())
	fatigue.night_fraction = 0.9
	fatigue.tick(100.0, true, false)
	fatigue.add_dash()
	assert_almost_eq(fatigue.level, 0.35, 0.0001, "time, sprint and dash add nothing while it lasts")
	fatigue.tick(141.0, false, false)
	assert_false(fatigue.caffeinated())
	fatigue.tick(10.0, true, false)
	assert_gt(fatigue.level, 0.35, "and then the night goes on")


func test_the_witching_special_is_the_strongest_and_shakes_the_hands() -> void:
	fatigue.level = 0.9
	fatigue.drink(&"special")
	assert_almost_eq(fatigue.level, 0.45, 0.0001)
	assert_almost_eq(fatigue.buff_left, 60.0)
	assert_almost_eq(fatigue.regen_factor(), (1.0 - Fatigue.REGEN_LOSS * fatigue.effect()) * 1.4, 0.0001)
	assert_almost_eq(fatigue.jitter(), 1.0, 0.0001, "the hands shake at once")
	assert_almost_eq(fatigue.sway_factor(), (1.0 + Fatigue.SWAY_GAIN * fatigue.effect()) * 2.0, 0.0001, "twice the sway")
	fatigue.tick(6.0, false, false)
	assert_almost_eq(fatigue.jitter(), 0.5, 0.01, "fading")
	fatigue.tick(7.0, false, false)
	assert_eq(fatigue.jitter(), 0.0, "12 s and the hands are steady")
	assert_true(fatigue.caffeinated(), "the caffeine outlasts the shakes")
	assert_false(fatigue.drink(&"tea"), "no such drink")


func test_a_shorter_coffee_does_not_throw_away_the_longer_caffeine() -> void:
	fatigue.level = 0.9
	fatigue.drink(&"large")
	fatigue.tick(100.0, false, false)
	fatigue.drink(&"espresso")
	assert_eq(fatigue.buff, &"large", "the large coffee's 140 s outlast the espresso's 90")
	assert_almost_eq(fatigue.buff_left, 140.0, 0.0001, "and are not cut short, nor added to")
	assert_almost_eq(fatigue.level, 0.9 - 0.15 - 0.30, 0.0001, "both reliefs count in full")
	assert_true(fatigue.blocks_rise(), "the night still stands still")


func test_a_longer_coffee_takes_over_from_a_spent_one() -> void:
	fatigue.level = 0.9
	fatigue.drink(&"espresso")
	fatigue.tick(60.0, false, false)
	fatigue.drink(&"large")
	assert_eq(fatigue.buff, &"large", "240 s beat the espresso's 30 s left")
	assert_almost_eq(fatigue.buff_left, 240.0, 0.0001)
	fatigue.tick(200.0, false, false)
	fatigue.drink(&"espresso")
	assert_eq(fatigue.buff, &"espresso", "and the espresso's 90 beat the large's last 40")
	assert_almost_eq(fatigue.buff_left, 90.0, 0.0001)
	assert_almost_eq(fatigue.level, 0.9 - 0.30 - 0.15 - 0.30, 0.0001, "the reliefs keep adding up")


func test_the_same_cup_again_starts_its_time_over() -> void:
	fatigue.level = 0.9
	fatigue.drink(&"espresso")
	fatigue.tick(80.0, false, false)
	fatigue.drink(&"espresso")
	assert_almost_eq(fatigue.buff_left, 90.0, 0.0001, "a fresh 90 s, not 10 + 90")


func test_the_special_after_a_large_coffee_keeps_the_large_but_shakes_the_hands() -> void:
	fatigue.level = 0.9
	fatigue.drink(&"large")
	fatigue.tick(10.0, false, false)
	fatigue.drink(&"special")
	assert_eq(fatigue.buff, &"large", "230 s left against the special's 60")
	assert_almost_eq(fatigue.buff_left, 230.0, 0.0001)
	assert_almost_eq(fatigue.level, 0.9 - 0.15 - 0.45, 0.0001, "the relief counts")
	assert_almost_eq(fatigue.jitter(), 1.0, 0.0001, "and the hands shake all the same")


func test_the_save_keeps_level_coffee_and_shakes() -> void:
	fatigue.level = 0.42
	fatigue.night_fraction = 0.7
	fatigue.drink(&"special")
	fatigue.tick(4.0, false, false)
	var copy := Fatigue.new()
	copy.from_dict(fatigue.to_dict())
	assert_almost_eq(copy.level, fatigue.level, 0.0001)
	assert_eq(copy.buff, &"special")
	assert_almost_eq(copy.buff_left, 56.0, 0.0001)
	assert_almost_eq(copy.jitter_left, 8.0, 0.0001)
	assert_eq(copy.night_fraction, 0.0, "the clock feeds the fraction, not the save")
	var junk := Fatigue.new()
	junk.from_dict({"level": 7.0, "buff": "tea", "buff_left": -3.0})
	assert_eq(junk.level, 1.0, "clamped")
	assert_eq(junk.buff, &"", "an unknown drink is no drink")
	assert_false(junk.caffeinated())


func test_reset_is_a_fresh_guard() -> void:
	fatigue.level = 0.7
	fatigue.drink(&"special")
	fatigue.night_fraction = 0.5
	fatigue.reset()
	assert_eq(fatigue.level, 0.0)
	assert_false(fatigue.caffeinated())
	assert_eq(fatigue.jitter(), 0.0)
	assert_eq(fatigue.night_fraction, 0.0)


# --- the voice hears the stages (plan 2026-10-19-glos-g2-kwestie) ---------------

func test_the_stage_follows_the_level() -> void:
	fatigue.level = Fatigue.THRESHOLD - 0.01
	assert_eq(fatigue.stage(), 0, "below the threshold")
	fatigue.level = Fatigue.THRESHOLD
	assert_eq(fatigue.stage(), 1, "tired")
	fatigue.level = Fatigue.WORN_OUT
	assert_eq(fatigue.stage(), 2, "worn out")


func test_a_rise_is_told_once_and_again_after_a_coffee() -> void:
	fatigue.level = 0.2
	assert_eq(fatigue.take_rise(), 0, "fresh: nothing to tell")
	fatigue.level = Fatigue.THRESHOLD + 0.01
	assert_eq(fatigue.take_rise(), 1)
	assert_eq(fatigue.take_rise(), 0, "told once")
	fatigue.level = Fatigue.WORN_OUT + 0.01
	assert_eq(fatigue.take_rise(), 2)
	fatigue.drink(&"special")   # well below the threshold again
	assert_eq(fatigue.take_rise(), 0, "a fall is not told")
	fatigue.level = Fatigue.THRESHOLD + 0.01
	assert_eq(fatigue.take_rise(), 1, "tired again")


func test_a_restored_level_is_not_told_again_but_a_fresh_guard_tells_it() -> void:
	fatigue.level = 0.5
	var copy := Fatigue.new()
	copy.from_dict(fatigue.to_dict())
	assert_eq(copy.take_rise(), 0, "a resumed night keeps its tiredness quiet")
	fatigue.reset()
	fatigue.level = 0.5
	assert_eq(fatigue.take_rise(), 1)
