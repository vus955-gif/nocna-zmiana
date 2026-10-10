class_name TRex
extends CharacterBody3D
## The lobby boss: the T-Rex skeleton, woken by the red crystal lodged
## between its ribs. Only the crystal takes full damage (bones 10%, with
## sparks and a grey hit marker); a charge into a wall or column stuns it
## and pushes the crystal out (x1.5). It walks straight at the guard without
## a navigation mesh (feelers steer it around columns, a sidestep frees it
## when stuck), charges after a scrape-and-bellow telegraph, whips its tail
## at a guard behind it, and roars: from phase 2 to call wax figures (via
## [member summon]), in phase 3 to bring down the ceiling. A taser on the
## crystal staggers it. A guard inside a haven is no target (its
## exhibit-only walls stop the boss too). On death the crystal bursts and
## the skeleton falls apart into physical bones.
##
## The rules and timings live in TRexBrain; bones, pose and debris in
## TRexSkeleton. For a HUD: [member health] (a Health node: changed signal),
## [member max_health], [member phase], signals phase_changed and defeated,
## plus Events.boss_awakened / Events.boss_defeated. Works under any parent
## (moved or turned): it steers and places what it spawns in world space.

signal phase_changed(phase: int)
signal defeated
## The skeleton fell apart (DEATH_COLLAPSE_DELAY after defeated): the bones
## now lie in [param remains] (a node in the boss's parent).
signal collapsed(remains: Node3D)
signal state_changed(from: TRexBrain.State, to: TRexBrain.State)

const GRAVITY := 15.0
const CHARGE_DAMAGE := 30.0
const CHARGE_KNOCKBACK := 15.0
## The part of the body that runs the guard over in a charge: from the
## hips this far forward (nothing behind them), this wide either side.
const CHARGE_REACH := 4.8
const CHARGE_HALF_WIDTH := 1.15
const TAIL_DAMAGE := 25.0
const TAIL_KNOCKBACK := 16.0
## The whip hits where the real tail bones sweep through the guard: within
## their thickness plus GUARD_RADIUS sideways, and low enough (chevrons
## included) to reach below his head. Near its base the tail passes overhead.
const TAIL_CHEVRON := 0.25
const GUARD_RADIUS := 0.4
const GUARD_HEIGHT := 1.8
const DEBRIS_SPREAD := Vector2(3.0, 4.2)
## Shadows of one roar keep at least this far apart (metres), turning from
## their random direction in steps of DEBRIS_TURN (rad, alternately left
## and right, all the way round) when a wall is in the way.
const DEBRIS_GAP := 2.5
const DEBRIS_TURN := 0.25
const SUMMON_BATCH := 4
const MAX_SUMMONED := 6
## It stops walking this close to the guard (it towers over him anyway).
const STOP_DISTANCE := 3.2
## The skull's collider (hips space): it juts out furthest, so a wall at the
## guard's back stops the boss with its snout this far ahead of the hips.
const HEAD_COLLIDER := Vector3(0.0, 4.45, -5.0)
const HEAD_RADIUS := 0.6
const SNOUT_REACH := 5.9
const FEELER_LENGTH := 5.0
## Feelers start this far ahead of the hips (inside its own chest).
const FEELER_START := 0.9
## Closer to the guard than this much feeler, it just walks at him.
const FEELER_MIN := 0.5
const FEELER_HEIGHT := 1.2
const FEELER_HALF_WIDTH := 1.0
const STEER_INTERVAL := 0.1
const STUCK_TIME := 1.2
const STUCK_PROGRESS := 0.6
const DETOUR_TIME := 1.4
## A charge contact whose normal points this much against the run is a slam.
const WALL_HIT_DOT := -0.5
const DEATH_COLLAPSE_DELAY := 0.8
## Metres per step of the walk cycle.
const STEP_LENGTH := 2.2
## Seconds of the wake roar before it steps off its pedestal.
const WAKE_ROAR_TIME := 1.7
## Steepest ground it walks on (degrees).
const MAX_SLOPE_DEG := 20.0

@export var max_health: float = 1200.0
## Dust dropped for the guard (DustDropper bursts it on Events.boss_defeated).
@export var dust_value: int = 100

