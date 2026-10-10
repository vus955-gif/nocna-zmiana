extends Node
## Windowless previews of the paper museum map (W6): for a few moments of a
## game (a new game, after the first night, after the basement, late in the
## game) and each floor tab, records the sheet's drawing (MapRecorder) and
## the screen around it, and writes them as JSON to tests/_out/map/ for
## tools/map/render_preview.py (pycairo) to turn into PNGs. Also the wall
## poster. Run through tools/run_map_preview.sh (the scene map_preview.tscn,
## so the autoloads are there).

const OUT := "res://tests/_out/map"
const SCREEN := Vector2(1920.0, 1080.0)

var layout: LevelLayout
var projection: MapProjection


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	layout = Floor1Layout.create()
	projection = MapProjection.floor1()
	for locale: String in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for moment: String in ["new_game", "first_night", "after_basement", "late_game"]:
			if locale == "en" and moment != "late_game":
				continue
			var game := PersistentState.new()
			game.new_game()
			var guard := _play(game, moment)
			var state := MapState.from_game(game)
			var model := MapModel.build(layout, state)
			for tab in MapModel.TABS:
				_write("%s_%s%s" % [moment, tab, "" if locale == "pl" else "_en"], model, tab, guard)
			game.free()
	TranslationServer.set_locale("pl")
	_write_poster()
	_time()
	print("map previews written to ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


## Plays [param game] up to [param moment]; the guard's place: [position
## (world), facing (floor-plan direction)].
func _play(game: PersistentState, moment: String) -> Array:
	var rooms: Array[StringName] = []
	match moment:
		"new_game":
			rooms.assign([&"booth_security", &"booth_corridor"])
			return _guard_in(game, rooms, &"booth_security", Vector2(-1, 0))
		"first_night":
			rooms.assign([&"booth_security", &"booth_corridor", &"booth_staff", &"entrance_hall", &"entrance_cloakroom", &"court", &"court_balcony"])
			rooms.append_array(_public_rooms(&"egypt"))
			rooms.append(&"egypt_conservator")
			game.discover_haven(&"conservator")
			for weapon: StringName in [&"pistol", &"flare", &"shotgun"]:
				game.add_weapon(weapon)
			game.pistol_key = true
			game.notes.assign([NoteCatalog.KEY_NOTE, &"note_entrance_1", &"note_egypt_1", &"note_egypt_2"])
			return _guard_in(game, rooms, &"egypt_gallery", Vector2(0, -1))
		"after_basement":
			_play(game, "first_night")
			rooms.assign(game.rooms_visited)
			rooms.append_array([&"booth_stairs", &"egypt_cache"])
			rooms.append_array(_zone_rooms(&"basement"))
			rooms.append_array(_public_rooms(&"enlightenment"))
			rooms.append(&"enlightenment_librarian")
			game.discover_haven(&"workshop")
			game.discover_haven(&"librarian")
			game.defeat_guardian(&"colossus")
			game.add_seal(&"seal_sun")
			game.add_shard(&"shard_egypt")
			for gate: StringName in [&"seal_khorsabad", &"boards_staff_stairs", &"egypt_chain_cache", &"bolt_basement_egypt"]:
				game.open_gate(gate)
			game.add_item(&"fuse_basement")
			game.add_weapon(&"rifle_hunt")
			game.secrets.append(&"secret_egypt_1")
			game.chess_found.append(&"chess_2")
			game.notes.append(&"note_egypt_4")
			return _guard_in(game, rooms, layout.marker_rooms.get(&"switchboard", &"basement_workshop"), Vector2(1, 0))
		"late_game":
			_play(game, "after_basement")
			rooms.assign(game.rooms_visited)
			for zone: StringName in [&"assyria", &"greece", &"asia", &"americas", &"north_hall", &"roof", &"entrance", &"court"]:
				rooms.append_array(_public_rooms(zone))
			rooms.append_array(_zone_rooms(&"roof"))
			rooms.append_array([&"roof_stairs", &"enlightenment_roof_stairs", &"greece_cast_store", &"greece_service_stairs", &"greece_pottery", &"entrance_gallery", &"roof_loft"])
			for haven: StringName in [&"cast_store", &"teahouse"]:
				game.discover_haven(haven)
			for guardian: StringName in [&"lamassu", &"centaur", &"planetarium"]:
				var plan := Floor1Plan.guardian(guardian)
				game.defeat_guardian(guardian)
				game.add_seal(plan.seal)
				game.add_shard(plan.shard)
			for gate: StringName in [&"boards_tomb", &"bolt_lions_bassae", &"gate_north", &"gate_reading_room", &"chain_gatling", &"rope_planetarium", &"bolt_roof_enlightenment"]:
				game.open_gate(gate)
			for weapon: StringName in [&"gatling"]:
				game.add_weapon(weapon)
			game.add_item(&"fuse_assyria")
			game.chess_found.append_array([&"chess_1", &"chess_3"])
			game.secrets.append_array([&"secret_court_1", &"secret_greece_2"])
			return _guard_in(game, rooms, _zone_rooms(&"roof")[_zone_rooms(&"roof").size() - 1], Vector2(0, 1))
	return [Vector3.ZERO, Vector2.UP]


func _guard_in(game: PersistentState, rooms: Array[StringName], room_id: StringName, facing: Vector2) -> Array:
	for room in rooms:
		if layout.room(room) != null:
			game.visit_room(room)
	var model := MapModel.build(layout, MapState.from_game(game))
	var room := model.room(room_id)
	if room == null:
		push_warning("map preview: no room %s; the guard stands in the court" % room_id)
		room_id = &"court"
		room = model.room(room_id)
	var spec := layout.room(room_id)
	var at := room.anchor + Vector2(0.0, 2.0)
	return [Vector3(at.x, spec.floor_y, at.y), facing]


func _public_rooms(zone: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for room in layout.rooms:
		if room.zone == zone and room.public and not room.secret:
			found.append(room.id)
	return found


func _zone_rooms(zone: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for room in layout.rooms:
		if room.zone == zone and not room.secret:
			found.append(room.id)
	return found


func _write(name: String, model: MapModel, tab: StringName, guard: Array) -> void:
	var sheet := MapRecorder.new()
	MapDrawing.shadow(sheet)
	MapDrawing.paper(sheet)
	MapDrawing.print_page(sheet, model, projection, tab)
	MapDrawing.wear(sheet)
	MapDrawing.wing_names(sheet, model, projection, tab)
	MapDrawing.room_names(sheet, model, projection, tab)
	MapPencil.draw(sheet, model, projection, tab)
	var at: Vector3 = guard[0]
	var inside := layout.room(layout.room_at(at + Vector3.UP * 0.5))
	var guard_tab := MapModel.main_tab_of(inside) if inside != null else MapModel.tab_of_height(at.y)
	var guard_point := projection.point(at)
	if guard_tab == tab:
		MapDrawing.here(sheet, guard_point, guard[1])
	var view := MapView.new()
	view.screen_size = SCREEN
	view.look_at(guard_point, view.open_zoom())
	view.snap()
	var chrome := MapRecorder.new()
	var pencilled: Array[StringName] = []
	for each in MapModel.TABS:
		if model.has_pencil_on(each):
			pencilled.append(each)
	var hint := MapDrawing.tr_key(&"MAP_HINT") % ["M / Esc", MapDrawing.tr_key(&"MAP_KEY_SPACE")]
	MapDrawing.chrome(chrome, SCREEN, tab, guard_tab, pencilled, hint)
	var close := MapView.new()
	close.screen_size = SCREEN
	close.look_at(guard_point, close.fit_zoom() * 3.4)
	close.snap()
	var data := {
		"sheet": [MapStyle.SHEET.x, MapStyle.SHEET.y],
		"ops": sheet.ops,
		"screen": {"size": [SCREEN.x, SCREEN.y], "chrome": chrome.ops,
			"views": [
				{"name": "screen", "zoom": view.zoom, "center": [view.center.x, view.center.y], "names": MapView.name_alpha(view.zoom), "wings": view.wing_alpha(view.zoom)},
				{"name": "close", "zoom": close.zoom, "center": [close.center.x, close.center.y], "names": MapView.name_alpha(close.zoom), "wings": close.wing_alpha(close.zoom)},
			]},
	}
	var file := FileAccess.open(OUT.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## How long opening the map takes (the model, then each layer drawn once),
## a fresh layout (cold) and the same layout again (warm).
func _time() -> void:
	var fresh := Floor1Layout.create()
	var game := PersistentState.new()
	game.new_game()
	_play(game, "late_game")
	for pass_name: String in ["cold", "warm"]:
		var started := Time.get_ticks_usec()
		var model := MapModel.build(fresh, MapState.from_game(game))
		var built := Time.get_ticks_usec()
		var canvas := MapCanvas.new()   # draws nothing: the layout and geometry work only
		MapDrawing.print_page(canvas, model, projection, MapModel.GROUND)
		MapDrawing.wing_names(canvas, model, projection, MapModel.GROUND)
		MapDrawing.room_names(canvas, model, projection, MapModel.GROUND)
		MapPencil.draw(canvas, model, projection, MapModel.GROUND)
		var drawn := Time.get_ticks_usec()
		print("map open (%s): model %.1f ms, layers %.1f ms" % [pass_name, (built - started) / 1000.0, (drawn - built) / 1000.0])
	game.free()


## The wall poster: the print of the ground floor, no pencil, a red dot.
func _write_poster() -> void:
	var model := MapModel.build(layout, MapState.new())
	var sheet := MapRecorder.new()
	MapDrawing.paper(sheet)
	MapDrawing.print_page(sheet, model, projection, MapModel.GROUND)
	MapDrawing.wear(sheet)
	MapDrawing.wing_names(sheet, model, projection, MapModel.GROUND)
	MapDrawing.room_names(sheet, model, projection, MapModel.GROUND)
	var marker: Transform3D = layout.markers.get(&"museum_map_court", Transform3D.IDENTITY)
	sheet.set_layer(&"here")
	sheet.circle(projection.point(marker.origin), 9.0, MapStyle.RED)
	var file := FileAccess.open(OUT.path_join("poster.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"sheet": [MapStyle.SHEET.x, MapStyle.SHEET.y], "ops": sheet.ops}))
	file.close()
