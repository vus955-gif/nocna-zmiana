extends TestCase


func after_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = false


func test_a_loudspeaker_joins_the_group_and_plays_after_its_delay() -> void:
	var speaker := Loudspeaker.create(Transform3D.IDENTITY)
	add_child(speaker)
	assert_true(speaker.is_in_group(&"loudspeakers"))
	var stream := VoiceDirector.catalog.stream(&"VO_SYSTEM_CLOSING_1")
	speaker.play_voice(stream, 0.05)
	assert_false(speaker.is_speaking())
	speaker.advance(0.1)
	assert_true(speaker.is_speaking())
	assert_eq(speaker.player.bus, &"VoiceSystem")
	assert_true(speaker.player.area_mask & Layers.REVERB_ZONE != 0, "hears the reverb zones")
	speaker.stop_voice()
	assert_false(speaker.is_speaking())


func test_the_director_plays_the_system_through_the_nearest_loudspeakers() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var near := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(3, 3, 0)))
	var far := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(20, 3, 0)))
	var out_of_range := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(80, 3, 0)))
	for speaker in [near, far, out_of_range]:
		add_child(speaker)
	Events.night_started.emit(1, &"")
	GameState.mark_voice_heard(&"VO_HENIEK_NIGHT_1")   # straight to the System's line
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	Events.night_started.emit(1, &"")
	for i in 300:
		VoiceDirector.advance(0.1)
	assert_eq(VoiceDirector.current_line(), &"VO_SYSTEM_CLOSING_1")
	assert_true(near.is_speaking(), "the nearest plays at once")
	assert_false(out_of_range.is_speaking(), "80 m away stays silent")
	for i in 3:
		far.advance(0.1)
	assert_true(far.is_speaking(), "the farther one after its echo delay")


func test_a_stand_is_interactable_and_asks_the_director() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	var stand := AudioguideStand.create(&"rosetta", Transform3D.IDENTITY)
	add_child(stand)
	assert_eq(stand.prompt(), tr("PROMPT_AUDIOGUIDE"))
	assert_eq(stand.collision_layer, Layers.INTERACT)
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"VO_GUIDE_ROSETTA_A")
	assert_true(stand.is_speaking())
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"")
	assert_false(stand.is_speaking())


func test_floor1_places_loudspeakers_and_the_rosetta_stand() -> void:
	var layout := Floor1Layout.create()
	var speakers := layout.markers.keys().filter(func(k: StringName) -> bool: return String(k).begins_with("loudspeaker_"))
	assert_gt(speakers.size(), 2)
	assert_true(layout.markers.has(&"audioguide_rosetta"))
	for id in speakers:
		var at: Transform3D = layout.markers[id]
		var high := at.origin.y - layout.room(layout.marker_rooms[id]).floor_y   # (a gallery's speaker hangs over the gallery)
		assert_true(high > 2.5 and high < 5.0, "%s hangs high on a wall" % id)
	var stand: Transform3D = layout.markers[&"audioguide_rosetta"]
	assert_lt(stand.origin.distance_to(layout.markers[&"rosetta_stone"].origin), 4.0, "by the stone")


## (The night's QA, 19.10, in the window: the Rosetta vestibule's speaker
## hung in mid-air in the 7 m arch to the court, "over the door" of a door
## that is taller than it.)
func test_every_loudspeaker_hangs_on_wall_not_in_a_passage() -> void:
	var layout := Floor1Layout.create()
	var checked := 0
	for id: StringName in layout.markers:
		if not String(id).begins_with("loudspeaker_"):
			continue
		checked += 1
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		for opening in layout.openings:
			var area := opening.rect.grow(0.3)
			var in_span := area.has_point(Vector2(at.x, at.z))
			var in_height := at.y > opening.floor_y - 0.2 and at.y < opening.top_y + 0.2
			assert_false(in_span and in_height, "%s at %s hangs in the passage %s (%s, %.1f-%.1f m)" % [id, str(at), opening.id, str(opening.rect), opening.floor_y, opening.top_y])
	assert_gt(checked, 2, "speakers checked")


