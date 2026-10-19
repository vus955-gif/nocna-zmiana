class_name CollisionFit
extends RefCounted
## A piece's collision drawn from its look (QA #49, finding Q7 of
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): the
## art fits a kit model into the greybox box, but a model is seldom a box -
## a tipi is a cone, a steam engine a narrow bed in a wide box, a desk wider
## than its box - so the guard met solid air (an invisible corner) or walked
## into what is drawn. Here the box gives way to a stack of prisms, each the
## convex outline (floor plan) of everything the look draws within one band
## of height: BASE (the foot: a plinth's step, a column's base), then every
## BAND m up to the piece's top; bands alike are merged, so a column's shaft
## is one prism. Collision stays convex (cheap, smooth to slide along) and
## follows the drawing within the band's taper. What a piece's look holds
## in a batch (a MultiMesh: shelf units, cabinets) counts at its instances'
## places. Results are kept per look (pieces drawn alike share them).

## The foot band (m): what is drawn lower stops nobody but is still solid.
const BASE := 0.2
const BAND := 0.25
## Over this height (m: out of the guard's reach, only shots meet it) the
## bands are COARSE_BAND m.
const FINE_TO := 2.2
const COARSE_BAND := 1.0
## Consecutive bands merge when their outlines differ by at most this much
## on any side (m) and the merged one is at most MERGE_AREA times larger.
const MERGE_SLACK := 0.06
const MERGE_AREA := 1.12
## A band whose outline is smaller than this (m2) is left out (a lamp stem).
const MIN_AREA := 0.0004
## Batches (MultiMeshInstance3D) keep their instances' places in this meta
## (BasementArt.INSTANCES_META) - a headless run keeps none in the renderer.
const INSTANCES_META := &"instance_transforms"

## Look key -> Array of its prisms (ConvexPolygonShape3D, piece frame):
## looks drawn by meshes that last (a model's, a primitive's by its
## measures) are kept for good, the rest (a mesh made for one build: the
## kayak's hull) only for the build (_build_fitted, cleared each one).
static var _fitted: Dictionary = {}
static var _build_fitted: Dictionary = {}
## Mesh key (_mesh_key) -> PackedVector3Array of its triangles (mesh
## space); one build's meshes apart, likewise.
static var _meshes: Dictionary = {}
static var _build_meshes: Dictionary = {}
## Microseconds spent drawing collisions so far (the level build's cost).
static var spent_usec: int = 0


## Replaces [param piece]'s colliders by the prisms of what its [param look]
## (its "Visual", in the piece's frame) draws from the floor up to
## [param height] (m over the piece's base); [param columns] > 1 cuts the
## drawing along the piece's x into that many columns first, each its own
## stack (an arc - the card catalogue round the astrolabe - is no convex
## shape). False (colliders kept) when the look draws nothing to fit.
static func fit(piece: StaticBody3D, look: Node3D, height: float, columns: int = 1) -> bool:
	return fit_framed(piece, look, _relative(piece, look), height, columns)


## fit() for a [param look] standing beside [param piece] (not under it),
## [param frame] being its frame in the piece's (the gatling's display: its
## model and its plinth's body are siblings).
static func fit_framed(piece: StaticBody3D, look: Node3D, frame: Transform3D, height: float, columns: int = 1) -> bool:
	var parts: Array = []
	_collect(look, frame, parts)
	return fit_parts(piece, parts, height, columns)


## fit() from [param parts] ([[Mesh, its frame in the piece's], ...]: what
## draws the piece, wherever it hangs - a hero piece standing in a greybox
## box), cut to [param clip] (the piece's floor plan, its own frame) when it
## has an area.
static func fit_parts(piece: StaticBody3D, parts: Array, height: float, columns: int = 1, clip := Rect2()) -> bool:
	if parts.is_empty():
		return false
	var key := _key(parts, height, columns, clip)
	var kept := _kept(key)
	if not kept.has(key):
		var started := Time.get_ticks_usec()
		kept[key] = _shapes(outlines(_triangles(parts), height, columns, clip))
		spent_usec += Time.get_ticks_usec() - started
	return _apply(piece, kept[key])


## fit() kept for fit_queued() (a level's pieces: drawn all at once, on
## the worker threads). False when [param look] draws nothing.
static func queue(piece: StaticBody3D, look: Node3D, height: float, columns: int = 1) -> bool:
	var parts: Array = []
	_collect(look, _relative(piece, look), parts)
	return queue_parts(piece, parts, height, columns)


## fit_parts() kept for fit_queued().
static func queue_parts(piece: StaticBody3D, parts: Array, height: float, columns: int = 1, clip := Rect2()) -> bool:
	if parts.is_empty():
		return false
	_queue.append([piece, parts, height, columns, clip])
	return true


