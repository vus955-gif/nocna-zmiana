extends TestCase
## Floor1Layout (stage P1 part A skeleton): every zone module builds inside
## its zone, every junction finds a room on both sides, the gates of the
## plan are all there, the whole floor is one connected room graph once
## every gate is open, and the havens, markers and the Level contract data
## are in place.

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func test_the_layout_puts_itself_together_without_problems() -> void:
	assert_eq(Array(Floor1Layout.problems), [], "no problems")
	assert_eq(layout.id, &"floor1")
	assert_gt(layout.rooms.size(), 45, "about 45-55 rooms (design 4.6)")


func test_every_room_lies_in_its_zone() -> void:
	var ids := {}
	for room in layout.rooms:
		assert_false(ids.has(room.id), "unique room id " + str(room.id))
		ids[room.id] = true
		assert_true(Floor1Plan.ZONES.has(room.zone), "%s has a zone" % room.id)
		assert_true(String(room.id).begins_with(String(room.zone)), "%s is named after its zone" % room.id)
		assert_true(Floor1Plan.areas().has(room.progress_area()), "%s area" % room.id)
		assert_eq(Floor1Plan.zone_of_area(room.progress_area()), room.zone, "%s area in its zone" % room.id)
		for part in room.parts:
			for value in [part.position.x, part.position.y, part.end.x, part.end.y]:
				assert_true(ShellCarver.on_grid(value), "%s on the grid" % room.id)
			# the room and its ceiling slab (a floor slab between stacked zones,
			# the roof's over the court, is shared)
			assert_true(Floor1Plan.contains(room.zone, part, room.floor_y, room.ceiling_y + ShellCarver.ROOF_T), "%s part %s inside zone %s" % [room.id, part, room.zone])


func test_every_junction_opens_between_rooms_of_its_zones() -> void:
	for j in Floor1Plan.junctions():
		var passage := layout.opening(j.id)
		assert_not_null(passage, str(j.id))
		if passage == null:
			continue
		assert_eq(layout.room(passage.room_a).zone, j.zone_a, "%s room A" % j.id)
		assert_eq(layout.room(passage.room_b).zone, j.zone_b, "%s room B" % j.id)
		for room_id in [passage.room_a, passage.room_b]:
			var room := layout.room(room_id)
			assert_true(room.floor_y <= j.floor_y + 0.01 and room.ceiling_y >= j.top_y - 0.01, "%s: %s spans the doorway's height" % [j.id, room_id])


func test_every_plan_gate_is_in_the_layout_once() -> void:
	for plan in Floor1Plan.gates():
		var found := layout.gates.filter(func(g: GateSpec) -> bool: return g.id == plan.id)
		assert_eq(found.size(), 1, str(plan.id))
		if found.size() != 1:
			continue
		var gate: GateSpec = found[0]
		assert_eq(gate.kind, plan.kind, "%s kind" % plan.id)
		assert_eq(gate.requirement, plan.requirement, "%s requirement" % plan.id)
		if plan.junction != &"":
			assert_eq(gate.opening, plan.junction, "%s blocks its junction" % plan.id)
		else:
			var target: StringName = Floor1Plan.INTERNAL_GATE_TARGETS[plan.id]
			assert_true(gate.opening == target or gate.marker == target, "%s blocks %s" % [plan.id, target])
		if gate.opening != &"":
			var passage := layout.opening(gate.opening)
			assert_not_null(passage, "%s opening" % plan.id)
			if passage != null:
				assert_eq(passage.link, RoomGraph.Kind.GATE, "%s: shut in the room graph until opened" % plan.id)
				var areas := [layout.room(passage.room_a).progress_area(), layout.room(passage.room_b).progress_area()]
				assert_true(areas.has(plan.area_a) and areas.has(plan.area_b), "%s joins %s and %s, found %s" % [plan.id, plan.area_a, plan.area_b, areas])
		if gate.kind == GateSpec.Kind.BOLT:
			var bolt_room := layout.room(gate.one_way_side)
			assert_not_null(bolt_room, "%s bolt side" % plan.id)
			if bolt_room != null:
				assert_eq(bolt_room.progress_area(), plan.bolt_area, "%s opens from %s" % [plan.id, plan.bolt_area])


func test_with_every_gate_open_each_room_is_reachable_from_the_booth() -> void:
	var graph := layout.graph()
	var opened: Array[StringName] = []
	for gate in layout.gates:
		if gate.opening != &"":
			opened.append(gate.opening)
	var reached := graph.reachable(&"booth_security", [], opened)
	for room in layout.rooms:
		assert_true(reached.has(room.id), "%s reachable" % room.id)


