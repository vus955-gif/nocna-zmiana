class_name LamassuFall
extends Node3D
## The Lamassu's fall, after its last hit (Lamassu._on_defeated hands over
## its rig and model; the guardian itself is freed the same frame):
## 1. the eyes flare and die, the cracks blaze, the stone shudders where it
##    stands (TREMBLE s);
## 2. it kneels: the fore legs buckle (knees to the floor, the body pitching
##    nose-down, the head dropping), the wings break off and fall, the hind
##    legs fold and it sinks (KNEEL s);
## 3. it breaks: every part into chunks of alabaster (physical; they lie on
##    the floor for the night), dust, the court shakes.
## The seal and the shard are the keeper's (on the arena's reward marker).

signal shattered

const TREMBLE := 0.5
const KNEEL := 1.6
## When in the kneeling the wings break off (share of KNEEL).
const WINGS_OFF := 0.5
## Chunks per part.
const SLICES := 2
const GLOW := Color(1.0, 0.6, 0.25)

var remains: Node3D
var pieces: Array[RigidBody3D] = []
## The wings, fallen whole.
var wings: Array[RigidBody3D] = []

var _rig: LamassuRig
var _pivot: Node3D
var _model_at := Transform3D.IDENTITY
var _at := Transform3D.IDENTITY
var _guard: Node3D
var _push := Vector3.ZERO
var _time: float = 0.0
var _done := false
var _wings_off := false
var _pose := LamassuRig.Pose.new()
var _start: Array[Vector3] = []
var _light: OmniLight3D


## The fall of [param lamassu] (takes its model now), [param info] = its
## last hit (the push of the fall).
static func make(lamassu: Lamassu, info: DamageInfo) -> LamassuFall:
	var fall := LamassuFall.new()
	fall.name = "LamassuFall"
	fall._rig = lamassu.rig
	fall._guard = lamassu.target
	fall._push = info.direction if info != null else Vector3.ZERO
	fall._at = lamassu.global_transform
	var model := lamassu.rig.model
	fall._model_at = model.global_transform if model.is_inside_tree() else lamassu.global_transform
	for leg in 4:
		fall._start.append(lamassu.to_local(lamassu.rig.contact(leg)) if model.is_inside_tree() else LamassuGait.NEUTRAL[leg])
	fall._pivot = Node3D.new()
	fall._pivot.name = "Pivot"
	fall.add_child(fall._pivot)
	# its hit zones go with it (their receivers are freed with the guardian)
	for hurtbox in model.find_children("*", "Hurtbox", true, false):
		hurtbox.get_parent().remove_child(hurtbox)
		hurtbox.queue_free()
	for light in model.find_children("*", "OmniLight3D", true, false):
		light.get_parent().remove_child(light)
		light.queue_free()
	model.get_parent().remove_child(model)
	fall._pivot.add_child(model)
	return fall


func _ready() -> void:
	_pivot.global_transform = _at
	_rig.model.global_transform = _model_at
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	add_child(_light)
	_light.global_position = _at.origin + Vector3.UP * 2.0


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var p := _pose
	p.legs_ik = 1.0
	p.eyes = 1.0
	for leg in 4:
		p.contacts[leg] = _start[leg]
		p.hoof_pitch[leg] = 0.0
	if _time < TREMBLE:
		var k := _time / TREMBLE
		p.eyes = 1.0 - k
		p.cracks = 1.0 + 1.5 * k
		p.shiver = 0.02
		p.body = LamassuRig.BODY_REST
		p.body_turn = Vector3.ZERO
		p.head = Vector3(0.1 * (1.0 - k), 0.0, 0.0)
		_light.light_energy = 5.0 * k
		if not _rig.cracked:
			_rig.crack(true)
		_rig.apply(p, delta)
		return
	var t := clampf((_time - TREMBLE) / KNEEL, 0.0, 1.0)
	p.eyes = 0.0
	p.cracks = 2.5 * (1.0 - t * 0.4)
	p.shiver = 0.004
	_light.light_energy = 5.0 * (1.0 - t)
	# the fore legs buckle first (nose down, the knees to the floor), the
	# wings break off, the hind legs fold and it sinks
	var buckle := MotionClip.eased(MotionClip.IN, clampf(t / 0.45, 0.0, 1.0))
	var fold := MotionClip.eased(MotionClip.IN_OUT, clampf((t - 0.4) / 0.5, 0.0, 1.0))
	p.body = LamassuRig.BODY_REST + Vector3(0.0, -0.55 * buckle - 0.5 * fold, -0.2 * buckle)
	p.body_turn = Vector3(-0.42 * buckle * (1.0 - 0.7 * fold) - 0.04 * fold, 0.0, 0.0)
	for leg in 4:
		var side := -1.0 if leg % 2 == 0 else 1.0
		# the fore hooves fold back under the chest, the hind ones under the
		# haunches
		var tucked := Vector3(side * 0.41, 0.0, -0.3) if leg < 2 else Vector3(side * 0.41, 0.0, 0.55)
		var weight := buckle if leg < 2 else fold
		p.contacts[leg] = _start[leg].lerp(tucked, weight)
		p.hoof_pitch[leg] = -1.1 * weight
	p.head = Vector3(-0.5 * buckle - 0.2 * fold, 0.15 * fold, 0.0)
	for sidex in 2:
		p.wing_spread[sidex] = 0.6 * buckle * (1.0 - fold)
		p.wing_raise[sidex] = -0.3 * buckle
	p.tail = Vector2(-0.3 * fold, 0.0)
	_rig.apply(p, delta)
	if not _wings_off and t >= WINGS_OFF:
		_wings_off = true
		_drop_wings()
	if t >= 1.0:
		_shatter()


