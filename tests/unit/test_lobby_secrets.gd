extends TestCase
## The six lobby secrets and their record in the persistent state.

var game: PersistentState


func before_each() -> void:
	game = PersistentState.new()
	add_child(game)


func test_there_are_six_secrets() -> void:
	assert_eq(LobbySecrets.total(), 6)
	assert_eq(LobbySecrets.found(game), 0)


func test_a_secret_is_recorded_once() -> void:
	assert_true(LobbySecrets.discover(game, LobbySecrets.PAINTING))
	assert_false(LobbySecrets.discover(game, LobbySecrets.PAINTING), "found before")
	assert_eq(game.secrets, [LobbySecrets.PAINTING] as Array[StringName])
	assert_true(LobbySecrets.is_found(game, LobbySecrets.PAINTING))
	assert_eq(LobbySecrets.found(game), 1)


func test_unknown_ids_are_not_secrets() -> void:
	assert_false(LobbySecrets.discover(game, &"crystal"))
	assert_true(game.secrets.is_empty())


func test_found_counts_only_lobby_secrets() -> void:
	game.secrets = [&"vent", &"somewhere_else", &"notes"]
	assert_eq(LobbySecrets.found(game), 2)


func test_secrets_survive_a_save() -> void:
	game.file_path = SavePaths.save_file()
	LobbySecrets.discover(game, LobbySecrets.CLOSET)
	LobbySecrets.discover(game, LobbySecrets.VENT)
	game.save_game()
	var loaded := PersistentState.new()
	loaded.file_path = game.file_path
	add_child(loaded)
	assert_true(loaded.load_game())
	assert_eq(LobbySecrets.found(loaded), 2)
	assert_true(LobbySecrets.is_found(loaded, LobbySecrets.CLOSET))


func test_every_secret_has_a_name() -> void:
	for id in LobbySecrets.ALL:
		var key := LobbySecrets.name_key(id)
		assert_ne(tr(key), key, "translated " + key)


func test_world_sounds_are_generated() -> void:
	for sound in WorldSounds.NAMES:
		assert_true(ResourceLoader.exists(WorldSounds.PATH % sound), "no file for " + String(sound))
