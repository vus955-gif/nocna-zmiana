extends TestCase
## The carved lobby shell is watertight: every empty cell is walled in on
## all sides (by solid or by more empty space), closed below and above
## (skylight wells excepted), nothing solid overlaps empty space, and no
## public room shows a secret room's colour on its walls.

const CELL := ShellCarver.CELL
const EPS := 0.002

var _volumes: Array[ShellCarver.Volume] = []
var _boxes: Array[ShellCarver.ShellBox] = []
var _lo := Vector2.ZERO
var _nx: int = 0
var _nz: int = 0
## Per cell: merged open spans, merged solid spans, raw [bottom, top, kind, owner].
var _open: Array = []
var _solid: Array = []
var _raw: Array = []


func before_each() -> void:
	var layout := LobbyLayout.create()
	_volumes = LevelBuilder.new(layout, null, null, null).shell_volumes()
	_boxes = ShellCarver.carve(_volumes)
	_rasterize()


func _rasterize() -> void:
	var lo := _volumes[0].rect.position
	var hi := _volumes[0].rect.end
	for v in _volumes:
		lo = lo.min(v.rect.position)
		hi = hi.max(v.rect.end)
	_lo = lo - Vector2(2, 2)
	hi += Vector2(2, 2)
	_nx = int(roundf((hi.x - _lo.x) / CELL))
	_nz = int(roundf((hi.y - _lo.y) / CELL))
	_open.resize(_nx * _nz)
	_solid.resize(_nx * _nz)
	_raw.resize(_nx * _nz)
	for idx in _nx * _nz:
		_open[idx] = []
		_solid[idx] = []
		_raw[idx] = []
	for v in _volumes:
		for idx in _cells(v.rect.position.x, v.rect.end.x, v.rect.position.y, v.rect.end.y):
			(_open[idx] as Array).append(Vector2(v.bottom, v.top))
			(_raw[idx] as Array).append([v.bottom, v.top, v.kind, v.owner])
	for b in _boxes:
		for idx in _cells(b.aabb.position.x, b.aabb.end.x, b.aabb.position.z, b.aabb.end.z):
			(_solid[idx] as Array).append(Vector2(b.aabb.position.y, b.aabb.end.y))
	for idx in _nx * _nz:
		_open[idx] = _merge(_open[idx])
		_solid[idx] = _merge(_solid[idx])


func _cells(x0: float, x1: float, z0: float, z1: float) -> Array[int]:
	var found: Array[int] = []
	var i0 := int(roundf((x0 - _lo.x) / CELL))
	var i1 := int(roundf((x1 - _lo.x) / CELL))
	var j0 := int(roundf((z0 - _lo.y) / CELL))
	var j1 := int(roundf((z1 - _lo.y) / CELL))
	for j in range(j0, j1):
		for i in range(i0, i1):
			found.append(j * _nx + i)
	return found


func _where(idx: int) -> String:
	@warning_ignore("integer_division")
	var j := idx / _nx
	var i := idx % _nx
	return "(x %.2f, z %.2f)" % [_lo.x + (i + 0.5) * CELL, _lo.y + (j + 0.5) * CELL]


func test_nothing_solid_fills_empty_space() -> void:
	var overlaps: PackedStringArray = []
	for idx in _nx * _nz:
		for o: Vector2 in _open[idx]:
			for s: Vector2 in _solid[idx]:
				if minf(o.y, s.y) - maxf(o.x, s.x) > EPS:
					overlaps.append("%s open %s solid %s" % [_where(idx), o, s])
	assert_eq(overlaps.size(), 0, " / ".join(overlaps.slice(0, 5)))


func test_every_empty_cell_is_walled_in_on_all_sides() -> void:
	var leaks: PackedStringArray = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for j in range(1, _nz - 1):
		for i in range(1, _nx - 1):
			var idx := j * _nx + i
			if (_open[idx] as Array).is_empty():
				continue
			for d in dirs:
				var next := (j + d.y) * _nx + i + d.x
				var cover := _merge((_open[next] as Array) + (_solid[next] as Array))
				for o: Vector2 in _open[idx]:
					for gap in _subtract(o, cover):
						leaks.append("%s towards %s at y %.2f..%.2f" % [_where(idx), d, gap.x, gap.y])
	assert_eq(leaks.size(), 0, " / ".join(leaks.slice(0, 6)))


func test_every_empty_cell_has_a_floor_and_a_roof() -> void:
	var leaks: PackedStringArray = []
	for idx in _nx * _nz:
		for o: Vector2 in _open[idx]:
			var sky := false
			for entry: Array in _raw[idx]:
				if entry[2] == ShellCarver.Kind.SKY and absf(float(entry[1]) - o.y) < EPS:
					sky = true
			if not _covered(_solid[idx], o.x - 0.01):
				leaks.append("%s no floor under %.2f" % [_where(idx), o.x])
			if not sky and not _covered(_solid[idx], o.y + 0.01):
				leaks.append("%s no roof over %.2f" % [_where(idx), o.y])
	assert_eq(leaks.size(), 0, " / ".join(leaks.slice(0, 6)))


func test_public_rooms_never_wear_a_secret_rooms_colour() -> void:
	var layout := LobbyLayout.create()
	var secret := {}
	for room in layout.rooms:
		if room.secret:
			secret[room.id] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var giveaways := {}
	for b in _boxes:
		if b.kit != &"wall" or not secret.has(b.owner):
			continue
		for idx in _cells(b.aabb.position.x, b.aabb.end.x, b.aabb.position.z, b.aabb.end.z):
			for d in dirs:
				var next := idx + d.y * _nx + d.x
				if next < 0 or next >= _nx * _nz:
					continue
				for entry: Array in _raw[next]:
					if entry[2] != ShellCarver.Kind.ROOM or secret.has(entry[3]):
						continue
					var seen := minf(float(entry[1]), b.aabb.end.y) - maxf(float(entry[0]), b.aabb.position.y)
					if seen > EPS:
						giveaways["%s shows %s" % [entry[3], b.owner]] = true
	assert_eq(giveaways.size(), 0, str(giveaways.keys()))


func test_wall_faces_are_listed_for_every_carved_room() -> void:
	var faces := ShellCarver.wall_faces(_volumes)
	var rooms := {}
	for face in faces:
		rooms[face.room] = true
		assert_true(face.normal.length() > 0.99)
		assert_gt(face.aabb.size.y, 0.0)
	for room in LobbyLayout.create().rooms:
		if room.carved:
			assert_true(rooms.has(room.id), "faces of %s" % room.id)


static func _merge(list: Array) -> Array:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = []
	for s: Vector2 in sorted:
		if not out.is_empty() and s.x <= (out[-1] as Vector2).y + EPS:
			out[-1] = Vector2((out[-1] as Vector2).x, maxf((out[-1] as Vector2).y, s.y))
		else:
			out.append(s)
	return out


static func _subtract(span: Vector2, cover: Array) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	var y := span.x
	for c: Vector2 in cover:
		if c.y <= y + EPS:
			continue
		if c.x > y + EPS:
			var top := minf(c.x, span.y)
			if top - y > EPS:
				gaps.append(Vector2(y, top))
		y = maxf(y, c.y)
		if y >= span.y - EPS:
			break
	if span.y - y > EPS:
		gaps.append(Vector2(y, span.y))
	return gaps


static func _covered(list: Array, y: float) -> bool:
	for s: Vector2 in list:
		if y >= s.x - EPS and y <= s.y + EPS:
			return true
	return false
