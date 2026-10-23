class_name SubtitleBar
extends CanvasLayer
## Subtitles of the voice lines: who speaks (in their colour) and what, in the
## game's language (Polish players hear English and read Polish). Sits above
## the HUD's hint strip; long lines come in parts timed by their length.
## A HUD plaque (UiTheme): the speaker in small capitals of their colour
## (Heniek's radio in the lamps' amber, the museum's Curator and audio
## guide in the moon's blue), the line in the serif. The plaque grows up
## from its bottom edge, centred, so a second line never covers the hint.

const LAYER := 13
## Over the dawn card while the dawn line plays: its veil would hide the line's end.
const DAWN_LAYER := DawnScreen.LAYER + 1
const BOTTOM := 240              ## px above the bottom edge (the hint strip is at 170)
## Air kept above the HUD's hint strip when a long hint reaches higher.
const HINT_GAP := 14.0
const MAX_CHARS := 110
const WIDTH := 1100.0
## The text sizes of the option "Rozmiar napisów": the speaker's name, the
## line (points) and the width the line wraps at. Medium is the design
## (WIDTH); none is smaller than the HUD's smallest text.
const SIZES := {
	SettingsData.SubtitleSize.SMALL: {"who": 20, "text": 22, "width": 960.0},
	SettingsData.SubtitleSize.MEDIUM: {"who": 22, "text": 26, "width": WIDTH},
	SettingsData.SubtitleSize.LARGE: {"who": 30, "text": 38, "width": 1500.0},
}
## The dark backing (option "Ciemne tło napisów"): a band this much wider
## than the plaque on every side, at most this opaque (at the option's 100 %).
const BACKING_PAD := 16.0
const BACKING_ALPHA := 0.92
const COLOURS := {&"radio": UiTheme.ACCENT, &"pa": UiTheme.MOON, &"guide": UiTheme.MOON}
const LABELS := {&"radio": "VOICE_SPEAKER_HENIEK", &"pa": "VOICE_SPEAKER_SYSTEM", &"guide": "VOICE_SPEAKER_GUIDE"}

var _panel: PanelContainer
## The dark band behind the plaque (option subtitle_backing), under it.
var _backing: ColorRect
var _who: Label
var _text: Label
var _key: StringName = &""
var _parts: PackedStringArray = []
var _ends: PackedFloat32Array = []
var _elapsed := 0.0


func _init() -> void:
	layer = LAYER


## Raised above the dawn card (from dawn until the next night), back under the
## menus otherwise.
func set_over_dawn(over: bool) -> void:
	layer = DAWN_LAYER if over else LAYER


func _ready() -> void:
	_backing = ColorRect.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.visible = false
	add_child(_backing)
	_panel = PanelContainer.new()
	var style := UiTheme.plaque(UiTheme.Plaque.HUD)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_who = UiTheme.label("", 22, UiTheme.ACCENT, UiTheme.small_caps_font(2))
	_text = UiTheme.label("", 26, UiTheme.TEXT, UiTheme.body_font())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_who)
	column.add_child(_text)
	_panel.add_child(column)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM)
	# a line in two rows grows the bar up, its foot stays clear of the hint
	# strip under it (as the HUD's own hint grows)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	var director := get_parent()
	if director and director.has_signal(&"line_started"):
		director.line_started.connect(show_line)
		director.line_ended.connect(clear_line)
	Settings.settings_changed.connect(_on_setting_changed)
	_apply_look()


## The plaque centred, its bottom edge BOTTOM above the screen's (higher
## when the HUD's hint strip reaches up there), at its own size (one line
## or two).
func _place() -> void:
	var least := _panel.get_combined_minimum_size()
	var bottom := float(BOTTOM)
	if is_inside_tree():
		for hud in get_tree().get_nodes_in_group(Hud.GROUP):
			if hud is Hud and hud.get_viewport() == get_viewport():
				var hint := (hud as Hud).hint_clearance()
				if hint > 0.0:
					bottom = maxf(bottom, hint + HINT_GAP)
				# a big HUD size makes the corner plaques reach over the usual height
				bottom = maxf(bottom, (hud as Hud).bottom_clearance() + HINT_GAP)
	if _panel.offset_left != -least.x * 0.5 or _panel.offset_bottom != -bottom or _panel.offset_top != -bottom - least.y:
		_panel.offset_left = -least.x * 0.5
		_panel.offset_right = least.x * 0.5
		_panel.offset_bottom = -bottom
		_panel.offset_top = -bottom - least.y
	_place_backing(least, bottom)


## The backing round the plaque (anchored to the bottom middle like it).
func _place_backing(least: Vector2, bottom: float) -> void:
	_backing.visible = _panel.visible and Settings.data.subtitle_backing > 0.0
	if not _backing.visible:
		return
	_backing.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_backing.offset_left = -least.x * 0.5 - BACKING_PAD
	_backing.offset_right = least.x * 0.5 + BACKING_PAD
	_backing.offset_bottom = -bottom + BACKING_PAD
	_backing.offset_top = -bottom - least.y - BACKING_PAD


func show_line(key: StringName, channel: StringName, seconds: float) -> void:
	_key = key
	_parts = split(tr(key), MAX_CHARS)
	_ends = timings(_parts, seconds)
	_elapsed = 0.0
	_who.text = tr(LABELS.get(channel, "VOICE_SPEAKER_SYSTEM"))
	_who.add_theme_color_override(&"font_color", COLOURS.get(channel, UiTheme.TEXT))
	_text.text = _parts[0] if _parts.size() > 0 else ""
	_panel.visible = Settings.data.subtitles and _text.text != ""
	_place()


## The line ended: hide, unless another line has taken the bar since
## (&"" clears whatever is up — the director's silence).
func clear_line(key: StringName) -> void:
	if key == _key or key == &"":
		_key = &""
		_panel.visible = false
		_backing.visible = false


## The "Napisy" switch takes effect at once, also in the middle of a line.
func _on_setting_changed(key: StringName) -> void:
	if key == &"subtitles":
		_panel.visible = Settings.data.subtitles and _key != &"" and _text.text != ""
		_place()
	if key == &"subtitle_size" or key == &"subtitle_backing" or key == &"":
		_apply_look()


## The text size and the backing of the options (live, also mid-line).
func _apply_look() -> void:
	var look: Dictionary = SIZES[Settings.data.subtitle_size]
	_who.add_theme_font_size_override(&"font_size", int(look["who"]))
	_text.add_theme_font_size_override(&"font_size", int(look["text"]))
	_text.custom_minimum_size.x = float(look["width"])
	_backing.color = Color(0.0, 0.0, 0.0, Settings.data.subtitle_backing * BACKING_ALPHA)
	if _panel.visible:
		_place()


func _process(delta: float) -> void:
	if _key != &"":
		advance(delta / maxf(Engine.time_scale, 0.01))   # real time, like the director
	if _panel.visible:
		_place()


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
