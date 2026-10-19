class_name MummyTomb
extends Node3D
## Where an ambush mummy sleeps (design pietro-1-projekt 5.1, 7.2): a
## standing coffin (model "coffin": its lid tips forward off the bottom
## front edge) or a sarcophagus (model "sarcophagus": its lid slides back
## and drops behind it). Front = -Z, origin = the floor under its middle
## (docs/art/kit-pietro1-egipt.md 4). Without the model a greybox of the
## same size stands in.
## - A level may place sarcophagi itself (group GROUP, [method build]); a
##   mummy whose post is within Mummy.TOMB_REACH of a free one lies down in
##   it. Otherwise an entombed mummy builds its own coffin at its post.
## - Its walls are level geometry (WORLD): they block shots, sight and the
##   guard; the occupant is excepted from colliding with them. The lid's
##   wall drops out when it opens, so a mummy climbing out can be shot.
## - [method open] plays the lid (a creak or a stone grind, the slam, dust)
##   in physics time; the tomb stays open for the rest of the night.

const GROUP := &"mummy_tombs"
## Outer sizes (m). The coffin is cut to its sleeper: wide across the
## elbows of the crossed arms, so the stand under it and its walls are too
## (MummySpawn sits at its origin: the mummy stands in the middle).
const COFFIN_SIZE := Vector3(0.86, 2.02, 0.76)
const SARCOPHAGUS_SIZE := Vector3(2.72, 1.05, 1.37)
## Wall thickness of the colliders.
const WALL := 0.08
## Coffin: the lid turns about its bottom front edge down to LID_FALL
## radians in LID_FALL_TIME seconds (falling faster and faster), then
## bounces once (LID_BOUNCE radians, LID_BOUNCE_TIME seconds).
const LID_FALL := -1.6
const LID_FALL_TIME := 0.45
const LID_BOUNCE := 0.12
const LID_BOUNCE_TIME := 0.22
## Sarcophagus: the lid grinds LID_SLIDE metres back over LID_SLIDE_TIME,
## then tips off the back edge to the floor in LID_DROP_TIME.
const LID_SLIDE := 0.7
const LID_SLIDE_TIME := 0.38
const LID_DROP_TIME := 0.22
## How far in front of the coffin (from its origin) and to the side of the
## sarcophagus's axis a mummy stands once out.
const COFFIN_EXIT := 0.95
const SARCOPHAGUS_EXIT := 1.15
## The occupant's feet stand on the coffin's stand this high (MummySpawn
## sits at 1.07, the body's middle).
const COFFIN_STAND := 0.15
const SPAWN_MARKER := "MummySpawn"
const GREY_STONE := Color(0.55, 0.32, 0.26)
const GREY_WOOD := Color(0.36, 0.24, 0.14)

var style: MummyMoves.Tomb = MummyMoves.Tomb.COFFIN
## The mummy that sleeps (or slept) in it; null = free.
var occupant: Node3D = null
var body: StaticBody3D
var lid: Node3D

var _model: Node3D
var _lid_rest := Transform3D.IDENTITY
var _lid_wall: CollisionShape3D
var _spawn := Transform3D.IDENTITY
## Seconds since open() (-1 = closed).
var _opened: float = -1.0
var _landed := false


## A tomb of [param style_] at [param at] (world transform: origin on the
## floor, front -Z), not in the tree yet.
static func build(style_: MummyMoves.Tomb, at: Transform3D) -> MummyTomb:
	var tomb := MummyTomb.new()
	tomb.name = "Coffin" if style_ == MummyMoves.Tomb.COFFIN else "Sarcophagus"
	tomb.style = style_
	tomb.transform = at
	return tomb


## The nearest free tomb whose origin lies within [param radius] of
## [param point] (floor plan, the same floor), or null. [param world_node]
## is any node in the scene.
static func free_near(world_node: Node, point: Vector3, radius: float) -> MummyTomb:
	if world_node == null or not world_node.is_inside_tree():
		return null
	var best: MummyTomb = null
	var best_distance := radius
	for node in world_node.get_tree().get_nodes_in_group(GROUP):
		var tomb := node as MummyTomb
		if tomb == null or tomb.occupant != null or tomb.is_open():
			continue
		var at := tomb.global_position
		if absf(at.y - point.y) > 1.0:
			continue
		var distance := Vector2(at.x - point.x, at.z - point.z).length()
		if distance <= best_distance:
			best_distance = distance
			best = tomb
	return best


