class_name Jaguar
extends Enemy
## The jaguar warrior of the Americas wing (design pietro-1-projekt 5.6,
## kit docs/art/kit-pietro1-ameryki.md 9): a carved and painted wooden
## figure in a jaguar pelt with an obsidian-toothed club. 70 HP, Dust 5,
## WOOD (cedar chips). It walks upright (WALK) and, hunting, drops onto
## all fours and sprints low (SPRINT: its hit zones ride down with the
## model). Two attacks (JaguarMoves decides by distance):
## - the pounce from 3-7 m: a 0.6 s crouch (a snarl, the club drawn back),
##   then a leap heavier than the wolf's that lands STOP_SHORT before where
##   the guard stood (the aim is taken at the leap: a step aside dodges
##   it), the club overhead in the air; it lands on bent knees (SETTLE),
##   brings the club down (SWING: CLUB_DAMAGE in a cone in front at the end
##   of the swing) and leaves it stuck in the floor (STUCK: the opening);
## - the club up close (under 3 m): the same 0.6 s raise overhead, then
##   the swing and the stuck club.
## Its weak point is the warrior's face in the helmet's maw (the model's
## "face" marker). Asleep it is a statue; noticing something its head
## turns first with a creak of wood and its eyes light; awake and idle it
## breathes, shifts its weight and watches; it goes back to its post and
## freezes into a statue again. The model "jaguar" moves through a
## JaguarRig; without it a greybox.

const KIND := &"jaguar"
const WALK := 3.0
const SPRINT := 6.2
## Horizontal speed from which the hunt is a sprint on all fours (m/s).
const SPRINT_FROM := 4.0
## Where the club's blow is reported (over the guard's feet).
const HIT_HEIGHT := 1.0
## The landing's thud shakes the camera this close (m).
const THUD_REACH := 6.0
## Hit zones on the model: the chest, the hips, the helmet, the face.
const TORSO_ZONE := Vector3(0.46, 0.6, 0.38)
const TORSO_AT := Vector3(0.0, 1.32, 0.0)
const PELVIS_ZONE := Vector3(0.4, 0.3, 0.32)
const PELVIS_AT := Vector3(0.0, 0.92, 0.0)
const HEAD_RADIUS := 0.16
const HEAD_AT := Vector3(0.0, 1.68, 0.0)
const FACE_RADIUS := 0.09
const FACE_AT := Vector3(0.0, 1.6, -0.142)
## A hit of this much knocks a splinter of cedar off.
const SPLINTER_DAMAGE := 20.0
const CREAK_DB := -8.0

## The attack under way (or the one it would start now).
var move: JaguarMoves.Move = JaguarMoves.Move.CLUB
## The hit zone of the helmet (its height tells the sprint from the walk).
var head_zone: Hurtbox = null

var _planned: JaguarMoves.Move = JaguarMoves.Move.CLUB
var _leaping := false
var _airborne := false
## Seconds since it landed (or began a close blow); -1 before.
var _combo_time: float = -1.0
var _swung := false


func _configure() -> void:
	max_health = 70.0
	move_speed = WALK
	turn_speed = 10.0
	attack_damage = JaguarMoves.CLUB_DAMAGE
	attack_reach = JaguarMoves.SWING_REACH
	knockback_resist = 0.25
	eye_height = 1.6
	marker_height = 2.15
	material_kind = ExhibitMaterial.Kind.WOOD
	dust_value = 5
	notice_sound = &"jaguar_snarl"
	leash = PerceptionRules.HUNTER_LEASH
	windup_lean = 0.0
	strike_lean = 0.0
	brain.reaction_time = 0.6
	brain.attack_range = JaguarMoves.CLUB_RANGE
	brain.windup = JaguarMoves.WINDUP
	brain.recovery = JaguarMoves.club_recovery()


