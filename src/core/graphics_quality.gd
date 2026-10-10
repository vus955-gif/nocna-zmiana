class_name GraphicsQuality
## The graphics presets (option "Jakość grafiki"): what each of Low /
## Medium / High / Ultra turns on, and applying it live - to the engine's
## global render settings, the window's viewport and every level already
## built (their environment, moon, shadowed lamps). Settings owns the
## chosen preset ([member current]); LevelLighting calls
## [method apply_level] on each level it lights.
## High is the look of the art guide (SDFGI, volumetric fog, SSR, SSAO +
## SSIL, soft shadows, MSAA 4x); Medium halves the expensive parts; Low
## drops global illumination and screen-space effects for a brighter
## ambient fill and FXAA; Ultra raises what the RTX-class cards can afford.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

## Groups the lighting puts nodes in for the presets.
const ENVIRONMENTS := &"quality_environments"
const FOG_VOLUMES := &"quality_fog_volumes"
const PROBES := &"quality_probes"
## GPU particles of the atmosphere (dust in the moonbeams, Egypt's sand):
## their amount follows the preset ("particles"), meta "base_amount".
const PARTICLES := &"quality_particles"
## Lamps with a designed shadow (LevelLighting.SHADOWED) and its rank meta.
const SHADOWED := &"designed_shadows"
const SHADOW_RANK := &"shadow_rank"
## Environment metadata: the ambient multiplier this preset applied (so a
## change keeps what the night did to the ambient, e.g. a blackout).
const AMBIENT_META := &"quality_ambient"

## Per preset. sdfgi: on / off; sdfgi_half: half-resolution GI; cascades;
## rays (RenderingServer ENV_SDFGI_RAY_COUNT_*); fog: froxel grid (x, depth);
## ssr_steps (0 = off); ssao / ssil: quality (-1 = off); aa: MSAA level
## (Viewport.MSAA_*), fxaa; shadow sizes; soft: shadow filter quality;
## moon: splits and distance - 100 m on every preset: indoors the moon may
## only reach the floor through the lanterns, and past its shadow distance
## it would light everything (a far hall seen down a corridor from the
## security room glowed blue at 45 m); two splits cost the same FPS at 100 m
## as at 45 m (118 / 117 FPS, RTX 2080 Ti, the hall fight); lamp_shadows: lamps whose shadow rank is below
## this keep it (0 = none, 1 = the hall's column lamps, 2 = all);
## ambient: multiplier of the recipe's ambient (fills in for the GI);
## render_scale: what choosing the preset sets the render scale to;
## particles: share of the atmosphere's motes (0 = none); probes:
## reflection probes on or off; cull_depth: rooms this many passages from
## the camera keep their lamps, motes and probes (RoomCuller; Floor I).
const PRESETS := {
	Quality.LOW: {
		"sdfgi": false, "sdfgi_half": true, "cascades": 3, "rays": RenderingServer.ENV_SDFGI_RAY_COUNT_8,
		"fog": Vector2i(64, 48), "fog_filter": false, "ssr_steps": 0, "ssao": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssil": -1,
		"aa": Viewport.MSAA_DISABLED, "fxaa": true, "positional_atlas": 2048, "directional_atlas": 2048,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "moon_splits": 2, "moon_distance": 100.0,
		"lamp_shadows": 0, "ambient": 2.2, "lod": 4.0, "render_scale": 0.8,
		"particles": 0.0, "probes": false, "cull_depth": 1,
	},
	Quality.MEDIUM: {
		"sdfgi": true, "sdfgi_half": true, "cascades": 3, "rays": RenderingServer.ENV_SDFGI_RAY_COUNT_8,
		"fog": Vector2i(96, 64), "fog_filter": true, "ssr_steps": 32, "ssao": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssil": -1,
		"aa": Viewport.MSAA_2X, "fxaa": false, "positional_atlas": 2048, "directional_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "moon_splits": 2, "moon_distance": 100.0,
		"lamp_shadows": 1, "ambient": 1.3, "lod": 2.0, "render_scale": 1.0,
		"particles": 0.5, "probes": true, "cull_depth": 2,
	},
	Quality.HIGH: {
		"sdfgi": true, "sdfgi_half": false, "cascades": 4, "rays": RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		"fog": Vector2i(160, 96), "fog_filter": true, "ssr_steps": 64, "ssao": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssil": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"aa": Viewport.MSAA_4X, "fxaa": false, "positional_atlas": 4096, "directional_atlas": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "moon_splits": 2, "moon_distance": 100.0,
		"lamp_shadows": 2, "ambient": 1.0, "lod": 1.0, "render_scale": 1.0,
		"particles": 1.0, "probes": true, "cull_depth": 2,
	},
	Quality.ULTRA: {
		"sdfgi": true, "sdfgi_half": false, "cascades": 4, "rays": RenderingServer.ENV_SDFGI_RAY_COUNT_32,
		"fog": Vector2i(192, 128), "fog_filter": true, "ssr_steps": 96, "ssao": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ssil": RenderingServer.ENV_SSIL_QUALITY_MEDIUM,
		"aa": Viewport.MSAA_4X, "fxaa": false, "positional_atlas": 8192, "directional_atlas": 8192,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "moon_splits": 4, "moon_distance": 100.0,
		"lamp_shadows": 2, "ambient": 1.0, "lod": 0.75, "render_scale": 1.0,
		"particles": 1.0, "probes": true, "cull_depth": 3,
	},
}
## Words in adapter names of older or weaker cards (lowercase): these start
## on Medium.
const MODEST_GPUS: Array[String] = ["gtx 9", "gtx 10", "gtx 16", "rx 4", "rx 5", "rx 6400", "rx 6500",
	"arc a3", " mx", "quadro", "vega", "radeon(tm) graphics", "iris", "uhd", "hd graphics"]

