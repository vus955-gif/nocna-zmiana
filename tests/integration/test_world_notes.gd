extends TestCase
## Notes in the lobby and their reader; the till drawer with the gun locker
## key, and the locker with the pistol.

var bed: WorldTestbed


func _setup() -> void:
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup()
	await physics_frames(2)


func after_each() -> void:
	LobbyFeatures.include_locker = true


## Looks at [param target] from [param at], waits for the probe, presses E.
## Returns the prompt that was in focus ("" when nothing was).
func _use(at: Vector3, target: Vector3) -> String:
	bed.place_guard(at, target)
	await physics_frames(3)
	var focus := bed.player.interactor.focus
	var prompt := focus.prompt() if focus != null else ""
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	await physics_frames(1)
	return prompt


## Sends an action as a real input event (the reader listens for events).
func _event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_every_note_lies_in_its_room() -> void:
	await _setup()
	var rooms := {
		&"note_key": &"security", &"note_1": &"security", &"note_2": &"armory", &"note_3": &"balcony",
		&"note_chamber": &"secret_chamber", &"note_niche": &"shotgun_niche", &"note_vent": &"vent", &"note_closet": &"closet",
	}
	assert_eq(bed.features.notes.size(), rooms.size())
	for id: StringName in rooms:
		var note: NotePaper = bed.features.notes.get(id)
		assert_not_null(note, String(id))
		if note != null:
			assert_eq(bed.level.room_at(note.global_position + Vector3.UP * 0.05), rooms[id], String(id))


func test_reading_a_note_records_it_and_pauses_the_game() -> void:
	await _setup()
	var read := watch(bed.features.note_read)
	var prompt := await _use(Vector3(0, 0.05, 59.2), Vector3(0.9, 0.8, 60.2))
	assert_eq(prompt, "Przeczytaj notatkę")
	var reader := bed.features.reader
	assert_true(reader.is_open)
	assert_eq(reader.note_id, &"note_1")
	assert_true(get_tree().paused)
	assert_eq(GameInput.top_ui(), reader)
	assert_true(GameState.notes.has(&"note_1"))
	assert_eq(read.size(), 1)
	assert_eq(reader._title.text, "Zasady nocnej zmiany")
	assert_eq(reader._caption.text, "NOTATKI NOCNEJ ZMIANY · 1/3")
	assert_true(GameState.has_save(), "saved")


func test_e_puts_the_note_down_and_never_opens_it_again() -> void:
	await _setup()
	bed.place_guard(Vector3(0, 0.05, 59.2), Vector3(0.9, 0.8, 60.2))
	await physics_frames(3)
	var reader := bed.features.reader
	var opened := watch(reader.opened)
	bed.features.read_note(&"note_1")
	await physics_frames(2)
	_event(&"interact", true)
	await physics_frames(1)
	assert_false(reader.is_open, "E closes")
	assert_false(get_tree().paused)
	assert_true(reader.is_holding_input(), "the guard waits for E to come up")
	assert_false(GameInput.gameplay_input())
	await physics_frames(6)
	assert_false(reader.is_open, "held E does not reopen the note in focus")
	_event(&"interact", false)
	await physics_frames(3)
	assert_false(reader.is_holding_input())
	assert_true(GameInput.gameplay_input(), "input back")
	await physics_frames(4)
	assert_false(reader.is_open)
	assert_eq(opened.size(), 1)


func test_escape_puts_the_note_down() -> void:
	await _setup()
	var pause_menu := PauseMenu.new()
	bed.add_child(pause_menu)   # after the reader: it hears Esc first
	var reader := bed.features.reader
	bed.features.read_note(&"note_vent")
	assert_true(reader.is_open)
	assert_eq(reader._title.text, "Zlecenie serwisowe nr 117")
	_event(&"pause", true)
	await physics_frames(1)
	assert_false(reader.is_open)
	assert_false(pause_menu.is_open, "the Esc that put the note down opens no pause menu")
	_event(&"pause", false)
	await physics_frames(2)
	assert_false(pause_menu.is_open)
	assert_true(GameInput.gameplay_input(), "the key is up: input back, no extra step")


