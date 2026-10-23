class_name PlaythroughNav
extends RefCounted
## The playthrough bot's legs (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md): a way over the
## game's own navmesh to a point, walked through the pilot's keys like a
## player steering along it, with what a player does when he catches on
## something (a hop, a step aside, another look at the way), and the spots
## to stand on to use a thing (E within Interactor.REACH, the thing first
## under the crosshair) or to hit one (a shot whose ray meets it first).
##
## Paths are asked from the goal back to the guard and turned round: a
## query from the walkable floor to a goal on a sealed island of the mesh
## (a desk top, a pedestal) makes the engine print an error, the other way
## round it is quiet and simply ends on the island (see NavProbe). A
## haven's floor is a region of its own (layer HAVEN) that the walkable
## floor does not join: a way into a haven ends at its door and goes the
## last metres straight.

enum Status { IDLE, RUNNING, ARRIVED, FAILED }

## Both regions: the exhibits' floor and the havens'.
const LAYERS := LevelNavigation.WALK_LAYER | LevelNavigation.HAVEN_LAYER
## A waypoint counts as passed this close (m, on the floor plan).
const WAYPOINT := 0.45
## The path's end must come back this close to the guard's spot (m).
const BACK := 0.8
## A goal past the path's end within this (m) and in plain view is walked
## to straight (a haven's door, the last step to a thing).
const STRAIGHT_LAST := 7.0
## Without this much progress (m) in STALL_TIME s he is stuck.
const STALL_PROGRESS := 0.12
const STALL_TIME := 0.8
## Stuck this many times on one way: it has failed.
const MAX_STUCK := 5
## Sprint when this much way is left (m) and he is not fighting.
const SPRINT_LEFT := 10.0
## Fallen this far below the way: plan again.
const FALL_DROP := 2.5
## A thing he bumps into at most this big across (m) is an obstacle to go
## round (bigger: a wall); the ways keep this far (m) off it.
const OBSTACLE_SIZE := 3.5
const OBSTACLE_MARGIN := 0.45
## A gap of the navmesh his body crosses is walked straight over at most
## this far (m); at most BRIDGE_TRIES ways asked for it.
const BRIDGE := 3.2
const BRIDGE_TRIES := 8
## A gap looked for in vain is not looked for again between the same ends
## for this many physics steps.
const BRIDGE_AGAIN := 240
## Straight lines probed for a gap at most per search (each a dozen
## navmesh lookups).
const BRIDGE_PROBES := 360
## Spots to stand on tried for a way over a gap when none has a plain way.
const SPOT_SEARCHES := 3

var guard: Player
var pilot: PlaythroughPilot
var level: MuseumFloorLevel
var map: RID
var path := PackedVector3Array()
var index: int = 0
var goal := Vector3.INF
var reach: float = 0.6
var status: Status = Status.IDLE
## Why the last way failed ("no path", "stuck", "fell").
var failure: String = ""
## Allowed to sprint along the way.
var may_sprint: bool = true
## Each time he got stuck: {at, kit, top} (for the report; the bot logs it).
var stuck_events: Array[Dictionary] = []
## Seconds walked on the current way.
var walked: float = 0.0
## Small things in the way the navmesh does not know (their boxes), learnt
## by bumping into them.
var obstacles: Array[AABB] = []
## The gaps of the mesh he walked across tonight (_bridged): [one side,
## the other].
var bridges: Array[PackedVector3Array] = []
## "start>end" (rounded) -> the physics step a gap was looked for in vain.
var _bridge_failed: Dictionary = {}

var _best: float = INF
var _since_best: float = 0.0
var _stuck: int = 0
var _recover_left: float = 0.0
var _recover_dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _shape := PhysicsShapeQueryParameters3D.new()
var _stand := PhysicsShapeQueryParameters3D.new()
var _builder: LevelBuilder = null
## Room ids of the havens; room id -> [inside, outside] of its way out.
var _haven_rooms: Dictionary = {}
var _exits: Dictionary = {}


