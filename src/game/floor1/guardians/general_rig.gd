class_name GeneralRig
extends RefCounted
## The Samurai General's body: the Blender model "samurai_general"
## (ArtLibrary; 26 rigid parts jointed at their pivots, see
## docs/art/kit-pietro1-azja.md §9) driven by a Pose, or a greybox with the
## same part names and pivots when the model is off. apply() turns the parts:
## - the pelvis (the root) from a position and an euler turn;
## - each leg by two-bone IK from its hip to its ankle point (the footwork's
##   feet, planted in the world), the knee bending forward, the sole level;
## - the torso and the head by eulers; the four kusazuri panels swinging out
##   on their top edges; the sode hanging off the shoulders;
## - the sword as a frame (the right fist's grip point on the hilt and the
##   blade's line) and BOTH ARMS by two-bone IK onto the hilt: each fist's
##   grip point lands on the hilt and the fists turn with it (hands_on may
##   let a hand go to a free target - the draw, the bow);
## - the bow: slung on the back, or in the left fist with its string (two
##   segments to the nock; the baked string is cut out of the mesh) drawn
##   back to the right fist, the limbs bending with the draw; the arrow
##   nocked in the right hand;
## - the armour's assembly: with [member Pose.assembly] under 1 the parts
##   hang on the stand (world transform [member stand]) and fly together in
##   order (feet, legs, hips and skirt, cuirass, arms, shoulder guards,
##   helmet) as it goes 0 -> 1;
## - the glow: the eyes (awake; under 0 they die), the blade's glint and the
##   arrow's ember (glow), a hit's flash (the exhibit shader's uniforms).
## Body space = the General node's: origin on the floor between the feet,
## -Z his front, +X his right.

const PART_NAMES: Array[String] = ["pelvis", "torso", "head", "upperarm_l", "upperarm_r", "sode_l", "sode_r",
	"forearm_l", "forearm_r", "hand_l", "hand_r", "sword", "saya", "bow", "quiver", "arrow", "thigh_l", "thigh_r",
	"shin_l", "shin_r", "foot_l", "foot_r", "kusazuri_f", "kusazuri_b", "kusazuri_l", "kusazuri_r"]
const MARKERS: Array[String] = ["face", "back", "blade_tip", "glint", "bow_grip", "arrow_nock", "saya_mouth"]
## The parts that ride their parents as carved (no pose turns them): the
## scabbard on the hips, the quiver on the back.
const UNPOSED: Array[String] = ["saya", "quiver"]
const SIDES: Array[String] = ["l", "r"]
## The pelvis's rest pivot (body space).
const PELVIS_REST := Vector3(0.0, 1.292, 0.0)
## The left fist's grip point lies this far down the hilt from the right's.
const LEFT_GRIP_DOWN := 0.272
## Hilt: the pommel this far behind the right fist, the guard this far ahead.
const POMMEL_BACK := 0.45
const GUARD_AHEAD := 0.17
## How far the sode follow the world (hang) rather than the arm (0..1).
const SODE_HANG := 0.55
## The baked bowstring: vertices within this of the line between the bow's
## ends.
const STRING_CUT := 0.02
## The bow's limbs bend this far (rad) at full draw.
const LIMB_BEND := 0.16
## The eyes die at this awake value (the shader's emission reaches zero).
const EYES_DEAD := -0.6
## Where the General hangs on his stand (relative to the stand's frame, a
## rack 1.2 m behind the post): part -> offset from the posed rest. The
## armour hangs spread a little, the helmet high, the feet on the floor.
const STAND_SCATTER := {
	"head": Vector3(0.0, 0.12, 0.0), "sode_l": Vector3(-0.12, -0.05, 0.0), "sode_r": Vector3(0.12, -0.05, 0.0),
	"upperarm_l": Vector3(-0.06, 0.0, 0.0), "upperarm_r": Vector3(0.06, 0.0, 0.0),
	"forearm_l": Vector3(-0.08, 0.0, 0.0), "forearm_r": Vector3(0.08, 0.0, 0.0),
	"hand_l": Vector3(-0.1, 0.0, 0.0), "hand_r": Vector3(0.1, 0.0, 0.0),
	"kusazuri_f": Vector3(0.0, 0.0, -0.08), "kusazuri_b": Vector3(0.0, 0.0, 0.08),
	"kusazuri_l": Vector3(-0.08, 0.0, 0.0), "kusazuri_r": Vector3(0.08, 0.0, 0.0),
}
## The assembly's order: part -> [from, to] of Pose.assembly over which it
## flies from the stand to its place (the feet first, the helmet last).
const ASSEMBLY := {
	"foot_l": [0.0, 0.14], "foot_r": [0.03, 0.17],
	"shin_l": [0.08, 0.24], "shin_r": [0.1, 0.26], "thigh_l": [0.14, 0.3], "thigh_r": [0.16, 0.32],
	"pelvis": [0.24, 0.42], "kusazuri_f": [0.28, 0.44], "kusazuri_b": [0.3, 0.46], "kusazuri_l": [0.32, 0.48], "kusazuri_r": [0.34, 0.5],
	"saya": [0.3, 0.46], "sword": [0.3, 0.46],
	"torso": [0.42, 0.6], "bow": [0.46, 0.62], "quiver": [0.46, 0.62], "arrow": [0.46, 0.62],
	"upperarm_l": [0.56, 0.72], "upperarm_r": [0.58, 0.74], "forearm_l": [0.6, 0.76], "forearm_r": [0.62, 0.78],
	"hand_l": [0.64, 0.8], "hand_r": [0.66, 0.82],
	"sode_l": [0.72, 0.86], "sode_r": [0.74, 0.88],
	"head": [0.86, 1.0],
}

