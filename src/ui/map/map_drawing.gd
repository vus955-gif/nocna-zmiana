class_name MapDrawing
extends RefCounted
## Draws the printed visitor leaflet of the museum (design 9.1) on a
## MapCanvas, in sheet pixels, one layer at a time:
## - paper(): the bare sheet (texture), wear(): the folds, rubbed ink,
##   yellowed edges and the coffee ring over the print (texture),
## - print_page(): the building's grey mass, the public rooms in their
##   wings' colours with thin darker edges, the doorways between them, the
##   stairs, the balconies dashed, the Reading Room round, the pictograms
##   (information, cafe, shop, cloakroom, tickets, the entrance), the
##   compass and scale bar, the title block, the key (legend) with its notes
##   box; the basement and roof pages print only the building's ghost and
##   their staff-only notice,
## - wing_names(): each wing's name in big spaced capitals (fades out as
##   the guard zooms in), room_names(): the rooms' names (fade in),
## - here(): the red "you are here" arrow.
## The guard's pencil goes on top (MapPencil). Everything depends only on
## the model, the projection and the language, so a layer is drawn once and
## kept by the renderer.

const TEX_PAPER := &"paper"
const TEX_WEAR := &"wear"
const PAPER_PATH := "res://assets/ui/map/leaflet_paper.jpg"
const WEAR_PATH := "res://assets/ui/map/leaflet_wear.png"
const GRAIN_PATH := "res://assets/ui/map/graphite_grain.png"

## Metres the building's mass reaches past each zone (fills the 1 m walls
## between zones).
const MASS_GROW := 0.6
## Metres a printed doorway reaches into the rooms on both sides (cuts
## their edges).
const DOOR_REACH := 0.35
## Metres between the printed treads of a flight (every second tread).
const TREAD := 0.8
## Pictogram square (px).
const PICTO := 22.0
## Letter spacing of the wings' big names (px).
const WING_SPACING := 6.0
## The compass and the scale bar stand in the empty south-east corner.
const COMPASS_AT := Vector2(46.0, 40.5)
const SCALE_AT := Vector2(39.0, 50.0)
const SCALE_METRES := 20

## The key's layout (sheet px): its rows' baselines and the notes box.
const KEY_X := 1858.0
const KEY_TEXT_X := 1916.0
const KEY_RIGHT := 2330.0
const KEY_HEADING_Y := 290.0
const KEY_WINGS_Y := 344.0
const KEY_STEP := 38.0
const KEY_FACILITIES_Y := 724.0
const KEY_NOTICE_Y := 1104.0
const NOTES_CAPTION_Y := 1186.0
const NOTES_FIRST_Y := 1232.0
const NOTES_STEP := 44.0
const NOTES_LAST_Y := 1608.0
## Facilities in the key: pictogram -> its name.
const FACILITIES := [
	[&"info", &"MAP_PICTO_INFO"], [&"cafe", &"MAP_PICTO_CAFE"], [&"shop", &"MAP_PICTO_SHOP"],
	[&"cloakroom", &"MAP_PICTO_CLOAKROOM"], [&"tickets", &"MAP_PICTO_TICKETS"],
	[&"stairs", &"MAP_PICTO_STAIRS"], [&"entrance", &"MAP_PICTO_ENTRANCE"],
]
## Rooms whose names are not written (stairwells show their stairs).
const UNNAMED := [&"ROOM_SERVICE_STAIRS"]

const TAB_PAGE_KEYS := {
	MapModel.GROUND: &"MAP_PAGE_GROUND", MapModel.BASEMENT: &"MAP_PAGE_BASEMENT", MapModel.ROOF: &"MAP_PAGE_ROOF",
}
const TAB_NOTICE_KEYS := {MapModel.BASEMENT: &"MAP_NOTICE_BASEMENT", MapModel.ROOF: &"MAP_NOTICE_ROOF"}
## The floor tabs on screen (canvas px) and the hint band under the sheet.
const TAB_SIZE := Vector2(236.0, 46.0)
const TAB_GAP := 12.0
const TAB_TOP := 16.0
const HINT_BAND := 46.0


## The textures a MapCanvasItem needs (id -> Texture2D).
static func textures() -> Dictionary:
	return {TEX_PAPER: load(PAPER_PATH), TEX_WEAR: load(WEAR_PATH)}


# --- layers -----------------------------------------------------------------------

static func paper(canvas: MapCanvas) -> void:
	canvas.set_layer(&"paper")
	canvas.texture(Rect2(Vector2.ZERO, MapStyle.SHEET), TEX_PAPER)


static func wear(canvas: MapCanvas) -> void:
	canvas.set_layer(&"wear")
	canvas.texture(Rect2(Vector2.ZERO, MapStyle.SHEET), TEX_WEAR)


## The printed page of [param tab].
static func print_page(canvas: MapCanvas, model: MapModel, projection: MapProjection, tab: StringName) -> void:
	canvas.set_layer(&"print")
	_building(canvas, projection, tab)
	if tab == MapModel.GROUND:
		_rooms(canvas, model, projection)
		_doors(canvas, model, projection)
		_flights(canvas, model, projection)
		_pictos(canvas, model, projection)
	else:
		_notice(canvas, tab)
	_compass(canvas, projection)
	_header(canvas, tab)
	_key(canvas)


