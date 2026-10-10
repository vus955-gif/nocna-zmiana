extends Floor1ReachCase
## The walking bot of Floor I (P1 / W7; plan
## docs/superpowers/plans/2026-10-03-p1-w7-weryfikacja.md, design
## pietro-1-projekt 12): a scripted guard without exhibits walks the built
## floor's navmesh along the HUD order, opening the gates he can on foot as
## he goes (Floor1ReachCase.open_on_foot), and times it with the model of
## Floor1Route - the walks measured (the map's paths), the rest estimated
## (a look round each room on the first visit, the exhibits the night
## director draws there, the guardians, reading, searching, taking). Three
## guards:
## - critical: straight from step to step (glancing at the rooms passed),
## - typical: a first-time player - every public room as the museum opens
##   up, the havens, the notes lying in those rooms; no secret hunting,
## - full: 100% - every room (the secret ones too), haven, note, secret
##   and Lewis chess piece.
## In each state the new targets are visited nearest first (straight-line
## candidates measured on the map), then the step. Nights of 23 min 20 s:
## at dawn the next night starts in the last haven he passed (exhibits back,
## half of them slipped past, a weakened wing at 55%) and he walks back.
## Writes tests/_out/floor1_timing.json and floor1_timing.md; asserts only
## that every walk exists (numbers off the target are a report, not a bug).

const REPORT := "res://tests/_out/floor1_timing.json"
const SUMMARY := "res://tests/_out/floor1_timing.md"
const PROFILES: Array[StringName] = [&"critical", &"typical", &"full"]
## A haven door within this many metres of a walk: he steps in on the way.
const HAVEN_NEAR := 8.0
## Targets nearest in a straight line whose walks the map measures before
## the next one is chosen.
const NEAREST := 6

var profile: StringName
var timeline: Floor1Route.Timeline
var pos := Vector3.INF
var last_haven: StringName = &"security"
var known_havens: Array[StringName] = []
## Room id -> true: seen at all / fought tonight.
var visited: Dictionary = {}
var fought: Dictionary = {}
## Zones whose guardian fell before tonight (their exhibits at 55%).
var weakened: Array[StringName] = []
var fallen: Array[StringName] = []
## Room id -> {exhibits, seconds} (Floor1Route.room_fights).
var fights: Dictionary = {}
## Note marker -> words of its text.
var words: Dictionary = {}
## Target keys done.
var done: Dictionary = {}
var legs: Array[Dictionary] = []
## Room id -> seconds spent there (looking, fighting, reading, searching).
var room_seconds: Dictionary = {}
var dawns: Array[Dictionary] = []
var problems: PackedStringArray = []
var comp: int = -1
var layout: LevelLayout


func test_the_bot_walks_the_floor_and_times_it() -> void:
	await _survey()
	layout = survey.level.layout
	fights = Floor1Route.room_fights(layout, MuseumFloorLevel.describe_layout(layout))
	words = Floor1Route.note_words()
	var started := Time.get_ticks_msec()
	var report := {
		"generated": Time.get_datetime_string_from_system(),
		"assumptions": Floor1Route.assumptions(),
		"order": Floor1Route.hud_order(),
		"profiles": {},
	}
	for name in PROFILES:
		var result := await _run(name)
		report["profiles"][name] = result
		for problem in result["problems"]:
			fail("%s: %s" % [name, problem])
		assert_gt(float(result["total_s"]), 0.0)
		print("W7 bot %s: %.1f min, %.2f nights, %.0f m walked" % [name, float(result["total_s"]) / 60.0, result["nights"], result["metres"]])
		if name == &"full":
			var missed: Array[StringName] = []
			for room in layout.rooms:
				if not room.haven and not visited.has(room.id):
					missed.append(room.id)
			assert_eq(missed.size(), 0, "100%%: every room visited (missed %s)" % [missed])
	report["rooms"] = _rooms_table()
	report["parts"] = _parts_table(report)
	report["notes"] = _notes_table()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var summary := FileAccess.open(SUMMARY, FileAccess.WRITE)
	summary.store_string(_markdown(report))
	summary.close()
	print("W7 bot: %d bakes (%d ms), %d ms in all; %s" % [survey.bakes, survey.bake_msec, Time.get_ticks_msec() - started, REPORT])


# --- one guard ----------------------------------------------------------------------------

