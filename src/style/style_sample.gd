class_name StyleSample
extends Node3D
## Stage 1b style sample: a 12 x 10 m, 6 m high fragment of the sculpture
## gallery dressed with the Blender-made art. Polished marble floor with
## reflections, panelled walls with damask and cornice, tall arched windows
## letting moonlight shafts into volumetric fog, display cases, busts on
## pedestals, velvet ropes, a bench, a painting, warm lamps, a red emergency
## light and the finished wax figure. Everything is built in code.
## Room interior: x -6..6, z -5..5, floor y 0, ceiling y 6; windows north.
## Walk around with the guard (with_player) or drive a camera from a script.

const ROOM_W := 12.0
const ROOM_D := 10.0
const ROOM_H := 6.0
## Centres of the two tall windows in the north wall.
const WINDOW_XS: Array[float] = [-4.0, 4.0]
const WALL_BACK := 0.6
## Baked texture sets whose glow belongs to the warm lamps.
const LAMP_MATERIALS: Array[String] = ["sconce", "painting", "display_case"]
const NIGHT_SKY := preload("res://src/style/night_sky.gdshader")
## Where the wax figure stands and which way it faces (towards the entrance).
const FIGURE_AT := Vector3(3.0, 0.0, 2.0)
const FIGURE_YAW := 210.0

@export var with_player: bool = true

var env: Environment
var moon: DirectionalLight3D
var fog: FogVolume
## Warm lamps (sconces, picture light, case lights): the "main lights".
var main_lights: Array[Light3D] = []
var emergency: OmniLight3D
var figure: Node3D
var player: Player
var probe: ReflectionProbe


func _ready() -> void:
	_build_shell()
	_build_props()
	_build_lighting()
	if with_player:
		# same texture sharpness as the screenshot runner's 1080p view
		get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X
		player = Player.new()
		player.position = Vector3(4.2, 0.05, 4.0)
		add_child(player)
		player.head.rotation.y = deg_to_rad(50.0)
		add_child(PauseMenu.new())   # Esc frees the cursor (GameInput owns it)
		GameInput.set_gameplay_scene(true)


func _exit_tree() -> void:
	if with_player:
		GameInput.set_gameplay_scene(false)


## Mid-range fallback: no SDFGI and SSIL (ambient + SSAO only), coarser fog
## froxels, shorter SSR rays, cheaper soft shadows. Keeps the look (fog
## shafts, reflections, bloom), loses the soft warm bounce light.
static func apply_low_preset(environment: Environment) -> void:
	environment.sdfgi_enabled = false
	environment.ssil_enabled = false
	environment.ssr_max_steps = 32
	environment.ambient_light_energy = 0.2
	RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)


## Switches the warm lamps off (blackout) or on; moon and emergency stay.
func set_main_lights(on: bool) -> void:
	for light in main_lights:
		light.visible = on
	for mat_name in LAMP_MATERIALS:
		var mat := ArtLibrary.material(mat_name) as BaseMaterial3D
		if mat != null and mat.emission_enabled:
			mat.emission_energy_multiplier = (ArtLibrary.EXTRAS.get(mat_name, {}) as Dictionary).get("emission", 2.0) if on else 0.0


# --- architecture ---------------------------------------------------------

