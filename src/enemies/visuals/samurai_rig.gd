class_name SamuraiRig
extends KnightRig
## The samurai armour (model "samurai_ashigaru", docs/art/kit-pietro1-azja.md
## 8): the knight's part names - torso root, head, arm_l with the great
## sode as "shield", arm_r with the yari as "weapon" (the shaft level
## forward at rest, the tip 2.1 m ahead: the rest pose IS kamae), leg_l /
## leg_r roots, five plates (no plate_pauldron_l: the sode) - and the
## "face" and "spear_tip" markers. Posed in code:
## - asleep and calm (patrolling, going home): the armour stand - the yari
##   upright (STAND_YARI about the hand), the sode down at the side, the
##   arms easy;
## - alerted (suspicious, investigating, hunting): kamae - the yari comes
##   down level at the guard, the sode rises before the chest, the stance
##   widens and sinks a little, the embers in the helmet smoulder;
## - the walk: the knight's heavy, dipping step, the yari steady;
## - the telegraph: the spear arm draws back with the shaft kept level (the
##   weapon counter-turned about the hand and slid back), the torso winds
##   away, the front foot slides forward, the embers flare; the tip glints
##   (SamuraiArmor) past the middle;
## - the thrust: the arm drives through, the shaft slides forward, the
##   torso twists into it, held a moment, then it comes back slowly (the
##   opening);
## - stunned: the sode drops and swings out, the tip dips to the floor, the
##   head hangs.
## Hard hits knock its plates off (KnightRig.shed_plate).

## The yari upright about the hand (rad) and lifted a little in the stand.
const STAND_YARI := 1.45
const STAND_LIFT := 0.1
## The sode: down at the side asleep (rad), up before the chest in kamae.
const SODE_DOWN := -0.5
const SODE_UP := 0.4
const SODE_IN := -0.25
## The telegraph: the spear arm back, the shaft slid back (m), the wind of
## the torso (rad), the front foot's slide (m).
const DRAW_ARM := -0.55
const DRAW_SLIDE := 0.3
const DRAW_TWIST := 0.35
const DRAW_STEP := 0.12
## The thrust: the arm through, the shaft slid forward, the twist into it.
const DRIVE_ARM := 0.3
const DRIVE_SLIDE := -0.55
const DRIVE_TWIST := -0.3
const THRUST_TIME := 0.12
const HOLD_TIME := 0.15
## The embers: colour and reach of the light in the helmet.
const EMBER_COLOR := Color(1.0, 0.45, 0.15)
const EMBER_RANGE := 1.6

var samurai: SamuraiArmor

var _stand := 1.0
var _kamae := 0.0
var _draw := 0.0
var _drive := 0.0
var _sode := 0.0
var _wind := 0.0
var _step := 0.0
var _stun := 0.0
var _nod := 0.0
var _ember := 0.0
var _ember_light: OmniLight3D


static func build_samurai(owner: SamuraiArmor) -> SamuraiRig:
	var rig := SamuraiRig.new()
	rig.samurai = owner
	rig.cycle_length = 1.9
	rig.full_speed = 2.0
	rig.gib_density = 3.0
	return ExhibitRig.attach(owner, rig, &"samurai_ashigaru") as SamuraiRig


## How upright the yari is held (rad about the hand; 0 = level, kamae).
func yari_angle() -> float:
	var weapon := part("weapon")
	if weapon == null:
		return 0.0
	return ((rest["weapon"] as Transform3D).basis.inverse() * weapon.basis).get_euler().x


## How far the sode is raised (arm_l's pitch off its rest, rad).
func sode_angle() -> float:
	var arm := part("arm_l")
	if arm == null:
		return 0.0
	return ((rest["arm_l"] as Transform3D).basis.inverse() * arm.basis).get_euler().x


## The embers' brightness now.
func ember_energy() -> float:
	return _ember


func _setup() -> void:
	var face := part("face")
	_ember_light = OmniLight3D.new()
	_ember_light.name = "Embers"
	_ember_light.light_color = EMBER_COLOR
	_ember_light.omni_range = EMBER_RANGE
	_ember_light.light_energy = 0.0
	_ember_light.shadow_enabled = false
	_ember_light.visible = false
	if face != null:
		face.add_child(_ember_light)
		_ember_light.position = Vector3(0.0, 0.0, -0.06)
	else:
		var head := part("head")
		if head != null:
			head.add_child(_ember_light)
			_ember_light.position = Vector3(0.0, 0.16, -0.14)


