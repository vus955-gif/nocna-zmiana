class_name UncannyRules
extends RefCounted
## The uncanny events' rules, pure (plan 2026-10-21-eskalacja-nocy, 2):
## when an event fits (the night's phase, the night, its modifier, how often
## it came tonight or ever), weighted picks, the save entries in
## RunState.used, and what a change of the world may touch - fairly (2.4):
## - never a room to fight or rest in (havens, rooms of an arena or a wing
##   guardian: their markers say so - the court is the T-Rex's),
## - never a piece with a marker (an item, a note, a secret, a camera...),
##   a loot spot or an exhibit's post on it or near it, nor one the guard
##   could climb to reach a marker above it,
## - only pieces made to be moved: HIDE_KITS hide, TURN_KITS turn (by half
##   a turn or quarters on a square base: the footprint stays the same).

## Kits a change may hide / turn.
const HIDE_KITS: Array[StringName] = [&"sculpture"]
const TURN_KITS: Array[StringName] = [&"sculpture", &"bust_plinth", &"bench"]
## Nothing of the game within this far of a changed piece's footprint (m).
const MARGIN := 1.0
## A marker higher than a piece's top within this far of it could be
## reached by climbing it (m): such a piece stays.
const CLIMB_REACH := 3.0
## Markers that make their room a place to fight in.
const ARENA_PREFIXES: Array[String] = ["arena_", "guardian_"]
## Wings whose lamps are a mechanic of their own (the Americas' fire bowls
## say what the guard and the totems see): a night never leaves their rooms
## dark for good.
const BIOME_LIT_ZONES: Array[StringName] = [&"americas"]
## Floors more than this apart (m) make a step, a flight of stairs or a fall.
const STEP := 0.5
const PORTRAIT_PREFIX := "portrait_"
const LOUDSPEAKER_PREFIX := "loudspeaker_"
## RunState.used entries: an event fired tonight ("unc_<id>_<n>"), a change
## of the world tonight ("chg_<id>@<target>"), the night's changes drawn.
const FIRED_PREFIX := "unc_"
const CHANGE_PREFIX := "chg_"
const DRAWN := &"unc_drawn"
## GameState.uncanny_seen entry of a thought shown once per game.
const TEXT_PREFIX := "text_"


# --- when ------------------------------------------------------------------------------

## True when [param entry] may happen in [param phase] (an ambient event:
## its weight there is above 0; the others: within their phases).
static func in_phase(entry: Dictionary, phase: int) -> bool:
	if entry.has("weights"):
		return weight(entry, phase) > 0.0
	var phases: Array = entry.get("phases", [0, NightEscalation.PHASES.size() - 1])
	return phase >= int(phases[0]) and phase <= int(phases[1])


static func weight(entry: Dictionary, phase: int) -> float:
	var weights: Array = entry.get("weights", [])
	return float(weights[phase]) if phase >= 0 and phase < weights.size() else 0.0


static func fits_night(entry: Dictionary, night: int, modifier: StringName) -> bool:
	if night < int(entry.get("night_min", 1)):
		return false
	var last := int(entry.get("night_max", 0))
	if last > 0 and night > last:
		return false
	return not UncannyCatalog.names(entry, "modifiers_not").has(modifier)


## True when [param entry] may still fire: under its limit tonight
## ([param used]: RunState.used) and, once per game, not seen yet
## ([param seen]: GameState.uncanny_seen).
static func may_fire(entry: Dictionary, used: Array[StringName], seen: Array[StringName]) -> bool:
	var id := UncannyCatalog.id_of(entry)
	if bool(entry.get("once_per_game", false)) and seen.has(id):
		return false
	var limit := UncannyCatalog.limit_of(entry)
	return limit <= 0 or fired_count(used, id) < limit


## Times [param id] fired tonight (its "unc_<id>_<n>" entries).
static func fired_count(used: Array[StringName], id: StringName) -> int:
	var prefix := FIRED_PREFIX + String(id) + "_"
	var count := 0
	for entry in used:
		var text := String(entry)
		if text.begins_with(prefix) and text.trim_prefix(prefix).is_valid_int():
			count += 1
	return count


## The entry of [param id]'s [param n]-th firing tonight.
static func fired_id(id: StringName, n: int) -> StringName:
	return StringName("%s%s_%d" % [FIRED_PREFIX, id, n])


static func change_id(id: StringName, target: String) -> StringName:
	return StringName("%s%s@%s" % [CHANGE_PREFIX, id, target])


## [id, target] of a change entry, [] for anything else.
static func parse_change(entry: StringName) -> Array:
	var text := String(entry)
	if not text.begins_with(CHANGE_PREFIX) or not text.contains("@"):
		return []
	var body := text.trim_prefix(CHANGE_PREFIX)
	var at := body.rfind("@")
	return [StringName(body.substr(0, at)), body.substr(at + 1)]