func _init(player: Player, hands: PlaythroughPilot, floor_level: MuseumFloorLevel, rng_seed: int = 1) -> void:
	guard = player
	pilot = hands
	level = floor_level
	map = guard.get_world_3d().navigation_map
	if level != null:
		_builder = LevelBuilder.new(level.layout, null, null, null)
		for haven in Floor1Plan.havens():
			_haven_rooms[haven.room] = true
	_rng.seed = rng_seed
	_ray.collision_mask = Layers.WORLD
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_shape.shape = capsule
	_shape.collision_mask = Layers.WORLD
	_stand.shape = capsule
	_stand.collision_mask = Layers.WORLD


func feet() -> Vector3:
	return guard.global_position


func space() -> PhysicsDirectSpaceState3D:
	return guard.get_world_3d().direct_space_state


## True once the map has the level's navmesh (a night's scene just made has
## an empty map for a step or two: every query would answer the origin).
func ready() -> bool:
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var near := snap(feet())
	return near != Vector3.ZERO and near.distance_to(feet()) < 4.0


## The point of the navmesh nearest to [param point].
func snap(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, point)


## The point of the walkable floor (not a haven's) nearest to [param point].
func snap_walk(point: Vector3) -> Vector3:
	if level == null or level.navigation == null or level.navigation.regions.is_empty():
		return snap(point)
	var best := Vector3.INF
	for region in level.navigation.regions:
		var found := NavigationServer3D.region_get_closest_point(region.get_rid(), point)
		if best == Vector3.INF or found.distance_squared_to(point) < best.distance_squared_to(point):
			best = found
	return best


## The walk from where the guard stands (or [param from]) to [param to]
## (navmesh points; a goal off the mesh within STRAIGHT_LAST m of the way's
## end and in view is added as the last point); out of a haven's room and
## into one through its door; empty when there is no way. Over the gaps
## of the mesh crossed tonight always, a new one looked for only when
## [param search] (a walk he means to make, not a guess at a length).
func path_to(to: Vector3, from: Vector3 = Vector3.INF, search: bool = true) -> PackedVector3Array:
	var origin := feet() if from == Vector3.INF else from
	var room_here := _room_of(origin)
	var room_there := _room_of(to)
	if _haven_rooms.has(room_here) and room_here == room_there:
		return _haven_path(origin, to)
	var way := PackedVector3Array()
	var start_at := origin
	if _haven_rooms.has(room_here):
		var out := _room_exit(room_here)
		if not out.is_empty():
			way.append_array(_haven_path(origin, out[0]))
			start_at = out[1]
	var end_at := to
	var last_steps := PackedVector3Array()
	if _haven_rooms.has(room_there):
		var door := _room_exit(room_there)
		if not door.is_empty():
			end_at = door[1]
			last_steps = _haven_path(door[0], to)
	var middle := _mesh_path(start_at, end_at, last_steps.is_empty(), search)
	if middle.is_empty():
		return middle
	way.append_array(middle)
	way.append_array(last_steps)
	return way


## A walk inside a haven's room on the havens' own navmesh (layer HAVEN),
## from [param from] to [param to]; straight when the mesh has none.
func _haven_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = to
	query.target_position = from
	query.navigation_layers = LevelNavigation.HAVEN_LAYER
	query.path_search_max_polygons = LevelNavigation.SEARCH_POLYGONS
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	var back := result.path
	if back.is_empty() or Vector2(back[back.size() - 1].x - from.x, back[back.size() - 1].z - from.z).length() > 1.0:
		return PackedVector3Array([from, to])
	var way := PackedVector3Array([from])
	for i in range(back.size() - 1, -1, -1):
		way.append(back[i])
	way.append(to)
	return way


