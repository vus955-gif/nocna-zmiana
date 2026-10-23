class_name KeyBindings
extends RefCounted
## The player's keys and mouse buttons for the game's actions (plan
## 2026-10-21-sterowanie-nakladka). Pure data and rules: Settings keeps one
## in settings.cfg and GameInput.apply_bindings() puts it in the InputMap.
## - An action has SLOTS places (main and extra). A binding is one int: 0
##   nothing, > 0 a physical keycode (the same key position on any layout),
##   < 0 minus a mouse button index (the wheel is a button too).
## - One key belongs to one action. Giving a key to another action SWAPS
##   (the action that loses it gets what the other held in that place); when
##   that place was empty the loser just loses it, but never its last key
##   (refused). Every action keeps at least one key, in its main place.
## - Not bindable: Esc (menus cancel with it; the pause keeps it in its main
##   place for good, so the way into the menu can not be bound away), the
##   Windows key, F3 (the dev overlay).
## - Defaults are GameInput's own tables (KEYS, then MOUSE).
## - settings.cfg [bindings] lists only the actions that differ from the
##   defaults; a broken entry keeps its action's default, a key held twice
##   (a hand-edited file) brings every default back.
## The pad keeps its own bindings (GameInput.JOY_BUTTONS).

const SLOTS := 2
const SECTION := "bindings"

## What assign() / clear() answer in "result".
enum Result { OK, SWAPPED, MOVED, SAME, LOCKED, RESERVED, INVALID, LAST_KEY, UNKNOWN }