## The preset in use (Settings sets it; levels read it when they light up).
static var current: int = Quality.HIGH


static func preset(quality: int = -1) -> Dictionary:
	return PRESETS.get(quality if quality >= 0 else current, PRESETS[Quality.HIGH])


## A sensible first preset for this machine: Low on integrated or software
## GPUs, Medium on older cards, High otherwise (Ultra only by choice).
static func detect() -> int:
	if DisplayServer.get_name() == "headless":
		return Quality.HIGH
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_CPU, RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			return Quality.LOW
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	for word in MODEST_GPUS:
		if adapter.contains(word):
			return Quality.MEDIUM
	return Quality.HIGH


## Applies [param quality] everywhere: engine globals, the window's
## viewport, every level in [param tree].
static func apply_all(tree: SceneTree, quality: int) -> void:
	current = quality
	apply_globals()
	if tree == null:
		return
	apply_viewport(tree.root)
	for node in tree.get_nodes_in_group(ENVIRONMENTS):
		var world := node as WorldEnvironment
		if world != null and world.environment != null:
			apply_environment(world.environment)
	_apply_shadows(tree.get_nodes_in_group(SHADOWED), tree.get_nodes_in_group(&"moon"))
	_apply_atmosphere(tree.get_nodes_in_group(PARTICLES), tree.get_nodes_in_group(PROBES))


## Render settings shared by every viewport (shadow filters and atlas, fog
## grid, GI resolution, SDFGI rays, SSAO / SSIL / SSR quality).
static func apply_globals() -> void:
	var p := preset()
	var fog: Vector2i = p["fog"]
	RenderingServer.environment_set_volumetric_fog_volume_size(fog.x, fog.y)
	RenderingServer.environment_set_volumetric_fog_filter_active(p["fog_filter"])
	RenderingServer.gi_set_use_half_resolution(p["sdfgi_half"])
	RenderingServer.environment_set_sdfgi_ray_count(p["rays"])
	RenderingServer.directional_soft_shadow_filter_set_quality(p["soft"])
	RenderingServer.positional_soft_shadow_filter_set_quality(p["soft"])
	RenderingServer.directional_shadow_atlas_set_size(p["directional_atlas"], true)
	var ssao: int = p["ssao"]
	RenderingServer.environment_set_ssao_quality(maxi(ssao, 0) as RenderingServer.EnvironmentSSAOQuality, ssao < RenderingServer.ENV_SSAO_QUALITY_HIGH, 0.5, 2, 50.0, 300.0)
	var ssil: int = p["ssil"]
	RenderingServer.environment_set_ssil_quality(maxi(ssil, 0) as RenderingServer.EnvironmentSSILQuality, ssil < RenderingServer.ENV_SSIL_QUALITY_HIGH, 0.5, 4, 50.0, 300.0)
	var steps: int = p["ssr_steps"]
	RenderingServer.environment_set_ssr_half_size(steps < 96)


