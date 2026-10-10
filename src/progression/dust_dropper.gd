class_name DustDropper
extends Node
## Turns every destroyed exhibit into Dust motes for the guard: the
## exhibit's dust_value, the finisher bonus (DustRules) and the night's
## multipliers (RunState), split into 1-4 motes. The boss (not an exhibit:
## it announces itself through Events.boss_defeated) bursts into a shower of
## BOSS_MOTES motes worth its own dust_value.

## Who collects the motes.
var target: Node3D = null
## Where the motes are added (default: this node's parent).
var motes_parent: Node = null


func _ready() -> void:
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.boss_defeated.connect(_on_boss_defeated)


## Spawns motes worth [param total] Dust at [param at] (at most
## [param max_motes] of them).
func drop(at: Vector3, total: int, max_motes: int = DustRules.MAX_MOTES) -> Array[DustMote]:
	var parent := motes_parent if is_instance_valid(motes_parent) else get_parent()
	return DustMote.burst(parent, at, DustRules.split(total, max_motes), target)


func _on_enemy_destroyed(enemy: Node, info: DamageInfo, finisher: bool) -> void:
	var exhibit := enemy as Enemy
	if exhibit == null or exhibit.dust_value <= 0 or not exhibit.is_inside_tree():
		return
	if Enemy.fell_out(info):
		return   # fell out of the level: nothing to collect down there
	var total := RunState.scaled_dust(DustRules.kill_value(exhibit.dust_value, finisher))
	drop(exhibit.global_position + Vector3.UP * (exhibit.eye_height * 0.6), total)


func _on_boss_defeated(boss: Node) -> void:
	var body := boss as Node3D
	if body == null or not body.is_inside_tree():
		return
	var value := int(boss.get(&"dust_value")) if &"dust_value" in boss else 0
	if value <= 0:
		return
	drop(body.global_position + Vector3.UP * 1.2, RunState.scaled_dust(value), DustRules.BOSS_MOTES)
