class_name CentaurRig
extends RefCounted
## The Centaur's body: the Blender model "centaur" (ArtLibrary; 25 rigid
## parts jointed at their pivots, see docs/art/kit-pietro1-grecja.md §6)
## driven by a Pose, or a greybox with the same part names and pivots when
## the model is off. apply() turns the parts:
## - the barrel (the horse body, the root) from a position and an euler
##   turn (the gait's bob, pitch and roll, the rear, the buck);
## - each leg by two-bone IK from its root on the barrel to its fetlock
##   point (the gait's hooves, planted in the world): the forearm and cannon
##   of a fore leg fold at the knee, which bends forward; the gaskin and
##   cannon of a hind leg fold at the hock, which bends back; the root slides
##   a little inside the barrel toward a far hoof (the shoulder blade's
##   reach); the hoof (pastern and hoof) keeps its sole level, or curls back
##   in the swing;
## - the tail, the human torso (lean, twist, side lean on the barrel), the
##   neck (the head's look);
## - each arm by two-bone IK from its shoulder to a wrist point, the elbow
##   bent toward a pole; the javelin hand turned so the javelin points where
##   it should;
## - what shows: the javelin in the right hand, a second one in the left
##   (phase 3), the metope's piece on its flank;
## - the glow: the eyes (awake), the chest cracks, a javelin's glint, the
##   hooves' glint, a hit's flash (the exhibit shader's instance uniforms).
## Body space = the Centaur node's: origin on the floor under the barrel,
## -Z its front, +X its right.

const PART_NAMES: Array[String] = ["barrel", "leg_fl", "knee_fl", "hoof_fl", "leg_fr", "knee_fr", "hoof_fr",
	"leg_bl", "knee_bl", "hoof_bl", "leg_br", "knee_br", "hoof_br", "tail_1", "tail_2", "slab", "torso", "neck",
	"arm_l", "forearm_l", "wrist_l", "arm_r", "forearm_r", "wrist_r", "javelin"]
const LEGS: Array[String] = ["fl", "fr", "bl", "br"]
## How far a leg's root may slide inside the barrel toward its hoof (m).
const ROOT_SLIDE := 0.14
## The barrel's rest pivot (body space).
const BARREL_REST := Vector3(0.0, 1.25, 0.0)

## Target posture (body space).
class Pose:
	## The barrel's pivot and turn (euler: x pitch + nose up, y yaw + to its
	## left, z roll + its left side down).
	var barrel := BARREL_REST
	var barrel_turn := Vector3.ZERO
	## 0 = the legs as carved, 1 = IK to [member hooves].
	var legs_ik: float = 0.0
	## Fetlock points (body space): fl, fr, bl, br.
	var hooves: Array[Vector3] = [Vector3(-0.2, 0.17, -0.68), Vector3(0.2, 0.17, -0.68), Vector3(-0.22, 0.17, 0.84), Vector3(0.22, 0.17, 0.84)]
	## Each hoof's tilt (rad): 0 sole level, negative curled back (swing).
	var hoof_pitch: Array[float] = [0.0, 0.0, 0.0, 0.0]
	## The tail: x lift (+ up), y swish (+ to its left); the tip bends on.
	var tail := Vector2.ZERO
	var tail_tip := Vector2.ZERO
	## The human torso on the barrel: x lean (- forward), y twist (+ to its
	## left), z side lean (+ its left shoulder down).
	var torso := Vector3.ZERO
	## The head on the torso: x pitch (+ up), y turn (+ left), z tilt.
	var neck := Vector3.ZERO
	## Per arm (0 left, 1 right): 0 = as carved, 1 = IK to [member wrist];
	## the elbow bends toward [member elbow_pole] (body space direction).
	var arm_aim: Array[float] = [0.0, 0.0]
	var wrist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var elbow_pole: Array[Vector3] = [Vector3(-1.0, -0.6, 0.4), Vector3(1.0, -0.6, 0.4)]
	## Per hand: 0 = the hand as carved on the forearm, 1 = turned so its
	## javelin points along [member javelin_dir] (body space).
	var javelin_aim: Array[float] = [0.0, 0.0]
	var javelin_dir: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD]
	## A javelin shows in the left (phase 3) / right hand.
	var javelin_shown: Array[bool] = [false, true]
	## The metope's piece still on its flank.
	var slab_on := true
	## 0 asleep .. 1 awake (eyes, rim).
	var eyes: float = 0.0
	## The chest cracks' light (0..2).
	var cracks: float = 0.0
	## A javelin's glint (left, right) and the hooves' (fore, hind), 0..1.
	var glint: Array[float] = [0.0, 0.0]
	var hoof_glint: Array[float] = [0.0, 0.0]
	## Stone trembling (rad).
	var shiver: float = 0.0


