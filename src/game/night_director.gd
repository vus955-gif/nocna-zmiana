class_name NightDirector
extends RefCounted
## Draws a night (design: etap-2-projekt section 6). Everything comes from
## one RandomNumberGenerator seeded with the night seed, drawn in a fixed
## order, so the same seed and night give the same NightConfig.
## - modifier: night 1 none; later none 40% / blackout 20% / full moon 20% /
##   calm 20%,
## - crystal: one of the candidate cases,
## - locked door: none on night 1; later 60% one of the lockable doors,
##   but only a door whose closing leaves every objective reachable from
##   every start haven, and never a door on the crystal's flight to the
##   boss room,
## - encounters: one set per room (ALWAYS_SET slots stand every night on
##   top of it); on a level with zone densities (Floor I) a drawn set is
##   trimmed to the night's cap of the room (room area x zone density: its
##   whole part, one more with the chance of its fraction); calm keeps about
##   60% of its exhibits; a weakened wing (its guardian fell) about
##   WEAKENED_KEEP of its drawn exhibits,
## - loot: the always-artifact spots plus random containers make 2-3
##   artifacts; the janitor's key comes only on a night with a locked door
##   (KEY_CHANCE), in a display case the guard can reach with that door
##   shut, never in a secret room or an always-artifact spot; every other
##   spot gets ammo or a medkit with 60% chance (scaled by the difficulty:
##   loot_scale, applied after the portraits),
## - fuses: one of the two points of each wing,
## - portraits: 2-4 of the painting spots hold a portrait that wakes (drawn
##   last, so the draws above stay as they were),
## - watchers (backlog #8, #25): a room whose draw holds at least
##   WATCHER_ROOM exhibits (5 on night 1: watcher_room()) and none awake gets
##   one of them awake - a tank, a flanker or a melee kind of a plain set
##   (never an ambush's slot, never
##   a pack or a flock, never a kind whose sleep is its display: a mummy in
##   its tomb, a relief in its slab) - to walk a beat or a round while the
##   rest sleep and stir. Drawn on a generator of its own (seed and night),
##   so the rest of the night is as it was without them,
## - a gentle first night (pietro-1-projekt 7.2): on night 1 the rooms on
##   the way from the first start haven to the boss room hold no wolves nor
##   raptors (wax figures instead), no watchers, and at most GENTLE_AWAKE
##   awake exhibits;
##   applied after every draw, so the rest of the night stays the same. For
##   its first GENTLE_TIME seconds the sleepers there sleep soundly (the
##   Museum sets Enemy.sound_asleep): only the patrols are combat training.

const MODIFIERS: Array = [[&"none", 40], [&"blackout", 20], [&"full_moon", 20], [&"calm", 20]]
const LOCK_CHANCE := 0.6
const CALM_KEEP := 0.6
## A wing whose guardian fell keeps this part of its drawn exhibits
## (design 3.2: "the wing's magic has weakened").
const WEAKENED_KEEP := 0.55
const LOOT_CHANCE := 0.6
## Ammo for every weapon (the Museum swaps belts and flares for bullets and
## shells while the guard lacks the gatling or the flare gun).
const LOOT: Array = [[&"bullets", 38], [&"shells", 20], [&"rifle", 12], [&"flares", 8], [&"medkit", 22]]
const PORTRAITS := Vector2i(2, 4)
const ARTIFACTS: Array[StringName] = [&"scarab", &"monocle", &"fountain_coin", &"candle_stub", &"wolf_tooth", &"janitor_key"]
const JANITOR_KEY := &"janitor_key"
## Chance that a night with a locked door hides the janitor's key.
const KEY_CHANCE := 0.7
const MIN_ARTIFACTS := 2
const MAX_ARTIFACTS := 3
## Night 1 on the way out of the first haven: these kinds become wax, and
## at most this many exhibits there are awake (patrolling).
const GENTLE_SWAP: Array[StringName] = [&"wolf", &"raptor"]
const GENTLE_AWAKE := 2
## ...and the sleepers there sleep soundly for the night's first seconds.
const GENTLE_TIME := 180.0
## A room with this many drawn exhibits (and none awake) gets a watcher -
## from night 2; night 1 waits for WATCHER_ROOM_FIRST_NIGHT (measured on
## Floor I: three nearly doubled the first night's exhibits on their feet).
const WATCHER_ROOM := 3
const WATCHER_ROOM_FIRST_NIGHT := 5
## Roles a watcher may have (EnemyRoles.Role): on its feet it reads as a
## guard or a prowler, not as support left standing.
const WATCHER_ROLES: Array = [EnemyRoles.Role.TANK, EnemyRoles.Role.FLANKER, EnemyRoles.Role.MELEE_PRESSURE]
## Kinds never woken for a watch: their sleep is their display and their
## waking its moment (EnemyRoles.Sleep: a mummy in its tomb, a relief in
## its slab, books on their shelf).
const NEVER_WATCH: Array = [EnemyRoles.Sleep.TOMB, EnemyRoles.Sleep.SLAB, EnemyRoles.Sleep.SHELF]

