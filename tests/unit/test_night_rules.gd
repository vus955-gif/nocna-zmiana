extends TestCase
## Death, the dropped lantern, havens and the start of a night.

var game: PersistentState
var run: NightState


func before_each() -> void:
	game = PersistentState.new()
	game.file_path = SavePaths.dir().path_join("rules_test.json")
	add_child(game)
	game.new_game()
	run = NightState.new()
	add_child(run)
	NightRules.start_night(game, run)


func test_death_moves_carried_dust_into_the_lantern() -> void:
	run.add_dust(37, false)
	NightRules.on_death(game, run, Vector3(4.0, 0.0, -2.5))
	assert_true(game.lantern["active"])
	assert_eq(game.lantern["dust"], 37)
	assert_eq(game.lantern["position"], [4.0, 0.0, -2.5])
	assert_eq(run.dust, 0)
	assert_false(run.running)


func test_an_older_lantern_is_lost() -> void:
	run.add_dust(50, false)
	NightRules.on_death(game, run, Vector3(1, 0, 1))
	NightRules.start_night(game, run)
	run.add_dust(8, false)
	NightRules.on_death(game, run, Vector3(9, 0, 9))
	assert_eq(game.lantern["dust"], 8, "the 50 from before are gone")
	assert_eq(game.lantern["position"], [9.0, 0.0, 9.0])


func test_no_lantern_without_dust() -> void:
	run.add_dust(20, false)
	NightRules.on_death(game, run, Vector3(1, 0, 1))
	NightRules.start_night(game, run)
	NightRules.on_death(game, run, Vector3(2, 0, 2))
	assert_false(game.lantern["active"], "dying empty-handed still loses the old lantern")


func test_death_advances_the_night_and_counts_it() -> void:
	assert_eq(game.night, 1)
	NightRules.on_death(game, run, Vector3.ZERO)
	assert_eq(game.night, 2)
	assert_eq(game.stats["deaths"], 1)
	assert_eq(game.stats["nights"], 1)
	assert_eq(game.run_dust, 0)


func test_death_saves_the_game() -> void:
	run.add_dust(12, false)
	NightRules.on_death(game, run, Vector3(3, 0, 3))
	var loaded := PersistentState.new()
	loaded.file_path = game.file_path
	add_child(loaded)
	assert_true(loaded.load_game())
	assert_eq(loaded.night, 2)
	assert_eq(loaded.lantern["dust"], 12)


func test_lantern_returns_its_dust_once() -> void:
	run.add_dust(25, false)
	NightRules.on_death(game, run, Vector3.ZERO)
	NightRules.start_night(game, run)
	run.set_multiplier(&"full_moon", 1.5)
	assert_eq(NightRules.recover_lantern(game, run), 25)
	assert_eq(run.dust, 25, "no multipliers on recovered Dust")
	assert_false(game.lantern["active"])
	assert_eq(NightRules.recover_lantern(game, run), 0)
	assert_eq(run.dust, 25)


func test_entering_a_haven_saves_carried_dust_and_sets_the_start() -> void:
	run.add_dust(33, false)
	NightRules.enter_haven(game, run, &"closet")
	assert_eq(game.start_haven, &"closet")
	assert_true(game.havens.has(&"closet"))
	assert_eq(game.run_dust, 33)
	assert_true(game.has_save())


func test_start_night_seeds_the_run_and_restores_carried_dust() -> void:
	game.run_dust = 14
	NightRules.start_night(game, run)
	assert_eq(run.dust, 14)
	assert_true(run.running)
	var first := run.rng.randi()
	NightRules.start_night(game, run)
	assert_eq(run.rng.randi(), first, "same night, same seed")


func test_an_unfinished_night_resumes_what_was_done() -> void:
	run.mark_killed(3)
	run.mark_killed(0)
	run.mark_taken(2)
	run.mark_used(&"fuse_a")
	game.night_progress = NightRules.progress_snapshot(game, run, {"health": 40.0})
	NightRules.save_progress(game, run)
	NightRules.start_night(game, run)
	assert_eq(run.killed_slots, [0, 3] as Array[int])
	assert_eq(run.taken_loot, [2] as Array[int])
	assert_true(run.is_used(&"fuse_a"))
	assert_eq(game.current_progress()["guard"]["health"], 40.0)


func test_death_starts_the_next_night_full() -> void:
	run.mark_killed(1)
	game.night_progress = NightRules.progress_snapshot(game, run)
	NightRules.on_death(game, run, Vector3.ZERO)
	assert_eq(game.night_progress, {})
	NightRules.start_night(game, run)
	assert_eq(run.killed_slots.size(), 0)
	var loaded := PersistentState.new()
	loaded.file_path = game.file_path
	add_child(loaded)
	loaded.load_game()
	assert_eq(loaded.night_progress, {}, "cleared on disk too")


func test_progress_of_an_older_night_is_ignored() -> void:
	game.night_progress = {"night": game.night, "killed": [4]}
	game.night += 1
	NightRules.start_night(game, run)
	assert_eq(run.killed_slots.size(), 0)
	assert_eq(game.night_progress, {})
