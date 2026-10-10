extends TestCase
## Checks the lobby data against the design (section 5 of the stage-2
## design, with the deviations logged in the 2b-1 plan).

var layout: LevelLayout


func before_each() -> void:
	layout = LobbyLayout.create()


func _room_rect(id: StringName) -> Rect2:
	var room := layout.room(id)
	return room.parts[0] if room != null and not room.parts.is_empty() else Rect2()


func test_main_rooms_have_the_designed_size_and_height() -> void:
	var expected := {
		&"hall": [Rect2(-18, -22, 36, 44), 0.0, 14.0],
		&"gallery": [Rect2(-40, -14, 20, 28), 0.0, 7.0],
		&"armory": [Rect2(20, -14, 20, 28), 0.0, 7.0],
		&"diorama": [Rect2(-14, 24, 28, 20), 0.0, 8.0],
		&"security": [Rect2(-5, 54, 10, 8), 0.0, 3.0],
		&"closet": [Rect2(-2, -26, 4, 3), 6.0, 9.0],
	}
	for id: StringName in expected:
		var room := layout.room(id)
		assert_not_null(room, str(id))
		if room == null:
			continue
		assert_eq(_room_rect(id), expected[id][0], str(id))
		assert_eq(room.floor_y, expected[id][1], "%s floor" % id)
		assert_eq(room.ceiling_y, expected[id][2], "%s ceiling" % id)
	assert_true(layout.room(&"security").haven)
	assert_true(layout.room(&"closet").haven)
	assert_eq(layout.room(&"hall").skylights.size(), 3)


func test_balcony_is_a_four_metre_u_at_six_metres() -> void:
	var balcony := layout.room(&"balcony")
	assert_false(balcony.carved)
	assert_eq(balcony.floor_y, 6.0)
	assert_eq(balcony.parts.size(), 3)
	for part in balcony.parts:
		assert_eq(minf(part.size.x, part.size.y), 4.0)
	for id in [&"stairs_w", &"stairs_e"]:
		var flight: StairsSpec = null
		for candidate in layout.stairs:
			if candidate.id == id:
				flight = candidate
		assert_not_null(flight, str(id))
		if flight != null:
			assert_eq(flight.top_y, 6.0)
			assert_eq(flight.width(), 4.0)
			# 0.25 m cells with a 0.1 m climb join only slopes up to ~21.8 degrees
			assert_lt(atan2(flight.top_y - flight.bottom_y, flight.run()), deg_to_rad(21.0), "slope the navmesh can follow")


func test_everything_lies_on_the_half_metre_grid() -> void:
	var rects: Array[Rect2] = []
	for room in layout.rooms:
		rects.append_array(room.parts)
		rects.append_array(room.skylights)
	for passage in layout.openings:
		rects.append(passage.rect)
	for rect in rects:
		for value in [rect.position.x, rect.position.y, rect.end.x, rect.end.y]:
			assert_true(ShellCarver.on_grid(value), "%s off grid" % rect)


func test_rooms_and_passages_leave_head_room() -> void:
	for room in layout.rooms:
		assert_true(room.height() >= 2.199, "%s is %.1f m tall" % [room.id, room.height()])
	for passage in layout.openings:
		assert_true(passage.height() >= 2.199, "%s" % passage.id)
		assert_true(passage.width() >= 1.0, "%s" % passage.id)


func test_every_passage_touches_both_of_its_rooms_within_their_heights() -> void:
	for passage in layout.openings:
		for id in [passage.room_a, passage.room_b]:
			var room := layout.room(id)
			assert_not_null(room, "%s -> %s" % [passage.id, id])
			if room == null:
				continue
			var touches := false
			for part in room.parts:
				if passage.rect.grow(0.01).intersects(part):
					touches = true
			assert_true(touches, "%s touches %s" % [passage.id, id])
			assert_true(passage.floor_y >= room.floor_y - 0.01 and passage.top_y <= room.ceiling_y + 0.01, "%s fits in %s" % [passage.id, id])


