class_name SerpentMoves
extends RefCounted
## The Two-headed Serpent's choreography: from the brain's moment and the
## body's end frames it decides where each head is and looks, how open its
## jaw is, how its mouth glows, and how the tail bends, in two layers:
## 1. the HEADS AT REST, always: each head rides out along its end's line
##    and up (REST), turning to watch the guard a moment late (springs on
##    its yaw and pitch, within limits), the trailing head looking back
##    over the tail; asleep they lie low on the steps; at the ring's gate
##    they rise high and turn down the stairs toward whoever comes;
## 2. the ACTION, a MotionClip per attack sampled at the brain's clip_time()
##    (0..1 warning, 1..2 strike, 2..3 recovery) laid over the rest as
##    offsets: the spit (the head rears up and back, the jaw opens and the
##    mouth glows; a snap forward as the shards leave; it settles), the
##    lunge (the head draws back in an S and hisses, the jaw opening; it
##    shoots out low to the neck's full reach; it hangs out spent, then
##    comes back), the sweep (the tail's plates rattle and the tail winds
##    up the other way; it comes round; it settles), the waking (the eyes
##    light, the plates rattle, the heads rise from the steps), phase 2's
##    shift (the heads turn to each other, the light runs down the body
##    from the glowing head to the other).
## Principles as the Colossus's and the Centaur's: anticipation, ease in
## and out, overshoot and settle, follow-through on springs.

const S := SerpentBrain.State
const A := SerpentBrain.Attack
const END := SerpentBody.End

## A head at rest: out along the end's line (m), up (m) - root frame.
const REST := Vector2(2.5, 0.75)
## Asleep: low over the steps.
const REST_ASLEEP := Vector2(2.3, 0.25)
## At the ring's gate: high, over the stairs.
const REST_GATE := Vector2(1.7, 1.75)
## Head turning limits toward the guard (rad): yaw, pitch down, pitch up.
const YAW_LIMIT := 1.9
const PITCH_LIMIT := Vector2(-0.9, 0.6)
## The look settles this far toward the guard at rest (the rest looks a
## little down the line).
const WATCH := 0.85
## The lunge reaches out to this much of the neck's length.
const LUNGE_REACH := 0.97

var body: SerpentBody
var pose := SerpentRig.Pose.new()
## The guard's chest (world), set by the Serpent each frame.
var guard := Vector3.ZERO
## The ring's gate (world) and the way down its stairs (unit, flat): the
## heads at rest in the ring and asleep turn that way.
var gate_center := Vector3.ZERO
var gate_down := Vector3.FORWARD
## The steps under the gate (world y): a head at rest there lies on them,
## never in them.
var gate_floor: float = -INF
## The way the tail comes round in the sweep under way: +1 toward the
## trailing root frame's -X, -1 toward its +X, 0 = undecided (the Serpent
## sets it as it draws the arc; alone, compose() decides from where the
## guard stands as the sweep starts). Kept through the attack: the arc on
## the floor stays true whichever way the guard then runs.
var sweep_side: float = 0.0
var time: float = 0.0

var _clips: Dictionary = {}
var _out: Array[Spring] = [Spring.new(2.2, 0.8, REST.x), Spring.new(2.2, 0.8, REST.x)]
var _up: Array[Spring] = [Spring.new(2.2, 0.75, REST.y), Spring.new(2.2, 0.75, REST.y)]
var _side: Array[Spring] = [Spring.new(2.4, 0.7), Spring.new(2.4, 0.7)]
var _yaw: Array[Spring] = [Spring.new(2.0, 0.7), Spring.new(2.0, 0.7)]
var _pitch: Array[Spring] = [Spring.new(2.0, 0.75), Spring.new(2.0, 0.75)]
var _jaw: Array[Spring] = [Spring.new(4.0, 0.6), Spring.new(4.0, 0.6)]
var _glow: Array[Spring] = [Spring.new(3.0, 0.9), Spring.new(3.0, 0.9)]
var _sweep := Spring.new(3.6, 0.7)
var _sweep_latched: float = 0.0
var _flinch: Array[Spring] = [Spring.new(3.5, 0.4), Spring.new(3.5, 0.4)]


func _init(body_: SerpentBody) -> void:
	body = body_
	_build_clips()


## A hit landed on head [param end] (or the body: both heads twitch a little).
func flinch(end: int, amount: float = 1.0) -> void:
	if end < 0:
		_flinch[0].kick(amount * 2.0)
		_flinch[1].kick(amount * 2.0)
	else:
		_flinch[end].kick(amount * 5.0)


