extends TestCase
## Floor I east wings as data (P1 / W5a: zones/enlightenment.gd,
## zones/asia.gd; plan docs/superpowers/plans/2026-10-03-p1-w5a-oswiecenie-azja.md):
## rooms in their zones with names, walls between rooms, the key sizes,
## junction rooms on their doorways, the internal gates, the Planetarium's
## rope out of the pistol's reach and in the rifle's sight, secrets behind
## zone gates, markers in their rooms, encounter sets, density and free
## floor, patrols and ambushes, stairs, the rifle on the main path in plain
## view, the havens as dead ends and the wing light recipes.

const EAST: Array[StringName] = [&"enlightenment", &"asia"]
## Rooms standing inside another room's space -> their host.
const NESTED := {
	&"enlightenment_library_gallery": &"enlightenment_library",
	&"enlightenment_observatory": &"enlightenment_planetarium",
}
## What a secret's gate may ask for (all off the critical path).
const SECRET_NEEDS: Array[StringName] = [GateSpec.HEAVY, GateSpec.EXPLOSIVE, GateSpec.PRECISE, &"harpoon"]
## Exhibit kinds the game has today (each slot names one of them first).
const KNOWN_KINDS: Array[StringName] = [&"wax", &"wolf", &"knight", &"bust", &"raptor"]
## RopeLock (p1-weapons): the pulley 6 m over its origin, the weight 3 m
## under the pulley; the pistol cuts it from within 15 m only.
const ROPE_TOP := 6.0
const ROPE_BOTTOM := 3.0
const PISTOL_REACH := 15.0
## Kept clear of the pistol's reach by this much (aim, a lean, a jump).
const ROPE_MARGIN := 1.0
const EYE := 1.6
const GAP := 0.5
const EPS := 0.001
## A body standing at a slot or floor loot needs this much free floor.
const CLEARANCE := 0.5
const BODY_HEIGHT := 1.8

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _east_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in layout.rooms:
		if EAST.has(room.zone):
			found.append(room)
	return found


func _is_east(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and EAST.has(room.zone)


func _origin(marker: StringName) -> Vector3:
	return (layout.markers[marker] as Transform3D).origin


# --- rooms ---------------------------------------------------------------------

func test_east_rooms_lie_in_their_zones_with_names() -> void:
	var keys := _translation_keys()
	var rooms := _east_rooms()
	assert_gt(rooms.size(), 22, "both wings have their rooms")
	for room in rooms:
		assert_true(String(room.id).begins_with(String(room.zone) + "_"), "%s named after its zone" % room.id)
		assert_true(keys.has(String(room.name_key)), "%s: name %s translated" % [room.id, room.name_key])
		for part in room.parts:
			assert_true(Floor1Plan.contains(room.zone, part, room.floor_y, room.ceiling_y + ShellCarver.ROOF_T), "%s part %s in zone %s" % [room.id, part, room.zone])
			for value in [part.position.x, part.position.y, part.end.x, part.end.y]:
				assert_true(ShellCarver.on_grid(value), "%s on the grid" % room.id)
		if room.secret or room.haven:
			assert_false(room.public, "%s is not on the visitors' map" % room.id)
	for staff: StringName in [&"enlightenment_roof_stairs", &"enlightenment_attic", &"enlightenment_service_stairs", &"enlightenment_stacks", &"asia_service_stairs"]:
		assert_false(layout.room(staff).public, "%s is staff only" % staff)
	for visitors: StringName in [&"enlightenment_library", &"enlightenment_library_gallery", &"enlightenment_cabinet", &"enlightenment_clocks", &"enlightenment_portraits", &"enlightenment_planetarium", &"asia_china", &"asia_porcelain", &"asia_korea", &"asia_armor", &"asia_garden"]:
		assert_true(layout.room(visitors).public, "%s is printed on the map" % visitors)
	# behind the internal gates: the Planetarium, the Japanese garden
	assert_eq(layout.room(&"enlightenment_planetarium").progress_area(), &"planetarium")
	for garden: StringName in [&"asia_garden", &"asia_teahouse", &"asia_garden_shrine"]:
		assert_eq(layout.room(garden).progress_area(), &"asia_garden", "%s lies beyond the cracked wall" % garden)
	assert_eq(layout.room(&"enlightenment_observatory").progress_area(), &"enlightenment", "the observers' gallery is outside the arena")
	# the ambience picks its sub-zones from words in the room ids
	assert_true(String(&"enlightenment_clocks").contains("clock") and layout.room(&"enlightenment_clocks") != null)
	assert_true(layout.room(&"asia_garden") != null)


func test_rooms_keep_apart_and_nested_rooms_stand_in_their_hosts() -> void:
	var carved: Array[RoomSpec] = []
	for room in layout.rooms:
		if room.carved:
			carved.append(room)
	for room in _east_rooms():
		if not room.carved:
			assert_true(NESTED.has(room.id), "%s stands inside a known host" % room.id)
			var host := layout.room(NESTED.get(room.id, &""))
			if host == null:
				continue
			assert_true(room.floor_y > host.floor_y and room.ceiling_y <= host.ceiling_y + EPS, "%s fits in %s's height" % [room.id, host.id])
			for part in room.parts:
				for corner in [part.position, part.end, Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.position.y)]:
					assert_true(host.covers(corner), "%s lies inside %s" % [room.id, host.id])
			continue
		for other in carved:
			if other == room:
				continue
			if room.floor_y >= other.ceiling_y + GAP - EPS or other.floor_y >= room.ceiling_y + GAP - EPS:
				continue   # stacked with a slab between them
			for a in room.parts:
				for b in other.parts:
					var gap_x := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
					var gap_z := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
					assert_true(maxf(gap_x, gap_z) >= GAP - EPS, "%s and %s keep a wall between them" % [room.id, other.id])
	# on the gallery's slab the gallery wins room_at, under it the library
	assert_eq(layout.room_at(Vector3(32.5, 5.0, 10.0)), &"enlightenment_library_gallery")
	assert_eq(layout.room_at(Vector3(32.5, 1.0, 10.0)), &"enlightenment_library")
	assert_eq(layout.room_at(Vector3(49.0, 11.0, -16.5)), &"enlightenment_observatory")
	assert_eq(layout.room_at(Vector3(49.0, 1.0, -16.5)), &"enlightenment_planetarium")


