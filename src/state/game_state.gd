class_name PersistentState
extends Node
## Everything that survives death and quitting (autoload "GameState"):
## night number, upgrades, found weapons, key, secrets, notes, havens, the
## dropped lantern, statistics, the night in progress and Floor I's
## metroidvania progress (gates opened, guardians defeated, seals, shards,
## key items, world flags, rooms visited, chess pieces, difficulty). Saved as
## versioned JSON through SaveFile (main file, .tmp and .bak copies).
## A save is never thrown away: a broken one is moved aside as
## save.json.bad (a fresh game starts only when that worked), an unreadable
## one or one from a newer version of the game is left untouched, and a
## good .tmp or .bak copy is used when the main file is broken. Weapons are
## stored by id, never by resource path.

## Just before every write, so the game scene can put the night in
## progress (the guard's health and ammo) into [member night_progress].
signal saving
signal saved
## A write failed (the old save is still there); the HUD warns.
signal save_failed

## 1: the lobby demo. 2: Floor I (progress fields; a version-1 save is
## migrated, see _migrate()).
const VERSION := 2
const DEFAULT_HAVEN := &"security"
## Difficulty ids (design 7.5): "Spokojna zmiana", "Nocna zmiana" (the
## default), "Podwójna zmiana".
const DIFFICULTIES: Array[StringName] = [&"calm", &"night", &"double"]
const DEFAULT_DIFFICULTY := &"night"

var night: int = 1
## Drawn once per new game; the night seed mixes it with the night number.
var seed_base: int = 0
## Upgrade id -> bought level.
var upgrades: Dictionary = {}
## Weapons found so far (fists and the taser are always there).
var weapons: Array[StringName] = []
var pistol_key: bool = false
var secrets: Array[StringName] = []
var notes: Array[StringName] = []
var havens: Array[StringName] = [DEFAULT_HAVEN]
var start_haven: StringName = DEFAULT_HAVEN
## The Dust left where the guard died: {active, position: [x, y, z], dust}.
var lantern: Dictionary = {}
var stats: Dictionary = {}
var demo_complete: bool = false
## Carried Dust at the last save (restored when a night is continued).
var run_dust: int = 0
## The night in progress at the last save, so "Continue" resumes it:
## {night, killed: [spawn slot index], taken: [loot spot index],
## used: [interactable id], guard: {health, weapons: {id: {magazine,
## reserve, battery}}}}. Slot and spot indices are stable: the same night
## seed always builds the same level lists. Empty when no night is in
## progress (cleared on death); ignored when it is not for [member night].
var night_progress: Dictionary = {}
# --- Floor I progress (permanent; ProgressRules reads it via FloorProgress) ---
## GateSpec ids opened for good (chains, boards, bolts, seals, shutters...).
var gates_open: Array[StringName] = []
## Guardian ids defeated for good (Floor1Plan.GUARDIANS, and &"trex").
var guardians_defeated: Array[StringName] = []
## Seals and keys picked up (&"seal_sun", &"seal_wing", &"seal_owl",
## &"star_key").
var seals: Array[StringName] = []
## Crystal shards picked up (&"shard_egypt"...).
var shards: Array[StringName] = []
## Key items picked up for good (&"fuse_basement", &"fuse_assyria").
var items: Array[StringName] = []
## World facts that stay (&"power_north": the switchboard works;
## &"astrolabe": the shards are in; &"floor1_complete": walked down).
var flags: Array[StringName] = []
## Room ids ever visited (the paper map ticks them).
var rooms_visited: Array[StringName] = []
## Lewis chess pieces found (8 in all).
var chess_found: Array[StringName] = []
## Voice lines already heard (VoiceDirector; "once per game" and the audio
## guide's night recordings). Marked when a line ends; saved with the next save.
var voice_heard: Array[StringName] = []
## The director's counters: "destroyed" (exhibits destroyed, all nights),
## "death_turn" ("heniek"/"system": who comments the next death), "death_night",
## "death_pending" (a death the next night comments, kept with its save).
var voice_state: Dictionary = {}
var difficulty: StringName = DEFAULT_DIFFICULTY
## Secrets whose reward the guard has claimed (SecretRewards; the pouch of
## Dust taken, the bonus, finish or mod his). Missing in older saves.
var secret_rewards: Array[StringName] = []
## Uncanny moments of the museum seen once per game (UncannyDirector; plan
## 2026-10-21-eskalacja-nocy). Missing in older saves.
var uncanny_seen: Array[StringName] = []
## Save file; "" = SavePaths.save_file() (tests pass their own).
var file_path: String = ""
## Why the last load_game() failed: "" (it did not), "missing", "corrupt"
## (moved aside, fresh game), "corrupt_kept" (broken, but it could not be
## moved aside: left as it was), "unreadable" (cannot be opened: left as it
## was) or "newer" (written by a newer version: left as it was).
var last_load_error: String = ""


