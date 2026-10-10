class_name ProgressRules
extends RefCounted
## What opens what on Floor I (design: pietro-1-projekt sections 3.3,
## 4.2-4.3), as pure logic over Floor1Plan's areas, junctions and gates and
## a FloorProgress snapshot: which areas the guard can reach, which gates
## he can open, which step of the floor comes next (the goal on the HUD and
## the paper map), which guardians he can get to, and whether a state could
## still reach the end (never a soft lock).
##
## A step is something the guard does once for good: take a progress
## pickup (Floor1Plan.PICKUPS), defeat a guardian (GUARDIANS), defeat the
## T-Rex (needs the astrolabe), walk down into the crypt (the end).
## Everything is monotonic (nothing is ever taken back), so a greedy walk
## over the steps decides reachability exactly.

## The finale's steps (besides pickups and guardians).
const TREX := &"trex"
const DESCEND := &"descend"
const COMPLETE_FLAG := &"floor1_complete"
const TREX_DEFEATED := &"trex_defeated"
const SHARDS_ALL := &"shards_6"
const START_AREA := &"booth"

## The goal order (design 3.4, a new player's typical path): step id ->
## goal translation key. goal() shows the first step not done yet that the
## guard can do now.
const STEPS := [
	[&"pistol_key", &"GOAL_TICKET_KEY"],
	[&"pistol", &"GOAL_PISTOL"],
	[&"flare", &"GOAL_FLARE"],
	[&"shotgun", &"GOAL_SHOTGUN"],
	[&"colossus", &"GOAL_GUARDIAN_EGYPT"],
	[&"rifle_hunt", &"GOAL_RIFLE"],
	[&"planetarium", &"GOAL_GUARDIAN_ENLIGHTENMENT"],
	[&"lamassu", &"GOAL_GUARDIAN_ASSYRIA"],
	[&"centaur", &"GOAL_GUARDIAN_GREECE"],
	[&"gatling", &"GOAL_GATLING"],
	[&"fuse_basement", &"GOAL_FUSE_BASEMENT"],
	[&"fuse_assyria", &"GOAL_FUSE_ASSYRIA"],
	[&"power_north", &"GOAL_POWER"],
	[&"hwacha", &"GOAL_HWACHA"],
	[&"general", &"GOAL_GUARDIAN_ASIA"],
	[&"harpoon", &"GOAL_HARPOON"],
	[&"serpent", &"GOAL_GUARDIAN_AMERICAS"],
	[&"astrolabe", &"GOAL_ASTROLABE"],
	[&"trex", &"GOAL_TREX"],
	[&"descend", &"GOAL_DESCEND"],
]
## Shown when no step can be done now (should not happen on a sound floor)
## and after the end.
const GOAL_EXPLORE := &"GOAL_EXPLORE"
const GOAL_EPILOGUE := &"GOAL_EPILOGUE"


# --- requirements and gates ---------------------------------------------------

## True when the guard in [param progress] meets requirement [param token]
## (GateSpec tokens, weapon / item / seal / flag ids, &"shards_6",
## &"trex_defeated").
static func has_requirement(progress: FloorProgress, token: StringName) -> bool:
	match token:
		GateSpec.NONE, GateSpec.HEAVY:
			return true   # fists always hit hard enough, given time
		GateSpec.PRECISE:
			return progress.weapons.has(&"pistol") or progress.weapons.has(&"rifle_hunt")
		GateSpec.EXPLOSIVE:
			return progress.weapons.has(&"hwacha") or progress.weapons.has(&"flare")
		SHARDS_ALL:
			return progress.shards.size() >= Floor1Plan.SHARD_COUNT
		TREX_DEFEATED:
			return progress.guardians.has(TREX)
	return progress.has(token)


static func has_all(progress: FloorProgress, tokens: Array) -> bool:
	for token: StringName in tokens:
		if not has_requirement(progress, token):
			return false
	return true


## True when the guard standing in [param from_area] can open (or walk
## through) gate [param gate_id]: open already, or its requirement met (a
## BOLT only from its bolt side).
static func can_open(progress: FloorProgress, gate_id: StringName, from_area: StringName) -> bool:
	if gate_id == &"" or progress.gates_open.has(gate_id):
		return true
	var gate := Floor1Plan.gate(gate_id)
	if gate == null:
		return false
	if gate.kind == GateSpec.Kind.BOLT and from_area != gate.bolt_area:
		return false
	return has_requirement(progress, gate.requirement)


