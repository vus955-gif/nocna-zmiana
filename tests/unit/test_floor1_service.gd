extends TestCase
## The basement and the roof of Floor I as data (workstream W5b; plan
## docs/superpowers/plans/2026-10-03-p1-w5b-podziemia-dach.md): rooms in
## their zones with names, walls between rooms, the key sizes, junction rooms
## flush with their doorways, the doorways inside the zones, the secret rooms
## behind zone gates, every marker the game reads (the fuse, the switchboard,
## the workshop's terminal and map...), nothing only behind the workshop
## haven, spawn sets (low density, free floor, a gentle first descent),
## patrols and ambushes, the stairs and the boiler-room gantry, the
## colour-coded wing doors and the lights (none shines through a slab).

const SERVICE: Array[StringName] = [&"basement", &"roof"]
const KIT := preload("res://src/level/floor1/zones/service_kit.gd")
## Rooms inside another room's space -> the room they stand in.
const NESTED := {&"basement_boiler_catwalk": &"basement_boiler"}
const MAX_SLOPE := Floor1Plan.STAIR_SLOPE + 0.001
## An exhibit or loot needs this much free floor round its point (m).
const CLEARANCE := 0.5
const BODY_HEIGHT := 1.8
const Y := Floor1Plan.BASEMENT_Y
const ROOF := Floor1Plan.ROOF_Y
## Each wing's basement door -> the wing.
const WING_DOORS := {
	&"j_basement_egypt": &"egypt", &"j_basement_assyria": &"assyria", &"j_basement_greece": &"greece",
	&"j_basement_enlightenment": &"enlightenment", &"j_basement_americas": &"americas", &"j_basement_asia": &"asia",
}
const SECRETS := {
	&"basement_cage": &"secret_basement_1", &"basement_old_cellar": &"secret_basement_2",
	&"basement_shelter": &"secret_basement_3", &"roof_loft": &"secret_roof_1", &"roof_shed": &"secret_roof_2",
}
## The rooms right behind the booth's boards: the first descent sleeps.
const FIRST_DESCENT: Array[StringName] = [&"basement_corridor_staff", &"basement_store_guards"]
## Passages, the haven and the gantry stay free of exhibits.
const NO_EXHIBITS: Array[StringName] = [
	&"basement_workshop", &"basement_corridor_workshop", &"basement_corridor_spine_w", &"basement_corridor_spine_e",
	&"basement_boiler_catwalk", &"basement_cage", &"roof_stairs", &"roof_plant", &"roof_loft", &"roof_shed",
]

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _service_rooms() -> Array[RoomSpec]:
	var found: Array[RoomSpec] = []
	for room in layout.rooms:
		if SERVICE.has(room.zone):
			found.append(room)
	return found