func test_carved_rooms_do_not_touch_each_other_without_a_passage() -> void:
	var carved := layout.rooms.filter(func(r: RoomSpec) -> bool: return r.carved)
	for i in carved.size():
		for j in range(i + 1, carved.size()):
			var a: RoomSpec = carved[i]
			var b: RoomSpec = carved[j]
			var overlap_y := a.floor_y < b.ceiling_y and b.floor_y < a.ceiling_y
			if not overlap_y:
				continue
			for pa in a.parts:
				for pb in b.parts:
					assert_false(pa.grow(0.01).intersects(pb), "%s and %s need a wall between them" % [a.id, b.id])


func test_all_rooms_connect_when_the_secrets_are_open() -> void:
	var graph := layout.graph()
	var secrets := graph.doors_of_kind(RoomGraph.Kind.SECRET)
	secrets.append_array(graph.doors_of_kind(RoomGraph.Kind.GATE))
	var seen := graph.reachable(&"security", [], secrets)
	for room in layout.rooms:
		assert_true(seen.has(room.id), "%s reachable" % room.id)
	var plain := graph.reachable(&"security")
	for id in [&"closet", &"secret_chamber", &"shotgun_niche", &"vent", &"undercroft"]:
		assert_false(plain.has(id), "%s stays hidden" % id)
	assert_eq(graph.doors_of_kind(RoomGraph.Kind.LOCKABLE).size(), 6)


func test_loops_give_three_routes_between_the_diorama_and_the_wings() -> void:
	var graph := layout.graph()
	for wing in [&"gallery", &"armory"]:
		for door in graph.doors_of_kind(RoomGraph.Kind.LOCKABLE):
			assert_true(graph.connected(&"diorama", wing, [door] as Array[StringName]), "%s with %s closed" % [wing, door])


func test_spawn_slots_stand_in_their_rooms_clear_of_furniture() -> void:
	assert_gt(layout.spawn_slots.size(), 60)
	for slot in layout.spawn_slots:
		assert_eq(layout.room_at(slot.position + Vector3.UP * 0.1), slot.room, "slot at %s" % slot.position)
		assert_almost_eq(slot.position.y, layout.room(slot.room).floor_y, 0.01)
		for piece in layout.pieces:
			var stood_on := piece.position.y + piece.size.y <= slot.position.y + 0.05
			if piece.collide and not stood_on and piece.room in [slot.room, &"hall", &"balcony"] and absf(piece.position.y - slot.position.y) < 2.0:
				var clear := piece.footprint().grow(0.5)
				assert_false(clear.has_point(Vector2(slot.position.x, slot.position.z)), "slot %s inside %s at %s" % [slot.position, piece.kit, piece.position])


func test_slots_of_a_set_keep_their_distance() -> void:
	for a in layout.spawn_slots:
		for b in layout.spawn_slots:
			if a != b and a.room == b.room and a.set_id == b.set_id:
				assert_gt(a.position.distance_to(b.position), 1.2, "%s / %s" % [a.position, b.position])


func test_encounter_sets_fit_their_rooms() -> void:
	var description := LevelDescription.from_layout(layout)
	var rooms := description.encounter_rooms()
	for id in [&"hall", &"balcony", &"gallery", &"armory", &"diorama"]:
		assert_true(rooms.has(id), str(id))
	for room in rooms:
		var sets := description.sets_in(room)
		assert_true(sets.size() >= 2 and sets.size() <= 3, "%s has %d sets" % [room, sets.size()])
		assert_false(layout.room(room).haven, "no exhibits in havens")
		assert_false(layout.room(room).secret, "no exhibits in secret rooms")
	assert_false(rooms.has(&"staff_corridor"), "the corridor by the start stays calm")
	var kinds := {}
	for slot in layout.spawn_slots:
		if not kinds.has(slot.room):
			kinds[slot.room] = {}
		for kind in slot.kinds:
			kinds[slot.room][kind] = true
	assert_eq(_sorted(kinds[&"gallery"].keys()), [&"bust", &"wax"])
	assert_eq(_sorted(kinds[&"armory"].keys()), [&"knight", &"wax"])
	assert_true(kinds[&"diorama"].has(&"wolf"))
	assert_eq(_sorted(kinds[&"hall"].keys()), [&"knight", &"raptor", &"wax", &"wolf"])
	assert_gt(kinds[&"balcony"].size(), 2, "mixed")
	assert_true(kinds[&"balcony"].has(&"raptor"), "a pack up on the balcony too")


