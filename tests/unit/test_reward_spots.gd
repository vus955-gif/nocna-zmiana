extends TestCase
## Where the secrets' reward displays stand (plan 2026-10-10-nagrody-sekretow,
## review fixes): every one of the 27 on its room's floor, clear of every
## colliding piece, inside the room and off the doorways, its plaque turned
## to the room's nearest way in and readable from there. The court's marker
## lies on the face of the information desk's counter (a strongbox floating
## 30 cm up and buried 13 cm in it); 14 rooms had no door on the -Z side the
## plaques all faced.

## Samples per side of a footprint.
const GRID := 12
## Heights above the floor sampled for a hit with a solid.
const HEIGHTS: Array[float] = [0.1, 0.8, 1.5]
## The doorway's free zone in front of an opening (m).
const DOOR_ZONE := 0.8
## The floor in front of a plaque that must be free (m).
const READING := 0.6

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _spot(id: StringName) -> Transform3D:
	return RewardSpot.place(layout, id, layout.markers[id], SecretRewards.tier_of(id))


func _room(id: StringName) -> RoomSpec:
	return layout.room(layout.marker_rooms[id])


## Sample points over the floor rectangle [-half.x, half.x] x [z0, z1] of
## [param spot], on the level of [param height] above the room's floor.
func _samples(spot: Transform3D, half_x: float, z0: float, z1: float, height: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in GRID + 1:
		for j in GRID + 1:
			var local := Vector3(lerpf(-half_x, half_x, float(i) / GRID), height, lerpf(z0, z1, float(j) / GRID))
			points.append(spot * local)
	return points


## The collision shapes of the pieces that stand near [param spot]
## (LevelKit's own, as the level builds them): [transform, shape node].
func _solids_near(spot: Transform3D) -> Array:
	var found: Array = []
	for piece in layout.pieces:
		if not piece.collide or LevelKit.role(piece.kit) == &"floor":
			continue
		if Vector2(piece.position.x - spot.origin.x, piece.position.z - spot.origin.z).length() > piece.size.length() + 3.0:
			continue
		for shape in LevelKit.collision_shapes(piece.kit, piece.size):
			found.append([piece.transform() * shape.transform, shape.shape, piece.kit])
			shape.free()
	return found


func _inside(point: Vector3, solid: Array) -> bool:
	var local: Vector3 = (solid[0] as Transform3D).affine_inverse() * point
	var shape: Shape3D = solid[1]
	if shape is BoxShape3D:
		var half := (shape as BoxShape3D).size * 0.5
		return absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return absf(local.y) < cylinder.height * 0.5 and Vector2(local.x, local.z).length() < cylinder.radius
	return false


## The first solid among [param solids] that [param points] touch (its kit,
## "" when none).
func _touching(points: Array[Vector3], solids: Array) -> String:
	for point in points:
		for solid in solids:
			if _inside(point, solid):
				return String(solid[2])
	return ""


func _footprint_samples(spot: Transform3D, tier: SecretRewards.Tier, height: float) -> Array[Vector3]:
	var size := SecretRewardDisplay.footprint(tier)
	return _samples(spot, size.x * 0.5, -size.y * 0.5, size.y * 0.5, height)


func test_every_secret_has_a_marker_to_stand_at() -> void:
	for id in SecretRewards.ids():
		assert_true(layout.markers.has(id), "%s has a marker" % id)
		assert_not_null(layout.room(layout.marker_rooms.get(id, &"")), "%s lies in a room" % id)


func test_every_display_stands_on_its_rooms_floor() -> void:
	for id in SecretRewards.ids():
		assert_almost_eq(_spot(id).origin.y, _room(id).floor_y, 0.0001, "%s on the floor" % id)


func test_no_display_stands_in_a_piece_or_in_the_wall_or_in_a_doorway() -> void:
	var checked := 0
	for id in SecretRewards.ids():
		var spot := _spot(id)
		var tier := SecretRewards.tier_of(id)
		var room := _room(id)
		var solids := _solids_near(spot)
		checked += 1
		for height in HEIGHTS:
			var points := _footprint_samples(spot, tier, room.floor_y - spot.origin.y + height)
			var hit := _touching(points, solids)
			assert_eq(hit, "", "%s stands clear of the pieces (%s in it)" % [id, hit])
		for point in _footprint_samples(spot, tier, 0.0):
			assert_true(room.covers(Vector2(point.x, point.z)), "%s inside its room's walls" % id)
			for opening in layout.openings:
				if opening.room_a == room.id or opening.room_b == room.id:
					assert_false((opening.rect as Rect2).grow(DOOR_ZONE).has_point(Vector2(point.x, point.z)), "%s off the doorway %s" % [id, opening.id])
	assert_eq(checked, SecretRewards.total())


func test_the_courts_strongbox_no_longer_floats_in_the_information_desk() -> void:
	var marker: Transform3D = layout.markers[&"secret_court_1"]
	var desk: PieceSpec = null
	for piece in layout.pieces:
		if piece.kit == &"info_desk":
			desk = piece
	assert_not_null(desk)
	var spot := _spot(&"secret_court_1")
	assert_almost_eq(spot.origin.y, 0.0, 0.0001, "on the floor of the court, not 30 cm up the counter's face")
	var local := desk.transform().affine_inverse() * spot.origin
	var size := SecretRewardDisplay.footprint(SecretRewards.Tier.SMALL)
	var outside_x := absf(local.x) - desk.size.x * 0.5 - size.x * 0.5
	var outside_z := absf(local.z) - desk.size.z * 0.5 - size.y * 0.5
	assert_true(outside_x > 0.0 or outside_z > 0.0, "the strongbox stands beside the counter, not in it")
	assert_lt(Vector2(spot.origin.x - marker.origin.x, spot.origin.z - marker.origin.z).length(), 0.6, "still by the loose stone")


func _entrance(id: StringName) -> Vector2:
	var room := _room(id)
	var flat := Vector2(_spot(id).origin.x, _spot(id).origin.z)
	var best := Vector2.ZERO
	var best_distance := INF
	for secret_only in [true, false]:
		for opening in layout.openings:
			if opening.room_a != room.id and opening.room_b != room.id:
				continue
			var other := layout.room(opening.room_b if opening.room_a == room.id else opening.room_a)
			if secret_only and room.secret and other != null and other.secret:
				continue
			var centre: Vector2 = (opening.rect as Rect2).get_center()
			if flat.distance_to(centre) < best_distance:
				best_distance = flat.distance_to(centre)
				best = centre - flat
		if best_distance < INF:
			break
	return best.normalized()


func _front(spot: Transform3D) -> Vector2:
	var forward := spot.basis * Vector3.FORWARD
	return Vector2(forward.x, forward.z)


func test_the_plaque_faces_the_nearest_way_in() -> void:
	var turned_aside := 0
	for id in SecretRewards.ids():
		var heading := _front(_spot(id)).dot(_entrance(id))
		if heading < 0.7:
			turned_aside += 1
			assert_eq(id, &"secret_court_1", "%s faces its way in" % id)
			assert_gt(heading, -0.1, "%s is at least not turned away" % id)
	assert_eq(turned_aside, 1, "only the court's strongbox, with the counter in front of it")


func test_the_floor_in_front_of_every_plaque_is_free() -> void:
	for id in SecretRewards.ids():
		var spot := _spot(id)
		var tier := SecretRewards.tier_of(id)
		var size := SecretRewardDisplay.footprint(tier)
		var room := _room(id)
		var solids := _solids_near(spot)
		for height in HEIGHTS:
			var points := _samples(spot, 0.2, -size.y * 0.5 - READING, -size.y * 0.5 - 0.02, room.floor_y - spot.origin.y + height)
			assert_eq(_touching(points, solids), "", "%s: nothing in front of its plaque" % id)
			for point in points:
				assert_true(room.covers(Vector2(point.x, point.z)), "%s: room to read its plaque in" % id)