func _is_service_room(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and SERVICE.has(room.zone)


# --- rooms -------------------------------------------------------------------

func test_service_rooms_lie_in_their_zones_with_names() -> void:
	var keys := _translation_keys()
	var rooms := _service_rooms()
	assert_gt(rooms.size(), 24, "the basement and the roof have their rooms")
	for room in rooms:
		assert_true(String(room.id).begins_with(String(room.zone)), "%s named after its zone" % room.id)
		assert_true(keys.has(String(room.name_key)), "%s: name %s translated" % [room.id, room.name_key])
		assert_false(room.public, "%s is staff only: not on the visitors' map" % room.id)
		for part in room.parts:
			assert_true(Floor1Plan.contains(room.zone, part, room.floor_y, room.ceiling_y + ShellCarver.ROOF_T), "%s part %s in zone %s" % [room.id, part, room.zone])
			for value in [part.position.x, part.position.y, part.end.x, part.end.y]:
				assert_true(ShellCarver.on_grid(value), "%s on the grid" % room.id)
	for secret: StringName in SECRETS:
		assert_not_null(layout.room(secret), str(secret))
		if layout.room(secret) != null:
			assert_true(layout.room(secret).secret, "%s is secret" % secret)
	var haven := Floor1Plan.haven(&"workshop")
	assert_eq(haven.room, &"basement_workshop")
	assert_true(layout.room(&"basement_workshop").haven, "the workshop is a haven")
	for room in rooms:
		if room.haven:
			assert_eq(room.id, &"basement_workshop", "the workshop is the only haven down here")


func test_rooms_keep_a_wall_between_them() -> void:
	var rooms := _service_rooms()
	for i in rooms.size():
		for k in range(i + 1, rooms.size()):
			var a := rooms[i]
			var b := rooms[k]
			if not a.carved or not b.carved:
				continue
			if a.floor_y >= b.ceiling_y + ShellCarver.ROOF_T or b.floor_y >= a.ceiling_y + ShellCarver.ROOF_T:
				continue   # stacked: a slab between them
			for pa in a.parts:
				for pb in b.parts:
					assert_false(pa.grow(0.49).intersects(pb), "%s and %s need 0.5 m of wall (%s, %s)" % [a.id, b.id, pa, pb])
	for guest: StringName in NESTED:
		var host := layout.room(NESTED[guest])
		var room := layout.room(guest)
		assert_false(room.carved, "%s is a deck inside %s" % [guest, host.id])
		assert_true(room.floor_y > host.floor_y and room.ceiling_y <= host.ceiling_y + 0.01, "%s stands in %s" % [guest, host.id])
		for part in room.parts:
			for corner in [part.position, part.end, Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.position.y)]:
				assert_true(host.covers(corner), "%s lies inside %s" % [guest, host.id])


func test_key_rooms_have_their_sizes() -> void:
	var boiler := layout.room(&"basement_boiler")
	assert_eq(boiler.bounds(), Rect2(-14, -34, 28, 17), "the boiler room is 28 x 17")
	assert_almost_eq(boiler.height(), 5.0, 0.01, "and 5 m high")
	var gantry := layout.room(&"basement_boiler_catwalk")
	assert_true(gantry.ceiling_y - gantry.floor_y >= 2.2 - 0.01, "head room on the gantry (agents are 2 m)")
	assert_true(gantry.floor_y - KIT.SLAB - boiler.floor_y >= 2.4 - 0.01, "a door's height under the gantry")
	var workshop := layout.room(&"basement_workshop")
	assert_lt(workshop.bounds().get_center().length(), 12.5, "the workshop lies under the Reading Room, in the middle")
	assert_gt(workshop.area(), 120.0, "room for the restorers' tables")
	assert_eq(layout.room(&"basement_tunnel").bounds(), Rect2(-55, -37, 24.5, 4), "the tunnel under the Colossus hall")
	for id: StringName in [&"basement_corridor_north", &"basement_corridor_south", &"basement_corridor_west", &"basement_corridor_east"]:
		var corridor := layout.room(id)
		assert_almost_eq(corridor.floor_y, Y, 0.01)
		assert_almost_eq(corridor.height(), 3.5, 0.01, "%s: 3.5 m service corridor" % id)
	# the ring runs under the court's edge all round
	for point in [Vector2(-28, -36), Vector2(28, -36), Vector2(-28, 28), Vector2(28, 28), Vector2(0, -36), Vector2(0, 28), Vector2(-28, 0), Vector2(28, 0)]:
		assert_ne(layout.room_at(Vector3(point.x, Y + 1.0, point.y)), &"", "the ring passes %s" % point)
	var tower := layout.room(&"roof_stairs")
	assert_almost_eq(tower.floor_y, Floor1Plan.LANDING_Y, 0.01, "the tower starts at the entrance hall's landing")
	assert_true(tower.ceiling_y >= ROOF + 2.5, "and climbs to the roof")
	for id: StringName in [&"roof_catwalks", &"roof_plant"]:
		assert_almost_eq(layout.room(id).floor_y, ROOF, 0.01, "%s on the roof" % id)
	assert_eq(layout.room(&"roof_catwalks").bounds(), Rect2(-30, -30, 60, 60), "the catwalks span the court's roof")


