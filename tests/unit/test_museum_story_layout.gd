extends TestCase
## Floor I's story layer in the layout (plan docs/superpowers/plans/
## 2026-10-21-opowiesc-muzeum.md): the exhibit labels stand where their
## markers say, clear of the pieces, on a wall or on the floor, and every
## clue points at something the floor really has.

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


static func _origin(markers: Dictionary, id: StringName) -> Vector3:
	return (markers[id] as Transform3D).origin


## The way a marker faces (-Z), flat.
static func _facing(markers: Dictionary, id: StringName) -> Vector3:
	var forward := -(markers[id] as Transform3D).basis.z
	forward.y = 0.0
	return forward.normalized()


static func _inside(room: RoomSpec, at: Vector3) -> bool:
	for part in room.parts:
		if part.grow(0.001).has_point(Vector2(at.x, at.z)):
			return true
	return false


## True when a prop [param height] m tall at [param at] comes within
## [param margin] m of the piece's box (its yawed footprint, across its height).
static func _in_piece(piece: PieceSpec, at: Vector3, margin: float, height: float) -> bool:
	var bottom := piece.position.y + 0.05
	var top := piece.position.y + piece.size.y - 0.05
	if at.y + height < bottom or at.y > top:
		return false
	var local := Basis(Vector3.UP, piece.yaw).inverse() * (at - piece.position)
	return absf(local.x) <= piece.size.x * 0.5 + margin and absf(local.z) <= piece.size.z * 0.5 + margin


static func _rect_distance(rect: Rect2, at: Vector3) -> float:
	var dx := maxf(maxf(rect.position.x - at.x, 0.0), at.x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - at.z, 0.0), at.z - rect.end.y)
	return Vector2(dx, dz).length()


func _label_markers() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in layout.markers:
		if String(id).begins_with(ExhibitLabels.PREFIX):
			out.append(id)
	return out


func test_every_label_has_its_marker_and_every_marker_its_label() -> void:
	for id in ExhibitLabels.ids():
		assert_true(layout.markers.has(ExhibitLabels.marker_of(id)), "label %s has a marker" % id)
	for marker in _label_markers():
		assert_true(ExhibitLabels.has(ExhibitLabels.id_of_marker(marker)), "%s is in the catalogue" % marker)
	assert_true(ExhibitLabels.ids().size() >= 18, "labels all over the floor")
	# every wing has at least two, the hub some too
	var per_zone := {}
	for marker in _label_markers():
		var zone := layout.room(layout.marker_rooms[marker]).zone
		per_zone[zone] = int(per_zone.get(zone, 0)) + 1
	for zone in Floor1Plan.WINGS:
		assert_true(int(per_zone.get(zone, 0)) >= 2, "%s has labels (%d)" % [zone, int(per_zone.get(zone, 0))])


func test_every_label_lies_in_its_room() -> void:
	for marker in _label_markers():
		var room := layout.room(layout.marker_rooms[marker])
		var at := _origin(layout.markers, marker)
		assert_true(_inside(room, at), "%s lies over %s" % [marker, room.id])
		assert_true(at.y >= room.floor_y - 0.05 and at.y <= room.floor_y + 2.4, "%s at a reader's height in %s" % [marker, room.id])


## A stand: on its room's floor, off the walls, clear of the pieces, the
## doorways, the exhibits' spots, the loot and the other markers (like the
## audio guide's stands).
func test_label_stands_stand_clear() -> void:
	var checked := 0
	for id in ExhibitLabels.ids():
		if ExhibitLabels.mount(id) != ExhibitLabels.Mount.STAND:
			continue
		checked += 1
		var marker := ExhibitLabels.marker_of(id)
		_check_stand(marker, 0.35)
	assert_gt(checked, 3, "some labels stand on the floor")


