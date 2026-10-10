class_name ReliefWarrior
extends Enemy
## The warrior from the relief (Assyria, design pietro-1-projekt 5.2): a
## flat gypsum spearman who tears himself out of the wall panels.
## - Asleep he is the carved figure of an awakening slab on the wall behind
##   his post (ReliefWall, ReliefPanel); woken, its cracks glow up (0.8 s),
##   he steps out; until he is out he cannot be hit and does nothing.
## - 50 HP; flat: hits on his edge do half (ReliefMoves.edge_factor, on the
##   way his carved face looks - he turns edge-on to attack); his eye, on
##   the carved face, is the weak point. Gypsum chips fly off hits.
## - He keeps 7-12 m from the guard, sidestepping along his plane, and
##   throws his spear in an arc (0.8 s windup, 14; it grows back in his hand
##   in 3.5 s); up close he stabs (12). When the guard aims at him he darts
##   2 m aside (at most every 1.6 s).
## - Pressed (the guard within 3.5 m, or just hit) with a wall at his back,
##   he sinks into it and comes out 6 m along it (at most every 8 s).
## Dust 5. The model "relief_warrior" moves through a ReliefRig; without
## it a greybox.

const KIND := &"relief_warrior"
const BODY_SIZE := Vector3(0.55, 1.85, 0.18)
const BODY_AT := Vector3(0.08, 0.93, 0.02)
const EYE_RADIUS := 0.07
## Where the eye sits (the model's "eye" marker, on the carved face).
const EYE_AT := Vector3(-0.113, 1.648, -0.065)
## Chips of gypsum fly off a hit of at least this much.
const CHIP_DAMAGE := 10.0
## He keeps this far from the guard while his spear is in hand.
const KEEP := Vector2(7.0, 12.0)
const BACK_OFF := 4.5
## The guard this close presses him (m).
const PRESSED := 3.5
## Seconds after a hit that still count as being pressed.
const HIT_MEMORY := 1.0
## Sidestep speed (m/s, dies down on the floor: ~2 m).
const DART := 11.0
const CHECK := 0.2

var moves := ReliefMoves.new()
var wall: ReliefWall
## The attack under way (or the one he would start).
var move: ReliefMoves.Move = ReliefMoves.Move.STRIKE

var _planned: ReliefMoves.Move = ReliefMoves.Move.STRIKE
var _zones: Array[Hurtbox] = []
var _hurtable := true
var _check: float = 0.0
var _hit_ago: float = INF
var _strafe: float = 1.0
var _strafe_timer: float = 0.0


func _configure() -> void:
	max_health = 50.0
	move_speed = 3.2
	turn_speed = 8.0
	attack_damage = ReliefMoves.STRIKE_DAMAGE
	attack_reach = 2.0
	eye_height = 1.65
	marker_height = 2.25
	material_kind = ExhibitMaterial.Kind.MARBLE
	dust_value = 5
	notice_sound = &""
	windup_lean = 0.08
	strike_lean = -0.12
	brain.reaction_time = 0.7
	brain.attack_range = ReliefMoves.STRIKE_RANGE
	brain.windup = ReliefMoves.STRIKE_WINDUP
	brain.recovery = ReliefMoves.STRIKE_RECOVERY


func _init() -> void:
	super()
	wall = ReliefWall.new(self, ReliefPanel.Kind.WARRIOR)


func _ready() -> void:
	super()
	_strafe = 1.0 if randf() < 0.5 else -1.0
	Events.weapon_fired.connect(_on_weapon_fired)
	wall.setup.call_deferred()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = box_shape(Vector3(0.5, 1.85, 0.2))
	shape.position = Vector3(0.08, 0.93, 0.02)
	add_child(shape)
	rig = ReliefRig.build(self, ReliefRig.Kind.WARRIOR, wall)
	if rig == null:
		_build_greybox()
	var body_zone := add_hurtbox(box_shape(BODY_SIZE), BODY_AT)
	var eye_zone := add_hurtbox(sphere_shape(EYE_RADIUS), EYE_AT, true)
	_zones = [body_zone, eye_zone]
	if rig != null:
		rig.track(body_zone, &"torso", true)
		rig.track(eye_zone, &"eye")
	_set_hurtable(false)


func _build_greybox() -> void:
	var stone := body_material(Color(0.62, 0.66, 0.68))
	add_part(box_mesh(Vector3(0.4, 0.95, 0.16)), Vector3(0.05, 1.3, 0.0), stone)
	add_part(box_mesh(Vector3(0.3, 0.92, 0.14)), Vector3(0.0, 0.46, 0.0), stone)
	add_part(box_mesh(Vector3(0.24, 0.3, 0.14)), Vector3(-0.05, 1.72, 0.0), stone)
	add_part(box_mesh(Vector3(0.04, 2.1, 0.04)), Vector3(-0.36, 1.1, -0.05), stone)


## Which way his carved face looks (he turns edge-on to attack).
func carved_face() -> Vector3:
	var body := rig as ReliefRig
	return body.face_normal() if body != null else -global_basis.z


