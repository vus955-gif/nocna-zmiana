extends Node
## Visual effects service (autoload "Fx"): hit particles, physical debris,
## tracers, taser arcs, light flashes, marks on walls and hitstop. A shot on
## the level shows what it hit (plan 2026-10-19-gun-feel): surface_impact()
## throws stone dust and grit, wood splinters, metal sparks or carpet fluff,
## and mark() leaves that surface's own mark - a hole with a pale chipped
## rim in stone, a long dark splinter-hole in wood, a bright dent in metal,
## a soft spot in carpet, a scorch where a blast burst. Everything
## it spawns is parented here and removes itself after a while (lifetimes
## stand still while the game is paused); a scene change clears it all.
## Transforms are set before add_child() so physics interpolation never
## smears a node in from the origin.

const MAX_CHUNKS := 80
const MAX_DECALS := 80
## Live bursts of a shot's grit and dust on a wall (surface_impact()); the
## oldest make room, so sustained shotgun fire never piles up nodes.
const MAX_IMPACT_BURSTS := 40
## Below this strength (a pellet's share of a blast) a hit throws no
## second puff of dust: a handful of pellets would only add nodes.
const DUST_MIN_STRENGTH := 0.6
## A mark's kind for a blast's burn (mark()).
const SCORCH := &"scorch"
const CHUNK_LIFETIME := 8.0
const DECAL_LIFETIME := 30.0
## Microseconds per frame spent cutting model meshes for debris ahead of
## need (MeshShards.warm_*).
const SHARD_BUDGET_USEC := 2500

var _chunks: Array = []
var _decals: Array = []
var _impact_bursts: Array = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _processes: Dictionary = {}
var _hole: Texture2D = null
## Surface (or SCORCH) -> its mark's texture.
var _marks: Dictionary = {}
var _hitstop_token: int = 0
## Real time (s) when the running hitstop ends; negative when none runs.
var _hitstop_end: float = -1.0
var _time_scale_before: float = 1.0


func _ready() -> void:
	get_tree().scene_changed.connect(clear)


func _process(_delta: float) -> void:
	if MeshShards.pending() > 0:
		MeshShards.tick(SHARD_BUDGET_USEC)


## The night start, under the black fade (the end of Museum._ready): cuts
## every queued piece of debris now (MeshShards.drain(): a T-Rex cut takes
## a sixth of a second, it must not land in a fight) and shows the renderer
## one of everything a fight draws for the first time, right in front of
## [param camera] for a few frames (ShaderWarmUp: every material the art
## library made, debris on its cut pieces, these effects' particles,
## chunk, tracer, hole and flash, the flare's and the gatling's), so their
## shaders and pipelines compile now and not mid-fight. [param root] is
## the scene whose models it borrows meshes from. Safe to call again: the
## queue is empty and a running warm-up is replaced.
## (Headless there is nothing to compile: only the cutting happens.)
func warm_up(root: Node, camera: Camera3D) -> void:
	MeshShards.drain()
	if camera != null and camera.is_inside_tree() and DisplayServer.get_name() != "headless":
		ShaderWarmUp.start(root, camera)


## Small burst where a hit lands. [param kind] is an ExhibitMaterial.Kind,
## or -1 for level geometry (grey dust).
func impact(position: Vector3, normal: Vector3, kind: int = -1, strength: float = 1.0) -> void:
	var color := Color(0.62, 0.6, 0.56)
	var glow := false
	var speed := 3.5
	var gravity := 9.8
	if kind >= 0:
		var material_kind := kind as ExhibitMaterial.Kind
		color = ExhibitMaterial.particle_color(material_kind)
		match material_kind:
			ExhibitMaterial.Kind.WAX:
				speed = 2.5
				gravity = 14.0
			ExhibitMaterial.Kind.TAXIDERMY:
				speed = 2.0
				gravity = 3.0
			ExhibitMaterial.Kind.METAL:
				speed = 7.0
				glow = true
			ExhibitMaterial.Kind.WOOD:
				# chips: thrown hard, dropping fast
				speed = 4.5
				gravity = 12.0
			ExhibitMaterial.Kind.LINEN:
				# tomb dust: a slow puff that hangs in the air
				_burst(position, normal, color, false, int(clampf(8.0 * strength, 4.0, 30.0)), 1.6, 1.3, 70.0, 1.2, 0.07)
				return
	var amount := int(clampf(10.0 * strength, 4.0, 40.0))
	_burst(position, normal, color, glow, amount, speed, 0.7, 40.0, gravity, 0.045)


