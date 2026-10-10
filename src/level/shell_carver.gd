class_name ShellCarver
extends RefCounted
## Carves a level's solid shell out of its empty spaces. The layout only
## lists empty volumes (rooms, door passages, skylight wells); everything
## around them becomes solid: a floor under the lowest space of each grid
## column, a slab between stacked spaces, a ceiling over the top one (plus
## wall up to the tallest neighbour, e.g. over a doorway into a tall hall),
## wall under a raised passage down to the lowest floor around (a hatch at
## balcony height in the wall of a hall), and walls in the columns next to
## empty ones, from the lowest floor to the highest ceiling around. Door
## openings, jambs, lintels and light wells come out watertight by
## construction. Equal neighbouring solids merge greedily into boxes. Where
## a wall is shared, a room gives it its look before a passage, and an
## ordinary room before a secret one (a secret's colour must not show on
## the public side). Pure function of the input; results are cached, in
## memory and on disk (ShellCache: a whole floor takes seconds to carve).

## Grid resolution; every volume rectangle must lie on it.
const CELL := 0.5
## The carving's own version: raise it whenever _carve() changes what it
## makes (the boxes kept on disk are thrown away then).
const VERSION := 1
const FLOOR_T := 0.5
const ROOF_T := 0.5
const EPS := 0.001

enum Kind { ROOM, PASSAGE, SKY }


class Volume:
	var rect := Rect2()
	var bottom: float = 0.0
	var top: float = 0.0
	## Room or opening id (a sky well carries its room's id).
	var owner: StringName = &""
	## ShellCarver.Kind
	var kind: int = 0
	## A secret space: shared walls take the look of the other side.
	var hidden: bool = false


class ShellBox:
	## &"floor", &"threshold" (floor of a passage), &"slab" (between stacked
	## spaces), &"ceiling", &"lintel" (top of a passage) or &"wall".
	var kit: StringName = &""
	## Volume that gives the box its look (room or opening id).
	var owner: StringName = &""
	## Volume whose floor is this box's top (&"" = nobody walks on it).
	var walk_owner: StringName = &""
	var aabb := AABB()
	## Lies above every empty space of its columns (ceilings, roofs, wall
	## over a doorway): no walker ever stands on it.
	var above_all: bool = false


## One flat wall face seen from inside a room (for stage-3 wall modules):
## [member aabb] has no thickness along [member normal], which points into
## the room.
class WallFace:
	var room: StringName = &""
	var normal := Vector3.ZERO
	var aabb := AABB()


static var _cache: Dictionary = {}
static var _face_cache: Dictionary = {}


static func volume(area: Rect2, bottom: float, top: float, owner_id: StringName, kind: Kind, is_hidden: bool = false) -> Volume:
	var result := Volume.new()
	result.rect = area
	result.bottom = bottom
	result.top = top
	result.owner = owner_id
	result.kind = kind
	result.hidden = is_hidden
	return result


## True when [param value] lies on the grid.
static func on_grid(value: float) -> bool:
	return is_equal_approx(value / CELL, roundf(value / CELL))


## The solid boxes around [param volumes]. The returned array is shared
## (cached); do not modify it.
static func carve(volumes: Array[Volume]) -> Array[ShellBox]:
	var key := _cache_key(volumes)
	if not _cache.has(key):
		var kept: Variant = ShellCache.fetch(key)
		if kept is Array:
			_cache[key] = kept
		else:
			var carved := _carve(volumes)
			ShellCache.keep(key, carved)
			_cache[key] = carved
	return _cache[key]


## The cache key of [param volumes] (ShellCache keeps carvings under it).
static func cache_key(volumes: Array[Volume]) -> String:
	return _cache_key(volumes)


## True when the carving of [param volumes] is in memory already.
static func is_carved(volumes: Array[Volume]) -> bool:
	return _cache.has(_cache_key(volumes))


## Every flat wall face seen from inside a room, merged into rectangles
## (stage 3 lines rooms with wall modules from these). The returned array is
## shared (cached); do not modify it.
static func wall_faces(volumes: Array[Volume]) -> Array[WallFace]:
	var key := _cache_key(volumes)
	if not _face_cache.has(key):
		_face_cache[key] = _faces(volumes)
	return _face_cache[key]


