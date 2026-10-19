class_name Bust
extends Enemy
## Floating marble bust of a bearded philosopher on a small plinth. Hovers
## 1.6 m above the floor and bobs; keeps 8-14 m from the guard (backs off
## when he comes closer than 6 m, circles slowly otherwise). Its cracks glow
## from inside for 0.7 s, then it spits one slow marble shard (only when the
## guard is still in plain view at that moment), every 2.4 s. A taser stun
## drops it to the floor for 3 s, where a fist can finish it. Shatters into
## angular marble pieces. Support (EnemyRoles: it calls the others):
## hunting with the guard in view it grinds out a call every CALL_INTERVAL
## (the first FIRST_CALL into the hunt) that rouses up to CHAIN_MAX sleepers
## of its room in its sight - they come to look, quietly - unless the room
## hunts already (hunters near the guard at half the cap or more).

const KIND := &"bust"
const FIRE_INTERVAL := 2.4
const CALL_INTERVAL := 8.0
const FIRST_CALL := 3.0
## Where the shard aims, above the target's origin (the guard's chest).
const AIM_HEIGHT := 1.1
const MUZZLE := Vector3(0.0, 0.72, -0.2)
const BOB_SPEED := 1.7
## Hover spring: vertical speed per metre off the hover height, and its cap.
const HOVER_STIFFNESS := 3.0
const HOVER_MAX_SPEED := 2.5
## How fast knockback dies down while it hovers (m/s per second). The base
## only brakes it on the ground; up here a shotgun blast slid it for tens
## of metres. With this a punch shoves it about half a metre.
const HOVER_DRAG := 18.0
const FLOOR_CHECK := 0.1
## How long it circles one way before it may turn the other way (s).
const STRAFE_TIME := Vector2(2.0, 4.0)
## It fires from a little beyond keep_max: it keeps its distance on the
## floor plan, but hovering 1.6 m up its true distance is longer, and one
## circling right at keep_max would never be in range.
const RANGE_SLACK := 1.5

@export var hover_height: float = 1.6
@export var bob_amplitude: float = 0.15
@export var keep_min: float = 8.0
@export var keep_max: float = 14.0
@export var retreat_distance: float = 6.0
@export var shard_speed: float = 9.0

var _cooldown: float = 0.0
var _time: float = 0.0
var _floor_y: float = NAN
var _floor_timer: float = 0.0
var _strafe_side: float = 1.0
var _strafe_timer: float = 0.0
var _crack_material: StandardMaterial3D
var _inner_light: OmniLight3D
var _crack_energy: float = 0.0
var _call_wait: float = FIRST_CALL
## Calls made (tests).
var calls: int = 0


func _configure() -> void:
	max_health = 45.0
	move_speed = 3.0
	turn_speed = 5.0
	attack_damage = 12.0
	knockback_resist = 0.3
	eye_height = 0.78
	marker_height = 1.2
	material_kind = ExhibitMaterial.Kind.MARBLE
	notice_sound = &"bust_grind"
	sight_cone_deg = PerceptionRules.WIDE_CONE_DEG
	brain.reaction_time = 0.8
	brain.attack_range = keep_max + RANGE_SLACK
	brain.windup = 0.7
	brain.recovery = 0.1
	dust_value = 5


func _ready() -> void:
	super()
	# its path runs at hover height, so it reaches (and passes) path points
	# without sinking to the floor
	nav.path_height_offset = -hover_height
	_strafe_side = 1.0 if randf() < 0.5 else -1.0
	_strafe_timer = randf_range(STRAFE_TIME.x, STRAFE_TIME.y)
	_time = randf() * TAU


func _build_body() -> void:
	add_collider(0.28, 0.95)
	_crack_material = StandardMaterial3D.new()
	_crack_material.albedo_color = Color(0.18, 0.15, 0.13)
	_crack_material.emission_enabled = true
	_crack_material.emission = Color(1.0, 0.62, 0.3)
	_crack_material.emission_energy_multiplier = 0.0
	rig = BustRig.build(self)
	if rig == null:
		_build_greybox()
	_inner_light = OmniLight3D.new()
	_inner_light.light_color = Color(1.0, 0.6, 0.3)
	_inner_light.omni_range = 3.5
	_inner_light.light_energy = 0.0
	_inner_light.position = Vector3(0, 0.7, -0.35)
	visual.add_child(_inner_light)
	# hit zones: base and chest, back of the head, the face (weak point) in front
	add_hurtbox(box_shape(Vector3(0.52, 0.5, 0.32)), Vector3(0, 0.3, 0))
	var head_zone := add_hurtbox(sphere_shape(0.17), Vector3(0, 0.78, 0))
	var face_zone := add_hurtbox(sphere_shape(0.13), Vector3(0, 0.77, -0.07), true)
	if rig != null:
		rig.track(head_zone, &"bust")
		rig.track(face_zone, &"bust")