var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var greybox := false
## The second javelin (phase 3), in the left hand.
var left_javelin: Node3D

var _legs: Array = []
var _arms: Array = []
var _flash: float = 0.0
var _sent := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _time: float = 0.0


## The rig under [param parent] (the model, or the greybox when the model is
## off or missing).
static func create(parent: Node3D) -> CentaurRig:
	var rig := CentaurRig.new()
	rig.model = ArtLibrary.exhibit(&"centaur")
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "Centaur"
	parent.add_child(rig.model)
	for node in rig.model.find_children("*", "Node3D", true, false):
		rig.parts[String(node.name)] = node
		rig.rest[String(node.name)] = (node as Node3D).transform
		if node is MeshInstance3D:
			rig.meshes.append(node as MeshInstance3D)
	rig._setup()
	return rig


func part(part_name: String) -> Node3D:
	return parts.get(part_name) as Node3D


## Rest position (body space) of [param part_name]'s pivot.
func rest_point(part_name: String) -> Vector3:
	return rest_xform(part_name).origin


func rest_xform(part_name: String) -> Transform3D:
	var node := part(part_name)
	var xform := Transform3D.IDENTITY
	var chain: Array[Node3D] = []
	while node != null and node != model:
		chain.push_front(node)
		node = node.get_parent() as Node3D
	for link in chain:
		xform = xform * (rest[String(link.name)] as Transform3D)
	return xform


## The barrel's transform for pose [param p] (body space).
static func barrel_xform(p: Pose) -> Transform3D:
	return Transform3D(Basis.from_euler(p.barrel_turn), p.barrel)


## The human torso's transform for pose [param p] (body space).
func torso_xform(p: Pose) -> Transform3D:
	return barrel_xform(p) * Transform3D(Basis.from_euler(p.torso), (rest["torso"] as Transform3D).origin)


## Where arm [param side]'s shoulder is for pose [param p] (body space).
func shoulder_at(p: Pose, side: int) -> Vector3:
	return torso_xform(p) * (rest["arm_" + _arm_suffix(side)] as Transform3D).origin


## Where the wrist of arm [param side] is when it hangs as carved, for
## pose [param p] (body space).
func carved_wrist(p: Pose, side: int) -> Vector3:
	var s := _arm_suffix(side)
	return torso_xform(p) * ((rest["arm_" + s] as Transform3D) * (rest["forearm_" + s] as Transform3D) * (rest["wrist_" + s] as Transform3D)).origin


## Where a leg's root is for pose [param p] (body space).
func leg_root(p: Pose, leg: int) -> Vector3:
	return barrel_xform(p) * (rest["leg_" + LEGS[leg]] as Transform3D).origin


## Arm [param side]'s reach (shoulder to wrist, straight).
func arm_reach(side: int) -> float:
	var arm: Dictionary = _arms[side]
	return float(arm["l1"]) + float(arm["l2"])


## A leg's reach (root to fetlock, straight).
func leg_reach(leg: int) -> float:
	var data: Dictionary = _legs[leg]
	return float(data["l1"]) + float(data["l2"])


