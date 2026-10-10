class_name Enemy
extends CharacterBody3D
## Base class for awakened exhibits. Subclasses set their numbers in
## _configure() and build collider, meshes and hurtboxes in _build_body().
## The base handles perception, hunting, telegraphed melee strikes, stun,
## blocking, knockback, damage, material effects and destruction.
## Perception (design pietro-1-projekt 7.2; numbers in PerceptionRules, the
## level's light, rooms and doors in PerceptionWorld):
## - sight: a cone in front ([member sight_cone_deg]) plus a close sense all
##   around ([member close_sense]); its reach follows how lit the guard is
##   (lit [member sight_range], half-dark and dark less; a flashlight always
##   counts as lit), a sleeping exhibit sees at DORMANT_SCALE of it; a ray
##   to the guard's chest; checked every SIGHT_INTERVAL, sleeping exhibits
##   far from the guard less often,
## - hearing: PerceptionWorld calls hear() for noises that reach it,
## - home ([member home_room], [member territory], [member leash]): beyond
##   them it goes back; [member summoned] exhibits have no bounds and always
##   know where the guard is,
## - waking up by its own senses it rouses at most CHAIN_MAX sleeping
##   neighbours in its room (in sight, within [member wake_radius]); they
##   come to look, quietly,
## - EnemyBrain decides, the body walks where the state says.

const GRAVITY := 15.0
## How fast knockback and leaps die down on the ground (m/s per second).
const GROUND_FRICTION := 30.0
## Seconds between sight checks (spread over the exhibits); a sleeping
## exhibit farther than FAR_DISTANCE from the guard looks every
## FAR_SIGHT_INTERVAL.
const SIGHT_INTERVAL := 0.2
const FAR_SIGHT_INTERVAL := 0.6
const FAR_DISTANCE := 32.0
## The exhibit's room is looked up again after it moved this far (m).
const ROOM_REFRESH := 0.5
## Sleeping soundly (night 1's first rooms) it notices the guard only this
## close (m): he has to bump into it.
const SOUND_SLEEP_SENSE := 1.0
## Sound levels (dB) of the suspicion and the call-out.
const SUSPICION_DB := -8.0
const NOTICE_DB := -4.0
## Seconds between navigation path updates while chasing.
const REPATH_INTERVAL := 0.25
## A chaser averaging less than this (m/s) over STUCK_TIME seconds is stuck
## (a ledge, a corner, a crowd) and steps DETOUR_STEP metres sideways.
const STUCK_SPEED := 0.3
const STUCK_TIME := 0.75
const DETOUR_STEP := 1.0
## Longest a sidestep may take before the chase goes on regardless.
const DETOUR_TIME := 0.75
## Below this height an exhibit has fallen out of the level and is removed
## (the level in the scene may set its own, see Level.kill_plane()).
const KILL_PLANE_Y := Level.DEFAULT_KILL_PLANE
const MAX_FALL_SPEED := 30.0
## On a navmesh a sidestep target is snapped onto it and dropped when the
## snap moves it further than this (a ledge, a wall): never step off.
const DETOUR_SNAP_FLAT := 0.3
const DETOUR_SNAP_HEIGHT := 0.5
## The path must end this close to the goal (flat) for the target to be
## reachable, and within REACH_HEIGHT of its height.
const REACH_TOLERANCE := 1.0
const REACH_HEIGHT := 1.0
## A melee fighter this close (m) to its target, on the attack ring, is
## where it should be: no stuck-sidesteps while it waits its turn.
const RING_CALM := 3.5
## Exhibits whose attack range is at most this fight in melee and take a
## place on the ring around their target (EnemyCrowd).
const RING_MAX_RANGE := 2.5

@export var max_health: float = 60.0
@export var move_speed: float = 2.5
## Radians per second.
@export var turn_speed: float = 8.0
## How far it sees a lit guard in its cone (m); half-dark and dark scale
## from it (PerceptionRules.sight_range).
@export var sight_range: float = PerceptionRules.LIT_RANGE
## Full angle of its sight cone (degrees).
@export var sight_cone_deg: float = PerceptionRules.CONE_DEG
## It notices the guard all around within this (m).
@export var close_sense: float = PerceptionRules.CLOSE_SENSE
## Farthest it follows from home (m, floor plan).
@export var leash: float = PerceptionRules.LEASH
@export var eye_height: float = 1.5
@export var attack_damage: float = 10.0
@export var attack_reach: float = 1.9
## 0 = full knockback, 1 = immovable.
@export var knockback_resist: float = 0.0
## Sleeping neighbours within this (m) wake with it (chain waking).
@export var wake_radius: float = PerceptionRules.CHAIN_RADIUS
@export var marker_height: float = 2.0
@export var material_kind: ExhibitMaterial.Kind = ExhibitMaterial.Kind.WAX
@export var notice_sound: StringName = &"notice"
## What a hit stopped by its shield sounds like.
@export var block_sound: StringName = &"block"
## Dust this exhibit leaves when destroyed (before finisher and night bonuses).
@export var dust_value: int = 0
## How far the whole body leans back at the top of an attack's windup and
## forward after the strike (rad; an overhead chop leans a lot, a spear
## thrust hardly at all).
var windup_lean: float = 0.35
var strike_lean: float = -0.45