## The navmesh walk from [param from] to [param to] (both snapped; the
## goal itself added when off the mesh but near and in view, if
## [param straight_end]); [] when there is none.
func _mesh_path(from: Vector3, to: Vector3, straight_end: bool, search: bool = true) -> PackedVector3Array:
	var start := snap(from)
	var end := snap(to)
	if start.distance_to(end) < 0.05:
		return PackedVector3Array([start, to])
	var back := _query_back(end, start)
	if back.is_empty():
		return PackedVector3Array()
	if back[back.size() - 1].distance_to(start) > BACK:
		var across := _via_known_bridge(start, end)
		if across.is_empty() and search:
			# a gap looked for (dear: up to BRIDGE_TRIES ways asked and many
			# probes) at most once per BRIDGE_AGAIN steps for the same ends
			var key := "%d,%d,%d>%d,%d,%d" % [roundi(start.x), roundi(start.y), roundi(start.z), roundi(end.x * 2.0), roundi(end.y * 2.0), roundi(end.z * 2.0)]
			var frame := Engine.get_physics_frames()
			if frame - int(_bridge_failed.get(key, -BRIDGE_AGAIN)) >= BRIDGE_AGAIN:
				across = _bridged(start, end, back)
				if across.is_empty():
					across = _bridged_out(start, end)
				if across.is_empty():
					_bridge_failed[key] = frame
					if _bridge_failed.size() > 512:
						_bridge_failed.clear()
		if across.is_empty():
			return across
		back = across
	var way := PackedVector3Array()
	for i in range(back.size() - 1, -1, -1):
		way.append(back[i])
	var last := way[way.size() - 1]
	var off := Vector2(to.x - last.x, to.z - last.z).length()
	if straight_end and off > 0.3 and off <= STRAIGHT_LAST and absf(to.y - last.y) < 1.5 and clear_between(last, to):
		way.append(to)
	return way


## The navmesh way from [param goal] back toward [param start] (the quiet
## direction, see the header): it ends at [param start], or where the
## goal's part of the mesh comes nearest to it.
func _query_back(goal_at: Vector3, start: Vector3) -> PackedVector3Array:
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = goal_at
	query.target_position = start
	query.navigation_layers = LAYERS
	query.path_search_max_polygons = LevelNavigation.SEARCH_POLYGONS
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	return result.path


## [param back] (a way from the goal [param end] toward [param start] that
## ends on the goal's part of the mesh, short of him) carried on across a
## gap the navmesh does not cross but his body does - the mesh keeps its
## agent's 0.5 m off every piece, so a gap narrower than 1 m and more is
## sealed for it, while the guard is 0.8 m across (the card catalogue's
## arcs round the Reading Room's astrolabe leave about 1.1 m: the dais is
## an island of the mesh). Points of the mesh round the way's end (his side
## of the gap) are tried with a straight walk toward the way's end or the
## goal: across the first stretch off the mesh to the mesh beyond (within
## BRIDGE m), his capsule passing, floor under every step, the near point
## joined to him and the far one to the goal. In the same order (goal
## first, then the walk across, then on to him); [] when there is no such
## gap.
func _bridged(start: Vector3, end: Vector3, back: PackedVector3Array) -> PackedVector3Array:
	var rim := back[back.size() - 1]
	var near_side: Array[Vector3] = []
	for radius: float in [0.8, 1.4, 2.0, 2.6, 3.2, 4.0, 4.8]:
		for k in 16:
			var angle := TAU * float(k) / 16.0
			var point := snap(rim + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
			if _flat(point - rim).length() < 0.5 or absf(point.y - rim.y) > 0.6 or _on_furniture(point):
				continue
			var seen := false
			for other in near_side:
				if other.distance_to(point) < 0.4:
					seen = true
					break
			if not seen:
				near_side.append(point)
	near_side.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a - rim).length() < _flat(b - rim).length())
	var asked := 0
	var probes := BRIDGE_PROBES
	for point in near_side:
		if not _free_at(point):
			continue
		# toward the way's end and the goal, then round the compass (a gap
		# is crossed square: a slant into a 1.1 m gap catches its sides)
		var headings: Array[Vector3] = [rim, end]
		for turn in 16:
			headings.append(point + Vector3(cos(TAU * turn / 16.0), 0.0, sin(TAU * turn / 16.0)) * BRIDGE)
		for toward in headings:
			probes -= 1
			if probes < 0:
				return PackedVector3Array()
			var far := _far_side(point, toward)
			if far == Vector3.INF or _on_furniture(far) or not clear_between(point, far) or not _floor_along(point, far) or not _free_at(far):
				continue
			asked += 1
			var way := _joined(start, end, point, far, back if far.distance_to(rim) < 0.05 else PackedVector3Array())
			if not way.is_empty():
				return way
			if asked >= BRIDGE_TRIES:
				return PackedVector3Array()
	return PackedVector3Array()