func _ready() -> void:
	add_to_group(GROUP)
	var id := &"coffin" if style == MummyMoves.Tomb.COFFIN else &"sarcophagus"
	_model = ArtLibrary.try_instance(id)
	if _model == null:
		_model = _greybox()
	add_child(_model)
	var parts := ArtLibrary.parts(_model)
	lid = parts.get("lid") as Node3D
	var marker := parts.get(SPAWN_MARKER) as Node3D
	if marker != null:
		_spawn = _in_tomb(marker)
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.07, 0.0) if style == MummyMoves.Tomb.COFFIN else Vector3(0.0, 0.28, 0.0))
	if lid != null:
		_lid_rest = lid.transform
	_build_walls()


## Where MummySpawn lies in the tomb's space (the coffin: the body's
## middle; the sarcophagus: the floor of the trough).
func spawn_point() -> Transform3D:
	return _spawn


## Where the occupant's body (its feet, on the floor) waits inside, world.
func rest_position() -> Vector3:
	if style == MummyMoves.Tomb.COFFIN:
		return global_transform * Vector3(0.0, 0.0, _spawn.origin.z)
	return global_transform * Vector3(_spawn.origin.x, 0.0, _spawn.origin.z)


## Where it stands once out (world, on the floor): in front of the
## coffin; beside the sarcophagus, on its front (-Z) side.
func exit_point() -> Vector3:
	if style == MummyMoves.Tomb.COFFIN:
		return global_transform * Vector3(0.0, 0.0, -COFFIN_EXIT)
	return global_transform * Vector3(0.0, 0.0, -SARCOPHAGUS_EXIT)


## Which way (world, flat) the tomb's front looks.
func front() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD


func is_open() -> bool:
	return _opened >= 0.0


## Seconds since it was opened (-1 while closed).
func open_time() -> float:
	return _opened


## Opens the lid (once): the sound now, the slam and the dust when it lands.
func open() -> void:
	if is_open():
		return
	_opened = 0.0
	_landed = false
	if _lid_wall != null:
		_lid_wall.disabled = true
	if style == MummyMoves.Tomb.COFFIN:
		Sfx.play_at(&"portrait_creak", global_transform * Vector3(0.0, 1.6, -0.3), -2.0)
	else:
		Sfx.play_at(&"lock_seal_grind", global_transform * Vector3(0.0, 1.1, 0.0), -2.0)


func _physics_process(delta: float) -> void:
	if _opened < 0.0 or lid == null:
		return
	var total := (LID_FALL_TIME + LID_BOUNCE_TIME) if style == MummyMoves.Tomb.COFFIN else (LID_SLIDE_TIME + LID_DROP_TIME)
	if _opened > total + 0.1:
		return
	_opened += delta
	if style == MummyMoves.Tomb.COFFIN:
		_pose_coffin_lid(_opened)
	else:
		_pose_sarcophagus_lid(_opened)


## Falls forward faster and faster, slams, bounces once.
func _pose_coffin_lid(t: float) -> void:
	var angle := LID_FALL
	if t < LID_FALL_TIME:
		var k := t / LID_FALL_TIME
		angle = LID_FALL * k * k
	else:
		_land(global_transform * Vector3(0.0, 0.1, -1.0))
		var b := clampf((t - LID_FALL_TIME) / LID_BOUNCE_TIME, 0.0, 1.0)
		angle = LID_FALL + LID_BOUNCE * sin(b * PI)
	lid.transform = Transform3D(_lid_rest.basis * Basis(Vector3.RIGHT, angle), _lid_rest.origin)


## Grinds back, then tips over the back edge onto the floor behind.
func _pose_sarcophagus_lid(t: float) -> void:
	var slide := clampf(t / LID_SLIDE_TIME, 0.0, 1.0)
	slide = slide * slide * (3.0 - 2.0 * slide)
	var drop := clampf((t - LID_SLIDE_TIME) / LID_DROP_TIME, 0.0, 1.0)
	drop *= drop
	if drop >= 1.0:
		_land(global_transform * Vector3(0.0, 0.2, SARCOPHAGUS_SIZE.z * 0.5 + 0.3))
	var shift := Vector3(0.0, 0.03 * sin(slide * PI) - 0.95 * drop, LID_SLIDE * slide + 0.35 * drop)
	var tip := Basis(Vector3.RIGHT, 1.1 * drop)
	lid.transform = Transform3D(_lid_rest.basis * tip, _lid_rest.origin + shift)


