class_name LevelBuilder
extends RefCounted
## Turns a LevelLayout (pure data) into nodes: the carved shell (floors,
## walls, ceilings, doorways, skylight wells), placed pieces, stairs
## (visual steps + invisible ramp), skylight frames and doors. Every piece
## comes from LevelKit. Nodes go under three parents by role:
## - [member walk_root]: navigation sources of the walkable level,
## - [member haven_root]: navigation sources of havens (own nav layer),
## - [member structure_root]: all the rest (roofs, wall above doorways,
##   decoration, non-colliding props) — never a navigation source.

## Thickness and height of stair railings.
const STAIR_RAIL := Vector2(0.12, 1.0)
## Stair railings begin this far (floor plan, m) up from the foot.
const STAIR_RAIL_START := 1.2
## Shell kits whose top is walked on (they also stop particles).
const FLOOR_KITS: Array[StringName] = [&"floor", &"slab", &"threshold"]

var layout: LevelLayout
var walk_root: Node3D
var haven_root: Node3D
var structure_root: Node3D
## Opening id -> Door, for every opening with a door style.
var doors: Dictionary = {}
## Where the doors go (null: [member walk_root]; Floor I keeps them apart,
## they change the navigation).
var door_root: Node3D = null
## Piece kits left out (the game puts the live T-Rex where the lobby's
## stand-in skeleton would stand).
var skip_kits: Array[StringName] = []
## Dress the level with the lobby kit (LevelArt: tile fields, models, wall
## bands, ceilings); false = the greybox look. Collisions are the same.
var art: bool = LevelArt.enabled
## With [member art]: the rooms dressed (room id -> true); empty = every
## room. A floor dressed zone by zone (Floor I: MuseumFloorLevel.ART_ZONES)
## keeps the greybox in the rest.
var art_rooms: Dictionary = {}
## Rooms open to the sky (a roof), room id -> the room whose stone their
## walls wear: their ceilings and light wells have no look and cast no
## shadow, so the moon falls in (and through the glass beneath them).
## Collision stays.
var sky_rooms: Dictionary = {}
## Wall bands, ceilings, floor inlays, balcony fascia (under structure).
var dressing: Node3D = null


func _init(level_layout: LevelLayout, walkable: Node3D, havens: Node3D, structure: Node3D) -> void:
	layout = level_layout
	walk_root = walkable
	haven_root = havens
	structure_root = structure


func build() -> void:
	_build_shell()
	_build_pieces()
	for flight in layout.stairs:
		_build_stairs(flight)
	_build_skylights()
	for passage in layout.openings:
		_build_passage(passage)
	if art:
		dressing = Node3D.new()
		dressing.name = "Dressing"
		structure_root.add_child(dressing)
		LevelArt.dress(layout, dressing, art_rooms)


## Empty volumes the shell is carved around: carved room parts, every
## opening and the skylight wells.
func shell_volumes() -> Array[ShellCarver.Volume]:
	var volumes: Array[ShellCarver.Volume] = []
	for room in layout.rooms:
		if not room.carved:
			continue
		for part in room.parts:
			volumes.append(ShellCarver.volume(part, room.floor_y, room.ceiling_y, room.id, ShellCarver.Kind.ROOM, room.secret))
		for well in room.skylights:
			volumes.append(ShellCarver.volume(well, room.ceiling_y, room.ceiling_y + LevelLayout.SKYLIGHT_WELL, room.id, ShellCarver.Kind.SKY, room.secret))
	for passage in layout.openings:
		volumes.append(ShellCarver.volume(passage.rect, passage.floor_y, passage.top_y, passage.id, ShellCarver.Kind.PASSAGE))
	return volumes


## Every wall face seen from inside a room (stage-3 wall modules).
func wall_faces() -> Array[ShellCarver.WallFace]:
	return ShellCarver.wall_faces(shell_volumes())


## The room a shell owner belongs to (an opening counts as its first room).
func room_of(owner: StringName) -> StringName:
	if layout.room(owner) != null:
		return owner
	var passage := layout.opening(owner)
	return passage.room_a if passage != null else &""


## Tint of a room or of an opening (an opening looks like its first room).
func tint_of(owner: StringName) -> Color:
	var room := layout.room(owner)
	if room == null:
		var passage := layout.opening(owner)
		if passage != null:
			room = layout.room(passage.room_a)
	return room.tint if room != null else Color(0.6, 0.6, 0.6)


## True when [param room_id] wears the art (art on, and the room among
## [member art_rooms] when that is set).
func dresses(room_id: StringName) -> bool:
	return art and (art_rooms.is_empty() or art_rooms.has(room_id))


func _is_haven(room_id: StringName) -> bool:
	var room := layout.room(room_id)
	return room != null and room.haven


