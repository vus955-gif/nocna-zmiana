class_name KeyBindingsPanel
extends Control
## The keys of the game (opened from the options menu): every action of
## KeyBindings with its two places, grouped. A click or Enter on a place
## makes the panel listen: the next key or mouse button (the wheel too)
## goes to that place; Esc cancels, Delete or Backspace empties the place.
## A key held by another action swaps with it (KeyBindings); what happened
## is said in a line under the list. The pad keeps its own buttons.
## Changes apply at once and are written like the other options (a moment
## later, at the latest when the options menu closes).

signal closed

enum Say { NONE, GOOD, WARN }

## Rows by action.
var rows: Dictionary = {}
## The place being set (action &"" = none).
var listening_action: StringName = &""
var listening_slot: int = -1
## The line under the list and how it is coloured.
var message: String = ""
var message_kind: Say = Say.NONE

var _texts := UiTexts.new()
var _scroll: ScrollContainer
var _status: Label
var _hints: Label
var _reset: Button
var _back: Button
var _first: Button


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open() -> void:
	visible = true
	_say("", Say.NONE)
	refresh()
	_scroll.scroll_vertical = 0
	_first.grab_focus()


func close() -> void:
	if not visible:
		return
	cancel_listening()
	visible = false
	Sfx.play_ui(&"ui_back")
	closed.emit()


func is_listening() -> bool:
	return listening_action != &""


func row(action: StringName) -> KeyRow:
	return rows.get(action) as KeyRow


func refresh() -> void:
	for action: StringName in rows:
		(rows[action] as KeyRow).refresh(listening_slot if action == listening_action else -1)


## The panel listens for a key for [param slot] of [param action].
func begin_listening(action: StringName, slot: int) -> void:
	if not rows.has(action) or KeyBindings.is_locked(action, slot):
		if rows.has(action):
			_say(tr("BIND_MSG_LOCKED"), Say.WARN)
		return
	listening_action = action
	listening_slot = slot
	_say(tr("BIND_MSG_LISTENING"), Say.NONE)
	refresh()
	Sfx.play_ui(&"ui_move", -8.0)


func cancel_listening() -> void:
	if not is_listening():
		return
	listening_action = &""
	listening_slot = -1
	refresh()


## While listening: takes a pressed key or mouse button. Returns true when
## the event was used (Esc, Delete, Backspace, a key, a bindable button).
func capture_event(event: InputEvent) -> bool:
	if not is_listening():
		return false
	var key := event as InputEventKey
	if key != null:
		if not key.pressed:
			return false
		if key.echo:
			return true   # the Enter that opened the listening, still held
		match key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode:
			KEY_ESCAPE:
				cancel_listening()
				_say("", Say.NONE)
				Sfx.play_ui(&"ui_back")
			KEY_DELETE, KEY_BACKSPACE:
				_clear_listened()
			_:
				_give(KeyBindings.code_of_event(key))
		return true
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		var code := KeyBindings.code_of_event(click)
		if KeyBindings.MOUSE_BUTTONS.has(-code):
			_give(code)
			return true
	return false


## All keys back to the defaults.
func reset_to_defaults() -> void:
	cancel_listening()
	Settings.reset_bindings()
	refresh()
	_say(tr("BIND_MSG_RESET"), Say.GOOD)
	Sfx.play_ui(&"ui_confirm")


func _input(event: InputEvent) -> void:
	if visible and is_listening() and capture_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_listening() and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _scroll != null:
		_texts.refresh()
		refresh()


# --- what a change says ---

func _give(code: int) -> void:
	var action := listening_action
	var slot := listening_slot
	listening_action = &""
	listening_slot = -1
	var answer := Settings.bind(action, slot, code)
	_report(answer, action, code)
	refresh()


