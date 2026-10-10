class_name MapPoster
extends Node3D
## The visitors' map on a board on the wall of a haven or the booth (design
## 9.1; WorldFeatures hangs MuseumMap.poster() on every museum_map_*
## marker): the printed leaflet of the ground floor - no pencil - in a dark
## wooden frame, and a round red sticker where the board hangs ("you are
## here", put on by the staff). The marker's origin is the middle of the
## board on the wall, its -Z faces the room.
## The print is drawn once per process (per layout and language) through a
## SubViewport and kept as an ImageTexture; every other board and night
## reuses it. Without a renderer (headless runs) the sheet stays plain.

const SHEET_WIDTH := 1.25
const FRAME := 0.055
const DEPTH := 0.035
const TEXTURE_SIZE := Vector2i(1600, 1133)
const DOT_RADIUS := 0.015
const SHEET_COLOR := Color(0.93, 0.91, 0.85)
const FRAME_COLOR := Color(0.2, 0.13, 0.08)

## Which layout's print this board shows (MuseumMap.poster() sets it).
@export var layout_key: String = ""

var sheet: MeshInstance3D
var frame: MeshInstance3D
## The red sticker (null when the board is not on the ground floor).
var dot: MeshInstance3D = null

## Layout key -> LevelLayout (the print is drawn from it).
static var _layouts: Dictionary = {}
## Layout key -> the print (Texture2D), drawn once.
static var _prints: Dictionary = {}
## Layout key -> boards waiting for its print.
static var _waiting: Dictionary = {}


## A key for [param layout] in the current language: the same rooms (ids,
## shapes, public or not) and words give the same print.
static func key_of(layout: LevelLayout) -> String:
	var signature := PackedStringArray([TranslationServer.get_locale()])
	for room in layout.rooms:
		signature.append("%s|%s|%s|%s" % [room.id, room.public, room.secret, room.parts])
	return "%x" % "\n".join(signature).hash()


static func remember(key: String, layout: LevelLayout) -> void:
	_layouts[key] = layout


## The print for [param key] when it has been drawn (null otherwise).
static func print_of(key: String) -> Texture2D:
	return _prints.get(key)


static func sheet_size() -> Vector2:
	return Vector2(SHEET_WIDTH, SHEET_WIDTH * MapStyle.SHEET.y / MapStyle.SHEET.x)


func _ready() -> void:
	var size := sheet_size()
	frame = MeshInstance3D.new()
	frame.name = "Frame"
	var board := BoxMesh.new()
	board.size = Vector3(size.x + FRAME * 2.0, size.y + FRAME * 2.0, DEPTH)
	frame.mesh = board
	frame.position = Vector3(0.0, 0.0, -DEPTH * 0.5)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = FRAME_COLOR
	wood.roughness = 0.6
	frame.material_override = wood
	add_child(frame)
	sheet = MeshInstance3D.new()
	sheet.name = "Sheet"
	var quad := QuadMesh.new()
	quad.size = size
	sheet.mesh = quad
	# the quad faces +Z; turned round it faces the room (-Z), read the right way
	sheet.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, -DEPTH - 0.002))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = SHEET_COLOR
	paper.roughness = 0.88
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sheet.material_override = paper
	add_child(sheet)
	_stick_dot()
	_ask_for_print()


## Where the board's own place lies on its sheet (local x, y in m), or
## Vector2.INF when it hangs off the ground floor.
func dot_position() -> Vector2:
	var at := global_position
	if MapModel.tab_of_height(at.y - 1.5) != MapModel.GROUND:
		return Vector2.INF
	var uv := MapProjection.floor1().point(at) / MapStyle.SHEET
	var size := sheet_size()
	# seen from the room, the sheet's left edge is the board's +X side
	return Vector2((0.5 - uv.x) * size.x, (0.5 - uv.y) * size.y)


func _stick_dot() -> void:
	var spot := dot_position()
	if spot == Vector2.INF or absf(spot.x) > sheet_size().x * 0.5 or absf(spot.y) > sheet_size().y * 0.5:
		return
	dot = MeshInstance3D.new()
	dot.name = "YouAreHere"
	var disc := CylinderMesh.new()
	disc.top_radius = DOT_RADIUS
	disc.bottom_radius = DOT_RADIUS
	disc.height = 0.002
	disc.radial_segments = 24
	dot.mesh = disc
	dot.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(spot.x, spot.y, -DEPTH - 0.004))
	var red := StandardMaterial3D.new()
	red.albedo_color = MapStyle.RED
	red.roughness = 0.35
	red.emission_enabled = true
	red.emission = MapStyle.RED
	red.emission_energy_multiplier = 0.25
	dot.material_override = red
	add_child(dot)


func _show(picture: Texture2D) -> void:
	var paper := sheet.material_override as StandardMaterial3D
	paper.albedo_color = Color.WHITE
	paper.albedo_texture = picture


func _ask_for_print() -> void:
	var ready_print := print_of(layout_key)
	if ready_print != null:
		_show(ready_print)
		return
	if not _layouts.has(layout_key) or DisplayServer.get_name() == "headless":
		return
	if _waiting.has(layout_key):
		(_waiting[layout_key] as Array).append(self)
		return
	_waiting[layout_key] = [self]
	_draw_print.call_deferred()


## Draws the print once in a SubViewport, then keeps a copy of it.
func _draw_print() -> void:
	var key := layout_key
	var layout: LevelLayout = _layouts[key]
	var model := MapModel.build(layout, MapState.new())
	var projection := MapProjection.floor1()
	var port := SubViewport.new()
	port.name = "Print"
	port.size = TEXTURE_SIZE
	port.disable_3d = true
	port.transparent_bg = false
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	var page := Control.new()
	page.size = MapStyle.SHEET
	page.scale = Vector2.ONE * (float(TEXTURE_SIZE.x) / MapStyle.SHEET.x)
	port.add_child(page)
	var textures := MapDrawing.textures()
	page.add_child(MapSheetLayer.make("Paper", func(canvas: MapCanvas) -> void: MapDrawing.paper(canvas), MapStyle.SHEET, textures))
	page.add_child(MapSheetLayer.make("Print", func(canvas: MapCanvas) -> void: MapDrawing.print_page(canvas, model, projection, MapModel.GROUND), MapStyle.SHEET))
	page.add_child(MapSheetLayer.make("Wear", func(canvas: MapCanvas) -> void: MapDrawing.wear(canvas), MapStyle.SHEET, textures))
	page.add_child(MapSheetLayer.make("Wings", func(canvas: MapCanvas) -> void: MapDrawing.wing_names(canvas, model, projection, MapModel.GROUND), MapStyle.SHEET))
	page.add_child(MapSheetLayer.make("Names", func(canvas: MapCanvas) -> void: MapDrawing.room_names(canvas, model, projection, MapModel.GROUND), MapStyle.SHEET))
	add_child(port)
	var live := port.get_texture()
	for board: Variant in _waiting.get(key, []):
		if is_instance_valid(board):
			(board as MapPoster)._show(live)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(port):
		_waiting.erase(key)
		return
	var image := live.get_image()
	if image != null and not image.is_empty():
		image.generate_mipmaps()
		var kept := ImageTexture.create_from_image(image)
		_prints[key] = kept
		for board: Variant in _waiting.get(key, []):
			if is_instance_valid(board):
				(board as MapPoster)._show(kept)
		port.queue_free()
	_waiting.erase(key)
