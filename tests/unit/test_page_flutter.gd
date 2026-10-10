extends TestCase
## A shot book's page falls like a leaf (PageFlutter.Motion).


func _motion(push: Vector3 = Vector3.ZERO) -> PageFlutter.Motion:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var motion := PageFlutter.Motion.new(Vector3(0, 2.0, 0), push, rng)
	motion.floor_y = 0.0
	return motion


func test_it_sinks_slowly() -> void:
	var motion := _motion()
	for i in 60:
		motion.step(1.0 / 60.0)
	assert_lt(motion.velocity.y, 0.0)
	assert_gt(motion.velocity.y, -PageFlutter.Motion.SINK - 0.01, "never faster than paper sinks")
	assert_gt(motion.position.y, 1.0, "a second later it has fallen less than a metre")


func test_it_sways_from_side_to_side() -> void:
	var motion := _motion()
	var sides: Array[float] = []
	for i in 120:
		motion.step(1.0 / 60.0)
		sides.append(motion.position.dot(motion.axis))
	assert_gt(sides.max() - sides.min(), 0.25, "a sway of a few tens of centimetres")
	var tilts := 0
	motion = _motion()
	for i in 60:
		motion.step(1.0 / 60.0)
		if absf(motion.tilt()) > 0.3:
			tilts += 1
	assert_gt(tilts, 10, "it tips into its swings")


func test_a_push_dies_down_in_the_air() -> void:
	var motion := _motion(Vector3(3.0, 1.5, 0.0))
	for i in 90:
		motion.step(1.0 / 60.0)
	assert_lt(Vector2(motion.velocity.x, motion.velocity.z).length(), 0.2)


func test_it_lands_flat_and_stays() -> void:
	var motion := _motion()
	for i in 600:
		motion.step(1.0 / 60.0)
	assert_true(motion.landed)
	assert_almost_eq(motion.position.y, 0.0, 0.001)
	assert_almost_eq(motion.tilt(), 0.0)
	var face := motion.basis() * Vector3.BACK
	assert_gt(face.dot(Vector3.UP), 0.99, "lying with its face up")
	var resting := motion.position
	motion.step(0.5)
	assert_eq(motion.position, resting)
