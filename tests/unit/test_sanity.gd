extends TestCase
## Checks the test helpers themselves.

signal pinged(value: int)


func test_numbers_compare_across_int_and_float() -> void:
	assert_eq(3, 3.0)


func test_strings_compare_across_string_and_stringname() -> void:
	assert_eq(&"pistol", "pistol")


func test_watch_records_signal_arguments() -> void:
	var calls := watch(pinged)
	pinged.emit(7)
	assert_eq(calls.size(), 1)
	assert_eq(calls[0][0], 7)


func test_physics_frames_can_be_awaited() -> void:
	var before := Engine.get_physics_frames()
	await physics_frames(2)
	assert_gt(Engine.get_physics_frames(), before)
