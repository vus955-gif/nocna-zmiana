class_name ColossusMoves
extends RefCounted
## The Colossus's choreography: from the brain's state and the fight's
## points (set by the Colossus each frame, body space) it composes the
## Pose its rig shows. Every move is a MotionClip sampled at the brain's
## clip_time() (0..1 telegraph, 1..2 strike, 2..3 recovery) or at the
## state's progress, so a shorter telegraph keeps the same shape; the
## "where" comes from the points (the palm's shadow, the sweep's arc, the
## beam's aim) and the rig's IK. Secondary motion rides on springs: the
## head follows the guard a moment late and overshoots a little, the torso
## follows the head, the hips sink on a footfall, a slammed hand bounces
## off the floor. Principles (docs/superpowers/plans/2026-10-03-straznik-
## kolos.md): anticipation, ease in/out, overshoot and settle, the
## shoulders lead the arm, the stone breathes.

const S := ColossusBrain.State
const A := ColossusBrain.Attack
## The stand-up's two footfalls (s into it): stomps, dust, tremors.
const STAND_STOMPS: Array[float] = [2.1, 2.6]
## The stand-up's time when the throne cracks under the push.
const STAND_CRACK := 0.55
## Standing: the pelvis over the feet.
const STAND_HIPS := 5.02
## Where the stand-up leaves the feet (seated body space).
const STAND_FEET: Array[Vector3] = [Vector3(-0.55, ColossusRig.ANKLE_HEIGHT, -4.0), Vector3(0.55, ColossusRig.ANKLE_HEIGHT, -4.8)]
const STAND_PELVIS := Vector3(0.0, STAND_HIPS, -4.4)
## The phase shift's moment the plates fly off (progress).
const PLATES_AT := 0.4
## Radii of the low sweep: the elbow's and the hand's (m from the hips).
const SWEEP_ELBOW := 3.9
const SWEEP_HAND := 7.3
const SWEEP_HEIGHT := 0.35
## Head limits on the torso (rad).
const HEAD_YAW := 0.65
const HEAD_PITCH := Vector2(-0.75, 0.35)
## Seated torso twist toward the guard (rad).
const TWIST := 0.45

var rig: ColossusRig
var pose := ColossusRig.Pose.new()

# --- the fight's points, body space (set by the Colossus) -----------------------
## The guard's chest.
var guard := Vector3(0.0, 1.6, -12.0)
## Where the palm comes down (on the floor).
var slam_point := Vector3(0.0, 0.0, -8.0)
## Which arm attacks: 1 = its left, -1 = its right.
var side: int = 1
## Where the eyes look while the beam charges and burns.
var beam_point := Vector3(0.0, 1.0, -12.0)
## The throne opening the swarm comes out of.
var swarm_point := Vector3(-2.2, 0.6, -0.9)
## Standing: the planted ankles and the walk (ColossusGait).
var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var swing_foot: int = -1
var swing: float = 0.0
## Standing: each foot's yaw relative to the body (planted feet keep theirs
## while he turns).
var feet_yaw: Array[float] = [0.0, 0.0]

## Where the low sweep's hand passes now (rad) and whether it is down.
var sweep_bearing: float = 0.0
var sweep_low := false
## The slam's hand: where it is aimed now (body space).
var slam_hand := Vector3.ZERO

var time: float = 0.0

var _clips: Dictionary = {}
var _shift: MotionClip
var _stand: MotionClip
var _wake: MotionClip
var _look_yaw := Spring.new(0.9, 0.55)
var _look_pitch := Spring.new(0.9, 0.65)
var _twist := Spring.new(0.55, 0.85)
var _sink := Spring.new(1.5, 0.35)
var _bounce := Spring.new(3.2, 0.3)
var _neutral_hand: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _neutral_elbow: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _delta: float = 0.0


func _init(for_rig: ColossusRig) -> void:
	rig = for_rig
	for i in 2:
		feet[i] = Vector3(STAND_FEET[i].x, ColossusRig.ANKLE_HEIGHT, STAND_FEET[i].z - STAND_PELVIS.z)
	_build_clips()


