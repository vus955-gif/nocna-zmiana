class_name GeneralMoves
extends RefCounted
## The General's choreography: from the brain's moment, the footwork's feet
## and the fight's points (set by the General each frame, body space) it
## composes the Pose his rig shows, in two layers:
## 1. THE STANCE, always: chudan - the knees bent, the feet where the
##    footwork has them (a sliding foot dips the hips a little toward the
##    standing one), the torso turning toward the guard a moment late, the
##    head on him (springs), the blade breathing; the sode swing on springs
##    off the shoulders, the kusazuri off the hips (kicked by the hips'
##    acceleration, the front panel lifted by the thigh).
## 2. THE ACTION, a MotionClip per attack sampled at the brain's clip_time()
##    (0..1 warning, 1..2 strike, 2..3 recovery), laid over the first. The
##    sword is a frame in torso space (the right fist's grip point and the
##    blade's line); both fists stay on the hilt (the rig's IK) through every
##    frame - the frames below are all within both arms' reach:
##    - the dash cut: the blade rises to jodan over the head and coils (the
##      hips sink back), glints; at 1.0 the lunge (the General flies: the
##      body low and forward, the blade thrust ahead then swept across in a
##      horizontal cut, the torso turning with it); a miss ends in a stumble
##      with the blade low and the back open, a hit in a chiburi flick;
##    - the close cut: jodan, then kesa-giri down and across;
##    - the feint: the compact whirl, the sidestep, then the dash's moves;
##    - the leaps: the crouch, the tucked flight, the landing's absorb; the
##      sword sheathed and the bow taken on the way up, drawn again fast on
##      the way down (the landing cuts into the gravel);
##    - the volley: the arrow nocked, the bow drawn to the cheek, the release;
##    - the stun (the blade dropped, the body shuddering), the reel after a
##      fist, the transformation (the sword planted), and the waking (the
##      armour assembles - the rig's; then the draw: the right hand across to
##      the scabbard, the pull as the left hand draws the saya back, the swing
##      up into jodan and down to chudan).
## Principles: anticipation before every blow, ease in and out, overshoot
## and settle, follow-through on springs, contacts exactly on their marks.

const S := GeneralBrain.State
const A := GeneralBrain.Attack
## The stance: the hips sink this much below the carved rest (bent knees).
const STANCE_DROP := 0.08
## Head limits on the torso (rad).
const NECK_YAW := 1.0
const NECK_PITCH := Vector2(-0.6, 0.45)
## The torso turns this far toward the guard (rad) when he is off the front.
const TWIST := 0.35
const TWIST_MAX := 0.9

# --- the sword's frames (torso space: grip = the right fist's point on the
# --- hilt, dir = pommel -> point) --------------------------------------------
const CHUDAN_GRIP := Vector3(0.095, 0.109, -0.49)
const CHUDAN_DIR := Vector3(0.039, 0.635, -0.771)
const JODAN_GRIP := Vector3(0.08, 0.95, -0.05)
const JODAN_DIR := Vector3(0.0, 0.6, 0.8)
## The lunge: thrust ahead, then the horizontal cut's start and end.
const THRUST_GRIP := Vector3(0.2, 0.25, -0.5)
const THRUST_DIR := Vector3(-0.15, 0.05, -0.99)
const CUT_START_GRIP := Vector3(0.18, 0.2, -0.42)
const CUT_START_DIR := Vector3(-0.3, 0.0, -0.954)
const CUT_END_GRIP := Vector3(-0.08, 0.15, -0.42)
const CUT_END_DIR := Vector3(-0.93, -0.1, -0.35)
## The stumble's low blade (a miss), the chiburi's flick (a hit).
const LOW_LEFT_GRIP := Vector3(0.0, 0.0, -0.4)
const LOW_LEFT_DIR := Vector3(-0.6, -0.55, -0.58)
const CHIBURI_GRIP := Vector3(0.35, 0.2, -0.3)
const CHIBURI_DIR := Vector3(0.6, -0.6, -0.53)
## Kesa-giri's end (down and across).
const KESA_GRIP := Vector3(0.05, 0.05, -0.45)
const KESA_DIR := Vector3(-0.45, -0.55, -0.7)
## Hasso: upright by the right shoulder (the whirl, a parry, the leap).
const HASSO_GRIP := Vector3(0.3, 0.45, -0.2)
const HASSO_DIR := Vector3(0.1, 0.95, -0.3)
## Planted before him (the transformation), dropped (the stun).
const PLANTED_GRIP := Vector3(0.0, 0.31, -0.5)
const PLANTED_DIR := Vector3(0.0, -0.98, -0.2)
const DROPPED_GRIP := Vector3(0.15, 0.05, -0.35)
const DROPPED_DIR := Vector3(-0.1, -0.75, -0.65)
## The draw: the hilt's way from the scabbard's mouth up into jodan bulges
## this far forward.
const DRAW_BULGE := 0.3
## The saya is drawn back this far along its line by the left hand.
const SAYA_PULL := 0.5
## Where the free right hand hangs, and the quiver's arrows (body space,
## off the torso).
const HAND_REST_R := Vector3(0.46, -0.28, -0.08)
const HAND_REST_L := Vector3(-0.46, -0.28, -0.08)
const QUIVER_REACH := Vector3(0.32, 0.36, 0.3)
## The archer: the bow hand this far out along the aim, the string hand at
## the cheek (head space).
const BOW_REACH := 0.72
const CHEEK := Vector3(0.11, 0.0, -0.12)
## The legs tuck this far up toward the hips in a leap.
const TUCK := 0.45

var rig: GeneralRig
var pose := GeneralRig.Pose.new()

# --- the fight's points, body space (set by the General) ----------------------
## The guard's chest.
var guard := Vector3(0.0, 1.5, -8.0)
## The volley's aim (unit, body space): where the arrows go.
var aim := Vector3.FORWARD
## The blade blocked a hit from this direction (body space; ZERO = none).
var parry_dir := Vector3.ZERO
## The hips' speed last frame (body space; the springs read its change).
var hip_velocity := Vector3.ZERO

