extends Node
## Headless test runner. Runs every test_* method of every
## tests/unit/test_*.gd and tests/integration/test_*.gd script, prints a
## report and quits with exit code 0 (all passed) or 1.
## Filter by file name:  bash tools/run_tests.sh --filter=stamina
## (several, comma-separated: --filter=wolf,knight)
## Files named *_deep* (slow deep variants) run only with a filter that
## contains "deep":  bash tools/run_tests.sh --filter=deep
## --quick runs only the files listed in tests/quick_tests.txt (the fast,
## high-signal subset CI runs). --shards=N --shard=k (k from 0) runs the
## k-th of N groups of files balanced by their recorded wall time
## (tests/test_durations.json); `bash tools/run_tests.sh --parallel` starts
## the N processes. --timings=<path> writes the measured wall time per file.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]
## Wall milliseconds per file as last measured (--timings= writes the same
## format: "unit/test_x.gd", milliseconds, tests, tab-separated, a line per
## file); the shard balancer's weights. A file not in it weighs the median.
const DURATIONS_PATH := "res://tests/test_durations.tsv"
## The quick subset: one glob per line (file names, matched against
## "unit/test_x.gd"), a leading "-" removes what the lines above chose.
const QUICK_PATH := "res://tests/quick_tests.txt"
## Real milliseconds the audio thread gets to release stopped sounds before
## the runner quits.
const AUDIO_RELEASE_MS := 250
## A test slower than this (wall milliseconds) is listed in the time report.
const SLOW_TEST_MS := 3000


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
	var quick := false
	var shards := 1
	var shard := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
		elif arg == "--quick":
			quick = true
		elif arg.begins_with("--shards="):
			shards = int(arg.trim_prefix("--shards="))
		elif arg.begins_with("--shard="):
			shard = int(arg.trim_prefix("--shard="))
	if shards < 1 or shard < 0 or shard >= shards:
		print("ABORTED: --shard=%d is not within --shards=%d" % [shard, shards])
		get_tree().quit(2)
		return
	var files := _find_test_files(filter)
	if quick:
		files = select_quick(files, _read_lines(QUICK_PATH))
	if shards > 1:
		files = partition(files, _read_durations(), shards)[shard]
		print("SHARD %d/%d  %d files" % [shard + 1, shards, files.size()])
	var passed := 0
	var failed := 0
	var run_started := Time.get_ticks_msec()
	# wall time per file and per test (tests/test_durations.json, --timings=)
	var file_ms: Dictionary = {}
	var slow_tests: Array = []
	for path in files:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s  (script does not load)" % path)
			failed += 1
			continue
		var file_started := Time.get_ticks_msec()
		var file_tests := 0
		for method in _test_methods(script):
			var test_started := Time.get_ticks_msec()
			var test := script.new() as TestCase
			if test == null:
				print("FAIL  %s  (does not extend TestCase)" % path)
				failed += 1
				break
			add_child(test)
			test.current_test = method
			await test.before_each()
			await test.call(method)
			await test.after_each()
			for key in TestCase.changed_fixtures():
				test.fail("changed the shared fixture '%s': a test that changes what it looks at must build its own" % key)
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
			file_tests += 1
			var test_ms := Time.get_ticks_msec() - test_started
			if test_ms >= SLOW_TEST_MS:
				slow_tests.append([test_ms, "%s :: %s" % [path.get_file(), method]])
		TestCase.release_fixtures()
		file_ms[short_name(path)] = [Time.get_ticks_msec() - file_started, file_tests]
	# a shard may be left without files when there are more shards than files
	if passed + failed == 0 and (shards == 1 or not files.is_empty()):
		print("NO TESTS RAN")
		failed = 1
	print("\n%d passed, %d failed" % [passed, failed])
	_report_times(file_ms, slow_tests, Time.get_ticks_msec() - run_started)
	# Stopped sounds are released by the audio thread a moment later (it
	# mixes in real time; the main loop then frees them); quitting right away
	# would report leaked playbacks. Under --fixed-fps a game-time timer runs
	# out in a few flat-out frames, so wait for the wall clock, frames going on.
	var release_at := Time.get_ticks_msec() + AUDIO_RELEASE_MS
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
		OS.delay_msec(5)
	get_tree().quit(1 if failed > 0 else 0)


