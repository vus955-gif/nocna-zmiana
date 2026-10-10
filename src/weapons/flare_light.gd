class_name FlareLight
extends Node3D
## A flare stuck where it hit: a strong warm light (no shadows, cheap) for
## [member light_time] seconds that fades out at the end, spraying sparks.
## Stuck on an exhibit it rides along (it follows the exhibit's transform,
## it is not its child) and burns it: [member burn_dps] fire damage every
## BURN_TICK for [member burn_time] seconds (wax takes it double). When the
## exhibit breaks or disappears the flare drops to the floor and glows on.
## Burn ticks fall straight down onto the host (a knight's shield never
## stops them) and show no hit marker. At most MAX_LIT flares light the
## room at once; a new one makes the oldest fade, but a flare still burning
## its exhibit burns on to the end in the dark.

const MAX_LIT := 8
const LIGHT_COLOR := Color(1.0, 0.42, 0.2)
const LIGHT_ENERGY := 3.4
const LIGHT_RANGE := 10.0
## The last seconds of light fade away.
const FADE := 1.5
const BURN_TICK := 0.5
const FALL_GRAVITY := 12.0
const FLOOR_PROBE := 20.0
## The flare_round model stuck in the surface: tilted this far off the
## surface normal (rad), its back end this deep in it (m); the light burns
## this far out past the "Light" marker at its tip (the flame).
const STUCK_TILT := 0.45
const STUCK_DEPTH := 0.02
const FLAME_OUT := 0.12

static var _lit: Array[FlareLight] = []
static var _spark_mesh: Mesh = null
static var _materials: Dictionary = {}

var light_time: float = 12.0
var burn_dps: float = 6.0
var burn_time: float = 5.0
## Credited with the burn damage.
var source: Node = null
## The exhibit it is stuck on (null: a wall or the floor).
var host: Node3D = null
var light: OmniLight3D

var _age: float = 0.0
var _burn_left: float = 0.0
var _burn_timer: float = 0.0
## Transform relative to the host.
var _local := Transform3D.IDENTITY
var _stuck_to_host := false
var _falling := false
var _fall_speed: float = 0.0
var _floor_y: float = NAN
var _flames: GPUParticles3D
var _sparks: GPUParticles3D
var _fading_early := false
## The flare_round model (null: the greybox stick).
var _round: Node3D


## A flare stuck at [param point] (surface [param normal]) on
## [param stuck_on] (an exhibit, or null for level geometry), with the
## numbers of [param data] (light_time, burn_dps, burn_time).
static func stick(parent: Node, point: Vector3, normal: Vector3, stuck_on: Node3D, data: WeaponData, by: Node) -> FlareLight:
	var flare := FlareLight.new()
	flare.light_time = data.light_time
	flare.burn_dps = data.burn_dps
	flare.burn_time = data.burn_time
	flare.source = by
	flare.host = stuck_on
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	flare.transform = Transform3D(_up_basis(up), point + up * 0.03)
	if stuck_on != null and stuck_on.is_inside_tree():
		flare._local = stuck_on.global_transform.affine_inverse() * flare.transform
		flare._stuck_to_host = true
	parent.add_child(flare)
	return flare


## Flares lit right now (fading ones included).
static func lit_count() -> int:
	_lit = _lit.filter(func(f: FlareLight) -> bool: return is_instance_valid(f))
	return _lit.size()


## Where the flares still giving light burn (exhibit perception: a flare
## nearby lights the guard up).
static func lit_positions() -> PackedVector3Array:
	var found := PackedVector3Array()
	for flare in _lit:
		if is_instance_valid(flare) and flare.is_inside_tree() and flare.time_left() > 0.0:
			found.append(flare.global_position)
	return found


func _ready() -> void:
	_burn_left = burn_time if host != null else 0.0
	_burn_timer = BURN_TICK
	_build()
	_lit = _lit.filter(func(f: FlareLight) -> bool: return is_instance_valid(f) and f != self)
	_lit.append(self)
	var burning: Array[FlareLight] = _lit.filter(func(f: FlareLight) -> bool: return not f._fading_early)
	if burning.size() > MAX_LIT:
		burning[0].burn_out()
	Sfx.play_at(&"flare_burn", global_position, -2.0)


func _exit_tree() -> void:
	_lit.erase(self)


## Starts the fade at once (too many flares burning).
func burn_out() -> void:
	_fading_early = true
	_age = maxf(_age, light_time - FADE)


## Seconds of light left.
func time_left() -> float:
	return maxf(light_time - _age, 0.0)


func burning() -> bool:
	return _burn_left > 0.0 and _host_alive()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= light_time and not burning():
		queue_free()
		return
	if _stuck_to_host:
		if _host_alive():
			global_transform = host.global_transform * _local
		else:
			_drop()
	if _falling:
		_fall(delta)
	_burn(delta)
	_update_light()