## Warnings given so far (each once per run of the game: every night draws
## on a fresh description of the same level, so a warning kept on the
## description would come back every night).
static var warnings: PackedStringArray = []


## [param weakened_zones]: zones whose guardian fell (Floor I);
## [param loot_scale]: the difficulty's share of loot (DifficultyRules).
static func plan(night_seed: int, night: int, level: LevelDescription, weakened_zones: Array[StringName] = [], loot_scale: float = 1.0) -> NightConfig:
	var rng := RandomNumberGenerator.new()
	rng.seed = night_seed
	var config := NightConfig.new()
	config.night_seed = night_seed
	config.night = night
	config.modifier = &"none" if night <= 1 else _weighted(rng, MODIFIERS)
	if not level.crystal_cases.is_empty():
		config.crystal_case = level.crystal_cases[rng.randi_range(0, level.crystal_cases.size() - 1)]
	config.locked_door = _locked_door(rng, night, level, config.crystal_case)
	_encounters(rng, level, config)
	if not weakened_zones.is_empty():
		_weaken(rng, level, config, weakened_zones)
	watchers(level, config)
	_loot(rng, level, config)
	var wings: Array[StringName] = []
	wings.assign(level.fuse_points.keys())
	# by text, not by StringName identity: the same seed must give the same
	# night in every run of the game
	wings.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for wing: StringName in wings:
		var points: Array[StringName] = level.fuse_points[wing]
		if not points.is_empty():
			config.fuses[wing] = points[rng.randi_range(0, points.size() - 1)]
	_portraits(rng, level, config)
	if not is_equal_approx(loot_scale, 1.0):
		_scale_loot(rng, level, config, loot_scale)
	if night <= 1:
		gentle_first_night(level, config)
	return config


## Rooms on the way from the first start haven to the boss room (the
## haven itself left out), in order; [] when the level has no such way.
static func first_way(level: LevelDescription) -> Array[StringName]:
	var rooms: Array[StringName] = []
	if level.graph == null or level.start_rooms.is_empty() or level.boss_room == &"":
		return rooms
	var room := level.start_rooms[0]
	for door in level.graph.route(room, level.boss_room):
		var ends := level.graph.door_rooms(door)
		room = ends[1] if ends[0] == room else ends[0]
		rooms.append(room)
	return rooms


## Night 1's first rooms: wax for wolves and raptors, no watchers (only the
## level's own patrols are the combat training there), at most
## GENTLE_AWAKE awake exhibits (the rest sleep).
static func gentle_first_night(level: LevelDescription, config: NightConfig) -> void:
	var rooms := first_way(level)
	var awake := 0
	for spawn in config.spawns:
		if spawn.slot < 0 or spawn.slot >= level.spawn_slots.size() or not rooms.has(level.spawn_slots[spawn.slot].room):
			continue
		if GENTLE_SWAP.has(spawn.kind):
			spawn.kind = &"wax"
		if spawn.watcher:
			spawn.watcher = false
			spawn.dormant = true
		if not spawn.dormant:
			if awake < GENTLE_AWAKE:
				awake += 1
			else:
				spawn.dormant = true


## How many drawn exhibits make a room worth a watcher on [param night].
static func watcher_room(night: int) -> int:
	return WATCHER_ROOM_FIRST_NIGHT if night <= 1 else WATCHER_ROOM


## One watcher per well-filled sleeping room (see the class notes): drawn
## on its own generator, so nothing else in the night moves.
static func watchers(level: LevelDescription, config: NightConfig) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.night_seed * 53 + config.night * 17
	var by_room := {}
	for spawn in config.spawns:
		if spawn.slot < 0 or spawn.slot >= level.spawn_slots.size():
			continue
		var room := level.spawn_slots[spawn.slot].room
		if not by_room.has(room):
			by_room[room] = []
		(by_room[room] as Array).append(spawn)
	var rooms: Array = by_room.keys()
	rooms.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for room: StringName in rooms:
		var here: Array = by_room[room]
		if here.size() < watcher_room(config.night) or here.any(func(s: NightConfig.Spawn) -> bool: return not s.dormant):
			continue
		var candidates: Array = here.filter(func(s: NightConfig.Spawn) -> bool:
			return level.spawn_slots[s.slot].set_id != SpawnSlot.ALWAYS_SET and not NEVER_WATCH.has(EnemyRoles.sleep(s.kind)) \
					and WATCHER_ROLES.has(EnemyRoles.role(s.kind)) and s.kind != NightSpawner.PACK and s.kind != NightSpawner.FLOCK)
		if candidates.is_empty():
			continue
		var chosen: NightConfig.Spawn = candidates[rng.randi_range(0, candidates.size() - 1)]
		chosen.dormant = false
		chosen.watcher = true