## The wings' names (ground floor).
static func wing_names(canvas: MapCanvas, model: MapModel, projection: MapProjection, tab: StringName) -> void:
	canvas.set_layer(&"wings")
	if tab != MapModel.GROUND:
		return
	# where the names go depends only on the print and the language: kept on
	# the layout once worked out
	var cache := StringName("map_wings_%s" % TranslationServer.get_locale().validate_node_name().replace("-", "_").replace(".", "_"))
	var spots: Dictionary = model.layout.get_meta(cache, {})
	var obstacles: Array[Rect2] = []
	if spots.is_empty():
		obstacles = label_obstacles(model, projection, tab)
	for wing in model.wings:
		var words := tr_key(Floor1Plan.zone_name_key(wing.zone)).to_upper()
		var angle := -PI * 0.5 if wing.rotated else 0.0
		var ink := MapStyle.wing_ink(wing.zone)
		ink.a = 0.82
		if not spots.has(wing.zone):
			spots[wing.zone] = wing_spot(model, projection, wing, words, obstacles)
		var at: Vector2 = spots[wing.zone]
		MapFonts.spaced(canvas, at, words, MapFonts.BOLD, MapStyle.WING_SIZE, ink, WING_SPACING, angle, true)
	model.layout.set_meta(cache, spots)


## What a wing's big name should not cover: the rooms' names and the
## pictograms on [param tab] (sheet px).
static func label_obstacles(model: MapModel, projection: MapProjection, tab: StringName) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for room in model.rooms_on(tab, MapModel.Look.PRINTED):
		var block := name_block(room, projection)
		if not block.is_empty():
			found.append((block["rect"] as Rect2).grow(4.0))
	for picto in model.pictos:
		if picto.tab == tab:
			found.append(Rect2(projection.to_sheet(picto.at) - Vector2(PICTO, PICTO) * 0.6, Vector2(PICTO, PICTO) * 1.2))
	return found


