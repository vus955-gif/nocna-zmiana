class_name MummyRig
extends ExhibitRig
## The mummy (model "mummy", docs/art/kit-pietro1-egipt.md 6), animated in
## code on the model's own pivots:
## - the shamble: the left leg swings stiffly, the right one drags (a short
##   swing kept behind, swung out in an arc while it comes forward), the
##   body dips on the bad leg and lurches over the leg it stands on, hunched;
##   the head sits on a loose spring and lolls a beat behind the body; the
##   left arm reaches ahead, the whip arm hangs heavy;
## - asleep it is an exhibit: arms crossed on its chest (hands at the
##   opposite shoulders), head bowed, eyes dark; suspicious, the head snaps
##   round to the noise ahead of the body and the eyes light up (an
##   OmniLight at the EyeGlow marker, the shader's rim); woken, the arms
##   unfold with weight;
## - the claws: both arms up and the body leaning back, then a chop down;
## - the lash: the whip arm goes up and back, the body twists away, the
##   free arm out for balance, and the bandage unrolls to half again its
##   length and snakes up over the shoulder; the strike swings the arm down
##   and out and the bandage shoots to its mark segment by segment (the tip
##   last: the crack), holds the guard while he is pulled in (the arm yanks
##   back), or slaps the floor; then it is let go and falls and swings on;
## - panic: arms flailing over its head, head thrashing; stunned: hunched,
##   limp, head hanging, swaying;
## - climbing out of a coffin (leans out, steps down off its stand) or a
##   sarcophagus (lies on its back; sits up; swings its legs over the side
##   and stands), by moving the model's root about the hips;
## - the bandage whip (whip_1..4, unparented to the forearm) and the loose
##   strips (strip_1..4) are Verlet ropes (RopeChain) in world space: they
##   lag, swing on turns and hits and settle on their own.
## It falls apart into its parts plus bones and rags (mummy_debris) in a
## cloud of dust.

const WHIP: Array[String] = ["whip_1", "whip_2", "whip_3", "whip_4"]
const STRIPS: Array[String] = ["strip_1", "strip_2", "strip_3", "strip_4"]
## A whip segment's length in the model (m); the telegraph unrolls it to
## UNROLL times that.
const SEGMENT := 0.2
const UNROLL := 1.5
## The lash: each segment sets off LASH_DELAY s after the one before and
## takes LASH_REACH s to be pulled fully onto its line; the bandage holds
## the guard HIT_HOLD s (the pull), a missed slap MISS_HOLD s.
const LASH_DELAY := 0.025
const LASH_REACH := 0.04
const HIT_HOLD := MummyMoves.PULL_TIME + 0.05
const MISS_HOLD := 0.16
## Joint angles on top of the rest pose (radians, Euler YXZ; +x raises an
## arm or a leg forward, bends an elbow; -x leans the torso or the head
## forward; +z on the left arm brings it in, on the right takes it out).
## Crossed arms: tuned on the model so the hands rest at the opposite
## shoulders, elbows down at the sides.
const CROSS_ARM_L := Vector3(0.0, 0.0, -0.15)
const CROSS_FORE_L := Vector3(2.0, -1.2, 0.0)
const CROSS_ARM_R := Vector3(-0.15, 0.0, 0.0)
const CROSS_FORE_R := Vector3(1.8, 1.0, 0.0)
const REACH_ARM_L := Vector3(1.2, 0.0, -0.08)
const REACH_FORE_L := Vector3(0.35, 0.0, 0.0)
const HANG_ARM_R := Vector3(0.12, 0.0, 0.1)
const HANG_FORE_R := Vector3(0.25, 0.0, 0.0)
const CLAW_UP_ARM_L := Vector3(2.55, 0.0, -0.18)
const CLAW_UP_ARM_R := Vector3(2.55, 0.0, 0.18)
const CLAW_UP_FORE := Vector3(0.75, 0.0, 0.0)
const CLAW_DOWN_ARM_L := Vector3(0.95, 0.0, 0.12)
const CLAW_DOWN_ARM_R := Vector3(0.95, 0.0, -0.12)
const CLAW_DOWN_FORE := Vector3(0.15, 0.0, 0.0)
const CLAW_CHOP := 0.14
const LASH_UP_ARM_R := Vector3(2.75, 0.0, 0.4)
const LASH_UP_FORE_R := Vector3(0.55, 0.0, 0.0)
const LASH_OUT_ARM_R := Vector3(1.25, 0.0, 0.08)
const LASH_OUT_FORE_R := Vector3(0.05, 0.0, 0.0)
const LASH_PULL_ARM_R := Vector3(0.45, 0.0, 0.15)
const LASH_PULL_FORE_R := Vector3(1.2, 0.0, 0.0)
const LASH_SWING := 0.12
const BALANCE_ARM_L := Vector3(0.7, 0.0, -0.55)
const LIMP_ARM := Vector3(0.25, 0.0, 0.0)
const LIMP_FORE := Vector3(0.1, 0.0, 0.0)
## The hips' height over the feet (the legs' pivots).
const HIP := 0.92
## Climbing out of a sarcophagus (its space): the hips on its floor, then
## on its front rim; the share of the last phase spent getting onto the rim.
const HIP_IN := Vector3(-0.35, 0.42, 0.0)
const HIP_RIM := Vector3(-0.15, 1.12, -0.72)
const RIM_SHARE := 0.45
## The head's spring (stiffness, damping): loose enough to loll.
const HEAD_SPRING := Vector2(70.0, 7.0)
const EYE_COLOR := Color(1.0, 0.56, 0.2)
const EYE_RANGE := 1.8
const RAGS: Array[String] = ["scrap_1", "scrap_2", "scrap_3"]
const BONES: Array[String] = ["bone_1", "bone_2"]

