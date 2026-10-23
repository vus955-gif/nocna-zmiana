class_name PlaythroughBrain
extends RefCounted
## The playthrough bot's decisions as pure logic (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md): no nodes, numbers
## in, a choice out. The way through Floor I's areas and the gates to open
## on it (ProgressRules' area graph: a bolt only from its own side), the
## tool for each lock (LockRules), the weapon for a fight, the rounds kept
## back for the locks still ahead, when to break off for a haven (hurt, or
## dawn coming), what to buy at a terminal, which exhibit to fight first.

## Player.walk_speed (m/s): the bot's estimate of a walk.
const WALK_SPEED := 5.5
## A closed gate on the way costs this much more than a plain passage (the
## walk to its lock, the tool, the wait).
const GATE_COST := 3.0

# --- the way through the areas ------------------------------------------------------------

## The way from area [param from] to area [param to] with [param progress]:
## hops [{area, gate, from, open, junction}] in walking order (area = where
## the hop leads, gate = the gate on it or &"", from = the area it is
## walked from, open = the gate needs no work); the cheapest by passages
## and closed gates (GATE_COST). A gate he cannot open from where he stands
## (a bolt from its far side, a seal without its key) is no way. Junctions in
## [param closed] are shut (tonight's locked door). [] when [param to] is
## out of reach (or he is there).
static func area_route(progress: FloorProgress, from: StringName, to: StringName, closed: Array[StringName] = []) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	if from == to:
		return route
	var edges := _edges()
	var cost := {from: 0.0}
	var back := {}
	var open_set: Array[StringName] = [from]
	while not open_set.is_empty():
		var best := 0
		for i in open_set.size():
			if float(cost[open_set[i]]) < float(cost[open_set[best]]):
				best = i
		var area: StringName = open_set[best]
		open_set.remove_at(best)
		if area == to:
			break
		for edge: Array in edges.get(area, []):
			var next: StringName = edge[0]
			var gate: StringName = edge[1]
			if closed.has(edge[2]) or not ProgressRules.can_open(progress, gate, area):
				continue
			var is_open := gate == &"" or progress.gates_open.has(gate)
			var step := 1.0 + (0.0 if is_open else GATE_COST)
			var total := float(cost[area]) + step
			if not cost.has(next) or total < float(cost[next]) - 0.0001:
				cost[next] = total
				back[next] = {"area": next, "gate": gate, "from": area, "open": is_open, "junction": edge[2]}
				if not open_set.has(next):
					open_set.append(next)
	if not back.has(to):
		return route
	var at := to
	while at != from:
		var hop: Dictionary = back[at]
		route.push_front(hop)
		at = hop["from"]
	return route


## The gates of [param route] that still need opening, in order.
static func gates_to_open(route: Array[Dictionary]) -> Array[StringName]:
	var found: Array[StringName] = []
	for hop in route:
		if hop["gate"] != &"" and not hop["open"]:
			found.append(hop["gate"])
	return found


## Area -> [[other area, gate id, junction id]...] (both ways), as
## ProgressRules walks them.
static func _edges() -> Dictionary:
	var edges := {}
	for j in Floor1Plan.junctions():
		_link(edges, j.area_a, j.area_b, j.gate, j.id)
	for gate in Floor1Plan.gates():
		if gate.junction == &"" and gate.area_a != gate.area_b:
			_link(edges, gate.area_a, gate.area_b, gate.id, &"")
	return edges


static func _link(edges: Dictionary, a: StringName, b: StringName, gate: StringName, junction: StringName) -> void:
	if not edges.has(a):
		edges[a] = []
	if not edges.has(b):
		edges[b] = []
	(edges[a] as Array).append([b, gate, junction])
	(edges[b] as Array).append([a, gate, junction])


# --- the tool for a lock ----------------------------------------------------------------------

## Stand-off for a punch (the fist reaches 1.7 m) and a shotgun's blast on
## a chain or boards (all ten pellets on the lock), a flare's point-blank
## shot at a cracked wall, a pistol at a rope, the other shots (m).
const PUNCH_RANGE := 1.3
const SHOTGUN_LOCK_RANGE := 2.5
const FLARE_LOCK_RANGE := 4.0
const PISTOL_ROPE_RANGE := 12.0
const RIFLE_RANGE := 30.0
const HWACHA_LOCK_RANGE := 12.0
const HARPOON_RANGE := 40.0