func test_every_service_junction_has_a_flush_room() -> void:
	var seen := 0
	for zone in SERVICE:
		for j in Floor1Plan.junctions_of(zone):
			seen += 1
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
				assert_true(room.ceiling_y >= j.top_y - 0.01, "%s: %s reaches the top of the doorway" % [j.id, room_id])
				if found == &"":
					found = room_id
				assert_eq(room_id, found, "%s: one room along the whole doorway" % j.id)
				t += 0.25
	assert_eq(seen, 9, "seven doorways of the basement (six wings, the booth's stairs), two of the roof")


func test_internal_doorways_join_neighbouring_rooms() -> void:
	var inside := 0
	for passage in layout.openings:
		if String(passage.id).begins_with("j_") or not _is_service_room(passage.room_a):
			continue
		inside += 1
		assert_true(_is_service_room(passage.room_b), "%s stays in its zone" % passage.id)
		var axis := Vector3(1, 0, 0) if passage.runs_along_x() else Vector3(0, 0, 1)
		var middle := passage.center() + Vector3.UP * 1.0
		var found: Array[StringName] = []
		for sign in [-1.0, 1.0]:
			found.append(layout.room_at(middle + axis * sign * (passage.depth() * 0.5 + 0.25)))
		found.sort()
		var wanted: Array[StringName] = [passage.room_a, passage.room_b]
		wanted.sort()
		assert_eq(found, wanted, "%s joins %s and %s" % [passage.id, passage.room_a, passage.room_b])
		assert_true(passage.height() >= 2.4 - 0.01, "%s is a walk-through doorway" % passage.id)
		assert_true(passage.width() >= 2.0 - 0.01, "%s is at least 2 m wide" % passage.id)
	assert_gt(inside, 30, "the service zones' own doorways")


func test_secret_rooms_hide_behind_one_zone_gate() -> void:
	var kinds := {}
	for room in _service_rooms():
		if not room.secret:
			continue
		assert_true(SECRETS.has(room.id), "%s is a planned secret" % room.id)
		var ways: Array[OpeningSpec] = []
		for passage in layout.openings:
			if passage.room_a == room.id or passage.room_b == room.id:
				ways.append(passage)
		assert_eq(ways.size(), 1, "%s has one way in" % room.id)
		if ways.size() != 1:
			continue
		assert_eq(ways[0].link, RoomGraph.Kind.GATE, "%s behind a gate" % room.id)
		assert_eq(ways[0].face_room, ways[0].room_a, "%s: the lock shows on the public side" % room.id)
		var gate := layout.gate_of_opening(ways[0].id)
		assert_not_null(gate, "%s's gate" % room.id)
		if gate != null:
			assert_true(String(gate.id).begins_with(String(room.zone) + "_"), "%s: zone gate %s" % [room.id, gate.id])
			assert_null_plan(gate.id)
			assert_true([GateSpec.HEAVY, GateSpec.EXPLOSIVE, GateSpec.PRECISE, &"harpoon"].has(gate.requirement), "%s: a tool the guard finds (%s)" % [gate.id, gate.requirement])
			kinds[gate.kind] = true
		var marker_id: StringName = SECRETS.get(room.id, &"")
		assert_eq(layout.marker_rooms.get(marker_id, &""), room.id, "%s's marker %s lies inside" % [room.id, marker_id])
	assert_eq(kinds.size(), 5, "five different locks: chain, cracked wall, hook, rope, boards")


# --- markers -------------------------------------------------------------------

