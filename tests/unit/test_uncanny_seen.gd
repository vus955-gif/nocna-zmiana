extends TestCase
## The uncanny moments seen once per game survive saving, death and
## quitting (plan 2026-10-21-eskalacja-nocy, 2.3).

var state: PersistentState


func before_each() -> void:
	state = PersistentState.new()
	state.file_path = SavePaths.dir().path_join("uncanny_test.json")
	add_child(state)


func test_a_moment_is_seen_once() -> void:
	state.new_game()
	assert_false(state.has_seen_uncanny(&"court_eyes"))
	assert_true(state.see_uncanny(&"court_eyes"), "the first time")
	assert_false(state.see_uncanny(&"court_eyes"), "only once")
	assert_true(state.has_seen_uncanny(&"court_eyes"))


func test_the_moments_seen_survive_a_save() -> void:
	state.new_game()
	state.see_uncanny(&"court_eyes")
	state.see_uncanny(&"clocks_backwards")
	assert_true(state.save_game())
	var loaded := PersistentState.new()
	loaded.file_path = state.file_path
	add_child(loaded)
	assert_true(loaded.load_game())
	assert_eq(loaded.uncanny_seen, [&"court_eyes", &"clocks_backwards"] as Array[StringName])
	assert_eq(loaded.to_dict(), state.to_dict())


func test_junk_and_an_older_save_give_none() -> void:
	state.from_dict({"version": PersistentState.VERSION, "uncanny_seen": "court_eyes"})
	assert_true(state.uncanny_seen.is_empty(), "not a list")
	state.from_dict({"version": PersistentState.VERSION, "uncanny_seen": ["court_eyes", 7, "court_eyes"]})
	assert_eq(state.uncanny_seen, [&"court_eyes"] as Array[StringName], "names only, once each")
	state.from_dict({"version": PersistentState.VERSION})
	assert_true(state.uncanny_seen.is_empty(), "a save from before the field")


func test_a_new_game_forgets_them() -> void:
	state.see_uncanny(&"court_eyes")
	state.new_game()
	assert_true(state.uncanny_seen.is_empty())