## How the guard opens a lock of [param kind] (requirement
## [param requirement]) with [param rounds] (weapon id -> rounds he can fire:
## magazine + reserve): {how (&"use" E on it, &"punch", &"shoot", &"none"
## nothing he has / the game opens it), weapon, range (m to stand within),
## shots (blows or shots it takes)}.
static func gate_tool(kind: GateSpec.Kind, requirement: StringName, rounds: Dictionary) -> Dictionary:
	match kind:
		GateSpec.Kind.BOLT, GateSpec.Kind.SEAL:
			return _tool(&"use", &"", Interactor.REACH - 0.4, 1)
		GateSpec.Kind.CHAIN, GateSpec.Kind.BOARDS:
			if _has(rounds, &"shotgun", 1):
				return _tool(&"shoot", &"shotgun", SHOTGUN_LOCK_RANGE, 1)
			var blows := LockRules.CHAIN_PUNCHES if kind == GateSpec.Kind.CHAIN else LockRules.BOARDS_PUNCHES
			return _tool(&"punch", &"fists", PUNCH_RANGE, blows)
		GateSpec.Kind.CRACKED:
			if _has(rounds, &"hwacha", 1):
				return _tool(&"shoot", &"hwacha", HWACHA_LOCK_RANGE, 1)
			if _has(rounds, &"flare", LockRules.CRACKED_FLARES):
				return _tool(&"shoot", &"flare", FLARE_LOCK_RANGE, LockRules.CRACKED_FLARES)
		GateSpec.Kind.ROPE:
			if _has(rounds, &"rifle_hunt", 1):
				return _tool(&"shoot", &"rifle_hunt", RIFLE_RANGE, 1)
			if requirement != &"rifle_hunt" and _has(rounds, &"pistol", 1):
				return _tool(&"shoot", &"pistol", PISTOL_ROPE_RANGE, 1)
		GateSpec.Kind.HOOK:
			if _has(rounds, &"harpoon", 1):
				return _tool(&"shoot", &"harpoon", HARPOON_RANGE, 1)
	return _tool(&"none", &"", 0.0, 0)


static func _tool(how: StringName, weapon: StringName, reach: float, shots: int) -> Dictionary:
	return {"how": how, "weapon": weapon, "range": reach, "shots": shots}


static func _has(rounds: Dictionary, id: StringName, count: int) -> bool:
	return int(rounds.get(id, 0)) >= count


# --- the weapon for a fight -----------------------------------------------------------------

## Up close (m): the shotgun's spread (all ten pellets on a body), the
## taser's arc.
const CLOSE := 5.0
const TASER_RANGE := 6.0
## The shotgun still worth firing at a guardian from this close.
const GUARDIAN_SHOTGUN := 9.0

## The weapon for a fight at [param distance] m with [param rounds] (weapon
## id -> rounds he can fire; the taser counts its charge), against a
## guardian (or the T-Rex: its weak points want the rifle and the pistol)
## when [param guardian], a tough exhibit (100 health and more: a mummy, a
## hoplite, a knight - the rifle's round through its weak point) when
## [param tough]. Rounds in [param keep] stay for the locks ahead.
## &"fists" when nothing else will do.
static func combat_weapon(rounds: Dictionary, distance: float, guardian: bool, keep: Dictionary = {}, tough: bool = false) -> StringName:
	var order: Array[StringName] = []
	if guardian:
		order = [&"rifle_hunt", &"pistol", &"gatling"]
		if distance <= GUARDIAN_SHOTGUN:
			order.append(&"shotgun")
		order.append_array([&"hwacha", &"harpoon", &"flare", &"shotgun"])
	elif distance <= CLOSE:
		order = [&"shotgun", &"gatling", &"pistol", &"rifle_hunt", &"harpoon", &"flare", &"hwacha"]
	elif tough:
		order = [&"rifle_hunt", &"gatling", &"pistol", &"harpoon", &"shotgun", &"flare", &"hwacha"]
	else:
		order = [&"pistol", &"gatling", &"rifle_hunt", &"harpoon", &"shotgun", &"flare", &"hwacha"]
	for id in order:
		if int(rounds.get(id, 0)) - int(keep.get(id, 0)) > 0:
			return id
	if int(rounds.get(&"taser", 0)) > 0 and (distance <= TASER_RANGE or guardian):
		return &"taser"
	return &"fists"


## Rounds to keep back for the locks still shut on the floor's way (the
## garden's cracked wall, the Planetarium's rope, the canoe's hook).
static func ammo_to_keep(progress: FloorProgress) -> Dictionary:
	var keep := {}
	if not progress.gates_open.has(&"cracked_garden"):
		if progress.weapons.has(&"hwacha"):
			keep[&"hwacha"] = 1
		elif progress.weapons.has(&"flare"):
			keep[&"flare"] = LockRules.CRACKED_FLARES
	if not progress.gates_open.has(&"rope_planetarium") and progress.weapons.has(&"rifle_hunt"):
		keep[&"rifle_hunt"] = 1
	if not progress.gates_open.has(&"hook_canoe") and progress.weapons.has(&"harpoon"):
		keep[&"harpoon"] = 1
	return keep


# --- breaking off -------------------------------------------------------------------------------

