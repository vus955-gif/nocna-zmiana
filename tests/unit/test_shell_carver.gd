extends TestCase


func _room(rect: Rect2, bottom: float, top: float, owner: StringName) -> ShellCarver.Volume:
	return ShellCarver.volume(rect, bottom, top, owner, ShellCarver.Kind.ROOM)


func _carve(volumes: Array[ShellCarver.Volume]) -> Array[ShellCarver.ShellBox]:
	return ShellCarver.carve(volumes)


func _at(boxes: Array[ShellCarver.ShellBox], point: Vector3) -> Array[ShellCarver.ShellBox]:
	var found: Array[ShellCarver.ShellBox] = []
	for box in boxes:
		if box.aabb.grow(-0.001).has_point(point):
			found.append(box)
	return found


func _kits(boxes: Array[ShellCarver.ShellBox], point: Vector3) -> Array[StringName]:
	var kits: Array[StringName] = []
	for box in _at(boxes, point):
		kits.append(box.kit)
	return kits


func test_single_room_gets_one_floor_one_ceiling_and_a_closed_ring_of_walls() -> void:
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 3.0, &"a")])
	var floors := boxes.filter(func(b: ShellCarver.ShellBox) -> bool: return b.kit == &"floor")
	var ceilings := boxes.filter(func(b: ShellCarver.ShellBox) -> bool: return b.kit == &"ceiling")
	assert_eq(floors.size(), 1, "the floor merges into one box")
	assert_eq(ceilings.size(), 1)
	if floors.size() == 1:
		assert_eq(floors[0].aabb, AABB(Vector3(0, -0.5, 0), Vector3(4, 0.5, 4)))
		assert_eq(floors[0].walk_owner, &"a")
	var wall_area := 0.0
	for box in boxes:
		if box.kit == &"wall":
			wall_area += box.aabb.size.x * box.aabb.size.z
			assert_almost_eq(box.aabb.position.y, -0.5, 0.001)
			assert_almost_eq(box.aabb.end.y, 3.5, 0.001)
	assert_almost_eq(wall_area, 9.0, 0.001, "36 cells of 0.5 m around a 4 x 4 room")
	for probe in [Vector3(-0.25, 1, 2), Vector3(4.25, 1, 2), Vector3(2, 1, -0.25), Vector3(2, 1, 4.25), Vector3(-0.25, 1, -0.25), Vector3(4.25, 3.25, 4.25)]:
		assert_eq(_kits(boxes, probe), [&"wall"] as Array[StringName], "wall at %s" % probe)
	assert_eq(_at(boxes, Vector3(2, 1.5, 2)).size(), 0, "the room itself is empty")


func test_passage_cuts_a_doorway_with_jambs_and_a_lintel_up_to_the_taller_room() -> void:
	var passage := ShellCarver.volume(Rect2(4, 1, 2, 2), 0.0, 2.5, &"door", ShellCarver.Kind.PASSAGE)
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 3.0, &"a"), _room(Rect2(6, 0, 4, 4), 0.0, 6.0, &"b"), passage])
	assert_eq(_at(boxes, Vector3(5, 1.2, 2)).size(), 0, "walk through the doorway")
	assert_eq(_kits(boxes, Vector3(5, -0.25, 2)), [&"threshold"] as Array[StringName])
	assert_eq(_kits(boxes, Vector3(5, 2.75, 2)), [&"lintel"] as Array[StringName])
	assert_eq(_kits(boxes, Vector3(4.25, 1.2, 0.75)), [&"wall"] as Array[StringName], "jamb")
	assert_eq(_kits(boxes, Vector3(5.75, 1.2, 3.25)), [&"wall"] as Array[StringName], "jamb")
	var above := _at(boxes, Vector3(5.75, 5.0, 2))
	assert_eq(above.size(), 1, "the tall room's wall closes above the door")
	if above.size() == 1:
		assert_eq(above[0].kit, &"wall")
		assert_true(above[0].above_all)
		assert_eq(above[0].owner, &"b")
	assert_eq(_kits(boxes, Vector3(4.25, 5.0, 2)), [] as Array[StringName], "no wall above the low room's side")


func test_stacked_spaces_get_a_slab_that_is_the_upper_floor() -> void:
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 3.0, &"low"), _room(Rect2(0, 0, 4, 4), 4.0, 6.0, &"high")])
	var slab := _at(boxes, Vector3(2, 3.5, 2))
	assert_eq(slab.size(), 1)
	if slab.size() == 1:
		assert_eq(slab[0].kit, &"slab")
		assert_eq(slab[0].walk_owner, &"high")
		assert_false(slab[0].above_all)
	assert_eq(_kits(boxes, Vector3(-0.25, 5.0, 2)), [&"wall"] as Array[StringName], "walls run up to the top room")


