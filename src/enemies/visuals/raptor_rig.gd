class_name RaptorRig
extends ExhibitRig
## The velociraptor skeleton: a fast, springy run on digitigrade legs
## (thigh, shin, foot per side: the knee folds as the leg swings forward,
## the toes droop), the head held level and low on its S-neck, the stiff
## tail swinging against the hips; the screech when it notices the guard
## (head up, jaw wide); the telegraph crouches it low on bent legs, head
## down, jaw open and trembling in the hiss, tail up and lashing, arms
## raised; the leap stretches it out (feet and sickle claws forward, arms
## reaching, neck straight, jaw wide until the bite snaps it shut) and it
## lands with a squash. Stunned it sags onto one side and twitches. Two
## glowing embers in its eye sockets light up when it wakes and flare in
## the crouch; the skull carries the weak point.

const CROUCH_DROP := 0.16
const FALL_ROLL := 1.15
const FALL_DROP := 0.38
const LAND_TIME := 0.28
## The embers in the eye sockets (skull space), their colour.
const EYE_AT := Vector3(0.027, -0.006, -0.072)
const EYE_RADIUS := 0.013
const EYE_COLOR := Color(1.0, 0.36, 0.12)
## Draw calls: parts that never move on their own go into their parent's
## mesh ([part, parent]); the tail bends at three joints instead of six.
## 22 parts + 2 eyes -> 17 meshes + 1 (both eyes in one mesh).
const MERGED := [["ribs", "spine_2"], ["spine_1", "pelvis"], ["tail_2", "tail_1"], ["tail_4", "tail_3"], ["tail_6", "tail_5"]]
## The tail joints that bend (the others are merged into them).
const TAIL := ["tail_1", "tail_3", "tail_5"]
## Only the big bones cast shadows; the thin neck, jaw, arms, feet and tail
## (and the embers) do not.
const SHADOW_CASTERS := ["pelvis", "spine_2", "skull", "thigh_l", "thigh_r", "shin_l", "shin_r"]

static var _eye_mesh: ArrayMesh = null

var raptor: Raptor

var _crouch := 0.0
var _leap := 0.0
var _pitch := 0.0
var _neck := 0.0
var _jaw := 0.0
var _tail_lift := 0.0
var _arms := 0.0
var _fall := 0.0
var _screech := 0.0
var _airborne := false
var _land := 0.0
var _bitten := false
var _eye_material: StandardMaterial3D
var _eye_energy := -1.0


static func build(owner_raptor: Raptor) -> RaptorRig:
	var rig := RaptorRig.new()
	rig.raptor = owner_raptor
	rig.cycle_length = 2.1
	rig.full_speed = 7.0
	rig.gib_density = 5.0
	return ExhibitRig.attach(owner_raptor, rig, &"raptor") as RaptorRig


## Glow of the eye embers now (0 asleep).
func eye_glow() -> float:
	return maxf(_eye_energy, 0.0)


## Fewer draw calls and shadow casters before the rest pose is recorded.
func _arrange() -> void:
	var nodes := ArtLibrary.parts(model)
	for pair: Array in MERGED:
		ExhibitRig.merge_into(nodes.get(pair[0]) as MeshInstance3D, nodes.get(pair[1]) as MeshInstance3D)
	for node: Node in nodes.values():
		var view := node as MeshInstance3D
		if view != null:
			var casts := SHADOW_CASTERS.has(String(view.name))
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _setup() -> void:
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color(0.12, 0.05, 0.03)
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE_COLOR
	_eye_material.emission_energy_multiplier = 0.0
	var skull := part("skull")
	if skull == null:
		return
	var eyes := MeshInstance3D.new()
	eyes.name = "eye_embers"
	eyes.mesh = _embers()
	eyes.material_override = _eye_material
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skull.add_child(eyes)
	_set_eyes(0.0)


