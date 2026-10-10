extends TestCase
## Save locations, crash-safe writes and what reaches the Windows user
## folder (nothing).


func test_test_runs_never_use_the_real_save_dir() -> void:
	assert_true(SavePaths.is_test_run())
	var dir := SavePaths.dir().replace("\\", "/")
	assert_true(dir.ends_with("tests/_out/saves"), dir)
	assert_true(SavePaths.save_file().begins_with(SavePaths.dir()))
	assert_true(SavePaths.settings_file().begins_with(SavePaths.dir()))


func test_the_test_runner_is_recognised_from_any_form_of_its_path() -> void:
	assert_true(SavePaths.uses_test_dir())
	var absolute := ProjectSettings.globalize_path("res://tests/test_runner.tscn")
	assert_eq(SavePaths._localized(absolute), "res://tests/test_runner.tscn")
	assert_eq(SavePaths._localized(absolute.replace("/", "\\")), "res://tests/test_runner.tscn")
	assert_eq(SavePaths._localized("tests/test_runner.tscn"), "res://tests/test_runner.tscn")
	assert_eq(SavePaths._localized("res://tests/test_runner.tscn"), "res://tests/test_runner.tscn")
	assert_false(SavePaths._localized("--headless").begins_with("res://tests/"))


func test_redirected_saves_are_not_a_test_run() -> void:
	assert_false(SavePaths.is_redirected())
	OS.set_environment("NZ_SAVE_DIR", SavePaths.test_dir())
	assert_true(SavePaths.is_redirected())
	assert_eq(SavePaths._explicit_dir(), SavePaths.test_dir())
	OS.unset_environment("NZ_SAVE_DIR")
	assert_false(SavePaths.is_redirected())
	assert_true(SavePaths.is_test_run(), "decided by the start scene only")


func test_atomic_write_replaces_the_file_and_leaves_no_tmp() -> void:
	var path := SavePaths.dir().path_join("atomic.txt")
	assert_true(SaveFile.write_text(path, "first"))
	assert_true(SaveFile.write_text(path, "second"))
	assert_eq(SaveFile.read_text(path), "second")
	assert_false(FileAccess.file_exists(path + ".tmp"))


func test_a_write_keeps_the_previous_copy_as_bak() -> void:
	var path := SavePaths.dir().path_join("kept.txt")
	assert_true(SaveFile.write_text(path, "one"))
	assert_true(SaveFile.write_text(path, "two"))
	assert_eq(FileAccess.get_file_as_string(path), "two")
	assert_eq(FileAccess.get_file_as_string(path + ".bak"), "one")
	assert_false(FileAccess.file_exists(path + ".tmp"))


func test_readers_fall_back_to_tmp_then_bak() -> void:
	var path := SavePaths.dir().path_join("fallback.json")
	SaveFile.write_json(path, {"n": 1})
	SaveFile.write_json(path, {"n": 2})
	_raw(path, "{broken")
	assert_eq(SaveFile.read_json(path)["n"], 1, "the .bak copy")
	_raw(path + ".tmp", "{\"n\": 3}")
	assert_eq(SaveFile.read_json(path)["n"], 3, ".tmp comes before .bak")
	var numbers_only := func(text: String) -> bool: return text.is_valid_int()
	_raw(path + ".bak", "42")
	assert_eq(SaveFile.read_text(path, numbers_only), "42", "the first copy the caller accepts")


func test_a_good_tmp_without_a_main_file_is_promoted() -> void:
	var path := SavePaths.dir().path_join("promoted.json")
	_raw(path + ".tmp", "{\"n\": 7}")
	assert_eq(SaveFile.read_json(path)["n"], 7)
	assert_true(FileAccess.file_exists(path), "the interrupted rename is finished")
	assert_false(FileAccess.file_exists(path + ".tmp"))