func test_the_three_night_shift_notes_make_a_secret() -> void:
	await _setup()
	var reader := bed.features.reader
	for id in [&"note_1", &"note_key", &"note_2"]:
		bed.features.read_note(id)
		reader.close()
	assert_false(GameState.secrets.has(LobbySecrets.NOTES))
	bed.features.read_note(&"note_3")
	assert_false(GameState.secrets.has(LobbySecrets.NOTES), "not while reading")
	reader.close()
	assert_true(GameState.secrets.has(LobbySecrets.NOTES), "the last one put down")
	assert_eq(bed.features.hud.announced.back()[1], "Notatki nocnej zmiany")


func test_the_till_drawer_holds_the_locker_key() -> void:
	await _setup()
	var found := watch(bed.features.key_found)
	var prompt := await _use(Vector3(-9.5, 0.05, 18.9), Vector3(-9.5, 0.95, 17.3))
	assert_eq(prompt, "Otwórz szufladę kasy")
	assert_true(GameState.pistol_key)
	assert_eq(found.size(), 1)
	assert_true(bed.features.drawer.is_open)
	assert_true(bed.features.locker.unlocked, "the locker takes the key")
	assert_eq(bed.features.hud.current()[1], "Klucz do szafki na broń")
	prompt = await _use(Vector3(-9.5, 0.05, 18.9), Vector3(-9.5, 0.95, 17.3))
	assert_eq(prompt, "", "an open drawer is not a prompt any more")
	assert_eq(found.size(), 1)


func test_the_locker_refuses_without_the_key_and_gives_the_pistol_with_it() -> void:
	await _setup()
	var locker := bed.features.locker
	var at := Vector3(3.0, 0.05, locker.global_position.z)
	var prompt := await _use(at, locker.global_position)
	assert_eq(prompt, "Otwórz szafkę na broń")
	assert_false(locker.is_open)
	assert_eq(bed.features.hud.current()[0], "Zamknięte na klucz")
	await _use(at, locker.global_position)
	assert_eq(bed.features.hud.announced.size(), 1, "rattling again does not stack the message")
	bed.features._on_key_found()
	prompt = await _use(at, locker.global_position)
	assert_eq(prompt, "Otwórz szafkę kluczem")
	assert_true(locker.is_open)
	var pistol := bed.features.pistol
	assert_not_null(pistol)
	await physics_frames(40)
	prompt = await _use(at, pistol.global_position + Vector3.UP * 0.4)
	assert_eq(prompt, "Weź pistolet")
	assert_true(GameState.has_weapon(&"pistol"))
	assert_true(bed.player.weapons.has_weapon(&"pistol"))


func test_on_later_nights_the_drawer_holds_a_joke_and_the_locker_opens_at_once() -> void:
	GameState.pistol_key = true
	await _setup()
	var drawer := bed.features.drawer
	var locker := bed.features.locker
	assert_false(drawer.is_open, "shut again, still a use-zone")
	assert_false(locker.is_open, "shut, but the lamp is green")
	assert_true(locker.unlocked)
	assert_true(bed.features.pistol == null, "the pistol waits behind the door")
	assert_false(bed.features.notes.has(NoteCatalog.KEY_NOTE), "Heniek's note is gone")
	var found := watch(bed.features.key_found)
	var prompt := await _use(Vector3(-9.5, 0.05, 18.9), Vector3(-9.5, 0.95, 17.3))
	assert_eq(prompt, "Otwórz szufladę kasy")
	assert_true(drawer.is_open)
	assert_eq(found.size(), 0, "no second key")
	assert_eq(bed.features.hud.current()[1], tr("DRAWER_EMPTY"), "old tickets and a button")
	var at := Vector3(3.0, 0.05, locker.global_position.z)
	prompt = await _use(at, locker.global_position)
	assert_eq(prompt, "Otwórz szafkę kluczem")
	assert_true(locker.is_open)
	assert_not_null(bed.features.pistol, "the pistol waits until taken")


