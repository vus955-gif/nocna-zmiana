extends Floor1ReachCase
## No soft lock on Floor I, proven on the built floor's navmesh (P1 / W7;
## plan docs/superpowers/plans/2026-10-03-p1-w7-weryfikacja.md): the
## checks are Floor1ReachCase's. This fast variant walks the HUD order
## (every haven, tonight's doors) and two random orders, the 100% state
## and the game's navmesh through every open passage; the deep variant
## (test_floor1_reachability_deep, --filter=deep) walks many more orders.

## Random orders in this fast variant (the deep one walks more).
const RANDOM_SEEDS: Array[int] = [3, 8]


func test_every_state_of_the_hud_order_reaches_its_next_step() -> void:
	await _survey()
	var started := Time.get_ticks_msec()
	await walk_order(Floor1Route.hud_order(), "hud", true)
	print("W7 hud order: %d bakes (%d ms), %d ms in all" % [survey.bakes, survey.bake_msec, Time.get_ticks_msec() - started])
	for gate_id: StringName in opened_how:
		print("W7 gate %s: %s" % [gate_id, opened_how[gate_id]])


func test_random_play_orders_never_soft_lock() -> void:
	await _survey()
	var started := Time.get_ticks_msec()
	for seed_value in RANDOM_SEEDS:
		await walk_order(Floor1Route.random_order(seed_value), "seed %d" % seed_value, false)
	print("W7 random orders %s: %d bakes (%d ms), %d ms in all" % [RANDOM_SEEDS, survey.bakes, survey.bake_msec, Time.get_ticks_msec() - started])


func test_at_100_percent_everything_is_reached() -> void:
	await _survey()
	var progress := FloorProgress.new()
	for step in Floor1Route.hud_order():
		ProgressRules.apply(progress, step)
	var every: Array[StringName] = []
	for spec in survey.level.layout.gates:
		if spec.opening != &"":
			every.append(spec.id)
	var open := await open_on_foot(progress, [], every, "100%", true)
	progress.gates_open = open.duplicate()
	var start := survey.haven_start(&"security")
	var comp := survey.graph.component_at(start)
	for gate_id in every:
		_check(open.has(gate_id), "gate:%s:100" % gate_id, "100%%: gate %s is opened on foot (%s)" % [gate_id, survey.lock_reach(survey.level.layout.gate(gate_id), progress, comp)["how"]])
	var reached := survey.rooms_on(comp)
	for room in survey.level.layout.rooms:
		if room.haven:
			var out := survey.haven_exits(Floor1Plan.havens().filter(func(h: Floor1Plan.HavenPlan) -> bool: return h.room == room.id)[0].id)
			_check(out.size() > 0 and Array(out).any(func(at: Vector3) -> bool: return survey.graph.component_at(at) == comp), "room:%s:100" % room.id, "100%%: haven %s opens onto the floor" % room.id)
			continue
		_check(reached.has(room.id), "room:%s:100" % room.id, "100%%: room %s (%s) is walked to" % [room.id, room.zone])
		var point := survey.room_point(room.id, comp)
		if point != Vector3.INF:
			_check(survey.confirmed(start, point), "map:%s" % room.id, "100%%: the map agrees on %s" % room.id)
	var counts := {"secret_": 0, "note_": 0, "chess_": 0}
	for marker: StringName in survey.level.markers:
		var text := String(marker)
		for prefix: String in counts:
			if not text.begins_with(prefix):
				continue
			counts[prefix] = int(counts[prefix]) + 1
			var room := survey.level.layout.room(survey.level.layout.marker_rooms.get(marker, &""))
			if prefix == "secret_" and room != null and room.secret:
				_check(reached.has(room.id), "marker:%s" % marker, "100%%: secret %s: its room %s is walked into" % [marker, room.id])
				continue
			var at := (survey.level.markers[marker] as Transform3D).origin
			var reach := _reach_marker(at, room, comp, start, &"use", Floor1Route.USE_REACH + Floor1Route.PROP_SLACK)
			_check(reach["ok"], "marker:%s" % marker, "100%%: %s in %s within reach (closest %.2f m)" % [marker, room.id if room != null else "-", reach["distance"]])
	print("W7 100%%: %d gates open, %d rooms, markers %s, navmesh %.0f m2 walkable" % [open.size(), reached.size(), counts, survey.graph.area_of(comp)])
	for found: Dictionary in survey.breaks:
		print("W7 navmesh misses %s (%s -> %s)" % [found["what"], found["a"], found["b"]])
	assert_gt(float(counts["secret_"]), 15.0, "the secrets are on the floor")
	assert_eq(int(counts["chess_"]), 8, "eight Lewis chess pieces")
	# the rope of the Planetarium: out of the pistol's reach from every floor
	# outside the rotunda (rope 3-6 m over its counterweight marker; any
	# polygon, prop tops too)
	var rope := survey.gates.lock_of(&"rope_planetarium")
	if rope != null:
		var low: Vector3 = rope.global_transform * Vector3(0, float(rope.get(&"height")) - float(rope.get(&"hang")), 0)
		var high: Vector3 = rope.global_transform * Vector3(0, float(rope.get(&"height")), 0)
		var nearest := INF
		var where := Vector3.INF
		for p in survey.graph.polygons.size():
			var room := survey.level.layout.room(survey.room_of(survey.graph.centers[p] + Vector3.UP * 0.3))
			if room != null and room.progress_area() == &"planetarium":
				continue
			for v in survey.graph.polygons[p]:
				var eye := survey.graph.vertices[v] + Vector3.UP * Floor1Survey.EYE
				var distance := eye.distance_to(Geometry3D.get_closest_point_to_segment(eye, low, high))
				if distance < nearest:
					nearest = distance
					where = survey.graph.vertices[v]
		print("W7 Planetarium rope: closest eye outside the rotunda %.1f m (at %s)" % [nearest, where])
		assert_gt(nearest, LockRules.ROPE_PISTOL_RANGE, "the pistol never reaches the Planetarium's rope (closest at %s)" % [where])