## Target posture (body space).
class Pose:
	## The pelvis's pivot and turn (euler: x pitch + nose up, y yaw + to his
	## left, z roll + his left side down).
	var pelvis := PELVIS_REST
	var pelvis_turn := Vector3.ZERO
	## 0 = the legs as carved, 1 = IK to [member feet].
	var legs_ik: float = 1.0
	## Ankle points (body space): left, right.
	var feet: Array[Vector3] = [Vector3(-0.19, 0.136, 0.2), Vector3(0.19, 0.136, -0.24)]
	## Each foot's tilt (rad): 0 sole level, positive toes down.
	var foot_pitch: Array[float] = [0.0, 0.0]
	## The torso on the pelvis: x lean (- forward), y twist (+ to his left),
	## z side lean (+ his left shoulder down). The head on the torso likewise.
	var torso := Vector3.ZERO
	var head := Vector3.ZERO
	## The sword's frame: the right fist's grip point on the hilt (body
	## space), the blade's line (pommel -> point, unit), the roll about it.
	var sword_grip := Vector3(0.095, 1.537, -0.49)
	var sword_dir := Vector3(0.039, 0.635, -0.771).normalized()
	var sword_roll: float = 0.0
	var sword_shown := true
	## Per hand (0 left, 1 right): 1 = the fist on the hilt, 0 = at
	## [member hand_free] (wrist point, body space) turned by
	## [member hand_basis] (body space); between: a blend.
	var hands_on: Array[float] = [1.0, 1.0]
	var hand_free: Array[Vector3] = [Vector3(-0.42, 1.2, -0.1), Vector3(0.42, 1.2, -0.1)]
	var hand_basis: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]
	## The elbows bend toward these (body space directions); ZERO = the
	## natural pole (the rest elbow's side, turned with the hilt).
	var elbow_pole: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	## Shoulder guards (left, right): x swing (+ forward), y swing out.
	var sode: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	## Skirt panels' swing out (rad): front, back, left, right.
	var kusazuri: Array[float] = [0.0, 0.0, 0.0, 0.0]
	## The bow: in the left fist (else slung on the back), aimed along
	## [member bow_aim] (body space, unit), drawn 0..1 to the right fist; the
	## arrow nocked in the right hand.
	var bow_in_hand := false
	var bow_aim := Vector3.FORWARD
	var bow_drawn: float = 0.0
	var arrow_in_hand := false
	## 0 = hanging on the stand .. 1 = assembled.
	var assembly: float = 1.0
	## The eyes: 0 asleep .. 1 awake (EYES_DEAD: dead).
	var eyes: float = 0.0
	## The blade's glint (0..1+) and the arrow's ember.
	var glint: float = 0.0
	var arrow_glow: float = 0.0
	## Trembling (rad).
	var shiver: float = 0.0


var model: Node3D
var parts: Dictionary = {}
var rest: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var greybox := false
## Where he hangs asleep (world; the keeper's stand behind the post).
var stand := Transform3D.IDENTITY
## The blade's line and the grip as carved (body space).
var grip_rest := Vector3(0.095, 1.537, -0.49)
var blade_axis_rest := Vector3(0.039, 0.635, -0.771).normalized()
var blade_length: float = 1.78
## The saya: its mouth (body space, rest) and its line into the scabbard.
var saya_mouth_rest := Vector3(-0.35, 1.469, -0.342)
var saya_axis := Vector3(0.0, -0.49, 0.87).normalized()
## The bow (bow space): its ends (lower, upper), its grip, its long axis.
var bow_ends: Array[Vector3] = [Vector3(-0.58, -0.95, 0.01), Vector3(0.48, 1.23, 0.0)]
var bow_grip_local := Vector3(-0.2, -0.19, 0.12)
var bow_axis := Vector3(1.06, 2.18, -0.01).normalized()
## The arrow (arrow space): its head and its nock.
var arrow_head_local := Vector3(0.0, -0.095, 0.0)
var arrow_nock_local := Vector3(0.15, 1.24, 0.0)

var _legs: Array = []
var _arms: Array = []
var _grip_offset: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _pole_rest: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _flash: float = 0.0
var _sent := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _string: Array[MeshInstance3D] = []
var _limbs: Array[MeshInstance3D] = []
var _bow_body: MeshInstance3D
var _posed: Dictionary = {}
var _stand_cache: Dictionary = {}
var _hung: Dictionary = {}


## The rig under [param parent] (the model, or the greybox when the model is
## off or missing).
static func create(parent: Node3D) -> GeneralRig:
	var rig := GeneralRig.new()
	rig.model = ArtLibrary.exhibit(&"samurai_general")
	if rig.model == null:
		rig.model = _make_greybox()
		rig.greybox = true
	rig.model.name = "General"
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


## The pelvis's transform for pose [param p] (body space).
static func pelvis_xform(p: Pose) -> Transform3D:
	return Transform3D(Basis.from_euler(p.pelvis_turn), p.pelvis)


## The torso's transform for pose [param p] (body space).
func torso_xform(p: Pose) -> Transform3D:
	return pelvis_xform(p) * Transform3D(Basis.from_euler(p.torso), (rest["torso"] as Transform3D).origin)


## The head's transform for pose [param p] (body space).
func head_xform(p: Pose) -> Transform3D:
	return torso_xform(p) * Transform3D(Basis.from_euler(p.head), (rest["head"] as Transform3D).origin)


