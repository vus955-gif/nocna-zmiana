class_name ScenarioCatalog
extends RefCounted
## The rooms' fight scenarios as data (data/encounters/scenarios.json; plan
## 2026-10-22-projekt-starc, backlog #20): a room is a small scenario of
## beats - the guard's entry, first contact, a change, a flank, a new
## kind, the room's architecture - played by the exhibits the night drew
## there (ScenarioCast), never by exhibits of its own. Fields of a scenario:
## - id, on (false: switched off; or its id in the file's "off" list),
## - rooms: the rooms whose drawn exhibits are its cast,
## - absorbs: ambush ids it takes over (their sleepers join its beats),
## - from_night (default 1),
## - start: [x0, z0, x1, z1] (the floor where it begins) and start_y
##   [min, max]; none = anywhere in its rooms,
## - entry: [x, y, z], the way in ("near" / "far" picks measure from it),
## - points: name -> [x, y, z, yaw], where an exhibit waits for its beat,
## - beats: in order. A beat's cast: roles (EnemyRoles.Role names in lower
##   case; none = any), kinds, room (only slots of that room), ambush (only
##   that absorbed ambush's sleepers), count (1..MAX_COUNT), pick ("near",
##   "far" from the entry, "seed": the night's order), fallback (anyone
##   left when no exhibit fits). Its trigger, the first that holds: after
##   (s since the beat before - every beat after the first needs it, a
##   pickup beat too: the guard may never take the item; an item he owns
##   already lies nowhere and counts as taken), down (that many of the earlier beats' cast fell), area
##   ([x0, z0, x1, z1] + area_y), pickup (a marker's item taken). What it
##   does: from (the point its cast waits at all night; also_from: other
##   points - when the scenario begins, the cast moves unseen to whichever
##   lies farthest from the guard, so a flank never waits by the door he
##   came in through), cue (a sound of
##   Sfx.SOUNDS and dust at its cast), lead (s from the cue to the wake,
##   at least MIN_LEAD), ring (a TempleBell's device id: the bell tolls on
##   its own).

const PATH := "res://data/encounters/scenarios.json"
const MIN_LEAD := 0.6
const MAX_COUNT := 3
## A waiting point keeps this far (m) from the dressing's solid pieces.
const CLEARANCE := 0.6
const PICKS: Array[StringName] = [&"seed", &"near", &"far"]
## Role names in the data -> EnemyRoles.Role.
const ROLES := {
	"melee_pressure": EnemyRoles.Role.MELEE_PRESSURE, "tank": EnemyRoles.Role.TANK, "flanker": EnemyRoles.Role.FLANKER,
	"ranged": EnemyRoles.Role.RANGED, "support": EnemyRoles.Role.SUPPORT, "swarm": EnemyRoles.Role.SWARM,
	"turret": EnemyRoles.Role.TURRET,
}
const SCENARIO_FIELDS := {
	"id": TYPE_STRING, "on": TYPE_BOOL, "rooms": TYPE_ARRAY, "absorbs": TYPE_ARRAY, "from_night": TYPE_FLOAT,
	"start": TYPE_ARRAY, "start_y": TYPE_ARRAY, "entry": TYPE_ARRAY, "points": TYPE_DICTIONARY, "beats": TYPE_ARRAY,
	"note": TYPE_STRING,
}
const BEAT_FIELDS := {
	"id": TYPE_STRING, "roles": TYPE_ARRAY, "kinds": TYPE_ARRAY, "room": TYPE_STRING, "ambush": TYPE_STRING,
	"count": TYPE_FLOAT, "pick": TYPE_STRING, "fallback": TYPE_BOOL, "after": TYPE_FLOAT, "down": TYPE_FLOAT,
	"area": TYPE_ARRAY, "area_y": TYPE_ARRAY, "pickup": TYPE_STRING, "from": TYPE_STRING, "also_from": TYPE_ARRAY, "cue": TYPE_STRING,
	"lead": TYPE_FLOAT, "ring": TYPE_STRING, "note": TYPE_STRING,
}

