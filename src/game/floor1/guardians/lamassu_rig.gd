class_name LamassuRig
extends RefCounted
## The Lamassu's body: the Blender model "lamassu" (ArtLibrary; 20 rigid
## parts jointed at their pivots, docs/art/kit-pietro1-asyria.md §7)
## driven by a Pose, or a greybox with the same part names and pivots when
## the model is off. apply() turns the parts:
## - the body (the root: the barrel with the neck) from a position and an
##   euler turn (the settling over the hooves, the rear, the crouch, the
##   lean of a charge);
## - each leg by two-bone IK from its shoulder or hip to its fetlock, found
##   from the hoof's CONTACT point (the gait keeps those in the world): the
##   fore knee bends forward, the hock back; the shoulder slides a little
##   inside the body toward a far hoof; the hoof keeps its sole level, or
##   curls back in the swing;
## - the head (the human face) on the neck; the crown on the head;
## - each wing: spread (up and out, about its root's Z), beaten forward
##   (about Y) and its tip folded further (the wrist);
## - the tail;
## - what shows: the crown (shot off), the wing tips (chipped off);
## - the glow (the exhibit shader's instance uniforms): the eyes awake, the
##   cracks of the lamassu_cracked set (crack()), a hit's flash.
## Body space = the Lamassu node's: origin on the floor under the barrel,
## -Z its front, +X its right.

const PART_NAMES: Array[String] = ["body", "head", "headdress", "wing_l", "wing_l_tip", "wing_r", "wing_r_tip", "tail",
	"thigh_fl", "shin_fl", "hoof_fl", "thigh_fr", "shin_fr", "hoof_fr",
	"thigh_bl", "shin_bl", "hoof_bl", "thigh_br", "shin_br", "hoof_br"]
const LEGS: Array[String] = ["fl", "fr", "bl", "br"]
const SIDES: Array[String] = ["l", "r"]
## The body's rest pivot (body space).
const BODY_REST := Vector3(0.0, 1.9, 0.0)
## How far a leg's root may slide inside the body toward its hoof (m).
const ROOT_SLIDE := 0.1
## The texture sets: clean, and with the glowing cracks (phases 2-3).
const SET := "lamassu"
const CRACKED_SET := "lamassu_cracked"
## The far top corner of a wing (the tip part's space, the left wing; the
## right mirrors x).
const WING_END := Vector3(0.26, 0.65, 1.31)
const ALABASTER := Color(0.86, 0.82, 0.74)
const PAINT := Color(0.16, 0.14, 0.12)

## Target posture (body space).
class Pose:
	## The body's pivot and turn (euler: x pitch + nose up, y yaw + to its
	## left, z roll + its left side down).
	var body := BODY_REST
	var body_turn := Vector3.ZERO
	## 0 = the legs as carved, 1 = IK onto [member contacts].
	var legs_ik: float = 0.0
	## Each hoof's contact point (body space): fl, fr, bl, br.
	var contacts: Array[Vector3] = [Vector3(-0.41, 0.0, -0.98), Vector3(0.41, 0.0, -0.98), Vector3(-0.41, 0.0, 1.03), Vector3(0.41, 0.0, 1.03)]
	## Each hoof's tilt (rad): 0 sole level, negative curled back (the swing).
	var hoof_pitch: Array[float] = [0.0, 0.0, 0.0, 0.0]
	## The head on the neck: x pitch (+ up), y turn (+ left), z tilt.
	var head := Vector3.ZERO
	## Per wing (left, right): spread out from the back (rad about the
	## root's Z: the plate fans out to the side), raised (rad about X: its
	## far end lifts over the rump), beaten forward (rad about Y: the raised
	## wing sweeps round to the front), the tip folded further out (rad).
	var wing_spread: Array[float] = [0.0, 0.0]
	var wing_raise: Array[float] = [0.0, 0.0]
	var wing_beat: Array[float] = [0.0, 0.0]
	var wing_tip: Array[float] = [0.0, 0.0]
	## The tail: x lift (+ out behind), y swish (+ to its left).
	var tail := Vector2.ZERO
	## 0 asleep .. 1 awake (eyes, rim).
	var eyes: float = 0.0
	## The cracks' glow (0..2; shows with the cracked set).
	var cracks: float = 0.0
	## Stone trembling (rad).
	var shiver: float = 0.0


