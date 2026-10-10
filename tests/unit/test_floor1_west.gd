extends TestCase
## Floor I west wings as data (P1 / W3: zones/egypt.gd, zones/greece.gd;
## plan docs/superpowers/plans/2026-10-03-p1-w3-egipt-grecja.md): key room
## sizes, rooms apart inside their zone, junction rooms on their doorways,
## secrets behind zone gates, markers in their rooms, encounter sets and
## density, patrols and ambushes, stairs, the wing light recipes, and the
## shotgun on the main path in plain view of the court door.

const Egypt := preload("res://src/level/floor1/zones/egypt.gd")
const WEST: Array[StringName] = [&"egypt", &"greece"]
## What a secret's gate may ask for (all off the critical path).
const SECRET_NEEDS: Array[StringName] = [GateSpec.HEAVY, GateSpec.EXPLOSIVE, GateSpec.PRECISE, &"harpoon"]
## Exhibit kinds the game has today (each slot names one of them first).
const KNOWN_KINDS: Array[StringName] = [&"wax", &"wolf", &"knight", &"bust", &"raptor"]
## Eye height of the guard.
const EYE := 1.6
const GAP := 0.5
const EPS := 0.001

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _west_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in layout.rooms:
		if WEST.has(room.zone):
			found.append(room)
	return found