func _pose(delta: float) -> void:
	var brain := enemy.brain
	var state := brain.state
	var w := brain.windup_progress()
	var up := w * w * (3.0 - 2.0 * w)
	var stunned := state == EnemyBrain.State.STUNNED
	var dormant := state == EnemyBrain.State.DORMANT
	var alerted := brain.is_alerted()
	var walk := minf(gait, 1.2)
	var s := sin(walk_phase)
	var leg := s * 0.36 * walk
	var draw := 0.0
	var drive := 0.0
	var wind := s * 0.06 * walk
	var step := 0.0
	var head := 0.0
	var rate := 10.0
	if w > 0.0:
		draw = up
		wind = DRAW_TWIST * up
		step = up
		head = 0.05 * up
		rate = 14.0
	elif since_strike >= 0.0:
		if since_strike < THRUST_TIME + HOLD_TIME:
			drive = 1.0
			wind = DRIVE_TWIST
			step = 1.0
			head = -0.05
			rate = 45.0
		else:
			step = 0.4
			rate = 3.0   # the yari comes back slowly: the opening
	if stunned:
		draw = 0.0
		drive = 0.0
		wind = sin(time * 2.3) * 0.05
		head = -0.4
	_stand = ExhibitRig.ease_to(_stand, 1.0 if not alerted and not stunned else 0.0, 3.5 if not alerted else 5.0, delta)
	_kamae = ExhibitRig.ease_to(_kamae, 1.0 if alerted and not stunned else 0.0, 5.0, delta)
	_draw = ExhibitRig.ease_to(_draw, draw, rate, delta)
	_drive = ExhibitRig.ease_to(_drive, drive, rate, delta)
	_wind = ExhibitRig.ease_to(_wind, wind, rate * 0.7, delta)
	_step = ExhibitRig.ease_to(_step, step, rate, delta)
	_stun = ExhibitRig.ease_to(_stun, 1.0 if stunned else 0.0, 9.0 if stunned else 4.0, delta)
	_nod = ExhibitRig.ease_to(_nod, head, 6.0, delta)
	var sode := SODE_DOWN * _stand + SODE_UP * _kamae - 1.0 * _stun
	_sode = ExhibitRig.ease_to(_sode, sode, 6.0, delta)
	# legs: the knight's dipping step; in kamae a wider, lower stance, the
	# front (left) foot sliding forward in the telegraph
	var stance := 0.1 * _kamae
	pose_part("leg_l", Vector3(leg + stance + 0.25 * _step, 0.0, 0.0), Vector3(0.0, 0.0, -DRAW_STEP * _step))
	pose_part("leg_r", Vector3(-leg - stance * 0.6, 0.0, 0.0))
	var bob := -absf(s) * 0.035 * walk
	var sink := 0.04 * _kamae + 0.06 * _stun + 0.03 * _step
	pose_part("torso", Vector3(-0.04 * walk - 0.12 * _stun + 0.02 * _step, _wind, s * 0.03 * walk), Vector3(0.0, bob - sink, 0.0))
	# the spear arm: at ease in the stand, back in the telegraph, through in
	# the thrust (turned against the torso's wind: the shaft keeps its line)
	var arm_r := DRAW_ARM * _draw + DRIVE_ARM * _drive - 0.15 * _stand - 0.3 * _stun
	pose_part("arm_r", Vector3(arm_r, -_wind * 0.8, 0.05 * _stun))
	# the yari: upright in the stand (about the hand), level in kamae; in
	# the telegraph and thrust it slides along its shaft and counter-turns
	# so it stays level as the arm swings
	var yari_pitch := STAND_YARI * _stand - (DRAW_ARM * _draw + DRIVE_ARM * _drive) * (1.0 - _stand) - 0.6 * _stun
	var slide := (DRAW_SLIDE * _draw + DRIVE_SLIDE * _drive) * (1.0 - _stand)
	pose_part("weapon", Vector3(yari_pitch, 0.0, 0.0), Vector3(0.0, STAND_LIFT * _stand, slide))
	# the sode arm: down at the side asleep, up before the chest in kamae,
	# dropped and swung out when stunned
	pose_part("arm_l", Vector3(_sode, 0.15 * _kamae, SODE_IN * _kamae - 0.3 * _stun), Vector3(0.0, -0.02 * absf(s) * walk, 0.0))
	pose_part("shield", Vector3(0.0, -0.2 * _kamae, 0.35 * _stun))
	pose_part("head", Vector3(_nod, -_wind * 0.5, 0.0))
	_pose_embers(delta, dormant, stunned, w)


## The embers in the helmet: out asleep, smouldering and flickering awake,
## flaring in the telegraph, dim stunned.
func _pose_embers(delta: float, dormant: bool, stunned: bool, w: float) -> void:
	var goal := 0.0
	if not dormant:
		goal = 0.36 + 0.08 * sin(time * 13.0) + 0.05 * sin(time * 29.0)
	if enemy.brain.state == EnemyBrain.State.SUSPICIOUS:
		goal = 1.1
	elif w > 0.0:
		goal = 0.5 + 1.6 * w * w
	elif stunned:
		goal = 0.08
	_ember = ExhibitRig.ease_to(_ember, goal, 12.0, delta)
	if _ember_light != null:
		_ember_light.light_energy = _ember
		_ember_light.visible = _ember > 0.02