func test_key_rooms_have_their_sizes() -> void:
	var library := layout.room(&"enlightenment_library")
	assert_eq(library.bounds(), Rect2(31, -36, 14, 70), "the King's Library is 14 x 70 along the court")
	assert_almost_eq(library.height(), 10.0, EPS, "and 10 m high")
	assert_gt(library.skylights.size(), 2, "moonlight falls into the library")
	var gallery := layout.room(&"enlightenment_library_gallery")
	assert_almost_eq(gallery.floor_y, 4.0, EPS, "the upper gallery of bookcases at y 4")
	assert_false(gallery.carved)
	var rotunda := layout.room(&"enlightenment_planetarium")
	assert_true(rotunda.bounds().size.x >= 19.0 and rotunda.bounds().size.y >= 22.0, "the rotunda holds a 10 m orrery with room round it")
	assert_true(rotunda.height() >= 20.0, "a tall dome over the orrery")
	assert_gt(rotunda.skylights.size(), 0, "the oculus")
	var tower := layout.room(&"enlightenment_roof_stairs")
	assert_almost_eq(tower.floor_y, 4.0, EPS, "the roof stairs start on the upper gallery")
	assert_true(tower.ceiling_y >= Floor1Plan.ROOF_Y + 2.5, "and climb to the roof")
	assert_almost_eq(layout.room(&"enlightenment_attic").floor_y, Floor1Plan.ROOF_Y, EPS, "the library loft at roof height")
	assert_almost_eq(layout.room(&"enlightenment_observatory").floor_y, 4.0 + (Floor1Plan.ROOF_Y - 4.0) / 3.0, EPS, "the observers' gallery on the tower's second landing")
	for stairs: StringName in [&"enlightenment_service_stairs", &"asia_service_stairs"]:
		assert_almost_eq(layout.room(stairs).floor_y, Floor1Plan.BASEMENT_Y, EPS, "%s go down to the basement" % stairs)
	assert_true(layout.room(&"enlightenment_librarian").haven)
	assert_true(layout.room(&"asia_teahouse").haven)
	assert_true(layout.room(&"asia_china").height() >= 10.0, "the big Buddha's hall is high")
	var garden := layout.room(&"asia_garden")
	assert_gt(garden.area(), 400.0, "the General's garden is a real arena")
	var sky := 0.0
	for well in garden.skylights:
		sky += well.get_area()
	assert_gt(sky / garden.area(), 0.3, "the garden lies under an open roof")


