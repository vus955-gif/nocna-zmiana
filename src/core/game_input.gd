extends Node
## Registers every input action in code (autoload "GameInput"), so
## project.godot stays readable. Physical keycodes = same key position on
## any keyboard layout.

const KEYS := {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"sprint": [KEY_SHIFT],
	&"dash": [KEY_CTRL],
	&"reload": [KEY_R],
	&"flashlight": [KEY_F],
	&"interact": [KEY_E],
	&"punch": [KEY_V],
	&"weapon_1": [KEY_1],
	&"weapon_2": [KEY_2],
	&"weapon_3": [KEY_3],
	&"weapon_4": [KEY_4],
	&"weapon_5": [KEY_5],
	&"weapon_6": [KEY_6],
	&"weapon_7": [KEY_7],
	&"weapon_8": [KEY_8],
	&"toggle_help": [KEY_F1],
	&"toggle_fullscreen": [KEY_F11],
	&"pause": [KEY_ESCAPE],
	# the paper museum map (Floor I)
	&"map": [KEY_M],
	# dev arenas only (6-8 are weapons now)
	&"spawn_wax": [KEY_F5],
	&"spawn_wolf": [KEY_F6],
	&"spawn_knight": [KEY_F7],
	&"clear_enemies": [KEY_F8],
}

const MOUSE := {
	&"fire": [MOUSE_BUTTON_LEFT],
	&"punch": [MOUSE_BUTTON_RIGHT],
	&"dash": [MOUSE_BUTTON_XBUTTON1],
	&"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	&"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
}


## Pad buttons (any pad) of the game's own actions.
const JOY_BUTTONS := {
	&"map": [JOY_BUTTON_BACK],
}


## Extra keys for the built-in menu actions (W/S walk through menus too).
const UI_KEYS := {
	&"ui_up": [KEY_W],
	&"ui_down": [KEY_S],
	&"ui_left": [KEY_A],
	&"ui_right": [KEY_D],
}

## May the game capture the OS cursor at all (false: automated scenarios
## that leave the cursor to the desktop).
var capture_allowed: bool = true
## Does losing the window's focus (or starting a night without it) pause
## plain play. Off for test and scenario runs: their window rarely has the
## focus, and a pause menu would cover every screenshot.
var pause_on_focus_loss: bool = true

## Cached key names for the HUD (action -> label).
var _labels: Dictionary = {}
## Open menus holding the input, oldest first (pause, terminal, death
## screen). While any is open the guard takes no gameplay input and the
## cursor is free.
var _ui_owners: Array[Object] = []
## Owners that want no cursor at all while they are on top (death screen).
var _cursorless: Array[Object] = []
## A scene with a playable guard is running (menus scenes: false).
var _gameplay_scene: bool = false
## Physics frame in which the last menu let go of the input. The key or
## click that closed it is still "just pressed" in the next physics step,
## so gameplay input stays off until that step is over (E must not open
## the terminal it just closed, a click on "Resume" must not fire).
var _resumed_frame: int = -100
## Closed screens that keep the input until E, Esc and the mouse buttons
## are up again (see pop_ui_on_release()).
var _releasing: Array[Object] = []


