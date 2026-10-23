class_name UncannyCatalog
extends RefCounted
## The museum's uncanny events as data (data/night/uncanny.json; plan
## 2026-10-21-eskalacja-nocy, 3): hand-designed, each with its trigger,
## conditions, place, effect and rarity. Fields (all but id, trigger and
## effect optional):
## - trigger: "ambient" (the night's curve picks it: weights per phase),
##   "enter" (the guard walks into one of its rooms / zones), "return" (a
##   room the guard left changes behind his back after "away" seconds),
##   "night" (a room visited on an earlier night has changed by nightfall),
## - effect: what happens (EFFECTS); mode: the lamps' mode (RoomLamps.MODES);
##   lamps: a lamps' mode played in the room as well,
## - where: "here" (the guard's room) or "near" (a room next to it),
## - rooms, zones: where it may happen; marker: the point of its sound,
## - weights: four numbers, its weight in each phase of the night
##   (NightEscalation: calm, uneasy, witching, predawn; 0 = not then) -
##   ambient only; phases: [first, last] phase for the others,
## - night_min / night_max (0: no last night), modifiers_not,
## - limit: times a night (default 1, 0 = any number, kept with no save),
##   once_per_game, chance (0..1 per opportunity),
## - duration, delay (s after the guard walked in), away (s gone before a
##   room changes),
## - sound, volume (dB), pitch, noise (m the exhibits hear something fall),
## - text: a rare thought of the guard (a translation key; shown once per
##   game), quiet_voice: only while the voice is free (nothing on air or
##   waiting, the quiet after the last line over: VoiceDirector.is_free) -
##   for the events that bring a voice line of their own,
## - ambush, guardian, boss: tied to a real threat still to come (an ambush
##   waiting tonight, a wing guardian not beaten, the T-Rex),
## - kit, all (every fair piece of the kit, not one), kinds (exhibit kinds),
##   min_lamps, needs_emergency,
## - voice: the voice line that goes with it (data/voice/lines.json; the ones
##   the event itself brings are rules on Events.uncanny_event with this id as
##   "kind"); g3: a line still to record; note: what the player sees (for the
##   designer),
## - piece: the set-piece an effect "set_piece" plays (SET_PIECES; plan
##   2026-10-22-set-piece),
## - enabled: false leaves the whole event out, as if it were not in the
##   file (the owner's switch for a moment of taste).

const PATH := "res://data/night/uncanny.json"
const TRIGGERS: Array[StringName] = [&"ambient", &"enter", &"return", &"night"]
const EFFECTS: Array[StringName] = [&"lamps", &"sound", &"door_slam", &"pa_click", &"radio", &"gaze", &"clocks",
		&"tomb", &"glint", &"dust", &"hide", &"turn", &"sitter", &"look", &"sleeper", &"dark", &"set_piece"]
## The set-pieces an "enter" event may play (effect "set_piece", field piece).
const SET_PIECES: Array[StringName] = [&"court_game"]
## Effects that change the world for the rest of the night (return / night).
const CHANGES: Array[StringName] = [&"hide", &"turn", &"sitter", &"look", &"sleeper", &"dark"]
const WHERE: Array[StringName] = [&"here", &"near"]
## Field -> its JSON type (TYPE_FLOAT for numbers: JSON brings them as floats).
const FIELDS := {
	"id": TYPE_STRING, "trigger": TYPE_STRING, "effect": TYPE_STRING, "mode": TYPE_STRING, "lamps": TYPE_STRING,
	"where": TYPE_STRING, "rooms": TYPE_ARRAY, "zones": TYPE_ARRAY, "marker": TYPE_STRING, "weights": TYPE_ARRAY,
	"phases": TYPE_ARRAY, "night_min": TYPE_FLOAT, "night_max": TYPE_FLOAT, "modifiers_not": TYPE_ARRAY,
	"limit": TYPE_FLOAT, "once_per_game": TYPE_BOOL, "chance": TYPE_FLOAT, "duration": TYPE_FLOAT, "delay": TYPE_FLOAT,
	"away": TYPE_FLOAT, "sound": TYPE_STRING, "volume": TYPE_FLOAT, "pitch": TYPE_FLOAT, "noise": TYPE_FLOAT,
	"text": TYPE_STRING, "quiet_voice": TYPE_BOOL, "ambush": TYPE_STRING, "guardian": TYPE_STRING, "boss": TYPE_BOOL,
	"kit": TYPE_STRING, "all": TYPE_BOOL, "kinds": TYPE_ARRAY, "min_lamps": TYPE_FLOAT, "needs_emergency": TYPE_BOOL,
	"voice": TYPE_STRING, "g3": TYPE_STRING, "note": TYPE_STRING, "piece": TYPE_STRING, "enabled": TYPE_BOOL,
}

