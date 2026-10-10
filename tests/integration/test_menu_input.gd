extends TestCase
## Menus driven the way a player drives them: through real input events
## (keys, clicks, the mouse wheel) in the order the engine delivers them,
## not by calling the menus' methods.

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		if museum.upgrade_menu.is_open:
			museum.upgrade_menu.close()
		museum.free()
	get_tree().paused = false


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


## Press, hold for a few physics steps, release (as a player taps a key).
func _tap(action: StringName) -> void:
	_action(action, true)
	await physics_frames(3)
	_action(action, false)
	await physics_frames(3)


func _key(keycode: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = keycode
	release.keycode = keycode
	Input.parse_input_event(release)
	await get_tree().process_frame


## A left click (press and release in the same frame) at a control's
## [param local] point.
func _click(control: Control, local: Vector2) -> void:
	var at := get_viewport().get_final_transform() * (control.get_global_rect().position + local)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
	await get_tree().process_frame


func _wheel(control: Control, button: MouseButton) -> void:
	var at := get_viewport().get_final_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
	await get_tree().process_frame


## The guard in the booth, looking at the terminal.
func _at_the_terminal() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var terminal := museum.find_child("Terminal_security", true, false) as Node3D
	# 1.3 m in front of its screen, looking down at it
	var front := -terminal.global_transform.basis.z
	museum.player.global_position = terminal.global_position + front * 1.3 + Vector3.UP * 0.1
	museum.player.head.rotation = Vector3(-0.45, atan2(front.x, front.z), 0.0)
	var waited := 0
	while museum.player.interactor.focus != terminal and waited < 30:
		await physics_frames(1)   # the eyes follow the body a frame behind
		waited += 1
	assert_eq(museum.player.interactor.focus, terminal, "terminal in focus")


func test_e_opens_the_terminal_and_closes_it_for_good() -> void:
	await _at_the_terminal()
	await _tap(&"interact")
	assert_true(museum.upgrade_menu.is_open, "E opens the terminal")
	var closes := watch(museum.upgrade_menu.closed)
	await _tap(&"interact")
	await physics_frames(3)
	assert_false(museum.upgrade_menu.is_open, "the E that closed it did not open it again")
	assert_eq(closes.size(), 1)
	assert_false(get_tree().paused)


func test_esc_closes_the_terminal_without_pausing() -> void:
	await _at_the_terminal()
	await _tap(&"interact")
	assert_true(museum.upgrade_menu.is_open)
	await _tap(&"ui_cancel")
	assert_false(museum.upgrade_menu.is_open)
	assert_false(museum.pause_menu.is_open)
	assert_false(get_tree().paused)


func test_a_click_on_resume_fires_no_shot() -> void:
	GameState.new_game()
	GameState.add_weapon(&"pistol")
	_museum()
	await physics_frames(3)
	museum.player.global_position = Vector3(-8, 0.1, 18)   # out of the booth: weapons up
	await physics_frames(3)
	var pistol := museum.player.weapons.state_of(&"pistol")
	await _tap(&"pause")
	assert_true(museum.pause_menu.is_open)
	await get_tree().process_frame
	var resume := museum.pause_menu._resume
	await _click(resume, resume.size * 0.5)
	assert_false(museum.pause_menu.is_open, "the click resumed")
	await physics_frames(4)
	assert_eq(pistol.magazine, pistol.data.magazine_size, "and fired nothing")


func test_changing_the_language_during_a_night_keeps_the_terminal_working() -> void:
	await _at_the_terminal()
	Settings.set_value(&"language", "en", false)
	await get_tree().process_frame
	await _tap(&"interact")
	var menu := museum.upgrade_menu
	assert_true(menu.is_open)
	assert_true(menu._root.is_inside_tree(), "the screen is in the tree")
	assert_eq(menu._rows.size(), UpgradeCatalog.all().size())
	assert_true(menu._rows[0].is_inside_tree())
	assert_eq(menu._title.text, tr(UpgradeCatalog.find(menu.selected_id()).name_key()), "in English")
	Settings.set_value(&"language", "pl", false)
	await get_tree().process_frame
	assert_true(menu._root.is_inside_tree(), "also when it changes while open")


func test_the_mouse_wheel_scrolls_the_options_and_moves_no_slider() -> void:
	var options := OptionsMenu.new()
	add_child(options)
	options.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var row: OptionRow = null
	for candidate in options.rows:
		if candidate.key == &"mouse_sensitivity":
			row = candidate
	var before: float = Settings.data.mouse_sensitivity
	await _wheel(row._slider, MOUSE_BUTTON_WHEEL_DOWN)
	await _wheel(row._slider, MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(Settings.data.mouse_sensitivity, before, "the slider under the wheel keeps its value")
	assert_gt(options._scroll.scroll_vertical, 0, "the list scrolled instead")
	options.free()


func test_a_held_key_repeats_on_sliders_only() -> void:
	var options := OptionsMenu.new()
	add_child(options)
	options.open()
	await get_tree().process_frame
	var mode: OptionRow = null
	var fov: OptionRow = null
	for candidate in options.rows:
		if candidate.key == &"window_mode":
			mode = candidate
		elif candidate.key == &"fov":
			fov = candidate
	mode.grab_focus()
	await _key(KEY_RIGHT)
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.EXCLUSIVE)
	await _key(KEY_RIGHT, true)
	await _key(KEY_RIGHT, true)
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.EXCLUSIVE, "held: no racing through the modes")
	fov.grab_focus()
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT, true)
	assert_eq(Settings.data.fov, 72.0, "a slider keeps stepping while held")
	options.free()


