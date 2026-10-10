class_name PerceptionRules
extends RefCounted
## The numbers and pure geometry of how exhibits notice the guard (design:
## pietro-1-projekt 7.2). No nodes here: Enemy and PerceptionWorld feed in
## positions, facings, light levels, rooms and doors.
## - Sight: a cone in front (120 degrees; busts and portraits 160) plus a
##   close sense all around; its reach depends on how lit the guard is
##   (lit 22 m, half-dark 12 m, dark 7 m). A sleeping exhibit sees at
##   DORMANT_SCALE of that.
## - Hearing: every noise has a radius; it carries through open passages
##   only, PASSAGE_DAMPING per passage, at most MAX_HOPS passages.
## - Territory: home room plus the rooms behind its plain doors; the leash
##   is a distance from home.

## Sight cone (full angle, degrees).
const CONE_DEG := 120.0
## Busts, portraits (and later totems): a wider cone.
const WIDE_CONE_DEG := 160.0
## The close sense (m): noticed all around within this.
const CLOSE_SENSE := 3.5
## Sight range by how lit the guard is (m).
const LIT_RANGE := 22.0
const DIM_RANGE := 12.0
const DARK_RANGE := 7.0
## Light levels (0..1, LayoutIllumination) where the bands start.
const LIT_LEVEL := 0.45
const DIM_LEVEL := 0.15
## A sleeping exhibit notices at this share of the range and close sense.
const DORMANT_SCALE := 0.6

## How far each weapon is heard (m); unknown ids get DEFAULT_WEAPON_NOISE.
const WEAPON_NOISE := {
	&"fists": 6.0, &"taser": 6.0, &"pistol": 18.0, &"rifle_hunt": 24.0, &"shotgun": 22.0,
	&"harpoon": 12.0, &"gatling": 30.0, &"hwacha": 30.0, &"flare": 15.0,
}
const DEFAULT_WEAPON_NOISE := 18.0
## Other noises (m): a sprint step or a landing, broken glass and the fire
## cabinet, an explosion.
const STEP_NOISE := 7.0
const GLASS_NOISE := 16.0
const BLAST_NOISE := 30.0
## Loudness kept per open passage, and how many passages a noise crosses.
const PASSAGE_DAMPING := 0.6
const MAX_HOPS := 4

## Leash (m from home on the floor plan); wolves and raptors hunt further.
const LEASH := 28.0
const HUNTER_LEASH := 40.0
## Chain waking: radius (m) and how many one exhibit may wake.
const CHAIN_RADIUS := 8.0
const CHAIN_MAX := 2
## At most this many exhibits hunt within HUNT_RADIUS of the guard.
const HUNTER_CAP := 8
const HUNT_RADIUS := 30.0
## Difficulty (design 7.5): [sight scale, hunter cap] per level
## (0 calm shift, 1 night shift, 2 double shift).
const DIFFICULTY: Array = [[0.75, 8], [1.0, 8], [1.15, 10]]

## Patrol routes: points this far from the post (tried first far, then near).
const PATROL_REACH: Array[float] = [6.0, 3.0]
const PATROL_POINTS := 3


## Sight range for a guard lit at [param light] (0..1), scaled from an
## exhibit's own lit range [param lit_range].
static func sight_range(light: float, lit_range: float = LIT_RANGE) -> float:
	var scale := lit_range / LIT_RANGE
	if light >= LIT_LEVEL:
		return LIT_RANGE * scale
	return (DIM_RANGE if light >= DIM_LEVEL else DARK_RANGE) * scale


## True when [param to_target] (flat) lies within the [param cone_deg] cone
## around [param facing]. A zero vector counts as inside.
static func in_cone(facing: Vector3, to_target: Vector3, cone_deg: float) -> bool:
	var look := Vector2(facing.x, facing.z)
	var to := Vector2(to_target.x, to_target.z)
	if look.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return true
	return look.normalized().dot(to.normalized()) >= cos(deg_to_rad(cone_deg * 0.5))


