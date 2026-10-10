class_name CentaurMoves
extends RefCounted
## The Centaur's choreography: from the brain's moment, the gait's hooves
## and the fight's points (set by the Centaur each frame, body space) it
## composes the Pose its rig shows, in two layers:
## 1. LOCOMOTION, always: the hooves where the gait has them (planted in the
##    world, swinging in arcs, curling back in the swing); the barrel bobs
##    and rocks with the stride (a gallop's rocking-horse pitch, a trot's
##    double bounce), crouches as it speeds up and banks into turns; the
##    human torso keeps itself upright against the barrel's pitch, leans
##    forward into the gallop and further into the turn, twists toward the
##    guard; the head follows the guard a moment late (springs) and steadies
##    against the bob; the tail streams out at speed, lags the barrel's
##    pitch, swings out of turns and swishes when it slows.
## 2. ACTION, a MotionClip per attack sampled at the brain's clip_time()
##    (0..1 warning, 1..2 strike, 2..3 recovery), laid over the first: the
##    throw (the torso winds back, the arm draws the javelin behind the
##    shoulder, the other arm points; a whip, the javelin leaves at 1.0, a
##    follow-through; a new javelin forms in the hand), the rearing kick
##    (it rocks back on its haunches, rises on its hind hooves pawing the air,
##    crashes down onto the mark at 1.0), the buck (weight on the fore legs,
##    a look back over the shoulder, the hind hooves lash out at 1.0), the
##    charge (the torso drops, the javelin levels like a lance, a fore hoof
##    scrapes the floor twice), the stun (it reels: the head hangs and shakes,
##    the legs splay, the chest blazes), the call (it rears with the javelin
##    raised and cries out), the tear (the left hand rips the metope's piece
##    off its flank and flings it; a javelin forms in that hand); and the
##    waking (it strains against its metope, rears, breaks free, comes down
##    and shakes its head).
## Principles (docs/superpowers/plans/2026-10-03-straznik-kentaur.md):
## anticipation before every blow, ease in and out, overshoot and settle,
## follow-through on springs, contacts that land exactly on their marks.

const S := CentaurBrain.State
const A := CentaurBrain.Attack
const G := CentaurGait.Gait
## The rear's pivot: the hind fetlocks (body space); the buck's: the fore.
const HIND_PIVOT := Vector3(0.0, 0.17, 0.84)
const FORE_PIVOT := Vector3(0.0, 0.17, -0.68)
## Head limits on the torso (rad).
const NECK_YAW := 1.0
const NECK_PITCH := Vector2(-0.7, 0.45)
## How far the torso twists toward the guard roaming, and at most.
const TWIST := 0.55
const TWIST_MAX := 1.45
## The wrist of the javelin hand in its carved "ready" pose, torso space
## (the left hand mirrors it in phase 3).
const READY_WRIST := Vector3(0.46, 1.04, -0.08)

var rig: CentaurRig
var pose := CentaurRig.Pose.new()

# --- the fight's points, body space (set by the Centaur) -------------------------
## The guard's chest.
var guard := Vector3(0.0, 1.5, -12.0)
## Where each javelin (left, right) leaves along: its launch direction.
var throw_dir: Array[Vector3] = [Vector3(0.0, 0.3, -1.0).normalized(), Vector3(0.0, 0.3, -1.0).normalized()]

## The charge's hoof scrape touches the floor now (dust).
var scraping := false
var time: float = 0.0

var _clips: Dictionary = {}
var _wake: MotionClip
var _stun: MotionClip
var _look_yaw := Spring.new(1.6, 0.6)
var _look_pitch := Spring.new(1.6, 0.7)
var _twist := Spring.new(1.1, 0.75)
var _roll := Spring.new(1.4, 0.8)
var _lean := Spring.new(1.2, 0.7)
var _tail_lift := Spring.new(1.6, 0.35)
var _tail_swish := Spring.new(1.3, 0.3)
var _tail_tip := Spring.new(2.2, 0.3)
var _tail_tip_swish := Spring.new(1.8, 0.3)
var _flinch := Spring.new(3.0, 0.4)
var _head_bob := Spring.new(3.5, 0.5)
var _pitch_before: float = 0.0
var _delta: float = 0.0


func _init(for_rig: CentaurRig) -> void:
	rig = for_rig
	_build_clips()


## The pose for [param brain]'s moment, the [param gait]'s hooves and the
## body at [param body] (world), advanced by [param delta].
func compose(brain: CentaurBrain, gait: CentaurGait, body: Transform3D, delta: float) -> CentaurRig.Pose:
	time += delta
	_delta = delta
	_reset_pose()
	scraping = false
	if brain.state == S.DORMANT:
		_settle_springs()
		return pose   # the museum piece, exactly
	pose.eyes = 1.0
	pose.slab_on = not brain.pair and not (brain.attack == A.TEAR and brain.clip_time() >= 1.0)
	pose.javelin_shown[0] = brain.pair
	_locomotion(gait, body, delta)
	pose.torso.x += _flinch.step(0.0, delta)
	# the torso's twist first (the arms reach from where the shoulders are)
	var twist_to := clampf(_bearing_of(guard) * TWIST, -TWIST * 1.6, TWIST * 1.6)
	var t := brain.clip_time()
	var direct := false
	match brain.state:
		S.WAKING:
			twist_to *= _wake.sample(&"turn", brain.state_progress())
		S.STUNNED:
			twist_to *= 0.3
		S.ATTACK:
			match brain.attack:
				A.THROW:
					twist_to = _throw_twist(t)
					direct = true
				A.BUCK:
					twist_to = clampf(_bearing_of(guard) * 0.85, -TWIST_MAX, TWIST_MAX) * _clips[A.BUCK].sample(&"look", t)
				A.CHARGE:
					twist_to *= 0.2
				A.TEAR:
					twist_to = 0.35
	if direct:
		_twist.reset(clampf(twist_to, -TWIST_MAX, TWIST_MAX))
		pose.torso.y += _twist.value
	else:
		pose.torso.y += _twist.step(clampf(twist_to, -TWIST_MAX, TWIST_MAX), delta)
	var hold_ready := brain.pair
	match brain.state:
		S.WAKING:
			_waking(brain.state_progress())
		S.STUNNED:
			_stunned(brain.state_progress())
		S.ATTACK:
			match brain.attack:
				A.THROW:
					_throw(t, brain.pair)
					hold_ready = false
				A.KICK:
					_kick(t)
				A.BUCK:
					_buck(t)
				A.CHARGE:
					_charge(t)
				A.CALL:
					_call(t)
				A.TEAR:
					_tear(t)
					hold_ready = false
	if hold_ready:
		_hold_left_javelin(1.0)
	_look(guard, delta)
	return pose


