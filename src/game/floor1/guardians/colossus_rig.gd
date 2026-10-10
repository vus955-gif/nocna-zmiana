class_name ColossusRig
extends RefCounted
## The Colossus's body: the Blender model "colossus" (ArtLibrary; 23 rigid
## parts jointed at their pivots, see docs/art/kit-pietro1-egipt.md §5)
## driven by a Pose, or a greybox with the same part names and pivots when
## the model is off. apply() turns the parts:
## - pelvis, torso, head from euler turns (the head looks, the torso leans
##   and twists on the hips);
## - each arm by aiming its bones at an elbow and a hand point (LimbIK),
##   its joints parting along the bones when the points lie beyond its
##   reach: the stone holds together by "sinews of light" - glowing gaps
##   at shoulder, elbow and wrist (the seated Colossus could never reach the
##   floor otherwise; it reads as the sun that woke him);
## - each leg by two-bone IK to an ankle point (feet planted while it
##   stands up and walks), the foot kept level;
## - the glow: eyes (awake, the beam's charge), the chest cracks, an arm's
##   telegraph glow, a hit's flash (the exhibit shader's instance uniforms).
## Body space = the Colossus node's: origin on the floor under the seated
## hip joints, -Z its front.

const EYES_COLOR := Color(1.0, 0.82, 0.45)
const SEAM_COLOR := Color(1.0, 0.78, 0.38)
## Radius of the light in each arm joint: shoulder, elbow, wrist.
const SEAM_RADII: Array[float] = [0.3, 0.24, 0.17]
## Which share of the extra reach each joint gives: shoulder, elbow, wrist.
const SEAM_SHARE: Array[float] = [0.45, 0.4, 0.15]
## Gaps smaller than this stay closed (no light).
const MIN_GAP := 0.03
## Height of the ankle pivot over the sole (a planted foot's ankle).
const ANKLE_HEIGHT := 0.4
const PART_NAMES: Array[String] = ["pelvis", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	"torso", "head", "eyes", "uraeus", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "palm_l", "palm_r",
	"chest_plate_1", "chest_plate_2", "chest_plate_3", "crack_1", "crack_2", "crack_3"]

## Target posture (body space).
class Pose:
	## Pelvis pivot (seated rest (0, 3.3, 0)) and its turn (euler).
	var pelvis := Vector3(0.0, 3.3, 0.0)
	var pelvis_turn := Vector3.ZERO
	## Torso on the hips: x = lean (negative forward), y = twist (positive to
	## its left), z = side lean.
	var torso := Vector3.ZERO
	## Head on the torso: x = pitch (positive up), y = turn.
	var head := Vector3.ZERO
	## Per arm (0 = left, 1 = right): 0 = rest (hands on the knees),
	## 1 = aimed at elbow/hand.
	var arm_aim: Array[float] = [0.0, 0.0]
	var elbow: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var hand: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	## Palm bent back (+) / forward (-), rad.
	var wrist: Array[float] = [0.0, 0.0]
	## Shoulder raised (m).
	var shrug: Array[float] = [0.0, 0.0]
	## Telegraph glow of the arm (0..1).
	var arm_glow: Array[float] = [0.0, 0.0]
	## 0 = legs at rest (seated), 1 = IK to the ankle points.
	var legs_ik: float = 0.0
	var ankle: Array[Vector3] = [Vector3(-0.5, 1.0, -2.45), Vector3(0.5, 1.0, -2.45)]
	var foot_yaw: Array[float] = [0.0, 0.0]
	## 0 asleep .. 1 awake (eyes, rim).
	var eyes: float = 0.0
	## The beam's charge in the eyes (0..1.5).
	var charge: float = 0.0
	## The chest cracks (0..1.5).
	var cracks: float = 0.0
	## Light in the arm joints (multiplies the gaps' glow).
	var seams: float = 1.0
	## Stone trembling (rad).
	var shiver: float = 0.0


