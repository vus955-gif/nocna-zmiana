class_name Floor1Survey
extends Node3D
## The built Floor I for the W7 checks (tests only; plan
## docs/superpowers/plans/2026-10-03-p1-w7-weryfikacja.md): the floor
## (MuseumFloorLevel), its real gate locks (GateController on the save) and
## the walkable navmesh (every box region of LevelNavigation) as a
## Floor1NavGraph for any set of open gates - one synchronous bake
## (LevelNavigation.bake_now) per new set, kept by the set's key (the
## same set again costs nothing). The mesh is the game's own (what the
## exhibits walk). Where it misses a passage the guard walks - an open
## doorway (an open swing leaf along its jamb narrows a 1.5 m door below the
## agent's 1 m; the guard, radius 0.4, walks through) or a flight of stairs
## (a 20.6 degree ramp rises 0.094 m a 0.25 m cell against a 0.1 m climb:
## the mesh joins a stair's foot only when the voxels fall right) - the
## survey joins the two sides (Floor1NavGraph.join) and lists the place in
## [member breaks]: the guard passes, the exhibits cannot.
## It answers what the guard reaches on foot from a haven (the haven's own
## floor is another region: he starts just outside its door, so nothing
## counts that lies only through a haven), whether he can work a gate's
## lock from the side that opens it (the game's own use probe - Interactor
## - and shot rays - Hitscan - against the lock's prompt and hit zones),
## whether a marker is within his reach, and how long a walk is. Every
## answer the graph gives is confirmed on the NavigationServer's map
## through NavProbe (no search budget, goal to start first: no engine error
## on a prop-top island).

const NavProbe := preload("res://tests/support/nav_probe.gd")

## The guard's eye over his feet (Player.eye_height).
const EYE := 1.6
## Chains and boards with the shotgun: close enough for most pellets.
const SHOTGUN_REACH := 8.0
## A flare's blast breaks boards from where its flight stays true.
const FLARE_BLAST_REACH := 30.0
## A fire-arrow volley (12 degree fan): at this range at least two rockets
## still land on a 2 m wall (the cracked lock sums 40 within 0.3 s).
const HWACHA_REACH := 25.0
## A shot counts where it lands this close to the point aimed at.
const AIM_SLACK := 0.6
## Standing points tried per lock or marker (closest first, then sparser).
const MAX_TRIES := 700
## A squeeze into a tight gap starts at most this far from the navmesh.
const SQUEEZE := 4.0
## The haven's way out: this far beyond its door.
const EXIT_REACH := 1.0
## A passage's two sides are looked for this far beyond its wall faces
## (and this close above or below its floor).
const SIDE_REACH := 0.75
const SIDE_HEIGHT := 0.6

var level: MuseumFloorLevel
var gates: GateController
var graph: Floor1NavGraph
## Gates open now (sorted) and the night doors shut now.
var open_gates: Array[StringName] = []
var shut_doors: Array[StringName] = []
## Doors that are no gate but start shut (false panels, grates): opened
## with use_gates(..., hidden = true).
var hidden_doors: Array[StringName] = []
var hidden_open := false
## The passages the mesh misses in the current state (joined in the
## graph): {what, a, b} - a and b the navmesh points on its two sides.
var breaks: Array[Dictionary] = []
## Baked component -> a navmesh point in it where a joined passage lands
## (the map confirms walks inside a component from there).
var entries: Dictionary = {}
var bakes: int = 0
var bake_msec: int = 0
var fist_reach: float = 1.7
var rifle_range: float = 150.0
var harpoon_range: float = 45.0

## [origin, normal, wall depth] of the side lock_reach() is asked about
## ([] = any).
var _side: Array = []
## Key -> [the walkable boxes' meshes, Floor1NavGraph, room -> polygons,
## breaks, entries].
var _cache: Dictionary = {}
var _rooms_of_polygons: Dictionary = {}
var _builder: LevelBuilder
## Vector2i bucket -> Array of RoomSpec.
var _room_buckets: Dictionary = {}
var _interactor := Interactor.new()


