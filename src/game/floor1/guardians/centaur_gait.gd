class_name CentaurGait
extends RefCounted
## The Centaur's four legs as pure timing and footing (the guardians'
## pattern: docs/superpowers/plans/2026-10-03-straznik-kentaur.md). One
## cycle (phase [member cycle], 0..1, advancing at the stride frequency)
## carries every leg through its stance (the hoof planted where it landed,
## in the world - it never slides) and its swing (the hoof lifts, arcs and
## lands where, half a stance later, it will stand under its shoulder or
## hip). Each gait is a table of the four legs' phase offsets and the share
## of the cycle a hoof stands:
## - walk: four beats, lateral (left hind, left fore, right hind, right fore);
## - trot: diagonal pairs;
## - canter: three beats (outer hind, the diagonal pair, the leading fore),
##   then a moment of flight;
## - gallop: four beats, transverse (hind, hind, fore, fore - the leading
##   pair last), then flight with the legs gathered under it.
## The speed picks the gait; the offsets, the share, the frequency and the
## lift chase the gait's values, so it changes gait (and lead, to the side
## it turns) smoothly. Standing, a hoof only steps when the body moved or
## turned away from it (it settles under its shoulder); turning on the spot
## is stepping on the spot. Legs: 0 left fore, 1 right fore, 2 left hind,
## 3 right hind. World space in, world space out: the body's origin is on
## the floor under the barrel, -Z its front.

## A hoof came down (dust, a clatter) or lifted.
signal touchdown(leg: int)
signal liftoff(leg: int)

enum Gait { WALK, TROT, CANTER, GALLOP }

const LEGS := 4
const NAMES: Array[String] = ["fl", "fr", "bl", "br"]
## The fetlock pivot's height over the floor when the hoof stands.
const HOOF_HEIGHT := 0.17
## Each hoof's resting point (body space: the fetlock pivot under its leg).
const NEUTRAL: Array[Vector3] = [Vector3(-0.2, HOOF_HEIGHT, -0.68), Vector3(0.2, HOOF_HEIGHT, -0.68),
	Vector3(-0.22, HOOF_HEIGHT, 0.84), Vector3(0.22, HOOF_HEIGHT, 0.84)]
## Per gait (right lead): phase offsets [fl, fr, bl, br] (left hind lands at
## 0; values past 1 keep the blends between gaits short), stance share,
## stride frequency (Hz), swing lift (m).
const OFFSETS := {
	Gait.WALK: [0.25, 0.75, 0.0, 0.5],
	Gait.TROT: [0.5, 1.0, 0.0, 0.5],
	Gait.CANTER: [0.22, 1.44, 0.0, 0.22],
	Gait.GALLOP: [0.32, 1.42, 0.0, 0.1],
}
const DUTY := {Gait.WALK: 0.62, Gait.TROT: 0.38, Gait.CANTER: 0.3, Gait.GALLOP: 0.22}
const FREQUENCY := {Gait.WALK: 1.05, Gait.TROT: 1.7, Gait.CANTER: 2.0, Gait.GALLOP: 2.4}
const LIFT := {Gait.WALK: 0.13, Gait.TROT: 0.22, Gait.CANTER: 0.28, Gait.GALLOP: 0.32}
## Speeds (m/s) over which each gait holds: [from, to] (between two gaits
## it blends).
const SPEEDS := {Gait.WALK: [0.0, 1.1], Gait.TROT: [1.9, 3.8], Gait.CANTER: [4.6, 6.4], Gait.GALLOP: [7.6, 99.0]}
## Faster than the gallop's speed the stride quickens this much per m/s.
const GALLOP_QUICKEN := 0.045
## A hoof sweeps at most this far under the body while it stands (m): the
## stance share shrinks at speed so the legs reach.
const MAX_SWEEP := 0.78
## How fast the gait's numbers chase their targets: gait units, stance
## share and stride frequency (Hz) per second.
const BLEND_RATE := 2.2
const DUTY_RATE := 1.5
const FREQUENCY_RATE := 4.0
## A standing hoof lifts at the latest this much past its stance's time, or
## once the body has run this far past it (m) - when a change of gait made
## it miss its beat.
const OVERDUE := 1.25
const LEFT_BEHIND := 0.5
## The shortest swing (s).
const MIN_SWING := 0.11
## Below this the body counts as standing (m/s; turning counts as moving
## with TURN_ARM m of lever).
const MOVE_MIN := 0.25
const TURN_ARM := 0.9
## Standing, a hoof this far off its resting point steps back under.
const SETTLE := 0.16
## How far ahead a swinging hoof leads a turn (rad at most).
const TURN_LEAD := 0.6

## 0..1 through the stride.
var cycle: float = 0.0
## The gait now as a number: 0 walk, 1 trot, 2 canter, 3 gallop (blends
## between).
var gait: float = 0.0
## +1 right lead, -1 left lead (the leading fore lands last).
var lead: float = 1.0
var duty: float = 0.62
var frequency: float = 1.05
var lift: float = 0.13
## The body's flat speed and turn rate (rad/s, + to its left) last update.
var speed: float = 0.0
var yaw_rate: float = 0.0
## Stepping now (some hoof swings, or the body moves).
var stepping := false

