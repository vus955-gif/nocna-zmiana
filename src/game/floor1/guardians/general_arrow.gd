class_name GeneralArrow
extends Node3D
## One arrow of the General's volley (General: a volley splits one arrow
## into GeneralBrain.ARROWS of them off the tea house eave), in flight: it
## leaves the bow so that its head comes down exactly on its mark on the
## gravel after its flight time, along a true ballistic arc
## (launch_velocity), the shaft along its flight, glowing like an ember, a
## faint trail behind it. It hurts the guard once: where it passes through
## him in flight, or where it lands within GeneralBrain.ARROW_RADIUS of him
## (the mark's radius) - a rock or a stone lantern in its way stops it
## (cover). It sticks in the gravel quivering for STUCK_TIME s, then goes out
## and crumbles.
## World space (top_level); its origin is the arrow's head.

signal landed(at: Vector3)
signal hit(target: Node3D)

## Gravity of the arrow's arc (m/s^2): a high, readable lob.
const GRAVITY := 16.0
## The arrow is this long (head to nock).
const LENGTH := 1.43
const STUCK_TIME := 3.5
## How deep the head goes into what it hits (m).
const SINK := 0.25
## The guard's height for a hit in flight.
const GUARD_HEIGHT := 1.8
const EMBER := Color(1.0, 0.55, 0.2)
## The guard's body radius.
const GUARD_RADIUS := 0.4

## The shaft the General's rig lends its arrows (its model's arrow mesh with
## its materials); null: a greybox shaft.
static var shaft_mesh: Mesh = null
static var shaft_materials: Array[Material] = []
## The lent mesh's axis from its head to its nock (mesh space) and where its
## head lies (mesh space).
static var shaft_axis := Vector3.UP
static var shaft_head := Vector3.ZERO

var velocity := Vector3.ZERO
var damage: float = GeneralBrain.ARROW_DAMAGE
var radius: float = GeneralBrain.ARROW_RADIUS
var source: Node = null
var target: Node3D = null
var stuck := false
## The point it was shot at, and its mark on the gravel (fades as it lands).
var aim := Vector3.ZERO
var mark: GroundMark = null

var _head := Vector3.ZERO
var _spent := false
var _age: float = 0.0
var _quiver := Spring.new(8.0, 0.12)
var _view: Node3D
var _trail: MeshInstance3D
var _trail_mat: StandardMaterial3D
var _glow: float = 1.0


## An arrow leaving [param from] (its head) to come down on [param to] in
## [param flight] s.
static func make(from: Vector3, to: Vector3, flight: float, damage_: float, source_: Node = null, target_: Node3D = null) -> GeneralArrow:
	var arrow := GeneralArrow.new()
	arrow._head = from
	arrow.aim = to
	arrow.velocity = launch_velocity(from, to, flight, GRAVITY)
	arrow.damage = damage_
	arrow.source = source_
	arrow.target = target_
	return arrow


## The velocity that carries a point from [param from] to [param to] in
## [param time] s under [param gravity].
static func launch_velocity(from: Vector3, to: Vector3, time: float, gravity: float) -> Vector3:
	var t := maxf(time, 0.05)
	return (to - from) / t + Vector3.UP * (0.5 * gravity * t)


## How long an arrow flies [param distance] m (flat): longer shots fly
## longer, within GeneralBrain.ARROW_FLIGHT.
static func flight_time(distance: float) -> float:
	return clampf(0.6 + distance / 30.0, GeneralBrain.ARROW_FLIGHT.x, GeneralBrain.ARROW_FLIGHT.y)


## The General's rig lends [param view] (its model's arrow) as the shaft of
## every arrow: [param head] and [param nock] in the mesh's space.
static func adopt(view: MeshInstance3D, head: Vector3, nock: Vector3) -> void:
	if view == null or view.mesh == null:
		return
	shaft_mesh = view.mesh
	shaft_materials.clear()
	for i in view.mesh.get_surface_count():
		shaft_materials.append(view.get_active_material(i))
	shaft_head = head
	shaft_axis = (nock - head).normalized() if nock.distance_to(head) > 0.01 else Vector3.UP


func _init() -> void:
	top_level = true
	name = "GeneralArrow"