func _init() -> void:
	reset()


## A new game with a freshly drawn seed (not written until save_game()).
func new_game() -> void:
	reset()
	seed_base = randi() & 0x7FFFFFFF   # stays exact in JSON numbers


## Default values, nothing drawn, nothing written.
func reset() -> void:
	night = 1
	seed_base = 0
	upgrades = {}
	weapons = []
	pistol_key = false
	secrets = []
	notes = []
	havens = [DEFAULT_HAVEN]
	start_haven = DEFAULT_HAVEN
	lantern = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	stats = {"deaths": 0, "nights": 0, "dust_earned": 0, "play_time": 0.0, "bosses": 0}
	demo_complete = false
	run_dust = 0
	night_progress = {}
	gates_open = []
	guardians_defeated = []
	seals = []
	shards = []
	items = []
	flags = []
	rooms_visited = []
	chess_found = []
	voice_heard = []
	voice_state = {}
	difficulty = DEFAULT_DIFFICULTY
	secret_rewards = []
	uncanny_seen = []
	last_load_error = ""


func path() -> String:
	return file_path if file_path != "" else SavePaths.save_file()


## True when there is a save to continue or to protect from being
## overwritten: the main file (even a broken one), or a good .tmp or .bak.
func has_save() -> bool:
	var main := path()
	if FileAccess.file_exists(main):
		return true
	for backup in [main + SaveFile.TMP, main + SaveFile.BAK]:
		if _is_save(SaveFile.parse_json_file(backup)):
			return true
	return false


## Writes the save. False (and [signal save_failed]) when that failed.
func save_game() -> bool:
	saving.emit()
	var ok := SaveFile.write_json(path(), to_dict())
	if ok:
		saved.emit()
	else:
		push_warning("GameState: could not write " + path())
		save_failed.emit()
	return ok


## Loads the save: the main file, else its .tmp or .bak copy. False when
## there is nothing to load (see [member last_load_error]); only a broken
## save that was moved aside starts a fresh game, everything else keeps the
## current state and leaves the files alone.
func load_game() -> bool:
	var main := path()
	last_load_error = ""
	if FileAccess.file_exists(main) and not _readable(main):
		# maybe held by another program for a moment: it may well be newer
		# than any copy, so nothing is touched and no copy is used
		last_load_error = "unreadable"
		return false
	for candidate in SaveFile.candidates(main):
		var data: Variant = SaveFile.parse_json_file(candidate)
		if not _is_save(data):
			continue
		if int(data["version"]) > VERSION:
			last_load_error = "newer"
			return false
		if candidate != main and FileAccess.file_exists(main):
			SaveFile.quarantine(main)   # broken; the copy is good
		if candidate == main + SaveFile.TMP and not FileAccess.file_exists(main):
			SaveFile.move(candidate, main)   # stopped right before its rename
		from_dict(_migrate(data))
		return true
	if not FileAccess.file_exists(main):
		last_load_error = "missing"
	elif SaveFile.quarantine(main):
		new_game()
		last_load_error = "corrupt"
	else:
		last_load_error = "corrupt_kept"
	return false


## Seed of the current night: the same game and night always give the same.
func night_seed() -> int:
	return mix_seed(seed_base, night)


## 32-bit FNV-1a of "base/night" (does not depend on engine hashing).
static func mix_seed(base: int, night_number: int) -> int:
	var hash_value := 2166136261
	for byte in ("%d/%d" % [base, night_number]).to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF
	return hash_value


func upgrade_level(id: StringName) -> int:
	return int(upgrades.get(id, 0))