var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var greybox := false
## Per arm: [shoulder, elbow, wrist] seam views.
var seams: Array = [[], []]
## Per arm: a light in the elbow's seam.
var seam_lights: Array[OmniLight3D] = []
## Current gaps per arm: [shoulder, elbow, wrist] (m).
var gaps: Array = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
## Which chest plates are still on.
var plates_on: Array[bool] = [true, true, true]

var _arms: Array = []
var _legs: Array = []
var _seam_mat: StandardMaterial3D
var _flash: float = 0.0
## Per mesh: the last glow, awake and flash sent to it (only changes go out).
var _sent := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _time: float = 0.0


## The rig under [param parent] (the model, or the greybox when the model is
## off or missing).
static func create(parent: Node3D) -> ColossusRig:
	var rig := ColossusRig.new()
	rig.model = ArtLibrary.exhibit(&"colossus")
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "Colossus"
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


## Rest position (body space, seated) of [param part_name]'s pivot.
func rest_point(part_name: String) -> Vector3:
	var node := part(part_name)
	var xform := Transform3D.IDENTITY
	var chain: Array[Node3D] = []
	while node != null and node != model:
		chain.push_front(node)
		node = node.get_parent() as Node3D
	for link in chain:
		xform = xform * (rest[String(link.name)] as Transform3D)
	return xform.origin


## Rest elbow and hand (the hand marker) of arm [param side] (0 left, 1
## right), body space, seated.
func rest_elbow(side: int) -> Vector3:
	return rest_point("forearm_" + _suffix(side))


func rest_hand(side: int) -> Vector3:
	return rest_point("hand_" + _suffix(side))


## Where the shoulder joint of [param side] is for pose [param p] (body
## space).
func shoulder_at(p: Pose, side: int) -> Vector3:
	return _torso_xform(p) * ((rest["upperarm_" + _suffix(side)] as Transform3D).origin + Vector3.UP * p.shrug[side])


## Where the head pivot is for pose [param p] (body space).
func head_at(p: Pose) -> Vector3:
	return _torso_xform(p) * (rest["head"] as Transform3D).origin


## Poses the model from [param p].
func apply(p: Pose, delta: float = 0.0) -> void:
	_time += delta
	var shake := Vector3.ZERO
	if p.shiver > 0.0:
		shake = Vector3(_noise.get_noise_2d(_time * 90.0, 0.0), _noise.get_noise_2d(0.0, _time * 90.0), _noise.get_noise_2d(_time * 70.0, 50.0)) * p.shiver
	var pelvis := part("pelvis")
	pelvis.transform = Transform3D(Basis.from_euler(p.pelvis_turn), p.pelvis)
	_turn("torso", p.torso + shake)
	_turn("head", p.head + shake * 1.5)
	var torso_xform := _torso_xform(p)
	for side in 2:
		_arm(side, p, torso_xform)
	for side in 2:
		_leg(side, p)
	_glow(p, delta)


## Gives every part a short white flash (a hit landing).
func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


## Breaks chest plate [param index] (1..3) off: it falls as a physical piece
## pushed along [param push]; the crack under it shows. Returns false when
## it was off already.
func detach_plate(index: int, push: Vector3) -> bool:
	if not plates_on[index - 1]:
		return false
	plates_on[index - 1] = false
	var plate := part("chest_plate_%d" % index) as MeshInstance3D
	if plate == null:
		return true
	if plate.is_inside_tree() and plate.mesh != null:
		var materials: Array[Material] = []
		for i in plate.mesh.get_surface_count():
			materials.append(ArtLibrary.debris_material(plate.get_active_material(i)))
		Fx.piece(MeshShards.whole(plate.mesh), materials, plate.global_transform, push, 5.0)
	plate.visible = false
	return true


## Every plate back on (the Colossus calmed down: full health again).
func restore_plates() -> void:
	for i in 3:
		plates_on[i] = true
		var plate := part("chest_plate_%d" % (i + 1))
		if plate != null:
			plate.visible = true


## The eyes' midpoint and the way they look (world).
func eyes_point() -> Vector3:
	return (part("eye_l").global_position + part("eye_r").global_position) * 0.5


# --- arms -------------------------------------------------------------------

