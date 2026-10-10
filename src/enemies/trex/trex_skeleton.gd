class_name TRexSkeleton
extends Node3D
## The T-Rex's bones and pose. With the Blender model (ArtLibrary "trex")
## TRexModelRig maps every Pose field onto the model's 26 jointed parts
## (exact-mesh hit zones, leg IK, crystal_loose in the CrystalSocket,
## collapse into mesh islands); the fields below (body, head, neck, tail,
## legs, pieces, hurtboxes...) then point at the model's parts. Without it
## (models off or missing) it builds the greybox described here.
## Greybox skeleton of a Tyrannosaurus in a modern museum mount (about 11.5 m
## from snout to tail tip, 5 m to the top of the skull), built from
## primitives around animated pivots: hips (body) with pelvis and spine, six
## pairs of three-part ribs caging the red crystal, belly ribs, tiny
## two-fingered arms, an S-curved five-bone neck, a skull with dark
## fenestrae, glowing eye sockets and a hinged, toothed jaw, two legs and a
## fourteen-bone tail. The boss sets the target [member pose] every physics
## frame; animate() eases the bones toward it. Bone hit zones ride on the
## bones; the crystal has its own. collapse() turns every bone into physical
## debris. Origin = the floor under the hips, facing -Z.

const HIP_Y := 3.4
const BONE_COLOR := Color(0.8, 0.74, 0.62)
const DARK_COLOR := Color(0.14, 0.11, 0.1)
const TOOTH_COLOR := Color(0.95, 0.92, 0.83)
const CRYSTAL_POS := Vector3(0.0, -0.6, -1.75)
## Where the crystal moves (body space) when fully exposed in a stun.
const CRYSTAL_EXPOSED_SHIFT := Vector3(0.0, -0.3, -0.12)
const CRYSTAL_RADIUS := 0.26
const RIB_Z: Array[float] = [-0.75, -1.15, -1.55, -1.95, -2.35, -2.75]
const RIB_LENGTH: Array[float] = [0.85, 1.1, 1.25, 1.25, 1.1, 0.85]
## Outward swing of the upper rib (degrees); a stun opens the cage further.
const RIB_SPREAD := 65.0
const RIB_OPEN := 24.0
## Neck bones: pitch relative to the previous one (degrees), -Z along the bone.
const NECK_ANGLES: Array[float] = [50.0, -5.0, -15.0, -18.0, -20.0]
const NECK_LENGTH := 0.3
const HEAD_PITCH := -6.0
const TAIL_COUNT := 14
## Leg joint angles (degrees): thigh, shin, foot, toes; standing and crouched.
const LEG_STAND: Array[float] = [25.0, -55.0, 50.0, 70.0]
const LEG_CROUCH: Array[float] = [55.0, -110.0, 95.0, 50.0]
## Heartbeats per second of the crystal ("lub-dub").
const BEAT_RATE := 1.1


## Target (and eased) posture. All angles in radians, 0 = the museum pose.
class Pose:
	const FIELDS: Array[StringName] = [&"drop", &"pitch", &"roll", &"twist", &"neck", &"look",
			&"jaw", &"curl", &"lift", &"ribs", &"crouch", &"arms", &"exposure", &"glow", &"eyes"]
	## Hips lowered (m).
	var drop: float = 0.0
	## Body nose-up (+) / nose-down (-).
	var pitch: float = 0.0
	var roll: float = 0.0
	## Hips turned (tail swing follow-through).
	var twist: float = 0.0
	## Neck raised (+) / lowered (-).
	var neck: float = 0.0
	## Head turned to the left (+) / right (-).
	var look: float = 0.0
	## Jaw 0 (shut) .. 1 (wide open).
	var jaw: float = 0.0
	## Tail swung to the right (+, toward +X) / left (-).
	var curl: float = 0.0
	## Tail raised (+) / dropped (-).
	var lift: float = 0.0
	## Rib cage 0 (closed) .. 1 (open).
	var ribs: float = 0.0
	## Legs 0 (standing) .. 1 (crouched).
	var crouch: float = 0.0
	## Arms raised.
	var arms: float = 0.0
	## Crystal pushed out of the cage (stun window).
	var exposure: float = 0.0
	## Telegraph flare of crystal and eyes.
	var glow: float = 0.0
	## Eye sockets lit (0 = asleep).
	var eyes: float = 0.0

	func reset() -> void:
		for field in FIELDS:
			set(field, 0.0)

	func ease_to(target: Pose, weight: float) -> void:
		for field in FIELDS:
			set(field, lerpf(get(field), target.get(field), weight))


