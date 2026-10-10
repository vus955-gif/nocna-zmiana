class_name LamassuMoves
extends RefCounted
## The Lamassu's choreography: from the brain's moment, the gait's hooves
## and the fight's points (set by the Lamassu each frame, body space) it
## composes the Pose its rig shows, in three layers:
## 1. LOCOMOTION, always: the hooves where the gait has them (planted in the
##    world, swinging in arcs, curling back in the swing); the body rocks
##    with the gallop, rolls with the walk's weight shifts, banks into
##    turns and pitches with its acceleration (the nose dips as it digs in,
##    the haunches drop as it brakes); the head follows the guard a moment
##    late (springs) and steadies against the rocking; the tail streams out
##    at speed, swishes at rest; the wing tips lag the wings.
## 2. ACTION, a MotionClip per attack sampled at the brain's clip_time()
##    (0..1 warning, 1..2 strike, 2..3 recovery), laid over the first: the
##    charge (the head drops, the right fore hoof paws the floor twice; the
##    run; the skid - the haunches down, the fore legs braced), the gust (the
##    wings spread out and rise over the back; at 1.0 they beat forward and
##    down, the tips trailing; they fold), the stomp (it rocks back onto its
##    haunches and rears, the fore hooves pawing the air; at 1.0 they crash
##    down on the stomp point as the body lunges; it settles), the hop (a
##    crouch, the leap - the wings beating in the air; the landing squat),
##    the stun (it sags, the head hangs within a shot's reach and shakes),
##    the waking (dust, the eyes, the head lifting and turning, the wings
##    creaking open; the steps off the plinth are the gait's) and the phase
##    shifts (2: it rears and bellows, wings wide, the cracks blaze; 3: three
##    wing beats lift it off the floor and it drops).
## 3. SETTLING: the body comes down onto its legs when they cannot reach
##    their hooves (the legs are straight columns at rest), the front and
##    the back each by their own need - the pitch of a long step is born
##    from the hooves.
## Principles (docs/superpowers/plans/2026-10-03-straznik-lamassu.md):
## anticipation before every blow, ease in and out, overshoot and settle,
## follow-through on springs, contacts that land exactly on their marks.

const S := LamassuBrain.State
const A := LamassuBrain.Attack
const M := LamassuGait.Mode
## The rear's pivot: between the hind contacts (body space); the hop's
## crouch is about the fore.
const HIND_PIVOT := Vector3(0.0, 0.0, 1.03)
## The fore and hind leg roots' span along the body and the fore roots'
## lever from the pivot (m): the settling's pitch.
const ROOT_SPAN := 1.78
const FORE_ARM := 0.8
## Head limits on the neck (rad).
const HEAD_YAW := 0.9
const HEAD_PITCH := Vector2(-0.55, 0.35)
## The pawing hoof's reach forward and its drag back (body space, from its
## rest), and how high it lifts.
const PAW_FORWARD := 0.42
const PAW_BACK := 0.22
const PAW_LIFT := 0.16
## The fore hooves tucked under the chest in a rear (from the fore root,
## body space) and in the air.
const TUCK := Vector3(0.0, -0.55, -0.2)
## How much a hoof curls back in its swing (rad; fore, hind).
const CURL := Vector2(1.2, 0.9)
## The acceleration's pitch (rad per m/s^2) and its most.
const ACCEL_PITCH := 0.01
const ACCEL_MAX := 0.12
## The hover of the phase-3 shift: how high the body rises (m).
const HOVER_HEIGHT := 0.9

var rig: LamassuRig
var pose := LamassuRig.Pose.new()

# --- the fight's points, body space (set by the Lamassu) -------------------------
## The guard's chest.
var guard := Vector3(0.0, 1.5, -12.0)
## Where the stomp's fore hooves come down (on the floor, between them).
var stomp_point := Vector3(0.0, 0.0, -1.6)

## The pawing hoof drags along the floor now (dust).
var pawing := false
## The body rears now (its nose up more than this).
var rearing := false
## 0..1: how far off the floor the phase-3 shift's wing beats hold it (the
## node lifts the root by HOVER_HEIGHT times this).
var hover: float = 0.0
## Seconds of choreography so far (the sways, shakes and pulses are sines
## of it).
var time: float = 0.0

