class_name RollingPlanet
extends RigidBody3D
## A planet shot off the Great Orrery - or Saturn's rings, or Earth's Moon -
## as a hazard on the floor: it drops off its rod with the speed its tier
## gave it, rolls, bounces off the walls and the instruments in the corners
## (cover from it), and hurts a guard it rolls into (once a second, only
## while it rolls: a small one can be jumped). It cracks apart after
## LIFETIME s, once it has come to rest, or when shot BREAK_DAMAGE worth.
## Its look is a copy of the planet's views (the orrery hides its own).
## Configure with make() before add_child().

signal shattered

const LIFETIME := 9.0
## Slower than this for REST_TIME s, it cracks (after MIN_AGE s).
const REST_SPEED := 0.5
const REST_TIME := 0.8
const MIN_AGE := 1.5
## It hurts only while it rolls at least this fast (m/s).
const CONTACT_SPEED := 1.5
const DAMAGE := 14.0
const KNOCKBACK := 8.0
const HIT_COOLDOWN := 1.0
## Shot this much, it breaks.
const BREAK_DAMAGE := 25.0
## The guard's capsule (ShockwaveRing.GUARD_RADIUS, the Player's height).
const GUARD_RADIUS := 0.4
const GUARD_HEIGHT := 1.8

## Its radius (the ball), or the hoop's (rings).
var size: float = 0.3
## A hoop (Saturn's rings): its axis in its own space.
var hoop_axis := Vector3.ZERO
var target: Node3D = null
var source: Node = null
var damage_scale: float = 1.0
var hurtbox: Hurtbox

var _age: float = 0.0
var _rest: float = 0.0
var _cooldown: float = 0.0
var _taken: float = 0.0
var _done := false
var _start := Transform3D.IDENTITY
var _push := Vector3.ZERO
var _views: Array[MeshInstance3D] = []


## A rolling copy of [param views] (their world transforms now) round the
## planet's centre [param at], flung with [param velocity]; a hoop when
## [param axis] (world) is given.
static func make(views: Array[MeshInstance3D], at: Transform3D, velocity: Vector3, radius: float, axis: Vector3 = Vector3.ZERO) -> RollingPlanet:
	var body := RollingPlanet.new()
	body.name = "RollingPlanet"
	body.size = radius
	body._start = Transform3D(Basis.IDENTITY, at.origin)
	body._push = velocity
	var to_body := body._start.affine_inverse()
	for view in views:
		if view == null or view.mesh == null:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = view.mesh
		for i in view.mesh.get_surface_count():
			copy.set_surface_override_material(i, view.get_active_material(i))
		copy.transform = to_body * view.global_transform
		body._views.append(copy)
		body.add_child(copy)
	if axis != Vector3.ZERO:
		body.hoop_axis = axis.normalized()
	return body


func _init() -> void:
	collision_layer = Layers.DEBRIS
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.DEBRIS
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2


func _ready() -> void:
	global_transform = _start
	reset_physics_interpolation()
	var collider := CollisionShape3D.new()
	if hoop_axis != Vector3.ZERO:
		var hoop := CylinderShape3D.new()
		hoop.radius = size
		hoop.height = 0.08
		collider.shape = hoop
		collider.basis = Basis(Quaternion(Vector3.UP, hoop_axis))
		mass = 30.0
	else:
		var ball := SphereShape3D.new()
		ball.radius = size
		collider.shape = ball
		mass = 40.0 + 420.0 * size * size * size
	add_child(collider)
	var material := PhysicsMaterial.new()
	material.bounce = 0.3
	material.friction = 0.9
	physics_material_override = material
	linear_damp = 0.08
	angular_damp = 0.15
	linear_velocity = _push
	var flat := Vector3(_push.x, 0.0, _push.z)
	angular_velocity = Vector3.UP.cross(flat) / maxf(size, 0.1)
	var shape := SphereShape3D.new()
	shape.radius = (size if hoop_axis == Vector3.ZERO else 0.6) + 0.05
	hurtbox = Hurtbox.make(self, shape, Vector3.ZERO)
	add_child(hurtbox)
	body_entered.connect(_on_bump)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_cooldown -= delta
	var speed := linear_velocity.length()
	_rest = _rest + delta if speed < REST_SPEED else 0.0
	if _age >= LIFETIME or (_age > MIN_AGE and _rest >= REST_TIME):
		shatter()
		return
	_check_guard(speed)


