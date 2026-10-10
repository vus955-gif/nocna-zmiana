class_name RoomGraph
extends RefCounted
## Rooms joined by doors (and stairs). Answers "which rooms can the guard
## reach from here" with some doors shut, e.g. to check that a door the
## NightDirector locks never cuts off an objective.

## OPEN: always passable. LOCKABLE: passable unless closed this night.
## SECRET: a false panel, shut unless listed as opened. GATE: shut unless
## listed as opened (the grate to the undercroft).
enum Kind { OPEN, LOCKABLE, SECRET, GATE }

class Link:
	var id: StringName
	var a: StringName
	var b: StringName
	var kind: Kind

	func other(room: StringName) -> StringName:
		return b if room == a else a

var _rooms: Array[StringName] = []
## room id -> Array of Link
var _links: Dictionary = {}
## door id -> Link
var _doors: Dictionary = {}


func add_room(room: StringName) -> void:
	if not _links.has(room):
		_rooms.append(room)
		_links[room] = []


func add_door(door: StringName, room_a: StringName, room_b: StringName, kind: Kind = Kind.OPEN) -> void:
	add_room(room_a)
	add_room(room_b)
	var link := Link.new()
	link.id = door
	link.a = room_a
	link.b = room_b
	link.kind = kind
	_links[room_a].append(link)
	_links[room_b].append(link)
	_doors[door] = link


func rooms() -> Array[StringName]:
	return _rooms.duplicate()


func has_room(room: StringName) -> bool:
	return _links.has(room)


func has_door(door: StringName) -> bool:
	return _doors.has(door)


## Door ids of the given kind, in the order they were added.
func doors_of_kind(kind: Kind) -> Array[StringName]:
	var found: Array[StringName] = []
	for door: StringName in _doors:
		if (_doors[door] as Link).kind == kind:
			found.append(door)
	return found


## Ids of the doors touching [param room].
func doors_of_room(room: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for link: Link in _links.get(room, []):
		found.append(link.id)
	return found


## The two rooms a door joins ([] for an unknown door).
func door_rooms(door: StringName) -> Array[StringName]:
	if not _doors.has(door):
		return []
	var link: Link = _doors[door]
	return [link.a, link.b]


## Rooms reachable from [param from] (as a Dictionary room -> true; the
## start room included). Doors in [param closed] are shut; SECRET and GATE
## doors are shut unless listed in [param opened].
func reachable(from: StringName, closed: Array[StringName] = [], opened: Array[StringName] = []) -> Dictionary:
	var seen := {}
	if not _links.has(from):
		return seen
	seen[from] = true
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var room: StringName = queue.pop_front()
		for link: Link in _links[room]:
			if not _passable(link, closed, opened):
				continue
			var next := link.other(room)
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func connected(from: StringName, to: StringName, closed: Array[StringName] = [], opened: Array[StringName] = []) -> bool:
	return reachable(from, closed, opened).has(to)


## The doors along a shortest way (fewest doors) from [param from] to
## [param to], in order; [] when there is none (or from == to). Same rules
## for [param closed] and [param opened] as reachable(); ties go to the
## door added first, so the answer never changes between runs.
func route(from: StringName, to: StringName, closed: Array[StringName] = [], opened: Array[StringName] = []) -> Array[StringName]:
	var doors: Array[StringName] = []
	if not _links.has(from) or not _links.has(to) or from == to:
		return doors
	var came := {from: null}   # room -> Link it was entered through
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var room: StringName = queue.pop_front()
		if room == to:
			break
		for link: Link in _links[room]:
			if not _passable(link, closed, opened):
				continue
			var next := link.other(room)
			if not came.has(next):
				came[next] = link
				queue.append(next)
	if not came.has(to):
		return doors
	var room := to
	while came[room] != null:
		var link: Link = came[room]
		doors.push_front(link.id)
		room = link.other(room)
	return doors


func _passable(link: Link, closed: Array[StringName], opened: Array[StringName]) -> bool:
	if closed.has(link.id):
		return false
	match link.kind:
		Kind.SECRET, Kind.GATE:
			return opened.has(link.id)
	return true