## The rebindable actions as the menu lists them: [group's text key, actions].
const GROUPS := [
	[&"BIND_GROUP_MOVE", [&"move_forward", &"move_left", &"move_back", &"move_right", &"jump", &"sprint", &"dash"]],
	[&"BIND_GROUP_ARMS", [&"fire", &"punch", &"reload", &"weapon_next", &"weapon_prev",
		&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4", &"weapon_5", &"weapon_6", &"weapon_7", &"weapon_8"]],
	[&"BIND_GROUP_WORLD", [&"flashlight", &"interact", &"map"]],
	[&"BIND_GROUP_INTERFACE", [&"toggle_help", &"toggle_fullscreen", &"pause"]],
]
## Actions of the dev arenas and tools: never rebound, never in conflicts.
const DEV_ACTIONS: Array[StringName] = [&"spawn_wax", &"spawn_wolf", &"spawn_knight", &"clear_enemies", &"toggle_perf"]
## Keys nothing can be bound to.
const RESERVED: Array[int] = [KEY_ESCAPE, KEY_META, KEY_F3]
## Mouse buttons that can be bound.
const MOUSE_BUTTONS: Array[int] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

static var _actions: Array[StringName] = []

## action -> PackedInt32Array of SLOTS bindings.
var _slots: Dictionary = {}


func _init() -> void:
	reset_all()


# --- the catalogue ---

## Every rebindable action, in menu order.
static func actions() -> Array[StringName]:
	if _actions.is_empty():
		for group: Array in GROUPS:
			for action: StringName in group[1]:
				_actions.append(action)
	return _actions


static func is_bindable(action: StringName) -> bool:
	return actions().has(action)


## The main place of the pause is Esc for good.
static func is_locked(action: StringName, slot: int) -> bool:
	return action == &"pause" and slot == 0


## The defaults of [param action] (GameInput's tables): keys first, then
## mouse buttons, the first SLOTS of them.
static func default_codes(action: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	if action == &"pause":
		out.append(KEY_ESCAPE)
	else:
		for key: int in GameInput.KEYS.get(action, []):
			out.append(key)
		for button: int in GameInput.MOUSE.get(action, []):
			out.append(-button)
	out.resize(SLOTS)
	return out


# --- bindings as ints ---

static func is_mouse(code: int) -> bool:
	return code < 0


static func is_key(code: int) -> bool:
	return code > 0


## The binding of a pressed key or mouse button event (0: not one).
static func code_of_event(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key != null:
		return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var click := event as InputEventMouseButton
	if click != null:
		return -click.button_index
	return 0


## The InputMap event of a binding (null for 0).
static func event_for(code: int) -> InputEvent:
	if code > 0:
		var key := InputEventKey.new()
		key.physical_keycode = code as Key
		return key
	if code < 0:
		var click := InputEventMouseButton.new()
		click.button_index = (-code) as MouseButton
		return click
	return null


## May [param code] be stored: a key the OS names (not reserved) or a mouse
## button of MOUSE_BUTTONS.
static func is_valid(code: int) -> bool:
	if code > 0:
		return not RESERVED.has(code) and _key_named(code)
	if code < 0:
		return MOUSE_BUTTONS.has(-code)
	return false


static func is_reserved(code: int) -> bool:
	return code > 0 and RESERVED.has(code)


## A key the engine knows: a printable ASCII position (letters are the
## upper-case codes) or one of the special keys, with no modifier bits.
static func _key_named(code: int) -> bool:
	if code & KEY_CODE_MASK != code:
		return false
	var known := (code >= KEY_SPACE and code <= KEY_ASCIITILDE and not (code >= KEY_A + 32 and code <= KEY_Z + 32)) 			or (code >= KEY_SPECIAL and code <= KEY_LAUNCHF)
	return known and OS.get_keycode_string(code as Key) != ""


## The name on the key as printed on the player's keyboard (the binding is
## a position, the label follows the layout) or the mouse button's name.
static func label(code: int) -> String:
	if code < 0:
		return _mouse_label(-code)
	if code == 0:
		return "—"
	var shown := code
	if DisplayServer.get_name() != "headless" and code != KEY_ESCAPE:
		var on_layout := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
		if on_layout != KEY_NONE:
			shown = on_layout
	match shown:
		KEY_SPACE:
			return TranslationServer.translate("BIND_KEY_SPACE")
		KEY_ESCAPE:
			return "Esc"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
	return OS.get_keycode_string(shown as Key)


static func _mouse_label(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return TranslationServer.translate("BIND_MOUSE_LEFT")
		MOUSE_BUTTON_RIGHT:
			return TranslationServer.translate("BIND_MOUSE_RIGHT")
		MOUSE_BUTTON_MIDDLE:
			return TranslationServer.translate("BIND_MOUSE_MIDDLE")
		MOUSE_BUTTON_WHEEL_UP:
			return TranslationServer.translate("BIND_MOUSE_WHEEL_UP")
		MOUSE_BUTTON_WHEEL_DOWN:
			return TranslationServer.translate("BIND_MOUSE_WHEEL_DOWN")
		MOUSE_BUTTON_XBUTTON1:
			return TranslationServer.translate("BIND_MOUSE_SIDE_1")
		MOUSE_BUTTON_XBUTTON2:
			return TranslationServer.translate("BIND_MOUSE_SIDE_2")
	return "%s %d" % [TranslationServer.translate("BIND_MOUSE"), button]


# --- reading ---

## The binding in [param slot] of [param action] (0: none).
func code_at(action: StringName, slot: int) -> int:
	var row: PackedInt32Array = _slots.get(action, PackedInt32Array())
	return row[slot] if slot >= 0 and slot < row.size() else 0


## The bindings of [param action] in order, without the empty places.
func codes(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for slot in SLOTS:
		var code := code_at(action, slot)
		if code != 0:
			out.append(code)
	return out


## The action that holds [param code] (&"": nobody).
func holder_of(code: int) -> StringName:
	if code == 0:
		return &""
	for action: StringName in _slots:
		if (_slots[action] as PackedInt32Array).has(code):
			return action
	return &""


func slot_of(code: int) -> int:
	var holder := holder_of(code)
	return (_slots[holder] as PackedInt32Array).find(code) if holder != &"" else -1


func is_default_action(action: StringName) -> bool:
	return _slots.get(action, PackedInt32Array()) == default_codes(action)


func is_default() -> bool:
	for action in actions():
		if not is_default_action(action):
			return false
	return true


func duplicate_bindings() -> KeyBindings:
	var copy := KeyBindings.new()
	for action in actions():
		copy._slots[action] = (_slots[action] as PackedInt32Array).duplicate()
	return copy


func equals(other: KeyBindings) -> bool:
	for action in actions():
		if _slots[action] != other._slots[action]:
			return false
	return true


# --- changing ---

func reset_all() -> void:
	_slots.clear()
	for action in actions():
		_slots[action] = default_codes(action)


## Back to the defaults of one action. Its default keys may be held by other
## actions now: those swap them out (never leaving anyone without a key).
func reset_action(action: StringName) -> void:
	if not _slots.has(action):
		return
	var wanted := default_codes(action)
	for slot in SLOTS:
		if wanted[slot] != code_at(action, slot) and not is_locked(action, slot):
			if wanted[slot] == 0:
				clear(action, slot)
			else:
				assign(action, slot, wanted[slot])


## Gives [param code] to [param slot] of [param action]. Answers {"result":
## Result, "other": the action that swapped or lost its key (&"" if none)};
## nothing changes unless the result is OK, SWAPPED or MOVED.
func assign(action: StringName, slot: int, code: int) -> Dictionary:
	if not _slots.has(action) or slot < 0 or slot >= SLOTS:
		return _answer(Result.UNKNOWN)
	if is_locked(action, slot):
		return _answer(Result.LOCKED)
	if is_reserved(code):
		return _answer(Result.RESERVED)
	if not is_valid(code):
		return _answer(Result.INVALID)
	var current := code_at(action, slot)
	if current == code:
		return _answer(Result.SAME)
	var holder := holder_of(code)
	if holder == &"":
		_put(action, slot, code)
		return _answer(Result.OK)
	var held_slot := slot_of(code)
	if holder == action:
		# both places of one action: they trade
		_put(action, slot, code)
		_put(action, held_slot, current)
		_settle(action)
		return _answer(Result.SWAPPED, action)
	if current != 0:
		_put(holder, held_slot, current)
		_put(action, slot, code)
		return _answer(Result.SWAPPED, holder)
	if codes(holder).size() < 2:
		return _answer(Result.LAST_KEY, holder)
	_put(holder, held_slot, 0)
	_settle(holder)
	_put(action, slot, code)
	return _answer(Result.MOVED, holder)


## Empties [param slot] of [param action] (never its last key; the extra key
## moves up when the main one goes).
func clear(action: StringName, slot: int) -> Dictionary:
	if not _slots.has(action) or slot < 0 or slot >= SLOTS:
		return _answer(Result.UNKNOWN)
	if is_locked(action, slot):
		return _answer(Result.LOCKED)
	if code_at(action, slot) == 0:
		return _answer(Result.SAME)
	if codes(action).size() < 2:
		return _answer(Result.LAST_KEY, action)
	_put(action, slot, 0)
	_settle(action)
	return _answer(Result.OK)


func _put(action: StringName, slot: int, code: int) -> void:
	var row: PackedInt32Array = _slots[action]
	row[slot] = code
	_slots[action] = row


## The extra key takes the main place when that is empty.
func _settle(action: StringName) -> void:
	var row: PackedInt32Array = _slots[action]
	if row[0] == 0 and row[1] != 0:
		row[0] = row[1]
		row[1] = 0
		_slots[action] = row


static func _answer(result: Result, other: StringName = &"") -> Dictionary:
	return {"result": result, "other": other}


# --- settings.cfg ---

## Writes the actions that differ from the defaults to [member SECTION].
func to_config(config: ConfigFile) -> void:
	for action in actions():
		if not is_default_action(action):
			var row: PackedInt32Array = _slots[action]
			config.set_value(SECTION, action, [row[0], row[1]])


## Reads [member SECTION]; anything not usable keeps the defaults (see the
## class comment).
func from_config(config: ConfigFile) -> void:
	reset_all()
	if not config.has_section(SECTION):
		return
	var loaded := {}
	for action in actions():
		if not config.has_section_key(SECTION, action):
			continue
		var row := _parse_row(action, config.get_value(SECTION, action))
		if not row.is_empty():
			loaded[action] = row
	var before := _slots.duplicate(true)
	for action: StringName in loaded:
		_slots[action] = loaded[action]
	if not _consistent():
		_slots = before


## A stored row as a valid PackedInt32Array (empty: unusable).
static func _parse_row(action: StringName, value: Variant) -> PackedInt32Array:
	var items: Array = []
	if value is Array:
		items = value
	elif value is PackedInt32Array:
		items = Array(value)
	else:
		return PackedInt32Array()
	if items.size() != SLOTS:
		return PackedInt32Array()
	var row := PackedInt32Array([0, 0])
	for slot in SLOTS:
		var item: Variant = items[slot]
		if typeof(item) != TYPE_INT:
			return PackedInt32Array()
		var code: int = item
		if is_locked(action, slot):
			if code != default_codes(action)[slot]:
				return PackedInt32Array()
		elif code != 0 and not is_valid(code):
			return PackedInt32Array()
		row[slot] = code
	return row if row[0] != 0 else PackedInt32Array()


## Every action has a main key, and no key is held twice.
func _consistent() -> bool:
	var seen := {}
	for action in actions():
		var row: PackedInt32Array = _slots[action]
		if row[0] == 0:
			return false
		for code in row:
			if code == 0:
				continue
			if seen.has(code):
				return false
			seen[code] = true
	return true