## Below this share of his health he goes to rest (when nothing is on him).
const REST_BELOW := 0.4
## A haven farther than this (m of walking) is no help.
const REST_REACH := 160.0
## Seconds of margin before dawn; the walk to a haven counts DETOUR times.
const DAWN_SLACK := 45.0
const DETOUR := 1.5

## Below this share he runs for a haven even with exhibits on him (they
## cannot follow him in), when one is within FLEE_REACH m.
const FLEE_BELOW := 0.25
const FLEE_REACH := 90.0

## True when the guard at [param health_share] of his health, with
## [param threats_close] exhibits on him, should walk (or run) to a haven
## [param haven_metres] away.
static func wants_rest(health_share: float, threats_close: int, haven_metres: float) -> bool:
	if health_share < FLEE_BELOW and haven_metres <= FLEE_REACH:
		return true
	return health_share < REST_BELOW and threats_close == 0 and haven_metres <= REST_REACH


## True when, [param seconds_left] before dawn, it is time to walk to the
## haven [param haven_metres] away (to start the next night there, to rest
## and shop before the night ends).
static func dawn_retreat(seconds_left: float, haven_metres: float) -> bool:
	if haven_metres == INF:
		return false
	return seconds_left <= haven_metres / WALK_SPEED * DETOUR + DAWN_SLACK


# --- the terminal ----------------------------------------------------------------------------------

## What a shooter's player buys first: [upgrade id, level], in order.
const WISH_LIST := [
	[&"health", 1], [&"pockets", 1], [&"pistol_damage", 1], [&"shotgun_spread", 1], [&"dust_magnet", 1],
	[&"stamina", 1], [&"health", 2], [&"rifle_bolt", 1], [&"pistol_mag", 1], [&"gatling_spin", 1],
	[&"pockets", 2], [&"second_wind", 1], [&"health", 3], [&"shotgun_slug", 1], [&"fists", 1],
	[&"rifle_expand", 1], [&"gatling_belt", 1], [&"harpoon_reel", 1], [&"hwacha_fuse", 1], [&"stamina", 2],
	[&"flare_burn", 1], [&"dust_magnet", 2], [&"taser_charge", 1], [&"harpoon_barbs", 1], [&"hwacha_volley", 1],
	[&"flare_twin", 1], [&"fists", 2], [&"stamina", 3], [&"taser_chain", 1],
]

## The upgrades to buy now, in order, with [param dust] (current
## [param levels]: id -> level; [param weapons]: the guns he has): the wish
## list's next levels he can pay for (one he cannot is skipped for a
## cheaper one after it; a gun's upgrade only for a gun he has).
static func shopping(levels: Dictionary, weapons: Array[StringName], dust: int) -> Array[StringName]:
	var bought: Array[StringName] = []
	var now := levels.duplicate()
	var left := dust
	for wish: Array in WISH_LIST:
		var id: StringName = wish[0]
		var level: int = wish[1]
		var entry := UpgradeCatalog.find(id)
		if entry == null or int(now.get(id, 0)) != level - 1:
			continue
		if entry.weapon() != &"" and entry.weapon() != &"taser" and not weapons.has(entry.weapon()):
			continue
		var price := UpgradeCatalog.price(id, level - 1)
		if price < 0 or price > left:
			continue
		left -= price
		now[id] = level
		bought.append(id)
	return bought


# --- choosing a target --------------------------------------------------------------------------------

## An exhibit hunting him is fought within this range (m) when he has a
## gun with rounds, MELEE_ENGAGE when he has only his fists and the taser
## (let it come); one awake but not after him (on patrol, looking round)
## only within WANDERER_RANGE; a sleeping one only when he is about to walk
## into it.
const ENGAGE_RANGE := 30.0
const MELEE_ENGAGE := 8.0
const WANDERER_RANGE := 14.0
const SLEEPER_RANGE := 6.0

## The candidate to fight first among [param candidates] ([{distance,
## awake, hunting, in_sight}]; hunting defaults to awake): the nearest one
## hunting him within [param reach], else an awake one within
## WANDERER_RANGE (and reach), else the nearest sleeper within
## SLEEPER_RANGE - all in sight; -1 for none.
static func pick_target(candidates: Array, reach: float = ENGAGE_RANGE) -> int:
	var best := -1
	var best_score := INF
	for i in candidates.size():
		var c: Dictionary = candidates[i]
		if not bool(c.get("in_sight", false)):
			continue
		var distance := float(c.get("distance", INF))
		var awake := bool(c.get("awake", false))
		var hunting := bool(c.get("hunting", awake))
		var limit := SLEEPER_RANGE
		if hunting:
			limit = reach
		elif awake:
			limit = minf(WANDERER_RANGE, reach)
		if distance > limit:
			continue
		var score := distance + (0.0 if hunting else (50.0 if awake else 100.0))
		if score < best_score:
			best_score = score
			best = i
	return best