static func _cache_key(volumes: Array[Volume]) -> String:
	var parts := PackedStringArray()
	for v in volumes:
		parts.append("%s,%s,%s,%s,%s,%s,%s,%d,%d" % [v.rect.position.x, v.rect.position.y, v.rect.size.x, v.rect.size.y, v.bottom, v.top, v.owner, v.kind, int(v.hidden)])
	return ";".join(parts)


@warning_ignore("integer_division")
static func _carve(volumes: Array[Volume]) -> Array[ShellBox]:
	var result: Array[ShellBox] = []
	if volumes.is_empty():
		return result
	var lo := volumes[0].rect.position
	var hi := volumes[0].rect.end
	for v in volumes:
		lo = lo.min(v.rect.position)
		hi = hi.max(v.rect.end)
	var ox := floorf(lo.x / CELL) * CELL - 2.0 * CELL
	var oz := floorf(lo.y / CELL) * CELL - 2.0 * CELL
	var w := int(ceilf((hi.x - ox) / CELL)) + 2
	var h := int(ceilf((hi.y - oz) / CELL)) + 2
	var spans := _spans(volumes, ox, oz, w, h)
	# key -> [kit, owner, walk_owner, y0, y1, above_all, cells]
	var groups: Dictionary = {}
	for j in h:
		for i in w:
			var idx := j * w + i
			if spans[idx] != null:
				_open_cell(volumes, spans, i, j, w, h, groups)
			else:
				_wall_cell(volumes, spans, i, j, w, h, groups)
	var mark := PackedByteArray()
	mark.resize(w * h)
	for key: String in groups:
		var group: Array = groups[key]
		var cells: Array = group[6]
		cells.sort()
		for c: int in cells:
			mark[c] = 1
		for c: int in cells:
			if mark[c] != 1:
				continue
			var i := c % w
			var j := c / w
			var run := 1
			while i + run < w and mark[c + run] == 1:
				run += 1
			var rows := 1
			while j + rows < h:
				var row := (j + rows) * w + i
				var full := true
				for r in run:
					if mark[row + r] != 1:
						full = false
						break
				if not full:
					break
				rows += 1
			for rr in rows:
				for r in run:
					mark[(j + rr) * w + i + r] = 2
			var box := ShellBox.new()
			box.kit = group[0]
			box.owner = group[1]
			box.walk_owner = group[2]
			box.above_all = group[5]
			var y0: float = group[3]
			var y1: float = group[4]
			box.aabb = AABB(Vector3(ox + i * CELL, y0, oz + j * CELL), Vector3(run * CELL, y1 - y0, rows * CELL))
			result.append(box)
		for c: int in cells:
			mark[c] = 0
	return result


@warning_ignore("integer_division")
static func _faces(volumes: Array[Volume]) -> Array[WallFace]:
	var result: Array[WallFace] = []
	if volumes.is_empty():
		return result
	var lo := volumes[0].rect.position
	var hi := volumes[0].rect.end
	for v in volumes:
		lo = lo.min(v.rect.position)
		hi = hi.max(v.rect.end)
	var ox := floorf(lo.x / CELL) * CELL - 2.0 * CELL
	var oz := floorf(lo.y / CELL) * CELL - 2.0 * CELL
	var w := int(ceilf((hi.x - ox) / CELL)) + 2
	var h := int(ceilf((hi.y - oz) / CELL)) + 2
	var spans := _spans(volumes, ox, oz, w, h)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	# key -> [room, dir index, plane cell, y0, y1, cells along the edge]
	var groups: Dictionary = {}
	for v in volumes:
		if v.kind != Kind.ROOM:
			continue
		var i0 := int(roundf((v.rect.position.x - ox) / CELL))
		var i1 := int(roundf((v.rect.end.x - ox) / CELL))
		var j0 := int(roundf((v.rect.position.y - oz) / CELL))
		var j1 := int(roundf((v.rect.end.y - oz) / CELL))
		for j in range(j0, j1):
			for i in range(i0, i1):
				for d in dirs.size():
					var ni := i + dirs[d].x
					var nj := j + dirs[d].y
					if ni >= i0 and ni < i1 and nj >= j0 and nj < j1:
						continue   # inside the same part
					var open: Array = spans[nj * w + ni] if ni >= 0 and nj >= 0 and ni < w and nj < h and spans[nj * w + ni] != null else []
					for gap: Vector2 in _solid_gaps(Vector2(v.bottom, v.top), open):
						# the grid line between the room cell and its neighbour
						var plane := i + 1
						match d:
							1:
								plane = i
							2:
								plane = j + 1
							3:
								plane = j
						var key := "%s|%d|%d|%.3f|%.3f" % [v.owner, d, plane, gap.x, gap.y]
						if not groups.has(key):
							groups[key] = [v.owner, d, plane, gap.x, gap.y, []]
						((groups[key] as Array)[5] as Array).append(j if d < 2 else i)
	for key: String in groups:
		var group: Array = groups[key]
		var along: Array = group[5]
		along.sort()
		var start: int = along[0]
		var previous: int = start
		for k in range(1, along.size() + 1):
			var cell: int = along[k] if k < along.size() else -99999
			if cell == previous:
				continue   # the same cell from two overlapping parts
			if cell == previous + 1:
				previous = cell
				continue
			result.append(_face(group, start, previous, ox, oz))
			start = cell
			previous = cell
	return result