var brain := TRexBrain.new()
var health: Health
## Who it hunts. Defaults to the node in group "player".
var target: Node3D = null
var skeleton: TRexSkeleton
## Called by the roar with the number of exhibits wanted; returns the
## exhibits it woke or spawned (Array). Unset = the roar calls no one.
var summon: Callable = Callable()
## Exhibits it called that may still be alive.
var summoned: Array[Node] = []
## Bone debris left after death (in the boss's parent).
var remains: Node3D = null
var phase: int:
	get:
		return brain.phase

var _charge_dir := Vector3.FORWARD
var _charge_hit: bool = false
var _recoil := Vector3.ZERO
var _tail_side: float = 1.0
## Tail joints of the last whip frame, and whether this whip already hit.
var _tail_before := PackedVector3Array()
var _tail_hit: bool = false
var _stagger_side: float = 1.0
var _steer_dir := Vector3.ZERO
var _steer_timer: float = 0.0
var _stuck_time: float = 0.0
var _stuck_from := Vector3.ZERO
var _detour_dir := Vector3.ZERO
var _detour_time: float = 0.0
var _detour_side: float = 1.0
var _death_time: float = -1.0
var _walk_distance: float = 0.0
var _last_step: int = 0
var _last_beat: int = 0
var _scrape_timer: float = 0.0
var _crystal_flash: float = 0.0
var _fall_speed: float = 0.0
var _posed_asleep: bool = false
var _bone_zone: TRexZone
var _crystal_zone: TRexZone
## Frame and shooter of the last gold (crystal) hit marker.
var _gold_frame: int = -1
var _gold_source: int = 0


func _ready() -> void:
	add_to_group(&"boss")
	collision_layer = Layers.ENEMY
	# the exhibit-only walls of a haven stop it too
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY_BLOCK
	# the lobby's stair ramps (about 27 degrees) are walls to it: no charging
	# up onto the balcony
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEG)
	_add_colliders()
	health = Health.new()
	health.max_health = max_health
	add_child(health)
	_bone_zone = TRexZone.make(self, TRexBrain.Zone.BONE)
	add_child(_bone_zone)
	_crystal_zone = TRexZone.make(self, TRexBrain.Zone.CRYSTAL)
	add_child(_crystal_zone)
	skeleton = TRexSkeleton.new()
	add_child(skeleton)
	skeleton.build(_bone_zone, _crystal_zone)
	brain.state_changed.connect(_on_state_changed)
	brain.phase_changed.connect(_on_phase_changed)
	brain.roar_peak.connect(_on_roar_peak)
	brain.tail_strike.connect(_on_tail_strike)
	brain.charge_started.connect(_on_charge_started)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	_detour_side = 1.0 if randf() < 0.5 else -1.0


## Wakes it from its museum pose (in the game: the crystal has just lodged
## between its ribs). Only the first call counts.
func wake() -> void:
	if brain.state != TRexBrain.State.DORMANT:
		return
	brain.wake()
	skeleton.set_crystal_present(true)
	Events.boss_awakened.emit(self)


func is_dormant() -> bool:
	return brain.state == TRexBrain.State.DORMANT


func is_dead() -> bool:
	return brain.state == TRexBrain.State.DEAD


## Any hit that did not come through a zone counts as a bone hit.
func take_damage(info: DamageInfo) -> void:
	take_zone_damage(info, TRexBrain.Zone.BONE)


func take_zone_damage(info: DamageInfo, zone: TRexBrain.Zone) -> void:
	if brain.state == TRexBrain.State.DEAD:
		return
	var multiplier := TRexBrain.damage_multiplier(zone, brain.state)
	if zone == TRexBrain.Zone.CRYSTAL and multiplier > 0.0:
		info.weak_point = true   # gold hit marker
		_crystal_hit_effects(info)
		if info.kind == DamageInfo.Kind.ELECTRIC and brain.stagger():
			_stagger_side = 1.0 if randf() < 0.5 else -1.0
	else:
		info.blocked = true   # grey hit marker: the bones shrug most of it off
		if not info.periodic:
			_bone_hit_effects(info)   # (a flare burning on a bone just burns)
	var amount := info.amount * multiplier
	if amount > 0.0:
		health.apply_damage(amount)
		brain.set_health_fraction(health.fraction())
	if health.is_dead():
		info.blocked = false   # a killing blow shows the kill marker, never grey
		_die(info)
		return
	if not info.periodic:
		_report_hit(info)


