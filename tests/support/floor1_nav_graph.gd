class_name Floor1NavGraph
extends RefCounted
## A baked navmesh (the NavigationMesh of one region, or of every region of
## a layer: Floor I's walkable boxes) as a graph of its polygons, for the
## Floor I verification (W7): polygons are joined the way
## NavigationServer3D joins them on the map - where they share an edge
## (vertex positions merged on the map's cell grid), and free edges of
## different regions that lie within the map's edge connection margin of
## each other (its own test, NavMapBuilder3D). On top: connected
## components, the closest navmesh point of a component to any point and
## standing points for line-of-sight checks. Pure data: asking the NavigationServer for a path to a sealed
## island prints an engine error (nav_probe.gd), asking this graph never
## does.

## The map's merge cell (navigation/3d/default_cell_size and
## default_cell_height; the scale is 1).
const CELL := 0.25
const CELL_HEIGHT := 0.1
## Side of the spatial buckets (m).
const BUCKET := 4.0
## A standing point's corner lies this share of the way to the centre.
const INSET := 0.25

var vertices: PackedVector3Array = PackedVector3Array()
## Polygon -> its vertex indices (convex; Godot bakes triangles).
var polygons: Array[PackedInt32Array] = []
## Polygon -> polygons sharing one of its edges.
var neighbours: Array[PackedInt32Array] = []
var centers: PackedVector3Array = PackedVector3Array()
## Polygon -> its floor area (m2, seen from above).
var areas: PackedFloat32Array = PackedFloat32Array()
## Polygon -> its component (0 .. component_count - 1); join() merges two.
var component: PackedInt32Array = PackedInt32Array()
var component_count: int = 0
## Polygon -> its component as baked (before any join()).
var base_component: PackedInt32Array = PackedInt32Array()
## Edges shared by more than two polygons (the map warns about them).
var crowded_edges: int = 0
## Polygon -> its region (index of its mesh in from_meshes()).
var owners: PackedInt32Array = PackedInt32Array()
## Pairs of polygons joined across regions by the edge connection margin.
var margin_links: int = 0
## Free edges (on no other polygon's edge): [polygon, a, b].
var _free: Array = []

## Vector2i bucket -> PackedInt32Array of polygons overlapping it.
var _buckets: Dictionary = {}


static func from_mesh(mesh: NavigationMesh) -> Floor1NavGraph:
	var polys: Array[PackedInt32Array] = []
	for i in mesh.get_polygon_count():
		polys.append(mesh.get_polygon(i))
	return from_data(mesh.get_vertices(), polys)


## Every region's mesh of [param meshes] (Array of NavigationMesh, null
## skipped) as one graph, the regions' free edges joined within
## [param margin] (the map's edge connection margin).
static func from_meshes(meshes: Array, margin: float) -> Floor1NavGraph:
	var points := PackedVector3Array()
	var polys: Array[PackedInt32Array] = []
	var regions := PackedInt32Array()
	for r in meshes.size():
		var mesh := meshes[r] as NavigationMesh
		if mesh == null:
			continue
		var offset := points.size()
		points.append_array(mesh.get_vertices())
		for i in mesh.get_polygon_count():
			var poly := mesh.get_polygon(i)
			for k in poly.size():
				poly[k] += offset
			polys.append(poly)
			regions.append(r)
	return from_data(points, polys, regions, margin)


static func from_data(points: PackedVector3Array, polys: Array[PackedInt32Array], regions: PackedInt32Array = PackedInt32Array(), margin: float = 0.0) -> Floor1NavGraph:
	var graph := Floor1NavGraph.new()
	graph.vertices = points
	graph.polygons = polys
	graph.owners = regions
	if graph.owners.size() != polys.size():
		graph.owners.resize(polys.size())
		graph.owners.fill(0)
	var links := graph._link()
	if margin > 0.0:
		graph._link_free_edges(links, margin)
	graph.neighbours.resize(polys.size())
	for p in polys.size():
		graph.neighbours[p] = PackedInt32Array(links[p])
	graph._label()
	graph._index()
	return graph


## The map's test whether free edge [param a1]-[param a2] of one region
## and [param b1]-[param b2] of another join (NavMapBuilder3D's edge
## connection margin): the second projected onto the first overlaps it and
## both ends of the overlap lie within the margin.
static func margin_joins(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3, margin_squared: float) -> bool:
	var edge := a2 - a1
	var length_squared := edge.length_squared()
	if length_squared <= 0.0:
		return false
	var r1 := edge.dot(b1 - a1) / length_squared
	var r2 := edge.dot(b2 - a1) / length_squared
	if (r1 < 0.0 and r2 < 0.0) or (r1 > 1.0 and r2 > 1.0):
		return false
	var self1 := edge * clampf(r2, 0.0, 1.0) + a1
	var other1 := b2 if r2 >= 0.0 and r2 <= 1.0 else b1.lerp(b2, (1.0 - r1) / (r2 - r1))
	if other1.distance_squared_to(self1) > margin_squared:
		return false
	var self2 := edge * clampf(r1, 0.0, 1.0) + a1
	var other2 := b1 if r1 >= 0.0 and r1 <= 1.0 else b1.lerp(b2, (0.0 - r1) / (r2 - r1))
	return other2.distance_squared_to(self2) <= margin_squared