## Where arm [param side]'s shoulder is for pose [param p] (body space).
func shoulder_at(p: Pose, side: int) -> Vector3:
	return torso_xform(p) * (rest["upperarm_" + SIDES[side]] as Transform3D).origin


## Where a leg's hip is for pose [param p] (body space).
func hip_at(p: Pose, leg: int) -> Vector3:
	return pelvis_xform(p) * (rest["thigh_" + SIDES[leg]] as Transform3D).origin


## Arm [param side]'s reach (shoulder to wrist, straight).
func arm_reach(side: int) -> float:
	var arm: Dictionary = _arms[side]
	return float(arm["l1"]) + float(arm["l2"])


## A leg's reach (hip to ankle, straight).
func leg_reach(leg: int) -> float:
	var data: Dictionary = _legs[leg]
	return float(data["l1"]) + float(data["l2"])


## The sword's frame for pose [param p] (body space): the right fist's
## grip point and the blade's turn from its carved line.
func sword_frame(p: Pose) -> Transform3D:
	var dir := p.sword_dir.normalized() if p.sword_dir.length() > 0.001 else blade_axis_rest
	var turn := LimbIK.aim(Basis.IDENTITY, blade_axis_rest, dir)
	if absf(p.sword_roll) > 0.0001:
		turn = (Basis(dir, p.sword_roll) * turn).orthonormalized()
	return Transform3D(turn, p.sword_grip)


## Where fist [param side]'s grip point lies on the hilt for pose [param p]
## (body space): the right fist's at the frame's origin, the left's
## LEFT_GRIP_DOWN down the hilt.
func hilt_point(p: Pose, side: int) -> Vector3:
	var frame := sword_frame(p)
	if side == 1:
		return frame.origin
	return frame.origin - frame.basis * blade_axis_rest * LEFT_GRIP_DOWN


## The hilt as a segment (body space): pommel, guard.
func hilt_segment(p: Pose) -> Array[Vector3]:
	var frame := sword_frame(p)
	var axis := frame.basis * blade_axis_rest
	return [frame.origin - axis * POMMEL_BACK, frame.origin + axis * GUARD_AHEAD]


## The blade's point for pose [param p] (body space).
func blade_point(p: Pose) -> Vector3:
	var frame := sword_frame(p)
	return frame.origin + frame.basis * blade_axis_rest * blade_length


## Where fist [param side]'s grip point is now (world), as the parts stand.
func fist_point(side: int) -> Vector3:
	return part("hand_" + SIDES[side]).global_transform * _grip_offset[side]


## The grip offset of fist [param side] (hand space): where the hilt passes
## through the fist.
func grip_offset(side: int) -> Vector3:
	return _grip_offset[side]


## The eyes (world): the face marker.
func eyes_point() -> Vector3:
	return part("face").global_position


## The blade's glint spot and its point (world).
func glint_point() -> Vector3:
	return part("glint").global_position


func tip_point() -> Vector3:
	return part("blade_tip").global_position


## The nock of the arrow in the hand (world).
func nock_point() -> Vector3:
	return part("arrow").global_transform * arrow_nock_local


## The arrow's line in the hand (world, head -> nock reversed: the flight).
func arrow_line() -> Vector3:
	return -(part("arrow").global_basis * (arrow_nock_local - arrow_head_local)).normalized()


## Poses the model from [param p].
func apply(p: Pose, delta: float = 0.0) -> void:
	_time += delta
	var shake := Vector3.ZERO
	if p.shiver > 0.0:
		shake = Vector3(_noise.get_noise_2d(_time * 90.0, 0.0), _noise.get_noise_2d(0.0, _time * 90.0), _noise.get_noise_2d(_time * 70.0, 50.0)) * p.shiver
	var pelvis := Transform3D(Basis.from_euler(p.pelvis_turn + shake), p.pelvis)
	part("pelvis").transform = pelvis
	# the parts no pose drives sit at rest on their parents (the assembly
	# reads every part's place before it flies them: one left where its last
	# flight frame put it would stay there for good)
	for part_name in UNPOSED:
		var still := part(part_name)
		if still != null:
			still.transform = rest[part_name]
	for leg in 2:
		_leg(leg, p, pelvis)
	_kusazuri(p)
	_turn("torso", p.torso + shake * 0.6)
	_turn("head", p.head + shake)
	var torso := pelvis * part("torso").transform
	var frame := sword_frame(p)
	for side in 2:
		_arm(side, p, torso, frame)
	_sword(p, frame)
	_bow(p, torso)
	for side in 2:
		_sode(side, p)
	part("sword").visible = p.sword_shown
	if p.assembly < 1.0:
		_assemble(p.assembly)
	_glow(p, delta)


## Gives every part a short white flash (a hit landing).
func flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


## Lends the model's arrow to the volley's arrows (GeneralArrow).
func lend_arrow() -> void:
	var view := part("arrow") as MeshInstance3D
	if view != null and not greybox:
		GeneralArrow.adopt(view, arrow_head_local, arrow_nock_local)


# --- legs ---------------------------------------------------------------------

