extends TestCase
## The paper museum map's pure logic: the projection (world <-> sheet), the
## view on screen (zoom, pan, limits, smoothing), the floor tabs, which
## rooms are printed, pencilled in or hidden, the outlines, labels, doors
## and pictograms, the guard's pencil notes for every kind of progress and
## the goal (MapProjection, MapView, MapState, MapModel).

const EPS := 0.0001

var _layout: LevelLayout = null


## Floor I's layout (built once per test, about 5 ms).
func layout() -> LevelLayout:
	if _layout == null:
		_layout = Floor1Layout.create()
	return _layout


# --- projection ---------------------------------------------------------------

func test_projection_fits_the_floor_with_north_up() -> void:
	var projection := MapProjection.floor1()
	var floor_rect := Floor1Plan.bounds()
	var area := MapStyle.MAP_AREA
	var corners := [floor_rect.position, floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y), Vector2(floor_rect.end.x, floor_rect.position.y)]
	for corner: Vector2 in corners:
		var at := projection.to_sheet(corner)
		assert_true(area.grow(0.01).has_point(at), "corner %s lies in the map area (at %s)" % [corner, at])
	var used := projection.area
	assert_true(is_equal_approx(used.size.x, area.size.x) or is_equal_approx(used.size.y, area.size.y), "the floor fills the area along one axis")
	var north := projection.to_sheet(Vector2(0, -50))
	var south := projection.to_sheet(Vector2(0, 50))
	assert_lt(north.y, south.y, "north (-Z) is up")
	var west := projection.to_sheet(Vector2(-50, 0))
	var east := projection.to_sheet(Vector2(50, 0))
	assert_lt(west.x, east.x, "west is left")
	assert_almost_eq((east - west).length() / 100.0, (south - north).length() / 100.0, EPS, "one scale for both axes")
	var middle := projection.to_sheet(projection.world.get_center())
	assert_almost_eq(middle.x, area.get_center().x, 0.01, "centred across")
	assert_almost_eq(middle.y, area.get_center().y, 0.01, "centred down")


func test_projection_round_trips() -> void:
	var projection := MapProjection.floor1()
	for point: Vector2 in [Vector2(-112, -86), Vector2(65, 53), Vector2(0, 0), Vector2(-47.25, 13.5)]:
		var back := projection.to_world(projection.to_sheet(point))
		assert_lt(back.distance_to(point), EPS, "%s comes back" % point)
	var rect := Rect2(-10, -5, 20, 10)
	var on_sheet := projection.rect_to_sheet(rect)
	assert_almost_eq(on_sheet.size.x, 20.0 * projection.scale, EPS)
	assert_eq(projection.point(Vector3(3, 7, -4)), projection.to_sheet(Vector2(3, -4)), "a 3D point drops its height")


# --- view -----------------------------------------------------------------------

func _view() -> MapView:
	var view := MapView.new()
	view.screen_size = Vector2(1920, 1080)
	view.look_at(MapStyle.SHEET * 0.5, view.open_zoom())
	view.snap()
	return view


func test_view_zoom_keeps_the_point_under_the_cursor() -> void:
	var view := _view()
	var cursor := Vector2(1100, 600)
	var before := view.screen_to_sheet(cursor)
	view.zoom_at(cursor, 1.5)
	view.snap()
	assert_lt(view.screen_to_sheet(cursor).distance_to(before), 0.01, "the sheet point under the cursor stays put")
	assert_almost_eq(view.zoom, view.open_zoom() * 1.5, EPS)
	view.zoom_at(cursor, 1.0 / 1.5)
	view.snap()
	assert_lt(view.screen_to_sheet(cursor).distance_to(before), 0.01, "and on the way back")