var pose := Pose.new()
## Walk cycle angle (rad), advanced by the boss as it covers ground.
var walk_phase: float = 0.0
## Walk cycle strength (0 = standing, 1 = walking, 1.6 = charging).
var stride: float = 0.0
## Right foot scraping the floor (charge telegraph), 0..1.
var scrape: float = 0.0
## Death tremor, 0..1.
var tremble: float = 0.0
var crystal_present: bool = false

var body: Node3D
var head: Node3D
var jaw: Node3D
var neck: Array[Node3D] = []
var tail: Array[Node3D] = []
var ribs: Array[Node3D] = []
var arms: Array[Node3D] = []
## Per leg: [thigh, shin, foot, toes].
var legs: Array = []
var crystal_pivot: Node3D
var crystal_light: OmniLight3D
var crystal_hurtbox: Hurtbox
var hurtboxes: Array[Hurtbox] = []
## Every collapsible bone (a holder of merged meshes with an "aabb" meta).
var pieces: Array[Node3D] = []
## The Blender model driven by the pose (null = the greybox bones above).
var model_rig: TRexModelRig = null

var _now := Pose.new()
var _stride: float = 0.0
var _time: float = 0.0
var _gem: Node3D
var _bone_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _tooth_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _crystal_mat: BaseMaterial3D
var _halo_mat: StandardMaterial3D
var _bone_zone: Node
var _crystal_zone: Node
## Crystal pivot at rest (in its parent's space) and the tail tip (in the
## last tail bone's space).
var _crystal_rest := CRYSTAL_POS
var _tail_tip := Vector3.ZERO


## Builds every bone, the crystal and the hit zones. [param bone_zone] and
## [param crystal_zone] receive the hits (see TRexZone). Uses the Blender
## model (TRexModelRig) when it loads, else the greybox bones.
func build(bone_zone: Node, crystal_zone: Node) -> void:
	_bone_zone = bone_zone
	_crystal_zone = crystal_zone
	_make_materials()
	model_rig = TRexModelRig.create(self)
	if model_rig != null:
		model_rig.rig_skeleton(bone_zone)
		_tail_tip = model_rig.tail_tip
		_crystal_rest = model_rig.socket
		_build_crystal(ribs[0], _crystal_rest)
		set_crystal_present(false)
		animate(0.0)
		return
	body = _joint(self, Vector3(0.0, HIP_Y, 0.0))
	_build_pelvis_and_spine()
	_build_ribs()
	_build_arms()
	_build_neck_and_skull()
	_build_legs()
	_build_tail()
	_tail_tip = Vector3(0.0, 0.0, tail_length(tail.size() - 1))
	_build_crystal(body, CRYSTAL_POS)
	set_crystal_present(false)
	animate(0.0)


## 0..1 heartbeat of the crystal at the skeleton's clock.
func heartbeat() -> float:
	var beat := fmod(_time * BEAT_RATE, 1.0)
	return exp(-pow((beat - 0.08) / 0.05, 2.0)) + 0.6 * exp(-pow((beat - 0.3) / 0.05, 2.0))


## Number of heartbeats so far (the boss plays a pulse on each new one).
func beat_count() -> int:
	return int(_time * BEAT_RATE)


## Tail joints (world) from the base to the tip: TAIL_COUNT + 1 points, bone
## i between points i and i + 1 (thickness: tail_radius(i)).
func tail_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for bone in tail:
		points.append(bone.global_position)
	var last := tail[tail.size() - 1]
	points.append(last.global_transform * _tail_tip)
	return points