## The pose for [param brain]'s moment, advanced by [param delta].
func compose(brain: ColossusBrain, delta: float) -> ColossusRig.Pose:
	time += delta
	_delta = delta
	_reset_pose()
	var standing := brain.standing
	if brain.state == S.DORMANT:
		_look_yaw.reset(0.0)
		_look_pitch.reset(0.0)
		_twist.reset(0.0)
		return pose   # the museum piece, exactly
	pose.eyes = 1.0
	if brain.phase >= 2 and brain.state != S.PHASE_SHIFT:
		pose.cracks = 1.0 + 0.2 * sin(time * 2.3)
	if standing:
		_stand_still(delta)
	else:
		_sit(delta)
	var look_at := guard
	var twist_to := clampf(_bearing_of(guard) * 0.5, -TWIST, TWIST) if not standing else clampf(_bearing_of(guard) * 0.3, -0.25, 0.25)
	match brain.state:
		S.WAKING:
			_waking(brain.state_progress())
			twist_to *= _wake.sample(&"twist", brain.state_progress())
		S.PHASE_SHIFT:
			_phase_shift(brain.state_progress())
		S.STAND_UP:
			_stand_up(brain.state_time())
		S.ATTACK:
			var t := brain.clip_time()
			match brain.attack:
				A.SLAM:
					_slam(t)
					if t < 2.2:
						look_at = slam_point
						twist_to = clampf(_bearing_of(slam_point) * 0.6, -0.5, 0.5) * _clips[A.SLAM].sample(&"lead", t)
				A.SWEEP:
					_sweep(t)
					twist_to = clampf(sweep_bearing * 0.4, -0.55, 0.55)
				A.BEAM, A.BEAM_SWEEP:
					_beam(brain.attack, t)
					look_at = beam_point
					if brain.attack == A.BEAM_SWEEP:
						twist_to = clampf(_bearing_of(beam_point) * 0.5, -0.5, 0.5)
				A.SWARM:
					_swarm(t)
					if t < 1.3:
						look_at = swarm_point + Vector3.UP
	pose.torso.y += _twist.step(twist_to, delta)
	_look(look_at, delta, brain.state == S.WAKING and brain.state_progress() < 0.25)
	return pose


## How fast the torso turns on the hips now (rad/s): the throne grinds.
func twist_speed() -> float:
	return absf(_twist.velocity)


## The palm hit the floor: it bounces a little and settles.
func impact() -> void:
	_bounce.kick(1.6)


## A foot came down: the hips sink and come back.
func footfall() -> void:
	_sink.kick(-0.9)


## The guard fled, it sits again: springs at rest.
func reset() -> void:
	_look_yaw.reset(0.0)
	_look_pitch.reset(0.0)
	_twist.reset(0.0)
	_sink.reset(0.0)
	_bounce.reset(0.0)
	swing_foot = -1
	swing = 0.0
	feet_yaw = [0.0, 0.0]
	for i in 2:
		feet[i] = Vector3(STAND_FEET[i].x, ColossusRig.ANKLE_HEIGHT, STAND_FEET[i].z - STAND_PELVIS.z)


# --- bases --------------------------------------------------------------------

func _reset_pose() -> void:
	var p := pose
	p.pelvis = Vector3(0.0, 3.3, 0.0)
	p.pelvis_turn = Vector3.ZERO
	p.torso = Vector3.ZERO
	p.head = Vector3.ZERO
	for i in 2:
		p.arm_aim[i] = 0.0
		p.wrist[i] = 0.0
		p.shrug[i] = 0.0
		p.arm_glow[i] = 0.0
		p.foot_yaw[i] = 0.0
		p.ankle[i] = rig.rest_point("foot_" + ("l" if i == 0 else "r"))
	p.legs_ik = 0.0
	p.eyes = 0.0
	p.charge = 0.0
	p.cracks = 0.0
	p.seams = 1.0
	p.shiver = 0.0