func _arm(side: int, p: Pose, torso_xform: Transform3D) -> void:
	var arm: Dictionary = _arms[side]
	var upper := arm["upper"] as Node3D
	var fore := arm["fore"] as Node3D
	var palm := arm["palm"] as Node3D
	var aim := clampf(p.arm_aim[side], 0.0, 1.0)
	var wrist := Basis(Vector3.RIGHT, p.wrist[side])
	var shoulder: Vector3 = arm["shoulder"] + Vector3.UP * p.shrug[side]
	var upper_basis := Basis.IDENTITY
	var fore_basis := Basis.IDENTITY
	var g := [0.0, 0.0, 0.0]
	if aim > 0.0:
		var to_torso := torso_xform.affine_inverse()
		var elbow_t: Vector3 = to_torso * p.elbow[side]
		var hand_t: Vector3 = to_torso * p.hand[side]
		# the upper arm points at the elbow point, parting at the shoulder and
		# the elbow when that lies beyond the bone
		var upper_run := elbow_t - shoulder
		var upper_aim := LimbIK.aim(Basis.IDENTITY, arm["axis_u"], upper_run)
		var upper_gap := maxf(upper_run.length() - float(arm["len_u"]), 0.0)
		var share_u := SEAM_SHARE[0] / (SEAM_SHARE[0] + SEAM_SHARE[1])
		var g_shoulder := upper_gap * share_u
		var g_elbow := upper_gap * (1.0 - share_u)
		var elbow_at := shoulder + upper_aim * ((arm["axis_u"] as Vector3) * (float(arm["len_u"]) + upper_gap))
		# the lower arm (forearm, palm, hand) points at the hand point
		var lower: Vector3 = arm["palm_at"] + wrist * (arm["hand_at"] as Vector3)
		var lower_run := hand_t - elbow_at
		var g_wrist := maxf(lower_run.length() - lower.length(), 0.0)
		lower += (arm["axis_f"] as Vector3) * g_wrist
		var fore_world := LimbIK.aim(upper_aim, lower.normalized(), lower_run)
		upper_basis = Basis.IDENTITY.slerp(upper_aim, aim)
		fore_basis = Basis.IDENTITY.slerp(upper_aim.inverse() * fore_world, aim)
		g = [g_shoulder * aim, g_elbow * aim, g_wrist * aim]
	var axis_u: Vector3 = arm["axis_u"]
	var axis_f: Vector3 = arm["axis_f"]
	upper.transform = Transform3D(upper_basis, shoulder + upper_basis * axis_u * float(g[0]))
	fore.transform = Transform3D(fore_basis, (arm["fore_at"] as Vector3) + axis_u * float(g[1]))
	palm.transform = Transform3D(wrist, (arm["palm_at"] as Vector3) + axis_f * float(g[2]))
	gaps[side] = g
	_show_seams(side, arm, g, p.seams, shoulder)


func _show_seams(side: int, arm: Dictionary, g: Array, intensity: float, shoulder: Vector3) -> void:
	var views: Array = seams[side]
	if views.is_empty():
		return
	var upper := arm["upper"] as Node3D
	var fore := arm["fore"] as Node3D
	var palm := arm["palm"] as Node3D
	# each gap from its socket to the part that slid out of it, in the space
	# of the part holding the socket (torso, upper arm, forearm)
	var ends := [[shoulder, upper.transform.origin], [arm["fore_at"], fore.transform.origin], [arm["palm_at"], palm.transform.origin]]
	var widest := 0.0
	for k in 3:
		var view := views[k] as MeshInstance3D
		var gap := float(g[k])
		widest = maxf(widest, gap)
		var a: Vector3 = ends[k][0]
		var b: Vector3 = ends[k][1]
		var run := b - a
		var length := run.length()
		if gap < MIN_GAP or intensity <= 0.01 or length < 0.001:
			view.visible = false
			continue
		var up := run / length
		var across := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var radius := SEAM_RADII[k] * (0.85 + 0.15 * sin(_time * 17.0 + k))
		# a little longer than the gap: its ends sink into the stone
		view.transform = Transform3D(Basis(across * radius, up * (length + 0.25), across.cross(up).normalized() * radius), a + run * 0.5)
		view.visible = true
	var light := seam_lights[side] if side < seam_lights.size() else null
	if light != null:
		light.visible = widest > MIN_GAP and intensity > 0.01
		light.light_energy = clampf(widest, 0.0, 3.0) * 1.6 * intensity
		light.position = fore.position
	if _seam_mat != null:
		_seam_mat.albedo_color.a = clampf(0.55 * intensity, 0.0, 1.0)