func _build_shell() -> void:
	var floor_mat := ArtLibrary.tiled("marble_floor", Vector2(4.0, 4.0))
	_solid(Vector3(0, -0.1, 0), Vector3(ROOM_W + 2.0, 0.2, ROOM_D + 2.0), floor_mat)
	# roof slab 2 cm above the coffer fields (no z-fighting), then the coffers
	_solid(Vector3(0, ROOM_H + 0.12, 0), Vector3(ROOM_W + 2.0, 0.2, ROOM_D + 2.0), ArtLibrary.tiled("plaster", Vector2(2.0, 2.0)))
	if ResourceLoader.exists(ArtLibrary.MODEL_PATH % "ceiling_2m"):
		for ix in int(ROOM_W / 2.0):
			for iz in int(ROOM_D / 2.0):
				var coffer := ArtLibrary.model("ceiling_2m")
				coffer.position = Vector3(-ROOM_W * 0.5 + ix * 2.0, ROOM_H, -ROOM_D * 0.5 + (iz + 1) * 2.0)
				add_child(coffer)
	_wall_run(Vector3(-6, 0, -5), 0.0, ["wall_window_4m", "wall_4m", "wall_window_4m"])
	_wall_run(Vector3(6, 0, 5), 180.0, ["wall_4m", "wall_4m", "wall_4m"])
	_wall_run(Vector3(-6, 0, 5), 90.0, ["wall_4m", "wall_4m", "wall_2m"])
	_wall_run(Vector3(6, 0, -5), -90.0, ["wall_4m", "wall_4m", "wall_2m"])
	# solid backing behind the modules: blocks moonlight and GI leaks, collides
	# (kept 2 cm behind the wall plane so it never z-fights with the wallpaper)
	var back := ArtLibrary.tiled("plaster", Vector2(2.0, 2.0))
	var t := WALL_BACK
	var gap := 0.02
	_solid(Vector3(-ROOM_W * 0.5 - gap - t * 0.5, ROOM_H * 0.5, 0), Vector3(t, ROOM_H, ROOM_D + 2 * t), back)
	_solid(Vector3(ROOM_W * 0.5 + gap + t * 0.5, ROOM_H * 0.5, 0), Vector3(t, ROOM_H, ROOM_D + 2 * t), back)
	_solid(Vector3(0, ROOM_H * 0.5, ROOM_D * 0.5 + gap + t * 0.5), Vector3(ROOM_W, ROOM_H, t), back)
	var z := -ROOM_D * 0.5 - gap - t * 0.5
	var edges: Array[float] = [-ROOM_W * 0.5]
	for x in WINDOW_XS:
		edges.append(x - 1.05)
		edges.append(x + 1.05)
	edges.append(ROOM_W * 0.5)
	for i in [0, 2, 4]:
		_solid(Vector3((edges[i] + edges[i + 1]) * 0.5, ROOM_H * 0.5, z), Vector3(edges[i + 1] - edges[i], ROOM_H, t), back)
	for x in WINDOW_XS:
		_solid(Vector3(x, 0.65, z), Vector3(2.1, 1.3, t), back)
		_solid(Vector3(x, (4.85 + ROOM_H) * 0.5, z), Vector3(2.1, ROOM_H - 4.85, t), back)


## Slow dust motes: tiny lit (not glowing) specks, so they only show where a
## light (the moon shafts, the flashlight) actually hits them.
func _build_dust() -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(ROOM_W * 0.5 - 0.3, ROOM_H * 0.3, ROOM_D * 0.5 - 0.3)
	process.direction = Vector3(0.3, 0.2, 0.1)
	process.spread = 180.0
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.05
	process.gravity = Vector3(0.0, -0.004, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.3
	process.turbulence_noise_scale = 4.0
	process.scale_min = 0.6
	process.scale_max = 1.4
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.45, 0.47, 0.52)
	mat.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.008, 0.008)
	quad.material = mat
	var dust := GPUParticles3D.new()
	dust.amount = 700
	dust.lifetime = 40.0
	dust.preprocess = 40.0
	dust.process_material = process
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visibility_aabb = AABB(Vector3(-ROOM_W * 0.5, -ROOM_H * 0.5, -ROOM_D * 0.5), Vector3(ROOM_W, ROOM_H, ROOM_D))
	dust.position = Vector3(0, ROOM_H * 0.35, 0)
	add_child(dust)


