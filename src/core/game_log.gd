class_name GameLog
extends Logger
## The game's log file: everything printed and every warning and error go
## to <save dir>/logs/godot.log (the previous run's log is kept as
## godot.previous.log). It stands in for the engine's own file log, which
## could only live in Godot's user folder on C: and is turned off in
## project.godot. The engine may call a Logger from any thread.

const FILE_NAME := "godot.log"
const PREVIOUS_NAME := "godot.previous.log"
## Logger.ErrorType -> label.
const KINDS: Array[String] = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

var _file: FileAccess = null
var _mutex := Mutex.new()
## Set while writing: a message about a failed write is dropped instead of
## writing it (and failing) again.
var _writing: bool = false


## Starts a new log in [param dir]. Null when it cannot be written.
static func open(dir: String) -> GameLog:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return null
	var path := dir.path_join(FILE_NAME)
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, dir.path_join(PREVIOUS_NAME))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return null
	var logger := GameLog.new()
	logger._file = file
	return logger


func close() -> void:
	_mutex.lock()
	if _file != null:
		_file.close()
		_file = null
	_mutex.unlock()


func _log_message(message: String, error: bool) -> void:
	_write(message, error)


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind := KINDS[error_type] if error_type >= 0 and error_type < KINDS.size() else KINDS[0]
	_write("%s: %s\n   at: %s (%s:%d)\n" % [kind, rationale if rationale != "" else code, function, file, line], true)


func _write(text: String, flush: bool) -> void:
	_mutex.lock()
	if _file != null and not _writing:
		_writing = true
		_file.store_string(text)
		if flush:
			_file.flush()
		_writing = false
	_mutex.unlock()