## The way goal first over the gap [param near] (his side) - [param far]
## (the goal's): the mesh from the goal to [param far] ([param to_goal]
## when known), the straight walk, the mesh from [param near] to him; []
## when either end is not joined, or the last 1.5 m of the leg up to either
## end of the walk runs into something the mesh does not know (an
## audio-guide stand at a gap's mouth). The walk is remembered.
func _joined(start: Vector3, end: Vector3, near: Vector3, far: Vector3, to_goal: PackedVector3Array = PackedVector3Array()) -> PackedVector3Array:
	var way := _joined_as(start, end, near, far, to_goal)
	if way.is_empty() and to_goal.is_empty():
		# the probe round the way's end may stand on the goal's side and
		# look out across the gap to his
		way = _joined_as(start, end, far, near)
	return way


func _joined_as(start: Vector3, end: Vector3, near: Vector3, far: Vector3, to_goal: PackedVector3Array = PackedVector3Array()) -> PackedVector3Array:
	var to_start := _query_back(near, start)
	if to_start.is_empty() or to_start[to_start.size() - 1].distance_to(start) > BACK:
		return PackedVector3Array()
	if to_goal.is_empty():
		to_goal = _query_back(end, far)
	if to_goal.is_empty() or to_goal[to_goal.size() - 1].distance_to(far) > BACK:
		return PackedVector3Array()
	if to_start.size() >= 2 and not clear_between(_toward(near, to_start[1], 1.5), near):
		return PackedVector3Array()
	if to_goal.size() >= 2 and not clear_between(_toward(far, to_goal[to_goal.size() - 2], 1.5), far):
		return PackedVector3Array()
	_remember_bridge(far, near)
	var out := to_goal.duplicate()
	out.append_array(_straight(far, near))
	out.append_array(to_start)
	return out


## The first point of the mesh beyond a stretch off it on the straight
## floor-plan line from [param from] toward [param toward] (within BRIDGE m
## and about level with it); INF when the line never leaves the mesh or
## finds none.
func _far_side(from: Vector3, toward: Vector3) -> Vector3:
	var dir := _flat(toward - from)
	var length := dir.length()
	if length < 0.5:
		return Vector3.INF
	dir /= length
	var left_mesh := false
	var d := 0.5
	while d <= minf(BRIDGE, length + 0.5):
		var at := from + dir * d
		var on := snap(at)
		if Vector2(on.x - at.x, on.z - at.z).length() > 0.3:
			left_mesh = true
		elif left_mesh and absf(on.y - from.y) < 0.6:
			return on
		d += 0.3
	return Vector3.INF


