extends TestCase


func test_add_clamps_to_one() -> void:
	var trauma := Trauma.new()
	trauma.add(0.7)
	trauma.add(0.7)
	assert_eq(trauma.value, 1.0)


func test_decays_to_zero_and_not_below() -> void:
	var trauma := Trauma.new()
	trauma.add(0.5)
	trauma.tick(0.1)
	assert_almost_eq(trauma.value, 0.5 - trauma.decay_per_sec * 0.1)
	trauma.tick(10.0)
	assert_eq(trauma.value, 0.0)


func test_strength_is_trauma_squared() -> void:
	var trauma := Trauma.new()
	trauma.add(0.5)
	assert_almost_eq(trauma.strength(), 0.25)
