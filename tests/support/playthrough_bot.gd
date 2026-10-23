class_name PlaythroughBot
extends Node
## The playthrough bot (plan docs/superpowers/plans/2026-10-21-przejscie-bota.md,
## owner's #60): plays one night of the real game in the Museum scene the
## way a player does - only through PlaythroughPilot (the input actions,
## the weapon keys, the mouse) and PlaythroughNav (the game's navmesh) -
## and reports what happens to a PlaythroughLog.
##
## Each physics step, before the guard's own (process_physics_priority):
## a terminal's menu open -> buy from the wish list and close it with E;
## a fight on (an awake exhibit in sight and range, a guardian or the
## T-Rex fighting him) -> fight: the weapon for the range and the rounds
## (PlaythroughBrain), the view on the target's weak point or body, the
## trigger only while the ray from his eye meets the target first, a
## stand-off kept by strafing and backing off over the navmesh; else the
## task of the moment, chosen by priority: rest in a haven when hurt or
## when dawn is near (and buy there), his lantern, a guardian's seal and
## shard lying, ammo and medkits when short, else the goal the HUD shows
## (ProgressRules, as FloorGoal works it out) - the way to its area through
## the gates (PlaythroughBrain.area_route), each shut gate opened with its
## tool (E, fists, the right gun), the step itself (a thing to take or use,
## a guardian to wake, the crystal, the way down).
## The bot never moves the guard, heals him, fills his pockets or opens a
## lock by code; it reads the world like a player with the map and the HUD
## (and an aimbot's eye for where the targets are).

signal event(kind: StringName, data: Dictionary)

enum { RUNNING, DONE, FAILED }

## Seconds between task re-checks and target re-checks; the nearest
## haven's walk is measured again after HAVEN_CHECK s.
const HAVEN_CHECK := 5.0
## A terminal is visited again (more Dust since) after this long (s).
const SHOP_AGAIN := 120.0
## An undiscovered haven this close (m) is looked into on the way.
const DISCOVER_REACH := 35.0
const RETHINK := 1.0
const RETARGET := 0.25
## A thing is used from this far (m on the floor plan) round its aim point.
const USE_NEAR := 0.5
const USE_FAR := 1.7
## Tries before a task gives up; seconds a blocked step is left alone.
const TASK_TRIES := 3
const BLOCKED_FOR := 45.0
## With nothing else to do, a step given up on at least this long ago is
## tried again (one every this many seconds).
const UNBLOCK_EVERY := 15.0
## Loot is fetched within this walk (m) when needed; Dust lying within
## DUST_REACH (it fades in half a minute).
const LOOT_REACH := 30.0
const DUST_REACH := 22.0
## A walk's length is measured again after this long (s).
const WAY_CACHE := 4.0
## A medkit is wanted below this share of health, ammo below this share of
## a gun's starting load.
const MEDKIT_BELOW := 0.7
const AMMO_BELOW := 0.5
## The fight's stand-off (m) by weapon; a guardian's is never closer than
## GUARDIAN_STANDOFF.
const STANDOFF := {&"fists": 1.1, &"taser": 4.0, &"shotgun": 5.0, &"pistol": 11.0, &"gatling": 9.0,
		&"rifle_hunt": 16.0, &"flare": 10.0, &"harpoon": 12.0, &"hwacha": 14.0}
const GUARDIAN_STANDOFF := 9.0
## A gun swapped in while the other reloads stays in hand this long (s):
## swapping back cancels the reload.
const SWAP_HOLD := 3.0
## An exhibit with this much health is tough (the rifle for it).
const TOUGH_HEALTH := 100.0
## Exhibits this close are on him (no resting, back off).
const ON_HIM := 3.0
## He keeps at least this far from any awake exhibit (a mummy's lash
## reaches 4.6 m, a claw 2 m): closer, he backs off whatever he fights.
const KEEP_CLEAR := 5.0
## A foe that moved this far (m) from the way's goal gets a new way in.
const FIGHT_GOAL_MOVE := 1.5
## The bot that plays like a person (human = true, scenario --human): the
## view turns at most HUMAN_TURN_RATE degrees a second, the aim strays off
## the point by about HUMAN_SCATTER degrees (drawn again every 0.35-0.7 s),
## a new target is fired at after HUMAN_REACTION s, and the trigger is
## pulled whenever the aimed-at point is within HUMAN_TRIGGER degrees of
## the view (not only when the ray meets the target first: shots miss and
## land on shields). A rough stand-in for a player, not a model of one.
const HUMAN_TURN_RATE := 300.0
const HUMAN_SCATTER := 1.6
const HUMAN_REACTION := Vector2(0.25, 0.45)
const HUMAN_TRIGGER := 3.0

var museum: Museum
var game: PersistentState
var guard: Player
var level: MuseumFloorLevel
var floor_game: FloorGame
var pilot: PlaythroughPilot
var nav: PlaythroughNav
var rng := RandomNumberGenerator.new()
## Plays like a person (see HUMAN_TURN_RATE): set before setup().
var human: bool = false

## The task of the moment: {kind, key, priority, phase, ...}.
var task: Dictionary = {}
## The exhibit, guardian or boss he fights now (null: none).
var foe: Node3D = null
## Seconds of this night the bot has played (game time).
var clock: float = 0.0
## The progress area he was last seen in.
var area: StringName = ProgressRules.START_AREA
## Steps given up on for a while: step key -> clock when it may be tried again.
var blocked: Dictionary = {}
## Haven id -> clock of the last shopping at its terminal tonight.
var shopped_at: Dictionary = {}
## Counters for the night's report.
var stats := {"shots": 0, "punches": 0, "uses": 0, "kills": 0, "damage_taken": 0.0, "hits_taken": 0, "rests": 0,
		"stuck": 0, "nav_failures": 0, "task_failures": 0, "fights": 0, "bought": []}

var _rethink: float = 0.0
var _retarget: float = 0.0
var _foe_part: Hurtbox = null
var _foe_seen: bool = false
var _strafe: float = 1.0
var _strafe_left: float = 0.0
var _fight_goal := Vector3.INF
var _fight_goal_left: float = 0.0
var _shot_wait: float = 0.0
var _interactor := Interactor.new()
var _loot_scan: float = 0.0
var _loot: Array = []
var _menu_steps: int = 0
var _menu_close: bool = false
var _last_damage := {}
var _stuck_seen: int = 0
var _fought: bool = false
## Awake exhibits within KEEP_CLEAR + 2 m (their positions, this check).
var _near: Array[Vector3] = []
var _foe_unseen: float = 0.0
## Instance ids of the foes already announced in the log.
var _foes_met: Dictionary = {}
var _haven_checked: float = -INF
var _discover_checked: float = -INF
var _unblocked_at: float = -INF
var _failures: Array[float] = []
## Instance id -> [metres of walking, clock, where he stood] (_way_to()).
var _ways: Dictionary = {}
var _breather_until: float = -INF
var _discover_cache: Dictionary = {}
## The fight now: since when, the shots and damage counted when it began,
## what it is (kept for after it falls).
var _fight_since: float = -1.0
var _fight_shots: int = 0
var _fight_damage: float = 0.0
var _fight_kind: String = ""
var _swap_to: StringName = &""
var _swap_until: float = -INF
## Rounds in the current gun's magazine at the last step (shots counted
## by what left it).
var _mag_seen: Dictionary = {}
var _haven_cache: Dictionary = {}
## Exhibit instance id -> [its hit zones, clock when listed].
var _zone_cache: Dictionary = {}
## Microseconds the bot spent thinking, and its steps (for the report).
var think_usec: int = 0
var think_steps: int = 0
var _started: bool = false
## The aim's stray (degrees, right and up) and when it is drawn again; no
## shot at a new target before _react_until.
var _scatter := Vector2.ZERO
var _scatter_left: float = 0.0
var _react_until: float = -INF


func setup(for_museum: Museum, rng_seed: int) -> void:
	museum = for_museum
	game = museum.game
	guard = museum.player
	level = museum.floor_level
	floor_game = museum.floor_game
	rng.seed = rng_seed
	pilot = PlaythroughPilot.new(guard)
	if human:
		pilot.turn_rate = HUMAN_TURN_RATE
	nav = PlaythroughNav.new(guard, pilot, level, rng_seed)
	name = "PlaythroughBot"
	process_physics_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_damaged.connect(_on_damaged)
	Events.enemy_destroyed.connect(_on_enemy_destroyed)


func _exit_tree() -> void:
	if pilot != null:
		pilot.release_all()
	if Events.player_damaged.is_connected(_on_damaged):
		Events.player_damaged.disconnect(_on_damaged)
	if Events.enemy_destroyed.is_connected(_on_enemy_destroyed):
		Events.enemy_destroyed.disconnect(_on_enemy_destroyed)


func _note(kind: StringName, data: Dictionary = {}) -> void:
	event.emit(kind, data)


# --- the step -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	_step(delta)
	think_usec += Time.get_ticks_usec() - began
	think_steps += 1


