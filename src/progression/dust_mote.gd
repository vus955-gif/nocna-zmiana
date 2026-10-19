class_name DustMote
extends Node3D
## One glowing speck of Dust. It pops out of a destroyed exhibit, hangs in
## the air, and after MAGNET_DELAY flies to a living guard closer than
## MAGNET_RADIUS (further with the dust magnet: Player.dust_magnet_radius).
## Reaching him adds its value to the night's Dust (already
## scaled, so no multipliers again). Unclaimed motes blink out after
## [member lifetime] seconds.

signal collected(value: int)

const MAGNET_DELAY := 0.6
const MAGNET_RADIUS := 6.0
const COLLECT_RADIUS := 0.7
const MAX_SPEED := 18.0
const PULL_ACCEL := 40.0
const GRAVITY := 9.0
## The guard's chest, where motes fly to.
const CHEST := 1.1
## The last seconds of life blink.
const BLINK_TIME := 2.0
const COLOR := Color(1.0, 0.82, 0.45)

## The twinkling star sprite (4 frames of 16 px), metres per texel.
const SPRITE := "dust_mote"
const SPRITE_FRAMES := 4
const SPRITE_PIXEL := 0.018
const TWINKLE_FPS := 9.0

static var _mesh: SphereMesh = null
static var _sprite_material: StandardMaterial3D = null

## Dust this mote is worth.
var value: int = 1
## Who may collect it (the guard).
var target: Node3D = null
var lifetime: float = 30.0

var _age: float = 0.0
var _velocity := Vector3.ZERO
var _pulled := false
var _speed: float = 0.0
var _view: GeometryInstance3D
var _sprite: Sprite3D = null
var _light: OmniLight3D
var _bob_phase: float = 0.0


## Spawns one mote per value around [param at], flying out in a burst.
static func burst(parent: Node, at: Vector3, values: Array[int], collector: Node3D) -> Array[DustMote]:
	var motes: Array[DustMote] = []
	for i in values.size():
		var mote := DustMote.new()
		mote.value = values[i]
		mote.target = collector
		var angle := TAU * (float(i) / values.size()) + randf_range(-0.4, 0.4)
		mote._velocity = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.8, 1.6) + Vector3.UP * randf_range(2.6, 3.6)
		var space := parent as Node3D
		mote.position = space.global_transform.affine_inverse() * at if space != null and space.is_inside_tree() else at
		parent.add_child(mote)
		motes.append(mote)
	return motes


## One mote worth [param worth] hanging still at [param at] (world), ready
## to fly to [param collector] at once: Dust that lay there when the night
## was saved, laid again when it is continued (QA Q10).
static func hang(parent: Node, at: Vector3, worth: int, collector: Node3D) -> DustMote:
	var mote := DustMote.new()
	mote.value = worth
	mote.target = collector
	mote._age = MAGNET_DELAY
	var space := parent as Node3D
	mote.position = space.global_transform.affine_inverse() * at if space != null and space.is_inside_tree() else at
	parent.add_child(mote)
	return mote


func _ready() -> void:
	_bob_phase = randf() * TAU
	_view = _make_sprite()
	if _view == null:
		var sphere := MeshInstance3D.new()
		sphere.mesh = _shared_mesh()
		_view = sphere
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 0.9
	_light.omni_range = 1.8
	_light.light_volumetric_fog_energy = 0.5
	add_child(_light)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	visible = _age < lifetime - BLINK_TIME or fmod(_age * 8.0, 2.0) < 1.3
	if _age < MAGNET_DELAY:
		_velocity.y -= GRAVITY * delta
	else:
		_velocity = _velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		_update_pull(delta)
	position += _velocity * delta
	if not _pulled and _age >= MAGNET_DELAY:
		position.y += sin(_age * 3.0 + _bob_phase) * 0.12 * delta
	if _sprite != null:
		_sprite.frame = int(_age * TWINKLE_FPS + _bob_phase * 2.0) % SPRITE_FRAMES
	else:
		_view.rotation.y += delta * 3.0


func _update_pull(delta: float) -> void:
	if not _can_collect():
		_pulled = false
		return
	var chest := target.global_position + Vector3.UP * CHEST
	var to := chest - global_position
	if to.length() <= COLLECT_RADIUS:
		_collect()
		return
	if not _pulled and to.length() > magnet_radius():
		return
	_pulled = true
	_speed = minf(_speed + PULL_ACCEL * delta, MAX_SPEED)
	# never overshoot the guard in one step
	_velocity = to.normalized() * minf(_speed, to.length() / maxf(delta, 0.0001))


## How close the guard must come for the mote to fly to him.
func magnet_radius() -> float:
	var guard := target as Player
	return guard.dust_magnet_radius if guard != null else MAGNET_RADIUS


func _can_collect() -> bool:
	if not is_instance_valid(target):
		return false
	var guard := target as Player
	return guard == null or guard.alive


func _collect() -> void:
	RunState.add_dust(value, false)
	Events.dust_collected.emit(value)
	Sfx.play(&"dust", -6.0, 0.12)
	collected.emit(value)
	queue_free()


## The additive, always-facing star sprite (ArtLibrary's dust_mote sheet);
## null without the texture (a glowing sphere then).
func _make_sprite() -> Sprite3D:
	if not ArtLibrary.models_enabled or not ResourceLoader.exists("res://assets/textures/%s.png" % SPRITE):
		return null
	if _sprite_material == null:
		_sprite_material = StandardMaterial3D.new()
		_sprite_material.resource_name = SPRITE
		_sprite_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sprite_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sprite_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_sprite_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite_material.albedo_texture = load("res://assets/textures/%s.png" % SPRITE) as Texture2D
		_sprite_material.albedo_color = Color(2.2, 1.9, 1.4)
		_sprite_material.vertex_color_use_as_albedo = true
	_sprite = Sprite3D.new()
	_sprite.texture = _sprite_material.albedo_texture
	_sprite.hframes = SPRITE_FRAMES
	_sprite.pixel_size = SPRITE_PIXEL
	_sprite.material_override = _sprite_material
	return _sprite


static func _shared_mesh() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.06
		_mesh.height = 0.12
		_mesh.radial_segments = 8
		_mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(COLOR.r * 3.0, COLOR.g * 3.0, COLOR.b * 3.0)
		_mesh.material = material
	return _mesh