func _leg(leg: int, p: Pose, pelvis: Transform3D) -> void:
	var data: Dictionary = _legs[leg]
	var thigh := data["thigh"] as Node3D
	var shin := data["shin"] as Node3D
	var foot := data["foot"] as Node3D
	var weight := clampf(p.legs_ik, 0.0, 1.0)
	if weight <= 0.0:
		thigh.transform = rest[String(thigh.name)]
		shin.transform = rest[String(shin.name)]
		foot.transform = rest[String(foot.name)]
		return
	var hip := pelvis * (data["hip"] as Vector3)
	var target: Vector3 = p.feet[leg]
	var pole: Vector3 = pelvis.basis * Vector3.FORWARD
	var knee := LimbIK.joint(hip, target, data["l1"], data["l2"], pole)
	var to_pelvis := pelvis.basis.inverse()
	var thigh_aim := LimbIK.aim(Basis.IDENTITY, data["axis_u"], to_pelvis * (knee - hip))
	var thigh_world := pelvis.basis * thigh_aim
	var shin_aim := LimbIK.aim(Basis.IDENTITY, data["axis_l"], thigh_world.inverse() * (target - knee))
	var shin_world := thigh_world * shin_aim
	# the sole level with the floor (turned with the pelvis's yaw), tilted
	var level := Basis(Vector3.UP, p.pelvis_turn.y) * Basis(Vector3.RIGHT, -p.foot_pitch[leg])
	var foot_local := (shin_world.inverse() * level).orthonormalized()
	thigh.transform = Transform3D(Basis.IDENTITY.slerp(thigh_aim, weight), (rest[String(thigh.name)] as Transform3D).origin)
	shin.transform = Transform3D(Basis.IDENTITY.slerp(shin_aim, weight), (rest[String(shin.name)] as Transform3D).origin)
	foot.transform = Transform3D(Basis.IDENTITY.slerp(foot_local, weight), (rest[String(foot.name)] as Transform3D).origin)


func _kusazuri(p: Pose) -> void:
	# [panel, axis, sign]: + swings the bottom edge out
	for spec: Array in [["kusazuri_f", Vector3.RIGHT, 1.0, 0], ["kusazuri_b", Vector3.RIGHT, -1.0, 1], ["kusazuri_l", Vector3.BACK, -1.0, 2], ["kusazuri_r", Vector3.BACK, 1.0, 3]]:
		var node := part(spec[0])
		if node == null:
			continue
		var angle: float = p.kusazuri[spec[3]] * float(spec[2])
		node.transform = Transform3D(Basis(spec[1], angle), (rest[spec[0]] as Transform3D).origin)


# --- arms and the sword -----------------------------------------------------

func _arm(side: int, p: Pose, torso: Transform3D, frame: Transform3D) -> void:
	var data: Dictionary = _arms[side]
	var upper := data["upper"] as Node3D
	var fore := data["fore"] as Node3D
	var hand := data["hand"] as Node3D
	var on := clampf(p.hands_on[side], 0.0, 1.0)
	var shoulder := torso * (data["shoulder"] as Vector3)
	# the fist on the hilt: its grip point on the hilt, turned with the blade
	var hilt := frame.origin if side == 1 else frame.origin - frame.basis * blade_axis_rest * LEFT_GRIP_DOWN
	var on_wrist := hilt - frame.basis * _grip_offset[side]
	var on_basis := frame.basis
	var wrist := p.hand_free[side].lerp(on_wrist, on)
	var pole: Vector3 = p.elbow_pole[side]
	if pole.length_squared() < 0.0001:
		var outward := Vector3(-1.0 if side == 0 else 1.0, 0.0, 0.0)
		pole = (frame.basis * _pole_rest[side]).lerp(_pole_rest[side], 1.0 - on) * 0.6 + outward * 0.45 + Vector3.DOWN * 0.25
	var elbow := LimbIK.joint(shoulder, wrist, data["l1"], data["l2"], pole)
	var to_torso := torso.basis.inverse()
	var upper_aim := LimbIK.aim(Basis.IDENTITY, data["axis_u"], to_torso * (elbow - shoulder))
	var upper_world := torso.basis * upper_aim
	var fore_aim := LimbIK.aim(Basis.IDENTITY, data["axis_f"], upper_world.inverse() * (wrist - elbow))
	var fore_world := upper_world * fore_aim
	# a free hand follows its forearm unless the pose turns it
	var free_basis := fore_world if p.hand_basis[side] == Basis.IDENTITY else p.hand_basis[side].orthonormalized()
	var hand_world := free_basis.slerp(on_basis, on)
	upper.transform = Transform3D(upper_aim, (rest[String(upper.name)] as Transform3D).origin)
	fore.transform = Transform3D(fore_aim, (rest[String(fore.name)] as Transform3D).origin)
	hand.transform = Transform3D((fore_world.inverse() * hand_world).orthonormalized(), (rest[String(hand.name)] as Transform3D).origin)


## The sword exactly on its frame, whatever the hand's reach.
func _sword(_p: Pose, frame: Transform3D) -> void:
	var sword := part("sword")
	var hand := part("hand_r")
	var hand_world := _model_xform(hand)
	sword.transform = hand_world.affine_inverse() * frame


## The sode hang off the shoulders: mostly with the world (a pendulum),
## partly with the arm.
func _sode(side: int, p: Pose) -> void:
	var node := part("sode_" + SIDES[side])
	if node == null:
		return
	var upper := part("upperarm_" + SIDES[side])
	var upper_world := _model_xform(upper).basis
	var swing: Vector2 = p.sode[side]
	var hang := Basis(Vector3.UP, p.pelvis_turn.y + p.torso.y) * Basis.from_euler(Vector3(swing.x, 0.0, (-swing.y if side == 0 else swing.y)))
	var local := (upper_world.inverse() * hang).orthonormalized()
	node.transform = Transform3D(Basis.IDENTITY.slerp(local, SODE_HANG), (rest[String(node.name)] as Transform3D).origin)


