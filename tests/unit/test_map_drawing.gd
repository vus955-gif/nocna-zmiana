extends TestCase
## The paper map's drawing, recorded (MapRecorder): the print in the wings'
## colours with nothing of the secret rooms, the names and the key, the
## staff-only pages, and the guard's pencil - the rooms he drew in, every
## note on the page, tonight's goal with its arrow and in the notes box.

var _layout: LevelLayout = null


func layout() -> LevelLayout:
	if _layout == null:
		_layout = Floor1Layout.create()
	return _layout


func _state(visited: Array = [], lists: Dictionary = {}) -> MapState:
	var state := MapState.new()
	state.rooms_visited.assign(visited)
	state.havens.assign(lists.get("havens", [&"security"]))
	for list: String in ["guardians_defeated", "gates_open", "seals", "shards", "items", "weapons", "flags", "notes", "chess_found", "secrets"]:
		if lists.has(list):
			(state.get(list) as Array).assign(lists[list])
	state.goal_key = lists.get("goal_key", &"GOAL_TICKET_KEY")
	state.goal_step = lists.get("goal_step", &"pistol_key")
	return state


func _model(visited: Array = [], lists: Dictionary = {}) -> MapModel:
	return MapModel.build(layout(), _state(visited, lists))


func _same_rgb(a: Array, b: Color) -> bool:
	return absf(float(a[0]) - b.r) < 0.002 and absf(float(a[1]) - b.g) < 0.002 and absf(float(a[2]) - b.b) < 0.002


func _print(model: MapModel, tab: StringName) -> MapRecorder:
	var canvas := MapRecorder.new()
	MapDrawing.print_page(canvas, model, MapProjection.floor1(), tab)
	return canvas


func _pencil(model: MapModel, tab: StringName) -> MapRecorder:
	var canvas := MapRecorder.new()
	MapPencil.draw(canvas, model, MapProjection.floor1(), tab)
	return canvas


# --- the print ---------------------------------------------------------------------

func test_print_fills_every_printed_room_in_its_wing_colour() -> void:
	var model := _model()
	var projection := MapProjection.floor1()
	var canvas := _print(model, MapModel.GROUND)
	var checked := 0
	for room in model.rooms_on(MapModel.GROUND, MapModel.Look.PRINTED):
		if room.upper:
			continue
		var at := projection.to_sheet(room.anchor)
		var coloured := false
		for fill in canvas.fills_at(at, &"print"):
			if _same_rgb(fill["c"], MapStyle.fill(room.zone)):
				coloured = true
		assert_true(coloured, "%s is printed in %s's colour" % [room.id, room.zone])
		checked += 1
	assert_gt(checked, 30)


func test_print_never_touches_a_secret_room() -> void:
	var model := _model()
	var projection := MapProjection.floor1()
	var canvas := _print(model, MapModel.GROUND)
	var wing_colours: Array[Color] = []
	for zone: StringName in MapStyle.ZONE_PRINT:
		wing_colours.append(MapStyle.fill(zone))
	var secrets := 0
	for room in model.rooms:
		# the hidden rooms of the ground floor (a cellar may lie under a gallery)
		if room.main_tab != MapModel.GROUND or room.upper or room.look != MapModel.Look.HIDDEN:
			continue
		secrets += 1
		for part in room.parts:
			var middle := projection.to_sheet(part.get_center())
			for fill in canvas.fills_at(middle, &"print"):
				for colour in wing_colours:
					assert_false(_same_rgb(fill["c"], colour), "%s shows no gallery colour (only the grey mass)" % room.id)
	assert_gt(secrets, 3)
	for word in canvas.texts():
		for room in model.rooms:
			if room.look == MapModel.Look.HIDDEN and room.name_key != &"":
				assert_ne(word, MapDrawing.tr_key(room.name_key), "no name of a blank room on the print")


func test_print_names_the_wings_and_the_museum() -> void:
	var model := _model([], {"havens": []})
	var canvas := MapRecorder.new()
	var projection := MapProjection.floor1()
	MapDrawing.print_page(canvas, model, projection, MapModel.GROUND)
	MapDrawing.wing_names(canvas, model, projection, MapModel.GROUND)
	MapDrawing.room_names(canvas, model, projection, MapModel.GROUND)
	var words := canvas.texts()
	assert_true(words.has(MapDrawing.tr_key(&"MAP_TITLE").to_upper()), "the museum's name")
	assert_true(words.has(MapDrawing.tr_key(&"MAP_TAB_GROUND").to_upper()), "the page's name")
	for zone: StringName in [&"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas"]:
		assert_true(canvas.texts(&"wings").has(MapDrawing.tr_key(Floor1Plan.zone_name_key(zone)).to_upper()), "%s named in big letters" % zone)
	var names := " ".join(canvas.texts(&"names"))
	assert_true(names.contains(MapDrawing.tr_key(&"ROOM_EGYPT_GALLERY").split(" ")[0]), "the rooms' names")
	assert_false(names.contains(MapDrawing.tr_key(&"ROOM_BOOTH_SECURITY")), "no name of a staff room he has not drawn in")