## Poses the model from [param p].
func apply(p: Pose, delta: float = 0.0) -> void:
	_time += delta
	var shake := Vector3.ZERO
	if p.shiver > 0.0:
		shake = Vector3(_noise.get_noise_2d(_time * 90.0, 0.0), _noise.get_noise_2d(0.0, _time * 90.0), _noise.get_noise_2d(_time * 70.0, 50.0)) * p.shiver
	var barrel := Transform3D(Basis.from_euler(p.barrel_turn + shake), p.barrel)
	part("barrel").transform = barrel
	for leg in 4:
		_leg(leg, p, barrel)
	_turn("tail_1", Vector3(-p.tail.x, p.tail.y, 0.0))
	_turn("tail_2", Vector3(-p.tail_tip.x, p.tail_tip.y, 0.0))
	_turn("torso", p.torso + shake * 0.6)
	_turn("neck", p.neck + shake)
	var torso := barrel * (part("torso").transform)
	for side in 2:
		_arm(side, p, torso)
	part("javelin").visible = p.javelin_shown[1]
	if left_javelin != null:
		left_javelin.visible = p.javelin_shown[0]
	part("slab").visible = p.slab_on
	_glow(p, delta)


## Gives every part a short white flash (a hit landing).
func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


## The javelin tip of hand [param side] (world; the left one in phase 3).
func javelin_tip(side: int) -> Vector3:
	var holder := part("javelin") if side == 1 else left_javelin
	if holder == null:
		return part("wrist_l").global_position
	return holder.global_transform * Vector3(0.0, 0.0, -1.53)


## Hand [param side]'s grip (world).
func hand_point(side: int) -> Vector3:
	return part("hand_r").global_position if side == 1 else part("wrist_l").global_position


## The eyes (world): the head marker, a little forward.
func eyes_point() -> Vector3:
	return part("head").global_transform * Vector3(0.0, 0.03, -0.1)


# --- legs -------------------------------------------------------------------

func _leg(leg: int, p: Pose, barrel: Transform3D) -> void:
	var data: Dictionary = _legs[leg]
	var upper := data["upper"] as Node3D
	var lower := data["lower"] as Node3D
	var hoof := data["hoof"] as Node3D
	var weight := clampf(p.legs_ik, 0.0, 1.0)
	var root_rest: Vector3 = data["root"]
	if weight <= 0.0:
		upper.transform = Transform3D(Basis.IDENTITY, root_rest)
		lower.transform = rest[String(lower.name)]
		hoof.transform = rest[String(hoof.name)]
		return
	var target: Vector3 = p.hooves[leg]
	var l1: float = data["l1"]
	var l2: float = data["l2"]
	# the root slides toward a hoof that is far off (the shoulder blade, the
	# hip turning), inside the barrel where nobody sees it
	var root := barrel * root_rest
	var reach := target - root
	var over := reach.length() - (l1 + l2) * 0.985
	var slide := Vector3.ZERO
	if over > 0.0:
		var flat := barrel.basis.inverse() * reach
		flat.y = 0.0
		slide = flat.normalized() * minf(over, ROOT_SLIDE) if flat.length() > 0.001 else Vector3.ZERO
	var root_local := root_rest + slide
	root = barrel * root_local
	var pole: Vector3 = barrel.basis * (Vector3.FORWARD if leg < 2 else Vector3.BACK)
	var knee := LimbIK.joint(root, target, l1, l2, pole)
	var to_barrel := barrel.basis.inverse()
	var upper_aim := LimbIK.aim(Basis.IDENTITY, data["axis_u"], to_barrel * (knee - root))
	var upper_world := barrel.basis * upper_aim
	var lower_aim := LimbIK.aim(Basis.IDENTITY, data["axis_l"], upper_world.inverse() * (target - knee))
	var lower_world := upper_world * lower_aim
	# the sole level with the floor (turned with the barrel's yaw), tilted
	var level := Basis(Vector3.UP, p.barrel_turn.y) * Basis(Vector3.RIGHT, p.hoof_pitch[leg])
	var hoof_local := (lower_world.inverse() * level).orthonormalized()
	upper.transform = Transform3D(Basis.IDENTITY.slerp(upper_aim, weight), root_rest.lerp(root_local, weight))
	lower.transform = Transform3D(Basis.IDENTITY.slerp(lower_aim, weight), (rest[String(lower.name)] as Transform3D).origin)
	hoof.transform = Transform3D(Basis.IDENTITY.slerp(hoof_local, weight), (rest[String(hoof.name)] as Transform3D).origin)