## The glint of the blade this frame (0..1), for the node's light and sound.
var glint: float = 0.0
## The phantom's dash runs this far ahead (clip units); 0 for the General.
var clip_shift: float = 0.0
var time: float = 0.0

var _clips: Dictionary = {}
var _dash_miss: MotionClip
var _dash_hit: MotionClip
var _draw: MotionClip
var _stun: MotionClip
var _reel: MotionClip
var _transform: MotionClip
var _look_yaw := Spring.new(1.8, 0.6)
var _look_pitch := Spring.new(1.8, 0.7)
var _twist := Spring.new(1.3, 0.7)
var _breath: float = 0.0
var _parry := Spring.new(4.0, 0.35)
var _parry_dir := Vector3.ZERO
var _sode: Array = []
var _kusazuri: Array = []
var _hip_before := Vector3.ZERO
var _pelvis_before := Vector3.ZERO
var _grip_before := Vector3.ZERO
var _grip_speed: float = 0.0
var _dip := Spring.new(3.5, 0.5)
var _eye_flicker: float = 0.0


func _init(for_rig: GeneralRig) -> void:
	rig = for_rig
	for side in 2:
		_sode.append([Spring.new(1.9, 0.3), Spring.new(2.1, 0.3)])
	for panel in 4:
		_kusazuri.append(Spring.new(2.3, 0.32))
	_build_clips()


## The pose for [param brain]'s moment, the [param feet] and the body at
## [param body] (world), advanced by [param delta].
func compose(brain: GeneralBrain, feet: GeneralFootwork, body: Transform3D, delta: float) -> GeneralRig.Pose:
	time += delta
	_reset_pose()
	glint = 0.0
	if brain.state == S.DORMANT:
		_hanging()
		_settle_springs()
		return pose
	pose.eyes = 1.0
	_stance(brain, feet, body, delta)
	var t := brain.clip_time() + clip_shift
	match brain.state:
		S.WAKING:
			_waking(brain)
		S.GUARD:
			_guard_frame(brain, delta)
		S.ROOF:
			_roof_idle()
		S.STUNNED:
			_stunned(brain.state_progress())
		S.REEL:
			_reeling(brain.state_progress())
		S.TRANSFORM:
			_transforming(brain.state_progress())
		S.ATTACK:
			match brain.attack:
				A.DASH:
					_dash(t, brain.landed, GeneralBrain.glint_at(A.DASH, brain.phase), brain)
				A.FEINT:
					_feint(t, brain)
				A.CLOSE:
					_close(t)
				A.LEAP_UP:
					_leap_up(t)
				A.VOLLEY:
					_volley(t)
				A.LEAP_DOWN:
					_leap_down(t)
	_parry_frame(delta)
	_secondary(delta)
	_look(guard, delta)
	pose.glint = glint
	return pose


## A hit glanced off the blade from [param direction] (body space): the
## blade flicks toward it.
func parry(direction: Vector3) -> void:
	_parry_dir = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	_parry.kick(9.0)


## The guard fled, he stands on his stand again: springs at rest.
func reset() -> void:
	_settle_springs()


func _settle_springs() -> void:
	for spring: Spring in [_look_yaw, _look_pitch, _twist, _parry, _dip]:
		spring.reset(0.0)
	for pair: Array in _sode:
		for spring: Spring in pair:
			spring.reset(0.0)
	for spring: Spring in _kusazuri:
		spring.reset(0.0)
	_hip_before = Vector3.ZERO
	_grip_before = Vector3.ZERO


func _reset_pose() -> void:
	var p := pose
	p.pelvis = GeneralRig.PELVIS_REST
	p.pelvis_turn = Vector3.ZERO
	p.legs_ik = 1.0
	p.foot_pitch = [0.0, 0.0]
	p.torso = Vector3.ZERO
	p.head = Vector3.ZERO
	p.sword_roll = 0.0
	p.sword_shown = true
	p.hands_on = [1.0, 1.0]
	p.hand_free = [HAND_REST_L + Vector3(0.0, 1.428, 0.0), HAND_REST_R + Vector3(0.0, 1.428, 0.0)]
	p.hand_basis = [Basis.IDENTITY, Basis.IDENTITY]
	p.elbow_pole = [Vector3.ZERO, Vector3.ZERO]
	p.bow_in_hand = false
	p.bow_drawn = 0.0
	p.arrow_in_hand = false
	p.assembly = 1.0
	p.eyes = 0.0
	p.glint = 0.0
	p.arrow_glow = 0.0
	p.shiver = 0.0
	_frame(CHUDAN_GRIP, CHUDAN_DIR)


# --- the sword's frame ------------------------------------------------------------

## Sets the sword's frame from torso space: [param grip] (the right fist's
## point) and [param dir] (pommel -> point).
func _frame(grip: Vector3, dir: Vector3) -> void:
	var torso := rig.torso_xform(pose)
	pose.sword_grip = torso * grip
	pose.sword_dir = (torso.basis * dir).normalized()


## The frame between [param a] and [param b] (grip, dir pairs) at [param k].
func _frame_between(grip_a: Vector3, dir_a: Vector3, grip_b: Vector3, dir_b: Vector3, k: float) -> void:
	var w := clampf(k, 0.0, 1.0)
	_frame(grip_a.lerp(grip_b, w), dir_a.normalized().slerp(dir_b.normalized(), w))


## The frame in body space straight (the scabbard's, the draw's).
func _frame_body(grip: Vector3, dir: Vector3) -> void:
	pose.sword_grip = grip
	pose.sword_dir = dir.normalized()


## The sheathed frame for the pelvis as posed (the saya moves with it),
## pulled back [param pull] m along the saya's line.
func _sheathed(pull: float = 0.0) -> void:
	var pelvis := GeneralRig.pelvis_xform(pose) * GeneralRig.pelvis_xform(GeneralRig.Pose.new()).affine_inverse()
	_frame_body(pelvis * (rig.sheathed_grip() + rig.saya_axis * pull), pelvis.basis * rig.sheathed_dir())


# --- the stance -------------------------------------------------------------------