func _run(name: StringName) -> Dictionary:
	profile = name
	timeline = Floor1Route.Timeline.new()
	pos = survey.haven_start(&"security")
	last_haven = &"security"
	known_havens = [&"security"]
	visited = {}
	fought = {}
	weakened = []
	fallen = []
	done = {}
	legs = []
	room_seconds = {}
	dawns = []
	problems = PackedStringArray()
	var progress := FloorProgress.new()
	var open: Array[StringName] = []
	var candidates: Array[StringName] = []
	for spec in layout.gates:
		if spec.opening != &"" and (profile == &"full" or Floor1Plan.gate(spec.id) != null):
			candidates.append(spec.id)
	var order := Floor1Route.hud_order()
	for k in order.size():
		var step := order[k]
		var label := "%s #%d %s" % [profile, k + 1, step]
		var before := open.duplicate()
		open = await open_on_foot(progress, open, candidates, label, profile == &"full")
		for gate_id in open:
			if not before.has(gate_id):
				var opening := layout.opening(layout.gate(gate_id).opening)
				var room := layout.room(opening.room_a) if opening != null else null
				timeline.spend(&"gate", Floor1Route.GATE_TIME, Floor1Route.part_of(room.zone) if room != null else &"hub", String(gate_id))
		progress.gates_open = open.duplicate()
		comp = survey.graph.component_at(survey.haven_start(&"security"))
		if profile != &"critical":
			_explore(label)
		var reach := _reach_step(step, comp, survey.haven_start(&"security"))
		if not reach["ok"]:
			problems.append("%s: the step is out of reach" % label)
		else:
			var target := Floor1Route.step_target(step, survey.level.markers)
			var room := layout.room(layout.marker_rooms.get(target["marker"], &""))
			var part := Floor1Route.part_of(room.zone) if room != null else &"hub"
			var walk := _walk_point(reach, target["at"])
			if _go(walk[0], label):
				_extra(walk[1], part, label)
				var kind := &"guardian" if Floor1Plan.guardian(step) != null or step == ProgressRules.TREX else &"step"
				_act(kind, Floor1Route.step_seconds(step), part, label, walk[0])
				if room != null:
					room_seconds[room.id] = float(room_seconds.get(room.id, 0.0)) + Floor1Route.step_seconds(step)
		ProgressRules.apply(progress, step)
		var guardian := Floor1Plan.guardian(step)
		if guardian != null:
			fallen.append(guardian.zone)
	return _result()


## Visits every new target of this state, nearest first.
func _explore(label: String) -> void:
	var targets := _targets()
	var guard := 0
	while not targets.is_empty() and guard < 400:
		guard += 1
		targets = targets.filter(func(t: Dictionary) -> bool: return not done.has(t["key"]) and not (t["kind"] == &"room" and visited.has(t["room"])))
		if targets.is_empty():
			break
		targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return pos.distance_squared_to(a["point"]) < pos.distance_squared_to(b["point"]))
		var best: Dictionary = {}
		var best_length := INF
		for candidate: Dictionary in targets.slice(0, NEAREST):
			var path := survey.route(pos, candidate["point"])
			var length := Floor1Survey.path_length(path) if not path.is_empty() else INF
			if path.is_empty() and pos.distance_to(candidate["point"]) < 0.3:
				length = 0.0
			if length < best_length:
				best_length = length
				best = candidate
		if best.is_empty():
			for candidate: Dictionary in targets.slice(0, NEAREST):
				problems.append("%s: no walk to %s" % [label, candidate["key"]])
				done[candidate["key"]] = true
			continue
		var tag := "%s -> %s" % [label, best["key"]]
		if _go(best["point"], tag):
			_extra(best["extra"], best["part"], tag)
			if best["kind"] == &"haven":
				_haven(best["haven"])
			else:
				_act(best["kind"], best["seconds"], best["part"], tag, best["point"])
				if best["room"] != &"" and float(best["seconds"]) > 0.0:
					room_seconds[best["room"]] = float(room_seconds.get(best["room"], 0.0)) + float(best["seconds"])
		done[best["key"]] = true