## The catalog the game uses (null: the file's); tests set one of their
## own with use() and put the file's back with use(null).
static var _active: ScenarioCatalog = null
static var _file: ScenarioCatalog = null

## Scenarios in file order (normalised: see _scenario()).
var scenarios: Array[Dictionary] = []
## Ids switched off by the file's "off" list.
var off: Array[StringName] = []
## What the file got wrong (the game leaves such entries out).
var errors: PackedStringArray = []


static func active() -> ScenarioCatalog:
	if _active != null:
		return _active
	if _file == null:
		_file = load_default()
	return _file


static func use(catalog: ScenarioCatalog) -> void:
	_active = catalog


static func load_default() -> ScenarioCatalog:
	if not FileAccess.file_exists(PATH):
		return ScenarioCatalog.new()
	return from_data(JSON.parse_string(FileAccess.get_file_as_string(PATH)))


static func from_data(data: Variant) -> ScenarioCatalog:
	var catalog := ScenarioCatalog.new()
	if not data is Dictionary:
		catalog.errors.append("the file is not an object")
		return catalog
	for id: Variant in (data as Dictionary).get("off", []):
		catalog.off.append(StringName(str(id)))
	for raw: Variant in (data as Dictionary).get("scenarios", []):
		var scenario := catalog._scenario(raw)
		if not scenario.is_empty():
			catalog.scenarios.append(scenario)
	return catalog


## The scenarios playing (on and not in "off").
func enabled() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for scenario in scenarios:
		if scenario["on"] and not off.has(scenario["id"]):
			found.append(scenario)
	return found


func find(id: StringName) -> Dictionary:
	for scenario in scenarios:
		if scenario["id"] == id:
			return scenario
	return {}


## A copy with [param id] switched off (one data entry: its id in "off").
func without(id: StringName) -> ScenarioCatalog:
	var copy := ScenarioCatalog.new()
	copy.scenarios = scenarios.duplicate()
	copy.off = off.duplicate()
	copy.off.append(id)
	return copy


## What does not fit [param layout] (rooms, ambushes, points, devices):
## empty when every scenario can play there.
func problems(layout: LevelLayout, arenas: Array[StringName] = []) -> PackedStringArray:
	var found := errors.duplicate()
	var ambushes := {}
	for ambush in layout.ambushes:
		ambushes[ambush.id] = ambush
	var taken := {}
	for scenario in scenarios:
		var id: StringName = scenario["id"]
		var rooms: Array[StringName] = scenario["rooms"]
		var near := ScenarioCatalog.neighbourhood(layout, rooms)
		for room_id in rooms:
			var room := layout.room(room_id)
			if room == null:
				found.append("%s: no room %s" % [id, room_id])
			elif room.haven or room.secret or arenas.has(room_id):
				found.append("%s: %s is a haven, a secret or an arena" % [id, room_id])
			if taken.has(room_id):
				found.append("%s: %s already plays %s" % [id, room_id, taken[room_id]])
			taken[room_id] = id
		for ambush_id: StringName in scenario["absorbs"]:
			if not ambushes.has(ambush_id):
				found.append("%s: no ambush %s" % [id, ambush_id])
			elif not rooms.has((ambushes[ambush_id] as AmbushSpec).room):
				found.append("%s: ambush %s lies outside its rooms" % [id, ambush_id])
			elif not (scenario["beats"] as Array).any(func(b: Dictionary) -> bool: return b["ambush"] == ambush_id):
				found.append("%s: no beat plays ambush %s" % [id, ambush_id])
		for point_name: StringName in scenario["points"]:
			var at: Vector3 = (scenario["points"][point_name] as Array)[0]
			var room_there := layout.room_at(at + Vector3.UP * 0.5)
			if not near.has(room_there):
				found.append("%s: point %s lies in %s, not in or next to its rooms" % [id, point_name, room_there])
			var blocking := ScenarioCatalog.blocker(layout, at)
			if blocking != null:
				found.append("%s: point %s stands in a %s" % [id, point_name, blocking.kit])
		var beats: Array = scenario["beats"]
		for b in beats.size():
			var beat: Dictionary = beats[b]
			var where := "%s/%s" % [id, beat["id"]]
			if b > 0 and beat["after"] < 0.0:
				found.append("%s: a beat after the first needs 'after' (a pickup too: the guard may never take it)" % where)
			for point_name: StringName in [beat["from"]] + (beat["also_from"] as Array):
				if point_name != &"" and not (scenario["points"] as Dictionary).has(point_name):
					found.append("%s: no point %s" % [where, point_name])
			if beat["from"] == &"" and not (beat["also_from"] as Array).is_empty():
				found.append("%s: 'also_from' without 'from'" % where)
			if beat["ambush"] != &"" and not (scenario["absorbs"] as Array).has(beat["ambush"]):
				found.append("%s: ambush %s is not absorbed" % [where, beat["ambush"]])
			if beat["room"] != &"" and not rooms.has(beat["room"]):
				found.append("%s: room %s is not one of its rooms" % [where, beat["room"]])
			if beat["cue"] != &"" and not Sfx.SOUNDS.has(beat["cue"]):
				found.append("%s: no sound %s" % [where, beat["cue"]])
			if beat["ring"] != &"" and not TempleBell.PLACES.any(func(p: Dictionary) -> bool: return p["id"] == beat["ring"]):
				found.append("%s: no bell %s" % [where, beat["ring"]])
			for kind: StringName in beat["kinds"]:
				if not NightSpawner.builds(kind):
					found.append("%s: no kind %s" % [where, kind])
	return found