## Where a wing's name goes (sheet px, its middle): over the wing's printed
## rooms, as clear of the rooms' names and the pictograms as it can be,
## near the middle of the wing.
static func wing_spot(model: MapModel, projection: MapProjection, wing: MapModel.Wing, words: String, obstacles: Array[Rect2]) -> Vector2:
	var length := MapFonts.spaced_width(MapFonts.BOLD, words, MapStyle.WING_SIZE, WING_SPACING)
	var thick := MapStyle.WING_SIZE * 0.78
	var size := Vector2(thick, length) if wing.rotated else Vector2(length, thick)
	var rooms: Array[MapModel.Room] = []
	var box := Rect2()
	for room in model.rooms_on(MapModel.GROUND, MapModel.Look.PRINTED):
		if room.zone == wing.zone and not room.upper:
			box = projection.rect_to_sheet(room.bounds()) if rooms.is_empty() else box.merge(projection.rect_to_sheet(room.bounds()))
			rooms.append(room)
	var home := projection.to_sheet(wing.at)
	if rooms.is_empty():
		return home
	var best := home
	var best_score := -INF
	const GRID := 13
	for i in GRID:
		for j in GRID:
			var center := box.position + box.size * Vector2((i + 0.5) / GRID, (j + 0.5) / GRID)
			var rect := Rect2(center - size * 0.5, size)
			var inside := 0
			for sample: Vector2 in [center, rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
				for room in rooms:
					if room.covers(projection.to_world(sample)):
						inside += 1
						break
			if inside == 0:
				continue
			var covered := 0.0
			for obstacle in obstacles:
				covered += rect.intersection(obstacle).get_area()
			var score := inside * 400.0 - covered - center.distance_to(home) * 1.2
			if score > best_score:
				best_score = score
				best = center
	return best


## The rooms' names: printed in the print's sans, pencilled ones in the
## guard's hand.
static func room_names(canvas: MapCanvas, model: MapModel, projection: MapProjection, tab: StringName) -> void:
	canvas.set_layer(&"names")
	for room in model.rooms_on(tab):
		if room.look == MapModel.Look.HIDDEN:
			continue
		var block := name_block(room, projection)
		if block.is_empty():
			continue
		var lines: PackedStringArray = block["lines"]
		var font: StringName = block["font"]
		var size: int = block["size"]
		var angle: float = block["angle"]
		var color: Color = block["color"]
		var center: Vector2 = block["center"]
		var along := Vector2(cos(angle), sin(angle))
		var down := Vector2(-sin(angle), cos(angle))
		var pitch: float = block["pitch"]
		for i in lines.size():
			var middle := center + down * (i - (lines.size() - 1) * 0.5) * pitch
			var start := middle - along * MapFonts.width(font, lines[i], size) * 0.5 + down * size * 0.36
			canvas.text(start, lines[i], font, size, color, angle)


## How a room's name is laid out: {lines, font, size, angle, color, center,
## pitch, rect (sheet px, unturned)}; {} when the room has no name to show
## (no name, a stairwell, the court named by its wing, too small).
static func name_block(room: MapModel.Room, projection: MapProjection) -> Dictionary:
	if room.name_key == &"" or UNNAMED.has(room.name_key):
		return {}
	var words := tr_key(room.name_key)
	if words == tr_key(Floor1Plan.zone_name_key(room.zone)) and MapStyle.NAMED_ZONES.has(room.zone):
		return {}
	var pencil := room.look == MapModel.Look.PENCIL
	var font := MapFonts.HAND if pencil else MapFonts.PRINT
	var size := MapStyle.ROOM_SIZE
	var main := room.parts[0]
	for part in room.parts:
		if part.get_area() > main.get_area():
			main = part
	var box := projection.rect_to_sheet(main)
	if room.round:
		box = projection.rect_to_sheet(room.bounds()).grow(-projection.length(room.radius()) * 0.25)
	var fit := _fit_name(font, words, box, size)
	if fit.is_empty():
		return {}
	var lines: PackedStringArray = fit["lines"]
	size = fit["size"]
	var tall: bool = fit["tall"]
	var angle := -PI * 0.5 if tall else 0.0
	if pencil:
		angle += (_jitter(String(room.id)) - 0.5) * 0.06
	var color := MapStyle.PENCIL if pencil else Color(MapStyle.INK, 0.92)
	if room.upper and not pencil:
		color = Color(MapStyle.INK_SOFT, 0.95)
	var pitch := size * (1.3 if pencil else 1.12)
	var longest := 0.0
	for line in lines:
		longest = maxf(longest, MapFonts.width(font, line, size))
	var center := projection.to_sheet(room.anchor)
	var extent := Vector2(longest, pitch * lines.size())
	if tall:
		extent = Vector2(extent.y, extent.x)
	return {
		"lines": lines, "font": font, "size": size, "angle": angle, "color": color,
		"center": center, "pitch": pitch, "rect": Rect2(center - extent * 0.5, extent),
	}


## The first layout of a name that fits [param box] (sheet px): across at
## full size, across a little smaller, then (in a room taller than wide)
## up the page; {lines, size, tall}, {} when none fits.
static func _fit_name(font: StringName, words: String, box: Rect2, base_size: int) -> Dictionary:
	var tries := [[false, base_size], [false, base_size - 2]]
	if box.size.y > box.size.x * 1.4:
		tries.append_array([[true, base_size], [true, base_size - 2]])
	for attempt: Array in tries:
		var tall: bool = attempt[0]
		var size: int = attempt[1]
		var width := (box.size.y if tall else box.size.x) - 10.0
		var depth := (box.size.x if tall else box.size.y) - 4.0
		if width < 34.0:
			continue
		var lines := MapFonts.wrap(font, words, size, width)
		if lines.size() > 3 or lines.size() * size * 1.12 > depth:
			continue
		var longest := 0.0
		for line in lines:
			longest = maxf(longest, MapFonts.width(font, line, size))
		if longest <= width + 6.0:
			return {"lines": lines, "size": size, "tall": tall}
	return {}


## The red "you are here" arrow at [param at] (sheet px) facing
## [param facing] (floor-plan direction), with its label.
static func here(canvas: MapCanvas, at: Vector2, facing: Vector2, label: bool = true) -> void:
	canvas.set_layer(&"here")
	var forward := facing.normalized() if facing.length() > 0.001 else Vector2.UP
	var side := Vector2(-forward.y, forward.x)
	canvas.polyline(_circle_points(at, 21.0, 40), Color(MapStyle.RED, 0.32), 3.0, true)
	var tip := at + forward * 18.0
	var left := at - forward * 11.0 + side * 11.0
	var right := at - forward * 11.0 - side * 11.0
	var notch := at - forward * 4.0
	var arrow := PackedVector2Array([tip, left, notch, right])
	canvas.polyline(arrow, Color(MapStyle.PAPER, 0.95), 4.5, true)
	canvas.polygon(arrow, MapStyle.RED)
	canvas.circle(at, 2.4, MapStyle.PAPER)
	if not label:
		return
	var words := tr_key(&"MAP_YOU_ARE_HERE")
	var size := 17
	var width := MapFonts.width(MapFonts.BOLD, words, size)
	var place := at + Vector2(26.0, -10.0)
	if place.x + width + 12.0 > MapStyle.MAP_AREA.end.x:
		place = at + Vector2(-26.0 - width, -10.0)   # by the key: the label goes left
	canvas.rect(Rect2(place + Vector2(-5.0, -size * 0.95), Vector2(width + 10.0, size * 1.3)), Color(MapStyle.PAPER, 0.8))
	canvas.text(place, words, MapFonts.BOLD, size, MapStyle.RED)


## The sheet's soft shadow on the desk (outside the sheet).
static func shadow(canvas: MapCanvas) -> void:
	canvas.set_layer(&"shadow")
	var sheet := Rect2(Vector2.ZERO, MapStyle.SHEET)
	for i in 6:
		var grow := 4.0 + i * 5.0
		canvas.rect(Rect2(sheet.position + Vector2(10.0, 14.0), sheet.size).grow(grow), Color(0.0, 0.0, 0.0, 0.07))


# --- the screen around the sheet ------------------------------------------------------

## The floor tabs at the top of the screen (canvas px), in TABS order.
static func tab_rects(screen: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var count := MapModel.TABS.size()
	var total := TAB_SIZE.x * count + TAB_GAP * (count - 1)
	var x := (screen.x - total) * 0.5
	for i in count:
		rects.append(Rect2(Vector2(x + (TAB_SIZE.x + TAB_GAP) * i, TAB_TOP), TAB_SIZE))
	return rects


## The tabs (paper index tabs: the open one bright with a brass edge, a red
## dot on the guard's floor, a pencil tick where he has drawn something),
## the keys that turn them and the hint line at the bottom.
static func chrome(canvas: MapCanvas, screen: Vector2, active: StringName, guard_tab: StringName, pencilled: Array[StringName], hint: String) -> void:
	canvas.set_layer(&"chrome")
	var rects := tab_rects(screen)
	for i in MapModel.TABS.size():
		var tab := MapModel.TABS[i]
		var rect := rects[i]
		var open := tab == active
		canvas.rect(Rect2(rect.position + Vector2(3.0, 5.0), rect.size), Color(0.0, 0.0, 0.0, 0.35))
		var shape := PackedVector2Array([rect.position + Vector2(10.0, 0.0), Vector2(rect.end.x - 10.0, rect.position.y), Vector2(rect.end.x, rect.position.y + 10.0),
			rect.end, Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0.0, 10.0)])
		canvas.polygon(shape, MapStyle.PAPER if open else Color(0.6, 0.58, 0.53, 0.94))
		if open:
			canvas.rect(Rect2(Vector2(rect.position.x, rect.end.y - 4.0), Vector2(rect.size.x, 4.0)), UiTheme.ACCENT)
		var words := tr_key(MapModel.TAB_KEYS[tab]).to_upper()
		var room := rect.size.x - 76.0
		var spacing := 3.0 if MapFonts.spaced_width(MapFonts.BOLD, words, 19, 3.0) <= room else 1.0
		MapFonts.spaced(canvas, rect.get_center() + Vector2(4.0, -1.0), words, MapFonts.BOLD, 19, MapStyle.INK if open else Color(MapStyle.INK, 0.72), spacing, 0.0, true)
		if tab == guard_tab:
			canvas.circle(Vector2(rect.end.x - 18.0, rect.position.y + 15.0), 5.0, MapStyle.RED)
		if pencilled.has(tab):
			MapPencil.tick(canvas, Vector2(rect.position.x + 17.0, rect.get_center().y + 1.0), MapPencil.rng_for("tab/" + String(tab)))
			canvas.set_layer(&"chrome")
	var first := rects[0]
	var last := rects[rects.size() - 1]
	_key_cap(canvas, Vector2(first.position.x - 34.0, first.get_center().y), "Q")
	_key_cap(canvas, Vector2(last.end.x + 34.0, last.get_center().y), "E")
	canvas.rect(Rect2(0.0, screen.y - HINT_BAND, screen.x, HINT_BAND), Color(0.02, 0.02, 0.025, 0.82))
	canvas.rect(Rect2(0.0, screen.y - HINT_BAND, screen.x, 1.0), Color(UiTheme.ACCENT, 0.35))
	MapFonts.centered(canvas, Vector2(screen.x * 0.5, screen.y - HINT_BAND * 0.5), hint, MapFonts.PRINT, 19, Color(UiTheme.TEXT, 0.82))


static func _key_cap(canvas: MapCanvas, center: Vector2, key: String) -> void:
	var box := Rect2(center - Vector2(15.0, 15.0), Vector2(30.0, 30.0))
	canvas.rect(box, Color(0.0, 0.0, 0.0, 0.45))
	canvas.polyline(_rect_points(box), Color(UiTheme.ACCENT, 0.7), 1.5, true)
	MapFonts.centered(canvas, center, key, MapFonts.BOLD, 17, UiTheme.TEXT)


# --- the print ----------------------------------------------------------------------

## The building's floor-plan rectangles (world x, z) on the ground floor,
## grown to fill the walls between zones.
static func building_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for zone in Floor1Plan.ZONES:
		if Floor1Plan.MAP_TABS.has(zone):
			continue
		for box in Floor1Plan.zone_boxes(zone):
			if box.position.y <= 0.5 and box.end.y >= 0.5:
				found.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(MASS_GROW))
	return found


