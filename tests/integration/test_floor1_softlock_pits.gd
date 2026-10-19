extends Floor1ReachCase
## No pit keeps the guard (QA #50; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): the
## navmesh knows no edge he can drop off, so W7 (Floor1ReachCase) never
## asks what lies below one. Here, in every state of the HUD's play order
## (and of random orders in the deep variant), every part of the navmesh
## cut off from the floor he walks on (the start's component) that lies
## under an edge of it - open from above, 0.4 to 8 m down - is a pit he
## could drop into. The real guard (Floor1Walker) walks off that edge; if
## he lands down there, he must get back by walking or jumping, or work
## from down there the lock of a gate that leads on (Floor1Survey's own
## lock reach). Else it is a soft lock until dawn - the test fails. (A
## way out may lead down again: off the Temple of the Serpent's lower
## terrace he drops to its floor.)

const Walker := preload("res://tests/support/floor1_walker.gd")
## A pit lies at most this far (floor plan, m) from the edge over it, and
## this deep under it.
const EDGE_REACH := 1.5
const MIN_DROP := 0.4
const MAX_DROP := 8.0
## Navmesh parts smaller than this (m2) are no floor to land on.
const MIN_PIT := 1.5

var walker: Floor1Walker
## Per state: pits he dropped into and left (how), traps.
var dropped: Array[String] = []
var traps: Array[String] = []
var _checked: Dictionary = {}
var candidates := 0
var walked_off := 0


func _orders() -> Array:
	return [[Floor1Route.hud_order(), "hud"]]


func test_no_pit_keeps_him_in_any_state_of_the_play_order() -> void:
	await _survey()
	var guard := Player.new()
	guard.name = "Guard"
	survey.add_child(guard)
	await physics_frames(2)
	walker = Walker.new(guard)
	for entry: Array in _orders():
		await walk_order(entry[0], entry[1], false)
	walker.release()
	for line in dropped:
		print("  ", line)
	print("  pit edges found: %d, walked off: %d, pits dropped into and left: %d, traps: %d" % [candidates, walked_off, dropped.size(), traps.size()])
	for line in traps:
		fail(line)


func on_state(state: String, progress: FloorProgress, open: Array[StringName], comp: int) -> void:
	var graph := survey.graph
	var space := survey.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = Layers.WORLD
	# the pits: per component cut off from the start's, its closest edge
	var best := {}   # component -> [distance, edge point, pit point]
	for q in graph.polygons.size():
		var pit := graph.component[q]
		if pit == comp:
			continue
		var centre := graph.centers[q]
		for p in graph.polygons_near(centre, EDGE_REACH + 2.0):
			if graph.component[p] != comp:
				continue
			var edge := graph.closest_on(p, centre)
			var into := graph.closest_on(q, edge)
			var drop := edge.y - into.y
			var reach := Vector2(edge.x - into.x, edge.z - into.z).length()
			if drop < MIN_DROP or drop > MAX_DROP or reach > EDGE_REACH:
				continue
			if best.has(pit) and float(best[pit][0]) <= reach:
				continue
			# open from above: a little past the pit's near side nothing
			# stands between the edge's height and the pit's floor
			var away := Vector3(into.x - edge.x, 0.0, into.z - edge.z)
			var probe := into + (away.normalized() * 0.3 if away.length() > 0.01 else Vector3.ZERO)
			ray.from = Vector3(probe.x, edge.y + 0.3, probe.z)
			ray.to = Vector3(probe.x, into.y - 0.4, probe.z)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or absf((hit["position"] as Vector3).y - into.y) > 0.35:
				continue
			best[pit] = [reach, edge, probe]
	candidates += best.size()
	for pit: int in best:
		if graph.area_of(pit) < MIN_PIT:
			continue
		var edge: Vector3 = best[pit][1]
		var into: Vector3 = best[pit][2]
		var key := "%s|%s" % [edge.snapped(Vector3.ONE * 0.5), ",".join(open)]
		if _checked.has(key):
			continue
		_checked[key] = true
		await _try_pit(state, progress, comp, pit, edge, into)


## He walks off [param edge] toward [param into]; down in [param pit], he
## tries his way back up, then the locks he can work from down there.
func _try_pit(state: String, progress: FloorProgress, comp: int, pit: int, edge: Vector3, into: Vector3) -> void:
	var graph := survey.graph
	var start := walker.standing_spot(edge, 0.35)
	if start == Vector3.INF:
		start = walker.standing_spot(edge.lerp(Vector3(into.x, edge.y, into.z), -0.6), 0.35)
	if start == Vector3.INF:
		return
	walker.place(start)
	var off := Vector3(into.x, start.y, into.z) + (Vector3(into.x, 0, into.z) - Vector3(start.x, 0, start.z)).normalized() * 0.6
	walker.follow(PackedVector3Array([start, off]), 1.0)
	for i in 180:
		if walker.guard.is_on_floor():
			break
		walker.step(Vector3.ZERO)
	var landed := walker.feet()
	walked_off += 1
	if graph.component_at(landed, 0.6) != pit:
		return   # he does not end up down there
	var where := "%s: %s at %s (%.1f m down from %s)" % [state, survey.room_of(landed), landed.snapped(Vector3.ONE * 0.1), start.y - landed.y, start.snapped(Vector3.ONE * 0.1)]
	# back up: walking and jumping at the nearest points of the floor above
	var ups: Array[Vector3] = []
	for p in graph.polygons_near(landed, 4.0):
		if graph.component[p] == comp:
			ups.append(graph.closest_on(p, landed))
	ups.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(landed) < b.distance_squared_to(landed))
	for goal in ups.slice(0, 5):
		walker.place(landed)
		var back := walker.follow(PackedVector3Array([landed, Walker.past_edge(landed, goal)]), 2.0, true)
		walker.settle()   # (a way out over a further edge: he lands first)
		if back["ok"] and graph.component_at(walker.feet(), 0.6) == comp:
			dropped.append("%s - climbs back" % where)
			return
	# up a flight whose foot lies down there
	for flight in survey.level.layout.stairs:
		var frame := flight.frame()
		var foot := frame * Vector3(0.0, 0.0, 0.8)
		if absf(foot.y - landed.y) > 0.6 or graph.component_at(foot, 0.8) != pit:
			continue
		var rise := flight.top_y - flight.bottom_y
		var top := frame * Vector3(0.0, rise, -(flight.run() + 0.8))
		walker.place(landed)
		var climb := walker.follow(PackedVector3Array([landed, foot, frame * Vector3.ZERO, frame * Vector3(0.0, rise, -flight.run()), top]), 3.0)
		if climb["ok"] and graph.component_at(walker.feet(), 0.6) == comp:
			dropped.append("%s - climbs %s" % [where, flight.id])
			return
	# a lock he can work from down there
	for spec in survey.level.layout.gates:
		if spec.opening == &"" or progress.gates_open.has(spec.id):
			continue
		if survey.lock_reach(spec, progress, pit)["ok"]:
			dropped.append("%s - opens %s from down there" % [where, spec.id])
			return
	traps.append("%s: he cannot get out" % where)