## Prints the time report; with --timings=<path> also writes the per-file
## wall times there (one "name<TAB>ms<TAB>tests" line per file, sorted).
func _report_times(file_ms: Dictionary, slow_tests: Array, total_ms: int) -> void:
	slow_tests.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for entry in slow_tests.slice(0, 15):
		print("SLOW  %6.1f s  %s" % [entry[0] / 1000.0, entry[1]])
	print("TIME  %.1f s wall, %d files" % [total_ms / 1000.0, file_ms.size()])
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--timings="):
			path = arg.trim_prefix("--timings=")
	if path == "":
		return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		print("could not write timings to %s" % path)
		return
	var names: Array = file_ms.keys()
	names.sort()
	for entry in names:
		out.store_line("%s\t%d\t%d" % [entry, file_ms[entry][0], file_ms[entry][1]])
	out.close()


## The lines of a text file that are not empty or comments (# ...); none when
## it does not exist.
static func _read_lines(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	for line in file.get_as_text().split("\n", false):
		var text := line.get_slice("#", 0).strip_edges()
		if text != "":
			out.append(text)
	return out


## "unit/test_x.gd" for "res://tests/unit/test_x.gd".
static func short_name(path: String) -> String:
	return path.get_base_dir().get_file() + "/" + path.get_file()


## Recorded wall milliseconds per file ("unit/test_x.gd"); empty when there is
## no record.
static func _read_durations() -> Dictionary:
	var out := {}
	for line in _read_lines(DURATIONS_PATH):
		var parts := line.split("\t")
		if parts.size() >= 2 and parts[1].is_valid_int():
			out[parts[0]] = int(parts[1])
	return out


## The files of [param files] chosen by [param rules] (see QUICK_PATH): each
## rule is a glob over "dir/file" ("unit/test_stamina.gd", "unit/*",
## "integration/test_floor1_*"); a leading "-" takes matching files out again.
static func select_quick(files: PackedStringArray, rules: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for path in files:
		var label := short_name(path)
		var chosen := false
		for rule in rules:
			var removes := rule.begins_with("-")
			if label.matchn(rule.trim_prefix("-")):
				chosen = not removes
		if chosen:
			out.append(path)
	return out


## Splits [param files] into [param count] groups of about equal wall time
## ([param weights]: milliseconds by short_name()):
## the heaviest file goes to the group that is lightest so far (a file with
## no recorded time weighs the median of the recorded ones). Deterministic,
## so every shard process computes the same split; the files of a group are
## returned sorted, as a single process would run them.
static func partition(files: PackedStringArray, weights: Dictionary, count: int) -> Array[PackedStringArray]:
	var known: Array[int] = []
	for path in files:
		if weights.has(short_name(path)):
			known.append(int(weights[short_name(path)]))
	known.sort()
	var fallback: int = known[known.size() >> 1] if not known.is_empty() else 1000
	var weight_of := func(path: String) -> int:
		return int(weights[short_name(path)]) if weights.has(short_name(path)) else fallback
	var order := Array(files)
	order.sort_custom(func(a: String, b: String) -> bool:
		var wa: int = weight_of.call(a)
		var wb: int = weight_of.call(b)
		return wa > wb if wa != wb else a < b)
	var loads: Array[int] = []
	loads.resize(count)
	loads.fill(0)
	var group_of := {}
	for path in order:
		var lightest := 0
		for i in count:
			if loads[i] < loads[lightest]:
				lightest = i
		group_of[path] = lightest
		loads[lightest] += weight_of.call(path)
	var groups: Array[PackedStringArray] = []
	for i in count:
		groups.append(PackedStringArray())
	var sorted := files.duplicate()
	sorted.sort()
	for path in sorted:
		groups[group_of[path]].append(path)
	return groups


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
	var overlay := get_node_or_null(^"/root/PerfOverlay")
	if overlay != null:
		overlay.set(&"debug_build", OS.is_debug_build())
		overlay.call(&"set_mode", 0)
	SavePaths.clear_test_dir()
	Settings.reset_to_defaults(false)
	GameState.file_path = ""
	GameState.reset()
	RunState.reset()
	VoiceDirector.reset()
	GameInput.clear_ui()
	PerceptionWorld.reset()
	PerceptionWorld.set_difficulty(1)
	Enemy.doze_enabled = true
	ExhibitClock.reset()
	# the lobby is the test level; Floor I tests pick &"floor1" themselves
	Museum.level_id = &"lobby"
	# Floor I builds as greybox in the suite (fast); the art tests switch it on
	MuseumFloorLevel.dress_default = false
