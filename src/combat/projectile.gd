class_name Projectile
extends Node3D
## A slow, readable missile (the bust's marble shard; reusable for any
## exhibit that shoots). Flies in a straight line (or an arc with
## [member gravity]) and sweeps a sphere of [member radius] along its path
## every physics frame: whatever it touches that has take_damage() (the
## guard) gets [member damage]; anything else is level geometry and the
## missile bursts in its material. It is shootable: one hit from any weapon
## on its 0.25 m hurtbox destroys it.
##
## Configure everything before add_child() (use create()): it takes its
## world transform from create() when it enters the tree, whatever the
## parent's transform, so physics interpolation never smears it in.
## Meshes and materials are shared, so dozens in flight are just nodes.

## Why a flight ended.
signal finished(reason: End)

enum End { HIT, WALL, SHOT, EXPIRED }

const HURTBOX_RADIUS := 0.25
const TRAIL_LENGTH := 1.2
const TRAIL_WIDTH := 0.16
const SPIN_SPEED := 14.0
## Its glow grows to full size over its first HALO_GROWTH metres (a shot
## leaving the guard's own gun does not fill his view with light).
const HALO_GROWTH := 1.5

## Contact radius against bodies in [member hit_mask].
@export var radius: float = 0.2
@export var lifetime: float = 6.0
@export var gravity: float = 0.0
@export_flags_3d_physics var hit_mask: int = Layers.WORLD | Layers.PLAYER
## Debris and dust when it breaks.
@export var material_kind: ExhibitMaterial.Kind = ExhibitMaterial.Kind.MARBLE
@export var core_color: Color = Color(0.96, 0.93, 0.86)
@export var glow_color: Color = Color(1.0, 0.66, 0.34)
## 0 = no light (cheaper; for missiles that need no glow on the walls).
@export var light_energy: float = 1.1
@export var break_sound: StringName = &"shard_break"

var velocity := Vector3.ZERO
## Template of the hit; each hit gets a copy with direction and position.
var damage: DamageInfo = null
## Bodies it never hits (the shooter).
var exclude: Array[RID] = []
var hurtbox: Hurtbox

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var _age: float = 0.0
var _ended: bool = false
## World transform from create(), applied on entering the tree.
var _start := Transform3D.IDENTITY
var _placed: bool = false
var _speed: float = 0.0
var _query: PhysicsShapeQueryParameters3D
var _spin: Node3D
var _trail: MeshInstance3D
var _halo: MeshInstance3D


## A missile at [param from] (world space) flying with [param velocity_],
## facing its flight. Add it to the tree yourself, under any parent (after
## changing any exports).
static func create(from: Vector3, velocity_: Vector3, info: DamageInfo) -> Projectile:
	var shot := Projectile.new()
	shot.velocity = velocity_
	shot.damage = info
	shot._start = Transform3D(_facing(velocity_), from)
	shot._placed = true
	shot.transform = shot._start
	return shot


func _ready() -> void:
	if _placed:
		global_transform = _start
		reset_physics_interpolation()
	_speed = velocity.length()
	var shape := SphereShape3D.new()
	shape.radius = radius
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = shape
	_query.collision_mask = hit_mask
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	_query.exclude = exclude
	hurtbox = Hurtbox.make(self, _sphere(HURTBOX_RADIUS), Vector3.ZERO)
	add_child(hurtbox)
	_build_visuals()


func _physics_process(delta: float) -> void:
	if _ended:
		return
	_age += delta
	if _age >= lifetime:
		_end(End.EXPIRED)
		return
	if gravity != 0.0:
		velocity.y -= gravity * delta
		basis = _facing(velocity)
	var space := get_world_3d().direct_space_state
	# A sweep ignores shapes it starts in (or just touches), so a missile
	# that ended the last step flush against a wall must be caught here, or
	# it would tunnel through.
	var touching := _contact_at(space, global_position)
	if not touching.is_empty():
		_resolve(touching)
		return
	var motion := velocity * delta
	_query.transform = Transform3D(Basis.IDENTITY, global_position)
	_query.motion = motion
	var fractions := space.cast_motion(_query)
	if fractions[1] >= 1.0:
		global_position += motion
		_animate()
		return
	# something is in the way: find out what at the first touching spot
	var contact := _contact_at(space, global_position + motion * fractions[1])
	global_position += motion * fractions[0]
	_resolve(contact)


## A weapon hit its hurtbox: it breaks apart in mid-air.
func take_damage(info: DamageInfo) -> void:
	if _ended:
		return
	var toward := -info.direction if info.direction.length() > 0.01 else Vector3.UP
	_burst(global_position, toward, 1.3)
	Events.hit_landed.emit(self, info, true)
	_end(End.SHOT)