func test_a_stand_is_solid_to_walk_into() -> void:
	var stand := AudioguideStand.create(&"rosetta", Transform3D.IDENTITY)
	add_child(stand)
	var body: StaticBody3D = null
	for child in stand.get_children():
		if child is StaticBody3D:
			body = child
	assert_not_null(body, "a StaticBody3D under the stand")
	if body:
		assert_true(body.collision_layer & Layers.WORLD != 0, "on the world layer")
		assert_gt(body.get_child_count(), 0, "with a shape")


# --- G2: the stops and where they stand (plan 2026-10-19-glos-g2-kwestie) -------

func test_a_stand_shows_its_stop_number_on_the_plate() -> void:
	var stand := AudioguideStand.create(&"lamassu", Transform3D.IDENTITY)
	add_child(stand)
	var plate := stand.get_node_or_null(^"StopNumber") as Label3D
	assert_not_null(plate, "the number on the enamel plate")
	if plate:
		assert_eq(plate.text, str(AudioguideStand.STOPS[&"lamassu"]))
		assert_lt(plate.position.z, -0.05, "on the plate's front, toward the visitor")
		assert_almost_eq(plate.position.y, AudioguideStand.PLATE_Y, 0.001)
		assert_almost_eq(plate.rotation.y, PI, 0.001, "readable from the front")
	var stray := AudioguideStand.create(&"nowhere", Transform3D.IDENTITY)
	add_child(stray)
	assert_true(stray.get_node_or_null(^"StopNumber") == null, "a stand without a stop shows a blank plate")


func test_the_stops_are_numbered_one_by_one() -> void:
	var numbers: Array = AudioguideStand.STOPS.values()
	numbers.sort()
	assert_eq(numbers, range(1, numbers.size() + 1), "1..%d, each once" % numbers.size())
	assert_eq(AudioguideStand.STOPS.get(&"rosetta"), 1, "the Rosetta Stone stays stop one")


## Where the System is heard (spec 4.6): the court (four) and the way into every wing.
const SPEAKER_ZONES := {&"court": 4, &"entrance": 1, &"north_hall": 1, &"egypt": 1, &"assyria": 1,
		&"greece": 1, &"enlightenment": 1, &"asia": 1, &"americas": 1}
## Each stand by its exhibit: station -> [a point of the exhibit, the farthest the stand may be (m, across the floor)].
const EXHIBITS := {
	&"rosetta": [Vector3(-43.0, 1.0, 25.5), 4.0],
	&"ramesses": [Vector3(-36.0, 3.0, 12.0), 4.5],
	&"lamassu": [Vector3(-53.5, 2.0, -41.5), 4.5],
	&"flood": [Vector3(-59.5, 1.4, -30.5), 3.5],
	&"metopes": [Vector3(-82.75, 3.2, 39.46), 4.5],
	&"clocks": [Vector3(59.5, 2.0, -8.0), 4.0],
	&"buddha": [Vector3(13.5, 4.0, -57.5), 7.5],
	&"armour": [Vector3(40.5, 1.5, -74.0), 4.5],
	&"totems": [Vector3(-28.5, 3.0, -55.25), 4.5],
	&"moai": [Vector3(-40.5, 3.0, -56.6), 5.0],
	&"astrolabe": [Vector3(0.0, 0.3, 0.0), 4.5],
	&"trex": [Vector3(0.0, 1.2, -22.5), 10.0],
}


static func _ids(layout: LevelLayout, prefix: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in layout.markers:
		if String(id).begins_with(prefix):
			out.append(id)
	return out


static func _inside(room: RoomSpec, at: Vector3) -> bool:
	for part in room.parts:
		if part.grow(0.001).has_point(Vector2(at.x, at.z)):
			return true
	return false


## True when a prop [param height] m tall at [param at] comes within
## [param margin] m of the piece's box (its yawed footprint; across its
## height with [param rise] m to spare: a floor slab under a stand is no clash).
static func _in_piece(piece: PieceSpec, at: Vector3, margin: float, height: float, rise: float = 0.0) -> bool:
	var bottom := piece.position.y + 0.05
	var top := piece.position.y + piece.size.y - 0.05
	if at.y + height + rise < bottom or at.y - rise > top:
		return false
	var local := Basis(Vector3.UP, piece.yaw).inverse() * (at - piece.position)
	return absf(local.x) <= piece.size.x * 0.5 + margin and absf(local.z) <= piece.size.z * 0.5 + margin


static func _rect_distance(rect: Rect2, at: Vector3) -> float:
	var dx := maxf(maxf(rect.position.x - at.x, 0.0), at.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - at.z, 0.0), at.z - rect.end.y)
	return Vector2(dx, dz).length()


