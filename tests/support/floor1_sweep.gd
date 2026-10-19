class_name Floor1Sweep
extends RefCounted
## The collision sweep of Floor I (QA #49; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): the
## game scene (Museum) on the DRESSED floor with everything open - every
## gate's lock opened, every door and false panel open, every guardian and
## the T-Rex fallen, every weapon and fuse owned, the power on - and no
## exhibit standing, so the real guard (Floor1Walker) can walk every
## doorway, every flight and the whole walkable floor with the colliders
## the player meets: the shell, the pieces under the art, the locks'
## remains, the havens' furniture, the props of the floor's game.
## The walkable floor comes from the navmesh the exhibits use (agent 0.5 m
## wide each side, climb 0.1 m, slope 40 deg: everywhere it lies the guard's
## 0.4 m capsule fits and his controller - which climbs a lip of about
## 0.12 m on the capsule's round and floors up to 45 deg - should walk) as a
## lattice of points; lanes along x and z between neighbouring points are
## walked both ways, and a lane that breaks over a short gap (a ledge, a
## lip, a low piece the navmesh steps round) is walked across it too.

const Walker := preload("res://tests/support/floor1_walker.gd")

## Neighbouring lattice points join when their heights differ by at most
## this share of their distance (navmesh slope 40 deg; stairs ramps ~31 deg).
const MAX_GRADE := 0.9
## A lane breaking over at most this many missing points (with floor on
## both sides within LEDGE_RISE) is a crossing worth walking.
const GAP_POINTS := 2
const LEDGE_RISE := 0.9

var museum: Museum
var level: MuseumFloorLevel
var walker: Floor1Walker
## Lattice spacing (m) and cell -> Array of heights (one per navmesh layer
## over that point).
var spacing: float = 1.0
var lattice: Dictionary = {}


## Builds the world (see the class notes) under [param parent]; dressed
## unless [param dressed] is false.
static func build(parent: Node, dressed: bool = true) -> Floor1Sweep:
	var sweep := Floor1Sweep.new()
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = dressed
	GameState.new_game()
	open_everything(GameState)
	GameState.save_game()
	sweep.museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	parent.add_child(sweep.museum)
	sweep.level = sweep.museum.floor_level
	return sweep


## [param game] with every gate open, every guardian and the T-Rex fallen
## and their seals and shards taken, every weapon, fuse and haven known,
## the power on and the astrolabe filled.
static func open_everything(game: PersistentState) -> void:
	var layout := Floor1Layout.create()
	for gate in layout.gates:
		game.open_gate(gate.id)
	for plan in Floor1Plan.guardians():
		game.defeat_guardian(plan.id)
		if plan.seal != &"":
			game.add_seal(plan.seal)
		if plan.shard != &"":
			game.add_shard(plan.shard)
	game.defeat_guardian(FloorFinale.TREX)
	for id: StringName in Loadout.WEAPON_PATHS:
		game.add_weapon(id)
	for item in FloorPickups.FUSES:
		game.add_item(item)
	for haven in Floor1Plan.havens():
		game.discover_haven(haven.id)
	game.pistol_key = true
	game.set_flag(Switchboard.POWER_FLAG)
	game.set_flag(FloorFinale.ASTROLABE_FLAG)


## After the museum's first frames (await it): no exhibit stands, every
## door is open, the navmesh is baked for that once more (on this thread,
## the doors' own rebakes switched off), the guard is the bot's.
func settle() -> void:
	var tree := museum.get_tree()
	for exhibit in museum.exhibits():
		exhibit.free()
	for node in tree.get_nodes_in_group(&"guardians"):
		if museum.is_ancestor_of(node):
			node.free()
	var boss := museum.floor_game.finale.boss
	if boss != null and is_instance_valid(boss):
		boss.free()
	while level.navigation.is_baking():
		await tree.physics_frame
	for door: Door in level.doors.values():
		for connection: Dictionary in door.nav_blocking_changed.get_connections():
			door.nav_blocking_changed.disconnect(connection["callable"])
		door.unlock()
		door.open(true)
	level.navigation.bake_now()
	await tree.physics_frame
	await tree.physics_frame
	walker = Walker.new(museum.player)


func map() -> RID:
	return level.walk_region.get_navigation_map()


## Every navmesh polygon of the walkable boxes and the havens, as
## [vertices (PackedVector3Array, global), polygons (Array of
## PackedInt32Array)].
func navmesh_polygons() -> Array:
	var points := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	var regions: Array = level.navigation.regions.duplicate()
	regions.append(level.haven_region)
	for region: NavigationRegion3D in regions:
		var mesh := region.navigation_mesh
		if mesh == null:
			continue
		var base := points.size()
		var frame := region.global_transform
		for v in mesh.get_vertices():
			points.append(frame * v)
		for i in mesh.get_polygon_count():
			var polygon := mesh.get_polygon(i)
			var shifted := PackedInt32Array()
			for index in polygon:
				shifted.append(base + index)
			polygons.append(shifted)
	return [points, polygons]


