class_name CrystalRelic
extends Node3D
## The red crystal (design 7): a dull, unremarkable mineral in a display
## case ("of unknown origin, anonymous gift") until the fuses bring the
## power down. Then it pulses like a heart - a red light and a beat heard
## from about 25 m. When the guard comes within REACH the case bursts, the
## crystal lifts out and flies its route at SPEED, waiting in the air while
## the guard is more than WAIT_BEYOND away, a glowing trail behind it.
## [signal arrived] at the end of the route (between the T-Rex's ribs).

signal burst_out
signal arrived

enum Phase { DORMANT, PULSING, FLYING, ARRIVED }

const REACH := 3.0
const SPEED := 6.0
## The first stretch (up out of the case) goes slowly.
const LIFT_SPEED := 1.1
const WAIT_BEYOND := 14.0
## Seconds per heartbeat, and how far the beat is heard.
const BEAT := 0.9
const HEART_RANGE := 25.0
const RED := Color(1.0, 0.1, 0.06)
const SIZE := Vector3(0.16, 0.3, 0.16)

var phase: Phase = Phase.DORMANT
## Who it waits for and who wakes it.
var guard: Node3D = null
## The flight (world space), set by fly().
var route := PackedVector3Array()
## Display-case glass that shatters when it bursts out.
var case_glass: Array[GeometryInstance3D] = []

var _index: int = 0
var _time: float = 0.0
var _beat_left: float = 0.0
var _gem: MeshInstance3D
var _material: StandardMaterial3D
var _light: OmniLight3D
var _trail: GPUParticles3D
var _waiting: bool = false


func _ready() -> void:
	LevelKit.tag(self, &"crystal", SIZE)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.35, 0.05, 0.05)
	_material.roughness = 0.25
	_material.metallic_specular = 0.9
	_material.emission_enabled = true
	_material.emission = RED
	_material.emission_energy_multiplier = 0.15
	_gem = MeshInstance3D.new()
	_gem.mesh = gem_mesh(SIZE)
	_gem.material_override = _material
	add_child(_gem)
	_light = OmniLight3D.new()
	_light.light_color = RED
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 1.5
	_light.visible = false
	add_child(_light)
	_trail = _make_trail()
	add_child(_trail)


## An elongated octahedron (a cut gem) of [param size].
static func gem_mesh(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var top := Vector3(0, h.y, 0)
	var bottom := Vector3(0, -h.y, 0)
	var ring: Array[Vector3] = [Vector3(h.x, 0, 0), Vector3(0, 0, h.z), Vector3(-h.x, 0, 0), Vector3(0, 0, -h.z)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for tri in [[top, b, a], [bottom, a, b]]:
			for v: Vector3 in tri:
				tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## The power went out: it starts to beat.
func start_pulsing() -> void:
	if phase != Phase.DORMANT:
		return
	phase = Phase.PULSING
	_light.visible = true
	_beat_left = 0.3


## The guard came close: the case bursts and the crystal is ready to fly.
func burst() -> void:
	if phase != Phase.PULSING:
		return
	for glass in case_glass:
		if is_instance_valid(glass):
			glass.visible = false
			for i in 10:
				var fling := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.5), randf_range(-1.0, 1.0)) * randf_range(1.5, 3.5)
				Fx.chunk(glass.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4)), Color(0.75, 0.9, 0.95), randf_range(0.03, 0.07), fling)
	Sfx.play_at(&"glass_break", global_position)
	Sfx.play_at(&"crystal_rise", global_position, 2.0)
	Fx.flash(global_position, RED, 5.0, 8.0, 0.4)
	burst_out.emit()


## Flies [param points] from where it is now.
func fly(points: PackedVector3Array) -> void:
	route = points
	_index = 0
	phase = Phase.FLYING
	_trail.emitting = true


## True while it hangs in the air waiting for the guard.
func is_waiting() -> bool:
	return _waiting


func _physics_process(delta: float) -> void:
	_time += delta
	match phase:
		Phase.PULSING:
			_pulse(delta)
			if _guard_within(REACH):
				burst()
		Phase.FLYING:
			_pulse(delta)
			_follow(delta)
		Phase.ARRIVED:
			pass


func _follow(delta: float) -> void:
	_waiting = not _guard_within(WAIT_BEYOND)
	if _waiting:
		_gem.position.y = sin(_time * 2.5) * 0.06   # hovering, waiting
		return
	_gem.position.y = move_toward(_gem.position.y, 0.0, delta)
	var step := (LIFT_SPEED if _index == 0 else SPEED) * delta
	while step > 0.0 and _index < route.size():
		var goal := route[_index]
		var to := goal - global_position
		if to.length() <= step:
			global_position = goal
			step -= to.length()
			_index += 1
		else:
			global_position += to.normalized() * step
			step = 0.0
	_gem.rotate_y(delta * 3.0)
	if _index >= route.size():
		phase = Phase.ARRIVED
		_trail.emitting = false
		arrived.emit()


func _pulse(delta: float) -> void:
	# lub-dub: two quick swells per beat
	var t := fmod(_time, BEAT) / BEAT
	var beat := maxf(exp(-pow((t - 0.08) * 14.0, 2.0)), 0.7 * exp(-pow((t - 0.3) * 14.0, 2.0)))
	_material.emission_energy_multiplier = 0.6 + 4.0 * beat
	_light.light_energy = 0.4 + 2.6 * beat
	_beat_left -= delta
	if _beat_left <= 0.0:
		_beat_left = BEAT
		if _guard_within(HEART_RANGE):
			Sfx.play_at(&"crystal_pulse", global_position, 4.0, 0.0)


func _guard_within(distance: float) -> bool:
	if not is_instance_valid(guard):
		return false
	var alive := not (guard is Player) or (guard as Player).alive
	# measured from his chest, not his feet
	return alive and (guard.global_position + Vector3.UP * 1.2).distance_to(global_position) <= distance


func _make_trail() -> GPUParticles3D:
	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.amount = 220
	trail.lifetime = 1.6
	trail.local_coords = false
	trail.emitting = false
	trail.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 40, 120))
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3(0.0, 0.15, 0.0)
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.35
	process.spread = 180.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.06
	process.scale_min = 0.7
	process.scale_max = 1.1
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var fade_texture := CurveTexture.new()
	fade_texture.curve = fade
	process.scale_curve = fade_texture
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.45, 0.3, 1.0))
	ramp.set_color(1, Color(0.9, 0.05, 0.02, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	trail.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	# soft round sparks, not squares
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	falloff.add_point(0.35, Color(1.0, 1.0, 1.0, 0.7))
	dot.gradient = falloff
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = dot
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_color = Color(1.0, 0.35, 0.25)
	quad.material = mat
	trail.draw_pass_1 = quad
	return trail
