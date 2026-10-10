class_name Mummy
extends Enemy
## The mummy of the Egyptian wing (design pietro-1-projekt 5.1): 110 HP,
## a 1.9 m/s shamble dragging its right foot, two attacks (MummyMoves
## decides which):
## - the claws up close (16),
## - the bandage lash from 2.4-4.6 m: a 0.6 s telegraph (the whip arm goes
##   up and back, the bandage unrolls and rises over its head; the aim
##   freezes for the last 0.15 s), then the bandage cracks out to the guard:
##   8 damage, a pull of up to 3 m toward the mummy (Player.yank; never
##   closer than 1.2 m) and a slow (x0.5 for 1 s after the pull). After a
##   lash only the claws for 4 s; the whip coils back slowly (an opening).
## Linen burns double; fire on its bandages (not a burn's tick) sets them
## alight and sends it running in panic for 2 s, arms flailing, no attacks.
## Hits puff tomb dust and tear off rags of bandage, heavy ones chip bone;
## it falls apart into its parts, bones, rags and a cloud of dust.
## Asleep it is an exhibit with its arms crossed on its chest; suspicious,
## its head turns to the noise first and its eyes light up (EyeGlow).
## An [member entombed] mummy (an ambush) sleeps in a coffin (or a
## sarcophagus the level put by its post): waking, the lid falls or slides
## off and it climbs out (MummyMoves.rise_phases), then hunts. The model
## (ArtLibrary "mummy") moves through a MummyRig; without it a greybox.

const KIND := &"mummy"
## The body's hit zone (capsule) and the head's (weak point; the model's
## WeakPoint marker at 1.63 m).
const BODY_RADIUS := 0.27
const BODY_HEIGHT := 1.45
const BODY_Y := 0.82
const HEAD_RADIUS := 0.14
const HEAD_AT := Vector3(0.0, 1.63, -0.03)
## Share of its turning speed the body turns with while it is suspicious
## (the head turns first).
const SUSPICIOUS_TURN := 0.3
## A free tomb this close to its post (m, floor plan) takes an entombed mummy.
const TOMB_REACH := 2.5
## In its closed tomb it only feels the guard this close (m).
const TOMB_SENSE := 1.5
## Where the bandage leaves the hand at rest (the model's whip_1 pivot) and
## where the lash aims on the guard (over his feet).
const WRIST_AT := Vector3(0.21, 0.84, -0.05)
const GUARD_CHEST := 1.15
## The whip's crack in mummy_lash.wav comes this long after its start; the
## sound starts so the crack lands LASH_CRACK_DELAY after the strike.
const LASH_SOUND_CRACK := 0.44
const LASH_CRACK_DELAY := 0.08
## Gore: a rag of bandage flies off a hit of at least SCRAP_DAMAGE (at most
## one every SCRAP_INTERVAL s), a chip of bone off one of CHIP_DAMAGE or a
## head hit.
const SCRAP_DAMAGE := 14.0
const SCRAP_INTERVAL := 0.25
const CHIP_DAMAGE := 25.0

enum Lash { NONE, HIT, MISSED }

var moves := MummyMoves.new()
## Sleeps in a tomb and climbs out when it wakes (an ambush). Set before it
## enters the tree.
var entombed := false
## Its tomb (null: it sleeps standing as an exhibit).
var tomb: MummyTomb = null
## The attack under way (or the one it would start now).
var move: MummyMoves.Move = MummyMoves.Move.CLAW
## How the last lash went (the rig plays the hit, the miss's slap).
var lash_result: Lash = Lash.NONE
## Where the lash aims (world; frozen for the end of the telegraph).
var lash_aim := Vector3.ZERO

var _planned: MummyMoves.Move = MummyMoves.Move.CLAW
var _lash_sound := false
## Seconds into climbing out of the tomb (-1: not begun).
var _rise_time: float = -1.0
var _risen := false
var _rise_from := Vector3.ZERO
var _rise_to := Vector3.ZERO
var _panic_heading := Vector3.ZERO
var _panic_turn: float = 0.0
var _scrap_wait: float = 0.0
## A missed lash slaps the floor here after _slap_in seconds.
var _slap_in: float = -1.0
var _slap_at := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _configure() -> void:
	max_health = 110.0
	move_speed = 1.9
	turn_speed = 3.0
	attack_damage = 16.0
	attack_reach = 1.9
	knockback_resist = 0.35
	eye_height = 1.6
	marker_height = 2.05
	material_kind = ExhibitMaterial.Kind.LINEN
	dust_value = 6
	notice_sound = &"mummy_groan"
	brain.reaction_time = 0.9
	brain.attack_range = MummyMoves.CLAW_RANGE
	brain.windup = MummyMoves.CLAW_WINDUP
	brain.recovery = MummyMoves.CLAW_RECOVERY


