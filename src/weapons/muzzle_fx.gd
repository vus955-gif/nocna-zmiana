class_name MuzzleFx
extends Node3D
## What leaves a first-person weapon's muzzle and breech when it fires
## (plan 2026-10-19-gun-feel), from its FeelProfile: a star of fire (a
## second, smaller one ahead of it, so a big flash reads as a burst out of
## the barrel), puffs of smoke and casings thrown out of the breech. One per
## weapon view, under the WeaponHolder (the guard's view space: -Z ahead,
## no scale), kept on the view's Muzzle marker. The flash is drawn on the
## first-person layer with the viewmodel's field of view, like the weapon;
## smoke and casings are left in the world where the muzzle was on screen
## (WeaponHolder.on_screen_like_the_view), so they hang and fall there as
## the guard moves on - drawn as world things (true depth and field of
## view) but on the first-person layer too, so no CCTV camera shows them.
## The muzzle's light on the room is Fx.flash (WeaponHolder).

## The second star sits this far ahead (in flash sizes) at this size.
const BURST_AHEAD := 0.55
const BURST_SCALE := 0.6
## Casings look this much bigger than their profile size (the weapons are
## drawn big and chunky; real-size brass would vanish next to them).
const CASING_SCALE := 1.3
const CASING_LIFETIME := 0.9
const SMOKE_LIFETIME := 0.9
## Bursts of each kind kept in turn, so a quick run of shots never cuts
## the last one's casings or smoke short.
const POOL := 4

var profile: FeelProfile
## The weapon's view (its "Muzzle" marker is followed).
var view: Node3D
## Flashes and casings so far (tests).
var flashes: int = 0
var casings_thrown: int = 0

var _holder: Node3D
var _star: MeshInstance3D
var _burst: MeshInstance3D
var _flash_left: float = 0.0
var _smoke: Array[GPUParticles3D] = []
var _casings: Array[GPUParticles3D] = []
var _next_smoke: int = 0
var _next_casing: int = 0

static var _quad: QuadMesh = null
static var _star_texture: Texture2D = null
static var _flash_materials: Dictionary = {}
static var _casing_meshes: Dictionary = {}


## A MuzzleFx for [param weapon_view] under [param holder].
static func attach(holder: Node3D, weapon_view: Node3D, feel: FeelProfile) -> MuzzleFx:
	var fx := MuzzleFx.new()
	fx.name = "MuzzleFx_" + String(weapon_view.name)
	fx.profile = feel
	fx.view = weapon_view
	fx._holder = holder
	holder.add_child(fx)
	return fx


func _ready() -> void:
	if profile == null:
		profile = FeelProfile.new()
	if profile.flash_size > 0.0:
		_star = _flash_view(profile.flash_color)
		_star.scale = Vector3.ONE * profile.flash_size
		add_child(_star)
		_burst = _flash_view(profile.flash_color)
		add_child(_burst)
	if profile.smoke > 0:
		for i in POOL:
			_smoke.append(smoke_node(profile.smoke, profile.smoke_color))
			add_child(_smoke[i])
	if profile.casings > 0 or profile.breech_casings > 0:
		for i in POOL:
			_casings.append(casing_node(profile))
			add_child(_casings[i])
	_follow()


## A shot: the flash, the smoke, the profile's casings.
func fire() -> void:
	_follow()
	if _star != null:
		flashes += 1
		_flash_left = profile.flash_time
		var size := profile.flash_size * randf_range(0.8, 1.2)
		_star.scale = Vector3.ONE * size
		_star.visible = true
		_burst.position = _star.position + Vector3(0.0, 0.0, -size * BURST_AHEAD)
		_burst.scale = Vector3.ONE * size * BURST_SCALE * randf_range(0.8, 1.25)
		_burst.visible = true
	if not _smoke.is_empty():
		var smoke := _smoke[_next_smoke]
		_next_smoke = (_next_smoke + 1) % _smoke.size()
		smoke.global_position = _world_point(Vector3.ZERO)
		smoke.restart()
	if profile.casings > 0:
		eject(profile.casings)


## Throws [param count] casings out of the breech (a bolt run back, a
## break action opened).
func eject(count: int) -> void:
	if _casings.is_empty() or count <= 0:
		return
	_follow()
	var casings := _casings[_next_casing]
	_next_casing = (_next_casing + 1) % _casings.size()
	var shown := mini(count, casings.amount)
	casings_thrown += shown
	casings.amount_ratio = float(shown) / float(casings.amount)
	casings.global_position = _world_point(profile.eject_offset)
	casings.restart()


## True while the flash shows.
func flash_showing() -> bool:
	return _star != null and _star.visible


func _process(delta: float) -> void:
	_follow()
	if _star == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var showing := _flash_left > 0.0 and view != null and view.is_visible_in_tree()
	_star.visible = showing
	_burst.visible = showing


## Onto the view's muzzle (the holder's space).
func _follow() -> void:
	if view == null or not is_instance_valid(view):
		return
	var muzzle := view.get_node_or_null(^"Muzzle") as Node3D
	position = view.transform * (muzzle.position if muzzle != null else Vector3.ZERO)


## The world point where [param offset] (holder space, from the muzzle)
## shows on screen.
func _world_point(offset: Vector3) -> Vector3:
	var at := global_transform * offset
	if _holder != null and _holder.has_method(&"on_screen_like_the_view") and _holder.is_inside_tree():
		return _holder.call(&"on_screen_like_the_view", at)
	return at


