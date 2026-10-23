class_name ExhibitCard
extends CanvasLayer
## The card of a museum label, a staff notice or a thing the guard looks
## at closely (plan docs/superpowers/plans/2026-10-21-opowiesc-muzeum.md):
## an exhibit label in the HUD's style (UiTheme LABEL plaque, a band in the
## wing's colour on its left edge) at the right edge of the screen, beside
## what the guard is looking at - the inventory number in small capitals,
## a brass rule, the title in the serif, two or three lines in italic.
## The game goes on (no pause). It goes away by itself once there was time
## to read it (READ_BASE + READ_PER_CHAR per letter), when the guard walks
## more than LEAVE m from what he read (the [member source] point), or when
## the same thing is used again (toggle()).

signal closed

const LAYER := 12
## Width of the text column (canvas units of the 1920 x 1080 canvas).
const WIDTH := 560.0
## Air between the card and the right edge of the screen.
const EDGE := 64.0
## The card's middle sits this far down the screen (a little under the eyes).
const HEIGHT_AT := 0.5
const FADE := 0.2
const READ_BASE := 3.0
const READ_PER_CHAR := 0.05
## Walking this far (m) from what was read puts the card down.
const LEAVE := 3.5
## Seconds between looks at where the guard is.
const CHECK := 0.2

## What the card shows: [caption, title, text] (empty when closed).
var shown: PackedStringArray = []
## Where the thing read stands (INF: nowhere in particular).
var source := Vector3.INF
## -> the guard (Node3D) or null.
var guard_source: Callable = Callable()

var _root: Control
var _panel: PanelContainer
var _caption: Label
var _title: Label
var _text: Label
var _style: PlaqueStyle
var _time := 0.0
var _hold := 0.0
var _closing := false
var _check_left := 0.0


func _ready() -> void:
	layer = LAYER
	_root = Control.new()
	_root.name = "ExhibitCard"
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = UiTheme.plaque(UiTheme.Plaque.LABEL)
	_style.content_margin_left = 40.0
	_style.content_margin_right = 36.0
	_style.band_width = 6.0
	_panel.add_theme_stylebox_override("panel", _style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_caption = UiTheme.caption("", 18, UiTheme.ACCENT)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(_caption)
	var rule := UiTheme.ornament(WIDTH, false)
	rule.size_flags_horizontal = Control.SIZE_FILL
	column.add_child(rule)
	_title = UiTheme.label("", 34, UiTheme.TEXT, UiTheme.title_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(WIDTH, 0)
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(_title)
	_text = UiTheme.label("", 23, Color(0.84, 0.8, 0.72), UiTheme.italic_font())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	_text.add_theme_constant_override("line_spacing", 3)
	column.add_child(_text)
	_panel.visible = false
	_root.add_child(_panel)


## Shows [param title] with [param text] under [param caption]; the band
## takes [param accent] (a wing's colour). [param at]: where the thing
## stands (walking away from it puts the card down).
func show_card(caption: String, title: String, text: String, at: Vector3 = Vector3.INF, accent: Color = UiTheme.ACCENT) -> void:
	shown = PackedStringArray([caption, title, text])
	source = at
	_caption.text = caption.to_upper()
	_caption.visible = caption != ""
	_title.text = title
	_text.text = text
	_text.visible = text != ""
	_style.band = Color(accent, 0.9)
	_time = 0.0
	_closing = false
	_hold = READ_BASE + READ_PER_CHAR * float(title.length() + text.length())
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.reset_size()
	_place()


## Shows the card, or puts it down when this very card is up.
func toggle(caption: String, title: String, text: String, at: Vector3 = Vector3.INF, accent: Color = UiTheme.ACCENT) -> void:
	if is_open() and not _closing and shown == PackedStringArray([caption, title, text]):
		close()
		return
	show_card(caption, title, text, at, accent)


func is_open() -> bool:
	return not shown.is_empty()


## Fades the card out.
func close() -> void:
	if not is_open() or _closing:
		return
	_closing = true
	_time = 0.0


## The card's size on the canvas (its contents' full size).
func card_size() -> Vector2:
	return _panel.get_combined_minimum_size()


## The card's rectangle on the canvas.
func card_rect() -> Rect2:
	return Rect2(_panel.position, card_size())


## How long the card stays up before it fades by itself.
func hold_time() -> float:
	return _hold


func _place() -> void:
	var view := _root.size if _root.size.x > 0.0 else Vector2(1920.0, 1080.0)
	var size := card_size()
	_panel.position = Vector2(view.x - EDGE - size.x, view.y * HEIGHT_AT - size.y * 0.5)


func _process(delta: float) -> void:
	if not is_open():
		return
	_time += delta
	if _closing:
		_panel.modulate.a = 1.0 - clampf(_time / FADE, 0.0, 1.0)
		if _time >= FADE:
			_finish()
		return
	_panel.modulate.a = clampf(_time / FADE, 0.0, 1.0)
	_place()
	if _time >= _hold:
		close()
		return
	_check_left -= delta
	if _check_left > 0.0 or source == Vector3.INF or not guard_source.is_valid():
		return
	_check_left = CHECK
	var guard := guard_source.call() as Node3D
	if guard != null and guard.global_position.distance_to(source) > LEAVE:
		close()


func _finish() -> void:
	shown = PackedStringArray()
	source = Vector3.INF
	_closing = false
	_panel.visible = false
	closed.emit()
