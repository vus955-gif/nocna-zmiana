class_name EnvLamp
extends EnvProp
## A hanging lamp (plan docs/superpowers/plans/2026-10-21-srodowisko-
## walka.md): the pendants (ceiling_lamp fixtures), the bare bulbs on their
## flex, the paper lanterns (lantern pieces). A hit swings it like a
## pendulum from its mount - its light swings along, shadows sway round the
## room - and it settles again. A bulb bursts at the first real hit: dark
## at once. A pendant or a lantern comes down once it has taken its share
## (EnvRules.lamp_falls): a pendant creaks first (PROP_WARNING, its spot
## marked on the floor, sparks at the mount), its light dies as the flex
## tears, it drops and smashes where it was marked (a small blow round it);
## a paper lantern just flutters down. Out for the night: dark, left dark
## by any switch of its circuit and by the exhibits' light model
## (EnvLayer.put_out).

## What hangs, and how it is found: fixtures (in the level's lights, the
## Light3D in their meta "light") and lantern pieces (their lamp found
## beside them).
const FIXTURES: Array[StringName] = [&"ceiling_lamp", &"bulb"]
const PIECE := &"lantern"
## Its body's size by kind (the zone), the blow of a fall (exhibits, the
## guard) and its reach.
const BODY := {&"ceiling_lamp": Vector3(0.7, 0.75, 0.7), &"bulb": Vector3(0.36, 0.36, 0.36), &"lantern": Vector3(0.6, 0.9, 0.6)}
const CRUSH := {&"ceiling_lamp": [25.0, 10.0, 0.9], &"bulb": [0.0, 0.0, 0.0], &"lantern": [0.0, 0.0, 0.0]}
## Pendulum: gravity, damping (1/s), when it counts as still, the swing's cap (rad).
const GRAVITY := 9.8
const DAMPING := 0.9
const STILL := 0.004
const MAX_ANGLE := 0.45
## A drop is quicker than free fall (a game's reading of a falling lamp).
const DROP_GRAVITY := 16.0
const PAPER := Color(0.85, 0.25, 0.15)

## &"ceiling_lamp", &"bulb" or &"lantern".
var kind: StringName = &"ceiling_lamp"
var light: Light3D = null
## The mount (world) it swings from, and the rope's length (m).
var pivot := Vector3.ZERO
var length: float = 1.0
## Swing angles (rad) round world X and Z, and their speeds.
var angle := Vector2.ZERO
var speed := Vector2.ZERO
## Where it comes to rest on the floor (world y).
var floor_y: float = 0.0

var _rest := Transform3D.IDENTITY
var _light_rest := Transform3D.IDENTITY
var _warn_left: float = 0.0
var _mark: GroundMark = null


static func scan(layer: EnvLayer) -> void:
	var lights := layer.lights_root()
	if lights != null:
		for node in lights.get_children():
			var kit: StringName = node.get_meta(&"kit", &"")
			if not FIXTURES.has(kit) or layer.owned.has(node):
				continue
			var room_id: StringName = node.get_meta(&"kit_room", &"")
			var lamp_light := node.get_meta(&"light") as Light3D if node.has_meta(&"light") else null
			if lamp_light == null or layer.skips(room_id) or lamp_light.is_in_group(LightSpec.EMERGENCY):
				continue
			layer.add_prop(make(node as Node3D, kit, lamp_light, room_id, layer))
	for root in layer.piece_roots():
		for piece in root.get_children():
			if piece.get_meta(&"kit", &"") != PIECE or layer.owned.has(piece):
				continue
			var room_id: StringName = piece.get_meta(&"kit_room", &"")
			if layer.skips(room_id):
				continue
			var size: Vector3 = piece.get_meta(&"kit_size", BODY[PIECE])
			var lamp_light := layer.light_near((piece as Node3D).global_position + Vector3.UP * size.y * 0.5, 1.0)
			layer.add_prop(make(piece as Node3D, PIECE, lamp_light, room_id, layer))