func _build_shell() -> void:
	for box in ShellCarver.carve(shell_volumes()):
		var size := box.aabb.size
		var base := box.aabb.position + Vector3(size.x * 0.5, 0.0, size.z * 0.5)
		var room := room_of(box.owner)
		var look: Node3D = null
		if _open_to_sky(box, room):
			look = LevelArt.hidden_look()
		elif art and sky_rooms.has(room) and box.kit == &"wall":
			# the fronts round a roof open to the sky, seen through the glass
			# below: stone like the court's (the roof's own art comes later)
			look = LevelArt.shell_look(box.kit, box.aabb, sky_rooms[room], room)
		elif dresses(room):
			var walk := room_of(box.walk_owner) if box.walk_owner != &"" else room
			look = LevelArt.shell_look(box.kit, box.aabb, room, walk)
		var piece := LevelKit.make(box.kit, size, Transform3D(Basis.IDENTITY, base), tint_of(box.owner), true, {}, look)
		piece.set_meta(&"kit_room", room)
		if _open_to_sky(box, room):
			piece.set_meta(&"sky", true)
		var parent := walk_root
		if box.above_all:
			parent = structure_root
		elif FLOOR_KITS.has(box.kit) and _is_haven(box.walk_owner):
			parent = haven_root
		if FLOOR_KITS.has(box.kit):
			piece.add_child(_particle_stop(size))
		parent.add_child(piece)


func _build_pieces() -> void:
	var index := 0
	for spec in layout.pieces:
		index += 1
		if skip_kits.has(spec.kit):
			continue
		var tint := spec.tint if spec.tint.a > 0.0 else tint_of(spec.room)
		var look := LevelArt.piece_look(spec, index, layout) if dresses(spec.room) else null
		if look == null and sky_rooms.has(spec.room) and spec.kit == &"roof_glass":
			# glass under the open sky lets the moon down into the room below
			look = LevelArt.clear_glass_look(spec.size)
		var piece := LevelKit.make(spec.kit, spec.size, spec.transform(), tint, spec.collide, {}, look)
		piece.set_meta(&"kit_room", spec.room)
		if spec.kit == &"balcony":
			piece.add_child(_particle_stop(spec.size))
		var parent := structure_root
		if spec.collide:
			parent = haven_root if _is_haven(spec.room) else walk_root
		parent.add_child(piece)


## Visual steps (no collision) plus an invisible collision ramp through the
## step nosings: its foot starts one tread in front of the first step, it
## reaches the top one tread before the end, then runs flat.
func _build_stairs(flight: StairsSpec) -> void:
	var frame := flight.frame()
	var run := flight.run()
	var width := flight.width()
	var rise := flight.top_y - flight.bottom_y
	var steps := flight.step_count()
	var tread := run / steps
	var middle := frame * Vector3(0, 0, -run * 0.5)
	# the drawn steps are the ramp's steps (same count, same risers)
	var dressed := dresses(flight.room_low)
	var art_look := LevelArt.stairs_look(flight) if dressed else null
	var look := LevelKit.make(&"stairs", Vector3(width, rise, run), Transform3D(frame.basis, middle), tint_of(flight.room_low), false, {"steps": steps}, art_look)
	look.set_meta(&"kit_room", flight.room_low)
	structure_root.add_child(look)
	var hull := ConvexPolygonShape3D.new()
	var half := width * 0.5
	var crest := -(steps - 1) * tread
	hull.points = PackedVector3Array([
		Vector3(-half, 0, tread), Vector3(half, 0, tread),
		Vector3(-half, 0, -run), Vector3(half, 0, -run),
		Vector3(-half, rise, crest), Vector3(half, rise, crest),
		Vector3(-half, rise, -run), Vector3(half, rise, -run),
	])
	var collider := CollisionShape3D.new()
	collider.shape = hull
	var ramp := StaticBody3D.new()
	ramp.name = "stair_ramp"
	ramp.collision_layer = Layers.WORLD
	ramp.collision_mask = 0
	ramp.transform = frame
	ramp.add_child(collider)
	LevelKit.tag(ramp, &"stair_ramp", Vector3(width, rise, run + tread), flight.room_low)
	var particles := GPUParticlesCollisionBox3D.new()
	particles.size = Vector3(width, 0.2, Vector2(run, rise).length())
	particles.transform = Transform3D(Basis(Vector3.RIGHT, atan2(rise, run)), Vector3(0, rise * 0.5 - 0.1, -run * 0.5))
	ramp.add_child(particles)
	walk_root.add_child(ramp)
	# side railings start a little way up the flight (the first steps stay
	# open to the side, and the rail end does not jut out over the landing)
	var run_to_crest := tread - crest
	var start := minf(STAIR_RAIL_START, run_to_crest * 0.5) / run_to_crest
	var low := Vector3(0, rise * start, tread - run_to_crest * start)
	var slope := Vector3(0, rise, crest) - low
	var pitch := atan2(rise, run_to_crest)
	for side in [-1.0, 1.0]:
		if (side < 0.0 and not flight.rail_left) or (side > 0.0 and not flight.rail_right):
			continue
		var x: float = side * (half - STAIR_RAIL.x * 0.5)
		var middle_point := Vector3(x, 0, 0) + low + slope * 0.5
		var rail := Transform3D(frame.basis * Basis(Vector3.RIGHT, pitch), frame * middle_point)
		# with art the drawn balustrade (or the wall) stands there: the rail is only collision
		var hidden := LevelArt.hidden_look() if dressed else null
		var railing := LevelKit.make(&"railing", Vector3(STAIR_RAIL.x, STAIR_RAIL.y, slope.length()), rail, tint_of(flight.room_low), true, {}, hidden)
		railing.set_meta(&"kit_room", flight.room_low)
		walk_root.add_child(railing)


