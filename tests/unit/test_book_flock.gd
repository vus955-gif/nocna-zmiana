extends TestCase
## The flying books' flock controller (BookFlock): lead, ring, the dive
## rhythm, scattering, waking order, where it sleeps.

var flock: BookFlock
var books: Array[Node3D] = []


func before_each() -> void:
	flock = BookFlock.new()
	books.clear()
	for i in 5:
		var book := Node3D.new()
		book.position = Vector3(i * 1.0, 2.0, 0.0)
		add_child(book)
		books.append(book)
		flock.join(book)


func test_the_first_book_standing_leads() -> void:
	assert_eq(flock.lead(), books[0])
	assert_true(flock.is_lead(books[0]))
	assert_false(flock.is_lead(books[1]))
	flock.leave(books[0])
	assert_eq(flock.lead(), books[1], "the next one takes over")


func test_ring_places_surround_the_guard_and_turn() -> void:
	var guard := Vector3(10.0, 0.0, 10.0)
	var places: Array[Vector3] = []
	for book in books:
		var at := flock.ring_slot(book, guard)
		var flat := Vector2(at.x - guard.x, at.z - guard.z).length()
		assert_true(flat >= BookFlock.RING_RADIUS.x - 0.01 and flat <= BookFlock.RING_RADIUS.y + 0.01, "radius %.2f" % flat)
		assert_true(at.y - guard.y >= BookFlock.RING_HEIGHT.x - 0.01 and at.y - guard.y <= BookFlock.RING_HEIGHT.y + 0.01)
		for other in places:
			assert_gt(other.distance_to(at), 1.5, "places apart")
		places.append(at)
	var before := flock.ring_slot(books[0], guard)
	flock.tick(1.0)
	assert_gt(flock.ring_slot(books[0], guard).distance_to(before), 1.0, "the ring turns")


func test_one_dive_at_a_time_with_a_gap_and_a_cooldown() -> void:
	assert_true(flock.can_dive(books[0]))
	flock.begin_dive(books[0])
	assert_false(flock.can_dive(books[1]), "one at a time")
	flock.tick(1.0)
	flock.end_dive(books[0])
	assert_false(flock.can_dive(books[1]), "a gap after a dive")
	flock.tick(BookFlock.DIVE_GAP + 0.01)
	assert_true(flock.can_dive(books[1]))
	assert_false(flock.can_dive(books[0]), "its own cooldown")
	flock.tick(BookFlock.OWN_COOLDOWN)
	assert_true(flock.can_dive(books[0]))


func test_a_diver_that_falls_frees_the_turn() -> void:
	flock.begin_dive(books[2])
	flock.leave(books[2])
	assert_eq(flock.diver(), null)
	flock.tick(BookFlock.DIVE_GAP + 0.01)
	assert_true(flock.can_dive(books[3]))


func test_a_shot_down_book_scatters_the_near_ones_and_spooks_the_flock() -> void:
	books[4].position.x = 9.0
	var pushes := flock.scatter_from(books[0].position, books[0])
	assert_false(pushes.has(books[0]), "not the fallen one")
	assert_true(pushes.has(books[1]) and pushes.has(books[3]))
	assert_false(pushes.has(books[4]), "too far to care")
	var push: Vector3 = pushes[books[1]]
	assert_gt(push.x, 0.0, "away from the fall")
	assert_almost_eq(push.length(), BookFlock.SCATTER_SPEED, 0.01)
	assert_true(flock.spooked())
	assert_false(flock.can_dive(books[1]), "no dive while spooked")
	flock.tick(BookFlock.SPOOK_TIME + 0.01)
	assert_false(flock.spooked())


func test_the_others_wake_one_after_another_nearest_first() -> void:
	var sleeping: Array = books.duplicate()
	var delays := flock.wake_delays(books[2], sleeping)
	assert_false(delays.has(books[2]))
	assert_eq(delays.size(), 4)
	assert_lt(float(delays[books[1]]), float(delays[books[0]]), "nearest first")
	assert_almost_eq(float(delays[books[1]]) + float(delays[books[3]]), BookFlock.WAKE_STAGGER * 3.0, 0.001)


func test_they_sleep_in_a_row_on_the_nearest_shelf() -> void:
	# a wall facing +Z at z = -1.5 (the room is at +Z)
	var wall := func(from: Vector3, to: Vector3) -> Dictionary:
		if to.z >= -1.5 or from.z < -1.5:
			return {}
		var t := (from.z + 1.5) / (from.z - to.z)
		return {"position": from.lerp(to, t), "normal": Vector3.BACK}
	var spots := BookFlock.perches(Vector3.ZERO, 5, wall)
	assert_eq(spots.size(), 5)
	for i in spots.size():
		var spot := spots[i]
		assert_almost_eq(spot.origin.y, BookFlock.SHELF_HEIGHT, 0.001, "on the shelf")
		assert_almost_eq(spot.origin.z, -1.5 + BookFlock.SHELF_OFFSET, 0.001, "off its face")
		assert_gt((spot.basis * Vector3.BACK).dot(Vector3.BACK), 0.99, "spine to the room")
		if i > 0:
			assert_almost_eq(spots[i - 1].origin.distance_to(spot.origin), BookFlock.SHELF_SPACING, 0.001)


func test_without_a_shelf_they_lie_stacked_on_the_floor() -> void:
	var none := func(_from: Vector3, _to: Vector3) -> Dictionary: return {}
	var spots := BookFlock.perches(Vector3(3, 0, 3), 4, none)
	for i in spots.size():
		assert_almost_eq(spots[i].origin.y, BookFlock.STACK_BASE + BookFlock.STACK_STEP * i, 0.001)
		assert_gt(absf((spots[i].basis * Vector3.RIGHT).dot(Vector3.UP)), 0.99, "lying flat (closed covers up)")


func test_a_slot_makes_a_flock_of_books() -> void:
	var made := BookFlock.make_members(Vector3(5, 0, 5), 0.0, 5)
	assert_eq(made.size(), 5)
	var shared := (made[0] as FlyingBook).flock
	assert_not_null(shared)
	for i in made.size():
		var book := made[i] as FlyingBook
		assert_not_null(book)
		assert_eq(book.flock, shared)
		assert_eq(book.flock_index, i)
		book.free()
