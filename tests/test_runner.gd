extends Node
## Headless test runner. Runs every test_* method of every
## tests/unit/test_*.gd and tests/integration/test_*.gd script, prints a
## report and quits with exit code 0 (all passed) or 1.
## Filter by file name:  bash tools/run_tests.sh --filter=stamina
## (several, comma-separated: --filter=wolf,knight)
## Files named *_deep* (slow deep variants) run only with a filter that
## contains "deep":  bash tools/run_tests.sh --filter=deep

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]
## Real milliseconds the audio thread gets to release stopped sounds before
## the runner quits.
const AUDIO_RELEASE_MS := 250


func _ready() -> void:
	if not SavePaths.uses_test_dir():
		print("ABORTED: saves would go to %s, not the test folder" % SavePaths.dir())
		get_tree().quit(2)
		return
	# saves and settings of this run live in res://tests/_out/saves (see
	# SavePaths); every test starts from an empty folder and default options
	_reset_globals()
	# Navigation maps and regions take in changes synchronously in the
	# physics step here: a test that (re)bakes and waits a few frames sees
	# the new navmesh even with frames running flat out (--fixed-fps), where
	# an asynchronous update lags a varying number of frames behind. (New
	# maps and regions read the settings; the existing default map is set
	# directly.) The game keeps the asynchronous updates.
	ProjectSettings.set_setting(&"navigation/world/map_use_async_iterations", false)
	ProjectSettings.set_setting(&"navigation/world/region_use_async_iterations", false)
	NavigationServer3D.map_set_use_async_iterations(get_viewport().find_world_3d().navigation_map, false)
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var passed := 0
	var failed := 0
	for path in _find_test_files(filter):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s  (script does not load)" % path)
			failed += 1
			continue
		for method in _test_methods(script):
			var test := script.new() as TestCase
			if test == null:
				print("FAIL  %s  (does not extend TestCase)" % path)
				failed += 1
				break
			add_child(test)
			await test.before_each()
			await test.call(method)
			await test.after_each()
			if test._failures.is_empty():
				passed += 1
				print("ok    %s :: %s" % [path.get_file(), method])
			else:
				failed += 1
				print("FAIL  %s :: %s" % [path.get_file(), method])
				for failure in test._failures:
					print("        " + failure)
			test.queue_free()
			_reset_globals()
			await get_tree().process_frame
	if passed + failed == 0:
		print("NO TESTS RAN")
		failed = 1
	print("\n%d passed, %d failed" % [passed, failed])
	# Stopped sounds are released by the audio thread a moment later (it
	# mixes in real time; the main loop then frees them); quitting right away
	# would report leaked playbacks. Under --fixed-fps a game-time timer runs
	# out in a few flat-out frames, so wait for the wall clock, frames going on.
	var release_at := Time.get_ticks_msec() + AUDIO_RELEASE_MS
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
		OS.delay_msec(5)
	get_tree().quit(1 if failed > 0 else 0)


func _find_test_files(filter: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for dir_path in TEST_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.begins_with("test_") and file.ends_with(".gd") and _matches(file, filter):
				# slow deep variants (*_deep.gd) run only when asked for
				if file.contains("_deep") and not filter.contains("deep"):
					continue
				files.append(dir_path.path_join(file))
	files.sort()
	return files


## True when [param file] contains [param filter] (several filters: any of
## them, comma-separated: --filter=wolf,knight).
static func _matches(file: String, filter: String) -> bool:
	if filter == "":
		return true
	for part in filter.split(",", false):
		if file.contains(part):
			return true
	return false


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


## Undo global side effects a test may leave behind.
func _reset_globals() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	for action in InputMap.get_actions():
		Input.action_release(action)
	var fx := get_node_or_null(^"/root/Fx")
	if fx != null:
		fx.call(&"clear")
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.call(&"stop_all")
	SavePaths.clear_test_dir()
	Settings.reset_to_defaults(false)
	GameState.file_path = ""
	GameState.reset()
	RunState.reset()
	VoiceDirector.reset()
	GameInput.clear_ui()
	PerceptionWorld.reset()
	PerceptionWorld.set_difficulty(1)
	# the lobby is the test level; Floor I tests pick &"floor1" themselves
	Museum.level_id = &"lobby"
	# Floor I builds as greybox in the suite (fast); the art tests switch it on
	MuseumFloorLevel.dress_default = false
