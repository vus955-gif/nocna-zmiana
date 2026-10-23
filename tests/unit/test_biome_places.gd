extends TestCase
## The biome mechanics' placement data against Floor I's layout (plan
## 2026-10-21-mechaniki-biomow): every device in a room of its own wing,
## never in a guardian's arena, on a wall where it hangs on one, clear of
## pieces, spawns, patrols and doorways where it lies on a floor.

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _report(problems: PackedStringArray) -> void:
	for line in problems:
		fail(line)


func test_the_egypt_traps_lie_in_the_tombs() -> void:
	assert_gt(TombTrap.PLACES.size(), 3.0, "a trap in each tomb room at least")
	var rooms := {}
	for spec: Dictionary in TombTrap.PLACES:
		var room: StringName = spec["room"]
		rooms[room] = true
		var label := String(spec["id"])
		assert_true(room in [&"egypt_tomb_passage", &"egypt_tombs", &"egypt_tomb_hall"], "%s in the tombs" % label)
		assert_false(BiomeMechanics.ARENA_ROOMS.has(room), "%s: no arena" % label)
		var plate: Vector3 = spec["plate"]
		var mouth: Vector3 = spec["mouth"]
		var dir: Vector3 = spec["dir"]
		_report(BiomePlaces.floor_area(layout, room, plate, TombTrap.PLATE_SIZE, label + " plate"))
		_report(BiomePlaces.wall_point(layout, room, mouth, dir, label + " mouth"))
		var to := plate - mouth
		var along := to.dot(dir)
		assert_lt(absf(to.x * dir.z - to.z * dir.x), 0.05, "%s: the plate lies on the mouth's line" % label)
		assert_true(along > 1.0 and along < float(spec["length"]), "%s: the plate is down the line" % label)
		var far := mouth + dir * (float(spec["length"]) - 0.3) + Vector3.UP
		assert_eq(layout.room_at(far), room, "%s: the line ends at the room's far wall" % label)
	assert_eq(rooms.size(), 3, "the passage, the chambers and the hall")


func test_no_trap_lies_by_the_conservators_door() -> void:
	var door := layout.opening(&"egypt_tombs_conservator")
	assert_not_null(door)
	for spec: Dictionary in TombTrap.PLACES:
		var plate: Vector3 = spec["plate"]
		assert_gt(door.center().distance_to(Vector3(plate.x, door.center().y, plate.z)), 4.0, "%s: away from the haven's door" % spec["id"])


func test_the_asia_bells_hang_in_the_halls_clear_of_heads_and_lanterns() -> void:
	assert_eq(TempleBell.PLACES.size(), 3, "the China hall, the armour hall and the Korea pavilion")
	for spec: Dictionary in TempleBell.PLACES:
		var room: StringName = spec["room"]
		var label := String(spec["id"])
		var spec_room := layout.room(room)
		assert_not_null(spec_room, label)
		if spec_room == null:
			continue
		assert_eq(spec_room.zone, &"asia", label)
		assert_false(BiomeMechanics.ARENA_ROOMS.has(room), "%s: no arena" % label)
		if spec.has("pavilion"):
			var at: Vector3 = spec["pavilion"]
			var found := false
			for piece in layout.pieces:
				if piece.room == room and piece.kit == &"pedestal" and piece.size.x > 3.0 and Vector2(piece.position.x - at.x, piece.position.z - at.z).length() < 0.5:
					found = true
			assert_true(found, "%s: the pavilion's platform is there" % label)
			continue
		var hang: Vector3 = spec["hang"]
		var k := float(spec["scale"])
		assert_eq(layout.room_at(hang), room, "%s: hangs inside its room" % label)
		assert_almost_eq(float(spec["ceiling"]), spec_room.ceiling_y, 0.01, "%s: its chain reaches the ceiling" % label)
		assert_gt(hang.y - TempleBell.MODEL_BELL_HEIGHT * k, spec_room.floor_y + 3.2, "%s: high over every head" % label)
		var grip := Rect2(hang.x - 0.3, hang.z - 0.3, 0.6, 0.6)
		for piece in layout.pieces:
			if piece.room != room:
				continue
			if piece.collide and piece.position.y < 2.0:
				assert_false(piece.footprint().intersects(grip), "%s: its rope clear of %s" % [label, piece.kit])
			if piece.kit == &"lantern":
				assert_gt(Vector2(piece.position.x - hang.x, piece.position.z - hang.z).length(), 2.0, "%s: away from the lanterns (they swing and fall)" % label)


func test_the_americas_fires_are_the_wing_bowls_outside_the_temple() -> void:
	const Americas := preload("res://src/level/floor1/zones/americas.gd")
	var bowls := 0
	for piece in layout.pieces:
		if piece.kit == &"brazier" and String(piece.room).begins_with("americas_") and piece.room != &"americas_temple":
			bowls += 1
			assert_not_null(SacredFire._lamp_of(layout, piece), "the bowl in %s has its lamp" % piece.room)
	assert_eq(bowls, 5, "the North America hall's two, the totem hall's two, the Pacific's one")
	assert_true(TotemSight.is_fire(Americas.FIRE), "the bowls' and torches' fire")
	assert_true(TotemSight.is_fire(Americas.EMBER))
	assert_false(TotemSight.is_fire(Americas.UPLIGHT), "the museum's uplights are no fire")
	assert_false(TotemSight.is_fire(Americas.LANTERN), "nor the whalers' lantern")