## Builds the floor (gates shut) and its locks.
func setup() -> void:
	name = "Survey"
	level = MuseumFloorLevel.new()
	# as the game builds it: the greybox stand-ins of real locks left out
	level.skip_kits = GateLocks.replaced_kits()
	add_child(level)
	level.build()
	# this survey bakes by itself: no asynchronous rebake when a door moves
	for door: Door in level.doors.values():
		for connection: Dictionary in door.nav_blocking_changed.get_connections():
			door.nav_blocking_changed.disconnect(connection["callable"])
		if level.layout.gate_of_opening(door.id) == null and (door.style == OpeningSpec.DoorStyle.PANEL or door.style == OpeningSpec.DoorStyle.GATE):
			hidden_doors.append(door.id)
	_builder = LevelBuilder.new(level.layout, null, null, null)
	_index_rooms()
	fist_reach = _range_of(&"fists", fist_reach)
	rifle_range = _range_of(&"rifle_hunt", rifle_range)
	harpoon_range = _range_of(&"harpoon", harpoon_range)
	_make_locks()
	await use_gates([])


static func _range_of(weapon: StringName, fallback: float) -> float:
	var data := load("res://src/weapons/data/%s.tres" % weapon) as WeaponData
	return data.max_range if data != null else fallback


func _make_locks() -> void:
	if gates != null:
		# a lock's walkable part handed to the navigation (the canoe's deck)
		# goes with it
		for lock: Node in gates.locks.values():
			var deck := lock.get(&"bridge") as Node if is_instance_valid(lock) and &"bridge" in lock else null
			if deck != null and is_instance_valid(deck) and not lock.is_ancestor_of(deck):
				deck.free()
		remove_child(gates)
		gates.free()
	gates = GateController.new()
	add_child(gates)
	# the locks follow the level's open gates only: nothing from the save
	# (an open gate or the power flag there would open locks and doors)
	GameState.gates_open.clear()
	GameState.flags.clear()
	gates.setup(level, GameState, RunState)
	# this survey bakes by itself: no rebake round the new deck later
	level.navigation._dirty.clear()


# --- the state of the floor -----------------------------------------------------------

## Opens exactly the gates [param open] (every other gate shut and locked),
## shuts the night doors [param night_doors], opens the hidden doors (false
## panels) when [param hidden]; then the navmesh of that state (baked once
## per state) on the map and in [member graph], its passages joined.
func use_gates(open: Array[StringName], night_doors: Array[StringName] = [], hidden: bool = false) -> void:
	var wanted: Array[StringName] = open.duplicate()
	wanted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	# a lock opened once never shuts again: a smaller set needs fresh locks
	var fresh := false
	for gate_id in open_gates:
		if not wanted.has(gate_id):
			fresh = true
	level.gates_open = wanted.duplicate()
	if fresh:
		_make_locks()
	for spec in level.layout.gates:
		if spec.opening == &"" or not level.doors.has(spec.opening):
			continue
		var door: Door = level.doors[spec.opening]
		if wanted.has(spec.id):
			door.unlock()
			door.open(true)
			var lock := gates.lock_of(spec.id)
			if lock != null and not bool(lock.get(&"is_open")):
				lock.call(&"open_instantly")
		else:
			door.lock(true)
	for door_id in hidden_doors:
		var door: Door = level.doors[door_id]
		if hidden:
			door.unlock()
			door.open(true)
		else:
			door.close(true)
	for door_id: StringName in level.doors:
		var door: Door = level.doors[door_id]
		if door.link != RoomGraph.Kind.LOCKABLE:
			continue
		if night_doors.has(door_id):
			door.lock(true)
		else:
			door.unlock()
			door.open(true)
	open_gates = wanted
	shut_doors = night_doors.duplicate()
	hidden_open = hidden
	var key := "%s|%s|%s" % [",".join(wanted), ",".join(night_doors), hidden]
	var regions := level.navigation.regions
	if _cache.has(key):
		var entry: Array = _cache[key]
		var meshes: Array = entry[0]
		for i in regions.size():
			regions[i].navigation_mesh = meshes[i]
		graph = entry[1]
		_rooms_of_polygons = entry[2]
		breaks = entry[3]
		entries = entry[4]
	else:
		var started := Time.get_ticks_msec()
		level.navigation.bake_now()
		bake_msec += Time.get_ticks_msec() - started
		bakes += 1
		var meshes: Array = []
		for region in regions:
			meshes.append(region.navigation_mesh)
		graph = Floor1NavGraph.from_meshes(meshes, NavigationServer3D.map_get_edge_connection_margin(map()))
		_rooms_of_polygons = _room_polygons()
		_join_passages()
		_cache[key] = [meshes, graph, _rooms_of_polygons, breaks, entries]
	# the map takes the region's new mesh in the next physics step
	await get_tree().physics_frame
	await get_tree().physics_frame


func map() -> RID:
	return level.walk_region.get_navigation_map()