## One blast can hit ribs and crystal (two zones, two hits in one frame):
## the grey marker of the bones must not paint over the gold one.
func _report_hit(info: DamageInfo) -> void:
	var frame := Engine.get_process_frames()
	var shooter := info.source.get_instance_id() if is_instance_valid(info.source) else 0
	if info.weak_point:
		_gold_frame = frame
		_gold_source = shooter
	elif info.blocked and _gold_frame == frame and _gold_source == shooter:
		return
	Events.hit_landed.emit(self, info, false)


## Exhibits it summoned that are still alive.
func alive_summoned() -> int:
	if summoned.is_empty():
		return 0   # the usual case: no allocation every frame
	var alive: Array[Node] = []
	for node in summoned:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			alive.append(node)
	summoned = alive
	return summoned.size()


## True when the tail, moving from the joints [param before] to [param now]
## (see TRexSkeleton.tail_points()), swept through a guard standing at
## [param guard]: each bone's path between the two frames is a quad seen
## from above, grown by the bone's and the guard's radius, at a height that
## reaches him.
static func tail_swept(before: PackedVector3Array, now: PackedVector3Array, guard: Vector3) -> bool:
	var at := Vector2(guard.x, guard.z)
	for k in now.size() - 1:
		var corners: Array[Vector3] = [before[k], before[k + 1], now[k + 1], now[k]]
		var outline := PackedVector2Array()
		var low := INF
		var high := -INF
		for corner in corners:
			outline.append(Vector2(corner.x, corner.z))
			low = minf(low, corner.y)
			high = maxf(high, corner.y)
		var radius := TRexSkeleton.tail_radius(k)
		if low - radius - TAIL_CHEVRON > guard.y + GUARD_HEIGHT or high + radius < guard.y:
			continue   # over his head (near the base) or under his feet
		if Geometry2D.is_point_in_polygon(at, outline):
			return true
		for edge in 4:
			var closest := Geometry2D.get_closest_point_to_segment(at, outline[edge], outline[(edge + 1) % 4])
			if at.distance_to(closest) <= radius + GUARD_RADIUS:
				return true
	return false


func _physics_process(delta: float) -> void:
	if _death_time >= 0.0:
		_dying(delta)
		return
	# a guard in a haven is out of its reach: no target at all (it waits)
	var distance := INF
	var angle := 0.0
	if _target_alive() and not Haven.shelters(target.global_position):
		var to := target.global_position - global_position
		to.y = 0.0
		distance = to.length()
		angle = _bearing(to)
	brain.can_summon = alive_summoned() < MAX_SUMMONED
	brain.update(delta, distance, angle)
	var move := _steer(delta, distance, angle)
	velocity.x = move.x + _recoil.x
	velocity.z = move.z + _recoil.z
	_recoil = _recoil.move_toward(Vector3.ZERO, 8.0 * delta)
	if is_on_floor():
		_fall_speed = 0.0
	else:
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	var was_on_floor := is_on_floor()
	var before := global_position
	move_and_slide()
	_after_move(delta, before, move, was_on_floor)
	# asleep it holds the museum pose: posed once, then its 91 bones and 45
	# hit zones are left alone
	if brain.state != TRexBrain.State.DORMANT or not _posed_asleep:
		_pose(delta, angle)
		_posed_asleep = brain.state == TRexBrain.State.DORMANT
	if brain.is_whipping():
		_whip()


# --- movement -------------------------------------------------------------

func _steer(delta: float, distance: float, angle: float) -> Vector3:
	var forward := _forward()
	match brain.state:
		TRexBrain.State.WAKING:
			if brain.state_time() < WAKE_ROAR_TIME or is_inf(distance):
				return Vector3.ZERO
			_turn_by(angle, 1.6, delta)
			return forward * 3.0
		TRexBrain.State.STALK:
			if is_inf(distance):
				return Vector3.ZERO
			var desired := _desired_direction(delta)
			_turn_by(_bearing(desired), brain.turn_speed() * (1.8 if _detour_time > 0.0 else 1.0), delta)
			if _detour_time > 0.0:
				return desired * brain.walk_speed() * 0.7
			if distance < STOP_DISTANCE or _snout_at_wall(forward, distance):
				return Vector3.ZERO
			return forward * brain.walk_speed() * maxf(forward.dot(desired), 0.25)
		TRexBrain.State.CHARGE_WINDUP:
			if brain.is_tracking():
				_turn_by(angle, brain.turn_speed(), delta)
			return Vector3.ZERO
		TRexBrain.State.CHARGE:
			return _charge_dir * TRexBrain.CHARGE_SPEED
		TRexBrain.State.SKID:
			var slow := clampf(1.0 - brain.state_time() / 0.55, 0.0, 1.0)
			return _charge_dir * TRexBrain.CHARGE_SPEED * slow * slow
	return Vector3.ZERO


