class_name DifficultyDialog
extends Control
## New game: which shift (design 7.5)? The three difficulties of
## DifficultyRules, each a button with its name and a line on what it
## changes underneath; "Nocna zmiana" (the default) is focused first, Esc
## goes back. It can be changed later in the options, between nights.

signal chosen(difficulty: StringName)
signal cancelled

## Difficulty id -> its button.
var buttons: Dictionary = {}

var _texts := UiTexts.new()


## Translation keys of a difficulty's name and its line.
static func name_key(difficulty: StringName) -> String:
	return "DIFF_" + String(difficulty).to_upper()


static func detail_key(difficulty: StringName) -> String:
	return name_key(difficulty) + "_DETAIL"


func _ready() -> void:
	theme = UiTheme.theme()
	# anchors and offsets: added to a parent that has its size already
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = UiTheme.SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(40.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_texts.bind(UiTheme.caption(""), "DIFF_SUBTITLE", true))
	column.add_child(_texts.bind(UiTheme.heading("", 46), "DIFF_TITLE", true))
	column.add_child(UiTheme.rule())
	for id in DifficultyRules.IDS:
		var button := UiTheme.menu_button("", 34)
		button.custom_minimum_size = Vector2(0, 60)
		_texts.bind(button, name_key(id))
		button.pressed.connect(choose.bind(id))
		button.focus_entered.connect(func() -> void: Sfx.play_ui(&"ui_move", -8.0))
		column.add_child(button)
		buttons[id] = button
		var detail := UiTheme.label("", 22, UiTheme.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 26)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.add_child(_texts.bind(detail, detail_key(id)))
		column.add_child(margin)


## Shows the choice with [param current] focused.
func ask(current: StringName = PersistentState.DEFAULT_DIFFICULTY) -> void:
	visible = true
	var focused: Button = buttons.get(current, buttons[PersistentState.DEFAULT_DIFFICULTY])
	focused.grab_focus()


func choose(difficulty: StringName) -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui(&"ui_confirm")
	chosen.emit(difficulty)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		Sfx.play_ui(&"ui_back")
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_texts.refresh()
