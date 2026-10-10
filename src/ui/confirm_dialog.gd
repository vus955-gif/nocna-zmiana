class_name ConfirmDialog
extends Control
## A small modal question with a safe default: "No" is focused first and
## Esc answers it. Used before a new game overwrites the save.

signal answered(yes: bool)

var _texts := UiTexts.new()
var _question: Label
var _detail: Label
var _yes: Button
var _no: Button


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
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	_question = UiTheme.label("", 38, UiTheme.TEXT, UiTheme.title_font())
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_question)
	_detail = UiTheme.label("", 25, UiTheme.MUTED)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)
	column.add_child(UiTheme.rule())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	_no = UiTheme.menu_button("", 28)
	_no.pressed.connect(_answer.bind(false))
	_yes = UiTheme.menu_button("", 28)
	_yes.pressed.connect(_answer.bind(true))
	buttons.add_child(_no)
	buttons.add_child(_yes)
	column.add_child(buttons)


## Asks [param question_key] (with [param detail_key] below); the buttons
## read [param yes_key] and [param no_key].
func ask(question_key: String, detail_key: String, yes_key: String, no_key: String) -> void:
	_texts = UiTexts.new()
	_texts.bind(_question, question_key)
	_texts.bind(_detail, detail_key)
	_texts.bind(_yes, yes_key)
	_texts.bind(_no, no_key)
	visible = true
	_no.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_texts.refresh()


func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui(&"ui_confirm" if yes else &"ui_back")
	answered.emit(yes)
