extends TestCase
## Persistent state and the save file (a separate PersistentState per test,
## writing into the test save folder).

var state: PersistentState


func before_each() -> void:
	state = _fresh()


func _fresh() -> PersistentState:
	var fresh := PersistentState.new()
	fresh.file_path = SavePaths.dir().path_join("state_test.json")
	add_child(fresh)
	return fresh


func _fill(target: PersistentState) -> void:
	target.new_game()
	target.night = 4
	target.upgrades = {&"health": 2, &"pistol_mag": 1}
	target.add_weapon(&"pistol")
	target.pistol_key = true
	target.secrets = [&"painting"]
	target.notes = [&"note_1", &"note_2"]
	target.discover_haven(&"closet")
	target.start_haven = &"closet"
	target.lantern = {"active": true, "position": [1.5, 0.25, -7.0], "dust": 42}
	target.stats = {"deaths": 3, "nights": 3, "dust_earned": 180, "play_time": 1234.5, "bosses": 0}
	target.run_dust = 17
	target.mark_voice_heard(&"VO_HENIEK_NIGHT_1")
	target.voice_state = {"destroyed": 12, "death_turn": "system", "death_night": 2}


func test_new_game_defaults() -> void:
	state.new_game()
	assert_eq(state.night, 1)
	assert_eq(state.upgrades.size(), 0)
	assert_eq(state.weapons.size(), 0, "fists and taser are implicit")
	assert_false(state.pistol_key)
	assert_eq(state.havens, [&"security"])
	assert_eq(state.start_haven, &"security")
	assert_false(state.lantern["active"])
	assert_eq(state.stats["deaths"], 0)
	assert_false(state.demo_complete)
	assert_eq(state.run_dust, 0)


func test_save_then_load_restores_an_identical_state() -> void:
	_fill(state)
	assert_true(state.save_game())
	var loaded := _fresh()
	assert_true(loaded.load_game())
	assert_eq(loaded.to_dict(), state.to_dict())
	assert_eq(loaded.night_seed(), state.night_seed(), "same seed after loading")
	assert_eq(loaded.upgrade_level(&"health"), 2)
	assert_true(loaded.has_weapon(&"pistol"))


func test_save_is_versioned_json() -> void:
	_fill(state)
	state.save_game()
	var data: Variant = SaveFile.read_json(state.path())
	assert_true(data is Dictionary)
	if data is Dictionary:
		assert_eq(data["version"], PersistentState.VERSION)
		assert_eq(data["weapons"], ["pistol"], "weapons are stored by id")


func test_save_leaves_no_tmp_file() -> void:
	state.save_game()
	state.night = 2
	state.save_game()
	assert_true(FileAccess.file_exists(state.path()))
	assert_false(FileAccess.file_exists(state.path() + ".tmp"))


func test_corrupt_file_is_kept_as_bad_and_a_fresh_game_starts() -> void:
	SaveFile.write_text(state.path(), "{\"version\": 1, \"night\": 3,,,")
	state.night = 9
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "corrupt")
	assert_eq(state.night, 1, "fresh game")
	assert_true(FileAccess.file_exists(state.path() + ".bad"))
	assert_eq(SaveFile.read_text(state.path() + ".bad"), "{\"version\": 1, \"night\": 3,,,")
	assert_false(state.has_save(), "the broken file is out of the way")


func test_json_without_a_version_counts_as_corrupt() -> void:
	SaveFile.write_text(state.path(), "[1, 2, 3]")
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "corrupt")
	SaveFile.write_text(state.path(), "{\"night\": 3}")
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "corrupt")


func test_wrong_types_fall_back_to_defaults() -> void:
	SaveFile.write_json(state.path(), {
		"version": PersistentState.VERSION, "night": "three", "upgrades": [1, 2], "weapons": "pistol",
		"lantern": {"active": true, "position": ["x", 0, 0], "dust": 5},
		"stats": {"deaths": -4, "play_time": "long"}, "start_haven": "nowhere",
		"seed_base": 1234,
	})
	assert_true(state.load_game())
	assert_eq(state.night, 1)
	assert_eq(state.upgrades.size(), 0)
	assert_eq(state.weapons.size(), 0)
	assert_eq(state.lantern["position"], [0.0, 0.0, 0.0])
	assert_true(state.lantern["active"], "valid parts of the lantern survive")
	assert_eq(state.stats["deaths"], 0)
	assert_eq(state.stats["play_time"], 0.0)
	assert_eq(state.start_haven, &"security", "unknown haven falls back")
	assert_eq(state.seed_base, 1234)