## Toward the guard, around whatever the feelers find in the way (checked
## every STEER_INTERVAL), or along a sidestep while one lasts.
func _desired_direction(delta: float) -> Vector3:
	if _detour_time > 0.0:
		_detour_time -= delta
		return _detour_dir
	_steer_timer -= delta
	if _steer_timer <= 0.0 or _steer_dir == Vector3.ZERO:
		_steer_timer = STEER_INTERVAL
		var to := target.global_position - global_position
		to.y = 0.0
		_steer_dir = _avoid(to.normalized(), to.length())
	return _steer_dir


## [param desired] turned aside as little as it takes for the feelers to
## find the way clear. Only geometry between the boss and the guard (who is
## [param distance] away) counts: a wall at his back is no obstacle.
func _avoid(desired: Vector3, distance: float) -> Vector3:
	var reach := minf(FEELER_LENGTH, distance - FEELER_START)
	if reach <= FEELER_MIN or _path_clear(desired, reach):
		return desired
	for step in [0.6, 1.1, 1.6, 2.1]:
		for side in [_detour_side, -_detour_side]:
			var dir := desired.rotated(Vector3.UP, step * side)
			if _path_clear(dir, reach):
				return dir
	return desired


## Three parallel feelers (centre and both flanks) find no level geometry
## within [param reach] along [param dir].
func _path_clear(dir: Vector3, reach: float) -> bool:
	var space := get_world_3d().direct_space_state
	var side := Vector3.UP.cross(dir).normalized() * FEELER_HALF_WIDTH
	for offset in [Vector3.ZERO, side, -side]:
		var from: Vector3 = global_position + Vector3.UP * FEELER_HEIGHT + offset + dir * FEELER_START
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Layers.WORLD | Layers.ENEMY_BLOCK)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


## True when the snout is about to touch a wall at the guard's back (or
## beyond him): walking on would only bump the skull into it, so it stands
## its ground and faces him. A wall between them does not count (the feelers
## steer around that).
func _snout_at_wall(forward: Vector3, distance: float) -> bool:
	var from := global_position + Vector3.UP * HEAD_COLLIDER.y + forward * FEELER_START
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * (SNOUT_REACH - FEELER_START), Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var to := (hit["position"] as Vector3) - global_position
	return Vector2(to.x, to.z).length() >= distance - GUARD_RADIUS


func _after_move(delta: float, before: Vector3, move: Vector3, was_on_floor: bool) -> void:
	match brain.state:
		TRexBrain.State.CHARGE:
			_check_charge_contact()
			_check_slam(before, delta)
		TRexBrain.State.STALK:
			_check_stuck(move, delta)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_walk_distance += moved
	var step := int(_walk_distance / STEP_LENGTH)
	if step != _last_step:
		_last_step = step
		_footstep(step % 2)
	if is_on_floor() and not was_on_floor and _fall_speed > 3.0:
		Sfx.play_at(&"trex_step", global_position, 2.0)
		Fx.impact(global_position + Vector3.UP * 0.2, Vector3.UP, -1, 2.5)
		_shake_near(0.5, 30.0)
		_fall_speed = 0.0


func _check_stuck(move: Vector3, delta: float) -> void:
	if move.length() < 0.5:
		_stuck_time = 0.0
		_stuck_from = global_position
		return
	_stuck_time += delta
	if _stuck_time < STUCK_TIME:
		return
	var progress := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	_stuck_time = 0.0
	_stuck_from = global_position
	if progress >= STUCK_PROGRESS:
		return
	_detour_side = -_detour_side
	_detour_dir = (_forward() * -0.35 + _forward().cross(Vector3.UP) * _detour_side).normalized()
	_detour_time = DETOUR_TIME


func _check_slam(before: Vector3, delta: float) -> void:
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()
		if absf(normal.y) < 0.7 and normal.dot(_charge_dir) < WALL_HIT_DOT:
			_slam(contact.get_position(), normal)
			return
	# wedged in a corner with no clear head-on contact
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if brain.state_time() > 0.15 and moved < TRexBrain.CHARGE_SPEED * delta * 0.2:
		_slam(global_position + _charge_dir * 2.0 + Vector3.UP * 2.0, -_charge_dir)