## Rest info ({} when free) of the contact sphere placed at [param at].
func _contact_at(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	_query.transform = Transform3D(Basis.IDENTITY, at)
	_query.motion = Vector3.ZERO
	return space.get_rest_info(_query)


func _resolve(contact: Dictionary) -> void:
	var point: Vector3 = contact.get("point", global_position)
	var normal: Vector3 = contact.get("normal", -velocity.normalized())
	var collider: Object = null
	if contact.has("collider_id"):
		collider = instance_from_id(contact["collider_id"])
	_impact(collider, point, normal)


func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	var receiver := collider as Node
	if receiver != null and receiver.has_method(&"take_damage"):
		receiver.take_damage(_hit_info(point, normal))
		_burst(point, normal, 0.8)
		_end(End.HIT)
	else:
		_burst(point, normal, 1.0)
		_end(End.WALL)


func _hit_info(point: Vector3, normal: Vector3) -> DamageInfo:
	var template := damage if damage != null else DamageInfo.new()
	# the shooter may be gone by now (the source is a non-owning reference)
	var source: Node = template.source if is_instance_valid(template.source) else null
	var info := DamageInfo.make(template.amount, template.kind, source)
	info.knockback = template.knockback
	info.stun_time = template.stun_time
	info.direction = velocity.normalized()
	info.position = point
	info.normal = normal
	return info


func _burst(point: Vector3, normal: Vector3, strength: float) -> void:
	Fx.impact(point, normal, material_kind, strength)
	var color := ExhibitMaterial.color(material_kind)
	for i in 2:
		var fling := (normal + Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.0), randf_range(-0.8, 0.8))) * 2.5
		Fx.chunk(point + normal * 0.05, color, 0.07, fling)
	Sfx.play_at(break_sound, point, -3.0)


func _end(reason: End) -> void:
	_ended = true
	hurtbox.collision_layer = 0   # no second hit on a breaking missile
	finished.emit(reason)
	queue_free()


func _animate() -> void:
	_spin.rotation.z = wrapf(_age * SPIN_SPEED, -PI, PI)
	# the trail grows out of the muzzle instead of poking back through it,
	# and the glow with it
	_trail.scale.z = clampf(_age * _speed / TRAIL_LENGTH, 0.02, 1.0)
	_halo.scale = Vector3.ONE * clampf(_age * _speed / HALO_GROWTH, 0.05, 1.0)


func _build_visuals() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var core := MeshInstance3D.new()
	core.mesh = _shard_mesh()
	core.material_override = _core_material(core_color, glow_color)
	core.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # the mesh's long axis (Y) along the flight
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(core)
	_halo = MeshInstance3D.new()
	_halo.mesh = _halo_mesh()
	_halo.material_override = _additive_material(glow_color, 0.35)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.scale = Vector3.ONE * 0.05
	add_child(_halo)
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh()
	_trail.material_override = _additive_material(glow_color, 1.0)
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.scale = Vector3(1.0, 1.0, 0.02)
	add_child(_trail)
	if light_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = glow_color
		light.light_energy = light_energy
		light.omni_range = 2.6
		light.shadow_enabled = false
		add_child(light)


## Basis whose -Z points along [param direction].
static func _facing(direction: Vector3) -> Basis:
	if direction.length_squared() < 0.0001:
		return Basis.IDENTITY
	var dir := direction.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(dir, up)


static func _sphere(r: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = r
	return shape


## Stretched bipyramid: a sharp marble splinter.
static func _shard_mesh() -> Mesh:
	if not _meshes.has(&"shard"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.065
		mesh.height = 0.3
		mesh.radial_segments = 4
		mesh.rings = 1
		_meshes[&"shard"] = mesh
	return _meshes[&"shard"]


static func _halo_mesh() -> Mesh:
	if not _meshes.has(&"halo"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.15
		mesh.height = 0.3
		mesh.radial_segments = 12
		mesh.rings = 6
		_meshes[&"halo"] = mesh
	return _meshes[&"halo"]


## Two crossed ribbons along +Z (behind the missile), opaque at the head and
## fading to nothing at the tail.
static func _trail_mesh() -> Mesh:
	if not _meshes.has(&"trail"):
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for axis in [Vector3.RIGHT, Vector3.UP]:
			var base := vertices.size()
			var half: Vector3 = axis * TRAIL_WIDTH * 0.5
			var tail := Vector3(0, 0, TRAIL_LENGTH)
			vertices.append_array(PackedVector3Array([half, -half, tail + half * 0.15, tail - half * 0.15]))
			colors.append_array(PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[&"trail"] = mesh
	return _meshes[&"trail"]


static func _core_material(color: Color, glow: Color) -> StandardMaterial3D:
	var key := "core_%s_%s" % [color.to_html(), glow.to_html()]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = glow.lerp(Color.WHITE, 0.4)
		mat.emission_energy_multiplier = 3.0
		_materials[key] = mat
	return _materials[key]


static func _additive_material(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "add_%s_%.2f" % [color.to_html(), alpha]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, alpha)
		_materials[key] = mat
	return _materials[key]