func test_view_clamps_to_the_sheet_and_zoom_limits() -> void:
	var view := _view()
	view.zoom_at(Vector2(960, 540), 1000.0)
	assert_almost_eq(view.target_zoom, view.max_zoom(), EPS, "no closer than the limit")
	view.zoom_at(Vector2(960, 540), 0.0001)
	assert_almost_eq(view.target_zoom, view.min_zoom(), EPS, "no further than the whole sheet")
	view.snap()
	assert_eq(view.center, MapStyle.SHEET * 0.5, "the whole sheet is centred")
	view.look_at(Vector2(200, 200), view.max_zoom())
	view.pan_screen(Vector2(50000, 50000))
	view.snap()
	var top_left := view.sheet_to_screen(Vector2.ZERO)
	assert_lt(top_left.x, MapView.EDGE + 0.01, "the sheet's left edge stays within a strip of desk")
	assert_lt(top_left.y, MapView.EDGE + 0.01, "the sheet's top edge too")
	view.pan_screen(Vector2(-90000, -90000))
	view.snap()
	var bottom_right := view.sheet_to_screen(MapStyle.SHEET)
	assert_gt(bottom_right.x, view.screen_size.x - MapView.EDGE - 0.01, "and the right edge")
	assert_gt(bottom_right.y, view.screen_size.y - MapView.EDGE - 0.01, "and the bottom edge")


func test_view_smoothing_reaches_the_target() -> void:
	var view := _view()
	view.look_at(Vector2(700, 600), view.max_zoom() * 0.8)
	var moved := false
	for i in 60:
		moved = view.step(1.0 / 60.0) or moved
	assert_true(moved, "it glides")
	assert_lt(view.center.distance_to(view.target_center), 0.5, "there within a second")
	assert_almost_eq(view.zoom, view.target_zoom, view.target_zoom * 0.002)
	var at := view.transform() * Vector2(700, 600)
	assert_lt(at.distance_to(view.sheet_to_screen(Vector2(700, 600))), 0.01, "the transform is the view")
	assert_false(view.step(1.0 / 60.0) and view.step(1.0 / 60.0), "settles")


# --- model: rooms, tabs, print and pencil -------------------------------------

## A state with [param visited] rooms and the given lists (by name).
func _state(visited: Array = [], lists: Dictionary = {}) -> MapState:
	var state := MapState.new()
	state.rooms_visited.assign(visited)
	state.havens.assign(lists.get("havens", [&"security"]))
	for list: String in ["guardians_defeated", "gates_open", "seals", "shards", "items", "weapons", "flags", "notes", "chess_found", "secrets"]:
		if lists.has(list):
			(state.get(list) as Array).assign(lists[list])
	state.goal_key = lists.get("goal_key", &"")
	state.goal_step = lists.get("goal_step", &"")
	return state


func _model(visited: Array = [], lists: Dictionary = {}) -> MapModel:
	return MapModel.build(layout(), _state(visited, lists))


func _marker_room(marker: StringName) -> StringName:
	return layout().marker_rooms.get(marker, &"")


func test_tabs_follow_the_height() -> void:
	assert_eq(MapModel.tab_of_height(-6.0), MapModel.BASEMENT)
	assert_eq(MapModel.tab_of_height(-12.0), MapModel.BASEMENT)
	assert_eq(MapModel.tab_of_height(0.0), MapModel.GROUND)
	assert_eq(MapModel.tab_of_height(7.0), MapModel.GROUND, "a balcony is on the ground floor's page")
	assert_eq(MapModel.tab_of_height(Floor1Plan.ROOF_Y), MapModel.ROOF)
	assert_eq(MapModel.TABS.size(), 3)


func test_a_stairwell_shows_on_both_of_its_floors() -> void:
	var model := _model()
	assert_eq(model.room(&"booth_stairs").tabs, [MapModel.GROUND, MapModel.BASEMENT] as Array[StringName], "the staff stairs join the booth and the basement (in the tabs' order)")
	assert_eq(model.room(&"booth_stairs").main_tab, MapModel.BASEMENT, "its floor is the bottom landing")
	assert_eq(model.room(&"roof_stairs").tabs, [MapModel.GROUND, MapModel.ROOF] as Array[StringName], "the roof stairs join the landing and the roof")
	assert_eq(model.room(&"court").tabs, [MapModel.GROUND] as Array[StringName])
	var basement := model.room(Floor1Plan.haven(&"workshop").room)
	assert_eq(basement.tabs, [MapModel.BASEMENT] as Array[StringName])


