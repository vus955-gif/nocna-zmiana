extends TestCase
## Floor I progress in the save (version 2): every field survives save and
## load, the adders report new entries, junk falls back to defaults, and a
## lobby save (version 1) is migrated: weapons, upgrades, the key,
## statistics and Dust stay, lobby-only progress starts over.

var state: PersistentState


func before_each() -> void:
	state = _fresh()


func _fresh() -> PersistentState:
	var fresh := PersistentState.new()
	fresh.file_path = SavePaths.dir().path_join("floor1_state_test.json")
	add_child(fresh)
	return fresh


## A version-1 save as the lobby demo wrote it.
func _lobby_save() -> Dictionary:
	return {
		"version": 1,
		"night": 7,
		"seed_base": 4242,
		"upgrades": {"health": 2, "pistol_mag": 1},
		"weapons": ["pistol", "shotgun", "gatling"],
		"pistol_key": true,
		"secrets": ["secret_painting", "secret_vent"],
		"notes": ["note_1", "note_2"],
		"havens": ["security", "closet"],
		"start_haven": "closet",
		"lantern": {"active": true, "position": [3.0, 6.0, -12.0], "dust": 55},
		"stats": {"deaths": 4, "nights": 6, "dust_earned": 610, "play_time": 3600.5, "bosses": 1},
		"demo_complete": true,
		"run_dust": 20,
		"night_progress": {"night": 7, "killed": [1, 2], "taken": [], "used": []},
	}


func test_new_game_has_no_floor_progress() -> void:
	state.new_game()
	for list in [state.gates_open, state.guardians_defeated, state.seals, state.shards, state.items, state.flags, state.rooms_visited, state.chess_found]:
		assert_eq(list.size(), 0)
	assert_eq(state.difficulty, &"night", "Nocna zmiana is the default")


func test_adders_report_new_entries_only() -> void:
	assert_true(state.open_gate(&"boards_tomb"))
	assert_false(state.open_gate(&"boards_tomb"), "twice is not new")
	assert_true(state.is_gate_open(&"boards_tomb"))
	assert_true(state.defeat_guardian(&"colossus"))
	assert_true(state.is_guardian_defeated(&"colossus"))
	assert_true(state.add_seal(&"seal_sun"))
	assert_true(state.add_shard(&"shard_egypt"))
	assert_false(state.add_shard(&"shard_egypt"))
	assert_true(state.add_item(&"fuse_basement"))
	assert_true(state.has_item(&"fuse_basement"))
	assert_true(state.set_flag(&"power_north"))
	assert_true(state.has_flag(&"power_north"))
	assert_true(state.visit_room(&"egypt_gallery"), "the first visit")
	assert_false(state.visit_room(&"egypt_gallery"), "not the first any more")
	assert_true(state.find_chess(&"chess_king"))
	assert_false(state.open_gate(&""), "an empty id is never stored")


func test_every_progress_field_survives_save_and_load() -> void:
	state.new_game()
	state.open_gate(&"seal_khorsabad")
	state.open_gate(&"bolt_basement_egypt")
	state.defeat_guardian(&"colossus")
	state.defeat_guardian(&"lamassu")
	state.add_seal(&"seal_sun")
	state.add_seal(&"seal_wing")
	state.add_shard(&"shard_egypt")
	state.add_shard(&"shard_assyria")
	state.add_item(&"fuse_assyria")
	state.set_flag(&"power_north")
	state.visit_room(&"court")
	state.visit_room(&"egypt_colossus")
	state.find_chess(&"chess_queen")
	state.mark_voice_heard(&"VO_GUIDE_ROSETTA_B")
	state.difficulty = &"double"
	assert_true(state.save_game())
	var loaded := _fresh()
	assert_true(loaded.load_game())
	assert_eq(loaded.to_dict(), state.to_dict())
	assert_eq(loaded.gates_open, [&"seal_khorsabad", &"bolt_basement_egypt"])
	assert_eq(loaded.guardians_defeated, [&"colossus", &"lamassu"])
	assert_eq(loaded.seals, [&"seal_sun", &"seal_wing"])
	assert_eq(loaded.shards.size(), 2)
	assert_true(loaded.has_item(&"fuse_assyria"))
	assert_true(loaded.has_flag(&"power_north"))
	assert_eq(loaded.rooms_visited, [&"court", &"egypt_colossus"])
	assert_eq(loaded.chess_found, [&"chess_queen"])
	assert_eq(loaded.voice_heard, [&"VO_GUIDE_ROSETTA_B"])
	assert_eq(loaded.difficulty, &"double")
	var data: Variant = SaveFile.read_json(state.path())
	assert_eq((data as Dictionary)["version"], 2)
	assert_eq((data as Dictionary)["seals"], ["seal_sun", "seal_wing"], "stored as plain strings")