## Out of a pocket of the mesh he stands in by no known gap (knocked or
## fallen in): points of his own part round him, a straight walk from each
## every 30 degrees across the first stretch off the mesh, as _bridged();
## goal first; [] when none leads to the goal's part.
func _bridged_out(start: Vector3, end: Vector3) -> PackedVector3Array:
	var asked := 0
	for radius: float in [0.0, 1.0, 2.0]:
		for k in (1 if radius == 0.0 else 8):
			var angle := TAU * float(k) / 8.0
			var point := snap(start + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
			if absf(point.y - start.y) > 0.6 or not _free_at(point):
				continue
			for turn in 12:
				var heading := Vector3(cos(TAU * turn / 12.0), 0.0, sin(TAU * turn / 12.0))
				var far := _far_side(point, point + heading * BRIDGE)
				if far == Vector3.INF or _on_furniture(far) or not clear_between(point, far) or not _floor_along(point, far) or not _free_at(far):
					continue
				asked += 1
				var way := _joined(start, end, point, far)
				if not way.is_empty():
					return way
				if asked >= BRIDGE_TRIES:
					return PackedVector3Array()
	return PackedVector3Array()


## The point [param most] m (at most) from [param from] toward [param to].
static func _toward(from: Vector3, to: Vector3, most: float) -> Vector3:
	var length := from.distance_to(to)
	return to if length <= most else from.lerp(to, most / length)


## The points every half metre strictly between [param a] and [param b].
static func _straight(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps := maxi(int(ceil(_flat(b - a).length() / 0.5)), 1)
	for s in range(1, steps):
		out.append(a.lerp(b, float(s) / float(steps)))
	return out


func _remember_bridge(a: Vector3, b: Vector3) -> void:
	for known in bridges:
		if (known[0].distance_to(a) < 0.6 and known[1].distance_to(b) < 0.6) or (known[0].distance_to(b) < 0.6 and known[1].distance_to(a) < 0.6):
			return
	bridges.append(PackedVector3Array([a, b]))


## A way from [param end] (the goal, on the mesh) to [param start] over one
## of the gaps crossed tonight (the way he came into a pocket of the mesh is
## the way out of it - the way's own end may face another, closed side):
## goal first, as _bridged(); [] when none of them joins the two.
func _via_known_bridge(start: Vector3, end: Vector3) -> PackedVector3Array:
	for pair in bridges:
		for side in 2:
			var near := pair[side]
			var far := pair[1 - side]
			var to_near := _query_back(near, start)
			if to_near.is_empty() or to_near[to_near.size() - 1].distance_to(start) > BACK:
				continue
			var to_far := _query_back(end, far)
			if to_far.is_empty() or to_far[to_far.size() - 1].distance_to(far) > BACK:
				continue
			var out := to_far.duplicate()
			out.append_array(_straight(far, near))
			out.append_array(to_near)
			return out
	return PackedVector3Array()


## True when [param point] of the mesh lies on a piece's top (a desk, the
## card catalogue: well over its room's floor), not on a floor he walks.
func _on_furniture(point: Vector3) -> bool:
	if level == null:
		return false
	var room := level.layout.room(_room_of(point))
	return room != null and point.y - room.floor_y > 0.75


## True when he fits standing at [param point] (feet): nothing solid the
## navmesh does not know there (an audio-guide stand at a gap's mouth).
func _free_at(point: Vector3) -> bool:
	_stand.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.05)
	return space().intersect_shape(_stand, 1).is_empty()


## True when there is floor under every half metre from [param a] to [param b].
func _floor_along(a: Vector3, b: Vector3) -> bool:
	var steps := maxi(int(ceil(_flat(b - a).length() / 0.5)), 1)
	for s in steps + 1:
		var at := a.lerp(b, float(s) / float(steps))
		_ray.from = at + Vector3.UP * 0.6
		_ray.to = at - Vector3.UP * 1.0
		if space().intersect_ray(_ray).is_empty():
			return false
	return true


## The room at [param point] (&"" outside every room).
func _room_of(point: Vector3) -> StringName:
	return level.layout.room_at(point + Vector3.UP * 0.5) if level != null else &""


## [inside, outside] of room [param room_id]'s way out onto the walkable
## floor (the outside point on the navmesh); [] when none.
func _room_exit(room_id: StringName) -> PackedVector3Array:
	if _exits.has(room_id):
		return _exits[room_id]
	var best := PackedVector3Array()
	var best_off := 1.2
	for passage in level.layout.openings:
		if passage.room_a != room_id and passage.room_b != room_id:
			continue
		var frame := _builder.passage_frame(passage)   # +Z toward room A
		var outward := frame.basis.z if passage.room_b == room_id else -frame.basis.z
		var outside := frame.origin + outward * (passage.depth() * 0.5 + 1.0)
		var snapped := snap_walk(outside)
		var off := Vector2(snapped.x - outside.x, snapped.z - outside.z).length()
		if off < best_off and absf(snapped.y - outside.y) < 1.0:
			best_off = off
			# a door's leaf may stand open into the room beside its frame (the
			# havens' mesh does not know it): in through the middle, square to
			# the wall, from a leaf's length inside
			var door := level.doors.get(passage.id) as Door
			var inside := clampf(door.width + 0.5, 1.0, 2.6) if door != null else 1.0
			best = PackedVector3Array([frame.origin - outward * (passage.depth() * 0.5 + inside), snapped])
	if not best.is_empty():
		_exits[room_id] = best
	return best


## The length of [param points] (m).
static func length_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## Metres of walking to [param to] (INF: no way).
func distance_to(to: Vector3) -> float:
	var way := path_to(to, Vector3.INF, false)
	return length_of(way) if not way.is_empty() else INF


## True when his capsule (lifted over steps) moves from [param a] to
## [param b] (feet) without touching the building.
func clear_between(a: Vector3, b: Vector3) -> bool:
	_shape.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * 1.3)
	_shape.motion = Vector3(b.x - a.x, (b.y - a.y), b.z - a.z)
	var fraction := space().cast_motion(_shape)
	_shape.motion = Vector3.ZERO
	return fraction.size() == 2 and fraction[0] >= 0.999


