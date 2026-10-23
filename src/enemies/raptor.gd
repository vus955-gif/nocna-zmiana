class_name Raptor
extends Enemy
## Velociraptor skeleton (exhibit "Velociraptor — stado"): small (1.1 m),
## fast (7.5 m/s) and fragile (25 HP); hunts in packs of 3-4 (RaptorPack).
## A pack hunts with a driver and flankers (backlog #25): when its hunt
## begins the raptor nearest the guard goes straight for him (the driver,
## [member flank_side] 0) and the others split to his left and right -
## further than FLANK_UNTIL from him each flanker runs for a point
## FLANK_OFFSET beside him (relative to where he looks), closer in it goes
## straight for him; a fallen driver is replaced by the next nearest at the
## next rally. From 4 m it crouches and hisses (0.6 s), then leaps
## on an arc aimed to land on him and bites mid-air (8), skidding to a halt
## and open to punishment after. Old bone: it breaks into little bones.
## A pack (same [member pack_id]) hunts together: when one starts the hunt
## the others join it. Raptors range far (HUNTER_LEASH).
## It runs on the Blender skeleton (ArtLibrary id "raptor") through a
## RaptorRig (run cycle, crouch and hiss, leap, bite, tail; the skull's hit
## zone rides on the model); without the model a greybox of named pivots
## ("pelvis", "neck", "head", "jaw", "leg_l", "leg_r", "arm_l", "arm_r",
## "tail_1".."tail_4") animated here.

const KIND := &"raptor"
## Beyond this distance from the guard a flanker runs for his side.
const FLANK_UNTIL := 6.0
## How far beside the guard the flank point lies.
const FLANK_OFFSET := 4.0
## A flanker runs for a waypoint this far ahead on the way to its flank
## point (planned locally, so it passes obstacles on its own side), picked
## again every FLANK_REPLAN seconds.
const FLANK_LOOKAHEAD := 7.0
const FLANK_REPLAN := 0.3
const HIP_HEIGHT := 0.62
const HEAD_REST := Vector3(0.0, 0.98, -0.62)
const BONE := Color(0.84, 0.79, 0.66)
const EYE := Color(1.0, 0.35, 0.12)
## Hit zones on the Blender model (RaptorRig): the ribcage and hips, and
## the skull round its WeakPoint marker (where it sits in the rest pose).
const MODEL_BODY_ZONE := Vector3(0.32, 0.46, 0.8)
const MODEL_BODY_AT := Vector3(0.0, 0.74, -0.2)
const MODEL_HEAD_RADIUS := 0.12
const MODEL_WEAK_POINT := Vector3(0.0, 0.957, -0.904)

@export var max_leap_speed: float = 12.0
@export var leap_lift: float = 2.6

## +1 = the guard's right, -1 = his left, 0 = straight in.
var flank_side: float = 0.0
## Raptors with the same id (not 0) are one pack.
var pack_id: int = 0

var _leaping := false
var _leap_hit := false
var _airborne := false
var _flanking := false
var _flank_goal := Vector3.ZERO
var _flank_timer: float = 0.0
var _flanking_before := false
## Where a stand-in target "faces" (this raptor's first bearing from it).
var _approach := Vector3.ZERO
var _gait: float = 0.0
var _time: float = 0.0
var _parts: Dictionary = {}
var _eye_material: StandardMaterial3D

## Box meshes shared by every raptor, by size.
static var _boxes: Dictionary = {}


func _configure() -> void:
	max_health = 25.0
	move_speed = 7.5
	turn_speed = 14.0
	attack_damage = 8.0
	attack_reach = 1.4
	eye_height = 0.9
	marker_height = 1.35
	leash = PerceptionRules.HUNTER_LEASH
	material_kind = ExhibitMaterial.Kind.BONE
	notice_sound = &"raptor_screech"
	dust_value = 3
	brain.reaction_time = 0.6
	brain.attack_range = 4.0
	brain.windup = 0.6
	brain.recovery = 0.75


func _ready() -> void:
	super()
	_time = randf() * TAU


## True while it runs for the guard's flank (not straight at him).
func flanking() -> bool:
	return _flanking


