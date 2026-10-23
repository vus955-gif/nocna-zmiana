class_name EnvStatue
extends EnvProp
## A statue on its plinth (every "sculpture" piece of MIN_HEIGHT to
## MAX_HEIGHT standing on something - a base, a pedestal - outside the
## guardians' arenas; plan docs/superpowers/plans/2026-10-21-srodowisko-
## walka.md, backlog #22): a heavy hit (EnvRules.HEAVY) rocks it on its
## base; a crushing one, a blast or STATUE_HP of damage sends it over: it
## teeters for PROP_WARNING (its fall marked on the floor - it can hurt),
## then topples away from the blow, off its base and along the floor, and
## breaks - pieces of itself fly, it lies where it fell. Whatever stands in
## its way is crushed; the guard takes what his own blast would. Falling,
## it takes its collision with it; its base stays.

const KIT := &"sculpture"
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 2.6
const MIN_BASE := 0.3
## Rooms whose statues are part of a set piece (the Nereid temple's figures).
const SKIP_ROOMS: Array[StringName] = [&"greece_nereid_podium"]
const STATUE_HP := 90.0
const ROCK := 0.035
const ROCK_TIME := 0.5
const FALL_TIME := 0.6
const BLOW := 60.0
const GUARD_BLOW := 15.0
const PIECES := 8

var size := Vector3(1.0, 2.0, 1.0)
var floor_y: float = 0.0
## The way it falls (flat, world) once set going.
var away := Vector3.FORWARD

var _rest := Transform3D.IDENTITY
var _rock_left: float = 0.0
var _warn_left: float = 0.0
var _mark: GroundMark = null


static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece) or not piece is CollisionObject3D:
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			var piece_size: Vector3 = piece.get_meta(&"kit_size", Vector3.ONE)
			var spec := layer.room_spec(room_id)
			if piece_size.y <= MIN_HEIGHT or piece_size.y > MAX_HEIGHT or SKIP_ROOMS.has(room_id) or layer.skips(room_id):
				continue
			if spec == null or (piece as Node3D).global_position.y - spec.floor_y < MIN_BASE:
				continue
			layer.add_prop(make(piece as Node3D, room_id, piece_size, spec.floor_y))


static func make(piece: Node3D, room_id: StringName, piece_size: Vector3, floor_height: float) -> EnvStatue:
	var statue := EnvStatue.new()
	statue.name = "Statue"
	statue.id = EnvLayer.make_id(&"statue", room_id, piece.global_position)
	statue.room = room_id
	statue.target = piece
	statue.size = piece_size
	statue.floor_y = floor_height
	statue.transform = piece.global_transform
	var shape := BoxShape3D.new()
	shape.size = piece_size + Vector3(0.06, 0.04, 0.06)   # proud of its body: a shot meets it first
	statue.add_zone_round(shape, Transform3D(Basis.IDENTITY, Vector3(0.0, piece_size.y * 0.5, 0.0)), AABB(Vector3(-piece_size.x * 0.5, 0.0, -piece_size.z * 0.5), piece_size))
	return statue


func _ready() -> void:
	super()
	if is_instance_valid(target):
		_rest = target.global_transform


func _hit(info: DamageInfo) -> void:
	if phase == Phase.WARNING or phase == Phase.FALLING or not EnvRules.real(info):
		return
	taken += info.amount
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 0.8)
	var weight := EnvRules.weight(info)
	if info.explosive or weight >= EnvRules.CRUSHING or taken >= STATUE_HP:
		teeter(EnvBreak.flat_push(info))
		return
	if weight >= EnvRules.HEAVY:
		Sfx.play_at(&"bust_grind", info.position, -8.0, 0.1, 1.2)
		_rock_left = ROCK_TIME
		phase = Phase.MOVING
		wake()


## Sets it over toward [param toward]: it teeters, then falls.
func teeter(toward: Vector3 = Vector3.ZERO) -> void:
	if is_down or phase == Phase.WARNING or phase == Phase.FALLING:
		return
	settle()
	away = toward if toward.length() > 0.01 else -_rest.basis.z
	away = Vector3(away.x, 0.0, away.z).normalized()
	phase = Phase.WARNING
	_warn_left = EnvRules.PROP_WARNING
	_mark = GroundMark.lane(maxf(size.x, size.z) + 0.3, size.y + 0.5)
	add_child(_mark)
	var foot := _pivot()
	_mark.global_transform = Transform3D(Basis.looking_at(away, Vector3.UP), Vector3(foot.x, floor_y + 0.02, foot.z))
	Sfx.play_at(&"bust_grind", global_position + Vector3.UP * size.y * 0.5, -2.0, 0.1, 0.9)
	wake()


func recapture() -> void:
	if is_down or phase != Phase.IDLE or not is_instance_valid(target):
		return
	super()
	_rest = target.global_transform


