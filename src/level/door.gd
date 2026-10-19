class_name Door
extends Node3D
## A door filling one passage: swinging (single or double), sliding, a
## false panel that looks like the wall around it, or the undercroft gate
## (two barred leaves that can jam half a metre up and later roll aside into
## the wall). Leaves are AnimatableBody3D pieces on the WORLD layer; the door
## sits under the level's navigation source node, so a closed door cuts the
## navmesh at the next bake. [signal nav_blocking_changed] fires when the
## leaves come to rest in a new state, which is when a rebake should run.
## A door never shuts on somebody standing in it: it waits and tries again.
## Local frame: origin = middle of the passage floor, -Z points from room A
## to room B, X runs across the passage.

signal opened(door: Door)
signal closed(door: Door)
## Leaves start to move ([param opening] = towards open); for sounds. Not
## emitted for instant poses (level setup).
signal moving(door: Door, opening: bool)
signal lock_changed(door: Door, locked: bool)
## Someone tried a locked door.
signal open_refused(door: Door)
signal nav_blocking_changed(door: Door)
## GATE: the leaves lifted JAM_LIFT and stuck (still closed).
signal jammed(door: Door)

const LEAF := 0.12
const TIMES := {
	OpeningSpec.DoorStyle.SWING: 0.7,
	OpeningSpec.DoorStyle.DOUBLE_SWING: 0.9,
	OpeningSpec.DoorStyle.SLIDE: 0.6,
	OpeningSpec.DoorStyle.PANEL: 1.1,
	OpeningSpec.DoorStyle.GATE: 2.5,
}
const LOCK_COLOR := Color(1.0, 0.1, 0.06)
## GATE: how far the leaves rise when they jam, and how long that takes.
const JAM_LIFT := 0.4
const JAM_TIME := 0.8
## Seconds between tries to shut a door somebody stands in.
const CLOSE_RETRY := 0.4
## How far beyond the wall faces a swinging leaf sweeps (checked for bodies).
const SWEEP_MARGIN := 1.0

var id: StringName = &""
var style: OpeningSpec.DoorStyle = OpeningSpec.DoorStyle.SWING
var width: float = 2.0
var height: float = 2.6
var depth: float = 0.5
## Rooms on the +Z (A) and -Z (B) side.
var room_a: StringName = &""
var room_b: StringName = &""
## RoomGraph.Kind of the passage (LOCKABLE doors are the NightDirector's).
var link: RoomGraph.Kind = RoomGraph.Kind.OPEN
## Leaf colour (a false panel takes its wall's tint).
var tint := Color(0.4, 0.3, 0.22)
## PANEL: sits flush with the wall face of room A (true) or room B.
var panel_on_a: bool = true
## PANEL: kit id of the panel's look.
var panel_kit: StringName = &"false_panel"
## Leaves, frames and lock lamps from the lobby kit (ArtKit); false = the
## greybox look. Collisions are the same either way.
var art: bool = LevelArt.enabled
## With art: the rooms whose frames the passage wears, [A, B] (&"" = that
## side has none: a room still in greybox); empty = both rooms.
var frame_rooms: Array[StringName] = []

var locked: bool = false
var is_open: bool = false
## GATE: lifted and stuck (closed, but no longer flush with the floor).
var is_jammed: bool = false

var _hinges: Array[Node3D] = []
var _closed_poses: Array[Transform3D] = []
var _open_poses: Array[Transform3D] = []
var _jam_poses: Array[Transform3D] = []
var _lock_lamps: Array[Node3D] = []
var _tween: Tween = null
## Waiting for the doorway to clear before shutting.
var _close_pending: bool = false
var _retry_left: float = 0.0


static func make(spec: OpeningSpec, frame: Transform3D, leaf_tint: Color) -> Door:
	var door := Door.new()
	door.id = spec.id
	door.name = String(spec.id)
	door.style = spec.door_style
	door.width = spec.width()
	door.height = spec.height()
	door.depth = spec.depth()
	door.room_a = spec.room_a
	door.room_b = spec.room_b
	door.link = spec.link
	door.panel_on_a = spec.face_room != spec.room_b
	door.panel_kit = spec.panel_kit
	door.tint = leaf_tint
	door.transform = frame
	door.is_open = spec.start_open
	return door


func _ready() -> void:
	LevelKit.tag(self, &"door", Vector3(width, height, depth), room_a)
	_build_leaves()
	if style != OpeningSpec.DoorStyle.PANEL:
		var look: Node3D = null
		if art:
			var side_a := frame_rooms[0] if frame_rooms.size() == 2 else room_a
			var side_b := frame_rooms[1] if frame_rooms.size() == 2 else room_b
			look = ArtKit.passage(width, height, depth, side_a, side_b, id)
			if style == OpeningSpec.DoorStyle.GATE and not Floor1Art.disguised_gate(id):
				# the riveted guide channels and girder on the hall face
				if look == null:
					look = Node3D.new()
				var surround := ArtKit.model("grate_frame_6m")
				surround.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(width / 6.0, height / 5.0, 1.0)), Vector3(0, 0, depth * 0.5))
				look.add_child(surround)
			look = LevelArt.as_visual(look) if look != null else LevelArt.hidden_look()
		add_child(LevelKit.make(&"door_frame", Vector3(width, height, depth), Transform3D.IDENTITY, tint, false, {}, look))
	for face in [1.0, -1.0]:
		_lock_lamps.append(_make_lock_lamp(face))
	_pose_now()
	_show_lock()
	set_physics_process(false)


