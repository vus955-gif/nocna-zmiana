class_name NoteReader
extends CanvasLayer
## Reads a note on screen, as paper: a ruled notebook page, a yellow sticky
## note, an old typed order, a curator's letter or a service form, slightly
## askew over the dimmed game, in the writer's hand. While it is open the
## game is paused and the guard takes no input (GameInput stack). E, Esc
## or a click anywhere puts it down (heard before any menu under it: the
## reader lies over the pause menu too, whose list of notes opens it). The
## input is only handed back once those keys are up again, so the E that
## closes a note never opens it again, and the click never fires a shot.
## A long note gets a wider sheet (up to MAX_PAPER_WIDTH, the lines
## rewrapped) before it is scaled down, so a long letter still reads at a
## good size on a 1080p screen; only what does not fit even then shrinks.

signal opened(id: StringName)
signal closed(id: StringName)

const PAPER_WIDTH := 780.0
## A long note's sheet widens in these steps up to this (and the screen).
const MAX_PAPER_WIDTH := 1340.0
const WIDTH_STEP := 140.0
const STICKY_WIDTH := 560.0
const TILT_DEGREES := -1.3
const MARGIN := Vector2(64.0, 52.0)
const OPEN_TIME := 0.18
## Over the pause menu (layer 60): its list of notes opens the reader.
const LAYER := 65
## Room kept free above and below the sheet (the hint goes under it).
const SCREEN_MARGIN := Vector2(40.0, 110.0)

const PAPER_COLORS := {
	NoteCatalog.Paper.LINED: Color(0.93, 0.9, 0.82),
	NoteCatalog.Paper.STICKY: Color(0.98, 0.86, 0.36),
	NoteCatalog.Paper.TYPED: Color(0.87, 0.8, 0.65),
	NoteCatalog.Paper.LETTER: Color(0.94, 0.9, 0.8),
	NoteCatalog.Paper.FORM: Color(0.88, 0.92, 0.93),
}
const INK_COLORS := {
	NoteCatalog.Paper.LINED: Color(0.13, 0.16, 0.36),
	NoteCatalog.Paper.STICKY: Color(0.12, 0.1, 0.16),
	NoteCatalog.Paper.TYPED: Color(0.1, 0.09, 0.08),
	NoteCatalog.Paper.LETTER: Color(0.28, 0.16, 0.08),
	NoteCatalog.Paper.FORM: Color(0.12, 0.15, 0.32),
}

static var _fonts: Dictionary = {}

var is_open: bool = false
var note_id: StringName = &""
## The persistent state (GameState) for the "notes 2/3" line.
var game: PersistentState = null
## The screen to lay the sheet out for (zero: the real one; tests).
var screen_override := Vector2.ZERO

var _paused_here: bool = false
var _root: Control
var _paper: PanelContainer
var _lines: PaperLines
var _caption: Label
var _title: Label
var _body: Label
var _sign: Label
var _hint: Label
var _tween: Tween = null