## A hit landed: the torso flinches back.
func flinch(amount: float = 1.0) -> void:
	_flinch.kick(1.2 * amount)


## The guard fled, it stands in its metope again: springs at rest.
func reset() -> void:
	_settle_springs()


func _settle_springs() -> void:
	for spring: Spring in [_look_yaw, _look_pitch, _twist, _roll, _lean, _tail_lift, _tail_swish, _tail_tip, _tail_tip_swish, _flinch, _head_bob]:
		spring.reset(0.0)


func _reset_pose() -> void:
	var p := pose
	p.barrel = CentaurRig.BARREL_REST
	p.barrel_turn = Vector3.ZERO
	p.legs_ik = 0.0
	for leg in 4:
		p.hoof_pitch[leg] = 0.0
	p.tail = Vector2.ZERO
	p.tail_tip = Vector2.ZERO
	p.torso = Vector3.ZERO
	p.neck = Vector3.ZERO
	for side in 2:
		p.arm_aim[side] = 0.0
		p.javelin_aim[side] = 0.0
		p.glint[side] = 0.0
		p.hoof_glint[side] = 0.0
	p.elbow_pole[0] = Vector3(-1.0, -0.6, 0.4)
	p.elbow_pole[1] = Vector3(1.0, -0.6, 0.4)
	p.javelin_shown[1] = true
	p.javelin_shown[0] = false
	p.slab_on = true
	p.eyes = 0.0
	p.cracks = 0.0
	p.shiver = 0.0


# --- locomotion ------------------------------------------------------------------

func _locomotion(gait: CentaurGait, body: Transform3D, delta: float) -> void:
	var inverse := body.affine_inverse()
	var run := clampf(gait.speed / 7.0, 0.0, 1.0)
	for leg in 4:
		pose.hooves[leg] = inverse * gait.hoof(leg)
		var w := gait.swing(leg)
		# the hoof flips back as the leg folds in the swing
		pose.hoof_pitch[leg] = -(1.45 if leg < 2 else 1.0) * sin(PI * pow(w, 0.7)) * lerpf(0.45, 1.0, run)
	pose.legs_ik = 1.0
	var c := gait.cycle
	var stepping := 1.0 if gait.stepping else 0.0
	var gallop := gait.weight(G.GALLOP) * stepping
	var canter := gait.weight(G.CANTER) * stepping
	var trot := gait.weight(G.TROT) * stepping
	var walk := gait.weight(G.WALK) * stepping * clampf(gait.speed / 1.0, 0.0, 1.0)
	# the rocking-horse pitch of the gallop and canter (nose up while the hind
	# legs push, down as the fore legs land), the trot's double bounce
	var bob := gallop * 0.05 * cos(TAU * (c - 0.82)) * run + canter * 0.045 * cos(TAU * (c - 0.72)) \
		+ trot * 0.028 * cos(2.0 * TAU * (c - 0.43)) + walk * 0.014 * cos(2.0 * TAU * (c - 0.1))
	var pitch := gallop * 0.075 * cos(TAU * (c - 0.15)) * run + canter * 0.06 * cos(TAU * (c - 0.08)) \
		+ walk * 0.012 * sin(2.0 * TAU * c)
	var crouch := (gallop * 0.075 + canter * 0.035 + trot * 0.012) * run
	pose.barrel = Vector3(0.0, CentaurRig.BARREL_REST.y - crouch + bob, 0.0)
	pose.barrel_turn.x = pitch
	# it banks into a turn, the faster the more; the gallop sways over its lead
	var bank := clampf(gait.yaw_rate * gait.speed * 0.028, -0.3, 0.3)
	var roll := _roll.step(bank, delta)
	pose.barrel_turn.z = roll + gallop * gait.lead * 0.025 * sin(TAU * c) + trot * 0.012 * sin(TAU * c)
	# the human torso: steady over the pitch, forward into the run, into the
	# turn more than the barrel
	pose.torso.x = -0.7 * pitch + _lean.step(-(gallop * 0.16 + canter * 0.08) * run, delta)
	pose.torso.z = roll * 0.9
	# the head steadies against the bob (a moment late)
	pose.neck.x = -_head_bob.step(bob * 3.0 + pitch * 0.8, delta)
	# the tail: out behind at speed, lagging the pitch, out of the turns,
	# swishing when it slows
	var pitch_speed := (pitch - _pitch_before) / maxf(delta, 0.001)
	_pitch_before = pitch
	_tail_lift.kick(-pitch_speed * 0.02)
	var lift := _tail_lift.step(0.12 + 0.75 * gallop * run + 0.4 * canter + 0.15 * trot, delta)
	var swish_to := -gait.yaw_rate * 0.3 + sin(time * 1.1) * 0.22 * (1.0 - run) + sin(time * 0.37) * 0.08
	var swish := _tail_swish.step(swish_to, delta)
	pose.tail = Vector2(lift, swish)
	pose.tail_tip = Vector2(_tail_tip.step(lift * 0.55, delta) - lift * 0.15, _tail_tip_swish.step(swish * 0.8, delta))


