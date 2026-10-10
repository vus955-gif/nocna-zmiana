class_name MapFonts
extends RefCounted
## The paper map's type (system fonts, nothing bundled): a DIN-like sans
## for the print (Bahnschrift), its semibold, a book serif for the museum's
## name (Georgia) and the guard's hand (Segoe Print / Ink Free). Measuring,
## word wrapping and letter-spaced lines, shared by every MapCanvas, so the
## screen and the previews lay text out alike.

const PRINT := &"print"
const BOLD := &"bold"
const TITLE := &"title"
const HAND := &"hand"

const FAMILIES := {
	PRINT: ["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"],
	BOLD: ["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"],
	TITLE: ["Georgia", "Constantia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"],
	HAND: ["Segoe Print", "Ink Free", "Bradley Hand", "Comic Sans MS", "Georgia", "serif"],
}
const BOLD_WEIGHT := 600

static var _fonts: Dictionary = {}


static func font(id: StringName) -> Font:
	if not _fonts.has(id):
		var system := SystemFont.new()
		system.font_names = PackedStringArray(FAMILIES.get(id, FAMILIES[PRINT]))
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		system.hinting = TextServer.HINTING_LIGHT
		system.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		system.font_weight = BOLD_WEIGHT if id == BOLD else 400
		var result: Font = system
		if id == BOLD:
			# a variable Bahnschrift needs its weight axis set (see UiTheme)
			var variation := FontVariation.new()
			variation.base_font = system
			variation.variation_opentype = {"wght": BOLD_WEIGHT}
			result = variation
		_fonts[id] = result
	return _fonts[id]


## The family the previews ask cairo for (the first name).
static func family(id: StringName) -> String:
	return String((FAMILIES.get(id, FAMILIES[PRINT]) as Array)[0])


static func is_bold(id: StringName) -> bool:
	return id == BOLD


static func width(id: StringName, words: String, size: int) -> float:
	return font(id).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


static func ascent(id: StringName, size: int) -> float:
	return font(id).get_ascent(size)


## Width of [param words] spaced [param spacing] px between letters.
static func spaced_width(id: StringName, words: String, size: int, spacing: float) -> float:
	var total := 0.0
	for i in words.length():
		total += width(id, words[i], size)
	return total + spacing * maxf(words.length() - 1, 0)


## Words of [param words] in lines no wider than [param max_width] (a word
## longer than that gets a line of its own).
static func wrap(id: StringName, words: String, size: int, max_width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var line := ""
	for word in words.split(" ", false):
		var tried := word if line == "" else line + " " + word
		if line != "" and width(id, tried, size) > max_width:
			lines.append(line)
			line = word
		else:
			line = tried
	if line != "":
		lines.append(line)
	return lines


## Text centred on [param center] (its middle line there), turned by
## [param angle].
static func centered(canvas: MapCanvas, center: Vector2, words: String, id: StringName, size: int, color: Color, angle: float = 0.0) -> void:
	var along := Vector2(cos(angle), sin(angle))
	var down := Vector2(-sin(angle), cos(angle))
	var start := center - along * width(id, words, size) * 0.5 + down * size * 0.36
	canvas.text(start, words, id, size, color, angle)


## Letter-spaced text (capitals in signs and titles), letter by letter,
## its baseline starting at [param at] (or centred on [param at] with
## [param centre]).
static func spaced(canvas: MapCanvas, at: Vector2, words: String, id: StringName, size: int, color: Color, spacing: float, angle: float = 0.0, centre: bool = false) -> void:
	var along := Vector2(cos(angle), sin(angle))
	var down := Vector2(-sin(angle), cos(angle))
	canvas.label(words)
	var pen := at
	if centre:
		pen = at - along * spaced_width(id, words, size, spacing) * 0.5 + down * size * 0.36
	for i in words.length():
		var letter := words[i]
		if letter != " ":
			canvas.text(pen, letter, id, size, color, angle)
		pen += along * (width(id, letter, size) + spacing)
