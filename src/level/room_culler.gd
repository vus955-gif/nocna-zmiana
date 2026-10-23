class_name RoomCuller
extends Node
## Room-graph culling (design 11.3): rooms more than [member depth]
## passages from the room the camera is in lose their lamps, dust motes,
## reflection probes, fog volumes and decor processes. A culled lamp is
## hidden on the rendering server only - its node stays visible, so the
## exhibits' light model (LayoutIllumination.powered_by_nodes), the blackout
## and the power cut keep reading the truth - and a node made visible again
## by them (or by a graphics preset) is hidden again at once while its room
## is culled. Rooms inside another (a balcony) count as that room.
## A change of the camera's room touches only the rooms whose state changes
## (plan 2026-10-21-wydajnosc-cpu): the entered room and the rooms next to
## it come on at once, nearest first (nothing pops in view); the rooms two
## passages away coming on, then the rooms going off, follow a few a frame
## (spread_budget_usec of work a frame, at least one room). update_from()
## and refresh() switch everything at once (the menu's cuts, tests).

## Seconds between checks of the camera's room.
const INTERVAL := 0.25
## Rooms this many passages from the camera's (or nearer) come on in the
## frame it walks in; the farther ones wait in the queue.
const AT_ONCE_DEPTH := 1

## Passages from the camera's room that still count as near (GraphicsQuality
## "cull_depth"; 2 by the design).
var depth: int = 2
## False: everything stays on (comparisons, the dev view).
var enabled: bool = true
## The only rooms that may be on (room id -> true); empty = any room near
## the camera. The main menu's live scene keeps just the court, the entrance
## hall and Egypt's first rooms lit: every other room stays off wherever the
## camera is.
var only_rooms: Dictionary = {}
## Microseconds of queued switching a frame (after a room change); at least
## one room a frame whatever it costs.
var spread_budget_usec: int = 500
## Rooms switched on or off by room changes so far (tests, the profile).
var rooms_switched: int = 0
## The longest a check of the camera's room took (us), with what it
## switched at once, and how many changes of room there were (the profile).
var worst_check_usec: int = 0
var room_changes: int = 0

var _layout: LevelLayout
## Its rooms through a grid (the camera's room is looked up 4 times a second).
var _rooms: RoomIndex
## Room -> rooms one passage away (guests and hosts at no distance).
var _links: Dictionary = {}
## Room id -> {"render": [VisualInstance3D...], "motes": [GPUParticles3D...],
## "decor": [Node...]}.
var _by_room: Dictionary = {}
## Rooms culled now.
var _culled: Dictionary = {}
var _camera_room: StringName = &""
var _left: float = 0.0
## Rooms still to switch after a room change: [room, on], those coming on
## first.
var _queue: Array = []
## near() by room for _near_depth (the links never change after setup).
var _near_cache: Dictionary = {}
var _near_depth: int = -1


## Indexes what can be culled under [param roots] (lamps, motes, probes and
## fog volumes with meta "room"; decor processes in Floor1Art.DECOR_GROUP
## with meta "kit_room") and the room graph of [param layout].
func setup(layout: LevelLayout, roots: Array[Node]) -> void:
	_layout = layout
	_rooms = RoomIndex.build(layout)
	depth = int(GraphicsQuality.preset().get("cull_depth", 2))
	_links.clear()
	_near_cache.clear()
	_queue.clear()
	for room in layout.rooms:
		_links[room.id] = []
	for passage in layout.openings:
		_link(passage.room_a, passage.room_b)
	for flight in layout.stairs:
		_link(flight.room_low, flight.room_high)
	for guest in layout.rooms:
		if guest.carved or guest.parts.is_empty():
			continue
		var middle := guest.parts[0].get_center()
		for host in layout.rooms:
			# (a host holds the guest between its own floor and ceiling: the basement under
			# the court does not host the court's balcony)
			if host != guest and host.carved and host.floor_y <= guest.floor_y and guest.floor_y < host.ceiling_y and host.covers(middle):
				_link(guest.id, host.id, true)
	for root in roots:
		if root == null:
			continue
		for node in root.find_children("*", "", true, false):
			_index(node)