func test_junction_rooms_cover_their_doorways() -> void:
	for zone in EAST:
		for j in Floor1Plan.junctions_of(zone):
			var room_id := Floor1Layout.junction_room(layout, j, zone)
			assert_ne(room_id, &"", "%s has a %s room" % [j.id, zone])
			if room_id == &"":
				continue
			var room := layout.room(room_id)
			assert_true(room.floor_y <= j.floor_y + EPS and room.ceiling_y >= j.top_y - EPS, "%s spans %s's height" % [room_id, j.id])
			var face := j.point_in(zone, 0.25, 0.5)
			var across := Vector3(0, 0, 1) if j.runs_along_x() else Vector3(1, 0, 0)
			var half := j.width() * 0.5 - 0.1
			for t in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var point: Vector3 = face + across * half * t
				assert_eq(layout.room_at(point), room_id, "%s: %s covers the doorway at %s" % [j.id, room_id, point])
	assert_eq(Floor1Layout.junction_room(layout, Floor1Plan.junction(&"j_asia_enlightenment"), &"enlightenment"), &"enlightenment_planetarium", "Asia's bolted door opens into the Planetarium")
	assert_eq(Floor1Layout.junction_room(layout, Floor1Plan.junction(&"j_court_enlightenment"), &"enlightenment"), &"enlightenment_library")
	assert_eq(Floor1Layout.junction_room(layout, Floor1Plan.junction(&"j_north_asia"), &"asia"), &"asia_china")


func test_internal_doorways_join_their_rooms() -> void:
	for passage in layout.openings:
		if not (_is_east(passage.room_a) and _is_east(passage.room_b)):
			continue
		var axis := Vector3(1, 0, 0) if passage.runs_along_x() else Vector3(0, 0, 1)
		var middle := passage.center() + Vector3.UP
		var sides := [layout.room_at(middle - axis * (passage.depth() * 0.5 + 0.25)), layout.room_at(middle + axis * (passage.depth() * 0.5 + 0.25))]
		assert_true(sides.has(passage.room_a) and sides.has(passage.room_b), "%s joins %s and %s, found %s" % [passage.id, passage.room_a, passage.room_b, sides])
		var low := minf(layout.room(passage.room_a).ceiling_y, layout.room(passage.room_b).ceiling_y)
		assert_true(passage.top_y <= low + EPS, "%s fits under both ceilings" % passage.id)
		for piece in layout.pieces:
			if not piece.collide or piece.kit == &"balcony" or piece.position.y >= passage.top_y or piece.position.y + piece.size.y <= passage.floor_y + 0.1:
				continue
			var footprint := piece.footprint()
			if footprint.size.x > 0.2 and footprint.size.y > 0.2:
				footprint = footprint.grow(-0.05)
			if footprint.intersects(passage.rect.grow(0.4)):
				fail("%s at %s stands in the way of %s" % [piece.kit, piece.position, passage.id])


func test_internal_gates() -> void:
	var rope := layout.gate(&"rope_planetarium")
	assert_not_null(rope, "the Planetarium's rope")
	if rope != null:
		assert_eq(rope.kind, GateSpec.Kind.ROPE)
		assert_eq(rope.requirement, &"rifle_hunt", "only the rifle cuts it")
		assert_eq(rope.opening, Floor1Plan.INTERNAL_GATE_TARGETS[&"rope_planetarium"])
		var door := layout.opening(rope.opening)
		assert_eq(layout.room(door.room_a).progress_area(), &"enlightenment")
		assert_eq(layout.room(door.room_b).progress_area(), &"planetarium")
		assert_eq(door.link, RoomGraph.Kind.GATE)
		assert_ne(rope.marker, &"", "the rope hangs on a marker of its own")
		assert_eq(layout.marker_rooms.get(rope.marker, &""), &"enlightenment_planetarium", "inside the rotunda")
	var wall := layout.gate(&"cracked_garden")
	assert_not_null(wall, "the garden's cracked wall")
	if wall != null:
		assert_eq(wall.kind, GateSpec.Kind.CRACKED)
		assert_eq(wall.requirement, GateSpec.EXPLOSIVE)
		assert_eq(wall.opening, Floor1Plan.INTERNAL_GATE_TARGETS[&"cracked_garden"])
		var crack := layout.opening(wall.opening)
		assert_eq(layout.room(crack.room_a).progress_area(), &"asia")
		assert_eq(layout.room(crack.room_b).progress_area(), &"asia_garden")
		assert_eq(crack.link, RoomGraph.Kind.GATE)
	for plan in Floor1Plan.internal_gates(&"enlightenment") + Floor1Plan.internal_gates(&"asia"):
		assert_eq(layout.gates.filter(func(g: GateSpec) -> bool: return g.id == plan.id).size(), 1, "%s added once" % plan.id)