# --- the attacks -----------------------------------------------------------------

## The throw's torso twist: toward the throw, wound back, whipped through.
func _throw_twist(t: float) -> float:
	var aim_twist := clampf(_bearing_of_dir(throw_dir[1]) * 0.85, -TWIST_MAX, TWIST_MAX)
	return aim_twist - 0.55 * _clips[A.THROW].sample(&"wind", t)


## The throw: the arm draws the javelin behind the shoulder, whips it out
## at 1.0 and follows through; the free arm sights along it (or, in phase
## 3, throws its own a beat later).
func _throw(t: float, pair: bool) -> void:
	var clip: MotionClip = _clips[A.THROW]
	pose.torso.x += clip.sample(&"lean", t)
	pose.torso.z += clip.sample(&"tilt", t)
	_throw_arm(1, clip.sample(&"draw", t), clip.sample(&"whip", t), clip.sample(&"follow", t), clip.sample(&"back", t))
	pose.javelin_shown[1] = t < 1.0 or t >= 2.55
	pose.glint[1] = clip.sample(&"glint", t) + (clip.sample(&"form", t) if t >= 2.55 else 0.0)
	if pair:
		_throw_arm(0, clip.sample(&"draw", t), clip.sample(&"whip_l", t), clip.sample(&"follow_l", t), clip.sample(&"back", t))
		pose.javelin_shown[0] = t < 1.43 or t >= 2.6
		pose.glint[0] = clip.sample(&"glint_l", t) + (clip.sample(&"form", t) if t >= 2.6 else 0.0)
	else:
		# the free arm points at the mark, then pulls back to the hip
		var point := clip.sample(&"point", t)
		if point > 0.0:
			var shoulder := rig.shoulder_at(pose, 0)
			var flat := _flat(throw_dir[1])
			pose.arm_aim[0] = point
			pose.wrist[0] = shoulder + flat * 0.6 + Vector3.UP * 0.1
			pose.elbow_pole[0] = Vector3(-1.0, -0.4, 0.0)


## One arm's throw: [param draw] behind the shoulder, [param whip] to the
## release in front, [param follow] down across the body, [param back] to
## the javelin held ready.
func _throw_arm(side: int, draw: float, whip: float, follow: float, back: float) -> void:
	var shoulder := rig.shoulder_at(pose, side)
	var direction := throw_dir[side]
	var flat := _flat(direction)
	var out := flat.cross(Vector3.UP) * (1.0 if side == 1 else -1.0)
	var ready := _ready_wrist(side)
	var drawn := shoulder - flat * 0.4 + Vector3.UP * 0.27 + out * 0.14
	var release := shoulder + direction * 0.52 + Vector3.UP * 0.05
	var through := shoulder + flat * 0.3 + Vector3.DOWN * 0.4 - out * 0.22
	var wrist := ready.lerp(drawn, draw).lerp(release, whip).lerp(through, follow).lerp(ready, back)
	# (the left arm throws only in phase 3: it holds its javelin ready by IK
	# before and after)
	var held := side == 0
	pose.arm_aim[side] = 1.0 if held else clampf(maxf(draw, whip) * (1.0 - back), 0.0, 1.0)
	pose.wrist[side] = wrist
	pose.elbow_pole[side] = out + Vector3.DOWN * 0.55 + flat * -0.2
	# the javelin points up its arc as it is drawn, along its launch at the whip
	var lofted := (direction + Vector3.UP * 0.35).normalized()
	var ready_dir := rig.torso_xform(pose).basis * Vector3.FORWARD
	var line := ready_dir.lerp(lofted, draw).lerp(direction, whip).lerp(ready_dir, back)
	pose.javelin_aim[side] = 1.0 if held else clampf(draw + whip, 0.0, 1.0) * (1.0 - back)
	pose.javelin_dir[side] = line.normalized() if line.length() > 0.001 else direction


## The left hand's javelin held ready over the left shoulder (phase 3).
func _hold_left_javelin(weight: float) -> void:
	pose.arm_aim[0] = maxf(pose.arm_aim[0], weight)
	pose.wrist[0] = _ready_wrist(0)
	pose.elbow_pole[0] = Vector3(-1.0, 0.1, 0.3)
	pose.javelin_aim[0] = weight
	pose.javelin_dir[0] = rig.torso_xform(pose).basis * Vector3.FORWARD


## Where hand [param side] holds its javelin ready (body space).
func _ready_wrist(side: int) -> Vector3:
	var local := READY_WRIST if side == 1 else Vector3(-READY_WRIST.x, READY_WRIST.y, READY_WRIST.z)
	return rig.torso_xform(pose) * local


