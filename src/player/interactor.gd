class_name Interactor
extends RefCounted
## The guard's "use" probe: a ray of REACH metres from the middle of the
## screen. It focuses the first Interactable it meets; walls in between block
## it, other areas (triggers, havens) do not. The player updates it every
## physics frame and calls try_interact() on the interact key.

signal focus_changed(target: Interactable)

const REACH := 2.2
## Non-interactable areas the ray may pass before giving up.
const MAX_SKIPPED_AREAS := 4

var focus: Interactable = null
## The probe's ray, made once (it runs every physics frame).
var _query: PhysicsRayQueryParameters3D = null


## The usable Interactable straight ahead within REACH, or null.
func probe(space: PhysicsDirectSpaceState3D, from: Vector3, forward: Vector3, by: Node = null) -> Interactable:
	if _query == null:
		_query = PhysicsRayQueryParameters3D.new()
		_query.collision_mask = Layers.WORLD | Layers.INTERACT
		_query.collide_with_areas = true
		_query.collide_with_bodies = true
		_query.hit_from_inside = true
	_query.from = from
	_query.to = from + forward.normalized() * REACH
	var skipped: Array[RID] = []
	_query.exclude = skipped
	for attempt in MAX_SKIPPED_AREAS + 1:
		var hit := space.intersect_ray(_query)
		if hit.is_empty():
			return null
		var target := hit["collider"] as Interactable
		if target != null:
			return target if target.can_interact(by) else null
		if not hit["collider"] is Area3D:
			return null   # a wall
		skipped.append(hit["rid"])
		_query.exclude = skipped
	return null


func update(space: PhysicsDirectSpaceState3D, from: Vector3, forward: Vector3, by: Node) -> void:
	_set_focus(probe(space, from, forward, by))


func clear() -> void:
	_set_focus(null)


## Uses the focused Interactable. False when nothing usable is in focus.
func try_interact(by: Node) -> bool:
	if not is_instance_valid(focus) or not focus.can_interact(by):
		return false
	focus.interact(by)
	return true


func _set_focus(target: Interactable) -> void:
	if not is_instance_valid(focus):
		focus = null
	if target != focus:
		focus = target
		focus_changed.emit(target)