## Seated between moves: hands on the knees, breathing stone.
func _sit(_delta: float) -> void:
	var breath := sin(time * 0.9)
	pose.torso.x = 0.008 * breath
	for i in 2:
		pose.shrug[i] = 0.025 * sin(time * 0.9 + 0.4)
		_neutral_hand[i] = rig.rest_hand(i)
		_neutral_elbow[i] = rig.rest_elbow(i)
		pose.elbow[i] = _neutral_elbow[i]
		pose.hand[i] = _neutral_hand[i]


## Standing (phase 3): over its planted feet, arms hanging, the walk's sway.
func _stand_still(delta: float) -> void:
	var sink := _sink.step(0.0, delta)
	var lift := 0.1 * sin(PI * swing) if swing_foot >= 0 else 0.0
	pose.pelvis = Vector3(0.0, STAND_HIPS + lift + sink * 0.18, 0.0)
	# the hips roll over the foot that stands
	var stance := 1.0 if swing_foot == 0 else (-1.0 if swing_foot == 1 else 0.0)
	pose.pelvis_turn = Vector3(0.0, 0.0, 0.035 * stance * sin(PI * swing))
	pose.torso.x = 0.006 * sin(time * 0.9)
	pose.torso.z = -pose.pelvis_turn.z * 0.6
	pose.legs_ik = 1.0
	for i in 2:
		pose.ankle[i] = feet[i]
		pose.foot_yaw[i] = feet_yaw[i]
		if swing_foot == i:
			pose.ankle[i] += Vector3.UP * ColossusGait.LIFT * sin(PI * swing)
	# arms hang and swing against the legs
	for i in 2:
		var shoulder := rig.shoulder_at(pose, i)
		var out := Vector3(-0.25 if i == 0 else 0.25, 0.0, 0.0)
		var swing_arm := 0.0
		if swing_foot >= 0:
			swing_arm = 0.55 * sin(PI * swing) * (1.0 if swing_foot != i else -1.0)
		_neutral_elbow[i] = shoulder + out + Vector3(0.0, -1.45, 0.12 - swing_arm * 0.4)
		_neutral_hand[i] = _neutral_elbow[i] + Vector3(0.0, -1.2, -0.45 - swing_arm)
		pose.arm_aim[i] = 1.0
		pose.elbow[i] = _neutral_elbow[i]
		pose.hand[i] = _neutral_hand[i]
		pose.shrug[i] = 0.02 * sin(time * 0.9 + 0.4)


# --- the moves ------------------------------------------------------------------

func _waking(progress: float) -> void:
	var clip := _wake
	pose.eyes = clip.sample(&"eyes", progress)
	pose.charge = clip.sample(&"flare", progress)
	pose.shiver = clip.sample(&"shiver", progress)
	pose.torso.x += clip.sample(&"lean", progress)
	for i in 2:
		pose.shrug[i] += clip.sample(&"shrug", progress)


func _phase_shift(progress: float) -> void:
	var clip := _shift
	pose.torso.x += clip.sample(&"lean", progress)
	pose.head.x += clip.sample(&"head", progress)
	pose.cracks = clip.sample(&"cracks", progress)
	pose.shiver = clip.sample(&"shiver", progress)
	pose.charge = clip.sample(&"eyes", progress)
	var spread := clip.sample(&"spread", progress)
	if spread > 0.0:
		for i in 2:
			var shoulder := rig.shoulder_at(pose, i)
			var out := Vector3(-1.0 if i == 0 else 1.0, 0.0, 0.0)
			var open_elbow := shoulder + out * 1.3 + Vector3(0.0, -0.4, -0.4)
			var open_hand := open_elbow + out * 1.0 + Vector3(0.0, 0.5, -0.9)
			pose.arm_aim[i] = 1.0
			pose.elbow[i] = _neutral_elbow[i].lerp(open_elbow, spread)
			pose.hand[i] = _neutral_hand[i].lerp(open_hand, spread)
			pose.wrist[i] = 0.5 * spread


