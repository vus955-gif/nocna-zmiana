class_name FuDogRig
extends ExhibitRig
## The bronze Fu dog (model "fu_dog", docs/art/kit-pietro1-azja.md 7):
## body root, head with jaw and the loose pearl, four legs in two joints,
## the plume tail, the embroidered ball (a root part: FuDog leaves it on
## the plinth when the lion wakes); markers mouth_ball and roar. Animated
## in code:
## - asleep the exhibit: right fore paw up on the ball; waking, that paw
##   comes down (PAW_DOWN) and the head turns to the noise;
## - the heavy walk: lateral pairs of legs, the body rolling from side to
##   side and dipping, the head nodding, the plume swinging;
## - the charge's telegraph: the head drops, the weight goes back onto the
##   haunches, the right fore paw scrapes back twice; the gallop: fore legs
##   together against the hind legs, the body pitched down, the head low;
## - the roar's telegraph: the pearl lights up (its own glow), the head
##   goes up, the jaw opens, the chest swells (the body rises and rocks
##   back); the roar lunges the head forward with the jaw wide;
## - the paw: the right fore leg raised high, then slammed down past and back;
## - stunned (a wall): the head shakes, the legs splay, the body sags;
## - awake and idle: it breathes, its head follows the guard, the jaw
##   works, the plume sways on springs that answer turns and jolts;
## - the lioness is the mirror image (set_mirror).

## The right fore paw's drop off the ball (rad: the upper leg back, the
## lower leg down).
const PAW_DOWN_LEG := -0.6
const PAW_DOWN_SHIN := -0.5
const PAW_DOWN_TIME := 0.5
## The pearl is fully lit this far into the roar's telegraph (share).
const PEARL_ON := 0.2
## The roar's head: up (rad), the jaw open (rad), the lunge (rad).
const ROAR_HEAD := 0.35
const ROAR_JAW := -0.49
const ROAR_LUNGE := -0.25
const ROAR_JAW_WIDE := -0.6
const ROAR_CHEST := 0.06
## The charge: the gallop's leg swing, the body's pitch, the head low.
const GALLOP := 0.61
const CHARGE_PITCH := -0.09
const CHARGE_HEAD := -0.17
const SCRAPE_BACK := -0.45
const SCRAPE_UP := 0.3
## The paw: raised, slammed.
const PAW_RAISE := 1.1
const PAW_SLAM := -0.45
const PAW_SLAM_TIME := 0.15
const WALK_SWING := 0.32
const HEAD_FOLLOW := 0.7
const TAIL_SPRING := Vector2(1.8, 0.3)

var dog: FuDog

var _paw_down := 0.0
var _roar := 0.0
var _lunge := 0.0
var _charge := 0.0
var _gallop := 0.0
var _scrape := 0.0
var _raise := 0.0
var _slam := 0.0
var _stun := 0.0
var _head_pitch := 0.0
var _head_yaw := 0.0
var _jaw := 0.0
var _chest := 0.0
var _pitch := 0.0
var _pearl := 0.0
var _pearl_applied := -1.0
var _tail_pitch := Spring.new(TAIL_SPRING.x, TAIL_SPRING.y)
var _tail_yaw := Spring.new(TAIL_SPRING.x * 1.2, TAIL_SPRING.y)
var _last_yaw := 0.0
var _jolt := Vector3.ZERO
var _mirrored := false


static func build(owner: FuDog) -> FuDogRig:
	var rig := FuDogRig.new()
	rig.dog = owner
	rig.cycle_length = 1.6
	rig.full_speed = 2.4
	rig.gib_density = 3.0
	return ExhibitRig.attach(owner, rig, &"fu_dog") as FuDogRig


## The lioness: the model's mirror image.
func set_mirror(on: bool) -> void:
	_mirrored = on
	if model != null:
		model.scale.x = -1.0 if on else 1.0


func mirrored() -> bool:
	return _mirrored


## How bright the pearl glows (0..1).
func pearl_glow() -> float:
	return _pearl


## A hit's push (world) rocks the body and whips the plume.
func jolt(impulse: Vector3) -> void:
	_jolt += impulse
	_tail_yaw.kick(randf_range(-2.5, 2.5))
	_tail_pitch.kick(randf_range(1.0, 2.5))


