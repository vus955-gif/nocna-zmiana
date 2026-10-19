class_name RewardSpot
extends RefCounted
## Where a secret's reward display stands (plan 2026-10-10-nagrody-sekretow,
## review fixes). A secret_* marker only says "about here": the court's lies
## on the face of the information desk's counter, 30 cm up, and every one
## faces -Z whichever way the room opens. place() takes the marker to the
## spot the display really stands at:
## - on the room's floor,
## - pushed clear of the colliding pieces (by the shortest way, with
##   CLEARANCE to spare),
## - turned, true to the walls, so that the plaque faces the room's nearest
##   way in (an opening that does not lead on into another secret room, when
##   there is one), or, with a counter or a shelf right in front of the
##   plaque, to the next side that leaves READ_DEPTH of floor to read it on.
## Pure geometry on a LevelLayout (no nodes).

## Free floor kept round the display (m).
const CLEARANCE := 0.12
## Pieces lower than this over the floor are in the display's way, higher
## ones hang over it.
const HEIGHT := 1.6
## The floor kept free in front of the plaque (m), and how wide.
const READ_DEPTH := 0.8
const READ_WIDTH := 0.4
## Pieces further than this from the marker (m) are not looked at.
const NEAR := 6.0
## The turns tried, from facing the way in, until the plaque has room.
const TURNS: Array[float] = [0.0, PI * 0.5, -PI * 0.5, PI]
## Settling stops after this many rounds of pushing.
const ROUNDS := 8


## A floor rectangle: centre, half sizes (across, deep), yaw as in a marker.
class Box:
	var centre: Vector2
	var half: Vector2
	var yaw: float

	func _init(at: Vector2, extent: Vector2, turn: float) -> void:
		centre = at
		half = extent
		yaw = turn

	## The two axes of the rectangle on the floor plan (x, z).
	func axes() -> Array[Vector2]:
		var own: Array[Vector2] = [Vector2(cos(yaw), -sin(yaw)), Vector2(sin(yaw), cos(yaw))]
		return own

	## Half the rectangle's width along [param axis] (a unit vector).
	func radius(axis: Vector2) -> float:
		var own := axes()
		return absf(axis.dot(own[0])) * half.x + absf(axis.dot(own[1])) * half.y


## The marker [param marker] of secret [param id] as the display of
## [param tier] stands at it (the marker itself when its room is unknown).
static func place(layout: LevelLayout, id: StringName, marker: Transform3D, tier: SecretRewards.Tier) -> Transform3D:
	var room := layout.room(layout.marker_rooms.get(id, &"")) if layout != null else null
	if room == null:
		return marker
	var size := SecretRewardDisplay.footprint(tier)
	var flat := Vector2(marker.origin.x, marker.origin.z)
	var solids := _solids(layout, room, flat)
	var base := _entrance_yaw(layout, room, flat, marker.basis.get_euler().y)
	var chosen: Box = null
	for turn in TURNS:
		var body := Box.new(flat, size * 0.5 + Vector2.ONE * CLEARANCE, base + turn)
		_settle(body, solids)
		if chosen == null:
			chosen = body   # the way in itself, should no turn leave room to read
		if _readable(room, solids, body, size):
			chosen = body
			break
	return Transform3D(Basis(Vector3.UP, chosen.yaw), Vector3(chosen.centre.x, room.floor_y, chosen.centre.y))


## The yaw of a marker (as in LevelLayout.add_marker) whose -Z points along
## the floor-plan direction [param direction].
static func yaw_towards(direction: Vector2) -> float:
	return atan2(-direction.x, -direction.y)