## The rope's whole length is farther than the pistol's reach (plus a
## margin) from the eyes of a guard standing on any floor, slab or flight
## outside the Planetarium (walls ignored: the strict W7 measure), and the
## observers' gallery sees it across open air.
func test_the_rope_hangs_out_of_pistol_reach_and_in_rifle_sight() -> void:
	var gate := layout.gate(&"rope_planetarium")
	if gate == null or not layout.markers.has(gate.marker):
		fail("no rope marker")
		return
	var weight := _origin(gate.marker)
	var low := weight + Vector3.UP * ROPE_BOTTOM
	var high := weight + Vector3.UP * ROPE_TOP
	var nearest := INF
	var where := Vector3.ZERO
	for point in _standing_points(Rect2(weight.x - 40.0, weight.z - 40.0, 80.0, 80.0)):
		var eye := point + Vector3.UP * EYE
		var d := eye.distance_to(Geometry3D.get_closest_point_to_segment(eye, low, high))
		if d < nearest:
			nearest = d
			where = point
	assert_gt(nearest, PISTOL_REACH + ROPE_MARGIN, "the pistol never reaches the rope (nearest stand %s, %.1f m)" % [where, nearest])
	print("Planetarium rope: the nearest stand outside the rotunda is %s, %.1f m from the rope" % [where, nearest])
	# the rifle: a clean line from the observers' gallery to the rope
	var gallery := layout.room(&"enlightenment_observatory")
	var bounds := gallery.bounds()
	var from := Vector3(bounds.end.x - 1.0, gallery.floor_y + EYE, bounds.get_center().y)
	var target := (low + high) * 0.5
	assert_eq(_first_obstacle(from, target, 0.0), "", "the observers' gallery sees the rope")
	assert_gt(from.distance_to(target), PISTOL_REACH + ROPE_MARGIN, "and it is a rifle shot from there")
	# the rope reads: a lamp on it
	var lit := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"enlightenment_planetarium" and l.kind == LightSpec.Kind.SPOT and l.direction.angle_to(target - l.position) < deg_to_rad(10.0))
	assert_gt(lit.size(), 0, "a spot on the counterweight")


func test_secret_rooms_sit_behind_zone_gates() -> void:
	var secrets := {}
	var kinds := {}
	for room in _east_rooms():
		if not room.secret:
			continue
		secrets[room.zone] = int(secrets.get(room.zone, 0)) + 1
		assert_false(room.public, "%s is not printed on the map" % room.id)
		var ways := layout.openings.filter(func(o: OpeningSpec) -> bool: return o.room_a == room.id or o.room_b == room.id)
		assert_eq(ways.size(), 1, "%s has one way in" % room.id)
		for passage: OpeningSpec in ways:
			var gate := layout.gate_of_opening(passage.id)
			assert_not_null(gate, "%s: %s is gated" % [room.id, passage.id])
			if gate == null:
				continue
			kinds[gate.kind] = true
			assert_true(String(gate.id).begins_with(String(room.zone) + "_"), "%s is a zone gate" % gate.id)
			assert_true(SECRET_NEEDS.has(gate.requirement), "%s needs %s" % [gate.id, gate.requirement])
			assert_eq(passage.link, RoomGraph.Kind.GATE, "%s is shut in the room graph" % passage.id)
			assert_ne(gate.label_key, &"", "%s has a label" % gate.id)
			var hidden := passage.room_b if passage.room_a != room.id else passage.room_a
			assert_eq(hidden, room.id, "%s: the lock faces the public side" % passage.id)
	assert_eq(secrets, {&"enlightenment": 3, &"asia": 3}, "three secret rooms per wing")
	assert_true(kinds.size() >= 4, "the secrets ask for different tools (%s)" % [kinds.keys()])


func test_three_secrets_three_or_four_notes_and_a_chess_piece_per_wing() -> void:
	for zone in EAST:
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
	var chess := {}
	for marker: StringName in layout.markers:
		if String(marker).begins_with("chess_") and _is_east(layout.marker_rooms[marker]):
			chess[marker] = layout.room(layout.marker_rooms[marker]).zone
	assert_eq(chess, {&"chess_6": &"enlightenment", &"chess_7": &"asia"})