## mummy_debris part -> [Mesh, Array[Material]] (debris variants), shared.
static var _debris: Dictionary = {}

var mummy: Mummy
## The bandage whip: 5 points from the wrist.
var whip: RopeChain = null

var _whip_parts: Array[Node3D] = []
## [strip node, RopeChain, length]
var _strips: Array = []
var _eye_light: OmniLight3D
var _eye: float = 0.0
var _arm_l := Vector3.ZERO
var _fore_l := Vector3.ZERO
var _arm_r := Vector3.ZERO
var _fore_r := Vector3.ZERO
var _cross: float = 1.0
var _hunch: float = 0.0
var _twist: float = 0.0
var _roll: float = 0.0
var _head_yaw: float = 0.0
## Spring states: x = angle, y = angular velocity.
var _head_pitch := Vector2.ZERO
var _head_roll := Vector2.ZERO
var _panic: float = 0.0
var _stun: float = 0.0
var _wrist := Vector3.ZERO
var _last_root := Vector3.INF


static func build(owner_mummy: Mummy) -> MummyRig:
	var rig := MummyRig.new()
	rig.mummy = owner_mummy
	rig.cycle_length = 1.5
	rig.full_speed = 1.9
	rig.gib_density = 4.0
	return ExhibitRig.attach(owner_mummy, rig, &"mummy") as MummyRig


## Where the bandage leaves the hand now (world).
func wrist() -> Vector3:
	return _wrist


## The whip's tip now (world).
func whip_tip() -> Vector3:
	return whip.tip() if whip != null else _wrist


## Brightness of the eye light now.
func eye_energy() -> float:
	return _eye


## A hit swings the loose bandages and the whip ([param push]: m/s).
func jolt(push: Vector3) -> void:
	if whip != null:
		whip.kick(push, 1.0 / 60.0)
	for entry: Array in _strips:
		(entry[1] as RopeChain).kick(push * 1.5, 1.0 / 60.0)


