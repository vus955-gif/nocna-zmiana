extends TestCase
## The hub of Floor I as data (workstream W2: court, entrance, booth,
## north_hall; plan docs/superpowers/plans/2026-10-03-p1-w2-hub.md): rooms
## in their zones with names, walls between rooms, the key sizes, junction
## rooms flush with their doorways, the Reading Room's drum, balcony and
## stairs, the internal gates, every marker the game places, the secret
## rooms, spawn sets (density, free floor, the gentle first night), patrols,
## ambushes and the lights (no lamp shines through the drum's wall).

const HUB_ZONES: Array[StringName] = [&"booth", &"entrance", &"court", &"north_hall"]
## Rooms inside another room's space -> the room they stand in.
const NESTED := {
	&"court_reading": &"court", &"court_balcony": &"court",
	&"entrance_gallery": &"entrance_hall", &"north_hall_crypt_vault": &"north_hall_crypt",
}
const HUB := preload("res://src/level/floor1/zones/hub_kit.gd")
const COURT := preload("res://src/level/floor1/zones/court.gd")
## The staff door the guard first steps out of (junction j_entrance_booth).
const BOOTH_DOOR := Vector2(16.5, 42.0)
const MAX_SLOPE := Floor1Plan.STAIR_SLOPE + 0.001
## An exhibit or loot needs this much free floor round its point (m).
const CLEARANCE := 0.5
const BODY_HEIGHT := 1.8

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _hub_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in layout.rooms:
		if HUB_ZONES.has(room.zone):
			found.append(room)
	return found


func _is_hub_room(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and HUB_ZONES.has(room.zone)


# --- rooms -------------------------------------------------------------------

func test_hub_rooms_lie_in_their_zones_with_names() -> void:
	var keys := _translation_keys()
	var rooms := _hub_rooms()
	assert_gt(rooms.size(), 15, "the hub has its rooms")
	for room in rooms:
		assert_true(String(room.id).begins_with(String(room.zone)), "%s named after its zone" % room.id)
		assert_true(keys.has(String(room.name_key)), "%s: name %s translated" % [room.id, room.name_key])
		for part in room.parts:
			assert_true(Floor1Plan.contains(room.zone, part, room.floor_y, room.ceiling_y + ShellCarver.ROOF_T), "%s part %s in zone %s" % [room.id, part, room.zone])
			for value in [part.position.x, part.position.y, part.end.x, part.end.y]:
				assert_true(ShellCarver.on_grid(value), "%s on the grid" % room.id)
		if room.secret or room.haven:
			assert_false(room.public, "%s is not on the visitors' map" % room.id)
	for staff: StringName in [&"booth_corridor", &"booth_staff", &"booth_stairs", &"north_hall_crypt", &"north_hall_crypt_vault"]:
		assert_false(layout.room(staff).public, "%s is staff only" % staff)
	for visitors: StringName in [&"court", &"court_reading", &"court_balcony", &"entrance_hall", &"entrance_gallery", &"entrance_cloakroom", &"north_hall"]:
		assert_true(layout.room(visitors).public, "%s is printed on the map" % visitors)
	for secret: StringName in [&"booth_watch", &"entrance_coat_store", &"north_hall_lodge"]:
		assert_true(layout.room(secret).secret, "%s is secret" % secret)


func test_carved_rooms_keep_a_wall_between_them() -> void:
	var rooms := _hub_rooms()
	for i in rooms.size():
		for k in range(i + 1, rooms.size()):
			var a := rooms[i]
			var b := rooms[k]
			if NESTED.get(a.id, &"") == b.id or NESTED.get(b.id, &"") == a.id or not a.carved or not b.carved:
				continue
			if a.floor_y >= b.ceiling_y + ShellCarver.ROOF_T or b.floor_y >= a.ceiling_y + ShellCarver.ROOF_T:
				continue   # stacked: a slab between them
			for pa in a.parts:
				for pb in b.parts:
					assert_false(pa.grow(0.49).intersects(pb), "%s and %s need 0.5 m of wall (%s, %s)" % [a.id, b.id, pa, pb])
	for guest: StringName in NESTED:
		var host := layout.room(NESTED[guest])
		var room := layout.room(guest)
		assert_true(room.floor_y >= host.floor_y and room.ceiling_y <= host.ceiling_y + 0.01, "%s stands in %s" % [guest, host.id])
		for part in room.parts:
			for corner in [part.position, part.end, Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.position.y)]:
				assert_true(host.covers(corner), "%s lies inside %s" % [guest, host.id])
	# the Reading Room wins room_at inside the drum, the court outside it
	assert_eq(layout.room_at(Vector3(0, 1, 5)), &"court_reading")
	assert_eq(layout.room_at(Vector3(0, 1, 16)), &"court")
	assert_eq(layout.room_at(Vector3(0, 8, -14.4)), &"court_balcony")
	for part in COURT.reading_parts():
		for corner in [part.position, part.end, Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.position.y)]:
			assert_lt(_drum_apothem(Vector3(corner.x, 0, corner.y)), COURT.DRUM_IN + 0.01, "Reading Room part %s inside the drum" % part)


