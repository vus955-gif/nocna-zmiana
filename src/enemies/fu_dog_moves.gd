class_name FuDogMoves
extends RefCounted
## The bronze Fu dog's pure logic (design pietro-1-projekt 5.5): which move
## it starts (choose: the paw up close and in front, the roar or the charge
## on a guard in the roar's cone by a roll against its roar bias, the charge
## from afar), the roar's cone (roar_hits), the charge's steer (only
## TURN_RATE and only for the first TURN_TIME: a committed run), and the
## Pair: the lion and the lioness of neighbouring slots charge one at a
## time and never while the guard reels from a roar.

enum Move { NONE, CHARGE, ROAR, PAW }

const CHARGE_RANGE := Vector2(4.0, 12.0)
const ROAR_RANGE := 6.0
const ROAR_HALF_ARC := 40.0
const PAW_RANGE := 2.6
const PAW_HALF_ARC := 50.0
## Telegraphs (s).
const CHARGE_WINDUP := 0.8
const ROAR_WINDUP := 0.7
const PAW_WINDUP := 0.6
## The charge: speed, at most this long and this far, one hit, a wall
## stuns it, a miss skids and comes round.
const CHARGE_SPEED := 6.0
const CHARGE_TIME := 1.8
const CHARGE_DISTANCE := 10.0
const CHARGE_DAMAGE := 22.0
const CHARGE_KNOCKBACK := 10.0
const WALL_STUN := 1.4
const SKID := 0.5
const CHARGE_RETURN := 0.9
## The charge steers at most this (rad/s) and only this long (s).
const TURN_RATE := 0.5
const TURN_TIME := 0.3
## The roar: the guard reels this long; the roar comes back after this.
const ROAR_STAGGER := 0.5
const ROAR_COOLDOWN := 6.0
## A hit on the glowing pearl in the roar's telegraph chokes it: stunned this long.
const PEARL_STUN := 1.2
const PAW_DAMAGE := 14.0
const PAW_KNOCKBACK := 7.0
## The roll (0..1) under which it roars rather than charges, lion / lioness.
const LION_ROAR_BIAS := 0.4
const LIONESS_ROAR_BIAS := 0.6


## The move for a guard [param distance] metres away, [param off_front_deg]
## off the dog's front: the paw up close in its cone; in the roar's cone
## with the roar ready, the roar or (with leave and room) the charge by
## [param roll] against [param roar_bias]; the charge in its band with
## [param charge_ok]; else nothing (it closes in or turns).
static func choose(distance: float, off_front_deg: float, roar_ready: bool, charge_ok: bool, roll: float, roar_bias: float) -> Move:
	if distance <= PAW_RANGE:
		return Move.PAW if off_front_deg <= PAW_HALF_ARC else Move.NONE
	var can_charge := charge_ok and distance >= CHARGE_RANGE.x and distance <= CHARGE_RANGE.y
	if distance <= ROAR_RANGE and off_front_deg <= ROAR_HALF_ARC and roar_ready:
		if can_charge and roll >= roar_bias:
			return Move.CHARGE
		return Move.ROAR
	if can_charge:
		return Move.CHARGE
	return Move.NONE


## True when a roar from [param mouth] along [param forward] reaches a
## guard at [param guard]: within ROAR_RANGE on the floor plan, inside the cone.
static func roar_hits(mouth: Vector3, forward: Vector3, guard: Vector3) -> bool:
	var to := Vector3(guard.x - mouth.x, 0.0, guard.z - mouth.z)
	var distance := to.length()
	if distance > ROAR_RANGE or distance < 0.001:
		return false
	var look := Vector3(forward.x, 0.0, forward.z)
	if look.length_squared() < 0.0001:
		return false
	return look.normalized().dot(to / distance) >= cos(deg_to_rad(ROAR_HALF_ARC))


## Where the charge runs this frame: [param direction] turned toward
## [param to_guard] by at most TURN_RATE * [param delta], and only within
## the first TURN_TIME seconds ([param elapsed]); after that straight on.
static func charge_turn(direction: Vector3, to_guard: Vector3, elapsed: float, delta: float) -> Vector3:
	if elapsed >= TURN_TIME:
		return direction
	var want := Vector3(to_guard.x, 0.0, to_guard.z)
	if want.length_squared() < 0.0001:
		return direction
	want = want.normalized()
	var angle := direction.signed_angle_to(want, Vector3.UP)
	var step := clampf(angle, -TURN_RATE * delta, TURN_RATE * delta)
	return direction.rotated(Vector3.UP, step).normalized()


## The windup of [param move].
static func windup(move: Move) -> float:
	match move:
		Move.CHARGE:
			return CHARGE_WINDUP
		Move.ROAR:
			return ROAR_WINDUP
		Move.PAW:
			return PAW_WINDUP
	return PAW_WINDUP


## The brain's recovery after [param move] struck.
static func recovery(move: Move) -> float:
	match move:
		Move.CHARGE:
			return CHARGE_TIME + SKID + CHARGE_RETURN
		Move.ROAR:
			return 0.9
	return 0.8


## The lion and the lioness of neighbouring slots: one charge at a time,
## none while the guard reels; the lioness roars more.
class Pair:
	extends RefCounted
	var a: Object
	var b: Object
	var charging: Object = null


	func _init(first: Object, second: Object) -> void:
		a = first
		b = second


	## The other dog of the pair (null for a stranger).
	func other(dog: Object) -> Object:
		if dog == a:
			return b
		if dog == b:
			return a
		return null


	## True when [param dog] may start a charge: nobody else of the pair is
	## charging (a charger that fell frees it) and the guard is on his feet.
	func may_charge(dog: Object, guard_staggered: bool) -> bool:
		if guard_staggered:
			return false
		if charging != null and not is_instance_valid(charging):
			charging = null
		return charging == null or charging == dog


	func begin_charge(dog: Object) -> void:
		charging = dog


	func end_charge(dog: Object) -> void:
		if charging == dog:
			charging = null


	## The roll under which [param dog] roars rather than charges: the
	## second of the pair is the lioness and roars more.
	func roar_bias(dog: Object) -> float:
		return LIONESS_ROAR_BIAS if dog == b else LION_ROAR_BIAS
