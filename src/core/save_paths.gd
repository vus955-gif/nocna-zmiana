class_name SavePaths
## Where the save, the settings and the log live. Everything the game
## writes goes to the game's own drive, never to the Windows user folder:
## - Exported game: a "save" folder next to the exe (portable).
## - Editor-binary builds (Graj.bat, the tools): tools/godot/editor_data/
##   nz_save, next to the engine's own self-contained editor_data.
## - Test and scenario runs (a start scene under res://tests/): the test
##   folder, never a real save.
## - --save-dir=<dir> or NZ_SAVE_DIR=<dir>: that folder (any build).
## Only when the game's folder cannot be written to (e.g. installed under
## Program Files, or started from inside a zip, which Windows unpacks into
## the temp folder that it empties) does the save fall back to Godot's user
## folder (%APPDATA%\Nocna Zmiana).
## The engine itself would write its log and its shader and pipeline caches
## to that user folder as well; project.godot turns its file log off (the
## game logs through GameLog, into dir()/logs), the exported build keeps no
## shader or pipeline cache, and the dev tools point APPDATA at
## tools/godot/editor_data/appdata (tools/dev_env.sh, Graj.bat).

const TEST_DIR := "res://tests/_out/saves"
const SAVE_NAME := "save.json"
const SETTINGS_NAME := "settings.cfg"
const LOG_DIR := "logs"
## Folder (next to the engine exe) of editor-binary runs.
const DEV_DIR := "editor_data/nz_save"
## Folder (next to the game exe) of the exported game.
const PORTABLE_DIR := "save"
## Empty folders the engine leaves in its user folder.
const ENGINE_LEFTOVERS: Array[String] = ["objectdb_snapshots"]

## Forces a directory (absolute, res:// or user://). Wins over everything.
static var override_dir: String = ""
static var _resolved: String = ""


## Absolute path of the save directory (created if missing).
static func dir() -> String:
	var path := _absolute(override_dir) if override_dir != "" else _default_dir()
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path


static func save_file() -> String:
	return dir().path_join(SAVE_NAME)


static func settings_file() -> String:
	return dir().path_join(SETTINGS_NAME)


static func log_dir() -> String:
	return dir().path_join(LOG_DIR)


static func test_dir() -> String:
	return _absolute(TEST_DIR)


## True for the headless test runner and the visual scenarios: their start
## scene lives under res://tests/ (given as res://, relative or absolute
## path). Such runs never touch a real save and never change the window.
static func is_test_run() -> bool:
	for arg in OS.get_cmdline_args():
		if _localized(arg).begins_with("res://tests/"):
			return true
	return false


## True when --save-dir or NZ_SAVE_DIR chose the folder (the game still
## behaves normally otherwise: window mode, V-Sync).
static func is_redirected() -> bool:
	return _explicit_dir() != ""


## True when the saves of this run go to the test folder (the test runner
## refuses to start otherwise).
static func uses_test_dir() -> bool:
	return override_dir == "" and _default_dir() == test_dir()


## True when the saves go to Godot's user folder (the fallback).
static func uses_user_dir() -> bool:
	var user := _absolute("user://").trim_suffix("/").to_lower()
	var saves := dir().trim_suffix("/").to_lower()
	return saves == user or saves.begins_with(user + "/")


## Empties the test save directory (never a real one).
static func clear_test_dir() -> void:
	var path := test_dir()
	var out := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(path)
	# keep the editor's file scanner out of test output
	if not FileAccess.file_exists(out.path_join(".gdignore")):
		var ignore := FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
		if ignore != null:
			ignore.close()
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))


## Godot creates its user folder (%APPDATA%\Nocna Zmiana, on C:) at every
## start even when nothing is written there. Unless the save really lives
## there (the fallback), an empty one is removed again, together with the
## empty folders the engine and the editor leave in it. A folder with
## anything else inside is never touched. ([param folder]: tests pass a
## stand-in for the user folder.)
static func tidy_engine_user_dir(folder: String = "") -> void:
	if uses_user_dir():
		return
	var user := (folder if folder != "" else OS.get_user_data_dir()).trim_suffix("/")
	if not DirAccess.dir_exists_absolute(user):
		return
	for leftover in ENGINE_LEFTOVERS:
		var path := user.path_join(leftover)
		if DirAccess.dir_exists_absolute(path) and _is_empty(path):
			DirAccess.remove_absolute(path)
	if _is_empty(user):
		DirAccess.remove_absolute(user)


static func _default_dir() -> String:
	if _resolved != "":
		return _resolved
	var explicit := _explicit_dir()
	if explicit != "":
		_resolved = _absolute(explicit)
	elif is_test_run():
		_resolved = test_dir()
	else:
		var exe_dir := OS.get_executable_path().get_base_dir()
		var own := exe_dir.path_join(PORTABLE_DIR if OS.has_feature("template") else DEV_DIR)
		_resolved = own if not _in_temp(exe_dir) and _writable(own) else _absolute("user://")
	return _resolved


static func _explicit_dir() -> String:
	var explicit := _user_arg("--save-dir=")
	return explicit if explicit != "" else OS.get_environment("NZ_SAVE_DIR")


static func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	return path.replace("\\", "/").simplify_path()


## [param arg] as a res:// path when it names a file of the project.
static func _localized(arg: String) -> String:
	var path := arg.replace("\\", "/")
	if path.begins_with("res://") or not path.contains("/"):
		return path
	if path.is_relative_path():
		return "res://" + path.simplify_path()
	return ProjectSettings.localize_path(path.simplify_path())


static func _user_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


static func _in_temp(path: String) -> bool:
	var temp := OS.get_temp_dir().replace("\\", "/").simplify_path().to_lower()
	return temp != "" and path.replace("\\", "/").to_lower().begins_with(temp + "/")


static func _writable(path: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		return false
	var probe_path := path.path_join(".write_test")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(probe_path)
	return true


static func _is_empty(path: String) -> bool:
	return DirAccess.get_files_at(path).is_empty() and DirAccess.get_directories_at(path).is_empty()