## Buys the next level of [param id] with the night's carried Dust. Refused
## (false) for an unknown or maxed upgrade or when the Dust does not cover
## the price. A purchase is saved at once (with what is left carried).
func buy_upgrade(id: StringName, run: NightState) -> bool:
	var current := upgrade_level(id)
	var cost := UpgradeCatalog.price(id, current)
	if cost < 0 or not run.spend_dust(cost):
		return false
	upgrades[id] = current + 1
	run_dust = run.dust
	save_game()
	Events.upgrade_bought.emit(id, current + 1)
	return true


func has_weapon(id: StringName) -> bool:
	return weapons.has(id)


func add_weapon(id: StringName) -> void:
	if not weapons.has(id):
		weapons.append(id)


func discover_haven(id: StringName) -> void:
	if not havens.has(id):
		havens.append(id)


# --- Floor I progress --------------------------------------------------------
# Each adder returns true when the entry is new. None of them saves: the
# caller saves at the moment the design wants (design 7.7).

func open_gate(gate_id: StringName) -> bool:
	return _add_once(gates_open, gate_id)


func is_gate_open(gate_id: StringName) -> bool:
	return gates_open.has(gate_id)


func defeat_guardian(guardian_id: StringName) -> bool:
	return _add_once(guardians_defeated, guardian_id)


func is_guardian_defeated(guardian_id: StringName) -> bool:
	return guardians_defeated.has(guardian_id)


func add_seal(seal: StringName) -> bool:
	return _add_once(seals, seal)


func add_shard(shard: StringName) -> bool:
	return _add_once(shards, shard)


func add_item(item: StringName) -> bool:
	return _add_once(items, item)


func has_item(item: StringName) -> bool:
	return items.has(item)


func set_flag(flag: StringName) -> bool:
	return _add_once(flags, flag)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


## Records a visit; true the first time ever (Events.room_entered's
## first_visit).
func visit_room(room: StringName) -> bool:
	return _add_once(rooms_visited, room)


func find_chess(piece: StringName) -> bool:
	return _add_once(chess_found, piece)


func mark_voice_heard(key: StringName) -> bool:
	return _add_once(voice_heard, key)


## The reward of secret [param secret_id] is the guard's; true the first time.
func claim_reward(secret_id: StringName) -> bool:
	return _add_once(secret_rewards, secret_id)


static func _add_once(list: Array[StringName], entry: StringName) -> bool:
	if entry == &"" or list.has(entry):
		return false
	list.append(entry)
	return true


## The uncanny moment [param id] is seen (once per game); true the first time.
func see_uncanny(id: StringName) -> bool:
	return _add_once(uncanny_seen, id)


func has_seen_uncanny(id: StringName) -> bool:
	return uncanny_seen.has(id)


## The saved progress when it belongs to the current night, else {}.
func current_progress() -> Dictionary:
	return night_progress if int(night_progress.get("night", 0)) == night else {}


func to_dict() -> Dictionary:
	var levels := {}
	for id in upgrades:
		levels[String(id)] = int(upgrades[id])
	var position: Array = lantern["position"]
	return {
		"version": VERSION,
		"night": night,
		"seed_base": seed_base,
		"upgrades": levels,
		"weapons": _strings(weapons),
		"pistol_key": pistol_key,
		"secrets": _strings(secrets),
		"notes": _strings(notes),
		"havens": _strings(havens),
		"start_haven": String(start_haven),
		"lantern": {
			"active": bool(lantern["active"]),
			"position": [float(position[0]), float(position[1]), float(position[2])],
			"dust": int(lantern["dust"]),
		},
		"stats": {
			"deaths": int(stats["deaths"]),
			"nights": int(stats["nights"]),
			"dust_earned": int(stats["dust_earned"]),
			"play_time": float(stats["play_time"]),
			"bosses": int(stats["bosses"]),
		},
		"demo_complete": demo_complete,
		"run_dust": run_dust,
		"night_progress": clean_progress(night_progress, night),
		"gates_open": _strings(gates_open),
		"guardians_defeated": _strings(guardians_defeated),
		"seals": _strings(seals),
		"shards": _strings(shards),
		"items": _strings(items),
		"flags": _strings(flags),
		"rooms_visited": _strings(rooms_visited),
		"chess_found": _strings(chess_found),
		"voice_heard": _strings(voice_heard),
		"voice_state": voice_state.duplicate(),
		"difficulty": String(difficulty),
		"secret_rewards": _strings(secret_rewards),
		"uncanny_seen": _strings(uncanny_seen),
	}