func _kick(t: float) -> void:
	var clip: MotionClip = _clips[A.KICK]
	var rear := clip.sample(&"rear", t)
	_pivot(HIND_PIVOT, rear, clip.sample(&"lunge", t), clip.sample(&"crouch", t))
	# the fore hooves paw the air on the way up, then strike the mark
	var paw := clip.sample(&"paw", t)
	var strike := clip.sample(&"strike", t)
	var barrel := CentaurRig.barrel_xform(pose)
	for leg in 2:
		var side := -1.0 if leg == 0 else 1.0
		var root := rig.leg_root(pose, leg)
		var stroke := time * 13.0 + float(leg) * PI
		var tucked := root + barrel.basis * Vector3(0.0, -0.42 + 0.12 * sin(stroke), -0.3 + 0.14 * cos(stroke))
		var landing := Vector3(side * 0.24, CentaurGait.HOOF_HEIGHT, -CentaurBrain.KICK_REACH)
		var hoof := pose.hooves[leg].lerp(tucked, paw)
		pose.hooves[leg] = hoof.lerp(landing, strike)
		pose.hoof_pitch[leg] = lerpf(pose.hoof_pitch[leg], -1.2, paw * (1.0 - strike))
	pose.hoof_glint[0] = clip.sample(&"glint", t)
	pose.torso.x += -0.75 * pose.barrel_turn.x + clip.sample(&"lean", t)
	pose.neck.x += clip.sample(&"toss", t)
	pose.tail.x -= rear * 0.9
	_raise_arms(clip.sample(&"arms", t), 0.0)


func _buck(t: float) -> void:
	var clip: MotionClip = _clips[A.BUCK]
	var tip := clip.sample(&"tip", t)
	_pivot(FORE_PIVOT, -tip, clip.sample(&"shift", t), 0.0)
	var tuck := clip.sample(&"tuck", t)
	var lash := clip.sample(&"lash", t)
	var barrel := CentaurRig.barrel_xform(pose)
	for leg in [2, 3]:
		var root := rig.leg_root(pose, leg)
		var tucked := root + barrel.basis * Vector3(0.0, -0.5, -0.12)
		var lashed := root + barrel.basis * Vector3(0.0, -0.32, 0.86)
		var hoof := pose.hooves[leg].lerp(tucked, tuck)
		pose.hooves[leg] = hoof.lerp(lashed, lash)
		pose.hoof_pitch[leg] = lerpf(pose.hoof_pitch[leg], 0.9, lash)
	pose.hoof_glint[1] = clip.sample(&"glint", t)
	pose.torso.x += 0.6 * tip + clip.sample(&"lean", t)
	pose.tail.x += lash * 0.9
	pose.tail.y += sin(time * 11.0) * 0.3 * tuck


func _charge(t: float) -> void:
	var clip: MotionClip = _clips[A.CHARGE]
	var low := clip.sample(&"low", t)
	pose.torso.x += -0.45 * low
	pose.neck.x += -0.2 * low
	pose.barrel_turn.x += clip.sample(&"rock", t)
	# the javelin levelled like a lance
	var level := clip.sample(&"level", t)
	if level > 0.0:
		var shoulder := rig.shoulder_at(pose, 1)
		pose.arm_aim[1] = level
		pose.wrist[1] = shoulder + Vector3(0.06, -0.16, -0.42)
		pose.elbow_pole[1] = Vector3(1.0, -0.8, 0.5)
		pose.javelin_aim[1] = level
		pose.javelin_dir[1] = Vector3(0.0, -0.08, -1.0).normalized()
	# a fore hoof scrapes the floor twice: up and forward, then dragged back
	var scrape := clip.sample(&"scrape", t)
	if scrape > 0.0:
		var stroke := fposmod(clip.sample(&"stroke", t), 1.0)
		var reach := Vector3(0.0, 0.2 * sin(PI * clampf(stroke / 0.45, 0.0, 1.0)), -0.38 * (1.0 - stroke))
		if stroke > 0.45:
			reach = Vector3(0.0, 0.0, -0.38 + 0.66 * (stroke - 0.45) / 0.55)
			scraping = true
		var rest := pose.hooves[1]
		pose.hooves[1] = rest.lerp(Vector3(rest.x + 0.04, CentaurGait.HOOF_HEIGHT, rest.z) + reach, scrape)
		pose.hoof_pitch[1] = lerpf(pose.hoof_pitch[1], 0.35 if scraping else -0.6, scrape)
	pose.tail.y += sin(time * 9.0) * 0.45 * clip.sample(&"lash", t)
	pose.tail.x += 0.3 * low


func _stunned(u: float) -> void:
	var clip := _stun
	var reel := clip.sample(&"reel", u)
	pose.barrel_turn.x += -0.09 * reel + 0.04 * sin(time * 2.3) * reel
	pose.barrel_turn.z += 0.09 * sin(time * 1.7) * reel
	pose.barrel.y -= 0.08 * reel
	pose.hooves[0].x -= 0.16 * reel
	pose.hooves[1].x += 0.16 * reel
	pose.torso.x += -0.5 * reel
	pose.torso.z += 0.12 * sin(time * 1.3) * reel
	pose.neck.x += -0.5 * reel
	pose.neck.y += 0.4 * sin(time * 10.0) * clip.sample(&"shake", u)
	pose.cracks = maxf(pose.cracks, 1.4 + 0.5 * sin(time * 7.0)) * reel
	pose.shiver = 0.006 * reel
	# the arms hang, the javelin dangles
	var shoulder := rig.shoulder_at(pose, 1)
	pose.arm_aim[1] = reel
	pose.wrist[1] = shoulder + Vector3(0.12, -0.52, -0.16)
	pose.elbow_pole[1] = Vector3(1.0, 0.0, 0.6)
	pose.javelin_aim[1] = reel
	pose.javelin_dir[1] = Vector3(0.0, -0.75, -0.66).normalized()
	pose.arm_aim[0] = maxf(pose.arm_aim[0], reel)
	pose.wrist[0] = rig.shoulder_at(pose, 0) + Vector3(-0.1, -0.6, -0.12)
	pose.tail.x -= 0.3 * reel