var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var greybox := false
var cracked := false
var crown_on := true
var tips_on: Array[bool] = [true, true]

var _legs: Array = []
var _flash: float = 0.0
var _sent := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _time: float = 0.0


## The rig under [param parent] (the model, or the greybox when the model is
## off or missing).
static func create(parent: Node3D) -> LamassuRig:
	var rig := LamassuRig.new()
	rig.model = ArtLibrary.exhibit(StringName(SET))
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "Lamassu"
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


## The body's transform for pose [param p] (body space).
static func body_xform(p: Pose) -> Transform3D:
	return Transform3D(Basis.from_euler(p.body_turn), p.body)


## Where leg [param leg]'s root (its shoulder or hip) is for pose [param p]
## (body space).
func leg_root(p: Pose, leg: int) -> Vector3:
	return body_xform(p) * (rest["thigh_" + LEGS[leg]] as Transform3D).origin


## A leg's reach (root to fetlock, straight).
func leg_reach(leg: int) -> float:
	var data: Dictionary = _legs[leg]
	return float(data["l1"]) + float(data["l2"])


## The fetlock's offset from the contact point when the sole is level and
## the body unturned (body space): up and a little back.
func fetlock_offset(leg: int) -> Vector3:
	return -((_legs[leg] as Dictionary)["contact"] as Vector3)


## The fetlock point of leg [param leg] for pose [param p] (body space):
## the contact point lifted by the hoof's height, the hoof turned with the
## body's yaw and tilted by its pitch.
func fetlock_target(p: Pose, leg: int) -> Vector3:
	var hoof_basis := Basis(Vector3.UP, p.body_turn.y) * Basis(Vector3.RIGHT, p.hoof_pitch[leg])
	return p.contacts[leg] - hoof_basis * ((_legs[leg] as Dictionary)["contact"] as Vector3)


## Poses the model from [param p].
func apply(p: Pose, delta: float = 0.0) -> void:
	_time += delta
	var shake := Vector3.ZERO
	if p.shiver > 0.0:
		shake = Vector3(_noise.get_noise_2d(_time * 90.0, 0.0), _noise.get_noise_2d(0.0, _time * 90.0), _noise.get_noise_2d(_time * 70.0, 50.0)) * p.shiver
	var body := Transform3D(Basis.from_euler(p.body_turn + shake), p.body)
	part("body").transform = body
	for leg in 4:
		_leg(leg, p, body)
	_turn("head", p.head + shake * 0.8)
	part("headdress").transform = rest["headdress"]
	for side in 2:
		_wing(side, p)
	_turn("tail", Vector3(p.tail.x, p.tail.y, 0.0))
	part("headdress").visible = crown_on
	for side in 2:
		part("wing_%s_tip" % SIDES[side]).visible = tips_on[side]
	_glow(p, delta)


## Gives every part a short white flash (a hit landing).
func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


## The contact point of hoof [param leg] now (world).
func contact(leg: int) -> Vector3:
	return part("contact_" + LEGS[leg]).global_position


## The middle of the human face (world).
func face_point() -> Vector3:
	return part("face").global_position


## The crown's marker (world; the stump's place once it is gone).
func crown_point() -> Vector3:
	return part("crown").global_position


## The bull's chest (world): where its charge and its gust come from.
func chest_point() -> Vector3:
	return part("body").global_transform * Vector3(0.0, -0.2, -1.1)


## The far top corner of wing [param side] (world).
func wing_end(side: int) -> Vector3:
	var corner := WING_END if side == 0 else Vector3(-WING_END.x, WING_END.y, WING_END.z)
	return part("wing_%s_tip" % SIDES[side]).global_transform * corner


## Shows the cracked set ([param on]) or the clean one.
func crack(on: bool) -> void:
	if cracked == on:
		return
	cracked = on
	if greybox:
		return
	var from := SET if on else CRACKED_SET
	var to := CRACKED_SET if on else SET
	for view in meshes:
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i)
			if mat != null and mat.resource_name == from:
				view.set_surface_override_material(i, ArtLibrary.exhibit_material(to))
				# (builds the two-sided debris variant now, so the fall's pieces do not make it mid-fight)
				ArtLibrary.exhibit_material(to, true)