func test_with_every_gate_shut_the_start_reaches_only_the_first_night() -> void:
	var reached := layout.graph().reachable(&"booth_security")
	var zones := {}
	for room_id: StringName in reached:
		zones[layout.room(room_id).zone] = true
	for zone: StringName in [&"booth", &"entrance", &"court", &"egypt", &"enlightenment"]:
		assert_true(zones.has(zone), "%s on night 1" % zone)
	for zone: StringName in [&"assyria", &"greece", &"north_hall", &"asia", &"americas", &"basement", &"roof"]:
		assert_false(zones.has(zone), "%s behind a gate" % zone)


func test_havens_have_rooms_terminals_and_start() -> void:
	for haven in Floor1Plan.havens():
		var room := layout.room(haven.room)
		assert_not_null(room, str(haven.id))
		if room == null:
			continue
		assert_true(room.haven, "%s is a haven room" % haven.room)
		assert_true(layout.haven_spots.has(haven.id), "%s terminal" % haven.id)
		var spot: Transform3D = layout.haven_spots.get(haven.id, Transform3D())
		assert_eq(layout.room_at(spot.origin + Vector3.UP), haven.room, "%s terminal stands in its room" % haven.id)
		var inward := spot.origin + (-spot.basis.z) * 1.5 + Vector3.UP
		assert_eq(layout.room_at(inward), haven.room, "%s terminal faces into the room" % haven.id)
	assert_eq(layout.room_at(layout.player_start.origin + Vector3.UP), &"booth_security", "the night starts in the booth")


func test_markers_for_every_pickup_guardian_and_the_finale() -> void:
	var wanted: Array[StringName] = [Floor1Plan.TREX_MARKER, Floor1Plan.EXIT_MARKER]
	for pickup in Floor1Plan.pickups():
		wanted.append(pickup.marker)
	for guardian in Floor1Plan.guardians():
		wanted.append(guardian.marker)
	for marker in wanted:
		assert_true(layout.markers.has(marker), str(marker))
		if not layout.markers.has(marker):
			continue
		var room := layout.room(layout.marker_rooms[marker])
		assert_not_null(room, "%s room" % marker)
		var origin: Vector3 = (layout.markers[marker] as Transform3D).origin
		assert_true(room.covers(Vector2(origin.x, origin.z)), "%s lies in %s" % [marker, room.id])
	for pickup in Floor1Plan.pickups():
		var room := layout.room(layout.marker_rooms.get(pickup.marker, &""))
		if room != null:
			assert_eq(room.progress_area(), pickup.area, "%s in area %s" % [pickup.id, pickup.area])
	for guardian in Floor1Plan.guardians():
		var room := layout.room(layout.marker_rooms.get(guardian.marker, &""))
		if room != null:
			assert_eq(room.progress_area(), guardian.area, "%s in area %s" % [guardian.id, guardian.area])


func test_slots_loot_patrols_and_ambushes_point_at_real_rooms() -> void:
	assert_gt(layout.spawn_slots.size(), 30)
	assert_gt(layout.loot_spots.size(), 20)
	for slot in layout.spawn_slots:
		var room := layout.room(slot.room)
		assert_not_null(room, "slot room %s" % slot.room)
		if room == null:
			continue
		assert_eq(slot.zone, room.zone, "slot zone")
		assert_false(room.haven, "no exhibit in a haven")
		assert_eq(layout.room_at(slot.position + Vector3.UP), slot.room, "slot %s in %s" % [slot.position, slot.room])
		if slot.patrol != &"":
			assert_not_null(layout.patrol(slot.patrol), "patrol %s" % slot.patrol)
	for spot in layout.loot_spots:
		assert_eq(layout.room_at(spot.position + Vector3.UP), spot.room, "loot %s in %s" % [spot.position, spot.room])
	for patrol in layout.patrols:
		assert_true(patrol.points.size() >= 2, str(patrol.id))
		for point in patrol.points:
			assert_ne(layout.room_at(point + Vector3.UP), &"", "patrol %s point %s in a room" % [patrol.id, point])
	for ambush in layout.ambushes:
		assert_gt(ambush.slots.size(), 0, str(ambush.id))
		for index in ambush.slots:
			assert_true(index >= 0 and index < layout.spawn_slots.size(), "%s slot index" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.PICKUP:
			assert_true(layout.markers.has(ambush.marker), "%s marker" % ambush.id)


func test_the_description_knows_havens_objectives_and_the_boss_room() -> void:
	var description := Floor1Layout.describe(layout)
	assert_eq(description.start_rooms.size(), 6, "six havens to start from")
	assert_true(description.start_rooms.has(&"booth_security"))
	assert_eq(description.boss_room, &"court")
	assert_gt(description.objective_rooms.size(), 10)
	assert_eq(description.crystal_cases.size(), 0, "no crystal draw on Floor I")


func test_room_names_are_translated() -> void:
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	var keys := {}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			keys[line[0]] = true
	for room in layout.rooms:
		assert_ne(room.name_key, &"", "%s has a name" % room.id)
		assert_true(keys.has(String(room.name_key)), "%s name %s translated" % [room.id, room.name_key])
