class_name MeshShards
## Cuts a model's mesh into pieces of debris: its connected islands (the
## bones of a skeleton fall apart bone by bone) or slices of about equal
## size (a wax figure torn to chunks by a shotgun). Every piece is centred
## on the middle of its own box, so a rigid body carrying it spins around
## it. Results are cached per mesh (model meshes are shared resources); a
## whole part costs nothing (it reuses the model's own mesh).


## One piece: [member mesh] drawn at [member offset] from the piece's
## origin, which sits at [member center] in the source mesh's space; mesh
## surface k came from source surface [member surfaces][k].
class Piece:
	var mesh: Mesh
	var surfaces: PackedInt32Array = PackedInt32Array()
	var center := Vector3.ZERO
	var offset := Vector3.ZERO
	var size := Vector3.ZERO
	var triangles: int = 0


## The arrays of every surface of a mesh, read once.
class Source:
	var arrays: Array = []
	var counts: PackedInt32Array = PackedInt32Array()

	func _init(mesh: Mesh) -> void:
		for s in mesh.get_surface_count():
			var surface := mesh.surface_get_arrays(s)
			arrays.append(surface)
			var index: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
			counts.append(index.size() / 3 if index.size() > 0 else (surface[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)

	## Vertex numbers of the corners of triangle [param t] of surface [param s].
	func corner(s: int, c: int) -> int:
		var index: PackedInt32Array = arrays[s][Mesh.ARRAY_INDEX]
		return index[c] if index.size() > 0 else c

	func centroid(s: int, t: int) -> Vector3:
		var verts: PackedVector3Array = arrays[s][Mesh.ARRAY_VERTEX]
		return (verts[corner(s, t * 3)] + verts[corner(s, t * 3 + 1)] + verts[corner(s, t * 3 + 2)]) / 3.0


## Vertices closer than this (m) count as one when finding islands (UV
## seams split vertices that belong together).
const WELD := 0.0005

static var _cache: Dictionary = {}
## Cuts to prepare ahead of need: [mesh, kind ("slices"/"islands"), param].
static var _queue: Array = []
## Cache keys of the queued cuts (twenty wolves queue each cut once).
static var _queued: Dictionary = {}


## The whole mesh as one piece (the mesh itself, drawn off-centre).
static func whole(mesh: Mesh) -> Piece:
	var key := "%d:whole" % mesh.get_instance_id()
	if not _cache.has(key):
		var piece := Piece.new()
		piece.mesh = mesh
		var box := mesh.get_aabb()
		piece.center = box.get_center()
		piece.offset = -piece.center
		piece.size = box.size
		for s in mesh.get_surface_count():
			piece.surfaces.append(s)
			piece.triangles += mesh.surface_get_array_index_len(s) / 3 if mesh.surface_get_array_index_len(s) > 0 else mesh.surface_get_array_len(s) / 3
		_cache[key] = piece
	return _cache[key]


## The connected islands of [param mesh]; islands of fewer than
## [param min_triangles] triangles join the nearest bigger one (teeth stay
## in the jaw, rivets on their plate).
static func islands(mesh: Mesh, min_triangles: int = 40) -> Array:
	return _cached(mesh, "islands%d" % min_triangles, func(source: Source) -> Array: return _islands(source, min_triangles))


## [param count] slices of about equal triangle count: the triangles are
## split in halves across the longest side of their spread, again and again.
static func slices(mesh: Mesh, count: int) -> Array:
	if count <= 1:
		return [whole(mesh)]
	return _cached(mesh, "slices%d" % count, func(source: Source) -> Array: return _slices(source, count))


## Cuts [param mesh] in two by its triangles: those whose centroid (a
## Vector3 in the mesh's space) passes [param inside], and the rest. Both
## pieces keep the mesh's own space (centre at the origin: draw them where
## the mesh was drawn); [rest, cut], a side without triangles is null.
## Cached per mesh and [param key].
static func split(mesh: Mesh, inside: Callable, key: String) -> Array:
	return partition(mesh, func(centroid: Vector3) -> int: return 1 if inside.call(centroid) else 0, 2, key)


## Cuts [param mesh] into [param count] pieces by its triangles:
## [param classify] gives each triangle's centroid (in the mesh's space) its
## piece, 0 .. count - 1 (out of range: piece 0). The pieces keep the mesh's
## own space; a piece without triangles is null. Baked sub-parts get axes
## of their own this way (the orrery's hanging moons swing on their rods).
## Cached per mesh and [param key].
static func partition(mesh: Mesh, classify: Callable, count: int, key: String) -> Array:
	var cache_key := "%d:part:%s" % [mesh.get_instance_id(), key]
	if not _cache.has(cache_key):
		var source := Source.new(mesh)
		var groups: Array[Dictionary] = []
		for i in count:
			groups.append({})
		for s in source.counts.size():
			for t in source.counts[s]:
				var index := int(classify.call(source.centroid(s, t)))
				var group := groups[index if index >= 0 and index < count else 0]
				var tris: PackedInt32Array = group.get(s, PackedInt32Array())
				tris.append(t)
				group[s] = tris
		var pieces: Array = []
		for group in groups:
			pieces.append(_build(source, group, false))
		_cache[cache_key] = pieces
	return _cache[cache_key]


## Prepares [method slices] of [param mesh] in the background (see
## [method tick]), so the first exhibit torn apart costs no hitch.
static func warm_slices(mesh: Mesh, count: int) -> void:
	if count > 1:
		_enqueue(mesh, "slices", count)


## Prepares [method islands] of [param mesh] in the background.
static func warm_islands(mesh: Mesh, min_triangles: int) -> void:
	_enqueue(mesh, "islands", min_triangles)


static func _enqueue(mesh: Mesh, kind: String, param: int) -> void:
	var key := "%d:%s%d" % [mesh.get_instance_id(), kind, param]
	if _cache.has(key) or _queued.has(key):
		return
	_queued[key] = true
	_queue.append([mesh, kind, param])


## Works through the prepared cuts for about [param budget_usec]
## microseconds (at least one cut when any is waiting). Fx calls it every
## frame.
static func tick(budget_usec: int) -> void:
	var start := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - start < budget_usec:
		var job: Array = _queue.pop_front()
		_queued.erase("%d:%s%d" % [(job[0] as Mesh).get_instance_id(), job[1], job[2]])
		if job[1] == "slices":
			slices(job[0], job[2])
		else:
			islands(job[0], job[2])


## Cuts still waiting to be prepared.
static func pending() -> int:
	return _queue.size()


## Prepares every waiting cut now (the night start, under the black fade:
## Fx.warm_up). Returns how many were made.
static func drain() -> int:
	var count := _queue.size()
	while not _queue.is_empty():
		tick(1 << 30)
	return count


## One piece of a cut of [param mesh] made already (slices or islands:
## its own vertex layout, not the model's), or null (the shader warm-up
## draws debris materials on it).
static func cut_piece(mesh: Mesh) -> Piece:
	var prefix := "%d:" % mesh.get_instance_id()
	for key: String in _cache:
		if key.begins_with(prefix) and not key.ends_with(":whole"):
			for piece: Piece in _cache[key]:
				if piece != null:
					return piece
	return null


## True when the [method slices] of [param mesh] into [param count] are
## ready (a cut of 1 is the whole mesh: always ready).
static func has_slices(mesh: Mesh, count: int) -> bool:
	return count <= 1 or _cache.has("%d:slices%d" % [mesh.get_instance_id(), count])


## Every piece's material for surface k: [param materials] indexed by source
## surface.
static func materials_for(piece: Piece, materials: Array) -> Array[Material]:
	var out: Array[Material] = []
	for source in piece.surfaces:
		out.append(materials[source] if source < materials.size() else null)
	return out


static func _cached(mesh: Mesh, kind: String, make: Callable) -> Array:
	var key := "%d:%s" % [mesh.get_instance_id(), kind]
	if not _cache.has(key):
		var source := Source.new(mesh)
		var groups: Array = make.call(source)
		var pieces: Array = []
		for group: Dictionary in groups:
			var piece := _build(source, group)
			if piece != null:
				pieces.append(piece)
		_cache[key] = pieces
	return _cache[key]


static func _islands(source: Source, min_triangles: int) -> Array:
	var parent := PackedInt32Array()
	var keys := {}
	# per surface: welded vertex id of every corner
	var corners: Array[PackedInt32Array] = []
	for s in source.arrays.size():
		var verts: PackedVector3Array = source.arrays[s][Mesh.ARRAY_VERTEX]
		var ids := PackedInt32Array()
		ids.resize(verts.size())
		for i in verts.size():
			var key := Vector3i((verts[i] / WELD).round())
			var id: int = keys.get(key, -1)
			if id < 0:
				id = parent.size()
				keys[key] = id
				parent.append(id)
			ids[i] = id
		var count := source.counts[s]
		var tri_ids := PackedInt32Array()
		tri_ids.resize(count * 3)
		for c in count * 3:
			tri_ids[c] = ids[source.corner(s, c)]
		for t in count:
			_union(parent, tri_ids[t * 3], tri_ids[t * 3 + 1])
			_union(parent, tri_ids[t * 3], tri_ids[t * 3 + 2])
		corners.append(tri_ids)
	# island root -> {surfaces: {surface -> triangles}, count, sum of centroids}
	var groups := {}
	for s in corners.size():
		var tri_ids: PackedInt32Array = corners[s]
		for t in tri_ids.size() / 3:
			var root := _find(parent, tri_ids[t * 3])
			var island: Dictionary = groups.get(root, {})
			if island.is_empty():
				island = {"surfaces": {}, "count": 0, "sum": Vector3.ZERO}
				groups[root] = island
			var tris: PackedInt32Array = island["surfaces"].get(s, PackedInt32Array())
			tris.append(t)
			island["surfaces"][s] = tris
			island["count"] += 1
			island["sum"] += source.centroid(s, t)
	var big: Array = []
	var small: Array = []
	for island: Dictionary in groups.values():
		island["center"] = island["sum"] / float(island["count"])
		if island["count"] >= min_triangles:
			big.append(island)
		else:
			small.append(island)
	if big.is_empty():
		return [_all(source)]
	for island: Dictionary in small:
		var nearest: Dictionary = big[0]
		var best := INF
		for other: Dictionary in big:
			var d := (other["center"] as Vector3).distance_squared_to(island["center"])
			if d < best:
				best = d
				nearest = other
		for s: int in island["surfaces"]:
			var tris: PackedInt32Array = nearest["surfaces"].get(s, PackedInt32Array())
			tris.append_array(island["surfaces"][s])
			nearest["surfaces"][s] = tris
	var out: Array = []
	for island: Dictionary in big:
		out.append(island["surfaces"])
	return out


static func _all(source: Source) -> Dictionary:
	var group := {}
	for s in source.counts.size():
		var tris := PackedInt32Array()
		tris.resize(source.counts[s])
		for t in source.counts[s]:
			tris[t] = t
		group[s] = tris
	return group


static func _slices(source: Source, count: int) -> Array:
	# every triangle: its surface, number and centroid
	var surfaces := PackedInt32Array()
	var numbers := PackedInt32Array()
	var centroids := PackedVector3Array()
	for s in source.counts.size():
		for t in source.counts[s]:
			surfaces.append(s)
			numbers.append(t)
			centroids.append(source.centroid(s, t))
	var buckets: Array[PackedInt32Array] = []
	var all := PackedInt32Array()
	all.resize(centroids.size())
	for i in centroids.size():
		all[i] = i
	buckets.append(all)
	while buckets.size() < count:
		# halve the biggest bucket across the longest side of its spread,
		# at the median (native sort of the coordinates)
		var biggest := 0
		for i in buckets.size():
			if buckets[i].size() > buckets[biggest].size():
				biggest = i
		var bucket := buckets[biggest]
		if bucket.size() < 2:
			break
		var box := AABB(centroids[bucket[0]], Vector3.ZERO)
		for i in bucket:
			box = box.expand(centroids[i])
		var axis := box.get_longest_axis_index()
		var values := PackedFloat32Array()
		values.resize(bucket.size())
		for k in bucket.size():
			values[k] = centroids[bucket[k]][axis]
		var sorted := values.duplicate()
		sorted.sort()
		var median := sorted[sorted.size() / 2]
		var low := PackedInt32Array()
		var high := PackedInt32Array()
		for k in bucket.size():
			if values[k] < median:
				low.append(bucket[k])
			else:
				high.append(bucket[k])
		if low.is_empty() or high.is_empty():
			break
		buckets[biggest] = low
		buckets.append(high)
	var out: Array = []
	for bucket in buckets:
		var group := {}
		for i in bucket:
			var tris: PackedInt32Array = group.get(surfaces[i], PackedInt32Array())
			tris.append(numbers[i])
			group[surfaces[i]] = tris
		out.append(group)
	return out


## Builds the piece of the source mesh made of [param group]'s triangles
## (surface -> triangle numbers), centred on its own box ([param centred]
## false: left where it was in the source's space).
static func _build(source: Source, group: Dictionary, centred: bool = true) -> Piece:
	var piece := Piece.new()
	var built := ArrayMesh.new()
	var bounds := AABB()
	var first := true
	var ids: Array = group.keys()
	ids.sort()
	var outputs: Array = []
	for s: int in ids:
		var tris: PackedInt32Array = group[s]
		if tris.is_empty():
			continue
		var verts: PackedVector3Array = source.arrays[s][Mesh.ARRAY_VERTEX]
		var remap := PackedInt32Array()
		remap.resize(verts.size())
		remap.fill(-1)
		var order := PackedInt32Array()
		var index := PackedInt32Array()
		index.resize(tris.size() * 3)
		var n := 0
		for t in tris:
			for k in 3:
				var vertex := source.corner(s, t * 3 + k)
				var mapped := remap[vertex]
				if mapped < 0:
					mapped = order.size()
					remap[vertex] = mapped
					order.append(vertex)
					bounds = AABB(verts[vertex], Vector3.ZERO) if first else bounds.expand(verts[vertex])
					first = false
				index[n] = mapped
				n += 1
		outputs.append([s, order, index])
		piece.triangles += tris.size()
	if outputs.is_empty():
		return null
	piece.center = bounds.get_center() if centred else Vector3.ZERO
	piece.size = bounds.size
	for entry: Array in outputs:
		var arrays: Array = source.arrays[entry[0]]
		var order: PackedInt32Array = entry[1]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var new_verts := PackedVector3Array()
		new_verts.resize(order.size())
		for i in order.size():
			new_verts[i] = verts[order[i]] - piece.center
		out[Mesh.ARRAY_VERTEX] = new_verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var new_normals := PackedVector3Array()
			new_normals.resize(order.size())
			for i in order.size():
				new_normals[i] = normals[order[i]]
			out[Mesh.ARRAY_NORMAL] = new_normals
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var new_tangents := PackedFloat32Array()
			new_tangents.resize(order.size() * 4)
			for i in order.size():
				for k in 4:
					new_tangents[i * 4 + k] = tangents[order[i] * 4 + k]
			out[Mesh.ARRAY_TANGENT] = new_tangents
		for channel in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			if arrays[channel] != null:
				var uvs: PackedVector2Array = arrays[channel]
				var new_uvs := PackedVector2Array()
				new_uvs.resize(order.size())
				for i in order.size():
					new_uvs[i] = uvs[order[i]]
				out[channel] = new_uvs
		if arrays[Mesh.ARRAY_COLOR] != null:
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var new_colors := PackedColorArray()
			new_colors.resize(order.size())
			for i in order.size():
				new_colors[i] = colors[order[i]]
			out[Mesh.ARRAY_COLOR] = new_colors
		out[Mesh.ARRAY_INDEX] = entry[2]
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		piece.surfaces.append(entry[0])
	piece.mesh = built
	return piece


static func _find(parent: PackedInt32Array, x: int) -> int:
	var root := x
	while parent[root] != root:
		root = parent[root]
	while parent[x] != root:
		var next := parent[x]
		parent[x] = root
		x = next
	return root


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