# --- arms -------------------------------------------------------------------

func _arm(side: int, p: Pose, torso: Transform3D) -> void:
	var data: Dictionary = _arms[side]
	var upper := data["upper"] as Node3D
	var fore := data["fore"] as Node3D
	var wrist := data["wrist"] as Node3D
	var aim := clampf(p.arm_aim[side], 0.0, 1.0)
	var upper_basis := Basis.IDENTITY
	var fore_basis := Basis.IDENTITY
	if aim > 0.0:
		var shoulder := torso * (data["shoulder"] as Vector3)
		var elbow := LimbIK.joint(shoulder, p.wrist[side], data["l1"], data["l2"], p.elbow_pole[side])
		var to_torso := torso.basis.inverse()
		var upper_aim := LimbIK.aim(Basis.IDENTITY, data["axis_u"], to_torso * (elbow - shoulder))
		var upper_world := torso.basis * upper_aim
		var fore_aim := LimbIK.aim(Basis.IDENTITY, data["axis_f"], upper_world.inverse() * (p.wrist[side] - elbow))
		upper_basis = Basis.IDENTITY.slerp(upper_aim, aim)
		fore_basis = Basis.IDENTITY.slerp(fore_aim, aim)
	upper.transform = Transform3D(upper_basis, (rest[String(upper.name)] as Transform3D).origin)
	fore.transform = Transform3D(fore_basis, (rest[String(fore.name)] as Transform3D).origin)
	# the hand turns its javelin onto its line (the javelin lies along the
	# hand's -Z as carved)
	var grip := clampf(p.javelin_aim[side], 0.0, 1.0)
	var hand_basis := Basis.IDENTITY
	if grip > 0.0 and p.javelin_dir[side].length() > 0.001:
		var fore_world := torso.basis * upper_basis * fore_basis
		var wanted := LimbIK.aim(Basis.IDENTITY, Vector3.FORWARD, p.javelin_dir[side])
		hand_basis = Basis.IDENTITY.slerp((fore_world.inverse() * wanted).orthonormalized(), grip)
	wrist.transform = Transform3D(hand_basis, (rest[String(wrist.name)] as Transform3D).origin)


# --- glow ---------------------------------------------------------------------

func _glow(p: Pose, delta: float) -> void:
	_flash = move_toward(_flash, 0.0, 6.0 * delta)
	if greybox:
		return
	if _sent.size() != meshes.size() * 3:
		_sent.resize(meshes.size() * 3)
		_sent.fill(-1.0)
	for index in meshes.size():
		var view := meshes[index]
		var key := String(view.name)
		var glow := 0.0
		if key == "torso":
			glow = p.cracks
		elif key == "javelin":
			glow = p.glint[1] if view == part("javelin") else p.glint[0]
		elif key.begins_with("hoof_f"):
			glow = p.hoof_glint[0]
		elif key.begins_with("hoof_b"):
			glow = p.hoof_glint[1]
		_set_uniform(view, index * 3, &"glow", glow)
		_set_uniform(view, index * 3 + 1, &"awake", clampf(p.eyes, 0.0, 1.0))
		_set_uniform(view, index * 3 + 2, &"flash", _flash)


func _set_uniform(view: MeshInstance3D, slot: int, uniform: StringName, value: float) -> void:
	if absf(_sent[slot] - value) < 0.005:
		return
	_sent[slot] = value
	view.set_instance_shader_parameter(uniform, value)


