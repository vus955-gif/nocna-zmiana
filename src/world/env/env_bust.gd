class_name EnvBust
extends EnvProp
## A portrait bust on its plinth (every "bust_plinth" piece; plan
## docs/superpowers/plans/2026-10-21-srodowisko-walka.md): a light hit rocks
## it on its plinth, a heavy one (EnvRules.bust_topples: a punch, a shotgun,
## a rifle, a blast, or enough rounds) knocks it off - it tips over the
## plinth's edge away from the shot, drops and bursts on the floor into
## marble pieces of itself, a crash the exhibits hear. The plinth stands
## empty for the night (and the living busts of the wing were warned of).
## The bust is the plinth's look above its shaft (the top BUST_HEIGHT).

const KIT := &"bust_plinth"
const BUST_HEIGHT := 0.75
const ROCK := 0.06
const ROCK_TIME := 0.45
const TIP_TIME := 0.35
const DROP_GRAVITY := 14.0
const PIECES := 6
## It lands on what stands there.
const BLOW := 12.0
const BLOW_REACH := 0.6

## The bust's parts of the plinth's look (moved as one).
var parts: Array[Node3D] = []
## The plinth's height.
var height: float = 1.9
var floor_y: float = 0.0

var _holder: Node3D = null
var _rock_left: float = 0.0
var _rest: Array[Transform3D] = []


static func scan(layer: EnvLayer) -> void:
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != KIT or layer.owned.has(piece):
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if layer.skips(room_id):
				continue
			var bust := make(piece as Node3D, room_id)
			if bust != null:
				layer.add_prop(bust)


static func make(piece: Node3D, room_id: StringName) -> EnvBust:
	var look := piece.get_node_or_null(^"Visual") as Node3D
	if look == null:
		return null
	var size: Vector3 = piece.get_meta(&"kit_size", Vector3(0.7, 1.9, 0.7))
	var found := top_parts(look, piece.global_transform, size.y - BUST_HEIGHT)
	if found.is_empty():
		return null
	var bust := EnvBust.new()
	bust.name = "Bust"
	bust.id = EnvLayer.make_id(&"bust", room_id, piece.global_position)
	bust.room = room_id
	bust.target = piece
	bust.parts = found
	bust.height = size.y
	bust.floor_y = piece.global_position.y
	bust.transform = piece.global_transform
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 0.06, BUST_HEIGHT, size.z + 0.06)   # proud of the plinth's body round the bust
	var at := Transform3D(Basis.IDENTITY, Vector3(0.0, size.y - BUST_HEIGHT * 0.5, 0.0))
	bust.add_zone_round(box, at, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	return bust


## The parts of [param look] whose bounds lie wholly above [param from]
## (the piece's frame): direct children of the look, or the meshes of a
## merged greybox look.
static func top_parts(look: Node3D, frame: Transform3D, from: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var candidates: Array[Node] = look.get_children()
	if candidates.size() <= 1:
		candidates = look.find_children("*", "MeshInstance3D", true, false)
	for child in candidates:
		var node := child as Node3D
		if node == null:
			continue
		var views := EnvBreak.views(node)
		if views.is_empty():
			continue
		var box := EnvBreak.bounds(views, frame)
		if box.position.y >= from - 0.02:
			out.append(node)
	return out


func _hit(info: DamageInfo) -> void:
	if phase == Phase.FALLING or not EnvRules.real(info):
		return
	taken += info.amount
	if EnvRules.bust_topples(taken, info):
		topple(info)
		return
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.MARBLE, 0.6)
	Sfx.play_at(&"hit_marble", info.position, -6.0)
	_rock_left = ROCK_TIME
	phase = Phase.MOVING
	wake()


func recapture() -> void:
	if is_down or phase != Phase.IDLE:
		return
	super()
	_rest.clear()
	for each in parts:
		_rest.append(each.global_transform if is_instance_valid(each) else Transform3D.IDENTITY)


func settle() -> void:
	_rock_left = 0.0
	for i in parts.size():
		if is_instance_valid(parts[i]) and i < _rest.size():
			parts[i].global_transform = _rest[i]
	if phase == Phase.MOVING:
		phase = Phase.IDLE


func _ready() -> void:
	super()
	for each in parts:
		_rest.append(each.global_transform)


func _physics_process(delta: float) -> void:
	if phase != Phase.MOVING:
		rest()
		return
	_rock_left -= delta
	var lean := sin((ROCK_TIME - _rock_left) * 28.0) * ROCK * maxf(_rock_left / ROCK_TIME, 0.0)
	var pivot := global_transform * Vector3(0.0, height - BUST_HEIGHT, 0.0)
	var turn := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.BACK, lean), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	for i in parts.size():
		parts[i].global_transform = turn * _rest[i]
	if _rock_left <= 0.0:
		settle()
		rest()


## Knocks it off the plinth away from [param info]'s shot.
func topple(info: DamageInfo = null) -> void:
	if is_down or phase == Phase.FALLING:
		return
	settle()
	phase = Phase.FALLING
	var away := EnvBreak.flat_push(info) if info != null else -global_basis.z
	var edge := global_transform * Vector3(0.0, height - BUST_HEIGHT, 0.0) + away * 0.35
	_holder = Node3D.new()
	_holder.name = "Falling"
	add_child(_holder)
	_holder.global_transform = Transform3D(Basis.IDENTITY, edge)
	for each in parts:
		each.reparent(_holder)
	var axis := Vector3.UP.cross(away).normalized()
	var drop := height - BUST_HEIGHT + 0.1
	var landing := edge + away * 0.5 + Vector3.DOWN * drop
	var tween := create_tween()
	tween.tween_property(_holder, ^"global_transform", Transform3D(Basis(axis, 0.6), edge), TIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_holder, ^"global_transform", Transform3D(Basis(axis, 1.6), landing), sqrt(2.0 * drop / DROP_GRAVITY)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_shatter.bind(landing, away))
	Sfx.play_at(&"bust_grind", edge, -6.0, 0.1, 1.3)


func _shatter(at: Vector3, away: Vector3) -> void:
	var ground := Vector3(at.x, floor_y, at.z)
	var made := 0
	for each in parts:
		for view in EnvBreak.views(each):
			if made < PIECES:
				made += EnvBreak.shards(view, PIECES - made, away * 1.5 + Vector3.UP)
		each.visible = false
	if made == 0:
		EnvBreak.chunks(ground + Vector3.UP * 0.2, ExhibitMaterial.color(ExhibitMaterial.Kind.MARBLE), 6, 0.1, away)
	Fx.shatter(ground + Vector3.UP * 0.2, ExhibitMaterial.Kind.MARBLE, GibPlanner.plan(ExhibitMaterial.Kind.MARBLE, 0.0, 100.0, false, 0.3), away, false)
	Sfx.play_at(&"break_marble", ground)
	for receiver in EnvStrike.in_disc(self, ground, BLOW_REACH, 1.6, [self]):
		EnvStrike.hit(receiver, BLOW, DamageInfo.Kind.BLUNT, credited(), ground, away, 2.0)
	noise(ground, EnvRules.NOISE_FALL, ReactionRules.SOURCE_FALL)
	mark_down()


func _finish_down() -> void:
	for each in parts:
		if is_instance_valid(each):
			each.visible = false