var brain := EnemyBrain.new()
var health: Health
## Who this exhibit hunts. Defaults to the node in group "player".
var target: Node3D = null
## Parent of all body meshes; leans during attacks.
var visual: Node3D
## The animated model under [member visual] (null = greybox meshes).
var rig: ExhibitRig = null
var nav: NavigationAgent3D
## Where this exhibit appeared (its post) and which way it faced there.
var home := Vector3.ZERO
var home_yaw: float = 0.0
## The room it belongs to (&"" = the room of its post, if the level has rooms).
var home_room: StringName = &""
## Rooms it may go to; empty = its home room and the rooms next door.
var territory: Array[StringName] = []
## Its patrol loop (set before it enters the tree); empty = it keeps its post.
var patrol_route := PackedVector3Array()
## Awake at the start of the night: it patrols (or stands guard) instead of
## sleeping. Set before it enters the tree.
var starts_awake := false
## Seconds it still sleeps soundly (the first minutes of night 1 on the way
## out of the booth): asleep it does not see the guard, only feels him
## within SOUND_SLEEP_SENSE; noise, hits and neighbours wake it as ever.
var sound_asleep: float = 0.0
## Called in by the boss (or an arena wave): it hunts at once, always knows
## where the guard is, has no bounds and ignores the hunter cap.
var summoned := false:
	set(value):
		summoned = value
		if value and brain != null:
			brain.relentless = true

var _external := Vector3.ZERO
var _sees_target := false
var _sight_timer: float = 0.0
var _repath_timer: float = 0.0
var _stuck_time: float = 0.0
var _stuck_from := Vector3.ZERO
var _detour := Vector3.ZERO
var _detour_time: float = 0.0
## Which way the next sidestep goes (+1 / -1); alternates.
var _detour_side: float = 1.0
var _stun_marker: MeshInstance3D
var _flash_materials: Array[StandardMaterial3D] = []
var _glow: float = 0.0
## Its room now (looked up again after it moved ROOM_REFRESH metres).
var _room: StringName = &""
var _room_from := Vector3.INF
var _room_known := false
## Its territory rooms (worked out on the first look).
var _bounds_rooms: Array[StringName] = []
var _bounds_ready := false
var _out_of_bounds := false
## Per-exhibit repath interval, so a crowd does not repath in lockstep.
var _repath_interval: float = REPATH_INTERVAL
## False while the navmesh cannot bring this exhibit to its goal (the path
## ends far from it: a guard on a ledge, off the exhibits' layer...).
var _target_reachable := true
## The current goal is a place on the attack ring (not the target itself).
var _ring_goal := false
## That ring place lies off the walkable floor (a wall, a ledge): until the
## next repath, head for the target itself.
var _ring_off_floor := false
var _nav_iteration: int = -1
var _nav_has_regions := false
## Dawn turned it to stone: it neither moves nor takes hits.
var _frozen := false

## The grey of an exhibit frozen at dawn.
static var _stone: StandardMaterial3D = null


func _init() -> void:
	_configure()


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY | Layers.ENEMY_BLOCK
	health = Health.new()
	health.max_health = max_health
	add_child(health)
	nav = NavigationAgent3D.new()
	nav.radius = 0.5
	nav.navigation_layers = LevelNavigation.WALK_LAYER   # never the havens' layer
	nav.path_desired_distance = 0.35
	nav.target_desired_distance = 0.8
	# the server's default search (4096 polygons) is less than Floor I has:
	# an exhibit sent home from far off (fallen into a pit, pushed out of
	# its wing) would stop half way
	nav.path_search_max_polygons = LevelNavigation.AGENT_SEARCH_POLYGONS
	add_child(nav)
	visual = Node3D.new()
	add_child(visual)
	_build_body()
	_stun_marker = _make_stun_marker()
	add_child(_stun_marker)
	brain.strike.connect(_on_strike)
	brain.state_changed.connect(_on_state_changed)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	# spread the periodic checks of a group over different frames
	_sight_timer = randf() * SIGHT_INTERVAL
	_repath_interval = REPATH_INTERVAL * randf_range(0.8, 1.2)
	_repath_timer = randf() * _repath_interval
	_detour_side = 1.0 if randf() < 0.5 else -1.0
	home = global_position
	home_yaw = _world_yaw()
	brain.home = home
	brain.patrol = patrol_route
	if summoned:
		brain.relentless = true
	if starts_awake:
		brain.start_patrol()