## The map's key of a vertex position.
static func point_key(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / CELL), floori(point.y / CELL_HEIGHT), floori(point.z / CELL))


# --- queries ------------------------------------------------------------------

## Polygons whose floor-plan bounds come within [param radius] of
## [param point] (seen from above).
func polygons_near(point: Vector3, radius: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var seen := {}
	var low := Vector2i(floori((point.x - radius) / BUCKET), floori((point.z - radius) / BUCKET))
	var high := Vector2i(floori((point.x + radius) / BUCKET), floori((point.z + radius) / BUCKET))
	for bx in range(low.x, high.x + 1):
		for bz in range(low.y, high.y + 1):
			var cell: PackedInt32Array = _buckets.get(Vector2i(bx, bz), PackedInt32Array())
			for p in cell:
				if not seen.has(p):
					seen[p] = true
					found.append(p)
	return found


## The closest point of polygon [param p] to [param point].
func closest_on(p: int, point: Vector3) -> Vector3:
	var poly := polygons[p]
	var a := vertices[poly[0]]
	var best := a
	var best_distance := INF
	for k in range(1, poly.size() - 1):
		var on := closest_on_triangle(point, a, vertices[poly[k]], vertices[poly[k + 1]])
		var distance := on.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = on
	return best


## The closest navmesh point to [param point] within [param radius] (3D),
## on component [param comp] (-1: any); Vector3.INF when there is none.
func closest(point: Vector3, comp: int = -1, radius: float = 2.0) -> Vector3:
	var p := closest_polygon(point, comp, radius)
	return closest_on(p, point) if p >= 0 else Vector3.INF


## The polygon holding the closest point to [param point] (see closest());
## -1 when there is none.
func closest_polygon(point: Vector3, comp: int = -1, radius: float = 2.0) -> int:
	var best := -1
	var best_distance := radius * radius
	for p in polygons_near(point, radius):
		if comp >= 0 and component[p] != comp:
			continue
		var distance := closest_on(p, point).distance_squared_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = p
	return best


## The component of the navmesh under [param point] (its closest polygon
## within [param radius]); -1 off the mesh.
func component_at(point: Vector3, radius: float = 0.6) -> int:
	var p := closest_polygon(point, -1, radius)
	return component[p] if p >= 0 else -1


## Points a guard can stand on in component [param comp] within
## [param radius] of [param center] (floor-plan distance), closest first:
## of every polygon its point closest to the centre, its centre, its
## corners drawn in toward the centre of the polygon and the points half
## way from the closest point to each corner.
func stand_points(comp: int, center: Vector3, radius: float) -> PackedVector3Array:
	var found: Array[Vector3] = []
	var flat := Vector2(center.x, center.z)
	var limit := radius * radius
	for p in polygons_near(center, radius):
		if component[p] != comp:
			continue
		var middle := centers[p]
		# the polygon's point closest to the centre (a big floor triangle may
		# have all its corners far away), drawn in a little, and its centre
		# and corners drawn in
		var nearest := closest_on(p, center).lerp(middle, 0.05)
		var candidates: Array[Vector3] = [nearest, middle]
		for v in polygons[p]:
			candidates.append(vertices[v].lerp(middle, INSET))
			candidates.append(nearest.lerp(vertices[v], 0.5).lerp(middle, 0.05))
		for at in candidates:
			if Vector2(at.x, at.z).distance_squared_to(flat) <= limit:
				found.append(at)
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	return PackedVector3Array(found)


## Joins the components of polygons [param p] and [param q] (a passage the
## mesh misses); false when they were one already.
func join(p: int, q: int) -> bool:
	var keep := component[p]
	var drop := component[q]
	if keep == drop:
		return false
	for i in component.size():
		if component[i] == drop:
			component[i] = keep
	return true


## Polygons of component [param comp].
func polygons_of(comp: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	for p in polygons.size():
		if component[p] == comp:
			found.append(p)
	return found


## Floor area (m2) of component [param comp].
func area_of(comp: int) -> float:
	var total := 0.0
	for p in polygons.size():
		if component[p] == comp:
			total += areas[p]
	return total


## The closest point of triangle [param a] [param b] [param c] to
## [param point] (Ericson, Real-Time Collision Detection 5.1.5).
static func closest_on_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


# --- building -----------------------------------------------------------------

## Joins polygons sharing an edge; returns polygon -> Array of neighbours
## and keeps the free edges.
func _link() -> Array[Array]:
	var ids := {}
	var keys := PackedInt32Array()
	keys.resize(vertices.size())
	for i in vertices.size():
		var key := point_key(vertices[i])
		if not ids.has(key):
			ids[key] = ids.size()
		keys[i] = ids[key]
	var sharing_of := {}
	var ends := {}
	var links: Array[Array] = []
	links.resize(polygons.size())
	centers.resize(polygons.size())
	areas.resize(polygons.size())
	for p in polygons.size():
		links[p] = []
		var poly := polygons[p]
		var sum := Vector3.ZERO
		for k in poly.size():
			sum += vertices[poly[k]]
			var a := keys[poly[k]]
			var b := keys[poly[(k + 1) % poly.size()]]
			if a == b:
				continue
			var edge := mini(a, b) * 1048576 + maxi(a, b)
			if not sharing_of.has(edge):
				sharing_of[edge] = [p]
				ends[edge] = [vertices[poly[k]], vertices[poly[(k + 1) % poly.size()]]]
				continue
			var sharing: Array = sharing_of[edge]
			if sharing.size() >= 2:
				crowded_edges += 1
			for other: int in sharing:
				if other != p and not links[p].has(other):
					links[p].append(other)
					links[other].append(p)
			sharing.append(p)
		centers[p] = sum / float(poly.size())
		areas[p] = _flat_area(poly)
	_free = []
	for edge: int in sharing_of:
		if (sharing_of[edge] as Array).size() == 1:
			_free.append([sharing_of[edge][0], ends[edge][0], ends[edge][1]])
	return links


## Joins free edges of different regions within [param margin].
func _link_free_edges(links: Array[Array], margin: float) -> void:
	var cell := 2.0
	var cells := {}
	for i in _free.size():
		var a: Vector3 = _free[i][1]
		var b: Vector3 = _free[i][2]
		for bx in range(floori((minf(a.x, b.x) - margin) / cell), floori((maxf(a.x, b.x) + margin) / cell) + 1):
			for bz in range(floori((minf(a.z, b.z) - margin) / cell), floori((maxf(a.z, b.z) + margin) / cell) + 1):
				var key := Vector2i(bx, bz)
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append(i)
	var squared := margin * margin
	var tried := {}
	for key: Vector2i in cells:
		var members: Array = cells[key]
		for x in members.size():
			for y in range(x + 1, members.size()):
				var i: int = members[x]
				var j: int = members[y]
				var p: int = _free[i][0]
				var q: int = _free[j][0]
				if owners[p] == owners[q] or links[p].has(q):
					continue
				var pair := mini(i, j) * 1048576 + maxi(i, j)
				if tried.has(pair):
					continue
				tried[pair] = true
				if margin_joins(_free[i][1], _free[i][2], _free[j][1], _free[j][2], squared) or margin_joins(_free[j][1], _free[j][2], _free[i][1], _free[i][2], squared):
					links[p].append(q)
					links[q].append(p)
					margin_links += 1


func _label() -> void:
	component.resize(polygons.size())
	component.fill(-1)
	component_count = 0
	for first in polygons.size():
		if component[first] >= 0:
			continue
		var queue := PackedInt32Array([first])
		component[first] = component_count
		var head := 0
		while head < queue.size():
			var p := queue[head]
			head += 1
			for q in neighbours[p]:
				if component[q] < 0:
					component[q] = component_count
					queue.append(q)
		component_count += 1
	base_component = component.duplicate()


func _index() -> void:
	var cells := {}
	for p in polygons.size():
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for v in polygons[p]:
			var at := vertices[v]
			low = Vector2(minf(low.x, at.x), minf(low.y, at.z))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.z))
		for bx in range(floori(low.x / BUCKET), floori(high.x / BUCKET) + 1):
			for bz in range(floori(low.y / BUCKET), floori(high.y / BUCKET) + 1):
				var cell := Vector2i(bx, bz)
				if not cells.has(cell):
					cells[cell] = []
				(cells[cell] as Array).append(p)
	for cell: Vector2i in cells:
		_buckets[cell] = PackedInt32Array(cells[cell])


func _flat_area(poly: PackedInt32Array) -> float:
	var total := 0.0
	var a := vertices[poly[0]]
	for k in range(1, poly.size() - 1):
		var b := vertices[poly[k]] - a
		var c := vertices[poly[k + 1]] - a
		total += absf(b.x * c.z - b.z * c.x) * 0.5
	return total