func test_key_rooms_have_their_sizes() -> void:
	var court := layout.room(&"court")
	assert_eq(court.bounds(), Rect2(-30, -30, 60, 60), "the court is 60 x 60")
	assert_almost_eq(court.ceiling_y, 22.0, 0.01, "under the glass roof")
	var hall := layout.room(&"entrance_hall")
	assert_eq(hall.bounds(), Rect2(-16, 31, 32, 22), "the entrance hall is 32 x 22")
	assert_almost_eq(hall.height(), 12.0, 0.01)
	assert_almost_eq(layout.room(&"entrance_gallery").floor_y, Floor1Plan.LANDING_Y, 0.01, "the landing at y 6")
	assert_almost_eq(layout.room(&"court_balcony").floor_y, 7.0, 0.01, "the balcony at y 7")
	assert_almost_eq(layout.room(&"court_reading").ceiling_y, 20.0, 0.01, "the dome at 20")
	assert_true(layout.room(&"booth_security").haven, "the booth is the start haven")
	assert_almost_eq(layout.room(&"north_hall_crypt").floor_y, -12.0, 0.01, "the stairs go on into the dark")
	assert_almost_eq(layout.room(&"north_hall_crypt_vault").floor_y, Floor1Plan.BASEMENT_Y, 0.01)
	assert_eq(layout.room_at(layout.player_start.origin + Vector3.UP), &"booth_security")


func test_every_hub_junction_has_a_flush_room() -> void:
	for zone in HUB_ZONES:
		for j in Floor1Plan.junctions_of(zone):
			var axis := Vector3(1, 0, 0) if j.runs_along_x() else Vector3(0, 0, 1)
			var across := Vector3(0, 0, 1) if j.runs_along_x() else Vector3(1, 0, 0)
			var side := j.point_in(zone)
			assert_ne(side, Vector3.INF, "%s has a %s side" % [j.id, zone])
			if side == Vector3.INF:
				continue
			var out := (side - j.center() - Vector3.UP).dot(axis)
			var found: StringName = &""
			var t := -j.width() * 0.5 + 0.125
			while t < j.width() * 0.5:
				var point := j.center() + axis * out + across * t + Vector3.UP
				var room_id := layout.room_at(point)
				var room := layout.room(room_id)
				assert_not_null(room, "%s: a room behind every bit of the doorway (%s)" % [j.id, point])
				if room == null:
					break
				assert_eq(room.zone, zone, "%s on the %s side" % [j.id, zone])
				assert_almost_eq(room.floor_y, j.floor_y, 0.01, "%s: %s's floor at the doorway" % [j.id, room_id])
				var carved := room if room.carved else layout.room(NESTED.get(room_id, &""))
				assert_true(carved != null and carved.ceiling_y >= j.top_y - 0.01, "%s: %s reaches the top of the doorway" % [j.id, room_id])
				if found == &"":
					found = room_id
				assert_eq(room_id, found, "%s: one room along the whole doorway" % j.id)
				t += 0.25