var _clips: Dictionary = {}
var _wake: MotionClip
var _stun: MotionClip
var _shift2: MotionClip
var _shift3: MotionClip
var _look_yaw := Spring.new(1.5, 0.6)
var _look_pitch := Spring.new(1.5, 0.7)
var _head_bob := Spring.new(3.0, 0.5)
var _roll := Spring.new(1.4, 0.8)
var _accel := Spring.new(1.6, 0.7)
var _tail_lift := Spring.new(1.5, 0.35)
var _tail_swish := Spring.new(1.2, 0.3)
var _tips: Array[Spring] = [Spring.new(2.4, 0.45), Spring.new(2.4, 0.45)]
var _flinch := Spring.new(3.0, 0.4)
var _weight := Spring.new(4.0, 0.55)
var _speed_before: float = 0.0
var _accel_smooth: float = 0.0
var _beat_before: float = 0.0


func _init(for_rig: LamassuRig) -> void:
	rig = for_rig
	_build_clips()


## The pose for [param brain]'s moment, the [param gait]'s hooves and the
## body at [param body] (world), advanced by [param delta].
func compose(brain: LamassuBrain, gait: LamassuGait, body: Transform3D, delta: float) -> LamassuRig.Pose:
	time += delta
	_reset_pose()
	pawing = false
	rearing = false
	hover = 0.0
	if brain.state == S.DORMANT:
		_settle_springs()
		return pose   # the museum piece, exactly
	pose.eyes = 1.0
	pose.legs_ik = 1.0
	_locomotion(gait, body, delta)
	var t := brain.clip_time()
	var u := brain.state_progress()
	match brain.state:
		S.WAKING:
			_waking(u)
		S.STUNNED:
			_stunned(u)
		S.PHASE_SHIFT:
			_shift(brain.shift_phase, u)
		S.ATTACK:
			match brain.attack:
				A.CHARGE:
					_charge(t)
				A.GUST:
					_gust(t)
				A.STOMP:
					_stomp(t)
				A.HOP:
					_hop(t)
	var jolt := _flinch.step(0.0, delta)
	pose.head.x -= jolt * 0.5
	pose.body_turn.x -= jolt * 0.08
	_settle(delta)
	_look(delta)
	_wing_tips(delta)
	rearing = pose.body_turn.x > 0.35
	return pose


## A hit landed: the head jerks, the body flinches.
func flinch(amount: float = 1.0) -> void:
	_flinch.kick(1.0 * amount)


## A hoof came down: the body dips with the weight and comes back up.
func footfall(amount: float = 1.0) -> void:
	_weight.kick(0.5 * amount)


## Back on its plinth: springs at rest.
func reset() -> void:
	_settle_springs()
	_speed_before = 0.0
	_accel_smooth = 0.0


func _settle_springs() -> void:
	for spring: Spring in [_look_yaw, _look_pitch, _head_bob, _roll, _accel, _tail_lift, _tail_swish, _tips[0], _tips[1], _flinch, _weight]:
		spring.reset(0.0)


func _reset_pose() -> void:
	var p := pose
	p.body = LamassuRig.BODY_REST
	p.body_turn = Vector3.ZERO
	p.legs_ik = 0.0
	for leg in 4:
		p.contacts[leg] = LamassuGait.NEUTRAL[leg]
		p.hoof_pitch[leg] = 0.0
	p.head = Vector3.ZERO
	for side in 2:
		p.wing_spread[side] = 0.0
		p.wing_raise[side] = 0.0
		p.wing_beat[side] = 0.0
		p.wing_tip[side] = 0.0
	p.tail = Vector2.ZERO
	p.eyes = 0.0
	p.cracks = 0.0
	p.shiver = 0.0


# --- locomotion ------------------------------------------------------------------