func _clear_listened() -> void:
	var action := listening_action
	var slot := listening_slot
	listening_action = &""
	listening_slot = -1
	var answer := Settings.unbind(action, slot)
	match answer["result"]:
		KeyBindings.Result.LAST_KEY:
			_say(tr("BIND_MSG_NEEDS_KEY") % KeyRow.action_name(action), Say.WARN)
		KeyBindings.Result.OK:
			_say(tr("BIND_MSG_CLEARED") % KeyRow.action_name(action), Say.GOOD)
			Sfx.play_ui(&"ui_move", -8.0)
		_:
			_say("", Say.NONE)
	refresh()


func _report(answer: Dictionary, action: StringName, code: int) -> void:
	var shown := KeyBindings.label(code)
	var other: StringName = answer["other"]
	match answer["result"]:
		KeyBindings.Result.OK:
			_say(tr("BIND_MSG_SET") % [KeyRow.action_name(action), shown], Say.GOOD)
		KeyBindings.Result.SWAPPED:
			if other == action:
				_say(tr("BIND_MSG_SWAPPED_SELF") % KeyRow.action_name(action), Say.GOOD)
			else:
				_say(tr("BIND_MSG_SWAPPED") % [shown, KeyRow.action_name(other)], Say.GOOD)
		KeyBindings.Result.MOVED:
			var left := Settings.data.bindings.codes(other)
			_say(tr("BIND_MSG_MOVED") % [shown, KeyRow.action_name(other), KeyBindings.label(left[0]) if not left.is_empty() else "—"], Say.GOOD)
		KeyBindings.Result.LAST_KEY:
			_say(tr("BIND_MSG_LAST_KEY") % [shown, KeyRow.action_name(other)], Say.WARN)
		KeyBindings.Result.SAME:
			_say("", Say.NONE)
		KeyBindings.Result.LOCKED:
			_say(tr("BIND_MSG_LOCKED"), Say.WARN)
		_:
			_say(tr("BIND_MSG_RESERVED") % shown, Say.WARN)
	if answer["result"] == KeyBindings.Result.OK or answer["result"] == KeyBindings.Result.SWAPPED or answer["result"] == KeyBindings.Result.MOVED:
		Sfx.play_ui(&"ui_confirm", -6.0)
	elif answer["result"] != KeyBindings.Result.SAME:
		Sfx.play_ui(&"ui_back", -6.0)


func _say(text: String, kind: Say) -> void:
	message = text
	message_kind = kind
	if _status == null:
		return
	_status.text = text
	match kind:
		Say.GOOD:
			_status.add_theme_color_override("font_color", UiTheme.GOOD)
		Say.WARN:
			_status.add_theme_color_override("font_color", UiTheme.DANGER)
		_:
			_status.add_theme_color_override("font_color", UiTheme.MUTED)


# --- building ---

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = UiTheme.SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 880)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(40.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(_texts.bind(UiTheme.caption(""), "OPT_TITLE", true))
	column.add_child(_texts.bind(UiTheme.heading("", 46), "BIND_TITLE", true))
	column.add_child(UiTheme.rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	_scroll.add_child(list)
	for group: Array in KeyBindings.GROUPS:
		if list.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 12)
			list.add_child(gap)
		list.add_child(_texts.bind(UiTheme.caption("", 18), String(group[0]), true))
		for action: StringName in group[1]:
			var line := KeyRow.create(action)
			line.slot_pressed.connect(begin_listening)
			list.add_child(line)
			rows[action] = line
	_first = (rows[KeyBindings.actions()[0]] as KeyRow).buttons[0]
	column.add_child(UiTheme.rule())
	_status = UiTheme.label("", 22, UiTheme.MUTED)
	_status.custom_minimum_size = Vector2(0, 34)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	_reset = UiTheme.menu_button("", 26)
	_texts.bind(_reset, "BIND_RESET")
	_reset.pressed.connect(reset_to_defaults)
	footer.add_child(_reset)
	_hints = UiTheme.caption("", 18)
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_texts.bind(_hints, "BIND_HINTS", true))
	_back = UiTheme.menu_button("", 26)
	_texts.bind(_back, "OPT_BACK")
	_back.pressed.connect(close)
	footer.add_child(_back)
	column.add_child(footer)
	_say("", Say.NONE)
