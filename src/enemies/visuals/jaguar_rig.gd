class_name JaguarRig
extends ExhibitRig
## The jaguar warrior (model "jaguar", docs/art/kit-pietro1-ameryki.md 9):
## pelvis root, torso, head, arms with forearms (the club in the right
## hand, the feather shield on the left forearm), thighs, shins, feet, a
## two-joint tail; the "face" and "club_tip" markers. Animated in code:
## - asleep a statue (the rest pose: standing, the club hanging); waking,
##   the head turns to what it heard first, then the body wakes with weight;
## - awake and idle: it breathes, shifts its weight from foot to foot, the
##   head follows the guard (within 45 degrees), the tail sways;
## - the upright walk: thighs swing with the knees folding, the arms
##   counter-swing, the torso twists and bobs;
## - the sprint on all fours (Jaguar.sprinting): a bear-crawl trot - the
##   hips drop and tip, the spine pitches past the horizontal and the
##   shoulders slide down the chest (the model's arms are short), the head
##   held up to look ahead; the four limbs reach their footfalls by a
##   two-bone reach (diagonal pairs, the paws and feet on the floor through
##   the stance, lifted in the swing), the club hand on its knuckles with the
##   club trailing back, the shield turned and slid up the forearm, the tail
##   streaming behind;
## - the crouch (the telegraph): low on bent legs, the torso forward, the
##   head up at the guard, the club drawn back, a tremor at the end;
## - the leap: the club raised overhead, the legs tucked (left higher),
##   the torso forward, the tail back; it lands deep in the knees;
## - the blow: the club arm from overhead to below the hips in a MotionClip
##   (accelerating, a little past and back), the torso into it; then the
##   club stuck in the floor while it slowly straightens (the opening);
## - stunned: down on one knee, the head hanging, the arms limp;
## - the tail: two joints on springs, swinging with turns and jolts.

## Angles (rad): the kit's poses.
const CROUCH_DROP := 0.35
const CROUCH_TORSO := -0.61
const CROUCH_THIGH := 1.05
const CROUCH_SHIN := -1.66
const CROUCH_HEAD := 0.35
const CROUCH_CLUB := -0.7
## The sprint: the hips' drop and tip, the spine on the hips, the head on
## the spine, the shoulders' slide down the chest (toward its front), the
## tail on the hips (rad, m).
const LOW_DROP := 0.26
const LOW_PELVIS := -0.9
const LOW_TORSO := -0.95
const LOW_HEAD := 1.7
const LOW_SHOULDER := 0.04
const LOW_TAIL := 0.35
## Its footfalls (enemy frame, m): the hind feet's stride round a point
## FOOTFALL_BACK behind the hip, their lift in the swing, the ankle over
## the sole; the paws' stride round a point FOOTFALL_BACK ahead of the
## shoulder, their lift, the paw's tip in the forearm (y, z), how high it
## comes down (the club hand on its knuckles a little higher).
const HIND_STRIDE := 0.36
const HIND_LIFT := 0.14
const SOLE := 0.084
const FORE_STRIDE := 0.2
const FORE_LIFT := 0.1
const FOOTFALL_BACK := 0.05
const PAW_TIP := Vector2(-0.3325, -0.02)
const PAW_GROUND := 0.01
const FIST_GROUND := 0.05
## The club trails back from the knuckles at this pitch (world, rad); the
## shield is turned a quarter in its plane and slid up the forearm (m).
const CLUB_TRAIL := -1.7
const SHIELD_TURN := 1.57
const SHIELD_SLIDE := 0.12
const AIR_TORSO := -0.44
const AIR_CLUB := 2.62
const AIR_FORE := 0.7
const AIR_THIGH_L := 1.31
const AIR_THIGH_R := 0.7
const AIR_TAIL := -0.7
const SETTLE_DROP := 0.3
const SETTLE_THIGH := 0.87
const SETTLE_SHIN := -1.5
const SWING_END := 0.35
const SWING_PAST := -0.17
const STUCK_TORSO := -0.5
const STUN_DROP := 0.5
## How far the head follows the guard (rad).
const HEAD_FOLLOW := 0.8
## The splinter-glow colour the eyes carry comes from the texture; the
## tail's springs.
const TAIL_SPRING := Vector2(2.4, 0.3)

