class_name TestCase
extends Node
## Base class for tests. The runner (tests/test_runner.gd) creates a fresh
## instance per test method, adds it to the scene tree, then awaits
## before_each(), the test_* method and after_each(). Failed assertions are
## collected, not thrown, so one test reports all its problems at once.

var _failures: PackedStringArray = []


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