static func _building(canvas: MapCanvas, projection: MapProjection, tab: StringName) -> void:
	var rects := building_rects()
	var outline := MapModel.outline(rects)
	if tab == MapModel.GROUND:
		var mass := MapStyle.MASS
		mass.a = MapStyle.PRINT_ALPHA
		for rect in rects:
			canvas.rect(projection.rect_to_sheet(rect), mass)
		canvas.lines(_project_pairs(outline, projection), Color(MapStyle.INK_SOFT, 0.85), 2.4)
	else:
		for segment in outline:
			dashed(canvas, projection.to_sheet(segment[0]), projection.to_sheet(segment[1]), MapStyle.GHOST, 1.6, 7.0, 6.0)


static func _rooms(canvas: MapCanvas, model: MapModel, projection: MapProjection) -> void:
	var printed := model.rooms_on(MapModel.GROUND, MapModel.Look.PRINTED)
	printed.sort_custom(func(a: MapModel.Room, b: MapModel.Room) -> bool: return a.area > b.area)
	for room in printed:
		if room.upper:
			continue
		var fill := MapStyle.fill(room.zone)
		fill.a = MapStyle.PRINT_ALPHA
		var edge := Color(MapStyle.edge(room.zone), 0.85)
		if room.round:
			var ring := _circle_points(projection.to_sheet(room.bounds().get_center()), projection.length(room.radius()), 64)
			canvas.polygon(ring, fill)
			canvas.polyline(ring, edge, 1.5, true)
			continue
		for part in room.parts:
			canvas.rect(projection.rect_to_sheet(part), fill)
		canvas.lines(_project_pairs(room.outline, projection), edge, 1.4)
	# balconies and galleries over other rooms: dashed
	for room in printed:
		if not room.upper:
			continue
		var edge := Color(MapStyle.edge(room.zone), 0.9)
		for segment in room.outline:
			dashed(canvas, projection.to_sheet(segment[0]), projection.to_sheet(segment[1]), edge, 1.3, 5.0, 4.0)