func _step(delta: float) -> void:
	if museum == null or not is_instance_valid(guard):
		return
	if museum.upgrade_menu != null and museum.upgrade_menu.is_open:
		_shop()
		return
	if _menu_close:
		_menu_close = false
		_send_action(&"interact", false)
	if get_tree().paused:
		return
	if museum.night_over() or not guard.alive:
		pilot.release_all()
		return
	if not _started:
		# the night's navmesh reaches the map a step or two after the scene
		if not nav.ready():
			return
		_started = true
	clock += delta
	_track_area()
	_shot_wait = maxf(_shot_wait - delta, 0.0)
	_rethink -= delta
	if _rethink <= 0.0 or task.is_empty():
		_rethink = RETHINK
		var t_reconsider := Time.get_ticks_usec()
		_reconsider()
		_profile(&"reconsider", t_reconsider)
	_retarget -= delta
	if bool(task.get("flee", false)):
		foe = null   # running for the haven's door: no stopping to fight
	elif _retarget <= 0.0:
		_retarget = RETARGET
		var t_choose_foe := Time.get_ticks_usec()
		_choose_foe()
		_profile(&"choose_foe", t_choose_foe)
	pilot.firing = false
	if foe != null:
		var t_fight := Time.get_ticks_usec()
		_fight(delta)
		_profile(&"fight", t_fight)
		_fought = true
	else:
		if _fought:
			_fought = false
			nav.cancel()
			if not task.is_empty():
				task["phase"] = &"plan"   # the way is planned again from here
		if not task.is_empty():
			var t_task := Time.get_ticks_usec()
			var result := _run_task(delta)
			_profile(&"task", t_task)
			if result != RUNNING:
				_finish_task(result)
	_manage_reload()
	_count_shots()
	if nav.stuck_events.size() > _stuck_seen:
		for i in range(_stuck_seen, nav.stuck_events.size()):
			var stuck: Dictionary = nav.stuck_events[i]
			stats["stuck"] = int(stats["stuck"]) + 1
			_note(&"stuck", {"at": _v(stuck["at"]), "contacts": stuck["contacts"], "try": stuck["try"], "task": String(task.get("key", "")), "path": stuck.get("path", [])})
		_stuck_seen = nav.stuck_events.size()
	pilot.apply(delta)


func _track_area() -> void:
	var room := level.layout.room(level.layout.room_at(guard.global_position + Vector3.UP * 0.5))
	if room != null:
		area = room.progress_area()


## Seconds left of the night (to dawn).
func seconds_left() -> float:
	if museum.watch == null:
		return INF
	return NightClock.seconds_to_dawn() - museum.watch.clock.elapsed


# --- choosing what to do -----------------------------------------------------------------------

func _reconsider() -> void:
	if clock < _breather_until:
		if task.is_empty():
			task = {"kind": &"idle", "key": "idle", "priority": 0}
		return
	var wanted := _wanted_task()
	if wanted.is_empty() and not blocked.is_empty() and (task.is_empty() or task["kind"] == &"idle") and clock - _unblocked_at > UNBLOCK_EVERY:
		# nothing else to do: the step given up on longest ago (and not just
		# now) is tried again
		var first := ""
		for key: String in blocked:
			if (key.begins_with("step:") or key.begins_with("gate:")) and float(blocked[key]) - BLOCKED_FOR + UNBLOCK_EVERY <= clock:
				if first == "" or float(blocked[key]) < float(blocked[first]):
					first = key
		if first != "":
			_unblocked_at = clock
			blocked.erase(first)
			wanted = _wanted_task()
	if wanted.is_empty():
		if not task.is_empty() and task["kind"] != &"idle":
			return
		if task.is_empty():
			task = {"kind": &"idle", "key": "idle", "priority": 0}
			_note(&"idle", {"area": String(area)})
		return
	if task.is_empty() or (wanted["key"] != task["key"] and int(wanted["priority"]) > int(task.get("priority", 0))):
		_start(wanted)
	elif task["kind"] == &"idle":
		_start(wanted)


func _start(next: Dictionary) -> void:
	if not task.is_empty() and task.get("kind") != &"idle":
		_note(&"task_dropped", {"task": String(task["key"]), "for": String(next["key"])})
	nav.cancel()
	task = next
	task["phase"] = &"plan"
	task["tries"] = 0
	task["since"] = clock
	_note(&"task", {"task": String(task["key"]), "area": String(area)})


func _finish_task(result: int) -> void:
	var key := String(task.get("key", ""))
	if result == FAILED:
		stats["task_failures"] = int(stats["task_failures"]) + 1
		blocked[key] = clock + BLOCKED_FOR
		_note(&"task_failed", {"task": key, "why": String(task.get("why", "")), "at": _v(guard.global_position), "area": String(area)})
		# a burst of failures (one plan after another failing at once): a
		# breather instead of a loop
		_failures.append(clock)
		while not _failures.is_empty() and _failures[0] < clock - 3.0:
			_failures.pop_front()
		if _failures.size() > 6:
			_failures.clear()
			_breather_until = clock + 5.0
			_note(&"thrash", {"area": String(area), "at": _v(guard.global_position)})
	else:
		_note(&"task_done", {"task": key, "seconds": snappedf(clock - float(task.get("since", clock)), 0.1)})
	task = {}
	nav.cancel()
	_rethink = 0.0


## The most pressing task now ({} for nothing to do).
func _wanted_task() -> Dictionary:
	var health_share := guard.health.current / maxf(guard.health.max_health, 1.0)
	var haven := _nearest_haven()
	var haven_way: float = haven.get("metres", INF)
	if not floor_game.blocks_rest():
		if seconds_left() < INF and PlaythroughBrain.dawn_retreat(seconds_left(), haven_way):
			return {"kind": &"rest", "key": "dawn:%s" % haven["id"], "priority": 95, "haven": haven["id"], "stay": true}
		var threats := _threats_on_him()
		if PlaythroughBrain.wants_rest(health_share, threats, haven_way) and _can_rest_in(haven.get("id", &"")):
			var flee := threats > 0
			return {"kind": &"rest", "key": "%s:%s" % ["flee" if flee else "rest", haven["id"]], "priority": 92 if flee else 90,
					"haven": haven["id"], "stay": false, "flee": flee}
	var here := Haven.at(guard.global_position)
	if here != null and not _shopped_recently(here.id) and _worth_shopping():
		return {"kind": &"shop", "key": "shop:%s" % here.id, "priority": 85, "haven": here.id}
	var unknown := _haven_to_discover()
	if not unknown.is_empty():
		return {"kind": &"rest", "key": "discover:%s" % unknown["id"], "priority": 30, "haven": unknown["id"], "stay": false}
	var reward := _reward_lying()
	if reward != null and not _is_blocked("reward:%s" % reward.pickup_id):
		var reward_id := reward.get_instance_id()
		return _use_task("reward:%s" % reward.pickup_id, reward, 70, func() -> bool: return not is_instance_id_valid(reward_id))
	if is_instance_valid(museum.lantern) and bool(game.lantern.get("active", false)) and not _is_blocked("lantern"):
		var lantern := museum.lantern as Node3D
		return {"kind": &"walk", "key": "lantern", "priority": 60, "to": lantern.global_position, "within": 0.6,
				"done": func() -> bool: return not bool(game.lantern.get("active", false))}
	var mote := _nearest_mote()
	if mote != null and not _is_blocked("dust"):
		var mote_id := mote.get_instance_id()
		return {"kind": &"walk", "key": "dust", "priority": 45, "to": mote.global_position, "within": 2.0,
				"done": func() -> bool: return _loot_gone(mote_id)}
	var loot := _wanted_loot()
	if loot != null:
		var loot_id := loot.get_instance_id()
		return {"kind": &"walk", "key": "loot:%d" % loot_id, "priority": 40, "to": loot.global_position, "within": 0.5,
				"done": func() -> bool: return _loot_gone(loot_id)}
	return _objective_task()


func _is_blocked(key: String) -> bool:
	return blocked.has(key) and clock < float(blocked[key])


func _threats_on_him() -> int:
	var count := 0
	for exhibit in museum.exhibits():
		if _awake(exhibit) and exhibit.global_position.distance_to(guard.global_position) < ON_HIM * 2.0:
			count += 1
	return count


## {id, metres} of the nearest haven he knows and may rest in ({} none);
## worked out again every HAVEN_CHECK s.
func _nearest_haven() -> Dictionary:
	if clock - _haven_checked < HAVEN_CHECK and not _haven_cache.is_empty():
		return _haven_cache
	_haven_checked = clock
	_haven_cache = _find_nearest_haven()
	return _haven_cache


func _find_nearest_haven() -> Dictionary:
	var best := {}
	for id: StringName in game.havens:
		if not level.haven_spots.has(id) or not _can_rest_in(id) or _is_blocked("rest:%s" % id) or _is_blocked("dawn:%s" % id):
			continue
		var spot := _haven_spot(id)
		var straight := spot.distance_to(guard.global_position)
		if not best.is_empty() and straight > float(best["metres"]):
			continue
		var metres := nav.distance_to(spot)
		if metres == INF:
			continue
		if best.is_empty() or metres < float(best["metres"]):
			best = {"id": id, "metres": metres}
	return best