func test_the_greek_lamp_and_mirrors_hang_on_the_nereid_halls_walls() -> void:
	assert_eq(HeliosLamp.INSTALLATIONS.size(), 1)
	for place: Dictionary in HeliosLamp.INSTALLATIONS:
		var room: StringName = place["room"]
		assert_false(BiomeMechanics.ARENA_ROOMS.has(room))
		assert_eq(layout.room(room).zone, &"greece")
		var lamp: Dictionary = place["lamp"]
		var at: Vector3 = lamp["at"]
		_report(BiomePlaces.wall_point(layout, room, Vector3(at.x, 1.0, at.z), lamp["face"], "the lamp"))
		var lever := at + (lamp["face"] as Vector3) * 0.9 - Vector3.UP * 1.5
		assert_eq(layout.room_at(lever), &"greece_nereid_podium", "the lever over the balcony, at hand for a guard standing there")
		for mirror: Dictionary in place["mirrors"]:
			var label := String(mirror["id"])
			var spot: Vector3 = mirror["at"]
			_report(BiomePlaces.wall_point(layout, room, Vector3(spot.x, 0.0, spot.z), mirror["face"], label))
			assert_true(spot.y > 1.0 and spot.y < 2.0, "%s: at the height of a hand" % label)
			assert_eq((mirror["marks"] as Array).size(), 3, "%s: three marks" % label)


func test_the_regulator_hangs_on_the_clocks_rooms_wall_clear_of_its_doors() -> void:
	assert_eq(Regulator.PLACES.size(), 1)
	var spec: Dictionary = Regulator.PLACES[0]
	var room: StringName = spec["room"]
	assert_eq(room, &"enlightenment_clocks")
	var at: Vector3 = spec["at"]
	_report(BiomePlaces.wall_point(layout, room, at, spec["face"], "the regulator"))
	for opening in layout.openings:
		if opening.room_a == room or opening.room_b == room:
			var middle := opening.center()
			assert_gt(Vector2(middle.x - at.x, middle.z - at.z).length(), 2.0, "clear of %s" % opening.id)
	for piece in layout.pieces:
		if piece.room == room and piece.collide:
			assert_false(piece.footprint().grow(0.2).has_point(Vector2(at.x, at.z) + Vector2((spec["face"] as Vector3).x, (spec["face"] as Vector3).z) * 0.2), "its case clear of %s" % piece.kit)


func test_the_assyrian_nets_hang_high_over_open_floor() -> void:
	assert_eq(HuntingNet.PLACES.size(), 8)
	var pit := 0
	for spec: Dictionary in HuntingNet.PLACES:
		var room: StringName = spec["room"]
		var label := String(spec["id"])
		var spec_room := layout.room(room)
		assert_not_null(spec_room, label)
		if spec_room == null:
			continue
		assert_eq(spec_room.zone, &"assyria", label)
		assert_false(BiomeMechanics.ARENA_ROOMS.has(room), "%s: no arena" % label)
		var at: Vector3 = spec["at"]
		assert_eq(layout.room_at(at), room, "%s: hangs in its room" % label)
		assert_almost_eq(float(spec["floor"]), spec_room.floor_y, 0.01, "%s: falls to its room's floor" % label)
		assert_almost_eq(float(spec["ceiling"]), spec_room.ceiling_y, 0.01, "%s: hangs from its ceiling" % label)
		assert_gt(at.y - 0.6 - spec_room.floor_y, 2.6, "%s: its knot over every head" % label)
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var edge := Vector3(at.x + cos(angle) * HuntingNet.RADIUS * 0.8, spec_room.floor_y + 0.5, at.z + sin(angle) * HuntingNet.RADIUS * 0.8)
			assert_eq(layout.room_at(edge), room, "%s: it spreads over its room's floor (%s)" % [label, edge])
		if room == &"assyria_nimrud":
			assert_gt(at.x, -88.0, "%s: clear of the restorers' corner (env-combat's hoist)" % label)
		if room == &"assyria_lions":
			pit += 1
	assert_eq(pit, 3, "the Lion Hunt's pit is netted from its gallery")


func test_the_steam_vents_blow_across_the_rings_corridors_clear_of_doors() -> void:
	assert_eq(SteamVent.PLACES.size(), 6)
	for spec: Dictionary in SteamVent.PLACES:
		var room: StringName = spec["room"]
		var label := String(spec["id"])
		var spec_room := layout.room(room)
		assert_not_null(spec_room, label)
		if spec_room == null:
			continue
		assert_eq(spec_room.zone, &"basement", label)
		var at: Vector3 = spec["at"]
		var dir: Vector3 = spec["dir"]
		var valve: Vector3 = spec["valve"]
		assert_almost_eq(at.y, spec_room.floor_y, 0.01, "%s: on its floor" % label)
		_report(BiomePlaces.wall_point(layout, room, at, dir, label))
		_report(BiomePlaces.wall_point(layout, room, valve, dir, label + " wheel"))
		var side := Vector3(dir.z, 0, -dir.x)
		for corner in [at + side * SteamVent.HALF_WIDTH, at - side * SteamVent.HALF_WIDTH]:
			var far: Vector3 = corner + dir * (float(spec["across"]) - 0.2) + Vector3.UP
			var near: Vector3 = corner + dir * 0.2 + Vector3.UP
			assert_eq(layout.room_at(far), room, "%s: its plume ends at the far wall" % label)
			assert_eq(layout.room_at(near), room, "%s: its plume starts at its own wall" % label)
		var gap := Vector2(valve.x - at.x, valve.z - at.z).length()
		assert_true(gap > SteamVent.HALF_WIDTH + 0.8 and gap < 4.0, "%s: its wheel beside it, out of the steam" % label)
		for opening in layout.openings:
			if opening.room_a != room and opening.room_b != room:
				continue
			var middle := opening.center()
			for point: Vector3 in [at, valve]:
				assert_gt(Vector2(middle.x - point.x, middle.z - point.z).length(), 2.4, "%s: clear of %s" % [label, opening.id])
