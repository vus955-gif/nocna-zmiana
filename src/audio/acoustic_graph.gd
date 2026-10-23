class_name AcousticGraph
extends RefCounted
## How many passages a sound crosses between two rooms of a level (plan
## 2026-10-21-akustyka-ambient): rooms joined by their openings and stairs,
## a room inside another (a balcony in the court, a gallery in a hall) at no
## distance from its host - the same reading of the layout as RoomCuller's.
## Pure; built once per level layout (Acoustics.graph_of) and asked when a
## positional sound starts (hops with a small cache per starting room).

## Hops reported for rooms farther apart than MAX_HOPS, unknown or unlinked.
const FAR := 99
## A breadth-first walk stops this many passages out (2 and more sound the
## same: occluded).
const MAX_HOPS := 3

## Room -> Array of [other room, cost (0 guest/host, 1 passage)].
var _links: Dictionary = {}
## Room -> {room: hops} (filled lazily, up to MAX_HOPS).
var _dist: Dictionary = {}


## The graph of [param layout]: an object with rooms (id, parts, floor_y,
## ceiling_y, carved, covers()), openings (room_a, room_b) and stairs
## (room_low, room_high) - a LevelLayout; openings and stairs are optional.
static func from_layout(layout: Object) -> AcousticGraph:
	var graph := AcousticGraph.new()
	var rooms: Array = layout.get(&"rooms") if "rooms" in layout else []
	for room: Variant in rooms:
		graph.add_room(room.id)
	if "openings" in layout:
		for passage: Variant in layout.get(&"openings"):
			graph.link(passage.room_a, passage.room_b)
	if "stairs" in layout:
		for flight: Variant in layout.get(&"stairs"):
			graph.link(flight.room_low, flight.room_high)
	for guest: Variant in rooms:
		if not "carved" in guest or guest.carved or guest.parts.is_empty():
			continue
		var middle: Vector2 = (guest.parts[0] as Rect2).get_center()
		for host: Variant in rooms:
			if host == guest or not host.carved or not host.has_method(&"covers"):
				continue
			# (a host holds the guest between its own floor and ceiling)
			if host.floor_y <= guest.floor_y and guest.floor_y < host.ceiling_y and host.covers(middle):
				graph.link(guest.id, host.id, 0)
	return graph


func add_room(room: StringName) -> void:
	if not _links.has(room):
		_links[room] = []


## Joins [param a] and [param b] ([param cost] 1: a passage, 0: one room
## inside the other).
func link(a: StringName, b: StringName, cost: int = 1) -> void:
	if a == b or not _links.has(a) or not _links.has(b):
		return
	(_links[a] as Array).append([b, cost])
	(_links[b] as Array).append([a, cost])
	_dist.clear()


func has_room(room: StringName) -> bool:
	return _links.has(room)


## Passages between [param a] and [param b] (0: the same room or one inside
## the other; FAR: farther than MAX_HOPS, or unknown).
func hops(a: StringName, b: StringName) -> int:
	if a == b and _links.has(a):
		return 0
	return int(_from(a).get(b, FAR))


## Rooms exactly one passage from [param room] (where something can be
## heard "next door").
func neighbours(room: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	var dist := _from(room)
	for other: StringName in dist:
		if int(dist[other]) == 1:
			found.append(other)
	found.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	return found


## Distances from [param room] (0-1 breadth-first: guests at no cost).
func _from(room: StringName) -> Dictionary:
	if _dist.has(room):
		return _dist[room]
	var dist := {}
	if _links.has(room):
		dist[room] = 0
		var queue: Array[StringName] = [room]
		while not queue.is_empty():
			var at: StringName = queue.pop_front()
			for edge: Array in _links[at]:
				var next: StringName = edge[0]
				var d: int = int(dist[at]) + int(edge[1])
				if d > MAX_HOPS or (dist.has(next) and int(dist[next]) <= d):
					continue
				dist[next] = d
				if int(edge[1]) == 0:
					queue.push_front(next)
				else:
					queue.push_back(next)
	_dist[room] = dist
	return dist
