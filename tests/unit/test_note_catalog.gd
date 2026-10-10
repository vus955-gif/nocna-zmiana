extends TestCase
## The notes of the lobby: texts in both languages, the record of the ones
## read, and the night-shift set (secret 5).

var game: PersistentState


func before_each() -> void:
	game = PersistentState.new()
	add_child(game)


func after_each() -> void:
	Settings.reset_to_defaults(false)


func test_there_are_at_least_six_notes_each_on_its_paper() -> void:
	assert_gt(NoteCatalog.ALL.size(), 5)
	for id in NoteCatalog.ALL:
		assert_true(NoteCatalog.PAPER.has(id), "paper for " + String(id))
	for id in NoteCatalog.SET:
		assert_true(NoteCatalog.ALL.has(id))
	assert_eq(NoteCatalog.SET.size(), 3)
	assert_true(NoteCatalog.ALL.has(NoteCatalog.KEY_NOTE))
	assert_eq(NoteCatalog.paper(NoteCatalog.KEY_NOTE), NoteCatalog.Paper.STICKY)


func test_every_note_has_a_title_a_text_and_a_signature_in_both_languages() -> void:
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for id in NoteCatalog.ALL:
			for key in [NoteCatalog.title_key(id), NoteCatalog.body_key(id), NoteCatalog.sign_key(id)]:
				assert_ne(tr(key), key, "%s in %s" % [key, language])
			assert_gt(tr(NoteCatalog.body_key(id)).length(), 60, "a real text: " + String(id))


func test_heniek_points_to_the_till() -> void:
	var text := tr(NoteCatalog.body_key(NoteCatalog.KEY_NOTE))
	assert_true(text.contains("Klucz od szafki"), text)
	assert_true(text.contains("w kasie"), text)
	assert_eq(tr(NoteCatalog.sign_key(NoteCatalog.KEY_NOTE)), "— Heniek")


func test_a_note_is_recorded_once() -> void:
	assert_true(NoteCatalog.read(game, &"note_2"))
	assert_false(NoteCatalog.read(game, &"note_2"))
	assert_false(NoteCatalog.read(game, &"shopping_list"), "not a note")
	assert_eq(game.notes, [&"note_2"] as Array[StringName])
	assert_true(NoteCatalog.is_read(game, &"note_2"))


func test_the_set_is_complete_with_its_three_notes() -> void:
	NoteCatalog.read(game, &"note_1")
	NoteCatalog.read(game, &"note_chamber")
	NoteCatalog.read(game, &"note_3")
	assert_eq(NoteCatalog.set_read(game), 2)
	assert_false(NoteCatalog.set_complete(game))
	NoteCatalog.read(game, &"note_2")
	assert_true(NoteCatalog.set_complete(game))


func test_read_notes_come_in_reading_order() -> void:
	for id in [&"note_closet", &"note_1", &"note_key"]:
		NoteCatalog.read(game, id)
	assert_eq(NoteCatalog.read_notes(game), [&"note_key", &"note_1", &"note_closet"] as Array[StringName])
	assert_eq(NoteCatalog.title(&"note_1"), "Zasady nocnej zmiany")