var jaguar: Jaguar

var _low := 0.0
var _crouch := 0.0
var _air := 0.0
var _settle := 0.0
var _stuck := 0.0
var _stun := 0.0
var _statue := 1.0
var _club := 0.0
var _fore := 0.0
var _torso := 0.0
var _twist := 0.0
var _head_pitch := 0.0
var _head_yaw := 0.0
var _arm_l := 0.0
var _tremor := 0.0
var _swing := MotionClip.new()
var _tail_pitch: Array[Spring] = [Spring.new(TAIL_SPRING.x, TAIL_SPRING.y), Spring.new(TAIL_SPRING.x * 1.3, TAIL_SPRING.y)]
var _tail_yaw: Array[Spring] = [Spring.new(TAIL_SPRING.x, TAIL_SPRING.y), Spring.new(TAIL_SPRING.x * 1.3, TAIL_SPRING.y)]
var _last_yaw := 0.0
var _last_vy := 0.0
var _jolt := Vector3.ZERO


static func build(owner: Jaguar) -> JaguarRig:
	var rig := JaguarRig.new()
	rig.jaguar = owner
	rig.cycle_length = 1.7
	rig.full_speed = 3.0
	rig.gib_density = 3.5
	return ExhibitRig.attach(owner, rig, &"jaguar") as JaguarRig


## A hit's push (world) rocks the body and whips the tail.
func jolt(impulse: Vector3) -> void:
	_jolt += impulse
	for spring in _tail_yaw:
		spring.kick(randf_range(-3.0, 3.0))


## 0..1: how much of a statue it is (asleep).
func statue() -> float:
	return _statue


