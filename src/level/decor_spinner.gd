class_name DecorSpinner
extends Node
## Slow motion of dressing that never stops (an astrolabe's rings, a steam
## engine's flywheel and governor, a clock's pendulum): each target turns
## about one of its own axes at its own speed, or swings to and fro about
## it. Pure decoration; RoomCuller disables its process when its room is
## far away (meta "kit_room").

## [node, local axis (Vector3), radians per second] per target.
var targets: Array = []
## [node, local axis, amplitude (rad), period (s), rest basis, phase] per
## swinging target.
var swings: Array = []
var _time: float = 0.0


## Adds [param node] turning about its local [param axis] at [param speed]
## rad/s (skipped when the node is missing).
func add(node: Node3D, axis: Vector3, speed: float) -> void:
	if node != null:
		targets.append([node, axis.normalized(), speed])


## Adds [param node] swinging about its local [param axis] by
## [param amplitude] radians either way, once to and fro every
## [param period] seconds, starting at [param phase] (0..1) of a swing.
func swing(node: Node3D, axis: Vector3, amplitude: float, period: float, phase: float = 0.0) -> void:
	if node != null:
		swings.append([node, axis.normalized(), amplitude, period, node.basis, phase])


func _process(delta: float) -> void:
	_time += delta
	for entry: Array in targets:
		if is_instance_valid(entry[0]):
			(entry[0] as Node3D).rotate_object_local(entry[1], float(entry[2]) * delta)
	for entry: Array in swings:
		if is_instance_valid(entry[0]):
			var angle := float(entry[2]) * sin(TAU * (_time / float(entry[3]) + float(entry[5])))
			(entry[0] as Node3D).basis = (entry[4] as Basis) * Basis(entry[1], angle)
