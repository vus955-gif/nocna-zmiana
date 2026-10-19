class_name Floor1Route
extends RefCounted
## The pure logic of the Floor I verification (W7; plan
## docs/superpowers/plans/2026-10-03-p1-w7-weryfikacja.md): play orders
## from ProgressRules (the one the HUD goal leads a new player along and
## random valid ones), what the guard walks to for each step, and the time
## model of the walking bot (fights from the night director's draw, a look
## round each room, notes read from their texts, the nights). No nodes: the
## navmesh side lives in Floor1Survey.
##
## Every number of the time model is an assumption kept here (and written
## into the bot's JSON next to its results): the distances are measured on
## the navmesh, the rest is an estimate of a first-time player.

# --- the time model -------------------------------------------------------------

## Player.walk_speed (m/s).
const WALK_SPEED := 5.5
## Looking round a room on the first visit: a base, more for a bigger
## floor, capped; on the critical path a glance at the rooms passed through.
const LOOK_BASE := 8.0
const LOOK_PER_M2 := 1.0 / 25.0
const LOOK_MAX := 45.0
const GLANCE_SHARE := 0.5
## A first-time player's damage per second over a fight (aim, reloads,
## dodging) and the seconds every exhibit costs on top (closing in, the
## last blow); a room with exhibits takes ROOM_CLEAR more (loot, corners).
const DPS := 25.0
const FIGHT_OVERHEAD := 3.0
const ROOM_CLEAR := 5.0
## The same room on a later night: exhibits are back (design 3.2), but a
## guard who knows the way slips past about half of them; a wing whose
## guardian fell keeps NightDirector.WEAKENED_KEEP of them.
const REVISIT_SHARE := 0.5
## Guardian fights (design 7.4: 2-3.5 min) and the T-Rex.
const GUARDIAN_FIGHT := 165.0
const TREX_FIGHT := 150.0
## Reading a note: picking it up and putting it down, then the words.
const NOTE_BASE := 4.0
const WORDS_PER_SECOND := 3.0
## Searching out a secret (a knock, a loose stone, the lock of its gate).
const SECRET_SEARCH := 20.0
## Taking a weapon, a key item or a chess piece; working a device (the
## switchboard, the astrolabe); opening a gate.
const PICKUP_TIME := 5.0
const DEVICE_TIME := 8.0
const GATE_TIME := 4.0
## A night: 23:00-6:00 at 3 min 20 s an hour (design 3.1); each night
## starts at the last haven with a moment at its terminal.
const NIGHT_LENGTH := 7.0 * 200.0
const NIGHT_START := 30.0
## A new haven found: the toast, the map on the wall.
const HAVEN_FIRST := 10.0

## Exhibit kind -> hit points (the code's exhibits; the new kinds of
## design section 5 by their numbers; a flock or a totem as a whole).
const KIND_HP := {
	&"wax": 60.0, &"wolf": 35.0, &"knight": 180.0, &"bust": 45.0, &"raptor": 25.0, &"portrait": 40.0,
	&"mummy": 110.0, &"scarabs": 40.0, &"relief_warrior": 50.0, &"relief_lion": 35.0,
	&"hoplite": 140.0, &"books": 90.0, &"fu_dog": 160.0, &"samurai": 180.0, &"samurai_armor": 180.0,
	&"totem": 120.0, &"jaguar": 70.0,
}
const DEFAULT_HP := 60.0

## Zone -> the part of the floor it counts for in the report.
const WING_OF := {
	&"booth": &"hub", &"entrance": &"hub", &"court": &"hub", &"north_hall": &"hub",
	&"egypt": &"egypt", &"assyria": &"assyria", &"greece": &"greece",
	&"enlightenment": &"enlightenment", &"asia": &"asia", &"americas": &"americas",
	&"basement": &"basement", &"roof": &"roof",
}
const PARTS: Array[StringName] = [&"hub", &"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas", &"basement", &"roof"]