## Both eye embers in one mesh (skull space), shared by every raptor.
static func _embers() -> ArrayMesh:
	if _eye_mesh != null:
		return _eye_mesh
	var ball := SphereMesh.new()
	ball.radius = EYE_RADIUS
	ball.height = EYE_RADIUS * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var source := ball.get_mesh_arrays()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var index := PackedInt32Array()
	for side: float in [-1.0, 1.0]:
		var base := verts.size()
		var at := Vector3(EYE_AT.x * side, EYE_AT.y, EYE_AT.z)
		for v in (source[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			verts.append(v + at)
		normals.append_array(source[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		for i in (source[Mesh.ARRAY_INDEX] as PackedInt32Array):
			index.append(i + base)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	_eye_mesh = ArrayMesh.new()
	_eye_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _eye_mesh


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var on_floor := enemy.is_on_floor()
	var dormant := state == EnemyBrain.State.DORMANT
	var stunned := state == EnemyBrain.State.STUNNED
	var crouch := raptor.crouch()
	var leaping := brain.has_struck() and not on_floor
	if leaping and not _airborne:
		_bitten = false
	if _airborne and on_floor:
		_land = LAND_TIME
	_airborne = leaping
	_land = maxf(_land - delta, 0.0)
	if leaping and not _bitten and _near_target():
		_bitten = true
	var run := minf(gait, 1.2) if on_floor else 0.0
	var p := walk_phase
	# targets
	var pitch := -0.1 * run
	var neck := 0.12 * run + sin(p * 2.0) * 0.04 * run
	var jaw := 0.0 if dormant else -0.06 - 0.04 * sin(time * 2.3)
	var tail_lift := 0.0 if dormant else -0.05 - 0.05 * run
	var arms := 0.0
	var leap := 0.0
	var screech := 1.0 if state == EnemyBrain.State.SUSPICIOUS else 0.0
	if crouch > 0.0:
		pitch = -0.18 * crouch
		neck = -0.25 * crouch
		jaw = -0.5 * crouch + sin(time * 55.0) * 0.05 * crouch
		tail_lift = -0.07 * crouch
		arms = 0.7 * crouch
	elif leaping:
		leap = 1.0
		pitch = clampf(enemy.velocity.y * 0.06, -0.3, 0.25)
		neck = 0.05 - pitch * 0.6
		jaw = -0.12 if _bitten else -0.62
		tail_lift = -0.08
		arms = 1.0
	elif since_strike >= 0.0 and on_floor:
		pitch = -0.08
		neck = -0.1
		jaw = -0.25
		arms = 0.4
	if _land > 0.0:
		var squash := _land / LAND_TIME
		crouch = maxf(crouch, squash * 0.7)
		pitch = minf(pitch, -0.12 * squash)
	var rate := 18.0 if leaping else 12.0
	_crouch = ExhibitRig.ease_to(_crouch, crouch, 16.0, delta)
	_leap = ExhibitRig.ease_to(_leap, leap, rate, delta)
	_pitch = ExhibitRig.ease_to(_pitch, pitch, 10.0, delta)
	_neck = ExhibitRig.ease_to(_neck, neck, 10.0, delta)
	_jaw = ExhibitRig.ease_to(_jaw, jaw, 45.0 if _bitten else 16.0, delta)
	_tail_lift = ExhibitRig.ease_to(_tail_lift, tail_lift, 6.0, delta)
	_arms = ExhibitRig.ease_to(_arms, arms, 10.0, delta)
	_fall = ExhibitRig.ease_to(_fall, 1.0 if stunned else 0.0, 8.0 if stunned else 4.0, delta)
	_screech = ExhibitRig.ease_to(_screech, screech, 12.0, delta)
	var twitch := sin(time * 27.0) * 0.16 * _fall
	# the body: bob of the run, the crouch, the leap's pitch, the stun sag
	var bob := -absf(cos(p)) * 0.035 * run
	pose_part("pelvis", Vector3(_pitch + 0.05 * _screech, 0.0, FALL_ROLL * _fall + sin(p) * 0.03 * run),
			Vector3(0.0, bob - CROUCH_DROP * _crouch - FALL_DROP * _fall, 0.0))
	pose_part("spine_2", Vector3(0.04 * _crouch + sin(p * 2.0) * 0.03 * run, 0.0, 0.0))
	# neck and head: level and low in the run, raised in the screech,
	# lowered at the guard in the crouch, straight out in the leap
	var look := sin(time * 1.1) * 0.12 * (1.0 - run) * (0.0 if dormant else 1.0)
	pose_part("neck_1", Vector3(_neck - 0.2 * _leap + 0.2 * _screech - 0.25 * _fall, look * 0.5, 0.0))
	pose_part("neck_2", Vector3(-_pitch * 0.5 + 0.05 * _screech, look * 0.5, 0.0))
	pose_part("skull", Vector3(-_neck * 0.6 + 0.1 * _leap + 0.1 * _screech - _pitch * 0.4 + twitch * 0.5, 0.0, 0.0))
	pose_part("jaw", Vector3(_jaw - 0.5 * _screech - 0.3 * _fall, 0.0, 0.0))
	# arms: folded, raised in the crouch, reaching in the leap
	pose_part("arm_l", Vector3(_arms * 0.9 + sin(p) * 0.15 * run - twitch, 0.0, -0.1 * _arms))
	pose_part("arm_r", Vector3(_arms * 0.9 - sin(p) * 0.15 * run + twitch, 0.0, 0.1 * _arms))
	# legs: left and right half a cycle apart
	_leg("l", p, run, twitch)
	_leg("r", p + PI, run, -twitch)
	# the tail: stiff, swinging against the hips, lifted and lashing in the
	# crouch, drooping when stunned
	var lash := sin(time * 13.0) * 0.16 * _crouch
	for i in TAIL.size():
		# each joint bends for two segments (see MERGED)
		var k := float(i) / (TAIL.size() - 1)
		var swing := sin(p - 0.6 - i * 0.9) * (0.08 + 0.06 * k) * (0.4 + run) if not dormant else 0.0
		pose_part(TAIL[i], Vector3(2.0 * _tail_lift * (1.0 - 0.5 * k) + 0.24 * _fall * k + 0.04 * _leap,
				swing + lash * (0.5 + k) + twitch * 0.6 * k, 0.0))
	_set_eyes(0.0 if dormant else 1.2 + _crouch * _crouch * 5.0 + _screech * 1.5)


## One leg: the thigh swings, the knee folds while the leg comes forward,
## the foot stays flat on the stance and droops in the swing; the crouch
## bends it all, the leap tucks the feet forward with the claws out.
func _leg(side: String, phase: float, run: float, twitch: float) -> void:
	var swing := sin(phase)
	var forward := maxf(cos(phase), 0.0)
	var thigh := 0.55 * swing * run + 0.55 * _crouch + 0.95 * _leap + 0.35 * _fall + twitch
	var shin := -0.8 * forward * run - 0.95 * _crouch - 0.9 * _leap - 0.5 * _fall
	var foot := -(thigh + shin) * 0.85 + 0.45 * forward * run + 0.6 * _leap
	pose_part("thigh_" + side, Vector3(thigh, 0.0, 0.0))
	pose_part("shin_" + side, Vector3(shin, 0.0, 0.0))
	pose_part("foot_" + side, Vector3(foot, 0.0, 0.0))


func _set_eyes(energy: float) -> void:
	if _eye_material == null or is_equal_approx(energy, _eye_energy):
		return
	_eye_energy = energy
	_eye_material.emission_energy_multiplier = energy


func _near_target() -> bool:
	var goal := enemy.target
	return is_instance_valid(goal) and enemy.global_position.distance_to(goal.global_position) <= enemy.attack_reach + 0.5