func _locomotion(gait: LamassuGait, body: Transform3D, delta: float) -> void:
	var inverse := body.affine_inverse()
	var run := clampf(gait.speed / 9.0, 0.0, 1.0)
	for leg in 4:
		pose.contacts[leg] = inverse * gait.feet[leg]
		var w := gait.swing(leg)
		# the hoof curls back as the leg folds in the swing
		pose.hoof_pitch[leg] = -(CURL.x if leg < 2 else CURL.y) * sin(PI * pow(w, 0.7)) * lerpf(0.5, 1.0, run)
	var c := gait.cycle
	var stepping := 1.0 if gait.stepping else 0.0
	var walk := stepping * clampf(gait.speed / 1.2, 0.0, 1.0) if gait.mode == M.WALK else 0.0
	var gallop := run if gait.mode == M.GALLOP else 0.0
	# the heavy gallop rocks the body (nose up as the hind legs drive, down
	# as the fore legs land); the walk shifts its weight side to side
	var pitch := gallop * 0.07 * cos(TAU * (c - 0.45)) + walk * 0.012 * sin(2.0 * TAU * c)
	var sway := walk * 0.028 * sin(TAU * (c - 0.1))
	# it banks into a turn, the faster the more
	var bank := clampf(gait.yaw_rate * gait.speed * 0.02, -0.2, 0.2)
	var roll := _roll.step(bank, delta)
	# the nose dips as it digs in, the haunches drop as it brakes
	var accel := (gait.speed - _speed_before) / maxf(delta, 0.001) if delta > 0.0 else 0.0
	_speed_before = gait.speed
	_accel_smooth = lerpf(_accel_smooth, accel, clampf(delta * 10.0, 0.0, 1.0))
	var dig := _accel.step(clampf(-_accel_smooth * ACCEL_PITCH, -ACCEL_MAX, ACCEL_MAX), delta)
	pose.body_turn.x = pitch + dig
	pose.body_turn.z = roll + sway
	# the head steadies against the rocking (a moment late)
	pose.head.x = -_head_bob.step(pitch * 0.8 + dig * 0.5, delta)
	# the tail: out behind at speed, swishing at rest, out of the turns
	var lift := _tail_lift.step(0.1 + 0.7 * gallop + 0.15 * walk, delta)
	var swish := _tail_swish.step(-gait.yaw_rate * 0.25 + sin(time * 1.3) * 0.22 * (1.0 - run) + sin(time * 0.41) * 0.08, delta)
	pose.tail = Vector2(lift, swish)


## The body comes down onto its legs where they cannot reach their hooves:
## the front and the back each by their need, the pitch between them.
func _settle(delta: float) -> void:
	var front := 0.0
	var back := 0.0
	for leg in 4:
		var root := rig.leg_root(pose, leg)
		var target := rig.fetlock_target(pose, leg)
		var flat := Vector2(target.x - root.x, target.z - root.z).length()
		var reach := rig.leg_reach(leg) * 0.99
		var need := sqrt(maxf(reach * reach - flat * flat, 0.0))
		var have := root.y - target.y
		var drop := maxf(have - need, 0.0)
		if leg < 2:
			front = maxf(front, drop)
		else:
			back = maxf(back, drop)
	# (the hooves move continuously, so the need does: no smoothing - the
	# weight of a footfall is the node's kick on _weight)
	var pitch := (back - front) / ROOT_SPAN
	pose.body.y -= front + FORE_ARM * pitch + _weight.step(0.0, delta)
	pose.body_turn.x += pitch


# --- the attacks -----------------------------------------------------------------

func _charge(t: float) -> void:
	var clip: MotionClip = _clips[A.CHARGE]
	var low := clip.sample(&"low", t)
	pose.head.x += -0.45 * low
	pose.body_turn.x += -0.06 * low
	# the right fore hoof paws: up and forward, then dragged back along the
	# floor (dust), twice
	var paw := clip.sample(&"paw", t)
	if paw > 0.0:
		var stroke := fposmod(clip.sample(&"stroke", t), 1.0)
		var rest := LamassuGait.NEUTRAL[1]
		var reach: Vector3
		if stroke < 0.45:
			var k := stroke / 0.45
			reach = Vector3(0.0, PAW_LIFT * sin(PI * k), -PAW_FORWARD * MotionClip.eased(MotionClip.OUT, k))
		else:
			var k := (stroke - 0.45) / 0.55
			reach = Vector3(0.0, 0.0, -PAW_FORWARD + (PAW_FORWARD + PAW_BACK) * k)
			pawing = paw > 0.5
		var hoof := Vector3(pose.contacts[1].x, rest.y, rest.z) + reach
		pose.contacts[1] = pose.contacts[1].lerp(hoof, paw)
		pose.hoof_pitch[1] = lerpf(pose.hoof_pitch[1], 0.3 if pawing else -0.5, paw)
	# the skid: the haunches down, the head up, the fore legs braced forward
	var brace := clip.sample(&"brace", t)
	if brace > 0.0:
		pose.body_turn.x += 0.14 * brace
		pose.body.y -= 0.1 * brace
		pose.head.x += 0.3 * brace
		for leg in 2:
			pose.contacts[leg].z -= 0.3 * brace
		for leg in [2, 3]:
			pose.contacts[leg].z += 0.12 * brace
	pose.tail.y += sin(time * 9.0) * 0.4 * clip.sample(&"lash", t)
	pose.tail.x += 0.25 * low


