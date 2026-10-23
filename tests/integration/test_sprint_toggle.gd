extends TestCase
## Sprint held or switched (option "sprint_toggle", plan 2026-10-21-dostepnosc):
## held, the key must stay down; switched, one press starts the sprint and
## the next ends it. A switched sprint also ends when the stamina is gone,
## when a weapon forbids it, when a menu takes the input, or when the guard
## has stood still for a moment - and never starts again by itself.

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await physics_frames(5)


func after_each() -> void:
	for action in [&"sprint", &"move_forward"]:
		Input.action_release(action)
	Settings.reset_to_defaults(false)


## Presses [param action] for exactly one physics frame.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)
	await physics_frames(1)


func test_held_sprint_needs_the_key_down_and_a_tap_does_not_latch_it() -> void:
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await physics_frames(10)
	assert_false(player.sprinting, "held mode: a tap is not a sprint")
	Input.action_press(&"sprint")
	await physics_frames(10)
	assert_true(player.sprinting, "held: sprinting while the key is down")
	Input.action_release(&"sprint")
	await physics_frames(3)
	assert_false(player.sprinting, "held: the key up ends it")


func test_the_setting_reaches_the_guard_live() -> void:
	assert_false(player.sprint_toggle)
	Settings.set_value(&"sprint_toggle", true, false)
	assert_true(player.sprint_toggle)
	Settings.set_value(&"sprint_toggle", false, false)
	assert_false(player.sprint_toggle)


func test_a_tap_starts_a_switched_sprint_and_the_next_tap_ends_it() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	Input.action_press(&"move_forward")
	await physics_frames(5)
	assert_false(player.sprinting, "walking")
	await _tap(&"sprint")
	await physics_frames(10)
	assert_true(player.sprinting, "one tap: sprinting with the key up")
	await physics_frames(20)
	assert_true(player.sprinting, "and it goes on")
	await _tap(&"sprint")
	await physics_frames(3)
	assert_false(player.sprinting, "the second tap ends it")
	await physics_frames(10)
	assert_false(player.sprinting, "and it stays ended")


func test_a_switched_sprint_ends_when_the_stamina_is_gone_and_does_not_come_back() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await physics_frames(5)
	assert_true(player.sprinting)
	player.stamina.current = 0.5
	await physics_frames(10)
	assert_false(player.sprinting, "out of breath")
	assert_true(player.stamina.exhausted)
	player.stamina.exhausted = false
	player.stamina.current = player.stamina.maximum
	await physics_frames(10)
	assert_false(player.sprinting, "stamina back: the sprint does not start by itself")


func test_a_switched_sprint_ends_when_the_guard_stands_still_for_a_moment() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await physics_frames(5)
	assert_true(player.sprinting)
	Input.action_release(&"move_forward")
	await physics_frames(int(Player.SPRINT_IDLE_GRACE * 60.0) + 10)
	assert_false(player.sprinting, "stopped")
	Input.action_press(&"move_forward")
	await physics_frames(10)
	assert_false(player.sprinting, "walking again: a plain walk, the sprint was ended by the stop")


func test_the_key_pressed_a_moment_before_moving_still_sprints() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	await _tap(&"sprint")
	await physics_frames(5)
	assert_false(player.sprinting, "standing: nothing to sprint")
	Input.action_press(&"move_forward")
	await physics_frames(10)
	assert_true(player.sprinting, "Shift, then W a moment later: sprinting")


func test_a_menu_ends_a_switched_sprint() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await physics_frames(5)
	assert_true(player.sprinting)
	var menu := Node.new()
	add_child(menu)
	GameInput.push_ui(menu)
	await physics_frames(3)
	GameInput.pop_ui(menu)
	await physics_frames(8)
	assert_false(player.sprinting, "the menu ended it: the sprint does not resume after")
	menu.free()


func test_turning_the_option_off_ends_a_switched_sprint() -> void:
	Settings.set_value(&"sprint_toggle", true, false)
	Input.action_press(&"move_forward")
	await _tap(&"sprint")
	await physics_frames(5)
	assert_true(player.sprinting)
	Settings.set_value(&"sprint_toggle", false, false)
	await physics_frames(5)
	assert_false(player.sprinting, "held mode again, the key is up")
