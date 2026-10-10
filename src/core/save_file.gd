class_name SaveFile
## Crash-safe file helpers for the save and the settings.
## A write goes to <path>.tmp, is read back and compared, the old file is
## kept as <path>.bak and only then is the .tmp renamed to <path>. Renames
## are retried for a moment (on Windows a virus scanner or the search
## indexer may hold a file briefly, and a rename over an existing file is
## not atomic there).
## Readers try <path>, then <path>.tmp, then <path>.bak, so an interrupted
## write or a failed rename never loses the last good copy; a good .tmp
## without a main file (a save that stopped right before its rename) is
## renamed to <path>.

const TMP := ".tmp"
const BAK := ".bak"
const BAD := ".bad"
## A rename is tried this many times, RETRY_MSEC apart.
const RETRIES := 10
const RETRY_MSEC := 20


## Writes [param text] safely. Returns false when anything failed; the last
## good copy is then still found by read_text().
static func write_text(path: String, text: String) -> bool:
	var tmp := path + TMP
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(text)
	file.close()
	if not stored or _read(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path) and not move(path, path + BAK):
		DirAccess.remove_absolute(tmp)
		return false
	return move(tmp, path)


## The text of the first copy of [param path] (main, .tmp, .bak) that is
## readable, not empty and accepted by [param accept] (text -> bool; any
## text when not given). "" when there is none.
static func read_text(path: String, accept: Callable = Callable()) -> String:
	for candidate in candidates(path):
		var text := _read(candidate)
		if text == "" or (accept.is_valid() and not accept.call(text)):
			continue
		if candidate == path + TMP and not FileAccess.file_exists(path):
			move(candidate, path)
		return text
	return ""


## The parsed JSON of the first copy of [param path] that parses (null when
## none does).
static func read_json(path: String) -> Variant:
	var text := read_text(path, func(candidate: String) -> bool: return parse_json_text(candidate) != null)
	return parse_json_text(text) if text != "" else null


## The copies of [param path] in the order readers try them.
static func candidates(path: String) -> PackedStringArray:
	return PackedStringArray([path, path + TMP, path + BAK])


## True when [param path] is a file that can be opened for reading.
static func readable(path: String) -> bool:
	return FileAccess.open(path, FileAccess.READ) != null


## The parsed JSON of one file (null when missing, unreadable or broken).
static func parse_json_file(path: String) -> Variant:
	var text := _read(path)
	return parse_json_text(text) if text != "" else null


static func parse_json_text(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Moves a broken file aside as <path>.bad (replacing an older one). False
## when that failed; the file is then left where it was.
static func quarantine(path: String) -> bool:
	return FileAccess.file_exists(path) and move(path, path + BAD)


static func write_json(path: String, data: Dictionary) -> bool:
	return write_text(path, JSON.stringify(data, "\t"))


## Renames [param from] to [param to] (replacing it), retrying for a moment.
static func move(from: String, to: String) -> bool:
	for attempt in RETRIES:
		if DirAccess.rename_absolute(from, to) == OK:
			return true
		if attempt < RETRIES - 1:
			OS.delay_msec(RETRY_MSEC)
	return false


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