## Opens (animated unless [param instant]). A locked door stays shut.
func open(instant: bool = false) -> void:
	_close_pending = false
	if locked or is_open:
		return
	is_jammed = false
	_move(true, instant)


## Shuts (animated unless [param instant]). An animated close waits while
## somebody stands in the doorway, then shuts as soon as it is clear.
func close(instant: bool = false) -> void:
	if not is_open:
		if is_jammed:
			is_jammed = false
			_move(false, instant)
		return
	if not instant and _occupied():
		_close_pending = true
		_retry_left = CLOSE_RETRY
		set_physics_process(true)
		return
	_close_pending = false
	_move(false, instant)


## Opens unless locked; a locked door refuses (for the rattle sound).
func try_open() -> bool:
	if locked:
		open_refused.emit(self)
		return false
	open()
	return true


## GATE only: lifts the shut leaves JAM_LIFT metres and leaves them stuck
## there (the passage stays closed). Emits [signal jammed] when they rest.
func jam(instant: bool = false) -> void:
	if style != OpeningSpec.DoorStyle.GATE or is_open or is_jammed:
		return
	is_jammed = true
	_kill_tween()
	if instant or not is_inside_tree():
		_pose_now()
		jammed.emit(self)
		return
	moving.emit(self, true)
	_tween = create_tween().set_parallel(true)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i in _hinges.size():
		_tween.tween_property(_hinges[i], ^"transform", _jam_poses[i], JAM_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func() -> void:
		_tween = null
		jammed.emit(self))


## Locks the door, closing it first (a door somebody stands in shuts as
## soon as he steps out).
func lock(instant: bool = false) -> void:
	if locked:
		return
	close(instant)
	locked = true
	_show_lock()
	lock_changed.emit(self, true)


## Unlocks; the door stays closed until opened.
func unlock() -> void:
	if not locked:
		return
	locked = false
	_show_lock()
	lock_changed.emit(self, false)


func blocks_navigation() -> bool:
	return not is_open


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


## True while the door waits for its doorway to clear before shutting.
func is_waiting_to_close() -> bool:
	return _close_pending


func _physics_process(delta: float) -> void:
	if not _close_pending:
		set_physics_process(false)
		return
	_retry_left -= delta
	if _retry_left > 0.0:
		return
	_retry_left = CLOSE_RETRY
	if not _occupied():
		_close_pending = false
		set_physics_process(false)
		_move(false, false)