## The crown breaks off along [param fling] (m/s) as a physical piece
## (null when it is gone already).
func drop_crown(fling: Vector3) -> RigidBody3D:
	if not crown_on:
		return null
	crown_on = false
	var piece := _fling(part("headdress") as MeshInstance3D, fling)
	part("headdress").visible = false
	return piece


## Wing [param side]'s tip breaks off along [param fling] (null when it is
## gone already).
func drop_wing_tip(side: int, fling: Vector3) -> RigidBody3D:
	if not tips_on[side]:
		return null
	tips_on[side] = false
	var view := part("wing_%s_tip" % SIDES[side]) as MeshInstance3D
	var piece := _fling(view, fling)
	view.visible = false
	return piece


## Wing [param side] breaks off whole (its plate and its tip, two pieces)
## along [param fling]: its fall. Returns the pieces.
func drop_wing(side: int, fling: Vector3) -> Array[RigidBody3D]:
	var pieces: Array[RigidBody3D] = []
	var tip := part("wing_%s_tip" % SIDES[side]) as MeshInstance3D
	if tips_on[side] and tip != null and tip.visible:
		var piece := _fling(tip, fling + Vector3(0.0, 0.5, 0.3))
		if piece != null:
			pieces.append(piece)
	tips_on[side] = false
	if tip != null:
		tip.visible = false
	var wing := part("wing_%s" % SIDES[side]) as MeshInstance3D
	if wing != null and wing.visible:
		var piece := _fling(wing, fling)
		if piece != null:
			pieces.append(piece)
		wing.visible = false
	return pieces


## Whole again: the crown, the wings and their tips back, the clean set.
func restore() -> void:
	crown_on = true
	tips_on = [true, true]
	crack(false)
	part("headdress").visible = true
	for side in 2:
		part("wing_%s" % SIDES[side]).visible = true
		part("wing_%s_tip" % SIDES[side]).visible = true


# --- legs -------------------------------------------------------------------

func _leg(leg: int, p: Pose, body: Transform3D) -> void:
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
	var target := fetlock_target(p, leg)
	var l1: float = data["l1"]
	var l2: float = data["l2"]
	# the root slides toward a hoof that is far off (the shoulder blade, the
	# hip), inside the body where nobody sees it
	var root := body * root_rest
	var reach := target - root
	var over := reach.length() - (l1 + l2) * 0.985
	var slide := Vector3.ZERO
	if over > 0.0:
		var flat := body.basis.inverse() * reach
		flat.y = 0.0
		slide = flat.normalized() * minf(over, ROOT_SLIDE) if flat.length() > 0.001 else Vector3.ZERO
	var root_local := root_rest + slide
	root = body * root_local
	var pole: Vector3 = body.basis * (Vector3.FORWARD if leg < 2 else Vector3.BACK)
	var joint := LimbIK.joint(root, target, l1, l2, pole)
	var to_body := body.basis.inverse()
	var upper_aim := LimbIK.aim(Basis.IDENTITY, data["axis_u"], to_body * (joint - root))
	var upper_world := body.basis * upper_aim
	var lower_aim := LimbIK.aim(Basis.IDENTITY, data["axis_l"], upper_world.inverse() * (target - joint))
	var lower_world := upper_world * lower_aim
	# the sole level with the floor (turned with the body's yaw), tilted
	var level := Basis(Vector3.UP, p.body_turn.y) * Basis(Vector3.RIGHT, p.hoof_pitch[leg])
	var hoof_local := (lower_world.inverse() * level).orthonormalized()
	upper.transform = Transform3D(Basis.IDENTITY.slerp(upper_aim, weight), root_rest.lerp(root_local, weight))
	lower.transform = Transform3D(Basis.IDENTITY.slerp(lower_aim, weight), (rest[String(lower.name)] as Transform3D).origin)
	hoof.transform = Transform3D(Basis.IDENTITY.slerp(hoof_local, weight), (rest[String(hoof.name)] as Transform3D).origin)