## The floor-plan direction a marker of [param yaw] faces (its -Z).
static func facing(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


# --- the spot -------------------------------------------------------------------

## Moves [param body] off every solid it touches, round after round (a
## push may press it into the next one).
static func _settle(body: Box, solids: Array[Box]) -> void:
	for round_ in ROUNDS:
		var moved := false
		for solid in solids:
			var push := _push_out(body, solid)
			if push != Vector2.ZERO:
				body.centre += push
				moved = true
		if not moved:
			return


## The pieces near [param flat] that stand in the display's way: colliding,
## not a floor, reaching up into the first HEIGHT metres over the room's floor.
static func _solids(layout: LevelLayout, room: RoomSpec, flat: Vector2) -> Array[Box]:
	var solids: Array[Box] = []
	for piece in layout.pieces:
		if not piece.collide or LevelKit.role(piece.kit) == &"floor":
			continue
		if piece.position.y >= room.floor_y + HEIGHT or piece.position.y + piece.size.y <= room.floor_y + 0.05:
			continue
		if Vector2(piece.position.x, piece.position.z).distance_to(flat) > piece.size.length() + NEAR:
			continue
		solids.append(Box.new(Vector2(piece.position.x, piece.position.z), _reach(piece) * 0.5, piece.yaw))
	return solids


## The floor a piece takes (a column's base and capital are wider than its
## shaft; a dead tree stops at its trunk).
static func _reach(piece: PieceSpec) -> Vector2:
	match piece.kit:
		&"column":
			return Vector2(piece.size.x, piece.size.z) * 1.35
		&"dead_tree":
			return Vector2(0.5, 0.5)
	return Vector2(piece.size.x, piece.size.z)


## The shortest move that takes [param body] clear of [param other] (ZERO
## when they do not touch): separating axis test on two floor rectangles.
static func _push_out(body: Box, other: Box) -> Vector2:
	var offset := body.centre - other.centre
	var best := Vector2.ZERO
	var least := INF
	var axes: Array[Vector2] = body.axes()
	axes.append_array(other.axes())
	for axis in axes:
		var along := offset.dot(axis)
		var depth := body.radius(axis) + other.radius(axis) - absf(along)
		if depth <= 0.0:
			return Vector2.ZERO
		if depth < least:
			least = depth
			best = axis * (depth if along >= 0.0 else -depth)
	return best


# --- the turn -------------------------------------------------------------------

## The yaw that points a plaque at the room's nearest opening from
## [param flat], to the nearest quarter turn (the rooms are square and a
## plinth stands true to their walls; the plaque is at most 45 degrees off
## the way in); [param fallback] when the room has none.
static func _entrance_yaw(layout: LevelLayout, room: RoomSpec, flat: Vector2, fallback: float) -> float:
	var way := _way_in(layout, room, flat)
	return snappedf(yaw_towards(way), PI * 0.5) if way != Vector2.ZERO else fallback


## The direction from [param flat] to the room's nearest opening, ZERO when
## it has none. A secret room's way in is not its door on to another secret
## room (the pottery store's door to the cast cellar) unless that is all.
static func _way_in(layout: LevelLayout, room: RoomSpec, flat: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for skip_secret in [true, false]:
		for opening in layout.openings:
			if opening.room_a != room.id and opening.room_b != room.id:
				continue
			var other := layout.room(opening.room_b if opening.room_a == room.id else opening.room_a)
			if skip_secret and room.secret and other != null and other.secret:
				continue
			var centre := opening.rect.get_center()
			if flat.distance_to(centre) < best_distance:
				best_distance = flat.distance_to(centre)
				best = centre - flat
		if best_distance < INF:
			break
	return best.normalized()


## True when the floor in front of the plaque of [param body] (READ_DEPTH
## deep) is in the room and clear of the pieces.
static func _readable(room: RoomSpec, solids: Array[Box], body: Box, size: Vector2) -> bool:
	var front := facing(body.yaw)
	var ahead := Box.new(body.centre + front * (size.y * 0.5 + READ_DEPTH * 0.5), Vector2(READ_WIDTH * 0.5, READ_DEPTH * 0.5), body.yaw)
	for solid in solids:
		if _push_out(ahead, solid) != Vector2.ZERO:
			return false
	var across := ahead.axes()[0]
	for end: float in [-1.0, 1.0]:
		for depth: float in [-1.0, 1.0]:
			var corner := ahead.centre + across * (end * ahead.half.x) + front * (depth * ahead.half.y)
			if not room.covers(corner):
				return false
	return true
