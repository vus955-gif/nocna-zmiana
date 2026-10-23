extends TestCase
## The key panel of the options: listening for a key, swaps said out loud,
## clearing, resetting, the entry in the options menu.

var menu: OptionsMenu
var panel: KeyBindingsPanel


func before_each() -> void:
	menu = OptionsMenu.new()
	add_child(menu)
	menu.open()
	panel = menu.keys_panel


func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = pressed
	event.echo = echo
	return event


func _click(button: int, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	return event


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func test_every_action_has_a_row_with_two_places() -> void:
	panel.open()
	for action in KeyBindings.actions():
		var line := panel.row(action)
		assert_not_null(line, str(action))
		assert_eq(line.buttons.size(), 2)
	assert_eq(panel.row(&"jump").buttons[0].text, tr("BIND_KEY_SPACE"))
	assert_eq(panel.row(&"jump").buttons[1].text, "—", "an empty place")
	assert_eq(panel.row(&"punch").buttons[0].text, "V")
	assert_eq(panel.row(&"punch").buttons[1].text, tr("BIND_MOUSE_RIGHT"))
	assert_true(panel.row(&"pause").buttons[0].disabled, "Esc is fixed")
	assert_eq(panel.row(&"pause").buttons[0].text, "Esc")
	assert_false(panel.row(&"pause").buttons[1].disabled)


func test_pressing_a_place_makes_the_panel_listen_for_that_place() -> void:
	panel.open()
	panel.row(&"jump").buttons[1].pressed.emit()
	assert_eq(panel.listening_action, &"jump")
	assert_eq(panel.listening_slot, 1)
	assert_eq(panel.row(&"jump").buttons[1].text, tr("BIND_PRESS"))
	panel.row(&"fire").buttons[0].pressed.emit()
	assert_eq(panel.listening_action, &"fire", "another place takes over")
	assert_eq(panel.listening_slot, 0)
	assert_eq(panel.row(&"jump").buttons[1].text, "—", "the first one is as before")


func test_the_next_key_goes_to_the_place_listened_for() -> void:
	panel.open()
	panel.begin_listening(&"reload", 0)
	assert_true(panel.is_listening())
	assert_eq(panel.row(&"reload").buttons[0].text, tr("BIND_PRESS"))
	assert_true(panel.capture_event(_key(KEY_T)))
	assert_false(panel.is_listening())
	assert_eq(Settings.data.bindings.code_at(&"reload", 0), KEY_T)
	assert_eq(panel.row(&"reload").buttons[0].text, "T")
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.GOOD)
	assert_true(InputMap.action_has_event(&"reload", _key(KEY_T)), "applied at once")


func test_a_key_press_while_not_listening_is_not_taken() -> void:
	panel.open()
	assert_false(panel.capture_event(_key(KEY_T)))
	assert_true(Settings.data.bindings.is_default())


func test_mouse_buttons_and_the_wheel_are_taken_too() -> void:
	panel.open()
	panel.begin_listening(&"flashlight", 1)
	assert_true(panel.capture_event(_click(MOUSE_BUTTON_MIDDLE)))
	assert_eq(Settings.data.bindings.code_at(&"flashlight", 1), -MOUSE_BUTTON_MIDDLE)
	assert_eq(panel.row(&"flashlight").buttons[1].text, tr("BIND_MOUSE_MIDDLE"))
	panel.begin_listening(&"jump", 1)
	assert_false(panel.capture_event(_click(MOUSE_BUTTON_WHEEL_LEFT)), "a tilting wheel is no button")
	assert_true(panel.is_listening())
	assert_true(panel.capture_event(_click(MOUSE_BUTTON_XBUTTON2)))
	assert_eq(Settings.data.bindings.code_at(&"jump", 1), -MOUSE_BUTTON_XBUTTON2)


func test_a_release_or_a_held_key_is_not_a_new_key() -> void:
	panel.open()
	panel.begin_listening(&"reload", 0)
	assert_false(panel.capture_event(_key(KEY_ENTER, false)), "the release of the Enter that opened it")
	assert_true(panel.capture_event(_key(KEY_ENTER, true, true)), "its echo is swallowed")
	assert_true(panel.is_listening())
	assert_eq(Settings.data.bindings.code_at(&"reload", 0), KEY_R)
	assert_false(panel.capture_event(_click(MOUSE_BUTTON_LEFT, false)))


func test_esc_cancels_and_delete_clears() -> void:
	panel.open()
	panel.begin_listening(&"reload", 0)
	assert_true(panel.capture_event(_key(KEY_ESCAPE)))
	assert_false(panel.is_listening())
	assert_eq(Settings.data.bindings.code_at(&"reload", 0), KEY_R, "Esc binds nothing")
	assert_true(panel.visible, "and does not close the panel")
	# delete empties the extra place of the punch, never the last key
	panel.begin_listening(&"punch", 1)
	assert_true(panel.capture_event(_key(KEY_DELETE)))
	assert_eq(Settings.data.bindings.codes(&"punch"), [KEY_V] as Array[int])
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.GOOD)
	panel.begin_listening(&"punch", 0)
	assert_true(panel.capture_event(_key(KEY_BACKSPACE)))
	assert_eq(Settings.data.bindings.codes(&"punch"), [KEY_V] as Array[int], "its last key stays")
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.WARN)


func test_a_taken_key_swaps_and_says_so() -> void:
	panel.open()
	panel.begin_listening(&"jump", 0)
	panel.capture_event(_key(KEY_E))
	assert_eq(Settings.data.bindings.code_at(&"interact", 0), KEY_SPACE)
	assert_eq(panel.row(&"interact").buttons[0].text, tr("BIND_KEY_SPACE"), "the other row follows")
	assert_true(panel.message.contains(KeyRow.action_name(&"interact")), panel.message)
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.GOOD)