func _stance(brain: GeneralBrain, feet: GeneralFootwork, body: Transform3D, delta: float) -> void:
	var inverse := body.affine_inverse()
	for foot in 2:
		pose.feet[foot] = inverse * feet.foot(foot)
		var w := feet.swing(foot)
		pose.foot_pitch[foot] = 0.25 * sin(PI * w)
	pose.legs_ik = 1.0
	# the knees bent; a sliding foot dips the hips a little toward the
	# standing one
	var dip_to := 0.0
	var shift := 0.0
	for foot in 2:
		if not feet.standing(foot):
			dip_to = 0.025
			shift = (1.0 if foot == 0 else -1.0) * 0.03
	var dip := _dip.step(dip_to, delta)
	_breath += delta
	var breath := 0.006 * sin(_breath * TAU * 0.28)
	pose.pelvis = GeneralRig.PELVIS_REST + Vector3(shift, -STANCE_DROP - dip + breath, 0.0)
	if feet.carried:
		pose.pelvis.y -= 0.04
	# the torso turns toward the guard a moment late (the body's yaw is the
	# node's; this is the lag and the lean)
	var twist_to := clampf(_bearing_of(guard) * TWIST, -TWIST_MAX, TWIST_MAX)
	if brain.state == S.ATTACK or brain.state == S.ROOF or brain.state == S.STUNNED:
		twist_to *= 0.3
	pose.torso.y += _twist.step(twist_to, delta)
	if brain.advancing:
		pose.torso.x -= 0.08


func _guard_frame(brain: GeneralBrain, _delta: float) -> void:
	# chudan, the blade breathing with him
	var bob := Vector3(0.0, 0.008 * sin(_breath * TAU * 0.28), 0.006 * sin(_breath * TAU * 0.28 + 1.0))
	_frame(CHUDAN_GRIP + bob, CHUDAN_DIR)
	if brain.wanted_speed() > 0.5:
		pose.torso.x -= 0.05


func _roof_idle() -> void:
	# standing on the eave: the sword sheathed, the bow in the left fist at
	# rest, the right hand free, watching the guard below
	_sheathed()
	pose.hands_on = [0.0, 0.0]
	pose.bow_in_hand = true
	pose.bow_aim = (aim + Vector3.DOWN * 0.1).normalized()
	var shoulder := rig.shoulder_at(pose, 0)
	pose.hand_free[0] = shoulder + Vector3(-0.1, -0.52, -0.2)
	pose.hand_basis[0] = _bow_hand_basis(pose.bow_aim)
	pose.hand_free[1] = rig.torso_xform(pose) * HAND_REST_R
	pose.torso.x -= 0.1


# --- the attacks -------------------------------------------------------------------

## The dash cut at clip time [param t]; [param landed] picks the recovery.
func _dash(t: float, landed: bool, glint_at: float, brain: GeneralBrain) -> void:
	var clip: MotionClip = _clips[A.DASH]
	if t < 1.0:
		var raise := clip.sample(&"raise", t)
		_frame_between(CHUDAN_GRIP, CHUDAN_DIR, JODAN_GRIP, JODAN_DIR, raise)
		pose.pelvis += Vector3(0.0, -0.1 * clip.sample(&"coil", t), 0.12 * clip.sample(&"coil", t) - 0.14 * clip.sample(&"drive", t))
		pose.torso.x += -0.1 * clip.sample(&"coil", t) - 0.25 * clip.sample(&"drive", t)
		pose.head.x += 0.1 * raise
		# the glint, from its moment on (the phase's), pulsing
		var since := brain.stage_time() - glint_at
		if since >= 0.0 and brain.stage == GeneralBrain.Stage.TELEGRAPH:
			glint = clampf(since / 0.1, 0.0, 1.0) * (0.75 + 0.25 * sin(since * 28.0))
	elif t < 2.0:
		_lunge(clip, t)
	elif landed:
		_chiburi(_dash_hit, t)
	else:
		_stumble(_dash_miss, t)


## The lunge (1..2): the body low and forward, the blade thrust then swept
## across, the torso turning with the cut.
func _lunge(clip: MotionClip, t: float) -> void:
	var thrust := clip.sample(&"thrust", t)
	var sweep := clip.sample(&"sweep", t)
	if sweep <= 0.0:
		_frame_between(JODAN_GRIP, JODAN_DIR, THRUST_GRIP, THRUST_DIR, thrust)
	else:
		_frame_between(CUT_START_GRIP, CUT_START_DIR, CUT_END_GRIP, CUT_END_DIR, sweep)
	var low := clip.sample(&"lunge", t)
	pose.pelvis += Vector3(0.0, -0.16 * low, -0.2 * low)
	pose.torso.x += -0.35 * low
	pose.torso.y += 0.55 * sweep
	pose.head.y -= 0.3 * sweep
	# the legs stretch into the lunge: the rear foot trails
	pose.feet[0] += Vector3(0.0, 0.08 * low, 0.35 * low)
	pose.foot_pitch[0] += 0.6 * low
	for side in 2:
		pose.sode[side] += Vector2(-0.5 * low, 0.2 * low)


## A miss (2..3): the stumble - over-committed, the blade low to the left,
## the back to the guard; then up to chudan.
func _stumble(clip: MotionClip, t: float) -> void:
	var drop := clip.sample(&"drop", t)
	var settle := clip.sample(&"settle", t)
	if settle <= 0.0:
		_frame_between(CUT_END_GRIP, CUT_END_DIR, LOW_LEFT_GRIP, LOW_LEFT_DIR, drop)
	else:
		_frame_between(LOW_LEFT_GRIP, LOW_LEFT_DIR, CHUDAN_GRIP, CHUDAN_DIR, settle)
	var lean := clip.sample(&"lean", t)
	pose.torso.x += -0.45 * lean
	pose.torso.y += 0.5 * lean
	pose.torso.z += 0.15 * lean
	pose.pelvis.y -= 0.1 * lean
	pose.head.x += -0.3 * lean


