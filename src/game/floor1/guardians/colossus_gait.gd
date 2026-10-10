class_name ColossusGait
extends RefCounted
## The standing Colossus's walk as pure timing: one foot at a time lifts,
## swings forward for SWING_TIME (the stomp's warning: the foot hangs in
## the air, dust trailing) and comes down - a footfall, a shockwave ring
## and a tremor - then both feet stand for the rest of STEP_TIME before the
## other foot lifts. The body only moves while a foot swings (the planted
## one stays put), STEP_LENGTH per step along an ease-in-out, so it lurches
## like the giant it is. Feet: 0 = left, 1 = right.

signal lifted(foot: int)
signal planted(foot: int)

const STEP_TIME := 1.6
const SWING_TIME := 0.95
const STEP_LENGTH := 1.7
## How high a swinging foot rises (m).
const LIFT := 0.85

## The foot that moves next (or now).
var foot: int = 0

var _time: float = STEP_TIME
var _swinging := false
var _covered: float = 0.0


## Advances by [param delta]; [param walking] = it wants to go on. Returns
## how far the body moves this frame (m, forward).
func update(delta: float, walking: bool) -> float:
	if not _swinging and not walking:
		_time = STEP_TIME   # standing: the next step lifts at once
		return 0.0
	_time += delta
	if not _swinging and _time >= STEP_TIME:
		if not walking:
			return 0.0
		_time = 0.0
		_swinging = true
		_covered = 0.0
		lifted.emit(foot)
	if not _swinging:
		return 0.0
	var now := STEP_LENGTH * MotionClip.eased(MotionClip.IN_OUT, _time / SWING_TIME)
	var moved := now - _covered
	_covered = now
	if _time >= SWING_TIME:
		_swinging = false
		var landed := foot
		foot = 1 - foot
		planted.emit(landed)
	return moved


func swinging() -> bool:
	return _swinging


## 0..1 through the swing of [member foot] (0 when both feet stand).
func swing_progress() -> float:
	return clampf(_time / SWING_TIME, 0.0, 1.0) if _swinging else 0.0


## Both feet down, the next step lifts at once.
func reset() -> void:
	_time = STEP_TIME
	_swinging = false
	_covered = 0.0
	foot = 0
