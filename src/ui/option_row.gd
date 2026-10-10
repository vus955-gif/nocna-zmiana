class_name OptionRow
extends Button
## One line of the options menu: the option's name on the left, its value
## on the right. Focused, left/right (arrows or A/D) change the value (a
## held key keeps stepping a slider only); Enter steps a choice or flips a
## switch, a click on the left or right half of a choice steps it back or
## forward; a slider can also be dragged (the mouse wheel scrolls the list,
## it never moves a slider). Every change goes to Settings at once (applied
## live, written a moment later) - or, for a row of the game itself (the
## difficulty), to its [member getter] and [member setter].

enum Kind { SLIDER, CHOICE, TOGGLE }

signal value_changed(key: StringName)

const HEIGHT := 56
const VALUE_WIDTH := 400
## A click this far left of a choice's "‹" still counts as on it (px).
const CLICK_SLACK := 24.0

var kind: Kind = Kind.TOGGLE
var key: StringName = &""
var label_key: String = ""
## Slider range and step.
var minimum: float = 0.0
var maximum: float = 1.0
var step_size: float = 0.05
## Slider value -> shown text.
var format: Callable = Callable()
## Choices: [value, text] pairs; texts starting with a translation prefix
## are translated.
var choices: Array = []
## () -> value and (value) -> void in place of Settings (invalid: Settings).
var getter: Callable = Callable()
var setter: Callable = Callable()

var _name: Label
var _value: Label
var _slider: HSlider
var _updating: bool = false
## Where the last left click on the row went down (-1: not a click).
var _click_x: float = -1.0


static func slider(setting: StringName, text_key: String, low: float, high: float, step: float, shown: Callable) -> OptionRow:
	var row := OptionRow.new()
	row.kind = Kind.SLIDER
	row.key = setting
	row.label_key = text_key
	row.minimum = low
	row.maximum = high
	row.step_size = step
	row.format = shown
	return row


static func choice(setting: StringName, text_key: String, options: Array) -> OptionRow:
	var row := OptionRow.new()
	row.kind = Kind.CHOICE
	row.key = setting
	row.label_key = text_key
	row.choices = options
	return row


## A choice that reads [param read] and writes [param write] (not a
## setting).
static func bound_choice(text_key: String, options: Array, read: Callable, write: Callable) -> OptionRow:
	var row := choice(&"", text_key, options)
	row.getter = read
	row.setter = write
	return row


static func toggle(setting: StringName, text_key: String) -> OptionRow:
	var row := OptionRow.new()
	row.kind = Kind.TOGGLE
	row.key = setting
	row.label_key = text_key
	return row


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)
	pressed.connect(_on_pressed)
	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26.0
	content.offset_right = -22.0
	content.add_theme_constant_override("separation", 20)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_name = UiTheme.label("", 26)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(_name)
	var value_box := HBoxContainer.new()
	value_box.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value_box.add_theme_constant_override("separation", 18)
	value_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_box.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(value_box)
	if kind == Kind.SLIDER:
		_slider = HSlider.new()
		_slider.min_value = minimum
		_slider.max_value = maximum
		_slider.step = step_size
		_slider.focus_mode = Control.FOCUS_NONE
		_slider.scrollable = false   # the wheel scrolls the list
		_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_slider.value_changed.connect(_on_slider_moved)
		value_box.add_child(_slider)
	_value = UiTheme.label("", 26, UiTheme.TEXT, UiTheme.strong_font())
	_value.custom_minimum_size = Vector2(110 if kind == Kind.SLIDER else VALUE_WIDTH, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_box.add_child(_value)
	refresh()


## Shows the current setting (and the name, in the current language).
func refresh() -> void:
	if _name == null:
		return
	_name.text = tr(label_key)
	var current: Variant = _current()
	match kind:
		Kind.SLIDER:
			_updating = true
			_slider.value = float(current)
			_updating = false
			_value.text = format.call(float(current)) if format.is_valid() else str(current)
		Kind.CHOICE:
			var index := _choice_index()
			var text: String = str(current) if index < 0 else str(choices[index][1])
			_value.text = "‹   %s   ›" % _text(text)
		Kind.TOGGLE:
			var on := bool(current)
			_value.text = tr("OPT_ON") if on else tr("OPT_OFF")
			_value.add_theme_color_override("font_color", UiTheme.ACCENT if on else UiTheme.MUTED)


## Moves the value one step: -1 (left) or +1 (right).
func step(direction: int) -> void:
	match kind:
		Kind.SLIDER:
			var value := clampf(float(_current()) + step_size * direction, minimum, maximum)
			_apply_value(value)
		Kind.CHOICE:
			var index := _choice_index()
			index = 0 if index < 0 else wrapi(index + direction, 0, choices.size())
			_apply_value(choices[index][0])
		Kind.TOGGLE:
			_apply_value(not bool(_current()))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		_click_x = click.position.x
	var left := event.is_action_pressed(&"ui_left", true)
	if left or event.is_action_pressed(&"ui_right", true):
		if kind == Kind.SLIDER or not event.is_echo():
			step(-1 if left else 1)
		accept_event()   # a held key must not wander off to another control


func _on_pressed() -> void:
	var clicked_x := _click_x
	_click_x = -1.0
	if kind == Kind.CHOICE:
		step(click_direction(clicked_x))
	elif kind == Kind.TOGGLE:
		step(1)


## Which way a click at [param x] (row-local, -1 = no click) steps a
## choice: back on the left half of the shown "‹ value ›", forward
## anywhere else.
func click_direction(x: float) -> int:
	if x < 0.0 or _value == null:
		return 1
	var font := _value.get_theme_font(&"font")
	var width := font.get_string_size(_value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _value.get_theme_font_size(&"font_size")).x
	var right := _value.get_global_rect().end.x - get_global_rect().position.x
	var center := right - width * 0.5
	return -1 if x >= right - width - CLICK_SLACK and x < center else 1


func _on_slider_moved(value: float) -> void:
	if not _updating:
		_apply_value(value)


func _current() -> Variant:
	return getter.call() if getter.is_valid() else Settings.get_value(key)


func _apply_value(value: Variant) -> void:
	var before: Variant = _current()
	if setter.is_valid():
		setter.call(value)
	else:
		Settings.set_value(key, value, false)
	if _current() != before:
		Sfx.play_ui(&"ui_move", -8.0)
		value_changed.emit(key)
	refresh()


func _choice_index() -> int:
	var current: Variant = _current()
	for i in choices.size():
		if choices[i][0] == current:
			return i
	return -1


func _text(text: String) -> String:
	for prefix in ["OPT_", "LANG_", "DIFF_"]:
		if text.begins_with(prefix):
			return tr(text)
	return text