func test_the_last_key_of_another_action_is_refused_with_a_warning() -> void:
	panel.open()
	panel.begin_listening(&"fire", 1)
	panel.capture_event(_key(KEY_R))
	assert_true(Settings.data.bindings.is_default())
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.WARN)
	assert_true(panel.message.contains(KeyRow.action_name(&"reload")), panel.message)


func test_reserved_keys_are_refused_with_a_warning() -> void:
	panel.open()
	panel.begin_listening(&"jump", 1)
	panel.capture_event(_key(KEY_F3))
	assert_true(Settings.data.bindings.is_default())
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.WARN)


func test_the_fixed_pause_key_can_not_be_listened_for() -> void:
	panel.open()
	panel.begin_listening(&"pause", 0)
	assert_false(panel.is_listening())
	assert_eq(panel.message_kind, KeyBindingsPanel.Say.WARN)
	panel.begin_listening(&"pause", 1)
	assert_true(panel.is_listening())


func test_the_reset_button_brings_the_defaults_back() -> void:
	panel.open()
	panel.begin_listening(&"jump", 0)
	panel.capture_event(_key(KEY_X))
	assert_false(Settings.data.bindings.is_default())
	panel._reset.pressed.emit()
	assert_true(Settings.data.bindings.is_default())
	assert_eq(panel.row(&"jump").buttons[0].text, tr("BIND_KEY_SPACE"))
	assert_true(InputMap.action_has_event(&"jump", _key(KEY_SPACE)))


func test_a_real_key_press_reaches_the_listening_panel() -> void:
	panel.open()
	panel.begin_listening(&"reload", 0)
	Input.parse_input_event(_key(KEY_Y))
	await get_tree().process_frame
	assert_eq(Settings.data.bindings.code_at(&"reload", 0), KEY_Y)
	Input.parse_input_event(_key(KEY_Y, false))
	await get_tree().process_frame


func test_esc_closes_the_panel_not_the_options() -> void:
	menu.open_keys()
	assert_true(panel.visible)
	await _press_action(&"ui_cancel")
	assert_false(panel.visible)
	assert_true(menu.visible, "back in the options")
	await _press_action(&"ui_cancel")
	assert_false(menu.visible)


func test_esc_while_listening_only_cancels() -> void:
	menu.open_keys()
	panel.begin_listening(&"jump", 1)
	Input.parse_input_event(_key(KEY_ESCAPE))
	await get_tree().process_frame
	Input.parse_input_event(_key(KEY_ESCAPE, false))
	await get_tree().process_frame
	assert_true(panel.visible)
	assert_false(panel.is_listening())
	assert_true(menu.visible)


func test_the_options_row_opens_the_panel_and_shows_the_state() -> void:
	assert_true(menu.keys_row._value.text.begins_with(tr("OPT_KEYS_DEFAULT")))
	assert_false(panel.visible)
	menu.keys_row.activated.emit()
	assert_true(panel.visible)
	panel.begin_listening(&"jump", 0)
	panel.capture_event(_key(KEY_X))
	panel.close()
	assert_true(menu.keys_row._value.text.begins_with(tr("OPT_KEYS_CUSTOM")))
	assert_true(menu.keys_row.has_focus(), "the focus comes back to the row")


func test_the_options_menu_closing_takes_the_panel_with_it_and_saves() -> void:
	menu.open_keys()
	panel.begin_listening(&"jump", 0)
	panel.capture_event(_key(KEY_X))
	menu.close()
	assert_false(panel.visible)
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))
	Settings.reload()
	assert_eq(Settings.data.bindings.code_at(&"jump", 0), KEY_X)


func test_the_options_reset_restores_the_keys_too() -> void:
	Settings.bind(&"jump", 0, KEY_X)
	menu.reset_to_defaults()
	assert_true(Settings.data.bindings.is_default())
	assert_true(menu.keys_row._value.text.begins_with(tr("OPT_KEYS_DEFAULT")))


func test_the_names_follow_the_language() -> void:
	panel.open()
	assert_eq(panel.row(&"jump")._name.text, "Skok")
	assert_eq(panel.row(&"weapon_3")._name.text, "Broń 3")
	Settings.set_value(&"language", "en", false)
	await get_tree().process_frame
	assert_eq(panel.row(&"jump")._name.text, "Jump")
	assert_eq(panel.row(&"weapon_3")._name.text, "Weapon 3")
	assert_eq(panel.row(&"punch").buttons[1].text, "RMB")


func test_every_new_text_is_translated_in_both_languages() -> void:
	var keys: Array[String] = ["OPT_KEYS", "OPT_KEYS_DEFAULT", "OPT_KEYS_CUSTOM", "BIND_TITLE", "BIND_PRESS", "BIND_RESET", "BIND_HINTS",
		"BIND_MSG_LISTENING", "BIND_MSG_SET", "BIND_MSG_SWAPPED", "BIND_MSG_SWAPPED_SELF", "BIND_MSG_MOVED", "BIND_MSG_LAST_KEY",
		"BIND_MSG_LOCKED", "BIND_MSG_RESERVED", "BIND_MSG_NEEDS_KEY", "BIND_MSG_CLEARED", "BIND_MSG_RESET", "BIND_WEAPON", "BIND_MOUSE"]
	for group: Array in KeyBindings.GROUPS:
		keys.append(String(group[0]))
	for action in KeyBindings.actions():
		if not String(action).begins_with("weapon_") or not String(action).substr(7).is_valid_int():
			keys.append("BIND_" + String(action).to_upper())
	for locale in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s in %s" % [key, locale])
	TranslationServer.set_locale("pl")
