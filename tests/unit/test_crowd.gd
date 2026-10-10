extends TestCase


func test_ring_gives_the_free_place_closest_to_the_bearing() -> void:
	var ring := EnemyCrowd.AttackRing.new()
	assert_eq(ring.claim(11, 0.0), 0)
	assert_eq(ring.claim(12, PI * 0.4), 2, "0.4 pi = 2 of 10 places")
	assert_eq(ring.claim(13, 0.1), 1, "place 0 is taken: the nearest free neighbour")


func test_the_same_owner_keeps_its_place() -> void:
	var ring := EnemyCrowd.AttackRing.new()
	var first := ring.claim(5, PI)
	assert_eq(ring.claim(5, 0.0), first)


func test_released_places_come_back_and_a_full_ring_says_no() -> void:
	var ring := EnemyCrowd.AttackRing.new()
	for who in range(1, EnemyCrowd.RING_SLOTS + 1):
		assert_ne(ring.claim(who, 0.0), -1)
	assert_eq(ring.claim(99, 0.0), -1)
	ring.release(3)
	assert_ne(ring.claim(99, 0.0), -1)
	for who in range(1, EnemyCrowd.RING_SLOTS + 1):
		ring.release(who)
	ring.release(99)
	assert_true(ring.is_empty())


func test_separation_pushes_apart_and_fades_with_distance() -> void:
	var near := EnemyCrowd.separation(Vector3.ZERO, [Vector3(0.3, 0, 0)] as Array[Vector3])
	var far := EnemyCrowd.separation(Vector3.ZERO, [Vector3(0.9, 0, 0)] as Array[Vector3])
	assert_lt(near.x, 0.0, "away from the neighbour")
	assert_gt(near.length(), far.length())
	assert_eq(EnemyCrowd.separation(Vector3.ZERO, [Vector3(1.5, 0, 0)] as Array[Vector3]), Vector3.ZERO)
	var boxed := EnemyCrowd.separation(Vector3.ZERO, [Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0)] as Array[Vector3])
	assert_true(boxed.is_zero_approx(), "pushes from both sides cancel")
	assert_eq(EnemyCrowd.separation(Vector3.ZERO, [Vector3(0.1, 0, 0), Vector3(0.1, 0, 0.05), Vector3(0.05, 0, -0.1)] as Array[Vector3]).length() <= 1.0001, true, "capped")


func test_separation_ignores_height() -> void:
	var push := EnemyCrowd.separation(Vector3.ZERO, [Vector3(0.5, 3.0, 0)] as Array[Vector3])
	assert_eq(push.y, 0.0)