## A hit (2..3): chiburi - the blade flicked out to the right, zanshin, back
## to chudan.
func _chiburi(clip: MotionClip, t: float) -> void:
	var flick := clip.sample(&"flick", t)
	var settle := clip.sample(&"settle", t)
	if settle <= 0.0:
		_frame_between(CUT_END_GRIP, CUT_END_DIR, CHIBURI_GRIP, CHIBURI_DIR, flick)
	else:
		_frame_between(CHIBURI_GRIP, CHIBURI_DIR, CHUDAN_GRIP, CHUDAN_DIR, settle)
	pose.torso.y += 0.3 * flick * (1.0 - settle)
	pose.torso.x += 0.05 * flick


## The feint: the whirl hides him (compact), the sidestep, then the dash.
func _feint(t: float, brain: GeneralBrain) -> void:
	var clip: MotionClip = _clips[A.FEINT]
	if t < 1.0:
		var hide := clip.sample(&"hide", t)
		var raise := clip.sample(&"raise", t)
		if raise <= 0.0:
			_frame_between(CHUDAN_GRIP, CHUDAN_DIR, HASSO_GRIP, HASSO_DIR, hide)
		else:
			_frame_between(HASSO_GRIP, HASSO_DIR, JODAN_GRIP, JODAN_DIR, raise)
		pose.pelvis.y -= 0.1 * hide + 0.08 * clip.sample(&"coil", t)
		pose.torso.x += -0.2 * hide - 0.2 * clip.sample(&"drive", t)
		var since := brain.stage_time() - GeneralBrain.FEINT_GLINT_AT
		if since >= 0.0 and brain.stage == GeneralBrain.Stage.TELEGRAPH:
			glint = clampf(since / 0.1, 0.0, 1.0) * (0.75 + 0.25 * sin(since * 28.0))
	elif t < 2.0:
		_lunge(_clips[A.DASH], t)
	elif brain.landed:
		_chiburi(_dash_hit, t)
	else:
		_stumble(_dash_miss, t)


## The close cut: jodan, kesa-giri, back to chudan.
func _close(t: float) -> void:
	var clip: MotionClip = _clips[A.CLOSE]
	var raise := clip.sample(&"raise", t)
	var cut := clip.sample(&"cut", t)
	var settle := clip.sample(&"settle", t)
	if cut <= 0.0:
		_frame_between(CHUDAN_GRIP, CHUDAN_DIR, JODAN_GRIP, JODAN_DIR, raise)
	elif settle <= 0.0:
		_frame_between(JODAN_GRIP, JODAN_DIR, KESA_GRIP, KESA_DIR, cut)
	else:
		_frame_between(KESA_GRIP, KESA_DIR, CHUDAN_GRIP, CHUDAN_DIR, settle)
	var step := clip.sample(&"step", t)
	pose.pelvis += Vector3(0.0, -0.06 * raise - 0.08 * step, 0.05 * raise - 0.14 * step)
	pose.torso.x += 0.06 * raise - 0.32 * step
	pose.torso.y += 0.25 * cut * (1.0 - settle)
	pose.head.x += 0.12 * raise - 0.1 * step
	# the right foot slides forward into the cut
	pose.feet[1] += Vector3(0.0, 0.0, -0.3 * step)


## The leap onto the eave (telegraph: the crouch then the flight; the
## strike: the landing; the recovery: the sword sheathed, the bow taken).
func _leap_up(t: float) -> void:
	var clip: MotionClip = _clips[A.LEAP_UP]
	var crouch := clip.sample(&"crouch", t)
	var tuck := clip.sample(&"tuck", t)
	var absorb := clip.sample(&"absorb", t)
	var sheathe := clip.sample(&"sheathe", t)
	_frame_between(CHUDAN_GRIP, CHUDAN_DIR, HASSO_GRIP, HASSO_DIR, crouch)
	pose.pelvis += Vector3(0.0, -0.28 * crouch - 0.2 * absorb, 0.05 * crouch)
	pose.torso.x += -0.4 * crouch - 0.3 * absorb
	pose.head.x += 0.35 * crouch
	_tuck_legs(tuck)
	for side in 2:
		pose.sode[side] += Vector2(0.0, 0.5 * tuck)
	if sheathe > 0.0:
		_sheathe_and_take_bow(sheathe)


## The leap down (telegraph: the bow put away and the sword drawn fast in
## the crouch, then the flight with the blade high; the strike: the landing
## cut into the gravel; the recovery: up to chudan).
func _leap_down(t: float) -> void:
	var clip: MotionClip = _clips[A.LEAP_DOWN]
	var draw := clip.sample(&"draw", t)
	var crouch := clip.sample(&"crouch", t)
	var tuck := clip.sample(&"tuck", t)
	var cut := clip.sample(&"cut", t)
	var settle := clip.sample(&"settle", t)
	if draw < 1.0:
		# the bow back on the shoulder, the hands to the hilt, the blade out
		# and up in one pull
		pose.bow_in_hand = draw < 0.15
		pose.hands_on = [clampf((draw - 0.4) / 0.4, 0.0, 1.0), clampf(draw / 0.3, 0.0, 1.0)]
		var pull := clampf((draw - 0.3) / 0.7, 0.0, 1.0)
		var torso := rig.torso_xform(pose)
		var mouth := rig.sheathed_grip()
		var way := mouth.lerp(torso * JODAN_GRIP, pull) + Vector3(0.0, 0.0, -DRAW_BULGE) * sin(PI * pull)
		_frame_body(way, rig.sheathed_dir().slerp((torso.basis * JODAN_DIR).normalized(), pull))
		if pose.bow_in_hand:
			pose.bow_aim = aim
			pose.hand_basis[0] = _bow_hand_basis(aim)
		pose.hand_free[0] = torso * HAND_REST_L
	elif cut <= 0.0:
		_frame(JODAN_GRIP, JODAN_DIR)
	elif settle <= 0.0:
		_frame_between(JODAN_GRIP, JODAN_DIR, KESA_GRIP, KESA_DIR, cut)
	else:
		_frame_between(KESA_GRIP, KESA_DIR, CHUDAN_GRIP, CHUDAN_DIR, settle)
	pose.pelvis += Vector3(0.0, -0.25 * crouch - 0.25 * cut * (1.0 - settle), 0.0)
	pose.torso.x += -0.3 * crouch - 0.4 * cut * (1.0 - settle)
	_tuck_legs(tuck)