# --- wings -------------------------------------------------------------------

## Wing [param side]: spread about the root's Z (out: + for the left, -
## for the right), raised about X (the far end up), beaten forward about Y
## (the left sweeps round to its left, the right to its right), the tip
## folded on about its own Z.
func _wing(side: int, p: Pose) -> void:
	var sign := 1.0 if side == 0 else -1.0
	var wing := "wing_" + SIDES[side]
	var spread := Basis(Vector3.BACK, sign * p.wing_spread[side])
	var raise := Basis(Vector3.RIGHT, -p.wing_raise[side])
	var beat := Basis(Vector3.UP, -sign * p.wing_beat[side])
	part(wing).transform = Transform3D(beat * raise * spread, (rest[wing] as Transform3D).origin)
	var tip := wing + "_tip"
	part(tip).transform = Transform3D(Basis(Vector3.BACK, sign * p.wing_tip[side]), (rest[tip] as Transform3D).origin)


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
		_set_uniform(view, index * 3, &"glow", p.cracks if cracked else 0.0)
		_set_uniform(view, index * 3 + 1, &"awake", clampf(p.eyes, 0.0, 1.0))
		_set_uniform(view, index * 3 + 2, &"flash", Flashing.hit_flash(_flash))


func _set_uniform(view: MeshInstance3D, slot: int, uniform: StringName, value: float) -> void:
	if absf(_sent[slot] - value) < 0.005:
		return
	_sent[slot] = value
	view.set_instance_shader_parameter(uniform, value)


# --- pieces -----------------------------------------------------------------------

## [param view] flies off as a physical piece along [param fling].
func _fling(view: MeshInstance3D, fling: Vector3) -> RigidBody3D:
	if view == null or view.mesh == null or not view.is_inside_tree():
		return null
	var materials: Array[Material] = []
	for i in view.mesh.get_surface_count():
		var source := view.get_active_material(i)
		materials.append(ArtLibrary.debris_material(source) if source != null else null)
	return Fx.piece(MeshShards.whole(view.mesh), materials, view.global_transform, fling, 5.0)


# --- setup ---------------------------------------------------------------------

func _setup() -> void:
	_noise.seed = 13
	_noise.frequency = 0.5
	for leg in LEGS:
		var upper := part("thigh_" + leg)
		var lower := part("shin_" + leg)
		var hoof := part("hoof_" + leg)
		var joint_at: Vector3 = (rest["shin_" + leg] as Transform3D).origin
		var fetlock_at: Vector3 = (rest["hoof_" + leg] as Transform3D).origin
		var contact_at: Vector3 = (rest["contact_" + leg] as Transform3D).origin
		_legs.append({
			"upper": upper, "lower": lower, "hoof": hoof,
			"root": (rest["thigh_" + leg] as Transform3D).origin,
			"l1": joint_at.length(), "l2": fetlock_at.length(),
			"axis_u": joint_at.normalized(), "axis_l": fetlock_at.normalized(),
			"contact": contact_at,
		})
	# the parts break into chunks on its fall: cut them in the background
	if not greybox:
		for view in meshes:
			MeshShards.warm_slices(view.mesh, 2)


func _turn(part_name: String, euler: Vector3) -> void:
	var node := part(part_name)
	node.transform = Transform3D(Basis.from_euler(euler), (rest[part_name] as Transform3D).origin)