# --- legs -------------------------------------------------------------------

func _leg(side: int, p: Pose) -> void:
	var leg: Dictionary = _legs[side]
	var thigh := leg["thigh"] as Node3D
	var shin := leg["shin"] as Node3D
	var foot := leg["foot"] as Node3D
	var weight := clampf(p.legs_ik, 0.0, 1.0)
	if weight <= 0.0:
		thigh.transform = rest[String(thigh.name)]
		shin.transform = rest[String(shin.name)]
		foot.transform = rest[String(foot.name)]
		return
	var pelvis_xform := Transform3D(Basis.from_euler(p.pelvis_turn), p.pelvis)
	var to_pelvis := pelvis_xform.affine_inverse()
	var hip: Vector3 = leg["hip"]
	var ankle := to_pelvis * p.ankle[side]
	var reach := ankle - hip
	var distance := reach.length()
	var l1: float = leg["l1"]
	var l2: float = leg["l2"]
	var angles := LimbIK.two_bone(l1, l2, distance)
	var line := reach / maxf(distance, 0.0001)
	# the knee bends forward (the pelvis's -Z), in the plane of the reach
	var forward := to_pelvis.basis * Vector3.FORWARD
	var pole := (forward - line * forward.dot(line))
	pole = pole.normalized() if pole.length() > 0.0001 else Vector3.FORWARD
	var knee := hip + (line * cos(angles.x) + pole * sin(angles.x)) * l1
	var thigh_aim := LimbIK.aim(Basis.IDENTITY, leg["axis_t"], knee - hip)
	var shin_world := LimbIK.aim(thigh_aim, leg["axis_s"], ankle - knee)
	var shin_local := thigh_aim.inverse() * shin_world
	# the sole stays level with the floor, turned to its own yaw
	var level := Basis(Vector3.UP, p.foot_yaw[side])
	var foot_local := (pelvis_xform.basis * thigh_aim * shin_local).inverse() * level
	var thigh_rest: Transform3D = rest[String(thigh.name)]
	var shin_rest: Transform3D = rest[String(shin.name)]
	var foot_rest: Transform3D = rest[String(foot.name)]
	thigh.transform = Transform3D(Basis.IDENTITY.slerp(thigh_aim, weight), thigh_rest.origin)
	shin.transform = Transform3D(Basis.IDENTITY.slerp(shin_local.orthonormalized(), weight), shin_rest.origin)
	foot.transform = Transform3D(Basis.IDENTITY.slerp(foot_local.orthonormalized(), weight), foot_rest.origin)


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
		if key == "eyes":
			glow = p.charge
		elif key.begins_with("crack_"):
			glow = p.cracks
		elif key.ends_with("_l") and (key.begins_with("upperarm") or key.begins_with("forearm") or key.begins_with("palm")):
			glow = p.arm_glow[0]
		elif key.ends_with("_r") and (key.begins_with("upperarm") or key.begins_with("forearm") or key.begins_with("palm")):
			glow = p.arm_glow[1]
		_set_uniform(view, index * 3, &"glow", glow)
		_set_uniform(view, index * 3 + 1, &"awake", clampf(p.eyes, 0.0, 1.0))
		_set_uniform(view, index * 3 + 2, &"flash", _flash)


## Sets an instance uniform only when it changed (cheap when idle).
func _set_uniform(view: MeshInstance3D, slot: int, uniform: StringName, value: float) -> void:
	if absf(_sent[slot] - value) < 0.005:
		return
	_sent[slot] = value
	view.set_instance_shader_parameter(uniform, value)


# --- setup ---------------------------------------------------------------------

