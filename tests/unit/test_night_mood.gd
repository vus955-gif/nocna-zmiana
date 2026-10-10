extends TestCase
## NightMood: what the night in the lobby tells the soundtrack, and which
## of it a new night or a scene swap keeps.

const STAGE := NightObjective.Stage

var mood: NightMood


func before_each() -> void:
	mood = NightMood.new()


func test_a_blank_mood_is_no_night() -> void:
	assert_eq(mood.night, 0)
	assert_eq(mood.modifier, &"none")
	assert_eq(mood.stage, NightMood.NO_STAGE)
	assert_false(mood.power_out())
	assert_false(mood.crystal_loose())
	assert_false(mood.won())
	assert_false(mood.quiet(), "a scene without a night is not a quiet night")


func test_the_objective_tells_the_state_of_the_power_and_the_crystal() -> void:
	mood.start_night(3, &"none")
	mood.set_stage(STAGE.FUSES)
	assert_false(mood.power_out())
	mood.set_stage(STAGE.PULSING)
	assert_true(mood.power_out())
	assert_false(mood.crystal_loose())
	mood.set_stage(STAGE.FLIGHT)
	assert_true(mood.crystal_loose())
	mood.set_stage(STAGE.BOSS)
	assert_true(mood.crystal_loose(), "lodged in the T-Rex")
	mood.set_stage(STAGE.DESCEND)
	assert_true(mood.won())
	assert_true(mood.power_out(), "the hall stays dark")
	assert_false(mood.crystal_loose())


func test_the_power_cut_implies_the_pulsing_stage() -> void:
	var cues := watch(mood.changed)
	mood.cut_power()
	assert_eq(mood.stage, STAGE.PULSING)
	assert_eq(cues.size(), 1)
	assert_eq(cues[0][0], &"power_cut")


func test_quiet_nights_are_the_first_and_the_calm_ones() -> void:
	mood.start_night(1, &"none")
	assert_true(mood.quiet())
	mood.start_night(4, &"calm")
	assert_true(mood.quiet())
	mood.start_night(4, &"full_moon")
	assert_false(mood.quiet())
	mood.start_night(2, &"")
	assert_eq(mood.modifier, &"none")


func test_a_new_night_forgets_the_old_one_but_keeps_its_own_setup() -> void:
	mood.start_night(2, &"full_moon")
	mood.set_stage(STAGE.BOSS)
	mood.ring_witching()
	mood.break_dawn()
	await get_tree().process_frame
	# the next museum sets up in one frame: its stage comes first
	mood.set_stage(STAGE.PULSING)
	mood.start_night(3, &"blackout")
	assert_eq(mood.stage, STAGE.PULSING, "announced by its own objective")
	assert_false(mood.witching, "the old night's witching hour is gone")
	assert_false(mood.dawn)
	assert_eq(mood.modifier, &"blackout")
	await get_tree().process_frame
	mood.ring_witching()
	mood.start_night(4, &"none")
	assert_eq(mood.stage, NightMood.NO_STAGE, "a stage from another frame is forgotten")
	assert_true(mood.witching, "a night resumed past 3:00 announces it while setting up")


func test_a_scene_swap_keeps_only_the_night_that_just_announced_itself() -> void:
	assert_false(mood.claims(true), "nothing announced")
	mood.start_night(2, &"none")
	assert_true(mood.claims(true), "the museum that has just set up")
	assert_false(mood.claims(false), "a menu is no night")
	await get_tree().process_frame
	assert_true(mood.claims(true), "one frame later (the autoloads' first look)")
	for i in NightMood.SETUP_FRAMES + 1:
		await get_tree().process_frame
	assert_false(mood.claims(true), "a later scene (a dev viewer) has no night")


func test_cues_fire_once_per_change() -> void:
	var cues := watch(mood.changed)
	mood.start_night(2, &"none")
	mood.set_stage(STAGE.FUSES)
	mood.set_stage(STAGE.FUSES)
	mood.ring_witching()
	mood.ring_witching()
	mood.break_dawn()
	mood.break_dawn()
	var names: Array = cues.map(func(args: Array) -> StringName: return args[0])
	assert_eq(names, [&"night", &"stage", &"witching", &"dawn"])
	mood.reset()
	assert_eq(mood.night, 0)
	assert_false(mood.witching)
	assert_false(mood.dawn)