## Fits every queued piece: the outlines of the looks not drawn before are
## worked out on WorkerThreadPool's threads (pure arithmetic over each
## look's triangles, gathered here first), the shapes made and set here.
static func fit_queued() -> void:
	if _queue.is_empty():
		return
	var started := Time.get_ticks_usec()
	# (what one build made is no use to the next)
	_build_fitted.clear()
	_build_meshes.clear()
	var jobs := {}   # key -> [triangles, height, columns, clip]
	var keyed: Array = []
	for entry: Array in _queue:
		var key := _key(entry[1], entry[2], entry[3], entry[4])
		keyed.append([entry[0], key])
		if not _kept(key).has(key) and not jobs.has(key):
			jobs[key] = [_triangles(entry[1]), entry[2], entry[3], entry[4]]
	_queue.clear()
	var keys := jobs.keys()
	var results: Array = []
	results.resize(keys.size())
	if not keys.is_empty():
		var work := func(i: int) -> void:
			var job: Array = jobs[keys[i]]
			results[i] = CollisionFit.outlines(job[0], job[1], job[2], job[3])
		var task := WorkerThreadPool.add_group_task(work, keys.size(), -1, true, "CollisionFit")
		WorkerThreadPool.wait_for_group_task_completion(task)
	for i in keys.size():
		_kept(keys[i])[keys[i]] = _shapes(results[i])
	for entry: Array in keyed:
		if is_instance_valid(entry[0]):
			_apply(entry[0], _kept(entry[1])[entry[1]])
	spent_usec += Time.get_ticks_usec() - started


## Fits waiting for fit_queued(): [[piece, parts, height, columns, clip], ...].
static var _queue: Array = []


static func _key(parts: Array, height: float, columns: int, clip: Rect2) -> String:
	return "%.2f|%d|%s|%s" % [height, columns, clip, "|".join(parts.map(func(part: Array) -> String: return "%s@%s" % [_mesh_key(part[0]), _rounded(part[1])]))]


## Where the look of [param key] is kept (for good, or for this build).
static func _kept(key: String) -> Dictionary:
	return _build_fitted if key.contains(ONE_BUILD) else _fitted


## A mesh's key: its resource path (a model's), a primitive's class and
## measures, else (a mesh made for one build) its instance, marked ONE_BUILD.
static func _mesh_key(mesh: Mesh) -> String:
	if mesh.resource_path != "":
		return mesh.resource_path
	if mesh is PrimitiveMesh:
		var measures := PackedStringArray([mesh.get_class()])
		for property in mesh.get_property_list():
			var name: String = property["name"]
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE and not name.begins_with("resource_") and name != "material" and name != "script":
				measures.append("%s=%s" % [name, mesh.get(name)])
		return ":".join(measures)
	return "%s%d" % [ONE_BUILD, mesh.get_instance_id()]


const ONE_BUILD := "#build#"


## Every triangle of [param parts] in the piece's frame.
static func _triangles(parts: Array) -> PackedVector3Array:
	var triangles := PackedVector3Array()
	for part: Array in parts:
		var place: Transform3D = part[1]
		for p in _mesh_triangles(part[0]):
			triangles.append(place * p)
	return triangles


## [param piece]'s colliders swapped for [param shapes] (none: kept).
static func _apply(piece: StaticBody3D, shapes: Array) -> bool:
	if shapes.is_empty():
		return false
	for child in piece.get_children():
		if child is CollisionShape3D:
			piece.remove_child(child)
			child.free()
	for prism: Shape3D in shapes:
		var holder := CollisionShape3D.new()
		holder.shape = prism
		piece.add_child(holder)
	piece.set_meta(&"kit_fitted", true)
	return true


## Takes every collider off [param piece] (a fitted piece whose look draws
## nothing: the cloakroom's coat rack, its coats hang on the counter's rails).
static func clear(piece: StaticBody3D) -> void:
	for child in piece.get_children():
		if child is CollisionShape3D:
			piece.remove_child(child)
			child.free()
	piece.set_meta(&"kit_fitted", true)


## The prisms (ConvexPolygonShape3D in the frame of [param triangles]) of
## [param triangles] (three points each) between 0 and [param height], in
## [param columns] columns along x.
static func prisms(triangles: PackedVector3Array, height: float, columns: int = 1, clip := Rect2()) -> Array:
	return _shapes(outlines(triangles, height, columns, clip))