## Joins the two sides of every open doorway (no door, or its door open,
## the guard's capsule fitting through) and of every flight of stairs where
## the mesh has floor on both sides but the baked components differ.
func _join_passages() -> void:
	breaks = []
	entries = {}
	var space := get_world_3d().direct_space_state
	for passage in level.layout.openings:
		var door: Door = level.doors.get(passage.id)
		if door != null and not door.is_open:
			continue
		var frame := _builder.passage_frame(passage)   # +Z toward room A
		var reach := passage.depth() * 0.5 + SIDE_REACH
		var a := frame.origin + frame.basis.z * reach
		var b := frame.origin - frame.basis.z * reach
		if _capsule_blocked(space, frame.origin):
			continue
		_join_sides(String(passage.id), a, b, passage.floor_y, passage.floor_y)
	for flight in level.layout.stairs:
		var frame := flight.frame()   # -Z up the flight
		var foot := frame.origin + frame.basis.z * SIDE_REACH
		var top := frame.origin - frame.basis.z * (flight.run() + SIDE_REACH) + Vector3.UP * (flight.top_y - flight.bottom_y)
		_join_sides(String(flight.id), foot, top, flight.bottom_y, flight.top_y)


func _join_sides(what: String, a: Vector3, b: Vector3, a_floor: float, b_floor: float) -> void:
	var pa := _floor_polygon(a, a_floor)
	var pb := _floor_polygon(b, b_floor)
	if pa < 0 or pb < 0 or graph.base_component[pa] == graph.base_component[pb]:
		return
	var on_a := graph.closest_on(pa, a)
	var on_b := graph.closest_on(pb, b)
	for side: Array in [[pa, on_a], [pb, on_b]]:
		if not entries.has(graph.base_component[side[0]]):
			entries[graph.base_component[side[0]]] = side[1]
	graph.join(pa, pb)
	breaks.append({"what": what, "a": on_a, "b": on_b})


## The navmesh polygon on the floor at [param point] (its floor at
## [param floor_y]; the mesh lies a little over the floor).
func _floor_polygon(point: Vector3, floor_y: float) -> int:
	var at := Vector3(point.x, floor_y + 0.2, point.z)
	var p := graph.closest_polygon(at, -1, 1.0)
	if p < 0:
		return -1
	var on := graph.closest_on(p, at)
	return p if absf(on.y - floor_y) <= SIDE_HEIGHT else -1


## True when the guard's capsule standing at [param floor_point] touches
## the world (a door's leaf or a lock in the way).
func _capsule_blocked(space: PhysicsDirectSpaceState3D, floor_point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	query.transform = Transform3D(Basis.IDENTITY, floor_point + Vector3.UP * 1.0)
	return not space.intersect_shape(query, 1).is_empty()


# --- rooms ------------------------------------------------------------------------------

## The room at [param point] (LevelLayout.room_at, through buckets).
func room_of(point: Vector3) -> StringName:
	var best: RoomSpec = null
	for room: RoomSpec in _room_buckets.get(_bucket(point), []):
		if room.contains(point) and (best == null or room.floor_y > best.floor_y):
			best = room
	return best.id if best != null else &""


## Room id -> true for every room with walkable floor on component
## [param comp].
func rooms_on(comp: int) -> Dictionary:
	var found := {}
	for room_id: StringName in _rooms_of_polygons:
		for p in _rooms_of_polygons[room_id] as PackedInt32Array:
			if graph.component[p] == comp:
				found[room_id] = true
				break
	return found


## A navmesh point of component [param comp] inside room [param room_id],
## the one nearest the room's middle (Vector3.INF when the room has no
## floor there).
func room_point(room_id: StringName, comp: int) -> Vector3:
	var room := level.layout.room(room_id)
	if room == null:
		return Vector3.INF
	var middle := room.parts[0].get_center()
	var best := Vector3.INF
	var best_distance := INF
	for p in _rooms_of_polygons.get(room_id, PackedInt32Array()) as PackedInt32Array:
		if graph.component[p] != comp:
			continue
		var at := graph.centers[p]
		var distance := Vector2(at.x, at.z).distance_squared_to(middle)
		if distance < best_distance:
			best_distance = distance
			best = at
	return best


func _room_polygons() -> Dictionary:
	var found := {}
	for p in graph.polygons.size():
		var room_id := room_of(graph.centers[p] + Vector3.UP * 0.3)
		if room_id == &"":
			continue
		if not found.has(room_id):
			found[room_id] = PackedInt32Array()
		var list: PackedInt32Array = found[room_id]
		list.append(p)
		found[room_id] = list
	return found


func _index_rooms() -> void:
	for room in level.layout.rooms:
		var box := room.bounds()
		for bx in range(floori(box.position.x / Floor1NavGraph.BUCKET), floori(box.end.x / Floor1NavGraph.BUCKET) + 1):
			for bz in range(floori(box.position.y / Floor1NavGraph.BUCKET), floori(box.end.y / Floor1NavGraph.BUCKET) + 1):
				var cell := Vector2i(bx, bz)
				if not _room_buckets.has(cell):
					_room_buckets[cell] = []
				(_room_buckets[cell] as Array).append(room)


static func _bucket(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / Floor1NavGraph.BUCKET), floori(point.z / Floor1NavGraph.BUCKET))