func test_junk_progress_falls_back_to_defaults() -> void:
	SaveFile.write_json(state.path(), {
		"version": 2, "gates_open": "all", "seals": [1, "seal_sun", "seal_sun", null],
		"shards": {"a": 1}, "difficulty": "nightmare", "rooms_visited": ["court", 3],
	})
	assert_true(state.load_game())
	assert_eq(state.gates_open.size(), 0)
	assert_eq(state.seals, [&"seal_sun"], "only names, once")
	assert_eq(state.shards.size(), 0)
	assert_eq(state.difficulty, &"night", "unknown difficulty falls back")
	assert_eq(state.rooms_visited, [&"court"])


func test_a_lobby_save_keeps_what_the_guard_owns() -> void:
	SaveFile.write_json(state.path(), _lobby_save())
	assert_true(state.load_game())
	assert_eq(state.weapons, [&"pistol", &"shotgun", &"gatling"], "weapons stay")
	assert_eq(state.upgrade_level(&"health"), 2, "upgrades stay")
	assert_eq(state.upgrade_level(&"pistol_mag"), 1)
	assert_true(state.pistol_key, "the locker key stays")
	assert_eq(state.seed_base, 4242)
	assert_eq(state.stats["deaths"], 4, "statistics stay")
	assert_eq(state.stats["nights"], 6)
	assert_eq(state.stats["dust_earned"], 610)
	assert_eq(state.stats["bosses"], 1)
	assert_almost_eq(float(state.stats["play_time"]), 3600.5)
	assert_eq(state.run_dust, 75, "the carried Dust plus the lobby lantern's")


func test_a_lobby_save_drops_lobby_only_progress() -> void:
	SaveFile.write_json(state.path(), _lobby_save())
	assert_true(state.load_game())
	assert_eq(state.night, 1, "the first night on the new floor is the gentle one")
	assert_eq(state.secrets.size(), 0, "lobby secrets")
	assert_eq(state.notes.size(), 0, "lobby notes")
	assert_eq(state.havens, [&"security"], "the broom closet is gone")
	assert_eq(state.start_haven, &"security")
	assert_false(state.lantern["active"], "no lantern on a floor it never saw")
	assert_false(state.demo_complete, "the lobby's ending")
	assert_eq(state.current_progress(), {}, "no night in progress")
	assert_eq(state.gates_open.size(), 0)
	assert_eq(state.difficulty, &"night")


func test_a_migrated_save_is_written_back_as_version_2() -> void:
	SaveFile.write_json(state.path(), _lobby_save())
	assert_true(state.load_game())
	assert_true(state.save_game())
	var data: Variant = SaveFile.read_json(state.path())
	assert_eq((data as Dictionary)["version"], PersistentState.VERSION)
	var again := _fresh()
	assert_true(again.load_game())
	assert_eq(again.to_dict(), state.to_dict(), "loading it again changes nothing")
	assert_eq(again.run_dust, 75, "the lantern's Dust is not counted twice")


func test_a_lobby_save_without_a_lantern_keeps_its_dust() -> void:
	var old := _lobby_save()
	old["lantern"] = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	old.erase("run_dust")
	SaveFile.write_json(state.path(), old)
	assert_true(state.load_game())
	assert_eq(state.run_dust, 0)
	assert_false(state.lantern["active"])