## The targets of this profile within reach now: {key, kind, point (on the
## walkable navmesh), extra (metres in and out beyond it), seconds there,
## room, part, haven}.
func _targets() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var full := profile == &"full"
	var start := survey.haven_start(&"security")
	for room in layout.rooms:
		if room.haven or visited.has(room.id) or (room.secret and not full) or (not full and not room.public):
			continue
		var point := survey.room_point(room.id, comp)
		if point != Vector3.INF:
			found.append(_target("room:" + String(room.id), &"room", point, 0.0, 0.0, room))
	for haven in Floor1Plan.havens():
		if known_havens.has(haven.id):
			continue
		for exit in survey.haven_exits(haven.id):
			if survey.graph.component_at(exit) == comp:
				var target := _target("haven:" + String(haven.id), &"haven", exit, 0.0, 0.0, layout.room(haven.room))
				target["haven"] = haven.id
				found.append(target)
				break
	for marker: StringName in survey.level.markers:
		var text := String(marker)
		var kind := &""
		var seconds := 0.0
		if text.begins_with("note_") and words.has(marker):
			kind = &"note"
			seconds = Floor1Route.read_seconds(int(words[marker]))
		elif full and text.begins_with("chess_"):
			kind = &"chess"
			seconds = Floor1Route.PICKUP_TIME
		elif full and text.begins_with("secret_"):
			kind = &"secret"
			seconds = Floor1Route.SECRET_SEARCH
		else:
			continue
		if done.has(text):
			continue
		var room := layout.room(layout.marker_rooms.get(marker, &""))
		if room == null or (room.secret and not full) or (not full and not room.public and not room.haven):
			continue
		if kind == &"secret" and room.secret:
			continue   # found by walking into its room (_enter)
		var at := (survey.level.markers[marker] as Transform3D).origin
		var reach := _reach_marker(at, room, comp, start, &"use", Floor1Route.USE_REACH + Floor1Route.PROP_SLACK)
		if not reach["ok"]:
			continue
		var walk := _walk_point(reach, at)
		found.append(_target(text, kind, walk[0], walk[1], seconds, room))
	return found


func _target(key: String, kind: StringName, point: Vector3, extra: float, seconds: float, room: RoomSpec) -> Dictionary:
	return {"key": key, "kind": kind, "point": point, "extra": extra, "seconds": seconds,
		"room": room.id if room != null else &"", "part": Floor1Route.part_of(room.zone) if room != null else &"hub", "haven": &""}


## Where on the walkable navmesh the guard goes for a reach found by
## Floor1ReachCase (a haven's door for a thing inside a haven, the closest
## navmesh point for a squeeze) and the metres in and out beyond it.
func _walk_point(reach: Dictionary, at: Vector3) -> Array:
	var point: Vector3 = reach.get("point", Vector3.INF)
	match String(reach.get("how", "")):
		"haven":
			var room := layout.room(survey.room_of(at + Vector3.UP * 0.2))
			for haven in Floor1Plan.havens():
				if room != null and haven.room == room.id:
					var exit := survey.haven_start(haven.id)
					return [exit, exit.distance_to(point) * 2.0]
		"squeeze":
			var from := survey.graph.closest(point, comp, Floor1Survey.SQUEEZE)
			return [from, Vector2(from.x - point.x, from.z - point.z).length() * 2.0]
	if point == Vector3.INF or survey.graph.component_at(point) != comp:
		point = survey.graph.closest(at, comp, 6.0)
	return [point, 0.0]


# --- walking and the nights ---------------------------------------------------------------

## Walks from where he is to [param to] (a navmesh point): the rooms on the
## way (a look on the first visit, a fight unless fought tonight), the havens
## passed; at dawn the next night from the last haven, and on. False when
## there is no way.
func _go(to: Vector3, label: String) -> bool:
	for attempt in 8:
		var path := survey.route(pos, to)
		if path.is_empty():
			if pos.distance_to(to) < 0.3:
				return true
			problems.append("%s: no walk from %s to %s" % [label, pos, to])
			return false
		var entries := survey.rooms_along(path)
		for haven in Floor1Plan.havens():
			for exit in survey.haven_exits(haven.id):
				var near := _nearest_along(path, exit)
				if near[1] <= HAVEN_NEAR:
					var room := layout.room(haven.room)
					entries.append(["haven:" + String(haven.id), near[0], Floor1Route.part_of(room.zone)])
					break
		entries.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
		var length := Floor1Survey.path_length(path)
		var walked := 0.0
		var part := _part_at(pos)
		var dawn := false
		for entry: Array in entries:
			var piece := float(entry[1]) - walked
			if piece > 0.01:
				if timeline.walk({part: piece}, label) < 0.999:
					dawn = true
					break
				walked = float(entry[1])
			part = entry[2]
			var what: String = entry[0]
			if what.begins_with("haven:"):
				_haven(StringName(what.trim_prefix("haven:")))
			elif not _enter(StringName(what)):
				dawn = true
				break
		if not dawn and length - walked > 0.01:
			dawn = timeline.walk({part: length - walked}, label) < 0.999
		if not dawn:
			legs.append({"label": label, "metres": snappedf(length, 0.1), "night": timeline.night})
			pos = to
			return true
		_dawn()
	problems.append("%s: no night long enough" % label)
	return false