## Everything at rest at once (the guard fled, the body re-laid).
func reset(asleep: bool = true) -> void:
	for end in 2:
		var rest := REST_ASLEEP if asleep else REST
		_out[end].reset(rest.x)
		_up[end].reset(rest.y)
		_side[end].reset(0.0)
		_yaw[end].reset(0.0)
		_pitch[end].reset(0.0)
		_jaw[end].reset(0.0)
		_glow[end].reset(0.0)
		_flinch[end].reset(0.0)
	_sweep.reset(0.0)
	_sweep_latched = 0.0
	sweep_side = 0.0
	pose.eyes = 0.0 if asleep else 1.0
	pose.light_s = -1.0
	pose.rattle = 0.0
	body.sweep = 0.0


## Composes this frame: sets the body's head targets and tail sweep,
## returns the pose for the rig. [param ring]: the body lies on the ring.
func compose(brain: SerpentBrain, delta: float, ring: bool = false) -> SerpentRig.Pose:
	time += delta
	var clip_t := brain.clip_time()
	var clip: MotionClip = _clips.get(brain.attack) if brain.state == S.ATTACK else null
	var acting := brain.attack_end() if clip != null else -1
	var asleep := brain.state == S.DORMANT
	var waking := brain.state == S.WAKING
	var shift := brain.state == S.PHASE_SHIFT
	var at_gate := ring or brain.state == S.RING or asleep
	# eyes, light, rattle
	if asleep:
		pose.eyes = 0.0
	elif waking:
		pose.eyes = MotionClip.eased(MotionClip.OUT, clampf(brain.state_progress() / 0.25, 0.0, 1.0))
	else:
		pose.eyes = 1.0
	pose.light_s = -1.0
	if shift:
		var u := brain.state_progress()
		# the light runs from the glowing head's end to the other's
		var from := 0.0 if brain.spitter == END.A else 1.0
		pose.light_s = lerpf(from, 1.0 - from, MotionClip.eased(MotionClip.IN_OUT, u))
	var rattle := 0.0
	if waking:
		rattle = 1.0 - brain.state_progress()
	pose.rattle_end = brain.trailer()
	# the tail
	var sweep_goal := 0.0
	if clip != null and brain.attack == A.SWEEP:
		if _sweep_latched == 0.0:
			# the tail winds up away from the guard's side, then comes round
			# across where he stands - decided once, as the arc is drawn
			_sweep_latched = sweep_side
			if _sweep_latched == 0.0:
				var frame := body.root_frame(brain.trailer())
				var local := frame.affine_inverse() * guard
				_sweep_latched = -1.0 if local.x > 0.0 else 1.0
		sweep_goal = clip.sample(&"sweep", clip_t) * _sweep_latched
		rattle = maxf(rattle, clip.sample(&"rattle", clip_t))
	else:
		_sweep_latched = 0.0
	pose.rattle = rattle
	body.sweep = _sweep.step(sweep_goal, delta)
	# the heads
	for end in 2:
		var frame := body.root_frame(end)
		var rest := REST
		if asleep:
			rest = REST_ASLEEP
		elif at_gate:
			rest = REST_GATE
		var out := rest.x
		var up := rest.y
		var side := 0.0
		var jaw := 0.0
		var glow := 1.0 if (brain.spitter == end and not asleep and not waking) else 0.0
		if shift:
			glow = 1.0 - MotionClip.eased(MotionClip.IN_OUT, brain.state_progress()) if brain.spitter == end else MotionClip.eased(MotionClip.IN_OUT, brain.state_progress())
		if waking:
			glow = pose.eyes * (1.0 if brain.spitter == end else 0.0)
		glow *= 0.35
		# the look: toward the guard, within limits, a little down the line
		var local_guard := frame.affine_inverse() * guard
		var yaw_goal := 0.0
		var pitch_goal := -0.12
		if asleep or (at_gate and not acting == end):
			# down the stairs, toward whoever comes
			var down := frame.basis.inverse() * gate_down
			yaw_goal = atan2(-down.x, -down.z) * 0.6
			if not asleep:
				yaw_goal = lerpf(yaw_goal, clampf(atan2(-local_guard.x, -local_guard.z), -YAW_LIMIT, YAW_LIMIT), WATCH)
		else:
			var flat := Vector2(local_guard.x, local_guard.z).length()
			yaw_goal = clampf(atan2(-local_guard.x, -local_guard.z), -YAW_LIMIT, YAW_LIMIT) * WATCH
			pitch_goal = clampf(atan2(local_guard.y - up, maxf(flat, 0.5)), PITCH_LIMIT.x, PITCH_LIMIT.y) * WATCH
		if clip != null and acting == end:
			out += clip.sample(&"out", clip_t)
			up += clip.sample(&"up", clip_t)
			side += clip.sample(&"side", clip_t)
			jaw = clip.sample(&"jaw", clip_t)
			glow = maxf(glow, clip.sample(&"glow", clip_t))
			pitch_goal += clip.sample(&"pitch", clip_t)
			yaw_goal += clip.sample(&"yaw", clip_t) * signf(yaw_goal if absf(yaw_goal) > 0.05 else 1.0)
			if brain.attack == A.LUNGE and clip_t >= 1.0 and clip_t < 2.0:
				# the strike shoots straight at the guard
				yaw_goal = clampf(atan2(-local_guard.x, -local_guard.z), -YAW_LIMIT, YAW_LIMIT)
		if shift:
			# the heads turn to each other
			var other := body.head_point(END.B if end == END.A else END.A)
			var to_other := frame.affine_inverse() * other
			var k := MotionClip.eased(MotionClip.IN_OUT, clampf(brain.state_progress() * 3.0, 0.0, 1.0)) * (1.0 - MotionClip.eased(MotionClip.IN, clampf((brain.state_progress() - 0.75) * 4.0, 0.0, 1.0)))
			yaw_goal = lerpf(yaw_goal, clampf(atan2(-to_other.x, -to_other.z), -YAW_LIMIT, YAW_LIMIT), k)
			pitch_goal = lerpf(pitch_goal, clampf(atan2(to_other.y - up, Vector2(to_other.x, to_other.z).length()), PITCH_LIMIT.x, PITCH_LIMIT.y), k)
			up += 0.35 * k
			jaw = maxf(jaw, 0.3 * k)
		# the lunge's strike is too quick for a lazy spring: snap the springs
		var quick := clip != null and acting == end and brain.attack == A.LUNGE and clip_t >= 1.0 and clip_t < 2.0
		var o := _out[end].step(out, delta * (3.0 if quick else 1.0))
		var h := _up[end].step(up, delta * (3.0 if quick else 1.0))
		var sd := _side[end].step(side, delta)
		var yw := _yaw[end].step(yaw_goal, delta)
		var pt := _pitch[end].step(pitch_goal, delta)
		var twitch := _flinch[end].step(0.0, delta)
		pose.jaw[end] = clampf(_jaw[end].step(jaw, delta) + absf(twitch) * 0.08, 0.0, 1.0)
		pose.head_glow[end] = clampf(_glow[end].step(glow, delta), 0.0, 2.0)
		# the head's point and look in the frame (-Z out), then the world
		var yaw_turn := Basis(Vector3.UP, yw)
		var direction := yaw_turn * Vector3(0.0, sin(pt), -cos(pt))
		var point := Vector3(sd, h, 0.0) + yaw_turn * Vector3(0.0, 0.0, -o)
		point.y += twitch * 0.04
		var look := (frame.basis * direction).normalized()
		var wanted := frame * point
		if at_gate and gate_floor > -1000.0:
			# on the steps under the gate, never in them
			wanted.y = maxf(wanted.y, gate_floor + 0.45)
		body.set_head(end, wanted, look)
		pose.head_look[end] = look
	return pose