# --- setup ---------------------------------------------------------------------

func _setup() -> void:
	_noise.seed = 9
	_noise.frequency = 0.5
	for leg in LEGS:
		var upper := part("leg_" + leg)
		var lower := part("knee_" + leg)
		var hoof := part("hoof_" + leg)
		var knee_at: Vector3 = (rest["knee_" + leg] as Transform3D).origin
		var fetlock_at: Vector3 = (rest["hoof_" + leg] as Transform3D).origin
		_legs.append({
			"upper": upper, "lower": lower, "hoof": hoof,
			"root": (rest["leg_" + leg] as Transform3D).origin,
			"l1": knee_at.length(), "l2": fetlock_at.length(),
			"axis_u": knee_at.normalized(), "axis_l": fetlock_at.normalized(),
		})
	for side in 2:
		var s := _arm_suffix(side)
		var elbow_at: Vector3 = (rest["forearm_" + s] as Transform3D).origin
		var wrist_at: Vector3 = (rest["wrist_" + s] as Transform3D).origin
		_arms.append({
			"upper": part("arm_" + s), "fore": part("forearm_" + s), "wrist": part("wrist_" + s),
			"shoulder": (rest["arm_" + s] as Transform3D).origin,
			"l1": elbow_at.length(), "l2": wrist_at.length(),
			"axis_u": elbow_at.normalized(), "axis_f": wrist_at.normalized(),
		})
	# the second javelin (phase 3) in the left hand, held like the right
	var spare := part("javelin")
	if spare != null:
		left_javelin = spare.duplicate() as Node3D
		left_javelin.name = "javelin_left"
		left_javelin.transform = rest["javelin"] as Transform3D
		left_javelin.visible = false
		part("wrist_l").add_child(left_javelin)
		if left_javelin is MeshInstance3D:
			meshes.append(left_javelin as MeshInstance3D)
	# the parts break into chunks on its fall: cut them in the background
	if not greybox:
		for view in meshes:
			MeshShards.warm_slices(view.mesh, 2)


func _turn(part_name: String, euler: Vector3) -> void:
	var node := part(part_name)
	node.transform = Transform3D(Basis.from_euler(euler), (rest[part_name] as Transform3D).origin)


static func _arm_suffix(side: int) -> String:
	return "l" if side == 0 else "r"