static func _flash_view(color: Color) -> MeshInstance3D:
	var star := MeshInstance3D.new()
	star.mesh = _flash_quad()
	star.material_override = flash_material(color)
	star.layers = ArtLibrary.VIEWMODEL_LAYER
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.visible = false
	return star


static func _flash_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## The flash's additive star in [param color] (shared per colour), drawn
## like the viewmodel.
static func flash_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _flash_materials.has(key):
		return _flash_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = _star_image()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 1.0)
	material.use_fov_override = true
	material.fov_override = ArtLibrary.VIEWMODEL_FOV
	material.use_z_clip_scale = true
	material.z_clip_scale = ArtLibrary.VIEWMODEL_Z_CLIP
	material.disable_receive_shadows = true
	# the star sits at the very tip: drawn over the barrel it comes out of
	material.no_depth_test = true
	material.render_priority = 1
	_flash_materials[key] = material
	return material


## A star of fire (32 x 32): a white-hot core, four long uneven rays and
## four short ones, fading out to the edge; the profile's colour tints it.
static func _star_image() -> Texture2D:
	if _star_texture != null:
		return _star_texture
	var size := 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half, y - half) / half
			var r := d.length()
			var core := 1.0 - clampf(r / 0.38, 0.0, 1.0)
			var rays := maxf(1.0 - absf(d.x) / 0.09, 0.0) * maxf(1.0 - absf(d.y) * 1.05, 0.0) \
					+ maxf(1.0 - absf(d.y) / 0.09, 0.0) * maxf(1.0 - absf(d.x) * 1.25, 0.0)
			var diagonal := (maxf(1.0 - absf(d.x - d.y) / 0.12, 0.0) + maxf(1.0 - absf(d.x + d.y) / 0.12, 0.0)) \
					* maxf(1.0 - r / 0.75, 0.0)
			var heat := clampf(core * 1.5 + rays * 0.9 + diagonal * 0.5, 0.0, 1.0)
			var tone := Color(1.0, 0.55, 0.25).lerp(Color(1.0, 1.0, 0.92), clampf(core * 1.6, 0.0, 1.0))
			image.set_pixel(x, y, Color(tone.r, tone.g, tone.b, heat))
	_star_texture = ImageTexture.create_from_image(image)
	return _star_texture


## A one-shot burst of [param puffs] soft puffs in [param color] that rise,
## grow and fade (left in the world; not emitting yet).
static func smoke_node(puffs: int, color: Color) -> GPUParticles3D:
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = maxi(puffs, 1)
	smoke.lifetime = SMOKE_LIFETIME
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emitting = false
	smoke.local_coords = false
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.layers = ArtLibrary.VIEWMODEL_LAYER
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 0.3, -1.0)
	process.spread = 30.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0.0, 0.35, 0.0)
	process.damping_min = 0.8
	process.damping_max = 1.4
	process.scale_min = 0.7
	process.scale_max = 1.3
	process.color = color
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.8))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = GatlingDriver.puff_texture()
	quad.material = material
	smoke.draw_pass_1 = quad
	return smoke


## A one-shot throw of the profile's casings out of the breech (left in
## the world, tumbling and falling; not emitting yet).
static func casing_node(feel: FeelProfile) -> GPUParticles3D:
	var casings := GPUParticles3D.new()
	casings.name = "Casings"
	casings.amount = maxi(maxi(feel.casings, feel.breech_casings), 1)
	casings.lifetime = CASING_LIFETIME
	casings.one_shot = true
	casings.explosiveness = 1.0
	casings.emitting = false
	casings.local_coords = false
	casings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casings.layers = ArtLibrary.VIEWMODEL_LAYER
	var process := ParticleProcessMaterial.new()
	var throw := feel.eject_velocity
	process.direction = throw.normalized() if throw.length() > 0.01 else Vector3.RIGHT
	process.spread = 14.0
	process.initial_velocity_min = throw.length() * 0.8
	process.initial_velocity_max = throw.length() * 1.15
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.angular_velocity_min = -720.0
	process.angular_velocity_max = 720.0
	process.particle_flag_rotate_y = true
	process.scale_min = 0.9
	process.scale_max = 1.1
	casings.process_material = process
	casings.draw_pass_1 = casing_mesh(feel.casing_size, feel.casing_color)
	return casings


## A casing: a little box of [param size] (times CASING_SCALE) in polished
## [param color] (shared).
static func casing_mesh(size: Vector3, color: Color) -> Mesh:
	var key := "%s_%s" % [size, color.to_html()]
	if _casing_meshes.has(key):
		return _casing_meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = size * CASING_SCALE
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.8
	material.roughness = 0.35
	mesh.material = material
	_casing_meshes[key] = mesh
	return mesh


## One of everything a muzzle draws, for the shader warm-up: a star per
## profile colour, a smoke burst, a casing.
static func warm_set() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var colours: Dictionary = {}
	for id in [&"taser", &"pistol", &"shotgun", &"gatling", &"flare", &"rifle_hunt", &"harpoon", &"hwacha"]:
		var feel := FeelProfile.of(id)
		if feel.flash_size > 0.0:
			colours[feel.flash_color.to_html()] = feel.flash_color
		if feel.casings > 0 or feel.breech_casings > 0:
			var casing := MeshInstance3D.new()
			casing.mesh = casing_mesh(feel.casing_size, feel.casing_color)
			out.append(casing)
	for key in colours:
		var star := _flash_view(colours[key])
		star.visible = true
		star.scale = Vector3.ONE * 0.04
		out.append(star)
	var smoke := smoke_node(2, Color(0.7, 0.7, 0.72, 0.5))
	smoke.emitting = true
	out.append(smoke)
	return out
