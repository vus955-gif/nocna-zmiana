extends RefCounted
## Helpers the east wings (zones/enlightenment.gd, zones/asia.gd) share on
## top of hub_kit.gd and west_kit.gd: railings, runs of wall furniture
## (bookcases, cases, armour racks) that leave the doorways free, and rows
## of pieces. Pure layout data, no nodes.

## Railing on a slab edge: 1.1 m high, 0.15 m thick (the guard jumps
## 0.83 m: nobody climbs over it).
const RAIL := Vector3(0.15, 1.1, 0.15)


## A railing [param length] m long centred at [param at] (its foot), along x
## (yaw 0) or along z (yaw PI/2).
static func rail(layout: LevelLayout, at: Vector3, length: float, along_z: bool, room_id: StringName) -> void:
	layout.add_piece(&"railing", at, Vector3(length, RAIL.y, RAIL.x), room_id, PI * 0.5 if along_z else 0.0)


## Wall furniture of [param kit] standing against a wall that runs along z
## at [param x] (its back on the wall line; [param facing] +1 = it faces +x,
## -1 = it faces -x), from [param from] to [param to] on the floor at
## [param y], cut into pieces at most [param longest] m long with
## [param gap] m between them, leaving [param keep_clear] (Vector2 ranges
## along z) free for doorways.
static func along_z(layout: LevelLayout, kit: StringName, x: float, facing: float, from: float, to: float, y: float, height: float, depth: float, room_id: StringName, keep_clear: Array = [], longest: float = 6.0, gap: float = 0.5) -> void:
	for span: Vector2 in _spans(from, to, keep_clear, longest, gap):
		var middle := (span.x + span.y) * 0.5
		layout.add_piece(kit, Vector3(x + facing * depth * 0.5, y, middle), Vector3(span.y - span.x, height, depth), room_id, -PI * 0.5 * facing)


## The same for a wall that runs along x at [param z] ([param facing] +1 =
## it faces +z, -1 = it faces -z).
static func along_x(layout: LevelLayout, kit: StringName, z: float, facing: float, from: float, to: float, y: float, height: float, depth: float, room_id: StringName, keep_clear: Array = [], longest: float = 6.0, gap: float = 0.5) -> void:
	for span: Vector2 in _spans(from, to, keep_clear, longest, gap):
		var middle := (span.x + span.y) * 0.5
		layout.add_piece(kit, Vector3(middle, y, z + facing * depth * 0.5), Vector3(span.y - span.x, height, depth), room_id, PI if facing > 0.0 else 0.0)


## [param from]..[param to] minus the [param keep_clear] ranges, cut into
## pieces no longer than [param longest] with [param gap] between them.
static func _spans(from: float, to: float, keep_clear: Array, longest: float, gap: float) -> Array[Vector2]:
	var free: Array[Vector2] = [Vector2(from, to)]
	for blocked: Vector2 in keep_clear:
		var next: Array[Vector2] = []
		for span in free:
			if blocked.y <= span.x or blocked.x >= span.y:
				next.append(span)
				continue
			if blocked.x > span.x:
				next.append(Vector2(span.x, blocked.x))
			if blocked.y < span.y:
				next.append(Vector2(blocked.y, span.y))
		free = next
	var pieces: Array[Vector2] = []
	for span in free:
		var length := span.y - span.x
		if length < 1.0:
			continue
		var count := ceili((length + gap) / (longest + gap))
		var each := (length - gap * (count - 1)) / count
		for i in count:
			var start := span.x + i * (each + gap)
			pieces.append(Vector2(start, start + each))
	return pieces