var _offsets: Array[float] = [0.25, 0.75, 0.0, 0.5]
var _stance: Array[bool] = [true, true, true, true]
var _planted: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _hoof: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _swing_time: Array[float] = [0.3, 0.3, 0.3, 0.3]
var _swing_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _swing_lift: Array[float] = [0.2, 0.2, 0.2, 0.2]
var _stance_age: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _placed := false
var _yaw: float = 0.0


## Plants every hoof at its resting point under [param body] (a fresh
## start, a teleport).
func place(body: Transform3D) -> void:
	_placed = true
	_yaw = _yaw_of(body)
	yaw_rate = 0.0
	speed = 0.0
	stepping = false
	for leg in LEGS:
		_stance[leg] = true
		_planted[leg] = _floor_point(body, NEUTRAL[leg])
		_hoof[leg] = _planted[leg]
		_swing_age[leg] = 0.0


## Advances by [param delta] with the body at [param body] moving at
## [param velocity] (world).
func update(delta: float, body: Transform3D, velocity: Vector3) -> void:
	if not _placed:
		place(body)
	if delta <= 0.0:
		return
	var yaw := _yaw_of(body)
	var turn := wrapf(yaw - _yaw, -PI, PI) / delta
	_yaw = yaw
	yaw_rate = lerpf(yaw_rate, turn, clampf(delta * 12.0, 0.0, 1.0))
	speed = Vector2(velocity.x, velocity.z).length()
	var drive := maxf(speed, absf(yaw_rate) * TURN_ARM)
	_blend(drive, delta)
	var moving := drive > MOVE_MIN
	var swinging := _stance.has(false)
	var unsettled := not moving and _unsettled(body)
	stepping = moving or swinging or unsettled
	if not stepping:
		return
	var before := cycle
	cycle = fposmod(cycle + frequency * delta, 1.0)
	var advanced := frequency * delta
	for leg in LEGS:
		if _stance[leg]:
			_stance_age[leg] += delta
			var lift_at := fposmod(_offsets[leg] + duty, 1.0)
			var due := _crossed(before, advanced, lift_at) and (moving or _off_rest(body, leg) > SETTLE)
			var late := moving and (_stance_age[leg] > OVERDUE / frequency or _behind(body, leg) > LEFT_BEHIND)
			if due or late:
				_lift(leg)
		else:
			_swing_age[leg] += delta
			if _swing_age[leg] >= _swing_time[leg]:
				_land(leg, body, velocity)
	for leg in LEGS:
		if not _stance[leg]:
			_hoof[leg] = _swing_point(leg, body, velocity)


## The hoof (fetlock pivot) of [param leg] now, world.
func hoof(leg: int) -> Vector3:
	return _hoof[leg]


## True while [param leg] stands.
func standing(leg: int) -> bool:
	return _stance[leg]


## 0 while [param leg] stands, 0..1 through its swing.
func swing(leg: int) -> float:
	if _stance[leg]:
		return 0.0
	return clampf(_swing_age[leg] / maxf(_swing_time[leg], 0.001), 0.0, 1.0)


## How much of the gait now is [param kind] (0..1; the four add up to 1).
func weight(kind: Gait) -> float:
	return clampf(1.0 - absf(gait - float(kind)), 0.0, 1.0)


## Where in its own stance [param leg] is (0 landing .. 1 lifting), or -1
## while it swings.
func stance_progress(leg: int) -> float:
	if not _stance[leg]:
		return -1.0
	return clampf(fposmod(cycle - _offsets[leg], 1.0) / maxf(duty, 0.01), 0.0, 1.0)


## The gait's numbers for a body going [param drive] m/s: [gait, duty,
## frequency, lift].
static func numbers_for(drive: float) -> Array[float]:
	var g := 0.0
	for i in range(1, 4):
		var low: float = SPEEDS[i - 1][1]
		var high: float = SPEEDS[i][0]
		if drive >= high:
			g = float(i)
		elif drive > low:
			g = float(i - 1) + (drive - low) / (high - low)
			break
		else:
			break
	return _numbers_at(g, drive)


static func _numbers_at(g: float, drive: float) -> Array[float]:
	var low := clampi(floori(g), 0, 3)
	var high := clampi(low + 1, 0, 3)
	var k := clampf(g - float(low), 0.0, 1.0)
	var frequency_ := lerpf(FREQUENCY[low], FREQUENCY[high], k)
	if g >= 3.0:
		frequency_ += maxf(drive - float(SPEEDS[Gait.GALLOP][0]), 0.0) * GALLOP_QUICKEN
	var duty_ := lerpf(DUTY[low], DUTY[high], k)
	if drive > 0.01:
		duty_ = minf(duty_, MAX_SWEEP * frequency_ / drive)
	return [g, maxf(duty_, 0.12), frequency_, lerpf(LIFT[low], LIFT[high], k)]


