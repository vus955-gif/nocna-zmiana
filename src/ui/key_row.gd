class_name KeyRow
extends HBoxContainer
## One line of the key panel: the action's name on the left and its two
## places (main, extra) as buttons showing the key or mouse button bound
## there. A click or Enter on a place asks the panel to listen for the new
## key; the place being set shows "press a key" meanwhile.

signal slot_pressed(action: StringName, slot: int)

const HEIGHT := 56
const SLOT_WIDTH := 250
const NAME_INDENT := 26

var action: StringName = &""
var buttons: Array[Button] = []

var _name: Label


static func create(for_action: StringName) -> KeyRow:
	var row := KeyRow.new()
	row.action = for_action
	return row


## The action's name in the current language ("Broń 3" for a weapon slot).
static func action_name(for_action: StringName) -> String:
	var text := String(for_action)
	if text.begins_with("weapon_") and text.substr(7).is_valid_int():
		return TranslationServer.translate("BIND_WEAPON") % int(text.substr(7))
	return TranslationServer.translate("BIND_" + text.to_upper())


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	add_theme_constant_override("separation", 16)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(NAME_INDENT - 16, 0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(indent)
	_name = UiTheme.label("", 26)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_name)
	for slot in KeyBindings.SLOTS:
		var button := UiTheme.menu_button("", 24)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(SLOT_WIDTH, HEIGHT - 6)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func() -> void: slot_pressed.emit(action, slot))
		add_child(button)
		buttons.append(button)
	refresh()


## Shows the current keys; [param listening] is the place being set (-1: none).
func refresh(listening: int = -1) -> void:
	if _name == null:
		return
	_name.text = action_name(action)
	for slot in buttons.size():
		var button := buttons[slot]
		var code := Settings.data.bindings.code_at(action, slot)
		var locked := KeyBindings.is_locked(action, slot)
		button.disabled = locked
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_disabled_color")
		if slot == listening:
			button.text = TranslationServer.translate("BIND_PRESS")
			button.add_theme_color_override("font_color", UiTheme.ACCENT)
			continue
		button.text = KeyBindings.label(code)
		if locked:
			button.add_theme_color_override("font_disabled_color", UiTheme.MUTED)
		elif code == 0:
			button.add_theme_color_override("font_color", UiTheme.DISABLED)