func _check_stand(marker: StringName, margin: float) -> void:
	var at := _origin(layout.markers, marker)
	var room := layout.room(layout.marker_rooms[marker])
	assert_almost_eq(at.y, room.floor_y, 0.05, "%s stands on the floor of %s" % [marker, room.id])
	for step in [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
		assert_true(_inside(room, at + step), "%s keeps off the walls of %s" % [marker, room.id])
	assert_true(_inside(room, at + _facing(layout.markers, marker) * 1.2), "%s: the reader stands in %s" % [marker, room.id])
	for piece in layout.pieces:
		if piece.collide:
			assert_false(_in_piece(piece, at, margin, 1.1), "%s is clear of the %s at %s" % [marker, piece.kit, str(piece.position)])
	for opening in layout.openings:
		if absf(opening.floor_y - room.floor_y) < 0.5:
			assert_gt(_rect_distance(opening.rect, at), 1.2, "%s keeps out of the doorway %s" % [marker, opening.id])
	for slot in layout.spawn_slots:
		if absf(slot.position.y - at.y) < 1.0:
			assert_gt(Vector2(slot.position.x - at.x, slot.position.z - at.z).length(), 1.0, "%s: not where an exhibit wakes (%s)" % [marker, str(slot.position)])
	for spot in layout.loot_spots:
		if absf(spot.position.y - at.y) < 2.0:
			assert_gt(Vector2(spot.position.x - at.x, spot.position.z - at.z).length(), 0.8, "%s: not on a loot spot" % marker)
	for other: StringName in layout.markers:
		if other == marker or absf(_origin(layout.markers, other).y - at.y) > 2.0:
			continue
		var there := _origin(layout.markers, other)
		assert_gt(Vector2(there.x - at.x, there.z - at.z).length(), 0.8, "%s: clear of the marker %s" % [marker, other])


## A plate on a wall or a pedestal: a solid face right behind it (a wall:
## outside the room, or a piece), the room in front, nothing solid in the
## way, out of every doorway.
func test_label_plates_hang_on_a_face_toward_their_room() -> void:
	var checked := 0
	for id in ExhibitLabels.ids():
		if ExhibitLabels.mount(id) == ExhibitLabels.Mount.STAND:
			continue
		checked += 1
		_check_plate(ExhibitLabels.marker_of(id))
	assert_gt(checked, 8, "most labels hang on walls and pedestals")


func _check_plate(marker: StringName) -> void:
	var at := _origin(layout.markers, marker)
	var room := layout.room(layout.marker_rooms[marker])
	var out := _facing(layout.markers, marker)
	var behind := at - out * 0.06
	var on_piece := false
	for piece in layout.pieces:
		if piece.collide and _in_piece(piece, behind, 0.0, 0.0):
			on_piece = true
	assert_true(on_piece or not _inside(room, behind), "%s hangs on a wall or a piece of %s" % [marker, room.id])
	assert_true(_inside(room, at + out * 1.0), "%s faces into %s" % [marker, room.id])
	for piece in layout.pieces:
		if piece.collide:
			assert_false(_in_piece(piece, at + out * 0.25 + Vector3.DOWN * 0.15, 0.0, 0.3), "%s: nothing solid in front of it (%s at %s)" % [marker, piece.kit, str(piece.position)])
	for opening in layout.openings:
		if at.y >= opening.floor_y - 0.1 and at.y <= opening.top_y + 0.1:
			assert_gt(_rect_distance(opening.rect, at), 0.3, "%s is not in the doorway %s" % [marker, opening.id])


## The clues point at real things: the guardian's marker, the secret and
## the gate that hides it (the gate's opening leads into the secret's room,
## the tool is what the gate asks for), the ambush that wakes.
func test_every_clue_points_at_something_real() -> void:
	var kinds := {}
	for id in ExhibitLabels.ids():
		var data := ExhibitLabels.clue_data(id)
		var kind := ExhibitLabels.clue(id)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		match kind:
			ExhibitLabels.Clue.WEAKNESS:
				var marker: StringName = data.get("marker", &"")
				assert_true(layout.markers.has(marker), "%s: the guardian's marker %s" % [id, marker])
				var known := marker == Floor1Plan.TREX_MARKER
				for guardian in Floor1Plan.guardians():
					known = known or guardian.marker == marker
				assert_true(known, "%s points at a guardian (%s)" % [id, marker])
			ExhibitLabels.Clue.SECRET:
				var secret: StringName = data.get("secret", &"")
				assert_true(layout.markers.has(secret), "%s: the secret %s" % [id, secret])
				var gate := layout.gate(data.get("gate", &""))
				assert_not_null(gate, "%s: the gate %s" % [id, data.get("gate")])
				if gate != null and layout.markers.has(secret):
					assert_eq(gate.requirement, data.get("tool"), "%s: %s needs %s" % [id, gate.id, data.get("tool")])
					var opening := layout.opening(gate.opening)
					var room: StringName = layout.marker_rooms[secret]
					assert_true(opening != null and (opening.room_a == room or opening.room_b == room), "%s: %s opens into %s" % [id, gate.id, room])
			ExhibitLabels.Clue.TOOL:
				var gate := layout.gate(data.get("gate", &""))
				assert_not_null(gate, "%s: the gate %s" % [id, data.get("gate")])
				if gate != null:
					assert_eq(gate.requirement, data.get("tool"), "%s: %s needs %s" % [id, gate.id, data.get("tool")])
			ExhibitLabels.Clue.WARNING:
				assert_not_null(layout.ambush(data.get("ambush", &"")), "%s: the ambush %s" % [id, data.get("ambush")])
	assert_true(int(kinds.get(ExhibitLabels.Clue.WEAKNESS, 0)) >= 5, "weak spots of most guardians")
	assert_true(int(kinds.get(ExhibitLabels.Clue.SECRET, 0)) >= 5, "secrets in every wing")
	assert_true(int(kinds.get(ExhibitLabels.Clue.WARNING, 0)) >= 2, "exhibits that wake, shown before")


## A clue stands in the wing of what it points at (the reader finds it there).
func test_a_clue_stands_in_its_referents_wing() -> void:
	for id in ExhibitLabels.ids():
		var data := ExhibitLabels.clue_data(id)
		var target: StringName = data.get("marker", data.get("secret", &""))
		if target == &"" or not layout.markers.has(target):
			continue
		var here := layout.room(layout.marker_rooms[ExhibitLabels.marker_of(id)]).zone
		var there := layout.room(layout.marker_rooms[target]).zone
		assert_eq(here, there, "%s stands in the wing of %s" % [id, target])


# --- the staff's trails --------------------------------------------------------------

func _vignette_markers() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in layout.markers:
		if String(id).begins_with(StoryVignettes.PREFIX):
			out.append(id)
	return out


func test_every_wing_has_a_staff_trail_with_one_thing_to_look_at() -> void:
	var per_wing := {}
	for marker in _vignette_markers():
		var parsed := StoryVignettes.parse(marker)
		assert_ne(parsed[0], &"", "%s names its wing" % marker)
		assert_true(StoryProps.KINDS.has(parsed[1]), "%s: a prop StoryProps builds (%s)" % [marker, parsed[1]])
		if parsed[0] == &"":
			continue
		assert_eq(layout.room(layout.marker_rooms[marker]).zone, parsed[0], "%s lies in its wing" % marker)
		per_wing[parsed[0]] = int(per_wing.get(parsed[0], 0)) + 1
	for wing in Floor1Plan.WINGS:
		assert_true(int(per_wing.get(wing, 0)) >= 4, "%s: a trail of things (%d)" % [wing, int(per_wing.get(wing, 0))])
		assert_true(layout.markers.has(StoryVignettes.KEY_PROPS.get(wing, &"")), "%s: its one thing to look at" % wing)
	assert_eq(StoryVignettes.KEY_PROPS.size(), Floor1Plan.WINGS.size(), "one per wing")


## A trail ends somewhere that matters: a thing of it lies by the doorway
## (a secret's gate, a haven's door, the stairs down).
func test_every_trail_ends_by_its_doorway() -> void:
	for wing in Floor1Plan.WINGS:
		var opening := layout.opening(StoryVignettes.ENDS.get(wing, &""))
		assert_not_null(opening, "%s: the doorway %s" % [wing, StoryVignettes.ENDS.get(wing)])
		if opening == null:
			continue
		var nearest := INF
		for marker in _vignette_markers():
			if StoryVignettes.parse(marker)[0] == wing:
				nearest = minf(nearest, _rect_distance(opening.rect, _origin(layout.markers, marker)))
		assert_lt(nearest, 2.5, "%s's trail ends by %s (%.1f m)" % [wing, opening.id, nearest])


func test_trail_props_lie_on_their_floor_or_hang_on_a_wall() -> void:
	for marker in _vignette_markers():
		var kind: StringName = StoryVignettes.parse(marker)[1]
		if StoryVignettes.on_wall(kind):
			_check_plate(marker)
			continue
		var at := _origin(layout.markers, marker)
		var room := layout.room(layout.marker_rooms[marker])
		assert_almost_eq(at.y, room.floor_y, 0.02, "%s lies on the floor of %s" % [marker, room.id])
		for step in [Vector3(0.25, 0, 0), Vector3(-0.25, 0, 0), Vector3(0, 0, 0.25), Vector3(0, 0, -0.25)]:
			assert_true(_inside(room, at + step), "%s keeps off the walls of %s" % [marker, room.id])
		for piece in layout.pieces:
			if piece.collide:
				assert_false(_in_piece(piece, at, 0.1, 0.3), "%s is clear of the %s at %s" % [marker, piece.kit, str(piece.position)])
		for opening in layout.openings:
			if absf(opening.floor_y - room.floor_y) < 0.5:
				assert_gt(_rect_distance(opening.rect, at), 0.5, "%s is not in the doorway %s" % [marker, opening.id])


# --- the exhibits that answer ----------------------------------------------------------

func test_every_curio_has_its_marker() -> void:
	for id in Curios.ids():
		assert_true(layout.markers.has(Curios.marker_of(id)), "curio %s has a marker" % id)
	for id: StringName in layout.markers:
		if String(id).begins_with(Curios.PREFIX):
			assert_true(Curios.has(Curios.id_of_marker(id)), "%s is a curio" % id)
	assert_eq(layout.room(layout.marker_rooms[Curios.marker_of(&"bird")]).id, &"enlightenment_clocks", "the bird among the clocks")
	assert_eq(layout.room(layout.marker_rooms[Curios.marker_of(&"portrait")]).zone, &"north_hall", "the founder by the crypt")
	assert_eq(layout.room(layout.marker_rooms[Curios.marker_of(&"scale")]).zone, &"egypt")


## The bird's cage, the astrolabe's stand and the scales stand on the floor
## clear of everything (they are solid); the portrait hangs on a wall, its
## frame clear of the doorways.
func test_curios_stand_clear_or_hang_on_a_wall() -> void:
	for id in [&"bird", &"astrolabe", &"scale"]:
		_check_stand(Curios.marker_of(id), 0.45)
	var portrait := Curios.marker_of(&"portrait")
	_check_plate(portrait)
	var at := _origin(layout.markers, portrait)
	for opening in layout.openings:
		if at.y >= opening.floor_y - 0.6 and at.y <= opening.top_y + 0.6:
			assert_gt(_rect_distance(opening.rect, at), 0.9, "the portrait's frame clears the doorway %s" % opening.id)


## The bird sings its long note toward the Great Orrery: the marker it reads.
func test_the_bird_has_the_orrery_to_sing_to() -> void:
	assert_true(layout.markers.has(&"guardian_planetarium"))
	var bird := _origin(layout.markers, Curios.marker_of(&"bird"))
	var orrery := _origin(layout.markers, &"guardian_planetarium")
	assert_lt(Vector2(bird.x - orrery.x, bird.z - orrery.z).length(), 20.0, "next door to the rotunda")


# --- the places the guard comes back to ------------------------------------------------

func test_the_plaque_and_the_corkboard_hang_in_the_court() -> void:
	for marker: StringName in [&"rest_plaque", &"cafe_corkboard"]:
		assert_true(layout.markers.has(marker), str(marker))
		assert_eq(layout.marker_rooms.get(marker), &"court", "%s in the Great Court" % marker)
		_check_plate(marker)
	# the corkboard by the café, but out of its corner (the café's own test)
	var board := _origin(layout.markers, &"cafe_corkboard")
	var cafe: Vector3 = (layout.markers[&"cafe_machine"] as Transform3D).origin
	assert_lt(Vector2(board.x - cafe.x, board.z - cafe.z).length(), 6.0, "by the café")
	var rect := Rect2()
	for piece in layout.pieces:
		if piece.kit == &"cafe_counter" or piece.kit == &"cafe_flap":
			rect = piece.footprint() if rect.size == Vector2.ZERO else rect.merge(piece.footprint())
	assert_false(rect.grow(0.4).has_point(Vector2(board.x, board.z)), "out of the café's corner")
	# the plaque by the entrance arch, at eye height
	var plaque := _origin(layout.markers, &"rest_plaque")
	assert_lt(plaque.distance_to(Vector3(0, 1.7, 30)), 9.0, "by the way in from the entrance hall")