func _enter_tree() -> void:
	EnemyCrowd.join(self)
	PerceptionWorld.join(self)


func _exit_tree() -> void:
	EnemyCrowd.leave(self)
	PerceptionWorld.leave(self)


## Subclass hook: set stats and brain timings (brain.attack_range etc.).
## Runs in _init(), so a spawner can still override stats before add_child().
func _configure() -> void:
	pass


## Subclass hook: add a collider, meshes (under [member visual]) and hurtboxes.
func _build_body() -> void:
	pass


## Subclass hook: extra reaction to a hit that got through.
func _on_damaged(_info: DamageInfo) -> void:
	pass


## Subclass hook: true when this hit is stopped (e.g. by a shield).
func _blocks(_info: DamageInfo) -> bool:
	return false


## Subclass hook: true for exhibits that attack from afar (a bust): they
## may strike at a target the navmesh cannot bring them to.
func _attacks_from_range() -> bool:
	return false


## Subclass hook: false while it may start no attack (a mummy climbing out
## of its sarcophagus or running in panic); the brain then sees no target
## in reach.
func _may_attack() -> bool:
	return true


## Subclass hook: vertical motion. Walkers fall (never faster than
## MAX_FALL_SPEED); hovering exhibits override it and call super() when
## they drop.
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)


## A tick of damage over time (DamageInfo.periodic) only hurts: no hit
## marker, no clank on a shield (a burn that does not get through just
## does nothing), no hit sound; the tick that destroys the exhibit is
## reported like any kill.
func take_damage(info: DamageInfo) -> void:
	if brain.state == EnemyBrain.State.DESTROYED or _frozen:
		return
	if _blocks(info):
		if info.periodic:
			return
		info.blocked = true
		Fx.impact(info.position, -info.direction, ExhibitMaterial.Kind.METAL, 1.5)
		Sfx.play_at(block_sound, info.position)
		_alarm(info)
		Events.hit_landed.emit(self, info, false)
		return
	var finisher := info.can_finish and brain.is_stunned()
	var amount := health.current if finisher else info.amount
	var overkill := maxf(amount - health.current, 0.0)
	health.apply_damage(amount)
	_external += _push(info)
	if info.effects:
		Fx.impact(info.position, info.normal, material_kind, clampf(info.amount / 15.0, 0.5, 3.0))
	if not info.periodic:
		Sfx.play_at(ExhibitMaterial.hit_sound(material_kind), info.position)
	_on_damaged(info)
	if health.is_dead():
		_destroy(info, finisher, overkill)
		return
	if info.stun_time > 0.0:
		brain.stun(info.stun_time)
	else:
		_alarm(info)
	if not info.periodic:
		Events.hit_landed.emit(self, info, false)


## Dawn: stops dead mid-step and greys over like stone (for good).
func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	set_physics_process(false)
	if rig != null:
		rig.set_physics_process(false)   # the model stops mid-pose too
	velocity = Vector3.ZERO
	_stun_marker.visible = false
	EnemyCrowd.release(self)
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.albedo_color = Color(0.46, 0.46, 0.47)
		_stone.roughness = 0.95
	for node in visual.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = _stone


func is_frozen() -> bool:
	return _frozen


## Instantly turns to face a point (used when spawning: it becomes the way
## it faces at its post). Works in world space, under a turned parent too.
func face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		_set_world_yaw(atan2(-to.x, -to.z))
		home_yaw = _world_yaw()
		reset_physics_interpolation()


## A hit tells it where the guard is (the hit's source, else its target).
func _alarm(info: DamageInfo) -> void:
	var from := global_position
	var source := info.source as Node3D
	if source != null and is_instance_valid(source) and source.is_inside_tree():
		from = source.global_position
	elif _target_alive():
		from = target.global_position
	brain.alarm(from)


## A noise at [param point] (in [param point_room]) reached this exhibit:
## it turns, and goes to look when the point lies within its bounds.
## True when it is awake now (it reacted).
func hear(point: Vector3, point_room: StringName = &"") -> bool:
	if brain.state == EnemyBrain.State.DESTROYED or _frozen:
		return false
	_refresh_bounds()
	brain.hear(point, _within_bounds(point, point_room))
	return brain.state != EnemyBrain.State.DORMANT