func _gust(t: float) -> void:
	var clip: MotionClip = _clips[A.GUST]
	var spread := clip.sample(&"spread", t)
	var raise := clip.sample(&"raise", t)
	var beat := clip.sample(&"beat", t)
	for side in 2:
		pose.wing_spread[side] = spread
		pose.wing_raise[side] = raise
		pose.wing_beat[side] = beat
	pose.body_turn.x += clip.sample(&"rock", t)
	pose.body.y += clip.sample(&"rise", t)
	pose.head.x += clip.sample(&"toss", t)
	pose.tail.x += 0.3 * spread


func _stomp(t: float) -> void:
	var clip: MotionClip = _clips[A.STOMP]
	var rear := clip.sample(&"rear", t)
	_pivot(HIND_PIVOT, rear, clip.sample(&"lunge", t), clip.sample(&"crouch", t))
	# the fore hooves paw the air on the way up, then crash onto the point
	var paw := clip.sample(&"paw", t)
	var strike := clip.sample(&"strike", t)
	var body := LamassuRig.body_xform(pose)
	for leg in 2:
		var side := -1.0 if leg == 0 else 1.0
		var root := rig.leg_root(pose, leg)
		var stroke := time * 12.0 + float(leg) * PI
		var tucked := root + body.basis * (TUCK + Vector3(0.0, 0.1 * sin(stroke), 0.12 * cos(stroke))) - rig.fetlock_offset(leg)
		var landing := Vector3(stomp_point.x + side * 0.41, 0.0, stomp_point.z)
		var hoof := pose.contacts[leg].lerp(tucked, paw)
		pose.contacts[leg] = hoof.lerp(landing, strike)
		pose.hoof_pitch[leg] = lerpf(pose.hoof_pitch[leg], -1.0, paw * (1.0 - strike))
	pose.head.x += clip.sample(&"toss", t)
	pose.tail.x -= rear * 0.6
	var wings := clip.sample(&"wings", t)
	for side in 2:
		pose.wing_spread[side] += wings
		pose.wing_raise[side] += wings * 0.4


func _hop(t: float) -> void:
	var clip: MotionClip = _clips[A.HOP]
	pose.body.y -= clip.sample(&"crouch", t)
	pose.body_turn.x += clip.sample(&"pitch", t)
	var spread := clip.sample(&"spread", t)
	var flap := clip.sample(&"flap", t)
	for side in 2:
		pose.wing_spread[side] = spread
		pose.wing_raise[side] = clip.sample(&"raise", t) + 0.35 * sin(time * 14.0) * flap
		pose.wing_beat[side] = 0.6 * flap + 0.5 * cos(time * 14.0) * flap
	pose.head.x += clip.sample(&"toss", t)
	pose.tail.x += 0.5 * flap


func _stunned(u: float) -> void:
	var clip := _stun
	var reel := clip.sample(&"reel", u)
	pose.body.y -= 0.3 * reel
	pose.body_turn.x += -0.2 * reel + 0.03 * sin(time * 2.1) * reel
	pose.body_turn.z += 0.06 * sin(time * 1.9) * reel
	pose.contacts[0].x -= 0.12 * reel
	pose.contacts[1].x += 0.12 * reel
	pose.head.x += -0.55 * reel
	pose.head.y += 0.35 * sin(time * 9.0) * clip.sample(&"shake", u)
	for side in 2:
		pose.wing_spread[side] += 0.35 * reel
		pose.wing_raise[side] += -0.25 * reel
	pose.cracks = maxf(pose.cracks, (1.2 + 0.4 * sin(time * 7.0)) * reel)
	pose.shiver = 0.005 * reel
	pose.tail.x -= 0.2 * reel


## The waking (progress [param u]): the stone shivers, the eyes light, the
## head lifts and turns to the guard, the wings creak open; the steps off
## the plinth are the gait's (the node commands them).
func _waking(u: float) -> void:
	var clip := _wake
	pose.eyes = clip.sample(&"eyes", u)
	pose.shiver = clip.sample(&"shiver", u)
	pose.head.x += clip.sample(&"head", u)
	pose.head.y += clampf(_bearing_of(guard), -HEAD_YAW, HEAD_YAW) * clip.sample(&"turn", u) * 0.6
	pose.head.y += 0.4 * sin(time * 11.0) * clip.sample(&"shake", u)
	var spread := clip.sample(&"spread", u)
	for side in 2:
		pose.wing_spread[side] += spread
		pose.wing_raise[side] += clip.sample(&"raise", u)
	pose.tail.x += clip.sample(&"tail", u)