func _ready() -> void:
	super()
	_rng.randomize()
	if entombed:
		_settle_in_tomb.call_deferred()


func _build_body() -> void:
	add_collider(0.3, 1.8)
	rig = MummyRig.build(self)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(capsule_shape(BODY_RADIUS, BODY_HEIGHT), Vector3(0.0, BODY_Y, 0.0))
	var head_zone := add_hurtbox(sphere_shape(HEAD_RADIUS), HEAD_AT, true)
	if rig != null:
		# the zones ride on the model: hunched, flailing, lying in a sarcophagus
		rig.track(body_zone, &"torso", true)
		rig.track(head_zone, &"head")


func _build_greybox() -> void:
	var linen := body_material(Color(0.66, 0.58, 0.44))
	var dark := body_material(Color(0.3, 0.24, 0.17))
	var torso := CapsuleMesh.new()
	torso.radius = 0.22
	torso.height = 0.8
	add_part(torso, Vector3(0.0, 1.15, 0.0), linen)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.3
	add_part(head, HEAD_AT, linen)
	add_part(box_mesh(Vector3(0.14, 0.03, 0.02)), HEAD_AT + Vector3(0.0, 0.02, -0.125), dark)
	for side in [-1.0, 1.0]:
		add_part(box_mesh(Vector3(0.13, 0.9, 0.15)), Vector3(0.1 * side, 0.45, 0.0), linen)
		add_part(box_mesh(Vector3(0.1, 0.7, 0.1)), Vector3(0.27 * side, 1.12, -0.04), linen)


# --- what the rig reads -------------------------------------------------------

## In its tomb and not out of it yet (asleep or climbing out).
func in_tomb() -> bool:
	return tomb != null and not _risen


## Climbing out of its tomb now.
func rising() -> bool:
	return _rise_time >= 0.0 and not _risen


## Progress of the three phases of climbing out (zero while it sleeps in
## its tomb, one when it is out or never had a tomb).
func rise_phases() -> Vector3:
	if tomb == null or _risen:
		return Vector3.ONE
	if _rise_time < 0.0:
		return Vector3.ZERO
	return MummyMoves.rise_phases(tomb.style, _rise_time)


## Running in panic now (its bandages on fire).
func panicking() -> bool:
	return moves.panicking() and not rising() \
			and brain.state != EnemyBrain.State.STUNNED and brain.state != EnemyBrain.State.DORMANT \
			and brain.state != EnemyBrain.State.DESTROYED


## Where the bandage leaves the hand now (world).
func wrist() -> Vector3:
	var hold := rig as MummyRig
	if hold != null:
		return hold.wrist()
	return global_transform * WRIST_AT


## Where the lash's tip goes now (world): the guard's chest while it holds
## him, else the floor under its aim.
func lash_target() -> Vector3:
	if lash_result == Lash.HIT and _target_alive():
		return target.global_position + Vector3.UP * GUARD_CHEST
	if lash_result == Lash.MISSED:
		return _slap_at
	return lash_aim + Vector3.UP * GUARD_CHEST


# --- the step ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	moves.tick(delta)
	_scrap_wait = maxf(_scrap_wait - delta, 0.0)
	if rising():
		_advance_rise(delta)
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	_time_lash_sound()
	if _slap_in >= 0.0:
		_slap_in -= delta
		if _slap_in < 0.0:
			Fx.puff(_slap_at, ExhibitMaterial.particle_color(ExhibitMaterial.Kind.LINEN), 10, 0.35)
			Sfx.play_at(&"hit_linen", _slap_at, -6.0)


## The brain's attack numbers follow the move it would start now (the
## whip's reach while the lash is ready, else the claws').
func _brief_brain(has_target: bool, sheltered: bool) -> void:
	super(has_target, sheltered)
	if brain.state == EnemyBrain.State.ATTACK:
		return
	var distance := global_position.distance_to(target.global_position) if has_target and _sees_target else INF
	_planned = moves.planned(distance)
	brain.attack_range = moves.attack_range(distance)
	brain.windup = moves.windup(_planned)
	brain.recovery = moves.recovery(_planned)


