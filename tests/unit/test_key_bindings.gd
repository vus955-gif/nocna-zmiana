extends TestCase
## The key bindings' rules: defaults, swaps, refusals, settings.cfg.

var bindings: KeyBindings


func before_each() -> void:
	bindings = KeyBindings.new()


## Every key and mouse button once, no action without a key.
func _assert_sound(message: String = "") -> void:
	var seen := {}
	for action in KeyBindings.actions():
		assert_gt(bindings.codes(action).size(), 0.5, "%s keeps a key %s" % [action, message])
		assert_ne(bindings.code_at(action, 0), 0, "%s has its main key %s" % [action, message])
		for code in bindings.codes(action):
			assert_false(seen.has(code), "%d held once %s" % [code, message])
			seen[code] = action
	assert_eq(bindings.code_at(&"pause", 0), KEY_ESCAPE, "the pause keeps Esc " + message)


func test_defaults_are_the_game_input_tables() -> void:
	assert_eq(bindings.code_at(&"move_forward", 0), KEY_W)
	assert_eq(bindings.code_at(&"jump", 0), KEY_SPACE)
	assert_eq(bindings.code_at(&"punch", 0), KEY_V)
	assert_eq(bindings.code_at(&"punch", 1), -MOUSE_BUTTON_RIGHT)
	assert_eq(bindings.code_at(&"dash", 0), KEY_CTRL)
	assert_eq(bindings.code_at(&"dash", 1), -MOUSE_BUTTON_XBUTTON1)
	assert_eq(bindings.code_at(&"fire", 0), -MOUSE_BUTTON_LEFT)
	assert_eq(bindings.code_at(&"fire", 1), 0)
	assert_eq(bindings.code_at(&"weapon_next", 0), -MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(bindings.code_at(&"weapon_8", 0), KEY_8)
	assert_eq(bindings.code_at(&"map", 0), KEY_M)
	assert_true(bindings.is_default())
	_assert_sound("by default")


func test_every_game_action_can_be_rebound_except_the_dev_ones() -> void:
	var registered := {}
	for action in GameInput.KEYS:
		registered[action] = true
	for action in GameInput.MOUSE:
		registered[action] = true
	for action: StringName in registered:
		if KeyBindings.DEV_ACTIONS.has(action) or action == &"ui_up":
			continue
		assert_true(KeyBindings.is_bindable(action), "%s is in the menu" % action)
	for action in KeyBindings.actions():
		assert_true(registered.has(action), "%s is a registered action" % action)


func test_a_free_key_is_taken() -> void:
	var answer := bindings.assign(&"jump", 1, KEY_X)
	assert_eq(answer["result"], KeyBindings.Result.OK)
	assert_eq(bindings.codes(&"jump"), [KEY_SPACE, KEY_X] as Array[int])
	assert_eq(bindings.holder_of(KEY_X), &"jump")
	assert_false(bindings.is_default())
	_assert_sound()


func test_a_taken_key_swaps_with_the_other_action() -> void:
	var answer := bindings.assign(&"jump", 0, KEY_E)   # E is the interact key
	assert_eq(answer["result"], KeyBindings.Result.SWAPPED)
	assert_eq(answer["other"], &"interact")
	assert_eq(bindings.code_at(&"jump", 0), KEY_E)
	assert_eq(bindings.code_at(&"interact", 0), KEY_SPACE, "interact got what jump held")
	_assert_sound()


func test_a_taken_key_for_an_empty_place_moves_it() -> void:
	# punch holds V and the right button; the fire action takes V into its empty extra place
	var answer := bindings.assign(&"fire", 1, KEY_V)
	assert_eq(answer["result"], KeyBindings.Result.MOVED)
	assert_eq(answer["other"], &"punch")
	assert_eq(bindings.codes(&"punch"), [-MOUSE_BUTTON_RIGHT] as Array[int], "its other key moved up")
	assert_eq(bindings.code_at(&"punch", 0), -MOUSE_BUTTON_RIGHT)
	assert_eq(bindings.code_at(&"fire", 1), KEY_V)
	_assert_sound()


func test_the_last_key_of_an_action_is_never_taken() -> void:
	var answer := bindings.assign(&"fire", 1, KEY_R)   # reload's only key
	assert_eq(answer["result"], KeyBindings.Result.LAST_KEY)
	assert_eq(answer["other"], &"reload")
	assert_eq(bindings.code_at(&"reload", 0), KEY_R, "nothing changed")
	assert_eq(bindings.code_at(&"fire", 1), 0)
	_assert_sound()


func test_two_places_of_one_action_trade() -> void:
	bindings.assign(&"jump", 1, KEY_X)
	var answer := bindings.assign(&"jump", 0, KEY_X)
	assert_eq(answer["result"], KeyBindings.Result.SWAPPED)
	assert_eq(bindings.codes(&"jump"), [KEY_X, KEY_SPACE] as Array[int])
	_assert_sound()


func test_the_same_key_again_changes_nothing() -> void:
	assert_eq(bindings.assign(&"jump", 0, KEY_SPACE)["result"], KeyBindings.Result.SAME)
	assert_true(bindings.is_default())


func test_reserved_and_unknown_keys_are_refused() -> void:
	assert_eq(bindings.assign(&"jump", 1, KEY_ESCAPE)["result"], KeyBindings.Result.RESERVED)
	assert_eq(bindings.assign(&"jump", 1, KEY_F3)["result"], KeyBindings.Result.RESERVED, "the dev overlay's")
	assert_eq(bindings.assign(&"jump", 1, KEY_META)["result"], KeyBindings.Result.RESERVED)
	assert_eq(bindings.assign(&"jump", 1, 0)["result"], KeyBindings.Result.INVALID)
	assert_eq(bindings.assign(&"jump", 1, -MOUSE_BUTTON_WHEEL_LEFT)["result"], KeyBindings.Result.INVALID, "tilting the wheel")
	assert_eq(bindings.assign(&"jump", 1, 123456789)["result"], KeyBindings.Result.INVALID)
	assert_eq(bindings.assign(&"spawn_wax", 0, KEY_X)["result"], KeyBindings.Result.UNKNOWN)
	assert_eq(bindings.assign(&"jump", 2, KEY_X)["result"], KeyBindings.Result.UNKNOWN)
	assert_true(bindings.is_default())


func test_the_pause_keeps_esc_in_its_main_place() -> void:
	assert_eq(bindings.assign(&"pause", 0, KEY_P)["result"], KeyBindings.Result.LOCKED)
	assert_eq(bindings.clear(&"pause", 0)["result"], KeyBindings.Result.LOCKED)
	assert_eq(bindings.assign(&"pause", 1, KEY_P)["result"], KeyBindings.Result.OK, "an extra key is free")
	assert_eq(bindings.codes(&"pause"), [KEY_ESCAPE, KEY_P] as Array[int])
	_assert_sound()


func test_clearing_moves_the_extra_key_up_and_keeps_the_last() -> void:
	assert_eq(bindings.clear(&"punch", 0)["result"], KeyBindings.Result.OK)
	assert_eq(bindings.codes(&"punch"), [-MOUSE_BUTTON_RIGHT] as Array[int])
	assert_eq(bindings.clear(&"punch", 0)["result"], KeyBindings.Result.LAST_KEY)
	assert_eq(bindings.clear(&"punch", 1)["result"], KeyBindings.Result.SAME, "an empty place")
	_assert_sound()


func test_mouse_buttons_and_the_wheel_can_be_bound() -> void:
	assert_eq(bindings.assign(&"flashlight", 1, -MOUSE_BUTTON_MIDDLE)["result"], KeyBindings.Result.OK)
	assert_eq(bindings.assign(&"jump", 1, -MOUSE_BUTTON_WHEEL_UP)["result"], KeyBindings.Result.LAST_KEY, "the wheel up is weapon_prev's only key")
	assert_eq(bindings.assign(&"jump", 0, -MOUSE_BUTTON_WHEEL_UP)["result"], KeyBindings.Result.SWAPPED)
	assert_eq(bindings.code_at(&"weapon_prev", 0), KEY_SPACE, "weapon_prev got jump's key")
	_assert_sound()


func test_resetting_one_action_and_all() -> void:
	bindings.assign(&"jump", 0, KEY_E)   # jump <-> interact
	bindings.reset_action(&"jump")
	assert_true(bindings.is_default_action(&"jump"))
	assert_true(bindings.is_default(), "interact got its key back by the swap")
	bindings.assign(&"jump", 1, KEY_X)
	bindings.assign(&"fire", 0, KEY_Q)
	bindings.reset_all()
	assert_true(bindings.is_default())
	_assert_sound()


func test_random_changes_never_break_the_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2110
	var pool: Array[int] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_R, KEY_Q, KEY_X, KEY_Z, KEY_1, KEY_SPACE, KEY_CTRL,
		KEY_SHIFT, KEY_V, KEY_F, KEY_M, KEY_F1, KEY_F11, -MOUSE_BUTTON_LEFT, -MOUSE_BUTTON_RIGHT, -MOUSE_BUTTON_MIDDLE,
		-MOUSE_BUTTON_WHEEL_UP, -MOUSE_BUTTON_WHEEL_DOWN, -MOUSE_BUTTON_XBUTTON1, -MOUSE_BUTTON_XBUTTON2, KEY_ESCAPE, KEY_F3, KEY_TAB]
	var actions := KeyBindings.actions()
	for step in 600:
		var action := actions[rng.randi() % actions.size()]
		var slot := rng.randi() % KeyBindings.SLOTS
		if rng.randf() < 0.2:
			bindings.clear(action, slot)
		elif rng.randf() < 0.05:
			bindings.reset_action(action)
		else:
			bindings.assign(action, slot, pool[rng.randi() % pool.size()])
		if step % 25 == 0:
			_assert_sound("after step %d" % step)
	_assert_sound("at the end")


