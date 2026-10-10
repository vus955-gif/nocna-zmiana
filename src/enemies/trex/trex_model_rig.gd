class_name TRexModelRig
extends RefCounted
## The Blender T-Rex (ArtLibrary "trex", 26 jointed parts) driven by
## TRexSkeleton's pose: the same Pose fields the greybox bones read (drop,
## pitch, neck, look, jaw, curl, lift, crouch, arms, exposure...) turn the
## model's joints. Chains of different length than the greybox (3 neck,
## 3 spine, 8 tail bones) share the greybox's total bend, so every pose
## (walk, charge, tail swipe, stun head-flop, roar) keeps its shape. The
## legs are two-bone IK in the side plane: the feet stay planted through
## the crouch and the walk (a stride matches the ground covered), the paw
## scrapes, and the feet stay level.
## Every part carries a hurtbox: the rib cage its exact mesh (shots pass
## between the ribs to the crystal), the other bones their convex hulls;
## collapse() breaks each part into its bones
## (mesh islands) as physical debris. The crystal (crystal_loose) sits in
## the CrystalSocket between the 5th and 6th rib.

## Neck raise / look turn shared by neck_1..3 (the greybox total: 1.26 and
## 1.0 of the pose value).
const NECK_RAISE: Array[float] = [0.46, 0.44, 0.36]
const NECK_LOOK: Array[float] = [0.36, 0.34, 0.3]
## Per tail bone: the greybox's 14 bones bend 0.035 (lift) and 0.1 (curl)
## each; 8 bones bend 14/8 as much.
const TAIL_LIFT := 0.035 * 14.0 / 8.0
## The model's tail sits higher than the greybox's: a dropped tail (the
## swipe) bends further, mostly at its base, so it comes down to the
## guard's height still reaching as far.
const TAIL_DROP: Array[float] = [2.6, 1.8, 1.3, 1.0, 0.8, 0.7, 0.6, 0.5]
const TAIL_CURL := 0.1 * 14.0 / 8.0
## A sideways swing turns mostly at the base (the tail whips round as a
## long lever instead of rolling up); same total turn as the greybox.
const TAIL_SWING: Array[float] = [2.0, 1.6, 1.2, 0.9, 0.8, 0.6, 0.5, 0.4]
const TAIL_SWAY := 0.012 * 14.0 / 8.0
## Half a stride (m): trex.gd advances the walk phase by PI per 2.2 m.
const STEP_HALF := 1.1
const STEP_LIFT := 0.5
## Scale of crystal_loose in the socket.
const GEM_SCALE := 2.6
## Bone islands smaller than this (triangles) stay with their neighbour.
const MIN_BONE_TRIANGLES := 60
## Eye sockets in the skull's space.
const EYE_SPOT := Vector3(0.22, 0.12, -0.46)
## Parts whose hit zone is the bone's exact mesh: shots pass between the
## ribs to the crystal. Every other bone's zone is its convex hull (a sweep
## or a blast gets one overlap from it, not one per triangle).
const EXACT_ZONES: Array[String] = ["ribs"]

static var _shapes: Dictionary = {}

var skeleton: TRexSkeleton
var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
## Where the crystal pivot rests (ribs space).
var socket := Vector3.ZERO
## Tip of the tail in tail_8's space.
var tail_tip := Vector3.ZERO

## Per leg: {hip, l1, l2, a1, a2, ankle (root space), knee_sign}
var _legs: Array = []
var _awake := -1.0


## The rig, or null when the model is off or missing (greybox then).
static func create(owner: TRexSkeleton) -> TRexModelRig:
	var loaded := ArtLibrary.exhibit(&"trex")
	if loaded == null:
		return null
	var rig := TRexModelRig.new()
	rig.skeleton = owner
	rig.model = loaded
	owner.add_child(loaded)
	for node in loaded.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
		if node is MeshInstance3D:
			rig.meshes.append(node as MeshInstance3D)
	return rig


func part(part_name: String) -> Node3D:
	return parts.get(part_name) as Node3D