func _slam(point: Vector3, normal: Vector3) -> void:
	# a guard under the snout is crushed against the wall it rams
	_check_charge_contact(SNOUT_REACH)
	brain.hit_wall()
	_recoil = -_charge_dir * 4.0
	Fx.impact(point, normal, -1, 3.0)
	for i in 6:
		var fling := normal * randf_range(2.0, 4.0) + Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 4.0), randf_range(-2.0, 2.0))
		Fx.chunk(point + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 1.0), randf_range(-0.5, 0.5)), Color(0.55, 0.53, 0.5), randf_range(0.12, 0.25), fling)
	Sfx.play_at(&"trex_impact", point, 2.0)
	_shake_near(0.85, 35.0)
	Fx.hitstop(0.05)


## Runs the guard over once per charge when he is within [param reach] in
## front of the hips, in the body's lane.
func _check_charge_contact(reach: float = CHARGE_REACH) -> void:
	if _charge_hit or not _can_hurt_target():
		return
	var local := to_local(target.global_position)
	var ahead := -local.z
	# behind the hips he is out of the lane: the boss runs away from him
	if ahead < 0.0 or ahead > reach or absf(local.x) > CHARGE_HALF_WIDTH + GUARD_RADIUS:
		return
	if local.y < -1.0 or local.y > 4.5:
		return
	_charge_hit = true
	var side := signf(local.x) if absf(local.x) > 0.05 else _detour_side
	var info := DamageInfo.make(CHARGE_DAMAGE, DamageInfo.Kind.BLUNT, self)
	info.direction = (_charge_dir + global_basis.x * side * 1.2).normalized()
	info.knockback = CHARGE_KNOCKBACK
	info.position = target.global_position + Vector3.UP
	target.take_damage(info)
	Sfx.play_at(&"trex_impact", info.position, -4.0)
	_shake_near(0.6, 10.0)


# --- attacks and events ---------------------------------------------------

func _on_charge_started() -> void:
	_charge_dir = _forward()
	_charge_hit = false


## The swipe starts: the whip sweeps from where the windup left the tail.
func _on_tail_strike() -> void:
	Sfx.play_at(&"tail_whoosh", global_position - _forward() * 4.0 + Vector3.UP * 2.0)
	_tail_hit = false
	_tail_before = skeleton.tail_points()


## Every frame of the whip (after the pose): hits the guard once if the tail
## swept through him since the last frame.
func _whip() -> void:
	var now := skeleton.tail_points()
	var before := _tail_before if _tail_before.size() == now.size() else now
	_tail_before = now
	if _tail_hit or not _can_hurt_target():
		return
	if not tail_swept(before, now, target.global_position):
		return
	_tail_hit = true
	var away := target.global_position - global_position
	away.y = 0.0
	var info := DamageInfo.make(TAIL_DAMAGE, DamageInfo.Kind.BLUNT, self)
	info.direction = (away.normalized() + global_basis.x * _tail_side * 0.8).normalized()
	info.knockback = TAIL_KNOCKBACK
	info.position = target.global_position + Vector3.UP
	target.take_damage(info)
	Sfx.play_at(&"bone_hit", info.position)
	_shake_near(0.5, 10.0)


func _on_roar_peak(summons: bool, debris: bool) -> void:
	_shake_near(0.55, 40.0)
	if summons:
		_summon()
	if debris:
		_drop_debris()


func _summon() -> void:
	var count := mini(SUMMON_BATCH, MAX_SUMMONED - alive_summoned())
	if count <= 0 or not summon.is_valid():
		return
	var called: Variant = summon.call(count)
	if called is Array:
		for entry: Variant in called:
			# the summoner may hand back exhibits that already broke
			if typeof(entry) != TYPE_OBJECT or not is_instance_valid(entry):
				continue
			var node := entry as Node
			if node != null and not node.is_queued_for_deletion():
				summoned.append(node)


## Three shadows: under the guard and two a few metres around him.
func _drop_debris() -> void:
	if not _target_alive() or Haven.shelters(target.global_position):
		return
	var center := target.global_position
	var spots: Array[Vector3] = [center]
	var turn := randf() * TAU
	for i in 2:
		var angle := turn + PI * (0.75 + randf() * 0.5) * i
		spots.append(_debris_spot(center, angle, randf_range(DEBRIS_SPREAD.x, DEBRIS_SPREAD.y), spots))
	for spot in spots:
		get_parent().add_child(DebrisDrop.create(_floor_under(spot), target, self))