func test_drum_balcony_and_stairs() -> void:
	var segments := 0
	for piece in layout.pieces:
		if piece.kit != &"wall" or piece.room != &"court_reading":
			continue
		segments += 1
		var outward := HUB.direction(-rad_to_deg(piece.yaw))
		var face := Vector3(piece.position.x, 0, piece.position.z).dot(outward) + piece.size.z * 0.5
		assert_almost_eq(face, COURT.DRUM_OUT, 0.02, "drum segment's outer face on the 16-gon")
		assert_almost_eq(piece.size.y, 22.0 - piece.position.y, 0.01, "the drum reaches the roof")
	assert_eq(segments, 18, "15 segments, two jambs and the wall over the north portal")
	var door := layout.opening(&"court_reading_door")
	assert_not_null(door)
	assert_eq(door.link, RoomGraph.Kind.GATE)
	assert_almost_eq(door.width(), 3.0, 0.01, "the portal is 3 m wide (the art's drum portal)")
	assert_lt(door.center().z, -11.0, "the Reading Room's door faces north, towards the T-Rex")
	var slabs := 0
	for piece in layout.pieces:
		if piece.kit == &"balcony" and absf(piece.position.y + piece.size.y - 7.0) < 0.01:
			slabs += 1
	assert_eq(slabs, 9, "seven ring slabs and two landings at y 7")
	for flight in layout.stairs:
		if not _is_hub_room(flight.room_low):
			continue
		assert_lt((flight.top_y - flight.bottom_y) / flight.run(), MAX_SLOPE, "%s at most 20.6 deg" % flight.id)
	for id: StringName in [&"court_stairs_w", &"court_stairs_e"]:
		var flight: StairsSpec = null
		for candidate in layout.stairs:
			if candidate.id == id:
				flight = candidate
		assert_not_null(flight, str(id))
		if flight == null:
			continue
		var top := Vector3(flight.rect.get_center().x, 7.0, flight.rect.position.y - 0.5)
		assert_true(_on_slab(top), "%s arrives on the balcony (%s)" % [id, top])
		assert_eq(layout.room_at(top + Vector3.UP), &"court_balcony")
	var trex: Transform3D = layout.markers[Floor1Plan.TREX_MARKER]
	assert_lt(trex.origin.z, -COURT.BALCONY_OUT - 2.0, "the T-Rex stands north of the drum, clear of the balcony")
	assert_lt(absf(trex.origin.x), 0.01)


func test_internal_gates() -> void:
	var reading := layout.gate(&"gate_reading_room")
	assert_not_null(reading)
	assert_eq(reading.kind, GateSpec.Kind.SEAL)
	assert_eq(reading.requirement, &"seal_owl")
	assert_eq(reading.opening, &"court_reading_door")
	var door := layout.opening(&"court_reading_door")
	assert_eq([layout.room(door.room_a).progress_area(), layout.room(door.room_b).progress_area()], [&"court", &"reading_room"])
	var chain := layout.gate(&"chain_gatling")
	assert_not_null(chain)
	assert_eq(chain.kind, GateSpec.Kind.CHAIN)
	assert_eq(chain.requirement, GateSpec.HEAVY)
	assert_eq(chain.marker, &"gatling_case")
	assert_eq(layout.marker_rooms[&"gatling_case"], &"court_reading")
	var grate := layout.gate(&"grate_crypt")
	assert_not_null(grate)
	assert_eq(grate.kind, GateSpec.Kind.EVENT)
	assert_eq(grate.requirement, &"trex_defeated")
	var passage := layout.opening(&"north_hall_grate")
	assert_eq([layout.room(passage.room_a).progress_area(), layout.room(passage.room_b).progress_area()], [&"north_hall", &"crypt"])
	# besides the plan's gates only zone gates off the critical path (the
	# secrets), named after their zone
	for gate in layout.gates:
		if gate.opening == &"" or String(gate.opening).begins_with("j_"):
			continue
		var way := layout.opening(gate.opening)
		var room := layout.room(way.room_a)
		if room == null or not HUB_ZONES.has(room.zone) or Floor1Plan.gate(gate.id) != null:
			continue
		assert_true(String(gate.id).begins_with(String(room.zone) + "_"), "zone gate %s named after %s" % [gate.id, room.zone])
		assert_true(layout.room(way.room_b).secret, "zone gate %s guards a secret" % gate.id)


