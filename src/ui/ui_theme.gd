class_name UiTheme
## The look of every menu, panel and HUD piece: the museum plaque (design
## 2026-10-19-styl-hud). Dark enamel with cut corners and an engraved brass
## rule (PlaqueStyle), brass instruments for bars (HudGauge), icons drawn in
## a few strokes (UiIcons), and one typeface of the museum's century:
## Georgia, after the 19th-century Scotch Romans - engraved capitals for
## labels, lining figures for numbers, the roman for text, the italic for
## an exhibit label's description. Georgia is a Windows system font (the
## game ships for Windows only): nothing is bundled, a generic serif stands
## in elsewhere. The colours are the night's three lights: the lamps'
## amber (brass, captions, the clock, Dust), the moon's blue (the museum's
## systems: the Curator, the audio guide, the flashlight) and the
## emergency red (health, danger, the guardians' bars). The canvas stretch
## scales all sizes with the window (they are in 1920x1080 units).

## The lamps: brass and amber.
const ACCENT := Color(0.91, 0.67, 0.33)
const ACCENT_SOFT := Color(0.91, 0.67, 0.33, 0.3)
const BRASS := Color(0.82, 0.6, 0.3)
const BRASS_DARK := Color(0.2, 0.14, 0.07, 0.9)
## Ivory text on the enamel, and its quieter tones.
const TEXT := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.7, 0.66, 0.59)
const DISABLED := Color(0.45, 0.43, 0.4)
## The emergency light: danger text, and the fill of health and boss bars.
const DANGER := Color(0.96, 0.47, 0.39)
const EMERGENCY := Color(0.84, 0.17, 0.13)
## The moon: the museum's systems (the Curator, the audio guide), the flashlight.
const MOON := Color(0.6, 0.82, 0.95)
const GOOD := Color(0.62, 0.82, 0.55)
const DUST := Color(1.0, 0.84, 0.5)
## The plaque's enamel and the sunken channel of a bar.
const ENAMEL := Color(0.05, 0.043, 0.036, 0.86)
const CHANNEL := Color(0.025, 0.02, 0.018, 0.92)
const PANEL := Color(0.06, 0.055, 0.05, 0.92)
## Full-screen dim behind a menu opened over the game.
const SHADE := Color(0.01, 0.01, 0.015, 0.68)
## The serif and its stand-ins.
const SERIF: Array[String] = ["Georgia", "Constantia", "Cambria", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"]
## The modern security equipment (CCTV monitors, the gun locker's stencil):
## a DIN-like sans, not the museum's serif.
const DEVICE_SANS: Array[String] = ["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"]
## Lining figures (Georgia's default ones are old-style).
const LINING := {"lnum": 1}

## Plaque variants (plaque()).
enum Plaque { PANEL, HUD, CHIP, LABEL, KEYCAP, ROW }

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


## The serif at semibold weight (Georgia Bold): titles, and the base of
## the 3D labels about the museum.
static func title_font() -> Font:
	return _font("title", SERIF, 600)


## The roman with lining figures: text.
static func body_font() -> Font:
	var key := "body_lining"
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _font("body", SERIF, 400)
		variation.opentype_features = LINING
		_fonts[key] = variation
	return _fonts[key]


## The serif's italic: an exhibit label's description.
static func italic_font() -> Font:
	var key := "italic_lining"
	if not _fonts.has(key):
		var base := _font("italic", SERIF, 400) as SystemFont
		base.font_italic = true
		var variation := FontVariation.new()
		variation.base_font = base
		variation.opentype_features = LINING
		_fonts[key] = variation
	return _fonts[key]


## The serif at semibold (Georgia Bold) with lining figures: numbers,
## buttons, the HUD's labels. A variation with the "wght" axis set, so a
## variable stand-in gets its semibold too (Georgia has none: its bold face
## comes from the weight asked of the system).
static func strong_font() -> Font:
	var key := "strong_wght"
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _font("strong", SERIF, STRONG_WEIGHT)
		variation.variation_opentype = {"wght": STRONG_WEIGHT}
		variation.opentype_features = LINING
		_fonts[key] = variation
	return _fonts[key]


## The figures of the HUD's numbers (health, ammo, Dust, the clock).
static func number_font() -> Font:
	return strong_font()


## The security equipment's sans (CCTV, the gun locker): Bahnschrift at
## semibold, with [param spacing] between the letters.
static func device_font(spacing: int = 0) -> Font:
	var key := "device_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _font("device", DEVICE_SANS, STRONG_WEIGHT)
		variation.variation_opentype = {"wght": STRONG_WEIGHT}
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


## Title font with extra letter spacing (big headings).
static func spaced_title_font(spacing: int) -> Font:
	var key := "title_spaced_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = title_font()
		variation.spacing_glyph = spacing
		variation.opentype_features = LINING
		_fonts[key] = variation
	return _fonts[key]


## Engraved capitals: the semibold serif with letter spacing (labels,
## captions, the night's number, the weapon's name).
static func spaced_font(spacing: int) -> Font:
	var key := "body_spaced_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = strong_font()
		variation.spacing_glyph = spacing
		variation.opentype_features = LINING   # a variation's features do not reach through another
		_fonts[key] = variation
	return _fonts[key]


## Small capitals of the semibold serif (Georgia's own, Polish letters
## included) with letter spacing: a caption that keeps its text's case
## (a speaker's name: "Heniek · radio").
static func small_caps_font(spacing: int) -> Font:
	var key := "small_caps_%d" % spacing
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = strong_font()
		variation.spacing_glyph = spacing
		variation.opentype_features = {"lnum": 1, "smcp": 1}
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


## The big plaque of a menu (rivets, a soft shadow), [param margin] inside.
static func panel_style(margin: float = 36.0) -> PlaqueStyle:
	var style := plaque(Plaque.PANEL)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


## A plaque of the house style:
## PANEL - a menu's: rivets, a soft shadow, the most opaque enamel;
## HUD - a HUD corner's block: the rule, no rivets;
## CHIP - a small HUD piece (a toast, a prompt, the Dust): a lighter rule;
## LABEL - an exhibit label (a discovery's banner, the F1 help): rivets;
## KEYCAP - a brass key with a dark letter;
## ROW - a focused menu row: a brass wash and a brass band on the left.
static func plaque(kind: Plaque = Plaque.HUD) -> PlaqueStyle:
	var style := PlaqueStyle.new()
	match kind:
		Plaque.PANEL:
			style.field = Color(0.055, 0.048, 0.04, 0.94)
			style.rivets = true
			style.shadow = 18.0
			style.cut = 12.0
		Plaque.HUD:
			style.cut = 9.0
			style.content_margin_left = 18.0
			style.content_margin_right = 18.0
			style.content_margin_top = 12.0
			style.content_margin_bottom = 12.0
		Plaque.CHIP:
			style.cut = 7.0
			style.rim = Color(BRASS, 0.85)
			style.inner_rule = false
			style.content_margin_left = 20.0
			style.content_margin_right = 20.0
			style.content_margin_top = 7.0
			style.content_margin_bottom = 7.0
		Plaque.LABEL:
			style.field = Color(0.05, 0.043, 0.036, 0.9)
			style.rivets = true
			style.cut = 11.0
			style.shadow = 10.0
			style.content_margin_left = 44.0
			style.content_margin_right = 44.0
			style.content_margin_top = 16.0
			style.content_margin_bottom = 18.0
		Plaque.KEYCAP:
			style.field = Color(BRASS.lightened(0.08), 1.0)
			style.rim = Color(0.36, 0.25, 0.11)
			style.groove = Color(1.0, 0.93, 0.75, 0.55)
			style.inner_rule = false
			style.sheen = 0.12
			style.cut = 4.0
			style.rim_width = 1.5
			style.content_margin_left = 11.0
			style.content_margin_right = 11.0
			style.content_margin_top = 1.0
			style.content_margin_bottom = 1.0
		Plaque.ROW:
			style.field = Color(ACCENT, 0.13)
			style.rim = Color(0.0, 0.0, 0.0, 0.0)
			style.outline = Color(0.0, 0.0, 0.0, 0.0)
			style.cut = 6.0
			style.sheen = 0.0
			style.band = ACCENT
			style.band_width = 4.0
			style.content_margin_left = 22.0
			style.content_margin_right = 22.0
			style.content_margin_top = 8.0
			style.content_margin_bottom = 8.0
	return style


## A brass rule [param width] long with a lozenge in its middle (the
## ornament between a title and its subtitle).
static func ornament(width: float, lozenge: bool = true) -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(width, 10.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.draw.connect(_draw_ornament.bind(line, lozenge))
	return line


static func _draw_ornament(line: Control, lozenge: bool) -> void:
	var mid := line.size * 0.5
	var gap := 9.0 if lozenge else 0.0
	line.draw_line(Vector2(0.0, mid.y), mid - Vector2(gap, 0.0), Color(ACCENT, 0.55), 1.5)
	line.draw_line(mid + Vector2(gap, 0.0), Vector2(line.size.x, mid.y), Color(ACCENT, 0.55), 1.5)
	if lozenge:
		line.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4.5), mid + Vector2(5, 0), mid + Vector2(0, 4.5), mid + Vector2(-5, 0)]), ACCENT)