func _stand_up(seconds: float) -> void:
	var clip := _stand
	pose.pelvis = Vector3(0.0, clip.sample(&"hips_y", seconds), clip.sample(&"hips_z", seconds))
	pose.pelvis_turn = Vector3(clip.sample(&"hips_pitch", seconds), 0.0, 0.0)
	pose.torso.x = clip.sample(&"lean", seconds)
	pose.head.x += clip.sample(&"head", seconds)
	pose.shiver = clip.sample(&"shiver", seconds)
	pose.legs_ik = clip.sample(&"legs", seconds)
	for i in 2:
		var step := clip.sample(&"step_l" if i == 0 else &"step_r", seconds)
		var from := rig.rest_point("foot_" + ("l" if i == 0 else "r"))
		pose.ankle[i] = from.lerp(STAND_FEET[i], step) + Vector3.UP * 0.6 * sin(PI * step)
	# hands press on the thighs to push it up, then let go and hang
	var brace := clip.sample(&"brace", seconds)
	var release := clip.sample(&"release", seconds)
	for i in 2:
		var out := -1.0 if i == 0 else 1.0
		var shoulder := rig.shoulder_at(pose, i)
		var press_hand := pose.pelvis + Vector3(out * 0.62, 0.42, -1.3)
		var press_elbow := shoulder.lerp(press_hand, 0.5) + Vector3(out * 0.55, 0.2, 0.35)
		var hang_elbow := shoulder + Vector3(out * 0.25, -1.45, 0.12)
		var hang_hand := hang_elbow + Vector3(0.0, -1.2, -0.45)
		pose.arm_aim[i] = 1.0
		pose.elbow[i] = _neutral_elbow[i].lerp(press_elbow, brace).lerp(hang_elbow, release)
		pose.hand[i] = _neutral_hand[i].lerp(press_hand, brace).lerp(hang_hand, release)
		pose.shrug[i] = 0.18 * brace * (1.0 - release)


func _slam(t: float) -> void:
	var clip: MotionClip = _clips[A.SLAM]
	var arm := 0 if side > 0 else 1
	var other := 1 - arm
	pose.torso.x += clip.sample(&"lean", t)
	pose.seams = clip.sample(&"seams", t)
	var shoulder := rig.shoulder_at(pose, arm)
	var target := slam_point + Vector3.UP * 0.12
	var toward := Vector3(target.x - shoulder.x, 0.0, target.z - shoulder.z)
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
	var out := Vector3(-1.0 if arm == 0 else 1.0, 0.0, 0.0)
	var raised_hand := shoulder + Vector3.UP * 3.1 + toward * 0.3 + out * 0.6
	var raised_elbow := shoulder + Vector3.UP * 1.35 + toward * 0.15 + out * 0.95
	var strike_elbow := shoulder.lerp(target, 0.45) + Vector3.UP * 0.7 + out * 0.3
	var raise := clip.sample(&"raise", t)
	var fall := clip.sample(&"fall", t)
	var back := clip.sample(&"back", t)
	var hand: Vector3
	var elbow: Vector3
	if back > 0.0:
		hand = target.lerp(_neutral_hand[arm], back) + Vector3.UP * 1.6 * sin(PI * back)
		elbow = strike_elbow.lerp(_neutral_elbow[arm], back) + Vector3.UP * 0.8 * sin(PI * back)
	elif fall > 0.0:
		# over the top and down: a curve swinging out toward the target first
		var over := raised_hand + toward * 2.2 + Vector3.UP * 0.6
		hand = _bezier(raised_hand, over, target, fall)
		elbow = raised_elbow.lerp(strike_elbow, fall)
	else:
		hand = _neutral_hand[arm].lerp(raised_hand, raise) + toward * -0.4 * sin(PI * raise)
		elbow = _neutral_elbow[arm].lerp(raised_elbow, raise)
	slam_hand = hand
	pose.arm_aim[arm] = 1.0
	pose.hand[arm] = hand + Vector3.UP * _bounce.step(0.0, _delta) * 3.0
	pose.elbow[arm] = elbow
	pose.wrist[arm] = clip.sample(&"wrist", t)
	pose.shrug[arm] += clip.sample(&"shrug", t)
	pose.arm_glow[arm] = clip.sample(&"glow", t)
	# the other hand grips its knee harder
	pose.shrug[other] += clip.sample(&"brace", t)


