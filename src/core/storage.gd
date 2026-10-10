extends Node
## Prepares the game's storage before anything else (autoload "Storage",
## first in the list): removes the empty folder Godot creates in the
## Windows user folder at every start and starts the game's log file next
## to the save (see SavePaths). Test and scenario runs keep no log file.

var _log: GameLog = null


func _enter_tree() -> void:
	SavePaths.tidy_engine_user_dir()
	if not SavePaths.is_test_run():
		_log = GameLog.open(SavePaths.log_dir())
		if _log != null:
			OS.add_logger(_log)


func _exit_tree() -> void:
	if _log != null:
		OS.remove_logger(_log)
		_log.close()
		_log = null