# --- the bow ----------------------------------------------------------------------

func _bow(p: Pose, torso: Transform3D) -> void:
	var bow := part("bow")
	var arrow := part("arrow")
	var quiver := part("quiver")
	if bow == null:
		return
	if not p.bow_in_hand:
		bow.transform = rest["bow"]
		if arrow != null:
			arrow.transform = rest["arrow"]
			arrow.visible = true
		_string_visible(false)
		_bend_limbs(0.0)
		return
	# the bow in the left fist: its grip on the fist's grip point, its +Z
	# (the belly, away from the archer) along the aim, its long axis up with
	# the yumi's slant
	var aim := p.bow_aim.normalized() if p.bow_aim.length() > 0.001 else Vector3.FORWARD
	var r1 := LimbIK.aim(Basis.IDENTITY, Vector3.BACK, aim)
	var up := Vector3.UP - aim * Vector3.UP.dot(aim)
	up = up.normalized() if up.length() > 0.001 else Vector3.RIGHT
	var slanted := (Basis(aim, 0.2) * up).normalized()
	var axis_now := (r1 * bow_axis)
	axis_now = (axis_now - aim * axis_now.dot(aim)).normalized()
	var roll := axis_now.signed_angle_to(slanted, aim)
	var basis := (Basis(aim, roll) * r1).orthonormalized()
	var fist := fist_point_posed(0)
	var bow_world := Transform3D(basis, fist - basis * bow_grip_local)
	bow.transform = _local_under(bow, bow_world)
	_bend_limbs(p.bow_drawn)
	# the string: from the ends to the nock (the right fist when drawn)
	var ends: Array[Vector3] = [bow_world * bow_ends[0], bow_world * bow_ends[1]]
	var rest_nock := ends[0].lerp(ends[1], 0.35)
	var nock := rest_nock.lerp(fist_point_posed(1), clampf(p.bow_drawn, 0.0, 1.0))
	_string_visible(true)
	_string_segment(0, ends[0], nock)
	_string_segment(1, ends[1], nock)
	if arrow != null:
		arrow.visible = p.arrow_in_hand
		if p.arrow_in_hand:
			# the arrow along the aim, its nock at the right fist
			var line := (arrow_nock_local - arrow_head_local).normalized()
			var arrow_basis := LimbIK.aim(Basis.IDENTITY, line, -aim)
			var arrow_world := Transform3D(arrow_basis, nock - arrow_basis * arrow_nock_local)
			arrow.transform = _local_under(arrow, arrow_world)
		elif quiver != null:
			arrow.transform = rest["arrow"]


## A hand's grip point as the parts now stand (body space).
func fist_point_posed(side: int) -> Vector3:
	return _model_xform(part("hand_" + SIDES[side])) * _grip_offset[side]


## The sword's frame when it sits in the scabbard (body space, the pelvis at
## rest): the blade down the saya's line, the hilt out of its mouth.
func sheathed_grip() -> Vector3:
	return saya_mouth_rest - saya_axis * (GUARD_AHEAD + 0.03)


func sheathed_dir() -> Vector3:
	return saya_axis


func _bend_limbs(draw: float) -> void:
	if _limbs.size() < 2:
		return
	var bend := LIMB_BEND * clampf(draw, 0.0, 1.0)
	var pivot := bow_grip_local
	var across := bow_axis.cross(Vector3.BACK).normalized()
	for i in 2:
		var sign := -1.0 if i == 0 else 1.0
		var turn := Basis(across, sign * bend)
		_limbs[i].transform = Transform3D(turn, pivot - turn * pivot)


func _string_visible(shown: bool) -> void:
	for segment in _string:
		segment.visible = shown


func _string_segment(index: int, from: Vector3, to: Vector3) -> void:
	if index >= _string.size():
		return
	var segment := _string[index]
	var length := from.distance_to(to)
	var middle := (from + to) * 0.5
	var line := (to - from).normalized() if length > 0.001 else Vector3.UP
	var basis := LimbIK.aim(Basis.IDENTITY, Vector3.UP, line)
	var world := Transform3D(basis * Basis.from_scale(Vector3(1.0, maxf(length, 0.01), 1.0)), middle)
	segment.transform = _local_under(segment, world)


# --- the assembly --------------------------------------------------------------------

## The parts fly off the stand onto their places as [param assembly] goes
## 0 -> 1 (each over its ASSEMBLY window, in order). Every part is placed
## in world space here (parents first): a part already home must not be
## dragged along by a parent still flying.
func _assemble(assembly: float) -> void:
	_posed.clear()
	for part_name in PART_NAMES:
		var node := part(part_name)
		if node != null:
			_posed[part_name] = _model_xform(node)
	if not model.is_inside_tree():
		return
	var model_world := model.global_transform
	for part_name in PART_NAMES:
		var node := part(part_name)
		if node == null:
			continue
		var posed: Transform3D = model_world * (_posed[part_name] as Transform3D)
		var w := part_assembly(part_name, assembly)
		if w >= 1.0:
			node.global_transform = posed
			continue
		var eased := MotionClip.eased(MotionClip.OUT_BACK, w) if w > 0.0 else 0.0
		var hung := _stand_xform(part_name)
		node.global_transform = hung.interpolate_with(posed, eased)


## 0..1: how far [param part_name] has come off the stand at [param assembly].
static func part_assembly(part_name: String, assembly: float) -> float:
	var window: Array = ASSEMBLY.get(part_name, [0.0, 1.0])
	return clampf((assembly - float(window[0])) / maxf(float(window[1]) - float(window[0]), 0.001), 0.0, 1.0)