## A rag of bandage torn off at [param at], flying with [param fling].
func tear_rag(at: Vector3, fling: Vector3) -> void:
	_fly(RAGS[randi() % RAGS.size()], at, fling, 7.0)


## The parts fly (the base), then bones and rags tumble out of the body in
## a cloud of dust.
func shatter(center: Vector3, plan: GibPlanner.Plan, push: Vector3) -> void:
	super(center, plan, push)
	var flat := Vector3(push.x, 0.0, push.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO
	var names: Array[String] = BONES + RAGS
	for piece_name in names:
		var at := center + Vector3(randf_range(-0.2, 0.2), randf_range(-0.35, 0.35), randf_range(-0.2, 0.2))
		var velocity := (flat * 0.8 + Vector3(randf_range(-0.8, 0.8), randf_range(0.6, 1.3), randf_range(-0.8, 0.8))).normalized() \
				* plan.impulse * randf_range(0.5, 1.0)
		_fly(piece_name, at, velocity, 9.0)
	Fx.puff(center, ExhibitMaterial.particle_color(ExhibitMaterial.Kind.LINEN), 48 if plan.gibbed else 32, 1.1)


# --- set-up ---------------------------------------------------------------------

## The whip's segments go under the forearm side by side (each is placed in
## the world on its own, stretched along its length: nested, the stretch
## would carry down the chain); thin ropes cast no shadows.
func _arrange() -> void:
	var p := ArtLibrary.parts(model)
	var forearm := p.get("forearm_r") as Node3D
	if forearm != null:
		for segment in ["whip_4", "whip_3", "whip_2"]:
			var node := p.get(segment) as Node3D
			if node != null:
				ExhibitRig.nest(node, forearm)
	for rope_part in WHIP + STRIPS:
		var view := p.get(rope_part) as MeshInstance3D
		if view != null:
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _setup() -> void:
	for segment in WHIP:
		_whip_parts.append(part(segment))
	for strip_name in STRIPS:
		var view := part(strip_name) as MeshInstance3D
		if view != null and view.mesh != null:
			_strips.append([view, null, maxf(view.mesh.get_aabb().size.y, 0.1)])
	var head := part("head")
	var marker := part("EyeGlow")
	_eye_light = OmniLight3D.new()
	_eye_light.name = "EyeLight"
	_eye_light.light_color = EYE_COLOR
	_eye_light.omni_range = EYE_RANGE
	_eye_light.light_energy = 0.0
	_eye_light.shadow_enabled = false
	_eye_light.visible = false
	_eye_light.position = (marker.position if marker != null else Vector3(0.0, 0.126, -0.07)) + Vector3(0.0, 0.0, -0.08)
	if head != null:
		head.add_child(_eye_light)
	_arm_l = CROSS_ARM_L
	_fore_l = CROSS_FORE_L
	_arm_r = CROSS_ARM_R
	_fore_r = CROSS_FORE_R
	_head_pitch = Vector2(-0.28, 0.0)


# --- per frame -----------------------------------------------------------------

func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var dormant := state == EnemyBrain.State.DORMANT
	var stunned := state == EnemyBrain.State.STUNNED
	var attacking := state == EnemyBrain.State.ATTACK
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var lash := attacking and mummy.move == MummyMoves.Move.LASH
	var claw := attacking and mummy.move == MummyMoves.Move.CLAW
	var panic := mummy.panicking()
	var in_tomb := mummy.in_tomb()
	var lying := in_tomb and mummy.tomb.style == MummyMoves.Tomb.SARCOPHAGUS
	var rise := mummy.rise_phases()
	var g := 0.0 if lying else minf(gait, 1.3)
	var p := walk_phase
	var s := sin(p)
	var c := cos(p)
	# legs: the left swings stiffly, the right drags behind and arcs out
	var stride := 1.3 if panic else 1.0
	pose_part("leg_l", Vector3(0.36 * s * g * stride, 0.0, -0.03 * g))
	var drag := maxf(-c, 0.0)
	pose_part("leg_r", Vector3((-0.2 - 0.12 * _panic) * s * g - 0.08 * g * (1.0 - _panic), 0.0, 0.16 * drag * g * (1.0 - _panic)))
	# body: hunched, dipping on the bad leg, lurching over the standing one
	var hunch := -0.18 - 0.05 * g
	var twist := 0.08 * s * g
	var roll := -0.07 * g * c
	var bob := -0.02 * g - 0.03 * g * maxf(c, 0.0)
	var arm_l := REACH_ARM_L + Vector3(0.1 * sin(p + PI) * g, 0.0, 0.0)
	var fore_l := REACH_FORE_L
	var arm_r := HANG_ARM_R + Vector3(0.18 * s * g, 0.0, 0.0)
	var fore_r := HANG_FORE_R
	var rate := 9.0
	var rate_r := 9.0
	if claw:
		if w > 0.0:
			arm_l = arm_l.lerp(CLAW_UP_ARM_L, up)
			arm_r = arm_r.lerp(CLAW_UP_ARM_R, up)
			fore_l = fore_l.lerp(CLAW_UP_FORE, up)
			fore_r = fore_r.lerp(CLAW_UP_FORE, up)
			hunch = lerpf(hunch, 0.05, up)
			rate = 14.0
			rate_r = 14.0
		elif since_strike >= 0.0:
			if since_strike < CLAW_CHOP:
				arm_l = CLAW_DOWN_ARM_L
				arm_r = CLAW_DOWN_ARM_R
				fore_l = CLAW_DOWN_FORE
				fore_r = CLAW_DOWN_FORE
				hunch = -0.22
				rate = 40.0
				rate_r = 40.0
			else:
				rate = 4.5   # heavy arms come back slowly: the opening
				rate_r = 4.5
	elif lash:
		if not brain.has_struck():
			arm_r = arm_r.lerp(LASH_UP_ARM_R, up)
			fore_r = fore_r.lerp(LASH_UP_FORE_R, up)
			arm_l = arm_l.lerp(BALANCE_ARM_L, up)
			twist = lerpf(twist, -0.4, up)
			hunch = lerpf(hunch, 0.0, up)
			rate_r = 12.0
		else:
			arm_l = arm_l.lerp(BALANCE_ARM_L, 0.5)
			var hit := mummy.lash_result == Mummy.Lash.HIT
			if since_strike < LASH_SWING:
				arm_r = LASH_OUT_ARM_R
				fore_r = LASH_OUT_FORE_R
				twist = 0.28
				hunch = -0.12
				rate_r = 45.0
			elif hit and since_strike < HIT_HOLD + 0.1:
				arm_r = LASH_PULL_ARM_R
				fore_r = LASH_PULL_FORE_R
				twist = 0.1
				hunch = -0.05
				rate_r = 22.0
			else:
				rate_r = 3.0   # the whip coils back slowly
	_panic = ExhibitRig.ease_to(_panic, 1.0 if panic else 0.0, 8.0 if panic else 3.0, delta)
	if _panic > 0.01:
		var t := time
		arm_l = arm_l.lerp(Vector3(2.4 + 0.5 * sin(t * 11.0), 0.0, -0.45 + 0.3 * sin(t * 7.3)), _panic)
		arm_r = arm_r.lerp(Vector3(2.3 + 0.5 * sin(t * 10.3 + 1.5), 0.0, 0.45 + 0.3 * sin(t * 8.1)), _panic)
		fore_l = fore_l.lerp(Vector3(0.6 + 0.5 * sin(t * 13.0), 0.0, 0.0), _panic)
		fore_r = fore_r.lerp(Vector3(0.6 + 0.5 * sin(t * 12.1 + 0.7), 0.0, 0.0), _panic)
		twist += 0.2 * sin(t * 6.0) * _panic
		roll += 0.12 * sin(t * 5.1) * _panic
		hunch = lerpf(hunch, 0.1, _panic)
		rate = 20.0
		rate_r = 20.0
	_stun = ExhibitRig.ease_to(_stun, 1.0 if stunned else 0.0, 6.0 if stunned else 3.0, delta)
	if _stun > 0.01:
		arm_l = arm_l.lerp(LIMP_ARM, _stun)
		arm_r = arm_r.lerp(LIMP_ARM, _stun)
		fore_l = fore_l.lerp(LIMP_FORE, _stun)
		fore_r = fore_r.lerp(LIMP_FORE, _stun)
		hunch = lerpf(hunch, -0.5 + 0.04 * sin(time * 1.7), _stun)
		roll = lerpf(roll, 0.08 * sin(time * 1.3), _stun)
	# the exhibit's crossed arms: asleep, loosening when suspicious, unfolding
	# (with weight) when it wakes or climbs out
	var cross := 1.0 if dormant else 0.0
	if state == EnemyBrain.State.SUSPICIOUS and _cross > 0.5:
		cross = 0.75
	if mummy.rising():
		cross = 1.0 - rise.y
	_cross = ExhibitRig.ease_to(_cross, cross, 2.5 if cross < _cross else 6.0, delta)
	if _cross > 0.001:
		arm_l = arm_l.lerp(CROSS_ARM_L, _cross)
		fore_l = fore_l.lerp(CROSS_FORE_L, _cross)
		arm_r = arm_r.lerp(CROSS_ARM_R, _cross)
		fore_r = fore_r.lerp(CROSS_FORE_R, _cross)
		hunch = lerpf(hunch, 0.0, _cross)
		twist = lerpf(twist, 0.0, _cross)
		roll = lerpf(roll, 0.0, _cross)
		bob *= 1.0 - _cross
	_arm_l = _ease_v(_arm_l, arm_l, rate, delta)
	_fore_l = _ease_v(_fore_l, fore_l, rate, delta)
	_arm_r = _ease_v(_arm_r, arm_r, rate_r, delta)
	_fore_r = _ease_v(_fore_r, fore_r, rate_r, delta)
	_hunch = ExhibitRig.ease_to(_hunch, hunch, 8.0, delta)
	_twist = ExhibitRig.ease_to(_twist, twist, rate_r * 0.8 if lash else 8.0, delta)
	_roll = ExhibitRig.ease_to(_roll, roll, 7.0, delta)
	pose_part("torso", Vector3(_hunch, _twist, _roll), Vector3(0.0, bob, 0.0))
	pose_part("arm_l", _arm_l)
	pose_part("forearm_l", _fore_l)
	pose_part("arm_r", _arm_r)
	pose_part("forearm_r", _fore_r)
	_pose_head(delta, state, bob)
	_pose_rise(rise, in_tomb)
	_pose_eyes(delta, state, w, panic)
	_pose_whip(delta, lash, up)
	_pose_strips(delta)


## The head: turns to what it watches (fast when suspicious), nods and
## lolls on a spring a beat behind the body.
func _pose_head(delta: float, state: EnemyBrain.State, bob: float) -> void:
	var brain := enemy.brain
	var watch := Vector3.INF
	var reach := 0.6
	if state == EnemyBrain.State.SUSPICIOUS:
		watch = brain.last_known
		reach = 1.2
	elif brain.is_hunting() and brain.knows_guard() and is_instance_valid(enemy.target):
		watch = enemy.target.global_position
	var yaw := 0.0
	if watch != Vector3.INF:
		var local := enemy.global_basis.orthonormalized().inverse() * (watch - enemy.global_position)
		if Vector2(local.x, local.z).length() > 0.3:
			yaw = clampf(atan2(-local.x, -local.z) - _twist, -reach, reach)
	var pitch := -0.1 + bob * 3.0
	var roll := -_roll * 1.5 + 0.1 * sin(time * 0.9 + 1.3) * (0.5 + 0.5 * sin(time * 0.37))
	var spring := HEAD_SPRING
	match state:
		EnemyBrain.State.DORMANT:
			pitch = -0.28
			roll = 0.0
			spring = Vector2(120.0, 25.0)
		EnemyBrain.State.SUSPICIOUS:
			pitch = 0.02
		EnemyBrain.State.STUNNED:
			pitch = -0.6
			roll = 0.15 * sin(time * 1.7)
	if _panic > 0.01:
		pitch = lerpf(pitch, 0.25 + 0.2 * sin(time * 7.0), _panic)
		roll = lerpf(roll, 0.3 * sin(time * 5.7), _panic)
		yaw += 0.5 * sin(time * 6.5) * _panic
	_head_yaw = ExhibitRig.ease_to(_head_yaw, yaw, 9.0 if state == EnemyBrain.State.SUSPICIOUS else 5.0, delta)
	_head_pitch = _spring(_head_pitch, pitch, spring, delta)
	_head_roll = _spring(_head_roll, roll, spring, delta)
	pose_part("head", Vector3(_head_pitch.x, _head_yaw, _head_roll.x))


## Climbing out of the tomb: the model's root moves about the feet (the
## coffin: stands on its stand, leans out, steps down) or the hips (the
## sarcophagus: lies on its back, sits up, swings round and over the side
## to stand beside it). Out of the tomb the model sits where the body is.
func _pose_rise(rise: Vector3, in_tomb: bool) -> void:
	if not in_tomb:
		if not model.transform.is_equal_approx(Transform3D.IDENTITY):
			model.transform = Transform3D.IDENTITY
		return
	var tomb := mummy.tomb
	if tomb.style == MummyMoves.Tomb.COFFIN:
		var lean := _smooth(rise.y)
		var step := _smooth(rise.z)
		var height := MummyTomb.COFFIN_STAND * (1.0 - step) + 0.06 * sin(rise.z * PI)
		model.transform = Transform3D(Basis(Vector3.RIGHT, -0.26 * lean * (1.0 - step)), Vector3(0.0, height, 0.0))
		return
	# the sarcophagus, in its own space: lying on its back with the legs
	# along +X (body up = -X, face up); it sits up (the torso turns up
	# against the root); hoists itself onto the front rim swinging its stiff
	# legs round over the side (the root yaws a quarter turn: legs along
	# -Z); then stands up off the rim (the root turns about X until the legs
	# hang straight down), the torso kept upright all along.
	var lie := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	var sit_up := _smooth(rise.y)
	var swing := clampf(rise.z / RIM_SHARE, 0.0, 1.0)
	var stand := _smooth(clampf((rise.z - RIM_SHARE) / (1.0 - RIM_SHARE), 0.0, 1.0))
	var root := Basis(Vector3.UP, PI * 0.5 * pow(_smooth(swing), 1.5)) * lie
	var hip := HIP_IN
	if rise.z >= RIM_SHARE:
		root = Basis(Vector3.RIGHT, PI * 0.5 * (1.0 - stand))
		hip = HIP_RIM.lerp(Vector3(0.0, HIP, -MummyTomb.SARCOPHAGUS_EXIT), stand)
	elif swing > 0.0:
		var lift := 1.0 - pow(1.0 - swing, 3.0)   # up first, then out over the rim
		hip = Vector3(lerpf(HIP_IN.x, HIP_RIM.x, swing), lerpf(HIP_IN.y, HIP_RIM.y, lift), HIP_RIM.z * swing * swing)
	var place := tomb.global_transform.orthonormalized()
	var world := place * Transform3D(root, hip - root * Vector3(0.0, HIP, 0.0))
	model.transform = (model.get_parent() as Node3D).global_transform.affine_inverse() * world
	var torso := part("torso")
	if torso != null:
		var upright := -PI * 0.5 * (sit_up if rise.z < RIM_SHARE else 1.0 - stand)
		var base: Transform3D = rest["torso"]
		torso.transform = Transform3D(Basis(Vector3.RIGHT, upright) * base.basis, base.origin)


## The eyes: dark asleep, smouldering awake, flaring when it notices
## something and through every telegraph, flickering in panic.
func _pose_eyes(delta: float, state: EnemyBrain.State, w: float, panic: bool) -> void:
	var goal := 0.0
	if state != EnemyBrain.State.DORMANT:
		goal = 0.35
	if state == EnemyBrain.State.SUSPICIOUS:
		goal = 1.4
	elif state == EnemyBrain.State.ATTACK and not enemy.brain.has_struck():
		goal = 0.6 + 1.8 * w * w
	elif state == EnemyBrain.State.STUNNED:
		goal = 0.1
	if panic:
		goal = 0.9 + 0.5 * sin(time * 23.0)
	_eye = ExhibitRig.ease_to(_eye, goal, 10.0, delta)
	if _eye_light != null:
		_eye_light.light_energy = _eye
		_eye_light.visible = _eye > 0.02


## The bandage whip on its rope: hanging, rising and unrolling through the
## telegraph, shot onto its mark (segment after segment), holding the
## guard, let go to fall and swing.
func _pose_whip(delta: float, lash: bool, up: float) -> void:
	var forearm := part("forearm_r")
	if forearm == null or _whip_parts.size() < WHIP.size():
		return
	var root := forearm.global_transform * (rest["whip_1"] as Transform3D).origin
	_wrist = root
	if whip == null:
		whip = RopeChain.hanging(root, WHIP.size(), SEGMENT)
		whip.damping = 0.06
	elif root.distance_to(_last_root) > 0.6:
		whip.place(root)   # the body was moved (placed in its tomb, respawned)
	_last_root = root
	whip.floor_y = _floor_height()
	var length := SEGMENT
	var length_rate := 5.0
	var targets := PackedVector3Array()
	var weights := PackedFloat32Array()
	var pull_rate := 0.0
	if lash and not enemy.brain.has_struck():
		length = SEGMENT * lerpf(1.0, UNROLL, up)
		length_rate = 10.0
		var basis := enemy.global_basis.orthonormalized()
		for i in WHIP.size() + 1:
			var k := float(i)
			var wave := sin(time * 10.0 - k * 1.1)
			targets.append(root + Vector3.UP * (0.24 * k * up) + basis.z * (0.08 * k + 0.05 * k * cos(time * 8.0 - k)) \
					+ basis.x * (0.1 * k * wave * up))
			weights.append(0.5 * up)
		pull_rate = 18.0
	elif lash and since_strike >= 0.0:
		var hold := HIT_HOLD if mummy.lash_result == Mummy.Lash.HIT else MISS_HOLD
		if since_strike < hold:
			var aim := mummy.lash_target()
			var reach := root.distance_to(aim)
			length = clampf(reach / WHIP.size(), SEGMENT * 0.6, 1.2)
			length_rate = 40.0
			var line := (aim - root).normalized() if reach > 0.01 else -enemy.global_basis.z
			for i in WHIP.size() + 1:
				var k := float(i)
				targets.append(root + line * reach * k / WHIP.size())
				var start := (k - 1.0) * LASH_DELAY
				weights.append(clampf((since_strike - start) / LASH_REACH, 0.0, 1.0) if i > 0 else 0.0)
			pull_rate = 60.0
	for i in whip.lengths.size():
		whip.lengths[i] = ExhibitRig.ease_to(whip.lengths[i], length, length_rate, delta)
	whip.step(delta, root)
	if not targets.is_empty():
		whip.pull_toward(targets, weights, delta, pull_rate)
	var side := enemy.global_basis.x.normalized()
	for i in WHIP.size():
		_place(_whip_parts[i], whip.points[i], whip.points[i + 1], side, SEGMENT)


## The loose strips hang from where they are sewn on and swing.
func _pose_strips(delta: float) -> void:
	for entry: Array in _strips:
		var view: Node3D = entry[0]
		var parent := view.get_parent() as Node3D
		var anchor := parent.global_transform * (rest[String(view.name)] as Transform3D).origin
		var rope: RopeChain = entry[1]
		if rope == null:
			rope = RopeChain.hanging(anchor, 1, entry[2])
			rope.damping = 0.07
			entry[1] = rope
		elif rope.points[0].distance_to(anchor) > 0.6:
			rope.place(anchor)
		rope.floor_y = _floor_height()
		rope.step(delta, anchor)
		_place(view, rope.points[0], rope.points[1], parent.global_basis.x.normalized(), entry[2])


# --- helpers -----------------------------------------------------------------

## What the bandages lie on: the floor under it, or the floor of the
## sarcophagus it lies in.
func _floor_height() -> float:
	if mummy.in_tomb() and mummy.tomb.style == MummyMoves.Tomb.SARCOPHAGUS and mummy.rise_phases().z < RIM_SHARE:
		return mummy.tomb.global_position.y + 0.3
	return enemy.global_position.y + 0.015


## Sets [param node] (a mesh hanging along its -Y from its origin, rest
## length [param rest_length]) between [param from] and [param to] in the
## world, stretched to fit, its width along [param side].
func _place(node: Node3D, from: Vector3, to: Vector3, side: Vector3, rest_length: float) -> void:
	var run := to - from
	var length := run.length()
	var y_axis := -run / length if length > 0.0001 else Vector3.UP
	var x_axis := side - y_axis * side.dot(y_axis)
	if x_axis.length_squared() < 0.000001:
		x_axis = y_axis.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis)
	var basis := Basis(x_axis, y_axis * maxf(length / rest_length, 0.05), z_axis)
	var parent := node.get_parent() as Node3D
	node.transform = parent.global_transform.affine_inverse() * Transform3D(basis, from)