## A haven he has not been in yet whose door is within DISCOVER_REACH m
## of walking ({id, metres}; {} none): a safe room seen on the way is
## worth the look (it saves, heals and starts the next night).
func _haven_to_discover() -> Dictionary:
	if not _discover_cache.is_empty() and game.havens.has(_discover_cache["id"]):
		_discover_cache = {}
	if clock - _discover_checked < HAVEN_CHECK:
		return _discover_cache
	_discover_checked = clock
	_discover_cache = {}
	for plan in Floor1Plan.havens():
		if game.havens.has(plan.id) or not level.haven_spots.has(plan.id) or not _can_rest_in(plan.id):
			continue
		if _is_blocked("discover:%s" % plan.id):
			continue
		var spot := _haven_spot(plan.id)
		if spot.distance_to(guard.global_position) > DISCOVER_REACH:
			continue
		var metres := nav.distance_to(spot)
		if metres <= DISCOVER_REACH * 1.4:
			_discover_cache = {"id": plan.id, "metres": metres}
			break
	return _discover_cache


func _can_rest_in(haven_id: StringName) -> bool:
	return haven_id != &"" and not floor_game.haven_guarded(haven_id)


## Where he stands in haven [param id]: in front of its terminal, in the room.
func _haven_spot(id: StringName) -> Vector3:
	var spot: Transform3D = level.haven_spots[id]
	var into_room := (-spot.basis.z).normalized()
	return spot.origin + into_room * 1.4


func _worth_shopping() -> bool:
	return not PlaythroughBrain.shopping(game.upgrades, game.weapons, museum.run.dust).is_empty()


## A guardian's seal or shard lying in an arena (ProgressPickup), or null.
func _reward_lying() -> ProgressPickup:
	if floor_game.guardians == null:
		return null
	var best: ProgressPickup = null
	for child in floor_game.guardians.get_children():
		var pickup := child as ProgressPickup
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		if best == null or pickup.global_position.distance_to(guard.global_position) < best.global_position.distance_to(guard.global_position):
			best = pickup
	return best


## A medkit or ammo box worth the walk, or null.
func _wanted_loot() -> Node3D:
	_loot_scan -= RETHINK
	if _loot_scan <= 0.0:
		_loot_scan = 3.0
		_loot.clear()
		_loot = museum.pickups_root.get_children()
		var supplies := floor_game.guardians.get_node_or_null(^"Supplies") if floor_game.guardians != null else null
		if supplies != null:
			_loot.append_array(supplies.get_children())
	var health_share := guard.health.current / maxf(guard.health.max_health, 1.0)
	var best: Node3D = null
	var best_way := LOOT_REACH
	for item: Variant in _loot:
		if not is_instance_valid(item):
			continue
		var node := item as Pickup
		if node == null or not node.is_inside_tree() or not node.active:
			continue
		if node.global_position.distance_to(guard.global_position) > LOOT_REACH:
			continue
		var kind: int = node.get(&"type")
		var wanted := false
		if kind == Pickup.Type.MEDKIT:
			wanted = health_share < MEDKIT_BELOW
		else:
			wanted = _short_of(Pickup.AMMO.get(kind, &""))
		if not wanted or _is_blocked("loot:%d" % node.get_instance_id()):
			continue
		var way := _way_to(node)
		if way < best_way:
			best_way = way
			best = node
	return best


## True when the loot or Dust [param id] (an instance id) was taken or is gone.
static func _loot_gone(id: int) -> bool:
	var node := instance_from_id(id) as Node
	if node == null or not node.is_inside_tree() or node.is_queued_for_deletion():
		return true
	return node is Pickup and not (node as Pickup).active


## The nearest Dust lying (not flying to him yet) within DUST_REACH m of
## walking, or null.
func _nearest_mote() -> DustMote:
	var best: DustMote = null
	var best_distance := DUST_REACH
	for child in museum.pickups_root.get_children():
		var mote := child as DustMote
		if mote == null or mote.is_queued_for_deletion():
			continue
		var distance := mote.global_position.distance_to(guard.global_position)
		if distance < guard.dust_magnet_radius or distance >= best_distance:
			continue
		best_distance = distance
		best = mote
	if best != null and _way_to(best) > DUST_REACH * 1.5:
		return null
	return best


## Metres of walking to [param thing] (INF: no way), asked again after
## WAY_CACHE s (or once he moved off) - path queries over the whole floor
## are not free.
func _way_to(thing: Node3D) -> float:
	var id := thing.get_instance_id()
	var entry: Array = _ways.get(id, [])
	if not entry.is_empty() and clock - float(entry[1]) < WAY_CACHE and (entry[2] as Vector3).distance_to(guard.global_position) < 3.0:
		return float(entry[0])
	var metres := nav.distance_to(thing.global_position)
	_ways[id] = [metres, clock, guard.global_position]
	if _ways.size() > 256:
		_ways.clear()
	return metres


## True when the gun firing [param ammo] is short of rounds.
func _short_of(ammo: StringName) -> bool:
	for state in guard.weapons.owned:
		if state.data.ammo_type == ammo and ammo != &"":
			var load := state.data.magazine_size + int(Loadout.START_RESERVE.get(state.data.id, state.data.start_reserve))
			return state.magazine + state.reserve < load * AMMO_BELOW
	return false


# --- the goal ----------------------------------------------------------------------------------

## The HUD's goal as a task: the next shut gate on the way to its area, or
## the step itself ({} when there is nothing to do).
func _objective_task() -> Dictionary:
	var progress := FloorProgress.from_game(game)
	var closed: Array[StringName] = []
	if museum.night != null and Floor1Plan.junction(museum.night.locked_door) != null:
		closed.append(museum.night.locked_door)
	var steps := ProgressRules.available_steps(progress, ProgressRules.start_area(game.start_haven), closed)
	for extra in ProgressRules.available_steps(progress, area, closed):
		if not steps.has(extra):
			steps.append(extra)
	for step in steps:
		if _is_blocked("step:%s" % step):
			continue
		var route := PlaythroughBrain.area_route(progress, area, ProgressRules.step_area(step), closed)
		if route.is_empty() and area != ProgressRules.step_area(step):
			continue
		for gate_id in PlaythroughBrain.gates_to_open(route):
			if _is_blocked("gate:%s" % gate_id):
				route = []
				break
			var hop := _hop_of(route, gate_id)
			return {"kind": &"gate", "key": "gate:%s" % gate_id, "priority": 20, "gate": gate_id, "from": hop.get("from", area), "step": step}
		if route.is_empty() and area != ProgressRules.step_area(step):
			continue
		var task_for := _step_task(step)
		if not task_for.is_empty() and not _is_blocked(String(task_for["key"])):
			return task_for
	return {}


static func _hop_of(route: Array[Dictionary], gate_id: StringName) -> Dictionary:
	for hop in route:
		if hop["gate"] == gate_id:
			return hop
	return {}


func _step_task(step: StringName) -> Dictionary:
	var key := "step:%s" % step
	var pickups := floor_game.pickups
	match step:
		&"pistol_key":
			if pickups.drawer != null:
				return _use_task(key, pickups.drawer, 20, func() -> bool: return game.pistol_key)
		&"pistol":
			if is_instance_valid(pickups.pistol):
				return _use_task(key, pickups.pistol, 20, func() -> bool: return game.has_weapon(&"pistol"))
			if pickups.locker != null:
				return _use_task(key, pickups.locker, 20, func() -> bool: return is_instance_valid(pickups.pistol) or game.has_weapon(&"pistol"))
		&"flare":
			if pickups.cabinet != null:
				return _use_task(key, pickups.cabinet, 20, func() -> bool: return game.has_weapon(&"flare"), 2)
		&"shotgun", &"rifle_hunt", &"hwacha", &"harpoon":
			var weapon := pickups.weapons.get(step) as Interactable
			if weapon != null:
				return _use_task(key, weapon, 20, func() -> bool: return game.has_weapon(step))
		&"gatling":
			if pickups.display != null:
				if not game.is_gate_open(&"chain_gatling"):
					# the chained case stands in the Reading Room: broken from in there
					return {"kind": &"gate", "key": "gate:chain_gatling", "priority": 20, "gate": &"chain_gatling", "from": &"reading_room", "step": step}
				return _use_task(key, pickups.display, 20, func() -> bool: return game.has_weapon(&"gatling"))
		&"fuse_basement", &"fuse_assyria":
			var fuse := pickups.items.get(step) as Interactable
			if fuse != null:
				return _use_task(key, fuse, 20, func() -> bool: return game.has_item(step))
		&"power_north":
			if floor_game.switchboard != null:
				return _use_task(key, floor_game.switchboard, 20, func() -> bool: return game.has_flag(Switchboard.POWER_FLAG))
		&"astrolabe":
			if floor_game.finale != null and floor_game.finale.astrolabe != null:
				return _use_task(key, floor_game.finale.astrolabe, 20, func() -> bool: return game.has_flag(FloorFinale.ASTROLABE_FLAG))
		&"trex":
			return {"kind": &"trex", "key": key, "priority": 20}
		&"descend":
			var exit := floor_game.finale.exit if floor_game.finale != null else null
			if exit != null:
				return {"kind": &"walk", "key": key, "priority": 20, "to": exit.global_position, "within": 0.5,
						"done": func() -> bool: return game.has_flag(ProgressRules.COMPLETE_FLAG)}
		_:
			if Floor1Plan.guardian(step) != null:
				return {"kind": &"guardian", "key": key, "priority": 20, "guardian": step}
	return {}


