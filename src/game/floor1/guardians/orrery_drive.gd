class_name OrreryDrive
extends RefCounted
## The drive of one of the Great Orrery's tiers: a heavy brass wheel that
## turns at [member speed] (rad/s, positive = rotation.y growing) toward
## [member target], never changing faster than [member rate] rad/s² - it
## spins up with weight, and to turn round it first comes to a stop. The
## angle is the integral of the speed; [member acceleration] is the last
## step's change (the moves read it: gear backlash, the moons' swing).

var angle: float = 0.0
var speed: float = 0.0
var target: float = 0.0
## Fastest change of speed (rad/s²).
var rate: float = 1.0
## The last step's change of speed (rad/s²).
var acceleration: float = 0.0


func _init(rate_: float = 1.0) -> void:
	rate = rate_


## Turns the wheel for [param delta] s.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var before := speed
	speed = move_toward(speed, target, rate * delta)
	acceleration = (speed - before) / delta
	angle = wrapf(angle + (before + speed) * 0.5 * delta, -PI, PI)


## True while it turns at its target speed.
func steady() -> bool:
	return is_equal_approx(speed, target)


## At rest at [param to] (rad).
func reset(to: float = 0.0) -> void:
	angle = to
	speed = 0.0
	target = 0.0
	acceleration = 0.0