func test_markers_lie_in_their_rooms() -> void:
	var wanted: Array[StringName] = [
		&"weapon_rifle_hunt", &"weapon_hwacha", &"guardian_planetarium", &"guardian_general",
		&"arena_planetarium_start", &"arena_planetarium_door_1", &"arena_planetarium_door_2",
		&"arena_general_start", &"arena_general_door_1", &"arena_general_door_2", &"arena_general_door_3",
		&"museum_map_librarian", &"museum_map_teahouse", &"planetarium_counterweight",
		&"cctv_enlightenment_1", &"cctv_enlightenment_2", &"cctv_asia_1", &"cctv_asia_2",
	]
	for i in 3:
		wanted.append(StringName("arena_planetarium_supply_%d" % (i + 1)))
		wanted.append(StringName("arena_general_supply_%d" % (i + 1)))
	for i in 6:
		wanted.append(StringName("portrait_enlightenment_%d" % (i + 1)))
	for marker in wanted:
		assert_true(layout.markers.has(marker), str(marker))
	for marker: StringName in layout.markers:
		var room_id: StringName = layout.marker_rooms.get(marker, &"")
		if not _is_east(room_id):
			continue
		var room := layout.room(room_id)
		var origin := _origin(marker)
		assert_true(room.covers(Vector2(origin.x, origin.z)), "%s lies over %s" % [marker, room_id])
		assert_true(origin.y >= room.floor_y - EPS and origin.y <= room.ceiling_y, "%s lies between %s's floor and ceiling" % [marker, room_id])
	assert_eq(layout.marker_rooms[&"weapon_rifle_hunt"], &"enlightenment_cabinet")
	assert_eq(layout.marker_rooms[&"weapon_hwacha"], &"asia_korea")
	for arena: StringName in [&"planetarium", &"general"]:
		var post := _origin(StringName("guardian_%s" % arena))
		var start := _origin(StringName("arena_%s_start" % arena))
		assert_eq(layout.marker_rooms[StringName("arena_%s_start" % arena)], layout.marker_rooms[StringName("guardian_%s" % arena)], "%s: the start line is in the arena" % arena)
		assert_gt(post.distance_to(start), 5.0, "%s: the guard walks in before it wakes" % arena)
		# each door marker sits by a doorway of the arena (a grille or a door)
		for marker: StringName in layout.markers:
			if not String(marker).begins_with("arena_%s_door_" % arena):
				continue
			var at := _origin(marker)
			var near := layout.openings.filter(func(o: OpeningSpec) -> bool: return o.center().distance_to(at) < 3.0)
			assert_gt(near.size(), 0, "%s stands by a doorway" % marker)
			# a grille drops on the marker: -Z into the arena, X across the doorway
			var inward := -(layout.markers[marker] as Transform3D).basis.z
			assert_eq(layout.room_at(at + inward + Vector3.UP), layout.marker_rooms[StringName("guardian_%s" % arena)], "%s faces into the arena" % marker)
			if near.size() > 0:
				var doorway: OpeningSpec = near[0]
				var across := Vector3(0, 0, 1) if doorway.runs_along_x() else Vector3(1, 0, 0)
				assert_lt(absf(inward.dot(across)), 0.01, "%s stands across its doorway" % marker)
	# the orrery keeps a clear ring of floor round it
	var orrery := _origin(&"guardian_planetarium")
	for piece in layout.pieces:
		if piece.room == &"enlightenment_planetarium" and piece.collide and piece.position.y < 3.0:
			var flat := Vector2(piece.position.x - orrery.x, piece.position.z - orrery.z).length()
			assert_gt(flat, 9.0, "%s at %s leaves the orrery's ring clear" % [piece.kit, piece.position])


# --- encounters ------------------------------------------------------------------