func _use_task(key: String, target: Interactable, priority: int, done: Callable, uses: int = 1) -> Dictionary:
	return {"kind": &"use", "key": key, "priority": priority, "target": target, "done": done, "uses": uses}


# --- running a task ----------------------------------------------------------------------------

func _run_task(delta: float) -> int:
	match task["kind"]:
		&"idle":
			pilot.stop()
			return RUNNING
		&"walk":
			return _walk_task(delta)
		&"use":
			return _use_run(delta)
		&"gate":
			return _gate_run(delta)
		&"rest":
			return _rest_run(delta)
		&"shop":
			return _shop_run(delta)
		&"guardian":
			return _guardian_run(delta)
		&"trex":
			return _trex_run(delta)
	return FAILED


## Walks to task.to (task.within); done when task.done says so or there.
func _walk_task(delta: float) -> int:
	var done: Callable = task.get("done", Callable())
	if done.is_valid() and done.call():
		return DONE
	return _walk_to(task["to"], float(task.get("within", 0.6)), delta, not done.is_valid())


## Walks the task to [param to]: DONE when there (when [param done_there]),
## FAILED after TASK_TRIES failed ways.
func _walk_to(to: Vector3, within: float, delta: float, done_there: bool = true) -> int:
	if task["phase"] == &"plan" or nav.status == PlaythroughNav.Status.IDLE:
		if not nav.go(to, within):
			return _retry("no path")
		task["phase"] = &"walk"
	var status := nav.update(delta)
	if status == PlaythroughNav.Status.ARRIVED:
		task["phase"] = &"there"
		return DONE if done_there else RUNNING
	if status == PlaythroughNav.Status.FAILED:
		stats["nav_failures"] = int(stats["nav_failures"]) + 1
		task["phase"] = &"plan"
		return _retry(nav.failure)
	return RUNNING


func _retry(why: String) -> int:
	if why.begins_with("no path") and level.navigation != null and level.navigation.is_baking():
		# a gate just opened: the navmesh round it is being baked again
		task["phase"] = &"plan"
		nav.cancel()
		return RUNNING
	task["tries"] = int(task["tries"]) + 1
	task["why"] = why
	task["phase"] = &"plan"
	nav.cancel()
	return FAILED if int(task["tries"]) >= TASK_TRIES else RUNNING


# --- using a thing ------------------------------------------------------------------------------

## The point to look at on [param thing] (its first collision shape).
static func aim_point(thing: Node3D) -> Vector3:
	for child in thing.get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			return shape.global_position
	return thing.global_position


## The point of [param thing]'s boxes nearest to [param eye] (a little in
## from their faces): where a player looks to use a big thing (a seal
## gate's whole height) from where he stands.
static func use_point(thing: Node3D, eye: Vector3) -> Vector3:
	var best := Vector3.INF
	for child in thing.get_children():
		var holder := child as CollisionShape3D
		if holder == null:
			continue
		var box := holder.shape as BoxShape3D
		var point := holder.global_position
		if box != null:
			var frame := holder.global_transform
			var local := frame.affine_inverse() * eye
			var half := box.size * 0.5 * 0.8
			point = frame * Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
		if best == Vector3.INF or point.distance_to(eye) < best.distance_to(eye):
			best = point
	return best if best != Vector3.INF else thing.global_position


func _use_run(delta: float) -> int:
	var done: Callable = task["done"]
	if done.call():
		return DONE
	var thing: Variant = task["target"]
	if not is_instance_valid(thing) or not (thing as Node).is_inside_tree():
		task["target"] = null
		return _retry("gone")
	var target := thing as Interactable
	var aim := use_point(target, pilot.eye())
	match task["phase"]:
		&"plan":
			var spot := _use_spot(target, aim, task.get("side", &""))
			task["spot"] = spot
			if not nav.go(spot, 0.35):
				return _retry("no path to %s" % target.name)
			task["phase"] = &"walk"
		&"walk":
			var status := nav.update(delta)
			if status == PlaythroughNav.Status.IDLE:
				task["phase"] = &"plan"
			if status == PlaythroughNav.Status.FAILED:
				stats["nav_failures"] = int(stats["nav_failures"]) + 1
				return _retry(nav.failure)
			if status == PlaythroughNav.Status.ARRIVED:
				task["phase"] = &"aim"
				task["aim_time"] = 0.0
		&"aim":
			pilot.stop()
			pilot.look_at_point(aim)
			task["aim_time"] = float(task["aim_time"]) + delta
			if guard.interactor.focus == target and not pilot.tapping(&"interact"):
				pilot.tap(&"interact")
				stats["uses"] = int(stats["uses"]) + 1
				task["phase"] = &"after"
				task["wait"] = 0.6
			elif float(task["aim_time"]) > 2.0:
				return _retry("no focus on %s" % target.name)
		&"after":
			task["wait"] = float(task["wait"]) - delta
			if float(task["wait"]) <= 0.0:
				if done.call():
					return DONE
				task["phase"] = &"aim"
				task["aim_time"] = 0.0
				task["uses"] = int(task["uses"]) - 1
				if int(task["uses"]) < -2:
					return _retry("used, nothing came of it")
	return RUNNING


## Where to stand to use [param target] (aim point [param aim]): a floor
## spot from whose eye the use probe meets it first ([param side]: only in
## that progress area), else the navmesh nearest to it.
func _use_spot(target: Interactable, aim: Vector3, side: StringName = &"") -> Vector3:
	var floor_y := _floor_y_at(Vector3(aim.x, minf(aim.y, _bottom_of(target) + 0.5), aim.z))
	var spots := nav.spots_round(aim, USE_NEAR, USE_FAR, floor_y)
	var space := guard.get_world_3d().direct_space_state
	var spot := nav.first_spot(spots, func(eye: Vector3) -> bool:
		if side != &"" and _area_at(eye - Vector3.UP * guard.eye_height) != side:
			return false
		var at := use_point(target, eye)
		return eye.distance_to(at) <= Interactor.REACH - 0.1 and _interactor.probe(space, eye, at - eye, guard) == target)
	if spot != Vector3.INF:
		return spot
	return nav.snap(Vector3(aim.x, floor_y, aim.z))


## The lowest point of [param thing]'s collision boxes (its own origin
## when it has none).
static func _bottom_of(thing: Node3D) -> float:
	var low := INF
	for child in thing.get_children():
		var holder := child as CollisionShape3D
		if holder == null:
			continue
		var box := holder.shape as BoxShape3D
		var half := box.size.y * 0.5 if box != null else 0.0
		low = minf(low, holder.global_position.y - half)
	return low if low != INF else thing.global_position.y


## The floor under [param point]: its room's floor when it is within a
## storey of it, else the first floor a ray down meets (a rope high in a
## rotunda), else 1 m under it.
func _floor_y_at(point: Vector3) -> float:
	var room := level.layout.room(level.layout.room_at(point))
	if room != null and point.y - room.floor_y < 3.0:
		return room.floor_y
	# the highest room floor under it (a rope high in a rotunda)
	var best := -INF
	for other in level.layout.rooms:
		if other.floor_y > point.y:
			continue
		for part in other.parts:
			if part.has_point(Vector2(point.x, point.z)):
				best = maxf(best, other.floor_y)
				break
	if best > -INF:
		return best
	return room.floor_y if room != null else point.y - 1.0


func _area_at(point: Vector3) -> StringName:
	var room := level.layout.room(level.layout.room_at(point + Vector3.UP * 0.5))
	return room.progress_area() if room != null else &""


# --- opening a gate ----------------------------------------------------------------------------

func _gate_lock(gate_id: StringName) -> Node3D:
	if gate_id == &"chain_gatling":
		return floor_game.pickups.display
	return floor_game.gates.lock_of(gate_id)