# --- havens ---------------------------------------------------------------------------

## The points just outside the doors of haven [param haven_id]'s room, on
## the walkable navmesh (any component).
func haven_exits(haven_id: StringName) -> PackedVector3Array:
	var haven := Floor1Plan.haven(haven_id)
	var found := PackedVector3Array()
	if haven == null:
		return found
	for passage in level.layout.openings:
		if passage.room_a != haven.room and passage.room_b != haven.room:
			continue
		var frame := _builder.passage_frame(passage)   # +Z toward room A
		var outward := frame.basis.z if passage.room_b == haven.room else -frame.basis.z
		var beyond := frame.origin + outward * (passage.depth() * 0.5 + EXIT_REACH)
		var snapped := graph.closest(beyond, -1, 1.5)
		if snapped != Vector3.INF:
			found.append(snapped)
	return found


## Where a night in haven [param haven_id] starts on foot: its first way
## out (Vector3.INF when it has none on the navmesh).
func haven_start(haven_id: StringName) -> Vector3:
	var exits := haven_exits(haven_id)
	return exits[0] if not exits.is_empty() else Vector3.INF


## True when the NavigationServer's map confirms the walk from
## [param start] to [param point] (navmesh points of one joined
## component): straight when they share a baked component, else from the
## landing of the passage that joined the point's baked component.
func confirmed(start: Vector3, point: Vector3) -> bool:
	var p := graph.closest_polygon(point, -1, 0.6)
	var s := graph.closest_polygon(start, -1, 0.6)
	if p < 0 or s < 0:
		return false
	var from := start
	if graph.base_component[p] != graph.base_component[s]:
		from = entries.get(graph.base_component[p], Vector3.INF)
		if from == Vector3.INF:
			return false
	return NavProbe.connected(map(), from, point, LevelNavigation.WALK_LAYER)


## A marker in haven [param haven_id]'s room within [param reach] of the
## guard's eye, walked to from the haven's door on the haven's own navmesh
## (layer HAVEN): {ok, point, distance}.
func haven_reach(haven_id: StringName, at: Vector3, reach: float) -> Dictionary:
	var haven := Floor1Plan.haven(haven_id)
	var room := level.layout.room(haven.room) if haven != null else null
	if room == null:
		return _no("no haven")
	var region := level.haven_region.get_rid()
	var inner := Vector3.INF
	for passage in level.layout.openings:
		if passage.room_a != haven.room and passage.room_b != haven.room:
			continue
		var frame := _builder.passage_frame(passage)   # +Z toward room A
		var inward := -frame.basis.z if passage.room_b == haven.room else frame.basis.z
		inner = NavigationServer3D.region_get_closest_point(region, frame.origin + inward * (passage.depth() * 0.5 + EXIT_REACH))
		break
	if inner == Vector3.INF:
		return _no("no door")
	var best := _no("unreachable")
	for ring: float in [0.6, 1.0, 1.5, 2.0]:
		for k in 12:
			var probe := Vector3(at.x + cos(TAU * k / 12.0) * ring, room.floor_y, at.z + sin(TAU * k / 12.0) * ring)
			var snapped := NavigationServer3D.region_get_closest_point(region, probe)
			if Vector2(snapped.x - probe.x, snapped.z - probe.z).length() > 0.35 or absf(snapped.y - room.floor_y) > 0.5:
				continue
			var distance := (snapped + Vector3.UP * EYE).distance_to(at)
			if distance > reach or distance >= float(best["distance"]):
				continue
			if NavProbe.connected(map(), inner, snapped, LevelNavigation.HAVEN_LAYER):
				best = {"ok": true, "how": "haven", "point": snapped, "distance": distance}
	return best