func _build_greybox() -> void:
	var marble := body_material(Color(0.88, 0.87, 0.83))
	var stone := body_material(Color(0.34, 0.37, 0.35))
	# floating plinth and the small round socle a bust stands on
	add_part(_cylinder(0.2, 0.24, 0.14), Vector3(0, 0.07, 0), stone)
	add_part(_cylinder(0.1, 0.16, 0.12), Vector3(0, 0.2, 0), marble)
	# chest and shoulders, neck
	add_part(box_mesh(Vector3(0.46, 0.2, 0.26)), Vector3(0, 0.36, 0.01), marble)
	var shoulders := CapsuleMesh.new()
	shoulders.radius = 0.12
	shoulders.height = 0.6
	add_part(shoulders, Vector3(0, 0.44, 0.02), marble, Vector3(0, 0, 90))
	add_part(_cylinder(0.075, 0.085, 0.16), Vector3(0, 0.57, 0), marble)
	# head: skull, beard, nose, brow ridge, blank eyes, curls
	var skull := SphereMesh.new()
	skull.radius = 0.145
	skull.height = 0.34
	add_part(skull, Vector3(0, 0.78, 0), marble)
	var beard := SphereMesh.new()
	beard.radius = 0.1
	beard.height = 0.2
	add_part(beard, Vector3(0, 0.66, -0.08), marble).scale = Vector3(1.0, 1.1, 0.8)
	add_part(box_mesh(Vector3(0.045, 0.08, 0.06)), Vector3(0, 0.77, -0.15), marble, Vector3(-12, 0, 0))
	add_part(box_mesh(Vector3(0.22, 0.035, 0.05)), Vector3(0, 0.83, -0.125), marble)
	for x in [-0.055, 0.055]:
		add_part(box_mesh(Vector3(0.05, 0.022, 0.02)), Vector3(x, 0.8, -0.14), _crack_material)
	var curl := SphereMesh.new()
	curl.radius = 0.055
	curl.height = 0.11
	for spot in [Vector3(-0.1, 0.9, -0.02), Vector3(0.0, 0.93, 0.0), Vector3(0.1, 0.9, -0.02),
			Vector3(-0.13, 0.84, 0.06), Vector3(0.13, 0.84, 0.06), Vector3(-0.07, 0.9, 0.09),
			Vector3(0.07, 0.9, 0.09), Vector3(0.0, 0.86, 0.13)]:
		add_part(curl, spot, marble)
	# jagged cracks: forehead to cheek, across the chest
	var cracks := [
		[Vector3(0.03, 0.87, -0.132), Vector3(0.012, 0.07, 0.012), 25.0],
		[Vector3(0.06, 0.8, -0.13), Vector3(0.012, 0.07, 0.012), -20.0],
		[Vector3(0.085, 0.73, -0.11), Vector3(0.012, 0.07, 0.012), 30.0],
		[Vector3(-0.1, 0.38, -0.121), Vector3(0.015, 0.12, 0.012), -35.0],
		[Vector3(-0.04, 0.33, -0.121), Vector3(0.015, 0.1, 0.012), 40.0],
		[Vector3(0.12, 0.42, -0.121), Vector3(0.015, 0.09, 0.012), 15.0],
	]
	for crack in cracks:
		add_part(box_mesh(crack[1]), crack[0], _crack_material, Vector3(0, 0, crack[2]))


## Current emission of the cracks (0 while dormant; flares in the windup).
func crack_glow() -> float:
	return _crack_energy


func _physics_process(delta: float) -> void:
	_time += delta
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			brain.attack_range = keep_max + RANGE_SLACK
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(STRAFE_TIME.x, STRAFE_TIME.y)
		if randf() < 0.6:
			_strafe_side = -_strafe_side
	if brain.is_hunting() and _sees_target and _target_alive():
		_call_wait -= delta
		if _call_wait <= 0.0:
			_call_wait = CALL_INTERVAL
			_call()
	elif not brain.is_hunting():
		_call_wait = FIRST_CALL
	super(delta)


## The call: unless the room hunts already, a grind that rouses the
## sleepers near it to come and look (Enemy._rouse_neighbours: at most
## CHAIN_MAX, in its room, in its sight).
func _call() -> void:
	if PerceptionWorld.hunters_near(target.global_position) >= ceili(PerceptionWorld.hunter_cap * 0.5):
		return
	calls += 1
	Sfx.play_at(&"bust_grind", global_position + Vector3.UP * eye_height, -4.0)
	brain.last_known = target.global_position
	_rouse_neighbours()


