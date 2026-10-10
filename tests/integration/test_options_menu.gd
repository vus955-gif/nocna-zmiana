extends TestCase
## The options menu: one row per setting, live changes, saving on close.

var menu: OptionsMenu


func before_each() -> void:
	menu = OptionsMenu.new()
	add_child(menu)
	menu.open()


func _row(key: StringName) -> OptionRow:
	for row in menu.rows:
		if row.key == key:
			return row
	return null


func _press(action: StringName) -> void:
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


func test_every_setting_has_a_row() -> void:
	assert_eq(menu.rows.size(), SettingsData.keys().size())
	for key in SettingsData.keys():
		assert_not_null(_row(key), str(key))
	assert_true(menu.rows[0].has_focus())


func test_rows_apply_changes_live() -> void:
	_row(&"fov").step(1)
	assert_eq(Settings.data.fov, 71.0)
	_row(&"invert_y").step(1)
	assert_true(Settings.data.invert_y)
	_row(&"window_mode").step(-1)
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.MAXIMIZED)
	_row(&"volume_music").step(-1)
	assert_almost_eq(Settings.data.volume_music, 0.95)
	_row(&"max_fps").step(1)
	assert_eq(Settings.data.max_fps, 30)
	assert_false(FileAccess.file_exists(SavePaths.settings_file()), "not written while browsing")


func test_keyboard_left_right_change_the_focused_row() -> void:
	_row(&"mouse_sensitivity").grab_focus()
	await _press(&"ui_right")
	assert_almost_eq(Settings.data.mouse_sensitivity, 1.05)
	await _press(&"ui_left")
	await _press(&"ui_left")
	assert_almost_eq(Settings.data.mouse_sensitivity, 0.95)


func test_back_saves_the_settings() -> void:
	var closed := watch(menu.closed)
	_row(&"fov").step(1)
	await _press(&"ui_cancel")
	assert_false(menu.visible)
	assert_eq(closed.size(), 1)
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))
	Settings.reset_to_defaults(false)
	Settings.reload()
	assert_eq(Settings.data.fov, 71.0)


func test_reset_restores_defaults() -> void:
	_row(&"fov").step(1)
	_row(&"show_fps").step(1)
	menu.reset_to_defaults()
	assert_eq(Settings.data.fov, 70.0)
	assert_false(Settings.data.show_fps)
	assert_true(_row(&"fov")._value.text.begins_with("70"))


func test_language_row_switches_the_texts() -> void:
	_row(&"language").step(1)
	await get_tree().process_frame
	assert_eq(Settings.data.language, "en")
	assert_eq(_row(&"fov")._name.text, "Field of view")
	_row(&"language").step(1)
	await get_tree().process_frame
	assert_eq(_row(&"fov")._name.text, "Pole widzenia")
