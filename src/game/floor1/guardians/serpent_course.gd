class_name SerpentCourse
extends RefCounted
## The Serpent's tracks through its temple (plan
## docs/superpowers/plans/2026-10-03-straznik-waz.md) as a graph built from
## the arena's markers (Guardian.points, by group):
## - &"path": the floor loop round the temple, between the fire bowls and
##   the walls (closed);
## - &"loop": the lower terrace's loop, crossing the upper flights near
##   their feet (closed);
## - &"stair": pairs (foot, top) - the two lower flights the body climbs;
## - &"summit": the track over the upper terrace from the north flight's
##   foot to the south flight's (open);
## - &"ring": the phase-3 ring round the altar's terrace: the first two
##   markers are the gate's west and east posts (nothing links them: the
##   gate stands over the north flight), the rest run from the east post
##   round to the west one.
## Markers within MERGE m are one node, so the groups share their nodes.
## The leader (SerpentBody's) travels the graph: head_for() lays a route
## (Dijkstra, never back through the node it came from) as a dense line
## with the corners rounded to CORNER m, and advance() moves along it with
## a lateral wave of [member amplitude] (wavelength WAVE_LENGTH) that
## fades in and out at the line's ends - the serpentine the body carries
## down its length. Flat geometry: the body samples the ground itself.

const MERGE := 0.6
## Corner rounding radius (m).
const CORNER := 1.2
const WAVE_LENGTH := 4.5
## The wave fades in and out over this much of the line (m).
const WAVE_RAMP := 1.5
## Points on a rounded corner's arc.
const ARC_STEPS := 8

var nodes: PackedVector3Array = PackedVector3Array()
## Per node: the nodes it links to.
var links: Array = []
## The ring's nodes in walking order: the east post first, round to the
## west post.
var ring: PackedInt32Array = PackedInt32Array()
## Lateral wave amplitude (m).
var amplitude: float = 0.25
## Distance travelled altogether (the wave's phase).
var travelled: float = 0.0
## The nodes of the route under way (the one being headed for first).
var route_nodes: PackedInt32Array = PackedInt32Array()

var _groups: Dictionary = {}   # group -> PackedInt32Array of nodes in marker order
var _line: PackedVector3Array = PackedVector3Array()
var _line_len: PackedFloat32Array = PackedFloat32Array()
## Arc length along the line where each route node is passed.
var _node_at: PackedFloat32Array = PackedFloat32Array()
var _along: float = 0.0
var _at := Vector3.ZERO
var _prev: int = -1
var _next: int = -1


# --- building -----------------------------------------------------------------------

func build(points: Dictionary) -> void:
	nodes = PackedVector3Array()
	links = []
	_groups = {}
	for group: StringName in [&"path", &"loop", &"ring", &"summit", &"stair"]:
		var list: Array = points.get(group, [])
		var ids := PackedInt32Array()
		for xform: Transform3D in list:
			ids.append(_node_for(xform.origin))
		_groups[group] = ids
		match group:
			&"path", &"loop":
				for i in ids.size():
					_link(ids[i], ids[(i + 1) % ids.size()])
			&"summit":
				for i in range(1, ids.size()):
					_link(ids[i - 1], ids[i])
			&"stair":
				for i in range(1, ids.size(), 2):
					_link(ids[i - 1], ids[i])
			&"ring":
				# posts 0 (west) and 1 (east); the ring runs 1 -> 2 -> ... -> 0
				if ids.size() >= 3:
					ring = PackedInt32Array()
					for i in range(1, ids.size()):
						ring.append(ids[i])
					ring.append(ids[0])
					for i in range(1, ring.size()):
						_link(ring[i - 1], ring[i])


func _node_for(at: Vector3) -> int:
	var flat := Vector3(at.x, at.y, at.z)
	for i in nodes.size():
		if Vector2(nodes[i].x - flat.x, nodes[i].z - flat.z).length() <= MERGE:
			return i
	nodes.append(flat)
	links.append(PackedInt32Array())
	return nodes.size() - 1


func _link(a: int, b: int) -> void:
	if a == b:
		return
	# (packed arrays are values: write them back)
	var from_a: PackedInt32Array = links[a]
	if not from_a.has(b):
		from_a.append(b)
		links[a] = from_a
	var from_b: PackedInt32Array = links[b]
	if not from_b.has(a):
		from_b.append(a)
		links[b] = from_b