func _setup() -> void:
	# the blow: overhead, accelerating down, a little past the end and back
	_swing.key(&"arm", 0.0, AIR_CLUB).key(&"arm", JaguarMoves.SWING, SWING_END, MotionClip.IN) \
			.key(&"arm", JaguarMoves.SWING + 0.1, SWING_PAST, MotionClip.OUT_BACK)
	_swing.key(&"fore", 0.0, AIR_FORE).key(&"fore", JaguarMoves.SWING, 0.1, MotionClip.IN)
	_swing.key(&"torso", 0.0, -0.2).key(&"torso", JaguarMoves.SWING, STUCK_TORSO, MotionClip.IN)
	_last_yaw = enemy.global_rotation.y if enemy.is_inside_tree() else 0.0


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var dormant := state == EnemyBrain.State.DORMANT
	var stunned := state == EnemyBrain.State.STUNNED
	var awake := not dormant and state != EnemyBrain.State.DESTROYED
	var phase := jaguar.phase()
	var on_floor := enemy.is_on_floor()
	var walk := minf(gait, 1.0) if on_floor else 0.0
	var p := walk_phase
	var sprint := jaguar.sprinting()
	# targets
	var low := 1.0 if sprint else 0.0
	var crouch := up
	var air := 1.0 if phase == JaguarMoves.Phase.AIR else 0.0
	var settle := 1.0 if phase == JaguarMoves.Phase.SETTLE else 0.0
	var stuck := 1.0 if phase == JaguarMoves.Phase.STUCK else 0.0
	var club := 0.0
	var fore := 0.0
	var torso := 0.0
	var twist := sin(p) * 0.08 * walk * (1.0 - low)
	var head_pitch := 0.0
	var arm_l := 0.0
	var rate := 10.0
	if w > 0.0:
		club = CROUCH_CLUB * up
		torso = CROUCH_TORSO * up
		head_pitch = CROUCH_HEAD * up
		fore = 0.3 * up
		arm_l = -0.5 * up
		rate = 12.0
	elif phase == JaguarMoves.Phase.AIR:
		club = AIR_CLUB
		fore = AIR_FORE
		torso = AIR_TORSO
		head_pitch = 0.3
		arm_l = 0.6
		rate = 16.0
	elif phase == JaguarMoves.Phase.SETTLE:
		club = AIR_CLUB
		fore = AIR_FORE
		torso = -0.2
		head_pitch = 0.25
		arm_l = 0.4
		rate = 18.0
	elif phase == JaguarMoves.Phase.SWING or phase == JaguarMoves.Phase.STUCK:
		var t := jaguar.combo_time() - JaguarMoves.SETTLE
		club = _swing.sample(&"arm", t)
		fore = _swing.sample(&"fore", t)
		torso = _swing.sample(&"torso", t)
		head_pitch = -0.2
		arm_l = 0.3
		rate = 60.0 if phase == JaguarMoves.Phase.SWING else 3.0
		if phase == JaguarMoves.Phase.STUCK:
			# it straightens slowly, the club still in the floor
			var rise := clampf((t - JaguarMoves.SWING) / JaguarMoves.STUCK, 0.0, 1.0)
			torso = lerpf(STUCK_TORSO, -0.15, rise * rise)
			club = lerpf(SWING_PAST, 0.1, rise * rise)
	elif sprint:
		# (the limbs reach for their footfalls below; these hold the rest)
		torso = LOW_TORSO
		head_pitch = LOW_HEAD
		rate = 12.0
	elif awake:
		# idle and the upright walk: breathing, the arms counter-swinging
		torso = -0.04 * walk + 0.02 * sin(time * 1.9)
		arm_l = -sin(p) * 0.3 * walk + 0.05 * sin(time * 1.9 + 1.0)
		club = sin(p) * 0.3 * walk + 0.1
		fore = 0.2
	if stunned:
		club = 0.3
		fore = 0.6
		torso = -0.35
		head_pitch = -0.6
		arm_l = 0.2
		twist = sin(time * 2.1) * 0.05
		rate = 8.0
	# tremor at the end of the crouch
	_tremor = sin(time * 31.0) * 0.03 * clampf((w - 0.6) / 0.4, 0.0, 1.0)
	_low = ExhibitRig.ease_to(_low, low, 6.0, delta)
	_crouch = ExhibitRig.ease_to(_crouch, crouch, 14.0, delta)
	_air = ExhibitRig.ease_to(_air, air, 20.0, delta)
	_settle = ExhibitRig.ease_to(_settle, settle, 22.0, delta)
	_stuck = ExhibitRig.ease_to(_stuck, stuck, 12.0, delta)
	_stun = ExhibitRig.ease_to(_stun, 1.0 if stunned else 0.0, 8.0 if stunned else 4.0, delta)
	_statue = ExhibitRig.ease_to(_statue, 1.0 if dormant else 0.0, 4.0 if dormant else 5.0, delta)
	_club = ExhibitRig.ease_to(_club, club, rate, delta)
	_fore = ExhibitRig.ease_to(_fore, fore, rate, delta)
	_torso = ExhibitRig.ease_to(_torso, torso, rate * 0.8, delta)
	_twist = ExhibitRig.ease_to(_twist, twist, 8.0, delta)
	_head_pitch = ExhibitRig.ease_to(_head_pitch, head_pitch, 9.0, delta)
	_arm_l = ExhibitRig.ease_to(_arm_l, arm_l, rate, delta)
	_head_yaw = ExhibitRig.ease_to(_head_yaw, _look_yaw() if awake and not stunned else 0.0, 6.0, delta)
	_jolt = _jolt.move_toward(Vector3.ZERO, 6.0 * delta)
	var live := 1.0 - _statue
	# the hips: down in the sprint, the crouch, the settle and the stun; a
	# weight shift idling; a bob walking
	var drop := LOW_DROP * _low + CROUCH_DROP * _crouch + SETTLE_DROP * _settle + STUN_DROP * _stun - 0.1 * _air
	var bob := -absf(cos(p)) * 0.04 * walk
	var shift_x := 0.02 * sin(time * 0.7) * live * (1.0 - walk)
	var local_jolt := enemy.global_basis.inverse() * _jolt
	var tip := LOW_PELVIS * _low * live
	pose_part("pelvis", Vector3(local_jolt.z * 0.04 + tip, 0.0, -local_jolt.x * 0.04), Vector3(shift_x, (bob - drop) * live, 0.0))
	pose_part("torso", Vector3(_torso * live, _twist, sin(p) * 0.03 * walk * (1.0 - _low)))
	pose_part("head", Vector3(_head_pitch * live, _head_yaw, 0.0))
	# arms: the club arm, the shield arm (on all fours each reaches its paw's
	# footfall, in diagonal pairs with the legs)
	var on_fours := _low * live
	var slide := Vector3(0.0, 0.0, -LOW_SHOULDER * on_fours)
	pose_part("arm_r", Vector3(_club * live + _tremor, 0.0, 0.1 * _air), slide)
	pose_part("arm_l", Vector3(_arm_l * live, 0.0, -0.15 * _crouch), slide)
	var arms := {"l": Vector2(_arm_l * live, (0.4 + 0.3 * _crouch) * live), "r": Vector2(_club * live + _tremor, _fore * live)}
	if on_fours > 0.001:
		for side: String in ["l", "r"]:
			var ph := p + PI if side == "l" else p
			var lift := maxf(cos(ph), 0.0)
			var shoulder := part_transform("arm_" + side).origin
			var ground := FIST_GROUND if side == "r" else PAW_GROUND
			var footfall := Vector2(ground + FORE_LIFT * lift, shoulder.z - FORE_STRIDE * sin(ph) - FOOTFALL_BACK)
			var reached := reach(Vector2(shoulder.y, shoulder.z), footfall, _bone("forearm_" + side), PAW_TIP, false, pitch_of("torso"))
			arms[side] = (arms[side] as Vector2).lerp(reached, on_fours)
	var right: Vector2 = arms["r"]
	var left: Vector2 = arms["l"]
	pose_part("arm_r", Vector3(right.x, 0.0, 0.1 * _air), slide)
	pose_part("forearm_r", Vector3(right.y, 0.0, 0.0))
	pose_part("arm_l", Vector3(left.x, 0.0, -0.15 * _crouch), slide)
	pose_part("forearm_l", Vector3(left.y, 0.0, 0.0))
	# the club trails back from the knuckles, the shield rides up the forearm
	pose_part("club", Vector3(wrapf(CLUB_TRAIL - pitch_of("forearm_r"), -PI, PI) * on_fours, 0.0, 0.0))
	pose_part("shield", Vector3(SHIELD_TURN * on_fours, 0.0, 0.0), Vector3(0.0, SHIELD_SLIDE * on_fours, 0.0))
	_pose_legs(p, walk, live)
	_pose_tail(delta, live)


