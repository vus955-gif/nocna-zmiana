extends TestCase
## Every translation key the lobby's world content (src/world) names in
## code exists in locale/strings.csv with Polish and English text.

const CSV := "res://locale/strings.csv"
const KEY_PATTERN := "\"((?:SECRET|HAVEN|PROMPT|PLAQUE|NOTE|NOTES|ARTIFACT|CCTV|LOCKER|DRAWER|KEY|DOOR|WORLD)_[A-Z0-9_]+)\""


func _rows() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(CSV, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			rows[line[0]] = [line[1], line[2]]
	return rows


func test_every_world_key_exists_in_both_languages() -> void:
	var rows := _rows()
	var regex := RegEx.create_from_string(KEY_PATTERN)
	var checked := 0
	for file in DirAccess.get_files_at("res://src/world"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://src/world".path_join(file))
		for hit in regex.search_all(text):
			var key := hit.get_string(1)
			if key.ends_with("_"):
				continue   # a prefix put together in code
			checked += 1
			assert_true(rows.has(key), "%s uses unknown key %s" % [file, key])
			if rows.has(key):
				assert_ne(String(rows[key][0]).strip_edges(), "", "pl " + key)
				assert_ne(String(rows[key][1]).strip_edges(), "", "en " + key)
	assert_gt(checked, 5, "keys were found")


## WorldFeatures lays a note only where its title is in the translations:
## every note marker of Floor I has a title, a text and a signature.
func test_every_note_on_floor_one_has_its_text_in_both_languages() -> void:
	var layout := Floor1Layout.create()
	var checked := 0
	for language in ["pl", "en"]:
		Settings.set_value(&"language", language, false)
		for marker: StringName in layout.markers:
			if not String(marker).begins_with(WorldFeatures.NOTE_PREFIX):
				continue
			var id: StringName = WorldFeatures.NOTE_ALIASES.get(marker, marker)
			assert_true(NoteCatalog.is_note(id), "%s is a note" % marker)
			for key in [NoteCatalog.title_key(id), NoteCatalog.body_key(id), NoteCatalog.sign_key(id)]:
				assert_ne(tr(key), key, "%s in %s" % [key, language])
			assert_gt(tr(NoteCatalog.body_key(id)).length(), 60, "a real text: %s" % id)
			checked += 1
	Settings.set_value(&"language", "pl", false)
	assert_gt(checked, 60, "Floor I has its notes in both languages")


## A note on its own kind of paper is a note with a text (no paper for a
## marker that does not exist).
func test_every_paper_belongs_to_a_note_with_a_text() -> void:
	for id: StringName in NoteCatalog.PAPER:
		var key := NoteCatalog.title_key(id)
		assert_ne(tr(key), key, "%s has a title" % id)


func test_the_secret_banner_formats_its_count() -> void:
	assert_eq(tr("SECRET_FOUND") % [3, 6], "Sekret odkryty (3/6)")
	Settings.set_value(&"language", "en", false)
	assert_eq(tr("SECRET_FOUND") % [3, 6], "Secret found (3/6)")
	Settings.set_value(&"language", "pl", false)