static func make(node: Node3D, kit: StringName, lamp_light: Light3D, room_id: StringName, layer: EnvLayer = null) -> EnvLamp:
	var lamp := EnvLamp.new()
	lamp.name = "Lamp"
	lamp.kind = kit
	lamp.id = EnvLayer.make_id(&"lamp", room_id, node.global_position)
	lamp.room = room_id
	lamp.target = node
	lamp.light = lamp_light
	lamp.transform = Transform3D(Basis.IDENTITY, node.global_position)
	var body: Vector3 = BODY.get(kit, Vector3.ONE * 0.5)
	if kit == PIECE:
		body = node.get_meta(&"kit_size", body)
	var spec := layer.room_spec(room_id) if layer != null else null
	var ceiling := spec.ceiling_y if spec != null else node.global_position.y + 1.0
	lamp.floor_y = spec.floor_y if spec != null else 0.0
	# a fixture hangs from over its origin (its fitting reaches up to its
	# mount); a lantern hangs on a cord from the ceiling
	var top := node.global_position.y + (LevelKit.FIXTURE_SIZES.get(kit, body) as Vector3).y if kit != PIECE else ceiling
	lamp.pivot = Vector3(node.global_position.x, minf(maxf(top, node.global_position.y + 0.3), ceiling), node.global_position.z)
	lamp.length = maxf(lamp.pivot.y - node.global_position.y, 0.3)
	var shape := BoxShape3D.new()
	shape.size = body
	var middle := Vector3(0.0, body.y * 0.5, 0.0) if kit == PIECE else Vector3(0.0, body.y * 0.25, 0.0)
	lamp.add_zone(shape, Transform3D(Basis.IDENTITY, middle))
	return lamp


func _ready() -> void:
	super()
	if is_instance_valid(target):
		_rest = target.global_transform
	if is_instance_valid(light):
		_light_rest = light.global_transform


func _hit(info: DamageInfo) -> void:
	if phase == Phase.WARNING or phase == Phase.FALLING:
		return
	if not EnvRules.real(info):
		return
	taken += info.amount
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.5)
	if EnvRules.lamp_falls(kind, taken, info):
		if EnvRules.lamp_bursts(kind):
			burst()
		else:
			come_down()
		return
	var push := EnvBreak.flat_push(info) * EnvRules.swing_speed(info)
	speed += Vector2(-push.z, push.x)   # a turn round X swings it toward -Z, round Z toward +X
	phase = Phase.MOVING
	wake()


## A bulb's end: dark at once, a tinkle of glass.
func burst() -> void:
	if is_down:
		return
	var at := global_position
	_lights_out()
	EnvBreak.chunks(at, EnvBreak.GLASS_COLOR, 3, 0.03, Vector3.ZERO)
	Fx.flash(at, Color(1.0, 0.85, 0.6), 1.2, 3.0, 0.08)
	Sfx.play_at(&"glass_break", at, -12.0, 0.1, 1.5)
	noise(at, EnvRules.NOISE_FALL * 0.5, ReactionRules.SOURCE_FALL)
	mark_down()


## Comes down: a pendant creaks first (its spot marked on the floor), a
## lantern flutters down at once.
func come_down() -> void:
	if is_down or phase == Phase.WARNING or phase == Phase.FALLING:
		return
	settle()
	if _crush()[0] > 0.0:
		phase = Phase.WARNING
		_warn_left = EnvRules.PROP_WARNING
		_mark = GroundMark.disc(float(_crush()[2]))
		add_child(_mark)
		_mark.global_transform = Transform3D(Basis.IDENTITY, Vector3(global_position.x, floor_y + 0.02, global_position.z))
		Fx.impact(pivot, Vector3.DOWN, ExhibitMaterial.Kind.METAL, 0.8)
		Sfx.play_at(&"chain_clank", pivot, -6.0, 0.1, 1.3)
		wake()
		return
	_fall()


func recapture() -> void:
	if is_down or phase != Phase.IDLE or not is_instance_valid(target):
		return
	super()
	_rest = target.global_transform
	if is_instance_valid(light):
		_light_rest = light.global_transform


## A lamp's prop stands upright where the lamp hangs.
func _frame_of(piece: Node3D) -> Transform3D:
	return Transform3D(Basis.IDENTITY, piece.global_position)


func settle() -> void:
	angle = Vector2.ZERO
	speed = Vector2.ZERO
	if is_instance_valid(target) and not is_down:
		target.global_transform = _rest
	if is_instance_valid(light) and not is_down:
		light.global_transform = _light_rest
	if phase == Phase.MOVING:
		phase = Phase.IDLE


func _physics_process(delta: float) -> void:
	match phase:
		Phase.MOVING:
			_swing(delta)
		Phase.WARNING:
			_warn_left -= delta
			if is_instance_valid(_mark):
				_mark.progress = 1.0 - _warn_left / (EnvRules.PROP_WARNING + _drop_time())
			if is_instance_valid(target):
				var shiver := Basis(Vector3.RIGHT, sin(_warn_left * 90.0) * 0.03)
				target.global_transform = _about_pivot(shiver) * _rest
			if _warn_left <= 0.0:
				_fall()
		_:
			rest()


