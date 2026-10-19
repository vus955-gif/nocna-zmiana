class_name FuDog
extends Enemy
## The bronze Fu dog of the Asia wing (design pietro-1-projekt 5.5, kit
## docs/art/kit-pietro1-azja.md 7): a guardian lion of patinated bronze,
## 160 HP, Dust 8, METAL (sparks). Heavy: 2.4 m/s, a slow turn (flanking
## works). Three moves (FuDogMoves decides):
## - the charge from 4-12 m: a 0.8 s telegraph (the head drops, the right
##   fore paw scrapes the floor twice in sparks, fu_scrape), then a run
##   along the line taken at its end (it steers only a little, only at
##   first) at CHARGE_SPEED for at most CHARGE_TIME / CHARGE_DISTANCE: the
##   first guard in its path takes the charge's damage once (charge_damage():
##   22 at the paw's 14, so the night's tuning scales it too); a wall stops
##   it dead (sparks, stunned WALL_STUN); a miss skids and comes round. It
##   starts only with a clear line at knee height to the guard (it will not
##   charge over a case it could see over);
## - the roar on a guard within 6 m in front: a 0.7 s telegraph (the pearl
##   in its mouth lights up, the head goes up, the chest swells), then
##   fu_roar and a RoarWave: a guard in the cone with a clear line reels
##   (Player.stagger ROAR_STAGGER); ROAR_COOLDOWN before the next; a hit on
##   the glowing pearl (the weak point) in the telegraph chokes the roar:
##   stunned PEARL_STUN;
## - the paw on a guard within 2.6 m in front: a 0.6 s raise, a slam.
## A lion and a lioness of neighbouring slots pair up when they are set down
## (the same hall, within PAIR_REACH): one charge at a time, never at a
## reeling guard; the lioness is the model's mirror image from the start (and
## roars more). Asleep it is the
## exhibit: right fore paw on the embroidered ball; waking, the paw comes
## off the ball (which stays on the plinth) with a clank of bronze and the
## head turns to the noise. Awake and idle it watches, breathes and swishes
## its plume; home again it puts its paw back up. The model "fu_dog" moves
## through a FuDogRig; without it a greybox.

const KIND := &"fu_dog"
const WALK := 2.4
## A mate is found within this (m, the same hall).
const PAIR_REACH := 18.0
## How often it rolls its next move (s).
const PLAN_INTERVAL := 0.5
## The charge finds a guard within this of the point ahead of its chest.
const CHARGE_CONTACT := 1.3
const CHEST_AHEAD := 1.0
## The roar aims at (and the charge reports hits on) the guard's chest.
const AIM_HEIGHT := 1.1
## The charge wants a clear line this high over the floor (m): its shins.
const KNEE_HEIGHT := 0.45
## The scrapes of the charge's telegraph (shares of the windup).
const SCRAPES: Array[float] = [0.3, 0.65]
## The telegraph's sparks and the crash shake the camera this close (m).
const SHAKE_REACH := 8.0
## The model's mouth, the roar's start, the right fore paw (enemy space,
## rest pose; the greybox's places).
const MOUTH_AT := Vector3(0.0, 1.58, -1.58)
const ROAR_AT := Vector3(0.0, 1.62, -1.77)
const PAW_AT := Vector3(0.35, 0.08, -1.0)
## Hit zones: the body, the head, the pearl (weak point).
const BODY_ZONE := Vector3(0.8, 0.9, 1.9)
const BODY_AT := Vector3(0.0, 1.05, 0.1)
const HEAD_RADIUS := 0.3
const HEAD_AT := Vector3(0.0, 1.62, -1.1)
const PEARL_RADIUS := 0.14
const COLLIDER_RADIUS := 0.55
const COLLIDER_LENGTH := 2.4

## The move under way (or the one it would start now).
var move: FuDogMoves.Move = FuDogMoves.Move.NONE
## Its pair (null: alone).
var pair: FuDogMoves.Pair = null
## The second of a pair: the mirror image, roaring more.
var lioness := false
## The roll under which it roars rather than charges (the pair sets it).
var roar_bias: float = FuDogMoves.LION_ROAR_BIAS

var _planned: FuDogMoves.Move = FuDogMoves.Move.NONE
var _roll: float = 0.5
var _plan_timer: float = 0.0
var _roar_cooldown: float = 0.0
var _charging := false
var _charge_dir := Vector3.ZERO
var _charge_time: float = 0.0
var _charge_from := Vector3.ZERO
var _charge_hit := false
var _skid: float = 0.0
var _scrapes: int = 0
var _ball: Node3D = null
var _ball_left := false


