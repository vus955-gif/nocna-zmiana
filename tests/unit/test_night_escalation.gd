extends TestCase
## The night's curve (plan 2026-10-21-eskalacja-nocy, backlog #34): four
## phases read off the clock, an intensity that only ever rises, gaps
## between the uncanny events that shrink as the night goes on.

const HOUR := NightClock.SECONDS_PER_HOUR


func test_the_phases_follow_the_clock() -> void:
	assert_eq(NightEscalation.phase_at(0.0), NightEscalation.Phase.CALM, "23:00")
	assert_eq(NightEscalation.phase_at(2.0 * HOUR - 1.0), NightEscalation.Phase.CALM, "just before 1:00")
	assert_eq(NightEscalation.phase_at(2.0 * HOUR), NightEscalation.Phase.UNEASY, "1:00")
	assert_eq(NightEscalation.phase_at(4.0 * HOUR - 0.5), NightEscalation.Phase.UNEASY, "just before 3:00")
	assert_eq(NightEscalation.phase_at(NightClock.seconds_to_witching()), NightEscalation.Phase.WITCHING, "3:00 is the witching hour")
	assert_eq(NightEscalation.phase_at(6.0 * HOUR), NightEscalation.Phase.PREDAWN, "5:00")
	assert_eq(NightEscalation.phase_at(NightClock.seconds_to_dawn() - 1.0), NightEscalation.Phase.PREDAWN, "a second to dawn")
	assert_eq(NightEscalation.phase_at(NightClock.seconds_to_dawn() + 50.0), NightEscalation.Phase.PREDAWN, "past dawn it stays")
	assert_eq(NightEscalation.phase_at(-5.0), NightEscalation.Phase.CALM)


func test_each_phase_starts_where_the_clock_says() -> void:
	for phase in NightEscalation.PHASES:
		assert_eq(NightEscalation.phase_at(NightEscalation.phase_start(phase)), phase, "phase %d begins at its start" % phase)
	assert_eq(NightEscalation.phase_start(NightEscalation.Phase.WITCHING), NightClock.seconds_to_witching(), "the witching phase is the witching hour")


func test_the_intensity_only_rises_from_the_quiet_start_to_dawn() -> void:
	assert_almost_eq(NightEscalation.intensity(0.0), 0.1, 0.001, "23:00: quiet, not dead")
	assert_almost_eq(NightEscalation.intensity(NightClock.seconds_to_dawn()), 1.0, 0.001, "dawn: the museum is overrun")
	var last := -1.0
	var t := 0.0
	while t <= NightClock.seconds_to_dawn():
		var now := NightEscalation.intensity(t)
		assert_true(now >= last, "never falls (%.0f s: %.3f after %.3f)" % [t, now, last])
		last = now
		t += 15.0
	assert_gt(NightEscalation.intensity(NightClock.seconds_to_witching()), 0.6, "the witching hour is past the middle")


func test_the_gaps_shrink_as_the_night_goes_on() -> void:
	var last_low := INF
	var last_high := INF
	for phase in NightEscalation.PHASES:
		var low := NightEscalation.gap(phase, 2, &"none", 0.0)
		var high := NightEscalation.gap(phase, 2, &"none", 1.0)
		assert_lt(low, high, "phase %d: a range" % phase)
		assert_lt(low, last_low, "phase %d: shorter than the phase before" % phase)
		assert_lt(high, last_high, "phase %d: shorter than the phase before" % phase)
		last_low = low
		last_high = high
	assert_gt(NightEscalation.gap(NightEscalation.Phase.CALM, 2, &"none", 0.0), 90.0, "the start is calm: minutes apart")
	assert_lt(NightEscalation.gap(NightEscalation.Phase.PREDAWN, 2, &"none", 1.0), 50.0, "before dawn: under a minute")


func test_the_first_night_is_gentler_and_later_nights_denser() -> void:
	var middle := NightEscalation.gap(NightEscalation.Phase.UNEASY, 2, &"none", 0.5)
	assert_gt(NightEscalation.gap(NightEscalation.Phase.UNEASY, 1, &"none", 0.5), middle * 1.2, "night 1 learns")
	assert_almost_eq(NightEscalation.gap(NightEscalation.Phase.UNEASY, 3, &"none", 0.5), middle, 0.001, "nights 2 and 3 alike")
	assert_lt(NightEscalation.gap(NightEscalation.Phase.UNEASY, 4, &"none", 0.5), middle * 0.95, "night 4 on: denser")
	assert_almost_eq(NightEscalation.gap(NightEscalation.Phase.UNEASY, 9, &"none", 0.5), NightEscalation.gap(NightEscalation.Phase.UNEASY, 4, &"none", 0.5), 0.001, "and no denser after that")


func test_a_calm_night_is_quieter_and_a_full_moon_busier() -> void:
	var plain := NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, &"none", 0.5)
	assert_gt(NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, &"calm", 0.5), plain * 1.2, "calm")
	assert_lt(NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, &"full_moon", 0.5), plain, "full moon")
	assert_almost_eq(NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, &"blackout", 0.5), plain, 0.001, "a blackout changes what happens, not how often")


func test_changes_and_noises_grow_with_the_phase() -> void:
	assert_eq(NightEscalation.noise_scale(NightEscalation.Phase.CALM), 0.0, "the calm start wakes nobody")
	var last_noise := 0.0
	var last_change := 0.0
	for phase in NightEscalation.PHASES:
		assert_true(NightEscalation.noise_scale(phase) >= last_noise, "noise %d" % phase)
		assert_true(NightEscalation.change_scale(phase) >= last_change, "changes %d" % phase)
		last_noise = NightEscalation.noise_scale(phase)
		last_change = NightEscalation.change_scale(phase)
	assert_gt(NightEscalation.change_scale(NightEscalation.Phase.CALM), 0.0, "the world changes a little even early")
	assert_almost_eq(NightEscalation.change_scale(NightEscalation.Phase.WITCHING), 1.0, 0.001)


func test_the_phases_have_names() -> void:
	assert_eq(NightEscalation.phase_name(NightEscalation.Phase.CALM), &"calm")
	assert_eq(NightEscalation.phase_name(NightEscalation.Phase.UNEASY), &"uneasy")
	assert_eq(NightEscalation.phase_name(NightEscalation.Phase.WITCHING), &"witching")
	assert_eq(NightEscalation.phase_name(NightEscalation.Phase.PREDAWN), &"predawn")
	assert_eq(NightEscalation.PHASES.size(), 4)


func test_the_first_event_waits_for_the_night_to_settle() -> void:
	assert_gt(NightEscalation.first_wait(2, &"none"), 30.0, "nothing in the first half minute")
	assert_gt(NightEscalation.first_wait(1, &"none"), NightEscalation.first_wait(2, &"none"), "longer on night 1")