# --- reachability ---------------------------------------------------------------

## Area -> true for every area the guard can get to from [param start]
## (an area id) now, opening what he can on the way. Junctions listed in
## [param closed] are shut (tonight's locked door).
static func reachable_areas(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> Dictionary:
	var seen := {start: true}
	var queue: Array[StringName] = [start]
	var edges := _edges()
	while not queue.is_empty():
		var area: StringName = queue.pop_front()
		for edge: Array in edges.get(area, []):
			var next: StringName = edge[0]
			if seen.has(next) or closed.has(edge[2]):
				continue
			if can_open(progress, edge[1], area):
				seen[next] = true
				queue.append(next)
	return seen


static func is_reachable(progress: FloorProgress, area: StringName, start: StringName = START_AREA, closed: Array[StringName] = []) -> bool:
	return reachable_areas(progress, start, closed).has(area)


## The area a night starting in haven [param haven_id] begins in.
static func start_area(haven_id: StringName) -> StringName:
	var haven := Floor1Plan.haven(haven_id)
	return haven.area if haven != null else START_AREA


# --- steps ----------------------------------------------------------------------

## Every step id: the pickups, the guardians, then the finale.
static func step_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for pickup in Floor1Plan.pickups():
		ids.append(pickup.id)
	for guardian in Floor1Plan.guardians():
		ids.append(guardian.id)
	ids.append(TREX)
	ids.append(DESCEND)
	return ids


## The area a step happens in.
static func step_area(step: StringName) -> StringName:
	var pickup := Floor1Plan.pickup(step)
	if pickup != null:
		return pickup.area
	var guardian := Floor1Plan.guardian(step)
	if guardian != null:
		return guardian.area
	match step:
		TREX:
			return Floor1Plan.zone_of_area(&"court")
		DESCEND:
			return &"crypt"
	return &""


## What a step needs besides getting to its area.
static func step_requires(step: StringName) -> Array:
	var pickup := Floor1Plan.pickup(step)
	if pickup != null:
		return pickup.requires
	if step == TREX:
		return [&"astrolabe"]
	return []


static func is_done(progress: FloorProgress, step: StringName) -> bool:
	match step:
		&"pistol_key":
			return progress.items.has(step) or progress.weapons.has(&"pistol")
		DESCEND:
			return progress.flags.has(COMPLETE_FLAG)
	return progress.has(step)


## True when the guard can do [param step] now (not done, its area within
## reach, its requirements met). [param reached] = reachable_areas(...),
## computed when not given.
static func can_do(progress: FloorProgress, step: StringName, reached: Dictionary = {}) -> bool:
	if is_done(progress, step):
		return false
	var areas := reached if not reached.is_empty() else reachable_areas(progress)
	return areas.has(step_area(step)) and has_all(progress, step_requires(step))


## Steps the guard can do now, in STEPS order.
static func available_steps(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> Array[StringName]:
	var reached := reachable_areas(progress, start, closed)
	var found: Array[StringName] = []
	for row: Array in STEPS:
		if can_do(progress, row[0], reached):
			found.append(row[0])
	return found


## Records [param step] as done in [param progress] (its effect: a weapon,
## item or flag; a guardian with its seal and shard; the T-Rex; the end).
static func apply(progress: FloorProgress, step: StringName) -> void:
	var pickup := Floor1Plan.pickup(step)
	if pickup != null:
		match pickup.kind:
			&"weapon":
				FloorProgress.add_to(progress.weapons, step)
			&"flag":
				FloorProgress.add_to(progress.flags, step)
			_:
				FloorProgress.add_to(progress.items, step)
		return
	var guardian := Floor1Plan.guardian(step)
	if guardian != null:
		FloorProgress.add_to(progress.guardians, step)
		FloorProgress.add_to(progress.seals, guardian.seal)
		FloorProgress.add_to(progress.shards, guardian.shard)
		return
	match step:
		TREX:
			FloorProgress.add_to(progress.guardians, TREX)
		DESCEND:
			FloorProgress.add_to(progress.flags, COMPLETE_FLAG)


## Gates the guard can open from where he can get to (the bolts he would
## draw on the way, the seals he would use).
static func openable_gates(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> Array[StringName]:
	var reached := reachable_areas(progress, start, closed)
	var found: Array[StringName] = []
	for gate in Floor1Plan.gates():
		if progress.gates_open.has(gate.id) or gate.area_a == gate.area_b:
			continue
		var junction := Floor1Plan.junction(gate.junction) if gate.junction != &"" else null
		if junction != null and closed.has(junction.id):
			continue
		for side: StringName in [gate.area_a, gate.area_b]:
			if reached.has(side) and can_open(progress, gate.id, side):
				found.append(gate.id)
				break
	return found


# --- goal, guardians, soft locks ----------------------------------------------

## The goal for the HUD and the map: the first step in STEPS order the guard
## can do now; GOAL_EPILOGUE after the end; GOAL_EXPLORE when nothing can be
## done (a soft lock; never on a sound floor).
static func goal(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> StringName:
	if progress.flags.has(COMPLETE_FLAG):
		return GOAL_EPILOGUE
	var reached := reachable_areas(progress, start, closed)
	for row: Array in STEPS:
		if can_do(progress, row[0], reached):
			return row[1]
	return GOAL_EXPLORE


## The step behind goal() (&"" when there is none).
static func next_step(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> StringName:
	var reached := reachable_areas(progress, start, closed)
	for row: Array in STEPS:
		if can_do(progress, row[0], reached):
			return row[0]
	return &""


## True when the guard can get to guardian [param guardian_id]'s arena now
## and it still stands.
static func guardian_reachable(progress: FloorProgress, guardian_id: StringName, start: StringName = START_AREA, closed: Array[StringName] = []) -> bool:
	var guardian := Floor1Plan.guardian(guardian_id)
	if guardian == null or progress.guardians.has(guardian_id):
		return false
	return reachable_areas(progress, start, closed).has(guardian.area)


## Guardians standing and within reach now.
static func reachable_guardians(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> Array[StringName]:
	var reached := reachable_areas(progress, start, closed)
	var found: Array[StringName] = []
	for guardian in Floor1Plan.guardians():
		if not progress.guardians.has(guardian.id) and reached.has(guardian.area):
			found.append(guardian.id)
	return found


## [param progress] carried as far as it goes: every step the guard can do,
## every gate he can open, again and again until nothing changes (a copy).
static func finish(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> FloorProgress:
	var result := progress.copy()
	var changed := true
	while changed:
		changed = false
		for gate_id in openable_gates(result, start, closed):
			FloorProgress.add_to(result.gates_open, gate_id)
			changed = true
		for step in available_steps(result, start, closed):
			apply(result, step)
			changed = true
	return result


static func is_complete(progress: FloorProgress) -> bool:
	return progress.flags.has(COMPLETE_FLAG)


## True when the floor can no longer be finished from [param progress]
## (starting in [param start], with [param closed] junctions shut for good).
static func is_soft_locked(progress: FloorProgress, start: StringName = START_AREA, closed: Array[StringName] = []) -> bool:
	return not is_complete(finish(progress, start, closed))


# --- the area graph ----------------------------------------------------------------

static var _edge_cache: Dictionary = {}


## Area -> Array of [other area, gate id (&"" = none), junction id (&"" =
## inside a zone)], both directions.
static func _edges() -> Dictionary:
	if not _edge_cache.is_empty():
		return _edge_cache
	var edges := {}
	for j in Floor1Plan.junctions():
		_link(edges, j.area_a, j.area_b, j.gate, j.id)
	for gate in Floor1Plan.gates():
		if gate.junction == &"" and gate.area_a != gate.area_b:
			_link(edges, gate.area_a, gate.area_b, gate.id, &"")
	# a zone's sub-areas behind no gate would be listed here; every sub-area
	# of Floor I lies behind one of the internal gates above
	_edge_cache = edges
	return edges


static func _link(edges: Dictionary, a: StringName, b: StringName, gate: StringName, junction: StringName) -> void:
	if not edges.has(a):
		edges[a] = []
	if not edges.has(b):
		edges[b] = []
	(edges[a] as Array).append([b, gate, junction])
	(edges[b] as Array).append([a, gate, junction])