static func _doors(canvas: MapCanvas, model: MapModel, projection: MapProjection) -> void:
	for door in model.doors:
		if door.tab != MapModel.GROUND or door.look != MapModel.Look.PRINTED:
			continue
		var a := model.room(door.room_a)
		var b := model.room(door.room_b)
		if a.upper != b.upper:
			continue   # a stair landing: the flight shows the way
		var rect := door.rect
		if rect.size.x < rect.size.y:
			rect = rect.grow_individual(DOOR_REACH, 0.0, DOOR_REACH, 0.0)
		else:
			rect = rect.grow_individual(0.0, DOOR_REACH, 0.0, DOOR_REACH)
		var fill := MapStyle.fill(a.zone).lerp(MapStyle.fill(b.zone), 0.5)
		fill.a = 1.0
		canvas.rect(projection.rect_to_sheet(rect), fill)


static func _flights(canvas: MapCanvas, model: MapModel, projection: MapProjection) -> void:
	for flight in model.flights:
		if flight.look == MapModel.Look.PRINTED and flight.tabs.has(MapModel.GROUND):
			stairs(canvas, projection.rect_to_sheet(flight.rect), flight.ascend, projection.length(TREAD), Color(MapStyle.INK_SOFT, 0.6), 1.0)


## A flight of stairs in [param rect] (sheet px): stringers along the
## climb, a tread every [param pitch] px across it, a chevron at the top.
static func stairs(canvas: MapCanvas, rect: Rect2, ascend: Vector2, pitch: float, color: Color, width: float) -> void:
	var along_x := absf(ascend.x) > absf(ascend.y)
	var pairs := PackedVector2Array()
	if along_x:
		pairs.append_array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end])
		var x := rect.position.x
		while x <= rect.end.x + 0.01:
			pairs.append_array([Vector2(x, rect.position.y), Vector2(x, rect.end.y)])
			x += pitch
	else:
		pairs.append_array([rect.position, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y), rect.end])
		var y := rect.position.y
		while y <= rect.end.y + 0.01:
			pairs.append_array([Vector2(rect.position.x, y), Vector2(rect.end.x, y)])
			y += pitch
	canvas.lines(pairs, color, width)
	var up := ascend.normalized()
	var side := Vector2(-up.y, up.x)
	var reach := (rect.size.x if along_x else rect.size.y) * 0.5
	var head := rect.get_center() + up * (reach - pitch * 0.6)
	var arm := minf(rect.size.y if along_x else rect.size.x, 16.0) * 0.32
	canvas.polyline(PackedVector2Array([head - up * arm + side * arm, head, head - up * arm - side * arm]), color, width * 1.4)


static func _pictos(canvas: MapCanvas, model: MapModel, projection: MapProjection) -> void:
	for picto in model.pictos:
		if picto.tab != MapModel.GROUND:
			continue
		var at := projection.to_sheet(picto.at)
		if picto.kind == &"entrance":
			_entrance(canvas, at)
		else:
			pictogram(canvas, picto.kind, at)


## The main doors: an arrow in from the street and the word under it.
static func _entrance(canvas: MapCanvas, door: Vector2) -> void:
	var tail := door + Vector2(0.0, 30.0)
	var tip := door + Vector2(0.0, 4.0)
	canvas.polyline(PackedVector2Array([tail, tip]), MapStyle.INK, 3.0)
	canvas.polygon(PackedVector2Array([tip + Vector2(0, -6), tip + Vector2(-8, 6), tip + Vector2(8, 6)]), MapStyle.INK)
	MapFonts.spaced(canvas, door + Vector2(0.0, 44.0), tr_key(&"MAP_PICTO_ENTRANCE").to_upper(), MapFonts.BOLD, 15, MapStyle.INK, 2.5, 0.0, true)