## The pack's driver: it goes straight in while the others flank.
func driver() -> bool:
	return flank_side == 0.0


## Hands out the pack's parts for a hunt on a guard at [param guard]: the
## raptor nearest him drives (flank_side 0), the others flank, alternating
## right and left by their distance.
static func assign_roles(pack: Array, guard: Vector3) -> void:
	var order: Array = pack.duplicate()
	order.sort_custom(func(a: Raptor, b: Raptor) -> bool:
		return a.global_position.distance_squared_to(guard) < b.global_position.distance_squared_to(guard))
	for i in order.size():
		var raptor: Raptor = order[i]
		raptor.flank_side = 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)


## 0..1: how deep it crouches for the leap (the telegraph).
func crouch() -> float:
	return brain.windup_progress() if brain.state == EnemyBrain.State.ATTACK and not brain.has_struck() else 0.0


func _physics_process(delta: float) -> void:
	_flanking = false
	super(delta)
	if not _leaping:
		return
	if brain.state != EnemyBrain.State.ATTACK:
		_leaping = false
		return
	if not is_on_floor():
		_airborne = true
	elif _airborne:
		# landed: the bite window closes, the recovery is defenceless
		_airborne = false
		_leaping = false
		_external *= 0.2
		return
	if not _leap_hit and _target_alive() and global_position.distance_to(target.global_position) <= attack_reach and _has_line_of_sight():
		_leap_hit = true
		_deal_damage()


## Flankers aim for a point beside the guard until they are close.
func _chase_direction(delta: float, goal: Vector3) -> Vector3:
	if flank_side != 0.0 and brain.state == EnemyBrain.State.HUNT and brain.knows_guard() and _target_alive():
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > FLANK_UNTIL:
			_flank_timer -= delta
			if _flank_timer <= 0.0 or not _flanking_before:
				_flank_timer = FLANK_REPLAN
				_flank_goal = flank_waypoint()
			goal = _flank_goal
			_flanking = true
	if _flanking_before and not _flanking:
		_repath_timer = 0.0   # done flanking: plan for the guard himself (is he reachable?) at once
	_flanking_before = _flanking
	return super(delta, goal)


## The next waypoint toward the flank point: FLANK_LOOKAHEAD ahead on the
## straight line there, moved to where the navmesh really leads (the end
## of a path to it), so the route stays on this raptor's side of whatever
## stands between.
func flank_waypoint() -> Vector3:
	var flank := target.global_position + guard_right() * flank_side * FLANK_OFFSET
	var run := flank - global_position
	run.y = 0.0
	var point := global_position + (run if run.length() <= FLANK_LOOKAHEAD else run.normalized() * FLANK_LOOKAHEAD)
	point.y = flank.y
	if not _map_has_regions():
		return point
	var path := NavigationServer3D.map_get_path(nav.get_navigation_map(), global_position, point, true, LevelNavigation.WALK_LAYER)
	return path[path.size() - 1] if not path.is_empty() else global_position


## The guard's right (flattened), from where he looks. A target without a
## head (a stand-in) counts as facing the way this raptor first came from.
func guard_right() -> Vector3:
	var facing := Vector3.ZERO
	var guard := target as Player
	if guard != null and guard.head != null:
		facing = -guard.head.global_transform.basis.z
	else:
		if _approach.is_zero_approx():
			_approach = global_position - target.global_position
			_approach.y = 0.0
		facing = _approach
	facing.y = 0.0
	if facing.length() < 0.01:
		facing = Vector3.FORWARD
	return facing.normalized().cross(Vector3.UP)


## A flanker looks where it runs; otherwise it faces its target.
func _face_towards(point: Vector3, delta: float) -> void:
	var run := Vector3(velocity.x, 0.0, velocity.z)
	if _flanking and run.length() > 1.0:
		super(global_position + run, delta)
	else:
		super(point, delta)


