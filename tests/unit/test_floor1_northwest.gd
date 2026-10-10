extends TestCase
## Floor I north-west wings as data (P1 / W4: zones/assyria.gd,
## zones/americas.gd; plan docs/superpowers/plans/2026-10-03-p1-w4-asyria-
## ameryki.md): key room sizes, rooms apart inside their zone, junction
## rooms on their doorways, secrets behind zone gates, markers in their
## rooms, encounter sets and density, patrols and ambushes, stairs, the
## Lion Hunt gallery round its pit, the temple only beyond the canoe gate,
## the keys of both wings on their main paths, the Khorsabad axis and the
## hanging canoe in plain view, and the wings' light recipes.

const NW := preload("res://src/level/floor1/zones/northwest_kit.gd")
const Hub := preload("res://src/level/floor1/zones/hub_kit.gd")
const WINGS: Array[StringName] = [&"assyria", &"americas"]
## What a secret's gate may ask for (all off the critical path).
const SECRET_NEEDS: Array[StringName] = [GateSpec.HEAVY, GateSpec.EXPLOSIVE, GateSpec.PRECISE, &"harpoon"]
## Exhibit kinds the game has today (each slot names one of them first).
const KNOWN_KINDS: Array[StringName] = [&"wax", &"wolf", &"knight", &"bust", &"raptor"]
const ARENAS: Array[StringName] = [&"assyria_courtyard", &"americas_temple"]
## Eye height of the guard.
const EYE := 1.6
const GAP := 0.5
const EPS := 0.001

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _wing_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in layout.rooms:
		if WINGS.has(room.zone):
			found.append(room)
	return found