# --- the clips ----------------------------------------------------------------------------

func _build_clips() -> void:
	# the spit: a rear up and back, the jaw opening and the mouth glowing
	# through the warning; the snap forward as the shards leave at 1.0; the
	# settle
	var spit := MotionClip.new()
	spit.key(&"up", 0.0, 0.0).key(&"up", 0.7, 0.55, MotionClip.OUT).key(&"up", 1.0, 0.5).key(&"up", 1.25, -0.1, MotionClip.IN).key(&"up", 2.0, 0.05, MotionClip.OUT_BACK).key(&"up", 3.0, 0.0)
	spit.key(&"out", 0.0, 0.0).key(&"out", 0.7, -0.45, MotionClip.OUT).key(&"out", 1.0, -0.4).key(&"out", 1.3, 0.5, MotionClip.IN).key(&"out", 2.0, 0.2, MotionClip.OUT).key(&"out", 3.0, 0.0)
	spit.key(&"pitch", 0.0, 0.0).key(&"pitch", 0.7, 0.4, MotionClip.OUT).key(&"pitch", 1.0, 0.35).key(&"pitch", 1.3, -0.25, MotionClip.IN).key(&"pitch", 3.0, 0.0)
	spit.key(&"jaw", 0.0, 0.0).key(&"jaw", 0.5, 0.8, MotionClip.OUT).key(&"jaw", 1.0, 0.85).key(&"jaw", 1.4, 1.0).key(&"jaw", 2.0, 0.6).key(&"jaw", 3.0, 0.0)
	spit.key(&"glow", 0.0, 0.3).key(&"glow", 0.8, 1.6, MotionClip.IN).key(&"glow", 1.0, 2.0).key(&"glow", 1.6, 0.9, MotionClip.OUT).key(&"glow", 3.0, 0.35)
	_clips[A.SPIT] = spit
	# the lunge: the head draws back into an S, hissing, the jaw opening;
	# at 1.0 it shoots out low to the neck's reach, straight at the guard;
	# it hangs out spent (the weak point bared), then draws back
	var reach := float(SerpentBody.NECK) * SerpentBody.SPACING * LUNGE_REACH
	var lunge := MotionClip.new()
	lunge.key(&"out", 0.0, 0.0).key(&"out", 0.8, -0.9, MotionClip.OUT).key(&"out", 1.0, -0.95).key(&"out", 2.0, reach - REST.x, MotionClip.IN).key(&"out", 2.5, reach - REST.x - 0.15, MotionClip.OUT).key(&"out", 3.0, 0.0, MotionClip.IN_OUT)
	lunge.key(&"up", 0.0, 0.0).key(&"up", 0.8, 0.35, MotionClip.OUT).key(&"up", 1.0, 0.3).key(&"up", 2.0, -0.45, MotionClip.IN).key(&"up", 2.6, -0.55).key(&"up", 3.0, 0.0, MotionClip.IN_OUT)
	lunge.key(&"side", 0.0, 0.0).key(&"side", 0.5, 0.35, MotionClip.IN_OUT).key(&"side", 1.0, 0.3).key(&"side", 2.0, 0.0, MotionClip.IN).key(&"side", 3.0, 0.0)
	lunge.key(&"pitch", 0.0, 0.0).key(&"pitch", 0.8, 0.3, MotionClip.OUT).key(&"pitch", 2.0, -0.35, MotionClip.IN).key(&"pitch", 2.6, -0.45).key(&"pitch", 3.0, 0.0)
	lunge.key(&"jaw", 0.0, 0.0).key(&"jaw", 0.4, 0.55, MotionClip.OUT).key(&"jaw", 1.0, 0.6).key(&"jaw", 1.6, 1.0, MotionClip.OUT).key(&"jaw", 2.0, 1.0).key(&"jaw", 2.3, 0.1, MotionClip.IN).key(&"jaw", 3.0, 0.0)
	lunge.key(&"glow", 0.0, 0.0).key(&"glow", 3.0, 0.0)
	_clips[A.LUNGE] = lunge
	# the sweep: the plates rattle, the tail winds up the other way through
	# the warning; it comes round at 1.0 .. 2.0; it settles
	var sweep := MotionClip.new()
	sweep.key(&"sweep", 0.0, 0.0).key(&"sweep", 0.85, -0.4, MotionClip.OUT).key(&"sweep", 1.0, -0.42).key(&"sweep", 2.0, 1.0, MotionClip.IN_OUT).key(&"sweep", 2.3, 1.05, MotionClip.OUT).key(&"sweep", 3.0, 0.0, MotionClip.IN_OUT)
	sweep.key(&"rattle", 0.0, 0.4).key(&"rattle", 0.9, 1.0).key(&"rattle", 1.0, 1.0).key(&"rattle", 2.0, 0.3).key(&"rattle", 3.0, 0.0)
	# the trailing head rears a little, watching
	sweep.key(&"up", 0.0, 0.0).key(&"up", 1.0, 0.3, MotionClip.OUT).key(&"up", 3.0, 0.0)
	sweep.key(&"jaw", 0.0, 0.0).key(&"jaw", 1.0, 0.3).key(&"jaw", 2.0, 0.5).key(&"jaw", 3.0, 0.0)
	_clips[A.SWEEP] = sweep