## The changes of the world tonight ([id, target] each), in the order made.
static func changes(used: Array[StringName]) -> Array:
	var out: Array = []
	for entry in used:
		var change := parse_change(entry)
		if not change.is_empty():
			out.append(change)
	return out


## One of [param candidates] weighted by its weight in [param phase]
## ([param roll] 0..1); {} when none weighs anything.
static func pick(candidates: Array[Dictionary], phase: int, roll: float) -> Dictionary:
	var total := 0.0
	for entry in candidates:
		total += weight(entry, phase)
	if total <= 0.0:
		return {}
	var at := clampf(roll, 0.0, 0.999999) * total
	for entry in candidates:
		at -= weight(entry, phase)
		if at < 0.0:
			return entry
	return candidates[-1]


# --- where -----------------------------------------------------------------------------

## Rooms no change may touch: havens and the rooms of an arena or a guardian.
static func excluded_rooms(layout: LevelLayout) -> Array[StringName]:
	var out: Array[StringName] = []
	for room in layout.rooms:
		if room.haven and not out.has(room.id):
			out.append(room.id)
	for marker: StringName in layout.markers:
		for prefix in ARENA_PREFIXES:
			var room: StringName = layout.marker_rooms.get(marker, &"")
			if String(marker).begins_with(prefix) and room != &"" and not out.has(room):
				out.append(room)
	return out


## Indices into layout.pieces of the pieces [param entry] may change (its
## kit in its rooms, fair).
static func fair_pieces(layout: LevelLayout, entry: Dictionary) -> Array[int]:
	var found: Array[int] = []
	var kit := StringName(entry.get("kit", ""))
	var effect := StringName(entry.get("effect", ""))
	if (effect == &"hide" and not HIDE_KITS.has(kit)) or (effect == &"turn" and not TURN_KITS.has(kit)):
		return found
	var rooms := UncannyCatalog.names(entry, "rooms")
	var excluded := excluded_rooms(layout)
	for i in layout.pieces.size():
		var piece := layout.pieces[i]
		if piece.kit == kit and (rooms.is_empty() or rooms.has(piece.room)) and not excluded.has(piece.room) and piece_is_fair(layout, piece):
			found.append(i)
	return found


## True when nothing of the game lies on or near [param piece]: no marker,
## loot spot or exhibit's post within MARGIN of its footprint, no marker
## above it within CLIMB_REACH.
static func piece_is_fair(layout: LevelLayout, piece: PieceSpec) -> bool:
	var near := piece.footprint().grow(MARGIN)
	var top := piece.position.y + piece.size.y
	var reach := piece.footprint().grow(CLIMB_REACH)
	for marker: StringName in layout.markers:
		var at: Vector3 = (layout.markers[marker] as Transform3D).origin
		var flat := Vector2(at.x, at.z)
		if near.has_point(flat) and absf(at.y - piece.position.y) < piece.size.y + 2.5:
			return false
		if reach.has_point(flat) and at.y > top - 0.3 and at.y < top + 3.0:
			return false
	for spot in layout.loot_spots:
		if near.has_point(Vector2(spot.position.x, spot.position.z)) and absf(spot.position.y - piece.position.y) < piece.size.y + 2.5:
			return false
	for slot in layout.spawn_slots:
		if near.has_point(Vector2(slot.position.x, slot.position.z)) and absf(slot.position.y - piece.position.y) < piece.size.y + 2.5:
			return false
	return true


## The painting spots (portrait_* markers) of [param rooms] (all rooms when
## empty), in the layout's order.
static func painting_spots(layout: LevelLayout, rooms: Array[StringName]) -> Array[StringName]:
	var found: Array[StringName] = []
	for marker: StringName in layout.markers:
		if String(marker).begins_with(PORTRAIT_PREFIX) and (rooms.is_empty() or rooms.has(layout.marker_rooms.get(marker, &""))):
			found.append(marker)
	return found