func settle() -> void:
	_rock_left = 0.0
	if phase == Phase.MOVING:
		phase = Phase.IDLE
		if is_instance_valid(target):
			target.global_transform = _rest


func _physics_process(delta: float) -> void:
	match phase:
		Phase.MOVING:
			_rock_left -= delta
			_tilt(sin((ROCK_TIME - _rock_left) * 26.0) * ROCK * maxf(_rock_left / ROCK_TIME, 0.0), -_rest.basis.z)
			if _rock_left <= 0.0:
				settle()
				rest()
		Phase.WARNING:
			_warn_left -= delta
			if is_instance_valid(_mark):
				_mark.progress = 1.0 - _warn_left / (EnvRules.PROP_WARNING + FALL_TIME)
			_tilt(0.04 * (1.0 - _warn_left / EnvRules.PROP_WARNING) + sin(_warn_left * 60.0) * 0.01, away)
			if _warn_left <= 0.0:
				_fall()
		_:
			rest()


## The foot it falls over (world): its base's edge on the side it falls.
func _pivot() -> Vector3:
	return _foot(away)


## Its base's edge toward [param toward] (flat).
func _foot(toward: Vector3) -> Vector3:
	var half := absf(toward.dot(_rest.basis.x.normalized())) * size.x * 0.5 + absf(toward.dot(_rest.basis.z.normalized())) * size.z * 0.5
	return _rest.origin + toward * half


## Leaning [param angle] (rad) over its foot toward [param toward].
func _tilt(angle: float, toward: Vector3) -> void:
	if not is_instance_valid(target):
		return
	var flat := Vector3(toward.x, 0.0, toward.z).normalized()
	var axis := Vector3.UP.cross(flat).normalized()
	var foot := _foot(flat)
	target.global_transform = Transform3D(Basis.IDENTITY, foot) * Transform3D(Basis(axis, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -foot) * _rest


func _fall() -> void:
	phase = Phase.FALLING
	EnvProp.drop_collision(target)
	if not is_instance_valid(target):
		_landed()
		return
	var tween := create_tween()
	tween.tween_property(target, ^"global_transform", _fallen(), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


## Lying along the floor beyond its base, its foot by the base.
func _fallen() -> Transform3D:
	var axis := Vector3.UP.cross(away).normalized()
	var turned := Basis(axis, PI * 0.5) * _rest.basis
	var lift := minf(size.x, size.z) * 0.5
	var foot := _pivot()
	var spot := Vector3(foot.x, floor_y + lift, foot.z) + away * 0.2
	return Transform3D(turned, spot)


func _landed() -> void:
	if is_instance_valid(_mark):
		_mark.vanish(0.3)
		_mark = null
	var foot := _pivot()
	var center := Vector3(foot.x, floor_y, foot.z) + away * (size.y * 0.5 + 0.2)
	var frame := Transform3D(Basis.looking_at(away, Vector3.UP), center + Vector3.UP * 0.8)
	var lane := Vector3(maxf(size.x, size.z) + 0.3, 1.6, size.y + 0.4)
	for receiver in EnvStrike.in_box(self, frame, lane, [self]):
		EnvStrike.hit(receiver, BLOW, DamageInfo.Kind.BLUNT, credited(), foot, away, 6.0)
	var player := guard()
	if EnvStrike.guard_in_box(player, frame, lane):
		EnvStrike.hurt_guard(player, GUARD_BLOW, by_guard(), foot, away, 6.0, DamageInfo.Kind.BLUNT, credited())
	var made := 0
	if is_instance_valid(target):
		for view in EnvBreak.views(target):
			if made < PIECES:
				made += EnvBreak.shards(view, mini(3, PIECES - made), away + Vector3.UP)
	Fx.shatter(center + Vector3.UP * 0.3, ExhibitMaterial.Kind.MARBLE, GibPlanner.plan(ExhibitMaterial.Kind.MARBLE, 0.0, 100.0, false, 0.6), away, false)
	Fx.puff(center + Vector3.UP * 0.2, Color(0.82, 0.8, 0.74), 20, size.y * 0.5)
	Sfx.play_at(&"break_marble", center, 2.0)
	Sfx.play_at(&"weight_thud", center, 0.0)
	noise(center, EnvRules.NOISE_CRASH * 0.7, ReactionRules.SOURCE_BLAST)
	mark_down()
	rest()


func _finish_down() -> void:
	if not is_instance_valid(target):
		return
	if _rest == Transform3D.IDENTITY:
		_rest = target.global_transform
	if away == Vector3.FORWARD:
		away = -_rest.basis.z
		away = Vector3(away.x, 0.0, away.z).normalized()
	EnvProp.drop_collision(target)
	target.global_transform = _fallen()