# --- markers -------------------------------------------------------------------

func test_markers_are_there_and_inside_their_rooms() -> void:
	var wanted: Array[StringName] = [
		&"pistol_locker", &"cctv_wall", &"museum_map_booth", &"note_heniek",
		&"ticket_drawer", &"flare_cabinet", &"museum_exit", &"museum_map_entrance",
		&"gatling_case", &"astrolabe", &"crystal_path_1", &"crystal_path_2", &"crystal_path_3",
		Floor1Plan.TREX_MARKER, &"museum_map_court", Floor1Plan.EXIT_MARKER, &"chess_1",
		&"sign_court_1", &"sign_greece_1", &"sign_egypt_1", &"sign_enlightenment_1", &"sign_north_hall_1",
		&"sign_americas_1", &"sign_asia_1",
	]
	for id in wanted:
		assert_true(layout.markers.has(id), str(id))
	var counts := {
		# six cameras and the booth's monitor wall; four notes and Heniek's
		"cctv_": 7, "note_": 5, "secret_": 4, "chess_": 1, "arena_trex_supply_": 9, "arena_trex_start": 1,
		"arena_trex_raptor_": 4, "arena_trex_door_": 4, "crystal_path_": 3, "museum_map_": 3,
	}
	for prefix: String in counts:
		var found := 0
		for id: StringName in layout.markers:
			if String(id).begins_with(prefix) and _is_hub_room(layout.marker_rooms[id]):
				found += 1
		assert_eq(found, counts[prefix], "%s markers in the hub" % prefix)
	for id: StringName in layout.markers:
		if not _is_hub_room(layout.marker_rooms[id]):
			continue
		var room := layout.room(layout.marker_rooms[id])
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		assert_true(room.covers(Vector2(at.x, at.z)), "%s lies over %s" % [id, room.id])
		assert_true(at.y >= room.floor_y - 0.3 and at.y <= room.ceiling_y, "%s between %s's floor and ceiling" % [id, room.id])
	assert_eq(layout.marker_rooms[&"ticket_drawer"], &"entrance_hall")
	assert_eq(layout.marker_rooms[&"flare_cabinet"], &"entrance_hall")
	assert_eq(layout.marker_rooms[&"pistol_locker"], &"booth_security")
	assert_eq(layout.marker_rooms[&"astrolabe"], &"court_reading")
	assert_eq(layout.marker_rooms[Floor1Plan.EXIT_MARKER], &"north_hall_crypt")
	# the lens of every camera looks down into its room
	for id: StringName in layout.markers:
		if String(id).begins_with("cctv_") and id != &"cctv_wall" and _is_hub_room(layout.marker_rooms[id]):
			var lens: Transform3D = layout.markers[id]
			assert_lt((-lens.basis.z).y, -0.05, "%s looks down" % id)


