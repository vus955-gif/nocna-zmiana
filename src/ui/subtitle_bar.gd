class_name SubtitleBar
extends CanvasLayer
## Subtitles of the voice lines: who speaks (in their colour) and what, in the
## game's language (Polish players hear English and read Polish). Sits above
## the HUD's hint strip; long lines come in parts timed by their length.

const LAYER := 13
const BOTTOM := 240              ## px above the bottom edge (the hint strip is at 170)
const MAX_CHARS := 110
const WIDTH := 1100.0
const COLOURS := {&"radio": Color(0.91, 0.67, 0.33), &"pa": Color(0.55, 0.82, 0.95), &"guide": Color(0.55, 0.82, 0.95)}
const LABELS := {&"radio": "VOICE_SPEAKER_HENIEK", &"pa": "VOICE_SPEAKER_SYSTEM", &"guide": "VOICE_SPEAKER_GUIDE"}

var _panel: PanelContainer
var _who: Label
var _text: Label
var _key: StringName = &""
var _parts: PackedStringArray = []
var _ends: PackedFloat32Array = []
var _elapsed := 0.0


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 0.78)
	style.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_who = UiTheme.label("", 18, UiTheme.ACCENT)
	_text = UiTheme.label("", 26, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_who)
	column.add_child(_text)
	_panel.add_child(column)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM)
	_panel.visible = false
	var director := get_parent()
	if director and director.has_signal(&"line_started"):
		director.line_started.connect(show_line)
		director.line_ended.connect(clear_line)
	Settings.settings_changed.connect(_on_setting_changed)


func show_line(key: StringName, channel: StringName, seconds: float) -> void:
	_key = key
	_parts = split(tr(key), MAX_CHARS)
	_ends = timings(_parts, seconds)
	_elapsed = 0.0
	_who.text = tr(LABELS.get(channel, "VOICE_SPEAKER_SYSTEM"))
	_who.add_theme_color_override(&"font_color", COLOURS.get(channel, UiTheme.TEXT))
	_text.text = _parts[0] if _parts.size() > 0 else ""
	_panel.visible = Settings.data.subtitles and _text.text != ""


## The line ended: hide, unless another line has taken the bar since
## (&"" clears whatever is up — the director's silence).
func clear_line(key: StringName) -> void:
	if key == _key or key == &"":
		_key = &""
		_panel.visible = false


## The "Napisy" switch takes effect at once, also in the middle of a line.
func _on_setting_changed(key: StringName) -> void:
	if key == &"subtitles":
		_panel.visible = Settings.data.subtitles and _key != &"" and _text.text != ""


func _process(delta: float) -> void:
	if _key != &"":
		advance(delta / maxf(Engine.time_scale, 0.01))   # real time, like the director


func advance(dt: float) -> void:
	_elapsed += dt
	for i in _ends.size():
		if _elapsed < _ends[i]:
			_text.text = _parts[i]
			return
	_text.text = _parts[_parts.size() - 1] if _parts.size() > 0 else ""


func is_showing() -> bool:
	return _panel.visible


func speaker_text() -> String:
	return _who.text


func speaker_colour() -> Color:
	return _who.get_theme_color(&"font_color")


func current_text() -> String:
	return _text.text


## Sentences grouped greedily into parts of at most [param max_chars] (a longer
## sentence stays whole).
static func split(text: String, max_chars: int) -> PackedStringArray:
	var parts: PackedStringArray = []
	var current := ""
	var regex := RegEx.create_from_string("[^.!?…]+[.!?…]*\\s*")
	for found in regex.search_all(text):
		var sentence := found.get_string().strip_edges()
		if sentence == "":
			continue
		if current != "" and current.length() + 1 + sentence.length() > max_chars:
			parts.append(current)
			current = sentence
		else:
			current = sentence if current == "" else current + " " + sentence
	if current != "":
		parts.append(current)
	return parts


## End time of each part, proportional to its length, the last one at [param seconds].
static func timings(parts: PackedStringArray, seconds: float) -> PackedFloat32Array:
	var total := 0
	for part in parts:
		total += part.length()
	var ends: PackedFloat32Array = []
	var acc := 0
	for part in parts:
		acc += part.length()
		ends.append(seconds * acc / maxf(1.0, total))
	return ends