func _setup() -> void:
	_last_yaw = enemy.global_rotation.y if enemy.is_inside_tree() else 0.0


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var dormant := state == EnemyBrain.State.DORMANT
	var stunned := state == EnemyBrain.State.STUNNED
	var awake := not dormant and state != EnemyBrain.State.DESTROYED
	var winding := state == EnemyBrain.State.ATTACK and not brain.has_struck()
	var move := dog.move if state == EnemyBrain.State.ATTACK else FuDogMoves.Move.NONE
	var charging := dog.charging()
	var on_floor := enemy.is_on_floor()
	var walk := minf(gait, 1.0) if on_floor and not charging else 0.0
	var p := walk_phase
	# targets
	var roar := 0.0
	var lunge := 0.0
	var charge := 1.0 if charging or dog.skidding() > 0.0 else 0.0
	var scrape := 0.0
	var raise := 0.0
	var slam := 0.0
	var head_pitch := 0.0
	var jaw := -0.06 - 0.04 * sin(time * 1.7) if awake else 0.0
	var chest := 0.0
	var pitch := 0.0
	var pearl := 0.0
	var rate := 10.0
	if winding and move == FuDogMoves.Move.ROAR:
		roar = up
		pearl = MotionClip.eased(MotionClip.OUT, minf(w / PEARL_ON, 1.0))
		head_pitch = ROAR_HEAD * up
		jaw = ROAR_JAW * up
		chest = ROAR_CHEST * up
		pitch = 0.06 * up
		rate = 12.0
	elif winding and move == FuDogMoves.Move.CHARGE:
		head_pitch = CHARGE_HEAD * 1.5 * up
		pitch = 0.05 * up
		# two scrapes back with the right fore paw
		var k := fposmod(w * 2.0, 1.0)
		scrape = sin(k * PI) * clampf(w * 3.0, 0.0, 1.0)
		jaw = -0.2 * up
		rate = 16.0
	elif winding and move == FuDogMoves.Move.PAW:
		raise = up
		pitch = 0.08 * up
		head_pitch = 0.15 * up
		jaw = -0.25 * up
		rate = 12.0
	elif since_strike >= 0.0 and move == FuDogMoves.Move.ROAR:
		var t := since_strike
		lunge = 1.0 if t < 0.35 else 0.0
		jaw = ROAR_JAW_WIDE if t < 0.35 else -0.15
		head_pitch = 0.1 if t < 0.35 else 0.0
		pearl = maxf(0.0, 1.0 - t / 0.35)
		rate = 22.0
	elif since_strike >= 0.0 and move == FuDogMoves.Move.PAW:
		slam = 1.0 if since_strike < PAW_SLAM_TIME * 2.5 else 0.0
		pitch = -0.08 if since_strike < 0.3 else 0.0
		rate = 40.0 if since_strike < PAW_SLAM_TIME else 6.0
	elif charging:
		pitch = CHARGE_PITCH
		head_pitch = CHARGE_HEAD
		jaw = -0.3
		rate = 14.0
	if stunned:
		pitch = 0.05
		head_pitch = -0.15 + 0.1 * sin(time * 14.0)
		jaw = -0.35
	# ease
	_paw_down = ExhibitRig.ease_to(_paw_down, 0.0 if dormant else 1.0, 1.0 / PAW_DOWN_TIME * 2.2, delta)
	_roar = ExhibitRig.ease_to(_roar, roar, rate, delta)
	_lunge = ExhibitRig.ease_to(_lunge, lunge, 26.0, delta)
	_charge = ExhibitRig.ease_to(_charge, charge, 8.0, delta)
	_scrape = ExhibitRig.ease_to(_scrape, scrape, 24.0, delta)
	_raise = ExhibitRig.ease_to(_raise, raise, rate, delta)
	_slam = ExhibitRig.ease_to(_slam, slam, 40.0 if slam > _slam else 7.0, delta)
	_stun = ExhibitRig.ease_to(_stun, 1.0 if stunned else 0.0, 9.0 if stunned else 4.0, delta)
	_head_pitch = ExhibitRig.ease_to(_head_pitch, head_pitch, rate, delta)
	_jaw = ExhibitRig.ease_to(_jaw, jaw, rate, delta)
	_chest = ExhibitRig.ease_to(_chest, chest, rate, delta)
	_pitch = ExhibitRig.ease_to(_pitch, pitch, 9.0, delta)
	_pearl = ExhibitRig.ease_to(_pearl, pearl, 30.0 if pearl > _pearl else 10.0, delta)
	_head_yaw = ExhibitRig.ease_to(_head_yaw, _look_yaw() if awake and not stunned and not charging else 0.0, 5.0, delta)
	_jolt = _jolt.move_toward(Vector3.ZERO, 5.0 * delta)
	# the body: a heavy roll and dip walking, the gallop's bound charging,
	# the chest up roaring, the sag stunned
	var gallop_phase := p * 1.0
	var roll := sin(p) * 0.07 * walk
	var dip := -absf(sin(p)) * 0.04 * walk + absf(sin(gallop_phase)) * 0.06 * _charge
	var local_jolt := enemy.global_basis.inverse() * _jolt
	pose_part("body", Vector3(_pitch + local_jolt.z * 0.03 + 0.03 * sin(gallop_phase) * _charge, 0.0, roll - local_jolt.x * 0.03),
			Vector3(0.0, dip + _chest - 0.08 * _stun + 0.01 * sin(time * 1.3) * (1.0 if awake else 0.0), 0.0))
	var nod := -sin(p) * 0.04 * walk
	pose_part("head", Vector3(_head_pitch + nod + ROAR_LUNGE * 0.0, _head_yaw, 0.0),
			Vector3(0.0, 0.0, ROAR_LUNGE * 0.6 * _lunge))
	pose_part("jaw", Vector3(_jaw, 0.0, 0.0))
	_pose_legs(p, walk)
	_pose_tail(delta, awake)