func _is_west(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and WEST.has(room.zone)


func _origin(marker: StringName) -> Vector3:
	return (layout.markers[marker] as Transform3D).origin


func test_key_rooms_have_their_sizes() -> void:
	var gallery := layout.room(&"egypt_gallery")
	assert_almost_eq(gallery.bounds().size.x, 16.0, EPS, "the Great Gallery is 16 m wide")
	assert_gt(gallery.bounds().size.y, 32.0, "and over 32 m long")
	assert_almost_eq(gallery.height(), 11.0, EPS, "and 11 m high")
	var arena := layout.room(&"egypt_colossus")
	assert_eq(arena.bounds().size, Vector2(24, 24), "the Colossus hall is 24 x 24")
	assert_almost_eq(arena.height(), 14.0, EPS)
	var vestibule := layout.room(&"egypt_vestibule")
	assert_lt(vestibule.height(), gallery.height(), "the vestibule is lower than the gallery (the reveal)")
	# the long view: from the vestibule's south wall to the arena's north wall
	assert_gt(vestibule.bounds().end.y - arena.bounds().position.y, 66.0, "a 66 m view down the wing")
	for tomb: StringName in [&"egypt_tomb_passage", &"egypt_tombs", &"egypt_tomb_hall"]:
		assert_true(layout.room(tomb).height() <= 4.5, "%s is low" % tomb)
	var parthenon := layout.room(&"greece_parthenon")
	assert_true(absf(parthenon.bounds().size.x - 40.0) <= 1.0, "the Parthenon gallery is about 40 m long")
	assert_almost_eq(parthenon.bounds().size.y, 18.0, EPS, "and 18 m wide")
	assert_almost_eq(parthenon.height(), 12.0, EPS)
	assert_gt(layout.room(&"greece_nereid").height(), 12.0, "the Nereid hall holds a temple on a podium")
	var tower := layout.room(&"greece_service_stairs")
	assert_eq(tower.floor_y, Floor1Plan.BASEMENT_Y, "the Greek tower starts in the basement")
	assert_gt(tower.ceiling_y, Floor1Plan.LANDING_Y + 2.6, "and reaches the entrance landing")
	assert_eq(layout.room(&"egypt_service_stairs").floor_y, Floor1Plan.BASEMENT_Y)
	for raised: StringName in [&"greece_nereid_podium", &"greece_bassae_gallery"]:
		var mezzanine := layout.room(raised)
		assert_false(mezzanine.carved, "%s stands inside its hall" % raised)
		assert_gt(mezzanine.floor_y, 4.0, "%s is a mezzanine" % raised)


func test_rooms_keep_apart_inside_their_zone() -> void:
	var carved: Array[RoomSpec] = []
	for room in layout.rooms:
		if room.carved:
			carved.append(room)
	for room in _west_rooms():
		for part in room.parts:
			assert_true(Floor1Plan.contains(room.zone, part, room.floor_y, room.ceiling_y + ShellCarver.ROOF_T), "%s part %s inside %s" % [room.id, part, room.zone])
		if not room.carved:
			continue
		for other in carved:
			if other == room:
				continue
			# stacked with a slab between them is fine
			if room.floor_y >= other.ceiling_y + GAP - EPS or other.floor_y >= room.ceiling_y + GAP - EPS:
				continue
			for a in room.parts:
				for b in other.parts:
					var gap_x := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
					var gap_z := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
					assert_true(maxf(gap_x, gap_z) >= GAP - EPS, "%s and %s keep a wall between them" % [room.id, other.id])


func test_junction_rooms_cover_their_doorways() -> void:
	for zone in WEST:
		for j in Floor1Plan.junctions_of(zone):
			var room_id := Floor1Layout.junction_room(layout, j, zone)
			assert_ne(room_id, &"", "%s has a %s room" % [j.id, zone])
			if room_id == &"":
				continue
			var room := layout.room(room_id)
			assert_true(room.floor_y <= j.floor_y + EPS and room.ceiling_y >= j.top_y - EPS, "%s spans %s's height" % [room_id, j.id])
			# every point along the doorway, just past the wall on this side
			var face := j.point_in(zone, 0.25, 0.5)
			var across := Vector3(0, 0, 1) if j.runs_along_x() else Vector3(1, 0, 0)
			var half := j.width() * 0.5 - 0.1
			for t in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var point: Vector3 = face + across * half * t
				assert_eq(layout.room_at(point), room_id, "%s: %s covers the doorway at %s" % [j.id, room_id, point])


func test_internal_doorways_join_their_rooms() -> void:
	for passage in layout.openings:
		if not (_is_west(passage.room_a) and _is_west(passage.room_b)):
			continue
		var axis := Vector3(1, 0, 0) if passage.runs_along_x() else Vector3(0, 0, 1)
		var middle := passage.center() + Vector3.UP
		var sides := [layout.room_at(middle - axis * (passage.depth() * 0.5 + 0.25)), layout.room_at(middle + axis * (passage.depth() * 0.5 + 0.25))]
		assert_true(sides.has(passage.room_a) and sides.has(passage.room_b), "%s joins %s and %s, found %s" % [passage.id, passage.room_a, passage.room_b, sides])
		var low := minf(layout.room(passage.room_a).ceiling_y, layout.room(passage.room_b).ceiling_y)
		assert_true(passage.top_y <= low + EPS, "%s fits under both ceilings" % passage.id)


func test_secret_rooms_sit_behind_zone_gates() -> void:
	var secrets := 0
	for room in _west_rooms():
		if not room.secret:
			continue
		secrets += 1
		assert_false(room.public, "%s is not printed on the map" % room.id)
		var ways := layout.openings.filter(func(o: OpeningSpec) -> bool: return o.room_a == room.id or o.room_b == room.id)
		assert_gt(ways.size(), 0, "%s has a way in" % room.id)
		for passage: OpeningSpec in ways:
			var gate := layout.gate_of_opening(passage.id)
			assert_not_null(gate, "%s: %s is gated" % [room.id, passage.id])
			if gate == null:
				continue
			assert_true(String(gate.id).begins_with(String(room.zone) + "_"), "%s is a zone gate" % gate.id)
			assert_true(SECRET_NEEDS.has(gate.requirement), "%s needs %s" % [gate.id, gate.requirement])
			assert_eq(passage.link, RoomGraph.Kind.GATE, "%s is shut in the room graph" % passage.id)
			assert_ne(gate.label_key, &"", "%s has a label" % gate.id)
	assert_eq(secrets, 6, "three secret rooms per wing")


func test_markers_lie_in_their_rooms() -> void:
	var wanted: Array[StringName] = [
		&"weapon_shotgun", &"guardian_colossus", &"guardian_centaur", &"rosetta_stone",
		&"arena_colossus_start", &"arena_colossus_door_1", &"arena_colossus_door_2",
		&"arena_centaur_start", &"arena_centaur_door_1", &"arena_centaur_door_2",
		&"museum_map_conservator", &"museum_map_cast_store", &"cctv_egypt_1", &"cctv_greece_1",
	]
	for i in 3:
		wanted.append(StringName("arena_colossus_supply_%d" % (i + 1)))
		wanted.append(StringName("arena_centaur_supply_%d" % (i + 1)))
	for i in Egypt.COLUMNS.size():
		wanted.append(StringName("colossus_column_%d" % (i + 1)))
	for marker in wanted:
		assert_true(layout.markers.has(marker), str(marker))
	for marker: StringName in layout.markers:
		var room_id: StringName = layout.marker_rooms.get(marker, &"")
		if not _is_west(room_id):
			continue
		var room := layout.room(room_id)
		var origin := _origin(marker)
		assert_true(room.covers(Vector2(origin.x, origin.z)), "%s lies over %s" % [marker, room_id])
		assert_true(origin.y >= room.floor_y - EPS and origin.y <= room.ceiling_y, "%s lies between %s's floor and ceiling" % [marker, room_id])
	assert_lt(Egypt.COLUMNS.size(), 9, "the arena keeps room to move")
	assert_gt(Egypt.COLUMNS.size(), 5, "enough columns to hide behind")


func test_three_secrets_and_three_or_four_notes_per_wing() -> void:
	for zone in WEST:
		var secrets := 0
		var notes := 0
		for marker: StringName in layout.markers:
			if String(marker).begins_with("secret_%s_" % zone):
				secrets += 1
				assert_true(layout.room(layout.marker_rooms[marker]).secret, "%s lies in a secret room" % marker)
			elif String(marker).begins_with("note_%s_" % zone):
				notes += 1
		assert_eq(secrets, 3, "%s: three secrets" % zone)
		assert_true(notes >= 3 and notes <= 4, "%s: three or four notes, found %d" % [zone, notes])


func test_one_chess_piece_per_wing() -> void:
	var found := {}
	for marker: StringName in layout.markers:
		if String(marker).begins_with("chess_") and _is_west(layout.marker_rooms[marker]):
			found[marker] = layout.room(layout.marker_rooms[marker]).zone
	assert_eq(found, {&"chess_2": &"egypt", &"chess_3": &"greece"})


func test_every_room_with_exhibits_has_two_sets_and_a_sane_density() -> void:
	for room in _west_rooms():
		var always := 0
		var sets := {}
		for slot in layout.spawn_slots:
			if slot.room != room.id:
				continue
			assert_false(room.haven, "no exhibit in the haven %s" % room.id)
			assert_false(slot.kinds.is_empty(), "%s: a slot without kinds" % room.id)
			if not slot.kinds.is_empty():
				assert_true(KNOWN_KINDS.has(slot.kinds[0]), "%s: %s comes first (stand-in)" % [room.id, slot.kinds[0]])
			if slot.set_id == SpawnSlot.ALWAYS_SET:
				always += 1
			else:
				sets[slot.set_id] = int(sets.get(slot.set_id, 0)) + 1
		if always == 0 and sets.is_empty():
			continue
		if not sets.is_empty():
			assert_true(sets.size() >= 2, "%s draws from at least two sets" % room.id)
		# density 0.6-1.2 exhibits per 100 m2 (small rooms: one or two)
		var low := maxi(1, floori(room.area() * 0.006))
		var high := maxi(2, ceili(room.area() * 0.012))
		var counts: Array[int] = []
		if sets.is_empty():
			counts.append(always)
		for id: int in sets:
			counts.append(int(sets[id]) + always)
		for count in counts:
			assert_true(count >= low and count <= high, "%s (%.0f m2): %d exhibits, want %d-%d" % [room.id, room.area(), count, low, high])


func test_patrols_and_ambushes() -> void:
	var walked := {}
	for slot in layout.spawn_slots:
		if slot.patrol != &"":
			walked[slot.patrol] = true
	for patrol in layout.patrols:
		if not _is_west(patrol.room):
			continue
		assert_true(walked.has(patrol.id), "somebody walks %s" % patrol.id)
		for point in patrol.points:
			assert_eq(layout.room_at(point + Vector3.UP), patrol.room, "%s point %s" % [patrol.id, point])
	var camp := layout.ambush(&"egypt_camp")
	assert_not_null(camp, "the mummies by the camp")
	if camp != null:
		assert_eq(camp.trigger, AmbushSpec.Trigger.PICKUP)
		assert_eq(camp.marker, &"weapon_shotgun", "taking the shotgun wakes them")
		assert_true(camp.slots.size() >= 3, "three or more sleepers")
		for index in camp.slots:
			assert_eq(layout.spawn_slots[index].set_id, SpawnSlot.ALWAYS_SET, "the camp ambush is there every night")
	var ambushes := 0
	for ambush in layout.ambushes:
		if not _is_west(ambush.room):
			continue
		ambushes += 1
		for index in ambush.slots:
			var slot := layout.spawn_slots[index]
			assert_eq(slot.room, ambush.room, "%s wakes exhibits of its own room" % ambush.id)
			assert_true(slot.dormant, "%s: its sleepers sleep" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.AREA:
			var room := layout.room(ambush.room)
			var middle := ambush.area.get_center()
			assert_true(room.covers(middle), "%s's area lies in %s" % [ambush.id, ambush.room])
	assert_gt(ambushes, 6, "ambushes in both wings")


func test_stairs_never_steeper_than_the_plan() -> void:
	var flights := 0
	for flight in layout.stairs:
		if not _is_west(flight.room_low):
			continue
		flights += 1
		assert_true((flight.top_y - flight.bottom_y) / flight.run() <= Floor1Plan.STAIR_SLOPE + EPS, "%s is no steeper than 20.6 degrees" % flight.id)
	assert_gt(flights, 6, "service stairs, the tower and two mezzanine stairs")


## From 2.5 m inside the court door and from the vestibule's middle, at eye
## height, to the shotgun on the camp table: every point of the line lies in
## a room or a doorway (never in a wall) and passes no solid piece.
func test_the_shotgun_is_in_plain_view_of_the_court_door() -> void:
	var j := Floor1Plan.junction(&"j_court_egypt")
	var target := _origin(&"weapon_shotgun") + Vector3.UP * 0.15
	var vestibule := layout.room(&"egypt_vestibule").bounds().get_center()
	for from: Vector3 in [j.point_in(&"egypt", 2.5, EYE), Vector3(vestibule.x, EYE, vestibule.y)]:
		var blocked := _first_obstacle(from, target)
		assert_eq(blocked, "", "the shotgun is seen from %s (%s)" % [from, blocked])
	# the check itself sees walls: the conservator's room is out of sight
	var haven: Vector3 = (layout.haven_spots[&"conservator"] as Transform3D).origin + Vector3.UP
	assert_ne(_first_obstacle(j.point_in(&"egypt", 2.5, EYE), haven), "", "walls block the view")


func test_the_shotgun_needs_no_gate() -> void:
	var j := Floor1Plan.junction(&"j_court_egypt")
	var start := Floor1Layout.junction_room(layout, j, &"egypt")
	var reached := layout.graph().reachable(start)
	assert_true(reached.has(layout.marker_rooms[&"weapon_shotgun"]), "the shotgun lies on the main path")
	assert_eq(layout.marker_rooms[&"weapon_shotgun"], &"egypt_gallery")
	assert_true(reached.has(layout.marker_rooms[&"guardian_colossus"]), "the Colossus is open to night 1")


func test_havens_are_dead_ends() -> void:
	for haven: StringName in [&"egypt_conservator", &"greece_cast_store"]:
		var open_ways := layout.openings.filter(func(o: OpeningSpec) -> bool: return (o.room_a == haven or o.room_b == haven) and layout.gate_of_opening(o.id) == null)
		assert_eq(open_ways.size(), 1, "%s has one door" % haven)


func test_lights_follow_the_wing_recipe() -> void:
	var lit := {}
	var shadows := 0
	for light in layout.lights:
		if light.group == LightSpec.MAIN:
			lit[light.room] = true
		if _is_west(light.room) and light.shadow:
			shadows += 1
	for room in _west_rooms():
		if room.public and room.carved:
			assert_true(lit.has(room.id), "%s has lamps" % room.id)
	assert_lt(shadows, 14, "shadows only where they show")
	# Greece is the bright wing: more sky per square metre than Egypt
	var sky := {&"egypt": 0.0, &"greece": 0.0}
	var floor_area := {&"egypt": 0.0, &"greece": 0.0}
	for room in _west_rooms():
		floor_area[room.zone] += room.area()
		for well in room.skylights:
			sky[room.zone] += well.get_area()
	assert_gt(sky[&"greece"] / floor_area[&"greece"], sky[&"egypt"] / floor_area[&"egypt"], "Greece has more moonlight than Egypt")
	# the camp: a warm lamp with a shadow by the shotgun
	var gun := _origin(&"weapon_shotgun")
	var camp := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"egypt_gallery" and l.shadow and l.position.distance_to(gun) < 4.0 and l.color.r > l.color.b)
	assert_gt(camp.size(), 0, "the camp is lit warm")
	# warm spotlights on the Colossus
	var seat := _origin(&"guardian_colossus") + Vector3.UP * 6.0
	var on_him := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"egypt_colossus" and l.kind == LightSpec.Kind.SPOT and l.direction.angle_to(seat - l.position) < deg_to_rad(8.0))
	assert_gt(on_him.size(), 1, "spotlights on the Colossus")
	for haven: StringName in [&"egypt_conservator", &"greece_cast_store"]:
		assert_gt(layout.lights.filter(func(l: LightSpec) -> bool: return l.room == haven and l.group == LightSpec.HAVEN).size(), 0, "%s keeps its lamps in a blackout" % haven)



## The first thing between [param from] and [param to] ("" = nothing): a
## wall (a point in no room and no doorway) or a solid piece.
func _first_obstacle(from: Vector3, to: Vector3) -> String:
	var steps := int(from.distance_to(to) / 0.1)
	for i in range(1, steps):
		var point := from.lerp(to, float(i) / steps)
		if not _in_space(point):
			return "wall at %s" % point.snapped(Vector3.ONE * 0.01)
		if Vector2(point.x - to.x, point.z - to.z).length() < 0.6:
			continue   # the camp table under the gun
		for piece in layout.pieces:
			if not piece.collide:
				continue
			if point.y < piece.position.y or point.y > piece.position.y + piece.size.y:
				continue
			if piece.footprint().has_point(Vector2(point.x, point.z)):
				return "%s at %s" % [piece.kit, piece.position]
	return ""


func _in_space(point: Vector3) -> bool:
	for room in layout.rooms:
		if room.carved and room.contains(point, 0.0):
			return true
	for passage in layout.openings:
		if point.y >= passage.floor_y and point.y <= passage.top_y and passage.rect.has_point(Vector2(point.x, point.z)):
			return true
	return false
