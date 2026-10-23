class_name EnvBanner
extends EnvProp
## A banner or a hanging scroll (every "banner" piece: the Great Court's
## banners, the armour hall's scrolls; plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md): a hit sets it swaying from its rod and
## tears it a little; the BANNER_HITS-th hit, fire, a crushing hit or a
## blast (EnvRules.banner_falls) tears it off the rod - it drops and lies
## crumpled at the foot of the wall for the night. Cloth: it hurts nobody.

const KIT := &"banner"
const STIFFNESS := 14.0
const DAMPING := 2.2
const STILL := 0.003
const MAX_SWAY := 0.35
const DROP_TIME := 0.6
const CLOTH := Color(0.62, 0.16, 0.12)

## The piece's size, the sway (rad, round the rod) and its speed.
var size := Vector3(1.4, 5.5, 0.1)
var sway: float = 0.0
var sway_speed: float = 0.0
var hits: int = 0
var floor_y: float = 0.0

var _look: Node3D = null
var _rest := Transform3D.IDENTITY


static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece):
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if layer.skips(room_id):
				continue
			var spec := layer.room_spec(room_id)
			layer.add_prop(make(piece as Node3D, room_id, spec.floor_y if spec != null else 0.0))


static func make(piece: Node3D, room_id: StringName, floor_height: float) -> EnvBanner:
	var banner := EnvBanner.new()
	banner.name = "Banner"
	banner.id = EnvLayer.make_id(&"banner", room_id, piece.global_position)
	banner.room = room_id
	banner.target = piece
	banner.size = piece.get_meta(&"kit_size", banner.size)
	banner.floor_y = floor_height
	banner.transform = piece.global_transform
	var shape := BoxShape3D.new()
	shape.size = Vector3(banner.size.x, banner.size.y, maxf(banner.size.z, 0.12) + 0.06)
	banner.add_zone(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, banner.size.y * 0.5, 0.0)))
	return banner


func _ready() -> void:
	super()
	if is_instance_valid(target):
		_look = target.get_node_or_null(^"Visual") as Node3D
		if _look != null:
			_rest = _look.transform


func _hit(info: DamageInfo) -> void:
	if phase == Phase.FALLING or not EnvRules.real(info):
		return
	hits += 1
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.LINEN, 0.7)
	if EnvRules.banner_falls(hits, info):
		tear_down(info)
		return
	Sfx.play_at(&"hit_canvas", info.position, -8.0, 0.1, 0.8)
	var local_push := global_basis.inverse() * EnvBreak.flat_push(info)
	sway_speed += local_push.z * (0.8 + EnvRules.weight(info) * 1.6)
	phase = Phase.MOVING
	wake()


func recapture() -> void:
	if is_down or phase != Phase.IDLE or not is_instance_valid(target):
		return
	super()
	_look = target.get_node_or_null(^"Visual") as Node3D
	if _look != null:
		_rest = _look.transform


func settle() -> void:
	sway = 0.0
	sway_speed = 0.0
	if is_instance_valid(_look) and not is_down:
		_look.transform = _rest
	if phase == Phase.MOVING:
		phase = Phase.IDLE


func _physics_process(delta: float) -> void:
	if phase != Phase.MOVING:
		rest()
		return
	sway_speed += (-sway * STIFFNESS - sway_speed * DAMPING) * delta
	sway = clampf(sway + sway_speed * delta, -MAX_SWAY, MAX_SWAY)
	_place(sway)
	if absf(sway) < STILL and absf(sway_speed) < STILL * 10.0:
		settle()
		rest()


## Off its rod: it drops and crumples on the floor.
func tear_down(info: DamageInfo = null) -> void:
	if is_down or phase == Phase.FALLING:
		return
	settle()
	phase = Phase.FALLING
	Sfx.play_at(&"break_canvas", global_position + Vector3.UP * size.y, -6.0)
	if info != null and info.kind == DamageInfo.Kind.FIRE:
		Fx.puff(global_position + Vector3.UP * size.y * 0.6, Color(0.3, 0.27, 0.25), 14, 0.6)
	if _look == null:
		_landed()
		return
	var tween := create_tween()
	tween.tween_property(_look, ^"transform", _fallen(), DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


func _landed() -> void:
	var at := Vector3(global_position.x, floor_y, global_position.z)
	Fx.puff(at + Vector3.UP * 0.1, CLOTH.lightened(0.3), 8, 0.6)
	noise(at, EnvRules.NOISE_FALL * 0.5, ReactionRules.SOURCE_FALL)
	mark_down()


## The look swung by [param angle] round its rod (the piece's top, along X).
func _place(angle: float) -> void:
	if not is_instance_valid(_look):
		return
	var rod := Vector3(0.0, size.y, 0.0)
	_look.transform = Transform3D(Basis.IDENTITY, rod) * Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -rod) * _rest


## Crumpled at the foot of its wall: squashed to a heap, a little out.
func _fallen() -> Transform3D:
	var height := maxf(size.y, 0.5)
	var drop := global_position.y - floor_y
	var squash := clampf(0.35 / height, 0.04, 1.0)
	return Transform3D(_rest.basis.scaled(Vector3(1.0, squash, 1.0)), _rest.origin * Vector3(1.0, squash, 1.0) + Vector3(0.0, -drop, -0.25))


func _finish_down() -> void:
	if _look == null and is_instance_valid(target):
		_look = target.get_node_or_null(^"Visual") as Node3D
		if _look != null:
			_rest = _look.transform
	if _look != null:
		_look.transform = _fallen()