## Hovers on a spring above the floor while awake (air drag on knockback);
## falls while dormant, stunned or breaking apart.
func _apply_gravity(delta: float) -> void:
	if not _hovering():
		super(delta)
		return
	_external = _external.move_toward(Vector3.ZERO, HOVER_DRAG * delta)
	_floor_timer -= delta
	if _floor_timer <= 0.0 or is_nan(_floor_y):
		_floor_timer = FLOOR_CHECK
		_floor_y = _probe_floor()
	var goal := _floor_y + hover_height + sin(_time * BOB_SPEED) * bob_amplitude
	velocity.y = clampf((goal - global_position.y) * HOVER_STIFFNESS, -HOVER_MAX_SPEED, HOVER_MAX_SPEED)


## It shoots from afar: the navmesh need not bring it to the guard.
func _attacks_from_range() -> bool:
	return true


## Asleep on its plinth it turns to follow an unwatched guard, but a
## plinth goes nowhere.
func _stirs_in_place() -> bool:
	return true


## Keeps 8-14 m: approaches (base navigation) from afar or out of sight,
## backs off (angled, so it slides along walls instead of pinning itself)
## when crowded, circles slowly in between. The path is planned on in any
## case, so it always knows whether it could get to the guard.
## (Anything but a hunt in plain view - looking, searching, going home -
## is plain navigation, like every exhibit.)
func _chase_direction(delta: float, goal: Vector3) -> Vector3:
	if brain.state != EnemyBrain.State.HUNT or _detour_time > 0.0 or not _sees_target:
		return super(delta, goal)
	if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) > 0:
		_refresh_path(delta, goal)
	var away := global_position - target.global_position
	away.y = 0.0
	var distance := away.length()
	if distance < 0.01:
		return Vector3.ZERO
	if distance > keep_max:
		return super(delta, goal)
	away /= distance
	var side := Vector3.UP.cross(away) * _strafe_side
	if distance < retreat_distance:
		return (away + side * 0.35).normalized()
	if distance < keep_min:
		return (away + side * 0.3).normalized() * 0.6
	return side * 0.35


func _on_strike() -> void:
	_cooldown = FIRE_INTERVAL - brain.windup
	brain.attack_range = -1.0   # back to repositioning until the next shot
	if not _target_alive() or Haven.shelters(target.global_position):
		return   # gone, or he made it to a haven during the windup
	var muzzle := global_transform * MUZZLE
	var aim := target.global_position + Vector3.UP * AIM_HEIGHT
	if not _clear_line(muzzle, aim):
		return   # the guard ducked behind cover during the windup
	var info := DamageInfo.make(attack_damage, DamageInfo.Kind.BLUNT, self)
	info.knockback = 2.0
	var shard := Projectile.create(muzzle, (aim - muzzle).normalized() * shard_speed, info)
	shard.exclude = [get_rid()]
	get_parent().add_child(shard)
	Sfx.play_at(&"shard_fire", muzzle)


func _on_state_changed(from: EnemyBrain.State, to: EnemyBrain.State) -> void:
	super(from, to)
	if to == EnemyBrain.State.ATTACK:
		Sfx.play_at(&"bust_grind", global_position + Vector3.UP * eye_height, -2.0)
	elif to == EnemyBrain.State.STUNNED:
		_floor_y = NAN   # measure the floor again when it rises


func _update_visuals(delta: float) -> void:
	super(delta)
	var windup := brain.windup_progress()
	var awake := brain.state != EnemyBrain.State.DORMANT
	var energy := (0.35 if awake else 0.0) + windup * windup * 7.0
	if energy != _crack_energy:
		_crack_energy = energy
		_crack_material.emission_energy_multiplier = energy
		_inner_light.light_energy = windup * windup * 2.2
	# a stunned bust tips over on the floor; hovering it sways a little
	var tilt := 0.55 if brain.is_stunned() else (sin(_time * 1.3) * 0.05 if awake else 0.0)
	visual.rotation.z = lerpf(visual.rotation.z, tilt, 1.0 - exp(-8.0 * delta))


func _hovering() -> bool:
	return brain.state != EnemyBrain.State.DORMANT \
			and brain.state != EnemyBrain.State.STUNNED \
			and brain.state != EnemyBrain.State.DESTROYED


## Height of the floor under the bust (level geometry only).
func _probe_floor() -> float:
	var from := global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y - hover_height if is_nan(_floor_y) else _floor_y
	return (hit["position"] as Vector3).y


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return mesh
