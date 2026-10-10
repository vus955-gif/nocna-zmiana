class_name GeneralFootwork
extends RefCounted
## The General's two feet as pure footing (the guardians' pattern): suri-ashi,
## the sliding step of the sword schools. Each foot stands planted in the
## world (it never skates under him); when the body has moved or turned far
## enough off a foot, that foot slides to its place under him - low over the
## gravel, in a short slide - and the other one draws up after it. Only one
## foot is ever off the floor: going forward the leading (right, chudan)
## foot goes first, going back the rear one; turning on the spot he steps
## round. Faster than CARRY_SPEED (a dash) the feet are carried along and
## stand where he lands. World space in, world space out: the body's origin
## is on the floor between the feet, -Z his front. Feet: 0 left, 1 right.

## A foot begins to slide; a foot came to rest (a scuff on the gravel).
signal slide(foot: int)
signal step(foot: int)

const FEET := 2
## The ankle pivot's height over the floor.
const FOOT_HEIGHT := 0.136
## Each foot's resting point (body space): the chudan stance, right foot
## leading.
const NEUTRAL: Array[Vector3] = [Vector3(-0.19, FOOT_HEIGHT, 0.2), Vector3(0.19, FOOT_HEIGHT, -0.24)]
## A foot this far (m) off its resting point slides; planted this far off
## the body's yaw (rad) it steps round.
const TRIGGER := 0.28
const TURN_TRIGGER := 0.45
## A slide's length (s): slow .. at speed.
const SLIDE_TIME := Vector2(0.26, 0.12)
## The speed at which slides are quickest.
const QUICK_AT := 3.5
## How high the foot comes off the floor in a slide (m): barely.
const LIFT := 0.035
## Faster than this he is lunging or flying: the feet are carried.
const CARRY_SPEED := 7.0
## The rear foot draws up this long after the leading one landed (s), when
## it is not yet overdue itself.
const FOLLOW_GAP := 0.04
## A landing foot lands where its rest will be this long after it lands (s).
const LAND_AHEAD := 0.1
## Below this the body counts as standing (m/s).
const MOVE_MIN := 0.2

## The body's flat speed last update (m/s).
var speed: float = 0.0
## A foot slides, or he moves.
var stepping := false
## Carried along in a dash or a leap.
var carried := false

var _placed := false
var _sliding: Array[bool] = [false, false]
var _planted: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _age: Array[float] = [0.0, 0.0]
var _time: Array[float] = [0.2, 0.2]
var _yaw: Array[float] = [0.0, 0.0]
var _wait: float = 0.0


## Plants both feet at their resting points under [param body] (a fresh
## start, a landing, a teleport).
func place(body: Transform3D) -> void:
	_placed = true
	var yaw := _yaw_of(body)
	speed = 0.0
	stepping = false
	carried = false
	_wait = 0.0
	for foot in FEET:
		_sliding[foot] = false
		_planted[foot] = _floor_point(body, NEUTRAL[foot])
		_foot[foot] = _planted[foot]
		_yaw[foot] = yaw
		_age[foot] = 0.0