static func tail_length(i: int) -> float:
	return 0.48 - i * 0.016


## Half the thickness of tail bone [param i] (without spikes and chevrons).
static func tail_radius(i: int) -> float:
	return (0.26 - i * 0.014) * 0.5


func set_crystal_present(present: bool) -> void:
	crystal_present = present
	crystal_pivot.visible = present
	crystal_hurtbox.collision_layer = Layers.HURTBOX if present else 0


func set_zones_enabled(enabled: bool) -> void:
	for hurtbox in hurtboxes:
		hurtbox.collision_layer = Layers.HURTBOX if enabled else 0
	crystal_hurtbox.collision_layer = Layers.HURTBOX if enabled and crystal_present else 0


func crystal_position() -> Vector3:
	return crystal_pivot.global_position


## The crystal breaks: it disappears; returns where it was.
func shatter_crystal() -> Vector3:
	var at := crystal_pivot.global_position
	set_crystal_present(false)
	return at


## Eases the bones toward [member pose]; [param sharpness] = how quickly
## (higher snaps, e.g. a tail whip). delta 0 applies the pose at once.
func animate(delta: float, sharpness: float = 6.0) -> void:
	_time += delta
	var weight := 1.0 if delta <= 0.0 else 1.0 - exp(-sharpness * delta)
	_now.ease_to(pose, weight)
	_stride = lerpf(_stride, stride, 1.0 if delta <= 0.0 else 1.0 - exp(-5.0 * delta))
	var p := _now
	var shiver := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremble * 0.035
	if model_rig != null:
		model_rig.animate(p, _stride, walk_phase, _time, scrape, shiver)
		_animate_crystal(p)
		_eye_mat.emission_energy_multiplier = p.eyes * (2.0 + p.glow * 6.0)
		return
	var bob := absf(sin(walk_phase)) * 0.09 * minf(_stride, 1.2)
	body.position = Vector3(0.0, HIP_Y - p.drop - bob, 0.0)
	body.rotation = Vector3(p.pitch, p.twist, p.roll + sin(walk_phase) * 0.03 * _stride) + shiver
	for i in neck.size():
		var raise := p.neck * (0.45 if i < 2 else 0.12)
		neck[i].rotation = Vector3(deg_to_rad(NECK_ANGLES[i]) + raise, p.look * (0.3 if i < 3 else 0.05), 0.0)
	head.rotation = Vector3(deg_to_rad(HEAD_PITCH) - p.neck * 0.3, 0.0, 0.0) + shiver * 2.0
	jaw.rotation.x = -p.jaw * 0.8
	var sway := sin(_time * 1.3) * 0.012 + sin(walk_phase) * 0.03 * _stride
	for i in tail.size():
		var droop := deg_to_rad(8.0 if i == 0 else 1.2)
		tail[i].rotation = Vector3(droop - p.lift * 0.035, p.curl * 0.1 + sway, 0.0)
	for rib in ribs:
		var side: float = rib.get_meta(&"side")
		rib.rotation.z = side * deg_to_rad(RIB_SPREAD + p.ribs * RIB_OPEN)
	for arm in arms:
		arm.rotation.x = deg_to_rad(40.0) - p.arms * 0.7
	_animate_legs(p)
	_animate_crystal(p)
	_eye_mat.emission_energy_multiplier = p.eyes * (2.0 + p.glow * 6.0)


