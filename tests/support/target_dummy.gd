class_name TargetDummy
extends Node3D
## Stand-in target for tests: records every hit it receives, and every
## stagger (a Fu dog's roar: Player.stagger) by its length.

var hits: Array[DamageInfo] = []
var staggers: Array[float] = []


func take_damage(info: DamageInfo) -> void:
	hits.append(info)


func stagger(seconds: float) -> void:
	staggers.append(seconds)