func test_every_room_with_exhibits_has_two_sets_and_a_sane_density() -> void:
	for room in _east_rooms():
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
		var low := maxi(1, floori(room.area() * 0.006))
		var high := maxi(2, ceili(room.area() * 0.012))
		var counts: Array[int] = []
		if sets.is_empty():
			counts.append(always)
		for id: int in sets:
			counts.append(int(sets[id]) + always)
		for count in counts:
			assert_true(count >= low and count <= high, "%s (%.0f m2): %d exhibits, want %d-%d" % [room.id, room.area(), count, low, high])
	for quiet: StringName in [&"enlightenment_planetarium", &"enlightenment_observatory", &"enlightenment_roof_stairs", &"enlightenment_attic", &"enlightenment_service_stairs", &"asia_garden", &"asia_service_stairs"]:
		assert_eq(layout.spawn_slots.filter(func(s: SpawnSlot) -> bool: return s.room == quiet).size(), 0, "no exhibits in %s" % quiet)
	# the wings' own exhibits (stand-in first, the intended kind after it)
	var intended := {}
	for slot in layout.spawn_slots:
		if _is_east(slot.room) and slot.kinds.size() > 1:
			intended[slot.kinds[1]] = true
	for kind: StringName in [&"books", &"fu_dog", &"samurai_armor"]:
		assert_true(intended.has(kind), "%s appear" % kind)


func test_slots_and_loot_stand_on_free_floor() -> void:
	for slot in layout.spawn_slots:
		if not _is_east(slot.room):
			continue
		assert_eq(layout.room_at(slot.position + Vector3.UP), slot.room, "slot %s in %s" % [slot.position, slot.room])
		_assert_free_floor(slot.position, slot.room, "slot")
	var loot := 0
	for spot in layout.loot_spots:
		if not _is_east(spot.room):
			continue
		loot += 1
		assert_eq(layout.room_at(spot.position + Vector3.UP * 0.5), spot.room, "loot %s in %s" % [spot.position, spot.room])
		if not spot.container:
			_assert_free_floor(spot.position, spot.room, "loot")
	assert_gt(loot, 25, "loot round both wings")