func _on_strike() -> void:
	if not _target_alive():
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() <= attack_reach:
		super()
		return
	var airtime := 2.0 * leap_lift / GRAVITY
	_external = to.normalized() * clampf(to.length() / airtime, 4.0, max_leap_speed)
	velocity.y = leap_lift
	_leaping = true
	_leap_hit = false
	_airborne = false
	Sfx.play_at(&"swing", global_position, -4.0)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.ATTACK:
		Sfx.play_at(&"raptor_hiss", global_position + Vector3.UP * eye_height)
	elif to == EnemyBrain.State.HUNT:
		_rally_pack()
	elif to == EnemyBrain.State.DESTROYED and driver() and pack_id != 0:
		_pass_the_drive()


## The driver fell: the hunting rest of the pack picks a new one at once
## (the nearest to the guard drives, the others flank).
func _pass_the_drive() -> void:
	var rest: Array = []
	for other in PerceptionWorld.exhibits():
		var mate := other as Raptor
		if mate == null or mate == self or mate.pack_id != pack_id or mate.is_frozen() or not mate.is_inside_tree():
			continue
		if mate.brain.state == EnemyBrain.State.DESTROYED:
			continue
		rest.append(mate)
	var hunting := rest.any(func(mate: Raptor) -> bool: return mate.brain.is_hunting())
	if hunting:
		Raptor.assign_roles(rest, target.global_position if _target_alive() else brain.last_known)


## The pack hunts together: the others join this one's hunt (quietly: one
## screech is enough), and the pack has a driver (the nearest to the
## guard). Every new hunt - nobody of the pack hunting yet - hands the parts
## out anew; a hunt already on keeps its driver, and a new one is picked
## when the old fell.
func _rally_pack() -> void:
	if pack_id == 0:
		return
	var pack: Array = [self]
	var has_driver := driver()
	var hunting := false
	for other in PerceptionWorld.exhibits():
		var mate := other as Raptor
		if mate == null or mate == self or mate.pack_id != pack_id or mate.is_frozen():
			continue
		if mate.brain.state == EnemyBrain.State.DESTROYED or not mate.is_inside_tree():
			continue
		pack.append(mate)
		has_driver = has_driver or mate.driver()
		if mate.brain.is_hunting():
			hunting = true
		if mate.brain.is_hunting() or mate.brain.state == EnemyBrain.State.STUNNED:
			continue
		if mate.brain.state == EnemyBrain.State.DORMANT or mate.brain.state == EnemyBrain.State.PATROL:
			mate.end_doze()   # (its sleep caught up before it is told to keep quiet)
			mate.brain.quiet = true
		mate.brain.alarm(brain.last_known)
	if not has_driver or not hunting:
		Raptor.assign_roles(pack, brain.last_known)


static var _next_pack: int = 0


## A fresh pack id.
static func new_pack_id() -> int:
	_next_pack += 1
	return _next_pack


# --- body --------------------------------------------------------------

func _build_body() -> void:
	add_collider(0.3, 1.0)
	rig = RaptorRig.build(self)
	if rig == null:
		_build_greybox()
		return
	# hit zones ride on the model: the ribcage with the spine, the skull
	# (weak point) round its WeakPoint marker
	var body_zone := add_hurtbox(box_shape(MODEL_BODY_ZONE), MODEL_BODY_AT)
	var head_at := rig.part_transform("WeakPoint").origin if rig.part("WeakPoint") != null else MODEL_WEAK_POINT
	var head_zone := add_hurtbox(sphere_shape(MODEL_HEAD_RADIUS), head_at, true)
	rig.track(body_zone, &"spine_1", true)
	rig.track(head_zone, &"skull")