# --- reach ----------------------------------------------------------------------------

## Can the guard standing on component [param comp] reach [param at]?
## [param kind]: &"use" - his eye within [param reach] with nothing solid
## in between short of the thing itself (it may sit in a cabinet); &"floor"
## - the navmesh within [param reach] beside it (height within 1 m);
## &"near" - the navmesh within [param reach]. With [param floor_y] (the
## marker's room floor) a &"use" marker in a gap too tight for the navmesh
## is tried on the guard's own capsule (_squeeze_reach). Returns {ok,
## point (where he stands), distance}.
func marker_reach(at: Vector3, comp: int, kind: StringName, reach: float, floor_y: float = INF) -> Dictionary:
	if kind == &"floor" or kind == &"near":
		var p := graph.closest_polygon(at, comp, reach + 1.0)
		if p < 0:
			return {"ok": false, "point": Vector3.INF, "distance": INF}
		var on := graph.closest_on(p, at)
		var flat := Vector2(on.x - at.x, on.z - at.z).length()
		var ok := on.distance_to(at) <= reach if kind == &"near" else flat <= reach and absf(on.y - at.y) <= 1.0
		return {"ok": ok, "point": on, "distance": on.distance_to(at)}
	var space := get_world_3d().direct_space_state
	var best := {"ok": false, "point": Vector3.INF, "distance": INF}
	var tries := 0
	for stand in graph.stand_points(comp, at, reach + 0.5):
		var eye := stand + Vector3.UP * EYE
		var distance := eye.distance_to(at)
		if distance > reach:
			continue
		tries += 1
		if tries > MAX_TRIES:
			break
		if _sees(space, eye, at):
			if distance < float(best["distance"]):
				best = {"ok": true, "point": stand, "distance": distance}
			if tries > 40:
				break
	if not best["ok"] and floor_y != INF:
		best = _squeeze_reach(space, at, comp, reach, floor_y)
	return best


## Nothing solid between [param eye] and [param at] short of the thing on
## the marker itself (it may sit in a cabinet).
func _sees(space: PhysicsDirectSpaceState3D, eye: Vector3, at: Vector3) -> bool:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, Layers.WORLD))
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(at) <= Floor1Route.PROP_SLACK


## A marker in a gap narrower than the navmesh's agent (1 m) but wide
## enough for the guard (0.8 m): a floor point within reach where his
## capsule stands free, walked to in a straight line (a capsule cast)
## from a navmesh point of component [param comp] at most SQUEEZE m away.
func _squeeze_reach(space: PhysicsDirectSpaceState3D, at: Vector3, comp: int, reach: float, floor_y: float) -> Dictionary:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	var lift := Vector3.UP * 1.0
	for ring: float in [0.5, 0.8, 1.2, 1.6, 2.0]:
		for k in 16:
			var spot := Vector3(at.x + cos(TAU * k / 16.0) * ring, floor_y, at.z + sin(TAU * k / 16.0) * ring)
			var eye := spot + Vector3.UP * EYE
			if eye.distance_to(at) > reach or not _sees(space, eye, at):
				continue
			query.transform = Transform3D(Basis.IDENTITY, spot + lift)
			query.motion = Vector3.ZERO
			if not space.intersect_shape(query, 1).is_empty():
				continue
			var from := graph.closest(spot, comp, SQUEEZE)
			if from == Vector3.INF:
				continue
			from.y = floor_y
			query.transform = Transform3D(Basis.IDENTITY, from + lift)
			query.motion = spot - from
			var fractions := space.cast_motion(query)
			if fractions.size() == 2 and fractions[0] >= 0.999:
				return {"ok": true, "how": "squeeze", "point": spot, "distance": eye.distance_to(at)}
	return _no("unreachable")


## Can the guard on component [param comp] with [param progress] open gate
## [param spec] (only from the side of room [param from_room], when given)?
## Returns {ok, how, point, distance}: how = the tool (or why not:
## "requirement", "unreachable", "no lock").
func lock_reach(spec: GateSpec, progress: FloorProgress, comp: int, from_room: StringName = &"") -> Dictionary:
	_side = []
	if from_room != &"":
		var passage := level.layout.opening(spec.opening)
		if passage == null or (from_room != passage.room_a and from_room != passage.room_b):
			return _no("no such side")
		var frame := _builder.passage_frame(passage)   # +Z toward room A
		# out of the doorway: the guard (radius 0.4) stands in front of the wall
		_side = [frame.origin, frame.basis.z if from_room == passage.room_a else -frame.basis.z, passage.depth() * 0.5 + 0.4]
	var found := _lock_reach(spec, progress, comp)
	_side = []
	return found


