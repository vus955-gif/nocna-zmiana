class_name AmbientStory
extends RefCounted
## The ambient story's scheduler (plan 2026-10-21-akustyka-ambient, backlog
## #41): pure logic over data/audio/ambient_story.json. Its owner
## (StoryLayer) tells it, every poll, where the guard is and what goes on
## (zone, the night's phase, haven, a sleeping guardian next door, a fight,
## a line of the voice, rain, power) and calls advance(); advance() returns
## a story to tell now (a dictionary of the data: sound, where, db...) or {}.
## - Pace: a story every gaps[phase] s (calm 23-1 ... predawn 5-6), the first
##   night slower (first_night_scale); each story has its cooldown and a
##   nightly limit; a story waits for its zone, phase, night, rain, power.
## - Silence (silent(): nothing of the ambience may start - the zones' far
##   sounds wait too; bed_dip_db(): how far the beds go down): a haven (only
##   haven_ok stories: the booth's radio), next to / in the arena of a
##   sleeping guardian, a hush (after an uncanny moment, a guardian's fall),
##   the voice on air and voice_after s after it, and dead air - now and then
##   from 1:00 the building holds its breath for a few seconds and the
##   silence breaks with an after_silence story (steps next door).
## - A fight holds the stories back (the zone's far sounds may go on).
## Deterministic: start_night() seeds it.

enum { CALM, UNEASY, WITCHING, PREDAWN }
## guardian: none, next to a sleeping guardian's arena, inside it.
const GUARDIAN_NONE := 0
const GUARDIAN_NEAR := 1
const GUARDIAN_ARENA := 2

const DATA_PATH := "res://data/audio/ambient_story.json"

static var _data: Dictionary = {}

var rng := RandomNumberGenerator.new()
## What the owner tells it before advance().
var zone: StringName = &""
var phase: int = CALM
var night: int = 1
var modifier: StringName = &"none"
var in_haven: bool = false
var guardian: int = GUARDIAN_NONE
var fighting: bool = false
var voice: bool = false
var raining: bool = false
## No power where the guard is (a blackout, the power cut).
var dark: bool = false

var _data_override: Dictionary = {}
var _wait: float = 30.0
var _cooldowns: Dictionary = {}
var _counts: Dictionary = {}
var _hush_left: float = 0.0
var _voice_left: float = 0.0
var _dead_air_left: float = 0.0
var _after_dead_air: bool = false


## [param data_override]: a whole data dictionary instead of the file's (tests).
func _init(data_override: Dictionary = {}) -> void:
	_data_override = data_override


## The parsed data file (read once).
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"stories": [], "gaps": [[40, 80]]}
	return _data


func _d() -> Dictionary:
	return _data_override if not _data_override.is_empty() else data()


## True when [param zone_id] is one of [param zones] or a sub-zone of one
## (egypt_tomb is in egypt); an empty list holds every zone.
static func zone_in(zone_id: StringName, zones: Array) -> bool:
	if zones.is_empty():
		return true
	var text := String(zone_id)
	for entry: Variant in zones:
		var z := String(entry)
		if text == z or text.begins_with(z + "_"):
			return true
	return false


## Does it rain tonight? (Decided by the night's number, modifier and seed:
## the same night always has the same weather.)
static func rain_tonight(night_number: int, night_modifier: StringName, night_seed: int) -> bool:
	var rain: Dictionary = data().get("rain", {})
	if night_number < int(rain.get("night_min", 2)) or (rain.get("modifiers_not", []) as Array).has(String(night_modifier)):
		return false
	var roll := RandomNumberGenerator.new()
	roll.seed = hash([night_seed, night_number, "rain"])
	return roll.randf() < float(rain.get("chance", 0.0))


## A new night: limits, cooldowns and silences start over; the first story
## comes after first_wait s.
func start_night(night_number: int, night_modifier: StringName, night_seed: int) -> void:
	night = maxi(night_number, 1)
	modifier = night_modifier if night_modifier != &"" else &"none"
	rng.seed = hash([night_seed, night, "story"])
	_cooldowns.clear()
	_counts.clear()
	_hush_left = 0.0
	_voice_left = 0.0
	_dead_air_left = 0.0
	_after_dead_air = false
	var first: Array = _d().get("first_wait", [20.0, 40.0])
	_wait = rng.randf_range(float(first[0]), float(first[1])) * _night_scale()


## Keeps the story quiet for [param seconds] (an uncanny moment, a guardian's fall).
func hush(seconds: float) -> void:
	_hush_left = maxf(_hush_left, seconds)


## True while nothing of the ambience may start (see the class notes).
func silent() -> bool:
	return in_haven or guardian != GUARDIAN_NONE or _hush_left > 0.0 or _dead_air_left > 0.0 or voice or _voice_left > 0.0


## How far the beds go down now (dB, 0 = not at all).
func bed_dip_db() -> float:
	var silence: Dictionary = _d().get("silence", {})
	var dip := 0.0
	if in_haven:
		dip = minf(dip, float(silence.get("haven_beds_db", -3.0)))
	if guardian == GUARDIAN_NEAR:
		dip = minf(dip, float(silence.get("guardian_near_beds_db", -4.0)))
	elif guardian == GUARDIAN_ARENA:
		dip = minf(dip, float(silence.get("guardian_arena_beds_db", -9.0)))
	if _dead_air_left > 0.0:
		dip = minf(dip, float(_d().get("dead_air", {}).get("beds_db", -10.0)))
	return dip


