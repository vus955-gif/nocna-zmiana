extends TestCase
## RoomIndex (plan 2026-10-21-wydajnosc-cpu): LevelLayout.room_at() through
## a grid - the same answer everywhere, from a few rooms instead of all.


func test_the_same_room_as_the_layout_says_all_over_floor_one() -> void:
	var layout := Floor1Layout.create()
	var index := RoomIndex.build(layout)
	var bounds := Floor1Plan.bounds().grow(2.0)
	var dice := RandomNumberGenerator.new()
	dice.seed = 57
	var wrong := 0
	var inside := 0
	for i in 4000:
		var point := Vector3(dice.randf_range(bounds.position.x, bounds.end.x), dice.randf_range(-8.0, 22.0), dice.randf_range(bounds.position.y, bounds.end.y))
		var expected := layout.room_at(point)
		if expected != &"":
			inside += 1
		if index.room_at(point) != expected:
			wrong += 1
	assert_eq(wrong, 0, "every point in the same room")
	assert_gt(inside, 600, "and enough of them inside rooms (%d)" % inside)


func test_edges_corners_and_stacked_rooms_agree() -> void:
	var layout := Floor1Layout.create()
	var index := RoomIndex.build(layout)
	var wrong: Array[String] = []
	for room in layout.rooms:
		for part in room.parts:
			for corner in [part.position, part.end, Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.position.y), part.get_center()]:
				for y in [room.floor_y - 0.25, room.floor_y + 1.0, room.ceiling_y]:
					var point := Vector3((corner as Vector2).x, y, (corner as Vector2).y)
					if index.room_at(point) != layout.room_at(point):
						wrong.append("%s at %s" % [room.id, point])
	assert_eq(wrong.size(), 0, "edges agree: %s" % [wrong.slice(0, 5)])


func test_an_index_looks_at_a_few_rooms_not_every_room() -> void:
	# (structural, not timed: wall-clock comparisons are noise on a busy PC)
	var layout := Floor1Layout.create()
	var index := RoomIndex.build(layout)
	var most := index.largest_bucket()
	assert_gt(most, 0)
	assert_lt(most * 8, layout.rooms.size(), "at most %d rooms in a cell of %d on the floor" % [most, layout.rooms.size()])