func _may_attack() -> bool:
	return not rising() and not moves.panicking() and not in_tomb()


## Asleep in its closed tomb it only feels a guard right next to it.
func _can_see_target() -> bool:
	if in_tomb() and not rising():
		return global_position.distance_to(target.global_position) <= TOMB_SENSE
	return super()


func _steer(delta: float, has_target: bool) -> Vector3:
	if rising() or (in_tomb() and brain.state == EnemyBrain.State.DORMANT):
		EnemyCrowd.release(self)
		return Vector3.ZERO
	if panicking():
		return _panic_steer(delta)
	if brain.state == EnemyBrain.State.SUSPICIOUS:
		# its head snaps round (the rig); the stiff body follows slowly
		_face_towards(brain.last_known, delta * SUSPICIOUS_TURN)
		return Vector3.ZERO
	if brain.state == EnemyBrain.State.ATTACK and move == MummyMoves.Move.LASH and not brain.has_struck():
		var left := brain.windup * (1.0 - brain.windup_progress())
		if left > MummyMoves.LASH_AIM_LOCK and _target_alive():
			lash_aim = target.global_position
		_face_towards(lash_aim, delta * 0.5)
		return Vector3.ZERO
	return super(delta, has_target)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.ATTACK:
		move = _planned
		_lash_sound = false
		if move == MummyMoves.Move.LASH:
			lash_result = Lash.NONE
			lash_aim = target.global_position if _target_alive() else global_position - global_basis.z * 3.0
	if from == EnemyBrain.State.DORMANT and to != EnemyBrain.State.DESTROYED and in_tomb() and _rise_time < 0.0:
		_begin_rise()


func _on_strike() -> void:
	if move == MummyMoves.Move.LASH:
		_lash()
	else:
		super()


## The lash lands (or not) the moment it strikes: in reach, in its cone, a
## clear line from the hand to his chest.
func _lash() -> void:
	moves.lash_struck()
	lash_result = Lash.MISSED
	_slap_at = Vector3(lash_aim.x, global_position.y + 0.05, lash_aim.z)
	if not _target_alive():
		_slap_in = 0.12
		return
	var to := target.global_position - global_position
	var chest := target.global_position + Vector3.UP * GUARD_CHEST
	if Haven.shelters(target.global_position) or not moves.lash_hits(-global_basis.z, to) or not _clear_line(wrist(), chest):
		_slap_in = 0.12
		return
	lash_result = Lash.HIT
	var flat := Vector3(to.x, 0.0, to.z)
	var toward := -flat.normalized() if flat.length() > 0.01 else global_basis.z
	var info := DamageInfo.make(MummyMoves.LASH_DAMAGE, DamageInfo.Kind.BLUNT, self)
	info.direction = -toward
	info.position = chest
	target.take_damage(info)
	var pull := MummyMoves.pull_distance(flat.length())
	if pull > 0.01 and target.has_method(&"yank"):
		target.yank(toward * pull / MummyMoves.PULL_TIME, MummyMoves.PULL_TIME)
	if target.has_method(&"slow"):
		target.slow(MummyMoves.SLOW, MummyMoves.PULL_TIME + MummyMoves.SLOW_TIME)


## Starts mummy_lash so its crack lands just after the strike.
func _time_lash_sound() -> void:
	if _lash_sound or move != MummyMoves.Move.LASH or brain.state != EnemyBrain.State.ATTACK or brain.has_struck():
		return
	var elapsed := brain.windup_progress() * brain.windup
	if elapsed >= brain.windup - LASH_SOUND_CRACK + LASH_CRACK_DELAY:
		_lash_sound = true
		Sfx.play_at(&"mummy_lash", wrist())


# --- fire and panic ------------------------------------------------------------------

func take_damage(info: DamageInfo) -> void:
	var catches := info.kind == DamageInfo.Kind.FIRE and not info.periodic
	super(info)
	if catches and not info.blocked and is_inside_tree() and brain.state != EnemyBrain.State.DESTROYED and not is_frozen():
		_catch_fire(info)


## Its bandages catch fire: they burn on, and it panics (unless it just did).
func _catch_fire(info: DamageInfo) -> void:
	Burn.ignite(self, MummyMoves.BURN_DPS, MummyMoves.BURN_TIME, info.source)
	if not moves.catch_fire():
		return
	brain.interrupt()
	_panic_turn = 0.0
	Sfx.play_at(&"mummy_groan", global_position + Vector3.UP * eye_height, 2.0)