## WCAG contrast ratio of [param fore] over [param back] (both opaque; the
## relative luminance of the linearised colours).
static func contrast(fore: Color, back: Color) -> float:
	var a := Color(fore, 1.0).srgb_to_linear().get_luminance()
	var b := Color(back, 1.0).srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## [param top] laid over [param bottom] (alpha blending), opaque.
static func over(top: Color, bottom: Color) -> Color:
	return Color(Color(bottom, 1.0).lerp(Color(top, 1.0), top.a), 1.0)


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
	# buttons: plain text; focused, a brass wash with a brass band on the left
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 22.0
	normal.content_margin_right = 22.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var focus := plaque(Plaque.ROW)
	var pressed := plaque(Plaque.ROW)
	pressed.field = Color(ACCENT, 0.22)
	var disabled := normal.duplicate() as StyleBoxEmpty
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
	# sliders: a sunken channel in brass, the filled part brass, a brass knob
	var track := plaque(Plaque.CHIP)
	track.field = CHANNEL
	track.rim = Color(BRASS, 0.5)
	track.rim_width = 1.0
	track.groove = Color(0.0, 0.0, 0.0, 0.0)
	track.cut = 2.0
	track.sheen = 0.0
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	track.content_margin_left = 0.0
	track.content_margin_right = 0.0
	var filled := track.duplicate() as PlaqueStyle
	filled.field = Color(ACCENT, 0.9)
	filled.sheen = 0.08
	built.set_stylebox("slider", "HSlider", track)
	built.set_stylebox("grabber_area", "HSlider", filled)
	built.set_stylebox("grabber_area_highlight", "HSlider", filled)
	built.set_icon("grabber", "HSlider", _dot(24, TEXT))
	built.set_icon("grabber_highlight", "HSlider", _dot(24, ACCENT))
	built.set_icon("grabber_disabled", "HSlider", _dot(24, DISABLED))
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


## A round grabber: a knob in [param color] (a rivet's head), ringed dark.
static func _dot(diameter: int, color: Color) -> Texture2D:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter * 0.5
	var light := Vector2(-0.35, -0.4).normalized()
	for y in diameter:
		for x in diameter:
			var at := Vector2(x + 0.5 - radius, y + 0.5 - radius)
			var d := at.length()
			var alpha := clampf(radius - 0.5 - d, 0.0, 1.0)
			var body := clampf(radius - 3.5 - d, 0.0, 1.0)
			var shine := clampf(at.normalized().dot(light), 0.0, 1.0) * (d / radius) if d > 0.0 else 0.0
			var tone := color.lerp(Color(1.0, 0.98, 0.9), shine * 0.45).lerp(color.darkened(0.35), clampf(d / radius - 0.55, 0.0, 1.0) * 0.6)
			image.set_pixel(x, y, Color(tone.lerp(Color(0.08, 0.06, 0.04), 1.0 - body), alpha))
	return ImageTexture.create_from_image(image)