func _sweep(t: float) -> void:
	var clip: MotionClip = _clips[A.SWEEP]
	var arm := 0 if side > 0 else 1
	pose.torso.x += clip.sample(&"lean", t)
	pose.seams = clip.sample(&"seams", t)
	var from := ColossusBrain.SWEEP_FROM * side
	var to := ColossusBrain.SWEEP_TO * side
	var drawn := from + 0.35 * float(side)
	var draw := clip.sample(&"draw", t)
	var pass_through := clip.sample(&"sweep", t)
	var back := clip.sample(&"back", t)
	var drawn_hand := _ring_point(drawn, 5.2, 1.9)
	var drawn_elbow := _ring_point(drawn, 2.8, 2.7)
	var hand: Vector3
	var elbow: Vector3
	sweep_low = false
	if back > 0.0:
		var end_hand := _ring_point(to, SWEEP_HAND, SWEEP_HEIGHT)
		var end_elbow := _ring_point(to, SWEEP_ELBOW, SWEEP_HEIGHT + 0.55)
		hand = end_hand.lerp(_neutral_hand[arm], back) + Vector3.UP * 1.2 * sin(PI * back)
		elbow = end_elbow.lerp(_neutral_elbow[arm], back)
		sweep_bearing = to
	elif t >= 1.0:
		sweep_bearing = lerpf(from, to, pass_through)
		var drop := clampf(pass_through / 0.12, 0.0, 1.0)
		hand = drawn_hand.lerp(_ring_point(sweep_bearing, SWEEP_HAND, SWEEP_HEIGHT), MotionClip.eased(MotionClip.OUT, drop))
		elbow = drawn_elbow.lerp(_ring_point(sweep_bearing, SWEEP_ELBOW, SWEEP_HEIGHT + 0.55), MotionClip.eased(MotionClip.OUT, drop))
		sweep_low = drop >= 1.0 and t < 2.0
	else:
		hand = _neutral_hand[arm].lerp(drawn_hand, draw)
		elbow = _neutral_elbow[arm].lerp(drawn_elbow, draw)
		sweep_bearing = drawn
	pose.arm_aim[arm] = 1.0
	pose.hand[arm] = hand
	pose.elbow[arm] = elbow
	pose.wrist[arm] = clip.sample(&"wrist", t)
	pose.shrug[arm] += clip.sample(&"shrug", t)
	pose.arm_glow[arm] = clip.sample(&"glow", t)


func _beam(kind: A, t: float) -> void:
	var clip: MotionClip = _clips[kind]
	pose.charge = clip.sample(&"charge", t) * (1.0 + 0.08 * sin(time * 40.0) * clampf(t - 1.0, 0.0, 1.0))
	pose.torso.x += clip.sample(&"lean", t)
	for i in 2:
		pose.shrug[i] += clip.sample(&"shrug", t)


func _swarm(t: float) -> void:
	var clip: MotionClip = _clips[A.SWARM]
	var arm := 0 if swarm_point.x < 0.0 else 1
	var reach := clip.sample(&"reach", t)
	pose.charge = clip.sample(&"eyes", t)
	pose.torso.x += clip.sample(&"lean", t)
	var shoulder := rig.shoulder_at(pose, arm)
	var call_hand := swarm_point + Vector3(0.0, 1.6, -1.6)
	var call_elbow := shoulder.lerp(call_hand, 0.5) + Vector3(-0.5 if arm == 0 else 0.5, 0.3, 0.2)
	pose.arm_aim[arm] = 1.0
	pose.hand[arm] = _neutral_hand[arm].lerp(call_hand, reach)
	pose.elbow[arm] = _neutral_elbow[arm].lerp(call_elbow, reach)
	pose.wrist[arm] = -0.6 * reach


# --- looking --------------------------------------------------------------------

