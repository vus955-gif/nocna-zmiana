class_name ScenarioCast
extends RefCounted
## Who plays which beat of tonight's room scenarios (plan
## 2026-10-22-projekt-starc): worked out once a night from the night's draw,
## pure and the same for the same night. A scenario's pool is the night's
## exhibits in its rooms - the drawn sets (the director's density caps,
## calm, weakened wings, the gentle first night all stand) and the
## sleepers of the ambushes it absorbs; other ALWAYS_SET slots (ambushes it
## leaves alone, set pieces) stay out. The pool is shuffled on a generator
## of its own (seed, night, scenario id: the rest of the night does not
## move); each beat in turn takes its count of the exhibits that fit it
## (role, kind, room, ambush; only sleepers after the first beat, only
## kinds that may leave their post for a beat with a waiting point), in
## the order its pick says. Whoever no beat took plays as today. Nothing
## is added: a scenario only orders who the night already drew.

## Night meta key the cast is kept under (one cast per NightConfig).
const META := &"scenario_cast"

## Slot index -> [scenario id, beat index].
var beat_of: Dictionary = {}
## Scenario id -> Array (per beat) of Array[int] (slot indices).
var actors: Dictionary = {}
## Slot index -> [Vector3, yaw]: where it waits all night for its beat.
var staged: Dictionary = {}
## Ambush ids taken over by a scenario playing tonight.
var absorbed: Array[StringName] = []
## Scenario ids playing tonight (enabled, from their first night on).
var playing: Array[StringName] = []


## Tonight's cast on [param floor_layout] (worked out once, kept with the
## night).
static func of(config: NightConfig, floor_layout: LevelLayout) -> ScenarioCast:
	if config.has_meta(META):
		return config.get_meta(META)
	var cast := plan(config, floor_layout, ScenarioCatalog.active())
	config.set_meta(META, cast)
	return cast


static func plan(config: NightConfig, floor_layout: LevelLayout, catalog: ScenarioCatalog) -> ScenarioCast:
	var cast := ScenarioCast.new()
	var drawn := {}
	for spawn in config.spawns:
		drawn[spawn.slot] = spawn
	for scenario in catalog.enabled():
		if config.night < int(scenario["from_night"]):
			continue
		var id: StringName = scenario["id"]
		cast.playing.append(id)
		var absorbs: Array[StringName] = scenario["absorbs"]
		var ambush_of := {}
		for ambush in floor_layout.ambushes:
			if absorbs.has(ambush.id):
				for slot in ambush.slots:
					ambush_of[slot] = ambush.id
				if not cast.absorbed.has(ambush.id):
					cast.absorbed.append(ambush.id)
		var pool: Array = []
		var slots: Array = drawn.keys()
		slots.sort()
		for slot_index: int in slots:
			var spawn: NightConfig.Spawn = drawn[slot_index]
			if slot_index < 0 or slot_index >= floor_layout.spawn_slots.size() or cast.beat_of.has(slot_index):
				continue
			var slot := floor_layout.spawn_slots[slot_index]
			if not (scenario["rooms"] as Array).has(slot.room):
				continue
			if slot.set_id == SpawnSlot.ALWAYS_SET and not ambush_of.has(slot_index):
				continue
			pool.append({"slot": slot_index, "kind": spawn.kind, "awake": not spawn.dormant, "room": slot.room,
					"ambush": ambush_of.get(slot_index, &""), "at": slot.position})
		var rng := RandomNumberGenerator.new()
		rng.seed = config.night_seed * 59 + config.night * 23 + String(id).hash()
		_shuffle(rng, pool)
		var per_beat: Array = []
		var beats: Array = scenario["beats"]
		for b in beats.size():
			var beat: Dictionary = beats[b]
			var fits := pool.filter(func(e: Dictionary) -> bool: return _fits(e, beat, b, true))
			if fits.is_empty() and beat["fallback"]:
				fits = pool.filter(func(e: Dictionary) -> bool: return _fits(e, beat, b, false))
			_order(fits, beat["pick"], scenario["entry"])
			var chosen: Array[int] = []
			for entry: Dictionary in fits.slice(0, int(beat["count"])):
				var slot_index: int = entry["slot"]
				chosen.append(slot_index)
				cast.beat_of[slot_index] = [id, b]
				pool.erase(entry)
				if beat["from"] != &"":
					var point: Array = scenario["points"][beat["from"]]
					# a second exhibit waits a step to the side of the first
					var side := Vector3(cos(float(point[1])), 0.0, -sin(float(point[1])))
					cast.staged[slot_index] = [(point[0] as Vector3) + side * 1.2 * (chosen.size() - 1), float(point[1])]
			per_beat.append(chosen)
		cast.actors[id] = per_beat
	return cast


## True when [param entry] of the pool may play [param beat] (number
## [param index]); [param strict]: its roles, kinds and room as well.
static func _fits(entry: Dictionary, beat: Dictionary, index: int, strict: bool) -> bool:
	if entry["ambush"] != beat["ambush"]:
		return false
	if index > 0 and (entry["awake"] or entry["kind"] == NightSpawner.FLOCK):
		return false   # (a flock's books do not keep Enemy.held: they may only open a scenario)
	if beat["from"] != &"" and (entry["awake"] or not stageable(entry["kind"])):
		return false
	if not strict:
		return true
	if beat["room"] != &"" and entry["room"] != beat["room"]:
		return false
	var kinds: Array[StringName] = beat["kinds"]
	if not kinds.is_empty() and not kinds.has(entry["kind"]):
		return false
	var roles: Array[int] = beat["roles"]
	return roles.is_empty() or roles.has(int(EnemyRoles.role(entry["kind"])))


## True when [param kind] may wait for its beat away from its slot: not a
## pack or a flock, not a kind whose sleep is its display (a mummy in its
## tomb, a relief in its slab, books on their shelf).
static func stageable(kind: StringName) -> bool:
	if kind == NightSpawner.PACK or kind == NightSpawner.FLOCK:
		return false
	var sleep := EnemyRoles.sleep(kind)
	return sleep == EnemyRoles.Sleep.NONE or sleep == EnemyRoles.Sleep.STIR


static func _order(entries: Array, pick: StringName, entry_point: Vector3) -> void:
	if pick == &"seed" or entry_point == Vector3.INF:
		return
	var near := pick == &"near"
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := (a["at"] as Vector3).distance_squared_to(entry_point)
		var db := (b["at"] as Vector3).distance_squared_to(entry_point)
		if is_equal_approx(da, db):
			return int(a["slot"]) < int(b["slot"])
		return da < db if near else da > db)


## Fisher-Yates on the cast's own generator.
static func _shuffle(rng: RandomNumberGenerator, items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


## Every slot of [param scenario_id]'s beats before [param beat] (they
## count for a beat's "down").
func earlier(scenario_id: StringName, beat: int) -> Array[int]:
	var found: Array[int] = []
	var per_beat: Array = actors.get(scenario_id, [])
	for b in mini(beat, per_beat.size()):
		found.append_array(per_beat[b])
	return found


func slots_of(scenario_id: StringName, beat: int) -> Array[int]:
	var per_beat: Array = actors.get(scenario_id, [])
	if beat < 0 or beat >= per_beat.size():
		return [] as Array[int]
	return per_beat[beat]


## Plain data (tests, logs).
func to_dict() -> Dictionary:
	var placed := {}
	for slot: int in staged:
		placed[slot] = [staged[slot][0], staged[slot][1]]
	return {"beat_of": beat_of.duplicate(true), "staged": placed, "absorbed": absorbed.duplicate(), "playing": playing.duplicate()}