static func _portraits(rng: RandomNumberGenerator, level: LevelDescription, config: NightConfig) -> void:
	if level.portrait_spots.is_empty():
		return
	var spots: Array[StringName] = level.portrait_spots.duplicate()
	_shuffle(rng, spots)
	var chosen := spots.slice(0, mini(rng.randi_range(PORTRAITS.x, PORTRAITS.y), spots.size()))
	# in the level's order, so a night reads the same whatever the shuffle
	for id in level.portrait_spots:
		if chosen.has(id):
			config.portraits.append(id)


## Doors that may be locked without cutting any objective off (with
## LevelDescription.always_open set: without cutting any room off, the gates
## listed there counted as open - never the only way anywhere). Gates and
## false panels are never lockable.
static func safe_doors(level: LevelDescription) -> Array[StringName]:
	var safe: Array[StringName] = []
	for door in level.lockable_doors:
		var closed: Array[StringName] = [door]
		if level.always_open.is_empty():
			if level.objectives_reachable(closed):
				safe.append(door)
		elif not level.cuts_off(door):
			safe.append(door)
	return safe


static func _locked_door(rng: RandomNumberGenerator, night: int, level: LevelDescription, crystal_case: StringName) -> StringName:
	if night <= 1:
		return &""
	var roll := rng.randf()
	# the crystal flies to the boss through open doors
	var route := level.crystal_route(crystal_case)
	var candidates := safe_doors(level).filter(func(door: StringName) -> bool: return not route.has(door))
	if roll >= LOCK_CHANCE or candidates.is_empty():
		return &""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _encounters(rng: RandomNumberGenerator, level: LevelDescription, config: NightConfig) -> void:
	for room in level.encounter_rooms():
		var sets := level.sets_in(room)
		sets.erase(SpawnSlot.ALWAYS_SET)
		var picked: Array[int] = []
		var always: Array[int] = []
		var chosen: int = SpawnSlot.ALWAYS_SET
		if not sets.is_empty():
			chosen = sets[rng.randi_range(0, sets.size() - 1)]
			config.encounter_sets[room] = chosen
		for i in level.spawn_slots.size():
			var slot := level.spawn_slots[i]
			if slot.room != room:
				continue
			if slot.set_id == SpawnSlot.ALWAYS_SET:
				always.append(i)
			elif slot.set_id == chosen:
				picked.append(i)
		var limit := level.room_limit(room)
		var cap := -1
		if limit >= 0.0:
			cap = floori(limit) + (1 if rng.randf() < limit - floorf(limit) else 0)
		if cap >= 0 and picked.size() > cap:
			_shuffle(rng, picked)
			picked = picked.slice(0, cap)
			picked.sort()
		if config.modifier == &"calm" and not picked.is_empty():
			var keep := maxi(1, roundi(picked.size() * CALM_KEEP))
			_shuffle(rng, picked)
			picked = picked.slice(0, keep)
			picked.sort()
		picked.append_array(always)
		picked.sort()
		for i in picked:
			var slot := level.spawn_slots[i]
			# the draw stays (the same RNG calls: the rest of the night is
			# unchanged); a [stand-in, intended] pair gives the intended kind
			var kind: StringName = slot.kinds[rng.randi_range(0, slot.kinds.size() - 1)] if not slot.kinds.is_empty() else &"wax"
			config.spawns.append(NightConfig.Spawn.new(i, NightSpawner.preferred(slot.kinds, kind), slot.dormant))


## The wings in [param zones] keep WEAKENED_KEEP of their drawn exhibits
## (the ALWAYS_SET ones - ambushes, set pieces - all stay).
static func _weaken(rng: RandomNumberGenerator, level: LevelDescription, config: NightConfig, zones: Array[StringName]) -> void:
	var drawn: Array[int] = []
	for n in config.spawns.size():
		var slot := level.spawn_slots[config.spawns[n].slot]
		if slot.set_id != SpawnSlot.ALWAYS_SET and zones.has(level.room_zones.get(slot.room, slot.zone)):
			drawn.append(n)
	if drawn.is_empty():
		return
	var keep := roundi(drawn.size() * WEAKENED_KEEP)
	_shuffle(rng, drawn)
	var dropped := drawn.slice(keep)
	dropped.sort()
	dropped.reverse()
	for n: int in dropped:
		config.spawns.remove_at(n)