func test_skylight_well_leaves_the_roof_open_with_a_rim() -> void:
	var sky := ShellCarver.volume(Rect2(2, 2, 2, 2), 4.0, 5.5, &"hall", ShellCarver.Kind.SKY)
	var boxes := _carve([_room(Rect2(0, 0, 6, 6), 0.0, 4.0, &"hall"), sky])
	assert_eq(_at(boxes, Vector3(3, 4.25, 3)).size(), 0, "no ceiling over the well")
	assert_eq(_at(boxes, Vector3(3, 7.0, 3)).size(), 0, "open to the sky")
	assert_eq(_kits(boxes, Vector3(1, 4.25, 1)), [&"ceiling"] as Array[StringName])
	assert_eq(_kits(boxes, Vector3(1.75, 5.2, 3)), [&"wall"] as Array[StringName], "rim of the well")


func test_everything_over_the_top_space_is_marked_above_all() -> void:
	var passage := ShellCarver.volume(Rect2(4, 1, 2, 2), 0.0, 2.5, &"door", ShellCarver.Kind.PASSAGE)
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 3.0, &"a"), _room(Rect2(6, 0, 4, 4), 0.0, 6.0, &"b"), passage])
	for box in boxes:
		var expected := box.kit == &"ceiling" or box.kit == &"lintel" or (box.kit == &"wall" and box.aabb.position.y > 0.0)
		assert_eq(box.above_all, expected, "%s at %s" % [box.kit, box.aabb])


func test_results_are_cached_per_input() -> void:
	var volumes: Array[ShellCarver.Volume] = [_room(Rect2(0, 0, 2, 2), 0.0, 3.0, &"x")]
	var first := ShellCarver.carve(volumes)
	var again := ShellCarver.carve([_room(Rect2(0, 0, 2, 2), 0.0, 3.0, &"x")])
	assert_true(is_same(first, again))
	var other := ShellCarver.carve([_room(Rect2(0, 0, 2, 2), 0.0, 3.5, &"x")])
	assert_false(is_same(first, other))


func test_a_raised_passage_keeps_the_wall_under_it_down_to_the_lower_floor() -> void:
	# a hatch at 6 m in the 0.5 m wall between a tall hall and a shaft
	var hatch := ShellCarver.volume(Rect2(4, 1, 0.5, 1.5), 6.0, 8.2, &"hatch", ShellCarver.Kind.PASSAGE)
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 14.0, &"hall"), _room(Rect2(4.5, 0, 1, 4), 0.0, 8.4, &"shaft"), hatch])
	assert_eq(_kits(boxes, Vector3(4.25, 5.75, 1.75)), [&"threshold"] as Array[StringName], "the hatch sill")
	for y in [0.25, 2.0, 5.0]:
		assert_eq(_kits(boxes, Vector3(4.25, y, 1.75)), [&"wall"] as Array[StringName], "wall under the hatch at %.2f" % y)
	assert_eq(_kits(boxes, Vector3(4.25, -0.25, 1.75)), [&"wall"] as Array[StringName], "down into the ground")
	assert_eq(_at(boxes, Vector3(4.25, 7.0, 1.75)).size(), 0, "the hatch itself is open")


func test_a_shared_wall_takes_the_look_of_the_public_room() -> void:
	var secret := ShellCarver.volume(Rect2(4.5, 0, 2, 4), 0.0, 9.0, &"secret", ShellCarver.Kind.ROOM, true)
	var boxes := _carve([_room(Rect2(0, 0, 4, 4), 0.0, 7.0, &"public"), secret])
	var shared := _at(boxes, Vector3(4.25, 2.0, 2.0))
	assert_eq(shared.size(), 1)
	if shared.size() == 1:
		assert_eq(shared[0].owner, &"public", "the taller secret room must not colour the public wall")


func test_wall_faces_line_a_room_and_leave_its_doorway_open() -> void:
	var door := ShellCarver.volume(Rect2(4, 1, 1, 2), 0.0, 2.5, &"door", ShellCarver.Kind.PASSAGE)
	var volumes: Array[ShellCarver.Volume] = [_room(Rect2(0, 0, 4, 4), 0.0, 3.0, &"a"), _room(Rect2(5, 0, 4, 4), 0.0, 3.0, &"b"), door]
	var faces := ShellCarver.wall_faces(volumes)
	var east: Array[ShellCarver.WallFace] = []
	var area := 0.0
	for face in faces:
		if face.room == &"a":
			area += face.aabb.size.x * face.aabb.size.y + face.aabb.size.z * face.aabb.size.y
			if face.normal == Vector3.LEFT:
				east.append(face)
	# 4 walls of 4 x 3 m, minus the 2 x 2.5 m doorway
	assert_almost_eq(area, 4.0 * 4.0 * 3.0 - 2.0 * 2.5, 0.001)
	var over_door := east.filter(func(f: ShellCarver.WallFace) -> bool: return f.aabb.position.y > 2.4)
	assert_eq(over_door.size(), 1, "the strip above the door")
	for face in east:
		assert_almost_eq(face.aabb.position.x, 4.0, 0.001, "on the room's east wall plane")
		assert_eq(face.aabb.size.x, 0.0)
