class_name WaxRig
extends ExhibitRig
## The wax figure (a Napoleonic officer): a stiff, doll-like shuffle with a
## rocking torso and wooden arm swing, a head that twitches now and then,
## a windup that cocks the right arm high behind the head (the base leans
## the whole figure back) and a chopping strike. Stunned it trembles with
## its head hung. The model's seven parts come flat; head and arms are
## nested under the torso here so they turn with it.

## Arm angles (rad) at the top of the windup and the end of the chop.
const RAISED := 2.7
const CHOP := -0.45
## Seconds the chop takes.
const CHOP_TIME := 0.12

var _arm := 0.0
var _arm_out := 0.0
var _reach := 0.0
var _twist := 0.0
var _nod := 0.0
var _twitch := 0.0
var _twitch_timer := 2.0
var _twitch_goal := 0.0


static func build(owner_enemy: Enemy) -> WaxRig:
	var rig := WaxRig.new()
	rig.cycle_length = 1.3
	rig.full_speed = 2.4
	return ExhibitRig.attach(owner_enemy, rig, &"wax_figure") as WaxRig


func _arrange() -> void:
	var p := ArtLibrary.parts(model)
	var torso: Node3D = p["torso"]
	ExhibitRig.nest(p["head"], torso)
	ExhibitRig.nest(p["hat"], p["head"])
	ExhibitRig.nest(p["arm_l"], torso)
	ExhibitRig.nest(p["arm_r"], torso)


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var stunned := state == EnemyBrain.State.STUNNED
	var dormant := state == EnemyBrain.State.DORMANT
	var walk := minf(gait, 1.2)
	var s := sin(walk_phase)
	var leg := s * 0.3 * walk
	pose_part("leg_l", Vector3(leg, 0.0, 0.0))
	pose_part("leg_r", Vector3(-leg, 0.0, 0.0))
	# arm and torso targets
	var arm := -leg * 0.7
	var arm_out := 0.0
	var reach := leg * 0.7
	var twist := s * 0.09 * walk
	var nod := 0.0
	var rate := 12.0
	if w > 0.0:
		var up := w * w * (3.0 - 2.0 * w)
		arm = RAISED * up
		arm_out = 0.3 * up
		reach = 0.7 * up
		twist = -0.32 * up
		nod = 0.18 * up
	elif since_strike >= 0.0:
		if since_strike < CHOP_TIME * 2.5:
			arm = CHOP
			arm_out = 0.05
			reach = 0.3
			twist = 0.35
			nod = -0.12
			rate = 45.0
		else:
			rate = 5.0   # a slow, heavy return to the stance
	if stunned:
		arm = 0.15
		arm_out = 0.12
		reach = 0.1
		twist = sin(time * 3.1) * 0.05
		nod = -0.4
	if dormant:
		arm = 0.0
		arm_out = 0.0
		reach = 0.0
		twist = 0.0
	_arm = ExhibitRig.ease_to(_arm, arm, rate, delta)
	_arm_out = ExhibitRig.ease_to(_arm_out, arm_out, rate, delta)
	_reach = ExhibitRig.ease_to(_reach, reach, 10.0, delta)
	_twist = ExhibitRig.ease_to(_twist, twist, rate * 0.8, delta)
	_nod = ExhibitRig.ease_to(_nod, nod, 8.0, delta)
	_update_twitch(delta, dormant or stunned)
	var tremble := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (0.035 if stunned else 0.0)
	var bob := absf(cos(walk_phase)) * 0.02 * walk
	var roll := s * 0.05 * walk
	pose_part("torso", Vector3(0.0, _twist, roll) + tremble, Vector3(0.0, bob, 0.0))
	pose_part("arm_r", Vector3(_arm, 0.0, _arm_out))
	pose_part("arm_l", Vector3(_reach, 0.0, -0.05 * walk))
	pose_part("head", Vector3(_nod, _twitch * 0.4, _twitch) + tremble * 2.0)


## Now and then the awake figure's head snaps to a tilt and back, like a
## doll's.
func _update_twitch(delta: float, still: bool) -> void:
	if still:
		_twitch = ExhibitRig.ease_to(_twitch, 0.0, 6.0, delta)
		return
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(1.5, 4.0)
		_twitch_goal = 0.0 if _twitch_goal != 0.0 else randf_range(-0.28, 0.28)
	_twitch = ExhibitRig.ease_to(_twitch, _twitch_goal, 30.0, delta)