## Hands the skeleton its joints, adds the hit zones, the eyes, the toe
## markers and the leg IK data. [param bone_zone] receives the bone hits.
func rig_skeleton(bone_zone: Node) -> void:
	var s := skeleton
	s.body = part("pelvis")
	s.head = part("skull")
	s.jaw = part("jaw")
	s.neck.assign([part("neck_1"), part("neck_2"), part("neck_3")])
	s.tail.clear()
	for k in range(1, 9):
		s.tail.append(part("tail_%d" % k))
	s.ribs.assign([part("ribs")])
	s.arms.assign([part("arm_l"), part("arm_r")])
	s.legs.clear()
	for side in ["l", "r"]:
		var thigh := part("thigh_" + side)
		var shin := part("shin_" + side)
		var foot := part("foot_" + side) as MeshInstance3D
		var toes := Node3D.new()
		toes.name = "toes_" + side
		var box := foot.get_aabb()
		toes.position = Vector3(0.0, box.position.y + 0.05, box.position.z + 0.15)
		foot.add_child(toes)
		s.legs.append([thigh, shin, foot, toes])
		_legs.append(_leg_data(thigh, shin, foot))
	var tail_end := part("tail_8") as MeshInstance3D
	var end_box := tail_end.get_aabb()
	tail_tip = Vector3(0.0, end_box.get_center().y, end_box.end.z)
	socket = part("CrystalSocket").position
	for view in meshes:
		view.set_meta(&"aabb", view.get_aabb())
		s.pieces.append(view)
		# the zone's origin sits in the middle of the bone (melee sweeps and
		# the taser arc aim at it); its mesh shape stays where the bone is
		var middle := view.get_aabb().get_center()
		var hurtbox := Hurtbox.make(bone_zone, _shape_of(view.mesh, EXACT_ZONES.has(String(view.name))), middle)
		(hurtbox.get_child(0) as CollisionShape3D).position = -middle
		view.add_child(hurtbox)
		s.hurtboxes.append(hurtbox)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = TRexSkeleton._ball(0.06)
		eye.material_override = s._eye_mat
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(EYE_SPOT.x * side, EYE_SPOT.y, EYE_SPOT.z)
		s.head.add_child(eye)
	# the bones fall apart island by island: cut them in the background
	# (cached per mesh; a collapse before that cuts what is left at once)
	for view in meshes:
		MeshShards.warm_islands(view.mesh, MIN_BONE_TRIANGLES)


## The crystal model for the socket (under a holder the skeleton scales
## with the heartbeat) and its own material for the glow.
func make_gem() -> Array:
	var gem := ArtLibrary.try_instance(&"crystal_loose")
	if gem == null:
		return []
	gem.scale = Vector3.ONE * GEM_SCALE
	var box := (gem.find_child("crystal_loose", true, false) as MeshInstance3D).get_aabb()
	gem.position = -box.get_center() * GEM_SCALE
	var owned := ArtLibrary.own_materials(gem)
	return [gem, owned[0] if not owned.is_empty() else null]


## Poses the model from the eased pose [param p].
func animate(p: TRexSkeleton.Pose, stride: float, walk_phase: float, time: float, scrape: float, shiver: Vector3) -> void:
	var bob := absf(sin(walk_phase)) * 0.09 * minf(stride, 1.2)
	var pelvis := part("pelvis")
	var pelvis_rest: Transform3D = rest["pelvis"]
	pelvis.transform = Transform3D(Basis.from_euler(Vector3(p.pitch, p.twist, p.roll + sin(walk_phase) * 0.03 * stride) + shiver),
			pelvis_rest.origin + Vector3(0.0, -p.drop - bob, 0.0))
	_turn("spine_1", Vector3(p.neck * 0.04, p.look * 0.04, 0.0))
	_turn("spine_2", Vector3(p.neck * 0.04, p.look * 0.05, 0.0))
	_turn("spine_3", Vector3(p.neck * 0.06, p.look * 0.06, 0.0))
	for i in 3:
		_turn("neck_%d" % (i + 1), Vector3(p.neck * NECK_RAISE[i], p.look * NECK_LOOK[i], 0.0))
	_turn("skull", Vector3(-p.neck * 0.3, 0.0, 0.0) + shiver * 2.0)
	_turn("jaw", Vector3(-p.jaw * 0.8, 0.0, 0.0))
	var sway := sin(time * 1.3) * TAIL_SWAY + sin(walk_phase) * 0.03 * 14.0 / 8.0 * stride / 1.6
	for k in range(1, 9):
		var bend := TAIL_LIFT * (1.0 if p.lift > 0.0 else TAIL_DROP[k - 1])
		_turn("tail_%d" % k, Vector3(-p.lift * bend, p.curl * TAIL_CURL * TAIL_SWING[k - 1] + sway, 0.0))
	for arm in ["arm_l", "arm_r"]:
		_turn(arm, Vector3(p.arms * 0.9, 0.0, 0.0))
	for k in _legs.size():
		_leg(k, p, stride, walk_phase, time, scrape if k == 1 else 0.0)
	_set_awake(p.eyes)


## Turns every part into physical bones (its mesh islands) where it is,
## under a new node in [param parent]; returns that node.
func collapse(parent: Node) -> Node3D:
	var remains := Node3D.new()
	remains.name = "TRexRemains"
	parent.add_child(remains)
	var center := part("pelvis").global_position
	for view in meshes:
		var xform := view.global_transform
		var turn := xform.basis.orthonormalized()
		var materials: Array = []
		for i in view.mesh.get_surface_count():
			materials.append(view.get_active_material(i))
		for shard: MeshShards.Piece in MeshShards.islands(view.mesh, MIN_BONE_TRIANGLES):
			var bone := MeshInstance3D.new()
			bone.mesh = shard.mesh
			bone.position = shard.offset
			var mats := MeshShards.materials_for(shard, materials)
			for i in mats.size():
				bone.set_surface_override_material(i, mats[i])
			var rigid := RigidBody3D.new()
			rigid.collision_layer = Layers.DEBRIS
			rigid.collision_mask = Layers.WORLD | Layers.DEBRIS
			var dims := shard.size.max(Vector3.ONE * 0.06)
			rigid.mass = clampf(dims.x * dims.y * dims.z * 400.0, 0.3, 40.0)
			var shape := BoxShape3D.new()
			shape.size = dims
			var collider := CollisionShape3D.new()
			collider.shape = shape
			rigid.add_child(collider)
			rigid.add_child(bone)
			remains.add_child(rigid)
			rigid.global_transform = Transform3D(turn, xform * shard.center)   # world space, whatever the parent
			rigid.reset_physics_interpolation()
			var out := rigid.global_position - center
			out.y = 0.0
			rigid.linear_velocity = out.normalized() * randf_range(0.4, 2.2) + Vector3(0.0, randf_range(-0.5, 1.2), 0.0)
			rigid.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	model.visible = false
	return remains