func test_missing_file_means_no_save() -> void:
	assert_false(state.has_save())
	state.night = 5
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "missing")
	assert_eq(state.night, 5, "a missing file changes nothing")
	assert_false(FileAccess.file_exists(state.path() + ".bad"))


func test_interrupted_save_is_recovered_from_tmp() -> void:
	_fill(state)
	SaveFile.write_text(state.path() + ".tmp", JSON.stringify(state.to_dict()))
	var loaded := _fresh()
	assert_true(loaded.has_save())
	assert_true(loaded.load_game())
	assert_eq(loaded.night, 4)
	assert_true(FileAccess.file_exists(loaded.path()), "the copy became the save again")


## A save that cannot be opened (another program holds it).
class LockedState extends PersistentState:
	func _readable(_file: String) -> bool:
		return false


func test_unreadable_save_is_left_alone() -> void:
	_fill(state)
	state.save_game()
	var locked := LockedState.new()
	locked.file_path = state.path()
	add_child(locked)
	locked.night = 9
	assert_false(locked.load_game())
	assert_eq(locked.last_load_error, "unreadable")
	assert_eq(locked.night, 9, "no fresh game")
	assert_true(locked.has_save(), "New game asks before overwriting it")
	assert_false(FileAccess.file_exists(state.path() + ".bad"))
	assert_true(_fresh().load_game(), "still there, still good")


func test_failed_quarantine_keeps_the_broken_save() -> void:
	SaveFile.write_text(state.path(), "{broken")
	DirAccess.make_dir_recursive_absolute(state.path() + ".bad")   # blocks the move
	state.night = 6
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "corrupt_kept")
	assert_eq(state.night, 6, "no fresh game while the old file is in the way")
	assert_eq(FileAccess.get_file_as_string(state.path()), "{broken", "the main file survives")
	DirAccess.remove_absolute(state.path() + ".bad")


func test_broken_save_falls_back_to_the_backup() -> void:
	_fill(state)
	state.save_game()
	state.night = 5
	state.save_game()   # night 4 is now the .bak copy
	var file := FileAccess.open(state.path(), FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"night\": ")
	file.close()
	var loaded := _fresh()
	assert_true(loaded.load_game())
	assert_eq(loaded.night, 4)
	assert_eq(loaded.last_load_error, "")
	assert_true(FileAccess.file_exists(state.path() + ".bad"), "the broken one is set aside")


func test_save_from_a_newer_version_is_not_loaded_nor_moved() -> void:
	SaveFile.write_json(state.path(), {"version": PersistentState.VERSION + 1, "night": 12})
	state.night = 3
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "newer")
	assert_eq(state.night, 3)
	assert_true(FileAccess.file_exists(state.path()))
	assert_false(FileAccess.file_exists(state.path() + ".bad"))


func test_a_broken_tmp_alone_is_no_save() -> void:
	var file := FileAccess.open(state.path() + ".tmp", FileAccess.WRITE)
	file.store_string("{half a sa")
	file.close()
	assert_false(state.has_save())
	assert_false(state.load_game())
	assert_eq(state.last_load_error, "missing")


func test_failed_write_reports_it() -> void:
	var failures := watch(state.save_failed)
	state.file_path = SavePaths.dir().path_join("no_such_folder/deeper/state.json")
	assert_false(state.save_game())
	assert_eq(failures.size(), 1)


func test_night_progress_survives_save_and_load() -> void:
	_fill(state)
	state.night_progress = {
		"night": 4, "killed": [5, 1, 5, -2], "taken": [0], "used": ["fuse_a"],
		"guard": {"health": 61.5, "weapons": {"pistol": {"magazine": 3, "reserve": 20, "battery": 0.0}}},
	}
	state.save_game()
	var loaded := _fresh()
	loaded.load_game()
	assert_eq(loaded.to_dict(), state.to_dict())
	var progress := loaded.current_progress()
	assert_eq(progress["killed"], [1, 5], "sorted, no duplicates, no junk")
	assert_eq(progress["taken"], [0])
	assert_eq(progress["used"], ["fuse_a"])
	assert_eq(progress["guard"]["health"], 61.5)
	assert_eq(progress["guard"]["weapons"]["pistol"]["reserve"], 20)