func test_markers_are_there_and_inside_their_rooms() -> void:
	var wanted: Array[StringName] = [
		&"fuse_basement", &"switchboard", &"museum_map_workshop", &"chess_8",
		&"note_basement_1", &"note_basement_2", &"note_basement_3", &"note_roof_1",
		&"cctv_basement_1", &"cctv_roof_1", &"basement_freight_lift", &"basement_crypt_grille",
		&"steam_basement_1", &"steam_basement_2", &"steam_basement_3", &"roof_view_1", &"roof_view_2",
		&"sign_roof_enlightenment_1", &"sign_roof_entrance_1", &"sign_basement_booth_1",
	]
	for wing: StringName in WING_DOORS.values():
		wanted.append(StringName("sign_basement_%s_1" % wing))
		wanted.append(StringName("sign_basement_%s_2" % wing))
	for id in wanted:
		assert_true(layout.markers.has(id), str(id))
	var counts := {"note_": 4, "secret_": 5, "chess_": 1, "cctv_": 2, "museum_map_": 1, "steam_": 3, "roof_view_": 2, "sign_basement_": 14, "sign_roof_": 2}
	for prefix: String in counts:
		var found := 0
		for id: StringName in layout.markers:
			if String(id).begins_with(prefix) and _is_service_room(layout.marker_rooms.get(id, &"")):
				found += 1
		assert_eq(found, counts[prefix], "%s markers in the basement and on the roof" % prefix)
	for id: StringName in layout.markers:
		if not _is_service_room(layout.marker_rooms.get(id, &"")):
			continue
		var room := layout.room(layout.marker_rooms[id])
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		assert_true(room.covers(Vector2(at.x, at.z)), "%s lies over %s" % [id, room.id])
		assert_true(at.y >= room.floor_y - 0.3 and at.y <= room.ceiling_y, "%s between %s's floor and ceiling" % [id, room.id])
	for id: StringName in [&"cctv_basement_1", &"cctv_roof_1"]:
		var lens: Transform3D = layout.markers[id]
		assert_lt((-lens.basis.z).y, -0.05, "%s looks down into its room" % id)
	assert_eq(layout.marker_rooms[&"museum_map_workshop"], &"basement_workshop")
	assert_eq(layout.marker_rooms[&"chess_8"], &"roof_catwalks", "the roof's chess piece is out on the catwalks")
	# the map hangs on a wall, facing into the room
	var map: Transform3D = layout.markers[&"museum_map_workshop"]
	assert_eq(layout.room_at(map.origin - map.basis.z * 1.0), &"basement_workshop", "the map faces into the workshop")
	assert_eq(layout.room_at(map.origin + map.basis.z * 0.3), &"", "the map's back is against the wall")


func test_the_fuse_and_the_switchboard() -> void:
	var fuse: Transform3D = layout.markers[&"fuse_basement"]
	assert_eq(layout.marker_rooms[&"fuse_basement"], &"basement_boiler_catwalk", "the fuse waits out on the boiler gantry")
	var gantry := layout.room(&"basement_boiler_catwalk")
	assert_true(fuse.origin.y > gantry.floor_y and fuse.origin.y < gantry.floor_y + 1.5, "on the gantry's deck")
	assert_eq(layout.room(layout.marker_rooms[&"fuse_basement"]).progress_area(), &"basement")
	var ambush := layout.ambush(&"basement_fuse")
	assert_not_null(ambush, "taking the fuse wakes the boiler room")
	if ambush != null:
		assert_eq(ambush.trigger, AmbushSpec.Trigger.PICKUP)
		assert_eq(ambush.marker, &"fuse_basement")
		assert_true(ambush.slots.size() >= 2, "two at least")
		for index in ambush.slots:
			assert_eq(layout.spawn_slots[index].set_id, SpawnSlot.ALWAYS_SET, "every night")
	var board: Transform3D = layout.markers[&"switchboard"]
	assert_eq(layout.marker_rooms[&"switchboard"], &"basement_switchboard")
	assert_eq(layout.room_at(board.origin - board.basis.z * 1.5), &"basement_switchboard", "the switchboard faces into its room")
	assert_eq(layout.room_at(board.origin + board.basis.z * 0.5), &"", "and stands against its wall")
	var doors := layout.graph().doors_of_room(&"basement_switchboard")
	assert_true(doors.size() >= 2, "the switchboard room has two ways in")