## Range, cone and close sense together (no line of sight: the caller casts
## the ray when this says yes).
static func sees(facing: Vector3, to_target: Vector3, cone_deg: float, reach: float, close: float) -> bool:
	var distance := to_target.length()
	if distance > reach:
		return false
	return distance <= minf(close, reach) or in_cone(facing, to_target, cone_deg)


static func weapon_noise(weapon_id: StringName) -> float:
	return WEAPON_NOISE.get(weapon_id, DEFAULT_WEAPON_NOISE)


## Room -> loudness kept there for a noise in [param from_room]: 1 in the
## room itself, PASSAGE_DAMPING per passage on the shortest way through
## open passages ([param door_open] (passage id) -> bool; invalid = all
## open). Rooms behind closed doors are missing.
static func hearing_rooms(graph: RoomGraph, from_room: StringName, door_open: Callable) -> Dictionary:
	var reach := {from_room: 1.0}
	if graph == null or not graph.has_room(from_room):
		return reach
	var frontier: Array[StringName] = [from_room]
	for hop in MAX_HOPS:
		var next: Array[StringName] = []
		for room in frontier:
			for door in graph.doors_of_room(room):
				if door_open.is_valid() and not door_open.call(door):
					continue
				var ends := graph.door_rooms(door)
				var other: StringName = ends[1] if ends[0] == room else ends[0]
				if not reach.has(other):
					reach[other] = pow(PASSAGE_DAMPING, hop + 1)
					next.append(other)
		frontier = next
	return reach


## A noise of [param radius] kept at [param loudness] is heard
## [param distance] away.
static func heard(distance: float, radius: float, loudness: float) -> bool:
	return loudness > 0.0 and distance <= radius * loudness


## Home room plus the rooms behind its plain (OPEN / LOCKABLE) doors; never
## through false panels or gates. No graph: the home room alone.
static func territory(graph: RoomGraph, home_room: StringName) -> Array[StringName]:
	var rooms: Array[StringName] = []
	if home_room == &"":
		return rooms
	rooms.append(home_room)
	if graph == null or not graph.has_room(home_room):
		return rooms
	var hidden := graph.doors_of_kind(RoomGraph.Kind.SECRET) + graph.doors_of_kind(RoomGraph.Kind.GATE)
	for door in graph.doors_of_room(home_room):
		if hidden.has(door):
			continue
		var ends := graph.door_rooms(door)
		var other: StringName = ends[1] if ends[0] == home_room else ends[0]
		if not rooms.has(other):
			rooms.append(other)
	return rooms


## True when [param position] lies beyond [param leash] metres of
## [param home] (floor plan) or in a known room outside [param rooms]
## (empty = no room rule).
static func out_of_bounds(position: Vector3, home: Vector3, leash: float, room: StringName, rooms: Array[StringName]) -> bool:
	if Vector2(position.x - home.x, position.z - home.z).length() > leash:
		return true
	return not rooms.is_empty() and room != &"" and not rooms.has(room)


## A patrol loop from [param home]: the post and up to PATROL_POINTS points
## around it (PATROL_REACH away, eight directions) that lie in
## [param home_room] ([param room_of] (point) -> room). Empty when there
## are no rooms or no point fits: the exhibit keeps its post.
static func patrol_route(home: Vector3, home_room: StringName, room_of: Callable) -> PackedVector3Array:
	var route := PackedVector3Array()
	if home_room == &"" or not room_of.is_valid():
		return route
	var found: Array[Vector3] = []
	for reach in PATROL_REACH:
		for i in 8:
			var angle := TAU * i / 8.0
			var point := home + Vector3(cos(angle), 0.0, sin(angle)) * reach
			if room_of.call(point) == home_room:
				found.append(point)
	if found.is_empty():
		return route
	# spread out: the first point, then each time the one farthest from those taken
	var picked: Array[Vector3] = [found[0]]
	while picked.size() < mini(PATROL_POINTS, found.size()):
		var best := found[0]
		var best_gap := -1.0
		for point in found:
			if picked.has(point):
				continue
			var gap := INF
			for taken in picked + [home]:
				gap = minf(gap, point.distance_to(taken))
			if gap > best_gap:
				best_gap = gap
				best = point
		picked.append(best)
	route.append(home)
	for point in picked:
		route.append(point)
	return route