func _build_body() -> void:
	add_collider(0.36, 1.8)
	rig = JaguarRig.build(self)
	if rig == null:
		_build_greybox()
	var torso_zone := add_hurtbox(box_shape(TORSO_ZONE), TORSO_AT)
	var pelvis_zone := add_hurtbox(box_shape(PELVIS_ZONE), PELVIS_AT)
	head_zone = add_hurtbox(sphere_shape(HEAD_RADIUS), HEAD_AT)
	var face_zone := add_hurtbox(sphere_shape(FACE_RADIUS), FACE_AT, true)
	if rig != null:
		# the zones ride on the model: low in the sprint, crouched, in the air
		rig.track(torso_zone, &"torso", true)
		rig.track(pelvis_zone, &"pelvis", true)
		rig.track(head_zone, &"head")
		rig.track(face_zone, &"head")


func _build_greybox() -> void:
	var pelt := body_material(Color(0.78, 0.6, 0.28))
	var dark := body_material(Color(0.2, 0.16, 0.12))
	var turquoise := body_material(Color(0.2, 0.62, 0.6))
	add_part(box_mesh(Vector3(0.44, 0.56, 0.3)), Vector3(0, 1.32, 0), pelt)
	add_part(box_mesh(Vector3(0.36, 0.28, 0.28)), Vector3(0, 0.92, 0), dark)
	for x in [-0.11, 0.11]:
		add_part(box_mesh(Vector3(0.16, 0.8, 0.18)), Vector3(x, 0.4, 0), pelt)
	add_part(box_mesh(Vector3(0.3, 0.32, 0.34)), Vector3(0, 1.68, -0.02), pelt)
	add_part(box_mesh(Vector3(0.14, 0.12, 0.04)), FACE_AT, dark)
	add_part(box_mesh(Vector3(0.3, 0.06, 0.06)), Vector3(0, 1.3, -0.17), turquoise)
	add_part(box_mesh(Vector3(0.08, 0.9, 0.05)), Vector3(0.33, 0.6, -0.05), dark)
	add_part(box_mesh(Vector3(0.5, 0.5, 0.04)), Vector3(-0.36, 1.0, -0.1), turquoise)


# --- what the rig and the tests read -----------------------------------------------

## Hunting on all fours at speed.
func sprinting() -> bool:
	return brain.state == EnemyBrain.State.HUNT and is_on_floor() \
			and Vector2(velocity.x, velocity.z).length() > SPRINT_FROM


## In the air of a pounce.
func leaping() -> bool:
	return _leaping and _airborne


## The phase of the club combination after a pounce's landing (or a close
## blow); NONE outside an attack's strike.
func phase() -> JaguarMoves.Phase:
	if brain.state != EnemyBrain.State.ATTACK or not brain.has_struck():
		return JaguarMoves.Phase.NONE
	if _leaping:
		return JaguarMoves.Phase.AIR
	return JaguarMoves.phase_after_landing(_combo_time)


## Seconds since it landed (or began the close blow); -1 before.
func combo_time() -> float:
	return _combo_time


# --- the step -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	# upright walk everywhere but the hunt: there it drops onto all fours.
	# move_speed stays its WALK (what the night's tuning and the witching hour
	# scale); for the step of a hunt it is that times the sprint's share
	var walk := move_speed
	if brain.state == EnemyBrain.State.HUNT:
		move_speed = walk * SPRINT / WALK
	super(delta)
	move_speed = walk
	if brain.state != EnemyBrain.State.ATTACK or not brain.has_struck():
		return
	if _leaping:
		if not is_on_floor():
			_airborne = true
		elif _airborne:
			_land()
		return
	if _combo_time >= 0.0:
		_combo_time += delta
		if not _swung and _combo_time >= JaguarMoves.swing_time():
			_swung = true
			_swing()