## A spot [param distance] from the guard at [param center], toward
## [param angle], on his side of any wall or railing (a metre short of it)
## and DEBRIS_GAP clear of the shadows already [param taken]. If a wall
## is in the way it turns until it finds such a spot, so near a wall or in
## a corner the shadows spread along the walls instead of piling onto the
## guard; failing that, the spot furthest from the others.
func _debris_spot(center: Vector3, angle: float, distance: float, taken: Array[Vector3]) -> Vector3:
	var space := get_world_3d().direct_space_state
	var eye := center + Vector3.UP * 0.5
	var best := center
	var best_gap := -1.0
	var steps := ceili(PI / DEBRIS_TURN) * 2
	for step in steps:
		var turn := ceili(step / 2.0) * DEBRIS_TURN * (1.0 if step % 2 == 1 else -1.0)
		var dir := Vector3(cos(angle + turn), 0.0, sin(angle + turn))
		var query := PhysicsRayQueryParameters3D.create(eye, eye + dir * (distance + 1.0), Layers.WORLD)
		var hit := space.intersect_ray(query)
		var room := distance if hit.is_empty() else clampf(eye.distance_to(hit["position"]) - 1.0, 0.0, distance)
		var spot := center + dir * room
		var gap := INF
		for other in taken:
			gap = minf(gap, Vector2(spot.x - other.x, spot.z - other.z).length())
		if room >= distance and gap >= DEBRIS_GAP:
			return spot
		if gap > best_gap:
			best_gap = gap
			best = spot
	return best


func _on_state_changed(from: TRexBrain.State, to: TRexBrain.State) -> void:
	# a charge runs through the guard (contact damage) instead of stopping at him
	collision_mask = Layers.WORLD | Layers.ENEMY_BLOCK
	if to != TRexBrain.State.CHARGE:
		collision_mask |= Layers.PLAYER
	var mouth := skeleton.head.global_position
	match to:
		TRexBrain.State.WAKING:
			Sfx.play_at(&"trex_roar", mouth, 3.0, 0.02)
			_shake_near(0.6, 40.0)
		TRexBrain.State.CHARGE_WINDUP:
			Sfx.play_at(&"trex_bellow", mouth, 2.0, 0.05)
			_scrape_timer = 0.0
		TRexBrain.State.STUNNED:
			_stagger_side = 1.0 if randf() < 0.5 else -1.0
			Sfx.play_at(&"bone_rattle", global_position + Vector3.UP * 2.5, 2.0)
		TRexBrain.State.TAIL_WINDUP:
			_tail_side = signf(to_local(target.global_position).x) if _target_alive() else 1.0
			if _tail_side == 0.0:
				_tail_side = 1.0
			Sfx.play_at(&"bone_rattle", global_position - _forward() * 3.0 + Vector3.UP * 2.5)
		TRexBrain.State.ROAR:
			Sfx.play_at(&"trex_roar", mouth, 3.0, 0.04)
		TRexBrain.State.STAGGER:
			Sfx.play_at(&"bone_rattle", global_position + Vector3.UP * 2.5, 2.0)
	state_changed.emit(from, to)


func _on_phase_changed(new_phase: int) -> void:
	phase_changed.emit(new_phase)


# --- damage feedback and death --------------------------------------------

func _bone_hit_effects(info: DamageInfo) -> void:
	var normal := info.normal if not info.normal.is_zero_approx() else -info.direction
	if not info.effects:
		Sfx.play_at(&"bone_hit", info.position, -2.0)
		return
	Fx.impact(info.position, normal, ExhibitMaterial.Kind.METAL, 0.5)
	Fx.impact(info.position, normal, ExhibitMaterial.Kind.MARBLE, 0.5)
	if randf() < 0.35:
		var fling := normal * 2.5 + Vector3(randf_range(-1.0, 1.0), randf_range(1.0, 2.5), randf_range(-1.0, 1.0))
		Fx.chunk(info.position, TRexSkeleton.BONE_COLOR, 0.07, fling)
	Sfx.play_at(&"bone_hit", info.position, -2.0)


func _crystal_hit_effects(info: DamageInfo) -> void:
	_crystal_flash = 1.0
	Sfx.play_at(&"crystal_hit", info.position)
	if not info.effects:
		return   # a gatling round between dressed ones: the glow and the sound only
	Fx.flash(info.position, Color(1.0, 0.2, 0.1), 2.5, 5.0, 0.1)
	var normal := info.normal if not info.normal.is_zero_approx() else -info.direction
	for i in 2:
		var fling := normal * 3.0 + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.5), randf_range(-1.5, 1.5))
		Fx.chunk(info.position, Color(0.9, 0.08, 0.06), 0.05, fling)