func _link(a: StringName, b: StringName, same: bool = false) -> void:
	if not _links.has(a) or not _links.has(b) or a == b:
		return
	(_links[a] as Array).append([b, 0 if same else 1])
	(_links[b] as Array).append([a, 0 if same else 1])


func _index(node: Node) -> void:
	var room: StringName = node.get_meta(&"room", &"")
	if node.is_in_group(Floor1Art.DECOR_GROUP):
		room = node.get_meta(&"kit_room", &"")
		if room != &"":
			_entry(room)["decor"].append(node)
		return
	if room == &"" or node is DirectionalLight3D:
		return
	if node is GPUParticles3D:
		_entry(room)["motes"].append(node)
	elif node is Light3D or node is ReflectionProbe or node is FogVolume:
		_entry(room)["render"].append(node)
	else:
		return
	(node as Node3D).visibility_changed.connect(_reapply.bind(node as VisualInstance3D, room))


func _entry(room: StringName) -> Dictionary:
	if not _by_room.has(room):
		_by_room[room] = {"render": [], "motes": [], "decor": []}
	return _by_room[room]


func _process(delta: float) -> void:
	if not _queue.is_empty():
		_work_queue()
	_left -= delta
	if _left > 0.0 or not enabled:
		return
	_left = INTERVAL
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or _layout == null:
		return
	var began := Time.get_ticks_usec()
	var room := _rooms.room_at(camera.global_position)
	if room == &"" or room == _camera_room:
		return
	_camera_room = room
	room_changes += 1
	_switch(_allowed(near(room)), true)
	worst_check_usec = maxi(worst_check_usec, Time.get_ticks_usec() - began)


## Culls by the room at [param point] (a room nobody is in keeps the last
## state), all at once. Returns the rooms kept on.
func update_from(point: Vector3) -> Dictionary:
	var room := _rooms.room_at(point) if _rooms != null else &""
	if room == &"" or room == _camera_room:
		return _allowed(near(_camera_room)) if _camera_room != &"" else {}
	_camera_room = room
	var keep := _allowed(near(room))
	_switch(keep, false)
	return keep


## Applies the cull again for the room the camera was last in (after
## [member only_rooms] changed).
func refresh() -> void:
	if _camera_room == &"":
		return
	_switch(_allowed(near(_camera_room)), false)


## Switches the rooms whose state differs from [param keep] (room ->
## passages from the camera's room): those coming on nearest first. With
## [param spread] only the ones within AT_ONCE_DEPTH now, the rest queued
## (coming on before going off).
func _switch(keep: Dictionary, spread: bool) -> void:
	_queue.clear()
	var coming: Array[StringName] = []
	var going: Array[StringName] = []
	for room: StringName in _by_room:
		var on := keep.has(room)
		if on == _culled.has(room):
			if on:
				coming.append(room)
			else:
				going.append(room)
	coming.sort_custom(func(a: StringName, b: StringName) -> bool: return int(keep[a]) < int(keep[b]))
	for room in coming:
		if spread and int(keep[room]) > AT_ONCE_DEPTH:
			_queue.append([room, true])
		else:
			_switch_room(room, true)
	for room in going:
		if spread:
			_queue.append([room, false])
		else:
			_switch_room(room, false)


## A frame's share of the queue: rooms until the budget is spent (one at
## least).
func _work_queue() -> void:
	var began := Time.get_ticks_usec()
	while not _queue.is_empty():
		var entry: Array = _queue.pop_front()
		_switch_room(entry[0], entry[1])
		if Time.get_ticks_usec() - began >= spread_budget_usec:
			return


func _switch_room(room: StringName, on: bool) -> void:
	rooms_switched += 1
	set_room(room, on)