## Thighs and shins: the swing of the walk (knees folding), the sprint's
## stride, the crouch, the leap's tuck, the settle's deep knees, the stun's
## knee down.
func _pose_legs(p: float, walk: float, live: float) -> void:
	var low := _low * live
	for side in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var ph := p if side == "l" else p + PI
		var swing := sin(ph)
		var lift := maxf(cos(ph), 0.0)
		var thigh := 0.45 * swing * walk * (1.0 - _low)
		var shin := -0.7 * lift * walk * (1.0 - _low)
		var flat := 0.0
		if low > 0.001:
			# on all fours: the foot reaches its footfall behind the hip, flat
			var hip := part_transform("thigh_" + side).origin
			var footfall := Vector2(SOLE + HIND_LIFT * lift, hip.z - HIND_STRIDE * swing + FOOTFALL_BACK)
			var reached := reach(Vector2(hip.y, hip.z), footfall, _bone("shin_" + side), _bone("foot_" + side), true, pitch_of("pelvis"))
			thigh += reached.x * _low
			shin += reached.y * _low
			flat = -(pitch_of("pelvis") + reached.x + reached.y) * _low
		thigh += CROUCH_THIGH * _crouch + SETTLE_THIGH * _settle
		shin += CROUCH_SHIN * _crouch + SETTLE_SHIN * _settle
		thigh += (AIR_THIGH_L if side == "l" else AIR_THIGH_R) * _air
		shin += -1.4 * (AIR_THIGH_L if side == "l" else AIR_THIGH_R) * _air
		if side == "l":
			thigh += 1.05 * _stun
			shin += -1.57 * _stun
		else:
			thigh += -0.35 * _stun
			shin += -0.3 * _stun
		thigh += 0.15 * _stuck
		shin += -0.3 * _stuck
		pose_part("thigh_" + side, Vector3(thigh * live, 0.0, 0.0))
		pose_part("shin_" + side, Vector3(shin * live, 0.0, 0.0))
		pose_part("foot_" + side, Vector3((-0.3 * lift * walk * (1.0 - _low) - 0.4 * _air + flat) * live, 0.0, sign * 0.0))