func _setup() -> void:
	_noise.seed = 4
	_noise.frequency = 0.5
	_seam_mat = GuardianLooks.glow(SEAM_COLOR, 0.55)
	for side in 2:
		var s := _suffix(side)
		var upper := part("upperarm_" + s)
		var fore := part("forearm_" + s)
		var palm := part("palm_" + s)
		var fore_at: Vector3 = (rest["forearm_" + s] as Transform3D).origin
		var palm_at: Vector3 = (rest["palm_" + s] as Transform3D).origin
		var hand_at: Vector3 = (rest["hand_" + s] as Transform3D).origin
		_arms.append({
			"upper": upper, "fore": fore, "palm": palm,
			"shoulder": (rest["upperarm_" + s] as Transform3D).origin,
			"fore_at": fore_at, "palm_at": palm_at, "hand_at": hand_at,
			"axis_u": fore_at.normalized(), "len_u": fore_at.length(),
			"axis_f": palm_at.normalized(),
		})
		var views: Array[MeshInstance3D] = []
		for k in 3:
			var mesh := CylinderMesh.new()
			mesh.top_radius = 1.0
			mesh.bottom_radius = 1.0
			mesh.height = 1.0
			mesh.radial_segments = 10
			mesh.rings = 1
			var view := MeshInstance3D.new()
			view.name = "Seam_%s_%d" % [s, k]
			view.mesh = mesh
			view.material_override = _seam_mat
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.visible = false
			(upper.get_parent() if k == 0 else (upper if k == 1 else fore)).add_child(view)
			views.append(view)
		seams[side] = views
		var light := OmniLight3D.new()
		light.name = "SeamLight_" + s
		light.light_color = SEAM_COLOR
		light.omni_range = 6.0
		light.shadow_enabled = false
		light.visible = false
		upper.add_child(light)
		seam_lights.append(light)
		var thigh := part("thigh_" + s)
		var shin := part("shin_" + s)
		var foot := part("foot_" + s)
		var knee_at: Vector3 = (rest["shin_" + s] as Transform3D).origin
		var ankle_at: Vector3 = (rest["foot_" + s] as Transform3D).origin
		_legs.append({
			"thigh": thigh, "shin": shin, "foot": foot,
			"hip": (rest["thigh_" + s] as Transform3D).origin,
			"l1": knee_at.length(), "l2": ankle_at.length(),
			"axis_t": knee_at.normalized(), "axis_s": ankle_at.normalized(),
		})
	# the bones break into chunks on its fall: cut them in the background
	if not greybox:
		for view in meshes:
			MeshShards.warm_slices(view.mesh, 3)


func _turn(part_name: String, euler: Vector3) -> void:
	var node := part(part_name)
	var base: Transform3D = rest[part_name]
	node.transform = Transform3D(Basis.from_euler(euler), base.origin)


func _torso_xform(p: Pose) -> Transform3D:
	return Transform3D(Basis.from_euler(p.pelvis_turn), p.pelvis) * Transform3D(Basis.from_euler(p.torso), (rest["torso"] as Transform3D).origin)


static func _suffix(side: int) -> String:
	return "l" if side == 0 else "r"