## How close the guard's eye must come to a marker (m): the use probe
## (Interactor.REACH) plus the half-size of the thing on the marker.
const USE_REACH := 2.2
const PROP_SLACK := 0.6
## A floor marker (an arena's way in, the stairs into the dark): the
## navmesh within this many metres of it.
const FLOOR_REACH := 1.5
## The T-Rex's pedestal: the court floor this close to it.
const NEAR_REACH := 6.0


# --- play orders ------------------------------------------------------------------

## The steps in the order the HUD goal leads a new player: each time the
## first step of ProgressRules.STEPS he can do, opening what he can on the
## way.
static func hud_order() -> Array[StringName]:
	var progress := FloorProgress.new()
	var order: Array[StringName] = []
	while not ProgressRules.is_complete(progress) and order.size() < 64:
		open_what_he_can(progress)
		var step := ProgressRules.next_step(progress)
		if step == &"":
			break
		ProgressRules.apply(progress, step)
		order.append(step)
	return order


## A random valid order (seeded): each time any step he can do now.
static func random_order(seed_value: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var progress := FloorProgress.new()
	var order: Array[StringName] = []
	while not ProgressRules.is_complete(progress) and order.size() < 64:
		open_what_he_can(progress)
		var steps := ProgressRules.available_steps(progress)
		if steps.is_empty():
			break
		var step := steps[rng.randi_range(0, steps.size() - 1)]
		ProgressRules.apply(progress, step)
		order.append(step)
	return order


## Opens in [param progress] every gate ProgressRules lets the guard open
## from the security booth.
static func open_what_he_can(progress: FloorProgress) -> void:
	for gate_id in ProgressRules.openable_gates(progress):
		FloorProgress.add_to(progress.gates_open, gate_id)


## True when [param order] is a full play-through by the rules: every step
## doable when it comes, the floor complete at the end.
static func is_valid(order: Array[StringName]) -> bool:
	var progress := FloorProgress.new()
	for step in order:
		open_what_he_can(progress)
		if not ProgressRules.can_do(progress, step, ProgressRules.reachable_areas(progress)):
			return false
		ProgressRules.apply(progress, step)
	return ProgressRules.is_complete(progress)


# --- step targets -------------------------------------------------------------------

## What the guard walks to for [param step] on a level with [param markers]
## (marker id -> Transform3D): {marker, at, kind, reach}. Kinds: &"use"
## (his eye within reach of the thing), &"floor" (the navmesh within reach
## of a floor marker), &"near" (the navmesh within reach).
static func step_target(step: StringName, markers: Dictionary) -> Dictionary:
	var pickup := Floor1Plan.pickup(step)
	if pickup != null:
		return _target(pickup.marker, markers, &"use", USE_REACH + PROP_SLACK)
	var guardian := Floor1Plan.guardian(step)
	if guardian != null:
		var way_in := StringName("arena_%s_start" % step)
		if markers.has(way_in):
			return _target(way_in, markers, &"floor", FLOOR_REACH)
		return _target(guardian.marker, markers, &"near", NEAR_REACH)
	match step:
		ProgressRules.TREX:
			return _target(Floor1Plan.TREX_MARKER, markers, &"near", NEAR_REACH)
		ProgressRules.DESCEND:
			return _target(Floor1Plan.EXIT_MARKER, markers, &"floor", FLOOR_REACH)
	return {}


static func _target(marker: StringName, markers: Dictionary, kind: StringName, reach: float) -> Dictionary:
	var at: Vector3 = (markers[marker] as Transform3D).origin if markers.has(marker) else Vector3.INF
	return {"marker": marker, "at": at, "kind": kind, "reach": reach}


## Seconds the step itself takes once there (a fight, taking a pickup,
## working a device).
static func step_seconds(step: StringName) -> float:
	if Floor1Plan.guardian(step) != null:
		return GUARDIAN_FIGHT
	match step:
		ProgressRules.TREX:
			return TREX_FIGHT
		&"power_north", &"astrolabe":
			return DEVICE_TIME
		ProgressRules.DESCEND:
			return 0.0
	return PICKUP_TIME


# --- rooms: looking round and fighting --------------------------------------------------

## Seconds looking round [param room] on the first visit.
static func look_seconds(room: RoomSpec) -> float:
	return minf(LOOK_BASE + room.area() * LOOK_PER_M2, LOOK_MAX)


## Seconds a first-time player fights exhibit [param kind] (its hit points
## at DPS, plus the overhead).
static func fight_seconds(kind: StringName) -> float:
	return float(KIND_HP.get(kind, DEFAULT_HP)) / DPS + FIGHT_OVERHEAD


## Room id -> {exhibits, seconds}: what the night director's draw puts in
## each room on average (every set equally likely, a set trimmed to the
## room's cap by a random subset, the ALWAYS_SET slots on top; a slot's
## kind drawn from its list) and the seconds clearing it takes.
static func room_fights(layout: LevelLayout, description: LevelDescription) -> Dictionary:
	var slots_of := {}
	for slot in layout.spawn_slots:
		if not slots_of.has(slot.room):
			slots_of[slot.room] = []
		(slots_of[slot.room] as Array).append(slot)
	var result := {}
	for room_id: StringName in slots_of:
		var sets := {}
		var always: Array = []
		for slot: SpawnSlot in slots_of[room_id]:
			if slot.set_id == SpawnSlot.ALWAYS_SET:
				always.append(slot)
			else:
				if not sets.has(slot.set_id):
					sets[slot.set_id] = []
				(sets[slot.set_id] as Array).append(slot)
		var cap := description.room_limit(room_id)
		var exhibits := 0.0
		var seconds := 0.0
		for slot: SpawnSlot in always:
			exhibits += 1.0
			seconds += _slot_seconds(slot)
		for set_id: int in sets:
			var members: Array = sets[set_id]
			var picked := float(members.size()) if cap < 0.0 else minf(float(members.size()), cap)
			var share := picked / float(members.size()) / float(sets.size())
			for slot: SpawnSlot in members:
				exhibits += share
				seconds += share * _slot_seconds(slot)
		if exhibits > 0.0:
			seconds += ROOM_CLEAR
		result[room_id] = {"exhibits": exhibits, "seconds": seconds}
	return result


static func _slot_seconds(slot: SpawnSlot) -> float:
	if slot.kinds.is_empty():
		return fight_seconds(&"wax")
	var total := 0.0
	for kind in slot.kinds:
		total += fight_seconds(kind)
	return total / float(slot.kinds.size())


# --- notes ----------------------------------------------------------------------------

## Note marker id -> words of its Polish text (title + body; an alias
## marker counts its note's words); a marker whose note has no text yet is
## left out.
static func note_words(path: String = "res://locale/strings.csv") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var texts := {}
	if file == null:
		return texts
	var header := file.get_csv_line()
	var pl := header.find("pl")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= pl or pl < 0:
			continue
		var key := row[0]
		if key.begins_with("NOTE_") and (key.ends_with("_TITLE") or key.ends_with("_BODY")):
			var id := key.trim_suffix("_TITLE").trim_suffix("_BODY").to_lower()
			texts[id] = int(texts.get(id, 0)) + _words(row[pl])
	# markers that show another note's text (Heniek's sticky note)
	for alias: StringName in WorldFeatures.NOTE_ALIASES:
		var source := String(WorldFeatures.NOTE_ALIASES[alias])
		if texts.has(source):
			texts[String(alias)] = texts[source]
	return texts


static func _words(text: String) -> int:
	var count := 0
	for part in text.replace("\n", " ").split(" ", false):
		if part.strip_edges() != "":
			count += 1
	return count


## Seconds reading a note of [param words] words.
static func read_seconds(words: int) -> float:
	return NOTE_BASE + float(words) / WORDS_PER_SECOND


# --- the timeline and the nights -------------------------------------------------------

## A first-time player's evening by evening: everything he spends time on,
## with its part of the floor, in nights of NIGHT_LENGTH seconds.
class Timeline:
	extends RefCounted
	## Night index (1-based) and seconds into it.
	var night: int = 1
	var clock: float = 0.0
	var total: float = 0.0
	## Kind -> seconds; part of the floor -> seconds; part -> kind -> seconds.
	var by_kind: Dictionary = {}
	var by_part: Dictionary = {}
	var by_part_kind: Dictionary = {}
	var metres: float = 0.0
	var metres_by_part: Dictionary = {}
	## Every entry: {night, start, seconds, kind, label, part}.
	var entries: Array[Dictionary] = []

	## Seconds left tonight.
	func left() -> float:
		return Floor1Route.NIGHT_LENGTH - clock

	## Spends [param seconds] on [param kind] in [param part] (no check of
	## the night's end: the caller decides what does not fit).
	func spend(kind: StringName, seconds: float, part: StringName, label: String = "") -> void:
		if seconds <= 0.0:
			return
		entries.append({"night": night, "start": total, "seconds": seconds, "kind": kind, "label": label, "part": part})
		clock += seconds
		total += seconds
		by_kind[kind] = float(by_kind.get(kind, 0.0)) + seconds
		by_part[part] = float(by_part.get(part, 0.0)) + seconds
		if not by_part_kind.has(part):
			by_part_kind[part] = {}
		var kinds: Dictionary = by_part_kind[part]
		kinds[kind] = float(kinds.get(kind, 0.0)) + seconds

	## Walks [param split] (part -> metres, in walking order is not needed);
	## returns the share of the walk done before dawn (1.0 = all of it).
	func walk(split: Dictionary, label: String = "") -> float:
		var length := 0.0
		for part: StringName in split:
			length += float(split[part])
		if length <= 0.0:
			return 1.0
		var seconds := length / Floor1Route.WALK_SPEED
		var share := minf(1.0, left() / seconds) if seconds > 0.0 else 1.0
		for part: StringName in split:
			var part_metres := float(split[part]) * share
			metres += part_metres
			metres_by_part[part] = float(metres_by_part.get(part, 0.0)) + part_metres
			spend(&"walk", part_metres / Floor1Route.WALK_SPEED, part, label)
		return share

	## Dawn: the next night starts at a haven.
	func next_night(part: StringName) -> void:
		night += 1
		clock = 0.0
		spend(&"night_start", Floor1Route.NIGHT_START, part, "night %d" % night)

	## Whole nights and the share of the last one.
	func nights() -> float:
		return float(night - 1) + clock / Floor1Route.NIGHT_LENGTH


## The part of the floor zone [param zone] counts for.
static func part_of(zone: StringName) -> StringName:
	return WING_OF.get(zone, &"hub")


## Every assumption of the time model (for the bot's JSON).
static func assumptions() -> Dictionary:
	return {
		"walk_speed_mps": WALK_SPEED, "look_base_s": LOOK_BASE, "look_per_m2_s": LOOK_PER_M2, "look_max_s": LOOK_MAX,
		"glance_share": GLANCE_SHARE, "dps": DPS, "fight_overhead_s": FIGHT_OVERHEAD, "room_clear_s": ROOM_CLEAR,
		"revisit_share": REVISIT_SHARE, "weakened_keep": NightDirector.WEAKENED_KEEP,
		"guardian_fight_s": GUARDIAN_FIGHT, "trex_fight_s": TREX_FIGHT,
		"note_base_s": NOTE_BASE, "words_per_s": WORDS_PER_SECOND, "secret_search_s": SECRET_SEARCH,
		"pickup_s": PICKUP_TIME, "device_s": DEVICE_TIME, "gate_s": GATE_TIME,
		"night_s": NIGHT_LENGTH, "night_start_s": NIGHT_START, "haven_first_s": HAVEN_FIRST,
		"kind_hp": KIND_HP,
	}