func test_progress_of_another_night_is_dropped() -> void:
	_fill(state)
	state.night_progress = {"night": 3, "killed": [1]}
	state.save_game()
	var loaded := _fresh()
	loaded.load_game()
	assert_eq(loaded.night_progress, {})
	assert_eq(loaded.current_progress(), {})


func test_night_seed_is_deterministic_and_differs_per_night() -> void:
	state.seed_base = 777
	state.night = 1
	var first := state.night_seed()
	assert_eq(state.night_seed(), first)
	assert_eq(PersistentState.mix_seed(777, 1), first)
	state.night = 2
	assert_ne(state.night_seed(), first)
	state.seed_base = 778
	state.night = 1
	assert_ne(state.night_seed(), first)


func test_new_game_draws_a_new_seed_base() -> void:
	var seeds := {}
	for i in 5:
		state.new_game()
		seeds[state.seed_base] = true
		assert_true(state.seed_base >= 0 and state.seed_base <= 0x7FFFFFFF)
	assert_gt(seeds.size(), 1)


func _run_with(dust: int) -> NightState:
	var run := NightState.new()
	add_child(run)
	run.add_dust(dust, false)
	return run


func test_buying_spends_dust_and_raises_the_level() -> void:
	var run := _run_with(100)
	var bought := watch(Events.upgrade_bought)
	assert_true(state.buy_upgrade(&"health", run))
	assert_eq(state.upgrade_level(&"health"), 1)
	assert_eq(run.dust, 75)
	assert_true(state.buy_upgrade(&"health", run))
	assert_eq(state.upgrade_level(&"health"), 2)
	assert_eq(run.dust, 25)
	assert_eq(bought.size(), 2)
	if bought.size() == 2:
		assert_eq(bought[1][0], &"health")
		assert_eq(bought[1][1], 2)


func test_buying_is_refused_without_enough_dust() -> void:
	var run := _run_with(24)
	assert_false(state.buy_upgrade(&"health", run))
	assert_eq(state.upgrade_level(&"health"), 0)
	assert_eq(run.dust, 24)


func test_buying_is_refused_at_max_level() -> void:
	var run := _run_with(500)
	assert_true(state.buy_upgrade(&"shotgun_slug", run))
	assert_false(state.buy_upgrade(&"shotgun_slug", run))
	assert_eq(state.upgrade_level(&"shotgun_slug"), 1)
	assert_eq(run.dust, 420)
	assert_false(state.buy_upgrade(&"no_such_upgrade", run))


func test_buying_saves_the_game() -> void:
	var run := _run_with(60)
	assert_false(state.has_save())
	state.buy_upgrade(&"battery", run)
	assert_true(state.has_save())
	var loaded := _fresh()
	loaded.load_game()
	assert_eq(loaded.upgrade_level(&"battery"), 1)
	assert_eq(loaded.run_dust, 40, "what is left is still carried")


func test_loaded_levels_are_clamped_to_the_catalog() -> void:
	SaveFile.write_json(state.path(), {"version": 1, "upgrades": {"health": 7, "pistol_mag": 1, "jetpack": 2}})
	assert_true(state.load_game())
	assert_eq(state.upgrade_level(&"health"), 3)
	assert_eq(state.upgrade_level(&"pistol_mag"), 1)
	assert_false(state.upgrades.has(&"jetpack"))


func test_voice_lines_heard_survive_a_save() -> void:
	assert_true(state.mark_voice_heard(&"VO_A"))
	assert_false(state.mark_voice_heard(&"VO_A"), "once")
	state.voice_state = {"destroyed": 7, "death_turn": "system", "death_night": 3}
	var loaded := _fresh()
	loaded.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_true(loaded.voice_heard.has(&"VO_A"))
	assert_eq(loaded.voice_state, {"destroyed": 7, "death_turn": "system", "death_night": 3})
	loaded.from_dict({"version": PersistentState.VERSION, "voice_heard": "VO_A", "voice_state": {"destroyed": "many", "death_turn": "nobody"}})
	assert_true(loaded.voice_heard.is_empty() and loaded.voice_state.is_empty(), "junk falls back to defaults")
	loaded.reset()
	assert_true(loaded.voice_heard.is_empty() and loaded.voice_state.is_empty())
