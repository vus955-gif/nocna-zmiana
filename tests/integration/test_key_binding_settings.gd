extends TestCase
## The player's keys in the game: stored in settings.cfg, applied to the
## InputMap at runtime, named in the prompts.


func _key_event(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = pressed
	return event


func _click_event(button: int, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	return event


func _bound_to(action: StringName, event: InputEvent) -> bool:
	return InputMap.action_has_event(action, event)


func test_a_rebound_key_drives_the_action_at_once() -> void:
	assert_true(_bound_to(&"jump", _key_event(KEY_SPACE)))
	Settings.bind(&"jump", 0, KEY_X)
	assert_true(_bound_to(&"jump", _key_event(KEY_X)), "the new key")
	assert_false(_bound_to(&"jump", _key_event(KEY_SPACE)), "not the old one")
	# a real event reaches the game's action
	Input.parse_input_event(_key_event(KEY_X))
	await get_tree().process_frame
	assert_true(Input.is_action_pressed(&"jump"))
	Input.parse_input_event(_key_event(KEY_X, false))
	await get_tree().process_frame
	assert_false(Input.is_action_pressed(&"jump"))


func test_a_mouse_button_can_drive_an_action() -> void:
	Settings.bind(&"flashlight", 1, -MOUSE_BUTTON_MIDDLE)
	assert_true(_bound_to(&"flashlight", _click_event(MOUSE_BUTTON_MIDDLE)))
	assert_true(_bound_to(&"flashlight", _key_event(KEY_F)), "its key stays")


func test_the_pads_buttons_survive_a_change() -> void:
	var pad := InputEventJoypadButton.new()
	pad.device = -1
	pad.button_index = JOY_BUTTON_BACK
	assert_true(_bound_to(&"map", pad), "the map's pad button")
	Settings.bind(&"map", 0, KEY_N)
	assert_true(_bound_to(&"map", pad), "after rebinding the key")
	Settings.reset_bindings()
	assert_true(_bound_to(&"map", pad), "after resetting")


func test_a_swap_changes_both_actions() -> void:
	var answer := Settings.bind(&"jump", 0, KEY_E)
	assert_eq(answer["result"], KeyBindings.Result.SWAPPED)
	assert_true(_bound_to(&"interact", _key_event(KEY_SPACE)))
	assert_false(_bound_to(&"interact", _key_event(KEY_E)))
	assert_true(_bound_to(&"jump", _key_event(KEY_E)))


func test_a_refused_change_leaves_the_input_map_alone() -> void:
	var answer := Settings.bind(&"jump", 1, KEY_ESCAPE)
	assert_eq(answer["result"], KeyBindings.Result.RESERVED)
	assert_false(_bound_to(&"jump", _key_event(KEY_ESCAPE)))
	assert_true(Settings.data.bindings.is_default())


func test_the_keys_are_saved_and_come_back() -> void:
	Settings.bind(&"reload", 0, KEY_T, true)
	Settings.bind(&"fire", 1, KEY_G, true)
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))
	Settings.reset_to_defaults(false)
	assert_true(_bound_to(&"reload", _key_event(KEY_R)))
	Settings.reload()
	assert_eq(Settings.data.bindings.code_at(&"reload", 0), KEY_T)
	assert_true(_bound_to(&"reload", _key_event(KEY_T)), "applied to the InputMap on loading")
	assert_false(_bound_to(&"reload", _key_event(KEY_R)))
	assert_true(_bound_to(&"fire", _key_event(KEY_G)))
	assert_true(_bound_to(&"fire", _click_event(MOUSE_BUTTON_LEFT)), "the default stays beside it")


func test_changes_are_written_a_moment_later_like_the_other_options() -> void:
	Settings.bind(&"reload", 0, KEY_T)
	assert_false(FileAccess.file_exists(SavePaths.settings_file()), "not at once")
	assert_true(Settings.has_unsaved_changes())
	Settings.flush()
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))


func test_an_old_settings_file_without_keys_loads_the_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "fov", 90.0)
	config.set_value("settings", "language", "en")
	SaveFile.write_text(SavePaths.settings_file(), config.encode_to_text())
	Settings.bind(&"jump", 0, KEY_X)   # whatever was set before
	Settings.reload()
	assert_eq(Settings.data.fov, 90.0)
	assert_true(Settings.data.bindings.is_default())
	assert_true(_bound_to(&"jump", _key_event(KEY_SPACE)))
	assert_false(_bound_to(&"jump", _key_event(KEY_X)))


func test_resetting_the_options_brings_the_keys_back_too() -> void:
	Settings.bind(&"jump", 0, KEY_X)
	Settings.reset_to_defaults(false)
	assert_true(Settings.data.bindings.is_default())
	assert_true(_bound_to(&"jump", _key_event(KEY_SPACE)))
	assert_false(_bound_to(&"jump", _key_event(KEY_X)))


func test_the_change_is_announced() -> void:
	var seen := watch(Settings.settings_changed)
	Settings.bind(&"reload", 0, KEY_T)
	assert_eq(seen.size(), 1, "one announcement")
	assert_eq(seen[0][0], &"bindings")
	Settings.bind(&"reload", 0, KEY_ESCAPE)
	assert_eq(seen.size(), 1, "a refusal says nothing")


func test_prompts_name_the_current_keys() -> void:
	assert_eq(GameInput.key_label(&"interact"), "E")
	Settings.bind(&"interact", 0, KEY_Q)
	assert_eq(GameInput.key_label(&"interact"), "Q", "the cached label follows")
	Settings.bind(&"interact", 0, -MOUSE_BUTTON_MIDDLE)
	assert_eq(GameInput.key_label(&"interact"), tr("BIND_MOUSE_MIDDLE"))
	assert_eq(GameInput.binding_labels(&"punch").size(), 2, "V and the right button")
	assert_eq(GameInput.key_label(&"fire"), tr("BIND_MOUSE_LEFT"), "an action on the mouse only")


func test_labels_follow_the_language() -> void:
	Settings.set_value(&"language", "en", false)
	assert_eq(GameInput.key_label(&"fire"), "LMB")
	Settings.set_value(&"language", "pl", false)
	assert_eq(GameInput.key_label(&"fire"), "LPM")


func test_the_dev_actions_keep_their_keys() -> void:
	Settings.bind(&"jump", 1, KEY_X)
	assert_true(_bound_to(&"spawn_wax", _key_event(KEY_F5)))
	assert_true(_bound_to(&"toggle_perf", _key_event(KEY_F3)))