## Seconds until the next story (debug, tests).
func wait_left() -> float:
	return _wait


## The story [param id] of the data ({} when none).
func story(id: StringName) -> Dictionary:
	for entry: Dictionary in _d().get("stories", []):
		if StringName(entry.get("id", "")) == id:
			return entry
	return {}


## Moves time on by [param dt]; returns the story to tell now, or {}.
func advance(dt: float) -> Dictionary:
	for id: Variant in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - dt
	_hush_left = maxf(_hush_left - dt, 0.0)
	if voice:
		_voice_left = float(_d().get("voice_after", 2.0))
	else:
		_voice_left = maxf(_voice_left - dt, 0.0)
	if _dead_air_left > 0.0:
		_dead_air_left = maxf(_dead_air_left - dt, 0.0)
		if _dead_air_left > 0.0 or not _after_dead_air:
			return {}
		_after_dead_air = false
		var after := candidates().filter(func(entry: Dictionary) -> bool: return bool(entry.get("after_silence", false)))
		return _tell(after if not after.is_empty() else candidates())
	_wait -= dt
	if _wait > 0.0:
		return {}
	if _blocked():
		_rearm()
		return {}
	var ready := candidates()
	if ready.is_empty():
		_rearm()
		return {}
	if _dead_air_allowed(ready):
		var span: Array = _d()["dead_air"].get("seconds", [5.0, 9.0])
		_dead_air_left = rng.randf_range(float(span[0]), float(span[1]))
		_after_dead_air = true
		_wait = INF
		return {}
	return _tell(ready)


## Stories allowed here and now (zone, phase, night, cooldown, limit, rain,
## power, haven).
func candidates() -> Array:
	var found := []
	for entry: Dictionary in _d().get("stories", []):
		if allowed(entry):
			found.append(entry)
	return found


func allowed(entry: Dictionary) -> bool:
	var id := StringName(entry.get("id", ""))
	if zone == &"" or not zone_in(zone, entry.get("zones", [])):
		return false
	if entry.has("zones_not") and not (entry["zones_not"] as Array).is_empty() and zone_in(zone, entry["zones_not"]):
		return false
	var phases: Array = entry.get("phases", [CALM, PREDAWN])
	if phase < int(phases[0]) or phase > int(phases[1]):
		return false
	if night < int(entry.get("night_min", 1)) or _weight(entry) <= 0.0:
		return false
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return false
	var limit := int(entry.get("per_night", 0))
	if limit > 0 and int(_counts.get(id, 0)) >= limit:
		return false
	match String(entry.get("needs", "")):
		"rain":
			if not raining:
				return false
		"power":
			if dark:
				return false
	return not in_haven or bool(entry.get("haven_ok", false))


func _weight(entry: Dictionary) -> float:
	var by_phase: Variant = entry.get("phase_weights")
	if by_phase is Array and phase < (by_phase as Array).size():
		return float(by_phase[phase])
	return float(entry.get("weight", 1.0))


## Stories hold back: a sleeping guardian, a hush, the voice, a fight (a
## haven only narrows the choice).
func _blocked() -> bool:
	return guardian != GUARDIAN_NONE or _hush_left > 0.0 or voice or _voice_left > 0.0 or fighting


func _dead_air_allowed(ready: Array) -> bool:
	var dead: Dictionary = _d().get("dead_air", {})
	var phases: Array = dead.get("phases", [UNEASY, PREDAWN])
	if dead.is_empty() or in_haven or night < int(dead.get("night_min", 2)) or phase < int(phases[0]) or phase > int(phases[1]):
		return false
	if not ready.any(func(entry: Dictionary) -> bool: return bool(entry.get("after_silence", false))):
		return false
	return rng.randf() < float(dead.get("chance", 0.0))


func _tell(ready: Array) -> Dictionary:
	if ready.is_empty():
		_rearm()
		return {}
	var total := 0.0
	for entry: Dictionary in ready:
		total += _weight(entry)
	var roll := rng.randf() * total
	var chosen: Dictionary = ready[-1]
	for entry: Dictionary in ready:
		roll -= _weight(entry)
		if roll < 0.0:
			chosen = entry
			break
	var id := StringName(chosen.get("id", ""))
	_cooldowns[id] = float(chosen.get("cooldown", 0.0))
	_counts[id] = int(_counts.get(id, 0)) + 1
	var gaps: Array = _d().get("gaps", [[40.0, 80.0]])
	var gap: Array = gaps[clampi(phase, 0, gaps.size() - 1)]
	_wait = rng.randf_range(float(gap[0]), float(gap[1])) * _night_scale()
	return chosen


func _rearm() -> void:
	var span: Array = _d().get("rearm", [6.0, 14.0])
	_wait = rng.randf_range(float(span[0]), float(span[1]))


func _night_scale() -> float:
	return float(_d().get("first_night_scale", 1.0)) if night <= 1 else 1.0
