class_name BustRig
extends ExhibitRig
## The floating bust: the gallery bust torn off its plinth (scaled so its
## head fills the greybox hit zones) with a fragment of the plinth
## drifting under it on its own slow bob and spin. It sways as it hovers;
## in the windup it tips its face up and trembles while its cracks glow
## from inside (the emission map, per instance), then jerks forward as it
## spits the shard. The enemy's own lean and stun tilt carry it.

## The bust model is life-size; this scale puts its head on the 0.78 m
## hit zones of src/enemies/bust.gd (chest to crown 0.37-0.93 m).
const SCALE := 1.25
const LIFT := 0.37
const SPIT_TIME := 0.18

var _tip := 0.0


static func build(owner_enemy: Enemy) -> BustRig:
	var offset := Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(0.0, LIFT, 0.0))
	var rig := BustRig.new()
	rig.gib_density = 12.0
	return ExhibitRig.attach(owner_enemy, rig, &"bust_enemy", offset) as BustRig


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var hovering := state != EnemyBrain.State.DORMANT and state != EnemyBrain.State.STUNNED
	var tip := 0.0
	if w > 0.0:
		tip = 0.2 * w
	elif since_strike >= 0.0 and since_strike < SPIT_TIME:
		tip = -0.22
	_tip = ExhibitRig.ease_to(_tip, tip, 30.0 if tip < 0.0 else 9.0, delta)
	var tremble := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.025 * w * w
	var sway := Vector3(sin(time * 0.9) * 0.04, sin(time * 0.6) * 0.1, sin(time * 0.75 + 1.0) * 0.03) if hovering else Vector3.ZERO
	pose_part("bust", Vector3(_tip, 0.0, 0.0) + sway + tremble)
	# the plinth fragment: a lagging bob and a slow turn under the bust
	if hovering:
		pose_part("plinth", Vector3(sin(time * 0.8) * 0.12, time * 0.5, 0.0), Vector3(0.0, sin(time * 1.7 - 0.9) * 0.025 - 0.02, 0.0))
	else:
		pose_part("plinth", Vector3.ZERO)