func test_only_changed_actions_are_written_and_read_back() -> void:
	bindings.assign(&"jump", 1, KEY_X)
	bindings.assign(&"fire", 0, -MOUSE_BUTTON_MIDDLE)
	var config := ConfigFile.new()
	bindings.to_config(config)
	var written := config.get_section_keys(KeyBindings.SECTION)
	assert_true(written.has("jump") and written.has("fire"), "the changed ones")
	assert_false(written.has("map"), "not the defaults")
	assert_false(written.has("pause"))
	var read := KeyBindings.new()
	var text := ConfigFile.new()
	assert_eq(text.parse(config.encode_to_text()), OK)
	read.from_config(text)
	assert_true(read.equals(bindings))
	_assert_sound()


func test_a_file_without_the_section_gives_the_defaults() -> void:
	bindings.assign(&"jump", 1, KEY_X)
	bindings.from_config(ConfigFile.new())
	assert_true(bindings.is_default(), "an old settings file")


func test_a_broken_entry_keeps_that_actions_default() -> void:
	var config := ConfigFile.new()
	config.set_value(KeyBindings.SECTION, "jump", "x")
	config.set_value(KeyBindings.SECTION, "reload", [KEY_T, 0])
	config.set_value(KeyBindings.SECTION, "map", [999999999, 0])
	config.set_value(KeyBindings.SECTION, "sprint", [KEY_ESCAPE, 0])
	config.set_value(KeyBindings.SECTION, "interact", [0, KEY_Y])
	config.set_value(KeyBindings.SECTION, "flashlight", [1.5, 0])
	config.set_value(KeyBindings.SECTION, "no_such_action", [KEY_G, 0])
	bindings.from_config(config)
	assert_eq(bindings.code_at(&"jump", 0), KEY_SPACE)
	assert_eq(bindings.code_at(&"reload", 0), KEY_T, "the good entry is kept")
	assert_eq(bindings.code_at(&"map", 0), KEY_M)
	assert_eq(bindings.code_at(&"sprint", 0), KEY_SHIFT, "Esc is not bindable")
	assert_eq(bindings.code_at(&"interact", 0), KEY_E, "an action needs its main key")
	assert_eq(bindings.code_at(&"flashlight", 0), KEY_F)
	assert_eq(bindings.holder_of(KEY_G), &"")
	_assert_sound()