## The greybox body: boxes on the model's pivots, same names, same chains.
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.36, 0.3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = EYES_COLOR
	glow.emission_enabled = true
	glow.emission = EYES_COLOR
	# [name, parent, pivot (parent space), box size, box centre (own space)]
	var spec := [
		["pelvis", "", Vector3(0, 3.3, 0), Vector3(1.9, 1.2, 1.3), Vector3(0, 0.2, 0)],
		["thigh_l", "pelvis", Vector3(-0.45, 0, 0), Vector3(1.0, 0.9, 3.0), Vector3(-0.05, 0.1, -1.2)],
		["thigh_r", "pelvis", Vector3(0.45, 0, 0), Vector3(1.0, 0.9, 3.0), Vector3(0.05, 0.1, -1.2)],
		["shin_l", "thigh_l", Vector3(-0.03, 0.02, -2.3), Vector3(0.8, 2.9, 0.8), Vector3(0, -1.1, 0)],
		["shin_r", "thigh_r", Vector3(0.03, 0.02, -2.3), Vector3(0.8, 2.9, 0.8), Vector3(0, -1.1, 0)],
		["foot_l", "shin_l", Vector3(-0.02, -2.32, -0.15), Vector3(0.55, 0.5, 1.6), Vector3(0, -0.15, -0.4)],
		["foot_r", "shin_r", Vector3(0.02, -2.32, -0.15), Vector3(0.55, 0.5, 1.6), Vector3(0, -0.15, -0.4)],
		["torso", "pelvis", Vector3(0, 0.8, 0.05), Vector3(2.8, 2.3, 1.4), Vector3(0, 1.0, 0)],
		["head", "torso", Vector3(0, 1.98, 0.05), Vector3(2.0, 3.4, 1.4), Vector3(0, 1.0, -0.1)],
		["eyes", "head", Vector3(0, 0.79, -0.71), Vector3(0.58, 0.06, 0.1), Vector3(0, 0, 0.12)],
		["uraeus", "head", Vector3(0, 1.1, -0.755), Vector3(0.19, 0.64, 0.45), Vector3(0, 0.13, 0.1)],
		["upperarm_l", "torso", Vector3(-1.05, 1.62, 0.07), Vector3(0.8, 2.0, 0.9), Vector3(0, -0.7, -0.1)],
		["upperarm_r", "torso", Vector3(1.05, 1.62, 0.07), Vector3(0.8, 2.0, 0.9), Vector3(0, -0.7, -0.1)],
		["forearm_l", "upperarm_l", Vector3(0.03, -1.4, -0.32), Vector3(0.7, 0.7, 1.6), Vector3(0.1, -0.15, -0.6)],
		["forearm_r", "upperarm_r", Vector3(-0.03, -1.4, -0.32), Vector3(0.7, 0.7, 1.6), Vector3(-0.1, -0.15, -0.6)],
		["palm_l", "forearm_l", Vector3(0.3, -0.34, -1.22), Vector3(0.6, 0.25, 1.0), Vector3(0.1, -0.1, -0.5)],
		["palm_r", "forearm_r", Vector3(-0.3, -0.34, -1.22), Vector3(0.6, 0.45, 0.7), Vector3(-0.05, 0.05, -0.35)],
		["chest_plate_1", "torso", Vector3(-0.46, 0.92, -0.55), Vector3(0.64, 0.6, 0.28), Vector3.ZERO],
		["chest_plate_2", "torso", Vector3(0.05, 0.58, -0.573), Vector3(0.52, 0.6, 0.06), Vector3.ZERO],
		["chest_plate_3", "torso", Vector3(0.44, 0.26, -0.458), Vector3(0.58, 0.48, 0.28), Vector3.ZERO],
		["crack_1", "torso", Vector3(-0.46, 0.92, -0.55), Vector3(0.48, 0.43, 0.02), Vector3(0, 0, 0.18)],
		["crack_2", "torso", Vector3(0.05, 0.58, -0.573), Vector3(0.42, 0.43, 0.02), Vector3(0, 0, 0.18)],
		["crack_3", "torso", Vector3(0.44, 0.26, -0.458), Vector3(0.47, 0.39, 0.02), Vector3(0, 0, 0.18)],
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
		view.material_override = glow if String(entry[0]) in ["eyes", "crack_1", "crack_2", "crack_3"] else stone
		view.position = entry[2]
		var parent: Node3D = made.get(entry[1], root)
		parent.add_child(view)
		made[entry[0]] = view
	# markers
	for marker: Array in [["eye_l", "head", Vector3(-0.193, 0.789, -0.725)], ["eye_r", "head", Vector3(0.193, 0.789, -0.725)],
			["hand_l", "palm_l", Vector3(0.06, -0.2, -0.58)], ["hand_r", "palm_r", Vector3(-0.06, -0.19, -0.43)]]:
		var node := Node3D.new()
		node.name = marker[0]
		node.position = marker[2]
		(made[marker[1]] as Node3D).add_child(node)
	return root