## Takes every field it understands from [param data]; missing fields and
## fields of the wrong type keep their defaults.
func from_dict(data: Dictionary) -> void:
	reset()
	night = maxi(_int(data.get("night"), 1), 1)
	seed_base = maxi(_int(data.get("seed_base"), 0), 0)
	var levels: Variant = data.get("upgrades")
	if levels is Dictionary:
		for id in levels:
			var key := StringName(str(id))
			var level := mini(_int(levels[id], 0), UpgradeCatalog.max_level(key))
			if level > 0:
				upgrades[key] = level
	weapons = _names(data.get("weapons"))
	pistol_key = _bool(data.get("pistol_key"), false)
	secrets = _names(data.get("secrets"))
	notes = _names(data.get("notes"))
	havens = _names(data.get("havens"))
	if not havens.has(DEFAULT_HAVEN):
		havens.insert(0, DEFAULT_HAVEN)
	var start: Variant = data.get("start_haven")
	if (start is String or start is StringName) and havens.has(StringName(start)):
		start_haven = StringName(start)
	var drop: Variant = data.get("lantern")
	if drop is Dictionary:
		var at: Variant = drop.get("position")
		if at is Array and at.size() == 3 and _all_numbers(at):
			lantern["position"] = [float(at[0]), float(at[1]), float(at[2])]
		lantern["dust"] = maxi(_int(drop.get("dust"), 0), 0)
		lantern["active"] = _bool(drop.get("active"), false) and lantern["dust"] > 0
	var numbers: Variant = data.get("stats")
	if numbers is Dictionary:
		for key in ["deaths", "nights", "dust_earned", "bosses"]:
			stats[key] = maxi(_int(numbers.get(key), 0), 0)
		stats["play_time"] = maxf(_float(numbers.get("play_time"), 0.0), 0.0)
	demo_complete = _bool(data.get("demo_complete"), false)
	run_dust = maxi(_int(data.get("run_dust"), 0), 0)
	night_progress = clean_progress(data.get("night_progress"), night)
	gates_open = _names(data.get("gates_open"))
	guardians_defeated = _names(data.get("guardians_defeated"))
	seals = _names(data.get("seals"))
	shards = _names(data.get("shards"))
	items = _names(data.get("items"))
	flags = _names(data.get("flags"))
	rooms_visited = _names(data.get("rooms_visited"))
	chess_found = _names(data.get("chess_found"))
	voice_heard = _names(data.get("voice_heard"))
	voice_state = _voice_state(data.get("voice_state"))
	var level: Variant = data.get("difficulty")
	if (level is String or level is StringName) and DIFFICULTIES.has(StringName(level)):
		difficulty = StringName(level)
	secret_rewards = _names(data.get("secret_rewards"))
	uncanny_seen = _names(data.get("uncanny_seen"))


## [param progress] with only well-formed entries, or {} when it is not a
## progress of [param for_night].
static func clean_progress(progress: Variant, for_night: int) -> Dictionary:
	if not progress is Dictionary or _int(progress.get("night"), 0) != for_night:
		return {}
	var clean := {
		"night": for_night,
		"killed": _indices(progress.get("killed")),
		"taken": _indices(progress.get("taken")),
		"used": _strings(_names(progress.get("used"))),
	}
	var guard: Variant = progress.get("guard")
	if guard is Dictionary:
		var kept := {}
		var health := _float(guard.get("health"), 0.0)
		if health > 0.0:
			kept["health"] = health
		var arms: Variant = guard.get("weapons")
		if arms is Dictionary:
			var kept_arms := {}
			for id in arms:
				var entry: Variant = arms[id]
				if (id is String or id is StringName) and entry is Dictionary:
					kept_arms[String(id)] = {
						"magazine": maxi(_int(entry.get("magazine"), 0), 0),
						"reserve": maxi(_int(entry.get("reserve"), 0), 0),
						"battery": maxf(_float(entry.get("battery"), 0.0), 0.0),
					}
			kept["weapons"] = kept_arms
		var tired: Variant = guard.get("fatigue")
		if tired is Dictionary:
			# the guard's fatigue and caffeine (Fatigue.to_dict); Fatigue.from_dict clamps
			kept["fatigue"] = {
				"level": clampf(_float(tired.get("level"), 0.0), 0.0, 1.0),
				"buff": str(tired.get("buff", "")),
				"buff_left": maxf(_float(tired.get("buff_left"), 0.0), 0.0),
				"jitter_left": maxf(_float(tired.get("jitter_left"), 0.0), 0.0),
			}
		clean["guard"] = kept
	var motes := _motes(progress.get("dust"))
	if not motes.is_empty():
		clean["dust"] = motes
	return clean