## Starts walking to [param to] (arrived within [param within] m on the
## floor plan). False (FAILED, "no path") when there is no way.
func go(to: Vector3, within: float = 0.6) -> bool:
	reach = within
	goal = to
	path = _round_obstacles(path_to(to))
	index = 1
	walked = 0.0
	_stuck = 0
	_best = INF
	_since_best = 0.0
	_recover_left = 0.0
	if path.is_empty():
		status = Status.FAILED
		failure = "no path"
		return false
	status = Status.RUNNING
	failure = ""
	return true


func cancel() -> void:
	status = Status.IDLE
	path = PackedVector3Array()
	pilot.stop()


## True when the guard stands within [param within] m (floor plan) of
## [param point] and not far above or below it.
func at(point: Vector3, within: float) -> bool:
	return Vector2(point.x - feet().x, point.z - feet().z).length() <= within and absf(point.y - feet().y) < 1.6


## Metres of the way still to walk.
func remaining() -> float:
	if status != Status.RUNNING or path.is_empty():
		return 0.0
	var total := Vector2(path[mini(index, path.size() - 1)].x - feet().x, path[mini(index, path.size() - 1)].z - feet().z).length()
	for i in range(index + 1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


## One step of walking ([param delta] s of game time): steers the pilot
## along the way. Returns the status.
func update(delta: float) -> Status:
	if status != Status.RUNNING:
		return status
	walked += delta
	if at(goal, reach):
		status = Status.ARRIVED
		pilot.stop()
		return status
	while index < path.size() - 1 and _flat(path[index] - feet()).length() < WAYPOINT:
		index += 1
	var target := path[mini(index, path.size() - 1)]
	if index >= path.size() - 1 and _flat(target - feet()).length() < WAYPOINT:
		target = goal
	if feet().y < target.y - FALL_DROP and guard.is_on_floor():
		_replan("fell")
		return status
	var left := remaining()
	if left < _best - STALL_PROGRESS:
		_best = left
		_since_best = 0.0
	else:
		_since_best += delta
	if _recover_left > 0.0:
		_recover_left -= delta
		pilot.move(_recover_dir)
		return status
	if _since_best >= STALL_TIME:
		_on_stuck(target)
		return status
	var way := _flat(target - feet())
	pilot.move(way.normalized() if way.length() > 0.01 else Vector3.ZERO, may_sprint and left > SPRINT_LEFT and guard.stamina.current > guard.stamina.maximum * 0.3)
	return status


func _on_stuck(target: Vector3) -> void:
	_stuck += 1
	_since_best = 0.0
	var contacts := []
	var away := Vector3.ZERO
	for i in guard.get_slide_collision_count():
		var hit := guard.get_slide_collision(i)
		contacts.append(Floor1Walker.describe(hit.get_collider() as Node))
		var normal := hit.get_normal()
		if absf(normal.y) < 0.7:
			away += _flat(normal)
	var ahead_points := []
	for i in range(maxi(index - 1, 0), mini(index + 3, path.size())):
		ahead_points.append([snappedf(path[i].x, 0.1), snappedf(path[i].y, 0.1), snappedf(path[i].z, 0.1)])
	stuck_events.append({"at": feet(), "toward": target, "contacts": contacts, "try": _stuck, "path": ahead_points})
	if _stuck > MAX_STUCK:
		status = Status.FAILED
		failure = "stuck"
		pilot.stop()
		return
	# a thing in the way the navmesh does not know (a coffin a mummy stood
	# up at its post, an open door's leaf): remember it and go round it
	for i in guard.get_slide_collision_count():
		var hit := guard.get_slide_collision(i)
		if absf(hit.get_normal().y) < 0.7 and _learn_obstacle(hit.get_collider() as Node):
			_replan("stuck")
			return
	var ahead := _flat(target - feet()).normalized()
	var side := Vector3(-ahead.z, 0.0, ahead.x) * (1.0 if _stuck % 2 == 1 else -1.0)
	match _stuck % 3:
		1:
			# off what holds him, a little to the side, and a hop
			pilot.tap(&"jump")
			_recover_dir = (away.normalized() * 0.8 + side * 0.6).normalized() if away.length() > 0.01 else side
			_recover_left = 0.35
		2:
			_recover_dir = (side - ahead * 0.5).normalized()
			_recover_left = 0.5
		0:
			_replan("stuck")


## Remembers [param body] as an obstacle the ways go round when it is a
## small thing (no wall: at most OBSTACLE_SIZE m across) not known yet.
func _learn_obstacle(body: Node) -> bool:
	var solid := body as Node3D
	if solid == null or not solid.is_inside_tree():
		return false
	var area := LevelNavigation.source_area(solid)
	if area.size.x > OBSTACLE_SIZE or area.size.z > OBSTACLE_SIZE or area.size.x <= 0.0:
		return false
	for known in obstacles:
		if known.grow(0.1).intersects(area):
			return false
	obstacles.append(area)
	return true


## [param points] with a way round every known obstacle a leg crosses.
func _round_obstacles(points: PackedVector3Array) -> PackedVector3Array:
	if obstacles.is_empty() or points.size() < 2:
		return points
	var out := PackedVector3Array([points[0]])
	for i in range(1, points.size()):
		var a := out[out.size() - 1]
		var b := points[i]
		for box in obstacles:
			if not _leg_crosses(a, b, box):
				continue
			for detour in _detour(a, b, box):
				out.append(detour)
			break
		out.append(b)
	return out


## True when the floor-plan leg [param a] -> [param b] passes through
## [param box] grown by the guard's radius and a margin.
static func _leg_crosses(a: Vector3, b: Vector3, box: AABB) -> bool:
	if b.y < box.position.y - 1.0 or a.y > box.end.y + 0.5:
		return false
	var grown := Rect2(box.position.x - OBSTACLE_MARGIN, box.position.z - OBSTACLE_MARGIN, box.size.x + OBSTACLE_MARGIN * 2.0, box.size.z + OBSTACLE_MARGIN * 2.0)
	var steps := maxi(int(Vector2(b.x - a.x, b.z - a.z).length() / 0.2), 1)
	for k in steps + 1:
		var t := float(k) / steps
		if grown.has_point(Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t))):
			return true
	return false