func test_secret_rooms_hide_behind_one_zone_gate() -> void:
	var markers := {&"booth_watch": &"secret_booth_1", &"entrance_coat_store": &"secret_entrance_1", &"north_hall_lodge": &"secret_north_hall_1"}
	var kinds := {}
	for room in _hub_rooms():
		if not room.secret:
			continue
		var ways: Array[OpeningSpec] = []
		for passage in layout.openings:
			if passage.room_a == room.id or passage.room_b == room.id:
				ways.append(passage)
		assert_eq(ways.size(), 1, "%s has one way in" % room.id)
		if ways.size() != 1:
			continue
		assert_eq(ways[0].link, RoomGraph.Kind.GATE, "%s behind a gate" % room.id)
		var gate := layout.gate_of_opening(ways[0].id)
		assert_not_null(gate, "%s's gate" % room.id)
		if gate != null:
			assert_true(String(gate.id).begins_with(String(room.zone) + "_"), "%s: zone gate %s" % [room.id, gate.id])
			kinds[gate.kind] = true
		assert_true(markers.has(room.id), "%s has its secret marker" % room.id)
		var marker: Transform3D = layout.markers.get(markers.get(room.id, &""), Transform3D())
		assert_eq(layout.marker_rooms.get(markers.get(room.id, &""), &""), room.id, "%s's marker lies inside" % room.id)
		assert_true(room.covers(Vector2(marker.origin.x, marker.origin.z)), "%s's marker over its floor" % room.id)
	assert_eq(kinds.size(), 3, "three different locks: chain, cracked wall, rope")
	var desk := (layout.markers[&"secret_court_1"] as Transform3D).origin
	assert_lt(Vector2(desk.x, desk.z).distance_to(Vector2(0, 21)), 2.0, "the hidden drawer is at the information desk")


# --- encounters ----------------------------------------------------------------

func test_spawn_sets_density_and_free_floor() -> void:
	var by_room := {}
	for slot in layout.spawn_slots:
		if not _is_hub_room(slot.room):
			continue
		assert_eq(layout.room_at(slot.position + Vector3.UP), slot.room, "slot %s in %s" % [slot.position, slot.room])
		assert_false(layout.room(slot.room).haven, "no exhibit in a haven")
		_assert_free_floor(slot.position, slot.room, "slot")
		if not by_room.has(slot.room):
			by_room[slot.room] = {}
		var sets: Dictionary = by_room[slot.room]
		sets[slot.set_id] = int(sets.get(slot.set_id, 0)) + 1
	for room_id: StringName in by_room:
		var sets: Dictionary = by_room[room_id]
		var always: int = sets.get(SpawnSlot.ALWAYS_SET, 0)
		var drawn := sets.keys().filter(func(id: int) -> bool: return id != SpawnSlot.ALWAYS_SET)
		assert_true(drawn.size() >= 2, "%s has at least two sets" % room_id)
		var area := layout.room(room_id).area()
		for set_id: int in drawn:
			var density := (int(sets[set_id]) + always) * 100.0 / area
			assert_true(density >= 0.6 and density <= 1.2, "%s set %d: %.2f exhibits per 100 m2" % [room_id, set_id, density])
	for room_id: StringName in [&"booth_corridor", &"booth_staff", &"booth_stairs", &"booth_security", &"north_hall_crypt", &"north_hall_crypt_vault"]:
		assert_false(by_room.has(room_id), "no exhibits in %s" % room_id)
	for spot in layout.loot_spots:
		if not _is_hub_room(spot.room):
			continue
		assert_eq(layout.room_at(spot.position + Vector3.UP), spot.room, "loot %s in %s" % [spot.position, spot.room])
		if spot.position.y <= layout.room(spot.room).floor_y + 0.01:
			_assert_free_floor(spot.position, spot.room, "loot")