## The lying Dust of a saved night: [[x, y, z, value], ...] - finite
## places, values 1..MOTE_MOST, at most DustDropper.SAVED_MOTES; anything
## else left out.
static func _motes(value: Variant) -> Array:
	var out: Array = []
	if not value is Array:
		return out
	for entry: Variant in value:
		if not entry is Array or (entry as Array).size() != 4 or not _all_numbers(entry):
			continue
		var worth := _int(entry[3], 0)
		if worth < 1 or worth > MOTE_MOST:
			continue
		out.append([float(entry[0]), float(entry[1]), float(entry[2]), worth])
		if out.size() >= DustDropper.SAVED_MOTES:
			break
	return out


## A saved mote is worth at most this much Dust.
const MOTE_MOST := 10000


## True when the save file can be opened (a test double pretends it cannot).
func _readable(file: String) -> bool:
	return SaveFile.readable(file)


## Upgrades an older save's data to the current VERSION.
static func _migrate(data: Dictionary) -> Dictionary:
	var migrated := data
	if _int(migrated.get("version"), 1) < 2:
		migrated = _migrate_lobby(migrated)
	return migrated


## Version 1 (the lobby demo) -> 2 (Floor I): the guard keeps what he owns
## (weapons, upgrades, the gun locker key, statistics, the seed) and his
## Dust (a lantern left in the lobby is handed back as carried Dust: its
## place does not exist on the new floor). What only meant something in
## the lobby starts over: the night count (the first night on the new
## floor is the gentle one), secrets, notes, havens and the start haven,
## the night in progress and the lobby's ending.
static func _migrate_lobby(old: Dictionary) -> Dictionary:
	var data := old.duplicate(true)
	data["version"] = 2
	data["night"] = 1
	data["secrets"] = []
	data["notes"] = []
	data["havens"] = [String(DEFAULT_HAVEN)]
	data["start_haven"] = String(DEFAULT_HAVEN)
	data["night_progress"] = {}
	data["demo_complete"] = false
	var dust := maxi(_int(data.get("run_dust"), 0), 0)
	var drop: Variant = data.get("lantern")
	if drop is Dictionary and _bool(drop.get("active"), false):
		dust += maxi(_int(drop.get("dust"), 0), 0)
	data["run_dust"] = dust
	data["lantern"] = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	return data


static func _is_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var version: Variant = data.get("version")
	return (version is int or (version is float and is_finite(version))) and int(version) >= 1


static func _int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return roundi(value)
	return fallback


static func _float(value: Variant, fallback: float) -> float:
	if (value is float and is_finite(value)) or value is int:
		return float(value)
	return fallback


static func _bool(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback


static func _all_numbers(values: Array) -> bool:
	for value in values:
		if not (value is int or (value is float and is_finite(value))):
			return false
	return true


## Only the known voice counters, with their types (JSON brings numbers back as floats).
static func _voice_state(value: Variant) -> Dictionary:
	var out := {}
	if not value is Dictionary:
		return out
	for key in ["destroyed", "death_night"]:
		if value.has(key) and (value[key] is int or value[key] is float):
			out[key] = int(value[key])
	if value.get("death_turn") in ["heniek", "system"]:
		out["death_turn"] = String(value.death_turn)
	if value.get("death_pending") == true:
		out["death_pending"] = true
	return out


static func _names(value: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if value is Array:
		for item in value:
			if (item is String or item is StringName) and not names.has(StringName(item)):
				names.append(StringName(item))
	return names


## Distinct non-negative whole numbers of [param value], ascending.
static func _indices(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			var index := _int(item, -1)
			if index >= 0 and not out.has(index):
				out.append(index)
	out.sort()
	return out


static func _strings(names: Array[StringName]) -> Array:
	var out: Array = []
	for entry in names:
		out.append(String(entry))
	return out