func test_only_public_ground_rooms_are_printed() -> void:
	var model := _model([], {"havens": []})
	var printed := 0
	for spec in layout().rooms:
		var entry := model.room(spec.id)
		var should := spec.public and not spec.secret and spec.floor_y > -4.0 and spec.floor_y < 15.0 \
			and spec.zone != &"basement" and spec.zone != &"roof"
		if should:
			printed += 1
			assert_eq(entry.look, MapModel.Look.PRINTED, "%s is printed" % spec.id)
		else:
			assert_ne(entry.look, MapModel.Look.PRINTED, "%s is not printed" % spec.id)
			assert_eq(entry.look, MapModel.Look.HIDDEN, "%s stays blank in a new game" % spec.id)
	assert_gt(printed, 30, "the leaflet prints the galleries")
	for spec in layout().rooms:
		if spec.public and spec.floor_y < -0.5 and spec.floor_y > -4.0:
			assert_eq(model.room(spec.id).look, MapModel.Look.PRINTED, "a sunken hall (%s) is still the ground floor" % spec.id)
			assert_eq(model.room(spec.id).main_tab, MapModel.GROUND)
	for zone: StringName in [&"booth", &"basement", &"roof"]:
		for entry in model.rooms:
			if entry.zone == zone:
				assert_ne(entry.look, MapModel.Look.PRINTED, "no %s room is printed" % zone)


func test_staff_rooms_are_pencilled_in_once_visited() -> void:
	var boiler := _marker_room(&"fuse_basement")
	var switchboard := _marker_room(&"switchboard")
	assert_ne(boiler, &"", "the boiler room holds the basement's fuse")
	var model := _model([&"booth_corridor", boiler])
	assert_eq(model.room(&"booth_corridor").look, MapModel.Look.PENCIL)
	assert_eq(model.room(boiler).look, MapModel.Look.PENCIL)
	assert_true(model.room(boiler).on(MapModel.BASEMENT), "pencilled on the basement page")
	assert_eq(model.room(switchboard).look, MapModel.Look.HIDDEN, "a room he has not seen stays blank")
	assert_true(model.has_pencil_on(MapModel.BASEMENT))
	assert_false(_model().has_pencil_on(MapModel.ROOF), "nothing on the roof's page in a new game")


func test_secret_rooms_never_print_and_pencil_only_after_discovery() -> void:
	var secrets: Array[StringName] = []
	for spec in layout().rooms:
		if spec.secret:
			secrets.append(spec.id)
	assert_gt(secrets.size(), 3, "the floor has secret rooms")
	var fresh := _model()
	var found := _model(secrets)
	for id in secrets:
		assert_eq(fresh.room(id).look, MapModel.Look.HIDDEN, "%s is blank until found" % id)
		assert_eq(found.room(id).look, MapModel.Look.PENCIL, "%s is pencilled in once found" % id)
	for door in fresh.doors:
		if secrets.has(door.room_a) or secrets.has(door.room_b):
			assert_eq(door.look, MapModel.Look.HIDDEN, "the way into %s/%s is not shown" % [door.room_a, door.room_b])


func test_known_havens_are_pencilled_even_unvisited() -> void:
	var model := _model([], {"havens": [&"security", &"conservator"]})
	var booth := model.room(Floor1Plan.haven(&"security").room)
	var conservator := model.room(Floor1Plan.haven(&"conservator").room)
	assert_eq(booth.look, MapModel.Look.PENCIL)
	assert_eq(booth.haven, &"security")
	assert_eq(conservator.look, MapModel.Look.PENCIL)
	assert_eq(conservator.haven, &"conservator")
	assert_eq(model.room(Floor1Plan.haven(&"librarian").room).look, MapModel.Look.HIDDEN, "a haven not found yet")