## True when the guard or an exhibit stands where the leaves would sweep.
func _occupied() -> bool:
	if not is_inside_tree():
		return false
	var box := BoxShape3D.new()
	var sweep := 0.0 if style == OpeningSpec.DoorStyle.SLIDE or style == OpeningSpec.DoorStyle.GATE else SWEEP_MARGIN
	box.size = Vector3(width, maxf(height - 0.2, 0.5), depth + sweep * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = Layers.PLAYER | Layers.ENEMY
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _move(to_open: bool, instant: bool) -> void:
	is_open = to_open
	_kill_tween()
	if instant or not is_inside_tree():
		_pose_now()
		_arrived()
		return
	moving.emit(self, to_open)
	if to_open:
		# the creak of a door opening: the exhibits near it hear it, in the two
		# rooms it joins and not through the walls round it (a door set open at
		# once by the level's scripts makes no noise)
		Events.door_creaked.emit(global_position + Vector3.UP * minf(height * 0.5, 1.2), PerceptionRules.DOOR_NOISE, room_a, room_b)
	_tween = create_tween().set_parallel(true)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var poses := _rest_poses()
	for i in _hinges.size():
		_tween.tween_property(_hinges[i], ^"transform", poses[i], TIMES.get(style, 0.8)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(_arrived)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _arrived() -> void:
	_tween = null
	if is_open:
		opened.emit(self)
	else:
		closed.emit(self)
	nav_blocking_changed.emit(self)


## Where the leaves rest in the current state.
func _rest_poses() -> Array[Transform3D]:
	if is_open:
		return _open_poses
	return _jam_poses if is_jammed else _closed_poses


## Puts the leaves at rest at once (no interpolation from the old pose).
func _pose_now() -> void:
	var poses := _rest_poses()
	for i in _hinges.size():
		_hinges[i].transform = poses[i]
		_hinges[i].reset_physics_interpolation()


func _show_lock() -> void:
	for lamp in _lock_lamps:
		lamp.visible = locked


## Builds the moving parts and their closed / open poses. Swinging leaves
## hinge half a leaf in from the jamb, so an open leaf lies along the jamb
## inside the passage instead of cutting into the wall.
func _build_leaves() -> void:
	var face := depth * 0.5 - LEAF * 0.5
	var inset := LEAF * 0.5
	match style:
		OpeningSpec.DoorStyle.DOUBLE_SWING:
			var leaf_width := width * 0.5 - inset
			for side in [-1.0, 1.0]:
				var hinge := Transform3D(Basis.IDENTITY, Vector3(side * (width * 0.5 - inset), 0, face))
				_add_leaf(&"door_leaf", Vector3(leaf_width, height, LEAF), Vector3(-side * leaf_width * 0.5, 0, 0), hinge, hinge * Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3.ZERO), -side)
		OpeningSpec.DoorStyle.SWING:
			var leaf_width := width - inset
			var hinge := Transform3D(Basis.IDENTITY, Vector3(-width * 0.5 + inset, 0, face))
			_add_leaf(&"door_leaf", Vector3(leaf_width, height, LEAF), Vector3(leaf_width * 0.5, 0, 0), hinge, hinge * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
		OpeningSpec.DoorStyle.SLIDE:
			var shut := Transform3D.IDENTITY
			_add_leaf(&"door_leaf", Vector3(width, height, LEAF), Vector3.ZERO, shut, shut.translated(Vector3(width, 0, 0)))
		OpeningSpec.DoorStyle.PANEL:
			var at := face if panel_on_a else -face
			var shut := Transform3D(Basis.IDENTITY, Vector3(0, 0, at))
			_add_leaf(panel_kit, Vector3(width, height, LEAF), Vector3.ZERO, shut, shut.translated(Vector3(width, 0, 0)))
		OpeningSpec.DoorStyle.GATE:
			# two barred leaves meeting in the middle; open, each rolls its own
			# width sideways into a pocket in the wall
			var half := width * 0.5
			for side in [-1.0, 1.0]:
				var shut := Transform3D(Basis.IDENTITY, Vector3(side * half * 0.5, 0, face - 0.1))
				var lifted := shut.translated(Vector3(0, JAM_LIFT, 0))
				_add_leaf(&"grate", Vector3(half, height, LEAF), Vector3.ZERO, shut, lifted.translated(Vector3(side * half, 0, 0)), side)
				_jam_poses.append(lifted)
	if _jam_poses.is_empty():
		_jam_poses = _closed_poses


## One leaf: a body (collision + look) centred at [param offset] from its
## hinge, which moves between the two poses. [param side]: the sign of the
## leaf's offset from its hinge along X (+1: hinge at -X), which picks the
## left or right grand leaf.
func _add_leaf(kit: StringName, size: Vector3, offset: Vector3, shut: Transform3D, wide: Transform3D, side: float = 1.0) -> void:
	var body := AnimatableBody3D.new()
	body.name = String(kit)
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	# without sync the node takes its new pose at once, so a navmesh bake in
	# the same frame parses the leaves where they really are
	body.sync_to_physics = false
	LevelKit.tag(body, kit, size, room_a)
	for collider in LevelKit.collision_shapes(kit, size):
		collider.position += offset
		body.add_child(collider)
	var look := _leaf_look(kit, size, side)
	look.position = offset
	body.add_child(look)
	body.transform = shut
	add_child(body)
	_hinges.append(body)
	_closed_poses.append(shut)
	_open_poses.append(wide)


## A leaf's look in its own frame: the kit's leaf, panel or grate leaf, or
## the greybox.
func _leaf_look(kit: StringName, size: Vector3, side: float) -> Node3D:
	if art:
		var look: Node3D = null
		if kit == &"grate":
			look = ArtKit.grate_leaf(size, id, side)
		else:
			look = ArtKit.leaf(kit, size, style, side, room_a if panel_on_a else room_b)
		if look != null:
			look = LevelArt.as_visual(look)
			if style == OpeningSpec.DoorStyle.PANEL and not panel_on_a:
				# a panel's finished face is its +Z side: turn it to room B
				look.basis = Basis(Vector3.UP, PI)
			return look
	return LevelKit.visual(kit, size, tint)


## Red lamp over one face of the door, lit while it is locked.
func _make_lock_lamp(face: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "LockLamp"
	holder.position = Vector3(0, height + 0.3, face * (depth * 0.5 + 0.08))
	holder.add_to_group(&"lock_lights")
	var look := LevelArt.as_visual(ArtKit.fixture(&"emergency_lamp")) if art else null
	# the kit lamp's mount runs back along +Z to the wall
	var turn := Basis(Vector3.UP, PI if face > 0.0 else 0.0)
	var lamp := LevelKit.make(&"emergency_lamp", Vector3(0.24, 0.12, 0.12), Transform3D(turn, Vector3.ZERO), LOCK_COLOR, false, {}, look)
	holder.add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = LOCK_COLOR
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.light_volumetric_fog_energy = 0.0
	light.position = Vector3(0, -0.1, face * 0.3)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 8.0
	holder.add_child(light)
	add_child(holder)
	return holder
