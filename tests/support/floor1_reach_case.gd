class_name Floor1ReachCase
extends TestCase
## No soft lock on Floor I, proven on the built floor's navmesh (P1 / W7;
## plan docs/superpowers/plans/2026-10-03-p1-w7-weryfikacja.md, design
## pietro-1-projekt 4.2 "nigdy nie da się utknąć" and 12).
## For a play order (the one the HUD goal leads a new player along; random
## valid ones) and every state on it:
## - the gates the guard opens on foot: from the gates open so far, every
##   gate of the plan whose requirement he meets and whose lock he can work
##   from the side that opens it (a bolt from its side, a seal or a chain by
##   hand, a rope, a hook ring or a cracked wall within his weapon's range
##   with nothing in the way - Floor1Survey) opens, again and again; the
##   zones' secret gates stay shut (nothing needed lies behind a secret);
## - that set equals what ProgressRules says he can open, and the areas he
##   walks to equal ProgressRules.reachable_areas (the coarse area graph
##   and the real floor agree);
## - every step he can do now (the HUD goal among them) has its target
##   within reach on foot, from every haven he knows by then (havens are a
##   region of their own: he starts outside their doors);
## - every door the night director may lock that night (safe_doors) keeps
##   the HUD goal reachable from every known haven.
## At 100% (every step done, every gate with a reachable lock open, the
## secret ones too) every room, secret, note and chess piece is reached.
## The Planetarium's rope hangs out of the pistol's reach from anywhere
## outside the rotunda. Findings of this verification still open are
## listed in FINDINGS: printed, not failed (none open now: every check is
## a hard assert).
## The shared part of test_floor1_reachability (fast) and
## test_floor1_reachability_deep (more orders; bash tools/run_tests.sh
## --filter=deep).

const NavProbe := preload("res://tests/support/nav_probe.gd")
## Findings of this verification still open: check id prefix -> what it
## is (printed, never failed; the report docs/raporty/2026-10-03-czas-
## przejscia.html lists them; drop an entry once it is fixed - the test
## says so).
const FINDINGS := {}
## Gates whose lock cannot be worked from where the rules say: taken as
## opened from the side the guard stands on, the rest of the floor still
## checked, printed every time. Empty: every lock works on foot (W7-1 is
## fixed - a lock with a body of its own holds its passage, the door's
## leaves no longer stand in front of it: GateController).
const ASSUMED_OPEN: Array[StringName] = []
## Passages the game's navmesh does not walk through (exhibits cannot follow
## the guard there; he walks through: the survey joins them) -> why. Empty:
## W7-2 is fixed (enlightenment_stairs_stacks is 2 m wide).
const NAVMESH_FINDINGS := {}
var survey: Floor1Survey
## Gate id -> how it was first opened on foot ("tool @ metres in state").
var opened_how: Dictionary = {}
var _noted: Dictionary = {}


func after_each() -> void:
	if is_instance_valid(survey):
		survey.free()


func _survey() -> void:
	survey = Floor1Survey.new()
	add_child(survey)
	await survey.setup()


# --- walking an order -----------------------------------------------------------------