## The difficulty's loot: below 1 each consumable stays with that chance;
## above 1 empty spots fill up so about LOOT_CHANCE x [param scale] of the
## spots hold something. Artifacts stay as drawn.
static func _scale_loot(rng: RandomNumberGenerator, level: LevelDescription, config: NightConfig, scale: float) -> void:
	if scale < 1.0:
		var spots: Array = config.loot.keys()
		spots.sort()
		for spot: int in spots:
			if not ARTIFACTS.has(config.loot[spot]) and rng.randf() >= scale:
				config.loot.erase(spot)
		return
	var fill := clampf(LOOT_CHANCE * (scale - 1.0) / (1.0 - LOOT_CHANCE), 0.0, 1.0)
	for i in level.loot_spots.size():
		if not config.loot.has(i) and rng.randf() < fill:
			config.loot[i] = _weighted(rng, LOOT)


static func _loot(rng: RandomNumberGenerator, level: LevelDescription, config: NightConfig) -> void:
	var always: Array[int] = []
	for i in level.always_artifact_spots:
		if i >= 0 and i < level.loot_spots.size() and not always.has(i):
			always.append(i)
	# the janitor's key: only on a night with a locked door, not always, and
	# where the guard can get to it with that door shut
	var key_spot := -1
	if config.locked_door != &"" and rng.randf() < KEY_CHANCE:
		var candidates := _key_spots(level, config.locked_door, always)
		if not candidates.is_empty():
			key_spot = candidates[rng.randi_range(0, candidates.size() - 1)]
	var pool: Array[StringName] = ARTIFACTS.duplicate()
	pool.erase(JANITOR_KEY)
	_shuffle(rng, pool)
	var wanted := rng.randi_range(MIN_ARTIFACTS, MAX_ARTIFACTS) - (1 if key_spot >= 0 else 0)
	var holders: Array[int] = always.duplicate()
	var containers: Array[int] = []
	var open_spots: Array[int] = []
	for i in level.loot_spots.size():
		if holders.has(i) or i == key_spot:
			continue
		if level.loot_spots[i].container:
			containers.append(i)
		else:
			open_spots.append(i)
	_shuffle(rng, containers)
	_shuffle(rng, open_spots)
	# containers first; loose spots only when there are too few containers
	var extra := containers + open_spots
	while holders.size() < wanted and not extra.is_empty():
		holders.append(extra.pop_front())
	var placed := mini(holders.size(), pool.size())
	if placed + (1 if key_spot >= 0 else 0) < MIN_ARTIFACTS:
		_warn_once("NightDirector: only %d loot spots for at least %d artifacts" % [level.loot_spots.size(), MIN_ARTIFACTS])
	for n in placed:
		config.loot[holders[n]] = pool[n]
		config.artifacts.append(pool[n])
	if key_spot >= 0:
		config.loot[key_spot] = JANITOR_KEY
		config.artifacts.append(JANITOR_KEY)
	for i in level.loot_spots.size():
		if config.loot.has(i):
			continue
		if rng.randf() < LOOT_CHANCE:
			config.loot[i] = _weighted(rng, LOOT)


## Display cases for the janitor's key: not an always-artifact spot, not in
## a secret room, and reachable from every start with [param locked] shut.
static func _key_spots(level: LevelDescription, locked: StringName, always: Array[int]) -> Array[int]:
	var open_rooms := level.reachable_from_every_start([locked] as Array[StringName])
	var spots: Array[int] = []
	for i in level.loot_spots.size():
		var spot := level.loot_spots[i]
		if spot.container and not always.has(i) and not level.secret_rooms.has(spot.room) and open_rooms.has(spot.room):
			spots.append(i)
	return spots


static func _warn_once(text: String) -> void:
	if not warnings.has(text):
		warnings.append(text)
		push_warning(text)


## Picks from [[value, weight], ...].
static func _weighted(rng: RandomNumberGenerator, table: Array) -> StringName:
	var total := 0
	for entry: Array in table:
		total += int(entry[1])
	var roll := rng.randi_range(0, total - 1)
	for entry: Array in table:
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return table[-1][0]


## Fisher-Yates with the night's generator (Array.shuffle() would use the
## global one and break determinism).
static func _shuffle(rng: RandomNumberGenerator, items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