## The greybox skeleton (no model): boxes on the same named pivots.
func _build_greybox() -> void:
	var bone := body_material(BONE)
	var dark := body_material(BONE.darkened(0.35))
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color(0.1, 0.05, 0.03)
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE
	_eye_material.emission_energy_multiplier = 0.0
	var pelvis := _pivot(visual, "pelvis", Vector3(0.0, HIP_HEIGHT, 0.05))
	_bone(pelvis, Vector3(0.16, 0.12, 0.22), Vector3.ZERO, bone, Vector3.ZERO, true)
	# spine: vertebrae rising a little toward the chest
	for i in 5:
		var t := i / 4.0
		_bone(pelvis, Vector3(0.07, 0.07, 0.08), Vector3(0.0, 0.04 + 0.06 * t, -0.1 - 0.08 * i), bone)
	# ribcage: pairs of ribs curving down, shorter toward the hips
	for i in 5:
		var z := -0.14 - 0.065 * i
		var length := 0.2 - 0.02 * absf(i - 2.0)
		for side in [-1.0, 1.0]:
			_bone(pelvis, Vector3(0.02, length, 0.025), Vector3(side * 0.07, 0.02, z), bone, Vector3(0.0, 0.0, side * 22.0))
			_bone(pelvis, Vector3(0.02, length * 0.6, 0.025), Vector3(side * 0.05, -0.08, z), dark, Vector3(0.0, 0.0, -side * 18.0))
	# neck: an S-curve up to the skull
	var neck := _pivot(pelvis, "neck", Vector3(0.0, 0.1, -0.46))
	for i in 4:
		_bone(neck, Vector3(0.05, 0.05, 0.06), Vector3(0.0, 0.03 + 0.07 * i, -0.02 * i - (0.04 if i > 1 else 0.0)), bone)
	# the neck pivot sits at (0, HIP_HEIGHT + 0.1, 0.05 - 0.46) in the body
	var head := _pivot(neck, "head", HEAD_REST - Vector3(0.0, HIP_HEIGHT + 0.1, -0.41))
	_bone(head, Vector3(0.11, 0.11, 0.16), Vector3(0.0, 0.0, 0.0), bone, Vector3.ZERO, true)
	_bone(head, Vector3(0.08, 0.07, 0.16), Vector3(0.0, -0.01, -0.14), bone)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.022
		ball.height = 0.044
		eye.mesh = ball
		eye.material_override = _eye_material
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(side * 0.052, 0.025, -0.02)
		head.add_child(eye)
	var jaw := _pivot(head, "jaw", Vector3(0.0, -0.045, 0.04))
	_bone(jaw, Vector3(0.07, 0.025, 0.24), Vector3(0.0, -0.01, -0.12), bone)
	for i in 4:
		for side in [-1.0, 1.0]:
			_bone(head, Vector3(0.01, 0.025, 0.01), Vector3(side * 0.03, -0.055, -0.08 - 0.035 * i), bone)
			_bone(jaw, Vector3(0.01, 0.022, 0.01), Vector3(side * 0.028, 0.012, -0.06 - 0.035 * i), bone)
	# small clawed arms folded under the chest
	for side in [-1.0, 1.0]:
		var arm := _pivot(pelvis, "arm_l" if side < 0.0 else "arm_r", Vector3(side * 0.08, -0.02, -0.4))
		_bone(arm, Vector3(0.025, 0.12, 0.025), Vector3(0.0, -0.05, 0.0), bone, Vector3(25.0, 0.0, 0.0))
		_bone(arm, Vector3(0.02, 0.1, 0.02), Vector3(0.0, -0.1, -0.05), bone, Vector3(-60.0, 0.0, 0.0))
		_bone(arm, Vector3(0.012, 0.05, 0.012), Vector3(0.0, -0.1, -0.11), dark, Vector3(-120.0, 0.0, 0.0))
	# digitigrade legs with the sickle claw
	for side in [-1.0, 1.0]:
		var leg := _pivot(pelvis, "leg_l" if side < 0.0 else "leg_r", Vector3(side * 0.1, 0.0, 0.0))
		_bone(leg, Vector3(0.05, 0.3, 0.06), Vector3(0.0, -0.13, -0.05), bone, Vector3(-20.0, 0.0, 0.0), true)
		_bone(leg, Vector3(0.04, 0.26, 0.04), Vector3(0.0, -0.36, -0.02), bone, Vector3(25.0, 0.0, 0.0), true)
		_bone(leg, Vector3(0.035, 0.16, 0.035), Vector3(0.0, -0.53, 0.02), bone, Vector3(-15.0, 0.0, 0.0))
		_bone(leg, Vector3(0.07, 0.025, 0.12), Vector3(0.0, -0.605, -0.04), bone)
		_bone(leg, Vector3(0.015, 0.06, 0.015), Vector3(side * 0.02, -0.57, -0.07), dark, Vector3(-40.0, 0.0, 0.0))
	# tail: four hinged segments, thinner toward the tip
	var parent := pelvis
	for i in 4:
		var segment := _pivot(parent, "tail_%d" % (i + 1), Vector3(0.0, 0.02 if i == 0 else 0.0, 0.1 if i == 0 else 0.24))
		var size := 0.07 - 0.012 * i
		for k in 3:
			_bone(segment, Vector3(size, size, 0.07), Vector3(0.0, 0.0, 0.04 + 0.08 * k), bone)
		parent = segment
	# hit zones: the body, the skull (weak point)
	add_hurtbox(box_shape(Vector3(0.36, 0.42, 0.85)), Vector3(0.0, HIP_HEIGHT, -0.12))
	add_hurtbox(sphere_shape(0.13), HEAD_REST + Vector3(0.0, 0.0, -0.05), true)