## A facility's pictogram: a pale glyph on a dark square centred on
## [param at] ([param size] px).
static func pictogram(canvas: MapCanvas, kind: StringName, at: Vector2, size: float = PICTO) -> void:
	var half := size * 0.5
	var box := Rect2(at - Vector2(half, half), Vector2(size, size))
	if kind == &"stairs":
		canvas.rect(box, Color(MapStyle.INK_SOFT, 0.12))
		stairs(canvas, box.grow(-3.0), Vector2.UP, size * 0.2, Color(MapStyle.INK_SOFT, 0.75), 1.0)
		return
	if kind == &"entrance":
		canvas.rect(box, Color(MapStyle.INK, 0.9))
		var glyph := Color(MapStyle.PAPER, 0.96)
		canvas.polyline(PackedVector2Array([at + Vector2(0, half * 0.7), at + Vector2(0, -half * 0.35)]), glyph, 2.0)
		canvas.polygon(PackedVector2Array([at + Vector2(0, -half * 0.75), at + Vector2(-half * 0.45, -half * 0.15), at + Vector2(half * 0.45, -half * 0.15)]), glyph)
		return
	canvas.rect(box, Color(MapStyle.INK, 0.9))
	var ink := Color(MapStyle.PAPER, 0.96)
	var s := size / 22.0
	match kind:
		&"info":
			canvas.circle(at + Vector2(0, -6.5) * s, 1.9 * s, ink)
			canvas.rect(Rect2(at + Vector2(-1.6, -2.5) * s, Vector2(3.2, 10.0) * s), ink)
			canvas.rect(Rect2(at + Vector2(-3.5, 6.0) * s, Vector2(7.0, 1.6) * s), ink)
		&"cafe":
			canvas.polyline(_offset(at, s, [Vector2(-6, -3), Vector2(-5, 5), Vector2(3, 5), Vector2(4, -3), Vector2(-6, -3)]), ink, 1.6 * s)
			canvas.polyline(_offset(at, s, [Vector2(4, -1), Vector2(7, -1), Vector2(7, 2), Vector2(3.6, 3)]), ink, 1.4 * s)
			canvas.polyline(_offset(at, s, [Vector2(-8, 7.5), Vector2(6, 7.5)]), ink, 1.4 * s)
			canvas.polyline(_offset(at, s, [Vector2(-3, -6), Vector2(-2, -8)]), ink, 1.0 * s)
			canvas.polyline(_offset(at, s, [Vector2(0, -6), Vector2(1, -8)]), ink, 1.0 * s)
		&"shop":
			canvas.polyline(_offset(at, s, [Vector2(-6, -2), Vector2(6, -2), Vector2(7, 8), Vector2(-7, 8), Vector2(-6, -2)]), ink, 1.6 * s)
			var handle := PackedVector2Array()
			for i in 9:
				var t := PI + PI * i / 8.0
				handle.append(at + Vector2(cos(t) * 3.4, -2.0 + sin(t) * 4.2) * s)
			canvas.polyline(handle, ink, 1.4 * s)
		&"cloakroom":
			canvas.polyline(_offset(at, s, [Vector2(0, -3), Vector2(-8, 5), Vector2(8, 5), Vector2(0, -3)]), ink, 1.5 * s)
			var hook := PackedVector2Array()
			for i in 8:
				var t := -PI * 0.5 - PI * 1.3 * i / 7.0
				hook.append(at + Vector2(cos(t) * 2.4, -5.4 - sin(t) * 2.4) * s)
			canvas.polyline(hook, ink, 1.3 * s)
		&"tickets":
			canvas.polyline(_offset(at, s, [Vector2(-8, -4), Vector2(8, -4), Vector2(8, -1), Vector2(6.5, 0), Vector2(8, 1), Vector2(8, 4), Vector2(-8, 4), Vector2(-8, 1), Vector2(-6.5, 0), Vector2(-8, -1), Vector2(-8, -4)]), ink, 1.5 * s)
			canvas.polyline(_offset(at, s, [Vector2(2, -3), Vector2(2, 3)]), ink, 1.0 * s)


static func _notice(canvas: MapCanvas, tab: StringName) -> void:
	var words := tr_key(TAB_NOTICE_KEYS.get(tab, &"")).to_upper()
	if words == "":
		return
	var size := 26
	var width := MapFonts.spaced_width(MapFonts.BOLD, words, size, 3.0)
	var box := Rect2(Vector2(MapStyle.MAP_AREA.position.x + 30.0, MapStyle.MAP_AREA.position.y + 26.0), Vector2(width + 44.0, 56.0))
	canvas.rect(box, Color(MapStyle.RED, 0.06))
	canvas.polyline(_rect_points(box), Color(MapStyle.RED, 0.9), 2.4, true)
	canvas.polyline(_rect_points(box.grow(-5.0)), Color(MapStyle.RED, 0.6), 1.0, true)
	MapFonts.spaced(canvas, box.position + Vector2(22.0, 37.0), words, MapFonts.BOLD, size, MapStyle.RED, 3.0)


## The compass rose and the scale bar in the south-east corner.
static func _compass(canvas: MapCanvas, projection: MapProjection) -> void:
	var center := projection.to_sheet(COMPASS_AT)
	var ink := MapStyle.INK
	canvas.polyline(_circle_points(center, 30.0, 48), Color(ink, 0.8), 1.4, true)
	canvas.polyline(_circle_points(center, 25.0, 48), Color(ink, 0.5), 0.8, true)
	var north := center + Vector2(0, -26)
	var south := center + Vector2(0, 26)
	canvas.polygon(PackedVector2Array([north, center + Vector2(-7, 0), center]), ink)
	canvas.polygon(PackedVector2Array([north, center, center + Vector2(7, 0)]), Color(ink, 0.25))
	canvas.polygon(PackedVector2Array([south, center + Vector2(7, 0), center]), ink)
	canvas.polygon(PackedVector2Array([south, center, center + Vector2(-7, 0)]), Color(ink, 0.25))
	canvas.lines(PackedVector2Array([center + Vector2(-26, 0), center + Vector2(26, 0)]), Color(ink, 0.6), 1.0)
	MapFonts.centered(canvas, center + Vector2(0, -44), tr_key(&"MAP_NORTH"), MapFonts.BOLD, 20, ink)
	# the scale bar: 0 - 10 - 20 m in 5 m blocks
	var start := projection.to_sheet(SCALE_AT)
	var block := projection.length(5.0)
	for i in SCALE_METRES / 5:
		var piece := Rect2(start + Vector2(block * i, 0.0), Vector2(block, 7.0))
		if i % 2 == 0:
			canvas.rect(piece, Color(ink, 0.85))
		canvas.polyline(_rect_points(piece), Color(ink, 0.85), 1.0, true)
	for metres: int in [0, 10, SCALE_METRES]:
		var x := start.x + projection.length(metres)
		var number := str(metres)
		var words := number if metres < SCALE_METRES else tr_key(&"MAP_SCALE") % metres
		canvas.text(Vector2(x - MapFonts.width(MapFonts.PRINT, number, 14) * 0.5, start.y + 26.0), words, MapFonts.PRINT, 14, Color(ink, 0.85))