func test_the_locker_is_the_arts_wall_cabinet_with_the_pistol_on_its_felt() -> void:
	GameState.pistol_key = true
	await _setup()
	var locker := bed.features.locker
	assert_not_null(locker.model, "the art's pistol_locker")
	assert_eq(bed.level.room_at(locker.global_position), &"security")
	locker.interact(bed.player)
	await physics_frames(60)
	var door := locker.model.find_child("door", true, false) as Node3D
	assert_almost_eq(door.rotation_degrees.y, PropArt.LOCKER_OPEN_DEG, 1.0, "the door swung open")
	var pistol := bed.features.pistol
	assert_not_null(pistol)
	assert_eq(pistol.game, GameState, "the pickup belongs to the game")
	assert_eq(pistol.run, RunState)
	var on_felt := locker.find_child("PistolOnFelt", true, false) as Node3D
	assert_not_null(on_felt, "the pistol lies on the felt")
	assert_true(on_felt.is_visible_in_tree())
	pistol.interact(bed.player)
	await physics_frames(2)
	assert_false(on_felt.is_visible_in_tree(), "taken")
	assert_true(bed.player.weapons.has_weapon(&"pistol"))


func test_without_the_model_the_locker_is_a_greybox_door() -> void:
	GameState.pistol_key = true
	ArtLibrary.models_enabled = false
	await _setup()
	ArtLibrary.models_enabled = true
	var locker := bed.features.locker
	assert_true(locker.model == null)
	locker.interact(bed.player)
	await physics_frames(40)
	assert_true(locker.is_open)
	assert_not_null(bed.features.pistol)


func test_a_click_puts_the_note_down() -> void:
	await _setup()
	var reader := bed.features.reader
	bed.features.read_note(&"note_2")
	await physics_frames(2)
	assert_true(reader.is_open)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = Vector2(30, 30)
		click.global_position = Vector2(30, 30)
		get_tree().root.push_input(click)
	await physics_frames(2)
	assert_false(reader.is_open, "a click anywhere puts it down")
	assert_false(get_tree().paused)


func test_every_note_fits_the_screen_in_both_languages() -> void:
	await _setup()
	var reader := bed.features.reader
	for locale in ["pl", "en"]:
		Settings.set_value(&"language", locale, false)
		for id in NoteCatalog.ALL:
			reader.open_note(id)
			for i in 3:
				await get_tree().process_frame
			var screen := reader._root.size
			var sheet := reader.paper_rect()
			assert_gt(sheet.position.y, 0.0, "%s %s: the top shows" % [locale, id])
			assert_lt(sheet.end.y, screen.y - 40.0, "%s %s: the bottom shows (%.0f of %.0f)" % [locale, id, sheet.end.y, screen.y])
			assert_lt(reader._hint.position.y + reader._hint.size.y, screen.y, "%s %s: the hint shows" % [locale, id])
			reader.close()
			GameInput.clear_ui()
			get_tree().paused = false
			await get_tree().process_frame
	Settings.set_value(&"language", "pl", false)
	assert_true(reader._hint.text.contains(GameInput.key_label(&"interact").to_upper()), "the hint names the real keys")


func test_the_reader_lies_over_the_pause_menu() -> void:
	await _setup()
	var pause_menu := PauseMenu.new()
	bed.add_child(pause_menu)
	assert_gt(bed.features.reader.layer, pause_menu.layer)


func test_a_taken_pistol_is_not_there_again() -> void:
	GameState.pistol_key = true
	GameState.weapons = [&"pistol"] as Array[StringName]
	await _setup()
	assert_true(bed.features.pistol == null)


func test_a_host_with_its_own_locker_leaves_it_out() -> void:
	LobbyFeatures.include_locker = false
	await _setup()
	assert_true(bed.features.drawer == null)
	assert_true(bed.features.locker == null)
	assert_false(bed.features.notes.has(NoteCatalog.KEY_NOTE))
	assert_true(bed.features.notes.has(&"note_1"))
