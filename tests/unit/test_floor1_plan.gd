extends TestCase
## Floor1Plan, the contract the zone builders share: disjoint zones,
## junctions that pierce exactly the wall between their two zones, gates,
## havens, guardians and pickups that point at real areas, translation keys.

const CSV := "res://locale/strings.csv"


func _keys() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(CSV, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			rows[line[0]] = [line[1], line[2]]
	return rows


func _overlap(a: AABB, b: AABB) -> bool:
	var eps := 0.001
	return a.position.x < b.end.x - eps and b.position.x < a.end.x - eps \
		and a.position.y < b.end.y - eps and b.position.y < a.end.y - eps \
		and a.position.z < b.end.z - eps and b.position.z < a.end.z - eps


func test_every_zone_has_boxes_on_the_grid() -> void:
	for zone in Floor1Plan.ZONES:
		var boxes := Floor1Plan.zone_boxes(zone)
		assert_gt(boxes.size(), 0, str(zone))
		for box in boxes:
			for value in [box.position.x, box.position.z, box.end.x, box.end.z]:
				assert_true(ShellCarver.on_grid(value), "%s box %s on the 0.5 m grid" % [zone, box])
		assert_true(Floor1Plan.FLOOR_Y.has(zone), "%s floor height" % zone)
		assert_true(Floor1Plan.ZONE_COLORS.has(zone), "%s colour" % zone)
		assert_true(Floor1Plan.ZONE_NAME_KEYS.has(zone), "%s name" % zone)


func test_zones_never_overlap() -> void:
	var zones := Floor1Plan.ZONES
	for i in zones.size():
		for j in range(i + 1, zones.size()):
			for a in Floor1Plan.zone_boxes(zones[i]):
				for b in Floor1Plan.zone_boxes(zones[j]):
					assert_false(_overlap(a, b), "%s %s overlaps %s %s" % [zones[i], a, zones[j], b])


func test_the_floor_spans_about_178_by_138_metres() -> void:
	var bounds := Floor1Plan.bounds()
	assert_almost_eq(bounds.size.x, 177.0, 2.0, "east-west")
	assert_almost_eq(bounds.size.y, 139.0, 2.0, "north-south")
	assert_eq(Floor1Plan.zone_at(Vector3(0, 1, 0)), &"court", "the origin is in the Great Court")
	assert_eq(Floor1Plan.zone_at(Vector3(0, -4, 0)), &"basement")
	assert_eq(Floor1Plan.zone_at(Vector3(0, 25, 0)), &"roof")


func test_each_junction_pierces_the_wall_between_its_zones() -> void:
	var ids := {}
	for j in Floor1Plan.junctions():
		assert_false(ids.has(j.id), "unique id " + str(j.id))
		ids[j.id] = true
		assert_true(Floor1Plan.ZONES.has(j.zone_a) and Floor1Plan.ZONES.has(j.zone_b), str(j.id))
		assert_ne(j.zone_a, j.zone_b, str(j.id))
		for value in [j.rect.position.x, j.rect.position.y, j.rect.end.x, j.rect.end.y]:
			assert_true(ShellCarver.on_grid(value), "%s on the grid" % j.id)
		assert_true(j.width() >= 1.5, "%s at least 1.5 m wide" % j.id)
		assert_true(j.height() >= 2.5, "%s at least 2.5 m high" % j.id)
		# one side in each zone, nothing of either zone inside the opening
		var sides: Array[StringName] = []
		for point in j.side_points():
			sides.append(Floor1Plan.zone_at(point))
		assert_true(sides.has(j.zone_a) and sides.has(j.zone_b), "%s joins %s and %s, found %s" % [j.id, j.zone_a, j.zone_b, sides])
		var hole := AABB(Vector3(j.rect.position.x, j.floor_y, j.rect.position.y), Vector3(j.rect.size.x, j.height(), j.rect.size.y))
		for zone in Floor1Plan.ZONES:
			for box in Floor1Plan.zone_boxes(zone):
				assert_false(_overlap(hole, box), "%s lies in the wall, not in %s" % [j.id, zone])
		assert_true(Floor1Plan.zone_of_area(j.area_a) == j.zone_a and Floor1Plan.zone_of_area(j.area_b) == j.zone_b, "%s areas" % j.id)


func test_every_zone_is_joined_to_the_rest() -> void:
	var graph := RoomGraph.new()
	for j in Floor1Plan.junctions():
		graph.add_door(j.id, j.zone_a, j.zone_b)
	var reached := graph.reachable(&"booth")
	for zone in Floor1Plan.ZONES:
		assert_true(reached.has(zone), "%s reachable through junctions" % zone)


func test_every_wing_has_a_basement_shortcut_bolted_on_its_side() -> void:
	for wing in Floor1Plan.WINGS:
		var found := false
		for j in Floor1Plan.junctions_of(wing):
			if j.other(wing) == &"basement" and j.gate != &"":
				var gate := Floor1Plan.gate(j.gate)
				found = gate.kind == GateSpec.Kind.BOLT and Floor1Plan.zone_of_area(gate.bolt_area) == wing
		assert_true(found, "%s -> basement bolted from the wing" % wing)


func test_gates_match_their_junctions_and_areas() -> void:
	var areas := Floor1Plan.areas()
	var ids := {}
	for gate in Floor1Plan.gates():
		assert_false(ids.has(gate.id), "unique gate " + str(gate.id))
		ids[gate.id] = true
		assert_true(areas.has(gate.area_a) and areas.has(gate.area_b), "%s areas" % gate.id)
		if gate.kind == GateSpec.Kind.BOLT:
			assert_true(gate.bolt_area == gate.area_a or gate.bolt_area == gate.area_b, "%s bolt side" % gate.id)
		if gate.junction != &"":
			var j := Floor1Plan.junction(gate.junction)
			assert_not_null(j, "%s junction" % gate.id)
			if j != null:
				assert_eq(j.gate, gate.id, "%s is the junction's gate" % gate.id)
				var pair := [j.area_a, j.area_b]
				assert_true(pair.has(gate.area_a) and pair.has(gate.area_b), "%s joins its junction's areas" % gate.id)
		else:
			assert_true(Floor1Plan.INTERNAL_GATE_TARGETS.has(gate.id), "%s has a greybox target" % gate.id)
			assert_eq(Floor1Plan.zone_of_area(gate.area_a), Floor1Plan.zone_of_area(gate.area_b), "%s stays in one zone" % gate.id)
	for j in Floor1Plan.junctions():
		if j.gate != &"":
			assert_not_null(Floor1Plan.gate(j.gate), "%s gate %s is listed" % [j.id, j.gate])


func test_havens_guardians_and_pickups_are_complete() -> void:
	var areas := Floor1Plan.areas()
	assert_eq(Floor1Plan.havens().size(), 6, "six havens (design 4.5)")
	assert_not_null(Floor1Plan.haven(PersistentState.DEFAULT_HAVEN), "the booth is the first haven")
	for haven in Floor1Plan.havens():
		assert_true(areas.has(haven.area) and Floor1Plan.zone_of_area(haven.area) == haven.zone, str(haven.id))
	assert_eq(Floor1Plan.guardians().size(), 6, "a guardian per wing")
	var shards := {}
	for guardian in Floor1Plan.guardians():
		assert_true(Floor1Plan.WINGS.has(guardian.zone), str(guardian.id))
		assert_eq(Floor1Plan.zone_of_area(guardian.area), guardian.zone, str(guardian.id))
		assert_false(shards.has(guardian.shard), "one shard each")
		shards[guardian.shard] = true
		if guardian.seal != &"":
			assert_true(Floor1Plan.SEALS.has(guardian.seal), "%s seal" % guardian.id)
	assert_eq(shards.size(), Floor1Plan.SHARD_COUNT)
	for weapon: StringName in [&"pistol", &"flare", &"shotgun", &"gatling", &"rifle_hunt", &"harpoon", &"hwacha"]:
		assert_ne(Floor1Plan.weapon_zone(weapon), &"", "%s lies somewhere" % weapon)
	assert_eq(Floor1Plan.weapon_zone(&"shotgun"), &"egypt", "the shotgun is in Egypt, on the main path (design 1)")
	for pickup in Floor1Plan.pickups():
		assert_true(areas.has(pickup.area), "%s area" % pickup.id)
		assert_ne(pickup.marker, &"", "%s marker" % pickup.id)


func test_every_plan_key_is_translated() -> void:
	var rows := _keys()
	var keys: Array[StringName] = []
	keys.append_array(Floor1Plan.ZONE_NAME_KEYS.values())
	keys.append_array(Floor1Plan.SEALS.values())
	for gate in Floor1Plan.gates():
		keys.append(gate.label_key)
	for haven in Floor1Plan.havens():
		keys.append(haven.name_key)
	for guardian in Floor1Plan.guardians():
		keys.append(guardian.name_key)
		keys.append(guardian.title_key)
	for key in keys:
		assert_true(rows.has(String(key)), "strings.csv has " + String(key))