## What is printed or ruled on the sheet, drawn under the writing.
class PaperLines extends Control:
	var kind: NoteCatalog.Paper = NoteCatalog.Paper.LINED
	var body: Label = null
	var stain: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		match kind:
			NoteCatalog.Paper.LINED:
				_ruled()
			NoteCatalog.Paper.STICKY:
				draw_rect(Rect2(0, 0, size.x, 54), Color(0.0, 0.0, 0.0, 0.05))
				var curl := PackedVector2Array([Vector2(size.x - 70, size.y), Vector2(size.x, size.y - 70), Vector2(size.x, size.y)])
				draw_colored_polygon(curl, Color(0.0, 0.0, 0.0, 0.08))
			NoteCatalog.Paper.TYPED:
				var frame := Rect2(Vector2(22, 22), size - Vector2(44, 44))
				draw_rect(frame, Color(0.3, 0.22, 0.12, 0.5), false, 2.0)
				draw_rect(frame.grow(-6), Color(0.3, 0.22, 0.12, 0.35), false, 1.0)
				_stamp(Vector2(118, size.y - 70))
			NoteCatalog.Paper.LETTER:
				# a letterhead rule just above the first line of the letter
				var rule_y := _body_top() - 10.0 if body != null else 118.0
				draw_line(Vector2(56, rule_y), Vector2(size.x - 56, rule_y), Color(0.4, 0.26, 0.12, 0.35), 1.5)
				draw_rect(Rect2(Vector2(18, 18), size - Vector2(36, 36)), Color(0.4, 0.26, 0.12, 0.18), false, 1.0)
			NoteCatalog.Paper.FORM:
				var grid := Color(0.35, 0.55, 0.75, 0.16)
				var x := 0.0
				while x < size.x:
					draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
					x += 26.0
				var y := 0.0
				while y < size.y:
					draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
					y += 26.0
				draw_rect(Rect2(0, 0, size.x, 96), Color(0.2, 0.35, 0.55, 0.12))
		if stain:
			var center := Vector2(size.x - 130, size.y - 120)
			draw_arc(center, 72.0, 0.0, TAU, 64, Color(0.45, 0.27, 0.1, 0.16), 9.0, true)
			draw_arc(center, 66.0, 0.4, 4.9, 48, Color(0.45, 0.27, 0.1, 0.1), 3.0, true)

	## Notebook rules on the body's baselines, and the red margin.
	func _ruled() -> void:
		draw_line(Vector2(48, 0), Vector2(48, size.y), Color(0.85, 0.3, 0.3, 0.45), 2.0)
		if body == null:
			return
		var font := body.get_theme_font(&"font")
		var font_size := body.get_theme_font_size(&"font_size")
		var pitch := body.get_line_height() + body.get_theme_constant(&"line_spacing")
		if pitch <= 4.0:
			return
		var local := get_global_transform().affine_inverse() * body.get_global_transform()
		var first := local.origin.y + font.get_ascent(font_size) + 7.0
		var y := first
		while y > 60.0:
			y -= pitch
		y += pitch
		while y < size.y - 24.0:
			draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color(0.3, 0.45, 0.75, 0.28), 1.5)
			y += pitch

	## Top of the body text in this control's frame.
	func _body_top() -> float:
		return (get_global_transform().affine_inverse() * body.get_global_transform()).origin.y

	## A faded round museum stamp (in the corner, clear of the writing).
	func _stamp(center: Vector2) -> void:
		var ink := Color(0.45, 0.2, 0.55, 0.3)
		draw_arc(center, 50.0, 0.0, TAU, 40, ink, 2.5, true)
		draw_arc(center, 41.0, 0.0, TAU, 40, ink, 1.2, true)
		draw_string(NoteReader.typed_font(), center + Vector2(-40, 6), "MUZEUM", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 16, ink)


## A handwriting face (Windows ships Segoe Print and Ink Free).
static func hand_font() -> Font:
	return _font("hand", ["Segoe Print", "Ink Free", "Bradley Hand", "Comic Sans MS", "Georgia", "serif"], 400, false)


static func typed_font() -> Font:
	return _font("typed", ["Courier New", "Consolas", "Lucida Console", "monospace"], 400, false)


static func letter_font() -> Font:
	return _font("letter", ["Palatino Linotype", "Book Antiqua", "Georgia", "serif"], 400, true)


static func _font(key: String, names: Array, weight: int, italic: bool) -> Font:
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(names)
		font.font_weight = weight
		font.font_italic = italic
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.hinting = TextServer.HINTING_LIGHT
		_fonts[key] = font
	return _fonts[key]


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if game == null:
		game = GameState
	_build()


func _exit_tree() -> void:
	if is_open and _paused_here and is_inside_tree():
		get_tree().paused = false
	if is_open or is_holding_input():
		GameInput.pop_ui(self)