## Standing on the side of [member _side] (when set): in that room, in
## front of the wall (not in the doorway).
func _on_side(stand: Vector3) -> bool:
	return _side.is_empty() or (stand - (_side[0] as Vector3)).dot(_side[1] as Vector3) > float(_side[2])


func _lock_reach(spec: GateSpec, progress: FloorProgress, comp: int) -> Dictionary:
	if not ProgressRules.has_requirement(progress, spec.requirement):
		return _no("requirement")
	match spec.kind:
		GateSpec.Kind.POWER:
			return {"ok": true, "how": "switchboard", "point": Vector3.INF, "distance": 0.0}
		GateSpec.Kind.EVENT:
			return {"ok": true, "how": "event", "point": Vector3.INF, "distance": 0.0}
	var lock := gates.lock_of(spec.id)
	if lock == null:
		return _no("no lock")
	match spec.kind:
		GateSpec.Kind.BOLT:
			return _use_reach(lock, comp, true, "bolt")
		GateSpec.Kind.SEAL:
			return _use_reach(lock, comp, false, "seal")
	var tools: Array = []   # [how, range]
	match spec.kind:
		GateSpec.Kind.CHAIN, GateSpec.Kind.BOARDS:
			tools.append(["fists", fist_reach])
			if progress.weapons.has(&"shotgun"):
				tools.append(["shotgun", SHOTGUN_REACH])
			if spec.kind == GateSpec.Kind.BOARDS and ProgressRules.has_requirement(progress, GateSpec.EXPLOSIVE):
				tools.append(["blast", FLARE_BLAST_REACH])
		GateSpec.Kind.CRACKED:
			if progress.weapons.has(&"hwacha"):
				tools.append(["hwacha", HWACHA_REACH])
			if progress.weapons.has(&"flare"):
				tools.append(["flare", LockRules.FLARE_POINT_BLANK])
		GateSpec.Kind.ROPE:
			if progress.weapons.has(&"rifle_hunt"):
				tools.append(["rifle", rifle_range])
			if spec.requirement != &"rifle_hunt" and progress.weapons.has(&"pistol"):
				tools.append(["pistol", LockRules.ROPE_PISTOL_RANGE])
		GateSpec.Kind.HOOK:
			if progress.weapons.has(&"harpoon"):
				tools.append(["harpoon", harpoon_range])
	for tool: Array in tools:
		var found := _shot_reach(lock, comp, float(tool[1]), tool[0])
		if found["ok"]:
			return found
	return _no("unreachable")


static func _no(why: String) -> Dictionary:
	return {"ok": false, "how": why, "point": Vector3.INF, "distance": INF}


## True when the guard stands on component [param comp] right in front of
## gate [param spec]'s opening - on its bolt's side for a BOLT, on either
## side else.
func side_reached(spec: GateSpec, comp: int) -> bool:
	var passage := level.layout.opening(spec.opening)
	if passage == null:
		return false
	var frame := _builder.passage_frame(passage)   # +Z toward room A
	var reach := passage.depth() * 0.5 + SIDE_REACH
	for side: Array in [[passage.room_a, frame.basis.z], [passage.room_b, -frame.basis.z]]:
		if spec.kind == GateSpec.Kind.BOLT and side[0] != spec.one_way_side:
			continue
		var p := _floor_polygon(frame.origin + (side[1] as Vector3) * reach, passage.floor_y)
		if p >= 0 and graph.component[p] == comp:
			return true
	return false