## The head turns to [param point] (springs: a moment late, a little past);
## [param still] keeps it down (just waking).
func _look(point: Vector3, delta: float, still: bool) -> void:
	var head := rig.head_at(pose)
	var to := point - head
	var flat := Vector2(to.x, to.z).length()
	var yaw := atan2(-to.x, -to.z) - pose.torso.y - pose.pelvis_turn.y
	yaw = wrapf(yaw, -PI, PI)
	var pitch := atan2(to.y, maxf(flat, 0.01)) - pose.torso.x
	if still:
		yaw = 0.0
		pitch = 0.0
	pose.head.y += _look_yaw.step(clampf(yaw, -HEAD_YAW, HEAD_YAW), delta)
	pose.head.x += _look_pitch.step(clampf(pitch, HEAD_PITCH.x, HEAD_PITCH.y), delta)


## Bearing of a body-space point from the hips (rad, + to its left).
func _bearing_of(point: Vector3) -> float:
	var to := point - Vector3(pose.pelvis.x, 0.0, pose.pelvis.z)
	return atan2(-to.x, -to.z)


## A floor-plan point at [param bearing] and [param radius] from the hips,
## [param height] up.
func _ring_point(bearing: float, radius: float, height: float) -> Vector3:
	return Vector3(pose.pelvis.x - sin(bearing) * radius, height, pose.pelvis.z - cos(bearing) * radius)


static func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


# --- the clips ------------------------------------------------------------------