## Turns every bone into a physical piece of debris (where it is, in world
## space) under a new node in [param parent] (any transform) and hides what
## is left (eyes). Returns that node.
func collapse(parent: Node) -> Node3D:
	set_zones_enabled(false)
	if model_rig != null:
		var bones := model_rig.collapse(parent)
		pieces.clear()
		visible = false
		return bones
	var remains := Node3D.new()
	remains.name = "TRexRemains"
	parent.add_child(remains)
	var center := body.global_position
	for piece in pieces:
		var aabb: AABB = piece.get_meta(&"aabb")
		var placed := piece.global_transform.orthonormalized()
		var rigid := RigidBody3D.new()
		rigid.collision_layer = Layers.DEBRIS
		rigid.collision_mask = Layers.WORLD | Layers.DEBRIS
		rigid.mass = clampf(aabb.get_volume() * 400.0, 0.3, 40.0)
		var shape := BoxShape3D.new()
		shape.size = aabb.size.max(Vector3.ONE * 0.06)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = aabb.get_center()
		rigid.add_child(collider)
		for view in piece.get_children():
			piece.remove_child(view)
			rigid.add_child(view)
		remains.add_child(rigid)
		rigid.global_transform = placed   # world space, whatever the parent
		rigid.reset_physics_interpolation()
		var out := rigid.global_transform * aabb.get_center() - center
		out.y = 0.0
		rigid.linear_velocity = out.normalized() * randf_range(0.4, 2.2) + Vector3(0.0, randf_range(-0.5, 1.2), 0.0)
		rigid.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	pieces.clear()
	visible = false
	return remains


# --- building -----------------------------------------------------------

func _build_pelvis_and_spine() -> void:
	_piece(body, [
		_part(_box(Vector3(0.12, 0.72, 1.75)), Vector3(0.25, 0.14, 0.12)),
		_part(_box(Vector3(0.12, 0.72, 1.75)), Vector3(-0.25, 0.14, 0.12)),
		_part(_box(Vector3(0.36, 0.14, 1.3)), Vector3(0.0, 0.44, 0.1)),
	])
	_hurt(body, Vector3(0.7, 1.0, 2.0), Vector3(0.0, 0.1, 0.1))
	var pubis := _limb(body, Vector3(0.0, -0.05, -0.28), Vector3(28.0, 0.0, 0.0), 1.35, 0.11,
			[_part(_box(Vector3(0.34, 0.16, 0.8)), Vector3(0.0, -1.35, -0.1), Vector3(-28.0, 0.0, 0.0))])
	_hurt(pubis, Vector3(0.36, 1.5, 0.45), Vector3(0.0, -0.75, -0.05))
	_limb(body, Vector3(0.0, -0.05, 0.4), Vector3(-32.0, 0.0, 0.0), 0.95, 0.08)
	for i in 10:
		var z := 0.55 - i * 0.42
		var y := _spine_y(z)
		var spike := lerpf(0.6, 0.42, i / 9.0)
		_piece(body, [
			_part(_box(Vector3(0.24, 0.24, 0.32)), Vector3(0.0, y, z)),
			_part(_box(Vector3(0.07, spike, 0.2)), Vector3(0.0, y + 0.12 + spike * 0.5, z + 0.03), Vector3(-10.0, 0.0, 0.0)),
		])
	_hurt(body, Vector3(0.45, 1.0, 4.0), Vector3(0.0, 0.6, -1.3))


func _build_ribs() -> void:
	for i in RIB_Z.size():
		var z := RIB_Z[i]
		var length := RIB_LENGTH[i]
		for side in [-1.0, 1.0]:
			var root := _joint(body, Vector3(side * 0.12, _spine_y(z) - 0.06, z), Vector3(-8.0, 0.0, side * RIB_SPREAD))
			root.set_meta(&"side", side)
			ribs.append(root)
			_piece(root, [_part(_rod(0.05, 0.5), Vector3(0.0, -0.25, 0.0))])
			var mid := _joint(root, Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.0, side * -45.0))
			_piece(mid, [_part(_rod(0.055, length, 0.9), Vector3(0.0, -length * 0.5, 0.0))])
			_hurt(mid, Vector3(0.13, length, 0.13), Vector3(0.0, -length * 0.5, 0.0))
			var low := _joint(mid, Vector3(0.0, -length, 0.0), Vector3(0.0, 0.0, side * -35.0))
			_piece(low, [_part(_rod(0.045, 0.5, 0.6), Vector3(0.0, -0.25, 0.0))])
			_hurt(low, Vector3(0.12, 0.5, 0.12), Vector3(0.0, -0.25, 0.0))
	# belly ribs (gastralia) close the cage from below
	for i in 5:
		var z := -1.0 - i * 0.4
		var parts: Array = []
		for side in [-1.0, 1.0]:
			parts.append(_part(_rod(0.03, 0.75, 0.7, 5), Vector3(side * 0.33, -1.55, z), Vector3(0.0, 0.0, side * 75.0)))
		_piece(body, parts)