## Advances by [param delta] with the body at [param body] moving at
## [param velocity] (world; the real way he went, also when he is flown by
## hand). [param airborne]: he is off the floor (a leap): the feet hang under
## him whatever his speed, since nothing is there to stand on.
func update(delta: float, body: Transform3D, velocity: Vector3, airborne: bool = false) -> void:
	if not _placed:
		place(body)
	if delta <= 0.0:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	speed = flat.length()
	var yaw := _yaw_of(body)
	if speed > CARRY_SPEED or airborne:
		# the lunge or the leap: the feet go with him, to stand where he lands
		carried = true
		stepping = true
		for foot in FEET:
			_sliding[foot] = false
			_planted[foot] = _floor_point(body, NEUTRAL[foot])
			_foot[foot] = _planted[foot]
			_yaw[foot] = yaw
		return
	carried = false
	var moving := speed > MOVE_MIN
	stepping = moving
	_wait = maxf(_wait - delta, 0.0)
	for foot in FEET:
		if not _sliding[foot]:
			continue
		stepping = true
		_age[foot] += delta
		var left := maxf(_time[foot] - _age[foot], 0.0)
		var to := _target(foot, body, flat, left)
		var w := clampf(_age[foot] / maxf(_time[foot], 0.001), 0.0, 1.0)
		var along := w * w * (3.0 - 2.0 * w)
		var point := _from[foot].lerp(to, along)
		point.y += LIFT * sin(PI * w)
		_foot[foot] = point
		if _age[foot] >= _time[foot]:
			_sliding[foot] = false
			_planted[foot] = to
			_foot[foot] = to
			_yaw[foot] = yaw
			_wait = FOLLOW_GAP
			step.emit(foot)
		return   # one foot at a time
	# nothing slides: does a foot need to?
	var due: Array[bool] = [false, false]
	var overdue: Array[bool] = [false, false]
	for foot in FEET:
		var off := _off_rest(body, foot)
		var turned := absf(wrapf(yaw - _yaw[foot], -PI, PI))
		due[foot] = off > TRIGGER or turned > TURN_TRIGGER
		overdue[foot] = off > TRIGGER * 1.8 or turned > TURN_TRIGGER * 1.6
	if not due[0] and not due[1]:
		return
	var pick := -1
	if moving:
		# the foot toward the move leads
		var lead := _leading(body, flat)
		var rear := 1 - lead
		if due[lead]:
			pick = lead
		elif _wait <= 0.0 or overdue[rear]:
			pick = rear
	else:
		var worst := -1.0
		for foot in FEET:
			if not due[foot]:
				continue
			var off := _off_rest(body, foot) + absf(wrapf(yaw - _yaw[foot], -PI, PI)) * 0.3
			if off > worst and (_wait <= 0.0 or overdue[foot]):
				worst = off
				pick = foot
	if pick >= 0:
		_slide(pick, body, flat)
		stepping = true


## The ankle of [param foot] now (world).
func foot(foot: int) -> Vector3:
	return _foot[foot]


## True while [param foot] stands.
func standing(foot: int) -> bool:
	return not _sliding[foot]


## 0 while [param foot] stands, 0..1 through its slide.
func swing(foot: int) -> float:
	if not _sliding[foot]:
		return 0.0
	return clampf(_age[foot] / maxf(_time[foot], 0.001), 0.0, 1.0)


# --- inside ----------------------------------------------------------------------

func _slide(foot: int, body: Transform3D, flat: Vector3) -> void:
	_sliding[foot] = true
	_from[foot] = _planted[foot]
	_age[foot] = 0.0
	_time[foot] = lerpf(SLIDE_TIME.x, SLIDE_TIME.y, clampf(speed / QUICK_AT, 0.0, 1.0))
	_foot[foot] = _planted[foot]
	slide.emit(foot)
	# a first sample, so the foot is off the floor the frame it lifts
	_foot[foot] = _from[foot].lerp(_target(foot, body, flat, _time[foot]), 0.0)


## The foot toward [param flat] (the move): the one whose resting point
## lies further along it.
func _leading(body: Transform3D, flat: Vector3) -> int:
	var direction := flat.normalized()
	var best := 1
	var best_along := -INF
	for foot in FEET:
		var rest := _floor_point(body, NEUTRAL[foot]) - body.origin
		var along := Vector3(rest.x, 0.0, rest.z).dot(direction)
		if along > best_along + 0.001:
			best_along = along
			best = foot
	return best


## Where [param foot] lands if it lands [param ahead] s from now: under its
## resting point, the body carried on by its velocity a little past that.
func _target(foot: int, body: Transform3D, flat: Vector3, ahead: float) -> Vector3:
	var t := ahead + LAND_AHEAD
	var later := Transform3D(body.basis.orthonormalized(), body.origin + flat * t)
	return _floor_point(later, NEUTRAL[foot])


## How far [param foot]'s planted ankle is off its resting point (flat, m).
func _off_rest(body: Transform3D, foot: int) -> float:
	var rest := _floor_point(body, NEUTRAL[foot])
	return Vector2(_planted[foot].x - rest.x, _planted[foot].z - rest.z).length()


static func _floor_point(body: Transform3D, local: Vector3) -> Vector3:
	var flat := body.basis.orthonormalized()
	var point := body.origin + flat * Vector3(local.x, 0.0, local.z)
	point.y = body.origin.y + FOOT_HEIGHT
	return point


static func _yaw_of(body: Transform3D) -> float:
	var forward := -body.basis.z
	return atan2(-forward.x, -forward.z)