func _gate_run(delta: float) -> int:
	var gate_id: StringName = task["gate"]
	if game.is_gate_open(gate_id):
		return DONE
	var lock := _gate_lock(gate_id)
	var spec := level.layout.gate(gate_id)
	if lock == null or spec == null:
		task["why"] = "no lock"
		return FAILED
	if not task.has("floors"):
		var floors: Array[float] = []
		var passage := level.layout.opening(spec.opening) if spec.opening != &"" else null
		if passage != null:
			floors.append(passage.floor_y)
			for room_id: StringName in [passage.room_a, passage.room_b]:
				var room := level.layout.room(room_id)
				if room != null:
					floors.append(room.floor_y)
		if floors.is_empty():
			floors.append(_floor_y_at(lock.global_position + Vector3.UP))
		task["floors"] = floors
	if not task.has("tool"):
		var kind := spec.kind
		if gate_id == &"chain_gatling":
			kind = GateSpec.Kind.CHAIN
		task["tool"] = PlaythroughBrain.gate_tool(kind, spec.requirement, rounds())
		_note(&"gate_tool", {"gate": String(gate_id), "tool": String(task["tool"]["how"]), "weapon": String(task["tool"]["weapon"])})
	var tool: Dictionary = task["tool"]
	match tool["how"]:
		&"use":
			var prompt := lock.get(&"prompt_area") as Interactable
			if prompt == null:
				task["why"] = "no prompt"
				return FAILED
			if not task.has("target"):
				task["target"] = prompt
				task["done"] = func() -> bool: return game.is_gate_open(gate_id)
				task["uses"] = 1
				if spec.kind == GateSpec.Kind.BOLT:
					task["side"] = task["from"]
			return _use_run(delta)
		&"punch", &"shoot":
			return _hit_run(lock, tool, delta, func() -> bool: return game.is_gate_open(gate_id))
	task["why"] = "no tool for %s" % gate_id
	return FAILED


## The hit zones of [param thing] (its own Hurtboxes, on).
static func zones_of(thing: Node) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	for node in thing.find_children("*", "Hurtbox", true, false):
		var zone := node as Hurtbox
		if zone.collision_layer != 0 and zone.receiver == thing:
			found.append(zone)
	return found


## Breaks [param thing] with [param tool] ({how, weapon, range, shots}).
func _hit_run(thing: Node3D, tool: Dictionary, delta: float, done: Callable) -> int:
	if done.call():
		return DONE
	var zones := zones_of(thing)
	if zones.is_empty():
		return _retry("no zones")
	var aim := zones[0].global_position
	var reach := float(tool["range"])
	var weapon: StringName = tool["weapon"]
	match task["phase"]:
		&"plan":
			var floor_y := _floor_y_at(aim)
			var space := guard.get_world_3d().direct_space_state
			# the floors a gate is worked from (its passage's, its rooms'),
			# else the one under the thing
			var floors: Array[float] = []
			for height: float in task.get("floors", [floor_y]):
				if not floors.has(height):
					floors.append(height)
			var spots := PackedVector3Array()
			for height in floors:
				spots.append_array(nav.spots_round(aim, 0.6 if reach < 2.0 else 1.5, maxf(reach - 0.3, 0.9), height))
			var from := guard.global_position
			var sorted := Array(spots)
			sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(from) < b.distance_to(from))
			# a gate is worked from the area the way comes from (not from
			# behind it, where he cannot get yet)
			var side: StringName = task.get("from", &"") if task.get("kind") == &"gate" else &""
			var spot := nav.first_spot(PackedVector3Array(sorted), func(eye: Vector3) -> bool:
				if eye.distance_to(aim) > reach + 0.4:
					return false
				if side != &"" and _area_at(eye - Vector3.UP * guard.eye_height) != side:
					return false
				return _ray_meets(space, eye, aim, zones), 20)
			if spot == Vector3.INF:
				return _retry("no spot to strike the lock from")
			if not nav.go(spot, 0.4):
				return _retry("no path to the lock")
			task["phase"] = &"walk"
		&"walk":
			var status := nav.update(delta)
			if status == PlaythroughNav.Status.IDLE:
				task["phase"] = &"plan"
			if status == PlaythroughNav.Status.FAILED:
				stats["nav_failures"] = int(stats["nav_failures"]) + 1
				return _retry(nav.failure)
			if status == PlaythroughNav.Status.ARRIVED:
				task["phase"] = &"strike"
				task["aim_time"] = 0.0
				task["struck"] = 0
		&"strike":
			pilot.stop()
			pilot.look_at_point(aim)
			pilot.turn_now(delta)
			task["aim_time"] = float(task["aim_time"]) + delta
			if weapon != &"fists" and pilot.weapon() != weapon:
				pilot.select_weapon(weapon)
				return RUNNING
			var on := pilot.aim_error(aim) < 6.0
			var space := guard.get_world_3d().direct_space_state
			var meets := _ray_meets(space, pilot.eye(), pilot.eye() + pilot.forward() * (reach + 1.0), zones)
			if on and meets and _shot_wait <= 0.0:
				if weapon == &"fists":
					if pilot.tap(&"punch"):
						stats["punches"] = int(stats["punches"]) + 1
						task["struck"] = int(task["struck"]) + 1
						_shot_wait = guard.weapons.fists.data.cooldown + 0.05
				else:
					var state := guard.weapons.current_state()
					if state != null and state.can_fire():
						pilot.firing = true
						task["struck"] = int(task["struck"]) + 1
						_shot_wait = maxf(state.data.cooldown, 0.1) + 0.05
			if int(task["struck"]) > int(tool["shots"]) * 3 + 2 or float(task["aim_time"]) > 25.0:
				return _retry("the lock held")
			if float(task["aim_time"]) > 3.0 and int(task["struck"]) == 0:
				return _retry("no clear strike")
	return RUNNING


## True when a ray from [param eye] toward [param at] (a bit past it) meets
## one of [param zones] first.
func _ray_meets(space: PhysicsDirectSpaceState3D, eye: Vector3, at: Vector3, zones: Array) -> bool:
	var hit := Hitscan.ray(space, eye, at + (at - eye).normalized() * 0.5)
	return not hit.is_empty() and hit["hurtbox"] != null and zones.has(hit["hurtbox"])


# --- havens -------------------------------------------------------------------------------------

func _rest_run(delta: float) -> int:
	var id: StringName = task["haven"]
	if not level.haven_spots.has(id):
		return FAILED
	var spot := _haven_spot(id)
	if task["phase"] != &"in":
		var result := _walk_to(spot, 0.6, delta, false)
		if result == FAILED:
			return FAILED
		if task["phase"] == &"there":
			task["phase"] = &"in"
			stats["rests"] = int(stats["rests"]) + 1
			_note(&"rest", {"haven": String(id), "health": snappedf(guard.health.current, 1.0), "dust": museum.run.dust, "left": snappedf(seconds_left(), 1.0)})
		return RUNNING
	pilot.stop()
	if not _shopped_recently(id) and _worth_shopping():
		task = {"kind": &"shop", "key": "shop:%s" % id, "priority": 85, "haven": id, "phase": &"plan", "tries": 0, "since": clock, "stay": task.get("stay", false)}
		return RUNNING
	if bool(task.get("stay", false)):
		return RUNNING   # dawn finds him here
	return DONE


func _shop_run(delta: float) -> int:
	var id: StringName = task["haven"]
	var terminal := museum.get_node_or_null(NodePath("Terminal_" + String(id))) as Interactable
	if terminal == null or _shopped_recently(id):
		shopped_at[id] = clock
		return DONE if not bool(task.get("stay", false)) else RUNNING
	if not task.has("target"):
		task["target"] = terminal
		task["done"] = func() -> bool: return _shopped_recently(id)
		task["uses"] = 1
	var result := _use_run(delta)
	if result == FAILED:
		shopped_at[id] = clock
		return FAILED
	return result


## True when he shopped at haven [param id]'s terminal less than
## SHOP_AGAIN s ago.
func _shopped_recently(id: StringName) -> bool:
	return shopped_at.has(id) and clock - float(shopped_at[id]) < SHOP_AGAIN


## The terminal's menu is open: buy what the wish list says and close it.
func _shop() -> void:
	pilot.release_all()
	var menu := museum.upgrade_menu
	_menu_steps += 1
	if _menu_steps < 3:
		return
	var here := Haven.at(guard.global_position)
	var id: StringName = here.id if here != null else &"?"
	var wishes := PlaythroughBrain.shopping(game.upgrades, game.weapons, museum.run.dust)
	var bought: Array = []
	for wish in wishes:
		var row: int = (menu.get(&"_row_ids") as Array).find(wish)
		if row < 0:
			continue
		var before := museum.run.dust
		menu.call(&"_on_row_pressed", row)
		if game.upgrade_level(wish) > 0 and museum.run.dust < before:
			bought.append(String(wish))
	(stats["bought"] as Array).append_array(bought)
	_note(&"shop", {"haven": String(id), "bought": bought, "dust_left": museum.run.dust, "levels": game.upgrades.duplicate()})
	shopped_at[id] = clock
	_menu_steps = 0
	_send_action(&"interact", true)
	_menu_close = true


func _send_action(action: StringName, pressed: bool) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = pressed
	Input.parse_input_event(press)


# --- guardians and the T-Rex ----------------------------------------------------------------