func test_outline_drops_shared_edges() -> void:
	var parts: Array[Rect2] = [Rect2(0, 0, 4, 2), Rect2(4, 0, 2, 6)]
	var segments := MapModel.outline(parts)
	var total := 0.0
	for segment in segments:
		total += segment[0].distance_to(segment[1])
		var middle := (segment[0] + segment[1]) * 0.5
		assert_false(is_equal_approx(middle.x, 4.0) and middle.y < 2.0, "the shared edge x = 4 (z 0..2) is gone: %s" % segment)
	assert_almost_eq(total, 4 + 2 + 6 + 2 + 4 + 4 + 2, 0.001, "the outline is the L's perimeter")
	var single := MapModel.outline([Rect2(1, 1, 3, 2)] as Array[Rect2])
	assert_eq(single.size(), 4)


func test_the_reading_room_is_round() -> void:
	var model := _model()
	assert_true(model.room(&"court_reading").round, "the Reading Room's drum")
	assert_false(model.room(&"court").round)
	assert_false(model.room(&"court_balcony").round)
	assert_almost_eq(model.room(&"court_reading").radius(), 10.5, 0.6)


func test_balconies_are_upper_rooms() -> void:
	var model := _model()
	assert_true(model.room(&"court_balcony").upper)
	assert_true(model.room(&"entrance_gallery").upper)
	assert_false(model.room(&"entrance_hall").upper)


func test_doors_print_only_between_printed_rooms() -> void:
	var model := _model()
	var garden_wall: StringName = Floor1Plan.INTERNAL_GATE_TARGETS[&"cracked_garden"]
	for door in model.doors:
		var opening := layout().opening(door.id)
		var a := model.room(door.room_a)
		var b := model.room(door.room_b)
		var both := a.look == MapModel.Look.PRINTED and b.look == MapModel.Look.PRINTED
		var panel := opening.door_style == OpeningSpec.DoorStyle.PANEL or opening.link == RoomGraph.Kind.SECRET
		assert_eq(door.look == MapModel.Look.PRINTED, both and not panel, "door %s" % door.id)
	var wall := _find_door(model, garden_wall)
	assert_not_null(wall)
	if wall != null:
		assert_ne(wall.look, MapModel.Look.PRINTED, "the cracked wall is no door for the visitors")
	var conservator := Floor1Plan.haven(&"conservator").room
	for door in model.doors:
		if door.room_a == conservator or door.room_b == conservator:
			assert_eq(door.look, MapModel.Look.HIDDEN, "the conservator's door is not printed")
	var known := _model([], {"havens": [&"security", &"conservator"]})
	var pencilled := 0
	for door in known.doors:
		if door.room_a == conservator or door.room_b == conservator:
			pencilled += 1
			assert_eq(door.look, MapModel.Look.PENCIL, "pencilled in with the room")
	assert_gt(pencilled, 0)


func _find_door(model: MapModel, id: StringName) -> MapModel.Doorway:
	for door in model.doors:
		if door.id == id:
			return door
	return null


func test_labels_anchor_inside_their_room() -> void:
	var model := _model()
	for entry in model.rooms:
		assert_true(entry.covers(entry.anchor), "%s's label point lies in it (%s)" % [entry.id, entry.anchor])
		if entry.upper or entry.round:
			continue
		for other in model.rooms:
			if other == entry or not other.on(entry.main_tab) or other.bounds().encloses(entry.bounds()):
				continue
			assert_false(other.covers(entry.anchor), "%s's label point is not in %s" % [entry.id, other.id])
	var court := model.room(&"court")
	assert_gt(court.anchor.distance_to(Vector2.ZERO), 11.0, "the court's name stays off the Reading Room")