## The loudspeakers (markers) of [param room].
static func loudspeakers(layout: LevelLayout, room: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for marker: StringName in layout.markers:
		if String(marker).begins_with(LOUDSPEAKER_PREFIX) and layout.marker_rooms.get(marker, &"") == room:
			found.append(marker)
	return found


## Rooms that may be left dark for good: a public room with main lamps and
## at least one emergency lamp (never a black hole), where the guard cannot
## fall, trip on a flight of stairs or lose the night in the dark -
## no haven, no arena nor room standing inside one, no secret room, no
## stairs, no drop, no objective (the switchboard, the astrolabe, a fuse, a
## pickup, a guardian's or the T-Rex's room), no room of the fire bowls' wing.
static func dark_rooms(layout: LevelLayout) -> Array[StringName]:
	var kept := excluded_rooms(layout)
	for others in [inside_rooms(layout, kept), stair_rooms(layout), drop_rooms(layout), Floor1Layout.objective_rooms(layout)]:
		for room_id: StringName in others:
			if not kept.has(room_id):
				kept.append(room_id)
	var mains := {}
	var reds := {}
	for light in layout.lights:
		if light.group == LightSpec.MAIN:
			mains[light.room] = true
		elif light.group == LightSpec.EMERGENCY:
			reds[light.room] = true
	var found: Array[StringName] = []
	for room in layout.rooms:
		if mains.has(room.id) and reds.has(room.id) and not kept.has(room.id) and not room.secret and not room.haven and not _lit_by_biome(room):
			found.append(room.id)
	return found


## True for a room of a wing whose lamps belong to its mechanic.
static func _lit_by_biome(room: RoomSpec) -> bool:
	for zone in BIOME_LIT_ZONES:
		if room.zone == zone or String(room.id).begins_with(String(zone) + "_"):
			return true
	return false


## Rooms with a flight of stairs in them or at one end of it.
static func stair_rooms(layout: LevelLayout) -> Array[StringName]:
	var found: Array[StringName] = []
	for flight in layout.stairs:
		for room_id: StringName in [flight.room_low, flight.room_high]:
			if room_id != &"" and not found.has(room_id):
				found.append(room_id)
	return found


## Both rooms of every passage between floors more than STEP apart that no
## flight of stairs of the lower room reaches: a drop, a pit (the Americas').
static func drop_rooms(layout: LevelLayout) -> Array[StringName]:
	var found: Array[StringName] = []
	for opening in layout.openings:
		var a := layout.room(opening.room_a)
		var b := layout.room(opening.room_b)
		if a == null or b == null or absf(a.floor_y - b.floor_y) <= STEP:
			continue
		var lower := a if a.floor_y < b.floor_y else b
		if _flight_reaches(layout, lower.id, opening.floor_y):
			continue
		for room in [a, b]:
			if not found.has(room.id):
				found.append(room.id)
	return found


## True when a flight of [param room_id] starts or ends at height [param y].
static func _flight_reaches(layout: LevelLayout, room_id: StringName, y: float) -> bool:
	for flight in layout.stairs:
		if (flight.room_low == room_id or flight.room_high == room_id) and (absf(flight.top_y - y) <= STEP or absf(flight.bottom_y - y) <= STEP):
			return true
	return false


## Rooms that lie wholly inside one of [param hosts] (a room within a room:
## the court's reading room stands inside the T-Rex's court).
static func inside_rooms(layout: LevelLayout, hosts: Array[StringName]) -> Array[StringName]:
	var found: Array[StringName] = []
	for room in layout.rooms:
		if hosts.has(room.id) or room.parts.is_empty():
			continue
		for host_id in hosts:
			var host := layout.room(host_id)
			if host == null or room.floor_y < host.floor_y - STEP or room.floor_y >= host.ceiling_y:
				continue
			if room.parts.all(func(part: Rect2) -> bool: return host.parts.any(func(big: Rect2) -> bool: return big.encloses(part))):
				found.append(room.id)
				break
	return found


## Rooms one passage or flight of stairs from [param room] (sorted by id).
static func neighbours(graph: RoomGraph, room: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for door in graph.doors_of_room(room):
		for other in graph.door_rooms(door):
			if other != room and not found.has(other):
				found.append(other)
	found.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return found


## A point of [param room], chest high: the middle of its largest part, or
## (where another room stands inside it there: the court's reading room)
## the nearest point of its parts that is the room's own.
static func room_point(layout: LevelLayout, room_id: StringName) -> Vector3:
	var room := layout.room(room_id)
	if room == null or room.parts.is_empty():
		return Vector3.INF
	var parts := room.parts.duplicate()
	parts.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_area() > b.get_area())
	var first := Vector3.INF
	for part: Rect2 in parts:
		for share: Vector2 in [Vector2(0.5, 0.5), Vector2(0.5, 0.2), Vector2(0.5, 0.8), Vector2(0.2, 0.5), Vector2(0.8, 0.5), Vector2(0.2, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8), Vector2(0.8, 0.2)]:
			var flat := part.position + part.size * share
			var point := Vector3(flat.x, room.floor_y + 1.2, flat.y)
			if first == Vector3.INF:
				first = point
			if layout.room_at(point) == room_id:
				return point
	return first


## Where an ambush shows itself: the middle of its area (its floor + 1 m),
## or its pickup's marker.
static func ambush_point(layout: LevelLayout, ambush: AmbushSpec) -> Vector3:
	if ambush.trigger == AmbushSpec.Trigger.PICKUP and layout.markers.has(ambush.marker):
		return (layout.markers[ambush.marker] as Transform3D).origin + Vector3.UP * 0.8
	var room := layout.room(ambush.room)
	var middle := ambush.area.get_center()
	return Vector3(middle.x, (room.floor_y if room != null else 0.0) + 1.0, middle.y)


## A far sound brought within [param reach] of [param listener] along its
## own direction (heard from where it is, not lost beyond the sound's range).
static func within_earshot(at: Vector3, listener: Vector3, reach: float) -> Vector3:
	var to := at - listener
	if to.length() <= reach:
		return at
	return listener + to.normalized() * reach