## Event dictionaries in file order (the order is the priority of the
## "enter" events: the first that fits a room wins).
var events: Array[Dictionary] = []
var _by_id: Dictionary = {}


static func load_default() -> UncannyCatalog:
	return from_data(JSON.parse_string(FileAccess.get_file_as_string(PATH)))


## A catalog of [param data] ({"events": [...]}); events with problems
## (problems_of) or switched off ("enabled": false) are left out.
static func from_data(data: Variant) -> UncannyCatalog:
	var catalog := UncannyCatalog.new()
	if not data is Dictionary or not (data as Dictionary).get("events") is Array:
		return catalog
	for entry: Variant in data["events"]:
		if entry is Dictionary and not switched_off(entry) and problems_of(entry).is_empty() and not catalog._by_id.has(String(entry["id"])):
			catalog.events.append(entry)
			catalog._by_id[String(entry["id"])] = entry
	return catalog


## What is wrong with one event's fields ([] when nothing).
static func problems_of(entry: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for field in ["id", "trigger", "effect"]:
		if not entry.has(field):
			out.append("no %s" % field)
	for field: Variant in entry:
		if not FIELDS.has(field):
			out.append("unknown field %s" % field)
		elif typeof(entry[field]) != FIELDS[field] and not (FIELDS[field] == TYPE_FLOAT and entry[field] is int):
			out.append("%s is not a %s" % [field, type_string(FIELDS[field])])
	if not out.is_empty():
		return out
	if not TRIGGERS.has(StringName(entry["trigger"])):
		out.append("unknown trigger %s" % entry["trigger"])
	if not EFFECTS.has(StringName(entry["effect"])):
		out.append("unknown effect %s" % entry["effect"])
	if entry.has("mode") and not RoomLamps.MODES.has(StringName(entry["mode"])):
		out.append("unknown lamps' mode %s" % entry["mode"])
	if entry.has("lamps") and not RoomLamps.MODES.has(StringName(entry["lamps"])):
		out.append("unknown lamps' mode %s" % entry["lamps"])
	if StringName(entry["effect"]) == &"lamps" and not entry.has("mode"):
		out.append("lamps without a mode")
	if entry.has("where") and not WHERE.has(StringName(entry["where"])):
		out.append("unknown where %s" % entry["where"])
	if entry["trigger"] == "ambient":
		var weights: Variant = entry.get("weights")
		if not weights is Array or (weights as Array).size() != NightEscalation.PHASES.size() or not (weights as Array).all(func(w: Variant) -> bool: return (w is float or w is int) and w >= 0.0):
			out.append("an ambient event needs %d weights" % NightEscalation.PHASES.size())
	elif entry.has("weights"):
		out.append("weights are for ambient events")
	if entry.has("phases"):
		var phases: Array = entry["phases"]
		if phases.size() != 2 or not phases.all(func(p: Variant) -> bool: return (p is float or p is int) and p >= 0.0 and p < NightEscalation.PHASES.size()) or float(phases[0]) > float(phases[1]):
			out.append("phases must be [first, last]")
	var change := CHANGES.has(StringName(entry["effect"]))
	var later: bool = entry["trigger"] == "return" or entry["trigger"] == "night"
	if change != later:
		out.append("a change of the world comes back with the guard (return / night), nothing else does")
	if entry.has("chance") and (float(entry["chance"]) <= 0.0 or float(entry["chance"]) > 1.0):
		out.append("chance out of (0, 1]")
	if StringName(entry["effect"]) == &"set_piece":
		if entry["trigger"] != "enter":
			out.append("a set-piece starts when the guard walks in")
		if not SET_PIECES.has(StringName(entry.get("piece", ""))):
			out.append("unknown set-piece %s" % entry.get("piece", ""))
	elif entry.has("piece"):
		out.append("piece is for set-pieces")
	return out


## True when [param entry] is switched off ("enabled": false).
static func switched_off(entry: Dictionary) -> bool:
	return entry.get("enabled", true) is bool and not bool(entry.get("enabled", true))


func event(id: StringName) -> Dictionary:
	return _by_id.get(String(id), {})


func has(id: StringName) -> bool:
	return _by_id.has(String(id))


## The events of [param trigger], in file order.
func by_trigger(trigger: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in events:
		if StringName(entry["trigger"]) == trigger:
			found.append(entry)
	return found


# --- fields with their defaults ---------------------------------------------------------

static func id_of(entry: Dictionary) -> StringName:
	return StringName(entry.get("id", ""))


static func limit_of(entry: Dictionary) -> int:
	return int(entry.get("limit", 1.0))


static func names(entry: Dictionary, field: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Variant in entry.get(field, []):
		out.append(StringName(str(item)))
	return out
