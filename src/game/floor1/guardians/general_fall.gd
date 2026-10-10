class_name GeneralFall
extends Node3D
## The General's fall, after his last hit (General._on_defeated hands over
## his rig and model; the guardian itself is freed the same frame):
## 1. the ember eyes flare and the armour shudders (TREMBLE s);
## 2. he kneels (KNEEL s): the hips sink, one knee to the gravel, the torso
##    bows, and he plants the nodachi point-down before him, both fists on
##    the hilt; the eyes die;
## 3. the armour falls apart: part after part comes off from the helmet
##    down (SHED_GAP s apart) as a rigid body on DEBRIS that lies where it
##    fell for the night; the sword stays planted in the gravel.
## The shard is the keeper's (on the arena's reward marker). On later
## nights the keeper dresses the arena with the kneeling armour
## (General.make_fallen).

signal shed

const TREMBLE := 0.4
const KNEEL := 1.3
const SHED_GAP := 0.11
## The parts, from the helmet down (the sword stays).
const SHED_ORDER: Array[String] = ["head", "sode_l", "sode_r", "hand_l", "hand_r", "forearm_l", "forearm_r",
	"upperarm_l", "upperarm_r", "bow", "arrow", "quiver", "kusazuri_f", "kusazuri_b", "kusazuri_l", "kusazuri_r",
	"saya", "torso", "foot_l", "foot_r", "shin_l", "shin_r", "thigh_l", "thigh_r", "pelvis"]
const EMBER := Color(1.0, 0.55, 0.2)

var remains: Node3D
var pieces: Array[RigidBody3D] = []
## True once every part has come off.
var done := false

var _rig: GeneralRig
var _pivot: Node3D
var _model_at := Transform3D.IDENTITY
var _at := Transform3D.IDENTITY
var _guard: Node3D
var _push := Vector3.ZERO
var _time: float = 0.0
var _start: GeneralRig.Pose
var _kneel: GeneralRig.Pose
var _pose := GeneralRig.Pose.new()
var _shed_next: float = 0.0
var _shed_index: int = 0
var _light: OmniLight3D


## The fall of [param general] (takes his model now), [param info] = his
## last hit (the push of the fall). [param drop]: how high over the floor he
## was struck (a leap's air): the kneel starts that much lower, on the floor.
static func make(general: General, info: DamageInfo, drop: float = 0.0) -> GeneralFall:
	var fall := GeneralFall.new()
	fall.name = "GeneralFall"
	fall._rig = general.rig
	fall._guard = general.target
	fall._push = info.direction if info != null else Vector3.ZERO
	fall._at = general.global_transform
	fall._start = _copy(general.moves.pose)
	fall._kneel = kneel_pose(fall._start)
	var model := general.rig.model
	fall._model_at = model.global_transform if model.is_inside_tree() else general.global_transform
	fall._at.origin.y -= drop
	fall._model_at.origin.y -= drop
	fall._pivot = Node3D.new()
	fall._pivot.name = "Pivot"
	fall.add_child(fall._pivot)
	# his hit zones go with him (their receivers are freed with the guardian)
	for hurtbox in model.find_children("*", "Hurtbox", true, false):
		hurtbox.get_parent().remove_child(hurtbox)
		hurtbox.queue_free()
	for light in model.find_children("*", "OmniLight3D", true, false):
		light.get_parent().remove_child(light)
		light.queue_free()
	model.get_parent().remove_child(model)
	fall._pivot.add_child(model)
	return fall


## The kneel (body space): one knee down, the torso bowed, the nodachi
## planted point-down before him, both fists on the hilt, the eyes dead.
## [param from] gives what to keep (the bow away, the hands on the hilt).
static func kneel_pose(from: GeneralRig.Pose = null) -> GeneralRig.Pose:
	var p := GeneralRig.Pose.new()
	p.pelvis = Vector3(0.0, 0.72, -0.1)
	p.torso = Vector3(-0.35, 0.0, 0.0)
	p.head = Vector3(-0.4, 0.0, 0.0)
	p.feet = [Vector3(-0.19, 0.136, -0.45), Vector3(0.19, 0.136, 0.35)]
	p.foot_pitch = [0.0, 1.2]
	p.sword_grip = Vector3(0.0, 1.55, -0.62)
	p.sword_dir = Vector3(0.0, -0.985, -0.17).normalized()
	p.hands_on = [1.0, 1.0]
	p.eyes = GeneralRig.EYES_DEAD
	if from != null:
		p.assembly = 1.0
	return p


static func _copy(source: GeneralRig.Pose) -> GeneralRig.Pose:
	var p := GeneralRig.Pose.new()
	for property in source.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = source.get(property["name"])
			p.set(property["name"], value.duplicate() if value is Array else value)
	return p


func _ready() -> void:
	_pivot.global_transform = _at
	_rig.model.global_transform = _model_at
	_light = OmniLight3D.new()
	_light.light_color = EMBER
	_light.omni_range = 6.0
	_light.light_energy = 0.0
	add_child(_light)
	_light.global_position = _at.origin + Vector3.UP * 2.2
	_start.assembly = 1.0


