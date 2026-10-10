class_name Spring
extends RefCounted
## A damped spring for secondary motion: a value chasing its target with
## weight - a head that follows the guard a moment late and overshoots a
## little, hips that sink on a footfall and come back up, a hand that
## bounces off the floor. [member frequency] (Hz) sets how quickly it
## follows, [member damping] how much it overshoots (1 = none, 0.3 = a
## lively wobble). Steps are cut into short substeps, so a long frame (a
## hitch) never makes it blow up.

## Longest substep (s).
const SUBSTEP := 1.0 / 240.0

var frequency: float = 2.0
var damping: float = 0.7
var value: float = 0.0
var velocity: float = 0.0


func _init(frequency_hz: float = 2.0, damping_ratio: float = 0.7, start: float = 0.0) -> void:
	frequency = frequency_hz
	damping = damping_ratio
	value = start


## Moves toward [param target] for [param delta] s; returns the new value.
func step(target: float, delta: float) -> float:
	if delta <= 0.0:
		return value
	var omega := TAU * frequency
	var steps := maxi(1, ceili(delta / SUBSTEP))
	var dt := delta / steps
	for i in steps:
		var acceleration := omega * omega * (target - value) - 2.0 * damping * omega * velocity
		velocity += acceleration * dt
		value += velocity * dt
	return value


## Jumps to [param to] at rest.
func reset(to: float = 0.0) -> void:
	value = to
	velocity = 0.0


## Adds [param impulse] to its speed (a jolt: a footfall, an impact).
func kick(impulse: float) -> void:
	velocity += impulse