## Hits on the edge of the slab do half; in the wall nothing lands.
func take_damage(info: DamageInfo) -> void:
	if not wall.hurtable():
		return
	info.amount *= ReliefMoves.edge_factor(carved_face(), info.direction)
	if not info.periodic:
		_hit_ago = 0.0
	super(info)


func _on_damaged(info: DamageInfo) -> void:
	if info.periodic or info.amount < CHIP_DAMAGE:
		return
	var fling := Vector3(info.direction.x, 0.0, info.direction.z).normalized() * randf_range(1.0, 2.5) \
			+ Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
	var body := rig as ReliefRig
	if body != null:
		body.chip(info.position, fling)
	else:
		Fx.chunk(info.position, ExhibitMaterial.color(material_kind), 0.07, fling)


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or is_frozen():
		return
	moves.tick(delta)
	_hit_ago += delta
	wall.tick(delta)
	_set_hurtable(wall.hurtable())
	super(delta)
	_check -= delta
	if _check <= 0.0 and brain.state != EnemyBrain.State.DESTROYED:
		_check = CHECK
		_react()


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
	return not wall.busy()


func _attacks_from_range() -> bool:
	return true


func _uses_attack_ring() -> bool:
	return brain.attack_range <= RING_MAX_RANGE


func _steer(delta: float, has_target: bool) -> Vector3:
	if wall.busy():
		EnemyCrowd.release(self)
		return Vector3.ZERO
	return super(delta, has_target)


## Spear in hand he keeps his distance and paces sideways along his plane
## (back off when crowded, close in from afar); without it he closes in.
func _chase_direction(delta: float, goal: Vector3) -> Vector3:
	if brain.state != EnemyBrain.State.HUNT or not _sees_target or moves.throw_ready_in > 0.0 or _detour_time > 0.0:
		return super(delta, goal)
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0:
		_refresh_path(delta, goal)
	var away := global_position - target.global_position
	away.y = 0.0
	var distance := away.length()
	if distance < 0.01 or distance > KEEP.y:
		return super(delta, goal)
	away /= distance
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.5, 3.0)
		_strafe = -_strafe
	var side := Vector3.UP.cross(away) * _strafe
	if distance < BACK_OFF:
		return (away + side * 0.4).normalized()
	if distance < KEEP.x:
		return (away * 0.6 + side * 0.5).normalized()
	return side * 0.55


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.ATTACK:
		move = _planned
	if from == EnemyBrain.State.DORMANT and to != EnemyBrain.State.DESTROYED:
		wall.wake()


func _on_strike() -> void:
	if move == ReliefMoves.Move.THROW:
		_throw()
	else:
		super()


## The spear in an arc at his chest (not through a wall).
func _throw() -> void:
	moves.thrown()
	var body := rig as ReliefRig
	if body != null:
		body.spear_thrown()
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	var grip := rig.part("spear") if rig != null else null
	var hand := grip.global_position if grip != null else global_transform * Vector3(0.0, 1.9, -0.3)
	var aim := target.global_position + Vector3.UP * 1.1
	var launch: Variant = ReliefMoves.throw_velocity(hand, aim)
	if launch == null:
		return
	var spear := ReliefSpear.throw(hand, launch, self)
	get_parent().add_child(spear)
	Sfx.play_at(&"centaur_javelin", hand, -4.0)


## Sidesteps when the guard aims at him, sinks into the wall when pressed.
func _react() -> void:
	if wall.busy() or not brain.is_hunting() or not _target_alive():
		return
	var to := target.global_position - global_position
	var distance := Vector2(to.x, to.z).length()
	if distance <= PRESSED or _hit_ago <= HIT_MEMORY:
		if moves.wall_ready_in <= 0.0 and wall.sink(target.global_position):
			moves.sink()
			EnemyCrowd.release(self)
			return
	if distance > PRESSED and _aimed_at():
		_dart()


func _on_weapon_fired(_weapon: StringName) -> void:
	if is_inside_tree() and not wall.busy() and brain.is_hunting() and _aimed_at():
		_dart()


## A quick step aside along his plane (the side with floor to land on).
func _dart() -> void:
	if not moves.sidestep():
		return
	var side := global_basis.x
	side.y = 0.0
	side = side.normalized() * (1.0 if randf() < 0.5 else -1.0)
	if _map_has_regions():
		var landing := global_position + side * ReliefMoves.SIDESTEP
		if _walk_closest_point(landing).distance_to(landing) > 0.5:
			side = -side
	shove(side * DART)
	Sfx.play_at(&"relief_scrape", global_position + Vector3.UP, -8.0)


## The guard (a Player) looks at him now.
func _aimed_at() -> bool:
	var guard := target as Player
	if guard == null or guard.camera == null:
		return false
	var eye := guard.camera.global_position
	return ReliefMoves.aimed_at(eye, -guard.camera.global_basis.z, global_position + Vector3.UP * 1.1)


func _set_hurtable(on: bool) -> void:
	if on == _hurtable:
		return
	_hurtable = on
	for zone in _zones:
		zone.collision_layer = Layers.HURTBOX if on else 0