## The lattice of navmesh points [param step] m apart where the guard
## stands squarely (Floor1Walker.standing_spot: not on the very edge of a
## ramp or a ledge, where the navmesh's simplified outline may reach),
## at the height of the floor under them.
func build_lattice(step: float) -> void:
	_navmesh_lattice(step)
	var dropped := 0
	for cell: Vector2i in lattice.keys():
		var kept: Array = []
		for height: float in lattice[cell]:
			var spot := walker.standing_spot(point(cell, height))
			if spot != Vector3.INF:
				kept.append(spot.y)
			else:
				dropped += 1
		if kept.is_empty():
			lattice.erase(cell)
		else:
			lattice[cell] = kept
	edge_points = dropped


## Lattice points dropped as not squarely standing (see build_lattice()).
var edge_points: int = 0


func _navmesh_lattice(step: float) -> void:
	spacing = step
	lattice.clear()
	var mesh := navmesh_polygons()
	var points: PackedVector3Array = mesh[0]
	for polygon: PackedInt32Array in mesh[1]:
		if polygon.size() < 3:
			continue
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for index in polygon:
			var p := points[index]
			low = Vector2(minf(low.x, p.x), minf(low.y, p.z))
			high = Vector2(maxf(high.x, p.x), maxf(high.y, p.z))
		for ix in range(ceili(low.x / step), floori(high.x / step) + 1):
			for iz in range(ceili(low.y / step), floori(high.y / step) + 1):
				var height := _height_in(points, polygon, Vector2(ix * step, iz * step))
				if height == INF:
					continue
				var cell := Vector2i(ix, iz)
				var heights: Array = lattice.get(cell, [])
				if heights.all(func(h: float) -> bool: return absf(h - height) > 0.3):
					heights.append(height)
					lattice[cell] = heights


## The navmesh height of convex [param polygon] over [param at] (INF when
## the point is outside it).
static func _height_in(points: PackedVector3Array, polygon: PackedInt32Array, at: Vector2) -> float:
	var a := points[polygon[0]]
	for i in range(1, polygon.size() - 1):
		var b := points[polygon[i]]
		var c := points[polygon[i + 1]]
		var weights := _barycentric(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), at)
		if weights.x >= -0.0001 and weights.y >= -0.0001 and weights.z >= -0.0001:
			return a.y * weights.x + b.y * weights.y + c.y * weights.z
	return INF


