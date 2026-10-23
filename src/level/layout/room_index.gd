class_name RoomIndex
extends RefCounted
## LevelLayout.room_at() through a grid (plan 2026-10-21-wydajnosc-cpu): the
## same answer - the room with a part over the point, between its floor
## (less 0.25 m) and ceiling, the highest floor winning and the first listed
## on a tie - from only the rooms whose parts touch the point's cell
## instead of every room of the floor (Floor I: 114, ~60 us a look-up in
## script). Built from a finished layout: rooms added or reshaped afterwards
## are not seen (build a new one).

## Cell size (m) of the floor-plan grid.
const CELL := 4.0

## Cell (Vector2i) -> Array of RoomSpec in the layout's order.
var _cells: Dictionary = {}
var _none: Array = []


static func build(layout: LevelLayout) -> RoomIndex:
	var index := RoomIndex.new()
	for room in layout.rooms:
		var cells := {}
		for part in room.parts:
			var low := Vector2i(floori(part.position.x / CELL), floori(part.position.y / CELL))
			var high := Vector2i(floori(part.end.x / CELL), floori(part.end.y / CELL))
			for x in range(low.x, high.x + 1):
				for z in range(low.y, high.y + 1):
					cells[Vector2i(x, z)] = true
		for cell: Vector2i in cells:
			var bucket: Array = index._cells.get(cell, [])
			if bucket.is_empty():
				index._cells[cell] = bucket
			bucket.append(room)
	return index


## The most rooms one cell looks at (tests: a look-up costs that many
## checks at worst, not one per room of the floor).
func largest_bucket() -> int:
	var most := 0
	for cell: Vector2i in _cells:
		most = maxi(most, (_cells[cell] as Array).size())
	return most


## The room [param point] lies in (&"" outside every room).
func room_at(point: Vector3) -> StringName:
	var best: RoomSpec = null
	for candidate: RoomSpec in _cells.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)), _none):
		if candidate.contains(point) and (best == null or candidate.floor_y > best.floor_y):
			best = candidate
	return best.id if best != null else &""
