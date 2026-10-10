class_name SandboxArena
## Layout of the grey combat sandbox: a 44 x 44 m hall with four pillars,
## a jumpable dais, cover crates and a mezzanine along the north wall reached
## by a ramp. Also sets up the night lighting and fog.

const FLOOR := Color(0.42, 0.42, 0.45)
const WALL := Color(0.62, 0.6, 0.58)
const ACCENT := Color(0.55, 0.45, 0.35)
## Height of the mezzanine's walkable surface.
const MEZZANINE_Y := 3.75


static func build(region: NavigationRegion3D) -> void:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = Layers.WORLD
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 2.0
	# fine height cells and a low climb: the navmesh only joins the floor and
	# the ramp where a walker can really step over the edge, not along the
	# ramp's side (must match navigation/3d/default_cell_height)
	navmesh.cell_height = 0.1
	navmesh.agent_max_climb = 0.1
	navmesh.agent_max_slope = 40.0
	region.navigation_mesh = navmesh
	# floor and outer walls
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(44, 1, 44), FLOOR)
	Greybox.box(region, Vector3(0, 4, -22.5), Vector3(46, 8, 1), WALL)
	Greybox.box(region, Vector3(0, 4, 22.5), Vector3(46, 8, 1), WALL)
	Greybox.box(region, Vector3(-22.5, 4, 0), Vector3(1, 8, 44), WALL)
	Greybox.box(region, Vector3(22.5, 4, 0), Vector3(1, 8, 44), WALL)
	# pillars
	for x in [-8.0, 8.0]:
		for z in [-6.0, 6.0]:
			Greybox.box(region, Vector3(x, 4, z), Vector3(1.5, 8, 1.5), WALL)
	# central dais (0.6 m, jumpable) and cover crates
	Greybox.box(region, Vector3(0, 0.3, 0), Vector3(6, 0.6, 6), ACCENT)
	for crate in [Vector3(-14, 0.75, 10), Vector3(13, 0.75, 12), Vector3(-4, 0.75, -12), Vector3(12, 0.75, 2)]:
		Greybox.box(region, crate, Vector3(1.5, 1.5, 1.5), ACCENT)
	# mezzanine (z -22..-13) with a railing gap for the ramp at x 14..18
	Greybox.box(region, Vector3(0, MEZZANINE_Y - 0.25, -17.5), Vector3(44, 0.5, 9), FLOOR)
	Greybox.box(region, Vector3(-4, MEZZANINE_Y + 0.5, -13.1), Vector3(36, 1.0, 0.2), WALL)
	Greybox.box(region, Vector3(20, MEZZANINE_Y + 0.5, -13.1), Vector3(4, 1.0, 0.2), WALL)
	Greybox.ramp(region, Vector3(16, 0, -2), Vector3(16, MEZZANINE_Y, -13), 4.0, ACCENT)


static func add_lighting(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.8, 0.85, 1.0)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	parent.add_child(moon)
	for spot in [Vector3(-8, 6, -5), Vector3(8, 6, -5), Vector3(-8, 6, 7), Vector3(8, 6, 7)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = 1.6
		lamp.omni_range = 14.0
		lamp.shadow_enabled = true
		lamp.position = spot
		parent.add_child(lamp)
	# lets hit particles land on the floor and the mezzanine
	var particle_floor := GPUParticlesCollisionHeightField3D.new()
	particle_floor.size = Vector3(44, 12, 44)
	particle_floor.position = Vector3(0, 5, 0)
	particle_floor.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	parent.add_child(particle_floor)
