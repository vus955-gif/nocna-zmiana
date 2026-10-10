extends TestCase
## Esc, the pause menu, and the guard's input while a menu is open.

var player: Player
var menu: PauseMenu


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	menu = PauseMenu.new()
	add_child(menu)


func after_each() -> void:
	menu.close()


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


func test_escape_pauses_and_blocks_gameplay_input() -> void:
	await _press(&"pause")
	assert_true(menu.is_open)
	assert_true(get_tree().paused)
	assert_false(GameInput.gameplay_input())
	assert_true(menu._resume.has_focus())


func test_resume_restores_play() -> void:
	await _press(&"pause")
	menu._resume.pressed.emit()
	assert_false(menu.is_open)
	assert_false(get_tree().paused)
	assert_false(GameInput.gameplay_input(), "not in the very next step: the click must not fire")
	await physics_frames(2)
	assert_true(GameInput.gameplay_input())
	await _press(&"pause")
	await _press(&"pause")
	assert_false(menu.is_open, "Esc closes it again")


func test_guard_does_not_move_or_shoot_while_a_menu_is_open() -> void:
	var pistol := player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	await physics_frames(5)
	var start := player.global_position
	GameInput.push_ui(self)
	Input.action_press(&"move_forward")
	Input.action_press(&"fire")
	await physics_frames(20)
	Input.action_release(&"move_forward")
	Input.action_release(&"fire")
	assert_lt(player.global_position.distance_to(start), 0.05, "no walking")
	assert_eq(pistol.magazine, 12, "no shooting")
	GameInput.pop_ui(self)
	Input.action_press(&"move_forward")
	await physics_frames(20)
	Input.action_release(&"move_forward")
	assert_gt(player.global_position.distance_to(start), 0.5, "free again")


func test_options_open_from_pause() -> void:
	menu.open()
	menu._options_button.pressed.emit()
	assert_true(menu._options.visible)
	assert_false(menu._panel.visible)
	await _press(&"ui_cancel")
	assert_false(menu._options.visible, "Esc leaves the options first")
	assert_true(menu.is_open)
	assert_true(menu._panel.visible)


func test_quit_requests_reach_the_game_scene() -> void:
	var to_menu := watch(menu.quit_to_menu_requested)
	var to_desktop := watch(menu.quit_game_requested)
	menu.open()
	var shown := menu._panel.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.visible)
	assert_eq(shown.size(), 4, "resume, options, quit to menu, quit (no notes list without a reader)")
	shown[2].pressed.emit()
	shown[3].pressed.emit()
	assert_eq(to_menu.size(), 1)
	assert_eq(to_desktop.size(), 1)


func test_no_pause_while_another_menu_holds_the_input() -> void:
	GameInput.push_ui(self)
	await _press(&"pause")
	assert_false(menu.is_open)
	GameInput.pop_ui(self)
