class_name ColossusFall
extends Node3D
## The Colossus's fall, after his last hit (Colossus._on_defeated hands his
## model over; the guardian itself is freed the same frame):
## 1. the eyes flare white and die, the chest cracks blaze, the stone
##    shudders (TREMBLE s);
## 2. he topples - standing: forward over his feet, pivoting on them, the
##    fall accelerating; seated: he slumps over his knees (TOPPLE s);
## 3. the impact: every part breaks into chunks of granite (physical, they
##    stay on the floor for the night), a wall of dust, the hall shakes.
## The seal and the shard are the keeper's (on the arena's reward marker).

signal shattered

const TREMBLE := 0.7
const TOPPLE := 1.35
## How far he tips: standing, seated (rad).
const TIP_STANDING := 1.45
const TIP_SEATED := 0.55
## Chunks per part.
const SLICES := 3
const GOLD := Color(1.0, 0.78, 0.36)

var standing := false
var remains: Node3D
var pieces: Array[RigidBody3D] = []

var _pivot: Node3D
var _model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _time: float = 0.0
var _done := false
var _light: OmniLight3D
var _push := Vector3.ZERO
var _guard: Node3D
var _at := Transform3D.IDENTITY
var _model_at := Transform3D.IDENTITY
var _greybox := false


## The fall of [param colossus] (takes his model now), [param info] = his
## last hit (the push of the fall).
static func make(colossus: Colossus, info: DamageInfo) -> ColossusFall:
	var fall := ColossusFall.new()
	fall.name = "ColossusFall"
	fall.standing = colossus.standing
	fall._guard = colossus.target
	fall._push = info.direction if info != null else Vector3.ZERO
	var model := colossus.rig.model
	var at := colossus.global_transform
	# the pivot: under his feet's line (standing) or his hips (seated)
	fall._at = at.translated_local(Vector3(0.0, 0.0, -0.3)) if fall.standing else at
	fall._model_at = model.global_transform if model.is_inside_tree() else at
	fall._pivot = Node3D.new()
	fall._pivot.name = "Pivot"
	fall.add_child(fall._pivot)
	# his hit zones go with him (their receivers are freed with the guardian)
	for hurtbox in model.find_children("*", "Hurtbox", true, false):
		hurtbox.get_parent().remove_child(hurtbox)
		hurtbox.queue_free()
	model.get_parent().remove_child(model)
	fall._pivot.add_child(model)
	fall._model = model
	fall._greybox = colossus.rig.greybox
	fall._meshes.assign(colossus.rig.meshes)
	return fall


func _ready() -> void:
	_pivot.global_transform = _at
	_model.global_transform = _model_at
	_light = OmniLight3D.new()
	_light.light_color = GOLD
	_light.omni_range = 14.0
	_light.light_energy = 0.0
	add_child(_light)
	_light.global_position = _model.global_position + Vector3.UP * (8.0 if standing else 5.0)
	_glow(&"glow", 0.0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time < TREMBLE:
		var k := _time / TREMBLE
		# the eyes flare and die; the cracks blaze; the stone shudders
		_glow_part("eyes", 2.2 * (1.0 - k))
		_glow_cracks(1.0 + 2.5 * k)
		_glow(&"awake", 1.0 - k)
		_light.light_energy = 6.0 * k
		_pivot.rotation.z = sin(_time * 70.0) * 0.006
		return
	var t := clampf((_time - TREMBLE) / TOPPLE, 0.0, 1.0)
	# gravity: slow to start, ever faster
	var tip := (TIP_STANDING if standing else TIP_SEATED) * t * t
	_pivot.rotation.x = -tip
	_pivot.rotation.z = 0.0
	_glow_part("eyes", 0.0)
	_light.light_energy = 6.0 * (1.0 - t * 0.5)
	if t >= 1.0:
		_shatter()


func _shatter() -> void:
	_done = true
	remains = Node3D.new()
	remains.name = "ColossusRemains"
	add_child(remains)
	var forward := -_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var center := _model.global_position
	for view in _meshes:
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
	_model.visible = false
	# the dust of the impact rolls along where he fell
	var reach := 9.0 if standing else 4.0
	for i in 8:
		var at := global_transform.origin + forward * reach * (float(i) / 7.0) + Vector3.UP * 0.4
		Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 4.0)
		Fx.impact(at, Vector3.UP, -1, 4.0)
	var mid := global_transform.origin + forward * reach * 0.5
	Sfx.play_at(&"lock_wall_collapse", mid + Vector3.UP, 4.0, 0.0)
	Sfx.play_at(&"rubble", mid, 3.0, 0.0)
	Sfx.play_at(&"colossus_slam", mid, 4.0, 0.0)
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(mid)
		if distance < 45.0:
			Events.shake_requested.emit(0.9 * (1.0 - distance / 45.0))
	var fade := create_tween()
	fade.tween_property(_light, "light_energy", 0.0, 1.5)
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
	var dims := (shape_basis * shard.size).abs().max(Vector3.ONE * 0.08)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = clampf(dims.x * dims.y * dims.z * 800.0, 2.0, 400.0)
	body.add_child(collider)
	body.add_child(view)
	remains.add_child(body)
	body.global_transform = Transform3D(turn, xform * shard.center)
	body.reset_physics_interpolation()
	var out := body.global_position - center
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else forward
	body.linear_velocity = forward * randf_range(1.0, 3.5) + out * randf_range(0.5, 2.5) + Vector3(0.0, randf_range(-1.0, 1.5), 0.0) + _push * 0.5
	body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	return body


func _glow(uniform: StringName, value: float) -> void:
	if _greybox:
		return
	for view in _meshes:
		if is_instance_valid(view) and not view.name.begins_with("crack_") and view.name != &"eyes":
			view.set_instance_shader_parameter(uniform, value)


func _glow_part(part_name: String, value: float) -> void:
	if _greybox:
		return
	for view in _meshes:
		if is_instance_valid(view) and String(view.name) == part_name:
			view.set_instance_shader_parameter(&"glow", value)


func _glow_cracks(value: float) -> void:
	if _greybox:
		return
	for view in _meshes:
		if is_instance_valid(view) and String(view.name).begins_with("crack_"):
			view.set_instance_shader_parameter(&"glow", value)