## Two points round [param box] on the side of the leg [param a] -> [param b]
## its middle is not on, on the navmesh (the other side when that one is walled).
func _detour(a: Vector3, b: Vector3, box: AABB) -> PackedVector3Array:
	var dir := _flat(b - a).normalized()
	var across := Vector3(-dir.z, 0.0, dir.x)
	var center := box.get_center()
	center.y = a.y
	var radius := maxf(box.size.x, box.size.z) * 0.5 + OBSTACLE_MARGIN + 0.2
	var first := -1.0 if (center - a).dot(across) > 0.0 else 1.0
	for side: float in [first, -first]:
		var points := PackedVector3Array()
		for along: float in [-radius, radius]:
			var want := center + across * side * radius + dir * along
			var on := snap_walk(want)
			# on the floor beside it, not on a desk's top the mesh also covers
			if Vector2(on.x - want.x, on.z - want.z).length() > 0.45 or absf(on.y - a.y) > 0.4:
				points.clear()
				break
			points.append(on)
		if points.size() == 2:
			return points
	return PackedVector3Array()


func _replan(why: String) -> void:
	var to := goal
	var within := reach
	var stuck := _stuck
	var events := stuck_events
	if not go(to, within):
		failure = why if why != "" else failure
	_stuck = stuck
	stuck_events = events