func _call(t: float) -> void:
	var clip: MotionClip = _clips[A.CALL]
	var rear := clip.sample(&"rear", t)
	_pivot(HIND_PIVOT, rear, 0.0, clip.sample(&"crouch", t))
	for leg in 2:
		var root := rig.leg_root(pose, leg)
		var tucked := root + CentaurRig.barrel_xform(pose).basis * Vector3(0.0, -0.45, -0.28)
		pose.hooves[leg] = pose.hooves[leg].lerp(tucked, clip.sample(&"paw", t))
	pose.torso.x += -0.6 * pose.barrel_turn.x + clip.sample(&"lean", t)
	pose.neck.x += clip.sample(&"cry", t)
	pose.tail.x -= rear * 0.8
	_raise_arms(clip.sample(&"arms", t), clip.sample(&"arms", t))


func _tear(t: float) -> void:
	var clip: MotionClip = _clips[A.TEAR]
	pose.torso.z += clip.sample(&"bend", t)
	pose.torso.x += clip.sample(&"lean", t)
	pose.neck.x += clip.sample(&"look", t)
	var grab := clip.sample(&"grab", t)
	var fling := clip.sample(&"fling", t)
	var hold := clip.sample(&"hold", t)
	var shoulder := rig.shoulder_at(pose, 0)
	var slab := CentaurRig.barrel_xform(pose) * ((rig.rest["slab"] as Transform3D).origin + Vector3(-0.08, 0.62, -0.25))
	var flung := shoulder + Vector3(-0.5, 0.32, -0.12)
	var wrist := rig.carved_wrist(pose, 0).lerp(slab, grab).lerp(flung, fling).lerp(_ready_wrist(0), hold)
	pose.arm_aim[0] = 1.0
	pose.wrist[0] = wrist
	pose.elbow_pole[0] = Vector3(-1.0, 0.2 * fling, 0.4)
	pose.javelin_shown[0] = t >= 2.4
	pose.glint[0] = clip.sample(&"form", t)
	pose.javelin_aim[0] = hold
	pose.javelin_dir[0] = rig.torso_xform(pose).basis * Vector3.FORWARD
	pose.barrel_turn.z += clip.sample(&"heave", t)


## The waking (progress [param u]).
func _waking(u: float) -> void:
	var clip := _wake
	pose.eyes = clip.sample(&"eyes", u)
	pose.shiver = clip.sample(&"shiver", u)
	pose.legs_ik = clip.sample(&"legs", u)
	var rear := clip.sample(&"rear", u)
	_pivot(HIND_PIVOT, rear, clip.sample(&"lunge", u), clip.sample(&"crouch", u))
	for leg in 2:
		var root := rig.leg_root(pose, leg)
		var tucked := root + CentaurRig.barrel_xform(pose).basis * Vector3(0.0, -0.42, -0.3)
		pose.hooves[leg] = pose.hooves[leg].lerp(tucked, clip.sample(&"paw", u))
	pose.torso.x += -0.7 * pose.barrel_turn.x + clip.sample(&"lean", u)
	pose.neck.x += clip.sample(&"toss", u)
	pose.neck.y += 0.45 * sin(time * 11.0) * clip.sample(&"shake", u)
	pose.tail.x += clip.sample(&"tail", u) - rear * 0.7
	_raise_arms(clip.sample(&"arms", u), clip.sample(&"arms", u) * 0.6)


## Rotates the barrel by [param pitch] about [param pivot] (body space; the
## hind fetlocks for a rear, the fore for a buck), carried [param shift]
## forward and [param crouch] down.
func _pivot(pivot: Vector3, pitch: float, shift: float, crouch: float) -> void:
	var turn := Basis(Vector3.RIGHT, pitch)
	var low := pivot + Vector3.DOWN * crouch
	pose.barrel = low + turn * (pose.barrel - low) + Vector3.FORWARD * shift
	pose.barrel_turn.x += pitch


## Arms up (a rear, the call): the javelin raised high in the right hand,
## the left arm out for balance.
func _raise_arms(right: float, left: float) -> void:
	if right > 0.0:
		var shoulder := rig.shoulder_at(pose, 1)
		var torso := rig.torso_xform(pose).basis
		pose.arm_aim[1] = right
		pose.wrist[1] = shoulder + torso * Vector3(0.1, 0.55, 0.05)
		pose.elbow_pole[1] = torso * Vector3(1.0, 0.2, 0.3)
		pose.javelin_aim[1] = right
		pose.javelin_dir[1] = torso * Vector3(0.0, 0.55, -1.0).normalized()
	if left > 0.0:
		var shoulder_l := rig.shoulder_at(pose, 0)
		var torso_l := rig.torso_xform(pose).basis
		pose.arm_aim[0] = maxf(pose.arm_aim[0], left)
		pose.wrist[0] = shoulder_l + torso_l * Vector3(-0.48, 0.24, -0.18)
		pose.elbow_pole[0] = torso_l * Vector3(-0.6, -1.0, 0.2)


# --- looking -----------------------------------------------------------------------