## The volley: the arrow nocked, the bow drawn to the cheek, the release.
func _volley(t: float) -> void:
	var clip: MotionClip = _clips[A.VOLLEY]
	_sheathed()
	pose.hands_on = [0.0, 0.0]
	pose.bow_in_hand = true
	pose.bow_aim = aim
	var torso := rig.torso_xform(pose)
	var reach := clip.sample(&"reach", t)
	var draw := clip.sample(&"draw", t)
	var lower := clip.sample(&"lower", t)
	pose.arrow_in_hand = clip.sample(&"arrow", t) > 0.5
	pose.arrow_glow = clip.sample(&"ember", t)
	# the archer turns his left side to the target
	pose.torso.y += 0.55 * reach * (1.0 - lower)
	torso = rig.torso_xform(pose)
	var shoulder_l := rig.shoulder_at(pose, 0)
	var rest_l := shoulder_l + Vector3(-0.1, -0.52, -0.2)
	var out := shoulder_l + aim * BOW_REACH + Vector3.UP * 0.05
	pose.hand_free[0] = rest_l.lerp(out, reach * (1.0 - 0.6 * lower))
	pose.hand_basis[0] = _bow_hand_basis(aim)
	# the right hand: to the quiver, to the string, back to the cheek, the
	# release flick
	var quiver := torso * QUIVER_REACH
	var string := out - aim * 0.25 + Vector3.DOWN * 0.05
	var cheek := rig.head_xform(pose) * CHEEK
	var nock := clip.sample(&"nock", t)
	var right := torso * HAND_REST_R
	if nock < 1.0:
		right = right.lerp(quiver, clampf(nock * 2.0, 0.0, 1.0)).lerp(string, clampf(nock * 2.0 - 1.0, 0.0, 1.0))
	else:
		right = string.lerp(cheek, draw) + Vector3(0.0, 0.0, 0.18) * clip.sample(&"flick", t)
	pose.hand_free[1] = right.lerp(torso * HAND_REST_R, lower)
	pose.bow_drawn = draw
	pose.head.y += 0.1 * reach


## The stun (progress [param u]): the blade drops, he shudders bent over,
## the head hangs; he gathers himself at the end.
func _stunned(u: float) -> void:
	var clip := _stun
	var reel := clip.sample(&"reel", u)
	_frame_between(CHUDAN_GRIP, CHUDAN_DIR, DROPPED_GRIP, DROPPED_DIR, reel)
	pose.pelvis.y -= 0.15 * reel
	pose.torso.x += -0.45 * reel + 0.04 * sin(time * 17.0) * reel
	pose.torso.z += 0.08 * sin(time * 13.0) * reel
	pose.head.x += -0.5 * reel
	pose.head.y += 0.25 * sin(time * 19.0) * clip.sample(&"shake", u)
	pose.shiver = 0.014 * reel
	pose.feet[0].x -= 0.08 * reel
	pose.feet[1].x += 0.08 * reel


## The reel after a fist (progress [param u]): staggering back, the blade
## flung up, then chudan again.
func _reeling(u: float) -> void:
	var clip := _reel
	var back := clip.sample(&"back", u)
	_frame_between(DROPPED_GRIP, DROPPED_DIR, HASSO_GRIP, HASSO_DIR, clip.sample(&"fling", u))
	if clip.sample(&"settle", u) > 0.0:
		_frame_between(HASSO_GRIP, HASSO_DIR, CHUDAN_GRIP, CHUDAN_DIR, clip.sample(&"settle", u))
	pose.torso.x += 0.35 * back
	pose.head.x += 0.4 * back
	pose.pelvis += Vector3(0.0, -0.05 * back, 0.12 * back)


## The transformation (progress [param u]): jodan, the blade planted before
## him, the bowed hold (the gust, the petals), the draw back to chudan.
func _transforming(u: float) -> void:
	var clip := _transform
	var raise := clip.sample(&"raise", u)
	var plant := clip.sample(&"plant", u)
	var rise := clip.sample(&"rise", u)
	if plant <= 0.0:
		_frame_between(CHUDAN_GRIP, CHUDAN_DIR, JODAN_GRIP, JODAN_DIR, raise)
	elif rise <= 0.0:
		_frame_between(JODAN_GRIP, JODAN_DIR, PLANTED_GRIP, PLANTED_DIR, plant)
	else:
		_frame_between(PLANTED_GRIP, PLANTED_DIR, CHUDAN_GRIP, CHUDAN_DIR, rise)
	var bow := clip.sample(&"bow", u)
	pose.pelvis.y -= 0.12 * bow
	pose.torso.x += -0.3 * bow
	pose.head.x += -0.45 * bow
	pose.pelvis.y -= 0.06 * raise * (1.0 - plant)


## The waking: the armour assembles (the rig's), then the draw.
func _waking(brain: GeneralBrain) -> void:
	pose.assembly = brain.assemble_progress()
	var u := brain.draw_progress()
	pose.legs_ik = 1.0 if pose.assembly > 0.3 else 0.0
	# the eyes catch as the helmet lands, flickering
	var lit := clampf((pose.assembly - 0.9) / 0.1, 0.0, 1.0)
	_eye_flicker = fposmod(_eye_flicker + 0.37, 1.0)
	pose.eyes = 1.0 if pose.assembly >= 1.0 else lit * (0.4 + 0.6 * float(_eye_flicker > 0.4))
	if u <= 0.0:
		_hanging_arms()
		return
	var clip := _draw
	var reach := clip.sample(&"reach", u)
	var pull := clip.sample(&"pull", u)
	var swing := clip.sample(&"swing", u)
	var join := clip.sample(&"join", u)
	var torso := rig.torso_xform(pose)
	# the right hand across the body to the hilt in the scabbard, the left
	# to the scabbard's mouth
	pose.hands_on = [join, reach]
	pose.hand_free[1] = torso * HAND_REST_R
	var mouth := rig.sheathed_grip()
	pose.hand_free[0] = mouth + rig.saya_axis * (0.25 + SAYA_PULL * pull) + Vector3(-0.06, 0.0, 0.0)
	if swing <= 0.0:
		# the pull: the hilt up and forward on its arc, the saya drawn back
		var way := mouth.lerp(torso * JODAN_GRIP, pull) + Vector3(0.0, 0.0, -DRAW_BULGE) * sin(PI * pull)
		_frame_body(way, rig.sheathed_dir().slerp((torso.basis * JODAN_DIR).normalized(), pull))
	else:
		_frame_between(JODAN_GRIP, JODAN_DIR, CHUDAN_GRIP, CHUDAN_DIR, swing)
	pose.torso.y += 0.3 * pull * (1.0 - swing) - 0.1 * reach * (1.0 - pull)
	pose.torso.x += -0.1 * reach * (1.0 - pull)
	pose.pelvis.y -= 0.05 * pull * (1.0 - swing)
	pose.head.x += 0.2 * pull * (1.0 - swing)