func _configure() -> void:
	max_health = 160.0
	move_speed = WALK
	turn_speed = 2.4
	attack_damage = FuDogMoves.PAW_DAMAGE
	attack_reach = FuDogMoves.PAW_RANGE
	knockback_resist = 0.8
	eye_height = 1.6
	marker_height = 2.5
	material_kind = ExhibitMaterial.Kind.METAL
	dust_value = 8
	notice_sound = &"growl"
	windup_lean = 0.0
	strike_lean = 0.0
	brain.reaction_time = 0.9
	brain.attack_range = FuDogMoves.PAW_RANGE
	brain.windup = FuDogMoves.PAW_WINDUP
	brain.recovery = FuDogMoves.recovery(FuDogMoves.Move.PAW)


func _ready() -> void:
	super()
	_plan_timer = randf() * PLAN_INTERVAL
	_roll = randf()
	# set down, a lion looks for its lioness: the one that comes second is
	# the mirror image from the first frame (flipped later she would pop
	# where she stands)
	if lioness:
		_mirror_model()   # (a mate that came first named her before her model stood)
	else:
		_find_mate()


func _build_body() -> void:
	# a long body: the capsule lies along it
	var collider := CollisionShape3D.new()
	collider.shape = capsule_shape(COLLIDER_RADIUS, COLLIDER_LENGTH)
	collider.rotation_degrees.x = 90.0
	collider.position = Vector3(0.0, COLLIDER_RADIUS + 0.01, 0.1)
	add_child(collider)
	rig = FuDogRig.build(self)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(BODY_ZONE), BODY_AT)
	var head_zone := add_hurtbox(sphere_shape(HEAD_RADIUS), HEAD_AT)
	var pearl_zone := add_hurtbox(sphere_shape(PEARL_RADIUS), MOUTH_AT, true)
	if rig != null:
		# the zones ride on the model (by place only: a lioness is a mirror
		# image, and a reflected zone basis is no zone)
		rig.track(body_zone, &"body")
		rig.track(head_zone, &"head")
		rig.track(pearl_zone, &"mouth_ball")


func _build_greybox() -> void:
	var bronze := body_material(Color(0.45, 0.5, 0.4))
	var dark := body_material(Color(0.2, 0.24, 0.2))
	var pearl := body_material(Color(0.85, 0.85, 0.9))
	add_part(box_mesh(Vector3(0.8, 0.8, 1.7)), Vector3(0, 1.1, 0.15), bronze)
	add_part(box_mesh(Vector3(0.6, 0.6, 0.7)), Vector3(0, 1.6, -1.1), bronze)
	add_part(box_mesh(Vector3(0.5, 0.2, 0.4)), Vector3(0, 1.3, -1.35), dark)
	add_part(box_mesh(Vector3(0.2, 0.2, 0.2)), MOUTH_AT, pearl)
	for x in [-0.3, 0.3]:
		for z in [-0.65, 0.85]:
			add_part(box_mesh(Vector3(0.24, 0.7, 0.24)), Vector3(x, 0.4, z), dark)
	add_part(box_mesh(Vector3(0.2, 0.5, 0.2)), Vector3(0, 1.6, 1.1), bronze, Vector3(-30.0, 0.0, 0.0))


# --- what the rig and the tests read -----------------------------------------------

## Running its charge.
func charging() -> bool:
	return _charging


## Skidding to a halt after a charge (0..1, 1 just stopped).
func skidding() -> float:
	return _skid / FuDogMoves.SKID if _skid > 0.0 else 0.0


## How many scrapes of the right fore paw the charge's telegraph has made.
func scrapes() -> int:
	return _scrapes


## What the charge takes off a guard: the paw's attack_damage grown by the
## charge's share (22 : 14), so the night's tuning (difficulty, full moon,
## the witching hour) scales it as it scales the paw.
func charge_damage() -> float:
	return attack_damage * FuDogMoves.CHARGE_DAMAGE / FuDogMoves.PAW_DAMAGE


## How fast the charge runs: CHARGE_SPEED at the walk it was made with, more
## when something (the witching hour) hurried the walk.
func charge_speed() -> float:
	return FuDogMoves.CHARGE_SPEED * move_speed / WALK


## Its right fore paw rests on the ball (asleep at its post).
func paw_on_ball() -> bool:
	return brain.state == EnemyBrain.State.DORMANT