## Lateral pairs walking (left legs together, right legs together), fore
## against hind galloping; the right fore paw down off the ball when awake,
## scraping in the charge's telegraph, raised and slammed for the paw;
## splayed stunned.
func _pose_legs(p: float, walk: float) -> void:
	var gallop := _charge
	for side in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		var ph := p if side == "l" else p + PI
		var fore := sin(ph) * WALK_SWING * walk * (1.0 - gallop) + sin(p) * GALLOP * gallop
		var hind := sin(ph) * WALK_SWING * walk * (1.0 - gallop) - sin(p) * GALLOP * gallop
		var fore_knee := -maxf(cos(ph), 0.0) * 0.35 * walk * (1.0 - gallop) - maxf(cos(p), 0.0) * 0.5 * gallop
		var hind_knee := maxf(cos(ph), 0.0) * 0.3 * walk * (1.0 - gallop) + maxf(cos(p + PI), 0.0) * 0.45 * gallop
		var splay := sign * 0.25 * _stun
		var leg_f := fore
		var shin_f := fore_knee
		if side == "r":
			# the raised paw: down off the ball awake, scraping, raised and slammed
			leg_f += PAW_DOWN_LEG * _paw_down + SCRAPE_BACK * _scrape + PAW_RAISE * _raise + PAW_SLAM * _slam
			shin_f += PAW_DOWN_SHIN * _paw_down + SCRAPE_UP * _scrape - 0.4 * _raise + 0.3 * _slam
		pose_part("leg_f" + side, Vector3(leg_f, 0.0, splay))
		pose_part("shin_f" + side, Vector3(shin_f, 0.0, 0.0))
		pose_part("leg_b" + side, Vector3(hind - 0.1 * _roar, 0.0, splay))
		pose_part("shin_b" + side, Vector3(hind_knee + 0.15 * _roar, 0.0, 0.0))


## The plume: on springs, swung by turns and jolts, swaying idly, up in
## the charge.
func _pose_tail(delta: float, awake: bool) -> void:
	var yaw := enemy.global_rotation.y
	var yaw_rate := angle_difference(_last_yaw, yaw) / maxf(delta, 0.0001)
	_last_yaw = yaw
	_tail_yaw.kick(clampf(-yaw_rate * 0.012, -0.5, 0.5))
	var idle := sin(time * 1.1) * 0.2 if awake else 0.0
	var sway := _tail_yaw.step(idle, delta)
	var pitch := _tail_pitch.step(0.25 * _charge + 0.1 * _roar, delta)
	pose_part("tail", Vector3(pitch, sway, 0.0))


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


## The body glows for the charge and the paw; the roar lights the pearl alone.
func _glow_amount() -> float:
	if enemy.brain.state == EnemyBrain.State.ATTACK and dog.move == FuDogMoves.Move.ROAR:
		return 0.0
	return enemy.brain.windup_progress()


func _update_shading(delta: float) -> void:
	var before := _shading
	super(delta)
	var pearl := part("pearl") as MeshInstance3D
	if pearl == null:
		return
	if before != _shading or not is_equal_approx(_pearl, _pearl_applied):
		_pearl_applied = _pearl
		pearl.set_instance_shader_parameter(&"glow", maxf(_pearl, _shading.y))