func test_patrols_and_ambushes() -> void:
	var patrols := 0
	for patrol in layout.patrols:
		if not _is_east(patrol.room):
			continue
		patrols += 1
		assert_true(patrol.points.size() >= 2, str(patrol.id))
		for point in patrol.points:
			assert_eq(layout.room_at(point + Vector3.UP), patrol.room, "%s point %s in its room" % [patrol.id, point])
			_assert_free_floor(point, patrol.room, "patrol %s" % patrol.id)
		var walkers := layout.spawn_slots.filter(func(slot: SpawnSlot) -> bool: return slot.patrol == patrol.id)
		assert_gt(walkers.size(), 0, "%s has its walker" % patrol.id)
		for walker: SpawnSlot in walkers:
			assert_false(walker.dormant, "%s's walker is awake" % patrol.id)
	assert_gt(patrols, 3, "patrols in both wings")
	for pair: Array in [[&"enlightenment_rifle", &"weapon_rifle_hunt", 2], [&"asia_hwacha", &"weapon_hwacha", 3]]:
		var ambush := layout.ambush(pair[0])
		assert_not_null(ambush, str(pair[0]))
		if ambush == null:
			continue
		assert_eq(ambush.trigger, AmbushSpec.Trigger.PICKUP)
		assert_eq(ambush.marker, pair[1], "taking %s wakes them" % pair[1])
		assert_true(ambush.slots.size() >= pair[2], "%s: enough sleepers" % pair[0])
		for index in ambush.slots:
			assert_eq(layout.spawn_slots[index].set_id, SpawnSlot.ALWAYS_SET, "%s is there every night" % pair[0])
	var ambushes := 0
	for ambush in layout.ambushes:
		if not _is_east(ambush.room):
			continue
		ambushes += 1
		assert_gt(ambush.slots.size(), 0, str(ambush.id))
		for index in ambush.slots:
			var slot := layout.spawn_slots[index]
			assert_eq(slot.room, ambush.room, "%s wakes exhibits of its own room" % ambush.id)
			assert_true(slot.dormant, "%s: its sleepers sleep" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.AREA:
			assert_true(layout.room(ambush.room).covers(ambush.area.get_center()), "%s's area lies in %s" % [ambush.id, ambush.room])
	assert_gt(ambushes, 9, "ambushes in both wings")


func test_stairs_never_steeper_than_the_plan() -> void:
	var flights := 0
	for flight in layout.stairs:
		if not _is_east(flight.room_low):
			continue
		flights += 1
		assert_true((flight.top_y - flight.bottom_y) / flight.run() <= Floor1Plan.STAIR_SLOPE + EPS, "%s is no steeper than 20.6 degrees" % flight.id)
	assert_true(flights >= 12, "the gallery's two flights, the roof tower's six, two service stairs (found %d)" % flights)
	# both gallery flights climb from the library floor to the gallery
	var gallery := 0
	for flight in layout.stairs:
		if flight.room_low == &"enlightenment_library" and flight.room_high == &"enlightenment_library_gallery":
			gallery += 1
			assert_almost_eq(flight.top_y, 4.0, EPS)
	assert_eq(gallery, 2, "a flight at each end of the library: the loop")


# --- routes --------------------------------------------------------------------

## The rifle lies on night 1's path: no gate between the court door and the
## cabinet, and the table is in plain view from the doorway (every point of
## the line lies in a room or a doorway and passes no solid piece).
func test_the_rifle_lies_on_the_main_path_in_plain_view() -> void:
	var j := Floor1Plan.junction(&"j_court_enlightenment")
	var reached := layout.graph().reachable(Floor1Layout.junction_room(layout, j, &"enlightenment"))
	assert_true(reached.has(layout.marker_rooms[&"weapon_rifle_hunt"]), "the rifle needs no gate")
	assert_true(reached.has(&"enlightenment_observatory"), "the observers' gallery needs no gate")
	var target := _origin(&"weapon_rifle_hunt") + Vector3.UP * 0.15
	for from: Vector3 in [j.point_in(&"enlightenment", 0.5, EYE), j.point_in(&"enlightenment", 4.0, EYE)]:
		assert_eq(_first_obstacle(from, target, 0.6), "", "the rifle is seen from %s" % from)
	# the check sees walls: the haven is out of sight from the court door
	var haven: Vector3 = (layout.haven_spots[&"librarian"] as Transform3D).origin + Vector3.UP
	assert_ne(_first_obstacle(j.point_in(&"enlightenment", 0.5, EYE), haven, 0.0), "", "walls block the view")
	assert_true(_origin(&"weapon_rifle_hunt").distance_to(Vector3(j.center().x, 0, j.center().z)) > 25.0, "a long look across the library")


func test_gates_hold_the_planetarium_and_the_garden() -> void:
	var graph := layout.graph()
	var library := graph.reachable(&"enlightenment_library")
	assert_false(library.has(&"enlightenment_planetarium"), "the rope keeps the Planetarium shut")
	var opened: Array[StringName] = [&"enlightenment_planetarium_door"]
	assert_true(graph.reachable(&"enlightenment_library", [], opened).has(&"enlightenment_planetarium"), "the cut rope lets the guard in")
	var china := graph.reachable(&"asia_china")
	assert_true(china.has(&"asia_korea"), "the fire chest needs no gate inside Asia")
	for beyond: StringName in [&"asia_garden", &"asia_teahouse", &"asia_garden_shrine"]:
		assert_false(china.has(beyond), "%s waits behind the cracked wall" % beyond)
	assert_true(graph.reachable(&"asia_china", [], [&"asia_garden_wall"] as Array[StringName]).has(&"asia_garden"), "the blast opens the garden")


func test_havens_are_dead_ends_and_nothing_lies_behind_them() -> void:
	for haven: StringName in [&"enlightenment_librarian", &"asia_teahouse"]:
		var ways := layout.openings.filter(func(o: OpeningSpec) -> bool: return (o.room_a == haven or o.room_b == haven) and layout.gate_of_opening(o.id) == null)
		assert_eq(ways.size(), 1, "%s has one door" % haven)
	var opened: Array[StringName] = []
	for gate in layout.gates:
		if gate.opening != &"":
			opened.append(gate.opening)
	var graph := layout.graph()
	var through_havens: Array[StringName] = []
	for room in layout.rooms:
		if room.haven:
			through_havens.append_array(graph.doors_of_room(room.id))
	var reached := graph.reachable(&"enlightenment_library", through_havens, opened)
	for room in _east_rooms():
		if not room.haven:
			assert_true(reached.has(room.id), "%s reachable without walking through a haven" % room.id)


func test_lights_follow_the_wing_recipes() -> void:
	var lit := {}
	var shadows := 0
	for light in layout.lights:
		if light.group == LightSpec.MAIN or light.group == LightSpec.MOON:
			lit[light.room] = true
		if _is_east(light.room) and light.shadow:
			shadows += 1
	for room in _east_rooms():
		if room.public or room.secret:
			assert_true(lit.has(room.id), "%s has lamps" % room.id)
	assert_lt(shadows, 14, "shadows only where they show")
	# Enlightenment: warm lamps in the library, moonlight through its roof
	for light in layout.lights:
		if light.room == &"enlightenment_library" and light.group == LightSpec.MAIN:
			assert_true(light.color.r > light.color.b, "the library's lamps are warm (%s)" % light.color)
	var library_moon := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"enlightenment_library" and l.group == LightSpec.MOON)
	assert_true(library_moon.size() >= 3, "moon shafts cross the library")
	var long_shadows := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"enlightenment_library" and l.shadow)
	assert_gt(long_shadows.size(), 0, "the bookcases throw long shadows")
	# the rifle and the Buddha in warm spotlights
	var rifle := _origin(&"weapon_rifle_hunt")
	assert_gt(layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"enlightenment_cabinet" and l.shadow and l.position.distance_to(rifle) < 5.0 and l.color.r > l.color.b).size(), 0, "the rifle is lit warm")
	var buddha := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"asia_china" and l.kind == LightSpec.Kind.SPOT and l.shadow)
	assert_gt(buddha.size(), 0, "a golden spot on the Buddha")
	# Asia: the moon only over the garden, lanterns elsewhere
	var garden_moon := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"asia_garden" and l.group == LightSpec.MOON)
	assert_true(garden_moon.size() >= 2, "the garden lies under the moon")
	for haven: StringName in [&"enlightenment_librarian", &"asia_teahouse"]:
		assert_gt(layout.lights.filter(func(l: LightSpec) -> bool: return l.room == haven and l.group == LightSpec.HAVEN).size(), 0, "%s keeps its lamps in a blackout" % haven)