func test_pictograms_come_from_the_pieces() -> void:
	var model := _model()
	var kinds := {}
	for picto in model.pictos:
		kinds[picto.kind] = true
		assert_eq(picto.tab, MapModel.GROUND)
		var holder := model.room_at(picto.at, MapModel.GROUND)
		assert_true(holder != &"" and model.room(holder).look == MapModel.Look.PRINTED, "%s stands in a public room" % picto.kind)
	for kind: StringName in [&"info", &"cafe", &"shop", &"cloakroom", &"tickets", &"entrance"]:
		assert_true(kinds.has(kind), "the leaflet shows %s" % kind)


func test_wings_are_named_over_their_rooms() -> void:
	var model := _model()
	var zones := {}
	for wing in model.wings:
		zones[wing.zone] = wing
		var holder := model.room_at(wing.at, MapModel.GROUND)
		assert_ne(holder, &"", "%s's name lies on the plan" % wing.zone)
		if holder != &"":
			assert_eq(model.room(holder).zone, wing.zone, "%s's name lies in its own wing" % wing.zone)
	for zone in MapStyle.NAMED_ZONES:
		assert_true(zones.has(zone), "%s is named" % zone)
	if zones.has(&"egypt") and zones.has(&"court"):
		assert_true((zones[&"egypt"] as MapModel.Wing).rotated, "Egypt's long gallery: the name runs up the page")
		assert_false((zones[&"court"] as MapModel.Wing).rotated)


func test_state_from_game() -> void:
	var game := PersistentState.new()
	game.new_game()
	game.visit_room(&"booth_security")
	game.add_weapon(&"flare")
	game.pistol_key = true
	game.notes.append(&"note_heniek")
	var state := MapState.from_game(game)
	assert_eq(state.rooms_visited, [&"booth_security"] as Array[StringName])
	assert_true(state.items.has(&"pistol_key"), "the till key counts as found")
	assert_eq(state.weapons, [&"flare"] as Array[StringName])
	assert_eq(state.havens, [&"security"] as Array[StringName])
	assert_eq(state.goal_key, &"GOAL_PISTOL", "the HUD's goal")
	assert_eq(state.goal_step, &"pistol")
	var fresh := PersistentState.new()
	fresh.new_game()
	assert_eq(MapState.from_game(fresh).goal_step, &"pistol_key")
	fresh.flags.append(ProgressRules.COMPLETE_FLAG)
	var done := MapState.from_game(fresh)
	assert_eq(done.goal_key, ProgressRules.GOAL_EPILOGUE)
	assert_eq(done.goal_step, &"", "the epilogue has no place")
	game.free()
	fresh.free()


# --- model: the guard's pencil notes and the goal --------------------------------

func _marker_point(marker: StringName) -> Vector2:
	var at: Transform3D = layout().markers[marker]
	return Vector2(at.origin.x, at.origin.z)


func test_visited_rooms_get_a_tick() -> void:
	var boiler := _marker_room(&"fuse_basement")
	var model := _model([&"entrance_hall", &"court", boiler], {"havens": []})
	var ticks := model.marks_of(MapModel.MarkKind.TICK)
	var ids := {}
	for tick in ticks:
		ids[tick.id] = tick
	assert_eq(ids.keys().size(), 3, "one tick per room visited")
	assert_eq((ids[&"court"] as MapModel.Mark).at, model.room(&"court").anchor, "at its label point")
	assert_eq((ids[&"court"] as MapModel.Mark).tab, MapModel.GROUND)
	assert_eq((ids[boiler] as MapModel.Mark).tab, MapModel.BASEMENT)
	assert_true(_model([], {"havens": []}).marks_of(MapModel.MarkKind.TICK).is_empty(), "no ticks in a new game")