func _build_arms() -> void:
	for side in [-1.0, 1.0]:
		_piece(body, [_part(_box(Vector3(0.08, 0.7, 0.2)), Vector3(side * 0.45, 0.0, -2.85), Vector3(-35.0, 0.0, side * -8.0))])
		var upper := _limb(body, Vector3(side * 0.47, -0.32, -3.0), Vector3(40.0, 0.0, side * 12.0), 0.5, 0.065)
		var fore := _limb(upper, Vector3(0.0, -0.5, 0.0), Vector3(55.0, 0.0, 0.0), 0.38, 0.05)
		_piece(fore, [
			_part(_rod(0.025, 0.16, 0.3, 5), Vector3(0.03, -0.45, -0.03), Vector3(40.0, 0.0, 0.0)),
			_part(_rod(0.025, 0.16, 0.3, 5), Vector3(-0.03, -0.45, -0.03), Vector3(40.0, 0.0, 0.0)),
		])
		arms.append(upper)


func _build_neck_and_skull() -> void:
	var parent := body
	var at := Vector3(0.0, 0.5, -3.3)
	for i in NECK_ANGLES.size():
		var bone := _joint(parent, at, Vector3(NECK_ANGLES[i], 0.0, 0.0))
		neck.append(bone)
		var width := lerpf(0.3, 0.22, i / 4.0)
		_piece(bone, [
			_part(_box(Vector3(width, width * 0.9, NECK_LENGTH * 0.92)), Vector3(0.0, 0.0, -NECK_LENGTH * 0.5)),
			_part(_box(Vector3(0.06, 0.16, 0.16)), Vector3(0.0, width * 0.5 + 0.06, -NECK_LENGTH * 0.5)),
		])
		_hurt(bone, Vector3(width + 0.12, width + 0.15, NECK_LENGTH + 0.04), Vector3(0.0, 0.02, -NECK_LENGTH * 0.5))
		parent = bone
		at = Vector3(0.0, 0.0, -NECK_LENGTH)
	head = _joint(parent, at, Vector3(HEAD_PITCH, 0.0, 0.0))
	var skull: Array = [
		_part(_box(Vector3(0.52, 0.58, 0.55)), Vector3(0.0, 0.1, -0.3)),
		_part(_box(Vector3(0.36, 0.3, 0.82)), Vector3(0.0, 0.12, -0.95), Vector3(-5.0, 0.0, 0.0)),
		_part(_box(Vector3(0.42, 0.2, 0.85)), Vector3(0.0, -0.1, -0.9)),
		_part(_box(Vector3(0.14, 0.08, 0.75)), Vector3(0.0, 0.3, -0.98), Vector3(-5.0, 0.0, 0.0)),
		_part(_box(Vector3(0.46, 0.3, 0.2)), Vector3(0.0, -0.08, -0.08)),
	]
	for side in [-1.0, 1.0]:
		skull.append(_part(_box(Vector3(0.12, 0.09, 0.18)), Vector3(side * 0.2, 0.39, -0.52)))
		skull.append(_part(_box(Vector3(0.08, 0.2, 0.5)), Vector3(side * 0.27, -0.08, -0.4)))
		# dark openings: eye socket, antorbital and temporal fenestrae
		skull.append(_part(_box(Vector3(0.04, 0.17, 0.17)), Vector3(side * 0.265, 0.2, -0.5), Vector3.ZERO, _dark_mat))
		skull.append(_part(_box(Vector3(0.02, 0.15, 0.32)), Vector3(side * 0.215, 0.03, -0.86), Vector3.ZERO, _dark_mat))
		skull.append(_part(_box(Vector3(0.02, 0.22, 0.2)), Vector3(side * 0.265, 0.07, -0.18), Vector3.ZERO, _dark_mat))
		for k in 6:
			skull.append(_part(_cone(0.035, 0.15), Vector3(side * 0.17, -0.25, -0.45 - k * 0.15), Vector3(180.0, 0.0, 0.0), _tooth_mat))
		skull.append(_part(_cone(0.03, 0.13), Vector3(side * 0.07, -0.24, -1.3), Vector3(180.0, 0.0, 0.0), _tooth_mat))
	_piece(head, skull)
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		eyes.append(_part(_ball(0.055), Vector3(side * 0.245, 0.2, -0.5), Vector3.ZERO, _eye_mat))
	_piece(head, eyes, false)
	_hurt(head, Vector3(0.62, 0.8, 1.45), Vector3(0.0, 0.08, -0.7))
	jaw = _joint(head, Vector3(0.0, -0.18, -0.1))
	var mandible: Array = [_part(_box(Vector3(0.4, 0.2, 1.12)), Vector3(0.0, -0.1, -0.62))]
	for side in [-1.0, 1.0]:
		mandible.append(_part(_box(Vector3(0.02, 0.1, 0.25)), Vector3(side * 0.205, -0.1, -0.35), Vector3.ZERO, _dark_mat))
		for k in 5:
			mandible.append(_part(_cone(0.032, 0.13), Vector3(side * 0.15, 0.04, -0.45 - k * 0.15), Vector3.ZERO, _tooth_mat))
	_piece(jaw, mandible)
	_hurt(jaw, Vector3(0.44, 0.28, 1.15), Vector3(0.0, -0.1, -0.62))