func _die(info: DamageInfo) -> void:
	brain.die()
	_death_time = 0.0
	collision_layer = 0
	collision_mask = Layers.WORLD
	velocity = Vector3.ZERO
	var at := skeleton.shatter_crystal()
	# shots pass through the trembling skeleton instead of vanishing in it
	skeleton.set_zones_enabled(false)
	Fx.flash(at, Color(1.0, 0.18, 0.1), 9.0, 16.0, 0.8)
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 3.0)
	for i in 14:
		var fling := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(3.0, 7.0)
		Fx.chunk(at, Color(0.9, 0.08, 0.06), randf_range(0.04, 0.1), fling)
	Sfx.play_at(&"crystal_shatter", at, 3.0, 0.0)
	Fx.hitstop(0.12)
	_shake_near(0.9, 60.0)
	Events.hit_landed.emit(self, info, true)
	defeated.emit()
	Events.boss_defeated.emit(self)


func _dying(delta: float) -> void:
	_death_time += delta
	var p := skeleton.pose
	p.reset()
	p.jaw = 1.0
	p.neck = 0.35
	p.arms = 1.0
	skeleton.tremble = minf(_death_time / DEATH_COLLAPSE_DELAY, 1.0)
	skeleton.stride = 0.0
	skeleton.animate(delta, 8.0)
	if _death_time >= DEATH_COLLAPSE_DELAY:
		remains = skeleton.collapse(get_parent())
		collapsed.emit(remains)
		Sfx.play_at(&"bone_collapse", global_position + Vector3.UP * 2.0, 3.0, 0.0)
		Fx.impact(global_position + Vector3.UP * 0.3, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 4.0)
		_shake_near(0.6, 40.0)
		queue_free()


# --- posture --------------------------------------------------------------

func _pose(delta: float, angle: float) -> void:
	var p := skeleton.pose
	p.reset()
	p.eyes = 0.0 if brain.state == TRexBrain.State.DORMANT else 1.0
	var t := brain.state_time()
	var sharpness := 6.0
	var speed := Vector2(velocity.x, velocity.z).length()
	skeleton.stride = clampf(speed / 3.5, 0.0, 1.6)
	skeleton.scrape = 0.0
	skeleton.walk_phase = _walk_distance / STEP_LENGTH * PI
	match brain.state:
		TRexBrain.State.WAKING:
			if t < WAKE_ROAR_TIME:
				p.neck = 0.5
				p.pitch = 0.06
				p.jaw = 1.0 if t > 0.15 and t < WAKE_ROAR_TIME - 0.2 else 0.2
				p.arms = 0.7
				p.glow = 1.0
		TRexBrain.State.STALK:
			p.neck = -0.05
			p.look = clampf(angle, -0.7, 0.7)
		TRexBrain.State.CHARGE_WINDUP:
			var wind := brain.windup_progress()
			p.neck = -0.55
			p.pitch = -0.12
			p.jaw = 0.35
			p.lift = 0.6
			p.glow = 0.4 + wind * 0.6
			skeleton.scrape = 1.0
			_scrape(delta)
		TRexBrain.State.CHARGE:
			p.neck = -0.6
			p.pitch = -0.16
			p.jaw = 0.5
			p.lift = 0.9
			p.glow = 0.6
		TRexBrain.State.SKID:
			p.neck = -0.3
			p.pitch = -0.08
			p.lift = 0.4
		TRexBrain.State.STUNNED:
			p.drop = 0.95
			p.pitch = -0.2
			p.roll = 0.08 * _stagger_side
			p.neck = -0.9
			p.look = 1.1 * _stagger_side   # the dazed head flops aside, off the chest
			p.crouch = 1.0
			p.ribs = 1.0
			p.exposure = 1.0
			p.jaw = 0.4
			p.lift = -0.8
			sharpness = 9.0
		TRexBrain.State.TAIL_WINDUP:
			p.curl = -_tail_side * 1.0
			p.twist = _tail_side * 0.25
			p.look = clampf(angle, -1.2, 1.2)
			p.lift = 0.5
			p.glow = brain.windup_progress() * 0.6
		TRexBrain.State.TAIL_SWIPE:
			# the whip comes down to the guard's height as it sweeps through
			var sweeping := t < TRexBrain.TAIL_SWIPE_TIME * 0.6
			p.curl = _tail_side * 1.4 if sweeping else 0.0
			p.twist = -_tail_side * 0.3 if sweeping else 0.0
			p.lift = -2.3 if sweeping else 0.0
			sharpness = 16.0
		TRexBrain.State.ROAR:
			p.neck = 0.55
			p.pitch = 0.08
			p.jaw = 1.0 if t > 0.12 and t < TRexBrain.ROAR_TIME - 0.3 else 0.2
			p.arms = 0.8
			p.glow = 1.0
		TRexBrain.State.STAGGER:
			p.roll = 0.22 * _stagger_side
			p.drop = 0.35
			p.neck = -0.35
			p.jaw = 0.6
			p.crouch = 0.35
			p.glow = 1.0
			sharpness = 12.0
	_crystal_flash = move_toward(_crystal_flash, 0.0, 6.0 * delta)
	p.glow = minf(p.glow + _crystal_flash, 1.5)
	skeleton.animate(delta, sharpness)
	if skeleton.crystal_present and skeleton.beat_count() != _last_beat:
		_last_beat = skeleton.beat_count()
		if _target_alive() and target.global_position.distance_to(global_position) < 25.0:
			Sfx.play_at(&"crystal_pulse", skeleton.crystal_position(), -8.0, 0.0)