func test_legend_lists_every_wing_and_pictogram() -> void:
	var words := _print(_model(), MapModel.GROUND).texts(&"print")
	for zone: StringName in [&"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas"]:
		assert_true(words.has(MapDrawing.tr_key(Floor1Plan.zone_name_key(zone))), "%s in the key" % zone)
	assert_true(words.has(MapDrawing.tr_key(&"MAP_LEGEND_COURT")))
	for row: Array in MapDrawing.FACILITIES:
		assert_true(words.has(MapDrawing.tr_key(row[1])), "%s in the key" % row[1])
	assert_true(words.has(MapDrawing.tr_key(&"MAP_YOU_ARE_HERE")))
	assert_true(words.has(MapDrawing.tr_key(&"MAP_LEGEND_STAFF")))


func test_basement_page_prints_only_the_staff_notice() -> void:
	var model := _model()
	var canvas := _print(model, MapModel.BASEMENT)
	for entry in canvas.ops_on(&"print"):
		if String(entry["op"]) != "rect" or float((entry["c"] as Array)[3]) < 0.5:
			continue
		var r: Array = entry["r"]
		if not MapStyle.MAP_AREA.has_point(Vector2(r[0], r[1])):
			continue
		for zone: StringName in MapStyle.ZONE_PRINT:
			assert_false(_same_rgb(entry["c"], MapStyle.fill(zone)), "no gallery printed on the basement page")
	assert_true(canvas.texts().has(MapDrawing.tr_key(&"MAP_NOTICE_BASEMENT").to_upper()), "the staff-only notice")
	assert_true(canvas.texts().has(MapDrawing.tr_key(&"MAP_TAB_BASEMENT").to_upper()))


# --- the pencil ------------------------------------------------------------------------

func _inside(entry: Dictionary, box: Rect2) -> bool:
	for point in MapRecorder.points_of(entry):
		if not box.has_point(point):
			return false
	return true


func test_pencil_outlines_and_hatches_staff_rooms() -> void:
	var model := _model([&"booth_corridor"], {"havens": []})
	var projection := MapProjection.floor1()
	var canvas := _pencil(model, MapModel.GROUND)
	var box := projection.rect_to_sheet(model.room(&"booth_corridor").bounds()).grow(6.0)
	var strokes := 0
	var hatching := 0
	for entry in canvas.ops_on(&"pencil"):
		if String(entry["op"]) == "line" and _inside(entry, box):
			strokes += 1
		if String(entry["op"]) == "lines" and _inside(entry, box):
			hatching = maxi(hatching, (entry["pts"] as Array).size() / 4)
	assert_gt(strokes, 3, "its four walls drawn (and doors)")
	assert_gt(hatching, 2, "hatched inside")
	var empty := _pencil(_model([], {"havens": []}), MapModel.GROUND)
	var stray := 0
	for entry in empty.ops_on(&"pencil"):
		if String(entry["op"]) != "text" and String(entry["op"]) != "label" and _inside(entry, box):
			stray += 1
	assert_eq(stray, 0, "nothing drawn there before he went in")


func test_pencil_strokes_wobble_deterministically() -> void:
	var lists := {"havens": [&"security", &"conservator"]}
	var first := _pencil(_model([&"booth_corridor", &"court"], lists), MapModel.GROUND).to_json()
	var second := _pencil(_model([&"booth_corridor", &"court"], lists), MapModel.GROUND).to_json()
	assert_eq(first, second, "the same state draws the same lines")
	var canvas := _pencil(_model([&"booth_corridor"], lists), MapModel.GROUND)
	var bent := false
	for entry in canvas.ops_on(&"pencil"):
		if String(entry["op"]) != "line":
			continue
		var points := MapRecorder.points_of(entry)
		if points.size() < 4:
			continue
		var a := points[0]
		var b := points[points.size() - 1]
		for point in points:
			if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) > 0.2:
				bent = true
	assert_true(bent, "a hand, not a ruler")