func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var thigh := _limb(body, Vector3(side * 0.46, -0.12, 0.0), Vector3(LEG_STAND[0], 0.0, 0.0), 1.45, 0.13,
				[_part(_ball(0.17), Vector3(0.0, -1.45, 0.0))], 0.34)
		var shin := _limb(thigh, Vector3(0.0, -1.45, 0.0), Vector3(LEG_STAND[1], 0.0, 0.0), 1.3, 0.1,
				[_part(_rod(0.05, 1.2, 0.7, 5), Vector3(side * 0.1, -0.62, 0.02))], 0.26)
		var foot := _limb(shin, Vector3(0.0, -1.3, 0.0), Vector3(LEG_STAND[2], 0.0, 0.0), 0.8, 0.08, [], 0.2)
		var toes := _joint(foot, Vector3(0.0, -0.8, 0.0), Vector3(LEG_STAND[3], 0.0, 0.0))
		var claws: Array = []
		for k in [-1.0, 0.0, 1.0]:
			var spread := Vector3(0.0, 0.0, k * -12.0)
			var tip := Basis.from_euler(spread * PI / 180.0) * Vector3(0.0, -0.5, 0.0)
			claws.append(_part(_rod(0.05, 0.5, 0.8, 5), Vector3(k * 0.1, 0.0, 0.0) + tip * 0.5, spread))
			claws.append(_part(_cone(0.045, 0.14), Vector3(k * 0.1, 0.0, 0.0) + tip * 1.1, spread + Vector3(180.0, 0.0, 0.0), _tooth_mat))
		_piece(toes, claws)
		legs.append([thigh, shin, foot, toes])