## Paw scrape of the charge telegraph: dust and scraping at the right foot.
func _scrape(delta: float) -> void:
	_scrape_timer -= delta
	if _scrape_timer > 0.0:
		return
	_scrape_timer = 0.28
	var foot: Node3D = skeleton.legs[1][3]
	var at := Vector3(foot.global_position.x, global_position.y + 0.1, foot.global_position.z)
	Fx.impact(at, Vector3.UP, -1, 1.4)
	Sfx.play_at(&"trex_scrape", at, -2.0)


func _footstep(foot: int) -> void:
	var leg: Array = skeleton.legs[foot]
	var toes: Node3D = leg[3]
	var at := Vector3(toes.global_position.x, global_position.y + 0.1, toes.global_position.z)
	var charging := brain.state == TRexBrain.State.CHARGE
	Sfx.play_at(&"trex_step", at, 0.0 if charging else -3.0)
	Fx.impact(at, Vector3.UP, -1, 1.2 if charging else 0.7)
	_shake_near(0.2 if charging else 0.12, 25.0)


# --- helpers --------------------------------------------------------------

func _add_colliders() -> void:
	var legs := CollisionShape3D.new()
	legs.shape = _capsule(0.9, 3.3)
	legs.position = Vector3(0.0, 1.65, 0.0)
	add_child(legs)
	var torso := CollisionShape3D.new()
	torso.shape = _capsule(1.0, 4.6)
	torso.position = Vector3(0.0, 3.05, -1.3)
	torso.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(torso)
	var head_shape := SphereShape3D.new()
	head_shape.radius = HEAD_RADIUS
	var head := CollisionShape3D.new()
	head.shape = head_shape
	head.position = HEAD_COLLIDER
	add_child(head)


func _forward() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Signed bearing of the world direction [param to] from the facing (+ = to
## the left), whatever the parent's turn.
func _bearing(to: Vector3) -> float:
	var forward := _forward()
	return wrapf(atan2(-to.x, -to.z) - atan2(-forward.x, -forward.z), -PI, PI)


func _turn_by(angle: float, speed: float, delta: float) -> void:
	rotation.y = wrapf(rotation.y + clampf(angle, -speed * delta, speed * delta), -PI, PI)


func _target_alive() -> bool:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
		if target == null:
			return false
	var guard := target as Player
	return guard == null or guard.alive


## The guard is alive, can be hurt and is not sheltered in a haven.
func _can_hurt_target() -> bool:
	return _target_alive() and target.has_method(&"take_damage") and not Haven.shelters(target.global_position)


func _floor_under(point: Vector3) -> Vector3:
	var from := point + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point


## Camera shake for a guard within [param reach] metres, fading with distance.
func _shake_near(trauma: float, reach: float) -> void:
	if not _target_alive() or not target is Player:
		return
	var distance := target.global_position.distance_to(global_position)
	if distance < reach:
		Events.shake_requested.emit(trauma * (1.0 - distance / reach))


static func _capsule(radius: float, height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape
