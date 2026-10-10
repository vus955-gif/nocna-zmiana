extends TestCase
## The paper museum map on screen (MuseumMap): the M key and the pad's
## Back button, opening and closing with the game paused and the input held,
## the floor tabs, the view (centred on the guard, zoom about the cursor,
## drag), the pause menu's entry, Floor I's installation and the maps on the
## walls of the havens (MuseumMap.poster).


func test_map_action_is_bound_to_m_and_the_pad_back_button() -> void:
	assert_true(InputMap.has_action(&"map"), "the map action exists")
	var key := false
	var pad := false
	for event in InputMap.action_get_events(&"map"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_M:
			key = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
			pad = true
	assert_true(key, "M opens the map")
	assert_true(pad, "the pad's Back (View / Select) button opens the map")
	assert_eq(GameInput.key_label(&"map"), "M")


# --- the screen (a map with Floor I's layout, the save and a stand-in guard) ---

var map: MuseumMap = null
var guard: Node3D = null
var pause_menu: PauseMenu = null


func after_each() -> void:
	if is_instance_valid(map):
		map.free()
	if is_instance_valid(guard):
		guard.free()
	if is_instance_valid(pause_menu):
		pause_menu.free()
	get_tree().paused = false


## The map with the guard standing at [param at] (feet), looking north.
func _map(at: Vector3 = Vector3(33.0, 0.0, 46.0)) -> MuseumMap:
	guard = Node3D.new()
	add_child(guard)
	guard.global_position = at
	map = MuseumMap.new()
	map.layout = Floor1Layout.create()
	map.game = GameState
	map.guard_source = func() -> Node3D: return guard
	add_child(map)
	return map


func _action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_action(action, true)
	await get_tree().process_frame
	_action(action, false)
	await get_tree().process_frame


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## A mouse button at [param at] (canvas px, as the map's root sees it).
func _mouse(button: MouseButton, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = get_viewport().get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


func _drag_by(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	var scale := get_viewport().get_final_transform().get_scale()
	event.relative = delta * scale
	event.position = get_viewport().get_final_transform() * Vector2(900, 500)
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


func test_m_opens_and_pauses_and_m_closes() -> void:
	_map()
	await get_tree().process_frame
	await _tap(&"map")
	assert_true(map.is_open, "M opens the map")
	assert_true(get_tree().paused, "the game waits")
	assert_eq(GameInput.top_ui(), map, "the map holds the input")
	assert_false(GameInput.gameplay_input(), "the guard does not move")
	assert_true(map.visible)
	await _tap(&"map")
	assert_false(map.is_open, "M again puts it down")
	assert_false(get_tree().paused)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameInput.top_ui(), null, "the input is back")


func test_escape_closes_without_the_pause_menu() -> void:
	_map()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	await get_tree().process_frame
	map.open()
	await _key(KEY_ESCAPE)
	assert_false(map.is_open, "Esc puts the map down")
	assert_false(pause_menu.is_open, "and only that")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(get_tree().paused)


func test_it_opens_on_the_guards_floor_centred_on_him() -> void:
	var layout := Floor1Layout.create()
	var boiler: StringName = layout.marker_rooms[&"fuse_basement"]
	var room := layout.room(boiler)
	var middle := room.parts[0].get_center()
	_map(Vector3(middle.x, room.floor_y, middle.y))
	await get_tree().process_frame
	map.open()
	assert_eq(map.tab, MapModel.BASEMENT, "his floor's page")
	assert_eq(map.guard_tab, MapModel.BASEMENT)
	var on_screen := map.view.sheet_to_screen(map.guard_sheet_point())
	assert_lt(on_screen.distance_to(map.view.screen_size * 0.5), 1.0, "centred on him")
	assert_almost_eq(map.view.zoom, map.view.open_zoom(), 0.0001, "a little closer than the whole sheet")
	map.close()
	_map_free()
	_map(Vector3(0.0, 0.0, 40.0))
	await get_tree().process_frame
	map.open()
	assert_eq(map.tab, MapModel.GROUND, "in the entrance hall: the ground floor")


func _map_free() -> void:
	map.free()
	guard.free()


func test_tabs_switch_and_wrap() -> void:
	_map()
	await get_tree().process_frame
	map.open()
	assert_eq(map.tab, MapModel.GROUND)
	await _key(KEY_E)
	assert_eq(map.tab, MapModel.BASEMENT, "E: the next floor")
	await _key(KEY_Q)
	assert_eq(map.tab, MapModel.GROUND, "Q: back")
	await _key(KEY_Q)
	assert_eq(map.tab, MapModel.ROOF, "wraps round")
	await _key(KEY_2)
	assert_eq(map.tab, MapModel.BASEMENT, "2: the basement")
	var roof := map.tab_rect(MapModel.ROOF).get_center()
	await _mouse(MOUSE_BUTTON_LEFT, roof, true)
	await _mouse(MOUSE_BUTTON_LEFT, roof, false)
	assert_eq(map.tab, MapModel.ROOF, "a click on a tab")
	assert_true(map.is_open, "E (interact) turns pages here, it does not close the map")


func test_wheel_zooms_about_the_cursor_and_drag_pans() -> void:
	_map(Vector3(0.0, 0.0, 0.0))
	await get_tree().process_frame
	map.open()
	var cursor := Vector2(800.0, 450.0)
	var before := map.view.target_center + (cursor - map.view.screen_size * 0.5) / map.view.target_zoom
	var zoom := map.view.target_zoom
	await _mouse(MOUSE_BUTTON_WHEEL_UP, cursor, true)
	await _mouse(MOUSE_BUTTON_WHEEL_UP, cursor, false)
	assert_almost_eq(map.view.target_zoom, zoom * MuseumMap.WHEEL_STEP, 0.0001, "the wheel zooms in")
	var after := map.view.target_center + (cursor - map.view.screen_size * 0.5) / map.view.target_zoom
	assert_lt(after.distance_to(before), 0.5, "about the cursor")
	map.view.snap()
	var center := map.view.target_center
	await _mouse(MOUSE_BUTTON_LEFT, Vector2(900, 500), true)
	await _drag_by(Vector2(60.0, -30.0))
	await _mouse(MOUSE_BUTTON_LEFT, Vector2(960, 470), false)
	var moved := center - map.view.target_center
	assert_almost_eq(moved.x, 60.0 / map.view.target_zoom, 0.5, "the sheet follows the drag")
	assert_almost_eq(moved.y, -30.0 / map.view.target_zoom, 0.5)
	for i in 40:
		await get_tree().process_frame
	assert_lt(map.view.center.distance_to(map.view.target_center), 1.0, "and glides there")


func test_names_fade_in_with_zoom() -> void:
	_map()
	await get_tree().process_frame
	map.open()
	map.view.resize(Vector2(1920.0, 1080.0))   # a full HD screen, whatever the test window is
	map.view.look_at(map.view.center, map.view.fit_zoom())
	map.view.snap()
	await get_tree().process_frame
	var names := map.sheet_layer(&"names")
	var wings := map.sheet_layer(&"wings")
	assert_almost_eq(names.modulate.a, 0.0, 0.001, "no names when the whole sheet shows")
	assert_almost_eq(wings.modulate.a, 1.0, 0.001, "the wings' names in full")
	map.view.look_at(map.view.center, map.view.max_zoom())
	map.view.snap()
	await get_tree().process_frame
	assert_almost_eq(names.modulate.a, 1.0, 0.001, "every name close up")
	assert_lt(wings.modulate.a, 0.5, "the wings' names fade to a watermark")


func test_no_open_while_not_allowed() -> void:
	_map()
	map.can_open = func() -> bool: return false
	await get_tree().process_frame
	await _tap(&"map")
	assert_false(map.is_open)
	assert_false(get_tree().paused)


func test_layers_draw_once_not_per_frame() -> void:
	_map()
	await get_tree().process_frame
	map.open()
	for i in 3:
		await get_tree().process_frame
	var print_layer := map.sheet_layer(&"print")
	var drawn := print_layer.draws
	assert_gt(drawn, 0, "the print is drawn")
	map.view.look_at(Vector2(500, 500), map.view.max_zoom())
	for i in 20:
		await get_tree().process_frame
	assert_eq(print_layer.draws, drawn, "moving and zooming draws nothing again")
	await _key(KEY_E)
	await get_tree().process_frame
	assert_eq(print_layer.draws, drawn + 1, "a new page draws once")


# --- the pause menu and Floor I ------------------------------------------------------------

func test_the_pause_menu_opens_the_map_over_it() -> void:
	_map()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	await get_tree().process_frame
	pause_menu.open()
	var entry := pause_menu.get(&"_map_button") as Button
	assert_false(entry.visible, "no map entry without a map (the lobby)")
	pause_menu.close()
	pause_menu.museum_map = map
	pause_menu.open()
	assert_true(entry.visible, "the map's entry on Floor I")
	pause_menu.open_map()
	assert_true(map.is_open, "opens over the menu")
	assert_eq(GameInput.top_ui(), map)
	await _key(KEY_ESCAPE)
	assert_false(map.is_open, "Esc puts the map down")
	assert_true(pause_menu.is_open, "back to the menu")
	assert_true(get_tree().paused, "the game still waits")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameInput.top_ui(), pause_menu, "the menu has the input again")
	pause_menu.close()


func test_floor_one_installs_the_map() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(3)
	var installed := museum.floor_game.map
	assert_not_null(installed, "Floor I has its map")
	if installed != null:
		assert_eq(museum.pause_menu.museum_map, installed, "the pause menu opens it")
		assert_true(museum.hud.help_keys.has(MuseumMap.HELP_KEY), "the help panel names its key")
		await _tap(&"map")
		assert_true(installed.is_open, "M opens it in the game")
		assert_eq(installed.tab, MapModel.GROUND, "the night starts in the booth, on the ground floor")
		assert_true(installed.model.room(&"booth_security").look == MapModel.Look.PENCIL, "the booth pencilled in")
		await _tap(&"map")
		assert_false(installed.is_open)
	museum.free()
	await get_tree().process_frame


func test_the_lobby_has_no_map() -> void:
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	assert_eq(museum.find_children("*", "MuseumMap", true, false).size(), 0)
	assert_eq(museum.pause_menu.museum_map, null)
	museum.free()
	await get_tree().process_frame


# --- the map on the walls ----------------------------------------------------------------

func test_poster_is_a_board_with_the_printed_map_and_a_red_dot() -> void:
	var layout := Floor1Layout.create()
	var scene := MuseumMap.poster(layout)
	assert_not_null(scene, "a scene for the walls")
	var marker: Transform3D = layout.markers[&"museum_map_court"]
	var holder := Node3D.new()
	add_child(holder)
	var board := scene.instantiate() as MapPoster
	assert_not_null(board, "its root is a MapPoster")
	board.transform = marker
	holder.add_child(board)
	await get_tree().process_frame
	assert_not_null(board.sheet, "the printed sheet")
	assert_not_null(board.frame, "in a frame")
	var facing := board.sheet.global_transform.basis.z
	var into_room := -marker.basis.z
	assert_gt(facing.dot(into_room), 0.99, "the print faces the room")
	assert_not_null(board.dot, "a red dot: you are here")
	if board.dot != null:
		var expected := board.dot_position()
		assert_almost_eq(board.dot.position.x, expected.x, 0.0001)
		assert_almost_eq(board.dot.position.y, expected.y, 0.0001)
		# the dot's place on the sheet, seen from the room, is the board's place on the plan
		var seen := Vector2(0.5 - board.dot.position.x / MapPoster.sheet_size().x, 0.5 - board.dot.position.y / MapPoster.sheet_size().y)
		var on_plan := MapProjection.floor1().point(marker.origin) / MapStyle.SHEET
		assert_lt(seen.distance_to(on_plan), 0.001, "where the board hangs")
	holder.free()


func test_poster_is_cached_per_layout_and_language() -> void:
	var layout := Floor1Layout.create()
	var first := MuseumMap.poster(layout)
	assert_eq(MuseumMap.poster(Floor1Layout.create()), first, "the same floor: the same poster")
	var english := TranslationServer.get_locale() != "en"
	TranslationServer.set_locale("en" if english else "pl")
	assert_ne(MuseumMap.poster(layout), first, "another language: another print")
	TranslationServer.set_locale("pl" if english else "en")


func test_floor_one_hangs_a_map_on_every_museum_map_marker() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var markers := 0
	for marker: StringName in museum.floor_level.layout.markers:
		if String(marker).begins_with("museum_map_"):
			markers += 1
	assert_gt(markers, 3, "the havens and the booth have a marker")
	assert_eq(museum.find_children("*", "MapPoster", true, false).size(), markers, "a map on every one")
	museum.free()
	await get_tree().process_frame