func _build_clips() -> void:
	var I := MotionClip.IN
	var O := MotionClip.OUT
	var IO := MotionClip.IN_OUT
	var BK := MotionClip.OUT_BACK
	# the hand slam: the shoulders lead, the arm rises over the shoulder
	# (anticipation: a lean back, the wrist cocked), hangs a beat, falls
	# accelerating onto the shadow (impact exactly at 1.0), lies there,
	# rises and settles back on the knee
	var slam := MotionClip.new()
	slam.key(&"lead", 0.0, 0.0).key(&"lead", 0.35, 1.0, O).key(&"lead", 2.2, 1.0).key(&"lead", 3.0, 0.0, IO)
	slam.key(&"raise", 0.0, 0.0).key(&"raise", 0.12, 0.0, MotionClip.HOLD).key(&"raise", 0.64, 1.0, IO)
	slam.key(&"fall", 0.0, 0.0).key(&"fall", 0.7, 0.0, MotionClip.HOLD).key(&"fall", 1.0, 1.0, I)
	slam.key(&"back", 0.0, 0.0).key(&"back", 2.0, 0.0, MotionClip.HOLD).key(&"back", 3.0, 1.0, IO)
	slam.key(&"lean", 0.0, 0.0).key(&"lean", 0.62, 0.07, IO).key(&"lean", 1.0, -0.3, I).key(&"lean", 1.12, -0.26, BK) \
		.key(&"lean", 2.0, -0.24, IO).key(&"lean", 3.0, 0.0, IO)
	slam.key(&"wrist", 0.0, 0.0).key(&"wrist", 0.62, 0.95, IO).key(&"wrist", 1.0, -0.3, I).key(&"wrist", 1.4, 0.0, IO)
	slam.key(&"shrug", 0.0, 0.0).key(&"shrug", 0.3, 0.3, O).key(&"shrug", 1.0, -0.12, I).key(&"shrug", 2.5, 0.0, IO)
	slam.key(&"seams", 0.0, 0.0).key(&"seams", 0.6, 0.7, IO).key(&"seams", 1.0, 1.9, I).key(&"seams", 1.5, 0.9, O).key(&"seams", 2.8, 0.0, IO)
	slam.key(&"glow", 0.0, 0.0).key(&"glow", 0.9, 0.7, I).key(&"glow", 1.25, 0.0, O)
	slam.key(&"brace", 0.0, 0.0).key(&"brace", 0.6, 0.12, IO).key(&"brace", 1.0, -0.05, I).key(&"brace", 2.5, 0.0, IO)
	_clips[A.SLAM] = slam
	# the low sweep: the arm draws back (the torso winds with it), drops to
	# the floor and sweeps across in front of the knees, then comes back
	var sweep := MotionClip.new()
	sweep.key(&"draw", 0.0, 0.0).key(&"draw", 0.85, 1.0, IO)
	sweep.key(&"sweep", 1.0, 0.0).key(&"sweep", 2.0, 1.0, IO)
	sweep.key(&"back", 0.0, 0.0).key(&"back", 2.0, 0.0, MotionClip.HOLD).key(&"back", 3.0, 1.0, IO)
	sweep.key(&"lean", 0.0, 0.0).key(&"lean", 0.8, 0.06, IO).key(&"lean", 1.25, -0.2, I).key(&"lean", 2.0, -0.12, IO).key(&"lean", 3.0, 0.0, IO)
	sweep.key(&"wrist", 0.0, 0.0).key(&"wrist", 0.8, 0.6, IO).key(&"wrist", 1.2, -0.2, I).key(&"wrist", 2.6, 0.0, IO)
	sweep.key(&"shrug", 0.0, 0.0).key(&"shrug", 0.8, 0.25, IO).key(&"shrug", 1.2, -0.1, I).key(&"shrug", 2.6, 0.0, IO)
	sweep.key(&"seams", 0.0, 0.0).key(&"seams", 0.9, 1.2, IO).key(&"seams", 1.3, 1.6, O).key(&"seams", 2.8, 0.0, IO)
	sweep.key(&"glow", 0.0, 0.0).key(&"glow", 1.0, 0.6, I).key(&"glow", 1.6, 0.0, O)
	_clips[A.SWEEP] = sweep
	# the beam: the head gathers the light (a lean in), recoils as it fires
	# and pushes into it
	var beam := MotionClip.new()
	beam.key(&"charge", 0.0, 0.0).key(&"charge", 1.0, 1.0, I).key(&"charge", 1.06, 1.45, O).key(&"charge", 2.0, 1.2, IO).key(&"charge", 2.35, 0.0, O)
	beam.key(&"lean", 0.0, 0.0).key(&"lean", 0.9, -0.06, IO).key(&"lean", 1.1, 0.08, BK).key(&"lean", 2.0, 0.03, IO).key(&"lean", 3.0, 0.0, IO)
	beam.key(&"shrug", 0.0, 0.0).key(&"shrug", 1.0, 0.16, IO).key(&"shrug", 2.5, 0.0, IO)
	_clips[A.BEAM] = beam
	_clips[A.BEAM_SWEEP] = beam
	# the swarm: a palm held out over the throne's side, the eyes flaring
	var swarm := MotionClip.new()
	swarm.key(&"reach", 0.0, 0.0).key(&"reach", 0.8, 1.0, IO).key(&"reach", 2.0, 1.0).key(&"reach", 3.0, 0.0, IO)
	swarm.key(&"eyes", 0.0, 0.0).key(&"eyes", 0.9, 0.6, I).key(&"eyes", 1.3, 0.0, O)
	swarm.key(&"lean", 0.0, 0.0).key(&"lean", 0.8, -0.08, IO).key(&"lean", 3.0, 0.0, IO)
	_clips[A.SWARM] = swarm
	# waking: the eyes ignite (a flare), the stone shivers loose, it draws
	# itself up and turns to the guard
	_wake = MotionClip.new()
	_wake.key(&"eyes", 0.0, 0.0).key(&"eyes", 0.12, 1.0, O)
	_wake.key(&"flare", 0.0, 0.0).key(&"flare", 0.1, 1.5, O).key(&"flare", 0.4, 0.0, IO)
	_wake.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.08, 0.03, O).key(&"shiver", 0.5, 0.0, IO)
	_wake.key(&"lean", 0.0, 0.0).key(&"lean", 0.35, 0.09, IO).key(&"lean", 0.8, -0.02, IO).key(&"lean", 1.0, 0.0, IO)
	_wake.key(&"shrug", 0.0, 0.0).key(&"shrug", 0.3, 0.22, IO).key(&"shrug", 0.75, 0.0, IO)
	_wake.key(&"twist", 0.0, 0.0).key(&"twist", 0.4, 0.0, MotionClip.HOLD).key(&"twist", 0.95, 1.0, IO)
	# phase 2: it rears back, arms thrown open; the plates burst off at
	# PLATES_AT and the cracks blaze; it slumps forward, then glares
	_shift = MotionClip.new()
	_shift.key(&"lean", 0.0, 0.0).key(&"lean", 0.35, 0.26, O).key(&"lean", 0.6, 0.3, IO).key(&"lean", 0.85, -0.08, IO).key(&"lean", 1.0, 0.0, IO)
	_shift.key(&"head", 0.0, 0.0).key(&"head", 0.35, 0.3, O).key(&"head", 0.85, -0.1, IO).key(&"head", 1.0, 0.0, IO)
	_shift.key(&"spread", 0.0, 0.0).key(&"spread", 0.35, 1.0, O).key(&"spread", 0.6, 1.0).key(&"spread", 1.0, 0.0, IO)
	_shift.key(&"cracks", 0.0, 0.0).key(&"cracks", 0.3, 0.2, I).key(&"cracks", PLATES_AT, 1.8, O).key(&"cracks", 1.0, 1.0, IO)
	_shift.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.2, 0.02, IO).key(&"shiver", PLATES_AT, 0.04, I).key(&"shiver", 0.7, 0.0, IO)
	_shift.key(&"eyes", 0.0, 0.0).key(&"eyes", PLATES_AT, 1.3, I).key(&"eyes", 1.0, 0.0, IO)
	# phase 3: it stands up (seconds). Anticipation: a dip, the head bows,
	# the hands press on the thighs; the hips rise and slide forward, the
	# torso leans far over the knees; the left foot, the right foot step
	# off the plinth (stomps); it rises to its full height, a little past
	# it, and settles
	_stand = MotionClip.new()
	_stand.key(&"hips_y", 0.0, 3.3).key(&"hips_y", 0.45, 3.22, IO).key(&"hips_y", 1.6, 3.95, IO) \
		.key(&"hips_y", 2.95, STAND_HIPS + 0.12, O).key(&"hips_y", 3.4, STAND_HIPS, IO)
	_stand.key(&"hips_z", 0.0, 0.0).key(&"hips_z", 0.5, 0.05, IO).key(&"hips_z", 1.6, -1.6, IO).key(&"hips_z", 2.9, STAND_PELVIS.z, IO)
	_stand.key(&"hips_pitch", 0.0, 0.0).key(&"hips_pitch", 1.2, -0.12, IO).key(&"hips_pitch", 2.9, 0.0, IO)
	_stand.key(&"lean", 0.0, 0.0).key(&"lean", 0.45, -0.14, IO).key(&"lean", 1.3, -0.5, IO).key(&"lean", 2.2, -0.34, IO) \
		.key(&"lean", 3.0, 0.05, IO).key(&"lean", 3.4, 0.0, IO)
	_stand.key(&"head", 0.0, 0.0).key(&"head", 0.45, -0.25, IO).key(&"head", 1.6, -0.05, IO).key(&"head", 2.7, 0.12, IO).key(&"head", 3.4, 0.0, IO)
	_stand.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.4, 0.012, IO).key(&"shiver", 1.0, 0.02, IO).key(&"shiver", 1.8, 0.0, IO)
	_stand.key(&"legs", 0.0, 0.0).key(&"legs", 0.4, 1.0, IO)
	_stand.key(&"step_l", 0.0, 0.0).key(&"step_l", 1.6, 0.0, MotionClip.HOLD).key(&"step_l", STAND_STOMPS[0], 1.0, IO)
	_stand.key(&"step_r", 0.0, 0.0).key(&"step_r", STAND_STOMPS[0], 0.0, MotionClip.HOLD).key(&"step_r", STAND_STOMPS[1], 1.0, IO)
	_stand.key(&"brace", 0.0, 0.0).key(&"brace", 0.5, 1.0, IO)
	_stand.key(&"release", 0.0, 0.0).key(&"release", 1.5, 0.0, MotionClip.HOLD).key(&"release", 2.6, 1.0, IO)