## prisms() as outlines: [[bottom, top, hull (PackedVector2Array, floor
## plan)], ...] - plain arithmetic, safe on a worker thread.
static func outlines(triangles: PackedVector3Array, height: float, columns: int = 1, clip := Rect2()) -> Array:
	var edges := PackedFloat32Array([0.0])
	var y := BASE
	while y < height - 0.05:
		edges.append(y)
		y += BAND if y < FINE_TO else COARSE_BAND
	edges.append(height)
	var count := edges.size() - 1
	# the columns' bounds along x (one column: no cut)
	var cuts := PackedFloat32Array()
	if columns > 1:
		var low := INF
		var high := -INF
		for p in triangles:
			if p.y >= 0.0 and p.y <= height:
				low = minf(low, p.x)
				high = maxf(high, p.x)
		if low < high:
			for k in columns + 1:
				cuts.append(lerpf(low, high, float(k) / columns))
	var stacks := maxi(cuts.size() - 1, 1)
	var bands: Array = []   # [column][band] -> Array of Vector2 (in place)
	for c in stacks:
		var column: Array = []
		for k in count:
			column.append([])
		bands.append(column)
	var cutting := clip.has_area()
	var plain := cuts.size() < 2
	var first: Array = bands[0]
	for t in range(0, triangles.size() - 2, 3):
		var a := triangles[t]
		var b := triangles[t + 1]
		var c := triangles[t + 2]
		var lo := minf(a.y, minf(b.y, c.y))
		var hi := maxf(a.y, maxf(b.y, c.y))
		if hi < 0.0 or lo > height:
			continue
		var k0 := _band_of(edges, lo)
		var k1 := _band_of(edges, hi)
		var inside := not cutting
		if cutting:
			var x0 := minf(a.x, minf(b.x, c.x))
			var x1 := maxf(a.x, maxf(b.x, c.x))
			var z0 := minf(a.z, minf(b.z, c.z))
			var z1 := maxf(a.z, maxf(b.z, c.z))
			if x1 < clip.position.x or x0 > clip.end.x or z1 < clip.position.y or z0 > clip.end.y:
				continue
			inside = x0 >= clip.position.x and x1 <= clip.end.x and z0 >= clip.position.y and z1 <= clip.end.y
		if plain and inside and k0 == k1 and lo >= edges[k0] and hi <= edges[count]:
			# (the common case: a small triangle within one band)
			var into: Array = first[k0]
			into.append(Vector2(a.x, a.z))
			into.append(Vector2(b.x, b.z))
			into.append(Vector2(c.x, c.z))
			continue
		var whole := PackedVector3Array([a, b, c])
		if not inside:
			whole = _cut(whole, 0, clip.position.x, true)
			whole = _cut(whole, 0, clip.end.x, false)
			whole = _cut(whole, 2, clip.position.y, true)
			whole = _cut(whole, 2, clip.end.y, false)
			if whole.size() < 3:
				continue
		var pieces: Array = [[0, whole]]
		if cuts.size() > 1:
			pieces.clear()
			var left := minf(a.x, minf(b.x, c.x))
			var right := maxf(a.x, maxf(b.x, c.x))
			for col in stacks:
				if right < cuts[col] or left > cuts[col + 1]:
					continue
				var cut := _cut(whole, 0, cuts[col], true)
				cut = _cut(cut, 0, cuts[col + 1], false)
				if cut.size() >= 3:
					pieces.append([col, cut])
		for entry: Array in pieces:
			var column: Array = bands[entry[0]]
			for k in range(k0, k1 + 1):
				_clip(column[k], entry[1], edges[k], edges[k + 1])
	var out: Array = []
	for column: Array in bands:
		out.append_array(_stack(column, edges))
	return out


## The outlines of one column's bands ([param column]: points per band of
## [param edges]), alike neighbours merged: [[bottom, top, hull], ...].
static func _stack(column: Array, edges: PackedFloat32Array) -> Array:
	var merged: Array = []   # [bottom, top, hull]
	for k in column.size():
		var found: Array = column[k]
		if found.size() < 3:
			continue
		var hull := Geometry2D.convex_hull(PackedVector2Array(found))
		if hull.size() < 4 or _area(hull) < MIN_AREA:
			continue
		if not merged.is_empty():
			var last: Array = merged[merged.size() - 1]
			if is_equal_approx(float(last[1]), edges[k]):
				var joined := Geometry2D.convex_hull(last[2] + hull)
				if _alike(last[2], hull, joined):
					merged[merged.size() - 1] = [last[0], edges[k + 1], joined]
					continue
		merged.append([edges[k], edges[k + 1], hull])
	return merged