## Passages (openings with no door or an open one, flights of stairs) the
## game's navmesh does not walk through in the current state: both sides
## have floor, but the map's path between them is missing or a detour
## (longer than [param detour] times the step across plus 15 m). Returns
## [what, metres across, path metres].
func passage_breaks(detour: float = 3.0) -> Array:
	var found := []
	var space := get_world_3d().direct_space_state
	var sides := []
	for passage in level.layout.openings:
		var door: Door = level.doors.get(passage.id)
		if door != null and not door.is_open:
			continue
		var frame := _builder.passage_frame(passage)
		if _capsule_blocked(space, frame.origin):
			continue
		var reach := passage.depth() * 0.5 + SIDE_REACH
		sides.append([String(passage.id), frame.origin + frame.basis.z * reach, frame.origin - frame.basis.z * reach, passage.floor_y, passage.floor_y])
	for flight in level.layout.stairs:
		var frame := flight.frame()
		sides.append([String(flight.id), frame.origin + frame.basis.z * SIDE_REACH, frame.origin - frame.basis.z * (flight.run() + SIDE_REACH) + Vector3.UP * (flight.top_y - flight.bottom_y), flight.bottom_y, flight.top_y])
	for entry: Array in sides:
		var pa := _floor_polygon(entry[1], entry[3])
		var pb := _floor_polygon(entry[2], entry[4])
		if pa < 0 or pb < 0:
			continue
		var a := graph.closest_on(pa, entry[1])
		var b := graph.closest_on(pb, entry[2])
		var across := a.distance_to(b)
		var length := INF
		if graph.base_component[pa] == graph.base_component[pb]:
			length = path_length(NavProbe.path(map(), a, b, LevelNavigation.WALK_LAYER))
		if length > across * detour + 15.0:
			found.append([entry[0], across, length])
	return found


## Closes every gate's door and puts fresh, shut locks in all of them,
## keeping the current navmesh (for asking each lock side by side).
func shut_every_lock() -> void:
	level.gates_open = []
	for spec in level.layout.gates:
		var door: Door = level.doors.get(spec.opening)
		if door != null:
			door.lock(true)
	open_gates = []
	_make_locks()


## A shot (or a punch) from a standing point of [param comp] within
## [param reach] whose first hit (Hitscan.ray: walls and hit zones) is one
## of the lock's own zones: aimed at a zone's centre (where a melee sweep
## and a blast look), or at three of its five aim points (a hitscan shot at
## any part of it) - never through a slit at a jamb.
func _shot_reach(lock: Node3D, comp: int, reach: float, how: String) -> Dictionary:
	var groups := _aims(lock)
	if groups.is_empty():
		return _no("no zones")
	var space := get_world_3d().direct_space_state
	var center: Vector3 = (groups[0] as PackedVector3Array)[0]
	var stands := graph.stand_points(comp, center, reach + EYE)
	# the closest MAX_TRIES points one by one, then every stride-th
	var stride := maxi(1, stands.size() / MAX_TRIES)
	var i := 0
	var tried := 0
	while i < stands.size():
		var eye := stands[i] + Vector3.UP * EYE
		i += 1 if tried < MAX_TRIES else stride
		if not _on_side(stands[i - 1] if tried < MAX_TRIES else eye - Vector3.UP * EYE):
			continue
		tried += 1
		for aims: PackedVector3Array in groups:
			if eye.distance_to(aims[0]) > reach:
				continue
			var hits := 0
			for n in aims.size():
				var hit := Hitscan.ray(space, eye, aims[n] + (aims[n] - eye).normalized() * 0.4)
				var zone := hit.get("hurtbox") as Hurtbox if not hit.is_empty() else null
				# it counts where it was aimed (not a graze through a slit at a jamb)
				if zone != null and zone.receiver == lock and (hit["position"] as Vector3).distance_to(aims[n]) <= AIM_SLACK:
					hits += 1
					if n == 0:
						hits = aims.size()
						break
			if hits >= 3:
				return {"ok": true, "how": how, "point": eye - Vector3.UP * EYE, "distance": eye.distance_to(aims[0])}
	return _no("unreachable")


## The lock's hit zones: per zone its centre first, then four points
## toward its corners.
func _aims(lock: Node3D) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	var zones: Array = lock.get(&"zones") if &"zones" in lock else []
	for zone: Hurtbox in zones:
		if zone.collision_layer == 0:
			continue
		for child in zone.get_children():
			var collider := child as CollisionShape3D
			if collider == null or not collider.shape is BoxShape3D:
				continue
			var size := (collider.shape as BoxShape3D).size
			var frame := collider.global_transform
			var aims := PackedVector3Array([frame.origin])
			for corner: Vector2 in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
				aims.append(frame * Vector3(size.x * corner.x, size.y * corner.y, 0.0))
			found.append(aims)
	return found


