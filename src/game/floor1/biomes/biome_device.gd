class_name BiomeDevice
extends Node3D
## One piece of a wing's own mechanic (plan docs/superpowers/plans/
## 2026-10-21-mechaniki-biomow.md): a dart plate, a hunting net, a mirror,
## a bell... built and owned by BiomeMechanics. It knows its [member host]
## (the guard, the exhibits, the layout) and the [member room] it serves,
## and stops for good at dawn ([method freeze]).
## Its fields never use the names Floor1WorldSnapshot reads as the world's
## state (state, active, is_open, locked...): a cycle's phase is no part of
## the world a save keeps.

var host: BiomeMechanics = null
## The room it stands in (or serves, for a device on a wall).
var room: StringName = &""
## The device's own id (what RunState.used remembers of it).
var device_id: StringName = &""
## Dawn came: it moves no more.
var frozen: bool = false


## Dawn: it stops where it is (subclasses settle their looks).
func freeze() -> void:
	frozen = true
	set_physics_process(false)
	set_process(false)


## The guard while he is alive (null otherwise).
func guard() -> Player:
	var player := host.guard() if host != null else null
	return player if player != null and player.alive else null