## [param rooms] (room -> distance) without the rooms outside only_rooms.
func _allowed(rooms: Dictionary) -> Dictionary:
	if only_rooms.is_empty():
		return rooms
	var kept := {}
	for room: StringName in rooms:
		if only_rooms.has(room):
			kept[room] = rooms[room]
	return kept


## Rooms at most [member depth] passages from [param room] (room ->
## passages; worked out once per room and depth - do not change it).
func near(room: StringName) -> Dictionary:
	if depth != _near_depth:
		_near_depth = depth
		_near_cache.clear()
	var known: Variant = _near_cache.get(room)
	if known != null:
		return known
	var dist := _near(room)
	_near_cache[room] = dist
	return dist


func _near(room: StringName) -> Dictionary:
	var dist := {room: 0}
	var queue: Array[StringName] = [room]
	while not queue.is_empty():
		var at: StringName = queue.pop_front()
		for link: Array in _links.get(at, []):
			var next: StringName = link[0]
			var d: int = int(dist[at]) + int(link[1])
			if d > depth or (dist.has(next) and int(dist[next]) <= d):
				continue
			dist[next] = d
			# same-room links first: keep the queue in distance order
			if int(link[1]) == 0:
				queue.push_front(next)
			else:
				queue.push_back(next)
	return dist


## Switches [param room]'s lamps, motes, probes, fog and decor on or off.
func set_room(room: StringName, on: bool) -> void:
	if not _by_room.has(room):
		return
	if on:
		_culled.erase(room)
	else:
		_culled[room] = true
	var entry: Dictionary = _by_room[room]
	for node: Variant in entry["render"]:
		if is_instance_valid(node):
			_show(node as VisualInstance3D, on)
	for node: Variant in entry["motes"]:
		if is_instance_valid(node):
			var motes := node as GPUParticles3D
			_show(motes, on)
			motes.emitting = on and motes.visible and LevelKit.is_burning(motes)
	for node: Variant in entry["decor"]:
		if is_instance_valid(node):
			(node as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## True while [param room] is culled.
func is_culled(room: StringName) -> bool:
	return _culled.has(room)


## What the culling leaves on right now (the dev overlay): the rooms kept and
## all of them, the lamps (and those casting shadows) in the kept rooms and
## all of them, the reflection probes and the burning dust motes kept. A lamp
## the power cut or a blackout turned off does not count as on.
func light_stats() -> Dictionary:
	var out := {"rooms": _by_room.size(), "rooms_on": 0, "lamps": 0, "lamps_on": 0, "shadows_on": 0, "probes_on": 0, "motes_on": 0}
	for room: StringName in _by_room:
		var on := not _culled.has(room)
		if on:
			out["rooms_on"] += 1
		var entry: Dictionary = _by_room[room]
		for node: Variant in entry["render"]:
			if not is_instance_valid(node):
				continue
			if node is Light3D:
				out["lamps"] += 1
				if on and (node as Light3D).is_visible_in_tree():
					out["lamps_on"] += 1
					if (node as Light3D).shadow_enabled:
						out["shadows_on"] += 1
			elif node is ReflectionProbe and on and (node as ReflectionProbe).is_visible_in_tree():
				out["probes_on"] += 1
		if on:
			for node: Variant in entry["motes"]:
				if is_instance_valid(node) and (node as GPUParticles3D).emitting:
					out["motes_on"] += 1
	return out


func _show(node: VisualInstance3D, on: bool) -> void:
	RenderingServer.instance_set_visible(node.get_instance(), on and node.is_visible_in_tree())


## A culled node made visible by somebody else (the blackout's end, a
## preset) is hidden again on the server.
func _reapply(node: VisualInstance3D, room: StringName) -> void:
	if _culled.has(room):
		_rehide.call_deferred(node, room)


func _rehide(node: Variant, room: StringName) -> void:
	if is_instance_valid(node) and _culled.has(room):
		_show(node as VisualInstance3D, false)
