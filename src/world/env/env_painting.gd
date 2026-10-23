class_name EnvPainting
extends EnvProp
## A painting on the gallery wall (every WallPainting the Museum hangs; the
## living Portraits answer for themselves; plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md): every hit knocks it crooked on its nail
## (EnvRules.painting_tilt, towards the side that was hit) - it wobbles and
## stays crooked, the next hit adds to it. Past PAINTING_FALL_TILT, to a
## crushing hit or a blast it slips off its nail: it slides down the wall
## and comes to rest on the floor, leaning back against the wall - a thud
## the exhibits hear. It stays there for the night. It hurts nobody (no
## warning needed); falling, it takes its collision with it.

## A wobble's spring (1/s^2) and damping (1/s), when it counts as still.
const STIFFNESS := 90.0
const DAMPING := 9.0
const STILL := 0.002
const SLIDE_TIME := 0.45
## How far it leans back against the wall lying on the floor (rad), and how
## crooked it stays.
const LEAN := 0.22
const KEEP_CROOKED := 0.25

## Its frame's outer size and depth.
var outer := PaintingArt.MODEL_OUTER
var depth: float = PaintingArt.MODEL_DEPTH
## Crooked by (rad, + = clockwise seen from the room) and where it heads.
var tilt: float = 0.0
var floor_y: float = 0.0

var _goal: float = 0.0
var _spin: float = 0.0
var _rest := Transform3D.IDENTITY


static func scan(layer: EnvLayer) -> void:
	var root: Variant = layer.museum.get(&"paintings_root") if is_instance_valid(layer.museum) else null
	if not root is Node:
		return
	var layout: Variant = layer.level.get(&"layout")
	for node in (root as Node).get_children():
		var painting := node as WallPainting
		if painting == null or layer.owned.has(painting):
			continue
		var front := painting.global_position - painting.global_basis.z * 0.4
		var room_id: StringName = (layout as LevelLayout).room_at(front) if layout is LevelLayout else &""
		if layer.skips(room_id):
			continue
		var spec := layer.room_spec(room_id)
		layer.add_prop(make(painting, room_id, spec.floor_y if spec != null else painting.global_position.y - 1.6))


static func make(painting: WallPainting, room_id: StringName, floor_height: float) -> EnvPainting:
	var prop := EnvPainting.new()
	prop.name = "Painting"
	prop.id = EnvLayer.make_id(&"painting", room_id, painting.global_position)
	prop.room = room_id
	prop.target = painting
	prop.floor_y = floor_height
	prop.transform = painting.global_transform
	if painting.model == null:
		prop.outer = PaintingArt.CANVAS_SIZE + Vector2.ONE * PaintingArt.FRAME_WIDTH * 2.0
		prop.depth = PaintingArt.DEPTH
	var shape := BoxShape3D.new()
	shape.size = Vector3(prop.outer.x + 0.04, prop.outer.y + 0.04, 0.06)
	prop.add_zone(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -prop.depth - 0.03)))
	return prop


func _ready() -> void:
	super()
	if is_instance_valid(target):
		_rest = target.global_transform


func _hit(info: DamageInfo) -> void:
	if phase == Phase.FALLING or not EnvRules.real(info):
		return
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.CANVAS, 0.8)
	Sfx.play_at(&"hit_canvas", info.position, -4.0)
	var local := global_transform.affine_inverse() * info.position
	var side := 1.0 if local.x >= 0.0 else -1.0
	var next := _goal + side * deg_to_rad(EnvRules.painting_tilt(info))
	if EnvRules.painting_falls(rad_to_deg(next), info):
		_goal = next
		slip()
		return
	_goal = next
	_spin += side * 3.0
	phase = Phase.MOVING
	wake()


func recapture() -> void:
	if is_down or phase != Phase.IDLE or not is_instance_valid(target):
		return
	super()
	_rest = target.global_transform
	tilt = 0.0
	_goal = 0.0
	var picture := target as WallPainting
	if picture != null:
		outer = PaintingArt.MODEL_OUTER if picture.model != null else PaintingArt.CANVAS_SIZE + Vector2.ONE * PaintingArt.FRAME_WIDTH * 2.0
		depth = PaintingArt.MODEL_DEPTH if picture.model != null else PaintingArt.DEPTH


func settle() -> void:
	tilt = _goal
	_spin = 0.0
	_place(tilt)
	if phase == Phase.MOVING:
		phase = Phase.IDLE


func _physics_process(delta: float) -> void:
	if phase != Phase.MOVING:
		rest()
		return
	_spin += ((_goal - tilt) * STIFFNESS - _spin * DAMPING) * delta
	tilt += _spin * delta
	_place(tilt)
	if absf(_goal - tilt) < STILL and absf(_spin) < STILL * 10.0:
		settle()
		rest()


## Off its nail: down the wall onto the floor.
func slip() -> void:
	if is_down or phase == Phase.FALLING or not is_instance_valid(target):
		return
	phase = Phase.FALLING
	tilt = clampf(_goal, -KEEP_CROOKED, KEEP_CROOKED)
	EnvProp.drop_collision(target)
	var tween := create_tween()
	tween.tween_property(target, ^"global_transform", _fallen(), SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)
	Sfx.play_at(&"portrait_creak", global_position, -8.0, 0.1, 1.4)


func _landed() -> void:
	var at := target.global_position if is_instance_valid(target) else global_position
	Fx.puff(Vector3(at.x, floor_y + 0.1, at.z), Color(0.8, 0.76, 0.66), 10, 0.5)
	Sfx.play_at(&"weight_thud", at, -10.0, 0.1, 1.3)
	noise(at, EnvRules.NOISE_FALL, ReactionRules.SOURCE_FALL)
	mark_down()


## Its place crooked by [param angle] round its nail.
func _place(angle: float) -> void:
	if not is_instance_valid(target):
		return
	var nail := _rest * Vector3(0.0, outer.y * 0.5 + 0.04, 0.0)
	var turn := Transform3D(Basis(_rest.basis.z.normalized(), -angle), Vector3.ZERO)
	target.global_transform = Transform3D(Basis.IDENTITY, nail) * turn * Transform3D(Basis.IDENTITY, -nail) * _rest


## On the floor, leaning back against the wall, still a little crooked.
func _fallen() -> Transform3D:
	var half := outer.y * 0.5
	var wall := _rest.origin
	var out := -_rest.basis.z.normalized()
	var lean := Basis(_rest.basis.x.normalized(), LEAN)
	var crooked := Basis(_rest.basis.z.normalized(), -tilt * 0.5)
	var origin := Vector3(wall.x, floor_y + half * cos(LEAN) + 0.02, wall.z) + out * (half * sin(LEAN) + depth)
	return Transform3D(crooked * lean * _rest.basis, origin)


func _finish_down() -> void:
	if not is_instance_valid(target):
		return
	if _rest == Transform3D.IDENTITY:
		_rest = target.global_transform
	EnvProp.drop_collision(target)
	target.global_transform = _fallen()
