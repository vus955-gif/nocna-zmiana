extends TestCase
## Phalanx geometry: places on the line, wheeling, overlapping shields.


func test_places_lie_on_a_line_across_the_front() -> void:
	var places := Phalanx.slots(Vector3(0, 0, 0), Vector3.FORWARD, 3)
	assert_eq(places.size(), 3)
	assert_almost_eq(places[0].x, -Phalanx.SPACING, 0.001, "left of the middle")
	assert_almost_eq(places[1].x, 0.0, 0.001)
	assert_almost_eq(places[2].x, Phalanx.SPACING, 0.001, "right of it")
	for place in places:
		assert_almost_eq(place.z, 0.0, 0.001, "side by side")
	var two := Phalanx.slots(Vector3(5, 0, 5), Vector3.RIGHT, 2)
	assert_almost_eq(two[0].distance_to(two[1]), Phalanx.SPACING, 0.001)
	assert_almost_eq(two[0].x, 5.0, 0.001, "facing +X the line runs along Z")


func test_the_shields_overlap() -> void:
	assert_gt(Phalanx.shield_overlap(), 0.05, "no gap between neighbouring shields")


func test_wheeling_is_limited() -> void:
	var turned := Phalanx.wheel(Vector3.FORWARD, Vector3.RIGHT, 0.5)
	assert_almost_eq(Vector3.FORWARD.angle_to(turned), Phalanx.WHEEL_RATE * 0.5, 0.001, "0.6 rad in half a second")
	assert_lt(turned.dot(Vector3.RIGHT), 1.0)
	var done := Phalanx.wheel(Vector3.FORWARD, Vector3.RIGHT, 5.0)
	assert_true(done.is_equal_approx(Vector3.RIGHT), "it gets there in the end")


func test_right_of_a_facing() -> void:
	assert_true(Phalanx.right_of(Vector3.FORWARD).is_equal_approx(Vector3.RIGHT))
	assert_true(Phalanx.right_of(Vector3.RIGHT).is_equal_approx(Vector3.BACK))