## A cloud of dust at [param position] (a mummy coming apart, a coffin lid
## slamming down): [param amount] coarse motes thrown out all around within
## about [param radius] metres, rising a little and hanging for a second
## and a half.
func puff(position: Vector3, color: Color, amount: int = 24, radius: float = 0.6) -> void:
	_burst(position, Vector3.UP, color, false, amount, clampf(radius * 2.2, 0.5, 4.0), 1.6, 180.0, -0.4, 0.09)


## Breaks an exhibit apart: a burst of particles plus physical chunks
## flying mostly along [param push]. Without [param chunks] only the
## particles (a model's own parts fly as debris instead, see piece()).
func shatter(center: Vector3, kind: ExhibitMaterial.Kind, plan: GibPlanner.Plan, push: Vector3, chunks: bool = true) -> void:
	var glow := kind == ExhibitMaterial.Kind.METAL
	var flat_push := Vector3(push.x, 0.0, push.z).normalized()
	# the harder the blow throws the pieces back (plan.push past the plain
	# plan's), the more the burst leans that way and narrows; a plain kill
	# or a crumble puffs out all round
	var lean := clampf((plan.push - 0.9) / (GibPlanner.PUSH.y - 0.9), 0.0, 1.0)
	var heading := (Vector3.UP + flat_push * 1.2 * lean).normalized()
	_burst(center, heading, ExhibitMaterial.particle_color(kind), glow, plan.particles, plan.impulse, 1.2,
			lerpf(180.0, 70.0, lean), 9.8, 0.06)
	if not chunks:
		return
	for i in plan.chunks:
		var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.2) * plan.lift / 0.85, randf_range(-1.0, 1.0))
		var velocity := (flat_push * plan.push * 0.9 + scatter * plan.spread).normalized() * plan.impulse * randf_range(0.7, 1.2)
		var offset := Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.3, 0.3))
		chunk(center + offset, ExhibitMaterial.color(kind), plan.chunk_size * randf_range(0.7, 1.3), velocity)


## One physical debris piece. Shrinks away after CHUNK_LIFETIME seconds.
func chunk(position: Vector3, color: Color, size: float, velocity: Vector3) -> void:
	var dims := Vector3(size, size * randf_range(0.5, 1.2), size * randf_range(0.6, 1.4))
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var view := chunk_view(color, dims)
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = 0.4
	body.position = position
	body.add_child(collider)
	body.add_child(view)
	add_child(body)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))
	_chunks.append(body)
	while _chunks.size() > MAX_CHUNKS:
		var oldest = _chunks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_shrink_and_free(body, view, CHUNK_LIFETIME)


## A debris chunk's box of [param dims] in [param color] (no body).
func chunk_view(color: Color, dims: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _solid_material(color)
	return view


## One piece of a broken model as physical debris: [param shard] (a
## MeshShards.Piece of a mesh that sits at [param xform] in the world) with
## [param materials] (one per piece surface). Scale in [param xform] (a
## melted wax figure) stays on the mesh, never on the body, and so does a
## mirror (the lioness' model is flipped): a body with a negative scale is
## no body. Shrinks away after CHUNK_LIFETIME seconds like the other chunks.
func piece(shard: MeshShards.Piece, materials: Array[Material], xform: Transform3D, velocity: Vector3, spin: float = 8.0) -> RigidBody3D:
	var turn := xform.basis.orthonormalized()
	if turn.determinant() < 0.0:
		turn = turn * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))   # a proper turn; the flip goes to the view below
	var view := MeshInstance3D.new()
	view.mesh = shard.mesh
	var shape_basis := turn.inverse() * xform.basis
	view.transform = Transform3D(shape_basis, shape_basis * shard.offset)
	for i in mini(materials.size(), shard.mesh.get_surface_count()):
		view.set_surface_override_material(i, materials[i])
	var dims := (shape_basis * shard.size).abs().max(Vector3.ONE * 0.04)
	var shape := BoxShape3D.new()
	shape.size = dims
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD | Layers.DEBRIS
	body.mass = clampf(dims.x * dims.y * dims.z * 600.0, 0.2, 6.0)
	body.transform = Transform3D(turn, xform * shard.center)
	body.add_child(collider)
	body.add_child(view)
	add_child(body)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * spin
	_chunks.append(body)
	while _chunks.size() > MAX_CHUNKS:
		var oldest = _chunks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_shrink_and_free(body, view, CHUNK_LIFETIME)
	return body


