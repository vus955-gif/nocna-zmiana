class_name Health
extends Node
## Hit points. Emits [signal depleted] exactly once when reaching zero.

signal changed(current: float, maximum: float)
signal depleted

@export var max_health: float = 100.0
var current: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0.0


## Returns the damage actually taken (never more than what was left).
func apply_damage(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var taken := minf(amount, current)
	current -= taken
	changed.emit(current, max_health)
	if current <= 0.0:
		current = 0.0
		depleted.emit()
	return taken


## Returns the amount actually healed. The dead cannot be healed.
func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var healed := minf(amount, max_health - current)
	current += healed
	changed.emit(current, max_health)
	return healed


func fraction() -> float:
	return current / max_health if max_health > 0.0 else 0.0