func _guardian_run(delta: float) -> int:
	var id: StringName = task["guardian"]
	if game.is_guardian_defeated(id):
		return DONE
	var keeper := floor_game.guardians
	var guardian := keeper.guardians.get(id) as Guardian if keeper != null else null
	if guardian == null:
		task["why"] = "no guardian"
		return FAILED
	if guardian.state == Guardian.State.FIGHT:
		return RUNNING   # the fight is _fight()'s
	var start_marker := StringName("arena_%s_start" % id)
	if not task.has("to"):
		var to := guardian.global_position
		if level.markers.has(start_marker):
			to = (level.markers[start_marker] as Transform3D).origin
		task["to"] = to
		_note(&"guardian_approach", {"guardian": String(id)})
	if task["phase"] == &"there":
		# over the start line and on toward it: it wakes
		var close := nav.snap(guardian.global_position)
		task["to"] = close
		task["phase"] = &"plan"
		task["closer"] = int(task.get("closer", 0)) + 1
		if int(task["closer"]) > 3:
			return _retry("it does not wake")
	var result := _walk_to(task["to"], 1.0, delta, false)
	return result


func _trex_run(delta: float) -> int:
	var finale := floor_game.finale
	if finale == null:
		return FAILED
	if game.is_guardian_defeated(FloorFinale.TREX):
		return DONE
	match finale.stage:
		FloorFinale.Stage.PULSING, FloorFinale.Stage.FLIGHT:
			# up to the beating crystal (it bursts out within CrystalRelic.REACH
			# of his chest), then after it in its flight (it waits for him
			# farther off than WAIT_BEYOND)
			if not is_instance_valid(finale.crystal):
				return RUNNING
			var at := finale.crystal.global_position
			var near := 1.2 if finale.stage == FloorFinale.Stage.PULSING else 7.0
			task["follow_left"] = float(task.get("follow_left", 0.0)) - delta
			# planned again every second (a way that failed too: not every
			# step - a failed plan tries the gaps of the mesh, which is dear)
			if float(task["follow_left"]) <= 0.0 or nav.status == PlaythroughNav.Status.IDLE:
				task["follow_left"] = 1.0
				var goal := nav.snap(Vector3(at.x, _floor_y_at(at), at.z))
				if not nav.go(goal, near):
					nav.go(nav.snap(at), near + 1.0)
			if nav.update(delta) == PlaythroughNav.Status.ARRIVED:
				pilot.stop()
			pilot.look_at_point(at)
			return RUNNING
		FloorFinale.Stage.BOSS:
			pilot.stop()
			if is_instance_valid(finale.boss):
				pilot.look_at_point(finale.boss.global_position + Vector3.UP * 3.0)
			return RUNNING
	return RUNNING


# --- fighting -------------------------------------------------------------------------------------

func _awake(exhibit: Enemy) -> bool:
	var state := exhibit.brain.state
	return state != EnemyBrain.State.DORMANT and state != EnemyBrain.State.DESTROYED


## True while [param exhibit] is after him (hunting, striking, searching
## for him, coming to look, stunned mid-fight).
static func _hunting(exhibit: Enemy) -> bool:
	match exhibit.brain.state:
		EnemyBrain.State.HUNT, EnemyBrain.State.ATTACK, EnemyBrain.State.SEARCH, EnemyBrain.State.INVESTIGATE, EnemyBrain.State.STUNNED:
			return true
	return false


## True when he has a gun with rounds (not just his fists and the taser).
func _armed() -> bool:
	for state in guard.weapons.owned:
		if state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE and state.magazine + state.reserve > 0:
			return true
	return false


## The weapon id -> rounds he can fire (the taser: 1 with a charge).
func rounds() -> Dictionary:
	var found := {}
	for state in guard.weapons.owned:
		if state.data.ammo_mode == WeaponData.AmmoMode.BATTERY:
			found[state.data.id] = 1 if state.battery >= state.data.battery_cost else 0
		else:
			found[state.data.id] = state.magazine + state.reserve
	return found


## The guardian fighting him now, the T-Rex awake, or the nearest
## exhibit worth fighting (PlaythroughBrain.pick_target).
func _choose_foe() -> void:
	var previous := foe if is_instance_valid(foe) else null
	foe = null
	_foe_part = null
	_near.clear()
	var eye := pilot.eye()
	var space := guard.get_world_3d().direct_space_state
	var big: Node3D = null
	if floor_game.guardians != null:
		for node: Guardian in floor_game.guardians.guardians.values():
			if is_instance_valid(node) and node.state == Guardian.State.FIGHT and node.guard_in_arena():
				big = node
	var finale := floor_game.finale
	if finale != null and finale.stage == FloorFinale.Stage.BOSS and is_instance_valid(finale.boss) and not finale.boss.is_dead():
		big = finale.boss
	var candidates: Array = []
	var nodes: Array[Enemy] = []
	var kept := -1
	for exhibit in museum.exhibits():
		var distance := exhibit.global_position.distance_to(guard.global_position)
		if distance > PlaythroughBrain.ENGAGE_RANGE + 2.0:
			continue
		if exhibit.health != null and exhibit.health.is_dead():
			continue
		var awake := _awake(exhibit)
		if awake and distance < KEEP_CLEAR + 2.0:
			_near.append(exhibit.global_position)
		if not awake and distance > PlaythroughBrain.SLEEPER_RANGE + 1.0:
			continue
		var part := _visible_part(exhibit, eye, space)
		if exhibit == previous:
			kept = candidates.size()
			if part == null:
				_foe_unseen += RETARGET
			else:
				_foe_unseen = 0.0
		candidates.append({"distance": distance, "awake": awake, "hunting": _hunting(exhibit), "in_sight": part != null})
		nodes.append(exhibit)
	var picked := PlaythroughBrain.pick_target(candidates, PlaythroughBrain.ENGAGE_RANGE if _armed() else PlaythroughBrain.MELEE_ENGAGE)
	# the one he fights stays his target while he still sees it (or lost it
	# only a moment ago), unless another comes much closer
	if kept >= 0 and _foe_unseen < 1.0 and float(candidates[kept]["distance"]) < PlaythroughBrain.ENGAGE_RANGE + 2.0:
		if picked < 0 or picked == kept or float(candidates[picked]["distance"]) > float(candidates[kept]["distance"]) * 0.6:
			picked = kept
	if big != null:
		# a summoned or called exhibit right on him first, else the big one
		if picked >= 0 and float(candidates[picked]["distance"]) < ON_HIM * 2.0 and bool(candidates[picked]["awake"]):
			foe = nodes[picked]
		else:
			foe = big
	elif picked >= 0:
		foe = nodes[picked]
	if foe == null and previous != null:
		_end_fight(previous)
	if foe != null:
		_fight_kind = _describe(foe)
		_foe_part = _visible_part(foe, eye, space)
		_foe_seen = _foe_part != null
		if foe != previous:
			_end_fight(previous)
			_react_until = clock + (rng.randf_range(HUMAN_REACTION.x, HUMAN_REACTION.y) if human else 0.0)
			_fight_since = clock
			_fight_shots = int(stats["shots"])
			_fight_damage = float(stats["damage_taken"])
			_foe_unseen = 0.0
			stats["fights"] = int(stats["fights"]) + 1
			nav.cancel()
			_fight_goal = Vector3.INF
			if not _foes_met.has(foe.get_instance_id()):
				_foes_met[foe.get_instance_id()] = true
				_note(&"fight", {"foe": _describe(foe), "distance": snappedf(foe.global_position.distance_to(guard.global_position), 0.1), "task": String(task.get("key", ""))})


## The part of [param thing] to shoot at seen from [param eye]: a weak
## point the ray meets first, else any of its zones it meets; null when
## none is in sight.
func _visible_part(thing: Node3D, eye: Vector3, space: PhysicsDirectSpaceState3D) -> Hurtbox:
	var zones := _zones_cached(thing)
	var seen: Hurtbox = null
	for zone in zones:
		var at := zone.global_position
		if at.distance_to(eye) > 60.0:
			continue
		var hit := Hitscan.ray(space, eye, at + (at - eye).normalized() * 0.3)
		if hit.is_empty() or hit["hurtbox"] == null or not zones.has(hit["hurtbox"]):
			continue
		if _weak(hit["hurtbox"]):
			return hit["hurtbox"]
		if seen == null:
			seen = hit["hurtbox"]
	return seen


## The hit zones of [param thing], listed again every 2 s (a summoned
## part, a plate knocked off).
func _zones_cached(thing: Node) -> Array[Hurtbox]:
	var id := thing.get_instance_id()
	var entry: Array = _zone_cache.get(id, [])
	if entry.is_empty() or clock - float(entry[1]) > 2.0:
		entry = [_all_zones(thing), clock]
		_zone_cache[id] = entry
	var zones: Array[Hurtbox] = []
	for zone: Variant in entry[0]:
		if is_instance_valid(zone) and (zone as Hurtbox).is_inside_tree() and (zone as Hurtbox).collision_layer != 0:
			zones.append(zone)
	return zones