## Shows note [param id]; pauses the game and takes the input.
func open_note(id: StringName) -> void:
	if is_open or not NoteCatalog.is_note(id):
		return
	note_id = id
	_fill(id)
	is_open = true
	visible = true
	_paused_here = not get_tree().paused
	get_tree().paused = true
	GameInput.push_ui(self)
	WorldSounds.ui(&"paper")
	_paper.modulate.a = 0.0
	_center.call_deferred()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_paper, ^"modulate:a", 1.0, OPEN_TIME)
	opened.emit(id)


## Puts the note down. The guard gets the input back when E / Esc / the
## mouse buttons are up again.
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if _paused_here:
		get_tree().paused = false
	GameInput.pop_ui_on_release(self)
	WorldSounds.ui(&"paper", -6.0)
	closed.emit(note_id)


## True while the input is still held back after closing.
func is_holding_input() -> bool:
	return GameInput.is_releasing(self)


## Heard before the GUI and every other node: whatever lies under the
## sheet (the game, the pause menu and its buttons) never gets the E, the
## Esc or the click that puts it down.
func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var click := event as InputEventMouseButton
	if WorldInput.closes(event) or (click != null and click.pressed and click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_open and _body != null:
		_fill(note_id)


func _fill(id: StringName) -> void:
	var kind := NoteCatalog.paper(id)
	var ink: Color = INK_COLORS[kind]
	var hand := hand_font()
	var body_font := hand
	var body_size := 27
	var title_font := hand
	match kind:
		NoteCatalog.Paper.TYPED:
			body_font = typed_font()
			title_font = typed_font()
			body_size = 24
		NoteCatalog.Paper.LETTER:
			body_font = letter_font()
			title_font = letter_font()
			body_size = 29
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_COLORS[kind]
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 26
	style.shadow_offset = Vector2(6, 10)
	_paper.add_theme_stylebox_override("panel", style)
	var width := STICKY_WIDTH if kind == NoteCatalog.Paper.STICKY else sheet_width(id, _screen_size())
	_paper.custom_minimum_size = Vector2(width, width if kind == NoteCatalog.Paper.STICKY else 0.0)
	var text_width := width - MARGIN.x * 2.0
	_caption.text = ""
	if NoteCatalog.in_set(id):
		_caption.text = (tr("NOTES_SET_PROGRESS") % [NoteCatalog.set_read(game), NoteCatalog.SET.size()]).to_upper()
	elif kind == NoteCatalog.Paper.FORM:
		_caption.text = tr("NOTE_FORM_HEADER").to_upper()
	_caption.visible = _caption.text != ""
	_caption.add_theme_color_override("font_color", Color(ink, 0.55))
	_style_label(_title, title_font, 38 if kind != NoteCatalog.Paper.TYPED else 28, ink, text_width)
	_style_label(_body, body_font, body_size, ink, text_width)
	_style_label(_sign, title_font, body_size + 2, ink, text_width)
	_title.text = tr(NoteCatalog.title_key(id))
	_body.text = tr(NoteCatalog.body_key(id))
	_sign.text = tr(NoteCatalog.sign_key(id))
	_body.add_theme_constant_override("line_spacing", 6 if kind != NoteCatalog.Paper.TYPED else 8)
	_lines.kind = kind
	_lines.body = _body
	_lines.stain = id == &"note_1"
	_lines.queue_redraw()
	_hint.text = (tr("NOTE_READER_HINT") % [GameInput.key_label(&"interact"), GameInput.key_label(&"pause")]).to_upper()


## The width of note [param id]'s sheet on a [param screen]-sized screen:
## PAPER_WIDTH, or wider in WIDTH_STEP steps while its text would not fit
## the screen's height (never past MAX_PAPER_WIDTH or the screen).
func sheet_width(id: StringName, screen: Vector2) -> float:
	var room := screen.y - SCREEN_MARGIN.y * 2.0
	var widest := minf(MAX_PAPER_WIDTH, screen.x - SCREEN_MARGIN.x * 2.0)
	var width := PAPER_WIDTH
	while width < widest and sheet_height(id, width) > room:
		width = minf(width + WIDTH_STEP, widest)
	return width


## About how tall note [param id]'s sheet is at [param width] (its title,
## body and signature wrapped in their fonts, the margins and gaps).
func sheet_height(id: StringName, width: float) -> float:
	var kind := NoteCatalog.paper(id)
	var text_width := width - MARGIN.x * 2.0
	var body_font := hand_font()
	var body_size := 27
	var spacing := 6
	match kind:
		NoteCatalog.Paper.TYPED:
			body_font = typed_font()
			body_size = 24
			spacing = 8
		NoteCatalog.Paper.LETTER:
			body_font = letter_font()
			body_size = 29
	var title_size := 38 if kind != NoteCatalog.Paper.TYPED else 28
	var height := MARGIN.y * 2.0 + 14.0 * 3.0
	height += body_font.get_multiline_string_size(tr(NoteCatalog.title_key(id)), HORIZONTAL_ALIGNMENT_LEFT, text_width, title_size).y
	var body := body_font.get_multiline_string_size(tr(NoteCatalog.body_key(id)), HORIZONTAL_ALIGNMENT_LEFT, text_width, body_size)
	var lines := maxf(round(body.y / maxf(body_font.get_height(body_size), 1.0)), 1.0)
	height += body.y + spacing * (lines - 1.0)
	height += body_font.get_multiline_string_size(tr(NoteCatalog.sign_key(id)), HORIZONTAL_ALIGNMENT_LEFT, text_width, body_size + 2).y
	return height


func _screen_size() -> Vector2:
	if screen_override != Vector2.ZERO:
		return screen_override
	return _root.size if _root != null and _root.size.x > 0.0 else Vector2(1920, 1080)


static func _style_label(target: Label, font: Font, font_size: int, color: Color, width: float) -> void:
	target.add_theme_font_override("font", font)
	target.add_theme_font_size_override("font_size", font_size)
	target.add_theme_color_override("font_color", color)
	target.custom_minimum_size = Vector2(width, 0.0)


## Middle of the screen, a little high (the hint goes under it), askew;
## scaled down when the sheet would not fit the screen's height.
func _center() -> void:
	if _paper == null:
		return
	_paper.reset_size()
	var screen := _screen_size()
	var fit := minf((screen.y - SCREEN_MARGIN.y * 2.0) / _paper.size.y, (screen.x - SCREEN_MARGIN.x * 2.0) / _paper.size.x)
	var shrink := clampf(fit, 0.3, 1.0)
	_paper.pivot_offset = _paper.size * 0.5
	_paper.scale = Vector2.ONE * shrink
	_paper.position = ((screen - _paper.size) * 0.5 + Vector2(0.0, -24.0)).round()
	_paper.rotation = deg_to_rad(TILT_DEGREES)
	_hint.reset_size()
	var paper_bottom := _paper.position.y + _paper.size.y * 0.5 * (1.0 + shrink)
	_hint.position = Vector2((screen.x - _hint.size.x) * 0.5, minf(paper_bottom + 34.0, screen.y - _hint.size.y - 16.0))
	_lines.queue_redraw()


## The sheet's on-screen rectangle (scale included, tilt left out).
func paper_rect() -> Rect2:
	var shown := _paper.size * _paper.scale
	return Rect2(_paper.position + (_paper.size - shown) * 0.5, shown)


func _build() -> void:
	_root = Control.new()
	_root.name = "NoteReader"
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.015, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_paper = PanelContainer.new()
	_paper.name = "Paper"
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_paper)
	_lines = PaperLines.new()
	_paper.add_child(_lines)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(MARGIN.x))
	margin.add_theme_constant_override("margin_right", int(MARGIN.x))
	margin.add_theme_constant_override("margin_top", int(MARGIN.y))
	margin.add_theme_constant_override("margin_bottom", int(MARGIN.y))
	_paper.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_caption = UiTheme.caption("", 17)
	column.add_child(_caption)
	_title = _text_label()
	column.add_child(_title)
	_body = _text_label()
	column.add_child(_body)
	_sign = _text_label()
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_sign)
	_paper.resized.connect(_center)
	_hint = UiTheme.caption("", 20, UiTheme.MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)


static func _text_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