## The shift into phase [param into] (progress [param u]).
func _shift(into: int, u: float) -> void:
	if into == 2:
		var clip := _shift2
		var rear := clip.sample(&"rear", u)
		_pivot(HIND_PIVOT, rear, 0.0, clip.sample(&"crouch", u))
		var body := LamassuRig.body_xform(pose)
		var paw := clip.sample(&"paw", u)
		for leg in 2:
			var root := rig.leg_root(pose, leg)
			var tucked := root + body.basis * TUCK - rig.fetlock_offset(leg)
			pose.contacts[leg] = pose.contacts[leg].lerp(tucked, paw)
			pose.hoof_pitch[leg] = lerpf(pose.hoof_pitch[leg], -1.0, paw)
		var spread := clip.sample(&"spread", u)
		for side in 2:
			pose.wing_spread[side] += spread
			pose.wing_raise[side] += clip.sample(&"raise", u)
		pose.head.x += clip.sample(&"bellow", u)
		pose.head.y += 0.3 * sin(time * 10.0) * clip.sample(&"shake", u)
		pose.cracks = clip.sample(&"cracks", u)
		pose.shiver = clip.sample(&"shiver", u)
		pose.tail.x -= rear * 0.6
	else:
		var clip := _shift3
		hover = clip.sample(&"hover", u)
		pose.body.y -= clip.sample(&"squat", u)
		pose.body_turn.x += clip.sample(&"pitch", u)
		var spread := clip.sample(&"spread", u)
		for side in 2:
			pose.wing_spread[side] += spread
			pose.wing_raise[side] += clip.sample(&"raise", u)
			pose.wing_beat[side] += clip.sample(&"beat", u)
		pose.head.x += clip.sample(&"toss", u)
		pose.cracks = 1.2 + 0.4 * sin(time * 6.0)
		pose.tail.x += 0.5 * hover


## Rotates the body by [param pitch] about [param pivot] (body space, on
## the floor: between the hind contacts for a rear), carried [param shift]
## forward and [param crouch] down.
func _pivot(pivot: Vector3, pitch: float, shift: float, crouch: float) -> void:
	var turn := Basis(Vector3.RIGHT, pitch)
	var low := pivot + Vector3.DOWN * crouch
	pose.body = low + turn * (pose.body - low) + Vector3.FORWARD * shift
	pose.body_turn.x += pitch


# --- looking, the tips ---------------------------------------------------------------

## The head turns to the guard (springs: a moment late, a little past).
func _look(delta: float) -> void:
	var body := LamassuRig.body_xform(pose)
	var neck := body * (rig.rest["head"] as Transform3D).origin
	var local := body.basis.inverse() * (guard - neck)
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, maxf(Vector2(local.x, local.z).length(), 0.01))
	pose.head.y += _look_yaw.step(clampf(yaw, -HEAD_YAW, HEAD_YAW), delta)
	pose.head.x += _look_pitch.step(clampf(pitch, HEAD_PITCH.x, HEAD_PITCH.y), delta)


## The wing tips fold out as the wings spread and trail a beat (springs).
func _wing_tips(delta: float) -> void:
	var beat_now := pose.wing_beat[0]
	if beat_now > 0.05 and _beat_before <= 0.05:
		for spring in _tips:
			spring.kick(-2.5)   # the tips are left behind as the beat starts
	_beat_before = beat_now
	for side in 2:
		var target := pose.wing_spread[side] * 0.3 + pose.wing_beat[side] * 0.15 + pose.wing_raise[side] * 0.1
		pose.wing_tip[side] = _tips[side].step(target, delta)


## Bearing of a body-space point from the body (rad, + to its left).
static func _bearing_of(point: Vector3) -> float:
	return atan2(-point.x, -point.z)


# --- the clips ---------------------------------------------------------------------

