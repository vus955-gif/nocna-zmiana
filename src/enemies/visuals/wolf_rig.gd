class_name WolfRig
extends ExhibitRig
## The stuffed wolf: a trot on stiff stick legs (diagonal pairs) that
## turns into a bounding gallop at full speed, a panting jaw and a wagging
## tail; the attack crouches it low (legs splayed, head down, jaw bared),
## the pounce stretches it out (fore legs reaching, hind legs trailing,
## nose following the arc) and the jaw snaps shut on the bite; it lands
## with a squash and skids on braced legs. Stunned it keels over on its
## side and twitches.

const CROUCH_DROP := 0.14
## Stunned: lying on its side.
const FALL_ROLL := 1.4
const FALL_DROP := 0.4
const LAND_TIME := 0.3

var _crouch := 0.0
var _front := 0.0
var _hind := 0.0
var _pitch := 0.0
var _head := 0.0
var _jaw := 0.0
var _tail_lift := 0.0
var _fall := 0.0
var _airborne := false
var _land := 0.0
var _bitten := false


static func build(owner_enemy: Enemy) -> WolfRig:
	var rig := WolfRig.new()
	rig.cycle_length = 1.5
	rig.full_speed = 4.2
	return ExhibitRig.attach(owner_enemy, rig, &"wolf") as WolfRig


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var on_floor := enemy.is_on_floor()
	var leaping := brain.has_struck() and not on_floor
	var dormant := state == EnemyBrain.State.DORMANT
	var stunned := state == EnemyBrain.State.STUNNED
	if leaping and not _airborne:
		_bitten = false
	if _airborne and on_floor:
		_land = LAND_TIME
	_airborne = not on_floor and brain.has_struck()
	_land = maxf(_land - delta, 0.0)
	if leaping and not _bitten and _near_target():
		_bitten = true
	# gait: trot (diagonal pairs) blending into a gallop (pairs together)
	var walk := minf(gait, 1.0) if on_floor else 0.0
	var gallop := clampf((gait - 1.0) * 2.0, 0.0, 1.0) if on_floor else 0.0
	var p := walk_phase
	var amp_front := 0.5 * walk + 0.2 * gallop
	var amp_hind := 0.45 * walk + 0.2 * gallop
	var fl := sin(p) * amp_front
	var fr := lerpf(sin(p + PI), sin(p + 0.35), gallop) * amp_front
	var bl := lerpf(sin(p + PI), sin(p + PI), gallop) * amp_hind
	var br := lerpf(sin(p), sin(p + PI + 0.35), gallop) * amp_hind
	# pose targets
	var crouch := 0.0
	var front := 0.0
	var hind := 0.0
	var pitch := sin(p) * 0.09 * gallop
	var head := -pitch * 0.8
	var jaw := -0.08 - 0.05 * sin(time * 11.0) if not dormant else 0.0
	var tail_lift := -0.35 * minf(gait, 1.3) if not dormant else 0.0
	var rate := 10.0
	if w > 0.0:
		crouch = w
		front = 0.62 * w
		hind = -0.62 * w
		pitch = -0.12 * w
		head = -0.28 * w
		jaw = -0.35 * w
		tail_lift = 0.35 * w
	elif leaping:
		front = 1.1
		hind = -1.0
		pitch = clampf(enemy.velocity.y * 0.07, -0.35, 0.3)
		head = -pitch * 0.5 + 0.1
		jaw = -0.12 if _bitten else -0.75
		tail_lift = -0.15
		rate = 18.0
	elif since_strike >= 0.0 and on_floor:
		front = 0.45
		hind = -0.15
		head = -0.2
		jaw = -0.2
		pitch = -0.06
	if _land > 0.0:
		var squash := _land / LAND_TIME
		crouch = maxf(crouch, squash * 0.8)
		front = maxf(front, 0.45 * squash)
	if dormant:
		front = 0.0
		hind = 0.0
	_crouch = ExhibitRig.ease_to(_crouch, crouch, 14.0, delta)
	_front = ExhibitRig.ease_to(_front, front, rate, delta)
	_hind = ExhibitRig.ease_to(_hind, hind, rate, delta)
	_pitch = ExhibitRig.ease_to(_pitch, pitch, 10.0, delta)
	_head = ExhibitRig.ease_to(_head, head, 10.0, delta)
	_jaw = ExhibitRig.ease_to(_jaw, jaw, 40.0 if _bitten else 14.0, delta)
	_tail_lift = ExhibitRig.ease_to(_tail_lift, tail_lift, 6.0, delta)
	_fall = ExhibitRig.ease_to(_fall, 1.0 if stunned else 0.0, 7.0 if stunned else 4.0, delta)
	var twitch := sin(time * 23.0) * 0.18 * _fall
	var bob := -absf(cos(p)) * 0.03 * walk + absf(sin(p)) * 0.05 * gallop
	pose_part("body", Vector3(_pitch, 0.0, FALL_ROLL * _fall), Vector3(0.0, bob - CROUCH_DROP * _crouch - FALL_DROP * _fall, 0.0))
	pose_part("leg_fl", Vector3(fl + _front + twitch, 0.0, 0.0))
	pose_part("leg_fr", Vector3(fr + _front - twitch, 0.0, 0.0))
	pose_part("leg_bl", Vector3(bl + _hind - twitch * 0.7, 0.0, 0.0))
	pose_part("leg_br", Vector3(br + _hind + twitch * 0.7, 0.0, 0.0))
	pose_part("head", Vector3(_head - 0.25 * _fall, sin(time * 1.3) * 0.08 * (1.0 - walk) if not dormant else 0.0, 0.0))
	pose_part("jaw", Vector3(_jaw - 0.3 * _fall, 0.0, 0.0))
	var wag := sin(time * (9.0 if gait < 0.5 else 14.0)) * (0.35 - 0.2 * minf(gait, 1.0)) if not dormant and not stunned else 0.0
	pose_part("tail", Vector3(_tail_lift + 0.4 * _fall, wag, 0.0))


func _near_target() -> bool:
	var goal := enemy.target
	return is_instance_valid(goal) and enemy.global_position.distance_to(goal.global_position) <= enemy.attack_reach + 0.4