func test_nothing_lies_only_behind_the_workshop() -> void:
	var graph := layout.graph()
	var opened: Array[StringName] = []
	for gate in layout.gates:
		if gate.opening != &"":
			opened.append(gate.opening)
	var through_haven := graph.doors_of_room(&"basement_workshop")
	assert_eq(through_haven.size(), 2, "the workshop has a door north and a door south")
	var reached := graph.reachable(&"booth_stairs", through_haven, opened)
	for room in _service_rooms():
		if room.zone == &"basement" and not room.haven:
			assert_true(reached.has(room.id), "%s reachable from the staff stairs without the workshop" % room.id)
	# with the gates open the workshop leads to every wing (the shortcut hub)
	var from_haven := graph.reachable(&"basement_workshop", [], opened)
	for j_id: StringName in WING_DOORS:
		var room := Floor1Layout.junction_room(layout, Floor1Plan.junction(j_id), WING_DOORS[j_id])
		assert_true(from_haven.has(room), "the workshop leads to %s" % WING_DOORS[j_id])
	# every gate shut: the basement is a world of its own (each way out of
	# it is a gate: the boards, the bolts) and its secrets stay shut
	var sealed := graph.reachable(&"basement_crossing")
	for room_id: StringName in sealed:
		var room := layout.room(room_id)
		assert_eq(room.zone, &"basement", "%s is not reached through a shut gate" % room_id)
		assert_false(room.secret, "%s stays shut" % room_id)
	# the boards broken: from the booth's staff stairs to the switchboard
	var boards: Array[StringName] = [&"j_booth_basement"]
	var first := graph.reachable(&"booth_stairs", [], boards)
	for id: StringName in [&"basement_workshop", &"basement_boiler", &"basement_boiler_catwalk", &"basement_switchboard", &"basement_tunnel"]:
		assert_true(first.has(id), "%s on the first descent" % id)


# --- encounters ----------------------------------------------------------------

func test_spawn_sets_density_and_free_floor() -> void:
	var by_room := {}
	for slot in layout.spawn_slots:
		if not _is_service_room(slot.room):
			continue
		assert_eq(layout.room_at(slot.position + Vector3.UP), slot.room, "slot %s in %s" % [slot.position, slot.room])
		assert_false(layout.room(slot.room).haven, "no exhibit in a haven")
		assert_false(NO_EXHIBITS.has(slot.room), "no exhibit in %s" % slot.room)
		_assert_free_floor(slot.position, slot.room, "slot")
		if FIRST_DESCENT.has(slot.room):
			assert_true(slot.dormant, "the first rooms after the boards sleep (%s)" % slot.position)
			assert_false(slot.kinds.has(&"wolf") or slot.kinds.has(&"raptor"), "no hunters right behind the boards")
		if not by_room.has(slot.room):
			by_room[slot.room] = {}
		var sets: Dictionary = by_room[slot.room]
		sets[slot.set_id] = int(sets.get(slot.set_id, 0)) + 1
	var nightly := 0
	for room_id: StringName in by_room:
		var room := layout.room(room_id)
		var sets: Dictionary = by_room[room_id]
		var always: int = sets.get(SpawnSlot.ALWAYS_SET, 0)
		var drawn := sets.keys().filter(func(id: int) -> bool: return id != SpawnSlot.ALWAYS_SET)
		if drawn.is_empty():
			assert_true(always >= 1 and always <= 2, "%s: only its ambush" % room_id)
			nightly += always
			continue
		assert_true(drawn.size() >= 2, "%s has at least two sets" % room_id)
		var most := 0
		for set_id: int in drawn:
			var count := int(sets[set_id]) + always
			most = maxi(most, count)
			if room.zone == &"roof":
				assert_true(count >= 1 and count <= 2, "%s set %d: one or two on the roof" % [room_id, set_id])
			elif room.area() < 125.0:
				assert_eq(count, 1, "%s set %d: a small room holds one" % [room_id, set_id])
			else:
				var density := count * 100.0 / room.area()
				assert_true(density >= 0.4 and density <= 0.8, "%s set %d: %.2f exhibits per 100 m2" % [room_id, set_id, density])
		nightly += most
	assert_true(nightly >= 15 and nightly <= 30, "few runaways in the whole basement and roof (%d at most a night)" % nightly)
	for spot in layout.loot_spots:
		if not _is_service_room(spot.room):
			continue
		assert_eq(layout.room_at(spot.position + Vector3.UP), spot.room, "loot %s in %s" % [spot.position, spot.room])
		if spot.position.y <= layout.room(spot.room).floor_y + 0.01:
			_assert_free_floor(spot.position, spot.room, "loot")
	var loot := layout.loot_spots.filter(func(spot: LootSpot) -> bool: return _is_service_room(spot.room))
	assert_gt(loot.size(), 30, "storerooms are worth searching")


