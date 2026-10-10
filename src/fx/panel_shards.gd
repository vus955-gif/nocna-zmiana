class_name PanelShards
## Tears a flat panel (a mesh lying in one plane: a painting's canvas, a
## cabinet's pane) into jagged pieces for Fx.piece. MeshShards cuts along
## the triangles a mesh has, and a panel has only two: here a grid of
## [param cols] x [param rows] cells whose inner corners are jittered is
## laid over it, each cell a quad of its own with the panel's texture
## mapped on it as it was on the panel (and its faces turned the same way).
## Pieces follow MeshShards.Piece (centred on their own box, surface 0 from
## the panel's surface 0). Cached per mesh and grid.

static var _cache: Dictionary = {}


## The pieces of [param mesh] (its first surface) on a jittered grid.
static func cut(mesh: Mesh, cols: int, rows: int, jitter: float = 0.35) -> Array:
	var key := "%d:%dx%d" % [mesh.get_instance_id(), cols, rows]
	if _cache.has(key):
		return _cache[key]
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		uvs = arrays[Mesh.ARRAY_TEX_UV]
	var index := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		index = arrays[Mesh.ARRAY_INDEX]
	var box := mesh.get_aabb()
	# the panel's plane: its thinnest side is its normal
	var n_axis := box.get_shortest_axis_index()
	var a := (n_axis + 1) % 3
	var b := (n_axis + 2) % 3
	var depth := box.position[n_axis] + box.size[n_axis] * 0.5
	var facing := _facing(verts, index, n_axis)
	var normal := Vector3.ZERO
	normal[n_axis] = facing
	var uv_map := _uv_map(verts, uvs, a, b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var grid: Array = []
	for i in cols + 1:
		var column: Array = []
		for j in rows + 1:
			var s := float(i) / cols
			var t := float(j) / rows
			if i > 0 and i < cols:
				s += rng.randf_range(-jitter, jitter) / cols
			if j > 0 and j < rows:
				t += rng.randf_range(-jitter, jitter) / rows
			column.append(Vector2(box.position[a] + s * box.size[a], box.position[b] + t * box.size[b]))
		grid.append(column)
	var pieces: Array = []
	for i in cols:
		for j in rows:
			var corners: Array[Vector2] = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			pieces.append(_quad(corners, a, b, n_axis, depth, normal, uv_map))
	_cache[key] = pieces
	return pieces


## One cell as a piece: two triangles turned like the panel's faces.
static func _quad(corners: Array[Vector2], a: int, b: int, n_axis: int, depth: float, normal: Vector3, uv_map: Array) -> MeshShards.Piece:
	var points := PackedVector3Array()
	var bounds := AABB()
	for k in corners.size():
		var p := Vector3.ZERO
		p[a] = corners[k].x
		p[b] = corners[k].y
		p[n_axis] = depth
		points.append(p)
		bounds = AABB(p, Vector3.ZERO) if k == 0 else bounds.expand(p)
	var center := bounds.get_center()
	var out_verts := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_normals := PackedVector3Array()
	for p in points:
		out_verts.append(p - center)
		out_normals.append(normal)
		if not uv_map.is_empty():
			var u_coef: Vector3 = uv_map[0]
			var v_coef: Vector3 = uv_map[1]
			out_uvs.append(Vector2(u_coef.x * p[a] + u_coef.y * p[b] + u_coef.z, v_coef.x * p[a] + v_coef.y * p[b] + v_coef.z))
	# corners run counter-clockwise in (a, b); keep the panel's winding
	var turned := (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0
	var tris := PackedInt32Array([0, 2, 1, 0, 3, 2]) if turned else PackedInt32Array([0, 1, 2, 0, 2, 3])
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = out_verts
	surface[Mesh.ARRAY_NORMAL] = out_normals
	if not out_uvs.is_empty():
		surface[Mesh.ARRAY_TEX_UV] = out_uvs
	surface[Mesh.ARRAY_INDEX] = tris
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	var piece := MeshShards.Piece.new()
	piece.mesh = built
	piece.center = center
	piece.size = bounds.size
	piece.surfaces = PackedInt32Array([0])
	piece.triangles = 2
	return piece


## +1 when the panel's first triangle, wound as drawn (Godot: clockwise
## seen from the front), faces along +[param n_axis], else -1.
static func _facing(verts: PackedVector3Array, index: PackedInt32Array, n_axis: int) -> float:
	if verts.size() < 3:
		return 1.0
	var i0 := index[0] if index.size() >= 3 else 0
	var i1 := index[1] if index.size() >= 3 else 1
	var i2 := index[2] if index.size() >= 3 else 2
	var cross := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
	# clockwise front faces: the front normal is the negative cross product
	return 1.0 if -cross[n_axis] >= 0.0 else -1.0


## The texture mapping as two affine functions of the in-plane coordinates
## ([u, v] coefficients (x, y, constant)), solved from three corners; empty
## without UVs.
static func _uv_map(verts: PackedVector3Array, uvs: PackedVector2Array, a: int, b: int) -> Array:
	if uvs.size() < verts.size() or verts.size() < 3:
		return []
	# three corners that span the plane
	for k in range(2, verts.size()):
		var p0 := Vector2(verts[0][a], verts[0][b])
		var p1 := Vector2(verts[1][a], verts[1][b])
		var p2 := Vector2(verts[k][a], verts[k][b])
		var det := (p1 - p0).cross(p2 - p0)
		if absf(det) < 1e-8:
			continue
		var m := Transform2D(p1 - p0, p2 - p0, p0).affine_inverse()
		var coefs: Array = []
		for channel in 2:
			var f0: float = uvs[0][channel]
			var f1: float = uvs[1][channel]
			var f2: float = uvs[k][channel]
			# f(p) = f0 + (f1 - f0) * s + (f2 - f0) * t, (s, t) = m * p
			var col_x := m.x
			var col_y := m.y
			var origin := m.origin
			var cx := (f1 - f0) * col_x.x + (f2 - f0) * col_x.y
			var cy := (f1 - f0) * col_y.x + (f2 - f0) * col_y.y
			var c0 := f0 + (f1 - f0) * origin.x + (f2 - f0) * origin.y
			coefs.append(Vector3(cx, cy, c0))
		return coefs
	return []
