extends TestCase

const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump",
	&"sprint", &"dash", &"fire", &"punch", &"reload", &"flashlight",
	&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_next", &"weapon_prev",
	&"toggle_help", &"toggle_fullscreen", &"pause", &"interact",
	&"spawn_wax", &"spawn_wolf", &"spawn_knight", &"clear_enemies",
]


func test_every_action_exists_and_has_a_binding() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action " + str(action))
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "no binding for " + str(action))


func test_punch_is_on_mouse_and_keyboard() -> void:
	assert_eq(InputMap.action_get_events(&"punch").size(), 2)


func test_event_bus_is_autoloaded() -> void:
	assert_not_null(get_node_or_null(^"/root/Events"))


func test_ui_stack_blocks_gameplay_input() -> void:
	var menu := Node.new()
	var other := Node.new()
	assert_true(GameInput.gameplay_input())
	GameInput.push_ui(menu)
	GameInput.push_ui(other)
	assert_false(GameInput.gameplay_input())
	assert_eq(GameInput.top_ui(), other)
	GameInput.pop_ui(other)
	assert_eq(GameInput.top_ui(), menu)
	other.free()
	menu.free()
	assert_true(GameInput.gameplay_input(), "freed menus let go")
	assert_eq(GameInput.top_ui(), null)


func test_the_step_after_a_menu_closes_takes_no_gameplay_input() -> void:
	var menu := Node.new()
	GameInput.push_ui(menu)
	GameInput.pop_ui(menu)
	assert_false(GameInput.gameplay_input(), "the closing key or click is still fresh")
	Input.action_press(&"interact")
	assert_false(GameInput.fresh_press(&"interact"))
	Input.action_release(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GameInput.gameplay_input())
	menu.free()


func test_a_menu_can_hide_the_cursor() -> void:
	var screen := Node.new()
	GameInput.set_gameplay_scene(true)
	assert_eq(GameInput.wanted_mouse_mode(), Input.MOUSE_MODE_CAPTURED)
	GameInput.push_ui(screen, false)
	assert_eq(GameInput.wanted_mouse_mode(), Input.MOUSE_MODE_HIDDEN, "the death screen shows no cursor")
	var menu := Node.new()
	GameInput.push_ui(menu)
	assert_eq(GameInput.wanted_mouse_mode(), Input.MOUSE_MODE_VISIBLE, "a menu on top has one")
	GameInput.clear_ui()
	GameInput.set_gameplay_scene(false)
	assert_eq(GameInput.wanted_mouse_mode(), Input.MOUSE_MODE_VISIBLE)
	screen.free()
	menu.free()


func test_focus_loss_pauses_plain_play_only() -> void:
	assert_false(GameInput.should_pause_unfocused(), "never without a window")
	var menu := Node.new()
	GameInput.push_ui(menu)
	assert_false(GameInput.should_pause_unfocused())
	GameInput.pop_ui(menu)
	menu.free()


func test_a_screen_let_go_on_release_waits_for_the_keys_and_no_step_more() -> void:
	var screen := Node.new()
	GameInput.push_ui(screen)
	Input.action_press(&"pause")
	GameInput.pop_ui_on_release(screen)
	assert_true(GameInput.is_releasing(screen))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(GameInput.gameplay_input(), "Esc is still down")
	assert_eq(GameInput.top_ui(), screen, "so no pause menu lands on top")
	Input.action_release(&"pause")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(GameInput.is_releasing(screen))
	assert_true(GameInput.gameplay_input(), "the press that closed it is over: no step to wait out")
	screen.free()


func test_a_screen_let_go_with_the_keys_up_is_a_plain_pop() -> void:
	var screen := Node.new()
	GameInput.push_ui(screen)
	GameInput.pop_ui_on_release(screen)
	assert_false(GameInput.is_releasing(screen))
	assert_eq(GameInput.top_ui(), null)
	assert_false(GameInput.gameplay_input(), "the click that closed it is still fresh")
	screen.free()


func test_a_screen_opened_again_before_the_keys_come_up_keeps_the_input() -> void:
	var screen := Node.new()
	GameInput.push_ui(screen)
	Input.action_press(&"interact")
	GameInput.pop_ui_on_release(screen)
	GameInput.push_ui(screen)
	Input.action_release(&"interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(GameInput.top_ui(), screen)
	GameInput.pop_ui(screen)
	screen.free()