func _is_wing(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and WINGS.has(room.zone)


func _origin(marker: StringName) -> Vector3:
	return (layout.markers[marker] as Transform3D).origin


func _pieces(kit: StringName, room_id: StringName = &"") -> Array[PieceSpec]:
	var found: Array[PieceSpec] = []
	for piece in layout.pieces:
		if piece.kit == kit and (room_id == &"" or piece.room == room_id):
			found.append(piece)
	return found


func test_key_rooms_have_their_sizes() -> void:
	var gate := layout.room(&"assyria_gate")
	assert_true(gate.bounds().size.x >= 16.0 and gate.bounds().size.y >= 18.0, "the Khorsabad Gate hall is at least 16 x 18 m")
	assert_true(gate.height() >= Floor1Plan.junction(&"j_egypt_assyria").height(), "and as high as the gate")
	var lamassu := _pieces(&"lamassu", &"assyria_gate")
	assert_eq(lamassu.size(), 2, "a pair of lamassu guards the gate")
	for piece in lamassu:
		assert_almost_eq(piece.size.y, 4.5, EPS, "4.5 m tall")
	var court := layout.room(&"assyria_courtyard")
	assert_true(court.bounds().size.x >= 28.0 and court.bounds().size.y >= 26.0, "the courtyard leaves room to charge")
	assert_gt(court.height(), 12.0)
	var sky := 0.0
	for well in court.skylights:
		sky += well.get_area()
	assert_gt(sky / court.area(), 0.4, "the courtyard is open to the sky")
	var nimrud := layout.room(&"assyria_nimrud")
	assert_gt(nimrud.bounds().size.x, nimrud.bounds().size.y * 2.5, "the Nimrud gallery is long")
	var freight := layout.room(&"assyria_freight_stairs")
	assert_eq(freight.floor_y, Floor1Plan.BASEMENT_Y, "the freight stairs reach the basement")
	assert_true(freight.ceiling_y <= layout.room(&"assyria_library").floor_y - GAP + EPS, "the library stands over them")
	var temple := layout.room(&"americas_temple")
	assert_true(temple.bounds().size.x >= 20.0 and temple.bounds().size.y >= 26.0, "the temple is at least 20 x 26 m")
	assert_almost_eq(temple.height(), 12.0, EPS)
	assert_eq(temple.progress_area(), &"americas_temple")
	var terraces: Array[float] = []
	for piece in _pieces(&"temple_tier", &"americas_temple"):
		terraces.append(piece.position.y + piece.size.y)
	terraces.sort()
	assert_eq(terraces, [1.5, 3.0] as Array[float], "two stepped terraces")
	var pacific := layout.room(&"americas_pacific")
	assert_gt(pacific.height(), 9.0, "the canoe hangs high")
	assert_true(pacific.floor_y - layout.room(&"americas_pit").floor_y >= 5.0, "the floor caved in deep")
	var tower := layout.room(&"americas_service_stairs")
	assert_eq(tower.floor_y, Floor1Plan.BASEMENT_Y, "the Americas' tower starts in the basement")
	assert_gt(tower.ceiling_y, 2.6, "and reaches the ground floor")
	var head := _pieces(&"moai", &"americas_moai")
	assert_eq(head.size(), 1, "one head in the Moai room")
	if head.size() == 1:
		assert_gt(head[0].position.y + head[0].size.y, 6.0, "a head taller than the guard by far")


func test_rooms_keep_apart_inside_their_zone() -> void:
	var carved: Array[RoomSpec] = []
	for room in layout.rooms:
		if room.carved:
			carved.append(room)
	for room in _wing_rooms():
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
	for zone in WINGS:
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
	# the bolt to Greece opens from the Lion Hunt gallery
	var bolt := layout.gate(&"bolt_lions_bassae")
	assert_eq(bolt.one_way_side, &"assyria_lions_gallery", "the Bassae bolt is drawn from the gallery")


func test_internal_doorways_join_their_rooms() -> void:
	for passage in layout.openings:
		if not (_is_wing(passage.room_a) and _is_wing(passage.room_b)):
			continue
		var axis := Vector3(1, 0, 0) if passage.runs_along_x() else Vector3(0, 0, 1)
		var middle := passage.center() + Vector3.UP
		var sides := [layout.room_at(middle - axis * (passage.depth() * 0.5 + 0.25)), layout.room_at(middle + axis * (passage.depth() * 0.5 + 0.25))]
		assert_true(sides.has(passage.room_a) and sides.has(passage.room_b), "%s joins %s and %s, found %s" % [passage.id, passage.room_a, passage.room_b, sides])
		var low := minf(layout.room(passage.room_a).ceiling_y, layout.room(passage.room_b).ceiling_y)
		assert_true(passage.top_y <= low + EPS, "%s fits under both ceilings" % passage.id)


func test_secret_rooms_sit_behind_zone_gates() -> void:
	var secrets := 0
	for room in _wing_rooms():
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
		for flight in layout.stairs:
			assert_false(flight.room_low != flight.room_high and (flight.room_low == room.id or flight.room_high == room.id), "%s has no open flight in" % room.id)
	assert_eq(secrets, 6, "three secret rooms per wing")


func test_markers_lie_in_their_rooms() -> void:
	var wanted: Array[StringName] = [
		&"fuse_assyria", &"weapon_harpoon", &"guardian_lamassu", &"guardian_serpent",
		&"arena_lamassu_start", &"arena_lamassu_door_1", &"arena_lamassu_door_2",
		&"arena_serpent_start", &"arena_serpent_door_1", &"black_obelisk", &"americas_canoe",
		&"cctv_assyria_1", &"cctv_assyria_2", &"cctv_americas_1", &"cctv_americas_2",
	]
	for i in 3:
		wanted.append(StringName("arena_lamassu_supply_%d" % (i + 1)))
		wanted.append(StringName("arena_serpent_supply_%d" % (i + 1)))
	for i in 6:
		wanted.append(StringName("lamassu_relief_%d" % (i + 1)))
	for i in 8:
		wanted.append(StringName("serpent_path_%d" % (i + 1)))
	for marker in wanted:
		assert_true(layout.markers.has(marker), str(marker))
	for marker: StringName in layout.markers:
		var room_id: StringName = layout.marker_rooms.get(marker, &"")
		if not _is_wing(room_id):
			continue
		var room := layout.room(room_id)
		var origin := _origin(marker)
		assert_true(room.covers(Vector2(origin.x, origin.z)), "%s lies over %s" % [marker, room_id])
		assert_true(origin.y >= room.floor_y - EPS and origin.y <= room.ceiling_y, "%s lies between %s's floor and ceiling" % [marker, room_id])
	# an arena door marker stands in a doorway of its arena (the grille there)
	for marker: StringName in layout.markers:
		var marker_name := String(marker)
		if not (marker_name.begins_with("arena_lamassu_door_") or marker_name.begins_with("arena_serpent_door_")):
			continue
		var arena: StringName = layout.marker_rooms[marker]
		var doorways := layout.openings.filter(func(o: OpeningSpec) -> bool: return (o.room_a == arena or o.room_b == arena) and o.center().distance_to(_origin(marker)) < 0.6)
		assert_eq(doorways.size(), 1, "%s stands in a doorway of %s" % [marker, arena])
		var inward := _origin(marker) - (layout.markers[marker] as Transform3D).basis.z * 1.5 + Vector3.UP
		assert_eq(layout.room_at(inward), arena, "%s faces into %s" % [marker, arena])
	assert_eq(layout.marker_rooms[&"fuse_assyria"], &"assyria_nimrud", "the fuse lies in the Nimrud gallery")
	assert_eq(layout.marker_rooms[&"weapon_harpoon"], &"americas_pacific", "the harpoon in the Pacific gallery")


func test_three_secrets_and_three_or_four_notes_per_wing() -> void:
	for zone in WINGS:
		var secrets := 0
		var notes := 0
		for marker: StringName in layout.markers:
			if String(marker).begins_with("secret_%s_" % zone):
				secrets += 1
				assert_true(layout.room(layout.marker_rooms[marker]).secret, "%s lies in a secret room" % marker)
			elif String(marker).begins_with("note_%s_" % zone):
				notes += 1
				assert_eq(layout.room(layout.marker_rooms[marker]).zone, zone, "%s lies in its wing" % marker)
		assert_eq(secrets, 3, "%s: three secrets" % zone)
		assert_true(notes >= 3 and notes <= 4, "%s: three or four notes, found %d" % [zone, notes])


func test_one_chess_piece_per_wing() -> void:
	var found := {}
	for marker: StringName in layout.markers:
		if String(marker).begins_with("chess_") and _is_wing(layout.marker_rooms[marker]):
			found[marker] = layout.room(layout.marker_rooms[marker]).zone
	assert_eq(found, {&"chess_4": &"assyria", &"chess_5": &"americas"})


func test_every_room_with_exhibits_has_two_sets_and_a_sane_density() -> void:
	for room in _wing_rooms():
		var always := 0
		var sets := {}
		for slot in layout.spawn_slots:
			if slot.room != room.id:
				continue
			assert_false(room.haven, "no exhibit in the haven %s" % room.id)
			assert_false(ARENAS.has(room.id), "the arena %s is the guardian's alone" % room.id)
			assert_false(slot.kinds.is_empty(), "%s: a slot without kinds" % room.id)
			if not slot.kinds.is_empty():
				assert_true(KNOWN_KINDS.has(slot.kinds[0]), "%s: %s comes first (stand-in)" % [room.id, slot.kinds[0]])
				assert_eq(slot.kinds.size(), 2, "%s: the stand-in and the wing's own kind" % room.id)
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
	var patrols := 0
	for patrol in layout.patrols:
		if not _is_wing(patrol.room):
			continue
		patrols += 1
		assert_true(walked.has(patrol.id), "somebody walks %s" % patrol.id)
		for point in patrol.points:
			assert_eq(layout.room_at(point + Vector3.UP), patrol.room, "%s point %s" % [patrol.id, point])
	assert_gt(patrols, 6, "patrols in both wings")
	for spec: Array in [[&"assyria_fuse", &"fuse_assyria"], [&"americas_whalers", &"weapon_harpoon"]]:
		var ambush := layout.ambush(spec[0])
		assert_not_null(ambush, str(spec[0]))
		if ambush == null:
			continue
		assert_eq(ambush.trigger, AmbushSpec.Trigger.PICKUP)
		assert_eq(ambush.marker, spec[1], "taking %s wakes them" % spec[1])
		assert_true(ambush.slots.size() >= 2, "two or more sleepers")
		for index in ambush.slots:
			assert_eq(layout.spawn_slots[index].set_id, SpawnSlot.ALWAYS_SET, "%s is there every night" % ambush.id)
	var ambushes := 0
	for ambush in layout.ambushes:
		if not _is_wing(ambush.room):
			continue
		ambushes += 1
		for index in ambush.slots:
			var slot := layout.spawn_slots[index]
			assert_eq(slot.room, ambush.room, "%s wakes exhibits of its own room" % ambush.id)
			assert_true(slot.dormant, "%s: its sleepers sleep" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.AREA:
			var room := layout.room(ambush.room)
			assert_true(room.covers(ambush.area.get_center()), "%s's area lies in %s" % [ambush.id, ambush.room])
	assert_gt(ambushes, 8, "ambushes in both wings")


func test_stairs_never_steeper_than_the_plan() -> void:
	var flights := 0
	for flight in layout.stairs:
		if not _is_wing(flight.room_low):
			continue
		flights += 1
		assert_true((flight.top_y - flight.bottom_y) / flight.run() <= Floor1Plan.STAIR_SLOPE + EPS, "%s is no steeper than 20.6 degrees" % flight.id)
	assert_true(flights >= 10, "freight stairs, the pit's two flights, the tower, the hideout, the temple's four: %d" % flights)


## The Lion Hunt hall: a gallery ring at the ground floor's height all round
## a pit 3 m down, slabs under every part of it, two flights between them,
## and every ground-floor doorway of the hall lands on the gallery.
func test_the_lion_hunt_hall_has_a_gallery_round_its_pit() -> void:
	var ring := layout.room(&"assyria_lions_gallery")
	var hall := layout.room(&"assyria_lions")
	assert_eq(ring.parts.size(), 4, "a ring of four sides")
	var slabs := _pieces(&"balcony", ring.id)
	for part in ring.parts:
		assert_true(hall.covers(part.get_center()), "the gallery lies in the hall")
		assert_almost_eq(minf(part.size.x, part.size.y), 3.0, EPS, "a 3 m walk")
		var under := slabs.filter(func(p: PieceSpec) -> bool: return p.footprint().is_equal_approx(part) and is_equal_approx(p.position.y + p.size.y, ring.floor_y))
		assert_eq(under.size(), 1, "a slab under %s" % part)
	var down := layout.stairs.filter(func(f: StairsSpec) -> bool: return f.room_low == hall.id and f.room_high == ring.id)
	assert_eq(down.size(), 2, "two flights into the pit")
	for passage in layout.openings:
		if passage.room_a == hall.id or passage.room_b == hall.id:
			assert_almost_eq(passage.floor_y, hall.floor_y, EPS, "%s opens on the pit's floor" % passage.id)
		if passage.room_a == ring.id or passage.room_b == ring.id:
			assert_almost_eq(passage.floor_y, ring.floor_y, EPS, "%s opens on the gallery" % passage.id)
	assert_eq(layout.opening(&"j_assyria_greece").room_a, ring.id, "the shortcut to Greece leaves from the gallery")


func test_the_temple_lies_only_beyond_the_canoe() -> void:
	var gate := layout.gate(&"hook_canoe")
	assert_not_null(gate)
	if gate == null:
		return
	assert_eq(gate.kind, GateSpec.Kind.HOOK)
	assert_eq(gate.requirement, &"harpoon")
	assert_eq(gate.opening, &"americas_canoe_bridge")
	var bridge := layout.opening(&"americas_canoe_bridge")
	assert_eq([bridge.room_a, bridge.room_b], [&"americas_pit", &"americas_temple"], "from the collapsed floor into the temple")
	var temple := &"americas_temple"
	for passage in layout.openings:
		if passage.room_a == temple or passage.room_b == temple:
			assert_eq(passage.id, &"americas_canoe_bridge", "%s is no other way into the temple" % passage.id)
	var graph := layout.graph()
	for room in _wing_rooms():
		if room.zone == &"americas" and room.id != temple:
			assert_false(graph.reachable(room.id).has(temple), "%s does not reach the temple while the canoe hangs" % room.id)
	assert_true(graph.reachable(&"americas_pacific", [], [&"americas_canoe_bridge"] as Array[StringName]).has(temple), "the canoe makes the bridge")
	# the gap: a deck at the gallery floor's height from the edge of the
	# collapse to the gate, over a floor 6 m down; the canoe hangs over it
	var gap := layout.room(&"americas_pit")
	var decks := _pieces(&"canoe_bridge", gap.id)
	assert_eq(decks.size(), 1, "the canoe's stand-in deck")
	if decks.size() == 1:
		var deck: PieceSpec = decks[0]
		assert_almost_eq(deck.position.y + deck.size.y, bridge.floor_y, EPS, "the deck lies level with the gate")
		assert_almost_eq(deck.footprint().size.x, gap.bounds().size.x, EPS, "across the whole gap")
		assert_true(deck.footprint().grow(EPS).encloses(_gate_strip(bridge.rect.get_center().y)), "in line with the gate")
	var ledge := layout.opening(&"americas_pacific_pit")
	assert_eq([ledge.room_a, ledge.room_b], [&"americas_pacific", &"americas_pit"])
	assert_almost_eq(ledge.floor_y, 0.0, EPS, "the gallery's floor ends at the edge")
	var canoe := _origin(&"americas_canoe")
	assert_eq(layout.marker_rooms[&"americas_canoe"], gap.id)
	assert_gt(canoe.y, 5.0, "the canoe hangs over the void")


## A strip 1 m wide across the gap's width at the gate's [param z].
func _gate_strip(z: float) -> Rect2:
	var gap := layout.room(&"americas_pit").bounds()
	return Rect2(gap.position.x, z - 0.5, gap.size.x, 1.0)


func test_the_harpoon_fuse_and_lamassu_need_no_inner_gate() -> void:
	var graph := layout.graph()
	# the Americas from either way in: the harpoon, every room but the temple
	# and the secrets
	for id: StringName in [&"j_assyria_americas", &"j_north_americas", &"j_basement_americas"]:
		var start := Floor1Layout.junction_room(layout, Floor1Plan.junction(id), &"americas")
		var reached := graph.reachable(start)
		assert_true(reached.has(layout.marker_rooms[&"weapon_harpoon"]), "the harpoon from %s" % id)
		for room in _wing_rooms():
			if room.zone == &"americas" and not room.secret and room.progress_area() == &"americas":
				assert_true(reached.has(room.id), "%s from %s" % [room.id, id])
	# Assyria from the Khorsabad Gate (and from its basement door): the fuse,
	# the Lamassu, every room but the secrets
	for id: StringName in [&"j_egypt_assyria", &"j_basement_assyria"]:
		var start := Floor1Layout.junction_room(layout, Floor1Plan.junction(id), &"assyria")
		var reached := graph.reachable(start)
		for marker: StringName in [&"fuse_assyria", &"guardian_lamassu"]:
			assert_true(reached.has(layout.marker_rooms[marker]), "%s from %s" % [marker, id])
		for room in _wing_rooms():
			if room.zone == &"assyria" and not room.secret:
				assert_true(reached.has(room.id), "%s from %s" % [room.id, id])


## From 2.5 m inside the Colossus hall, at eye height, through the open
## Khorsabad Gate to the Black Obelisk at the end of the Assyrian axis, and
## down the Pacific gallery from the harpoon to the canoe over the gap:
## every point of each line lies in a room or a doorway and passes no solid
## piece.
func test_the_khorsabad_axis_and_the_canoe_are_in_plain_view() -> void:
	var j := Floor1Plan.junction(&"j_egypt_assyria")
	var from := j.point_in(&"egypt", 2.5, EYE)
	var obelisk := _origin(&"black_obelisk") + Vector3(0, 2.0, 0.65)
	assert_eq(_first_obstacle(from, obelisk), "", "the obelisk closes the axis")
	for piece in _pieces(&"lamassu"):
		var head := piece.position + Vector3(0, 3.6, 2.0)
		assert_eq(_first_obstacle(from, head), "", "a lamassu's head at %s greets the guard" % head)
	# the check itself sees walls: the library is out of sight
	var library := layout.room(&"assyria_library").bounds().get_center()
	assert_ne(_first_obstacle(from, Vector3(library.x, EYE, library.y)), "", "walls block the view")
	var harpoon := _origin(&"weapon_harpoon") + Vector3.UP * 0.6
	assert_eq(_first_obstacle(harpoon, _origin(&"americas_canoe")), "", "the canoe hangs in view of the harpoon")


func test_lights_follow_the_wing_recipes() -> void:
	var lit := {}
	var shadows := 0
	for light in layout.lights:
		if light.group == LightSpec.MAIN:
			lit[light.room] = true
		if _is_wing(light.room) and light.shadow:
			shadows += 1
	for room in _wing_rooms():
		if room.public:
			assert_true(lit.has(room.id), "%s has lamps" % room.id)
	assert_lt(shadows, 14, "shadows only where they show")
	# Assyria: the lamps are torches, hung low, burning red; cold light rakes
	# the reliefs from the floor
	var lamps := 0
	var torches := 0
	var rakes := 0
	for light in layout.lights:
		var room := layout.room(light.room)
		if room == null or room.zone != &"assyria" or light.group != LightSpec.MAIN:
			continue
		var height := light.position.y - room.floor_y
		if light.kind == LightSpec.Kind.SPOT and height <= 1.0:
			rakes += 1
		if not room.public or light.kind != LightSpec.Kind.OMNI:
			continue
		lamps += 1
		if height <= 3.0 and light.color.r > 0.9 and light.color.g < 0.6:
			torches += 1
	assert_gt(lamps, 10)
	assert_true(torches >= lamps * 0.7, "torches: %d of %d lamps" % [torches, lamps])
	assert_true(rakes >= 6, "light from the floor: %d" % rakes)
	# the courtyard: the moon through the wing's biggest opening to the sky
	var court := &"assyria_courtyard"
	var moon := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == court and l.group == Hub.MOON_GROUP)
	assert_gt(moon.size(), 0, "moonlight in the courtyard")
	var widest := &""
	var widest_sky := 0.0
	for room in _wing_rooms():
		var sky := 0.0
		for well in room.skylights:
			sky += well.get_area()
		if sky > widest_sky:
			widest_sky = sky
			widest = room.id
	assert_eq(widest, court, "the courtyard has the widest sky")
	# the Americas: lit from below in every hall
	for room_id: StringName in [&"americas_moai", &"americas_totems", &"americas_temple", &"americas_north", &"americas_pit", &"americas_pacific"]:
		var floor_y := layout.room(room_id).floor_y
		var up := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == room_id and l.kind == LightSpec.Kind.SPOT and l.direction.y > 0.25 and l.position.y - floor_y <= 1.0)
		assert_gt(up.size(), 0, "%s is lit from below" % room_id)
	var head := _pieces(&"moai")[0]
	var face := head.position + Vector3.UP * head.size.y * 0.6
	var on_head := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"americas_moai" and l.kind == LightSpec.Kind.SPOT and l.direction.y > 0.5 and l.direction.angle_to(face - l.position) < deg_to_rad(10.0))
	assert_eq(on_head.size(), 1, "one light from below on the moai's face")
	var canoe := _origin(&"americas_canoe")
	var embers := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"americas_pit" and l.position.y < 0.0)
	assert_true(embers.size() >= 2, "embers glow in the gap")
	assert_true(embers.any(func(l: LightSpec) -> bool: return l.kind == LightSpec.Kind.SPOT and l.direction.angle_to(canoe - l.position) < deg_to_rad(10.0)), "and light the canoe from below")
	var bowls := layout.pieces.filter(func(p: PieceSpec) -> bool: return p.kit == &"brazier" and _is_wing(p.room))
	assert_true(bowls.size() >= 8, "fire bowls: %d" % bowls.size())
	var shaft := layout.lights.filter(func(l: LightSpec) -> bool: return l.room == &"americas_temple" and l.group == Hub.MOON_GROUP)
	assert_eq(shaft.size(), 1, "one shaft of moon on the altar")


## The first thing between [param from] and [param to] ("" = nothing): a
## wall (a point in no room and no doorway) or a solid piece.
func _first_obstacle(from: Vector3, to: Vector3) -> String:
	var steps := int(from.distance_to(to) / 0.1)
	for i in range(1, steps):
		var point := from.lerp(to, float(i) / steps)
		if not _in_space(point):
			return "wall at %s" % point.snapped(Vector3.ONE * 0.01)
		if Vector2(point.x - to.x, point.z - to.z).length() < 0.6:
			continue   # the target's own stand
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