## How bright the pearl glows (0..1): the roar's telegraph.
func pearl_glow() -> float:
	var hold := rig as FuDogRig
	if hold != null:
		return hold.pearl_glow()
	if brain.state == EnemyBrain.State.ATTACK and move == FuDogMoves.Move.ROAR and not brain.has_struck():
		return minf(brain.windup_progress() / FuDogRig.PEARL_ON, 1.0)
	return 0.0


## The embroidered ball, once it has left the lion's paw (on the plinth).
func ball() -> Node3D:
	return _ball


## Where the mouth (the pearl) is now (world).
func mouth() -> Vector3:
	if rig != null and rig.part("mouth_ball") != null:
		return global_transform * rig.part_transform("mouth_ball").origin
	return global_transform * MOUTH_AT


# --- the step -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	_roar_cooldown = maxf(_roar_cooldown - delta, 0.0)
	_skid = maxf(_skid - delta, 0.0)
	_plan_timer -= delta
	if _plan_timer <= 0.0:
		_plan_timer = PLAN_INTERVAL
		_roll = randf()
	_tick_scrapes()
	super(delta)
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	if _charging:
		_run_charge(delta)


## The brain's attack numbers follow the move it would start now.
func _brief_brain(has_target: bool, sheltered: bool) -> void:
	super(has_target, sheltered)
	if brain.state == EnemyBrain.State.ATTACK:
		return
	var distance := INF
	var off_front := 180.0
	if has_target and _sees_target:
		var to := target.global_position - global_position
		distance = to.length()
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.01:
			off_front = rad_to_deg((-global_basis.z).angle_to(flat.normalized()))
	var charge_ok := pair == null or pair.may_charge(self, _guard_staggered())
	if charge_ok and distance >= FuDogMoves.CHARGE_RANGE.x and distance <= FuDogMoves.CHARGE_RANGE.y:
		charge_ok = _knee_line_clear()
	_planned = FuDogMoves.choose(distance, off_front, _roar_cooldown <= 0.0, charge_ok, _roll, roar_bias)
	match _planned:
		FuDogMoves.Move.CHARGE:
			brain.attack_range = FuDogMoves.CHARGE_RANGE.y
		FuDogMoves.Move.ROAR:
			brain.attack_range = FuDogMoves.ROAR_RANGE
		FuDogMoves.Move.PAW:
			brain.attack_range = FuDogMoves.PAW_RANGE
		_:
			brain.attack_range = -1.0   # it closes in, or turns to him
	brain.windup = FuDogMoves.windup(_planned)
	brain.recovery = FuDogMoves.recovery(_planned)


func _may_attack() -> bool:
	return _planned != FuDogMoves.Move.NONE and not _charging and _skid <= 0.0


## The charge runs on its own line; the skid slows it; else as every exhibit.
func _steer(delta: float, has_target: bool) -> Vector3:
	if _charging:
		_set_world_yaw(atan2(-_charge_dir.x, -_charge_dir.z))
		EnemyCrowd.release(self)
		return _charge_dir * charge_speed()
	if _skid > 0.0:
		EnemyCrowd.release(self)
		return _charge_dir * charge_speed() * skidding() * skidding()
	return super(delta, has_target)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if from == EnemyBrain.State.ATTACK or to == EnemyBrain.State.STUNNED:
		if _charging:
			_end_charge(false)
		if pair != null:
			pair.end_charge(self)
	match to:
		EnemyBrain.State.ATTACK:
			move = _planned
			_scrapes = 0
			if move == FuDogMoves.Move.CHARGE:
				if pair != null:
					pair.begin_charge(self)
				Sfx.play_at(&"fu_scrape", _paw(), -2.0)
			elif move == FuDogMoves.Move.ROAR:
				Sfx.play_at(&"growl", mouth(), -6.0, 0.1, 0.8)
		EnemyBrain.State.SUSPICIOUS:
			if from == EnemyBrain.State.DORMANT:
				_leave_ball()
		_:
			if from == EnemyBrain.State.DORMANT:
				_leave_ball()


## The end of the telegraph: the charge sets off, the roar sounds, the paw
## comes down.
func _on_strike() -> void:
	match move:
		FuDogMoves.Move.CHARGE:
			_begin_charge()
		FuDogMoves.Move.ROAR:
			_roar()
		_:
			_paw_strike()