## A neighbour woke up next to it: it comes to look at [param point],
## quietly (no call-out, it wakes nobody). True when it woke.
func rouse(point: Vector3) -> bool:
	if brain.state != EnemyBrain.State.DORMANT or _frozen:
		return false
	brain.quiet = true
	hear(point, PerceptionWorld.room_at(point))
	if brain.state == EnemyBrain.State.DORMANT:
		brain.quiet = false
		return false
	return true


## The room it stands in now (&"" without rooms).
func current_room() -> StringName:
	if not _room_known or global_position.distance_squared_to(_room_from) > ROOM_REFRESH * ROOM_REFRESH:
		_room_known = true
		_room_from = global_position
		_room = PerceptionWorld.room_at(global_position)
	return _room


## The rooms it may go to (its territory, worked out once).
func bounds_rooms() -> Array[StringName]:
	_refresh_bounds()
	return _bounds_rooms


## Counts toward the hunter cap (a portrait on its wall does not).
func counts_as_hunter() -> bool:
	return true


## How far it sees the guard right now: his light, the difficulty, and
## whether it sleeps.
func sight_reach() -> float:
	var light := PerceptionWorld.guard_light(target) if _target_alive() else 1.0
	var reach := PerceptionRules.sight_range(light, sight_range) * PerceptionWorld.sight_scale
	if brain.state == EnemyBrain.State.DORMANT:
		reach *= PerceptionRules.DORMANT_SCALE
	return reach


## How bright its eyes glow (the rig's "awake" shading): 0 asleep, flaring
## while suspicious, 1 otherwise.
func eye_glow() -> float:
	match brain.state:
		EnemyBrain.State.DORMANT:
			return 0.0
		EnemyBrain.State.SUSPICIOUS:
			return 2.0
	return 1.0


func _physics_process(delta: float) -> void:
	if brain.state == EnemyBrain.State.DESTROYED:
		return
	if _below_kill_plane():
		return
	if sound_asleep > 0.0:
		sound_asleep -= delta
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = _sight_interval()
		_look()
	var has_target := _target_alive()
	# a guard inside a haven is out of reach: no sight, no attacks
	var sheltered := has_target and Haven.shelters(target.global_position)
	_sees_target = _sees_target and has_target and not sheltered
	# attacks only start against a target in plain view (not through floors)
	var distance := global_position.distance_to(target.global_position) if _sees_target else INF
	if not _target_reachable and distance > attack_reach and not _attacks_from_range():
		distance = INF   # no leaping at a guard the navmesh cannot reach (a ledge)
	if not _may_attack():
		distance = INF   # busy (climbing out of its tomb, panicking): no attack starts
	_brief_brain(has_target, sheltered)
	brain.update(delta, _sees_target, distance)
	var move := _steer(delta, has_target)
	_apply_gravity(delta)
	velocity.x = move.x + _external.x
	velocity.z = move.z + _external.z
	var friction := GROUND_FRICTION if is_on_floor() else 1.0
	_external = _external.move_toward(Vector3.ZERO, friction * delta)
	if resting():
		velocity = Vector3.ZERO   # a museum piece on its floor: nothing to slide
	else:
		move_and_slide()
	_check_stuck(move, delta)
	_update_visuals(delta)


## What the brain needs to know this frame (see EnemyBrain's context).
func _brief_brain(has_target: bool, sheltered: bool) -> void:
	brain.position = global_position
	brain.guard_sheltered = sheltered
	brain.out_of_bounds = _out_of_bounds
	brain.may_hunt = true
	brain.guard_in_bounds = true
	if not has_target:
		return
	brain.guard = target.global_position
	if not brain.is_hunting() and (_sees_target or brain.spotted()):
		brain.may_hunt = PerceptionWorld.may_hunt(self)
	if _sees_target:
		brain.guard_in_bounds = _within_bounds(target.global_position, PerceptionWorld.guard_room(target))