func _build_clips() -> void:
	var I := MotionClip.IN
	var O := MotionClip.OUT
	var IO := MotionClip.IN_OUT
	var BK := MotionClip.OUT_BACK
	var H := MotionClip.HOLD
	# the charge: the head drops, the body leans; the right fore hoof paws
	# twice (up and forward, dragged back along the floor); the run (the
	# gait's gallop, the head low); the skid (haunches down, head up, the
	# fore legs braced), then it stands
	var charge := MotionClip.new()
	charge.key(&"low", 0.0, 0.0).key(&"low", 0.3, 1.0, IO).key(&"low", 2.0, 0.85).key(&"low", 2.5, 0.0, IO)
	charge.key(&"paw", 0.0, 0.0).key(&"paw", 0.1, 1.0, IO).key(&"paw", 0.86, 1.0).key(&"paw", 0.97, 0.0, IO)
	charge.key(&"stroke", 0.0, 0.0).key(&"stroke", 0.12, 0.0, H).key(&"stroke", 0.5, 0.999, MotionClip.LINEAR) \
		.key(&"stroke", 0.5001, 1.0, H).key(&"stroke", 0.88, 1.999, MotionClip.LINEAR)
	charge.key(&"brace", 0.0, 0.0).key(&"brace", 2.0, 0.0, H).key(&"brace", 2.12, 1.0, O).key(&"brace", 2.55, 0.9).key(&"brace", 3.0, 0.0, IO)
	charge.key(&"lash", 0.0, 0.0).key(&"lash", 0.2, 1.0, IO).key(&"lash", 1.0, 1.0).key(&"lash", 1.25, 0.0, IO)
	_clips[A.CHARGE] = charge
	# the gust: the wings spread out from the back and rise over the rump as
	# the body rocks back and the head comes up; at 1.0 they beat forward and
	# down (the body pitches into it, the tips trailing); they fold
	var gust := MotionClip.new()
	gust.key(&"spread", 0.0, 0.0).key(&"spread", 0.75, 1.25, O).key(&"spread", 2.2, 1.2).key(&"spread", 2.95, 0.0, IO)
	gust.key(&"raise", 0.0, 0.0).key(&"raise", 0.12, 0.0, H).key(&"raise", 0.9, 1.05, IO).key(&"raise", 1.0, 1.05) \
		.key(&"raise", 1.28, -0.4, I).key(&"raise", 1.7, -0.3, O).key(&"raise", 2.8, 0.0, IO)
	gust.key(&"beat", 0.0, 0.0).key(&"beat", 1.0, 0.0, H).key(&"beat", 1.28, 2.1, O).key(&"beat", 2.0, 2.0).key(&"beat", 2.9, 0.0, IO)
	gust.key(&"rock", 0.0, 0.0).key(&"rock", 0.8, 0.09, IO).key(&"rock", 1.0, 0.09).key(&"rock", 1.3, -0.1, I).key(&"rock", 2.6, 0.0, IO)
	gust.key(&"rise", 0.0, 0.0).key(&"rise", 0.8, 0.06, IO).key(&"rise", 1.3, -0.08, I).key(&"rise", 2.6, 0.0, IO)
	gust.key(&"toss", 0.0, 0.0).key(&"toss", 0.8, 0.28, IO).key(&"toss", 1.3, -0.25, I).key(&"toss", 2.6, 0.0, IO)
	_clips[A.GUST] = gust
	# the stomp: a dip onto the haunches (anticipation), up onto the hind
	# hooves, the fore hooves pawing the air; it hangs a beat; at 1.0 it
	# crashes down (lunging forward) onto the stomp point; it settles
	var stomp := MotionClip.new()
	stomp.key(&"rear", 0.0, 0.0).key(&"rear", 0.1, -0.05, IO).key(&"rear", 0.6, 0.78, O).key(&"rear", 0.78, 0.8) \
		.key(&"rear", 1.0, -0.05, I).key(&"rear", 1.3, 0.02, BK).key(&"rear", 2.4, 0.0, IO)
	stomp.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.12, 0.1, IO).key(&"crouch", 0.6, 0.04, IO).key(&"crouch", 1.0, 0.14, I).key(&"crouch", 1.6, 0.0, IO)
	stomp.key(&"lunge", 0.0, 0.0).key(&"lunge", 0.78, 0.0, H).key(&"lunge", 1.0, 0.4, I).key(&"lunge", 2.0, 0.4).key(&"lunge", 2.9, 0.0, IO)
	stomp.key(&"paw", 0.0, 0.0).key(&"paw", 0.2, 0.0, H).key(&"paw", 0.55, 1.0, IO).key(&"paw", 0.8, 1.0).key(&"paw", 0.97, 0.0, I)
	stomp.key(&"strike", 0.0, 0.0).key(&"strike", 0.72, 0.0, H).key(&"strike", 1.0, 1.0, I).key(&"strike", 3.0, 1.0)
	stomp.key(&"toss", 0.0, 0.0).key(&"toss", 0.6, 0.3, O).key(&"toss", 1.0, -0.25, I).key(&"toss", 2.2, 0.0, IO)
	stomp.key(&"wings", 0.0, 0.0).key(&"wings", 0.6, 0.5, IO).key(&"wings", 1.0, 0.3, IO).key(&"wings", 2.5, 0.0, IO)
	_clips[A.STOMP] = stomp
	# the hop: a crouch (the wings spread), the leap with its nose up (the
	# node flies the body; the wings beat), the landing squat, the rise
	var hop := MotionClip.new()
	hop.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.22, 0.32, IO).key(&"crouch", 0.28, 0.28).key(&"crouch", 0.36, -0.05, O).key(&"crouch", 0.6, 0.0, IO) \
		.key(&"crouch", 1.0, 0.0, H).key(&"crouch", 1.35, 0.35, I).key(&"crouch", 2.0, 0.3, IO).key(&"crouch", 2.9, 0.0, IO)
	hop.key(&"pitch", 0.0, 0.0).key(&"pitch", 0.22, -0.06, IO).key(&"pitch", 0.36, 0.22, O).key(&"pitch", 0.8, 0.05, IO).key(&"pitch", 1.0, -0.08, IO) \
		.key(&"pitch", 1.35, -0.14, I).key(&"pitch", 2.6, 0.0, IO)
	hop.key(&"spread", 0.0, 0.0).key(&"spread", 0.25, 1.2, O).key(&"spread", 2.0, 1.1).key(&"spread", 2.9, 0.0, IO)
	hop.key(&"raise", 0.0, 0.0).key(&"raise", 0.28, 0.6, O).key(&"raise", 1.0, 0.6).key(&"raise", 1.3, 0.95, O).key(&"raise", 2.8, 0.0, IO)
	hop.key(&"flap", 0.0, 0.0).key(&"flap", 0.3, 0.0, H).key(&"flap", 0.4, 1.0, O).key(&"flap", 0.95, 1.0).key(&"flap", 1.1, 0.0, IO)
	hop.key(&"toss", 0.0, 0.0).key(&"toss", 0.22, -0.2, IO).key(&"toss", 0.4, 0.3, O).key(&"toss", 1.0, 0.1).key(&"toss", 1.35, -0.3, I).key(&"toss", 2.4, 0.0, IO)
	_clips[A.HOP] = hop
	# the stun: it sags, the head hangs and shakes as it hits, hangs, shakes
	# again as it gathers itself
	_stun = MotionClip.new()
	_stun.key(&"reel", 0.0, 0.0).key(&"reel", 0.12, 1.0, O).key(&"reel", 0.82, 1.0).key(&"reel", 1.0, 0.0, IO)
	_stun.key(&"shake", 0.0, 0.0).key(&"shake", 0.05, 1.0, O).key(&"shake", 0.3, 0.0, IO).key(&"shake", 0.75, 0.0, H).key(&"shake", 0.85, 1.0, IO).key(&"shake", 1.0, 0.0, IO)
	# the waking (progress): dust shivers off it, the eyes light, the head
	# lifts and turns to the guard, the wings creak half open and settle;
	# a shake of the head as it stands on the floor
	_wake = MotionClip.new()
	_wake.key(&"eyes", 0.0, 0.0).key(&"eyes", 0.1, 1.0, O)
	_wake.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.04, 0.012, O).key(&"shiver", 0.22, 0.024, I).key(&"shiver", 0.32, 0.0, O)
	_wake.key(&"head", 0.0, -0.22).key(&"head", 0.08, -0.22, H).key(&"head", 0.28, 0.18, O).key(&"head", 0.5, 0.0, IO)
	_wake.key(&"turn", 0.0, 0.0).key(&"turn", 0.1, 0.0, H).key(&"turn", 0.3, 1.0, IO)
	_wake.key(&"spread", 0.0, 0.0).key(&"spread", 0.12, 0.0, H).key(&"spread", 0.3, 0.55, O).key(&"spread", 0.5, 0.45).key(&"spread", 0.9, 0.12, IO)
	_wake.key(&"raise", 0.0, 0.0).key(&"raise", 0.12, 0.0, H).key(&"raise", 0.3, 0.35, O).key(&"raise", 0.9, 0.0, IO)
	_wake.key(&"shake", 0.0, 0.0).key(&"shake", 0.88, 0.0, H).key(&"shake", 0.92, 1.0, IO).key(&"shake", 1.0, 0.0, IO)
	_wake.key(&"tail", 0.0, 0.0).key(&"tail", 0.3, 0.4, IO).key(&"tail", 1.0, 0.15, IO)
	# phase 2: it rears up with its wings wide and raised, bellows (the
	# cracks blaze from the middle of it), crashes down, shakes its head
	_shift2 = MotionClip.new()
	_shift2.key(&"rear", 0.0, 0.0).key(&"rear", 0.08, -0.05, IO).key(&"rear", 0.35, 0.8, O).key(&"rear", 0.58, 0.85).key(&"rear", 0.7, -0.05, I).key(&"rear", 0.85, 0.0, BK)
	_shift2.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.08, 0.1, IO).key(&"crouch", 0.35, 0.04, IO).key(&"crouch", 0.7, 0.14, I).key(&"crouch", 0.95, 0.0, IO)
	_shift2.key(&"paw", 0.0, 0.0).key(&"paw", 0.15, 0.0, H).key(&"paw", 0.35, 1.0, IO).key(&"paw", 0.6, 1.0).key(&"paw", 0.69, 0.0, I)
	_shift2.key(&"spread", 0.0, 0.0).key(&"spread", 0.3, 1.25, O).key(&"spread", 0.75, 1.2).key(&"spread", 1.0, 0.0, IO)
	_shift2.key(&"raise", 0.0, 0.0).key(&"raise", 0.3, 1.0, O).key(&"raise", 0.75, 0.9).key(&"raise", 1.0, 0.0, IO)
	_shift2.key(&"bellow", 0.0, 0.0).key(&"bellow", 0.35, 0.4, O).key(&"bellow", 0.6, 0.35).key(&"bellow", 0.75, -0.15, I).key(&"bellow", 1.0, 0.0, IO)
	_shift2.key(&"shake", 0.0, 0.0).key(&"shake", 0.8, 0.0, H).key(&"shake", 0.86, 1.0, IO).key(&"shake", 1.0, 0.0, IO)
	_shift2.key(&"cracks", 0.0, 0.0).key(&"cracks", 0.42, 0.0, H).key(&"cracks", 0.5, 2.0, O).key(&"cracks", 1.0, 1.2, IO)
	_shift2.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.4, 0.0, H).key(&"shiver", 0.45, 0.02, O).key(&"shiver", 0.6, 0.0, IO)
	# phase 3: the wings spread and beat three times, lifting it off the
	# floor; it hangs, drops heavily and squats on the landing
	_shift3 = MotionClip.new()
	_shift3.key(&"spread", 0.0, 0.0).key(&"spread", 0.15, 1.2, O).key(&"spread", 0.9, 1.1).key(&"spread", 1.0, 0.3, IO)
	_shift3.key(&"beat", 0.0, 0.0).key(&"beat", 0.12, 0.0, H).key(&"beat", 0.22, 1.7, I).key(&"beat", 0.34, 0.3, O).key(&"beat", 0.46, 1.7, I) \
		.key(&"beat", 0.58, 0.3, O).key(&"beat", 0.7, 1.7, I).key(&"beat", 0.82, 0.4, O).key(&"beat", 1.0, 0.0, IO)
	_shift3.key(&"raise", 0.0, 0.0).key(&"raise", 0.12, 0.9, O).key(&"raise", 0.22, -0.3, I).key(&"raise", 0.34, 0.9, O).key(&"raise", 0.46, -0.3, I) \
		.key(&"raise", 0.58, 0.9, O).key(&"raise", 0.7, -0.3, I).key(&"raise", 0.82, 0.8, O).key(&"raise", 1.0, 0.0, IO)
	_shift3.key(&"hover", 0.0, 0.0).key(&"hover", 0.2, 0.0, H).key(&"hover", 0.5, 1.0, O).key(&"hover", 0.78, 1.0).key(&"hover", 0.88, 0.0, I)
	_shift3.key(&"squat", 0.0, 0.0).key(&"squat", 0.88, 0.0, H).key(&"squat", 0.92, 0.3, O).key(&"squat", 1.0, 0.0, IO)
	_shift3.key(&"pitch", 0.0, 0.0).key(&"pitch", 0.3, 0.12, IO).key(&"pitch", 0.8, 0.08).key(&"pitch", 0.92, -0.1, I).key(&"pitch", 1.0, 0.0, IO)
	_shift3.key(&"toss", 0.0, 0.0).key(&"toss", 0.3, 0.25, IO).key(&"toss", 0.92, -0.2, I).key(&"toss", 1.0, 0.0, IO)