## The head turns to [param point] (springs: a moment late, a little past).
func _look(point: Vector3, delta: float) -> void:
	var torso := rig.torso_xform(pose)
	var neck := torso * (rig.rest["neck"] as Transform3D).origin
	var local := torso.basis.inverse() * (point - neck)
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, maxf(Vector2(local.x, local.z).length(), 0.01))
	pose.neck.y += _look_yaw.step(clampf(yaw, -NECK_YAW, NECK_YAW), delta)
	pose.neck.x += _look_pitch.step(clampf(pitch, NECK_PITCH.x, NECK_PITCH.y), delta)


## Bearing of a body-space point from the barrel (rad, + to its left).
func _bearing_of(point: Vector3) -> float:
	return atan2(-point.x, -point.z)


func _bearing_of_dir(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _flat(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD


# --- the clips ---------------------------------------------------------------------

func _build_clips() -> void:
	var I := MotionClip.IN
	var O := MotionClip.OUT
	var IO := MotionClip.IN_OUT
	var BK := MotionClip.OUT_BACK
	var H := MotionClip.HOLD
	# the throw: the torso winds back, leaning back, the javelin drawn behind
	# the shoulder and pointed up its arc, the free arm sighting along it, a
	# glint on the tip; at 1.0 the whip - the javelin leaves; the arm follows
	# through across the body, the torso leans into it and unwinds; a new
	# javelin forms in the hand
	var throw := MotionClip.new()
	throw.key(&"draw", 0.0, 0.0).key(&"draw", 0.82, 1.0, IO).key(&"draw", 0.94, 1.0)
	throw.key(&"whip", 0.0, 0.0).key(&"whip", 0.94, 0.0, H).key(&"whip", 1.04, 1.0, I)
	throw.key(&"follow", 0.0, 0.0).key(&"follow", 1.04, 0.0, H).key(&"follow", 1.7, 1.0, O)
	throw.key(&"back", 0.0, 0.0).key(&"back", 2.05, 0.0, H).key(&"back", 2.95, 1.0, IO)
	throw.key(&"whip_l", 0.0, 0.0).key(&"whip_l", 1.36, 0.0, H).key(&"whip_l", 1.46, 1.0, I)
	throw.key(&"follow_l", 0.0, 0.0).key(&"follow_l", 1.46, 0.0, H).key(&"follow_l", 1.95, 1.0, O)
	throw.key(&"wind", 0.0, 0.0).key(&"wind", 0.8, 1.0, IO).key(&"wind", 1.08, -0.5, I).key(&"wind", 1.5, -0.35, O).key(&"wind", 2.8, 0.0, IO)
	throw.key(&"lean", 0.0, 0.0).key(&"lean", 0.8, 0.14, IO).key(&"lean", 1.08, -0.3, I).key(&"lean", 1.6, -0.18, O).key(&"lean", 2.8, 0.0, IO)
	throw.key(&"tilt", 0.0, 0.0).key(&"tilt", 0.8, -0.1, IO).key(&"tilt", 1.1, 0.08, I).key(&"tilt", 2.6, 0.0, IO)
	throw.key(&"point", 0.0, 0.0).key(&"point", 0.15, 0.0, H).key(&"point", 0.65, 1.0, IO).key(&"point", 1.02, 1.0).key(&"point", 1.45, 0.0, IO)
	throw.key(&"glint", 0.0, 0.0).key(&"glint", 0.5, 0.0, H).key(&"glint", 0.85, 1.0, I).key(&"glint", 1.0, 0.3, O)
	throw.key(&"glint_l", 0.0, 0.0).key(&"glint_l", 0.5, 0.0, H).key(&"glint_l", 0.85, 1.0, I).key(&"glint_l", 1.43, 0.6).key(&"glint_l", 1.5, 0.0, O)
	throw.key(&"form", 0.0, 0.0).key(&"form", 2.55, 0.0, H).key(&"form", 2.65, 1.2, O).key(&"form", 3.0, 0.0, O)
	_clips[A.THROW] = throw
	# the rearing kick: a dip on the haunches (anticipation), up onto the hind
	# hooves pawing the air, the hooves glinting; it hangs a beat, crashes
	# down (impact exactly at 1.0) a stride forward onto the mark, settles
	var kick := MotionClip.new()
	kick.key(&"rear", 0.0, 0.0).key(&"rear", 0.1, -0.05, IO).key(&"rear", 0.55, 0.88, O).key(&"rear", 0.66, 0.9) \
		.key(&"rear", 1.0, -0.05, I).key(&"rear", 1.3, 0.02, BK).key(&"rear", 2.4, 0.0, IO)
	kick.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.12, 0.1, IO).key(&"crouch", 0.55, 0.06, IO).key(&"crouch", 1.0, 0.12, I).key(&"crouch", 1.5, 0.0, IO)
	kick.key(&"lunge", 0.0, 0.0).key(&"lunge", 0.66, 0.0, H).key(&"lunge", 1.0, 0.38, I).key(&"lunge", 2.6, 0.0, IO)
	kick.key(&"paw", 0.0, 0.0).key(&"paw", 0.2, 0.0, H).key(&"paw", 0.5, 1.0, IO).key(&"paw", 0.8, 1.0).key(&"paw", 0.96, 0.0, I)
	kick.key(&"strike", 0.0, 0.0).key(&"strike", 0.7, 0.0, H).key(&"strike", 1.0, 1.0, I).key(&"strike", 2.0, 1.0).key(&"strike", 2.8, 0.0, IO)
	kick.key(&"glint", 0.0, 0.0).key(&"glint", 0.3, 0.0, H).key(&"glint", 0.9, 1.0, I).key(&"glint", 1.25, 0.0, O)
	kick.key(&"lean", 0.0, 0.0).key(&"lean", 0.55, -0.2, IO).key(&"lean", 1.0, 0.1, I).key(&"lean", 2.5, 0.0, IO)
	kick.key(&"toss", 0.0, 0.0).key(&"toss", 0.55, 0.3, O).key(&"toss", 1.0, -0.25, I).key(&"toss", 2.2, 0.0, IO)
	kick.key(&"arms", 0.0, 0.0).key(&"arms", 0.5, 1.0, IO).key(&"arms", 1.0, 0.6, IO).key(&"arms", 2.6, 0.0, IO)
	_clips[A.KICK] = kick
	# the buck: weight forward over the fore legs, a look back over the
	# shoulder, the hind hooves tucked and glinting; at 1.0 they lash out
	# behind as the croup rises; it comes down and settles
	var buck := MotionClip.new()
	buck.key(&"tip", 0.0, 0.0).key(&"tip", 0.5, 0.06, IO).key(&"tip", 1.0, 0.18, I).key(&"tip", 1.12, 0.42, O).key(&"tip", 1.6, 0.3, IO).key(&"tip", 2.6, 0.0, IO)
	buck.key(&"shift", 0.0, 0.0).key(&"shift", 0.6, 0.14, IO).key(&"shift", 2.6, 0.0, IO)
	buck.key(&"tuck", 0.0, 0.0).key(&"tuck", 0.45, 0.0, H).key(&"tuck", 0.95, 1.0, IO).key(&"tuck", 1.0, 1.0).key(&"tuck", 1.15, 0.0, O)
	buck.key(&"lash", 0.0, 0.0).key(&"lash", 1.0, 0.0, H).key(&"lash", 1.12, 1.0, I).key(&"lash", 1.6, 0.9).key(&"lash", 2.4, 0.0, IO)
	buck.key(&"glint", 0.0, 0.0).key(&"glint", 0.3, 0.0, H).key(&"glint", 0.95, 1.0, I).key(&"glint", 1.3, 0.0, O)
	buck.key(&"lean", 0.0, 0.0).key(&"lean", 0.7, 0.15, IO).key(&"lean", 1.1, -0.15, I).key(&"lean", 2.5, 0.0, IO)
	buck.key(&"look", 0.0, 0.0).key(&"look", 0.4, 1.0, O).key(&"look", 1.6, 1.0).key(&"look", 2.6, 0.0, IO)
	_clips[A.BUCK] = buck
	# the charge: the torso drops, the javelin levels like a lance; a fore
	# hoof scrapes the floor twice (the barrel rocks with each stroke, the
	# tail lashes); the run (the gait's gallop at full tilt); the skid
	var charge := MotionClip.new()
	charge.key(&"low", 0.0, 0.0).key(&"low", 0.4, 1.0, IO).key(&"low", 2.0, 0.85).key(&"low", 2.6, 0.0, IO)
	charge.key(&"level", 0.0, 0.0).key(&"level", 0.35, 1.0, IO).key(&"level", 2.1, 1.0).key(&"level", 2.8, 0.0, IO)
	charge.key(&"scrape", 0.0, 0.0).key(&"scrape", 0.12, 1.0, IO).key(&"scrape", 0.88, 1.0).key(&"scrape", 0.98, 0.0, IO)
	charge.key(&"stroke", 0.0, 0.0).key(&"stroke", 0.14, 0.0, H).key(&"stroke", 0.5, 0.999, MotionClip.LINEAR) \
		.key(&"stroke", 0.5001, 1.0, H).key(&"stroke", 0.86, 1.999, MotionClip.LINEAR)
	charge.key(&"rock", 0.0, 0.0).key(&"rock", 0.3, 0.05, IO).key(&"rock", 0.5, -0.03, IO).key(&"rock", 0.7, 0.05, IO).key(&"rock", 0.9, -0.04, IO) \
		.key(&"rock", 1.0, -0.02, IO).key(&"rock", 2.0, 0.0).key(&"rock", 2.2, 0.12, O).key(&"rock", 3.0, 0.0, IO)
	charge.key(&"lash", 0.0, 0.0).key(&"lash", 0.2, 1.0, IO).key(&"lash", 1.0, 1.0).key(&"lash", 1.2, 0.0, IO)
	_clips[A.CHARGE] = charge
	# the call: it rears with the javelin raised high and the free arm up,
	# the head thrown back in a cry; the fore hooves stamp at 1.0 (the Lapiths
	# step out)
	var call := MotionClip.new()
	call.key(&"rear", 0.0, 0.0).key(&"rear", 0.12, -0.04, IO).key(&"rear", 0.6, 0.62, O).key(&"rear", 0.8, 0.64).key(&"rear", 1.0, -0.03, I).key(&"rear", 1.3, 0.0, BK)
	call.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.12, 0.08, IO).key(&"crouch", 0.6, 0.04, IO).key(&"crouch", 1.0, 0.1, I).key(&"crouch", 1.6, 0.0, IO)
	call.key(&"paw", 0.0, 0.0).key(&"paw", 0.25, 0.0, H).key(&"paw", 0.55, 1.0, IO).key(&"paw", 0.85, 1.0).key(&"paw", 0.98, 0.0, I)
	call.key(&"cry", 0.0, 0.0).key(&"cry", 0.6, 0.4, O).key(&"cry", 1.6, 0.35).key(&"cry", 2.4, 0.0, IO)
	call.key(&"lean", 0.0, 0.0).key(&"lean", 0.6, 0.12, IO).key(&"lean", 2.4, 0.0, IO)
	call.key(&"arms", 0.0, 0.0).key(&"arms", 0.55, 1.0, IO).key(&"arms", 2.0, 1.0).key(&"arms", 2.9, 0.0, IO)
	_clips[A.CALL] = call
	# the tear: it bends to its left flank, the left hand grips the metope's
	# piece; at 1.0 it rips it off and flings it out; a javelin forms in
	# that hand and is raised ready
	var tear := MotionClip.new()
	tear.key(&"grab", 0.0, 0.0).key(&"grab", 0.75, 1.0, IO).key(&"grab", 1.0, 1.0)
	tear.key(&"fling", 0.0, 0.0).key(&"fling", 1.0, 0.0, H).key(&"fling", 1.3, 1.0, I).key(&"fling", 1.9, 1.0)
	tear.key(&"hold", 0.0, 0.0).key(&"hold", 2.0, 0.0, H).key(&"hold", 2.7, 1.0, IO)
	tear.key(&"bend", 0.0, 0.0).key(&"bend", 0.75, 0.32, IO).key(&"bend", 1.0, 0.36).key(&"bend", 1.3, -0.12, I).key(&"bend", 2.4, 0.0, IO)
	tear.key(&"lean", 0.0, 0.0).key(&"lean", 0.75, -0.2, IO).key(&"lean", 1.3, 0.1, I).key(&"lean", 2.4, 0.0, IO)
	tear.key(&"look", 0.0, 0.0).key(&"look", 0.6, -0.45, IO).key(&"look", 1.2, 0.0, IO)
	tear.key(&"heave", 0.0, 0.0).key(&"heave", 0.9, 0.04, IO).key(&"heave", 1.05, -0.08, I).key(&"heave", 1.6, 0.0, BK)
	tear.key(&"form", 0.0, 0.0).key(&"form", 2.35, 0.0, H).key(&"form", 2.45, 1.4, O).key(&"form", 3.0, 0.0, O)
	_clips[A.TEAR] = tear
	# the stun: it reels in, the head shakes as it hits, hangs, shakes again
	# as it gathers itself
	_stun = MotionClip.new()
	_stun.key(&"reel", 0.0, 0.0).key(&"reel", 0.12, 1.0, O).key(&"reel", 0.82, 1.0).key(&"reel", 1.0, 0.0, IO)
	_stun.key(&"shake", 0.0, 0.0).key(&"shake", 0.05, 1.0, O).key(&"shake", 0.3, 0.0, IO).key(&"shake", 0.75, 0.0, H).key(&"shake", 0.85, 1.0, IO).key(&"shake", 1.0, 0.0, IO)
	# the waking (progress): the eyes ignite, the stone shivers as it strains
	# against the slab, the legs come alive; it rears (the slab bursts at
	# WAKE_BURST), crashes down, lunging free; shakes its head and turns to
	# the guard
	_wake = MotionClip.new()
	_wake.key(&"eyes", 0.0, 0.0).key(&"eyes", 0.06, 1.0, O)
	_wake.key(&"shiver", 0.0, 0.0).key(&"shiver", 0.08, 0.012, O).key(&"shiver", 0.34, 0.03, I).key(&"shiver", 0.42, 0.0, O)
	_wake.key(&"legs", 0.0, 0.0).key(&"legs", 0.1, 0.0, H).key(&"legs", 0.22, 1.0, IO)
	_wake.key(&"rear", 0.0, 0.0).key(&"rear", 0.3, -0.04, IO).key(&"rear", 0.47, 0.78, O).key(&"rear", 0.53, 0.8).key(&"rear", 0.64, -0.05, I).key(&"rear", 0.74, 0.0, BK)
	_wake.key(&"crouch", 0.0, 0.0).key(&"crouch", 0.3, 0.1, IO).key(&"crouch", 0.47, 0.04, IO).key(&"crouch", 0.64, 0.12, I).key(&"crouch", 0.8, 0.0, IO)
	_wake.key(&"lunge", 0.0, 0.0).key(&"lunge", 0.53, 0.0, H).key(&"lunge", 0.64, 0.25, I).key(&"lunge", 0.9, 0.0, IO)
	_wake.key(&"paw", 0.0, 0.0).key(&"paw", 0.38, 0.0, H).key(&"paw", 0.47, 1.0, IO).key(&"paw", 0.55, 1.0).key(&"paw", 0.63, 0.0, I)
	_wake.key(&"lean", 0.0, 0.0).key(&"lean", 0.3, -0.15, IO).key(&"lean", 0.5, 0.1, IO).key(&"lean", 0.7, 0.0, IO)
	_wake.key(&"toss", 0.0, 0.0).key(&"toss", 0.3, -0.25, IO).key(&"toss", 0.48, 0.4, O).key(&"toss", 0.64, -0.15, I).key(&"toss", 0.8, 0.0, IO)
	_wake.key(&"shake", 0.0, 0.0).key(&"shake", 0.7, 0.0, H).key(&"shake", 0.76, 1.0, IO).key(&"shake", 0.9, 0.0, IO)
	_wake.key(&"tail", 0.0, 0.0).key(&"tail", 0.3, 0.6, IO).key(&"tail", 1.0, 0.2, IO)
	_wake.key(&"arms", 0.0, 0.0).key(&"arms", 0.32, 0.0, H).key(&"arms", 0.48, 1.0, O).key(&"arms", 0.62, 0.6, IO).key(&"arms", 0.85, 0.0, IO)
	_wake.key(&"turn", 0.0, 0.0).key(&"turn", 0.1, 0.0, H).key(&"turn", 0.3, 1.0, IO)