## Runs from the guard, a new swerve every PANIC_TURN seconds, keeping to
## the walkable floor.
func _panic_steer(delta: float) -> Vector3:
	EnemyCrowd.release(self)
	_panic_turn -= delta
	if _panic_turn <= 0.0 or _panic_heading.is_zero_approx():
		_panic_turn = MummyMoves.PANIC_TURN
		var away := global_position - target.global_position if _target_alive() else global_basis.z
		_panic_heading = _walkable(moves.panic_heading(away, _rng))
	_face_towards(global_position + _panic_heading, delta * 2.5)
	return _panic_heading * move_speed * MummyMoves.PANIC_PACE + EnemyCrowd.push_for(self)


## [param heading], or the nearest turn of it that does not run off the
## navmesh within 1.5 m (no navmesh: as it is).
func _walkable(heading: Vector3) -> Vector3:
	if not _map_has_regions():
		return heading
	for turn in [0.0, 1.2, -1.2, 2.2, -2.2, PI]:
		var candidate := heading.rotated(Vector3.UP, turn)
		var ahead := global_position + candidate * 1.5
		var snapped := _walk_closest_point(ahead)
		if Vector2(snapped.x - ahead.x, snapped.z - ahead.z).length() < 0.4:
			return candidate
	return heading


# --- the tomb ---------------------------------------------------------------------

## Lies down in a free tomb near its post, or stands up its own coffin there.
func _settle_in_tomb() -> void:
	if not is_inside_tree() or brain.state != EnemyBrain.State.DORMANT or tomb != null:
		return
	var found := MummyTomb.free_near(self, global_position, TOMB_REACH)
	if found == null:
		found = MummyTomb.build(MummyMoves.Tomb.COFFIN, Transform3D.IDENTITY)
		var holder := get_parent() as Node3D
		var at := Transform3D(Basis(Vector3.UP, _world_yaw()), global_position)
		found.transform = holder.global_transform.affine_inverse() * at if holder != null else at
		get_parent().add_child(found)
		found.reset_physics_interpolation()
	tomb = found
	tomb.occupant = self
	add_collision_exception_with(tomb.body)
	var front := tomb.front()
	global_position = tomb.rest_position()
	_set_world_yaw(atan2(-front.x, -front.z))
	home = global_position
	home_yaw = _world_yaw()
	brain.home = home
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func _begin_rise() -> void:
	_rise_time = 0.0
	_rise_from = global_position
	_rise_to = tomb.exit_point()
	_rise_to.y = global_position.y
	tomb.open()
	EnemyCrowd.release(self)


## Moves the body out over the last phase; done, it stands at the exit
## (its post stays in the tomb: back home it sleeps standing in it).
func _advance_rise(delta: float) -> void:
	_rise_time += delta
	var phases := MummyMoves.rise_phases(tomb.style, _rise_time)
	var out := phases.z * phases.z * (3.0 - 2.0 * phases.z)
	var at := _rise_from.lerp(_rise_to, out)
	global_position = Vector3(at.x, global_position.y, at.z)
	velocity = Vector3(0.0, velocity.y, 0.0)
	if _rise_time >= MummyMoves.rise_length(tomb.style):
		_risen = true
		_rise_time = -1.0


# --- gore ----------------------------------------------------------------------------

## Dust puffs come with every hit (the linen's impact); heavier hits tear
## off a rag of bandage, the heaviest (or one to the head) chip bone. The
## loose strips swing with every hit.
func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return
	var hold := rig as MummyRig
	if hold != null:
		hold.jolt(info.direction * clampf(info.amount / 10.0, 0.5, 3.0))
	if info.amount >= SCRAP_DAMAGE and _scrap_wait <= 0.0:
		_scrap_wait = SCRAP_INTERVAL
		var fling := Vector3(info.direction.x, 0.0, info.direction.z).normalized() * randf_range(1.5, 3.0) \
				+ Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		if hold != null:
			hold.tear_rag(info.position, fling)
		else:
			Fx.chunk(info.position, ExhibitMaterial.color(material_kind), 0.12, fling)
	if info.amount >= CHIP_DAMAGE or info.weak_point:
		var chip := Vector3(randf_range(-1.5, 1.5), randf_range(2.5, 4.0), randf_range(-1.5, 1.5))
		Fx.chunk(info.position, ExhibitMaterial.color(ExhibitMaterial.Kind.BONE), 0.05, chip)