## The right fore paw scrapes twice in the charge's telegraph: sparks.
func _tick_scrapes() -> void:
	if brain.state != EnemyBrain.State.ATTACK or move != FuDogMoves.Move.CHARGE or brain.has_struck():
		return
	var w := brain.windup_progress()
	while _scrapes < SCRAPES.size() and w >= SCRAPES[_scrapes]:
		_scrapes += 1
		var paw := _paw()
		Fx.impact(paw, Vector3.UP, ExhibitMaterial.Kind.METAL, 1.2)


func _begin_charge() -> void:
	_charging = true
	_charge_time = 0.0
	_charge_from = global_position
	_charge_hit = false
	var to := -global_basis.z
	if _target_alive():
		to = target.global_position - global_position
	_charge_dir = Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.01 else -global_basis.z
	Sfx.play_at(&"growl", mouth(), 0.0, 0.1, 0.7)


## A frame of the charge (after the body moved): steer a little at first,
## the guard in its path takes the hit, a wall stops it dead, time or
## distance up it skids.
func _run_charge(delta: float) -> void:
	_charge_time += delta
	if _target_alive():
		_charge_dir = FuDogMoves.charge_turn(_charge_dir, target.global_position - global_position, _charge_time, delta)
	var chest := global_position - global_basis.z * CHEST_AHEAD
	if not _charge_hit and _target_alive():
		var to := target.global_position - chest
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() <= CHARGE_CONTACT and flat.dot(_charge_dir) >= -0.2 and not Haven.shelters(target.global_position):
			_charge_hit = true
			var info := DamageInfo.make(charge_damage(), DamageInfo.Kind.BLUNT, self)
			info.direction = _charge_dir
			info.knockback = FuDogMoves.CHARGE_KNOCKBACK
			info.position = target.global_position + Vector3.UP * AIM_HEIGHT
			target.take_damage(info)
			Sfx.play_at(&"weight_thud", info.position, -2.0)
			_end_charge(true)
			return
	if is_on_wall():
		var hit := get_last_slide_collision()
		var other: Object = hit.get_collider() if hit != null else null
		var wall := other != null and not other is Enemy and other != target and not (other is Node and (other as Node).has_method(&"take_damage"))
		if wall and get_wall_normal().dot(_charge_dir) < -0.5:
			_crash(get_wall_normal())
			return
	if _charge_time >= FuDogMoves.CHARGE_TIME or global_position.distance_to(_charge_from) >= FuDogMoves.CHARGE_DISTANCE:
		_end_charge(true)


## Into a wall: sparks off its head, a clang, stunned.
func _crash(normal: Vector3) -> void:
	var head := global_position + Vector3.UP * eye_height - global_basis.z * 1.3
	Fx.impact(head, normal, ExhibitMaterial.Kind.METAL, 2.5)
	Sfx.play_at(&"wall_hit", head)
	Sfx.play_at(&"hit_metal", head, -2.0, 0.1, 0.7)
	_shake(0.35)
	_charging = false
	_skid = 0.0
	if pair != null:
		pair.end_charge(self)
	brain.stun(FuDogMoves.WALL_STUN)


## The run is over: a skid (sparks off the paws), then only the turn-round
## is left of the recovery.
func _end_charge(skid: bool) -> void:
	_charging = false
	if pair != null:
		pair.end_charge(self)
	if skid:
		_skid = FuDogMoves.SKID
		Fx.impact(_paw(), Vector3.UP, ExhibitMaterial.Kind.METAL, 1.0)
		brain.cut_recovery(FuDogMoves.SKID + FuDogMoves.CHARGE_RETURN)


## The roar: the wave, and a guard in the cone with a clear line reels.
func _roar() -> void:
	_roar_cooldown = FuDogMoves.ROAR_COOLDOWN
	var from := mouth()
	var forward := -global_basis.z
	Sfx.play_at(&"fu_roar", from)
	RoarWave.spawn(get_parent(), from, forward)
	_shake(0.25)
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	if FuDogMoves.roar_hits(from, forward, target.global_position) and _clear_line(from, target.global_position + Vector3.UP * AIM_HEIGHT):
		if target.has_method(&"stagger"):
			target.stagger(FuDogMoves.ROAR_STAGGER)