## Walks [param order] state by state (see the file's head); with
## [param per_haven] every step's target is confirmed on the map from every
## known haven's door, and tonight's lockable doors are tried.
func walk_order(order: Array[StringName], label: String, per_haven: bool) -> void:
	assert_true(Floor1Route.is_valid(order), "%s is a play-through by the rules" % label)
	var progress := FloorProgress.new()
	var open: Array[StringName] = []
	var known: Array[StringName] = [&"security"]
	var plan_gates: Array[StringName] = []
	for gate in Floor1Plan.gates():
		var spec := survey.level.layout.gate(gate.id)
		if spec != null and spec.opening != &"":
			plan_gates.append(gate.id)
	for k in order.size():
		var step := order[k]
		var state := "%s #%d (before %s)" % [label, k + 1, step]
		open = await open_on_foot(progress, open, plan_gates, state)
		progress.gates_open = open.duplicate()
		var start := survey.haven_start(&"security")
		var comp := survey.graph.component_at(start)
		_check(comp >= 0, "start:%s" % state, "%s: the security booth opens onto the navmesh" % state)
		if comp < 0:
			return
		# the gates and the areas agree with ProgressRules
		var rules_open := progress.gates_open.duplicate()
		for gate_id in ProgressRules.openable_gates(progress):
			if not rules_open.has(gate_id):
				rules_open.append(gate_id)
		for gate_id in rules_open:
			if plan_gates.has(gate_id):
				_check(open.has(gate_id), "lock:%s" % gate_id, "%s: the rules open %s, but its lock is out of reach on foot (%s)" % [state, gate_id, survey.lock_reach(survey.level.layout.gate(gate_id), progress, comp)["how"]])
		for gate_id in open:
			_check(rules_open.has(gate_id), "extra:%s" % gate_id, "%s: the guard opens %s on foot, the rules do not" % [state, gate_id])
		var areas := {}
		for room_id: StringName in survey.rooms_on(comp):
			var room := survey.level.layout.room(room_id)
			if room != null and not room.haven:
				areas[room.progress_area()] = true
		var rule_areas := ProgressRules.reachable_areas(progress)
		for area: StringName in rule_areas:
			_check(areas.has(area), "area:%s:%s" % [area, step], "%s: the rules reach area %s, the navmesh does not" % [state, area])
		for area: StringName in areas:
			_check(rule_areas.has(area), "area:%s:%s" % [area, step], "%s: the navmesh reaches area %s, the rules do not (gates open: %s)" % [state, area, open])
		# the havens known by now open onto the same floor
		for haven in Floor1Plan.havens():
			var exits := survey.haven_exits(haven.id)
			var on_floor := Array(exits).any(func(at: Vector3) -> bool: return survey.graph.component_at(at) == comp)
			if on_floor and not known.has(haven.id):
				known.append(haven.id)
			elif known.has(haven.id):
				_check(on_floor, "haven:%s" % haven.id, "%s: the known haven %s is cut off" % [state, haven.id])
		# every step he can do now is within reach on foot
		var goal := ProgressRules.next_step(progress)
		var available := ProgressRules.available_steps(progress)
		_check(available.has(step), "order:%s" % state, "%s: %s can be done (rules)" % [state, step])
		for doable in available:
			var reach := _reach_step(doable, comp, start)
			_check(reach["ok"], "step:%s" % doable, "%s: %s%s is reached on foot (%s; closest %.2f m)" % [state, doable, " (the HUD goal)" if doable == goal else "", reach.get("marker", ""), reach.get("distance", INF)])
			if not per_haven or not reach["ok"] or reach.get("how", "") in ["squeeze", "haven"]:
				continue
			for haven_id in known:
				var from := survey.haven_start(haven_id)
				_check(survey.confirmed(from, reach["point"]), "haven:%s:%s" % [haven_id, doable], "%s: %s is walked to from the haven %s" % [state, doable, haven_id])
		# tonight's lockable doors keep the goal in reach from every known haven
		if per_haven:
			for door_id in _night_doors(progress, known):
				await survey.use_gates(open, [door_id] as Array[StringName])
				for haven_id in known:
					var from := survey.haven_start(haven_id)
					var from_comp := survey.graph.component_at(from)
					var reach := _reach_step(goal, from_comp, from)
					_check(reach["ok"], "night:%s:%s" % [door_id, goal], "%s: with %s locked the goal %s is reached from %s" % [state, door_id, goal, haven_id])
				await survey.use_gates(open)
		print("W7 %s: %d gates open, %d havens known, steps %s, %.0f m2" % [state, open.size(), known.size(), available, survey.graph.area_of(comp)])
		ProgressRules.apply(progress, step)