## A solid piece of the floor's dressing an exhibit standing at
## [param at] would stand in (within CLEARANCE of its footprint, at its
## height), or null.
static func blocker(layout: LevelLayout, at: Vector3) -> PieceSpec:
	for piece in layout.pieces:
		if not piece.collide or piece.position.y > at.y + 2.0 or piece.position.y + piece.size.y < at.y + 0.1:
			continue
		var local := (at - piece.position).rotated(Vector3.UP, -piece.yaw)
		if absf(local.x) < piece.size.x * 0.5 + CLEARANCE and absf(local.z) < piece.size.z * 0.5 + CLEARANCE:
			return piece
	return null


## [param rooms] and every room next door (an opening between).
static func neighbourhood(layout: LevelLayout, rooms: Array[StringName]) -> Array[StringName]:
	var near: Array[StringName] = rooms.duplicate()
	for opening in layout.openings:
		if rooms.has(opening.room_a) and not near.has(opening.room_b):
			near.append(opening.room_b)
		elif rooms.has(opening.room_b) and not near.has(opening.room_a):
			near.append(opening.room_a)
	return near


# --- reading the file ----------------------------------------------------------------

func _scenario(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		errors.append("a scenario is not an object")
		return {}
	var data: Dictionary = raw
	var id := StringName(str(data.get("id", "")))
	if id == &"" or not _types(data, SCENARIO_FIELDS, String(id)):
		if id == &"":
			errors.append("a scenario without an id")
		return {}
	if not find(id).is_empty():
		errors.append("%s: the id comes twice" % id)
		return {}
	var points := {}
	for point_name: Variant in data.get("points", {}):
		var p: Array = data["points"][point_name]
		if p.size() < 3:
			errors.append("%s: point %s needs x, y, z" % [id, point_name])
			return {}
		points[StringName(str(point_name))] = [Vector3(float(p[0]), float(p[1]), float(p[2])), float(p[3]) if p.size() > 3 else 0.0]
	var scenario := {
		"id": id,
		"on": bool(data.get("on", true)),
		"rooms": _names(data.get("rooms", [])),
		"absorbs": _names(data.get("absorbs", [])),
		"from_night": int(data.get("from_night", 1)),
		"start": _rect(data.get("start", [])),
		"start_y": _span(data.get("start_y", [])),
		"entry": _point(data.get("entry", [])),
		"points": points,
		"beats": [],
	}
	if (scenario["rooms"] as Array).is_empty():
		errors.append("%s: no rooms" % id)
		return {}
	var beats: Array = data.get("beats", [])
	if beats.is_empty():
		errors.append("%s: no beats" % id)
		return {}
	for raw_beat: Variant in beats:
		var beat := _beat(raw_beat, id)
		if beat.is_empty():
			return {}
		(scenario["beats"] as Array).append(beat)
	return scenario


func _beat(raw: Variant, scenario_id: StringName) -> Dictionary:
	if not raw is Dictionary:
		errors.append("%s: a beat is not an object" % scenario_id)
		return {}
	var data: Dictionary = raw
	var where := "%s/%s" % [scenario_id, data.get("id", "?")]
	if not data.has("id") or not _types(data, BEAT_FIELDS, where):
		if not data.has("id"):
			errors.append("%s: a beat without an id" % scenario_id)
		return {}
	var roles: Array[int] = []
	for role_name: Variant in data.get("roles", []):
		if str(role_name) == "any":
			continue
		if not ROLES.has(str(role_name)):
			errors.append("%s: no role %s" % [where, role_name])
			return {}
		roles.append(int(ROLES[str(role_name)]))
	var count := int(data.get("count", 1))
	var lead := float(data.get("lead", MIN_LEAD))
	var pick := StringName(str(data.get("pick", "seed")))
	if count < 1 or count > MAX_COUNT:
		errors.append("%s: count %d is not 1..%d" % [where, count, MAX_COUNT])
		return {}
	if lead < MIN_LEAD:
		errors.append("%s: lead %.2f s is under %.1f s" % [where, lead, MIN_LEAD])
		return {}
	if not PICKS.has(pick):
		errors.append("%s: no pick %s" % [where, pick])
		return {}
	return {
		"id": StringName(str(data["id"])),
		"roles": roles,
		"kinds": _names(data.get("kinds", [])),
		"room": StringName(str(data.get("room", ""))),
		"ambush": StringName(str(data.get("ambush", ""))),
		"count": count,
		"pick": pick,
		"fallback": bool(data.get("fallback", false)),
		"after": float(data.get("after", -1.0)),
		"down": int(data.get("down", -1)),
		"area": _rect(data.get("area", [])),
		"area_y": _span(data.get("area_y", [])),
		"pickup": StringName(str(data.get("pickup", ""))),
		"from": StringName(str(data.get("from", ""))),
		"also_from": _names(data.get("also_from", [])),
		"cue": StringName(str(data.get("cue", ""))),
		"lead": lead,
		"ring": StringName(str(data.get("ring", ""))),
	}


func _types(data: Dictionary, fields: Dictionary, where: String) -> bool:
	for key: Variant in data:
		if not fields.has(key):
			errors.append("%s: unknown field %s" % [where, key])
			return false
		var type := typeof(data[key])
		if type != fields[key] and not (type == TYPE_INT and fields[key] == TYPE_FLOAT):
			errors.append("%s: field %s has the wrong type" % [where, key])
			return false
	return true


static func _names(raw: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	for item: Variant in raw:
		names.append(StringName(str(item)))
	return names


## [x0, z0, x1, z1] -> Rect2 on the floor plan (an empty one for none).
static func _rect(raw: Variant) -> Rect2:
	var values: Array = raw
	if values.size() < 4:
		return Rect2()
	var a := Vector2(float(values[0]), float(values[1]))
	var b := Vector2(float(values[2]), float(values[3]))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


static func _span(raw: Variant) -> Vector2:
	var values: Array = raw
	if values.size() < 2:
		return Vector2(-INF, INF)
	return Vector2(float(values[0]), float(values[1]))


static func _point(raw: Variant) -> Vector3:
	var values: Array = raw
	if values.size() < 3:
		return Vector3.INF
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


## True when [param point] lies on [param rect] between the heights of
## [param span] (an empty rect holds nothing).
static func holds(rect: Rect2, span: Vector2, point: Vector3) -> bool:
	if rect.size == Vector2.ZERO or point.y < span.x or point.y > span.y:
		return false
	return rect.has_point(Vector2(point.x, point.z))
