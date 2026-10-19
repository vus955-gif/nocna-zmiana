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

## Seconds between checks of the camera's room.
const INTERVAL := 0.25

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

var _layout: LevelLayout
## Room -> rooms one passage away (guests and hosts at no distance).
var _links: Dictionary = {}
## Room id -> {"render": [VisualInstance3D...], "motes": [GPUParticles3D...],
## "decor": [Node...]}.
var _by_room: Dictionary = {}
## Rooms culled now.
var _culled: Dictionary = {}
var _camera_room: StringName = &""
var _left: float = 0.0


## Indexes what can be culled under [param roots] (lamps, motes, probes and
## fog volumes with meta "room"; decor processes in Floor1Art.DECOR_GROUP
## with meta "kit_room") and the room graph of [param layout].
func setup(layout: LevelLayout, roots: Array[Node]) -> void:
	_layout = layout
	depth = int(GraphicsQuality.preset().get("cull_depth", 2))
	_links.clear()
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
	_left -= delta
	if _left > 0.0 or not enabled:
		return
	_left = INTERVAL
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		update_from(camera.global_position)


## Culls by the room at [param point] (a room nobody is in keeps the last
## state). Returns the rooms kept on.
func update_from(point: Vector3) -> Dictionary:
	var room := _layout.room_at(point) if _layout != null else &""
	if room == &"" or room == _camera_room:
		return _allowed(near(_camera_room)) if _camera_room != &"" else {}
	_camera_room = room
	var keep := _allowed(near(room))
	for other: StringName in _by_room:
		set_room(other, keep.has(other))
	return keep


## Applies the cull again for the room the camera was last in (after
## [member only_rooms] changed).
func refresh() -> void:
	if _camera_room == &"":
		return
	var keep := _allowed(near(_camera_room))
	for other: StringName in _by_room:
		set_room(other, keep.has(other))


## [param rooms] (room -> distance) without the rooms outside only_rooms.
func _allowed(rooms: Dictionary) -> Dictionary:
	if only_rooms.is_empty():
		return rooms
	var kept := {}
	for room: StringName in rooms:
		if only_rooms.has(room):
			kept[room] = rooms[room]
	return kept


## Rooms at most [member depth] passages from [param room].
func near(room: StringName) -> Dictionary:
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