## The tail: two joints on springs, swung by turns and vertical jolts,
## swaying idly, held back in the leap.
func _pose_tail(delta: float, live: float) -> void:
	var yaw := enemy.global_rotation.y
	var yaw_rate := angle_difference(_last_yaw, yaw) / maxf(delta, 0.0001)
	_last_yaw = yaw
	var vy := enemy.velocity.y
	var jerk := (vy - _last_vy) / maxf(delta, 0.0001)
	_last_vy = vy
	for i in 2:
		_tail_yaw[i].kick(clampf(-yaw_rate * 0.01, -0.6, 0.6) * (1.0 + 0.5 * i))
		_tail_pitch[i].kick(clampf(-jerk * 0.0015, -0.6, 0.6))
		var idle_yaw := sin(time * 1.4 + i * 0.9) * 0.18 * live
		var sway := _tail_yaw[i].step(idle_yaw, delta)
		var pitch := _tail_pitch[i].step((AIR_TAIL * _air + LOW_TAIL * _low + 0.15 * _crouch) * live, delta)
		pose_part("tail_%d" % (i + 1), Vector3(pitch, sway, 0.0))


## The rest vector (y, z) from part [param part_name]'s parent joint to its
## own pivot: the bone it hangs on.
func _bone(part_name: String) -> Vector2:
	var at: Vector3 = (rest[part_name] as Transform3D).origin
	return Vector2(at.y, at.z)


## The pitch (rad, about X: up tipping toward -Z is negative) of part
## [param part_name] in the enemy's frame.
func pitch_of(part_name: String) -> float:
	var up := part_transform(part_name).basis.y
	return atan2(up.z, up.y)


## Planar two-bone reach in a limb's (y, z) plane: from the joint at
## [param root] to [param target], over bones [param upper] and [param lower]
## (their rest vectors, (y, z)), the middle joint bent ahead (a knee) or
## back (an elbow), the parent pitched [param parent]. Returns the two
## joints' pitches about X on their parents (the upper's on the parent).
## Out of reach: the limb straight toward the target.
static func reach(root: Vector2, target: Vector2, upper: Vector2, lower: Vector2, ahead: bool, parent: float) -> Vector2:
	var l1 := upper.length()
	var l2 := lower.length()
	var to := target - root
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var first := to.angle() + (bend if ahead else -bend)
	var middle := root + Vector2(cos(first), sin(first)) * l1
	var second := (target - middle).angle()
	var a1 := first - upper.angle()
	var a2 := second - lower.angle()
	return Vector2(wrapf(a1 - parent, -PI, PI), wrapf(a2 - a1, -PI, PI))


## The head's yaw toward the guard (or what it heard), within HEAD_FOLLOW.
func _look_yaw() -> float:
	var brain := enemy.brain
	var point := Vector3.INF
	if brain.knows_guard() and is_instance_valid(enemy.target):
		point = enemy.target.global_position
	elif brain.state == EnemyBrain.State.SUSPICIOUS or brain.state == EnemyBrain.State.INVESTIGATE:
		point = brain.last_known
	if point == Vector3.INF:
		return 0.0
	var local := enemy.global_transform.affine_inverse() * point
	if Vector2(local.x, local.z).length_squared() < 0.0001:
		return 0.0
	return clampf(atan2(-local.x, -local.z), -HEAD_FOLLOW, HEAD_FOLLOW)
