class_name BiomePlaces
extends RefCounted
## Checks the biome mechanics' placement data against Floor I's layout (plan
## 2026-10-21-mechaniki-biomow): a point on a room's floor, a point on one
## of its walls, a floor area clear of pieces, spawns, patrol routes and
## doorways. Each returns the problems found ("" lines), empty when sound.


## Problems of a flat floor area (a square of [param size] m round
## [param at]) in [param room_id]: outside the room, under a solid piece,
## on a spawn slot, on a patrol route, in a doorway.
static func floor_area(layout: LevelLayout, room_id: StringName, at: Vector3, size: float, label: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var room := layout.room(room_id)
	if room == null:
		problems.append("%s: no room %s" % [label, room_id])
		return problems
	var half := size * 0.5
	var area := Rect2(at.x - half, at.z - half, size, size)
	for corner: Vector2 in [area.position, area.end, Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.position.y)]:
		if layout.room_at(Vector3(corner.x, at.y + 0.5, corner.y)) != room_id:
			problems.append("%s: corner %s is not in %s" % [label, corner, room_id])
	for piece in layout.pieces:
		if piece.room != room_id or not piece.collide or piece.position.y > at.y + 0.5:
			continue
		if piece.footprint().intersects(area):
			problems.append("%s: under piece %s at %s" % [label, piece.kit, piece.position])
	for slot in layout.spawn_slots:
		if slot.room == room_id and Vector2(slot.position.x - at.x, slot.position.z - at.z).length() < half + 0.5:
			problems.append("%s: on spawn slot %s" % [label, slot.position])
	for patrol in layout.patrols:
		for i in range(1, patrol.points.size()):
			if _to_segment(Vector2(at.x, at.z), patrol.points[i - 1], patrol.points[i]) < half + 0.4:
				problems.append("%s: on patrol %s" % [label, patrol.id])
	for opening in layout.openings:
		if opening.room_a != room_id and opening.room_b != room_id:
			continue
		if opening.rect.grow(1.0).intersects(area):
			problems.append("%s: in doorway %s" % [label, opening.id])
	return problems


## Problems of a point [param at] (floor height) meant to lie on a wall of
## [param room_id] facing [param inward] (flat): the room must be right in
## front of it and not behind it.
static func wall_point(layout: LevelLayout, room_id: StringName, at: Vector3, inward: Vector3, label: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var flat := Vector3(inward.x, 0.0, inward.z).normalized()
	var front := at + flat * 0.3 + Vector3.UP * 1.0
	var back := at - flat * 0.3 + Vector3.UP * 1.0
	if layout.room_at(front) != room_id:
		problems.append("%s: in front of the wall is %s, not %s" % [label, layout.room_at(front), room_id])
	var room := layout.room(room_id)
	if room != null and room.covers(Vector2(back.x, back.z)):
		problems.append("%s: no wall behind it (the room goes on)" % label)
	return problems


## Distance from [param point] to the flat segment [param a]-[param b].
static func _to_segment(point: Vector2, a: Vector3, b: Vector3) -> float:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	var along := to - from
	var t := 0.0 if along.length_squared() < 0.0001 else clampf((point - from).dot(along) / along.length_squared(), 0.0, 1.0)
	return point.distance_to(from + along * t)