## The brain's attack numbers follow the move it would start now.
func _brief_brain(has_target: bool, sheltered: bool) -> void:
	super(has_target, sheltered)
	if brain.state == EnemyBrain.State.ATTACK:
		return
	var distance := global_position.distance_to(target.global_position) if has_target and _sees_target else INF
	_planned = JaguarMoves.choose(distance)
	brain.attack_range = JaguarMoves.CLUB_RANGE if _planned == JaguarMoves.Move.CLUB else JaguarMoves.POUNCE_RANGE.y
	brain.windup = JaguarMoves.windup(_planned)
	brain.recovery = JaguarMoves.pounce_recovery(JaguarMoves.LIFT, GRAVITY) if _planned == JaguarMoves.Move.POUNCE else JaguarMoves.club_recovery()


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if from == EnemyBrain.State.ATTACK or to == EnemyBrain.State.STUNNED:
		_leaping = false
		_airborne = false
		_combo_time = -1.0
	match to:
		EnemyBrain.State.ATTACK:
			move = _planned
			_swung = false
			Sfx.play_at(&"jaguar_snarl", global_position + Vector3.UP * eye_height, -2.0)
		EnemyBrain.State.SUSPICIOUS:
			if from == EnemyBrain.State.DORMANT:
				Sfx.play_at(&"portrait_creak", global_position + Vector3.UP * eye_height, CREAK_DB, 0.15, 1.1)


## The end of the telegraph: the pounce leaps (aimed now; committed), the
## close blow goes straight into its swing.
func _on_strike() -> void:
	if move == JaguarMoves.Move.POUNCE and _target_alive():
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > JaguarMoves.CLUB_RANGE:
			_external = JaguarMoves.leap(global_position, target.global_position, JaguarMoves.LIFT, GRAVITY, JaguarMoves.MAX_SPEED)
			velocity.y = JaguarMoves.LIFT
			_leaping = true
			_airborne = false
			_combo_time = -1.0
			Sfx.play_at(&"swing", global_position, -6.0)
			return
	_combo_time = JaguarMoves.SETTLE   # no settling: the club comes straight down


## Landed: the knees take it, the floor takes chips, the club follows.
func _land() -> void:
	_leaping = false
	_airborne = false
	_combo_time = 0.0
	_external *= 0.2
	Fx.impact(global_position + Vector3.UP * 0.05, Vector3.UP, ExhibitMaterial.Kind.WOOD, 1.2)
	Sfx.play_at(&"weight_thud", global_position, -5.0)
	if _target_alive():
		var distance := global_position.distance_to(target.global_position)
		if distance < THUD_REACH:
			Events.shake_requested.emit(0.18 * (1.0 - distance / THUD_REACH))


## The club comes down: into the guard in its cone, into the floor otherwise.
func _swing() -> void:
	Sfx.play_at(&"swing", global_position + Vector3.UP, -3.0)
	var tip := _club_tip()
	Fx.impact(Vector3(tip.x, global_position.y + 0.03, tip.z), Vector3.UP, ExhibitMaterial.Kind.WOOD, 0.8)
	Sfx.play_at(&"hit_wood", tip, -7.0, 0.1, 0.8)
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	var to := target.global_position - global_position
	if JaguarMoves.swing_hits(-global_basis.z, to, attack_reach, JaguarMoves.SWING_HALF_ARC) and _has_line_of_sight():
		var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
		var flat := Vector3(to.x, 0.0, to.z)
		info.direction = flat.normalized() if flat.length() > 0.01 else -global_basis.z
		info.knockback = JaguarMoves.CLUB_KNOCKBACK
		info.position = target.global_position + Vector3.UP * HIT_HEIGHT
		target.take_damage(info)


## Where the club's teeth are now (world).
func _club_tip() -> Vector3:
	if rig != null and rig.part("club_tip") != null:
		return global_transform * rig.part_transform("club_tip").origin
	return global_position - global_basis.z * 1.6 + Vector3.UP * 0.2


## Chips fly off every hit (the wood's impact); a hard one knocks off a
## splinter of cedar.
func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return
	var hold := rig as JaguarRig
	if hold != null:
		hold.jolt(info.direction * clampf(info.amount / 12.0, 0.4, 2.5))
	if info.amount >= SPLINTER_DAMAGE:
		var fling := Vector3(info.direction.x, 0.0, info.direction.z).normalized() * randf_range(1.5, 3.0) \
				+ Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), randf_range(0.06, 0.1), fling)