static func _face(group: Array, first: int, last: int, ox: float, oz: float) -> WallFace:
	var face := WallFace.new()
	face.room = group[0]
	var d: int = group[1]
	var plane: int = group[2]
	var y0: float = group[3]
	var y1: float = group[4]
	var length := (last - first + 1) * CELL
	match d:
		0, 1:
			face.normal = Vector3.LEFT if d == 0 else Vector3.RIGHT
			face.aabb = AABB(Vector3(ox + plane * CELL, y0, oz + first * CELL), Vector3(0.0, y1 - y0, length))
		_:
			face.normal = Vector3.FORWARD if d == 2 else Vector3.BACK
			face.aabb = AABB(Vector3(ox + first * CELL, y0, oz + plane * CELL), Vector3(length, y1 - y0, 0.0))
	return face


## Parts of [param span] (bottom, top) not covered by the [param open]
## spans of a neighbouring column: where the room looks at solid wall.
static func _solid_gaps(span: Vector2, open: Array) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	var y := span.x
	for entry: Array in open:
		var bottom := float(entry[0])
		var top := float(entry[1])
		if top <= y + EPS:
			continue
		if bottom > y + EPS:
			var upto := minf(bottom, span.y)
			if upto - y > EPS:
				gaps.append(Vector2(y, upto))
		y = maxf(y, top)
		if y >= span.y - EPS:
			return gaps
	if span.y - y > EPS:
		gaps.append(Vector2(y, span.y))
	return gaps


## Per grid cell: the merged empty spans, each [bottom, top, bottom volume,
## top volume] sorted upwards; null where nothing is empty.
static func _spans(volumes: Array[Volume], ox: float, oz: float, w: int, h: int) -> Array:
	var raw: Array = []
	raw.resize(w * h)
	for vi in volumes.size():
		var v := volumes[vi]
		var i0 := int(roundf((v.rect.position.x - ox) / CELL))
		var i1 := int(roundf((v.rect.end.x - ox) / CELL))
		var j0 := int(roundf((v.rect.position.y - oz) / CELL))
		var j1 := int(roundf((v.rect.end.y - oz) / CELL))
		for j in range(j0, j1):
			for i in range(i0, i1):
				var idx := j * w + i
				if raw[idx] == null:
					raw[idx] = [vi]
				else:
					(raw[idx] as Array).append(vi)
	var by_bottom := func(a: int, b: int) -> bool:
		if not is_equal_approx(volumes[a].bottom, volumes[b].bottom):
			return volumes[a].bottom < volumes[b].bottom
		return volumes[a].kind < volumes[b].kind if volumes[a].kind != volumes[b].kind else a < b
	var spans: Array = []
	spans.resize(w * h)
	for idx in w * h:
		if raw[idx] == null:
			continue
		var list: Array = raw[idx]
		if list.size() > 1:
			list.sort_custom(by_bottom)
		var merged: Array = []
		for vi: int in list:
			var v := volumes[vi]
			if not merged.is_empty() and v.bottom <= (merged[-1] as Array)[1] + EPS:
				var last: Array = merged[-1]
				var higher := v.top > float(last[1]) + EPS
				var same_but_room := absf(v.top - float(last[1])) <= EPS and v.kind == Kind.ROOM and volumes[last[3]].kind != Kind.ROOM
				if higher or same_but_room:
					last[1] = maxf(v.top, last[1])
					last[3] = vi
			else:
				merged.append([v.bottom, v.top, vi, vi])
		spans[idx] = merged
	return spans