## Anti-aliasing, the lamp shadow atlas and mesh LOD of [param viewport].
static func apply_viewport(viewport: Viewport) -> void:
	if viewport == null:
		return
	var p := preset()
	viewport.msaa_3d = p["aa"]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = p["positional_atlas"]
	viewport.mesh_lod_threshold = p["lod"]


## The preset on one level environment (the lobby recipe's): GI, fog,
## screen-space effects, and the ambient fill that stands in for the GI
## (scaled relative to what the preset before it did, so a blackout's
## darker ambient stays darker).
static func apply_environment(env: Environment) -> void:
	var p := preset()
	env.sdfgi_enabled = p["sdfgi"]
	if env.sdfgi_cascades != int(p["cascades"]):
		env.sdfgi_cascades = p["cascades"]
	var steps: int = p["ssr_steps"]
	env.ssr_enabled = steps > 0
	if steps > 0:
		env.ssr_max_steps = steps
	env.ssao_enabled = int(p["ssao"]) >= 0
	env.ssil_enabled = int(p["ssil"]) >= 0
	var before: float = env.get_meta(AMBIENT_META, 1.0)
	var after: float = p["ambient"]
	env.ambient_light_energy *= after / before
	env.set_meta(AMBIENT_META, after)


## The preset's shadows on the lamps and the moon under [param root] (a
## level's lights), and its environment: called when a level lights up.
static func apply_level(root: Node) -> void:
	apply_globals()
	for node in root.get_children():
		if node is WorldEnvironment and node.is_in_group(ENVIRONMENTS) and (node as WorldEnvironment).environment != null:
			apply_environment((node as WorldEnvironment).environment)
	var lamps: Array[Node] = []
	var moons: Array[Node] = []
	var motes: Array[Node] = []
	var probes: Array[Node] = []
	for node in root.get_children():
		if node.is_in_group(SHADOWED):
			lamps.append(node)
		elif node is DirectionalLight3D:
			moons.append(node)
		elif node.is_in_group(PARTICLES):
			motes.append(node)
		elif node.is_in_group(PROBES):
			probes.append(node)
	_apply_shadows(lamps, moons)
	_apply_atmosphere(motes, probes)


## The preset's share of the motes (none on Low: hidden) and whether the
## reflection probes are on.
static func _apply_atmosphere(motes: Array[Node], probes: Array[Node]) -> void:
	var p := preset()
	var share: float = p.get("particles", 1.0)
	for node in motes:
		var particles := node as GPUParticles3D
		if particles == null:
			continue
		particles.amount_ratio = clampf(share, 0.0, 1.0)
		particles.visible = share > 0.0
		particles.emitting = share > 0.0
	for node in probes:
		(node as Node3D).visible = bool(p.get("probes", true))


static func _apply_shadows(lamps: Array[Node], moons: Array[Node]) -> void:
	var p := preset()
	var keep: int = p["lamp_shadows"]
	for node in lamps:
		var light := node as Light3D
		if light != null:
			light.shadow_enabled = int(light.get_meta(SHADOW_RANK, 1)) < keep
	for node in moons:
		var moon := node as DirectionalLight3D
		if moon == null:
			continue
		var four := int(p["moon_splits"]) >= 4
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if four else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		moon.directional_shadow_max_distance = p["moon_distance"]
		# two splits: the near one 20 m deep keeps the shafts through the
		# lanterns crisp; four: the recipe's fractions
		moon.directional_shadow_split_1 = 0.08 if four else 0.2
		moon.directional_shadow_split_2 = 0.2
		moon.directional_shadow_split_3 = 0.5