func test_the_system_is_heard_in_the_court_and_at_every_wings_way_in() -> void:
	var layout := Floor1Layout.create()
	var count := {}
	for id in _ids(layout, "loudspeaker_"):
		var zone := layout.room(layout.marker_rooms[id]).zone
		count[zone] = int(count.get(zone, 0)) + 1
	for zone: StringName in SPEAKER_ZONES:
		assert_true(int(count.get(zone, 0)) >= int(SPEAKER_ZONES[zone]), "%s: %d loudspeaker(s)" % [zone, int(count.get(zone, 0))])


func test_every_loudspeaker_hangs_on_its_rooms_wall_facing_in() -> void:
	var layout := Floor1Layout.create()
	for id in _ids(layout, "loudspeaker_"):
		var at: Transform3D = layout.markers[id]
		var room := layout.room(layout.marker_rooms[id])
		var spot := at.origin
		var high := spot.y - room.floor_y
		assert_true(high > 2.5 and high < 5.0, "%s hangs %.1f m over its room's floor" % [id, high])
		var to_wall := INF
		for part in room.parts:
			to_wall = minf(to_wall, minf(minf(absf(spot.x - part.position.x), absf(spot.x - part.end.x)),
					minf(absf(spot.z - part.position.y), absf(spot.z - part.end.y))))
		assert_lt(to_wall, 0.3, "%s is on a wall of %s (%.2f m off)" % [id, room.id, to_wall])
		assert_true(_inside(room, spot - at.basis.z * 1.0), "%s faces into %s" % [id, room.id])
		for piece in layout.pieces:
			assert_false(_in_piece(piece, spot + Vector3.DOWN * 0.2, 0.25, 0.4, 0.25), "%s is clear of the %s at %s" % [id, piece.kit, str(piece.position)])


func test_every_stand_stands_clear_by_its_exhibit() -> void:
	var layout := Floor1Layout.create()
	var stands := _ids(layout, "audioguide_")
	assert_eq(stands.size(), EXHIBITS.size(), "a stand for every stop")
	for id in stands:
		var station := StringName(String(id).trim_prefix("audioguide_"))
		assert_true(AudioguideStand.STOPS.has(station), "%s has a stop number" % id)
		assert_true(EXHIBITS.has(station), "%s has its exhibit" % id)
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		var room := layout.room(layout.marker_rooms[id])
		assert_almost_eq(at.y, room.floor_y, 0.05, "%s stands on the floor of %s" % [id, room.id])
		for step in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
			assert_true(_inside(room, at + step), "%s keeps off the walls of %s" % [id, room.id])
		for piece in layout.pieces:
			assert_false(_in_piece(piece, at, 0.35, 1.1), "%s is clear of the %s at %s" % [id, piece.kit, str(piece.position)])
		for opening in layout.openings:
			if absf(opening.floor_y - room.floor_y) < 0.5:
				assert_gt(_rect_distance(opening.rect, at), 1.2, "%s keeps out of the doorway %s" % [id, opening.id])
		for slot in layout.spawn_slots:
			assert_gt(Vector2(slot.position.x - at.x, slot.position.z - at.z).length(), 1.0, "%s: not where an exhibit wakes" % id)
		for spot in layout.loot_spots:
			assert_gt(Vector2(spot.position.x - at.x, spot.position.z - at.z).length(), 0.8, "%s: not on a loot spot" % id)
		for other: StringName in layout.markers:
			if other == id or absf((layout.markers[other] as Transform3D).origin.y - at.y) > 2.0:
				continue
			var there: Vector3 = (layout.markers[other] as Transform3D).origin
			assert_gt(Vector2(there.x - at.x, there.z - at.z).length(), 0.8, "%s: clear of the marker %s" % [id, other])
		if EXHIBITS.has(station):
			var exhibit: Vector3 = EXHIBITS[station][0]
			var reach := Vector2(exhibit.x - at.x, exhibit.z - at.z).length()
			assert_lt(reach, float(EXHIBITS[station][1]), "%s stands by its exhibit (%.1f m)" % [id, reach])