## Where the body goes this frame (and which way it turns), by state.
func _steer(delta: float, has_target: bool) -> Vector3:
	var move := Vector3.ZERO
	match brain.state:
		EnemyBrain.State.HUNT:
			if has_target and brain.knows_guard():
				var goal := target.global_position
				if _uses_attack_ring():
					goal = EnemyCrowd.chase_goal(self, target, true, brain.attack_range, _sees_target)
				_ring_goal = not goal.is_equal_approx(target.global_position)
				move = _chase_direction(delta, goal) * move_speed + EnemyCrowd.push_for(self)
				_face_towards(target.global_position, delta)
			else:
				move = _walk_to(delta, brain.last_known, 1.0)
		EnemyBrain.State.INVESTIGATE, EnemyBrain.State.SEARCH, EnemyBrain.State.RETURN, EnemyBrain.State.PATROL:
			if brain.walking():
				move = _walk_to(delta, brain.goal, brain.pace())
			else:
				_ring_goal = false
				EnemyCrowd.release(self)
				if brain.settling() or (brain.state == EnemyBrain.State.PATROL and brain.patrol.size() < 2):
					_turn_to_yaw(home_yaw, delta)   # back at its post, the way it stood
				elif brain.state == EnemyBrain.State.INVESTIGATE:
					_face_towards(brain.last_known, delta)   # waiting at the edge, watching him
				elif brain.state == EnemyBrain.State.SEARCH:
					_face_towards(brain.goal, delta)
		EnemyBrain.State.SUSPICIOUS:
			_face_towards(brain.last_known, delta)
		EnemyBrain.State.ATTACK:
			if has_target and not brain.has_struck():
				_face_towards(target.global_position, delta * 0.5)
	return move


## Walks toward [param point] at [param pace] of its speed (not on the
## attack ring), looking where it goes.
func _walk_to(delta: float, point: Vector3, pace: float) -> Vector3:
	_ring_goal = false
	EnemyCrowd.release(self)
	if Vector2(point.x - global_position.x, point.z - global_position.z).length() < 0.6:
		return Vector3.ZERO
	var direction := _chase_direction(delta, point)
	if direction.is_zero_approx():
		return Vector3.ZERO
	_face_towards(global_position + direction, delta)
	return direction * move_speed * pace + EnemyCrowd.push_for(self)


## True for a sleeping exhibit standing still on its floor: its physics
## step is skipped (only its eyes keep watching). Anything that moves it
## (a hit, waking up) ends the rest.
func resting() -> bool:
	return brain.state == EnemyBrain.State.DORMANT and is_on_floor() and _external.is_zero_approx() \
			and absf(velocity.x) < 0.001 and absf(velocity.z) < 0.001


func _update_visuals(delta: float) -> void:
	var lean := 0.0
	if brain.state == EnemyBrain.State.ATTACK:
		lean = strike_lean if brain.has_struck() else windup_lean * brain.windup_progress()
	visual.rotation.x = lerpf(visual.rotation.x, lean, 1.0 - exp(-14.0 * delta))
	var glow := brain.windup_progress()
	if glow != _glow:
		_glow = glow
		for material in _flash_materials:
			material.emission_energy_multiplier = glow * glow * 2.5
	if _stun_marker.visible:
		_stun_marker.rotate_y(6.0 * delta)


func _on_strike() -> void:
	if not _target_alive():
		return
	Sfx.play_at(&"swing", global_position)
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var facing := -global_transform.basis.z
	if to.length() <= attack_reach and facing.dot(flat.normalized()) > 0.3 and _has_line_of_sight():
		_deal_damage()


## Hits the target with this exhibit's attack (no range checks).
func _deal_damage() -> void:
	if not is_instance_valid(target) or not target.has_method(&"take_damage"):
		return
	if Haven.shelters(target.global_position):
		return   # the guard made it to safety in time
	var to := target.global_position - global_position
	to.y = 0.0
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	info.direction = to.normalized() if to.length() > 0.01 else -global_transform.basis.z
	info.knockback = 5.0
	info.position = global_position + Vector3.UP * eye_height
	target.take_damage(info)


## Sounds and neighbours: waking up by its own senses it calls out (the
## guard seen: its notice sound; only a noise: the suspicion sound) and
## rouses sleeping neighbours; finding the guard again later it calls out.
## Woken by a neighbour it stays quiet until it rests again.
func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	_stun_marker.visible = to == EnemyBrain.State.STUNNED
	_repath_timer = 0.0   # a new goal: plan at once
	if to == EnemyBrain.State.DESTROYED or brain.quiet:
		return
	var resting_before := from == EnemyBrain.State.DORMANT or from == EnemyBrain.State.PATROL
	if to == EnemyBrain.State.SUSPICIOUS and resting_before:
		if brain.spotted():
			Sfx.play_at(notice_sound, global_position, NOTICE_DB)
		else:
			Sfx.play_at(&"suspicion", global_position + Vector3.UP * eye_height, SUSPICION_DB)
		if from == EnemyBrain.State.DORMANT:
			_rouse_neighbours()
	elif to == EnemyBrain.State.HUNT and (from == EnemyBrain.State.INVESTIGATE or from == EnemyBrain.State.SEARCH or from == EnemyBrain.State.RETURN):
		Sfx.play_at(notice_sound, global_position, NOTICE_DB)