func test_clicking_left_of_a_choice_steps_it_back() -> void:
	var options := OptionsMenu.new()
	add_child(options)
	options.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var mode: OptionRow = null
	for candidate in options.rows:
		if candidate.key == &"window_mode":
			mode = candidate
	var value := mode._value
	var font := value.get_theme_font(&"font")
	var width := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size(&"font_size")).x
	var value_right := value.get_global_rect().end.x - mode.get_global_rect().position.x
	var middle := mode.size.y * 0.5
	await _click(mode, Vector2(value_right - width + 6.0, middle))
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.MAXIMIZED, "‹ goes back")
	await _click(mode, Vector2(value_right - 6.0, middle))
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.FULLSCREEN, "› goes forward")
	await _click(mode, Vector2(40.0, middle))
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.EXCLUSIVE, "the name goes forward")
	options.free()


func test_hovering_the_buy_button_takes_no_focus() -> void:
	var menu := UpgradeMenu.new()
	add_child(menu)
	RunState.add_dust(100, false)
	menu.open(GameState, RunState)
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner()
	menu._buy.mouse_entered.emit()
	assert_eq(get_viewport().gui_get_focus_owner(), focused, "the row keeps the focus")
	menu.close()
	menu.free()


func test_quick_denies_do_not_walk_the_details_away() -> void:
	var menu := UpgradeMenu.new()
	add_child(menu)
	menu.open(GameState, RunState)
	await get_tree().process_frame
	await get_tree().process_frame
	var rest := menu._details.position.x
	menu.buy_selected()
	await get_tree().create_timer(0.06).timeout
	menu.buy_selected()
	await get_tree().create_timer(0.5).timeout
	assert_almost_eq(menu._details.position.x, rest, 0.5)
	menu.close()
	menu.free()


func test_the_pause_line_follows_the_language() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	museum.pause_menu.open()
	assert_true(museum.pause_menu._info.text.begins_with("NOC"))
	Settings.set_value(&"language", "en", false)
	await get_tree().process_frame
	assert_true(museum.pause_menu._info.text.begins_with("NIGHT"), museum.pause_menu._info.text)
	museum.pause_menu.close()


func test_strong_text_is_semibold() -> void:
	var strong := UiTheme.strong_font() as FontVariation
	assert_not_null(strong, "a variation of the sans")
	if strong != null:
		assert_eq(int(strong.variation_opentype.get("wght", 0)), UiTheme.STRONG_WEIGHT)
		assert_eq((strong.base_font as SystemFont).font_weight, UiTheme.STRONG_WEIGHT)


func test_the_help_hint_is_readable() -> void:
	var hud := Hud.new()
	hud.night = 2
	add_child(hud)
	assert_true(hud._help_hint.label_settings.font_size >= 20)
	assert_true(hud._help_hint.label_settings.font_color.a >= 0.75)
	hud.free()


func test_menus_over_the_title_cover_the_whole_view() -> void:
	var menu := (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await get_tree().process_frame
	menu.options_button.pressed.emit()
	await get_tree().process_frame
	var view := menu.get_viewport_rect().size
	assert_eq(menu.options.size, view, "options centred, not squeezed into a corner")
	assert_eq(menu.confirm.size, view)
	menu.free()


func test_the_use_prompt_hides_under_a_menu() -> void:
	await _at_the_terminal()
	assert_true(museum.hud._prompt.visible)
	museum.pause_menu.open()
	await get_tree().process_frame
	assert_false(museum.hud._prompt.visible)
	museum.pause_menu.close()


func test_the_title_dust_spans_the_whole_view() -> void:
	var menu := (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	add_child(menu)
	var view := menu.get_viewport_rect().size
	assert_eq(menu._dust.position.x, view.x * 0.5)
	assert_true(menu._dust.emission_rect_extents.x >= view.x * 0.5)
	menu.free()