func _physics_process(delta: float) -> void:
	if done:
		return
	_time += delta
	if _time < TREMBLE:
		var k := _time / TREMBLE
		_blend(0.0)
		_pose.eyes = 1.0 + 0.4 * sin(_time * 50.0)
		_pose.shiver = 0.02
		_light.light_energy = 3.5 * k
		_rig.apply(_pose, delta)
		return
	var t := clampf((_time - TREMBLE) / KNEEL, 0.0, 1.0)
	if t < 1.0 or (_shed_index == 0 and _shed_next <= 0.0):
		var k := MotionClip.eased(MotionClip.IN_OUT, t)
		_blend(k)
		_pose.eyes = lerpf(1.0, GeneralRig.EYES_DEAD, MotionClip.eased(MotionClip.IN, t))
		_pose.shiver = 0.012 * (1.0 - t)
		_light.light_energy = 3.5 * (1.0 - t)
		_rig.apply(_pose, delta)
		if t >= 1.0:
			_shed_next = SHED_GAP * 2.0
			Sfx.play_at(&"hit_marble", _rig.tip_point(), -2.0, 0.1, 0.7)
			Fx.impact(_rig.tip_point(), Vector3.UP, -1, 1.5)
		return
	_shed_next -= delta
	if _shed_next <= 0.0:
		_shed_next = SHED_GAP
		_shed(SHED_ORDER[_shed_index])
		_shed_index += 1
		if _shed_index >= SHED_ORDER.size():
			done = true
			_light.light_energy = 0.0
			shed.emit()


## The pose between his last stance ([param k] = 0) and the kneel (1).
func _blend(k: float) -> void:
	var a := _start
	var b := _kneel
	var p := _pose
	p.legs_ik = 1.0
	p.assembly = 1.0
	p.pelvis = a.pelvis.lerp(b.pelvis, k)
	p.pelvis_turn = a.pelvis_turn.lerp(Vector3.ZERO, k)
	p.torso = a.torso.lerp(b.torso, k)
	p.head = a.head.lerp(b.head, k)
	for i in 2:
		p.feet[i] = a.feet[i].lerp(b.feet[i], k)
		p.foot_pitch[i] = lerpf(a.foot_pitch[i], b.foot_pitch[i], k)
		p.hands_on[i] = lerpf(a.hands_on[i], 1.0, clampf(k * 1.5, 0.0, 1.0))
		p.sode[i] = a.sode[i].lerp(Vector2.ZERO, k)
		p.hand_free[i] = a.hand_free[i]
	for i in 4:
		p.kusazuri[i] = lerpf(a.kusazuri[i], 0.0, k)
	p.sword_grip = a.sword_grip.lerp(b.sword_grip, k)
	p.sword_dir = a.sword_dir.normalized().slerp(b.sword_dir, k)
	p.sword_shown = true
	p.bow_in_hand = a.bow_in_hand and k < 0.2
	p.bow_aim = a.bow_aim
	p.arrow_in_hand = false
	p.glint = 0.0


## [param part_name] comes off: a rigid body with its mesh where it stood;
## the part's own mesh is emptied (its children stay where they are).
func _shed(part_name: String) -> void:
	var view := _rig.part(part_name) as MeshInstance3D
	if view == null or view.mesh == null or not view.is_inside_tree():
		return
	if remains == null:
		remains = Node3D.new()
		remains.name = "GeneralRemains"
		add_child(remains)
	var xform := view.global_transform
	var materials: Array = []
	for i in view.mesh.get_surface_count():
		var source := view.get_active_material(i)
		materials.append(ArtLibrary.debris_material(source) if source != null else null)
	var shard := MeshShards.whole(view.mesh)
	var body := _piece(shard, materials, xform)
	pieces.append(body)
	view.mesh = null
	var at := xform.origin
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 0.8)
	Sfx.play_at(&"hit_metal", at, -6.0 if part_name != "head" else -2.0, 0.2, 0.75)
	if part_name == "head":
		Fx.impact(at, Vector3.UP, -1, 1.5)
		Sfx.play_at(&"break_metal", at, -4.0)
	if is_instance_valid(_guard) and _guard is Player:
		var distance := _guard.global_position.distance_to(at)
		if distance < 20.0:
			Events.shake_requested.emit(0.08 * (1.0 - distance / 20.0))


func _piece(shard: MeshShards.Piece, materials: Array, xform: Transform3D) -> RigidBody3D:
	var turn := xform.basis.orthonormalized()
	var view := MeshInstance3D.new()
	view.mesh = shard.mesh
	var shape_basis := turn.inverse() * xform.basis
	view.transform = Transform3D(shape_basis, shape_basis * shard.offset)
	var picked := MeshShards.materials_for(shard, materials)
	for i in picked.size():
		if picked[i] != null:
			view.set_surface_override_material(i, picked[i])
	view.set_instance_shader_parameter(&"awake", GeneralRig.EYES_DEAD)
	var dims := (shape_basis * shard.size).abs().max(Vector3.ONE * 0.06)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = clampf(dims.x * dims.y * dims.z * 300.0, 0.5, 30.0)
	body.add_child(collider)
	body.add_child(view)
	remains.add_child(body)
	body.global_transform = Transform3D(turn, xform * shard.center)
	body.reset_physics_interpolation()
	var out := body.global_position - _at.origin
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	body.linear_velocity = out * randf_range(0.3, 1.2) + Vector3(0.0, randf_range(0.2, 0.8), 0.0) + _push * 0.3
	body.angular_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	return body