func _enter_tree() -> void:
	# lets go of released screens while the game is paused, too
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_on_focus_loss = not SavePaths.is_test_run()
	for action in KEYS:
		_ensure(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in MOUSE:
		_ensure(action)
		for button in MOUSE[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action in JOY_BUTTONS:
		_ensure(action)
		for button in JOY_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action in UI_KEYS:
		_ensure(action)
		for key in UI_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


## A menu takes the input (and frees the cursor, or hides it without
## [param show_cursor]) until pop_ui().
func push_ui(owner: Object, show_cursor: bool = true) -> void:
	_releasing.erase(owner)   # opened again before the keys came up: it keeps the input
	if not _ui_owners.has(owner):
		_ui_owners.append(owner)
	if not show_cursor and not _cursorless.has(owner):
		_cursorless.append(owner)
	_update_mouse()


func pop_ui(owner: Object) -> void:
	_forget_freed()
	var held := not _ui_owners.is_empty()
	_ui_owners.erase(owner)
	_cursorless.erase(owner)
	_releasing.erase(owner)
	if held and _ui_owners.is_empty():
		_resumed_frame = Engine.get_physics_frames()
	_update_mouse()


## pop_ui() for a screen put away by E, Esc or a click (the world's note
## reader and camera view): [param owner] keeps the input until those keys
## and the mouse buttons are all up again, so the E that closed a note
## never opens it again and a held click never fires. It then lets go at
## once: the press that closed it is over by then, no step to wait out.
## With the keys already up it is plain pop_ui().
func pop_ui_on_release(owner: Object) -> void:
	if not _ui_owners.has(owner):
		return
	if not closing_keys_down():
		pop_ui(owner)
	elif not _releasing.has(owner):
		_releasing.append(owner)


## True while [param owner] is closed but still waits for the keys to come up.
func is_releasing(owner: Object) -> bool:
	return _releasing.has(owner)


## True while E, Esc or a mouse button is still held.
func closing_keys_down() -> bool:
	if Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"pause") or Input.is_action_pressed(&"ui_cancel"):
		return true
	if DisplayServer.get_name() == "headless":
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _process(_delta: float) -> void:
	if _releasing.is_empty() or closing_keys_down():
		return
	_forget_freed()
	for screen in _releasing:
		_ui_owners.erase(screen)
		_cursorless.erase(screen)
	_releasing.clear()
	_update_mouse()


## The newest open menu, or null.
func top_ui() -> Object:
	_forget_freed()
	return _ui_owners.back() if not _ui_owners.is_empty() else null


func clear_ui() -> void:
	_forget_freed()
	if not _ui_owners.is_empty():
		_resumed_frame = Engine.get_physics_frames()
	_ui_owners.clear()
	_cursorless.clear()
	_releasing.clear()
	_update_mouse()


## True while no menu holds the input (and none just let go of it): the
## guard may move, look and shoot.
func gameplay_input() -> bool:
	_forget_freed()
	return _ui_owners.is_empty() and Engine.get_physics_frames() > _resumed_frame + 1


## [param action] was pressed for the game: just pressed, with no menu
## holding the input or having just let go of it (see gameplay_input()).
func fresh_press(action: StringName) -> bool:
	return gameplay_input() and Input.is_action_just_pressed(action)


## True when an unfocused window should pause the game now: a real window,
## the option on, plain play (no menu holds the input already, so the
## pause menu never lands on top of the terminal or the death screen).
func should_pause_unfocused() -> bool:
	return pause_on_focus_loss and DisplayServer.get_name() != "headless" and top_ui() == null


## Game scenes call this on entering (true) and leaving (false) the tree.
func set_gameplay_scene(active: bool) -> void:
	_gameplay_scene = active
	_update_mouse()


## The one place that captures or frees the cursor: captured only in a game
## scene with no menu open.
func _update_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = wanted_mouse_mode()


## The cursor mode for the current game scene and menus: captured in play,
## hidden under a menu that wants none, visible otherwise. (The headless
## runner never changes the real cursor; tests ask this.)
func wanted_mouse_mode() -> Input.MouseMode:
	_forget_freed()
	if _ui_owners.is_empty():
		return Input.MOUSE_MODE_CAPTURED if _gameplay_scene and capture_allowed else Input.MOUSE_MODE_VISIBLE
	return Input.MOUSE_MODE_HIDDEN if _cursorless.has(_ui_owners.back()) else Input.MOUSE_MODE_VISIBLE


func _forget_freed() -> void:
	for i in range(_ui_owners.size() - 1, -1, -1):
		if not is_instance_valid(_ui_owners[i]):
			_ui_owners.remove_at(i)
	for i in range(_cursorless.size() - 1, -1, -1):
		if not is_instance_valid(_cursorless[i]):
			_cursorless.remove_at(i)
	for i in range(_releasing.size() - 1, -1, -1):
		if not is_instance_valid(_releasing[i]):
			_releasing.remove_at(i)


## Name of the first key bound to [param action] as printed on the player's
## keyboard (bindings are physical positions, the label follows the layout).
func key_label(action: StringName) -> String:
	if _labels.has(action):
		return _labels[action]
	var label := "?"
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			var shown := key.physical_keycode
			if DisplayServer.get_name() != "headless":
				var on_layout := DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				if on_layout != KEY_NONE:
					shown = on_layout
			label = OS.get_keycode_string(shown)
			break
	_labels[action] = label
	return label


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_labels.clear()   # the keyboard layout may have changed meanwhile


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