## Places wall modules side by side from [param origin] along the module's
## local +X, decorated side facing the room.
func _wall_run(origin: Vector3, yaw_deg: float, modules: Array[String]) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var offset := 0.0
	for module_name in modules:
		if not ResourceLoader.exists(ArtLibrary.MODEL_PATH % module_name):
			push_warning("style sample: model %s not generated yet" % module_name)
			continue
		var node := ArtLibrary.model(module_name)
		node.transform = Transform3D(basis, origin + basis.x * offset)
		add_child(node)
		_double_sided_shadows(node)
		offset += 2.0 if module_name.ends_with("2m") else 4.0


func _double_sided_shadows(node: Node) -> void:
	for view in node.find_children("*", "MeshInstance3D", true, false):
		(view as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


func _solid(center: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	body.add_child(view)
	add_child(body)
	return body


# --- props ------------------------------------------------------------------

func _build_props() -> void:
	for x in WINDOW_XS:
		_prop("window", Vector3(x, 0, -5.0))
	# busts on pedestals along the side walls, facing the room
	var busts := [[Vector3(-5.1, 0, -2.3), 90.0, "bust"], [Vector3(-5.1, 0, 1.7), 90.0, "bust_bronze"],
		[Vector3(5.1, 0, -2.3), -90.0, "bust"]]
	for entry in busts:
		_prop("pedestal", entry[0], entry[1], Vector3(0.52, 1.1, 0.52))
		var swap := {} if entry[2] == "bust" else {"bust": entry[2]}
		_prop("bust", entry[0] + Vector3(0, 1.1, 0), entry[1] + 15.0, Vector3.ZERO, swap)
	# columns framing the painting between the windows
	for x in [-2.0, 2.0]:
		_prop("column", Vector3(x, 0, -3.9), 0.0, Vector3(0.7, 6.0, 0.7))
	_prop("painting", Vector3(0, 2.95, -5.0))
	_prop("stanchion", Vector3(0, 0, -3.7), 0.0, Vector3(2.0, 1.0, 0.3))
	_prop("bench", Vector3(0, 0, 2.6), 180.0, Vector3(1.6, 0.5, 0.5))
	for entry in [[Vector3(-2.3, 0, 0.2), 20.0, true], [Vector3(2.4, 0, -0.6), -15.0, false]]:
		var case_node := _prop("display_case", entry[0], entry[1], Vector3(1.1, 1.6, 0.8))
		if case_node == null:
			continue
		_case_light(case_node)
		if entry[2]:
			var crystal := ArtLibrary.model("crystal")
			crystal.position = Vector3(0, 0.93, 0.02)
			crystal.rotation.y = deg_to_rad(-20.0)
			case_node.add_child(crystal)
	for side in [-1.0, 1.0]:
		for z in [-0.3, 3.7]:
			var sconce := _prop("sconce", Vector3(side * 6.0, 2.55, z), -90.0 * side)
			if sconce != null:
				_no_shadows(sconce)
	_prop("emergency_light", Vector3(-6.0, 3.3, -4.2), 90.0)
	figure = _prop("wax_figure", FIGURE_AT, FIGURE_YAW)
	if figure != null:
		_pose_figure(figure)


## Mid-lurch pose, done on the model's jointed parts (the same pivots the
## game can animate and gib): right arm reaching, head cocked.
func _pose_figure(node: Node3D) -> void:
	var parts := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		parts[child.name] = child
	if parts.has("arm_r"):
		(parts["arm_r"] as Node3D).rotation = Vector3(0.95, 0.0, 0.1)
	if parts.has("arm_l"):
		(parts["arm_l"] as Node3D).rotation = Vector3(0.45, 0.0, -0.08)
	if parts.has("head"):
		(parts["head"] as Node3D).rotation = Vector3(0.12, -0.2, 0.22)
	if parts.has("hat"):
		# the hat rides on the head: same turn about the neck pivot
		var hat := parts["hat"] as Node3D
		var head := parts["head"] as Node3D
		var offset := hat.position - head.position
		hat.position = head.position + head.basis * offset
		hat.basis = head.basis


func _case_light(case_node: Node3D) -> void:
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.8, 0.55)
	spot.light_energy = 1.6
	spot.spot_range = 1.4
	spot.spot_angle = 55.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 0.0
	spot.position = Vector3(0, 1.46, 0.22)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	case_node.add_child(spot)
	main_lights.append(spot)


func _no_shadows(node: Node) -> void:
	for view in node.find_children("*", "MeshInstance3D", true, false):
		(view as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Places a model if it has been generated; adds a simple box collider.
func _prop(model_name: String, at: Vector3, yaw_deg: float = 0.0, collider_size: Vector3 = Vector3.ZERO, swap: Dictionary = {}) -> Node3D:
	if not ResourceLoader.exists(ArtLibrary.MODEL_PATH % model_name):
		push_warning("style sample: model %s not generated yet" % model_name)
		return null
	var node := ArtLibrary.model(model_name, swap)
	node.position = at
	node.rotation.y = deg_to_rad(yaw_deg)
	add_child(node)
	if collider_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = collider_size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = collider_size.y * 0.5
		body.add_child(collider)
		node.add_child(body)
	return node


# --- light ------------------------------------------------------------------

func _build_lighting() -> void:
	env = Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = NIGHT_SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.38, 0.6)
	env.ambient_light_energy = 0.12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.15
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.1
	env.sdfgi_cascades = 4
	env.sdfgi_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.95)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_gi_inject = 0.25
	env.volumetric_fog_ambient_inject = 0.0
	# finer froxels than the default 64 x 64: crisp shafts through the glazing bars
	RenderingServer.environment_set_volumetric_fog_volume_size(128, 96)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# the haze lives only inside the gallery, so the windows show the night sky
	fog = FogVolume.new()
	fog.size = Vector3(ROOM_W, ROOM_H, ROOM_D)
	fog.position = Vector3(0, ROOM_H * 0.5, 0)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.022
	fog_mat.albedo = Color(0.78, 0.83, 0.95)
	fog_mat.edge_fade = 0.05
	fog.material = fog_mat
	add_child(fog)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.67, 1.0)
	moon.light_energy = 2.2
	moon.light_volumetric_fog_energy = 9.0
	moon.shadow_enabled = true
	moon.light_angular_distance = 0.3
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, Vector3(0.25, -0.55, 0.8), Vector3.UP)

	# sconces: the light sits in the tulip shade (the fixture casts no shadow)
	for side in [-1.0, 1.0]:
		for z in [-0.3, 3.7]:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.7, 0.42)
			lamp.light_energy = 1.6
			lamp.omni_range = 6.5
			lamp.omni_attenuation = 1.3
			lamp.shadow_enabled = true
			lamp.light_volumetric_fog_energy = 0.15
			lamp.position = Vector3(side * 5.72, 2.8, z)
			add_child(lamp)
			main_lights.append(lamp)
	# picture light washing the painting from above
	var picture := SpotLight3D.new()
	picture.light_color = Color(1.0, 0.78, 0.5)
	picture.light_energy = 5.0
	picture.spot_range = 3.2
	picture.spot_angle = 58.0
	picture.shadow_enabled = true
	picture.light_volumetric_fog_energy = 0.3
	picture.position = Vector3(0, 3.79, -4.66)
	add_child(picture)
	picture.look_at(Vector3(0, 2.75, -5.0), Vector3.UP)
	main_lights.append(picture)

	emergency = OmniLight3D.new()
	emergency.light_color = Color(1.0, 0.12, 0.08)
	emergency.light_energy = 2.0
	emergency.omni_range = 5.0
	emergency.shadow_enabled = true
	emergency.light_volumetric_fog_energy = 0.6
	emergency.position = Vector3(-5.8, 3.3, -4.2)
	add_child(emergency)

	_build_dust()

	probe = ReflectionProbe.new()
	probe.size = Vector3(ROOM_W, ROOM_H, ROOM_D)
	probe.position = Vector3(0, ROOM_H * 0.5, 0)
	probe.origin_offset = Vector3(0, -1.4, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