func test_the_game_navmesh_walks_through_every_open_passage() -> void:
	await _survey()
	var every: Array[StringName] = []
	for spec in survey.level.layout.gates:
		if spec.opening != &"":
			every.append(spec.id)
	await survey.use_gates(every, [], true)
	var found := survey.passage_breaks()
	for entry: Array in found:
		var what: String = entry[0]
		var message := "the game's navmesh does not walk through %s (%.1f m across, path %s m): exhibits cannot follow the guard there" % [what, entry[1], "none" if entry[2] == INF else "%.0f" % entry[2]]
		if NAVMESH_FINDINGS.has(what):
			_note("W7 FINDING (%s): %s" % [NAVMESH_FINDINGS[what], message])
		else:
			fail(message)
	for what: String in NAVMESH_FINDINGS:
		if not found.any(func(entry: Array) -> bool: return entry[0] == what):
			_note("W7: %s is walked through now - drop it from NAVMESH_FINDINGS" % what)
	print("W7 navmesh: %d passages the game's mesh misses" % found.size())


## Every lock asked side by side (each door shut, the guard on the floor in
## front of the wall): a bolt must work from its side, a plan gate of
## boards, a seal or a cracked wall from both, any other lock from at least
## one (the side the guard comes from is checked by the play orders).
## Prints the table for the report.
func test_every_lock_works_from_its_sides() -> void:
	await _survey()
	var every: Array[StringName] = []
	for spec in survey.level.layout.gates:
		if spec.opening != &"":
			every.append(spec.id)
	await survey.use_gates(every, [], true)
	var comp := survey.graph.component_at(survey.haven_start(&"security"))
	survey.shut_every_lock()
	await physics_frames(2)
	var progress := FloorProgress.new()
	for step in Floor1Route.hud_order():
		ProgressRules.apply(progress, step)
	for spec in survey.level.layout.gates:
		if spec.opening == &"" or spec.kind == GateSpec.Kind.POWER or spec.kind == GateSpec.Kind.EVENT:
			continue
		var passage := survey.level.layout.opening(spec.opening)
		var sides: Array[StringName] = [passage.room_a, passage.room_b]
		if spec.kind == GateSpec.Kind.BOLT:
			sides = [spec.one_way_side]
		var line := PackedStringArray()
		var works := false
		# a plan gate of boards, a seal or a cracked wall opens from either side
		var both := Floor1Plan.gate(spec.id) != null and spec.kind in [GateSpec.Kind.BOARDS, GateSpec.Kind.SEAL, GateSpec.Kind.CRACKED]
		for room_id in sides:
			var reach := survey.lock_reach(spec, progress, comp, room_id)
			works = works or reach["ok"]
			if both:
				_check(reach["ok"], "side:%s:%s" % [spec.id, room_id], "the lock of %s (%s) cannot be worked from %s" % [spec.id, GateSpec.kind_name(spec.kind), room_id])
			line.append("%s %s: %s" % ["A" if room_id == passage.room_a else "B", room_id, "%s @ %.1f m" % [reach["how"], reach["distance"]] if reach["ok"] else "no"])
		_check(works, "lock:%s" % spec.id, "the lock of %s (%s) works from no side (%s)" % [spec.id, GateSpec.kind_name(spec.kind), " | ".join(line)])
		print("W7 sides %s (%s): %s" % [spec.id, GateSpec.kind_name(spec.kind), " | ".join(line)])
