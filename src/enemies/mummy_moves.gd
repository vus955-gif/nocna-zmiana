class_name MummyMoves
extends RefCounted
## The mummy's fighting rules as pure logic (design pietro-1-projekt 5.1),
## tested without a scene; Mummy asks it every frame.
## - Two attacks: the claws up close, and the bandage lash between LASH_MIN
##   and LASH_MAX (its 0.6 s telegraph; the aim freezes for the last
##   LASH_AIM_LOCK of it, so a dash aside or a step back escapes) that pulls
##   the guard PULL metres in (never closer than PULL_STOP) and slows him;
##   after a lash only the claws for LASH_COOLDOWN seconds.
## - Fire: the bandages catch and it runs in panic for PANIC_TIME seconds
##   (away from the guard, zigzagging), at most once every PANIC_COOLDOWN.
## - Climbing out of its tomb: three phases per style (coffin: the lid falls,
##   it leans out, it steps down; sarcophagus: the lid slides off, it sits
##   up, it swings its legs over and stands).

enum Move { CLAW, LASH }
enum Tomb { COFFIN, SARCOPHAGUS }

## The claws: brain range, windup and recovery (s).
const CLAW_RANGE := 1.7
const CLAW_WINDUP := 0.6
const CLAW_RECOVERY := 0.8
## The lash: its band (m), telegraph and recovery (s), its cone (full
## half-angle, degrees, on the floor plan), the slack added to its reach at
## the strike, how long before the strike the aim freezes, its cooldown.
const LASH_MIN := 2.4
const LASH_MAX := 4.6
const LASH_WINDUP := 0.6
const LASH_RECOVERY := 1.1
const LASH_CONE_DEG := 18.0
const LASH_SLACK := 0.3
const LASH_AIM_LOCK := 0.15
const LASH_COOLDOWN := 4.0
const LASH_DAMAGE := 8.0
## The pull: at most PULL metres, never closer than PULL_STOP to the mummy,
## over PULL_TIME seconds; then SLOW of his speed for SLOW_TIME seconds.
const PULL := 3.0
const PULL_STOP := 1.2
const PULL_TIME := 0.25
const SLOW := 0.5
const SLOW_TIME := 1.0
## Fire: the panic, its cooldown, a new swerve every PANIC_TURN seconds of
## up to PANIC_SWERVE radians off "straight away", its pace (share of the
## walking speed); the bandages' burn (damage per second before linen's x2,
## seconds).
const PANIC_TIME := 2.0
const PANIC_COOLDOWN := 5.0
const PANIC_TURN := 0.5
const PANIC_SWERVE := 0.9
const PANIC_PACE := 1.6
const BURN_DPS := 4.0
const BURN_TIME := 3.0
## Seconds per phase of climbing out.
const COFFIN_PHASES := Vector3(0.45, 0.35, 0.6)
const SARCOPHAGUS_PHASES := Vector3(0.6, 0.6, 0.7)

## Seconds until the lash may be used again.
var lash_ready_in: float = 0.0
## Seconds of panic left.
var panic_left: float = 0.0
## Seconds until fire may panic it again.
var panic_ready_in: float = 0.0


func tick(delta: float) -> void:
	lash_ready_in = maxf(lash_ready_in - delta, 0.0)
	panic_left = maxf(panic_left - delta, 0.0)
	panic_ready_in = maxf(panic_ready_in - delta, 0.0)


func lash_ready() -> bool:
	return lash_ready_in <= 0.0


func panicking() -> bool:
	return panic_left > 0.0


## The attack it would start with the guard [param distance] away.
func planned(distance: float) -> Move:
	if lash_ready() and distance > LASH_MIN and distance <= LASH_MAX:
		return Move.LASH
	return Move.CLAW


## The brain's attack range now: the whip's reach while the lash is ready
## and the guard stands beyond LASH_MIN, else the claws'.
func attack_range(distance: float) -> float:
	return LASH_MAX if lash_ready() and distance > LASH_MIN else CLAW_RANGE


func windup(move: Move) -> float:
	return LASH_WINDUP if move == Move.LASH else CLAW_WINDUP


func recovery(move: Move) -> float:
	return LASH_RECOVERY if move == Move.LASH else CLAW_RECOVERY


## The lash has struck (hit or not): claws only for LASH_COOLDOWN.
func lash_struck() -> void:
	lash_ready_in = LASH_COOLDOWN


## True when the lash reaches a guard at [param to_guard] (from the
## mummy) while it faces [param facing]: in reach and in its cone, both
## on the floor plan.
func lash_hits(facing: Vector3, to_guard: Vector3) -> bool:
	var look := Vector2(facing.x, facing.z)
	var to := Vector2(to_guard.x, to_guard.z)
	if look.length_squared() < 0.0001 or to.length_squared() < 0.0001:
		return false
	if to.length() > LASH_MAX + LASH_SLACK:
		return false
	return look.normalized().dot(to.normalized()) >= cos(deg_to_rad(LASH_CONE_DEG))


## How far the lash drags a guard standing [param distance] away (floor
## plan): PULL, but never closer than PULL_STOP.
static func pull_distance(distance: float) -> float:
	return clampf(minf(PULL, distance - PULL_STOP), 0.0, PULL)


## Fire on its bandages: true when it panics now (not while it already
## panics, nor within PANIC_COOLDOWN of the last panic's start).
func catch_fire() -> bool:
	if panicking() or panic_ready_in > 0.0:
		return false
	panic_left = PANIC_TIME
	panic_ready_in = PANIC_COOLDOWN
	return true


## A fresh panic heading: [param away] (from the guard, flattened) turned
## by up to PANIC_SWERVE either way.
func panic_heading(away: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var flat := Vector3(away.x, 0.0, away.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
	var swerve := rng.randf_range(-PANIC_SWERVE, PANIC_SWERVE)
	return flat.normalized().rotated(Vector3.UP, swerve)


## Seconds the climb out of a [param style] tomb takes.
static func rise_length(style: Tomb) -> float:
	var phases := _phases(style)
	return phases.x + phases.y + phases.z


## Progress (0..1) of each of the three phases [param seconds] into the
## climb out of a [param style] tomb.
static func rise_phases(style: Tomb, seconds: float) -> Vector3:
	var phases := _phases(style)
	var first := clampf(seconds / phases.x, 0.0, 1.0)
	var second := clampf((seconds - phases.x) / phases.y, 0.0, 1.0)
	var third := clampf((seconds - phases.x - phases.y) / phases.z, 0.0, 1.0)
	return Vector3(first, second, third)


static func _phases(style: Tomb) -> Vector3:
	return SARCOPHAGUS_PHASES if style == Tomb.SARCOPHAGUS else COFFIN_PHASES
