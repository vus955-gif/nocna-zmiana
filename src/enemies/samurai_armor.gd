class_name SamuraiArmor
extends Knight
## The empty samurai armour of the Asia wing (design pietro-1-projekt 5.5,
## kit docs/art/kit-pietro1-azja.md 8): an ashigaru's okegawa-do on the
## knight's rules - 180 HP, Dust 8, METAL, a slow turn, the great sode on
## its left arm as the shield (ShieldGuard: hits from the front arc are
## stopped, not electric ones, not steep ones, not while stunned), plates
## that fly off hard hits (KnightRig.shed_plate) - and its own attack:
## - the yari thrust from THRUST_RANGE: a THRUST_WINDUP telegraph (the
##   spear draws back to the hip level, the front foot slides, the torso
##   winds; at GLINT_AT of it the tip glints with a quiet samurai_glint),
##   then a lunge (shove) and the thrust: THRUST_DAMAGE on a guard within
##   THRUST_REACH in a THRUST_HALF_ARC cone with a clear line; the spear
##   comes back slowly (the opening).
## Its eyes are embers in the dark of the helmet (a flickering light at the
## "face" marker: out asleep, flaring in the telegraph). Asleep it stands
## as the armour stand with the yari upright; alerted it takes kamae: the
## sode up before the chest, the yari level at the guard; stunned the sode
## drops, the tip goes to the floor. The model "samurai_ashigaru" (the
## knight's part names) moves through a SamuraiRig; without it the knight's
## greybox.

const KIND := &"samurai_armor"
const THRUST_RANGE := 2.6
const THRUST_REACH := 3.2
const THRUST_HALF_ARC := 25.0
const THRUST_WINDUP := 0.8
const THRUST_RECOVERY := 1.0
const THRUST_DAMAGE := 20.0
const THRUST_KNOCKBACK := 6.0
## The lunge (m/s, dying down on the floor: about half a metre).
const LUNGE := 5.5
## The tip glints this far into the telegraph (share).
const GLINT_AT := 0.55
const GLINT_DB := -8.0
## A guard higher than this over its feet is out of the thrust (m).
const THRUST_HEIGHT := 1.0
## Where the hit is reported (over the guard's feet).
const HIT_HEIGHT := 1.2

var _glinted := false


func _configure() -> void:
	super()
	attack_damage = THRUST_DAMAGE
	attack_reach = THRUST_REACH
	dust_value = 8
	windup_lean = 0.05
	strike_lean = -0.1
	brain.attack_range = THRUST_RANGE
	brain.windup = THRUST_WINDUP
	brain.recovery = THRUST_RECOVERY


func _build_body() -> void:
	add_collider(0.42, 2.0)
	rig = SamuraiRig.build_samurai(self)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(Vector3(0.62, 1.45, 0.45)), Vector3(0, 0.85, 0))
	var head_zone := add_hurtbox(sphere_shape(0.2), Vector3(0, 1.78, -0.05), true)
	if rig != null:
		rig.track(body_zone, &"torso", true)
		rig.track(head_zone, &"face")


## True when a yari thrust by armour facing [param forward] finds a guard
## [param to_target] away: within [param reach] on the floor plan, inside
## the cone, not a storey up.
static func thrust_hits(forward: Vector3, to_target: Vector3, reach: float, half_arc_deg: float) -> bool:
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance > reach or distance < 0.001 or absf(to_target.y) > THRUST_HEIGHT:
		return false
	var look := Vector3(forward.x, 0.0, forward.z)
	if look.length_squared() < 0.0001:
		return false
	return look.normalized().dot(flat / distance) >= cos(deg_to_rad(half_arc_deg))


## A spear fighter keeps its place on the ring at spear reach.
func _uses_attack_ring() -> bool:
	return brain.attack_range > 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	if brain.state == EnemyBrain.State.ATTACK and not brain.has_struck() and not _glinted and brain.windup_progress() >= GLINT_AT:
		_glinted = true
		var tip := spear_tip()
		Fx.flash(tip, Color(0.85, 0.92, 1.0), 1.6, 1.6, 0.22)
		Sfx.play_at(&"samurai_glint", tip, GLINT_DB)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.ATTACK:
		_glinted = false


## The thrust: a lunge, and the yari finds him in reach within its cone.
func _on_strike() -> void:
	if not _target_alive():
		return
	var forward := -global_basis.z
	Sfx.play_at(&"hoplite_thrust", global_position + Vector3.UP * 1.4, -1.0)
	shove(forward * LUNGE)
	if Haven.shelters(target.global_position):
		return
	var to := target.global_position - global_position
	if thrust_hits(forward, to, attack_reach, THRUST_HALF_ARC) and _has_line_of_sight():
		var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
		var flat := Vector3(to.x, 0.0, to.z)
		info.direction = flat.normalized() if flat.length() > 0.01 else forward
		info.knockback = THRUST_KNOCKBACK
		info.position = target.global_position + Vector3.UP * HIT_HEIGHT
		target.take_damage(info)


## Where the yari's tip is now (world).
func spear_tip() -> Vector3:
	if rig != null and rig.part("spear_tip") != null:
		return global_transform * rig.part_transform("spear_tip").origin
	return global_position - global_basis.z * 2.1 + Vector3.UP * 1.4