func test_loot_spots_are_in_their_rooms_and_include_containers() -> void:
	var containers := 0
	for spot in layout.loot_spots:
		assert_eq(layout.room_at(spot.position + Vector3.UP * 0.05), spot.room, "loot at %s" % spot.position)
		if spot.container:
			containers += 1
	assert_gt(containers, 6)
	assert_true(layout.loot_spots.any(func(s: LootSpot) -> bool: return s.room == &"secret_chamber" and s.container))


func test_markers_for_later_stages_exist_in_the_right_rooms() -> void:
	var required := {
		&"fuse_a_1": &"gallery", &"fuse_a_2": &"gallery", &"fuse_b_1": &"armory", &"fuse_b_2": &"armory",
		&"crystal_case_gallery": &"gallery", &"crystal_case_armory": &"armory",
		&"crystal_case_diorama": &"diorama", &"crystal_case_hall": &"balcony",
		&"pistol_locker": &"security", &"ticket_drawer": &"hall", &"cctv_wall": &"security",
		&"grate": &"hall", &"fuse_box": &"hall", &"shotgun_case": &"shotgun_niche",
		&"note_1": &"security", &"note_2": &"armory", &"note_3": &"balcony",
	}
	for id: StringName in required:
		assert_true(layout.markers.has(id), "marker %s" % id)
		assert_eq(layout.marker_rooms.get(id), required[id], "room of %s" % id)
	for id in LobbyLayout.SECRETS:
		assert_true(layout.markers.has(id), "secret %s" % id)
	assert_eq(LobbyLayout.SECRETS.size(), 6)
	for id: StringName in layout.markers:
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		var inside := layout.room_at(at + Vector3.UP * 0.05)
		var near_wall := layout.room_at(at + (layout.markers[id] as Transform3D).basis * Vector3(0, 0.05, -0.3))
		assert_true(inside == layout.marker_rooms[id] or near_wall == layout.marker_rooms[id], "%s at %s lies in %s" % [id, at, layout.marker_rooms[id]])


func test_havens_and_start() -> void:
	assert_eq(_sorted(layout.haven_spots.keys()), [&"closet", &"security"])
	for id: StringName in layout.haven_spots:
		var spot: Transform3D = layout.haven_spots[id]
		assert_eq(layout.room_at(spot.origin + Vector3.UP * 0.1), id)
		var facing := spot.basis * Vector3.FORWARD
		assert_eq(layout.room_at(spot.origin + facing * 1.0 + Vector3.UP * 0.1), id, "%s terminal faces into the room" % id)
	assert_eq(layout.room_at(layout.player_start.origin), &"security")


func test_collidable_pieces_stand_inside_their_rooms() -> void:
	for piece in layout.pieces:
		if not piece.collide:
			continue
		var room := layout.room(piece.room)
		assert_not_null(room, "%s room %s" % [piece.kit, piece.room])
		if room == null:
			continue
		var box := piece.footprint()
		for corner in [box.position, box.end, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y)]:
			assert_true(room.covers(corner.lerp(box.get_center(), 0.02)), "%s at %s pokes out of %s" % [piece.kit, piece.position, room.id])


func test_description_lists_lockable_doors_starts_and_objectives() -> void:
	var description := LobbyLayout.describe(layout)
	assert_eq(description.lockable_doors.size(), 6)
	assert_eq(_sorted(description.start_rooms), [&"closet", &"security"])
	for room in [&"hall", &"gallery", &"armory", &"diorama", &"balcony"]:
		assert_true(description.objective_rooms.has(room), str(room))
	assert_eq(description.crystal_cases.size(), 4)
	assert_eq(description.fuse_points[&"A"].size(), 2)
	assert_eq(description.fuse_points[&"B"].size(), 2)
	assert_eq(description.always_artifact_spots.size(), 2, "secret chamber pedestal and the locked hall case")
	assert_true(description.objectives_reachable([]))
	for door in description.lockable_doors:
		assert_true(description.objectives_reachable([door] as Array[StringName]), str(door))


func _sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort_custom(func(a, b) -> bool: return str(a) < str(b))
	return copy