# --- reading the graph ----------------------------------------------------------------

## The nodes of marker group [param group] in marker order.
func group_nodes(group: StringName) -> PackedInt32Array:
	return _groups.get(group, PackedInt32Array())


## Group [param group] as the rounded line the leader would follow (a
## closed group closes back on its first node).
func group_line(group: StringName) -> PackedVector3Array:
	var ids := group_nodes(group)
	var points := PackedVector3Array()
	for id in ids:
		points.append(_flat(nodes[id]))
	return rounded(points, group == &"path" or group == &"loop")


## The (foot, top) pairs of group [param group].
func group_pairs(group: StringName) -> Array[Vector2i]:
	var ids := group_nodes(group)
	var out: Array[Vector2i] = []
	for i in range(1, ids.size(), 2):
		out.append(Vector2i(ids[i - 1], ids[i]))
	return out


## The node nearest [param at] (flat).
func nearest(at: Vector3, exclude: int = -1) -> int:
	var best := -1
	var gap := INF
	for i in nodes.size():
		if i == exclude:
			continue
		var d := Vector2(nodes[i].x - at.x, nodes[i].z - at.z).length()
		if d < gap:
			gap = d
			best = i
	return best


## Shortest route from node [param from] to [param to] (both included),
## never stepping first to [param avoid] (the node it came from); empty
## when there is none.
func route(from: int, to: int, avoid: int = -1) -> PackedInt32Array:
	if from < 0 or to < 0 or from >= nodes.size() or to >= nodes.size():
		return PackedInt32Array()
	if from == to:
		return PackedInt32Array([from])
	var distance := PackedFloat32Array()
	distance.resize(nodes.size())
	distance.fill(INF)
	var previous := PackedInt32Array()
	previous.resize(nodes.size())
	previous.fill(-1)
	var done := PackedByteArray()
	done.resize(nodes.size())
	distance[from] = 0.0
	for step in nodes.size():
		var current := -1
		var best := INF
		for i in nodes.size():
			if done[i] == 0 and distance[i] < best:
				best = distance[i]
				current = i
		if current < 0 or current == to:
			break
		done[current] = 1
		for next in links[current] as PackedInt32Array:
			if current == from and next == avoid:
				continue
			var through := distance[current] + nodes[current].distance_to(nodes[next])
			if through < distance[next]:
				distance[next] = through
				previous[next] = current
	if is_inf(distance[to]):
		return PackedInt32Array()
	var out := PackedInt32Array()
	var at := to
	while at >= 0:
		out.insert(0, at)
		at = previous[at]
	return out


# --- the ring ------------------------------------------------------------------------

## The gate's posts: [west, east] (flat).
func gate_posts() -> Array[Vector3]:
	if ring.size() < 2:
		return [Vector3.ZERO, Vector3.ZERO]
	return [_flat(nodes[ring[ring.size() - 1]]), _flat(nodes[ring[0]])]


func gate_center() -> Vector3:
	var posts := gate_posts()
	return (posts[0] + posts[1]) * 0.5


## The ring as the rounded line from the east post round to the west post.
func ring_path() -> PackedVector3Array:
	var points := PackedVector3Array()
	for id in ring:
		points.append(_flat(nodes[id]))
	return rounded(points)


# --- the leader -----------------------------------------------------------------------

## The leader stands at [param at], on (or by) node [param node], going
## nowhere yet.
func start_at(at: Vector3, node: int) -> void:
	_at = _flat(at)
	_prev = node
	_next = -1
	_line = PackedVector3Array()
	_line_len = PackedFloat32Array()
	_node_at = PackedFloat32Array()
	route_nodes = PackedInt32Array()
	_along = 0.0


## Lays the route to [param goal] from where the leader is: on through the
## node it heads for (never back through the one it came from), then the
## shortest way.
func head_for(goal: int) -> void:
	_at = position()   # the new line starts where the leader really is
	var from := _next if _next >= 0 else _prev
	var avoid := _prev if _next >= 0 else -1
	var path := route(from, goal, avoid)
	if path.is_empty():
		path = route(from, goal)
	if path.is_empty():
		return
	route_nodes = path
	var points := PackedVector3Array([_at])
	for id in path:
		points.append(_flat(nodes[id]))
	if _next < 0 and points.size() > 1 and points[0].distance_to(points[1]) < 0.02:
		points.remove_at(1)
		route_nodes = path.slice(1)
		if route_nodes.is_empty():
			_line = PackedVector3Array()
			return
	_lay_line(points)
	_next = route_nodes[0]
	_along = 0.0


