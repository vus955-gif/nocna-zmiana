extends TestCase
## Player-facing texts: locale/strings.csv (keys,pl,en) and its use in code.

const CSV := "res://locale/strings.csv"
## String literals in code that look like translation keys.
const KEY_PATTERN := "\"((?:HUD|MENU|OPT|UPG|PROMPT|DEATH|PAUSE|WEAPON|DEMO|TERMINAL|NIGHT|CONFIRM|LANG|HAVEN|LANTERN|SAVE|CAT)_[A-Z0-9_]+)\""


func after_each() -> void:
	Settings.reset_to_defaults(false)


## key -> [pl, en]
func _rows() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(CSV, FileAccess.READ)
	var header := file.get_csv_line()
	assert_eq(Array(header), ["keys", "pl", "en"], "CSV header")
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue
		if line.size() < 3:
			fail("short row: %s" % [line])
			continue
		if rows.has(line[0]):
			fail("duplicate key " + line[0])
		rows[line[0]] = [line[1], line[2]]
	return rows


func _source_files(dir_path: String, found: PackedStringArray) -> PackedStringArray:
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd") or file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	for sub in DirAccess.get_directories_at(dir_path):
		_source_files(dir_path.path_join(sub), found)
	return found


func test_every_key_has_polish_and_english_text() -> void:
	var rows := _rows()
	assert_gt(rows.size(), 10)
	for key in rows:
		assert_ne(rows[key][0].strip_edges(), "", "pl for " + key)
		assert_ne(rows[key][1].strip_edges(), "", "en for " + key)


func test_polish_is_the_default_locale() -> void:
	assert_eq(TranslationServer.get_locale().substr(0, 2), "pl")
	assert_eq(tr("MENU_NEW_GAME"), "Nowa gra")
	assert_eq(tr("WEAPON_PISTOL"), "Pistolet")


func test_english_switches_the_texts() -> void:
	Settings.set_value(&"language", "en", false)
	assert_eq(tr("MENU_NEW_GAME"), "New game")
	Settings.set_value(&"language", "pl", false)
	assert_eq(tr("MENU_NEW_GAME"), "Nowa gra")


func test_every_key_used_in_code_exists() -> void:
	var rows := _rows()
	var regex := RegEx.create_from_string(KEY_PATTERN)
	var checked := 0
	for path in _source_files("res://src", PackedStringArray()):
		var text := FileAccess.get_file_as_string(path)
		for match in regex.search_all(text):
			checked += 1
			var key := match.get_string(1)
			assert_true(rows.has(key), "%s uses unknown key %s" % [path.get_file(), key])
	assert_gt(checked, 5, "keys were found in the code")


func test_keys_built_at_runtime_exist() -> void:
	var rows := _rows()
	var keys: PackedStringArray = []
	for entry in UpgradeCatalog.all():
		keys.append(entry.name_key())
		keys.append(entry.desc_key())
	for category in UpgradeCatalog.CATEGORIES:
		keys.append(UpgradeCatalog.category_key(category))
	for id in Loadout.WEAPON_PATHS:
		keys.append((load(Loadout.WEAPON_PATHS[id]) as WeaponData).display_name)
		if id != &"taser":
			keys.append("PROMPT_TAKE_%s" % String(id).to_upper())   # WeaponPickup
	keys.append(WeaponHolder.FISTS.display_name)
	for notice in MainMenu.NOTICES.values():
		keys.append(notice)
	for language in SettingsData.LANGUAGES:
		keys.append("LANG_" + language.to_upper())
	keys.append_array(Coffee.all_keys())   # the café builds them at run time
	for key in keys:
		assert_true(rows.has(key), "missing " + key)


func test_placeholders_match_in_both_languages() -> void:
	var rows := _rows()
	# "%d", "%s", "%.2f", "%%"; a plain "15% faster" is no placeholder
	var placeholder := RegEx.create_from_string("%[-+0-9.]*[dsfxXcv%]")
	for key in rows:
		var pl: Array = placeholder.search_all(rows[key][0]).map(func(m: RegExMatch) -> String: return m.get_string().right(1))
		var en: Array = placeholder.search_all(rows[key][1]).map(func(m: RegExMatch) -> String: return m.get_string().right(1))
		assert_eq(pl, en, "%s: pl %s, en %s" % [key, pl, en])


func test_hud_help_is_translated() -> void:
	var hud := Hud.new()
	add_child(hud)
	var text := hud._help_label.text
	assert_true(text.begins_with("STEROWANIE"), text.substr(0, 40))
	Settings.set_value(&"language", "en", false)
	await get_tree().process_frame
	assert_true(hud._help_label.text.begins_with("CONTROLS"), "follows the language live")