static func _barycentric(a: Vector2, b: Vector2, c: Vector2, p: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var denominator := v0.x * v1.y - v1.x * v0.y
	if absf(denominator) < 0.000001:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / denominator
	var w := (v0.x * v2.y - v2.x * v0.y) / denominator
	return Vector3(1.0 - v - w, v, w)


## The lattice point of [param cell] nearest [param height] (INF none).
func height_at(cell: Vector2i, height: float, within: float) -> float:
	var best := INF
	for h: float in lattice.get(cell, []):
		if absf(h - height) <= within and (best == INF or absf(h - height) < absf(best - height)):
			best = h
	return best


func point(cell: Vector2i, height: float) -> Vector3:
	return Vector3(cell.x * spacing, height, cell.y * spacing)


## True when the navmesh runs all the way from [param a] to [param b]
## (points every 0.5 m between them lie on it).
func _on_navmesh(a: Vector3, b: Vector3) -> bool:
	var count := maxi(int(a.distance_to(b) / 0.5), 1)
	for k in range(1, count):
		var p := a.lerp(b, float(k) / count)
		var q := NavigationServer3D.map_get_closest_point(map(), p)
		if _flat_distance(p, q) > 0.15 or absf(p.y - q.y) > 0.4:
			return false
	return true


## The room at a guard's feet [param at].
func room_at(at: Vector3) -> StringName:
	return level.room_at(at + Vector3.UP * 0.5)


## A finding of a walk that went wrong: {what, kind, room, at, top, kits,
## rise} (kind: "low" - stopped by something at most a step
## (Player.STEP_HEIGHT) over his feet, which he should walk over; "knee" - up to 0.9 m, a low piece; "tall" /
## "wall" - something higher; "fell"; "timeout").
func finding(what: String, result: Dictionary, rise: float = 0.0) -> Dictionary:
	var top: float = result.get("top", INF)
	var kind := String(result["reason"])
	if kind == "stuck":
		kind = "wall" if top == INF else ("low" if top <= LOW_STEP else ("knee" if top <= 0.9 else "tall"))
	var kits: Array[String] = []
	for contact: Dictionary in result.get("blockers", []):
		if not kits.has(contact["kit"]):
			kits.append(contact["kit"])
	var at: Vector3 = result["at"]
	return {"what": what, "kind": kind, "room": room_at(at), "at": at.snapped(Vector3.ONE * 0.1), "top": top, "kits": kits, "rise": rise, "no_step": result.get("no_step", "")}


static func line(entry: Dictionary) -> String:
	var why: String = entry.get("no_step", "")
	return "%s: %s in %s at %s (top %.2f, rise %.2f) against %s%s" % [entry["what"], entry["kind"], entry["room"], entry["at"], entry["top"], entry["rise"], ", ".join(entry["kits"]), "" if why == "" else " (no step up: %s)" % why]


## Walks every lane of the lattice both ways (from where a walk stopped
## the next one starts past the trouble). Returns {snags: findings,
## slow: [[at, speed]...], crossings: [[from, to]...], lanes, steps}.
func sweep_lanes() -> Dictionary:
	var snags: Array[Dictionary] = []
	var slow: Array = []
	var crossings: Array = []
	var lane_count := 0
	var steps_before := walker.steps
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var found := lanes(axis)
		crossings.append_array(found[1])
		for lane: PackedVector3Array in found[0]:
			lane_count += 1
			for way in 2:
				var points := lane.duplicate()
				if way == 1:
					points.reverse()
				var start := 0
				while start < points.size() - 1:
					walker.place(points[start])
					var result := walker.follow(points.slice(start))
					for entry: Array in result["slow"]:
						slow.append(entry)
					if result["ok"]:
						break
					snags.append(finding("lane", result))
					start += int(result["index"]) + 1
	return {"snags": snags, "slow": slow, "crossings": crossings, "lanes": lane_count, "steps": walker.steps - steps_before}


## The navmesh of the walkable boxes and the havens as a graph (built once).
func nav_graph() -> Floor1NavGraph:
	if _graph == null:
		var meshes: Array = []
		for region: NavigationRegion3D in level.navigation.regions:
			meshes.append(region.navigation_mesh)
		meshes.append(level.haven_region.navigation_mesh)
		_graph = Floor1NavGraph.from_meshes(meshes, NavigationServer3D.map_get_edge_connection_margin(map()))
		_component_areas.clear()
		for p in _graph.polygons.size():
			var comp := _graph.component[p]
			_component_areas[comp] = float(_component_areas.get(comp, 0.0)) + _graph.areas[p]
	return _graph


var _graph: Floor1NavGraph = null
var _component_areas: Dictionary = {}


## Floor area (m2) of the navmesh component under [param at] (0 off it).
func floor_area(at: Vector3) -> float:
	var comp := nav_graph().component_at(at, 0.6)
	return float(_component_areas.get(comp, 0.0)) if comp >= 0 else 0.0


## The crossings of the lanes (see lanes()) that tell of something to walk
## over, each walked: a ledge between two floors (the floor goes on higher
## or lower beyond the gap; both sides at least PIECE_TOP m2 - not the top
## of a plinth or a desk), walked up and down; and a low piece (at most
## a step over the floor: a lip, a kerb, a low step) between two points of
## one floor or under the top of a small piece, walked over. Findings of
## those he cannot walk over, each with "jump": he gets over jumping.
func sweep_ledges(crossings: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for pair: Array in crossings:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var rise := b.y - a.y
		var floors := absf(rise) >= 0.05 and floor_area(a) >= PIECE_TOP and floor_area(b) >= PIECE_TOP
		var ways := 2 if floors else 1
		for way in ways:
			var from := a if way == 0 else b
			var to := b if way == 0 else a
			walker.place(from)
			var result := walker.follow(PackedVector3Array([from, to]))
			if result["ok"]:
				continue
			var entry := finding("ledge %s" % ("up" if to.y > from.y else "down") if floors else "low piece", result, to.y - from.y)
			if not floors and entry["kind"] != "low":
				continue   # a piece standing on the floor: walked round, not over
			walker.place(from)
			entry["jump"] = walker.follow(PackedVector3Array([from, to]), 2.0, true)["ok"]
			found.append(entry)
	return found


## A finding stopped by something at most this high is "low": he should
## have walked over it. (Player.STEP_HEIGHT less 5 cm: at the limit his
## stride may not clear a step whose top goes on rising - a ramp's side.)
const LOW_STEP := Player.STEP_HEIGHT - 0.05
## A navmesh component smaller than this (m2) is the top of a piece.
const PIECE_TOP := 6.0


## Every opening of the layout walked through both ways (feet 1.2 m out of
## the wall on each side, through its middle; also 0.3 m off the middle on
## either side when it is wide enough for that). A side with no floor to
## stand on squarely is skipped (listed in "skipped"); a side lower by more
## than a jump is a drop - walked down only. Returns {failed: findings,
## skipped: [opening id: why], walked: count}.
func sweep_doorways() -> Dictionary:
	var builder := LevelBuilder.new(level.layout, null, null, null)
	var failed: Array[Dictionary] = []
	var skipped := {}
	var walked := 0
	for passage in level.layout.openings:
		var frame := builder.passage_frame(passage)
		var ahead := -frame.basis.z
		var across := frame.basis.x
		var out := passage.depth() * 0.5 + 1.2
		var offsets: Array[float] = [0.0]
		var spare := passage.width() * 0.5 - 0.45
		if spare >= 0.3:
			offsets.append_array([-0.3, 0.3])
		for offset in offsets:
			var middle := passage.center() + across * offset
			var a := _side_spot(middle, -ahead, out, passage.floor_y)
			var b := _side_spot(middle, ahead, out, passage.floor_y)
			if a == Vector3.INF or b == Vector3.INF:
				skipped[passage.id] = "no floor to stand on, side %s" % ("A" if a == Vector3.INF else "B")
				continue
			var inside := walker.floor_below(middle, 0.5, 1.0)
			if inside == Vector3.INF:
				inside = middle
			var drop := b.y - a.y
			for way in 2:
				var from := a if way == 0 else b
				var to := b if way == 0 else a
				if to.y - from.y > 0.5:
					continue   # up a drop: by design only down
				walker.place(from)
				var result := walker.follow(PackedVector3Array([from, inside, to]))
				walked += 1
				if not result["ok"]:
					var entry := finding("%s %s%s" % [passage.id, "A->B" if way == 0 else "B->A", "" if offset == 0.0 else " off %.1f" % offset], result, drop)
					failed.append(entry)
	return {"failed": failed, "skipped": skipped, "walked": walked}


## A spot to stand on squarely about [param out] m from [param middle]
## along [param way] (from 0.6 m less to 1.5 m more, up to 0.8 m to a
## side), on a floor from 3 m under to 0.6 m over [param floor_y]; the
## nearest such spot, INF when none.
func _side_spot(middle: Vector3, way: Vector3, out: float, floor_y: float) -> Vector3:
	# the navmesh nearest that side first (a doorway onto a flight: the
	# floor there is the ramp, at its own height)
	var nominal := middle + way * out
	var nearest := NavigationServer3D.map_get_closest_point(map(), nominal)
	if _flat_distance(nearest, nominal) < 1.5 and (nearest - middle).dot(way) > out - 1.0:
		var spot := _near_spot(nearest, 0.75)
		if spot != Vector3.INF:
			return spot
	var across := way.cross(Vector3.UP)
	for extra: float in [0.0, -0.3, 0.4, -0.6, 0.8, 1.5]:
		for side: float in [0.0, 0.4, -0.4, 0.8, -0.8]:
			var at := middle + way * (out + extra) + across * side
			for height: float in [floor_y, floor_y - 0.6, floor_y + 0.6, floor_y - 1.2, floor_y - 1.8, floor_y - 2.4, floor_y - 3.0]:
				var spot := walker.standing_spot(Vector3(at.x, height, at.z), 0.32)
				if spot != Vector3.INF:
					return spot
	return Vector3.INF


## The standing spot nearest [param at] (floor plan, within [param radius]
## m, on a grid of 0.25 m) whose floor lies within 0.2 m of at's height;
## INF when none.
func _near_spot(at: Vector3, radius: float) -> Vector3:
	var offsets: Array[Vector2] = []
	var n := int(radius / 0.25)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var offset := Vector2(i, j) * 0.25
			if offset.length() <= radius:
				offsets.append(offset)
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	for offset in offsets:
		var spot := walker.standing_spot(at + Vector3(offset.x, 0.0, offset.y), 0.2)
		if spot != Vector3.INF:
			return spot
	return Vector3.INF


## Every flight of stairs walked up and down (feet 1.2 m before the foot to
## 1.2 m past the top; along the middle and 0.55 m in from each side when
## it is wide enough). Returns {failed: findings, skipped, walked, eyes:
## [[walk, bob against the way, largest change in a step]...] (his view
## on each walk that got there, Floor1Walker.eye_bob)}.
func sweep_stairs() -> Dictionary:
	var failed: Array[Dictionary] = []
	var skipped := {}
	var walked := 0
	var eyes: Array = []
	for flight in level.layout.stairs:
		var frame := flight.frame()
		var rise := flight.top_y - flight.bottom_y
		var run := flight.run()
		var offsets: Array[float] = [0.0]
		var spare := flight.width() * 0.5 - 0.55
		if spare >= 0.25:
			offsets.append_array([-spare, spare])
		for offset in offsets:
			# in front of the foot (or beside it on a landing: a stairwell turning
			# back on itself) and past the top
			var foot := _near_spot(frame * Vector3(offset, 0.0, 1.0), 2.0)
			var top := _near_spot(frame * Vector3(offset, rise, -(run + 1.0)), 2.0)
			if foot == Vector3.INF or top == Vector3.INF:
				skipped["%s %.1f" % [flight.id, offset]] = "no %s to stand on" % ("foot" if foot == Vector3.INF else "top")
				continue
			var low := frame * Vector3(offset, 0.0, 0.0)
			var high := frame * Vector3(offset, rise, -run)
			for way in 2:
				var points := PackedVector3Array([foot, low, high, top])
				if way == 1:
					points.reverse()
				walker.place(points[0])
				walker.eyes.clear()
				walker.record_eyes = true
				var result := walker.follow(points)
				walker.record_eyes = false
				walked += 1
				var what := "%s %s%s" % [flight.id, "up" if way == 0 else "down", "" if offset == 0.0 else " off %.1f" % offset]
				if not result["ok"]:
					failed.append(finding(what, result, rise))
				else:
					var bob := walker.eye_bob(way == 0)
					eyes.append([what, bob.x, bob.y])
	return {"failed": failed, "skipped": skipped, "walked": walked, "eyes": eyes}


## Places he can drop into but not climb out of. The navmesh as a graph
## (Floor1NavGraph: the walkable boxes and the havens, joined as the map
## joins them): every component other than the one of the night's start
## that holds at least [param min_points] lattice points and lies under a
## lattice point of the start's component (within 2.5 m on the floor plan,
## at least 0.3 m higher) is a pit he could drop into. He walks off the
## edge into it; then, from where he landed, he tries to walk and jump back
## to each of the five nearest points of the start's component above. A
## pit he lands in and leaves no way is a trap: {room, at, points, drop}.
## Returns {traps, pits (count of pits dropped into and left), main}.
func traps(min_points: int = 2) -> Dictionary:
	var graph := nav_graph()
	var main := -1
	for comp: int in _component_areas:
		if main < 0 or float(_component_areas[comp]) > float(_component_areas[main]):
			main = comp
	var by_component := {}
	var main_points: Array[Vector3] = []
	for cell: Vector2i in lattice:
		for height: float in lattice[cell]:
			var at := point(cell, height)
			var comp := graph.component_at(at, 0.6)
			if comp < 0:
				continue
			if comp == main:
				main_points.append(at)
			else:
				var list: Array = by_component.get(comp, [])
				list.append(at)
				by_component[comp] = list
	var found: Array[Dictionary] = []
	var left := 0
	var in_main := {}
	for p in main_points:
		in_main[p] = true
	for comp: int in by_component:
		var points: Array = by_component[comp]
		if points.size() < min_points:
			continue
		var edge := _drop_edge(points, in_main)
		if edge.is_empty():
			continue
		var from: Vector3 = edge[0]
		var into: Vector3 = edge[1]
		walker.place(from)
		var dropped := walker.follow(PackedVector3Array([from, into]), 3.0)
		var landed := walker.feet()
		if graph.component_at(landed, 0.6) != comp:
			continue   # he does not end up down there walking off the edge
		var near := main_points.duplicate()
		near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat_distance(a, landed) < _flat_distance(b, landed))
		var out := false
		for goal: Vector3 in near.slice(0, 5):
			walker.place(landed)
			var back := walker.follow(PackedVector3Array([landed, Walker.past_edge(landed, goal)]), 3.0, true)
			walker.settle()   # (a way out over an edge: he lands first)
			if back["ok"] and graph.component_at(walker.feet(), 0.6) == main:
				out = true
				break
		if out:
			left += 1
		else:
			found.append({"room": room_at(landed), "at": landed.snapped(Vector3.ONE * 0.1), "points": points.size(), "drop": from.y - landed.y, "fell": dropped["reason"]})
	return {"traps": found, "pits": left, "main": main_points.size()}


## The lattice point of the start's component ([param main]: point ->
## true) and of [param pit] closest on the floor plan with the main one at
## least 0.3 m higher and within 2.5 m: [main point, pit point], or [] when
## the pit lies under none.
func _drop_edge(pit: Array, main: Dictionary) -> Array:
	var best := []
	var best_distance := 2.5
	var reach := ceili(best_distance / spacing)
	for q: Vector3 in pit:
		var cell := Vector2i(roundi(q.x / spacing), roundi(q.z / spacing))
		for dx in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				var near := cell + Vector2i(dx, dz)
				for height: float in lattice.get(near, []):
					var p := point(near, height)
					if not main.has(p) or p.y - q.y < 0.3:
						continue
					var distance := _flat_distance(p, q)
					if distance < best_distance:
						best_distance = distance
						best = [p, q]
	return best


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The lanes of the lattice along [param axis] (Vector2i(1, 0) or (0, 1)):
## each a PackedVector3Array of neighbouring points, plus the crossings:
## [from, to] over a gap of 1..GAP_POINTS missing points where the floor
## goes on within LEDGE_RISE. Returns [lanes, crossings].
func lanes(axis: Vector2i) -> Array:
	var found: Array[PackedVector3Array] = []
	var crossings: Array = []
	var taken := {}
	for cell: Vector2i in lattice:
		for start_h: float in lattice[cell]:
			var key := [cell, snappedf(start_h, 0.01)]
			if taken.has(key):
				continue
			# only lane starts: no neighbour behind
			if height_at(cell - axis, start_h, MAX_GRADE * spacing) != INF:
				continue
			var lane := PackedVector3Array()
			var at := cell
			var h := start_h
			while true:
				taken[[at, snappedf(h, 0.01)]] = true
				lane.append(point(at, h))
				var next := height_at(at + axis, h, MAX_GRADE * spacing)
				if next != INF and spacing > 1.0 and not (_on_navmesh(point(at, h), point(at + axis, next)) and walker.sweeps_clear(point(at, h), point(at + axis, next))):
					next = INF   # far apart: a wall, a leaf or a piece may stand between
				if next == INF:
					# a short gap with floor beyond: a crossing
					for gap in range(2, GAP_POINTS + 2):
						var beyond := height_at(at + axis * gap, h, LEDGE_RISE)
						if beyond != INF:
							crossings.append([point(at, h), point(at + axis * gap, beyond)])
							break
					break
				at += axis
				h = next
			if lane.size() >= 2:
				found.append(lane)
	return [found, crossings]


# --- invisible collision -----------------------------------------------------

## A box face standing this far (m) proud of anything drawn behind it is
## a face of invisible collision; looked for up to PROBE m behind it.
const GAP := 0.3
const PROBE := 0.6
## Collision layer of the looks' stand-in bodies (no game query uses it).
const LOOK_LAYER := 1 << 29
## Kit roles of the shell (its look is the wall itself) left out.
const SHELL_ROLES: Array[StringName] = [&"wall", &"floor", &"ceiling", &"door", &"trim", &"fixture"]


## Solid boxes standing proud of their drawing ("invisible corners"):
## every box collider of the level's pieces and the game's props within head
## height (its bottom under 1.9 m over the room's floor; not the shell, not
## the stairs' ramps, not greybox pieces - their look is the box) is walked
## round its outline every 0.15 m where the guard can stand beside it; from
## each point rays go in through the face at every height his body meets
## it against everything drawn there (each visible mesh and batch instance
## near it stands in as a trimesh on LOOK_LAYER) - see _longest_bare_run().
## The longest run of outline at least GAP m proud of the drawing is
## reported when it is at least [param min_run] m: {what, room, at, run,
## gap, size}. (Await it: the stand-ins need a physics frame.)
func invisible_collision(min_run: float = 0.3) -> Array[Dictionary]:
	var boxes: Array = []   # [shape node, body]
	for body in museum.find_children("*", "StaticBody3D", true, false):
		var solid := body as StaticBody3D
		if solid.collision_layer & Layers.WORLD == 0 or not solid.is_visible_in_tree() and not solid.has_meta(&"kit"):
			continue
		if solid.has_meta(&"kit"):
			var kit: StringName = solid.get_meta(&"kit")
			if kit == &"stair_ramp" or SHELL_ROLES.has(LevelKit.role(kit)) or solid.get_meta(&"kit_greybox", false):
				continue
		for child in solid.get_children():
			var holder := child as CollisionShape3D
			if holder != null and not holder.disabled and (holder.shape is BoxShape3D or holder.shape is ConvexPolygonShape3D or holder.shape is CylinderShape3D):
				boxes.append([holder, solid])
	# the stand-ins: every visible mesh whose bounds come near a box
	var meshes: Array = []
	for node in museum.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if view.mesh != null and view.is_visible_in_tree():
			meshes.append([view, view.global_transform * view.mesh.get_aabb()])
	# batched looks (racks, cabinets, tiles): each instance stands in too
	var batches: Array[MeshInstance3D] = []
	for node in museum.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null or not batch.is_visible_in_tree():
			continue
		# (headless, the RenderingServer keeps no instance data: the batch's
		# own record of its places first - BasementArt.INSTANCES_META)
		var places: Array = batch.get_meta(BasementArt.INSTANCES_META, [])
		if places.is_empty():
			for i in batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0 else batch.multimesh.instance_count:
				places.append(batch.multimesh.get_instance_transform(i))
		for place: Transform3D in places:
			var copy := MeshInstance3D.new()
			copy.mesh = batch.multimesh.mesh
			copy.transform = batch.global_transform * place
			batches.append(copy)
			meshes.append([copy, copy.transform * copy.mesh.get_aabb()])
	var buckets := {}
	for i in meshes.size():
		var bounds: AABB = meshes[i][1]
		for key in _bucket_keys(bounds):
			var list: Array = buckets.get(key, [])
			list.append(i)
			buckets[key] = list
	var near: Array[MeshInstance3D] = []
	var added := {}
	for entry: Array in boxes:
		var holder: CollisionShape3D = entry[0]
		var reach := _box_bounds(holder).grow(0.1)
		for key in _bucket_keys(reach):
			for i: int in buckets.get(key, []):
				if not added.has(i) and (meshes[i][1] as AABB).intersects(reach):
					added[i] = true
					near.append(meshes[i][0])
	var stand_in := stand_ins(near, museum)
	await museum.get_tree().physics_frame
	await museum.get_tree().physics_frame
	var found: Array[Dictionary] = []
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = LOOK_LAYER
	ray.hit_back_faces = true
	for entry: Array in boxes:
		var holder: CollisionShape3D = entry[0]
		var body: StaticBody3D = entry[1]
		var bounds := _box_bounds(holder)
		var room := level.layout.room(room_at(bounds.get_center() - Vector3.UP * bounds.size.y * 0.5))
		var floor_y := room.floor_y if room != null else bounds.position.y
		if bounds.position.y > floor_y + 1.9:
			continue
		var run := _longest_bare_run(holder, bounds, ray, floor_y) if holder.shape is BoxShape3D else _longest_bare_arc(holder, body, bounds, ray, floor_y)
		if run >= min_run:
			found.append({"what": Walker.describe(body), "room": room.id if room != null else &"", "at": bounds.get_center().snapped(Vector3.ONE * 0.1), "run": run, "gap": _last_gap, "size": bounds.size.snapped(Vector3.ONE * 0.01)})
	stand_in.free()
	for copy in batches:
		copy.free()
	return found


## A body on LOOK_LAYER standing in for what [param views] draw: a
## trimesh of each one's mesh where it is (free it when done; it needs a
## physics frame before rays find it).
static func stand_ins(views: Array[MeshInstance3D], parent: Node) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "LookStandIns"
	body.collision_layer = LOOK_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var shapes := {}
	for view in views:
		if not shapes.has(view.mesh):
			var trimesh := view.mesh.create_trimesh_shape()
			if trimesh != null:
				trimesh.backface_collision = true   # rays find a face from either side
			shapes[view.mesh] = trimesh
		if shapes[view.mesh] == null:
			continue
		var copy := CollisionShape3D.new()
		copy.shape = shapes[view.mesh]
		copy.transform = view.global_transform if view.is_inside_tree() else view.transform
		body.add_child(copy)
	return body


## The world bounds of collider [param holder].
static func _box_bounds(holder: CollisionShape3D) -> AABB:
	if holder.shape is BoxShape3D:
		var size := (holder.shape as BoxShape3D).size
		return holder.global_transform * AABB(-size * 0.5, size)
	return holder.global_transform * holder.shape.get_debug_mesh().get_aabb()


## _longest_bare_run() for a collider of any shape (a rock's hull, a
## cylinder): its face found by rays from outside in toward its middle every
## ARC_STEP degrees (those that meet this body first), each checked as a
## box's face is; the run measured round its outline.
func _longest_bare_arc(holder: CollisionShape3D, body: CollisionObject3D, bounds: AABB, ray: PhysicsRayQueryParameters3D, floor_y: float) -> float:
	var space := museum.get_world_3d().direct_space_state
	var solid := PhysicsRayQueryParameters3D.new()
	solid.collision_mask = Layers.WORLD
	var middle := bounds.get_center()
	var reach := Vector2(bounds.size.x, bounds.size.z).length() * 0.5 + 0.6
	var steps := int(360.0 / ARC_STEP)
	var bare_at: Array[bool] = []
	var lengths: Array[float] = []
	var gaps: Array[float] = []
	for k in steps:
		var angle := deg_to_rad(ARC_STEP * k)
		var way := Vector3(cos(angle), 0.0, sin(angle))
		# the floor beside it and his capsule there
		solid.from = Vector3(middle.x, bounds.position.y + minf(0.5, bounds.size.y * 0.5), middle.z) + way * reach
		solid.to = Vector3(middle.x, solid.from.y, middle.z)
		var face_hit := space.intersect_ray(solid)
		if face_hit.is_empty() or face_hit["collider"] != body:
			bare_at.append(false)
			lengths.append(0.0)
			gaps.append(0.0)
			continue
		var face: Vector3 = face_hit["position"]
		lengths.append(deg_to_rad(ARC_STEP) * Vector2(face.x - middle.x, face.z - middle.z).length())
		var under := PhysicsRayQueryParameters3D.new()
		under.collision_mask = Layers.WORLD
		under.from = Vector3(face.x, bounds.position.y + 0.3, face.z) + way * 0.1
		under.to = Vector3(face.x, floor_y - 0.5, face.z) + way * 0.1
		var ground := space.intersect_ray(under)
		var ground_y: float = (ground["position"] as Vector3).y if not ground.is_empty() else floor_y
		# his capsule beside the shape where it reaches out furthest (a
		# boulder's sides lean in: its foot, not its middle)
		var stand := face
		solid.from = Vector3(middle.x, maxf(bounds.position.y, ground_y) + 0.05, middle.z) + way * reach
		solid.to = Vector3(middle.x, solid.from.y, middle.z)
		var foot_hit := space.intersect_ray(solid)
		if not foot_hit.is_empty() and foot_hit["collider"] == body:
			var foot: Vector3 = foot_hit["position"]
			if (foot - middle).dot(way) > (face - middle).dot(way):
				stand = Vector3(foot.x, face.y, foot.z)
		var bare := ground_y <= floor_y + 0.95 and walker.capsule_fits(Vector3(stand.x, ground_y + 0.03, stand.z) + way * 0.43)
		var gap := GAP + 0.05
		var h := maxf(bounds.position.y, ground_y) + BODY_FROM
		var high := minf(bounds.end.y, ground_y + 1.8) - 0.05
		if high < h:
			bare = false   # lower than his body meets: a step, not a wall
		while bare and h <= high + 0.001:
			solid.from = Vector3(middle.x, h, middle.z) + way * reach
			solid.to = Vector3(middle.x, h, middle.z)
			var at_height := space.intersect_ray(solid)
			if not at_height.is_empty() and at_height["collider"] == body:
				var start: Vector3 = (at_height["position"] as Vector3) + way * 0.01
				ray.from = start
				ray.to = start - way * (GAP + 0.06)
				var drawn := space.intersect_ray(ray)
				if not drawn.is_empty():
					gap = minf(gap, (drawn["position"] as Vector3).distance_to(start) - 0.01)
					if gap < GAP:
						bare = false
			h += 0.25
		bare_at.append(bare)
		gaps.append(gap)
	var best := 0.0
	for start in steps:
		if not bare_at[start] or bare_at[(start - 1 + steps) % steps]:
			continue
		var run := 0.0
		var least := INF
		var k := start
		while bare_at[k] and run < 100.0:
			run += lengths[k]
			least = minf(least, gaps[k])
			k = (k + 1) % steps
			if k == start:
				break
		if run > best:
			best = run
			_last_gap = least
	if bare_at.all(func(b: bool) -> bool: return b):
		best = 0.0
		for length in lengths:
			best += length
		_last_gap = gaps.min()
	return best


## The guard's body meets a collider from this high over his floor (m):
## what is drawn lower - a rug, raked sand, an inlay - stops nobody.
const BODY_FROM := 0.2
## Degrees between the rays round a collider of any shape.
const ARC_STEP := 10.0


static func _bucket_keys(bounds: AABB) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for x in range(floori(bounds.position.x / 2.0), floori(bounds.end.x / 2.0) + 1):
		for z in range(floori(bounds.position.z / 2.0), floori(bounds.end.z / 2.0) + 1):
			keys.append(Vector2i(x, z))
	return keys


## The longest stretch (m) of the box's outline (every 0.15 m) where its
## face stands at least GAP m proud of anything drawn behind it, at every
## height the guard's body meets it: from the floor he stands on beside it
## (a ray down just outside the face; at most a jump - 0.95 m - over the
## room's floor [param floor_y], else out of his reach) up to 1.8 m over
## that floor, every 0.25 m, a ray from the face inward finds the drawn
## surface (or nothing within PROBE m).
func _longest_bare_run(holder: CollisionShape3D, bounds: AABB, ray: PhysicsRayQueryParameters3D, floor_y: float) -> float:
	var under := PhysicsRayQueryParameters3D.new()
	under.collision_mask = Layers.WORLD
	var half := (holder.shape as BoxShape3D).size * 0.5
	var frame := holder.global_transform
	var corners := [Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z)]
	var space := museum.get_world_3d().direct_space_state
	var best := 0.0
	var run := 0.0
	var run_gap := INF
	var first_run := -1.0
	for side in 4:
		var a: Vector3 = corners[side]
		var b: Vector3 = corners[(side + 1) % 4]
		var middle := (a + b) * 0.5
		var inward_local := Vector3(-signf(middle.x) if absf(middle.x) > 0.001 else 0.0, 0.0, -signf(middle.z) if absf(middle.z) > 0.001 else 0.0)
		var inward := (frame.basis * inward_local).normalized()
		var depth := half.z * 2.0 if absf(inward_local.z) > 0.5 else half.x * 2.0
		# a face proud of the drawing by GAP, or (a thin box: a rail) with
		# nothing drawn in it nor 10 cm behind it
		var proud := minf(GAP, depth + 0.1)
		var probe := proud + 0.05
		var length := Vector2(a.x - b.x, a.z - b.z).length()
		var count := maxi(int(length / 0.15), 1)
		for k in count:
			var face := frame * a.lerp(b, (k + 0.5) / count)
			under.from = Vector3(face.x, bounds.position.y + 0.3, face.z) - inward * 0.1
			under.to = Vector3(face.x, floor_y - 0.5, face.z) - inward * 0.1
			var ground := space.intersect_ray(under)
			var ground_y: float = (ground["position"] as Vector3).y if not ground.is_empty() else floor_y
			# he can be there: on a floor within a jump, his capsule beside
			# the face (not a back against a wall, not over a drop)
			var bare := ground_y <= floor_y + 0.95 and walker.capsule_fits(Vector3(face.x, ground_y + 0.03, face.z) - inward * 0.43)
			var low := maxf(bounds.position.y, ground_y) + BODY_FROM
			var high := minf(bounds.end.y, ground_y + 1.8) - 0.05
			if high < low:
				bare = false
			var heights: Array[float] = []
			var h := low
			while h < high:
				heights.append(h)
				h += 0.25
			heights.append(high)   # the top too: a table's top over open legs
			var gap := probe
			for at_height in heights:
				if not bare:
					break
				var start := Vector3(face.x, at_height, face.z) - inward * 0.01
				ray.from = start
				ray.to = start + inward * (probe + 0.01)
				var hit := space.intersect_ray(ray)
				if not hit.is_empty():
					gap = minf(gap, (hit["position"] as Vector3).distance_to(start) - 0.01)
					if gap < proud:
						bare = false
			if not bare:
				if first_run < 0.0:
					first_run = run
				if run > best:
					best = run
					_last_gap = run_gap
				run = 0.0
				run_gap = INF
			else:
				run += length / count
				run_gap = minf(run_gap, gap)
	# the outline is a loop: the run at its end goes on into its start
	var wrapped := run + maxf(first_run, 0.0) if first_run >= 0.0 else run
	if wrapped > best:
		best = wrapped
		_last_gap = run_gap
	return best


## How far (at least) the face stood proud of the drawing along the last
## _longest_bare_run()'s run.
var _last_gap: float = 0.0