func _swing(delta: float) -> void:
	var stiffness := GRAVITY / length
	speed += (-angle * stiffness - speed * DAMPING) * delta
	angle += speed * delta
	angle = angle.clamp(Vector2.ONE * -MAX_ANGLE, Vector2.ONE * MAX_ANGLE)
	var turn := Basis(Vector3.RIGHT, angle.x) * Basis(Vector3.BACK, angle.y)
	if is_instance_valid(target):
		target.global_transform = _about_pivot(turn) * _rest
	if is_instance_valid(light) and light.visible:
		light.global_transform = _about_pivot(turn) * _light_rest
	if angle.length() < STILL and speed.length() < STILL * 4.0:
		settle()
		rest()


## The turn [param turn] about the mount, as a transform of the world.
func _about_pivot(turn: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)


## [exhibits' blow, the guard's, reach] of a fall.
func _crush() -> Array:
	return CRUSH.get(kind, [0.0, 0.0, 0.0])


func _drop_time() -> float:
	return sqrt(2.0 * maxf(global_position.y - floor_y, 0.1) / DROP_GRAVITY)


func _fall() -> void:
	phase = Phase.FALLING
	wake()
	_lights_out(false)
	_drop_cord()
	Sfx.play_at(&"chain_break", pivot, -6.0, 0.1, 1.2)
	if not is_instance_valid(target):
		_landed()
		return
	var tween := create_tween()
	tween.tween_property(target, ^"global_transform", _fallen(), _drop_time()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


## Where it lies when down: on the floor under its mount, tipped over.
func _fallen() -> Transform3D:
	var lift := 0.12 if kind == PIECE else 0.25
	var tip := Basis(Vector3.BACK, 1.2 if kind == PIECE else 1.35) * _rest.basis
	if kind == PIECE:
		tip = tip.scaled(Vector3(1.0, 0.6, 1.0))   # crumpled paper
	return Transform3D(tip, Vector3(_rest.origin.x, floor_y + lift, _rest.origin.z))


func _landed() -> void:
	var at := Vector3(global_position.x, floor_y, global_position.z)
	var blow: Array = _crush()
	if is_instance_valid(_mark):
		_mark.vanish(0.3)
		_mark = null
	if float(blow[0]) > 0.0:
		for receiver in EnvStrike.in_disc(self, at, float(blow[2]), 1.6, [self]):
			EnvStrike.hit(receiver, float(blow[0]), DamageInfo.Kind.BLUNT, credited(), at, Vector3.ZERO, 3.0)
		var player := guard()
		if EnvStrike.guard_in_disc(player, at, float(blow[2]), 1.6):
			EnvStrike.hurt_guard(player, float(blow[1]), by_guard(), at, Vector3.ZERO, 4.0, DamageInfo.Kind.BLUNT, credited())
		EnvBreak.chunks(at + Vector3.UP * 0.2, EnvBreak.GLASS_COLOR, 5, 0.05, Vector3.ZERO)
		Fx.impact(at + Vector3.UP * 0.1, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.6)
		Sfx.play_at(&"glass_break", at, -3.0, 0.1)
		Sfx.play_at(&"weight_thud", at, -6.0)
	else:
		Fx.puff(at + Vector3.UP * 0.2, PAPER.lightened(0.4), 8, 0.4)
		Sfx.play_at(&"hit_canvas", at, -8.0)
	_lights_out()
	noise(at, EnvRules.NOISE_FALL, ReactionRules.SOURCE_FALL)
	mark_down()
	rest()


## A lantern's cord up to the ceiling stays behind (hidden: it is torn).
func _drop_cord() -> void:
	if kind != PIECE or not is_instance_valid(target):
		return
	var body: Vector3 = target.get_meta(&"kit_size", BODY[PIECE])
	var top := target.global_position.y + body.y + 0.15
	for view in EnvBreak.views(target):
		var box := view.global_transform * view.get_aabb()
		if box.end.y > top:
			view.visible = false


## Its lamp out (and, when [param glow] too, the fitting's glow).
func _lights_out(glow: bool = true) -> void:
	if is_instance_valid(light) and layer != null and layer.has_method(&"put_out"):
		layer.call(&"put_out", light)
	elif is_instance_valid(light):
		light.visible = false
	if glow and is_instance_valid(target):
		LevelKit.set_lit(target, false)
		target.set_meta(&"env_broken", true)


func _finish_down() -> void:
	_lights_out()
	if is_instance_valid(target) and kind != &"bulb":
		if _rest == Transform3D.IDENTITY:
			_rest = target.global_transform
		_drop_cord()
		target.global_transform = _fallen()