func _ready() -> void:
	_view = Node3D.new()
	add_child(_view)
	var shaft := MeshInstance3D.new()
	if shaft_mesh != null:
		shaft.mesh = shaft_mesh
		for i in shaft_materials.size():
			if shaft_materials[i] != null:
				shaft.set_surface_override_material(i, shaft_materials[i])
		# the lent mesh's head at this node's origin, its shaft along +Z
		# (behind the head, the flight coming toward -Z)
		var turn := LimbIK.aim(Basis.IDENTITY, shaft_axis, Vector3.BACK)
		shaft.transform = Transform3D(turn, -(turn * shaft_head))
		shaft.set_instance_shader_parameter(&"awake", 1.0)
		shaft.set_instance_shader_parameter(&"glow", 0.9)
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.025, 0.025, LENGTH)
		shaft.mesh = mesh
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.3, 0.16)
		wood.emission_enabled = true
		wood.emission = EMBER
		wood.emission_energy_multiplier = 1.4
		shaft.material_override = wood
		shaft.position.z = LENGTH * 0.5
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(shaft)
	_trail_mat = GuardianLooks.glow(EMBER, 0.4, true)
	_trail = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 1.2)
	_trail.mesh = quad
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.rotation.x = -PI * 0.5
	_trail.position = Vector3(0.0, 0.0, LENGTH + 0.6)
	add_child(_trail)
	_place()


func _physics_process(delta: float) -> void:
	_age += delta
	if stuck:
		_quivering(delta)
		return
	var before := _head
	velocity += Vector3.DOWN * GRAVITY * delta
	var after := before + velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(before, after, Layers.WORLD)
	var blocked := space.intersect_ray(query)
	if not blocked.is_empty():
		after = blocked["position"]
	if not _spent and _guard_alive() and SunBeam.segment_hits_capsule(before, after, target.global_position, GUARD_HEIGHT, 0.3):
		_strike(after)
	_head = after
	_place()
	if not blocked.is_empty():
		_stick(blocked["normal"])
	elif _age > 6.0:
		queue_free()   # out of the world


## The arrow's line now (unit, world).
func heading() -> Vector3:
	return velocity.normalized() if velocity.length() > 0.01 else -global_basis.z


## Where its head is (world).
func head() -> Vector3:
	return _head


func _place() -> void:
	var line := heading()
	var up := Vector3.UP if absf(line.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(line, up), _head)
	if is_inside_tree() and _age <= 0.0:
		reset_physics_interpolation()


func _guard_alive() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var alive: Variant = target.get(&"alive")
	return not (alive is bool) or alive


func _strike(at: Vector3) -> void:
	_spent = true
	var info := DamageInfo.make(damage, DamageInfo.Kind.BALLISTIC, source if is_instance_valid(source) else null)
	var push := Vector3(velocity.x, 0.0, velocity.z)
	info.direction = push.normalized() if push.length() > 0.1 else Vector3.FORWARD
	info.knockback = 3.0
	info.position = target.global_position + Vector3.UP * 1.0
	target.call(&"take_damage", info)
	Fx.impact(at, -heading(), ExhibitMaterial.Kind.WOOD, 1.2)
	hit.emit(target)


## It strikes into what stopped it ([param normal]): sinks in, quivers;
## the guard near where it came down is hurt.
func _stick(normal: Vector3) -> void:
	stuck = true
	_age = 0.0
	_head += heading() * SINK
	velocity = heading() * 0.01
	_place()
	var at := _head - heading() * SINK
	Fx.impact(at + normal * 0.05, normal, -1, 1.4)
	Fx.impact(at + normal * 0.05, normal, ExhibitMaterial.Kind.WOOD, 0.8)
	Sfx.play_at(&"hit_metal", at, -8.0, 0.2, 1.4)
	_quiver.kick(10.0)
	_trail.visible = false
	_fade_mark(0.3)
	landed.emit(at)
	if _spent or not _guard_alive():
		return
	var off := target.global_position - at
	if Vector2(off.x, off.z).length() <= radius + GUARD_RADIUS and off.y < 1.2 and off.y > -1.0:
		_strike(at)


func _exit_tree() -> void:
	_fade_mark(0.2)


func _fade_mark(seconds: float) -> void:
	if mark != null and is_instance_valid(mark) and mark.is_inside_tree():
		mark.vanish(seconds)
	mark = null


func _quivering(delta: float) -> void:
	var wobble := _quiver.step(0.0, delta)
	_view.rotation = Vector3(wobble * 0.04, wobble * 0.025, 0.0)
	# the ember dies down
	_glow = maxf(_glow - delta / STUCK_TIME, 0.0)
	for child in _view.get_children():
		if child is MeshInstance3D and shaft_mesh != null:
			(child as MeshInstance3D).set_instance_shader_parameter(&"glow", 0.9 * _glow)
	if _age >= STUCK_TIME:
		Fx.impact(_head - heading() * 0.4, Vector3.UP, -1, 0.8)
		queue_free()
