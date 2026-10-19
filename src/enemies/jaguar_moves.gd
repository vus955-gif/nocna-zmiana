class_name JaguarMoves
extends RefCounted
## The jaguar warrior's pure logic (design pietro-1-projekt 5.6, kit
## docs/art/kit-pietro1-ameryki.md 9): which attack it starts by distance
## (the club up close, the pounce from POUNCE_RANGE), the pounce's leap
## (heavier than the wolf's: LIFT, capped at MAX_SPEED, aimed to land
## STOP_SHORT metres before the guard), the phases of the club combination
## after landing (settling on bent knees, the swing, the club stuck in the
## floor: the opening), the club's cone and the recoveries.

enum Move { NONE, POUNCE, CLUB }
enum Phase { NONE, AIR, SETTLE, SWING, STUCK, DONE }

## The brain's attack range for the club (m) and the pounce's band (m).
const CLUB_RANGE := 2.4
const POUNCE_RANGE := Vector2(3.0, 7.0)
## It lands this far before the guard (m).
const STOP_SHORT := 1.4
## Phases after landing (s): the knees take the fall, the club comes down,
## the club stays in the floor.
const SETTLE := 0.25
const SWING := 0.22
const STUCK := 0.8
## The telegraph (s): the crouch before a pounce, the club raised overhead
## before a close blow.
const WINDUP := 0.6
## The leap: vertical speed (m/s) and the cap on the horizontal one.
const LIFT := 3.2
const MAX_SPEED := 10.0
## A hop at least, when the guard is right there (m/s).
const MIN_SPEED := 2.5
## The club's blow: reach (m), cone (half-angle, degrees), damage, knockback.
const SWING_REACH := 2.5
const SWING_HALF_ARC := 55.0
const CLUB_DAMAGE := 18.0
const CLUB_KNOCKBACK := 6.0
## A guard higher than this over the jaguar's feet is out of the club's reach (m).
const SWING_HEIGHT := 1.0


## The attack for a guard [param distance] metres away: the club inside
## the pounce's band, the pounce in it, nothing beyond (it closes in).
static func choose(distance: float) -> Move:
	if distance < POUNCE_RANGE.x:
		return Move.CLUB
	if distance <= POUNCE_RANGE.y:
		return Move.POUNCE
	return Move.NONE


## Seconds a leap of [param lift] stays in the air under [param gravity].
static func airtime(lift: float, gravity: float) -> float:
	return 2.0 * lift / maxf(gravity, 0.001)


## The horizontal speed (m/s) of a leap from [param from] that lands
## STOP_SHORT before [param to] in its airtime, at most [param max_speed].
static func leap(from: Vector3, to: Vector3, lift: float, gravity: float, max_speed: float) -> Vector3:
	var run := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var distance := run.length()
	if distance < 0.01:
		return Vector3.ZERO
	var direction := run / distance
	var span := maxf(distance - STOP_SHORT, 0.0)
	return direction * clampf(span / airtime(lift, gravity), MIN_SPEED, max_speed)


## The phase [param t] seconds after landing (negative: still in the air).
static func phase_after_landing(t: float) -> Phase:
	if t < 0.0:
		return Phase.AIR
	if t < SETTLE:
		return Phase.SETTLE
	if t < SETTLE + SWING:
		return Phase.SWING
	if t < SETTLE + SWING + STUCK:
		return Phase.STUCK
	return Phase.DONE


## Seconds after landing when the blow lands (the end of the swing).
static func swing_time() -> float:
	return SETTLE + SWING


## True when the club, swung by a warrior facing [param facing], finds a
## guard [param to_target] away: within [param reach] on the floor plan,
## inside the cone, not a storey up.
static func swing_hits(facing: Vector3, to_target: Vector3, reach: float, half_arc_deg: float) -> bool:
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance > reach or distance < 0.001 or absf(to_target.y) > SWING_HEIGHT:
		return false
	var look := Vector3(facing.x, 0.0, facing.z)
	if look.length_squared() < 0.0001:
		return false
	return look.normalized().dot(flat / distance) >= cos(deg_to_rad(half_arc_deg))


## The brain's recovery after a pounce: the flight, the settling, the
## swing and the club stuck in the floor (a little slack for the landing).
static func pounce_recovery(lift: float, gravity: float) -> float:
	return airtime(lift, gravity) + SETTLE + SWING + STUCK + 0.2


## The brain's recovery after a close blow: the swing and the stuck club.
static func club_recovery() -> float:
	return SWING + STUCK


## The telegraph of [param move].
static func windup(_move: Move) -> float:
	return WINDUP