func test_havens_get_a_circle() -> void:
	var model := _model([], {"havens": [&"security", &"workshop"]})
	var circles := model.marks_of(MapModel.MarkKind.HAVEN)
	assert_eq(circles.size(), 2)
	var workshop := model.mark(MapModel.MarkKind.HAVEN, &"workshop")
	assert_not_null(workshop)
	if workshop != null:
		assert_eq(workshop.tab, MapModel.BASEMENT)
		assert_true(model.room(workshop.room).covers(workshop.at), "round the haven's room")


func test_finds_get_icons() -> void:
	var model := _model([], {
		"weapons": [&"shotgun"],
		"items": [&"pistol_key", &"fuse_basement"],
		"flags": [&"power_north"],
		"notes": [NoteCatalog.KEY_NOTE, &"note_egypt_1"],
		"chess_found": [&"chess_1"],
		"secrets": [&"secret_court_1"],
	})
	var gun := model.mark(MapModel.MarkKind.WEAPON, &"shotgun")
	assert_not_null(gun, "the shotgun found")
	if gun != null:
		assert_eq(gun.at, _marker_point(&"weapon_shotgun"))
		assert_eq(gun.item, &"shotgun")
	var key := model.mark(MapModel.MarkKind.ITEM, &"pistol_key")
	assert_not_null(key, "the till key")
	if key != null:
		assert_eq(key.at, _marker_point(&"ticket_drawer"))
	var fuse := model.mark(MapModel.MarkKind.ITEM, &"fuse_basement")
	assert_not_null(fuse)
	if fuse != null:
		assert_eq(fuse.tab, MapModel.BASEMENT)
	assert_not_null(model.mark(MapModel.MarkKind.ITEM, &"power_north"), "the power restored at the switchboard")
	var heniek := model.mark(MapModel.MarkKind.NOTE, NoteCatalog.KEY_NOTE)
	assert_not_null(heniek, "Heniek's sticky note through its marker's alias")
	if heniek != null:
		assert_eq(heniek.at, _marker_point(&"note_heniek"))
	assert_not_null(model.mark(MapModel.MarkKind.NOTE, &"note_egypt_1"))
	assert_not_null(model.mark(MapModel.MarkKind.CHESS, &"chess_1"))
	assert_not_null(model.mark(MapModel.MarkKind.SECRET, &"secret_court_1"))
	assert_eq(model.marks_of(MapModel.MarkKind.WEAPON).size(), 1, "nothing else drawn as found")
	assert_true(_model().marks_of(MapModel.MarkKind.NOTE).is_empty())


func test_guardians_get_an_exclamation_crossed_when_defeated() -> void:
	var arena := _marker_room(&"guardian_colossus")
	assert_eq(_model().marks_of(MapModel.MarkKind.GUARDIAN).size(), 0, "no guardian known in a new game")
	var seen := _model([arena]).mark(MapModel.MarkKind.GUARDIAN, &"colossus")
	assert_not_null(seen, "his arena seen")
	if seen != null:
		assert_false(seen.crossed)
		assert_eq(seen.at, _marker_point(&"guardian_colossus"))
	var won := _model([arena], {"guardians_defeated": [&"colossus"], "seals": [&"seal_sun"], "shards": [&"shard_egypt"]})
	var fallen := won.mark(MapModel.MarkKind.GUARDIAN, &"colossus")
	assert_not_null(fallen)
	if fallen != null:
		assert_true(fallen.crossed, "crossed out once he fell")
		var seal := won.mark(MapModel.MarkKind.SEAL, &"seal_sun")
		var shard := won.mark(MapModel.MarkKind.SHARD, &"shard_egypt")
		assert_not_null(seal, "the seal beside him")
		assert_not_null(shard, "the shard beside him")
		if seal != null and shard != null:
			assert_lt(seal.at.distance_to(fallen.at), 4.0)
			assert_lt(shard.at.distance_to(fallen.at), 4.0)
			assert_gt(seal.at.distance_to(shard.at), 1.0, "side by side, not on top of each other")


