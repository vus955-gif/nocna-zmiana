class_name UiTheme
## The look shared by every menu and panel: near-black translucent panels
## with a thin brass edge, warm off-white text and a brass accent for
## titles and focus (an old museum at night). Fonts come from the system
## (nothing bundled): a book serif for titles, a clean DIN-like sans for
## everything else, each with generic fallbacks. The canvas stretch scales
## all sizes with the window (they are in 1920x1080 units).

const ACCENT := Color(0.91, 0.67, 0.33)
const ACCENT_SOFT := Color(0.91, 0.67, 0.33, 0.3)
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.64, 0.6, 0.54)
const DISABLED := Color(0.43, 0.41, 0.38)
const DANGER := Color(0.9, 0.38, 0.32)
const GOOD := Color(0.62, 0.82, 0.55)
const DUST := Color(1.0, 0.84, 0.5)
const PANEL := Color(0.06, 0.055, 0.05, 0.92)
## Full-screen dim behind a menu opened over the game.
const SHADE := Color(0.01, 0.01, 0.015, 0.68)

const TEXT_SIZE := 26
const SMALL_SIZE := 20
## Weight of strong_font() (semibold).
const STRONG_WEIGHT := 600

static var _theme: Theme = null
static var _fonts: Dictionary = {}


## The theme every menu root uses (built once).
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func title_font() -> Font:
	return _font("title", ["Georgia", "Constantia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"], 600)


static func body_font() -> Font:
	return _font("body", ["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"], 400)


## The sans at semibold. Bahnschrift is one variable font file (its weights
## are points on a "wght" axis, not separate faces), so asking the system
## for weight 600 still gives its regular face; the variation sets the axis.
## Fonts without that axis ignore it and use their own semibold face.
static func strong_font() -> Font:
	var key := "strong_wght"
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _font("strong", ["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"], STRONG_WEIGHT)
		variation.variation_opentype = {"wght": STRONG_WEIGHT}
		_fonts[key] = variation
	return _fonts[key]


## Title font with extra letter spacing (big headings).
static func spaced_title_font(spacing: int) -> Font:
	var key := "title_spaced_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = title_font()
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


## Sans font with letter spacing (small caps-like labels).
static func spaced_font(spacing: int) -> Font:
	var key := "body_spaced_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = strong_font()
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


static func label(text: String, size: int = TEXT_SIZE, color: Color = TEXT, font: Font = null) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if font != null:
		result.add_theme_font_override("font", font)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A heading in the brass title face.
static func heading(text: String, size: int = 44) -> Label:
	return label(text, size, ACCENT, spaced_title_font(2))


## Small uppercase caption (section names, hints).
static func caption(text: String, size: int = SMALL_SIZE, color: Color = MUTED) -> Label:
	return label(text, size, color, spaced_font(3))


## A thin brass line.
static func rule(width: float = 0.0) -> ColorRect:
	var line := ColorRect.new()
	line.color = ACCENT_SOFT
	line.custom_minimum_size = Vector2(width, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The dark translucent panel with a brass edge.
static func panel_style(margin: float = 36.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(ACCENT, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 18
	return style


## A menu button: plain text, a brass bar and warm wash when focused.
static func menu_button(text: String, size: int = 34) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", size)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus())
	return button


static func _font(key: String, names: Array, weight: int) -> Font:
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(names)
		font.font_weight = weight
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.hinting = TextServer.HINTING_LIGHT
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		font.multichannel_signed_distance_field = false
		_fonts[key] = font
	return _fonts[key]


static func _build() -> Theme:
	var built := Theme.new()
	built.default_font = body_font()
	built.default_font_size = TEXT_SIZE
	built.set_color("font_color", "Label", TEXT)
	built.set_constant("line_spacing", "Label", 4)
	# buttons
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.content_margin_left = 22.0
	normal.content_margin_right = 22.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(ACCENT, 0.12)
	focus.border_color = ACCENT
	focus.border_width_left = 4
	var pressed := focus.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(ACCENT, 0.22)
	var disabled := normal.duplicate() as StyleBoxFlat
	built.set_stylebox("normal", "Button", normal)
	built.set_stylebox("hover", "Button", focus)
	built.set_stylebox("focus", "Button", focus)
	built.set_stylebox("pressed", "Button", pressed)
	built.set_stylebox("hover_pressed", "Button", pressed)
	built.set_stylebox("disabled", "Button", disabled)
	built.set_color("font_color", "Button", TEXT)
	built.set_color("font_hover_color", "Button", ACCENT)
	built.set_color("font_focus_color", "Button", ACCENT)
	built.set_color("font_pressed_color", "Button", ACCENT)
	built.set_color("font_hover_pressed_color", "Button", ACCENT)
	built.set_color("font_disabled_color", "Button", DISABLED)
	built.set_font("font", "Button", strong_font())
	# panels
	built.set_stylebox("panel", "PanelContainer", panel_style())
	built.set_stylebox("panel", "Panel", panel_style())
	# sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	track.set_corner_radius_all(2)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(ACCENT, 0.85)
	built.set_stylebox("slider", "HSlider", track)
	built.set_stylebox("grabber_area", "HSlider", filled)
	built.set_stylebox("grabber_area_highlight", "HSlider", filled)
	built.set_icon("grabber", "HSlider", _dot(22, TEXT))
	built.set_icon("grabber_highlight", "HSlider", _dot(22, ACCENT))
	built.set_icon("grabber_disabled", "HSlider", _dot(22, DISABLED))
	built.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	# scroll bars: a thin brass thread
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	bar.content_margin_left = 3.0
	bar.content_margin_right = 3.0
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(ACCENT, 0.5)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3.0
	grab.content_margin_right = 3.0
	built.set_stylebox("scroll", "VScrollBar", bar)
	built.set_stylebox("grabber", "VScrollBar", grab)
	built.set_stylebox("grabber_highlight", "VScrollBar", grab)
	built.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return built


## A round grabber icon.
static func _dot(diameter: int, color: Color) -> Texture2D:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var alpha := clampf(radius - 1.0 - d, 0.0, 1.0)
			var ring := clampf(radius - 4.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(color.lerp(Color(0.1, 0.09, 0.08), 1.0 - ring), alpha))
	return ImageTexture.create_from_image(image)