## Thin glowing line (bullet trail).
func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.55), width: float = 0.012, duration: float = 0.05) -> void:
	var run := to - from
	if run.length() < 0.05:
		return
	var view := tracer_view(color, width, run.length())
	var up := Vector3.UP if absf(run.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	view.transform = Transform3D(Basis.looking_at(run.normalized(), up), (from + to) * 0.5)
	add_child(view)
	_free_after(view, duration)


## A tracer's glowing beam along -Z ([param length] m), not placed nor added.
func tracer_view(color: Color, width: float, length: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, length)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.material_override = _glow_material(color)
	return view


## Jagged electric arc for the taser, with a blue flash at the far end.
func arc(from: Vector3, to: Vector3) -> void:
	var points: Array[Vector3] = [from]
	var segments := 7
	for i in range(1, segments):
		var t := float(i) / segments
		var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.12
		points.append(from.lerp(to, t) + jitter)
	points.append(to)
	for i in points.size() - 1:
		tracer(points[i], points[i + 1], Color(0.45, 0.8, 1.0), 0.02, 0.09)
	flash(to, Color(0.5, 0.8, 1.0), 2.5, 4.0, 0.12)


## Short-lived point light (muzzle flash, zap).
func flash(position: Vector3, color: Color, energy: float, light_range: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.position = position
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


## Dark mark where a bullet hit a wall (a stone one). Oldest ones
## disappear first.
func bullet_hole(position: Vector3, normal: Vector3) -> void:
	mark(position, normal, Surface.STONE, 0.14)


## The mark a hit leaves on [param surface] (a Surface name, or SCORCH for
## a blast's burn), [param size] metres across, turned at random about the
## surface's normal. Oldest ones disappear first. Returns the decal (null
## for a point-blank hit: no surface to mark).
func mark(position: Vector3, normal: Vector3, surface: StringName, size: float) -> Decal:
	if normal.is_zero_approx() or size <= 0.0:
		return null   # the ray started inside the wall: no surface to mark
	var decal := Decal.new()
	decal.texture_albedo = mark_texture(surface)
	var stretch := 1.6 if surface == Surface.WOOD else 1.0
	var depth := maxf(size * 0.6, 0.1) if surface == SCORCH else 0.1
	decal.size = Vector3(size * stretch, depth, size)
	decal.normal_fade = 0.25
	var turn := _basis_with_up(normal) * Basis(Vector3.UP, randf() * TAU)
	decal.transform = Transform3D(turn, position)
	add_child(decal)
	_decals.append(decal)
	while _decals.size() > MAX_DECALS:
		var oldest = _decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_free_after(decal, DECAL_LIFETIME)
	return decal


## What a shot throws off the level where it hit [param surface]:
## stone dust and grit, wood splinters, metal sparks, carpet fluff.
## [param strength] scales it (a rifle round more than a pellet); a weak
## hit (under DUST_MIN_STRENGTH) leaves out the second, dusty burst. At
## most MAX_IMPACT_BURSTS of these stay alive, the oldest going first.
func surface_impact(position: Vector3, normal: Vector3, surface: StringName, strength: float = 1.0) -> void:
	var amount := int(clampf(10.0 * strength, 4.0, 40.0))
	var dust := strength >= DUST_MIN_STRENGTH
	match surface:
		Surface.WOOD:
			_surface_burst(position, normal, Color(0.62, 0.44, 0.27), false, amount, 4.5, 0.6, 35.0, 12.0, 0.04)
			if dust:
				_surface_burst(position, normal, Color(0.5, 0.4, 0.3), false, maxi(amount / 3, 2), 1.0, 0.9, 60.0, -0.2, 0.06)
		Surface.METAL:
			_surface_burst(position, normal, Color(1.0, 0.72, 0.36), true, amount + 4, 7.5, 0.35, 45.0, 9.8, 0.02)
		Surface.CARPET:
			_surface_burst(position, normal, Color(0.42, 0.33, 0.29), false, maxi(amount / 2, 3), 1.4, 0.6, 70.0, 3.0, 0.022)
		_:
			# stone: grit thrown hard, a pale puff of dust that hangs
			_surface_burst(position, normal, Color(0.62, 0.6, 0.56), false, amount, 3.5, 0.7, 40.0, 9.8, 0.045)
			if dust:
				_surface_burst(position, normal, Color(0.78, 0.76, 0.72), false, maxi(amount / 3, 2), 0.9, 1.2, 70.0, -0.3, 0.08)


## The texture of [param surface]'s mark (made once; SCORCH a blast's burn).
func mark_texture(surface: StringName) -> Texture2D:
	var key := surface if surface == SCORCH or Surface.ALL.has(surface) else Surface.STONE
	if not _marks.has(key):
		_marks[key] = _make_mark(key)
	return _marks[key]


## A bullet hole's decal (projecting along its -Y), not placed nor added.
func hole_decal() -> Decal:
	var decal := Decal.new()
	decal.texture_albedo = _hole_texture()
	decal.size = Vector3(0.14, 0.1, 0.14)
	return decal


## Nearly freezes time for [param duration] real seconds (heavy kills).
## Overlapping hitstops last until the latest one ends, then the time scale
## from before the first one comes back.
func hitstop(duration: float, time_scale: float = 0.05) -> void:
	var end := Time.get_ticks_usec() / 1000000.0 + duration
	if _hitstop_end < 0.0:
		_time_scale_before = Engine.time_scale
	Engine.time_scale = time_scale
	if end <= _hitstop_end:
		return   # the running hitstop lasts longer and will end this one too
	_hitstop_end = end
	_hitstop_token += 1
	var token := _hitstop_token
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		_hitstop_end = -1.0
		Engine.time_scale = _time_scale_before


func chunk_count() -> int:
	_chunks = _chunks.filter(func(c: Variant) -> bool: return is_instance_valid(c))
	return _chunks.size()


## Removes every effect at once and ends any hitstop (scene change, tests).
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_chunks.clear()
	_decals.clear()
	_impact_bursts.clear()
	_hitstop_token += 1
	_hitstop_end = -1.0
	Engine.time_scale = 1.0


## A burst of a shot on the level (surface_impact()), kept in the ring of
## MAX_IMPACT_BURSTS: past it the oldest still alive is freed, like marks.
func _surface_burst(position: Vector3, direction: Vector3, color: Color, glow: bool, amount: int, speed: float, lifetime: float, spread_deg: float, gravity: float, size: float) -> void:
	_impact_bursts.append(_burst(position, direction, color, glow, amount, speed, lifetime, spread_deg, gravity, size))
	while _impact_bursts.size() > MAX_IMPACT_BURSTS:
		var oldest = _impact_bursts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## The emitter is turned so its +Y (the material's direction) points along
## [param direction]; that keeps the process materials shareable. Returns
## the burst.
func _burst(position: Vector3, direction: Vector3, color: Color, glow: bool, amount: int, speed: float, lifetime: float, spread_deg: float, gravity: float, size: float) -> GPUParticles3D:
	var up := direction if direction.length() > 0.01 else Vector3.UP
	var particles := burst_node(color, glow, amount, speed, lifetime, spread_deg, gravity, size)
	particles.transform = Transform3D(_basis_with_up(up), position)
	add_child(particles)
	particles.emitting = true
	_free_after(particles, lifetime + 0.5)
	return particles


## One particle burst (one-shot, spraying along its +Y), not placed, not
## added, not emitting yet.
func burst_node(color: Color, glow: bool, amount: int, speed: float, lifetime: float, spread_deg: float, gravity: float, size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.process_material = _process_material(color, speed, spread_deg, gravity)
	particles.draw_pass_1 = _particle_mesh(size, glow)
	return particles


## Shared particle behaviour, cached per parameter set. [param speed] is
## rounded to 0.5 m/s so overkill-dependent speeds reuse a few materials.
func _process_material(color: Color, speed: float, spread_deg: float, gravity: float) -> ParticleProcessMaterial:
	var rounded := snappedf(speed, 0.5)
	var key := "%s_%.1f_%.1f_%.1f" % [color.to_html(), rounded, spread_deg, gravity]
	if not _processes.has(key):
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = spread_deg
		process.initial_velocity_min = rounded * 0.4
		process.initial_velocity_max = rounded
		process.gravity = Vector3(0.0, -gravity, 0.0)
		process.scale_min = 0.6
		process.scale_max = 1.4
		process.color = color
		process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		process.collision_bounce = 0.15
		process.collision_friction = 0.7
		_processes[key] = process
	return _processes[key]


func _particle_mesh(size: float, glow: bool) -> Mesh:
	var key := "%.3f_%s" % [size, glow]
	if not _meshes.has(key):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		if glow:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(4.0, 4.0, 4.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		mesh.material = material
		_meshes[key] = mesh
	return _meshes[key]


func _solid_material(color: Color) -> StandardMaterial3D:
	var key := "solid_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.6
		_materials[key] = material
	return _materials[key]


func _glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow_" + color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
		_materials[key] = material
	return _materials[key]


## A mark of [param surface] (64 x 64): a dark hole and what is round it.
static func _make_mark(surface: StringName) -> ImageTexture:
	var size := 64
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = hash(surface)
	noise.frequency = 0.09
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half, y - half) / half
			var r := d.length()
			var angle := atan2(d.y, d.x)
			var rough := noise.get_noise_2d(x, y)
			var edge := noise.get_noise_1d(angle * 9.0) * 0.12
			var color := Color(0, 0, 0, 0)
			match surface:
				SCORCH:
					var soot := clampf(1.0 - (r + edge * 2.0 + rough * 0.15) / 0.95, 0.0, 1.0)
					var tone := Color(0.06, 0.045, 0.035).lerp(Color(0.2, 0.13, 0.08), clampf(r * 1.3, 0.0, 1.0))
					color = Color(tone.r, tone.g, tone.b, soot * soot * (0.85 + rough * 0.15))
				Surface.WOOD:
					# a long hole along the grain, pale splinters torn out round it
					var grain := Vector2(d.x * 0.62, d.y)
					var gr := grain.length()
					var splinter := maxf(1.0 - absf(d.y + rough * 0.25) / 0.16, 0.0) * maxf(1.0 - absf(d.x) / 0.95, 0.0)
					if gr < 0.26 + edge:
						color = Color(0.05, 0.035, 0.025, 1.0)
					elif splinter > 0.0 and gr < 0.85:
						color = Color(0.72, 0.56, 0.36, splinter * 0.8)
					elif gr < 0.42 + edge:
						color = Color(0.2, 0.13, 0.08, 0.7)
				Surface.METAL:
					if r < 0.2 + edge * 0.5:
						color = Color(0.08, 0.08, 0.09, 0.9)
					elif r < 0.42 + edge * 0.5:
						color = Color(0.78, 0.8, 0.84, 0.75 * (1.0 - (r - 0.2) / 0.25))
					elif r < 0.75:
						color = Color(0.25, 0.25, 0.27, 0.25 * (1.0 - r / 0.75))
				Surface.CARPET:
					var spot := clampf(1.0 - (r + rough * 0.35) / 0.7, 0.0, 1.0)
					color = Color(0.07, 0.05, 0.05, spot * 0.75)
				_:
					# stone: a dark hole, a pale chipped rim, hairline cracks
					var crack := 0.0
					for ray in 5:
						var dir := Vector2.from_angle(float(ray) * 1.27 + 0.4)
						var along := d.dot(dir)
						if along > 0.2 and along < 0.92:
							crack = maxf(crack, maxf(1.0 - absf(d.cross(dir) + rough * 0.06) / 0.035, 0.0))
					if r < 0.22 + edge:
						color = Color(0.04, 0.035, 0.03, 1.0)
					elif r < 0.55 + edge * 1.5:
						var chip := 0.55 + rough * 0.25
						color = Color(0.82, 0.8, 0.76, clampf(chip, 0.2, 0.8))
					elif crack > 0.0:
						color = Color(0.1, 0.09, 0.08, crack * 0.7)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _hole_texture() -> Texture2D:
	if _hole == null:
		var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				image.set_pixel(x, y, Color(0.05, 0.04, 0.04, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
		_hole = ImageTexture.create_from_image(image)
	return _hole


## Basis whose +Y is [param up] (decals project along their -Y).
static func _basis_with_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var reference := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := reference.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _free_after(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


func _shrink_and_free(body: Node3D, view: Node3D, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(body):
		return
	_chunks.erase(body)
	var tween := body.create_tween()
	tween.tween_property(view, "scale", Vector3.ONE * 0.01, 0.6)
	tween.tween_callback(body.queue_free)
