class_name FirstLook
extends RefCounted
## The guard looks a weapon over the first time he finds it (owner's note
## 44, plan 2026-10-21-animacje-fpp): a weapon taken from its pickup is
## queued, and WeaponHolder starts the look (ViewmodelRig.look_over()) at
## the next calm moment with it up in his hands - never in a fight: not
## while an exhibit hunts him within CALM_RADIUS m or a guardian fights,
## nor within QUIET_AFTER s of a shot or a blow. The calm is checked every
## CHECK_EVERY s, and only while there is something to look at.

const CALM_RADIUS := 16.0
const QUIET_AFTER := 1.0
const CHECK_EVERY := 0.25

var _queued: Array[StringName] = []
var _check_left: float = 0.0
var _calm: bool = true


## Weapon [param id] was just found: it is looked over at the next calm
## moment it is in hand.
func queue(id: StringName) -> void:
	if not _queued.has(id):
		_queued.append(id)


func queued(id: StringName) -> bool:
	return _queued.has(id)


## Any weapon still waiting to be looked over.
func waiting() -> bool:
	return not _queued.is_empty()


## Weapon [param id] is being looked over now (or never will be).
func take(id: StringName) -> void:
	_queued.erase(id)


## True when it is calm round [param at] (no hunter near, no guardian
## fighting); looked up again every CHECK_EVERY s of [param delta].
func calm(tree: SceneTree, at: Vector3, delta: float) -> bool:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_EVERY
		_calm = tree == null or not hunters_near(tree, at, CALM_RADIUS)
	return _calm


## Look again at once (the next calm() asks the world).
func recheck() -> void:
	_check_left = 0.0


## True when an exhibit within [param radius] m of [param at] hunts the
## guard (or attacks him), or a guardian is in its fight.
static func hunters_near(tree: SceneTree, at: Vector3, radius: float) -> bool:
	for node in tree.get_nodes_in_group(&"enemies"):
		var body := node as Node3D
		var brain: Variant = node.get("brain")
		if body == null or not body.is_inside_tree() or not brain is EnemyBrain:
			continue
		if (brain as EnemyBrain).is_hunting() and body.global_position.distance_to(at) <= radius:
			return true
	for node in tree.get_nodes_in_group(&"guardians"):
		if node.get("state") == Guardian.State.FIGHT:
			return true
	return false