## The prisms of [param found] (outlines()).
static func _shapes(found: Array) -> Array:
	var out: Array = []
	for entry: Array in found:
		var hull: PackedVector2Array = entry[2]
		var cloud := PackedVector3Array()
		for i in hull.size() - 1:   # (the hull repeats its first point last)
			cloud.append(Vector3(hull[i].x, float(entry[0]), hull[i].y))
			cloud.append(Vector3(hull[i].x, float(entry[1]), hull[i].y))
		var prism := ConvexPolygonShape3D.new()
		prism.points = cloud
		out.append(prism)
	return out


## The band of [param edges] height [param y] lies in.
static func _band_of(edges: PackedFloat32Array, y: float) -> int:
	return clampi(edges.bsearch(y, false) - 1, 0, edges.size() - 2)


## Adds to [param points] the floor plan of polygon [param poly] cut to the
## band from [param bottom] to [param top]: its corners within it and where
## its edges cross the band's planes.
static func _clip(points: Array, poly: PackedVector3Array, bottom: float, top: float) -> void:
	for p in poly:
		if p.y >= bottom and p.y <= top:
			points.append(Vector2(p.x, p.z))
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		if is_equal_approx(p.y, q.y):
			continue
		for plane: float in [bottom, top]:
			if (p.y - plane) * (q.y - plane) < 0.0:
				var s := (plane - p.y) / (q.y - p.y)
				points.append(Vector2(p.x + (q.x - p.x) * s, p.z + (q.z - p.z) * s))


## [param poly] cut by the plane where coordinate [param axis] is
## [param value], keeping the side above it ([param above]) or below.
static func _cut(poly: PackedVector3Array, axis: int, value: float, above: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var p_in := (p[axis] >= value) == above
		var q_in := (q[axis] >= value) == above
		if p_in:
			out.append(p)
		if p_in != q_in:
			var s := (value - p[axis]) / (q[axis] - p[axis])
			out.append(p.lerp(q, s))
	return out


## True when outlines [param a] and [param b] are near enough the same
## that their [param joined] outline may stand for both.
static func _alike(a: PackedVector2Array, b: PackedVector2Array, joined: PackedVector2Array) -> bool:
	var ra := _rect(a)
	var rb := _rect(b)
	if absf(ra.position.x - rb.position.x) > MERGE_SLACK or absf(ra.position.y - rb.position.y) > MERGE_SLACK:
		return false
	if absf(ra.end.x - rb.end.x) > MERGE_SLACK or absf(ra.end.y - rb.end.y) > MERGE_SLACK:
		return false
	return _area(joined) <= MERGE_AREA * maxf(_area(a), _area(b))


static func _rect(points: PackedVector2Array) -> Rect2:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r


static func _area(hull: PackedVector2Array) -> float:
	var twice := 0.0
	for i in hull.size() - 1:
		twice += hull[i].x * hull[i + 1].y - hull[i + 1].x * hull[i].y
	return absf(twice) * 0.5


## Every drawn mesh (shown) of [param node] and under it, with its frame
## from [param frame] on: [[Mesh, Transform3D], ...] into [param out]
## (batches: one entry per instance).
static func _collect(node: Node3D, frame: Transform3D, out: Array) -> void:
	if not node.visible:
		return
	var view := node as MeshInstance3D
	if view != null and view.mesh != null:
		out.append([view.mesh, frame])
	var batch := node as MultiMeshInstance3D
	if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
		var places: Array = batch.get_meta(INSTANCES_META, [])
		if places.is_empty():
			for i in batch.multimesh.instance_count:
				places.append(batch.multimesh.get_instance_transform(i))
		for place: Transform3D in places:
			out.append([batch.multimesh.mesh, frame * place])
	for child in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, frame * (child as Node3D).transform, out)


## [param node]'s frame in [param ancestor]'s (inside a tree or not).
static func _relative(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## The triangles of [param mesh] (three points each, mesh space), kept.
static func _mesh_triangles(mesh: Mesh) -> PackedVector3Array:
	var id := _mesh_key(mesh)
	var store := _build_meshes if id.begins_with(ONE_BUILD) else _meshes
	if store.has(id):
		return store[id]
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var order: Variant = arrays[Mesh.ARRAY_INDEX]
		if order == null or (order as PackedInt32Array).is_empty():
			out.append_array(points)
		else:
			for i: int in order:
				out.append(points[i])
	store[id] = out
	return out


static func _rounded(xf: Transform3D) -> String:
	return "%s%s%s%s" % [xf.basis.x.snapped(Vector3.ONE * 0.001), xf.basis.y.snapped(Vector3.ONE * 0.001), xf.basis.z.snapped(Vector3.ONE * 0.001), xf.origin.snapped(Vector3.ONE * 0.001)]