func test_night_one_route_is_gentle() -> void:
	# nothing lies only behind the haven (its floor is a navmesh of its own)
	var opened: Array[StringName] = []
	for gate in layout.gates:
		if gate.opening != &"":
			opened.append(gate.opening)
	var graph := layout.graph()
	var through_havens: Array[StringName] = []
	for room in layout.rooms:
		if room.haven:
			through_havens.append_array(graph.doors_of_room(room.id))
	var reached := graph.reachable(&"booth_corridor", through_havens, opened)
	for room in _hub_rooms():
		if not room.haven:
			assert_true(reached.has(room.id), "%s reachable without walking through a haven" % room.id)
	var route: Array[StringName] = [&"booth_corridor", &"booth_staff", &"booth_stairs", &"entrance_hall", &"entrance_gallery", &"entrance_cloakroom", &"court", &"court_balcony"]
	var walkers := 0
	for slot in layout.spawn_slots:
		if slot.zone == &"booth" or slot.zone == &"entrance":
			assert_false(slot.kinds.has(&"wolf") or slot.kinds.has(&"raptor"), "no hunters near the booth (%s)" % slot.position)
		if slot.kinds.has(&"wolf") or slot.kinds.has(&"raptor"):
			if _is_hub_room(slot.room):
				assert_gt(Vector2(slot.position.x, slot.position.z).distance_to(BOOTH_DOOR), 30.0, "hunters far from the staff door")
		if not route.has(slot.room):
			continue
		assert_ne(slot.set_id, SpawnSlot.ALWAYS_SET, "nothing on the first night's route every night (%s)" % slot.room)
		if slot.set_id != 0:
			continue
		for kind in slot.kinds:
			assert_true([&"wax", &"bust"].has(kind), "set 0 on the route: figures and busts only (%s)" % kind)
		if slot.patrol != &"":
			walkers += 1
			assert_eq(slot.kinds, [&"wax"] as Array[StringName], "the walkers are wax figures")
		else:
			assert_true(slot.dormant, "set 0 on the route sleeps (%s)" % slot.position)
	assert_true(walkers >= 1 and walkers <= 2, "one or two figures walk the route on the first night (%d)" % walkers)