func _burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_timer -= delta
	if _burn_timer <= 0.0 and _host_alive():
		_burn_timer += BURN_TICK
		var by: Node = source if is_instance_valid(source) else null
		var info := DamageInfo.make(Blast.scaled(burn_dps * BURN_TICK, host, DamageInfo.Kind.FIRE), DamageInfo.Kind.FIRE, by)
		info.position = global_position
		info.normal = Vector3.UP
		info.direction = Vector3.DOWN   # fire eats in from where it sits (past any shield)
		info.periodic = true
		host.take_damage(info)
	if _burn_left <= 0.0 or not _host_alive():
		_burn_left = 0.0
		_flames.emitting = false


func _update_light() -> void:
	var flicker := 0.86 + 0.08 * sin(_age * 23.0) + 0.06 * sin(_age * 37.0 + 1.3)
	var fade := clampf((light_time - _age) / FADE, 0.0, 1.0)
	var rise := clampf(_age / 0.15, 0.0, 1.0)
	light.light_energy = LIGHT_ENERGY * flicker * fade * rise
	light.visible = fade > 0.0   # (burnt out early, still burning: dark)
	_sparks.amount_ratio = fade


func _host_alive() -> bool:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var exhibit := host as Enemy
	return exhibit == null or exhibit.brain.state != EnemyBrain.State.DESTROYED


## The exhibit is gone: the flare falls to the floor below and burns on.
func _drop() -> void:
	_stuck_to_host = false
	host = null
	_burn_left = 0.0
	_flames.emitting = false
	_falling = true
	var from := global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_floor_y = (hit["position"] as Vector3).y + 0.03 if not hit.is_empty() else global_position.y - FLOOR_PROBE


func _fall(delta: float) -> void:
	_fall_speed += FALL_GRAVITY * delta
	var y := global_position.y - _fall_speed * delta
	if y <= _floor_y:
		y = _floor_y
		_falling = false
		global_basis = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.45)   # lying on its side
	global_position.y = y


func _build() -> void:
	var tip_at := _build_round()
	if _round == null:
		tip_at = _build_stick()
	light = OmniLight3D.new()
	light.light_color = LIGHT_COLOR
	light.light_energy = 0.0
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.6
	light.position = tip_at + Vector3.UP * (FLAME_OUT if _round != null else 0.14)
	add_child(light)
	_sparks = _particles(36, 0.6, 2.8, 30.0, 9.0, Color(1.0, 0.62, 0.3))
	_sparks.position = tip_at
	add_child(_sparks)
	_flames = _particles(30, 0.5, 0.8, 45.0, -1.5, Color(1.0, 0.45, 0.15))
	_flames.position = tip_at
	_flames.emitting = host != null
	add_child(_flames)


## The flare_round model stuck in the surface (+Y is its normal), its
## burning tip out and tilted a little to a random side; returns where the
## tip is (local).
func _build_round() -> Vector3:
	_round = ArtLibrary.try_instance(Flare.MODEL)
	if _round == null:
		return Vector3.ZERO
	_round.name = "Round"
	var lean := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, STUCK_TILT)
	# the model flies along -Z: turn -Z up the normal, sink the back end in
	var upright := lean * Basis(Vector3.RIGHT, PI * 0.5)
	var half := 0.0
	var mesh := _round.find_child(Flare.MODEL, true, false) as MeshInstance3D
	if mesh != null:
		half = -mesh.get_aabb().position.z
	var out := upright * Vector3.FORWARD
	_round.transform = Transform3D(upright, out * (half - STUCK_DEPTH))
	for view in _round.find_children("*", "GeometryInstance3D", true, false):
		(view as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_round)
	var tip := _round.find_child("Light", true, false) as Node3D
	return _round.transform * tip.position if tip != null else Vector3.UP * 0.1


## The greybox flare stick (no model): a red casing with a white-hot tip,
## along the normal; returns where the tip is (local).
func _build_stick() -> Vector3:
	var casing := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.022
	tube.bottom_radius = 0.022
	tube.height = 0.12
	tube.radial_segments = 8
	tube.rings = 1
	casing.mesh = tube
	casing.position = Vector3(0.0, 0.04, 0.0)
	casing.material_override = _material(Color(0.7, 0.08, 0.06), false)
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(casing)
	var tip := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	ball.radial_segments = 8
	ball.rings = 4
	tip.mesh = ball
	tip.position = Vector3(0.0, 0.11, 0.0)
	tip.material_override = _material(Color(1.0, 0.85, 0.7), true)
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tip)
	return tip.position


static func _particles(amount: int, lifetime: float, speed: float, spread: float, gravity: float, color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -gravity, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.color = color
	particles.process_material = process
	particles.draw_pass_1 = spark_mesh()
	return particles


## Basis whose +Y is [param up].
static func _up_basis(up: Vector3) -> Basis:
	var y := up.normalized()
	var reference := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())


## A tiny glowing box shared by every spark.
static func spark_mesh() -> Mesh:
	if _spark_mesh == null:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.025
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(3.0, 3.0, 3.0)
		mesh.material = material
		_spark_mesh = mesh
	return _spark_mesh


static func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), glowing]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		if glowing:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
		_materials[key] = material
	return _materials[key]
