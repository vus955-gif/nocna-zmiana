class_name Stamina
extends RefCounted
## Stamina for sprint and dash (pure logic, ticked by the player).
## Regenerates after a short pause. Running dry while sprinting "exhausts"
## the guard: no sprinting until stamina is back to [member recover_at]
## (or full, if that is lower).

var maximum: float = 100.0
var current: float = 100.0
var sprint_cost_per_sec: float = 18.0
var dash_cost: float = 30.0
var regen_per_sec: float = 30.0
var regen_delay: float = 0.7
var recover_at: float = 30.0
var exhausted: bool = false
var _regen_wait: float = 0.0


func can_sprint() -> bool:
	return not exhausted and current > 0.0


## Spends sprint stamina for this frame. Returns false when sprinting must stop.
func spend_sprint(delta: float) -> bool:
	if not can_sprint():
		return false
	current = maxf(current - sprint_cost_per_sec * delta, 0.0)
	_regen_wait = regen_delay
	if current <= 0.0:
		exhausted = true
		return false
	return true


func try_dash() -> bool:
	if current < dash_cost:
		return false
	current -= dash_cost
	_regen_wait = regen_delay
	return true


## Call once per frame, after any spending.
func tick(delta: float) -> void:
	var regen_time := delta
	if _regen_wait > 0.0:
		regen_time = maxf(delta - _regen_wait, 0.0)
		_regen_wait = maxf(_regen_wait - delta, 0.0)
	current = minf(current + regen_per_sec * regen_time, maximum)
	if exhausted and current >= minf(recover_at, maximum):
		exhausted = false


func fraction() -> float:
	return current / maximum