## Where [param part_name] hangs on the stand (world): its place in the
## hanging pose carried to the stand's frame, scattered a little.
func _stand_xform(part_name: String) -> Transform3D:
	if _stand_cache.has(part_name):
		return _stand_cache[part_name]
	var scatter: Vector3 = STAND_SCATTER.get(part_name, Vector3.ZERO)
	var local: Transform3D = _hung.get(part_name, rest_xform(part_name))
	var hung := stand * Transform3D(local.basis, local.origin + scatter)
	_stand_cache[part_name] = hung
	return hung


## The stand moved (the keeper placed it): forget the cached places.
func set_stand(at: Transform3D) -> void:
	stand = at
	_stand_cache.clear()


## The pose the armour hangs in on its stand: the legs as carved, the arms
## down, the sword in its scabbard, the bow on the back, asleep.
func hanging_pose() -> Pose:
	var p := Pose.new()
	p.legs_ik = 0.0
	p.sword_grip = sheathed_grip()
	p.sword_dir = sheathed_dir()
	p.hands_on = [0.0, 0.0]
	p.hand_free = [Vector3(-0.46, 1.15, -0.02), Vector3(0.46, 1.15, -0.02)]
	p.eyes = 0.0
	return p


## Remembers where every part stands in the hanging pose (body space), for
## the stand. Called once at setup (the model must be in the tree).
func _remember_hanging() -> void:
	apply(hanging_pose())
	_hung.clear()
	for part_name in PART_NAMES:
		var node := part(part_name)
		if node != null:
			_hung[part_name] = _model_xform(node)


# --- glow ---------------------------------------------------------------------

func _glow(p: Pose, delta: float) -> void:
	_flash = move_toward(_flash, 0.0, 6.0 * delta)
	if greybox:
		return
	var views: Array[MeshInstance3D] = meshes.duplicate()
	views.append_array(_limbs)
	if _sent.size() != views.size() * 3:
		_sent.resize(views.size() * 3)
		_sent.fill(-1.0)
	for index in views.size():
		var view := views[index]
		if view.mesh == null:
			continue
		var key := String(view.name)
		var glow := 0.0
		if key == "sword":
			glow = p.glint
		elif key == "arrow":
			glow = p.arrow_glow
		_set_uniform(view, index * 3, &"glow", glow)
		_set_uniform(view, index * 3 + 1, &"awake", clampf(p.eyes, EYES_DEAD, 1.0))
		_set_uniform(view, index * 3 + 2, &"flash", _flash)


func _set_uniform(view: MeshInstance3D, slot: int, uniform: StringName, value: float) -> void:
	if absf(_sent[slot] - value) < 0.005:
		return
	_sent[slot] = value
	view.set_instance_shader_parameter(uniform, value)


# --- setup -------------------------------------------------------------------------

func _setup() -> void:
	_noise.seed = 17
	_noise.frequency = 0.5
	for leg in 2:
		var s := SIDES[leg]
		var knee_at: Vector3 = (rest["shin_" + s] as Transform3D).origin
		var ankle_at: Vector3 = (rest["foot_" + s] as Transform3D).origin
		_legs.append({
			"thigh": part("thigh_" + s), "shin": part("shin_" + s), "foot": part("foot_" + s),
			"hip": (rest["thigh_" + s] as Transform3D).origin,
			"l1": knee_at.length(), "l2": ankle_at.length(),
			"axis_u": knee_at.normalized(), "axis_l": ankle_at.normalized(),
		})
	# the sword as carved: the grip (its pivot) and the blade's line
	grip_rest = rest_point("sword")
	if parts.has("blade_tip"):
		var tip := rest_point("blade_tip")
		blade_axis_rest = (tip - grip_rest).normalized()
		blade_length = tip.distance_to(grip_rest)
	for side in 2:
		var s := SIDES[side]
		var elbow_at: Vector3 = (rest["forearm_" + s] as Transform3D).origin
		var wrist_at: Vector3 = (rest["hand_" + s] as Transform3D).origin
		var shoulder := rest_point("upperarm_" + s)
		var wrist := rest_point("hand_" + s)
		var elbow := rest_point("forearm_" + s)
		_arms.append({
			"upper": part("upperarm_" + s), "fore": part("forearm_" + s), "hand": part("hand_" + s),
			"shoulder": (rest["upperarm_" + s] as Transform3D).origin,
			"l1": elbow_at.length(), "l2": wrist_at.length(),
			"axis_u": elbow_at.normalized(), "axis_f": wrist_at.normalized(),
		})
		# the fist's grip point: where the hilt passes through it as carved
		var hilt := grip_rest if side == 1 else grip_rest - blade_axis_rest * LEFT_GRIP_DOWN
		_grip_offset[side] = hilt - wrist
		# the elbow's natural side, off the shoulder-wrist line
		var line := (wrist - shoulder).normalized()
		var bend := (elbow - shoulder) - line * (elbow - shoulder).dot(line)
		_pole_rest[side] = bend.normalized() if bend.length() > 0.001 else Vector3(-1.0 if side == 0 else 1.0, 0.0, 0.0)
	if parts.has("saya_mouth"):
		saya_mouth_rest = rest_point("saya_mouth")
		var saya_pivot := rest_point("saya")
		var into := saya_pivot - saya_mouth_rest
		if into.length() > 0.01:
			saya_axis = into.normalized()
	if parts.has("bow_grip"):
		bow_grip_local = (rest["bow_grip"] as Transform3D).origin
	if parts.has("arrow_nock"):
		arrow_nock_local = (rest["arrow_nock"] as Transform3D).origin
		arrow_head_local = -arrow_nock_local.normalized() * 0.095
	_setup_bow()
	_remember_hanging()
	if not greybox:
		for view in meshes:
			if view.mesh != null:
				MeshShards.warm_slices(view.mesh, 2)


