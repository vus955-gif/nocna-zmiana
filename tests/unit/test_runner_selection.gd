extends TestCase
## How the test runner picks files: the quick subset, the split into shards
## for parallel runs (plan docs/superpowers/plans/2026-10-21-testy-szybciej-ci.md)
## and the shard's own save folder.

const Runner := preload("res://tests/test_runner.gd")


func _files(names: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for label in names:
		out.append("res://tests/" + label)
	return out


func test_short_names_are_dir_and_file() -> void:
	assert_eq(Runner.short_name("res://tests/unit/test_a.gd"), "unit/test_a.gd")
	assert_eq(Runner.short_name("res://tests/integration/test_b.gd"), "integration/test_b.gd")


func test_quick_rules_choose_by_glob_and_a_minus_takes_files_out() -> void:
	var files := _files(["unit/test_a.gd", "unit/test_slow.gd", "integration/test_floor1_x.gd", "integration/test_floor1_y.gd", "integration/test_other.gd"])
	var rules := PackedStringArray(["unit/*", "-unit/test_slow.gd", "integration/test_floor1_*", "-integration/*_y.gd"])
	var picked := Runner.select_quick(files, rules)
	assert_eq(Array(picked), Array(_files(["unit/test_a.gd", "integration/test_floor1_x.gd"])))


func test_quick_rules_are_ordered_so_a_later_plus_wins() -> void:
	var files := _files(["unit/test_a.gd"])
	assert_eq(Runner.select_quick(files, PackedStringArray(["unit/*", "-unit/test_a.gd", "unit/test_a.gd"])).size(), 1)
	assert_eq(Runner.select_quick(files, PackedStringArray()).size(), 0, "no rules, no files")


func test_the_shipped_quick_list_names_files_that_exist() -> void:
	var rules := Runner._read_lines(Runner.QUICK_PATH)
	assert_gt(rules.size(), 0, "tests/quick_tests.txt is missing or empty")
	var all: PackedStringArray = []
	for dir_path in Runner.TEST_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if file.begins_with("test_") and file.ends_with(".gd"):
				all.append(dir_path.path_join(file))
	for rule in rules:
		var pattern := rule.trim_prefix("-")
		var hits := 0
		for path in all:
			if Runner.short_name(path).matchn(pattern):
				hits += 1
		assert_gt(hits, 0, "quick rule '%s' matches no test file" % rule)
	var picked := Runner.select_quick(all, rules)
	assert_gt(picked.size(), 20, "the quick subset is suspiciously small")
	assert_lt(picked.size(), all.size(), "the quick subset must leave something out")
	# a slow file that slipped in would make CI slow: it belongs in the exceptions
	var durations: Dictionary = Runner._read_durations()
	var total := 0
	for path in picked:
		var ms: int = durations.get(Runner.short_name(path), 0)
		assert_lt(ms, 25000, "%s takes %d ms: add '-%s' to tests/quick_tests.txt" % [Runner.short_name(path), ms, Runner.short_name(path)])
		total += ms
	assert_lt(total, 400000, "the quick subset takes %d s of recorded time" % (total / 1000))


func test_a_split_gives_every_file_to_exactly_one_group() -> void:
	var files := _files(["unit/a.gd", "unit/b.gd", "unit/c.gd", "integration/d.gd", "integration/e.gd", "integration/f.gd", "integration/g.gd"])
	var groups := Runner.partition(files, {"unit/a.gd": 50, "integration/d.gd": 900, "integration/e.gd": 300}, 3)
	assert_eq(groups.size(), 3)
	var seen := {}
	for group in groups:
		for path in group:
			assert_false(seen.has(path), "%s in two groups" % path)
			seen[path] = true
	assert_eq(seen.size(), files.size())


func test_a_split_is_deterministic_and_each_group_is_sorted() -> void:
	var files := _files(["unit/z.gd", "unit/a.gd", "unit/m.gd", "integration/k.gd", "integration/b.gd"])
	var weights := {"unit/z.gd": 70, "unit/a.gd": 10, "unit/m.gd": 40, "integration/k.gd": 40, "integration/b.gd": 90}
	var first := Runner.partition(files, weights, 2)
	var second := Runner.partition(files, weights, 2)
	for i in 2:
		assert_eq(Array(first[i]), Array(second[i]))
		var sorted := Array(first[i])
		sorted.sort()
		assert_eq(Array(first[i]), sorted)


func test_the_heaviest_files_go_to_different_groups_and_loads_balance() -> void:
	var names := ["a", "b", "c", "d", "e"]
	var weights := {"unit/a.gd": 10, "unit/b.gd": 9, "unit/c.gd": 8, "unit/d.gd": 7, "unit/e.gd": 1}
	var files: PackedStringArray = []
	for label in names:
		files.append("res://tests/unit/%s.gd" % label)
	var groups := Runner.partition(files, weights, 2)
	var loads: Array[int] = []
	for group in groups:
		var total := 0
		for path in group:
			total += weights[Runner.short_name(path)]
		loads.append(total)
	assert_lt(absi(loads[0] - loads[1]), 3, "loads %s" % str(loads))
	assert_ne(groups[0].has(files[0]), groups[0].has(files[1]), "the two heaviest share a group")


func test_a_file_without_a_record_weighs_the_median() -> void:
	# known: 100, 200, 900 -> median 200; two unknown files of 200 each
	var files := _files(["unit/a.gd", "unit/b.gd", "unit/c.gd", "unit/new1.gd", "unit/new2.gd"])
	var groups := Runner.partition(files, {"unit/a.gd": 100, "unit/b.gd": 200, "unit/c.gd": 900}, 2)
	assert_true(groups[0].has(files[2]) != groups[1].has(files[2]))
	var with_big: PackedStringArray = groups[0] if groups[0].has(files[2]) else groups[1]
	assert_eq(with_big.size(), 1, "the 900 ms file runs alone against the other four")


func test_more_groups_than_files_leave_empty_groups() -> void:
	var groups := Runner.partition(_files(["unit/a.gd", "unit/b.gd"]), {}, 4)
	assert_eq(groups.size(), 4)
	var used := 0
	for group in groups:
		if not group.is_empty():
			used += 1
	assert_eq(used, 2)


func test_recorded_times_are_read_from_the_tab_separated_record() -> void:
	var durations: Dictionary = Runner._read_durations()
	assert_gt(durations.size(), 100, "tests/test_durations.tsv is missing or short")
	for label in durations:
		assert_true(String(label).begins_with("unit/") or String(label).begins_with("integration/"), label)
		assert_gt(durations[label], -1)


func test_every_shard_keeps_its_saves_in_its_own_folder() -> void:
	var plain := SavePaths._test_dir_for("")
	assert_true(plain.ends_with("tests/_out/saves"), plain)
	assert_true(SavePaths._test_dir_for("0").ends_with("tests/_out/saves_0"))
	assert_true(SavePaths._test_dir_for("12").ends_with("tests/_out/saves_12"))
	assert_eq(SavePaths._test_dir_for("x"), plain, "not a number: the plain folder")
	assert_eq(SavePaths._test_dir_for("../x"), plain, "no way out of the test folder")


func _toy(host: Node) -> Node:
	var root := Node3D.new()
	host.add_child(root)
	var child := Node3D.new()
	child.name = "Child"
	root.add_child(child)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	root.add_child(lamp)
	return root


func test_the_fingerprint_sees_nodes_moves_and_visibility_but_not_turning_or_flicker() -> void:
	var root := _toy(self)
	var before := fixture_fingerprint(root)
	assert_eq(fixture_fingerprint(root), before, "the same tree, the same number")
	(root.get_node(^"Child") as Node3D).rotation.y = 1.0
	assert_eq(fixture_fingerprint(root), before, "turning is not a change (decor spins by itself)")
	(root.get_node(^"Child") as Node3D).position.x = 1.0
	assert_ne(fixture_fingerprint(root), before, "a move")
	(root.get_node(^"Child") as Node3D).position.x = 0.0
	assert_eq(fixture_fingerprint(root), before, "and back")
	(root.get_node(^"Lamp") as Node3D).visible = false
	assert_ne(fixture_fingerprint(root), before, "hidden")
	(root.get_node(^"Lamp") as Node3D).visible = true
	(root.get_node(^"Lamp") as OmniLight3D).light_energy = 0.3
	assert_eq(fixture_fingerprint(root), before, "a flickering lamp is not a change")
	(root.get_node(^"Lamp") as OmniLight3D).light_energy = 1.0
	var extra := Node3D.new()
	root.add_child(extra)
	assert_ne(fixture_fingerprint(root), before, "a new node")
	extra.free()
	assert_eq(fixture_fingerprint(root), before, "taken away again")
	root.free()


func test_a_shared_fixture_is_built_once_and_a_changed_one_is_dropped() -> void:
	var builds := [0]
	var build := func(host: Node) -> Node:
		builds[0] += 1
		return _toy(host)
	var first: Node = await shared_fixture(&"toy", build)
	var second: Node = await shared_fixture(&"toy", build)
	assert_eq(builds[0], 1, "built once")
	assert_true(first == second)
	assert_eq(TestCase.changed_fixtures().size(), 0, "untouched")
	(first.get_node(^"Child") as Node3D).position.y = 2.0
	var changed := TestCase.changed_fixtures()
	assert_eq(changed.size(), 1, "a test that moved something is told")
	assert_eq(changed[0], &"toy")
	assert_false(is_instance_valid(first), "the changed fixture is gone")
	var third: Node = await shared_fixture(&"toy", build)
	assert_eq(builds[0], 2, "the next test gets a new one")
	assert_true(is_instance_valid(third))
	TestCase.release_fixtures()
	assert_false(is_instance_valid(third), "released after the file")