## Lays an explicit route through [param nodes] (in order) from where the
## leader is: the ring walked round, not shortcut.
func head_along(order: PackedInt32Array) -> void:
	_at = position()
	route_nodes = order.duplicate()
	if not route_nodes.is_empty() and _flat(nodes_at(route_nodes[0])).distance_to(_at) < 0.02:
		route_nodes.remove_at(0)
	if route_nodes.is_empty():
		_line = PackedVector3Array()
		_next = -1
		return
	var points := PackedVector3Array([_at])
	for id in route_nodes:
		points.append(_flat(nodes[id]))
	_lay_line(points)
	_next = route_nodes[0]
	_along = 0.0


## The leader stands at [param at] facing [param heading] (flat), between
## nodes: it will head on for the nearest node ahead of it.
func start_on(at: Vector3, heading: Vector3) -> void:
	_at = _flat(at)
	_line = PackedVector3Array()
	_line_len = PackedFloat32Array()
	_node_at = PackedFloat32Array()
	route_nodes = PackedInt32Array()
	_along = 0.0
	_prev = -1
	var flat := Vector3(heading.x, 0.0, heading.z)
	flat = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	var best := -1
	var gap := INF
	for i in nodes.size():
		var to := _flat(nodes[i]) - _at
		var d := to.length()
		if d < 0.05 or d >= gap:
			continue
		if to.normalized().dot(flat) > 0.2:
			gap = d
			best = i
	if best < 0:
		best = nearest(_at)
	_next = best
	# a line straight to it, so advance() has something to walk until a
	# goal is given
	_lay_line(PackedVector3Array([_at, _flat(nodes[best])]))
	route_nodes = PackedInt32Array([best])


## Node [param id]'s point (with its marker's height).
func nodes_at(id: int) -> Vector3:
	return nodes[id]


## Moves the leader [param distance] m along its line; returns where it
## is now (with the wave).
func advance(distance: float) -> Vector3:
	if _line.size() < 2:
		return position()
	var total := _line_len[_line_len.size() - 1]
	var before := _along
	_along = minf(_along + maxf(distance, 0.0), total)
	travelled += _along - before
	_at = _sample(_along)
	# the nodes passed on the way
	while route_nodes.size() > 1 and _node_at.size() > 0 and _along >= _node_at[0] - 0.001:
		_prev = route_nodes[0]
		route_nodes.remove_at(0)
		_node_at.remove_at(0)
		_next = route_nodes[0]
	if _along >= total - 0.0005:
		if not route_nodes.is_empty():
			_prev = route_nodes[route_nodes.size() - 1]
		_next = -1
	return position()


## The line [param ahead] m on from the leader (flat, no wave; the line's
## end when that is nearer): what the body looks ahead at for a rise.
func peek(ahead: float) -> Vector3:
	if _line.size() < 2:
		return _at
	return _sample(minf(_along + maxf(ahead, 0.0), _line_len[_line_len.size() - 1]))


## Where the leader is (flat, with the wave).
func position() -> Vector3:
	if _line.size() < 2:
		return _at
	var right := heading().cross(Vector3.UP)
	return _at + right * wave_offset()


## The wave's lateral offset now (m).
func wave_offset() -> float:
	if _line.size() < 2:
		return 0.0
	var total := _line_len[_line_len.size() - 1]
	var ramp := clampf(_along / WAVE_RAMP, 0.0, 1.0) * clampf((total - _along) / WAVE_RAMP, 0.0, 1.0)
	return amplitude * sin(TAU * travelled / WAVE_LENGTH) * ramp