## Rouses up to CHAIN_MAX sleeping exhibits within [member wake_radius] in
## its room that it can see (not through walls or floors), nearest first.
## They come to look where it looked, quietly.
func _rouse_neighbours() -> void:
	if wake_radius <= 0.0:
		return
	var room := current_room()
	var near: Array = []
	for other in PerceptionWorld.exhibits():
		if other == self or other.brain.state != EnemyBrain.State.DORMANT or not other.is_inside_tree():
			continue
		var distance := other.global_position.distance_to(global_position)
		if distance > wake_radius:
			continue
		var other_room := other.current_room()
		if room != &"" and other_room != &"" and other_room != room:
			continue
		near.append([distance, other])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var eye := global_position + Vector3.UP * eye_height
	var woken := 0
	for entry: Array in near:
		if woken >= PerceptionRules.CHAIN_MAX:
			break
		var other: Enemy = entry[1]
		if _clear_line(eye, other.global_position + Vector3.UP * other.eye_height) and other.rouse(brain.last_known):
			woken += 1


func _destroy(info: DamageInfo, finisher: bool, overkill: float) -> void:
	brain.destroy()
	var plan := GibPlanner.plan(material_kind, overkill, max_health, finisher)
	var center := global_position + Vector3.UP * (eye_height * 0.6)
	if rig != null:
		rig.shatter(center, plan, info.direction)   # the model's own parts fly
	else:
		Fx.shatter(center, material_kind, plan, info.direction)
	Sfx.play_at(ExhibitMaterial.break_sound(material_kind), center)
	if plan.gibbed:
		Fx.hitstop(0.06)
		Events.shake_requested.emit(0.25)
	Events.hit_landed.emit(self, info, true)
	Events.enemy_destroyed.emit(self, info, finisher)
	queue_free()


func _push(info: DamageInfo) -> Vector3:
	var flat := Vector3(info.direction.x, 0.0, info.direction.z)
	if info.knockback <= 0.0 or flat.length_squared() < 0.0001:
		return Vector3.ZERO
	return flat.normalized() * info.knockback * (1.0 - knockback_resist)


## Periodic perception: finds the guard again if the target is gone,
## updates its room and bounds, then checks its sight.
func _look() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	_refresh_bounds()
	var started := Time.get_ticks_usec() if PerceptionWorld.profiling else 0
	_sees_target = _target_alive() and _can_see_target()
	PerceptionWorld.stats["looks"] = int(PerceptionWorld.stats["looks"]) + 1
	if PerceptionWorld.profiling:
		PerceptionWorld.stats["look_usec"] = int(PerceptionWorld.stats["look_usec"]) + Time.get_ticks_usec() - started


## Range (by light), cone or close sense, then the ray.
func _can_see_target() -> bool:
	var to := target.global_position - global_position
	if sound_asleep > 0.0 and brain.state == EnemyBrain.State.DORMANT:
		return to.length() <= SOUND_SLEEP_SENSE and _has_line_of_sight()
	var reach := sight_reach()
	if to.length_squared() > reach * reach:
		return false
	var close := close_sense * (PerceptionRules.DORMANT_SCALE if brain.state == EnemyBrain.State.DORMANT else 1.0)
	if not PerceptionRules.sees(-global_transform.basis.z, to, sight_cone_deg, reach, close):
		return false
	PerceptionWorld.stats["rays"] = int(PerceptionWorld.stats["rays"]) + 1
	return _has_line_of_sight()


## Sleeping exhibits far from the guard look less often.
func _sight_interval() -> float:
	if brain.state == EnemyBrain.State.DORMANT and _target_alive() \
			and global_position.distance_squared_to(target.global_position) > FAR_DISTANCE * FAR_DISTANCE:
		return FAR_SIGHT_INTERVAL
	return SIGHT_INTERVAL


## Its room, territory (once) and whether it stands out of bounds now.
func _refresh_bounds() -> void:
	if not _bounds_ready:
		_bounds_ready = true
		if home_room == &"":
			home_room = PerceptionWorld.room_at(home)
		_bounds_rooms = PerceptionWorld.territory_of(home_room, territory)
	_out_of_bounds = not summoned and PerceptionRules.out_of_bounds(global_position, home, leash, current_room(), _bounds_rooms)


## True when [param point] (in [param point_room]) lies where it may go.
func _within_bounds(point: Vector3, point_room: StringName) -> bool:
	return summoned or not PerceptionRules.out_of_bounds(point, home, leash, point_room, _bounds_rooms)