## E on the lock's prompt from a standing point of [param comp] (the
## game's use probe: the first Interactable on the ray, walls block it);
## [param bolt_side]: only from the side the bolt is on.
func _use_reach(lock: Node3D, comp: int, bolt_side: bool, how: String) -> Dictionary:
	var prompt := lock.get(&"prompt_area") as Interactable
	if prompt == null:
		return _no("no prompt")
	var boxes: Array[Transform3D] = []
	var sizes: Array[Vector3] = []
	for child in prompt.get_children():
		var collider := child as CollisionShape3D
		if collider != null and collider.shape is BoxShape3D:
			boxes.append(collider.global_transform)
			sizes.append((collider.shape as BoxShape3D).size)
	if boxes.is_empty():
		return _no("no prompt")
	var space := get_world_3d().direct_space_state
	var center := boxes[0].origin
	var front := bool(lock.get(&"bolt_in_front")) if &"bolt_in_front" in lock else false
	var tried := 0
	for stand in graph.stand_points(comp, center, Interactor.REACH + 1.0):
		if not _on_side(stand):
			continue
		if bolt_side:
			var depth := (stand - lock.global_position).dot(lock.global_basis.z)
			if (depth >= 0.0) == front:
				continue
		var eye := stand + Vector3.UP * EYE
		tried += 1
		if tried > MAX_TRIES:
			break
		for n in boxes.size():
			var local := boxes[n].affine_inverse() * eye
			var half := sizes[n] * 0.5
			var nearest := boxes[n] * Vector3(clampf(local.x, -half.x * 0.8, half.x * 0.8), clampf(local.y, -half.y * 0.8, half.y * 0.8), 0.0)
			for aim in [nearest, boxes[n].origin]:
				var target := _interactor.probe(space, eye, (aim as Vector3) - eye)
				if target == prompt:
					return {"ok": true, "how": how, "point": stand, "distance": eye.distance_to(aim)}
	return _no("unreachable")


# --- walks ------------------------------------------------------------------------------

## The walk from [param start] to [param goal] (both navmesh points) on the
## map, [] when they do not connect.
func path_between(start: Vector3, goal: Vector3) -> PackedVector3Array:
	if start.distance_to(goal) < 0.05:
		return PackedVector3Array([start, goal])
	if not NavProbe.connected(map(), start, goal, LevelNavigation.WALK_LAYER):
		return PackedVector3Array()
	return NavProbe.path(map(), start, goal, LevelNavigation.WALK_LAYER)


## The guard's walk from [param start] to [param goal] (navmesh points):
## the map's path inside one baked component, across the passages the
## mesh misses (breaks) from one component to the next; [] when there is
## no way.
func route(start: Vector3, goal: Vector3) -> PackedVector3Array:
	var ps := graph.closest_polygon(start, -1, 0.6)
	var pg := graph.closest_polygon(goal, -1, 0.6)
	if ps < 0 or pg < 0 or graph.component[ps] != graph.component[pg]:
		return PackedVector3Array()
	var from := graph.base_component[ps]
	var to := graph.base_component[pg]
	if from == to:
		return path_between(start, goal)
	# hops over the breaks between baked components (breadth first)
	var came := {from: null}
	var queue: Array[int] = [from]
	while not queue.is_empty() and not came.has(to):
		var comp: int = queue.pop_front()
		for found: Dictionary in breaks:
			for side: Array in [[found["a"], found["b"]], [found["b"], found["a"]]]:
				var near := graph.base_component[graph.closest_polygon(side[0], -1, 0.6)]
				var far := graph.base_component[graph.closest_polygon(side[1], -1, 0.6)]
				if near == comp and not came.has(far):
					came[far] = [comp, side[0], side[1]]
					queue.append(far)
	if not came.has(to):
		return PackedVector3Array()
	var hops: Array = []
	var at := to
	while came[at] != null:
		hops.push_front(came[at])
		at = came[at][0]
	var walk := PackedVector3Array()
	var here := start
	for hop: Array in hops:
		var piece := path_between(here, hop[1])
		if piece.is_empty():
			return PackedVector3Array()
		walk.append_array(piece)
		here = hop[2]
	var last := path_between(here, goal)
	if last.is_empty():
		return PackedVector3Array()
	walk.append_array(last)
	return walk


## The rooms [param path] enters, in order: [room id, metres from the
## start where it enters, its part of the floor], sampled every half metre
## (a doorway between two rooms counts for the room it leads into).
func rooms_along(path: PackedVector3Array) -> Array:
	var found := []
	var walked := 0.0
	var last := &""
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var length := a.distance_to(b)
		var steps := maxi(1, ceili(length * 2.0))
		for k in steps + 1:
			var t := float(k) / float(steps)
			var room_id := room_of(a.lerp(b, t) + Vector3.UP * 0.3)
			if room_id != &"" and room_id != last:
				last = room_id
				found.append([room_id, walked + length * t, Floor1Route.part_of(level.layout.room(room_id).zone)])
		walked += length
	return found


static func path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length