func _land(at: Vector3) -> void:
	if _landed:
		return
	_landed = true
	Fx.puff(at, ExhibitMaterial.particle_color(ExhibitMaterial.Kind.LINEN), 28, 0.9)
	Sfx.play_at(&"weight_thud" if style == MummyMoves.Tomb.COFFIN else &"rubble", at)


## Walls as level geometry: back, sides, floor and the lid's wall (front
## of the coffin, top of the sarcophagus), which drops out on opening.
func _build_walls() -> void:
	body = StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	if style == MummyMoves.Tomb.COFFIN:
		var s := COFFIN_SIZE
		_wall(Vector3(s.x, s.y, WALL), Vector3(0.0, s.y * 0.5, s.z * 0.5 - WALL * 0.5))
		for side in [-1.0, 1.0]:
			_wall(Vector3(WALL, s.y, s.z), Vector3(side * (s.x * 0.5 - WALL * 0.5), s.y * 0.5, 0.0))
		_lid_wall = _wall(Vector3(s.x, s.y - 0.12, WALL), Vector3(0.0, 0.12 + (s.y - 0.12) * 0.5, -s.z * 0.5 + WALL * 0.5))
	else:
		var s := SARCOPHAGUS_SIZE
		_wall(Vector3(s.x, 0.28, s.z), Vector3(0.0, 0.14, 0.0))
		for side in [-1.0, 1.0]:
			_wall(Vector3(s.x, s.y, WALL * 1.5), Vector3(0.0, s.y * 0.5, side * (s.z * 0.5 - WALL * 0.75)))
			_wall(Vector3(WALL * 1.5, s.y, s.z), Vector3(side * (s.x * 0.5 - WALL * 0.75), s.y * 0.5, 0.0))
		_lid_wall = _wall(Vector3(s.x - 0.06, 0.4, s.z - 0.06), Vector3(0.0, s.y + 0.2, 0.0))


func _wall(size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var wall := CollisionShape3D.new()
	wall.shape = shape
	wall.position = at
	body.add_child(wall)
	return wall


## [param node]'s transform in the tomb's space.
func _in_tomb(node: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != self:
		xform = parent.transform * xform
		parent = parent.get_parent() as Node3D
	return xform


## Boxes of the same size and parts as the model ("lid" with its pivot
## where the model has it, the "MummySpawn" marker).
func _greybox() -> Node3D:
	var root := Node3D.new()
	root.name = "TombGreybox"
	var coffin := style == MummyMoves.Tomb.COFFIN
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GREY_WOOD if coffin else GREY_STONE
	mat.roughness = 0.8
	var size := COFFIN_SIZE if coffin else SARCOPHAGUS_SIZE
	var shell := MeshInstance3D.new()
	shell.name = "coffin" if coffin else "sarcophagus"
	shell.mesh = Enemy.box_mesh(size - (Vector3(0.0, 0.0, 0.1) if coffin else Vector3(0.0, 0.05, 0.0)))
	shell.position = Vector3(0.0, size.y * 0.5, 0.05 if coffin else 0.0)
	shell.material_override = mat
	root.add_child(shell)
	var pivot := Node3D.new()
	pivot.name = "lid"
	var cover := MeshInstance3D.new()
	if coffin:
		pivot.position = Vector3(0.0, 0.12, -0.22)
		cover.mesh = Enemy.box_mesh(Vector3(0.78, 1.9, 0.14))
		cover.position = Vector3(0.0, 0.95, -0.07)
	else:
		pivot.position = Vector3(0.0, 1.0, 0.0)
		cover.mesh = Enemy.box_mesh(Vector3(2.66, 0.3, 1.31))
		cover.position = Vector3(0.0, 0.15, 0.0)
	cover.material_override = mat
	pivot.add_child(cover)
	root.add_child(pivot)
	var spawn := Node3D.new()
	spawn.name = SPAWN_MARKER
	spawn.position = Vector3(0.0, 1.07, 0.0) if coffin else Vector3(0.0, 0.28, 0.0)
	root.add_child(spawn)
	return root