# --- inside ----------------------------------------------------------------------

func _blend(drive: float, delta: float) -> void:
	var wanted := numbers_for(drive)
	gait = move_toward(gait, wanted[0], BLEND_RATE * delta)
	var now := _numbers_at(gait, drive)
	duty = move_toward(duty, now[1], DUTY_RATE * delta)
	frequency = move_toward(frequency, now[2], FREQUENCY_RATE * delta)
	lift = now[3]
	# the lead follows the turn (a flying change, smoothed by the offsets)
	if absf(yaw_rate) > 0.35 and speed > float(SPEEDS[Gait.TROT][1]):
		lead = -1.0 if yaw_rate > 0.0 else 1.0
	var low := clampi(floori(gait), 0, 3)
	var high := clampi(low + 1, 0, 3)
	var k := clampf(gait - float(low), 0.0, 1.0)
	for leg in LEGS:
		var source := leg if lead > 0.0 else _mirror(leg)
		var target := lerpf(float(OFFSETS[low][source]), float(OFFSETS[high][source]), k)
		# the nearest way round the circle (an offset counts modulo 1)
		var gap := wrapf(target - _offsets[leg], -0.5, 0.5)
		_offsets[leg] += clampf(gap, -BLEND_RATE * 0.5 * delta, BLEND_RATE * 0.5 * delta)


static func _mirror(leg: int) -> int:
	return [1, 0, 3, 2][leg]


## True when a cycle that advanced by [param advanced] from [param before]
## passed [param point] (on the circle).
static func _crossed(before: float, advanced: float, point: float) -> bool:
	var ahead := fposmod(point - before, 1.0)
	return ahead > 0.0 and ahead <= advanced


func _lift(leg: int) -> void:
	_stance[leg] = false
	_from[leg] = _planted[leg]
	_swing_age[leg] = 0.0
	# it lands on its beat: when the cycle comes round to its offset (a hoof
	# that lifted late skips to the beat after, rather than a hop)
	var to_beat := fposmod(_offsets[leg] - cycle, 1.0) / frequency
	if to_beat < MIN_SWING:
		to_beat += 1.0 / frequency
	_swing_time[leg] = to_beat
	_swing_lift[leg] = lift
	liftoff.emit(leg)
	_stance_age[leg] = 0.0


func _land(leg: int, body: Transform3D, velocity: Vector3) -> void:
	_stance[leg] = true
	_stance_age[leg] = 0.0
	_planted[leg] = _target(leg, body, velocity, 0.0)
	_hoof[leg] = _planted[leg]
	touchdown.emit(leg)


## Where a swinging [param leg]'s hoof is now: from where it lifted toward
## where it will land, up in an arc.
func _swing_point(leg: int, body: Transform3D, velocity: Vector3) -> Vector3:
	var w := swing(leg)
	var left := maxf(_swing_time[leg] - _swing_age[leg], 0.0)
	var to := _target(leg, body, velocity, left)
	var along := w * w * (3.0 - 2.0 * w)
	var point := _from[leg].lerp(to, along)
	# a hoof folds up early and reaches forward late
	var arc := sin(PI * pow(w, 0.8))
	point.y += _swing_lift[leg] * arc
	return point


## Where [param leg] lands if it lands [param ahead] s from now: under its
## shoulder or hip half a stance after that, the body carried on by its
## velocity and its turn.
func _target(leg: int, body: Transform3D, velocity: Vector3, ahead: float) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	# half a stance ahead - never further than half the longest sweep
	var half := minf(duty / maxf(frequency, 0.01) * 0.5, MAX_SWEEP * 0.5 / maxf(flat.length(), 0.1))
	var t := ahead + half
	var turn := clampf(yaw_rate * t, -TURN_LEAD, TURN_LEAD)
	var later := Transform3D(Basis(Vector3.UP, turn) * body.basis.orthonormalized(), body.origin + flat * t)
	return _floor_point(later, NEUTRAL[leg])


## How far [param leg]'s planted hoof is off its resting point (flat, m).
func _off_rest(body: Transform3D, leg: int) -> float:
	var rest := _floor_point(body, NEUTRAL[leg])
	return Vector2(_planted[leg].x - rest.x, _planted[leg].z - rest.z).length()


## How far the body has run past [param leg]'s planted hoof: its distance
## behind its resting point (m, along the body).
func _behind(body: Transform3D, leg: int) -> float:
	var local := body.affine_inverse() * _planted[leg]
	return local.z - NEUTRAL[leg].z


func _unsettled(body: Transform3D) -> bool:
	for leg in LEGS:
		if _off_rest(body, leg) > SETTLE:
			return true
	return false


static func _floor_point(body: Transform3D, local: Vector3) -> Vector3:
	var flat := body.basis.orthonormalized()
	var point := body.origin + flat * Vector3(local.x, 0.0, local.z)
	point.y = body.origin.y + HOOF_HEIGHT
	return point


static func _yaw_of(body: Transform3D) -> float:
	var forward := -body.basis.z
	return atan2(-forward.x, -forward.z)