static func _header(canvas: MapCanvas, tab: StringName) -> void:
	var ink := MapStyle.INK
	_portico(canvas, Rect2(62.0, 54.0, 116.0, 110.0))
	MapFonts.spaced(canvas, Vector2(206.0, 124.0), tr_key(&"MAP_TITLE").to_upper(), MapFonts.TITLE, MapStyle.TITLE_SIZE, ink, 7.0)
	MapFonts.spaced(canvas, Vector2(209.0, 170.0), tr_key(&"MAP_SUBTITLE").to_upper(), MapFonts.PRINT, 21, MapStyle.INK_SOFT, 2.6)
	var page := tr_key(MapModel.TAB_KEYS.get(tab, &"")).to_upper()
	var right := MapStyle.HEADER_AREA.end.x
	MapFonts.spaced(canvas, Vector2(right - MapFonts.spaced_width(MapFonts.BOLD, page, MapStyle.PAGE_SIZE, 5.0), 122.0), page, MapFonts.BOLD, MapStyle.PAGE_SIZE, ink, 5.0)
	var note := tr_key(TAB_PAGE_KEYS.get(tab, &""))
	var note_ink := MapStyle.RED if tab != MapModel.GROUND else MapStyle.INK_SOFT
	canvas.text(Vector2(right - MapFonts.width(MapFonts.PRINT, note, 22), 166.0), note, MapFonts.PRINT, 22, note_ink)
	canvas.rect(Rect2(50.0, 196.0, 2300.0, 3.0), Color(ink, 0.9))
	canvas.rect(Rect2(50.0, 203.0, 2300.0, 1.0), Color(ink, 0.7))


## The museum's mark: a portico (pediment, columns, steps).
static func _portico(canvas: MapCanvas, box: Rect2) -> void:
	var ink := MapStyle.INK
	var x0 := box.position.x
	var w := box.size.x
	var y0 := box.position.y
	canvas.polygon(PackedVector2Array([Vector2(x0 + w * 0.5, y0), Vector2(x0 + w, y0 + 30.0), Vector2(x0, y0 + 30.0)]), ink)
	canvas.polygon(PackedVector2Array([Vector2(x0 + w * 0.5, y0 + 9.0), Vector2(x0 + w - 18.0, y0 + 25.0), Vector2(x0 + 18.0, y0 + 25.0)]), MapStyle.PAPER)
	canvas.rect(Rect2(x0 + 4.0, y0 + 33.0, w - 8.0, 6.0), ink)
	for i in 5:
		var cx := x0 + 14.0 + (w - 28.0) * i / 4.0
		canvas.rect(Rect2(cx - 5.0, y0 + 43.0, 10.0, 46.0), ink)
	canvas.rect(Rect2(x0 + 2.0, y0 + 92.0, w - 4.0, 6.0), ink)
	canvas.rect(Rect2(x0 - 4.0, y0 + 101.0, w + 8.0, 7.0), ink)


