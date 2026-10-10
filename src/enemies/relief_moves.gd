class_name ReliefMoves
extends RefCounted
## The rules of the figures that step out of the Assyrian wall reliefs
## (design pietro-1-projekt 5.2) as pure logic:
## - flat: a hit on the edge (more than EDGE_ANGLE off the carved face)
##   does EDGE_FACTOR of its damage;
## - stepping out of the wall: the panel cracks and glows CRACK_TIME, then
##   the figure steps out STEP_OUT metres in STEP_TIME; sinking back takes
##   SINK_TIME and it travels hidden in the wall TRAVEL_TIME before coming
##   out SLIDE metres along it (at most once every WALL_COOLDOWN);
## - the warrior's moves: the spear thrown in an arc (THROW_RANGE, a
##   ballistic aim), the strike up close, a quick sidestep (SIDESTEP m in
##   SIDESTEP_TIME, at most every SIDESTEP_COOLDOWN) when the guard aims at
##   it, and the timers of all of them.

enum Move { STRIKE, THROW }
## Where a relief figure is with its wall.
enum Wall { IN, CRACKING, STEPPING, OUT, SINKING, TRAVELLING }

const EDGE_ANGLE := 60.0
const EDGE_FACTOR := 0.5
const CRACK_TIME := 0.8
const STEP_TIME := 0.5
const STEP_OUT := 0.75
## Where a figure stands in its slab (m off the wall's face; ReliefPanel).
const FLUSH := 0.1
const SINK_TIME := 0.5
const TRAVEL_TIME := 0.4
## Re-emerging: the crack before it steps out again is shorter.
const RECRACK_TIME := 0.5
const SLIDE := 6.0
const WALL_COOLDOWN := 8.0
## A wall this close (m) behind or beside it is one it can sink into.
const WALL_REACH := 1.5
const THROW_RANGE := Vector2(6.0, 16.0)
const THROW_SPEED := 16.0
const THROW_GRAVITY := 9.0
const THROW_DAMAGE := 14.0
const THROW_WINDUP := 0.8
const THROW_RECOVERY := 0.6
const THROW_COOLDOWN := 3.5
const STRIKE_RANGE := 1.8
const STRIKE_DAMAGE := 12.0
const STRIKE_WINDUP := 0.5
const STRIKE_RECOVERY := 0.7
const SIDESTEP := 2.0
const SIDESTEP_TIME := 0.25
const SIDESTEP_COOLDOWN := 1.6
## The guard aims at it when his view passes within this angle (degrees).
const AIMED_AT_DEG := 8.0

var throw_ready_in: float = 0.0
var sidestep_ready_in: float = 0.0
var wall_ready_in: float = 0.0


func tick(delta: float) -> void:
	throw_ready_in = maxf(throw_ready_in - delta, 0.0)
	sidestep_ready_in = maxf(sidestep_ready_in - delta, 0.0)
	wall_ready_in = maxf(wall_ready_in - delta, 0.0)


## Share of a hit's damage that lands: EDGE_FACTOR when it travels along
## [param hit_direction] onto the figure's edge (the figure faces
## [param facing]), else all of it.
static func edge_factor(facing: Vector3, hit_direction: Vector3) -> float:
	var face := Vector2(facing.x, facing.z)
	var toward := Vector2(-hit_direction.x, -hit_direction.z)
	if face.length_squared() < 0.0001 or toward.length_squared() < 0.0001:
		return 1.0
	var off := absf(face.normalized().dot(toward.normalized()))
	return EDGE_FACTOR if off < cos(deg_to_rad(EDGE_ANGLE)) else 1.0


## The launch velocity of a spear from [param from] to land on
## [param to] at [param speed] under [param gravity] (the low arc), or null
## when it cannot reach.
static func throw_velocity(from: Vector3, to: Vector3, speed: float = THROW_SPEED, gravity: float = THROW_GRAVITY) -> Variant:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	if d < 0.01:
		return null
	var h := to.y - from.y
	var v2 := speed * speed
	var root := v2 * v2 - gravity * (gravity * d * d + 2.0 * h * v2)
	if root < 0.0:
		return null
	var angle := atan((v2 - sqrt(root)) / (gravity * d))
	return flat.normalized() * cos(angle) * speed + Vector3.UP * sin(angle) * speed


## The move it would start with the guard [param distance] away.
func planned(distance: float) -> Move:
	if throw_ready_in <= 0.0 and distance >= THROW_RANGE.x and distance <= THROW_RANGE.y:
		return Move.THROW
	return Move.STRIKE


func attack_range(distance: float) -> float:
	return THROW_RANGE.y if throw_ready_in <= 0.0 and distance >= THROW_RANGE.x else STRIKE_RANGE


func windup(move: Move) -> float:
	return THROW_WINDUP if move == Move.THROW else STRIKE_WINDUP


func recovery(move: Move) -> float:
	return THROW_RECOVERY if move == Move.THROW else STRIKE_RECOVERY


func thrown() -> void:
	throw_ready_in = THROW_COOLDOWN


## True (and the cooldown starts) when it may sidestep now.
func sidestep() -> bool:
	if sidestep_ready_in > 0.0:
		return false
	sidestep_ready_in = SIDESTEP_COOLDOWN
	return true


## True (and the cooldown starts) when it may sink into the wall now.
func sink() -> bool:
	if wall_ready_in > 0.0:
		return false
	wall_ready_in = WALL_COOLDOWN
	return true


## True when a guard looking along [param view] from [param eye] aims at
## [param point] (within AIMED_AT_DEG).
static func aimed_at(eye: Vector3, view: Vector3, point: Vector3) -> bool:
	var to := point - eye
	if to.length_squared() < 0.0001 or view.length_squared() < 0.0001:
		return false
	return view.normalized().dot(to.normalized()) >= cos(deg_to_rad(AIMED_AT_DEG))


## The two places SLIDE metres either way along a wall through
## [param point] with outward normal [param normal] (flat), the one
## farther from [param away_from] first.
static func slide_spots(point: Vector3, normal: Vector3, away_from: Vector3, slide: float = SLIDE) -> Array[Vector3]:
	var along := Vector3(normal.x, 0.0, normal.z).normalized().cross(Vector3.UP)
	var a := point + along * slide
	var b := point - along * slide
	var spots: Array[Vector3] = [a, b]
	if a.distance_to(away_from) < b.distance_to(away_from):
		spots = [b, a]
	return spots
