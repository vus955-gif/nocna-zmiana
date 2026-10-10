class_name Trauma
extends RefCounted
## Screen-shake "trauma" in 0..1. Shake strength is trauma squared, so small
## hits barely move the camera and big ones kick hard. Decays linearly.

var value: float = 0.0
var decay_per_sec: float = 1.6


func add(amount: float) -> void:
	value = clampf(value + amount, 0.0, 1.0)


func tick(delta: float) -> void:
	value = maxf(value - decay_per_sec * delta, 0.0)


func strength() -> float:
	return value * value
