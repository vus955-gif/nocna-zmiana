extends TestCase
## TotemFaces (design pietro-1-projekt 5.6): faces from health, the rate of
## fire by faces left, which block a hit lands on and what it does there,
## how many faces a place gets, and which face shoots.


func test_faces_left_follow_the_health() -> void:
	assert_eq(TotemFaces.faces_left(150.0), 5)
	assert_eq(TotemFaces.faces_left(121.0), 5)
	assert_eq(TotemFaces.faces_left(120.0), 4)
	assert_eq(TotemFaces.faces_left(1.0), 1)
	assert_eq(TotemFaces.faces_left(0.0), 0)
	assert_eq(TotemFaces.faces_left(-5.0), 0)
	assert_eq(TotemFaces.faces_left(90.0, 45.0), 2, "a tuned totem counts by its own face health")


func test_fewer_faces_shoot_faster() -> void:
	assert_almost_eq(TotemFaces.interval(5), 2.0)
	assert_almost_eq(TotemFaces.interval(4), 1.7)
	assert_almost_eq(TotemFaces.interval(3), 1.4)
	assert_almost_eq(TotemFaces.interval(2), 1.1)
	assert_almost_eq(TotemFaces.interval(1), 0.8)
	assert_almost_eq(TotemFaces.interval(0), 0.8, 0.001, "never faster than one face")


func test_blocks_by_height() -> void:
	assert_eq(TotemFaces.block_at(0.1), 0, "the stump")
	assert_eq(TotemFaces.block_at(0.87), 1, "the bear's face")
	assert_eq(TotemFaces.block_at(1.79), 2)
	assert_eq(TotemFaces.block_at(2.59), 3)
	assert_eq(TotemFaces.block_at(3.41), 4)
	assert_eq(TotemFaces.block_at(4.31), 5)
	assert_eq(TotemFaces.block_at(4.9), 6, "the hat")


func test_only_the_top_face_takes_full_damage() -> void:
	assert_almost_eq(TotemFaces.hit_factor(5, 5), 1.0)
	assert_almost_eq(TotemFaces.hit_factor(6, 5), 1.0, 0.001, "the hat counts as the top")
	assert_almost_eq(TotemFaces.hit_factor(3, 5), TotemFaces.LOWER_FACTOR)
	assert_almost_eq(TotemFaces.hit_factor(0, 5), TotemFaces.LOWER_FACTOR, 0.001, "the stump is dead wood")
	assert_almost_eq(TotemFaces.hit_factor(3, 3), 1.0, 0.001, "once the faces above are gone it is the top")


func test_a_place_gets_three_to_five_faces_for_good() -> void:
	var seen: Dictionary = {}
	for i in 60:
		var point := Vector3(i * 1.7, 0.0, -i * 2.3)
		var count := TotemFaces.count_for(point)
		assert_true(count >= 3 and count <= 5, "%d faces" % count)
		assert_eq(TotemFaces.count_for(point), count, "the same place, the same totem")
		assert_eq(TotemFaces.count_for(point + Vector3.UP * 0.05), count, "the spawner's lift off the slot is still the place")
		seen[count] = true
	assert_eq(seen.size(), 3, "all three sizes come up")


func test_faces_turn_faster_higher_up() -> void:
	assert_almost_eq(TotemFaces.turn_rate(1), 0.9)
	assert_almost_eq(TotemFaces.turn_rate(5), 1.5)
	assert_gt(TotemFaces.turn_rate(3), TotemFaces.turn_rate(2))


func test_the_best_aimed_clear_face_shoots() -> void:
	var guard := 0.5
	var yaws := PackedFloat32Array([0.0, 0.3, 0.6, 1.2, 0.47])
	var all_clear := func(_face: int) -> bool: return true
	assert_eq(TotemFaces.pick_face(yaws, 5, guard, all_clear), 5, "face 5 is 0.03 rad off")
	assert_eq(TotemFaces.pick_face(yaws, 3, guard, all_clear), 3, "with two faces gone, face 3")
	var third_blocked := func(face: int) -> bool: return face != 3
	assert_eq(TotemFaces.pick_face(yaws, 3, guard, third_blocked), 2, "a blocked face passes")
	assert_eq(TotemFaces.pick_face(yaws, 1, guard, all_clear), -1, "face 1 is 0.5 rad off: none")
	assert_eq(TotemFaces.pick_face(PackedFloat32Array([3.0]), 1, -3.1, all_clear), 1, "across the wrap-around")
	var alike := PackedFloat32Array([0.5, 0.5, 0.5, 0.5, 0.5])
	assert_eq(TotemFaces.pick_face(alike, 5, guard, all_clear), 5, "aimed alike, the top face shoots")
	assert_eq(TotemFaces.pick_face(alike, 4, guard, third_blocked), 4)