## Asleep on the stand: the hanging pose.
func _hanging() -> void:
	pose.assembly = 0.0
	pose.legs_ik = 0.0
	_sheathed()
	_hanging_arms()
	pose.eyes = 0.0


func _hanging_arms() -> void:
	_sheathed()
	pose.hands_on = [0.0, 0.0]
	var torso := rig.torso_xform(pose)
	pose.hand_free = [torso * HAND_REST_L, torso * HAND_REST_R]


## The legs tucked up toward the hips (a leap's flight).
func _tuck_legs(tuck: float) -> void:
	if tuck <= 0.0:
		return
	for leg in 2:
		var hip := rig.hip_at(pose, leg)
		var tucked := hip + Vector3(0.0, -0.95 + TUCK, -0.15)
		pose.feet[leg] = pose.feet[leg].lerp(tucked, tuck)
		pose.foot_pitch[leg] += 0.7 * tuck


## The sword into its scabbard and the bow into the left fist (a leap up's
## recovery): [param k] 0..1.
func _sheathe_and_take_bow(k: float) -> void:
	var torso := rig.torso_xform(pose)
	var sheathed_grip := rig.sheathed_grip()
	var way := (torso * HASSO_GRIP).lerp(sheathed_grip, k)
	_frame_body(way, (torso.basis * HASSO_DIR).normalized().slerp(rig.sheathed_dir(), k))
	pose.hands_on = [clampf(1.0 - k * 2.5, 0.0, 1.0), clampf(1.0 - (k - 0.6) * 2.5, 0.0, 1.0)]
	pose.hand_free[1] = torso * HAND_REST_R
	pose.bow_in_hand = k > 0.5
	if pose.bow_in_hand:
		pose.bow_aim = (aim + Vector3.DOWN * 0.1).normalized()
		var shoulder := rig.shoulder_at(pose, 0)
		pose.hand_free[0] = shoulder + Vector3(-0.1, -0.52, -0.2)
		pose.hand_basis[0] = _bow_hand_basis(pose.bow_aim)
	else:
		pose.hand_free[0] = torso * HAND_REST_L


## How the left fist turns round the bow's grip aimed along [param dir]
## (body space): its bore along the bow's axis.
func _bow_hand_basis(dir: Vector3) -> Basis:
	var r1 := LimbIK.aim(Basis.IDENTITY, Vector3.BACK, dir)
	var bore := LimbIK.aim(Basis.IDENTITY, rig.blade_axis_rest, r1 * rig.bow_axis)
	return bore.orthonormalized()


# --- the parry, the secondary motion, the look ------------------------------------

func _parry_frame(delta: float) -> void:
	var flick := _parry.step(0.0, delta)
	if absf(flick) < 0.001 or _parry_dir.length_squared() < 0.001:
		return
	# the blade flicks toward where the hit came from
	var toward := -_parry_dir
	pose.sword_dir = pose.sword_dir.slerp((pose.sword_dir + toward * 0.6).normalized(), clampf(flick * 0.12, 0.0, 0.6))
	pose.sword_grip += toward * 0.04 * clampf(flick, 0.0, 1.0)


## The sode and the kusazuri on springs, kicked by the hips' and the hilt's
## motion; the front panel lifts with the thigh.
func _secondary(delta: float) -> void:
	var hip := pose.pelvis
	var hip_speed := (hip - _pelvis_before) / maxf(delta, 0.001) if delta > 0.0 else Vector3.ZERO
	var jolt := (hip_speed - _hip_before) if delta > 0.0 else Vector3.ZERO
	_hip_before = hip_speed
	_pelvis_before = hip
	var grip_speed := (pose.sword_grip - _grip_before).length() / maxf(delta, 0.001) if delta > 0.0 else 0.0
	_grip_before = pose.sword_grip
	var arm_kick := clampf(grip_speed - _grip_speed, -6.0, 6.0) * 0.04
	_grip_speed = grip_speed
	if delta > 0.0:
		for side in 2:
			var pair: Array = _sode[side]
			(pair[0] as Spring).kick(-jolt.z * 0.015 + arm_kick + hip_velocity.z * 0.0)
			(pair[1] as Spring).kick(absf(jolt.x) * 0.01 + absf(arm_kick) * 0.5)
			pose.sode[side] += Vector2((pair[0] as Spring).step(0.0, delta), (pair[1] as Spring).step(0.0, delta))
		# the skirt: the front panel rides up the thigh when a leg comes
		# forward, the others swing with the hips
		var thigh_lift := 0.0
		for leg in 2:
			var hip_at := rig.hip_at(pose, leg)
			var to_foot := pose.feet[leg] - hip_at
			thigh_lift = maxf(thigh_lift, clampf(atan2(-to_foot.z, -to_foot.y) - 0.15, 0.0, 1.2))
		var kicks: Array[float] = [-jolt.z * 0.012, jolt.z * 0.012, -jolt.x * 0.012, jolt.x * 0.012]
		for panel in 4:
			var spring := _kusazuri[panel] as Spring
			spring.kick(kicks[panel])
			var target := thigh_lift * 0.8 if panel == 0 else 0.0
			pose.kusazuri[panel] += spring.step(target, delta)
	else:
		for panel in 4:
			pose.kusazuri[panel] += (_kusazuri[panel] as Spring).value
	# a slide swings the skirt a little
	for panel in 4:
		pose.kusazuri[panel] = clampf(pose.kusazuri[panel], -0.4, 1.2)


