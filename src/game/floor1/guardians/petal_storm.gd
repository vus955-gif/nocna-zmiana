class_name PetalStorm
extends Node3D
## The cherry's petals in the General's phase 3 (General): from the
## transformation on, the tree sheds petals that drift down over the
## garden (emitters under its crown: the Petals_* nodes of a dressed
## cherry_tree, or points round the greybox crown), a gust of petals bursts
## out of it when he plants the sword, and a whirl of petals rises round him
## to hide him for the feint (two figures step out of it; the phantom
## bursts into petals when its dash ends).
## World space (top_level).

const PETAL := Color(0.97, 0.76, 0.82)
const PETAL_DEEP := Color(0.93, 0.6, 0.72)
## Emitters round the greybox crown (offsets from its centre).
const CROWN_SPREAD: Array[Vector3] = [Vector3(0.0, -0.8, 0.0), Vector3(1.8, -0.6, 0.6), Vector3(-1.6, -0.4, 1.2),
	Vector3(0.9, -0.5, -1.7), Vector3(-1.1, -0.9, -1.3), Vector3(1.4, -1.1, 1.6)]
## The fall: petals a second per emitter, how long they live, their drift.
const RATE := 10
const LIFE := 7.0
const DRIFT := 0.6
## The gust and the whirl.
const GUST_AMOUNT := 320
const WHIRL_AMOUNT := 220
const BURST_AMOUNT := 160

static var _mesh: Mesh = null
static var _fall_material: ParticleProcessMaterial = null

## True while the tree sheds petals.
var falling := false

var _emitters: Array[GPUParticles3D] = []
var _bursts: Array[GPUParticles3D] = []


## The storm with emitters at [param points] (world).
static func make(points: Array[Vector3]) -> PetalStorm:
	var storm := PetalStorm.new()
	for at in points:
		var emitter := storm._emitter()
		emitter.position = at
		storm.add_child(emitter)
		storm._emitters.append(emitter)
	return storm


## Where the petals come from: the Petals_* nodes of a dressed cherry
## tree within [param reach] m of [param near] (looked for under
## [param root]), else points round the greybox crown at [param crown].
static func emitters_for(root: Node, near: Vector3, crown: Vector3, reach: float = 14.0) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if root != null:
		for node in root.find_children("Petals_*", "Node3D", true, false):
			var spot := node as Node3D
			if spot != null and spot.is_inside_tree() and spot.global_position.distance_to(near) < reach:
				points.append(spot.global_position)
	if points.is_empty():
		for offset in CROWN_SPREAD:
			points.append(crown + offset)
	return points


func _init() -> void:
	top_level = true
	name = "PetalStorm"


## The tree sheds petals from now on.
func start() -> void:
	falling = true
	for emitter in _emitters:
		emitter.emitting = true


func stop() -> void:
	falling = false
	for emitter in _emitters:
		emitter.emitting = false


## A gust of petals out of the crown toward [param direction] (the sword
## planted: the transformation).
func gust(direction: Vector3 = Vector3.ZERO) -> void:
	for emitter in _emitters:
		var away := direction if direction.length() > 0.01 else Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0))
		_burst(emitter.global_position, away.normalized(), GUST_AMOUNT / maxi(_emitters.size(), 1) + 20, 7.0, 4.0, 55.0, 1.2)


## A whirl of petals rising round [param at] (the feint: it hides him).
func whirl(at: Vector3) -> void:
	_burst(at + Vector3.UP * 0.3, Vector3.UP, WHIRL_AMOUNT, 5.5, 2.2, 75.0, 1.6)
	_burst(at + Vector3.UP * 1.6, Vector3.UP, WHIRL_AMOUNT / 2, 3.0, 2.0, 120.0, 0.8)


## The phantom bursts into petals at [param at] (its dash's end).
func burst(at: Vector3, direction: Vector3) -> void:
	_burst(at + Vector3.UP * 1.2, (direction + Vector3.UP * 0.5).normalized(), BURST_AMOUNT, 6.0, 2.5, 90.0, 1.5)


## How many bursts are in the air (tests).
func bursts_alive() -> int:
	var alive := 0
	for node in _bursts:
		if is_instance_valid(node):
			alive += 1
	return alive


func _burst(at: Vector3, direction: Vector3, amount: int, speed: float, life: float, spread: float, gravity: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(amount, 1)
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 0.9
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -gravity, 0.0)
	process.damping_min = 1.2
	process.damping_max = 2.4
	process.angular_velocity_min = -220.0
	process.angular_velocity_max = 220.0
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.color = PETAL_DEEP
	particles.process_material = process
	particles.draw_pass_1 = _petal_mesh()
	var up := direction if direction.length() > 0.01 else Vector3.UP
	var axis := up.cross(Vector3.UP)
	var basis := Basis.IDENTITY
	if axis.length() > 0.001 and absf(up.dot(Vector3.UP)) < 0.999:
		basis = Basis(axis.normalized(), -acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	particles.transform = Transform3D(basis, at)
	add_child(particles)
	particles.emitting = true
	_bursts.append(particles)
	get_tree().create_timer(life + 0.5, false).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			_bursts.erase(particles)
			particles.queue_free())


## A continuous shower of petals, drifting down.
func _emitter() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = int(RATE * LIFE)
	particles.lifetime = LIFE
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.6
	particles.emitting = false
	if _fall_material == null:
		_fall_material = ParticleProcessMaterial.new()
		_fall_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_fall_material.emission_box_extents = Vector3(1.4, 0.3, 1.4)
		_fall_material.direction = Vector3(0.3, -1.0, 0.1)
		_fall_material.spread = 60.0
		_fall_material.initial_velocity_min = 0.2
		_fall_material.initial_velocity_max = DRIFT
		_fall_material.gravity = Vector3(0.0, -0.35, 0.0)
		_fall_material.damping_min = 0.3
		_fall_material.damping_max = 0.6
		_fall_material.angular_velocity_min = -90.0
		_fall_material.angular_velocity_max = 90.0
		_fall_material.turbulence_enabled = true
		_fall_material.turbulence_noise_strength = 0.8
		_fall_material.turbulence_noise_scale = 3.0
		_fall_material.scale_min = 0.7
		_fall_material.scale_max = 1.2
		_fall_material.color = PETAL
	particles.process_material = _fall_material
	particles.draw_pass_1 = _petal_mesh()
	return particles


static func _petal_mesh() -> Mesh:
	if _mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.05)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = PETAL
		material.albedo_texture = petal_texture()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad.material = material
		_mesh = quad
	return _mesh


static var _shape: ImageTexture = null


## A cherry petal's outline (white, its alpha the shape): an oval with a
## notch at its tip, clear round it - the petals of the storm and of the
## garden's fall are cut from it (a bare quad read as a pink square).
static func petal_texture() -> ImageTexture:
	if _shape == null:
		var size := 32
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				# across: -1..1; along: -1 (stem) .. 1 (tip)
				var u := (x + 0.5) / size * 2.0 - 1.0
				var v := (y + 0.5) / size * 2.0 - 1.0
				# wider toward the tip, narrow at the stem
				var width := 0.55 + 0.35 * (v * 0.5 + 0.5)
				var inside := (u / width) * (u / width) + v * v <= 1.0
				# the notch: a small wedge cut into the tip
				if v > 0.62 and absf(u) < (v - 0.62) * 0.9:
					inside = false
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if inside else 0.0))
		image.generate_mipmaps()
		_shape = ImageTexture.create_from_image(image)
	return _shape
