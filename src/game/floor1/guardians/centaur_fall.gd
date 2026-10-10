class_name CentaurFall
extends Node3D
## The Centaur's fall, after its last hit (Centaur._on_defeated hands over
## its rig and model; the guardian itself is freed the same frame):
## 1. the eyes flare and die, the chest cracks blaze, the marble shudders
##    (TREMBLE s) - and it still runs on, its momentum fading;
## 2. it stumbles: the fore legs buckle (knees to the floor, the barrel
##    pitching nose-down), the hind legs fold under it, it sinks and rolls
##    onto its side, the torso slumping, the head dropping (COLLAPSE s);
## 3. it breaks: every part into chunks of marble (physical; they lie on
##    the floor for the night), dust, the gallery shakes.
## The seal and the shard are the keeper's (on the arena's reward marker).

signal shattered

const TREMBLE := 0.5
const COLLAPSE := 1.4
## Chunks per part.
const SLICES := 2
const GOLD := Color(1.0, 0.82, 0.5)

var remains: Node3D
var pieces: Array[RigidBody3D] = []

var _rig: CentaurRig
var _pivot: Node3D
var _model_at := Transform3D.IDENTITY
var _at := Transform3D.IDENTITY
var _velocity := Vector3.ZERO
var _guard: Node3D
var _push := Vector3.ZERO
var _time: float = 0.0
var _done := false
var _pose := CentaurRig.Pose.new()
var _start: Array[Vector3] = []
var _light: OmniLight3D


## The fall of [param centaur] (takes its model now), [param info] = its
## last hit (the push of the fall).
static func make(centaur: Centaur, info: DamageInfo) -> CentaurFall:
	var fall := CentaurFall.new()
	fall.name = "CentaurFall"
	fall._rig = centaur.rig
	fall._guard = centaur.target
	fall._push = info.direction if info != null else Vector3.ZERO
	fall._velocity = Vector3(centaur.velocity.x, 0.0, centaur.velocity.z)
	fall._at = centaur.global_transform
	var model := centaur.rig.model
	fall._model_at = model.global_transform if model.is_inside_tree() else centaur.global_transform
	for leg in 4:
		var hoof := centaur.rig.part("hoof_" + CentaurRig.LEGS[leg])
		fall._start.append(centaur.to_local(hoof.global_position) if hoof.is_inside_tree() else CentaurGait.NEUTRAL[leg])
	fall._pivot = Node3D.new()
	fall._pivot.name = "Pivot"
	fall.add_child(fall._pivot)
	# its hit zones go with it (their receivers are freed with the guardian)
	for hurtbox in model.find_children("*", "Hurtbox", true, false):
		hurtbox.get_parent().remove_child(hurtbox)
		hurtbox.queue_free()
	model.get_parent().remove_child(model)
	fall._pivot.add_child(model)
	return fall


func _ready() -> void:
	_pivot.global_transform = _at
	_rig.model.global_transform = _model_at
	_light = OmniLight3D.new()
	_light.light_color = GOLD
	_light.omni_range = 8.0
	_light.light_energy = 0.0
	add_child(_light)
	_light.global_position = _at.origin + Vector3.UP * 2.2


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	# it runs on, slowing (marble skidding on marble)
	_velocity = _velocity.move_toward(Vector3.ZERO, 9.0 * delta)
	_pivot.global_position += _velocity * delta
	var p := _pose
	p.legs_ik = 1.0
	p.eyes = 1.0
	p.javelin_shown[1] = _rig.part("javelin").visible
	p.javelin_shown[0] = _rig.left_javelin != null and _rig.left_javelin.visible
	p.slab_on = _rig.part("slab").visible
	if _time < TREMBLE:
		var k := _time / TREMBLE
		p.eyes = 1.0 - k
		p.cracks = 1.0 + 2.0 * k
		p.shiver = 0.02
		_light.light_energy = 4.0 * k
		for leg in 4:
			p.hooves[leg] = _start[leg]
		_rig.apply(p, delta)
		return
	var t := clampf((_time - TREMBLE) / COLLAPSE, 0.0, 1.0)
	p.eyes = 0.0
	p.cracks = 3.0 * (1.0 - t * 0.5)
	p.shiver = 0.0
	_light.light_energy = 4.0 * (1.0 - t)
	# the fore legs buckle first (nose down), the hind legs fold, it rolls
	var buckle := MotionClip.eased(MotionClip.IN, clampf(t / 0.45, 0.0, 1.0))
	var fold := MotionClip.eased(MotionClip.IN_OUT, clampf((t - 0.3) / 0.45, 0.0, 1.0))
	var roll := MotionClip.eased(MotionClip.IN, clampf((t - 0.62) / 0.38, 0.0, 1.0))
	p.barrel = Vector3(0.0, lerpf(CentaurRig.BARREL_REST.y, 0.92, buckle) - 0.42 * fold - 0.1 * roll, -0.15 * buckle)
	p.barrel_turn = Vector3(-0.32 * buckle * (1.0 - fold) - 0.05 * fold, 0.0, 1.2 * roll)
	for leg in 4:
		var side := -1.0 if leg % 2 == 0 else 1.0
		var tucked := Vector3(side * 0.24, 0.12, -0.32) if leg < 2 else Vector3(side * 0.28, 0.12, 0.42)
		var weight := buckle if leg < 2 else fold
		p.hooves[leg] = _start[leg].lerp(tucked, weight)
		p.hoof_pitch[leg] = -1.3 * weight
	p.torso = Vector3(-0.6 * buckle + 0.2 * roll, 0.0, -0.3 * roll)
	p.neck = Vector3(-0.55 * fold, 0.3 * roll, 0.0)
	p.tail = Vector2(-0.4 * fold, 0.3 * roll)
	_rig.apply(p, delta)
	if t >= 1.0:
		_shatter()


func _shatter() -> void:
	_done = true
	remains = Node3D.new()
	remains.name = "CentaurRemains"
	add_child(remains)
	var center := _rig.part("barrel").global_position
	var forward := _velocity.normalized() if _velocity.length() > 0.1 else -_pivot.global_basis.z
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
	for i in 6:
		var at := center + Vector3(randf_range(-1.0, 1.0), -0.3, randf_range(-1.2, 1.2))
		Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 3.5)
		Fx.impact(at, Vector3.UP, -1, 3.0)
	Sfx.play_at(&"break_marble", center, 3.0, 0.0)
	Sfx.play_at(&"rubble", center, 2.0, 0.0)
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(center)
		if distance < 30.0:
			Events.shake_requested.emit(0.6 * (1.0 - distance / 30.0))
	var fade := create_tween()
	fade.tween_property(_light, "light_energy", 0.0, 1.2)
	shattered.emit()


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
	body.mass = clampf(dims.x * dims.y * dims.z * 800.0, 1.0, 120.0)
	body.add_child(collider)
	body.add_child(view)
	remains.add_child(body)
	body.global_transform = Transform3D(turn, xform * shard.center)
	body.reset_physics_interpolation()
	var out := body.global_position - center
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else forward
	body.linear_velocity = forward * randf_range(0.5, 2.0) + out * randf_range(0.5, 2.0) + Vector3(0.0, randf_range(0.0, 1.5), 0.0) + _push * 0.5
	body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	return body