## The greybox body: boxes on the model's pivots, same names, same chains.
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.86, 0.83, 0.76)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.32, 0.47, 0.86)
	# [name, parent, pivot (parent space), box size, box centre (own space)]
	var spec := [
		["barrel", "", Vector3(0, 1.25, 0), Vector3(0.8, 0.93, 1.88), Vector3(0, 0.08, 0.12)],
		["leg_fl", "barrel", Vector3(-0.2, -0.23, -0.62), Vector3(0.3, 0.8, 0.34), Vector3(0, -0.15, 0)],
		["knee_fl", "leg_fl", Vector3(0, -0.46, -0.04), Vector3(0.15, 0.52, 0.17), Vector3(0, -0.2, -0.01)],
		["hoof_fl", "knee_fl", Vector3(0, -0.39, -0.02), Vector3(0.15, 0.25, 0.24), Vector3(0, -0.06, -0.06)],
		["leg_fr", "barrel", Vector3(0.2, -0.23, -0.62), Vector3(0.3, 0.8, 0.34), Vector3(0, -0.15, 0)],
		["knee_fr", "leg_fr", Vector3(0, -0.46, -0.04), Vector3(0.15, 0.52, 0.17), Vector3(0, -0.2, -0.01)],
		["hoof_fr", "knee_fr", Vector3(0, -0.39, -0.02), Vector3(0.15, 0.25, 0.24), Vector3(0, -0.06, -0.06)],
		["leg_bl", "barrel", Vector3(-0.22, -0.2, 0.7), Vector3(0.34, 0.8, 0.46), Vector3(0, -0.15, 0.05)],
		["knee_bl", "leg_bl", Vector3(0, -0.47, 0.2), Vector3(0.16, 0.56, 0.2), Vector3(0, -0.2, -0.03)],
		["hoof_bl", "knee_bl", Vector3(0, -0.41, -0.06), Vector3(0.15, 0.25, 0.24), Vector3(0, -0.06, -0.06)],
		["leg_br", "barrel", Vector3(0.22, -0.2, 0.7), Vector3(0.34, 0.8, 0.46), Vector3(0, -0.15, 0.05)],
		["knee_br", "leg_br", Vector3(0, -0.47, 0.2), Vector3(0.16, 0.56, 0.2), Vector3(0, -0.2, -0.03)],
		["hoof_br", "knee_br", Vector3(0, -0.41, -0.06), Vector3(0.15, 0.25, 0.24), Vector3(0, -0.06, -0.06)],
		["tail_1", "barrel", Vector3(0, 0.3, 1.08), Vector3(0.2, 0.5, 0.4), Vector3(0, -0.19, 0.13)],
		["tail_2", "tail_1", Vector3(0, -0.35, 0.24), Vector3(0.2, 0.66, 0.2), Vector3(0, -0.23, 0)],
		["slab", "barrel", Vector3(-0.37, -0.05, 0), Vector3(0.1, 1.31, 1.62), Vector3(0, 0.12, 0.09)],
		["torso", "barrel", Vector3(0, 0.37, -0.66), Vector3(0.78, 0.86, 0.42), Vector3(0, 0.38, -0.04)],
		["neck", "torso", Vector3(0, 0.8, -0.08), Vector3(0.34, 0.48, 0.36), Vector3(0, 0.18, -0.06)],
		["arm_l", "torso", Vector3(-0.34, 0.68, -0.02), Vector3(0.28, 0.44, 0.27), Vector3(-0.07, -0.14, -0.06)],
		["forearm_l", "arm_l", Vector3(-0.16, -0.3, -0.14), Vector3(0.26, 0.66, 0.36), Vector3(0, -0.27, -0.11)],
		["wrist_l", "forearm_l", Vector3(0.08, -0.14, -0.26), Vector3(0.11, 0.11, 0.2), Vector3(0, -0.01, -0.06)],
		["arm_r", "torso", Vector3(0.34, 0.68, -0.02), Vector3(0.4, 0.3, 0.22), Vector3(0.12, 0.08, 0.03)],
		["forearm_r", "arm_r", Vector3(0.26, 0.18, 0.08), Vector3(0.24, 0.28, 0.24), Vector3(-0.06, 0.08, -0.06)],
		["wrist_r", "forearm_r", Vector3(-0.14, 0.18, -0.14), Vector3(0.14, 0.14, 0.14), Vector3(-0.03, -0.03, -0.03)],
		["javelin", "wrist_r", Vector3(-0.04, -0.04, -0.04), Vector3(0.07, 0.035, 2.6), Vector3(0, 0, -0.23)],
	]
	var made := {}
	for entry: Array in spec:
		var view := MeshInstance3D.new()
		view.name = entry[0]
		var box := BoxMesh.new()
		box.size = entry[3]
		var shifted := ArrayMesh.new()
		var arrays := box.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] += entry[4]
		arrays[Mesh.ARRAY_VERTEX] = verts
		shifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		view.mesh = shifted
		view.material_override = blue if entry[0] == "slab" else stone
		view.position = entry[2]
		var parent: Node3D = made.get(entry[1], root)
		parent.add_child(view)
		made[entry[0]] = view
	for marker: Array in [["chest", "torso", Vector3(0, 0.5, -0.26)], ["head", "neck", Vector3(0, 0.24, -0.06)],
			["hand_r", "wrist_r", Vector3(-0.04, -0.04, -0.04)]]:
		var node := Node3D.new()
		node.name = marker[0]
		node.position = marker[2]
		(made[marker[1]] as Node3D).add_child(node)
	return root