func _turn(part_name: String, euler: Vector3) -> void:
	var node := parts.get(part_name) as Node3D
	var base: Transform3D = rest[part_name]
	node.transform = Transform3D(base.basis * Basis.from_euler(euler), base.origin)


## Rim and eyes of the bones follow the eyes of the pose (0 asleep).
func _set_awake(amount: float) -> void:
	if absf(amount - _awake) < 0.01:
		return
	_awake = amount
	for view in meshes:
		view.set_instance_shader_parameter(&"awake", clampf(amount, 0.0, 1.0))


func _leg_data(thigh: Node3D, shin: Node3D, foot: Node3D) -> Dictionary:
	var hip: Vector3 = rest[String(thigh.name)].origin
	var knee: Vector3 = rest[String(shin.name)].origin
	var ankle: Vector3 = rest[String(foot.name)].origin
	var v1 := Vector2(knee.y, knee.z)
	var v2 := Vector2(ankle.y, ankle.z)
	var pelvis_rest: Transform3D = rest["pelvis"]
	var ankle_root := pelvis_rest * (hip + knee + ankle)
	var reach := Vector2(knee.y + ankle.y, knee.z + ankle.z)
	var a1 := atan2(v1.y, v1.x)
	var sign_ := signf(wrapf(a1 - atan2(reach.y, reach.x), -PI, PI))
	return {"hip": hip, "l1": v1.length(), "l2": v2.length(), "a1": a1, "a2": atan2(v2.y, v2.x),
		"ankle": ankle_root, "knee_sign": sign_ if sign_ != 0.0 else 1.0,
		"thigh": String(thigh.name), "shin": String(shin.name), "foot": String(foot.name)}


## Two-bone IK in the leg's side plane: the ankle goes to its rest spot on
## the ground plus the walk cycle, wherever the hips are.
func _leg(k: int, p: TRexSkeleton.Pose, stride: float, walk_phase: float, time: float, scrape: float) -> void:
	var leg: Dictionary = _legs[k]
	# a footfall on every step of trex.gd (walk phase k * PI)
	var cycle := walk_phase + PI * k + PI * 0.5
	var walking := minf(stride, 1.0)
	var forward := -sin(cycle) * STEP_HALF * walking
	var lift := maxf(0.0, cos(cycle)) * STEP_LIFT * minf(stride, 1.3)
	forward += sin(time * 14.0) * 0.4 * scrape
	lift += absf(sin(time * 14.0)) * 0.12 * scrape
	var target: Vector3 = (leg["ankle"] as Vector3) + Vector3(0.0, lift, forward)
	var pelvis := part("pelvis")
	var local := pelvis.transform.affine_inverse() * target - (leg["hip"] as Vector3)
	var d := Vector2(local.y, local.z)
	var l1: float = leg["l1"]
	var l2: float = leg["l2"]
	var dist := clampf(d.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var aim := atan2(d.y, d.x)
	var bend := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var thigh_angle := aim + bend * float(leg["knee_sign"])
	var knee := Vector2(cos(thigh_angle), sin(thigh_angle)) * l1
	var ankle := Vector2(cos(aim), sin(aim)) * dist
	var shin_angle := atan2(ankle.y - knee.y, ankle.x - knee.x)
	var thigh_turn := wrapf(thigh_angle - float(leg["a1"]), -PI, PI)
	var shin_turn := wrapf(shin_angle - float(leg["a2"]) - thigh_turn, -PI, PI)
	# the foot stays level with the floor; it tips a little as it lifts
	var foot_turn := -(thigh_turn + shin_turn + p.pitch) - lift * 0.35
	_turn(leg["thigh"], Vector3(thigh_turn, 0.0, 0.0))
	_turn(leg["shin"], Vector3(shin_turn, 0.0, 0.0))
	_turn(leg["foot"], Vector3(foot_turn, 0.0, 0.0))


## The hit zone shape of [param mesh]: its exact triangles, or its convex
## hull (shared by every T-Rex).
static func _shape_of(mesh: Mesh, exact: bool) -> Shape3D:
	var key := "%d:%s" % [mesh.get_instance_id(), "exact" if exact else "hull"]
	if not _shapes.has(key):
		_shapes[key] = mesh.create_trimesh_shape() if exact else mesh.create_convex_shape(true, false)
	return _shapes[key]