# --- where to stand -----------------------------------------------------------------------------------

## Candidate floor spots round [param center] between [param near] and
## [param far] m (floor plan), nearest to the guard first: navmesh points
## on rings round it, snapped.
func spots_round(center: Vector3, near: float, far: float, floor_y: float = INF) -> PackedVector3Array:
	var found := PackedVector3Array()
	var low := center.y - 1.6 if floor_y == INF else floor_y
	var radii: Array[float] = []
	var r := maxf(near, 0.6)
	var stride := clampf((far - near) / 3.0, 0.5, 1.5)
	while r <= far + 0.01:
		radii.append(r)
		r += stride
	for radius in radii:
		var around := maxi(16, int(TAU * radius / 1.2))
		for k in around:
			var angle := TAU * float(k) / float(around)
			var probe := Vector3(center.x + cos(angle) * radius, low, center.z + sin(angle) * radius)
			var point := snap(probe)
			if point.distance_to(probe) > 0.9:
				continue
			var flat := Vector2(point.x - center.x, point.z - center.z).length()
			if flat < near - 0.3 or flat > far + 0.3:
				continue
			var near_one := false
			for other in found:
				if other.distance_to(point) < 0.5:
					near_one = true
					break
			if not near_one:
				found.append(point)
	var from := feet()
	var sorted := Array(found)
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(from) < b.distance_to(from))
	return PackedVector3Array(sorted)


## The first spot of [param spots] whose eye (eye height over it) passes
## [param works] and that he can walk to; Vector3.INF for none. At most
## [param tries] ways asked; a way over a gap of the mesh (a dais or a
## pocket ringed by pieces) looked for only when no spot has a plain one,
## for the first SPOT_SEARCHES that work.
func first_spot(spots: PackedVector3Array, works: Callable, tries: int = 12) -> Vector3:
	var asked := 0
	var working := PackedVector3Array()
	for spot in spots:
		if not works.call(spot + Vector3.UP * guard.eye_height):
			continue
		if not path_to(spot, Vector3.INF, false).is_empty():
			return spot
		if working.size() < SPOT_SEARCHES:
			working.append(spot)
		asked += 1
		if asked >= tries:
			break
	for spot in working:
		if not path_to(spot).is_empty():
			return spot
	return Vector3.INF


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
