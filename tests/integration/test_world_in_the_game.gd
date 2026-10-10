extends TestCase
## The world content inside the game: the pause menu's list of notes read,
## the camera view shut by a lost focus pausing the game, what a resumed
## night keeps of it (artifacts held, the door the janitor's key opened),
## the artifact row under the HUD's corner, the padlock's hit.

var museum: Museum


func after_each() -> void:
	GameInput.pause_on_focus_loss = false
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	for exhibit in museum.enemies_root.get_children():
		exhibit.free()
	return museum


func _event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_event(action, true)
	await physics_frames(1)
	_event(action, false)
	await physics_frames(2)


func _resume() -> void:
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(3)


func test_the_pause_menu_lists_the_notes_read_and_opens_them_again() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var menu := museum.pause_menu
	menu.open()
	assert_false(menu._notes_button.visible, "no notes read: no list")
	menu.close()
	GameState.notes = [&"note_vent", &"note_1"] as Array[StringName]
	menu.open()
	assert_true(menu._notes_button.visible)
	menu.open_notes()
	assert_true(menu.notes_shown())
	assert_eq(menu.listed_notes(), [NoteCatalog.title(&"note_1"), NoteCatalog.title(&"note_vent")] as Array[String], "in reading order")
	var reader := museum.features.reader
	menu.read_note(&"note_vent")
	assert_true(reader.is_open, "the note again, over the menu")
	assert_gt(reader.layer, menu.layer)
	assert_eq(GameInput.top_ui(), reader)
	assert_true(get_tree().paused)
	# Esc puts the note down, back on the list; the menu stays
	await _tap(&"pause")
	assert_false(reader.is_open)
	assert_true(menu.is_open, "the Esc that put the note down leaves the menu open")
	assert_true(menu.notes_shown())
	assert_true(get_tree().paused, "the game stays paused under the menu")
	# Esc again: back to the menu's main panel; once more: play
	await _tap(&"pause")
	assert_false(menu.notes_shown())
	assert_true(menu.is_open)
	await _tap(&"pause")
	assert_false(menu.is_open)
	assert_false(get_tree().paused)


func test_a_click_on_a_note_over_the_menu_presses_nothing_under_it() -> void:
	GameState.new_game()
	GameState.notes = [&"note_1"] as Array[StringName]
	_museum()
	await physics_frames(2)
	var menu := museum.pause_menu
	var quits := watch(menu.quit_game_requested)
	menu.open()
	menu.open_notes()
	menu.read_note(&"note_1")
	var reader := museum.features.reader
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = get_viewport().get_visible_rect().size * 0.5
		click.global_position = click.position
		get_tree().root.push_input(click)
	await physics_frames(2)
	assert_false(reader.is_open, "the click put the note down")
	assert_true(menu.is_open)
	assert_eq(quits.size(), 0)
	menu.close()


func test_a_lost_focus_in_the_camera_view_pauses_the_game() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var view := museum.features.cctv.view
	museum.features.cctv.open_view(0)
	assert_true(view.is_open)
	GameInput.pause_on_focus_loss = true
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(view.is_open)
	assert_true(museum.pause_menu.is_open, "paused: the night does not run on unseen")
	assert_true(get_tree().paused)
	museum.pause_menu.close()


func test_a_resumed_night_keeps_the_artifacts_held_and_the_door_the_key_opened() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = 3
	for base in 600:
		GameState.seed_base = 9000 + base
		var config := NightDirector.plan(GameState.night_seed(), 3, description)
		if config.locked_door != &"" and config.artifacts.has(ArtifactCatalog.JANITOR_KEY):
			break
	GameState.save_game()
	_museum()
	await physics_frames(2)
	var features := museum.features
	assert_true(museum.night.artifacts.has(ArtifactCatalog.JANITOR_KEY), "a night with the key and a locked door")
	var key_spot := -1
	for spot: int in features.artifacts:
		if (features.artifacts[spot] as ArtifactPickup).artifact_id == ArtifactCatalog.JANITOR_KEY:
			key_spot = spot
	(features.artifacts[key_spot] as ArtifactPickup).interact(museum.player)
	assert_true(RunState.has_artifact(ArtifactCatalog.JANITOR_KEY))
	var door: Door = museum.lobby.doors[museum.night.locked_door]
	features.latches[0].interact(museum.player)
	assert_false(door.locked, "the key opened tonight's locked door")
	var held := RunState.artifacts.duplicate()
	await _resume()
	features = museum.features
	assert_eq(RunState.artifacts, held, "the artifacts held come back with the night")
	assert_false(features.artifacts.has(key_spot), "their cases stay empty")
	assert_eq(features.hud.shown_artifacts(), held)
	door = museum.lobby.doors[museum.night.locked_door]
	assert_false(door.locked, "the door stays open")
	assert_true(door.is_open)
	assert_eq(features.latches.size(), 0)


func test_the_artifact_row_sits_under_the_huds_corner() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	RunState.artifacts.append(ArtifactCatalog.SCARAB)
	var hud := museum.hud
	var row := museum.features.hud._icons
	hud.set_objective("Bardzo długi cel nocy, który się nie mieści w jednej linijce, naprawdę długi")
	await physics_frames(20)
	assert_gt(row.position.y, hud.top_left_bottom(), "under the goal")
	hud._help.visible = true   # F1
	await physics_frames(3)
	assert_gt(row.position.y, hud.top_left_bottom(), "under the help")
	hud._help.visible = false


func test_a_shot_padlock_is_a_hit_not_a_kill() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var hits := watch(Events.hit_landed)
	museum.features.padlock.take_damage(DamageInfo.make(10.0, DamageInfo.Kind.BALLISTIC, museum.player))
	assert_eq(hits.size(), 1)
	assert_eq(hits[0][2], false, "nothing was destroyed")