## Every hit zone of [param thing] (its own, a guardian's zones, the T-Rex's).
static func _all_zones(thing: Node) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	for node in thing.find_children("*", "Hurtbox", true, false):
		var zone := node as Hurtbox
		if zone.collision_layer != 0 and zone.is_inside_tree():
			found.append(zone)
	return found


static func _weak(zone: Hurtbox) -> bool:
	if zone.weak_point:
		return true
	var receiver := zone.receiver
	return receiver is TRexZone and (receiver as TRexZone).zone == TRexBrain.Zone.CRYSTAL


func _is_big(thing: Node) -> bool:
	return thing is Guardian or thing is TRex


func _fight(delta: float) -> void:
	if not is_instance_valid(foe) or not foe.is_inside_tree():
		foe = null
		return
	var to_foe := foe.global_position - guard.global_position
	var distance := Vector2(to_foe.x, to_foe.z).length()
	var big := _is_big(foe)
	var exhibit := foe as Enemy
	if exhibit != null and not big and _finisher_worth(exhibit, distance):
		_stun_and_finish(delta, exhibit, distance)
		return
	var keep := PlaythroughBrain.ammo_to_keep(FloorProgress.from_game(game))
	var have := rounds()
	var tough := exhibit != null and exhibit.max_health >= TOUGH_HEALTH
	var weapon := PlaythroughBrain.combat_weapon(have, distance, big, keep, tough)
	var held := guard.weapons.current_state()
	if clock < _swap_until and have.has(_swap_to) and int(have[_swap_to]) > 0:
		weapon = _swap_to
	elif held != null and held.data.id == weapon and held.is_reloading() and distance < 9.0:
		# reloading with it close: the other gun for a while instead of waiting
		have.erase(weapon)
		var other := PlaythroughBrain.combat_weapon(have, distance, big, keep, tough)
		if other != &"fists" and other != &"taser":
			weapon = other
			_swap_to = other
			_swap_until = clock + SWAP_HOLD
	if weapon != &"fists" and pilot.weapon() != weapon:
		pilot.select_weapon(weapon)
	var aim: Vector3 = _foe_part.global_position if is_instance_valid(_foe_part) else foe.global_position + Vector3.UP * (2.0 if big else 1.0)
	pilot.look_at_point(_scattered(aim, delta))
	pilot.turn_now(delta)
	_fight_move(delta, distance, weapon, big)
	if not is_instance_valid(_foe_part):
		_hold(&"unseen")
		return
	if weapon == &"fists":
		if distance < 2.0 and pilot.aim_error(aim) < 20.0 and _shot_wait <= 0.0 and pilot.tap(&"punch"):
			stats["punches"] = int(stats["punches"]) + 1
			_shot_wait = guard.weapons.fists.data.cooldown + 0.05
		return
	# the trigger is held only while the view's ray meets the target first
	# (what it hides behind - a hoplite's shield - is one of its zones too:
	# only the part aimed at or a weak point); the gun fires at its own pace
	# and a gatling spins up while it is held
	if clock < _react_until:
		_hold(&"reacting")
		return
	if human:
		# pulled when the view is near enough the point aimed at: where the
		# shot lands is the gun's and the stray's affair
		if pilot.aim_error(aim) > HUMAN_TRIGGER + HUMAN_SCATTER:
			_hold(&"aiming")
			return
	else:
		var space := guard.get_world_3d().direct_space_state
		var hit := Hitscan.ray(space, pilot.eye(), pilot.eye() + pilot.forward() * 80.0)
		if hit.is_empty() or hit["hurtbox"] == null or not (hit["hurtbox"] == _foe_part or (_weak(hit["hurtbox"]) and _zones_cached(foe).has(hit["hurtbox"]))):
			_hold(&"aiming" if pilot.aim_error(aim) > 2.0 else &"blocked")
			return
	var state := guard.weapons.current_state()
	if state != null and state.data.id == weapon and state.has_ammo_left():
		pilot.firing = true
	else:
		_hold(&"switching" if state == null or state.data.id != weapon else &"empty")


## [param aim] as the bot that plays like a person points at it: off by
## the stray of the moment (HUMAN_SCATTER degrees, drawn again every
## 0.35-0.7 s), at its distance; [param aim] itself for the aimbot.
func _scattered(aim: Vector3, delta: float) -> Vector3:
	if not human:
		return aim
	_scatter_left -= delta
	if _scatter_left <= 0.0:
		_scatter_left = rng.randf_range(0.35, 0.7)
		_scatter = Vector2(rng.randfn(0.0, HUMAN_SCATTER), rng.randfn(0.0, HUMAN_SCATTER))
	var to := aim - pilot.eye()
	var distance := to.length()
	if distance < 0.1:
		return aim
	var ahead := to / distance
	var right := ahead.cross(Vector3.UP)
	if right.length() < 0.1:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(ahead).normalized()
	return aim + (right * tan(deg_to_rad(_scatter.x)) + up * tan(deg_to_rad(_scatter.y))) * distance


## A tough or shielded exhibit (a knight, a hoplite, a mummy) on its own is
## worth the taser and the fist: the stun drops its guard, a punch on the
## stunned finishes it (Enemy: can_finish) and heals.
func _finisher_worth(exhibit: Enemy, distance: float) -> bool:
	if exhibit.brain.is_stunned():
		return distance < 8.0
	var taser := guard.weapons.state_of(&"taser")
	if taser == null or taser.battery < taser.data.battery_cost or distance > 14.0:
		return false
	if exhibit.max_health < TOUGH_HEALTH and not (exhibit is Knight or exhibit is Hoplite):
		return false
	var others := 0
	for at in _near:
		if at.distance_to(exhibit.global_position) > 1.0:
			others += 1
	return others <= 1


## The taser from a few metres (its arc stuns), then in for the punch that
## finishes the stunned exhibit.
func _stun_and_finish(delta: float, exhibit: Enemy, distance: float) -> void:
	var aim: Vector3 = _foe_part.global_position if is_instance_valid(_foe_part) else exhibit.global_position + Vector3.UP * 1.0
	pilot.look_at_point(aim)
	pilot.turn_now(delta)
	var toward := exhibit.global_position - guard.global_position
	toward.y = 0.0
	if exhibit.brain.is_stunned():
		nav.cancel()
		if distance > 1.1:
			var way := _open_way(toward.normalized())
			pilot.move(way if way != Vector3.ZERO else toward.normalized(), true)
		else:
			pilot.stop()
		if distance < 1.9 and pilot.aim_error(aim) < 30.0 and _shot_wait <= 0.0 and pilot.tap(&"punch"):
			stats["punches"] = int(stats["punches"]) + 1
			stats["finishers"] = int(stats.get("finishers", 0)) + 1
			_shot_wait = guard.weapons.fists.data.cooldown + 0.05
		return
	if pilot.weapon() != &"taser":
		pilot.select_weapon(&"taser")
	if distance > PlaythroughBrain.TASER_RANGE - 1.0:
		_fight_goal_left -= delta
		if _fight_goal_due(exhibit.global_position):
			_fight_goal_left = 0.5
			_fight_goal = exhibit.global_position
			nav.may_sprint = false
			nav.go(exhibit.global_position, 3.5)
		nav.update(delta)
		nav.may_sprint = true
	else:
		nav.cancel()
		var away := -toward.normalized()
		var side := Vector3(-away.z, 0.0, away.x) * _strafe
		var wish := side if distance > 3.2 else (away + side * 0.5)
		var way := _open_way(wish.normalized())
		pilot.move(way)
	if pilot.weapon() != &"taser" or distance > PlaythroughBrain.TASER_RANGE:
		return
	var space := guard.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, pilot.eye(), pilot.eye() + pilot.forward() * PlaythroughBrain.TASER_RANGE)
	if not hit.is_empty() and hit["hurtbox"] != null and _zones_cached(exhibit).has(hit["hurtbox"]):
		pilot.firing = true


## True when the way in to the foe at [param at] is to be planned again:
## none yet (or it ended), or the timer ran out and the foe moved off the
## old goal by more than FIGHT_GOAL_MOVE m (a way planned again resets the
## walk's stuck check: re-planned every 0.6 s toward a foe standing still,
## the guard pressed into a column of the Colossus's hall for minutes
## without once counting as stuck).
func _fight_goal_due(at: Vector3) -> bool:
	if nav.status == PlaythroughNav.Status.IDLE or nav.status == PlaythroughNav.Status.ARRIVED or _fight_goal == Vector3.INF:
		return true
	if _fight_goal_left > 0.0:
		return false
	return nav.status == PlaythroughNav.Status.FAILED or at.distance_to(_fight_goal) > FIGHT_GOAL_MOVE