## The bow's baked string is cut out of its mesh (two segments of ours
## follow the draw instead); what is left is cut at the grip into two
## limbs that bend.
func _setup_bow() -> void:
	var bow := part("bow") as MeshInstance3D
	if bow == null:
		return
	var holder := bow
	if bow.mesh != null:
		var ends := _bow_ends_of(bow.mesh)
		if not ends.is_empty():
			bow_ends = ends
		bow_axis = (bow_ends[1] - bow_ends[0]).normalized()
		var a := bow_ends[0]
		var b := bow_ends[1]
		var near_string := func(centroid: Vector3) -> bool:
			var t := clampf((centroid - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
			return centroid.distance_to(a.lerp(b, t)) < STRING_CUT
		var cut: Array = MeshShards.split(bow.mesh, near_string, "bowstring")
		var body := cut[0] as MeshShards.Piece
		if body != null and cut[1] != null:
			var grip_along := (bow_grip_local - a).dot(bow_axis)
			var limbs: Array = MeshShards.partition(body.mesh, func(centroid: Vector3) -> int:
				return 0 if (centroid - a).dot(bow_axis) < grip_along else 1, 2, "bowlimbs")
			var materials: Array = []
			for i in bow.mesh.get_surface_count():
				materials.append(bow.get_active_material(i))
			for i in 2:
				var limb := limbs[i] as MeshShards.Piece
				if limb == null:
					continue
				var view := MeshInstance3D.new()
				view.name = "bow_limb_%d" % i
				view.mesh = limb.mesh
				var remapped := MeshShards.materials_for(_relay(limb, body), materials)
				for k in remapped.size():
					if remapped[k] != null:
						view.set_surface_override_material(k, remapped[k])
				bow.add_child(view)
				_limbs.append(view)
			bow.set_surface_override_material(0, null)
			# the carved bow (string and all) hidden behind its limbs: a mesh
			# instance's own visibility would hide the children too, so draw
			# nothing instead
			bow.mesh = null
			_bow_body = bow
	# the string: two thin segments (hidden while the bow is on the back)
	for i in 2:
		var segment := MeshInstance3D.new()
		segment.name = "bowstring_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.006, 1.0, 0.006)
		segment.mesh = mesh
		var silk := StandardMaterial3D.new()
		silk.albedo_color = Color(0.9, 0.88, 0.8)
		segment.material_override = silk
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.visible = false
		holder.add_child(segment)
		_string.append(segment)


## A limb's surfaces mapped back onto the carved bow's (the body piece kept
## the carved surface numbers; the limb's refer to the body's).
func _relay(limb: MeshShards.Piece, body: MeshShards.Piece) -> MeshShards.Piece:
	var piece := MeshShards.Piece.new()
	piece.mesh = limb.mesh
	for s in limb.surfaces:
		piece.surfaces.append(body.surfaces[s] if s < body.surfaces.size() else s)
	return piece


## The bow's ends (mesh space): the two vertices farthest apart along the
## mesh's longest extent.
static func _bow_ends_of(mesh: Mesh) -> Array[Vector3]:
	var lowest := Vector3.ZERO
	var highest := Vector3.ZERO
	var found := false
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if not found:
				lowest = v
				highest = v
				found = true
			if v.y < lowest.y:
				lowest = v
			if v.y > highest.y:
				highest = v
	if not found:
		return []
	return [lowest, highest]


## [param node]'s transform in the model's (body) space.
func _model_xform(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var walker := node
	while walker != null and walker != model:
		xform = walker.transform * xform
		walker = walker.get_parent() as Node3D
	return xform


## The local transform that puts [param node] at [param world] (body space).
func _local_under(node: Node3D, world: Transform3D) -> Transform3D:
	var parent := node.get_parent() as Node3D
	if parent == null or parent == model:
		return world
	return _model_xform(parent).affine_inverse() * world


func _turn(part_name: String, euler: Vector3) -> void:
	var node := part(part_name)
	node.transform = Transform3D(Basis.from_euler(euler), (rest[part_name] as Transform3D).origin)


## The greybox body: boxes on the model's pivots, same names, same chains.
static func _make_greybox() -> Node3D:
	var root := Node3D.new()
	var lacquer := StandardMaterial3D.new()
	lacquer.albedo_color = Color(0.16, 0.12, 0.12)
	var crimson := StandardMaterial3D.new()
	crimson.albedo_color = Color(0.62, 0.14, 0.12)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.86)
	steel.metallic = 0.8
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.7, 0.3)
	# [name, parent, pivot (parent space), box size, box centre (own space), material]
	var spec := [
		["pelvis", "", Vector3(0, 1.292, 0), Vector3(0.5, 0.22, 0.4), Vector3(0, -0.02, 0), crimson],
		["torso", "pelvis", Vector3(0, 0.136, 0), Vector3(0.62, 0.62, 0.42), Vector3(0, 0.32, 0), lacquer],
		["head", "torso", Vector3(0, 0.775, 0), Vector3(0.36, 0.46, 0.36), Vector3(0, 0.2, 0), lacquer],
		["upperarm_l", "torso", Vector3(-0.408, 0.639, 0), Vector3(0.16, 0.44, 0.16), Vector3(0.04, -0.22, -0.04), crimson],
		["upperarm_r", "torso", Vector3(0.408, 0.639, 0), Vector3(0.16, 0.4, 0.16), Vector3(0, -0.18, -0.09), crimson],
		["sode_l", "upperarm_l", Vector3(-0.092, 0.123, 0), Vector3(0.1, 0.5, 0.42), Vector3(-0.04, -0.25, 0), lacquer],
		["sode_r", "upperarm_r", Vector3(0.092, 0.123, 0), Vector3(0.1, 0.5, 0.42), Vector3(0.04, -0.25, 0), lacquer],
		["forearm_l", "upperarm_l", Vector3(0.082, -0.435, -0.082), Vector3(0.13, 0.42, 0.13), Vector3(0.17, -0.1, -0.08), steel],
		["forearm_r", "upperarm_r", Vector3(-0.014, -0.367, -0.177), Vector3(0.13, 0.38, 0.13), Vector3(-0.12, -0.07, -0.12), steel],
		["hand_l", "forearm_l", Vector3(0.335, -0.211, -0.155), Vector3(0.12, 0.1, 0.12), Vector3(0.04, -0.03, -0.02), crimson],
		["hand_r", "forearm_r", Vector3(-0.237, -0.13, -0.248), Vector3(0.12, 0.1, 0.12), Vector3(-0.03, -0.02, -0.03), crimson],
		["sword", "hand_r", Vector3(-0.062, -0.033, -0.065), Vector3(0.05, 0.05, 0.05), Vector3(0, 0, 0), gold],
		["saya", "pelvis", Vector3(-0.35, 0.068, -0.07), Vector3(0.06, 0.06, 0.06), Vector3(0, 0, 0), lacquer],
		["bow", "torso", Vector3(0, 0.272, 0.41), Vector3(0.06, 2.3, 0.06), Vector3(-0.05, 0.14, 0), lacquer],
		["quiver", "torso", Vector3(0.27, -0.098, 0.30), Vector3(0.2, 0.5, 0.14), Vector3(0, 0.2, 0), lacquer],
		["arrow", "quiver", Vector3(0.09, 0.08, -0.03), Vector3(0.02, 1.43, 0.02), Vector3(0.07, 0.62, 0), gold],
		["thigh_l", "pelvis", Vector3(-0.163, -0.041, 0), Vector3(0.24, 0.5, 0.26), Vector3(0, -0.27, -0.03), lacquer],
		["thigh_r", "pelvis", Vector3(0.163, -0.041, 0), Vector3(0.24, 0.5, 0.26), Vector3(0, -0.27, -0.03), lacquer],
		["shin_l", "thigh_l", Vector3(-0.014, -0.544, -0.068), Vector3(0.18, 0.52, 0.2), Vector3(0, -0.28, 0.03), steel],
		["shin_r", "thigh_r", Vector3(0.014, -0.544, -0.068), Vector3(0.18, 0.52, 0.2), Vector3(0, -0.28, 0.03), steel],
		["foot_l", "shin_l", Vector3(0, -0.571, 0.068), Vector3(0.16, 0.14, 0.34), Vector3(0, -0.07, -0.06), lacquer],
		["foot_r", "shin_r", Vector3(0, -0.571, 0.068), Vector3(0.16, 0.14, 0.34), Vector3(0, -0.07, -0.06), lacquer],
		["kusazuri_f", "pelvis", Vector3(0, 0.038, -0.34), Vector3(0.4, 0.42, 0.04), Vector3(0, -0.21, 0), lacquer],
		["kusazuri_b", "pelvis", Vector3(0, 0.038, 0.34), Vector3(0.4, 0.42, 0.04), Vector3(0, -0.21, 0), lacquer],
		["kusazuri_l", "pelvis", Vector3(-0.34, 0.038, 0), Vector3(0.04, 0.42, 0.4), Vector3(0, -0.21, 0), lacquer],
		["kusazuri_r", "pelvis", Vector3(0.34, 0.038, 0), Vector3(0.04, 0.42, 0.4), Vector3(0, -0.21, 0), lacquer],
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
		view.material_override = entry[5]
		view.position = entry[2]
		var parent: Node3D = made.get(entry[1], root)
		parent.add_child(view)
		made[entry[0]] = view
	# the blade: a long thin box along the carved line from the grip
	var blade := MeshInstance3D.new()
	blade.name = "blade"
	var strip := BoxMesh.new()
	strip.size = Vector3(0.04, 0.012, 1.95)
	blade.mesh = strip
	blade.material_override = steel
	var axis := Vector3(0.039, 0.635, -0.771).normalized()
	blade.transform = Transform3D(LimbIK.aim(Basis.IDENTITY, Vector3.FORWARD, axis), axis * (1.95 * 0.5 - 0.45))
	(made["sword"] as Node3D).add_child(blade)
	for marker: Array in [["face", "head", Vector3(0, 0.211, -0.109)], ["back", "torso", Vector3(0, 0.34, 0.381)],
			["blade_tip", "sword", axis * 1.78], ["glint", "sword", axis * 1.58],
			["bow_grip", "bow", Vector3(-0.2, -0.19, 0.12)], ["arrow_nock", "arrow", Vector3(0.15, 1.24, 0.0)],
			["saya_mouth", "saya", Vector3(0, 0.109, -0.272)]]:
		var node := Node3D.new()
		node.name = marker[0]
		node.position = marker[2]
		(made[marker[1]] as Node3D).add_child(node)
	return root