func _build_tail() -> void:
	var parent := body
	var at := Vector3(0.0, 0.3, 0.75)
	for i in TAIL_COUNT:
		var bone := _joint(parent, at, Vector3(8.0 if i == 0 else 1.2, 0.0, 0.0))
		tail.append(bone)
		var length := tail_length(i)
		var size := tail_radius(i) * 2.0
		var parts: Array = [_part(_box(Vector3(size, size, length * 0.88)), Vector3(0.0, 0.0, length * 0.5))]
		if i < 9:
			var spike := 0.32 - i * 0.03
			parts.append(_part(_box(Vector3(0.05, spike, 0.14)), Vector3(0.0, size * 0.5 + spike * 0.5, length * 0.55), Vector3(20.0, 0.0, 0.0)))
		if i < 11:
			var chevron := 0.36 - i * 0.028
			parts.append(_part(_box(Vector3(0.045, chevron, 0.1)), Vector3(0.0, -size * 0.5 - chevron * 0.5, length * 0.6), Vector3(-25.0, 0.0, 0.0)))
		_piece(bone, parts)
		if i % 3 == 0:
			_hurt(bone, Vector3(size + 0.25, size + 0.5, length * 3.0), Vector3(0.0, 0.0, length * 1.5))
		parent = bone
		at = Vector3(0.0, 0.0, length)


## The crystal at [param at] in [param parent]: the crystal_loose model
## (with its own glowing material) when there is one, else a greybox gem.
func _build_crystal(parent: Node3D, at: Vector3) -> void:
	crystal_pivot = _joint(parent, at)
	_gem = Node3D.new()
	crystal_pivot.add_child(_gem)
	var modelled: Array = model_rig.make_gem() if model_rig != null else []
	if modelled.size() == 2 and modelled[1] != null:
		_gem.add_child(modelled[0])
		_crystal_mat = modelled[1]
		_crystal_mat.emission = Color(0.5, 0.05, 0.03)
	else:
		var gem := SphereMesh.new()
		gem.radius = 0.2
		gem.height = 0.62
		gem.radial_segments = 6
		gem.rings = 2
		var core := MeshInstance3D.new()
		core.mesh = gem
		core.material_override = _crystal_mat
		_gem.add_child(core)
	var halo := MeshInstance3D.new()
	halo.mesh = _ball(0.42 if model_rig == null else 0.3, 16)
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.add_child(halo)
	crystal_light = OmniLight3D.new()
	crystal_light.light_color = Color(1.0, 0.16, 0.1)
	crystal_light.omni_range = 6.0
	crystal_light.light_energy = 2.0
	crystal_light.light_volumetric_fog_energy = 0.5
	crystal_pivot.add_child(crystal_light)
	var shape := SphereShape3D.new()
	shape.radius = CRYSTAL_RADIUS
	crystal_hurtbox = Hurtbox.make(_crystal_zone, shape, Vector3.ZERO)
	crystal_pivot.add_child(crystal_hurtbox)


func _make_materials() -> void:
	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = BONE_COLOR
	_bone_mat.roughness = 0.82
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = DARK_COLOR
	_dark_mat.roughness = 1.0
	_tooth_mat = StandardMaterial3D.new()
	_tooth_mat.albedo_color = TOOTH_COLOR
	_tooth_mat.roughness = 0.45
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.25, 0.02, 0.02)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.18, 0.08)
	_eye_mat.emission_energy_multiplier = 0.0
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.75, 0.04, 0.04)
	_crystal_mat.metallic = 0.25
	_crystal_mat.roughness = 0.12
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(1.0, 0.1, 0.06)
	_crystal_mat.emission_energy_multiplier = 3.0
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo_mat.albedo_color = Color(1.0, 0.15, 0.08, 0.18)


func _animate_legs(p: Pose) -> void:
	for k in legs.size():
		var leg: Array = legs[k]
		var cycle := walk_phase + PI * k
		var swing := sin(cycle) * 0.38 * minf(_stride, 1.4)
		var lift := maxf(0.0, cos(cycle)) * 0.55 * minf(_stride, 1.4)
		var paw := sin(_time * 14.0) * 0.32 * scrape if k == 1 else 0.0
		var angles: Array[float] = []
		for j in 4:
			angles.append(deg_to_rad(lerpf(LEG_STAND[j], LEG_CROUCH[j], p.crouch)))
		(leg[0] as Node3D).rotation.x = angles[0] + swing + paw
		(leg[1] as Node3D).rotation.x = angles[1] - lift - absf(paw) * 0.6
		(leg[2] as Node3D).rotation.x = angles[2] + lift * 0.6 - swing * 0.5
		(leg[3] as Node3D).rotation.x = angles[3] - swing * 0.3