## The head turns to [param point] (springs: a moment late, a little past).
func _look(point: Vector3, delta: float) -> void:
	var torso := rig.torso_xform(pose)
	var neck := torso * (rig.rest["head"] as Transform3D).origin
	var local := torso.basis.inverse() * (point - neck)
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, maxf(Vector2(local.x, local.z).length(), 0.01))
	pose.head.y += _look_yaw.step(clampf(yaw, -NECK_YAW, NECK_YAW), delta)
	pose.head.x += _look_pitch.step(clampf(pitch, NECK_PITCH.x, NECK_PITCH.y), delta)


## Bearing of a body-space point from the hips (rad, + to his left).
func _bearing_of(point: Vector3) -> float:
	return atan2(-point.x, -point.z)


# --- the clips ---------------------------------------------------------------------

func _build_clips() -> void:
	var I := MotionClip.IN
	var O := MotionClip.OUT
	var IO := MotionClip.IN_OUT
	var BK := MotionClip.OUT_BACK
	var H := MotionClip.HOLD
	# the dash: the blade rises to jodan and he coils back (the hips sink),
	# the glint comes (the node's moment); at 0.85 the hips drive forward; the
	# lunge: the thrust ahead (1.0-1.3), the horizontal cut across (1.3-1.9),
	# the body low (1.0-1.6) and rising
	var dash := MotionClip.new()
	dash.key(&"raise", 0.0, 0.0).key(&"raise", 0.4, 1.0, IO).key(&"raise", 1.0, 1.0)
	dash.key(&"coil", 0.0, 0.0).key(&"coil", 0.5, 1.0, IO).key(&"coil", 0.85, 1.0).key(&"coil", 1.0, 0.0, I)
	dash.key(&"drive", 0.0, 0.0).key(&"drive", 0.85, 0.0, H).key(&"drive", 1.0, 1.0, I)
	dash.key(&"thrust", 1.0, 0.0).key(&"thrust", 1.3, 1.0, O)
	dash.key(&"sweep", 1.0, 0.0).key(&"sweep", 1.3, 0.0, H).key(&"sweep", 1.9, 1.0, I)
	dash.key(&"lunge", 1.0, 0.0).key(&"lunge", 1.15, 1.0, O).key(&"lunge", 1.6, 1.0).key(&"lunge", 2.0, 0.6, IO)
	_clips[A.DASH] = dash
	# a miss: the stumble (2.0-2.35), the blade low; up to chudan (2.5-3.0)
	_dash_miss = MotionClip.new()
	_dash_miss.key(&"drop", 2.0, 0.0).key(&"drop", 2.35, 1.0, O)
	_dash_miss.key(&"lean", 2.0, 0.6).key(&"lean", 2.3, 1.0, BK).key(&"lean", 2.55, 1.0).key(&"lean", 3.0, 0.0, IO)
	_dash_miss.key(&"settle", 2.0, 0.0).key(&"settle", 2.5, 0.0, H).key(&"settle", 3.0, 1.0, IO)
	# a hit: the chiburi flick (2.0-2.3), zanshin, chudan (2.55-3.0)
	_dash_hit = MotionClip.new()
	_dash_hit.key(&"flick", 2.0, 0.0).key(&"flick", 2.3, 1.0, BK)
	_dash_hit.key(&"settle", 2.0, 0.0).key(&"settle", 2.55, 0.0, H).key(&"settle", 3.0, 1.0, IO)
	# the feint: the whirl hides him in a compact hasso (0-0.3), the sidestep
	# (the node, 0.3-0.5), jodan (0.35-0.7), the coil and the drive
	var feint := MotionClip.new()
	feint.key(&"hide", 0.0, 0.0).key(&"hide", 0.1, 1.0, O).key(&"hide", 0.25, 1.0).key(&"hide", 0.45, 0.0, IO)
	feint.key(&"raise", 0.0, 0.0).key(&"raise", 0.25, 0.0, H).key(&"raise", 0.6, 1.0, IO).key(&"raise", 1.0, 1.0)
	feint.key(&"coil", 0.0, 0.0).key(&"coil", 0.45, 0.0, H).key(&"coil", 0.75, 1.0, IO).key(&"coil", 1.0, 0.0, I)
	feint.key(&"drive", 0.0, 0.0).key(&"drive", 0.85, 0.0, H).key(&"drive", 1.0, 1.0, I)
	_clips[A.FEINT] = feint
	# the close cut: jodan (0-0.55), held; the step and kesa-giri (1.0-1.6);
	# chudan (2.0-2.9)
	var close := MotionClip.new()
	close.key(&"raise", 0.0, 0.0).key(&"raise", 0.55, 1.0, IO).key(&"raise", 1.0, 1.0).key(&"raise", 1.3, 0.0, I)
	close.key(&"cut", 1.0, 0.0).key(&"cut", 1.6, 1.0, I).key(&"cut", 2.0, 1.0)
	close.key(&"step", 1.0, 0.0).key(&"step", 1.4, 1.0, O).key(&"step", 2.0, 1.0).key(&"step", 2.9, 0.0, IO)
	close.key(&"settle", 2.0, 0.0).key(&"settle", 2.9, 1.0, IO)
	_clips[A.CLOSE] = close
	# the leap up (telegraph 1.4 s: the crouch to 0.357, the flight after):
	# the crouch, the legs tucked in flight, the landing's absorb (1.0-1.3),
	# the sword sheathed and the bow taken (2.0-2.9)
	var up := MotionClip.new()
	up.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.3, 1.0, IO).key(&"crouch", 0.357, 1.0).key(&"crouch", 0.5, 0.0, O)
	up.key(&"tuck", 0.0, 0.0).key(&"tuck", 0.357, 0.0, H).key(&"tuck", 0.55, 1.0, IO).key(&"tuck", 0.85, 1.0).key(&"tuck", 1.0, 0.0, I)
	up.key(&"absorb", 1.0, 0.0).key(&"absorb", 1.3, 1.0, O).key(&"absorb", 2.0, 1.0).key(&"absorb", 2.4, 0.0, IO)
	up.key(&"sheathe", 2.0, 0.0).key(&"sheathe", 2.1, 0.0, H).key(&"sheathe", 2.9, 1.0, IO)
	_clips[A.LEAP_UP] = up
	# the leap down (telegraph 1.4 s): the bow away and the fast draw in the
	# crouch (0-0.33), the flight tucked, the landing cut (1.0-2.0), chudan
	var down := MotionClip.new()
	down.key(&"draw", 0.0, 0.0).key(&"draw", 0.33, 1.0, IO)
	down.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.3, 1.0, IO).key(&"crouch", 0.357, 1.0).key(&"crouch", 0.5, 0.0, O)
	down.key(&"tuck", 0.0, 0.0).key(&"tuck", 0.357, 0.0, H).key(&"tuck", 0.55, 0.7, IO).key(&"tuck", 0.85, 0.5).key(&"tuck", 1.0, 0.0, I)
	down.key(&"cut", 1.0, 0.0).key(&"cut", 2.0, 1.0, I)
	down.key(&"settle", 2.0, 0.0).key(&"settle", 3.0, 1.0, IO)
	_clips[A.LEAP_DOWN] = down
	# the volley: the right hand to the quiver and the string (0-0.3), the
	# bow arm out (0-0.4), the draw to the cheek (0.3-0.9), held; the release
	# at 1.0 (the arrow gone, the hand flicks back), the bow lowered (2.0-3.0)
	var volley := MotionClip.new()
	volley.key(&"nock", 0.0, 0.0).key(&"nock", 0.3, 1.0, IO)
	volley.key(&"arrow", 0.0, 0.0).key(&"arrow", 0.12, 0.0, H).key(&"arrow", 0.13, 1.0, H).key(&"arrow", 1.0, 1.0).key(&"arrow", 1.01, 0.0, H)
	volley.key(&"ember", 0.0, 0.0).key(&"ember", 0.3, 0.0, H).key(&"ember", 0.9, 1.2, I).key(&"ember", 1.0, 1.2).key(&"ember", 1.05, 0.0, O)
	volley.key(&"reach", 0.0, 0.0).key(&"reach", 0.4, 1.0, IO).key(&"reach", 2.0, 1.0).key(&"reach", 3.0, 0.0, IO)
	volley.key(&"draw", 0.0, 0.0).key(&"draw", 0.3, 0.0, H).key(&"draw", 0.9, 1.0, IO).key(&"draw", 1.0, 1.0).key(&"draw", 1.08, 0.0, O)
	volley.key(&"flick", 0.0, 0.0).key(&"flick", 1.0, 0.0, H).key(&"flick", 1.15, 1.0, O).key(&"flick", 1.6, 0.0, IO)
	volley.key(&"lower", 0.0, 0.0).key(&"lower", 2.0, 0.0, H).key(&"lower", 3.0, 1.0, IO)
	_clips[A.VOLLEY] = volley
	# the stun (progress): he reels in, hangs, gathers himself
	_stun = MotionClip.new()
	_stun.key(&"reel", 0.0, 0.0).key(&"reel", 0.1, 1.0, O).key(&"reel", 0.85, 1.0).key(&"reel", 1.0, 0.0, IO)
	_stun.key(&"shake", 0.0, 0.0).key(&"shake", 0.05, 1.0, O).key(&"shake", 0.35, 0.0, IO).key(&"shake", 0.8, 0.0, H).key(&"shake", 0.9, 1.0, IO).key(&"shake", 1.0, 0.0, IO)
	# the reel after a fist (progress): back, the blade flung up, chudan
	_reel = MotionClip.new()
	_reel.key(&"back", 0.0, 0.0).key(&"back", 0.2, 1.0, O).key(&"back", 0.55, 0.8).key(&"back", 1.0, 0.0, IO)
	_reel.key(&"fling", 0.0, 0.0).key(&"fling", 0.3, 1.0, BK)
	_reel.key(&"settle", 0.0, 0.0).key(&"settle", 0.5, 0.0, H).key(&"settle", 1.0, 1.0, IO)
	# the transformation (progress): jodan (0-0.3), planted (0.3-0.45), the
	# bowed hold (the gust at 0.5), drawn back up (0.8-1.0)
	_transform = MotionClip.new()
	_transform.key(&"raise", 0.0, 0.0).key(&"raise", 0.3, 1.0, IO)
	_transform.key(&"plant", 0.0, 0.0).key(&"plant", 0.3, 0.0, H).key(&"plant", 0.45, 1.0, I)
	_transform.key(&"bow", 0.0, 0.0).key(&"bow", 0.45, 0.0, H).key(&"bow", 0.6, 1.0, O).key(&"bow", 0.8, 1.0).key(&"bow", 1.0, 0.0, IO)
	_transform.key(&"rise", 0.0, 0.0).key(&"rise", 0.8, 0.0, H).key(&"rise", 1.0, 1.0, IO)
	# the draw (the waking's second part, progress): the right hand across
	# to the hilt (0-0.3), the pull up and forward with the saya drawn back
	# (0.3-0.7), the swing from jodan down to chudan (0.7-1.0), the left hand
	# joining (0.8-1.0)
	_draw = MotionClip.new()
	_draw.key(&"reach", 0.0, 0.0).key(&"reach", 0.3, 1.0, IO)
	_draw.key(&"pull", 0.0, 0.0).key(&"pull", 0.3, 0.0, H).key(&"pull", 0.7, 1.0, IO)
	_draw.key(&"swing", 0.0, 0.0).key(&"swing", 0.7, 0.0, H).key(&"swing", 1.0, 1.0, IO)
	_draw.key(&"join", 0.0, 0.0).key(&"join", 0.8, 0.0, H).key(&"join", 1.0, 1.0, IO)