func test_known_closed_gates_get_a_question_mark_with_their_lock() -> void:
	var arena := _marker_room(&"guardian_colossus")
	var opening := layout().opening(&"j_egypt_assyria")
	var model := _model([arena])
	var gate := model.mark(MapModel.MarkKind.GATE, &"seal_khorsabad")
	assert_not_null(gate, "the Khorsabad gate seen from the Colossus hall")
	if gate != null:
		assert_eq(gate.lock, GateSpec.Kind.SEAL)
		assert_eq(gate.at, opening.rect.get_center())
		assert_eq(gate.tab, MapModel.GROUND)
	assert_null_mark(_model([arena], {"gates_open": [&"seal_khorsabad"]}).mark(MapModel.MarkKind.GATE, &"seal_khorsabad"), "gone once open")
	assert_null_mark(model.mark(MapModel.MarkKind.GATE, &"shutter_asia"), "a gate he has not seen")
	var reading := _marker_room(&"gatling_case")
	var chain := _model([reading]).mark(MapModel.MarkKind.GATE, &"chain_gatling")
	assert_not_null(chain, "the gatling's chained case")
	if chain != null:
		assert_eq(chain.lock, GateSpec.Kind.CHAIN)
		assert_eq(chain.at, _marker_point(&"gatling_case"))
	var stairs := _model([&"booth_stairs"]).mark(MapModel.MarkKind.GATE, &"boards_staff_stairs")
	assert_not_null(stairs, "the boarded staff stairs")
	if stairs != null:
		assert_eq(stairs.lock, GateSpec.Kind.BOARDS)
		assert_eq(stairs.tab, MapModel.BASEMENT, "down at the basement door")


func assert_null_mark(mark: MapModel.Mark, message: String) -> void:
	assert_true(mark == null, message)


func test_the_goal_points_at_its_place() -> void:
	var fresh := _model([], {"goal_key": &"GOAL_TICKET_KEY", "goal_step": &"pistol_key"})
	assert_true(fresh.goal.placed)
	assert_eq(fresh.goal.at, _marker_point(&"ticket_drawer"))
	assert_eq(fresh.goal.tab, MapModel.GROUND)
	assert_eq(fresh.goal.room, _marker_room(&"ticket_drawer"))
	assert_eq(fresh.goal.key, &"GOAL_TICKET_KEY")
	var fuse := _model([], {"goal_key": &"GOAL_FUSE_BASEMENT", "goal_step": &"fuse_basement"})
	assert_eq(fuse.goal.tab, MapModel.BASEMENT, "the basement's fuse: on the basement page")
	var guardian := _model([], {"goal_key": &"GOAL_GUARDIAN_EGYPT", "goal_step": &"colossus"})
	assert_eq(guardian.goal.at, _marker_point(&"guardian_colossus"))
	var finale := _model([], {"goal_key": &"GOAL_TREX", "goal_step": ProgressRules.TREX})
	assert_eq(finale.goal.at, _marker_point(Floor1Plan.TREX_MARKER))
	var epilogue := _model([], {"goal_key": ProgressRules.GOAL_EPILOGUE})
	assert_false(epilogue.goal.placed, "the epilogue has no place")
	assert_eq(epilogue.goal.key, ProgressRules.GOAL_EPILOGUE)


func test_label_points_are_worked_out_once_per_layout() -> void:
	var first := _model()
	assert_true(layout().has_meta(MapModel.ANCHORS_META), "kept on the layout")
	var kept: Dictionary = layout().get_meta(MapModel.ANCHORS_META)
	kept[&"court"] = Vector2(1.5, 2.5)
	var second := _model([&"court"])
	assert_eq(second.room(&"court").anchor, Vector2(1.5, 2.5), "the second map of the night reuses them")
	assert_ne(first.room(&"court").anchor, Vector2(1.5, 2.5))
	var other := MapModel.build(Floor1Layout.create(), _state())
	assert_eq(other.room(&"court").anchor, first.room(&"court").anchor, "a new layout works them out again, the same")