func _update_visuals(delta: float) -> void:
	super(delta)
	if rig != null:
		visual.rotation.x = 0.0   # the rig poses the crouch and the leap itself
		return
	_time += delta
	var awake := brain.state != EnemyBrain.State.DORMANT and brain.state != EnemyBrain.State.DESTROYED
	var run := Vector2(velocity.x, velocity.z).length()
	var stride := clampf(run / move_speed, 0.0, 1.0) if is_on_floor() else 0.0
	_gait += delta * run * 2.6
	var squat := crouch()
	var pelvis := _part("pelvis")
	pelvis.position.y = HIP_HEIGHT - 0.12 * squat + absf(sin(_gait)) * 0.035 * stride
	pelvis.rotation.x = lerpf(pelvis.rotation.x, -0.25 * squat + (0.2 if _airborne else 0.0), 1.0 - exp(-12.0 * delta))
	var tuck := 1.0 if _airborne else 0.0
	# feet first in the air (sickle claws out), knees bent in the crouch
	_part("leg_l").rotation.x = sin(_gait) * 0.7 * stride + 1.0 * tuck + 0.6 * squat
	_part("leg_r").rotation.x = -sin(_gait) * 0.7 * stride + 1.0 * tuck + 0.6 * squat
	var neck := _part("neck")
	neck.rotation.x = lerpf(neck.rotation.x, -0.35 * squat + sin(_gait * 2.0) * 0.05 * stride, 1.0 - exp(-14.0 * delta))
	var bite := 1.0 if brain.has_struck() and _leaping else 0.0
	var gape := maxf(squat * 0.55, bite * 0.8)
	if awake and brain.state == EnemyBrain.State.SUSPICIOUS:
		gape = 0.45   # the screech
	_part("jaw").rotation.x = lerpf(_part("jaw").rotation.x, -gape, 1.0 - exp(-20.0 * delta))
	for i in 4:
		var segment := _part("tail_%d" % (i + 1))
		segment.rotation.y = sin(_time * (2.0 + 4.0 * stride) + i * 0.7) * (0.06 + 0.1 * stride) * (1.0 if awake else 0.0)
		segment.rotation.x = (-0.12 if _airborne else 0.03) + squat * 0.1
	var glow := 0.0
	if awake:
		glow = 1.2 + squat * squat * 4.0
	_eye_material.emission_energy_multiplier = glow


func _part(part_name: String) -> Node3D:
	return _parts[part_name]


func _pivot(parent: Node3D, part_name: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = at
	parent.add_child(pivot)
	_parts[part_name] = pivot
	return pivot


## One box of the greybox skeleton. Only the few big ones
## ([param shadow]: hips, skull, thighs, shins) cast shadows: a pack of
## eighty-odd little bones each would cost a shadow draw apiece.
func _bone(parent: Node3D, size: Vector3, at: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, shadow: bool = false) -> MeshInstance3D:
	if not _boxes.has(size):
		_boxes[size] = box_mesh(size)
	var view := MeshInstance3D.new()
	view.mesh = _boxes[size]
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = at
	view.rotation_degrees = rot_deg
	parent.add_child(view)
	return view