## A mummy_debris part as debris at [param at] with [param velocity].
func _fly(piece_name: String, at: Vector3, velocity: Vector3, spin: float) -> void:
	var entry := _debris_piece(piece_name)
	if entry.is_empty():
		Fx.chunk(at, ExhibitMaterial.color(ExhibitMaterial.Kind.LINEN), 0.1, velocity)
		return
	var mesh: Mesh = entry[0]
	var materials: Array[Material] = []
	materials.assign(entry[1])
	var turn := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	var shard := MeshShards.whole(mesh)
	Fx.piece(shard, MeshShards.materials_for(shard, materials), Transform3D(turn, at - turn * shard.center), velocity, spin)


## [Mesh, materials] of a mummy_debris part ([] without the model).
static func _debris_piece(piece_name: String) -> Array:
	if _debris.is_empty():
		var source := ArtLibrary.exhibit(&"mummy_debris")
		if source == null:
			return []
		for child in source.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			if view.mesh == null:
				continue
			var materials: Array = []
			for i in view.mesh.get_surface_count():
				materials.append(ArtLibrary.debris_material(view.get_active_material(i)))
			_debris[String(view.name)] = [view.mesh, materials]
		source.free()
	return _debris.get(piece_name, [])


static func _ease_v(from: Vector3, to: Vector3, rate: float, delta: float) -> Vector3:
	return from.lerp(to, 1.0 - exp(-rate * delta))


static func _smooth(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## A damped spring (x = angle, y = velocity) toward [param goal];
## [param spring] = (stiffness, damping).
static func _spring(state: Vector2, goal: float, spring: Vector2, delta: float) -> Vector2:
	var velocity := state.y + (spring.x * (goal - state.x) - spring.y * state.y) * delta
	return Vector2(state.x + velocity * delta, velocity)