func _drop_wings() -> void:
	for side in 2:
		var out := _pivot.global_basis.x * (-1.0 if side == 0 else 1.0)
		for piece in _rig.drop_wing(side, out * 1.6 + Vector3.UP * 0.8 + _push * 0.4):
			piece.angular_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5))
			wings.append(piece)
		var at := _pivot.global_position + out * 0.7 + Vector3.UP * 2.2
		Fx.impact(at, out, ExhibitMaterial.Kind.MARBLE, 2.5)
	Sfx.play_at(&"break_marble", _pivot.global_position + Vector3.UP * 2.2, 1.0)
	Sfx.play_at(&"relief_crack", _pivot.global_position + Vector3.UP * 2.2, 0.0)
	_shake(0.3, 20.0)


func _shatter() -> void:
	_done = true
	remains = Node3D.new()
	remains.name = "LamassuRemains"
	add_child(remains)
	var center := _rig.part("body").global_position
	var forward := -_pivot.global_basis.z
	for view in _rig.meshes:
		if not is_instance_valid(view) or not view.is_visible_in_tree() or view.mesh == null:
			continue
		var xform := view.global_transform
		var materials: Array = []
		for i in view.mesh.get_surface_count():
			var source := view.get_active_material(i)
			materials.append(ArtLibrary.debris_material(source) if source != null else null)
		var cuts: Array = MeshShards.slices(view.mesh, SLICES) if view.mesh is ArrayMesh else [MeshShards.whole(view.mesh)]
		for shard: MeshShards.Piece in cuts:
			pieces.append(_piece(shard, materials, xform, center, forward))
	_rig.model.visible = false
	for i in 7:
		var at := center + Vector3(randf_range(-1.0, 1.0), -0.6, randf_range(-1.6, 1.6))
		Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 3.5)
		Fx.impact(at, Vector3.UP, -1, 3.0)
	Sfx.play_at(&"break_marble", center, 3.0, 0.0)
	Sfx.play_at(&"rubble", center, 2.0, 0.0)
	_shake(0.6, 30.0)
	var fade := create_tween()
	fade.tween_property(_light, "light_energy", 0.0, 1.2)
	shattered.emit()


func _shake(trauma: float, reach: float) -> void:
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(_pivot.global_position)
		if distance < reach:
			Events.shake_requested.emit(trauma * (1.0 - distance / reach))


func _piece(shard: MeshShards.Piece, materials: Array, xform: Transform3D, center: Vector3, forward: Vector3) -> RigidBody3D:
	var turn := xform.basis.orthonormalized()
	var view := MeshInstance3D.new()
	view.mesh = shard.mesh
	var shape_basis := turn.inverse() * xform.basis
	view.transform = Transform3D(shape_basis, shape_basis * shard.offset)
	var picked := MeshShards.materials_for(shard, materials)
	for i in picked.size():
		if picked[i] != null:
			view.set_surface_override_material(i, picked[i])
	var dims := (shape_basis * shard.size).abs().max(Vector3.ONE * 0.06)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = clampf(dims.x * dims.y * dims.z * 900.0, 1.0, 150.0)
	body.add_child(collider)
	body.add_child(view)
	remains.add_child(body)
	body.global_transform = Transform3D(turn, xform * shard.center)
	body.reset_physics_interpolation()
	var out := body.global_position - center
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else forward
	body.linear_velocity = out * randf_range(0.4, 1.8) + Vector3(0.0, randf_range(0.0, 1.2), 0.0) + _push * 0.4
	body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	return body