## The line's direction at the leader (flat, unit): smoothed over a short
## span, so the wave's offset turns gently through a rounded corner's
## facets.
func heading() -> Vector3:
	if _line.size() < 2:
		return Vector3.FORWARD
	var total := _line_len[_line_len.size() - 1]
	var d := _sample(minf(_along + 0.12, total)) - _sample(maxf(_along - 0.12, 0.0))
	if d.length() < 0.0001:
		var i := _segment_index(_along)
		d = _line[i + 1] - _line[i]
	return d.normalized() if d.length() > 0.0001 else Vector3.FORWARD


## True once the leader reached the end of its line.
func arrived() -> bool:
	return _line.size() < 2 or _along >= _line_len[_line_len.size() - 1] - 0.0005


## The node the leader heads for (-1 when standing).
func next_node() -> int:
	return _next


## The node the leader stands on or last passed.
func previous_node() -> int:
	return _prev


## Distance left to the end of the line (m).
func left() -> float:
	if _line.size() < 2:
		return 0.0
	return _line_len[_line_len.size() - 1] - _along


# --- lines ----------------------------------------------------------------------------

## [param points] with every corner rounded to CORNER (less where the arms
## are short): the line the leader follows. [param closed]: a loop (its
## first corner rounded too, the line closing back on its start).
static func rounded(points: PackedVector3Array, closed: bool = false) -> PackedVector3Array:
	var out := PackedVector3Array()
	if points.size() < 3:
		return points.duplicate()
	if closed:
		var cyclic := PackedVector3Array([points[points.size() - 1]])
		cyclic.append_array(points)
		cyclic.append(points[0])
		var open := rounded(cyclic, false)
		var loop := open.slice(1, open.size() - 1)
		loop.append(loop[0])
		return loop
	out.append(points[0])
	for i in range(1, points.size() - 1):
		var corner := points[i]
		var a := corner - points[i - 1]
		var b := points[i + 1] - corner
		if a.length() < 0.001 or b.length() < 0.001:
			continue
		var ahat := a.normalized()
		var bhat := b.normalized()
		var turn := acos(clampf(ahat.dot(bhat), -1.0, 1.0))
		if turn < 0.03:
			out.append(corner)
			continue
		var t := minf(CORNER * tan(turn * 0.5), 0.45 * minf(a.length(), b.length()))
		var r := t / tan(turn * 0.5)
		var t1 := corner - ahat * t
		var t2 := corner + bhat * t
		var bisector := (bhat - ahat).normalized()
		var center := corner + bisector * (r / cos(turn * 0.5))
		var from := t1 - center
		var sign := 1.0 if ahat.cross(bhat).y > 0.0 else -1.0
		for k in range(0, ARC_STEPS + 1):
			out.append(center + from.rotated(Vector3.UP, sign * turn * float(k) / float(ARC_STEPS)))
		if t2.distance_to(out[out.size() - 1]) > 0.01:
			out.append(t2)
	out.append(points[points.size() - 1])
	return out


func _lay_line(points: PackedVector3Array) -> void:
	_line = rounded(points)
	_line_len = PackedFloat32Array()
	_line_len.resize(_line.size())
	_line_len[0] = 0.0
	for i in range(1, _line.size()):
		_line_len[i] = _line_len[i - 1] + _line[i].distance_to(_line[i - 1])
	# where each route node is passed: the nearest point of the line to it
	_node_at = PackedFloat32Array()
	# (each node is looked for from where the previous one was found on: a route
	# that passes close to a later node earlier on is not at it yet)
	var cursor := 0
	for k in range(1, points.size()):
		var node := points[k]
		var best := INF
		var best_at := _line_len[_line_len.size() - 1]
		var best_index := cursor
		for i in range(cursor, _line.size() - 1):
			var on := Geometry3D.get_closest_point_to_segment(node, _line[i], _line[i + 1])
			var d := on.distance_to(node)
			if d < best:
				best = d
				best_at = _line_len[i] + on.distance_to(_line[i])
				best_index = i
		cursor = best_index
		_node_at.append(best_at)


func _segment_index(along: float) -> int:
	var low := 0
	var high := _line.size() - 1
	while high - low > 1:
		var mid := (low + high) >> 1
		if _line_len[mid] <= along:
			low = mid
		else:
			high = mid
	return low


func _sample(along: float) -> Vector3:
	var i := _segment_index(along)
	var span := _line_len[i + 1] - _line_len[i]
	var t := clampf((along - _line_len[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return _line[i].lerp(_line[i + 1], t)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