static func _open_cell(volumes: Array[Volume], spans: Array, i: int, j: int, w: int, h: int, groups: Dictionary) -> void:
	var list: Array = spans[j * w + i]
	var first: Array = list[0]
	var ground := volumes[first[2]]
	_add(groups, &"floor" if ground.kind == Kind.ROOM else &"threshold", ground.owner, ground.owner, first[0] - FLOOR_T, first[0], false, j * w + i)
	for k in range(1, list.size()):
		var below: Array = list[k - 1]
		var above: Array = list[k]
		var upper := volumes[above[2]]
		_add(groups, &"slab", upper.owner, upper.owner, below[1], above[0], false, j * w + i)
	# a neighbour whose floor lies lower (a hatch high up in a hall's wall):
	# the wall goes on under this cell's floor, down to that floor
	var low := float(first[0])
	var low_owner: StringName = &""
	var low_rank := -1
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ni := i + di
			var nj := j + dj
			if ni < 0 or nj < 0 or ni >= w or nj >= h or spans[nj * w + ni] == null:
				continue
			var lowest: Array = (spans[nj * w + ni] as Array)[0]
			var rank := _rank(volumes[lowest[2]])
			if float(lowest[0]) < low - EPS or (low_owner != &"" and absf(float(lowest[0]) - low) <= EPS and rank > low_rank):
				low = lowest[0]
				low_owner = volumes[lowest[2]].owner
				low_rank = rank
	if low_owner != &"" and low < float(first[0]) - EPS:
		_add(groups, &"wall", low_owner, &"", low - FLOOR_T, first[0] - FLOOR_T, false, j * w + i)
	var last: Array = list[-1]
	var top_volume := volumes[last[3]]
	if top_volume.kind == Kind.SKY:
		return
	var roof: float = last[1] + ROOF_T
	var reach := roof
	var reach_owner := top_volume.owner
	var reach_rank := -1
	var owner_top := -INF
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ni := i + di
			var nj := j + dj
			if ni < 0 or nj < 0 or ni >= w or nj >= h or spans[nj * w + ni] == null:
				continue
			for span: Array in spans[nj * w + ni]:
				var top := float(span[1]) + ROOF_T
				if top <= roof + EPS:
					continue
				reach = maxf(reach, top)
				# the look: an ordinary room before a secret one, then the taller
				var rank := _rank(volumes[span[3]])
				if rank > reach_rank or (rank == reach_rank and top > owner_top):
					reach_owner = volumes[span[3]].owner
					reach_rank = rank
					owner_top = top
	_add(groups, &"ceiling" if top_volume.kind == Kind.ROOM else &"lintel", top_volume.owner, &"", last[1], roof, true, j * w + i)
	if reach > roof + EPS:
		_add(groups, &"wall", reach_owner, &"", roof, reach, true, j * w + i)


static func _wall_cell(volumes: Array[Volume], spans: Array, i: int, j: int, w: int, h: int, groups: Dictionary) -> void:
	var base := INF
	var top := -INF
	var owner: StringName = &""
	var owner_top := -INF
	var owner_rank := -1
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ni := i + di
			var nj := j + dj
			if ni < 0 or nj < 0 or ni >= w or nj >= h or spans[nj * w + ni] == null:
				continue
			for span: Array in spans[nj * w + ni]:
				base = minf(base, span[0])
				top = maxf(top, span[1])
				var v := volumes[span[3]]
				# ordinary rooms give walls their look before secret rooms, rooms
				# before passages; taller first
				var rank := _rank(v)
				if rank > owner_rank or (rank == owner_rank and float(span[1]) > owner_top):
					owner = v.owner
					owner_top = span[1]
					owner_rank = rank
	if base == INF:
		return
	_add(groups, &"wall", owner, &"", base - FLOOR_T, top + ROOF_T, false, j * w + i)


## Who gives a shared wall its look: an ordinary room (2) before a secret
## room (1) before a passage (0).
static func _rank(v: Volume) -> int:
	if v.kind == Kind.PASSAGE:
		return 0
	return 1 if v.hidden else 2


static func _add(groups: Dictionary, kit: StringName, owner: StringName, walk: StringName, y0: float, y1: float, above: bool, cell: int) -> void:
	if y1 - y0 <= EPS:
		return
	var key := "%s|%s|%s|%.3f|%.3f|%d" % [kit, owner, walk, y0, y1, int(above)]
	var group: Array = groups.get(key, [])
	if group.is_empty():
		group.append_array([kit, owner, walk, y0, y1, above, []])
		groups[key] = group
	(group[6] as Array).append(cell)
