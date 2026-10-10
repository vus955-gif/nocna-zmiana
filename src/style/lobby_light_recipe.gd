class_name LobbyLightRecipe
## The lighting recipe of the style sample (src/style/style_sample.gd),
## scaled up to the lobby: one environment for the whole building (SDFGI
## sized for a 36 x 44 x 14 m hall), a FogVolume and a ReflectionProbe per
## room, the moon aimed down the hall's skylights, and per-room light budgets
## (which lamps may cast shadows, how far they fade, how much they light the
## fog). Data plus small factories; not wired into the level: LevelLighting
## (or the preview, src/style/lobby_kit_preview.gd) calls these.
##
## The rule that makes it work, from the sample: the moon lights the fog 9x,
## lamps 0.15-0.6x. When lamps light the haze too, the room turns milky and
## the moon shafts vanish.

const NIGHT_SKY := preload("res://src/style/night_sky.gdshader")

## Environment for every room of the lobby.
const ENVIRONMENT := {
	"ambient_color": Color(0.3, 0.38, 0.6),
	"ambient_energy": 0.1,
	"exposure": 1.0,
	# screen-space reflections on the marble; longer rays than the sample
	# (the hall floor is 44 m long)
	"ssr_max_steps": 96,
	"ssr_fade_in": 0.1,
	"ssr_fade_out": 2.0,
	"ssr_depth_tolerance": 0.2,
	"ssao_radius": 1.0,
	"ssao_intensity": 1.8,
	"ssao_power": 1.4,
	"ssil_radius": 5.0,
	"ssil_intensity": 0.8,
	# SDFGI: 4 cascades from 0.15 m cells cover about 150 m, the whole
	# building from anywhere in it, cascade 0 about 19 m around the camera
	# (most of a wing, half the hall). y scale 75 %: the hall is 14 m tall.
	"sdfgi_cascades": 4,
	"sdfgi_min_cell_size": 0.15,
	"sdfgi_y_scale": Environment.SDFGI_Y_SCALE_75_PERCENT,
	"sdfgi_energy": 1.0,
	"sdfgi_bounce_feedback": 0.5,
	"glow_intensity": 0.7,
	"glow_bloom": 0.04,
	"glow_hdr_threshold": 1.0,
	# fog only inside FogVolumes; 40 m of froxels for the long hall views
	"fog_albedo": Color(0.75, 0.8, 0.95),
	"fog_anisotropy": 0.6,
	"fog_length": 40.0,
	"fog_detail_spread": 1.6,
	"fog_gi_inject": 0.08,
	"fog_volume_size": Vector2i(160, 90),
	"fog_volume_depth": 96,
}
## The moon: cold, strong in the fog, aimed so its shafts fall through the
## three roof lanterns onto the T-Rex and the floor (steep, a little from
## the south-east). Direction = where the light travels.
const MOON := {
	"color": Color(0.55, 0.67, 1.0),
	"energy": 2.4,
	"fog_energy": 9.0,
	"direction": Vector3(-0.28, -0.9, -0.33),
	"angular_distance": 0.3,
	"shadow_max_distance": 70.0,
	"shadow_splits": Vector3(0.08, 0.2, 0.5),
}
## Per room: FogVolume density and colour (dust in the air), the reflection
## probe (marble and glass rooms), how many lamps may cast shadows, the
## fade distances of lamps, and how much lamps light the fog.
const ROOMS := {
	&"hall": {"fog": 0.013, "fog_albedo": Color(0.78, 0.82, 0.95), "probe": true, "probe_offset": Vector3(0, -4.0, 0),
		"shadowed": 6, "fade_begin": 40.0, "lamp_fog": 0.15},
	&"gallery": {"fog": 0.018, "fog_albedo": Color(0.8, 0.82, 0.92), "probe": true, "probe_offset": Vector3(0, -2.0, 0),
		"shadowed": 2, "fade_begin": 30.0, "lamp_fog": 0.2},
	&"armory": {"fog": 0.022, "fog_albedo": Color(0.84, 0.8, 0.74), "probe": false, "shadowed": 2,
		"fade_begin": 30.0, "lamp_fog": 0.25},
	&"diorama": {"fog": 0.014, "fog_albedo": Color(0.8, 0.86, 0.9), "probe": false, "shadowed": 2,
		"fade_begin": 30.0, "lamp_fog": 0.2},
	&"corridor_w": {"fog": 0.012, "fog_albedo": Color(0.8, 0.84, 0.86), "probe": false, "shadowed": 0,
		"fade_begin": 20.0, "lamp_fog": 0.3},
	&"corridor_e": {"fog": 0.012, "fog_albedo": Color(0.8, 0.84, 0.86), "probe": false, "shadowed": 0,
		"fade_begin": 20.0, "lamp_fog": 0.3},
	&"staff_corridor": {"fog": 0.008, "fog_albedo": Color(0.8, 0.84, 0.86), "probe": false, "shadowed": 0,
		"fade_begin": 16.0, "lamp_fog": 0.3},
	&"security": {"fog": 0.006, "fog_albedo": Color(0.82, 0.84, 0.86), "probe": false, "shadowed": 1,
		"fade_begin": 16.0, "lamp_fog": 0.3},
	&"closet": {"fog": 0.03, "fog_albedo": Color(0.85, 0.8, 0.72), "probe": false, "shadowed": 1,
		"fade_begin": 12.0, "lamp_fog": 0.5},
}
## Lights the layout does not have and the kit asks for (no shadows, little
## fog): in the hall, warm uplights hidden behind the balcony balustrade
## that graze the upper storey (ashlar, pilasters, entablature) - without
## them everything above 6 m is black; in the diorama, a wash on the painted
## backdrop from cove spots under the valance (three along each long wall,
## two on the far wall), so the painting reads at night; in the armory,
## spots under the beams on the banners and the weapon racks (the rubble
## walls drink the ceiling lamps); in the gallery, washes on the long walls
## for the portraits and the scenes over them.
const EXTRA_LIGHTS := [
	{"room": &"hall", "position": Vector3(-14.6, 6.25, -15.0), "direction": Vector3(-0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(-14.6, 6.25, -7.0), "direction": Vector3(-0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(-14.6, 6.25, 1.0), "direction": Vector3(-0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(14.6, 6.25, -15.0), "direction": Vector3(0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(14.6, 6.25, -7.0), "direction": Vector3(0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(14.6, 6.25, 1.0), "direction": Vector3(0.6, 1.0, 0.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(-7.0, 6.25, -18.6), "direction": Vector3(0.0, 1.0, -0.55), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"hall", "position": Vector3(7.0, 6.25, -18.6), "direction": Vector3(0.0, 1.0, -0.55), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 11.0, "angle": 50.0},
	{"room": &"diorama", "position": Vector3(-11.0, 7.4, 27.5), "direction": Vector3(-0.55, -0.45, 0.25), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(-11.0, 7.4, 35.0), "direction": Vector3(-0.6, -0.45, 0.0), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(-11.0, 7.4, 41.0), "direction": Vector3(-0.55, -0.45, -0.25), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(11.0, 7.4, 27.5), "direction": Vector3(0.55, -0.45, 0.25), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(11.0, 7.4, 35.0), "direction": Vector3(0.6, -0.45, 0.0), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(11.0, 7.4, 41.0), "direction": Vector3(0.55, -0.45, -0.25), "color": Color(1.0, 0.86, 0.66), "energy": 1.8, "range": 14.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(-4.5, 7.4, 40.5), "direction": Vector3(-0.1, -0.45, 0.6), "color": Color(0.82, 0.88, 1.0), "energy": 1.6, "range": 12.0, "angle": 75.0},
	{"room": &"diorama", "position": Vector3(4.5, 7.4, 40.5), "direction": Vector3(0.1, -0.45, 0.6), "color": Color(0.82, 0.88, 1.0), "energy": 1.6, "range": 12.0, "angle": 75.0},
	{"room": &"armory", "position": Vector3(34.0, 6.3, -5.0), "direction": Vector3(6.0, -2.8, -3.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 12.0, "angle": 65.0},
	{"room": &"armory", "position": Vector3(34.0, 6.3, 5.0), "direction": Vector3(6.0, -2.8, 3.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 12.0, "angle": 65.0},
	{"room": &"armory", "position": Vector3(26.0, 6.3, -5.0), "direction": Vector3(-6.0, -2.8, -2.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 12.0, "angle": 65.0},
	{"room": &"armory", "position": Vector3(26.0, 6.3, 5.0), "direction": Vector3(-6.0, -2.8, 2.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.6, "range": 12.0, "angle": 65.0},
	{"room": &"armory", "position": Vector3(30.0, 6.3, -9.0), "direction": Vector3(0.0, -4.8, -5.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.4, "range": 10.0, "angle": 75.0},
	{"room": &"armory", "position": Vector3(31.0, 6.3, 9.0), "direction": Vector3(0.0, -4.8, 5.0), "color": Color(1.0, 0.8, 0.56), "energy": 1.4, "range": 10.0, "angle": 75.0},
	{"room": &"gallery", "position": Vector3(-33.0, 6.4, -9.0), "direction": Vector3(0.0, -3.4, -5.0), "color": Color(1.0, 0.82, 0.6), "energy": 1.3, "range": 11.0, "angle": 65.0},
	{"room": &"gallery", "position": Vector3(-33.0, 6.4, 9.0), "direction": Vector3(0.0, -3.4, 5.0), "color": Color(1.0, 0.82, 0.6), "energy": 1.3, "range": 11.0, "angle": 65.0},
	{"room": &"gallery", "position": Vector3(-27.0, 6.4, -9.0), "direction": Vector3(0.0, -3.4, -5.0), "color": Color(1.0, 0.82, 0.6), "energy": 1.3, "range": 11.0, "angle": 65.0},
	{"room": &"gallery", "position": Vector3(-27.0, 6.4, 9.0), "direction": Vector3(0.0, -3.4, 5.0), "color": Color(1.0, 0.82, 0.6), "energy": 1.3, "range": 11.0, "angle": 65.0},
]

## Light fittings by LevelKit fixture id: which cast shadows (when the
## room's budget allows), how strongly they light the fog, and an energy
## multiplier over the layout's value (sconces must paint warm pools on
## the dark limestone of the hall). Emergency lamps always light the fog a little more (red haze
## round the exits reads from afar).
const FIXTURE_LIGHTS := {
	&"column_lamp": {"shadow": true, "fog": 0.15, "energy": 1.25},
	&"sconce": {"shadow": false, "fog": 0.12, "energy": 1.6},
	&"ceiling_lamp": {"shadow": false, "fog": 0.15},
	&"tube_lamp": {"shadow": false, "fog": 0.3},
	&"desk_lamp": {"shadow": true, "fog": 0.2},
	&"bulb": {"shadow": true, "fog": 0.5},
	&"exit_sign": {"shadow": false, "fog": 0.6},
	&"emergency_lamp": {"shadow": false, "fog": 0.6},
}


## The shared environment (night sky behind the windows and lanterns);
## [param e]: another recipe's environment (Floor1LightRecipe).
static func make_environment(e: Dictionary = ENVIRONMENT) -> WorldEnvironment:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = NIGHT_SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = e["ambient_color"]
	env.ambient_light_energy = e["ambient_energy"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = e["exposure"]
	env.ssr_enabled = true
	env.ssr_max_steps = e["ssr_max_steps"]
	env.ssr_fade_in = e["ssr_fade_in"]
	env.ssr_fade_out = e["ssr_fade_out"]
	env.ssr_depth_tolerance = e["ssr_depth_tolerance"]
	env.ssao_enabled = true
	env.ssao_radius = e["ssao_radius"]
	env.ssao_intensity = e["ssao_intensity"]
	env.ssao_power = e["ssao_power"]
	env.ssil_enabled = true
	env.ssil_radius = e["ssil_radius"]
	env.ssil_intensity = e["ssil_intensity"]
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = e["sdfgi_cascades"]
	env.sdfgi_min_cell_size = e["sdfgi_min_cell_size"]
	env.sdfgi_y_scale = e["sdfgi_y_scale"]
	env.sdfgi_energy = e["sdfgi_energy"]
	env.sdfgi_bounce_feedback = e["sdfgi_bounce_feedback"]
	env.glow_enabled = true
	env.glow_intensity = e["glow_intensity"]
	env.glow_bloom = e["glow_bloom"]
	env.glow_hdr_threshold = e["glow_hdr_threshold"]
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = e["fog_albedo"]
	env.volumetric_fog_anisotropy = e["fog_anisotropy"]
	env.volumetric_fog_length = e["fog_length"]
	env.volumetric_fog_detail_spread = e["fog_detail_spread"]
	env.volumetric_fog_gi_inject = e["fog_gi_inject"]
	env.volumetric_fog_ambient_inject = 0.0
	var size: Vector2i = e["fog_volume_size"]
	RenderingServer.environment_set_volumetric_fog_volume_size(size.x, e["fog_volume_depth"])
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	return world


static func make_moon(m: Dictionary = MOON) -> DirectionalLight3D:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = m["color"]
	moon.light_energy = m["energy"]
	moon.light_volumetric_fog_energy = m["fog_energy"]
	moon.light_angular_distance = m["angular_distance"]
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = m["shadow_max_distance"]
	var splits: Vector3 = m["shadow_splits"]
	moon.directional_shadow_split_1 = splits.x
	moon.directional_shadow_split_2 = splits.y
	moon.directional_shadow_split_3 = splits.z
	var dir: Vector3 = (m["direction"] as Vector3).normalized()
	moon.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	return moon


## Dust in one room: a FogVolume filling [param box] (world AABB of the
## room's air), density and colour from [param rooms] (default ROOMS); a
## room's "fog_noise" (0..1) breaks the dust into slow wisps.
static func make_fog(room: StringName, box: AABB, rooms: Dictionary = ROOMS) -> FogVolume:
	var r: Dictionary = rooms.get(room, ROOMS[&"corridor_w"])
	var fog := FogVolume.new()
	fog.name = "Fog_%s" % room
	fog.size = box.size
	fog.position = box.get_center()
	var mat := FogMaterial.new()
	mat.density = r["fog"]
	mat.albedo = r["fog_albedo"]
	mat.edge_fade = 0.05
	if float(r.get("fog_noise", 0.0)) > 0.0:
		mat.density_texture = fog_noise()
		mat.density *= 1.0 + float(r["fog_noise"]) * 0.5
	fog.material = mat
	return fog


static var _fog_noise: NoiseTexture3D = null


## A tiling 3D noise for wispy dust (shared; FogMaterial.density_texture).
static func fog_noise() -> NoiseTexture3D:
	if _fog_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.045
		noise.fractal_octaves = 3
		_fog_noise = NoiseTexture3D.new()
		_fog_noise.width = 64
		_fog_noise.height = 32
		_fog_noise.depth = 64
		_fog_noise.seamless = true
		_fog_noise.normalize = true
		_fog_noise.noise = noise
	return _fog_noise


## Box-projected reflection probe of a marble room (null if the room has
## none): updated once, interior (no sky), capture point lowered toward the
## floor that reflects.
static func make_probe(room: StringName, box: AABB, rooms: Dictionary = ROOMS) -> ReflectionProbe:
	var r: Dictionary = rooms.get(room, {})
	if not r.get("probe", false):
		return null
	var probe := ReflectionProbe.new()
	probe.name = "Probe_%s" % room
	probe.size = box.size
	probe.position = box.get_center()
	probe.origin_offset = r.get("probe_offset", Vector3.ZERO)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.max_distance = maxf(box.size.x, box.size.z) * 1.5
	return probe


## Applies the fixture rules and the room budget to a light: shadow only
## while the room still has shadow budget ([param used] = shadows placed
## so far in that room), fog energy, distance fade.
static func tune(light: Light3D, fixture: StringName, room: StringName, used: int, rooms: Dictionary = ROOMS, fixtures: Dictionary = FIXTURE_LIGHTS) -> bool:
	var r: Dictionary = rooms.get(room, ROOMS[&"corridor_w"])
	var f: Dictionary = fixtures.get(fixture, {"shadow": false, "fog": 0.2})
	var shadow: bool = f["shadow"] and used < int(r["shadowed"])
	light.shadow_enabled = shadow
	# the room caps how much its lamps light the dust - not the exit signs,
	# the red lamps and the moon (their haze is the point)
	var uncapped: bool = fixture == &"emergency_lamp" or fixture == &"exit_sign" or f.get("uncapped", false)
	light.light_volumetric_fog_energy = float(f["fog"]) if uncapped else minf(float(f["fog"]), float(r["lamp_fog"]))
	light.light_energy *= float(f.get("energy", 1.0))
	if not uncapped:
		# a room may light its lamps brighter than the plan (the basement's tubes)
		light.light_energy *= float(r.get("lamp_energy", 1.0))
	light.distance_fade_enabled = true
	light.distance_fade_begin = r["fade_begin"]
	light.distance_fade_length = 10.0
	light.distance_fade_shadow = float(r["fade_begin"]) * 0.6
	return shadow


## Mid-range fallback, as StyleSample.apply_low_preset: no SDFGI / SSIL,
## coarser fog, shorter SSR, softer shadows.
static func apply_low_preset(env: Environment) -> void:
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.ssr_max_steps = 32
	env.ambient_light_energy = 0.2
	RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