func test_patrols_and_ambushes() -> void:
	var patrols := 0
	for patrol in layout.patrols:
		if not _is_service_room(patrol.room):
			continue
		patrols += 1
		assert_true(patrol.points.size() >= 2, str(patrol.id))
		for point in patrol.points:
			assert_eq(layout.room_at(point + Vector3.UP), patrol.room, "%s point %s in its room" % [patrol.id, point])
			_assert_free_floor(point, patrol.room, "patrol %s" % patrol.id)
		var walkers := layout.spawn_slots.filter(func(slot: SpawnSlot) -> bool: return slot.patrol == patrol.id)
		assert_eq(walkers.size(), 1, "%s has its walker" % patrol.id)
		if walkers.size() == 1:
			assert_false((walkers[0] as SpawnSlot).dormant, "%s's walker is awake" % patrol.id)
	assert_true(patrols >= 6, "the corridors are walked (%d patrols)" % patrols)
	var ids: Array[StringName] = []
	for ambush in layout.ambushes:
		if not _is_service_room(ambush.room):
			continue
		ids.append(ambush.id)
		assert_gt(ambush.slots.size(), 0, str(ambush.id))
		for index in ambush.slots:
			assert_eq(layout.spawn_slots[index].room, ambush.room, "%s wakes its own room's exhibits" % ambush.id)
			assert_eq(layout.spawn_slots[index].set_id, SpawnSlot.ALWAYS_SET, "%s is there every night" % ambush.id)
		if ambush.trigger == AmbushSpec.Trigger.AREA:
			var middle := ambush.area.get_center()
			assert_eq(layout.room_at(Vector3(middle.x, (ambush.y_min + ambush.y_max) * 0.5, middle.y)), ambush.room, "%s's trigger lies in its room" % ambush.id)
	for id: StringName in [&"basement_fuse", &"basement_freight", &"basement_switchboard", &"basement_cellar", &"basement_shelter"]:
		assert_true(ids.has(id), "ambush %s" % id)


# --- stairs, gantry, doors, light ------------------------------------------------

func test_stairs_and_the_gantry() -> void:
	var tower := 0
	for flight in layout.stairs:
		if not _is_service_room(flight.room_low):
			continue
		assert_lt((flight.top_y - flight.bottom_y) / flight.run(), MAX_SLOPE, "%s at most 20.6 deg" % flight.id)
		if flight.room_low == &"roof_stairs":
			tower += 1
	assert_eq(tower, 3, "three flights up the roof tower")
	var gantry_stairs: StairsSpec = null
	for flight in layout.stairs:
		if flight.room_high == &"basement_boiler_catwalk":
			gantry_stairs = flight
	assert_not_null(gantry_stairs, "stairs up to the boiler gantry")
	if gantry_stairs == null:
		return
	assert_eq(gantry_stairs.room_low, &"basement_boiler")
	var gantry := layout.room(&"basement_boiler_catwalk")
	assert_almost_eq(gantry_stairs.top_y, gantry.floor_y, 0.01, "the stairs end at the deck")
	var axis := Vector3(gantry_stairs.ascend.x, 0, gantry_stairs.ascend.y)
	var middle := gantry_stairs.rect.get_center()
	var length := gantry_stairs.rect.size.y if absf(gantry_stairs.ascend.y) > 0.5 else gantry_stairs.rect.size.x
	var top := Vector3(middle.x, gantry.floor_y, middle.y) + axis * (length * 0.5 + 0.5)
	assert_true(_on_slab(top), "the stairs arrive on a deck slab (%s)" % top)
	assert_eq(layout.room_at(top + Vector3.UP), &"basement_boiler_catwalk")
	var fuse: Vector3 = (layout.markers[&"fuse_basement"] as Transform3D).origin
	assert_true(_on_slab(Vector3(fuse.x, gantry.floor_y, fuse.z)), "the fuse's spot has a deck under it")