func test_a_key_held_twice_brings_every_default_back() -> void:
	var config := ConfigFile.new()
	config.set_value(KeyBindings.SECTION, "reload", [KEY_T, 0])
	config.set_value(KeyBindings.SECTION, "jump", [KEY_T, 0])
	bindings.from_config(config)
	assert_true(bindings.is_default())
	# a file taking another action's default key without giving it up
	config = ConfigFile.new()
	config.set_value(KeyBindings.SECTION, "reload", [KEY_E, 0])
	bindings.from_config(config)
	assert_true(bindings.is_default(), "E is the interact key's")


func test_the_pause_in_a_file_keeps_esc() -> void:
	var config := ConfigFile.new()
	config.set_value(KeyBindings.SECTION, "pause", [KEY_P, 0])
	bindings.from_config(config)
	assert_eq(bindings.code_at(&"pause", 0), KEY_ESCAPE)
	config.set_value(KeyBindings.SECTION, "pause", [KEY_ESCAPE, KEY_P])
	bindings.from_config(config)
	assert_eq(bindings.codes(&"pause"), [KEY_ESCAPE, KEY_P] as Array[int])


func test_events_and_codes_round_trip() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	assert_eq(KeyBindings.code_of_event(key), KEY_Q)
	var made := KeyBindings.event_for(KEY_Q) as InputEventKey
	assert_eq(made.physical_keycode, KEY_Q)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_XBUTTON2
	assert_eq(KeyBindings.code_of_event(click), -MOUSE_BUTTON_XBUTTON2)
	var made_click := KeyBindings.event_for(-MOUSE_BUTTON_XBUTTON2) as InputEventMouseButton
	assert_eq(made_click.button_index, MOUSE_BUTTON_XBUTTON2)
	assert_eq(KeyBindings.code_of_event(InputEventMouseMotion.new()), 0)
	assert_eq(KeyBindings.event_for(0), null)


func test_labels_name_keys_and_mouse_buttons() -> void:
	TranslationServer.set_locale("en")
	assert_eq(KeyBindings.label(KEY_E), "E")
	assert_eq(KeyBindings.label(KEY_SPACE), "Space")
	assert_eq(KeyBindings.label(KEY_SHIFT), "Shift")
	assert_eq(KeyBindings.label(-MOUSE_BUTTON_LEFT), "LMB")
	assert_eq(KeyBindings.label(-MOUSE_BUTTON_WHEEL_UP), "Wheel up")
	assert_eq(KeyBindings.label(0), "—")
	TranslationServer.set_locale("pl")
	assert_eq(KeyBindings.label(KEY_SPACE), "Spacja")
	assert_eq(KeyBindings.label(-MOUSE_BUTTON_LEFT), "LPM")
	assert_eq(KeyBindings.label(-MOUSE_BUTTON_RIGHT), "PPM")