## The target exists and is still standing (a dead guard is left alone).
func _target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	var guard := target as Player
	return guard == null or guard.alive


func _has_line_of_sight() -> bool:
	return _clear_line(global_position + Vector3.UP * eye_height, target.global_position + Vector3.UP * 1.4)


## True when no level geometry lies between the two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Direction of travel toward [param goal] (the target, a point to look
## at, home).
func _chase_direction(delta: float, goal: Vector3) -> Vector3:
	if _detour_time > 0.0:
		_detour_time -= delta
		var aside := _detour - global_position
		aside.y = 0.0
		if _detour_time > 0.0 and aside.length() > 0.2:
			return aside.normalized()
		_detour_time = 0.0
		_repath_timer = 0.0   # plan a fresh path from the new spot
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0:
		_refresh_path(delta, goal)
		if _ring_goal and _ring_off_floor and _target_alive():
			goal = target.global_position   # that ring place lies off the floor (a wall, a ledge)
		if not nav.is_navigation_finished():
			var step := nav.get_next_path_position() - global_position
			step.y = 0.0
			if step.length() > 0.05:
				return step.normalized()
		if _map_has_regions() and not _target_reachable:
			return Vector3.ZERO   # the path ends short of the target: hold, never walk off the navmesh
		# path done and the goal on the navmesh: cover the last stretch straight
	var straight := goal - global_position
	straight.y = 0.0
	return straight.normalized() if straight.length() > 0.05 else Vector3.ZERO


## Plans the path to [param goal] again every repath interval and keeps
## [member _target_reachable] up to date (also for exhibits that move on
## their own between plans, like the bust).
func _refresh_path(delta: float, goal: Vector3) -> void:
	_repath_timer -= delta
	if _repath_timer > 0.0:
		return
	_repath_timer = _repath_interval
	_ring_off_floor = _ring_goal and _map_has_regions() and _walk_closest_point(goal).distance_to(goal) > 0.6
	if _ring_off_floor and _target_alive():
		goal = target.global_position
	nav.target_position = goal
	_target_reachable = not _map_has_regions() or _path_reaches(goal)


## True when the planned path ends at [param goal]: close on the floor plan
## and at about its height (a hovering bust's path is lifted by its
## path_height_offset, which is taken off again here).
func _path_reaches(goal: Vector3) -> bool:
	var end := nav.get_final_position()
	var flat := Vector2(end.x - goal.x, end.z - goal.z).length()
	var rise := absf(end.y + nav.path_height_offset - goal.y)
	return flat <= REACH_TOLERANCE and rise <= REACH_HEIGHT


## Stuck fallback: a walker (hunting, investigating, searching, going home,
## patrolling) that makes almost no headway for a while (also when it
## jitters back and forth) steps about a metre sideways, alternating sides,
## then plans its path again. Not a melee fighter waiting on the ring
## close to its target: shuffling there is the crowd, not being stuck.
func _check_stuck(move: Vector3, delta: float) -> void:
	if brain.state != EnemyBrain.State.HUNT and not (brain.is_active() and brain.walking()):
		_stuck_time = 0.0
		_detour_time = 0.0   # an attack or a stun ends the sidestep
		return
	if move.is_zero_approx() or _calm_on_ring():
		_stuck_time = 0.0
		return
	if _stuck_time == 0.0:
		_stuck_from = global_position
	_stuck_time += delta
	if _stuck_time < STUCK_TIME:
		return
	_stuck_time = 0.0
	var headway := global_position - _stuck_from
	if Vector2(headway.x, headway.z).length() >= STUCK_SPEED * STUCK_TIME:
		return
	var aside := Vector3.UP.cross(move.normalized()) * DETOUR_STEP
	for attempt in 2:
		_detour_side = -_detour_side
		var spot: Variant = _safe_detour(global_position + aside * _detour_side)
		if spot != null:
			_detour = spot
			_detour_time = DETOUR_TIME
			return


func _calm_on_ring() -> bool:
	if not _ring_goal or not _target_alive():
		return false
	var to := target.global_position - global_position
	return Vector2(to.x, to.z).length() < RING_CALM


## [param spot] snapped onto the navmesh, or null when the snap had to move
## it too far (it lies off a ledge or inside a wall). Without a navmesh the
## spot is used as it is.
func _safe_detour(spot: Vector3) -> Variant:
	if not _map_has_regions():
		return spot
	var snapped := _walk_closest_point(spot)
	if Vector2(snapped.x - spot.x, snapped.z - spot.z).length() > DETOUR_SNAP_FLAT or absf(snapped.y - spot.y) > DETOUR_SNAP_HEIGHT:
		return null
	return snapped


