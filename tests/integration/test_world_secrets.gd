extends TestCase
## The lobby's secrets in the walls: the painting, the vent shaft, the
## crooked plaque and the broom closet, found with E and kept for good.

var bed: WorldTestbed


func _setup(secrets: Array[StringName] = []) -> void:
	GameState.secrets = secrets
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup()
	await physics_frames(2)


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


func _door(id: StringName) -> Door:
	return bed.level.doors[id]


func _open_path(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return bed.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func test_discovering_a_secret_counts_once_announces_and_saves() -> void:
	await _setup()
	var found := watch(bed.features.secret_discovered)
	assert_true(bed.features.discover_secret(LobbySecrets.PAINTING))
	assert_false(bed.features.discover_secret(LobbySecrets.PAINTING), "only once")
	assert_eq(found.size(), 1)
	assert_eq(found[0], [LobbySecrets.PAINTING, 1, 6, null])
	assert_true(GameState.secrets.has(LobbySecrets.PAINTING))
	assert_true(GameState.has_save(), "saved at once")
	var banner := bed.features.hud.current()
	assert_eq(banner[0], "Sekret odkryty (1/6)")
	assert_eq(banner[1], "Przejście za obrazem")


func test_the_painting_swings_away_from_the_passage() -> void:
	await _setup()
	var door := _door(&"panel_painting")
	assert_false(door.is_open)
	var prompt := await _use(Vector3(-37.8, 0.05, 6.5), Vector3(-40, 1.3, 6.5))
	assert_eq(prompt, "Zajrzyj za obraz")
	assert_true(door.is_open)
	assert_true(GameState.secrets.has(LobbySecrets.PAINTING))
	await physics_frames(80)
	assert_true(_open_path(Vector3(-37, 1.2, 6.5), Vector3(-43, 1.2, 6.5)), "the chamber lies open")
	assert_true(bed.features.switches[LobbySecrets.PAINTING].is_empty(), "its switch is gone")


func test_only_the_gallery_side_of_the_painting_is_a_switch() -> void:
	await _setup()
	var made: Array = bed.features.switches[LobbySecrets.PAINTING]
	assert_eq(made.size(), 1)


func test_the_vent_is_found_from_either_end() -> void:
	await _setup()
	var made: Array = bed.features.switches[LobbySecrets.VENT]
	assert_eq(made.size(), 4, "both faces of both grilles")
	# from the balcony: the upper grille
	var prompt := await _use(Vector3(-16.2, 6.05, 3.75), Vector3(-18.2, 7.0, 3.75))
	assert_eq(prompt, "Odkręć kratkę")
	assert_true(_door(&"panel_vent_out").is_open)
	assert_false(_door(&"panel_vent_in").is_open, "the lower grille waits")
	assert_true(GameState.secrets.has(LobbySecrets.VENT))
	assert_eq(bed.features.switches[LobbySecrets.VENT].size(), 2)
	# the lower grille from inside the shaft: pushed out, found no second time
	var found := watch(bed.features.secret_discovered)
	prompt = await _use(Vector3(-12.75, 0.05, 22.95), Vector3(-12.75, 1.0, 24.2))
	assert_eq(prompt, "Wypchnij kratkę")
	assert_true(_door(&"panel_vent_in").is_open)
	assert_eq(found.size(), 0)


func test_the_diorama_grille_opens_the_shaft() -> void:
	await _setup()
	var prompt := await _use(Vector3(-12.75, 0.05, 26.0), Vector3(-12.75, 1.0, 23.8))
	assert_eq(prompt, "Odkręć kratkę")
	assert_true(_door(&"panel_vent_in").is_open)
	assert_true(GameState.secrets.has(LobbySecrets.VENT))


func test_the_crooked_plaque_straightens_and_the_wall_slides() -> void:
	await _setup()
	var plaque := bed.features.plaque
	assert_not_null(plaque)
	assert_not_null(plaque.piece, "it dresses the level's plaque")
	var prompt := await _use(Vector3(38.2, 0.05, 1.6), Vector3(39.95, 1.55, 1.6))
	assert_eq(prompt, "Wyprostuj krzywą tabliczkę")
	assert_true(plaque.straight)
	await physics_frames(40)
	assert_true(_door(&"panel_plaque").is_open)
	assert_true(GameState.secrets.has(LobbySecrets.PLAQUE))


func test_the_closet_panel_reveals_a_haven() -> void:
	await _setup()
	var havens := watch(bed.features.haven_discovered)
	var prompt := await _use(Vector3(0, 6.05, -20.2), Vector3(0, 7.1, -22.0))
	assert_eq(prompt, "Opukaj panel")
	assert_true(_door(&"panel_closet").is_open)
	assert_true(GameState.secrets.has(LobbySecrets.CLOSET))
	assert_true(GameState.havens.has(&"closet"), "a start option from now on")
	assert_eq(havens.size(), 1)
	var titles: Array = bed.features.hud.announced.map(func(entry: PackedStringArray) -> String: return entry[1])
	assert_true(titles.has("Składzik na miotły"))
	assert_true(bed.features.hud.announced.any(func(entry: PackedStringArray) -> bool: return entry[0] == "Nowa przystań"))


func test_secrets_found_on_earlier_nights_stand_open() -> void:
	await _setup([LobbySecrets.PAINTING, LobbySecrets.VENT, LobbySecrets.PLAQUE, LobbySecrets.CLOSET] as Array[StringName])
	for id in [&"panel_painting", &"panel_vent_in", &"panel_vent_out", &"panel_plaque", &"panel_closet"]:
		assert_true(_door(id).is_open, "%s open" % id)
	assert_false(bed.features.switches.has(LobbySecrets.PAINTING))
	assert_false(bed.features.switches.has(LobbySecrets.VENT))
	assert_true(bed.features.plaque.straight)
	assert_eq(bed.features.plaque.collision_layer, 0, "no use-zone left")
	assert_false(bed.features.hud.is_busy(), "nothing announced")