func _animate_crystal(p: Pose) -> void:
	if not crystal_present:
		return
	var beat := heartbeat()
	crystal_pivot.position = _crystal_rest + CRYSTAL_EXPOSED_SHIFT * p.exposure
	_gem.scale = Vector3.ONE * (1.0 + 0.55 * p.exposure + beat * 0.07)
	_gem.rotation.y = _time * 0.8
	var shape := crystal_hurtbox.get_child(0) as CollisionShape3D
	var radius := CRYSTAL_RADIUS * (1.0 + 0.5 * p.exposure)
	var sphere := shape.shape as SphereShape3D
	if absf(sphere.radius - radius) > 0.02:
		sphere.radius = radius
	_crystal_mat.emission_energy_multiplier = 2.2 + beat * 3.0 + p.glow * 4.0 + p.exposure * 6.0
	_halo_mat.albedo_color.a = 0.14 + beat * 0.1 + p.glow * 0.1 + p.exposure * 0.2
	# bright enough to read the window, not so bright the hall turns red
	crystal_light.light_energy = 1.2 + beat * 1.0 + p.glow * 1.4 + p.exposure * 1.6
	crystal_light.omni_range = 6.0 + p.exposure * 2.0


static func _spine_y(z: float) -> float:
	return 0.3 + maxf(-z, 0.0) * 0.045


func _joint(parent: Node3D, at: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	joint.rotation_degrees = rot_deg
	parent.add_child(joint)
	return joint


## A pivot at [param at] whose bone runs [param length] along its -Y, with
## optional extra parts and a box hit zone of [param hurt_width].
func _limb(parent: Node3D, at: Vector3, rot_deg: Vector3, length: float, radius: float, extra: Array = [], hurt_width: float = 0.0) -> Node3D:
	var joint := _joint(parent, at, rot_deg)
	var parts: Array = [_part(_rod(radius, length), Vector3(0.0, -length * 0.5, 0.0))]
	parts.append_array(extra)
	_piece(joint, parts)
	if hurt_width > 0.0:
		_hurt(joint, Vector3(hurt_width, length, hurt_width), Vector3(0.0, -length * 0.5, 0.0))
	return joint


## One bone made of primitive [param parts] ([mesh, transform, material or
## null for bone]), merged into one mesh per material.
func _piece(parent: Node3D, parts: Array, collapsible: bool = true) -> Node3D:
	var holder := Node3D.new()
	var tools: Dictionary = {}
	var bounds := AABB()
	for i in parts.size():
		var part: Array = parts[i]
		var mesh: Mesh = part[0]
		var xform: Transform3D = part[1]
		var material: Material = part[2] if part[2] != null else _bone_mat
		if not tools.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = tool
		(tools[material] as SurfaceTool).append_from(mesh, 0, xform)
		var box := xform * mesh.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	for material in tools:
		var view := MeshInstance3D.new()
		view.mesh = (tools[material] as SurfaceTool).commit()
		view.material_override = material
		holder.add_child(view)
	holder.set_meta(&"aabb", bounds)
	parent.add_child(holder)
	if collapsible:
		pieces.append(holder)
	return holder


func _hurt(parent: Node3D, size: Vector3, at: Vector3) -> Hurtbox:
	var shape := BoxShape3D.new()
	shape.size = size
	var hurtbox := Hurtbox.make(_bone_zone, shape, at)
	parent.add_child(hurtbox)
	hurtboxes.append(hurtbox)
	return hurtbox


static func _part(mesh: Mesh, at: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> Array:
	return [mesh, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), at), material]


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## Cylinder along Y, a little thinner at the top.
static func _rod(radius: float, length: float, taper: float = 0.85, sides: int = 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * taper
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


## Cone along +Y with its tip up.
static func _cone(radius: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 5
	mesh.rings = 1
	return mesh


static func _ball(radius: float, sides: int = 8) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = sides
	mesh.rings = maxi(sides / 2, 2)
	return mesh