## True once the navigation map has synced and holds at least one region
## (cached per map iteration).
func _map_has_regions() -> bool:
	var map := nav.get_navigation_map()
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if iteration != _nav_iteration:
		_nav_iteration = iteration
		_nav_has_regions = iteration > 0 and not NavigationServer3D.map_get_regions(map).is_empty()
	return _nav_has_regions


## The closest point to [param point] on the exhibits' own navigation
## regions (never on a haven's layer).
func _walk_closest_point(point: Vector3) -> Vector3:
	var best := point
	var best_distance := INF
	for region in _walk_regions(nav.get_navigation_map()):
		var near := NavigationServer3D.region_get_closest_point(region, point)
		var distance := near.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = near
	return best


## map RID -> [iteration id, Array[RID] of its walk-layer regions]
static var _walk_region_cache: Dictionary = {}


static func _walk_regions(map: RID) -> Array[RID]:
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	var cached: Array = _walk_region_cache.get(map, [])
	if cached.is_empty() or cached[0] != iteration:
		var regions: Array[RID] = []
		for region in NavigationServer3D.map_get_regions(map):
			if NavigationServer3D.region_get_navigation_layers(region) & LevelNavigation.WALK_LAYER:
				regions.append(region)
		cached = [iteration, regions]
		_walk_region_cache[map] = cached
	return cached[1]


## Melee fighters take a place on the ring around their target (a bust
## keeps its distance and sets a negative range between shots).
func _uses_attack_ring() -> bool:
	return brain.attack_range > 0.0 and brain.attack_range <= RING_MAX_RANGE


## Below the level's kill plane the exhibit fell out of the level: it is
## removed without debris but still reported, so "room cleared" logic never
## waits for it. Returns true when that happened.
func _below_kill_plane() -> bool:
	if global_position.y >= Level.kill_plane():
		return false
	brain.destroy()
	var info := DamageInfo.make(0.0, DamageInfo.Kind.BLUNT)
	info.position = global_position
	Events.enemy_destroyed.emit(self, info, false)
	queue_free()
	return true


## True for the report of an exhibit that fell out of the level (no damage,
## nobody's hit): it leaves no dust.
static func fell_out(info: DamageInfo) -> bool:
	return info != null and info.amount <= 0.0 and info.source == null


func _face_towards(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return
	_set_world_yaw(rotate_toward(_world_yaw(), atan2(-to.x, -to.z), turn_speed * delta))


## Turns toward world yaw [param yaw] (its post's facing).
func _turn_to_yaw(yaw: float, delta: float) -> void:
	_set_world_yaw(rotate_toward(_world_yaw(), yaw, turn_speed * delta))


## Which way the exhibit faces in the world (radians, 0 = -Z).
func _world_yaw() -> float:
	var forward := -global_transform.basis.z
	return atan2(-forward.x, -forward.z)


## Turns the exhibit to face [param yaw] in the world, whatever its parent's
## turn.
func _set_world_yaw(yaw: float) -> void:
	var parent := get_parent_node_3d()
	var parent_yaw := 0.0
	if parent != null:
		var forward := -parent.global_transform.basis.z
		parent_yaw = atan2(-forward.x, -forward.z)
	rotation.y = wrapf(yaw - parent_yaw, -PI, PI)


# --- body-building helpers for subclasses ---

## Per-instance material; all of them glow while an attack winds up.
func body_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.3)
	mat.emission_energy_multiplier = 0.0
	_flash_materials.append(mat)
	return mat


func add_part(mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_deg
	part.material_override = mat
	visual.add_child(part)
	return part


## Upright capsule collider standing on the origin.
func add_collider(radius: float, height: float) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = capsule_shape(radius, height)
	collider.position.y = height * 0.5
	add_child(collider)


func add_hurtbox(shape: Shape3D, pos: Vector3, weak: bool = false) -> Hurtbox:
	var hurtbox := Hurtbox.make(self, shape, pos, weak)
	add_child(hurtbox)
	return hurtbox


static func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func sphere_shape(radius: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


static func capsule_shape(radius: float, height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


func _make_stun_marker() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 1.6, 2.2)
	var marker := MeshInstance3D.new()
	marker.mesh = torus
	marker.material_override = mat
	marker.position.y = marker_height
	marker.visible = false
	return marker


## An outside force on the exhibit (the harpoon's pull): a horizontal push
## of [param push] m/s that dies down like knockback on the floor. Unlike a
## hit's knockback it is not reduced by knockback_resist (the caller
## decides who can be moved).
func shove(push: Vector3) -> void:
	_external += Vector3(push.x, 0.0, push.z)
