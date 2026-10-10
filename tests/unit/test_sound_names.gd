extends TestCase
## Every sound the code asks for by name is registered in Sfx.SOUNDS (loaded
## up front) and generated. Catches typos: a missing sound plays silently.

const PATTERNS: Array[String] = [
	r'Sfx\.play(?:_at)?\(&"([a-z_0-9]+)"',
	r'(?:notice_sound|break_sound)\s*(?::\s*StringName\s*)?=\s*&"([a-z_0-9]+)"',
]


func test_every_named_sound_is_registered_and_generated() -> void:
	var found := 0
	for path in _scripts("res://src"):
		var source := FileAccess.get_file_as_string(path)
		for pattern in PATTERNS:
			var regex := RegEx.create_from_string(pattern)
			for hit in regex.search_all(source):
				var sound := StringName(hit.get_string(1))
				found += 1
				assert_true(Sfx.SOUNDS.has(sound), "%s plays unregistered '%s'" % [path.get_file(), sound])
				assert_true(ResourceLoader.exists("res://assets/sfx/%s.wav" % sound), "no file for '%s'" % sound)
	assert_gt(found, 20, "the scan finds the sound calls")


func _scripts(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for file in dir.get_files():
		if file.ends_with(".gd"):
			files.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		files.append_array(_scripts(dir_path.path_join(sub)))
	return files