func _build_skylights() -> void:
	for room in layout.rooms:
		for well in room.skylights:
			var middle := well.get_center()
			var at := Vector3(middle.x, room.ceiling_y + LevelLayout.SKYLIGHT_WELL - 0.3, middle.y)
			var size := Vector3(well.size.x, 0.3, well.size.y)
			var look: Node3D = null
			if sky_rooms.has(room.id):
				look = LevelArt.hidden_look()
			elif dresses(room.id):
				look = LevelArt.skylight_look(size, room.id)
			var frame := LevelKit.make(&"skylight", size, Transform3D(Basis.IDENTITY, at), room.tint, false, {}, look)
			frame.set_meta(&"kit_room", room.id)
			structure_root.add_child(frame)


## A Door for passages with a door style, a plain frame trim for arches.
func _build_passage(passage: OpeningSpec) -> void:
	var frame := passage_frame(passage)
	if passage.door_style == OpeningSpec.DoorStyle.NONE:
		var size := Vector3(passage.width(), passage.height(), passage.depth())
		var look: Node3D = null
		if dresses(passage.room_a) or dresses(passage.room_b):
			# the rooms' architraves, or a bare opening in the stone when neither has one
			var frames := ArtKit.passage(size.x, size.y, size.z, _dressed_or_none(passage.room_a), _dressed_or_none(passage.room_b), passage.id)
			look = LevelArt.as_visual(frames) if frames != null else LevelArt.hidden_look()
		var trim := LevelKit.make(&"door_frame", size, frame, tint_of(passage.room_a), false, {}, look)
		trim.set_meta(&"kit_room", passage.room_a)
		structure_root.add_child(trim)
		return
	var leaf_tint := LevelKit.WOOD
	match passage.door_style:
		OpeningSpec.DoorStyle.PANEL:
			leaf_tint = tint_of(passage.face_room)
		OpeningSpec.DoorStyle.SLIDE:
			leaf_tint = LevelKit.METAL.darkened(0.2)
	var door := Door.make(passage, frame, leaf_tint)
	door.art = dresses(passage.room_a) or dresses(passage.room_b)
	if door.art and not (dresses(passage.room_a) and dresses(passage.room_b)):
		# frames only on the dressed side
		door.frame_rooms.assign([_dressed_or_none(passage.room_a), _dressed_or_none(passage.room_b)])
	(door_root if door_root != null else walk_root).add_child(door)
	doors[passage.id] = door


## [param room_id] when it wears the art, else &"" (no frame on that side).
func _dressed_or_none(room_id: StringName) -> StringName:
	return room_id if dresses(room_id) else &""


## True for a box of a sky room's roof: a ceiling (or a light well's wall
## above the room's ceiling) of a room in [member sky_rooms].
func _open_to_sky(box: ShellCarver.ShellBox, room: StringName) -> bool:
	if not sky_rooms.has(room):
		return false
	if box.kit == &"ceiling":
		return true
	var spec := layout.room(room)
	return box.kit == &"wall" and spec != null and box.aabb.position.y >= spec.ceiling_y - 0.01


## Local frame of a passage: origin in the middle of its floor, -Z pointing
## from room A to room B, X across.
func passage_frame(passage: OpeningSpec) -> Transform3D:
	var middle := passage.rect.get_center()
	var axis := Vector2(1, 0) if passage.runs_along_x() else Vector2(0, 1)
	var toward_a := _nearest_point(layout.room(passage.room_a), middle) - middle
	var a_to_b := -axis if toward_a.dot(axis) > 0.0 else axis
	var yaw := atan2(-a_to_b.x, -a_to_b.y)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(middle.x, passage.floor_y, middle.y))


static func _nearest_point(room: RoomSpec, point: Vector2) -> Vector2:
	var best := point
	var best_distance := INF
	if room == null:
		return point
	for part in room.parts:
		var closest := point.clamp(part.position, part.end)
		var distance := closest.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = closest
	return best


## Lets GPU particles (hit sparks, wax drops) land on a slab of [param size]
## whose base centre is the node origin.
static func _particle_stop(size: Vector3) -> GPUParticlesCollisionBox3D:
	var stop := GPUParticlesCollisionBox3D.new()
	stop.size = size
	stop.position = Vector3(0, size.y * 0.5, 0)
	return stop