## The key: the wings' colours, the staff areas, balconies, facilities,
## "you are here", the notices and the notes box (the guard writes there).
static func _key(canvas: MapCanvas) -> void:
	var ink := MapStyle.INK
	var area := MapStyle.LEGEND_AREA
	canvas.rect(area, Color(ink, 0.035))
	canvas.polyline(_rect_points(area), Color(MapStyle.INK_SOFT, 0.7), 1.2, true)
	MapFonts.spaced(canvas, Vector2(KEY_X, KEY_HEADING_Y), tr_key(&"MAP_LEGEND").to_upper(), MapFonts.BOLD, MapStyle.LEGEND_TITLE_SIZE, ink, 4.0)
	canvas.rect(Rect2(KEY_X, KEY_HEADING_Y + 13.0, KEY_RIGHT - KEY_X, 1.6), Color(ink, 0.8))
	var y := KEY_WINGS_Y
	for zone in MapStyle.NAMED_ZONES:
		var swatch := Rect2(KEY_X, y - 18.0, 44.0, 24.0)
		canvas.rect(swatch, Color(MapStyle.fill(zone), MapStyle.PRINT_ALPHA))
		canvas.polyline(_rect_points(swatch), Color(MapStyle.edge(zone), 0.9), 1.3, true)
		var label := tr_key(&"MAP_LEGEND_COURT") if zone == &"court" else tr_key(Floor1Plan.zone_name_key(zone))
		canvas.text(Vector2(KEY_TEXT_X + 6.0, y), label, MapFonts.PRINT, MapStyle.LEGEND_SIZE, ink)
		y += KEY_STEP
	var staff := Rect2(KEY_X, y - 18.0, 44.0, 24.0)
	canvas.rect(staff, Color(MapStyle.MASS, MapStyle.PRINT_ALPHA))
	canvas.polyline(_rect_points(staff), Color(MapStyle.INK_SOFT, 0.85), 1.3, true)
	canvas.text(Vector2(KEY_TEXT_X + 6.0, y), tr_key(&"MAP_LEGEND_STAFF"), MapFonts.PRINT, MapStyle.LEGEND_SIZE, ink)
	y += KEY_STEP
	var upper := Rect2(KEY_X + 2.0, y - 16.0, 40.0, 20.0)
	for segment in _rect_segments(upper):
		dashed(canvas, segment[0], segment[1], Color(MapStyle.INK_SOFT, 0.9), 1.3, 5.0, 4.0)
	canvas.text(Vector2(KEY_TEXT_X + 6.0, y), tr_key(&"MAP_UPPER"), MapFonts.PRINT, MapStyle.LEGEND_SIZE, ink)
	# facilities
	y = KEY_FACILITIES_Y
	MapFonts.spaced(canvas, Vector2(KEY_X, y), tr_key(&"MAP_LEGEND_FACILITIES").to_upper(), MapFonts.BOLD, 19, ink, 3.0)
	canvas.rect(Rect2(KEY_X, y + 11.0, KEY_RIGHT - KEY_X, 1.0), Color(ink, 0.6))
	y += 44.0
	for row: Array in FACILITIES:
		pictogram(canvas, row[0], Vector2(KEY_X + 22.0, y - 7.0))
		canvas.text(Vector2(KEY_TEXT_X + 6.0, y), tr_key(row[1]), MapFonts.PRINT, MapStyle.LEGEND_SIZE, ink)
		y += KEY_STEP
	here(canvas, Vector2(KEY_X + 22.0, y - 7.0), Vector2(1.0, -1.0), false)
	canvas.set_layer(&"print")
	canvas.text(Vector2(KEY_TEXT_X + 6.0, y), tr_key(&"MAP_YOU_ARE_HERE"), MapFonts.PRINT, MapStyle.LEGEND_SIZE, MapStyle.RED)
	# the notices
	y = KEY_NOTICE_Y
	canvas.rect(Rect2(KEY_X, y - 30.0, KEY_RIGHT - KEY_X, 1.0), Color(ink, 0.6))
	canvas.text(Vector2(KEY_X, y), tr_key(&"MAP_DO_NOT_TOUCH"), MapFonts.BOLD, 18, ink)
	canvas.text(Vector2(KEY_X, y + 27.0), tr_key(&"MAP_HOURS"), MapFonts.PRINT, 18, MapStyle.INK_SOFT)
	# the notes box, ruled with dotted lines
	MapFonts.spaced(canvas, Vector2(KEY_X, NOTES_CAPTION_Y), tr_key(&"MAP_NOTES").to_upper(), MapFonts.BOLD, 17, MapStyle.INK_SOFT, 3.0)
	for line_y in notes_lines():
		var dots := PackedVector2Array()
		var x := KEY_X
		while x < KEY_RIGHT:
			dots.append_array([Vector2(x, line_y), Vector2(x + 1.6, line_y)])
			x += 6.0
		canvas.lines(dots, Color(MapStyle.INK_SOFT, 0.55), 1.2)
	var edition := tr_key(&"MAP_EDITION")
	canvas.text(Vector2(KEY_RIGHT - MapFonts.width(MapFonts.PRINT, edition, 13), area.end.y - 12.0), edition, MapFonts.PRINT, 13, Color(MapStyle.INK_SOFT, 0.9))


## Baselines of the notes box's dotted lines (sheet px).
static func notes_lines() -> Array[float]:
	var found: Array[float] = []
	var y := NOTES_FIRST_Y
	while y <= NOTES_LAST_Y + 0.01:
		found.append(y)
		y += NOTES_STEP
	return found


# --- helpers ---------------------------------------------------------------------------

## A translation (a missing key stays visible as itself).
static func tr_key(key: StringName) -> String:
	if key == &"":
		return ""
	return String(TranslationServer.translate(key))


## A dashed line from [param a] to [param b].
static func dashed(canvas: MapCanvas, a: Vector2, b: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var dir := (b - a) / length
	var pairs := PackedVector2Array()
	var t := 0.0
	while t < length:
		pairs.append_array([a + dir * t, a + dir * minf(t + dash, length)])
		t += dash + gap
	canvas.lines(pairs, color, width)


static func _project_pairs(segments: Array[PackedVector2Array], projection: MapProjection) -> PackedVector2Array:
	var pairs := PackedVector2Array()
	for segment in segments:
		pairs.append(projection.to_sheet(segment[0]))
		pairs.append(projection.to_sheet(segment[1]))
	return pairs


static func _circle_points(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var t := TAU * i / count
		points.append(center + Vector2(cos(t), sin(t)) * radius)
	return points


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _rect_segments(rect: Rect2) -> Array[PackedVector2Array]:
	var corners := _rect_points(rect)
	var segments: Array[PackedVector2Array] = []
	for i in 4:
		segments.append(PackedVector2Array([corners[i], corners[(i + 1) % 4]]))
	return segments


static func _offset(at: Vector2, scale: float, points: Array) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point: Vector2 in points:
		placed.append(at + point * scale)
	return placed


## A stable 0..1 number for [param key] (the same text, the same number).
static func _jitter(key: String) -> float:
	return float(key.hash() & 0xFFFF) / 65535.0