## The paw: a guard in reach in the front cone takes the slam.
func _paw_strike() -> void:
	Sfx.play_at(&"swing", global_position + Vector3.UP, -2.0)
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > attack_reach or flat.length() < 0.01:
		return
	if (-global_basis.z).dot(flat.normalized()) >= cos(deg_to_rad(FuDogMoves.PAW_HALF_ARC)) and _has_line_of_sight():
		var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
		info.direction = flat.normalized()
		info.knockback = FuDogMoves.PAW_KNOCKBACK
		info.position = target.global_position + Vector3.UP * AIM_HEIGHT
		target.take_damage(info)
		Sfx.play_at(&"hit_metal", info.position, -4.0)


## Sparks fly off every hit (the metal's impact); the body rocks; a hit on
## the glowing pearl in the roar's telegraph chokes the roar.
func _on_damaged(info: DamageInfo) -> void:
	if info.periodic:
		return
	var hold := rig as FuDogRig
	if hold != null:
		hold.jolt(info.direction * clampf(info.amount / 15.0, 0.3, 2.0))
	if info.weak_point and brain.state == EnemyBrain.State.ATTACK and move == FuDogMoves.Move.ROAR and not brain.has_struck():
		var at := mouth()
		Fx.flash(at, Color(0.8, 0.9, 1.0), 2.5, 2.5, 0.25)
		Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 1.5)
		Sfx.play_at(&"hit_marble", at, -3.0, 0.1, 1.3)
		brain.stun(FuDogMoves.PEARL_STUN)


# --- the pair -------------------------------------------------------------------------

## A lone dog awake looks for a mate: another lone Fu dog of its hall
## within PAIR_REACH; the mate becomes the lioness.
func _find_mate() -> void:
	if not is_inside_tree():
		return
	for other in PerceptionWorld.exhibits():
		var mate := other as FuDog
		if mate == null or mate == self or mate.pair != null or not mate.is_inside_tree() or mate.is_frozen():
			continue
		if mate.global_position.distance_to(global_position) > PAIR_REACH:
			continue
		if home_room != &"" and mate.home_room != &"" and mate.home_room != home_room:
			continue
		# the one placed first is the lion, whichever of them looked first
		var exhibits := PerceptionWorld.exhibits()
		var first_is_me := exhibits.find(self) <= exhibits.find(mate)
		var lion: FuDog = self if first_is_me else mate
		var she: FuDog = mate if first_is_me else self
		pair = FuDogMoves.Pair.new(lion, she)
		mate.pair = pair
		roar_bias = pair.roar_bias(self)
		mate.roar_bias = pair.roar_bias(mate)
		she._become_lioness()
		return


func _become_lioness() -> void:
	lioness = true
	_mirror_model()


## The model flipped (its rig may not stand yet when a mate found her first:
## _ready() flips it then).
func _mirror_model() -> void:
	var hold := rig as FuDogRig
	if hold != null:
		hold.set_mirror(true)


## No level geometry between its shins and the guard's (a low case would
## stop the run dead; it would rather close in than charge into it).
func _knee_line_clear() -> bool:
	var knee := Vector3.UP * KNEE_HEIGHT
	return _clear_line(global_position + knee, target.global_position + knee)


func _guard_staggered() -> bool:
	return _target_alive() and target.has_method(&"staggered") and target.staggered()


# --- the ball --------------------------------------------------------------------------

## Waking, the paw comes off the ball: the ball stays on the plinth (it
## leaves the model for the level), a clank of bronze.
func _leave_ball() -> void:
	if _ball_left:
		return
	_ball_left = true
	Sfx.play_at(&"hit_metal", _paw(), -8.0, 0.1, 0.6)
	if rig == null:
		return
	var ball := rig.part("ball")
	var holder := get_parent()
	if ball == null or holder == null:
		return
	var xform := ball.global_transform
	for view in rig.meshes.duplicate():
		if is_instance_valid(view) and (view == ball or ball.is_ancestor_of(view)):
			rig.meshes.erase(view)
	ball.get_parent().remove_child(ball)
	holder.add_child(ball)
	ball.global_transform = xform
	ball.reset_physics_interpolation()
	ball.add_to_group(PROP_GROUP)   # it outlives the dog: dawn greys it with the rest
	_ball = ball


## Where the right fore paw is now (world).
func _paw() -> Vector3:
	if rig != null and rig.part("shin_fr") != null:
		var at := rig.part_transform("shin_fr").origin
		return global_transform * Vector3(at.x, 0.06, at.z - 0.15)
	return global_transform * PAW_AT


func _shake(trauma: float) -> void:
	if not _target_alive():
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < SHAKE_REACH:
		Events.shake_requested.emit(trauma * (1.0 - distance / SHAKE_REACH))