func test_patrols_and_ambushes() -> void:
	for patrol in layout.patrols:
		if not _is_hub_room(patrol.room):
			continue
		assert_true(patrol.points.size() >= 2, str(patrol.id))
		for point in patrol.points:
			assert_eq(layout.room_at(point + Vector3.UP), patrol.room, "%s point %s in its room" % [patrol.id, point])
			_assert_free_floor(point, patrol.room, "patrol %s" % patrol.id)
		var walkers := layout.spawn_slots.filter(func(slot: SpawnSlot) -> bool: return slot.patrol == patrol.id)
		assert_eq(walkers.size(), 1, "%s has its walker" % patrol.id)
		if walkers.size() == 1:
			assert_false((walkers[0] as SpawnSlot).dormant, "%s's walker is awake" % patrol.id)
	var ids: Array[StringName] = []
	for ambush in layout.ambushes:
		if not _is_hub_room(ambush.room):
			continue
		ids.append(ambush.id)
		assert_gt(ambush.slots.size(), 0, str(ambush.id))
		for index in ambush.slots:
			assert_eq(layout.spawn_slots[index].room, ambush.room, "%s wakes its own room's exhibits" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.AREA:
			var middle := ambush.area.get_center()
			var y := (ambush.y_min + ambush.y_max) * 0.5
			assert_true(layout.room(ambush.room).covers(middle) or layout.room_at(Vector3(middle.x, y, middle.y)) != &"", "%s's trigger lies on the floor" % ambush.id)
	for id: StringName in [&"court_gatling", &"north_hall_gate", &"court_trex_pack"]:
		assert_true(ids.has(id), "ambush %s" % id)
	assert_eq(layout.ambush(&"court_gatling").marker, &"gatling_case")


# --- light ---------------------------------------------------------------------

func test_lights() -> void:
	var lit := {}
	var moons := 0
	var reds := 0
	for spec in layout.lights:
		lit[spec.room] = true
		if spec.room == &"court" and spec.group == HUB.MOON_GROUP and spec.color == HUB.MOON:
			moons += 1
		if spec.room == &"court" and spec.color == HUB.RED:
			reds += 1
	for room in _hub_rooms():
		assert_true(lit.has(room.id), "%s has a lamp" % room.id)
	assert_gt(moons, 2, "moonlight through the court's roof")
	assert_gt(reds, 1, "red emergency lamps in the court")
	var haven := layout.lights.filter(func(spec: LightSpec) -> bool: return spec.room == &"booth_security" and spec.group == LightSpec.HAVEN)
	assert_gt(haven.size(), 0, "the booth keeps its own light")
	# walls stop light; lamps without shadows must not reach through the drum
	var inside: Array[Vector3] = []
	for part in COURT.reading_parts():
		var x := part.position.x + 0.25
		while x < part.end.x:
			var z := part.position.y + 0.25
			while z < part.end.y:
				inside.append(Vector3(x, 1.3, z))
				z += 1.0
			x += 1.0
	var outside: Array[Vector3] = []
	for k in 32:
		for radius in [12.6, 14.0, 16.0, 19.0]:
			outside.append(HUB.at_bearing(radius, k * 11.25, 1.3))
			outside.append(HUB.at_bearing(radius, k * 11.25, 8.3))
	for spec in layout.lights:
		var court_side := spec.room == &"court" or spec.room == &"court_balcony"
		if not court_side and spec.room != &"court_reading":
			continue
		var probes := inside if court_side else outside
		for point in probes:
			var light := LayoutIllumination.contribution(spec, point)
			if light > 0.0:
				fail("a %s lamp at %s lights %s through the drum's wall (%.2f)" % [spec.room, spec.position, point, light])
				break


# --- helpers -------------------------------------------------------------------

## Distance of [param point] from the drum's centre along its nearest
## face's normal (the 16-gon's own "radius").
func _drum_apothem(point: Vector3) -> float:
	var best := 0.0
	for j in 16:
		best = maxf(best, Vector3(point.x, 0, point.z).dot(HUB.direction(j * 22.5)))
	return best


## True when [param point] lies on top of a balcony slab.
func _on_slab(point: Vector3) -> bool:
	for piece in layout.pieces:
		if piece.kit != &"balcony" or absf(piece.position.y + piece.size.y - point.y) > 0.01:
			continue
		if _local_inside(piece, point, -0.05):
			return true
	return false


## [param point] (floor plan) inside [param piece]'s rotated footprint grown
## by [param margin].
func _local_inside(piece: PieceSpec, point: Vector3, margin: float) -> bool:
	var local := Basis(Vector3.UP, -piece.yaw) * Vector3(point.x - piece.position.x, 0, point.z - piece.position.z)
	var scale := 1.35 if piece.kit == &"column" else 1.0
	return absf(local.x) <= piece.size.x * scale * 0.5 + margin and absf(local.z) <= piece.size.z * scale * 0.5 + margin


## A body standing at [param point] fits: no solid piece or flight within
## CLEARANCE, room round it on every side, not over a marker's prop.
func _assert_free_floor(point: Vector3, room_id: StringName, what: String) -> void:
	var room := layout.room(room_id)
	for offset in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
		var near: Vector3 = point + offset
		if not room.covers(Vector2(near.x, near.z)):
			fail("%s %s too close to %s's edge" % [what, point, room_id])
			return
	for piece in layout.pieces:
		if not piece.collide:
			continue
		var bottom := piece.position.y
		var top := piece.position.y + piece.size.y
		if top <= point.y + 0.05 or bottom >= point.y + BODY_HEIGHT:
			continue
		if _local_inside(piece, point, CLEARANCE):
			fail("%s %s inside or by %s at %s" % [what, point, piece.kit, piece.position])
			return
	for flight in layout.stairs:
		if flight.top_y <= point.y + 0.05 or flight.bottom_y >= point.y + BODY_HEIGHT:
			continue
		if flight.rect.grow(CLEARANCE).has_point(Vector2(point.x, point.z)):
			fail("%s %s on the stairs %s" % [what, point, flight.id])
			return
	# props the game places on markers: the gatling's plinth, the astrolabe
	for id: StringName in [&"gatling_case", &"astrolabe"]:
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		if Vector2(at.x - point.x, at.z - point.z).length() < 1.6 and absf(at.y - point.y) < 2.0:
			fail("%s %s on the %s's prop" % [what, point, id])
			return


func _translation_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			keys[line[0]] = true
	return keys