## Keeps the stand-off of [param weapon] from the foe [param distance] m
## away: in closer over the navmesh, back off, or strafe round it.
func _fight_move(delta: float, distance: float, weapon: StringName, big: bool) -> void:
	var standoff := float(STANDOFF.get(weapon, 8.0))
	if big:
		standoff = maxf(standoff, GUARDIAN_STANDOFF)
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_left = rng.randf_range(1.2, 2.6)
		_strafe = -_strafe if rng.randf() < 0.6 else _strafe
	var away := guard.global_position - foe.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-away.z, 0.0, away.x) * _strafe
	if foe is TRex and _dodge_trex(foe as TRex, away):
		return
	# awake exhibits too close push him off (all of them, not just the target)
	var push := Vector3.ZERO
	for at in _near:
		var off := guard.global_position - at
		off.y = 0.0
		var d := off.length()
		if d < KEEP_CLEAR and d > 0.01 and weapon != &"fists":
			push += off / d * (KEEP_CLEAR - d)
	if push.length() < 0.05 and (distance > standoff + 3.0 or not _foe_seen):
		# in closer (or round to see it): along the navmesh
		_fight_goal_left -= delta
		if _fight_goal_due(foe.global_position):
			_fight_goal_left = 0.6
			_fight_goal = foe.global_position
			nav.may_sprint = false
			nav.go(foe.global_position, standoff * 0.6)
		nav.update(delta)
		nav.may_sprint = true
		return
	nav.cancel()
	var wish := side
	if push.length() >= 0.05:
		wish = push.normalized() * 1.4 + side * 0.5
	elif distance < standoff - 1.5:
		wish = away * 1.2 + side * 0.6
	elif distance > standoff + 1.0:
		wish = -away * 0.8 + side
	var free := _open_way(wish.normalized())
	if free == Vector3.ZERO:
		_strafe = -_strafe
		free = _open_way(Vector3(-away.z, 0.0, away.x) * _strafe)
	var hurt := guard.health.current < guard.health.max_health * 0.5
	pilot.move(free, push.length() >= 0.05 and hurt and guard.stamina.current > guard.stamina.maximum * 0.25)
	# a claw about to land: a dash out of it
	if push.length() > KEEP_CLEAR * 0.6 and guard.stamina.current > guard.stamina.maximum * 0.4 and free != Vector3.ZERO:
		pilot.tap(&"dash")


## The T-Rex's telegraphs (the scrape before a charge, the tail drawn
## back) answered like a player: out of the charge's line at a sprint, out
## of the tail's reach. True while dodging.
func _dodge_trex(rex: TRex, away: Vector3) -> bool:
	var state := rex.brain.state
	if state == TRexBrain.State.CHARGE_WINDUP or state == TRexBrain.State.CHARGE:
		nav.cancel()
		var facing := -rex.global_basis.z
		facing.y = 0.0
		var across := Vector3(-facing.z, 0.0, facing.x).normalized()
		# the side of its line he already stands on
		var side := 1.0 if (guard.global_position - rex.global_position).dot(across) >= 0.0 else -1.0
		var way := _open_way(across * side)
		if way == Vector3.ZERO:
			way = _open_way(-across * side)
		pilot.move(way, true)
		if state == TRexBrain.State.CHARGE and guard.stamina.current > guard.stamina.maximum * 0.3:
			pilot.tap(&"dash")
		return true
	if (state == TRexBrain.State.TAIL_WINDUP or state == TRexBrain.State.TAIL_SWIPE) and rex.global_position.distance_to(guard.global_position) < 9.0:
		nav.cancel()
		pilot.move(_open_way(away), true)
		return true
	return false


## The way along [param wish] (or the nearest of it, turned up to 135
## degrees either side) that has floor 1.5 m on (in the arena while a
## guardian fights); ZERO when he is boxed in.
func _open_way(wish: Vector3) -> Vector3:
	if wish.length() < 0.01:
		return Vector3.ZERO
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.4, -2.4]:
		var way := wish.rotated(Vector3.UP, turn)
		var probe := guard.global_position + way * 1.5
		var on_mesh := nav.snap(probe)
		if Vector2(on_mesh.x - probe.x, on_mesh.z - probe.z).length() <= 0.6 and absf(on_mesh.y - probe.y) < 1.0 and _stays_in_arena(on_mesh):
			return way
	return Vector3.ZERO


func _stays_in_arena(point: Vector3) -> bool:
	if not foe is Guardian:
		return true
	var arena := (foe as Guardian).arena_room
	return arena == &"" or level.layout.room_at(point + Vector3.UP * 0.5) == arena


## Counts the rounds that left the magazines since the last step (and the
## taser's discharges) as shots.
func _count_shots() -> void:
	for state in guard.weapons.owned:
		var id := state.data.id
		var now := state.magazine if state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE else int(state.battery / maxf(state.data.battery_cost, 1.0))
		var before := int(_mag_seen.get(id, now))
		if now < before and not state.is_reloading():
			stats["shots"] = int(stats["shots"]) + before - now
		_mag_seen[id] = now


## Reloads an empty gun (the game reloads only on a pull of the trigger),
## and tops up a half-empty one when nothing is after him.
func _manage_reload() -> void:
	var state := guard.weapons.current_state()
	if state == null or state.data.ammo_mode != WeaponData.AmmoMode.MAGAZINE or state.is_reloading() or state.reserve <= 0:
		return
	var calm := foe == null and _near.is_empty()
	if state.magazine == 0 or (calm and state.magazine < state.data.magazine_size * 0.5):
		pilot.tap(&"reload")


## The fight with [param was] is over (it fell, he turned to another, it
## went out of sight): a line for the log with its length, shots and the
## damage he took meanwhile.
func _end_fight(was: Node3D) -> void:
	if was == null or _fight_since < 0.0:
		return
	var killed := not is_instance_valid(was) or not was.is_inside_tree() or (was is Enemy and (was as Enemy).health.is_dead())
	var kind := _fight_kind if killed else _describe(was)
	var seconds := clock - _fight_since
	var by_kind: Dictionary = stats.get("fights_by", {})
	var entry: Array = by_kind.get(kind, [0, 0.0, 0, 0.0, 0])
	entry[0] = int(entry[0]) + 1
	entry[1] = float(entry[1]) + seconds
	entry[2] = int(entry[2]) + int(stats["shots"]) - _fight_shots
	entry[3] = float(entry[3]) + float(stats["damage_taken"]) - _fight_damage
	entry[4] = int(entry[4]) + (1 if killed else 0)
	by_kind[kind] = entry
	stats["fights_by"] = by_kind
	_fight_since = -1.0


## Adds the microseconds since [param since] to [param part]'s share of
## the bot's thinking (for the report: where its time goes).
func _profile(part: StringName, since: int) -> void:
	var spent: Dictionary = stats.get("think_ms", {})
	spent[String(part)] = float(spent.get(String(part), 0.0)) + (Time.get_ticks_usec() - since) / 1000.0
	stats["think_ms"] = spent


## Counts why a shot was held this step (for the report).
func _hold(why: StringName) -> void:
	var held: Dictionary = stats.get("held", {})
	held[String(why)] = int(held.get(String(why), 0)) + 1
	stats["held"] = held


# --- what happened -------------------------------------------------------------------------------

func _on_damaged(amount: float, from_position: Vector3) -> void:
	stats["damage_taken"] = float(stats["damage_taken"]) + amount
	stats["hits_taken"] = int(stats["hits_taken"]) + 1
	var by := _nearest_attacker(from_position)
	_last_damage = {"amount": snappedf(amount, 0.1), "by": by, "health": snappedf(guard.health.current - amount, 0.1), "clock": snappedf(clock, 0.1)}
	if guard.health.current - amount <= 0.0:
		_note(&"killing_blow", _last_damage)


func last_damage() -> Dictionary:
	return _last_damage


## What most likely dealt a hit from [param at]: the nearest exhibit,
## guardian or boss (by its class), "?" when nothing is near.
func _nearest_attacker(at: Vector3) -> String:
	var best := "?"
	var best_distance := 8.0
	for exhibit in museum.exhibits():
		var d := exhibit.global_position.distance_to(at)
		if d < best_distance:
			best_distance = d
			best = _describe(exhibit)
	if floor_game.guardians != null:
		for node: Guardian in floor_game.guardians.guardians.values():
			if is_instance_valid(node) and node.state == Guardian.State.FIGHT:
				var d := node.global_position.distance_to(at)
				if d < best_distance + 6.0:
					best = "guardian:%s" % node.guardian_id
					best_distance = d
	var finale := floor_game.finale
	if finale != null and finale.stage == FloorFinale.Stage.BOSS and is_instance_valid(finale.boss):
		if finale.boss.global_position.distance_to(at) < best_distance + 8.0:
			best = "trex"
	return best


func _on_enemy_destroyed(enemy: Node, info: DamageInfo, _finisher: bool) -> void:
	if info != null and info.source == guard:
		stats["kills"] = int(stats["kills"]) + 1
		if enemy == foe:
			_retarget = 0.0


static func _describe(thing: Node) -> String:
	if thing == null:
		return "?"
	if thing is Guardian:
		return "guardian:%s" % (thing as Guardian).guardian_id
	if thing is TRex:
		return "trex"
	var script := thing.get_script() as Script
	return String(script.get_global_name()) if script != null and script.get_global_name() != &"" else thing.get_class()


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]