func test_a_failed_rename_leaves_the_old_file_and_no_tmp() -> void:
	var path := SavePaths.dir().path_join("stuck.txt")
	assert_true(SaveFile.write_text(path, "old"))
	DirAccess.remove_absolute(path + ".bak")
	DirAccess.make_dir_recursive_absolute(path + ".bak")   # the old copy cannot be moved aside
	assert_false(SaveFile.write_text(path, "new"))
	assert_eq(SaveFile.read_text(path), "old")
	assert_false(FileAccess.file_exists(path + ".tmp"))
	DirAccess.remove_absolute(path + ".bak")


func test_quarantine_keeps_a_bad_copy() -> void:
	var path := SavePaths.dir().path_join("broken.json")
	SaveFile.write_text(path, "{not json")
	assert_true(SaveFile.quarantine(path))
	assert_false(FileAccess.file_exists(path), "moved, not copied")
	assert_eq(SaveFile.read_text(path + ".bad"), "{not json")
	assert_eq(SaveFile.read_json(path), null, "broken JSON reads as null")


func test_a_failed_quarantine_leaves_the_file() -> void:
	var path := SavePaths.dir().path_join("moved.json")
	_raw(path, "{bad")
	DirAccess.make_dir_recursive_absolute(path + ".bad")
	assert_false(SaveFile.quarantine(path), "a folder is in the way")
	assert_eq(FileAccess.get_file_as_string(path), "{bad", "the file stays")
	DirAccess.remove_absolute(path + ".bad")


func test_json_round_trip() -> void:
	var path := SavePaths.dir().path_join("data.json")
	assert_true(SaveFile.write_json(path, {"night": 3, "list": ["a"]}))
	var data: Variant = SaveFile.read_json(path)
	assert_eq(typeof(data), TYPE_DICTIONARY)
	if data is Dictionary:
		assert_eq(data["night"], 3)
		assert_eq(data["list"], ["a"])


func test_only_an_empty_engine_user_folder_is_removed() -> void:
	var folder := SavePaths.test_dir().get_base_dir().path_join("fake_user_dir")
	DirAccess.make_dir_recursive_absolute(folder.path_join("objectdb_snapshots"))
	SavePaths.tidy_engine_user_dir(folder)
	assert_false(DirAccess.dir_exists_absolute(folder), "empty: gone, leftovers included")
	DirAccess.make_dir_recursive_absolute(folder.path_join("shader_cache"))
	SavePaths.tidy_engine_user_dir(folder)
	assert_true(DirAccess.dir_exists_absolute(folder.path_join("shader_cache")), "anything else: untouched")
	DirAccess.remove_absolute(folder.path_join("shader_cache"))
	DirAccess.remove_absolute(folder)


func test_the_game_log_is_written_next_to_the_save() -> void:
	var dir := SavePaths.dir().path_join("log_test")
	var log_file := GameLog.open(dir)
	assert_not_null(log_file)
	if log_file == null:
		return
	log_file._log_message("hello\n", false)
	log_file._log_error("f", "file.gd", 3, "code", "went wrong", false, Logger.ERROR_TYPE_WARNING, [] as Array[ScriptBacktrace])
	log_file.close()
	var text := FileAccess.get_file_as_string(dir.path_join(GameLog.FILE_NAME))
	assert_true(text.begins_with("hello\n"), text)
	assert_true(text.contains("WARNING: went wrong"), text)
	GameLog.open(dir).close()
	assert_true(FileAccess.file_exists(dir.path_join(GameLog.PREVIOUS_NAME)), "the last run's log is kept")
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func test_the_engine_keeps_nothing_in_the_user_folder() -> void:
	assert_false(ProjectSettings.get_setting_with_override("debug/file_logging/enable_file_logging"), "no engine log")
	assert_true(ProjectSettings.get_setting("application/config/use_custom_user_dir"))
	assert_false(ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled.template"), "no shader cache in the exported game")
	assert_false(ProjectSettings.get_setting("rendering/rendering_device/pipeline_cache/enable.template"), "no pipeline cache in the exported game")
	assert_false(SavePaths.uses_user_dir())


func _raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