## True while it can hurt a guard standing on [param feet] now.
func touches(feet: Vector3) -> bool:
	if hoop_axis != Vector3.ZERO:
		# a hoop on its edge (not lying flat) is a wheel of brass
		var up := absf((global_basis * hoop_axis).normalized().dot(Vector3.UP))
		return up < 0.7 and OrreryGeometry.capsule_sphere(feet, GUARD_RADIUS, GUARD_HEIGHT, global_position, size * 0.85)
	return OrreryGeometry.capsule_sphere(feet, GUARD_RADIUS, GUARD_HEIGHT, global_position, size)


func _check_guard(speed: float) -> void:
	if _cooldown > 0.0 or speed < CONTACT_SPEED or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var alive: Variant = target.get(&"alive")
	if alive is bool and not alive:
		return
	if not touches(target.global_position) or not target.has_method(&"take_damage"):
		return
	_cooldown = HIT_COOLDOWN
	var info := DamageInfo.make(DAMAGE * damage_scale, DamageInfo.Kind.BLUNT, source if is_instance_valid(source) else null)
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	info.direction = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	info.knockback = KNOCKBACK
	info.position = target.global_position + Vector3.UP
	target.call(&"take_damage", info)
	Sfx.play_at(&"punch_hit", target.global_position + Vector3.UP, 0.0)
	Sfx.play_at(&"hit_metal", global_position, -2.0, 0.1, 0.6)


## A shot from a weapon: brass rings, and enough of them break it.
func take_damage(info: DamageInfo) -> void:
	if _done or info == null:
		return
	_taken += info.amount
	Fx.impact(info.position, info.normal, ExhibitMaterial.Kind.METAL, 0.8)
	Sfx.play_at(&"hit_metal", info.position, -4.0, 0.15, 1.3)
	var broke := _taken >= BREAK_DAMAGE
	Events.hit_landed.emit(self, info, broke)
	if broke:
		shatter()


## Cracks apart into brass and enamel pieces.
func shatter() -> void:
	if _done:
		return
	_done = true
	hurtbox.collision_layer = 0
	var at := global_position
	Fx.impact(at, Vector3.UP, ExhibitMaterial.Kind.METAL, 2.5)
	Fx.impact(at, Vector3.UP, -1, 1.5)
	Fx.flash(at + Vector3.UP * 0.3, Color(1.0, 0.7, 0.35), 2.0, 4.0, 0.2)
	Sfx.play_at(&"break_metal", at, 0.0)
	for view in _views:
		if not is_instance_valid(view) or view.mesh == null:
			continue
		var materials: Array = []
		for i in view.mesh.get_surface_count():
			var source_mat := view.get_active_material(i)
			materials.append(ArtLibrary.debris_material(source_mat) if source_mat != null else null)
		var cuts: Array = MeshShards.slices(view.mesh, 3) if view.mesh is ArrayMesh else [MeshShards.whole(view.mesh)]
		for shard: MeshShards.Piece in cuts:
			var fling := Vector3(randf_range(-1.0, 1.0), randf_range(0.8, 2.0), randf_range(-1.0, 1.0)) * 2.0 + linear_velocity * 0.5
			Fx.piece(shard, MeshShards.materials_for(shard, materials), view.global_transform, fling, 6.0)
	shattered.emit()
	queue_free()


func _on_bump(_body: Node) -> void:
	var speed := linear_velocity.length()
	if speed > 2.0:
		Sfx.play_at(&"hit_metal", global_position, clampf(-14.0 + speed * 1.5, -14.0, -2.0), 0.15, 0.55)
		Fx.impact(global_position - Vector3.UP * size * 0.9, Vector3.UP, -1, 0.6)
