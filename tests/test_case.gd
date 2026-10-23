class_name TestCase
extends Node
## Base class for tests. The runner (tests/test_runner.gd) creates a fresh
## instance per test method, adds it to the scene tree, then awaits
## before_each(), the test_* method and after_each(). Failed assertions are
## collected, not thrown, so one test reports all its problems at once.

var _failures: PackedStringArray = []
## The test method about to run (set by the runner before before_each()).
var current_test: StringName = &""

## Fixtures shared by the tests of one file: key -> node, and the fingerprint
## each had when it was built (see shared_fixture()).
static var _fixtures: Dictionary = {}
static var _fixture_prints: Dictionary = {}


## The factor a budget in wall-clock time is multiplied by: 1.0 on a quiet PC
## of the developer's. --slack=N (a runner argument) or NZ_TEST_SLACK=N makes
## it larger where the machine is slower or busy - CI, or several test
## processes side by side (tools/run_tests.sh --parallel passes 2). Budgets
## in game time (frames, seconds of the simulation) never use it.
static func time_slack() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slack="):
			return maxf(1.0, arg.trim_prefix("--slack=").to_float())
	var env := OS.get_environment("NZ_TEST_SLACK")
	return maxf(1.0, env.to_float()) if env != "" else 1.0


## An expensive thing that tests only LOOK at - a dressed floor, say - built
## once and shared by all the tests of this file, instead of once per test:
## [param build] is called with a node that lives until the file is done (the
## runner), and returns the node it made there. The runner frees it after the
## file, and after every test checks that the fixture is still as it was
## built (nodes, positions, visibility, light energies); a test that changed
## it fails, and must build its own. Use from before_each():
## [code]level = await shared_fixture(&"key", Builder.build)[/code]
func shared_fixture(key: StringName, build: Callable) -> Node:
	if not _fixtures.has(key) or not is_instance_valid(_fixtures[key]):
		var node: Node = await build.call(get_parent())
		_fixtures[key] = node
		_fixture_prints[key] = fixture_fingerprint(node)
	return _fixtures[key]


## Keys of the shared fixtures that no longer match their fingerprint; those
## are freed (the next test builds a new one).
static func changed_fixtures() -> Array[StringName]:
	var changed: Array[StringName] = []
	for key: StringName in _fixtures.keys():
		var node: Node = _fixtures[key]
		if not is_instance_valid(node) or fixture_fingerprint(node) != _fixture_prints[key]:
			changed.append(key)
	for key in changed:
		_drop_fixture(key)
	return changed


## Frees every shared fixture (the runner calls it after each file).
static func release_fixtures() -> void:
	for key: StringName in _fixtures.keys():
		_drop_fixture(key)


static func _drop_fixture(key: StringName) -> void:
	var node: Node = _fixtures.get(key)
	if is_instance_valid(node):
		node.get_parent().remove_child(node)
		node.free()
	_fixtures.erase(key)
	_fixture_prints.erase(key)


## A number that changes when a subtree gets or loses a node, or a Node3D in
## it moves, shows or hides. (Order does not matter. What changes by itself
## with time does not count: decor turning and swaying, lamps flickering in
## energy.)
static func fixture_fingerprint(root: Node) -> int:
	var total := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var item := node.get_instance_id()
		if node is Node3D:
			var spatial := node as Node3D
			item = hash([item, spatial.visible, Vector3i((spatial.position * 1000.0).round())])
		total += item
		stack.append_array(node.get_children())
	return total


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		fail("expected true. " + message)


func assert_false(value: bool, message: String = "") -> void:
	if value:
		fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		fail("expected <%s>, got <%s>. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		fail("expected anything but <%s>. %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("expected %s (+/- %s), got %s. %s" % [expected, tolerance, actual, message])


func assert_gt(actual: float, limit: float, message: String = "") -> void:
	if not actual > limit:
		fail("expected > %s, got %s. %s" % [limit, actual, message])


func assert_lt(actual: float, limit: float, message: String = "") -> void:
	if not actual < limit:
		fail("expected < %s, got %s. %s" % [limit, actual, message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected a value, got null. " + message)


## Records every emission of [param sig]. Returns an Array that gains one
## [a, b, c, d] entry per emission (unused arguments are null).
func watch(sig: Signal) -> Array:
	var calls: Array = []
	sig.connect(func(a = null, b = null, c = null, d = null) -> void: calls.append([a, b, c, d]))
	return calls


## Waits [param count] physics frames (use with await).
func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return a == b
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return is_equal_approx(float(a), float(b))
	var strings := [TYPE_STRING, TYPE_STRING_NAME]
	if typeof(a) in strings and typeof(b) in strings:
		return str(a) == str(b)
	return typeof(a) == typeof(b) and a == b