func test_wing_doors_are_colour_coded() -> void:
	var doors := WING_DOORS.duplicate()
	doors[&"j_booth_basement"] = &"booth"
	for j_id: StringName in doors:
		var j := Floor1Plan.junction(j_id)
		var wing: StringName = doors[j_id]
		var color := Floor1Plan.zone_color(wing)
		var door := Vector2(j.center().x, j.center().z)
		var red := false
		var tinted := false
		for spec in layout.lights:
			if not _is_service_room(spec.room) or Vector2(spec.position.x, spec.position.z).distance_to(door) > 4.0:
				continue
			red = red or (spec.group == LightSpec.EMERGENCY and spec.color == KIT.RED)
			tinted = tinted or spec.color.is_equal_approx(color)
		if wing != &"booth":
			assert_true(red, "a red lamp by %s's door" % wing)
			assert_true(tinted, "a lamp in %s's colour by its door" % wing)
		var signed := false
		for piece in layout.pieces:
			if piece.kit == &"sign_wing_portal" and _is_service_room(piece.room) and Vector2(piece.position.x, piece.position.z).distance_to(door) <= 4.0:
				signed = signed or piece.tint.is_equal_approx(color)
		assert_true(signed, "a plate in %s's colour over its door" % wing)
		if wing == &"booth":
			continue
		var piped := layout.pieces.any(func(piece: PieceSpec) -> bool: return piece.kit == &"pipe" and piece.tint.is_equal_approx(color))
		assert_true(piped, "a pipe in %s's colour leads to its door" % wing)


func test_lights() -> void:
	var lit := {}
	var flicker := 0
	for spec in layout.lights:
		if not _is_service_room(spec.room):
			continue
		lit[spec.room] = true
		var room := layout.room(spec.room)
		var aimed_down := spec.kind == LightSpec.Kind.SPOT and spec.direction.normalized().y < -0.95 and spec.spot_angle < 89.0
		var highest := spec.position.y if aimed_down else spec.position.y + spec.light_range
		var lowest := spec.position.y - spec.light_range
		if room.zone == &"basement":
			assert_true([LightSpec.MAIN, LightSpec.EMERGENCY, LightSpec.HAVEN, KIT.FLICKER].has(spec.group), "%s: a basement lamp's group" % spec.room)
			assert_lt(highest, -0.49, "a %s lamp at %s shines up through the slab" % [spec.room, spec.position])
			if spec.group == KIT.FLICKER:
				flicker += 1
				assert_eq(spec.fixture, &"tube_lamp", "only fluorescent tubes flicker")
		elif spec.room != &"roof_stairs":
			assert_true([LightSpec.MOON, LightSpec.EMERGENCY].has(spec.group), "%s: the roof has only the moon (and red warning lamps)" % spec.room)
			assert_true(lowest >= 22.0 - 0.01, "a %s lamp at %s reaches down into the court" % [spec.room, spec.position])
	for room in _service_rooms():
		assert_true(lit.has(room.id), "%s has a lamp" % room.id)
	assert_true(flicker >= 4, "some tubes flicker (%d)" % flicker)
	var haven := layout.lights.filter(func(spec: LightSpec) -> bool: return spec.room == &"basement_workshop" and spec.group == LightSpec.HAVEN)
	assert_true(haven.size() >= 2, "the workshop keeps its own light")
	var moons := layout.lights.filter(func(spec: LightSpec) -> bool: return spec.group == LightSpec.MOON and _is_service_room(spec.room))
	assert_true(moons.size() >= 8, "moonlight over the roof walk")


# --- helpers -------------------------------------------------------------------

func assert_null_plan(gate_id: StringName) -> void:
	assert_eq(Floor1Plan.gate(gate_id), null, "%s is a zone gate, not one of the plan's" % gate_id)


## True when [param point] lies on top of a deck slab.
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
	return absf(local.x) <= piece.size.x * 0.5 + margin and absf(local.z) <= piece.size.z * 0.5 + margin


## A body standing at [param point] fits: no solid piece or flight within
## CLEARANCE, room round it on every side, not under a deck that is too low.
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