## The greybox body: boxes on the model's pivots, same names, same chains
## (Godot space; the catalogue's pivots).
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = ALABASTER
	stone.roughness = 0.9
	var paint := StandardMaterial3D.new()
	paint.albedo_color = PAINT
	# [name, parent, pivot (parent space), box size, box centre (own space)]
	var spec := [
		["body", "", Vector3(0.0, 1.9, 0.0), Vector3(1.1, 1.2, 2.6), Vector3(0.0, 0.05, 0.05)],
		["head", "body", Vector3(0.0, 0.7, -1.22), Vector3(0.74, 1.0, 0.86), Vector3(0.0, 0.26, -0.3)],
		["headdress", "head", Vector3(0.0, 0.62, -0.28), Vector3(0.52, 0.76, 0.52), Vector3(0.0, 0.38, 0.0)],
		["wing_l", "body", Vector3(-0.54, 0.28, -0.68), Vector3(0.08, 0.72, 1.2), Vector3(0.1, 0.3, 0.6)],
		["wing_l_tip", "wing_l", Vector3(0.23, 0.58, 1.15), Vector3(0.08, 0.64, 1.3), Vector3(0.0, 0.3, 0.62)],
		["wing_r", "body", Vector3(0.54, 0.28, -0.68), Vector3(0.08, 0.72, 1.2), Vector3(-0.1, 0.3, 0.6)],
		["wing_r_tip", "wing_r", Vector3(-0.23, 0.58, 1.15), Vector3(0.08, 0.64, 1.3), Vector3(0.0, 0.3, 0.62)],
		["tail", "body", Vector3(0.0, 0.1, 1.46), Vector3(0.2, 1.4, 0.26), Vector3(0.0, -0.7, 0.08)],
		["thigh_fl", "body", Vector3(-0.41, -0.35, -0.8), Vector3(0.32, 0.9, 0.36), Vector3(0.0, -0.42, -0.03)],
		["shin_fl", "thigh_fl", Vector3(0.0, -0.83, -0.06), Vector3(0.24, 0.5, 0.26), Vector3(0.0, -0.24, -0.02)],
		["hoof_fl", "shin_fl", Vector3(0.0, -0.48, -0.04), Vector3(0.3, 0.26, 0.34), Vector3(0.0, -0.11, -0.06)],
		["thigh_fr", "body", Vector3(0.41, -0.35, -0.8), Vector3(0.32, 0.9, 0.36), Vector3(0.0, -0.42, -0.03)],
		["shin_fr", "thigh_fr", Vector3(0.0, -0.83, -0.06), Vector3(0.24, 0.5, 0.26), Vector3(0.0, -0.24, -0.02)],
		["hoof_fr", "shin_fr", Vector3(0.0, -0.48, -0.04), Vector3(0.3, 0.26, 0.34), Vector3(0.0, -0.11, -0.06)],
		["thigh_bl", "body", Vector3(-0.41, -0.25, 0.98), Vector3(0.34, 1.0, 0.42), Vector3(0.0, -0.48, 0.1)],
		["shin_bl", "thigh_bl", Vector3(0.0, -0.95, 0.22), Vector3(0.24, 0.48, 0.26), Vector3(0.0, -0.23, -0.04)],
		["hoof_bl", "shin_bl", Vector3(0.0, -0.46, -0.1), Vector3(0.3, 0.26, 0.34), Vector3(0.0, -0.11, -0.05)],
		["thigh_br", "body", Vector3(0.41, -0.25, 0.98), Vector3(0.34, 1.0, 0.42), Vector3(0.0, -0.48, 0.1)],
		["shin_br", "thigh_br", Vector3(0.0, -0.95, 0.22), Vector3(0.24, 0.48, 0.26), Vector3(0.0, -0.23, -0.04)],
		["hoof_br", "shin_br", Vector3(0.0, -0.46, -0.1), Vector3(0.3, 0.26, 0.34), Vector3(0.0, -0.11, -0.05)],
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
		view.material_override = paint if entry[0] == "headdress" else stone
		view.position = entry[2]
		var parent: Node3D = made.get(entry[1], root)
		parent.add_child(view)
		made[entry[0]] = view
	for marker: Array in [["face", "head", Vector3(0.0, 0.47, -0.59)], ["crown", "headdress", Vector3(0.0, 0.4, 0.0)],
			["contact_fl", "hoof_fl", Vector3(0.0, -0.24, -0.08)], ["contact_fr", "hoof_fr", Vector3(0.0, -0.24, -0.08)],
			["contact_bl", "hoof_bl", Vector3(0.0, -0.24, -0.07)], ["contact_br", "hoof_br", Vector3(0.0, -0.24, -0.07)]]:
		var node := Node3D.new()
		node.name = marker[0]
		node.position = marker[2]
		(made[marker[1]] as Node3D).add_child(node)
	return root