func test_pencil_marks_every_annotation() -> void:
	var arena: StringName = layout().marker_rooms[&"guardian_colossus"]
	var model := _model([&"entrance_hall", &"court", arena, &"booth_security"], {
		"havens": [&"security", &"conservator"],
		"weapons": [&"shotgun", &"flare"],
		"items": [&"pistol_key"],
		"notes": [&"note_egypt_1"],
		"chess_found": [&"chess_2"],
		"secrets": [&"secret_court_1"],
		"guardians_defeated": [&"colossus"], "seals": [&"seal_sun"], "shards": [&"shard_egypt"],
	})
	var projection := MapProjection.floor1()
	var canvas := _pencil(model, MapModel.GROUND)
	var kinds := {}
	for mark in model.marks_on(MapModel.GROUND):
		kinds[mark.kind] = true
		var point := projection.to_sheet(mark.at)
		if mark.kind == MapModel.MarkKind.TICK:
			point = MapPencil.tick_point(model.room(mark.room), projection)
		if mark.kind == MapModel.MarkKind.HAVEN:
			var box := projection.rect_to_sheet(model.room(mark.room).bounds())
			point = box.get_center() + Vector2(box.size.x * 0.5 + 9.0, 0.0)
		assert_false(canvas.marks_near(point, 24.0, &"pencil").is_empty(), "%s %s is drawn" % [MapModel.MarkKind.keys()[mark.kind], mark.id])
	for kind: MapModel.MarkKind in [MapModel.MarkKind.TICK, MapModel.MarkKind.HAVEN, MapModel.MarkKind.WEAPON, MapModel.MarkKind.ITEM,
			MapModel.MarkKind.NOTE, MapModel.MarkKind.CHESS, MapModel.MarkKind.SECRET, MapModel.MarkKind.GUARDIAN,
			MapModel.MarkKind.SEAL, MapModel.MarkKind.SHARD, MapModel.MarkKind.GATE]:
		assert_true(kinds.has(kind), "the test state has a %s" % MapModel.MarkKind.keys()[kind])


func test_goal_arrow_points_at_the_goal() -> void:
	var model := _model([], {"goal_key": &"GOAL_SHOTGUN", "goal_step": &"shotgun"})
	var projection := MapProjection.floor1()
	var at := projection.to_sheet(model.goal.at)
	var ground := _pencil(model, MapModel.GROUND)
	var here := MapDrawing.tr_key(&"MAP_PENCIL_HERE")
	assert_true(ground.texts(&"pencil").has(here), "\"here!\" at the arrow's tail")
	var tips := 0
	for entry in ground.ops_on(&"pencil"):
		if String(entry["op"]) == "line":
			var points := MapRecorder.points_of(entry)
			if points.size() == 2 or points.size() > 2:
				if points[0].distance_to(at) <= 20.0 or points[points.size() - 1].distance_to(at) <= 20.0:
					tips += 1
	assert_gt(tips, 1, "the arrow ends at the goal")
	var basement := _pencil(model, MapModel.BASEMENT)
	assert_false(basement.texts(&"pencil").has(here), "no arrow on another page")


func test_guard_notes_write_the_goal() -> void:
	var model := _model([], {"goal_key": &"GOAL_FUSE_BASEMENT", "goal_step": &"fuse_basement"})
	var canvas := _pencil(model, MapModel.GROUND)
	var written := " ".join(canvas.texts(&"pencil"))
	assert_true(written.contains(MapDrawing.tr_key(&"MAP_PENCIL_TONIGHT")))
	var goal := MapDrawing.tr_key(&"GOAL_FUSE_BASEMENT")
	assert_true(written.contains(goal.split(" ")[0]), "the goal is written down")
	assert_true(written.contains(MapDrawing.tr_key(&"MAP_TAB_BASEMENT")), "with the page it is on")
	for entry in canvas.ops_on(&"pencil"):
		if String(entry["op"]) == "text" and MapDrawing.tr_key(&"MAP_PENCIL_TONIGHT") != String(entry["t"]):
			var p: Array = entry["p"]
			if float(p[0]) > MapStyle.LEGEND_AREA.position.x:
				assert_lt(float(p[0]) + float(entry["w"]), MapStyle.LEGEND_AREA.end.x + 4.0, "inside the notes box: %s" % entry["t"])


func test_you_are_here_points_the_way_he_looks_and_stays_off_the_key() -> void:
	var canvas := MapRecorder.new()
	var at := Vector2(900.0, 700.0)
	MapDrawing.here(canvas, at, Vector2(1.0, 0.0))
	var arrow: Dictionary = {}
	for entry in canvas.ops_on(&"here"):
		if String(entry["op"]) == "poly":
			arrow = entry
	assert_false(arrow.is_empty(), "a red arrow")
	var tip := MapRecorder.points_of(arrow)[0]
	assert_gt(tip.x, at.x + 10.0, "pointing east when he looks east")
	assert_almost_eq(tip.y, at.y, 0.01)
	assert_true(canvas.texts(&"here").has(MapDrawing.tr_key(&"MAP_YOU_ARE_HERE")))
	var east := MapRecorder.new()
	MapDrawing.here(east, Vector2(MapStyle.MAP_AREA.end.x - 20.0, 700.0), Vector2.UP)
	for entry in east.ops_on(&"here"):
		if String(entry["op"]) == "text":
			var p: Array = entry["p"]
			assert_lt(float(p[0]) + float(entry["w"]), MapStyle.MAP_AREA.end.x, "by the key the label goes left")