## From the gates [param open], every gate of [param candidates] whose
## lock the guard with [param progress] works on foot opens, until no more
## do (the navmesh baked anew after each round). Returns the open set; the
## survey stands in it.
func open_on_foot(progress: FloorProgress, open: Array[StringName], candidates: Array[StringName], state: String, hidden: bool = false) -> Array[StringName]:
	var current: Array[StringName] = open.duplicate()
	for _pass in 32:
		await survey.use_gates(current, [], hidden)
		var comp := survey.graph.component_at(survey.haven_start(&"security"))
		var added: Array[StringName] = []
		for gate_id in candidates:
			if current.has(gate_id):
				continue
			var spec := survey.level.layout.gate(gate_id)
			var reach := survey.lock_reach(spec, progress, comp)
			if reach["ok"]:
				added.append(gate_id)
				if not opened_how.has(gate_id):
					opened_how[gate_id] = "%s @ %.1f m in %s" % [reach["how"], reach["distance"], state]
				if ASSUMED_OPEN.has(gate_id):
					_note("W7: %s opens on foot now (%s) - drop it from ASSUMED_OPEN and FINDINGS" % [gate_id, reach["how"]])
			elif ASSUMED_OPEN.has(gate_id) and reach["how"] == "unreachable" and survey.side_reached(spec, comp):
				added.append(gate_id)
				_note("W7 FINDING (%s): %s taken as opened" % [_finding_of(gate_id), gate_id])
				if not opened_how.has(gate_id):
					opened_how[gate_id] = "ASSUMED (finding W7-1) in %s" % state
		if added.is_empty():
			break
		current.append_array(added)
	return current


## Is the target of [param step] within reach of component [param comp]
## (confirmed on the map from [param start])?
func _reach_step(step: StringName, comp: int, start: Vector3) -> Dictionary:
	var target := Floor1Route.step_target(step, survey.level.markers)
	if target.is_empty() or target["at"] == Vector3.INF:
		return {"ok": false, "marker": target.get("marker", ""), "distance": INF}
	var marker: StringName = target["marker"]
	var room := survey.level.layout.room(survey.level.layout.marker_rooms.get(marker, &""))
	var reach := _reach_marker(target["at"], room, comp, start, target["kind"], target["reach"])
	reach["marker"] = marker
	return reach


## Reach of a marker at [param at] in [param room]: from the walkable
## floor, or - in a haven's room - through the haven's door.
func _reach_marker(at: Vector3, room: RoomSpec, comp: int, start: Vector3, kind: StringName, reach: float) -> Dictionary:
	if room != null and room.haven:
		return _reach_in_haven(at, room, comp, start, reach)
	var found := survey.marker_reach(at, comp, kind, reach, room.floor_y if room != null else INF)
	if found["ok"] and found.get("how", "") != "squeeze" and not survey.confirmed(start, found["point"]):
		found["ok"] = false
		found["why"] = "the map does not connect it"
	return found


## A marker inside a haven's room: the haven opens onto component
## [param comp], and its own navmesh leads from its door to the marker.
func _reach_in_haven(at: Vector3, room: RoomSpec, comp: int, _start: Vector3, reach: float) -> Dictionary:
	for haven in Floor1Plan.havens():
		if haven.room != room.id:
			continue
		if not Array(survey.haven_exits(haven.id)).any(func(p: Vector3) -> bool: return survey.graph.component_at(p) == comp):
			return {"ok": false, "distance": INF, "why": "the haven is cut off"}
		return survey.haven_reach(haven.id, at, reach)
	return {"ok": false, "distance": INF}


## Tonight's lockable doors for a save at [param progress] with
## [param havens] known (FloorNight's description, NightDirector.safe_doors).
func _night_doors(progress: FloorProgress, havens: Array[StringName]) -> Array[StringName]:
	GameState.weapons.assign(progress.weapons)
	GameState.items.assign(progress.items)
	GameState.seals.assign(progress.seals)
	GameState.shards.assign(progress.shards)
	GameState.guardians_defeated.assign(progress.guardians)
	GameState.gates_open.assign(progress.gates_open)
	GameState.flags.assign(progress.flags)
	GameState.havens.assign(havens)
	GameState.night = 2
	var doors := NightDirector.safe_doors(FloorNight.describe_tonight(GameState, survey.level.layout))
	GameState.reset()
	return doors



## A check: fails the test unless [param id] is a finding (then it is
## only printed).
func _check(ok: bool, id: String, message: String) -> void:
	if ok:
		return
	for known: String in FINDINGS:
		if id.begins_with(known):
			_note("W7 FINDING (%s): %s" % [FINDINGS[known], message])
			return
	fail(message)


func _finding_of(gate_id: StringName) -> String:
	for known: String in FINDINGS:
		if known.ends_with(":" + String(gate_id)):
			return FINDINGS[known]
	return "W7-1"


## Prints [param text] once per test.
func _note(text: String) -> void:
	if not _noted.has(text):
		_noted[text] = true
		print(text)