## The first visit (a look) and tonight's fight in a room he walks into;
## false when it does not fit into what is left of the night.
func _enter(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	if room == null:
		return true
	var part := Floor1Route.part_of(room.zone)
	var first := not visited.has(room_id)
	var look := 0.0
	if first:
		look = Floor1Route.look_seconds(room) * (Floor1Route.GLANCE_SHARE if profile == &"critical" else 1.0)
		if room.secret:
			look += Floor1Route.SECRET_SEARCH
	var fight := 0.0
	if not fought.has(room_id) and fights.has(room_id):
		fight = float((fights[room_id] as Dictionary)["seconds"])
		if not first:
			fight *= Floor1Route.REVISIT_SHARE
		if weakened.has(room.zone):
			fight *= NightDirector.WEAKENED_KEEP
	if look + fight > timeline.left():
		return false
	visited[room_id] = true
	fought[room_id] = true
	timeline.spend(&"look", look, part, String(room_id))
	timeline.spend(&"fight", fight, part, String(room_id))
	room_seconds[room_id] = float(room_seconds.get(room_id, 0.0)) + look + fight
	return true


## Steps into haven [param haven_id] (the first time: its toast and map).
func _haven(haven_id: StringName) -> void:
	last_haven = haven_id
	if not known_havens.has(haven_id):
		known_havens.append(haven_id)
		var room := layout.room(Floor1Plan.haven(haven_id).room)
		timeline.spend(&"haven", Floor1Route.HAVEN_FIRST, Floor1Route.part_of(room.zone), String(haven_id))
		visited[room.id] = true


## [param seconds] of [param kind] done at [param place]; when it does not
## fit into the night: dawn, back to the place the next night, then done.
func _act(kind: StringName, seconds: float, part: StringName, label: String, place: Vector3) -> void:
	if seconds <= 0.0:
		return
	if seconds > timeline.left():
		_dawn()
		_go(place, label + " (back)")
	timeline.spend(kind, seconds, part, label)


## Metres in and out beyond the navmesh (into a haven, a tight gap).
func _extra(metres: float, part: StringName, label: String) -> void:
	if metres > 0.01:
		timeline.walk({part: metres}, label)


## Dawn: the next night starts in the last haven; the exhibits are back and
## the wings whose guardian fell are weakened from now on.
func _dawn() -> void:
	dawns.append({"night": timeline.night, "at_s": snappedf(timeline.total, 1.0), "haven": last_haven})
	weakened = fallen.duplicate()
	var room := layout.room(Floor1Plan.haven(last_haven).room)
	timeline.next_night(Floor1Route.part_of(room.zone))
	fought = {}
	pos = survey.haven_start(last_haven)


func _part_at(point: Vector3) -> StringName:
	var room := layout.room(survey.room_of(point + Vector3.UP * 0.3))
	return Floor1Route.part_of(room.zone) if room != null else &"hub"


## [metres along [param path] to its point closest to [param point], that
## distance].
static func _nearest_along(path: PackedVector3Array, point: Vector3) -> Array:
	var best := INF
	var at := 0.0
	var walked := 0.0
	for i in range(1, path.size()):
		var on := Geometry3D.get_closest_point_to_segment(point, path[i - 1], path[i])
		var distance := on.distance_to(point)
		if distance < best:
			best = distance
			at = walked + path[i - 1].distance_to(on)
		walked += path[i - 1].distance_to(path[i])
	return [at, best]


# --- the report -------------------------------------------------------------------------------

func _result() -> Dictionary:
	var by_kind := {}
	for kind: StringName in timeline.by_kind:
		by_kind[kind] = snappedf(float(timeline.by_kind[kind]) / 60.0, 0.01)
	var by_part := {}
	for part in Floor1Route.PARTS:
		var kinds: Dictionary = timeline.by_part_kind.get(part, {})
		var minutes := {}
		for kind: StringName in kinds:
			minutes[kind] = snappedf(float(kinds[kind]) / 60.0, 0.01)
		by_part[part] = {
			"min": snappedf(float(timeline.by_part.get(part, 0.0)) / 60.0, 0.01),
			"metres": snappedf(float(timeline.metres_by_part.get(part, 0.0)), 1.0),
			"kinds_min": minutes,
		}
	var rooms := {}
	for room_id: StringName in room_seconds:
		rooms[room_id] = snappedf(float(room_seconds[room_id]), 0.1)
	return {
		"total_s": snappedf(timeline.total, 0.1),
		"total_min": snappedf(timeline.total / 60.0, 0.01),
		"nights": snappedf(timeline.nights(), 0.01),
		"nights_started": timeline.night,
		"metres": snappedf(timeline.metres, 1.0),
		"by_kind_min": by_kind,
		"by_part": by_part,
		"rooms_visited": visited.size(),
		"havens_known": known_havens.duplicate(),
		"dawns": dawns.duplicate(),
		"room_seconds": rooms,
		"legs": legs.duplicate(),
		"problems": Array(problems),
	}


func _rooms_table() -> Array:
	var rows := []
	var full: Dictionary = {}
	for room in layout.rooms:
		var counts := {"note": 0, "note_text": 0, "secret": 0, "chess": 0, "pickup": 0}
		for marker: StringName in layout.marker_rooms:
			if layout.marker_rooms[marker] != room.id:
				continue
			var text := String(marker)
			if text.begins_with("note_"):
				counts["note"] += 1
				if words.has(marker):
					counts["note_text"] += 1
			elif text.begins_with("secret_"):
				counts["secret"] += 1
			elif text.begins_with("chess_"):
				counts["chess"] += 1
		for pickup in Floor1Plan.pickups():
			if layout.marker_rooms.get(pickup.marker, &"") == room.id:
				counts["pickup"] += 1
		var fight: Dictionary = fights.get(room.id, {"exhibits": 0.0, "seconds": 0.0})
		rows.append({
			"id": room.id, "zone": room.zone, "part": Floor1Route.part_of(room.zone),
			"area_m2": snappedf(room.area(), 1.0), "public": room.public, "secret": room.secret, "haven": room.haven,
			"exhibits": snappedf(float(fight["exhibits"]), 0.1), "fight_s": snappedf(float(fight["seconds"]), 0.1),
			"look_s": snappedf(Floor1Route.look_seconds(room), 0.1),
			"notes": counts["note"], "notes_with_text": counts["note_text"], "secrets": counts["secret"],
			"chess": counts["chess"], "pickups": counts["pickup"],
		})
	return rows


func _parts_table(report: Dictionary) -> Dictionary:
	var parts := {}
	for part in Floor1Route.PARTS:
		parts[part] = {"rooms": 0, "area_m2": 0.0, "exhibits": 0.0, "notes": 0, "notes_with_text": 0, "secrets": 0, "chess": 0}
	for row: Dictionary in report["rooms"]:
		var entry: Dictionary = parts[row["part"]]
		entry["rooms"] += 1
		entry["area_m2"] = snappedf(float(entry["area_m2"]) + float(row["area_m2"]), 1.0)
		entry["exhibits"] = snappedf(float(entry["exhibits"]) + float(row["exhibits"]), 0.1)
		for key: String in ["notes", "notes_with_text", "secrets", "chess"]:
			entry[key] += int(row[key])
	for name: StringName in report["profiles"]:
		var profile_result: Dictionary = report["profiles"][name]
		for part in Floor1Route.PARTS:
			parts[part][String(name) + "_min"] = profile_result["by_part"][part]["min"]
	return parts


func _notes_table() -> Dictionary:
	var with_text := 0
	var without: Array[StringName] = []
	var total_words := 0
	for marker: StringName in layout.markers:
		if not String(marker).begins_with("note_"):
			continue
		if words.has(marker):
			with_text += 1
			total_words += int(words[marker])
		else:
			without.append(marker)
	return {"with_text": with_text, "without_text": without, "average_words": snappedf(float(total_words) / maxf(1.0, float(with_text)), 0.1)}


func _markdown(report: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# Floor I timing (W7 bot)")
	lines.append("")
	lines.append("| profile | minutes | nights (23 min 20 s) | metres |")
	lines.append("|---|---|---|---|")
	for name: StringName in report["profiles"]:
		var result: Dictionary = report["profiles"][name]
		lines.append("| %s | %.1f | %.2f | %d |" % [name, result["total_min"], result["nights"], int(result["metres"])])
	lines.append("")
	lines.append("| part | rooms | m2 | exhibits | critical | typical | full |")
	lines.append("|---|---|---|---|---|---|---|")
	for part in Floor1Route.PARTS:
		var entry: Dictionary = report["parts"][part]
		lines.append("| %s | %d | %d | %.1f | %.1f | %.1f | %.1f |" % [part, entry["rooms"], int(entry["area_m2"]), entry["exhibits"], entry.get("critical_min", 0.0), entry.get("typical_min", 0.0), entry.get("full_min", 0.0)])
	lines.append("")
	return "\n".join(lines)
