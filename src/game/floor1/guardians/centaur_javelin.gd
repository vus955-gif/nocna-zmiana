class_name CentaurJavelin
extends Node3D
## The Centaur's marble javelin in flight (Centaur: one per throw, two in
## phase 3): thrown from the hand so that its tip comes down exactly on the
## mark on the floor after its flight time, along a true ballistic arc
## (launch_velocity), its shaft along its flight, a faint glint trailing
## it, its whistle (centaur_javelin) travelling with it. It hurts the guard
## once: where it passes through him in flight, or where it lands within
## CentaurBrain.JAVELIN_RADIUS of him (the mark's radius) - a plinth or a
## wall in its way stops it (cover). It sticks in the floor quivering for
## STUCK_TIME s, then crumbles to dust.
## World space (top_level); its origin is the javelin's tip.

signal landed(at: Vector3)
signal hit(target: Node3D)

## Gravity of the javelin's arc (m/s^2): snappy, high arcs.
const GRAVITY := 18.0
## The javelin model's tip lies this far ahead of its origin (javelin.glb:
## the marker "tip" at -Z).
const TIP := 1.45
const STUCK_TIME := 4.0
## How deep the tip goes into what it hits (m).
const SINK := 0.35
## The guard's height for a hit in flight.
const GUARD_HEIGHT := 1.8
const GLINT := Color(1.0, 0.9, 0.7)

var velocity := Vector3.ZERO
var damage: float = CentaurBrain.JAVELIN_DAMAGE
var radius: float = CentaurBrain.JAVELIN_RADIUS
var source: Node = null
var target: Node3D = null
var stuck := false
## The point it was thrown at, and its mark on the floor (fades as it lands).
var aim := Vector3.ZERO
var mark: GroundMark = null

var _tip := Vector3.ZERO
var _spent := false
var _age: float = 0.0
var _quiver := Spring.new(7.0, 0.12)
var _view: Node3D
var _trail: MeshInstance3D
var _trail_mat: StandardMaterial3D
var _voice: AudioStreamPlayer3D


## A javelin leaving [param from] (its tip) to come down on [param to] in
## [param flight] s.
static func make(from: Vector3, to: Vector3, flight: float, damage_: float, source_: Node = null, target_: Node3D = null) -> CentaurJavelin:
	var javelin := CentaurJavelin.new()
	javelin._tip = from
	javelin.aim = to
	javelin.velocity = launch_velocity(from, to, flight, GRAVITY)
	javelin.damage = damage_
	javelin.source = source_
	javelin.target = target_
	return javelin


## The velocity that carries a point from [param from] to [param to] in
## [param time] s under [param gravity].
static func launch_velocity(from: Vector3, to: Vector3, time: float, gravity: float) -> Vector3:
	var t := maxf(time, 0.05)
	return (to - from) / t + Vector3.UP * (0.5 * gravity * t)


## How long a javelin flies [param distance] m (flat): longer throws fly
## longer, within CentaurBrain.JAVELIN_FLIGHT.
static func flight_time(distance: float) -> float:
	return clampf(0.45 + distance / 22.0, CentaurBrain.JAVELIN_FLIGHT.x, CentaurBrain.JAVELIN_FLIGHT.y)


func _init() -> void:
	top_level = true
	name = "CentaurJavelin"


func _ready() -> void:
	_view = ArtLibrary.exhibit(&"javelin")
	if _view == null:
		var shaft := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.06, 2.6)
		shaft.mesh = mesh
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.9, 0.87, 0.8)
		shaft.material_override = stone
		_view = Node3D.new()
		_view.add_child(shaft)
		shaft.position.z = -0.18
	add_child(_view)
	# the model's tip sits at this node's origin
	_view.position = Vector3(0.0, 0.0, TIP)
	for node in _view.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).set_instance_shader_parameter(&"awake", 1.0)
		(node as GeometryInstance3D).set_instance_shader_parameter(&"glow", 0.6)
	_trail_mat = GuardianLooks.glow(GLINT, 0.35, true)
	_trail = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 1.6)
	_trail.mesh = quad
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.rotation.x = -PI * 0.5
	_trail.position = Vector3(0.0, 0.0, TIP + 2.2)
	add_child(_trail)
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = Sfx.stream_of(&"centaur_javelin")
	_voice.bus = &"SFX"
	_voice.max_distance = 50.0
	_voice.volume_db = 2.0
	add_child(_voice)
	if _voice.stream != null:
		_voice.play()
	_place()


func _physics_process(delta: float) -> void:
	_age += delta
	if stuck:
		_quivering(delta)
		return
	var before := _tip
	velocity += Vector3.DOWN * GRAVITY * delta
	var after := before + velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(before, after, Layers.WORLD)
	var blocked := space.intersect_ray(query)
	if not blocked.is_empty():
		after = blocked["position"]
	if not _spent and _guard_alive() and SunBeam.segment_hits_capsule(before, after, target.global_position, GUARD_HEIGHT, 0.32):
		_strike(after)
	_tip = after
	_place()
	if not blocked.is_empty():
		_stick(blocked["normal"])
	elif _age > 6.0:
		queue_free()   # out of the world


## The javelin's line now (unit, world).
func heading() -> Vector3:
	return velocity.normalized() if velocity.length() > 0.01 else -global_basis.z


## Where its tip is (world).
func tip() -> Vector3:
	return _tip


func _place() -> void:
	var line := heading()
	var up := Vector3.UP if absf(line.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(line, up), _tip)
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
	info.knockback = 4.0
	info.position = target.global_position + Vector3.UP * 1.0
	target.call(&"take_damage", info)
	Fx.impact(at, -heading(), ExhibitMaterial.Kind.MARBLE, 1.6)
	hit.emit(target)


## It strikes into what stopped it ([param normal]): sinks in, quivers;
## the guard near where it came down is hurt.
func _stick(normal: Vector3) -> void:
	stuck = true
	_age = 0.0
	_tip += heading() * SINK
	velocity = heading() * 0.01
	_place()
	var at := _tip - heading() * SINK
	Fx.impact(at + normal * 0.05, normal, ExhibitMaterial.Kind.MARBLE, 2.2)
	Fx.impact(at + normal * 0.05, normal, -1, 1.8)
	Sfx.play_at(&"hit_marble", at, 1.0, 0.15)
	_quiver.kick(9.0)
	_trail.visible = false
	if _voice != null:
		_voice.stop()
	_fade_mark(0.35)
	landed.emit(at)
	if _spent or not _guard_alive():
		return
	var off := target.global_position - at
	if Vector2(off.x, off.z).length() <= radius + ShockwaveRing.GUARD_RADIUS and off.y < 1.2 and off.y > -1.0:
		_strike(at)


func _exit_tree() -> void:
	_fade_mark(0.2)


func _fade_mark(seconds: float) -> void:
	if mark != null and is_instance_valid(mark) and mark.is_inside_tree():
		mark.vanish(seconds)
	mark = null


func _quivering(delta: float) -> void:
	var wobble := _quiver.step(0.0, delta)
	_view.rotation = Vector3(wobble * 0.05, wobble * 0.03, 0.0)
	if _age >= STUCK_TIME:
		var shaft := global_transform * Vector3(0.0, 0.0, TIP)
		Fx.impact(shaft, Vector3.UP, ExhibitMaterial.Kind.MARBLE, 1.5)
		Fx.impact(_tip - heading() * 0.4, Vector3.UP, -1, 1.0)
		queue_free()