# --- helpers ---------------------------------------------------------------------

## Points a guard can stand on near [param area] outside the Planetarium:
## room floors, slabs and landings, and flights (sampled every 0.5 m).
func _standing_points(area: Rect2) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for room in layout.rooms:
		if not room.carved or room.progress_area() == &"planetarium" or not room.bounds().intersects(area):
			continue
		for part in room.parts:
			_sample(points, part, room.floor_y)
	for piece in layout.pieces:
		var room := layout.room(piece.room)
		if room == null or room.progress_area() == &"planetarium" or not (piece.kit == &"balcony" or piece.kit == &"landing"):
			continue
		if piece.footprint().intersects(area):
			_sample(points, piece.footprint(), piece.position.y + piece.size.y)
	for flight in layout.stairs:
		var room := layout.room(flight.room_low)
		if room == null or room.progress_area() == &"planetarium" or not flight.rect.intersects(area):
			continue
		var steps := int(flight.run() / 0.5)
		for i in steps + 1:
			var t := float(i) / steps
			var along := flight.rect.get_center() + flight.ascend * flight.run() * (t - 0.5)
			points.append(Vector3(along.x, lerpf(flight.bottom_y, flight.top_y, t), along.y))
	return points


func _sample(points: Array[Vector3], rect: Rect2, y: float) -> void:
	var x := rect.position.x + 0.25
	while x < rect.end.x:
		var z := rect.position.y + 0.25
		while z < rect.end.y:
			points.append(Vector3(x, y, z))
			z += 0.5
		x += 0.5


## The first thing between [param from] and [param to] ("" = nothing): a
## wall (a point in no room and no doorway) or a solid piece (ignored within
## [param spare] m of the target, e.g. the table under a pickup).
func _first_obstacle(from: Vector3, to: Vector3, spare: float) -> String:
	var steps := int(from.distance_to(to) / 0.1)
	for i in range(1, steps):
		var point := from.lerp(to, float(i) / steps)
		if not _in_space(point):
			return "wall at %s" % point.snapped(Vector3.ONE * 0.01)
		if Vector2(point.x - to.x, point.z - to.z).length() < spare:
			continue
		for piece in layout.pieces:
			if not piece.collide:
				continue
			if point.y < piece.position.y or point.y > piece.position.y + piece.size.y:
				continue
			if _local_inside(piece, point, 0.0):
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


## [param point] (floor plan) inside [param piece]'s rotated footprint grown
## by [param margin].
func _local_inside(piece: PieceSpec, point: Vector3, margin: float) -> bool:
	var local := Basis(Vector3.UP, -piece.yaw) * Vector3(point.x - piece.position.x, 0, point.z - piece.position.z)
	var scale := 1.35 if piece.kit == &"column" else 1.0
	return absf(local.x) <= piece.size.x * scale * 0.5 + margin and absf(local.z) <= piece.size.z * scale * 0.5 + margin


## A body standing at [param point] fits: room round it on every side, no
## solid piece or flight within CLEARANCE.
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


func _translation_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() >= 3:
			keys[line[0]] = true
	return keys
