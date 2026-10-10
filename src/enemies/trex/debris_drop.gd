class_name DebrisDrop
extends Node3D
## A chunk of ceiling falling on a marked spot (the T-Rex's phase-3 roar).
## A dark shadow with a glowing warning ring appears on the floor at once;
## the ring closes in and the shadow darkens while the rock drops (visible
## the whole way, accelerating), landing after [member delay]. Only then is
## the target hurt, if it still stands inside [member radius].
## Create with create() (a world position; it places itself there on
## entering the tree, under any parent).

signal landed(hit: bool)

const GUARD_RADIUS := 0.4
const ROCK_COLOR := Color(0.5, 0.48, 0.45)
const WARNING_COLOR := Color(1.0, 0.35, 0.12)

@export var delay: float = 1.0
@export var damage: float = 20.0
@export var radius: float = 1.6
## Highest start of the fall above the marker (lower under a ceiling).
@export var drop_height: float = 9.0

var target: Node3D = null
## Who brought it down (the boss). Once that one is dead or gone the rock
## still falls, but it hurts no one: the fight is over.
var source: Node = null:
	set(value):
		source = value
		_has_source = value != null

var _has_source: bool = false
## World spot from create(), applied on entering the tree.
var _spot := Vector3.ZERO
var _placed: bool = false

var _time: float = 0.0
var _done: bool = false
var _height: float = 0.0
var _shadow_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _rock: Node3D


static func create(on_floor: Vector3, target_: Node3D, source_: Node = null) -> DebrisDrop:
	var drop := DebrisDrop.new()
	drop._spot = on_floor
	drop._placed = true
	drop.position = on_floor
	drop.target = target_
	drop.source = source_
	return drop


func _ready() -> void:
	if _placed:
		global_position = _spot
		reset_physics_interpolation()
	_height = _fall_height()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.25)
	var shadow := MeshInstance3D.new()
	shadow.mesh = disc
	shadow.material_override = _shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.03
	add_child(shadow)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.08
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 4
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(WARNING_COLOR.r * 2.0, WARNING_COLOR.g * 2.0, WARNING_COLOR.b * 2.0)
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.05
	add_child(_ring)
	_rock = _make_rock()
	_rock.position.y = _height
	add_child(_rock)
	# plaster dust trickles from where it breaks loose
	Fx.impact(global_position + Vector3.UP * (_height + 0.3), Vector3.DOWN, -1, 1.5)
	_update_visuals()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time >= delay:
		_land()
		return
	_update_visuals()


func _update_visuals() -> void:
	var t := clampf(_time / delay, 0.0, 1.0)
	_shadow_mat.albedo_color.a = lerpf(0.25, 0.8, t)
	_ring.scale = Vector3.ONE * lerpf(1.6, 1.0, t)
	_rock.position.y = _height * (1.0 - t * t)
	_rock.rotation = Vector3(t * 3.0, t * 1.7, 0.0)


func _land() -> void:
	_done = true
	var hit := not _source_defeated() and _target_inside()
	if hit:
		var info := DamageInfo.make(damage, DamageInfo.Kind.BLUNT, source)
		var away := target.global_position - global_position
		away.y = 0.0
		info.direction = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		info.knockback = 6.0
		info.position = target.global_position + Vector3.UP
		target.take_damage(info)
	Fx.impact(global_position + Vector3.UP * 0.2, Vector3.UP, -1, 3.0)
	for i in 5:
		var fling := Vector3(randf_range(-3.0, 3.0), randf_range(2.0, 5.0), randf_range(-3.0, 3.0))
		Fx.chunk(global_position + Vector3.UP * 0.4, ROCK_COLOR, randf_range(0.15, 0.3), fling)
	Sfx.play_at(&"rubble", global_position)
	var guard := get_tree().get_first_node_in_group(&"player") as Node3D
	if guard != null:
		var distance := guard.global_position.distance_to(global_position)
		if distance < 14.0:
			Events.shake_requested.emit(0.35 * (1.0 - distance / 14.0))
	landed.emit(hit)
	queue_free()


## True when the drop had a source that has since died or been freed.
func _source_defeated() -> bool:
	if not _has_source:
		return false
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return true
	return source.has_method(&"is_dead") and source.call(&"is_dead")


func _target_inside() -> bool:
	if not is_instance_valid(target) or not target.has_method(&"take_damage"):
		return false
	var guard := target as Player
	if guard != null and not guard.alive:
		return false
	if Haven.shelters(target.global_position):
		return false   # a haven's roof holds
	var to := target.global_position - global_position
	if to.y < -0.6 or to.y > 2.5:
		return false
	return Vector2(to.x, to.z).length() <= radius + GUARD_RADIUS


## Fall distance: up to the ceiling above the marker, at most drop_height.
func _fall_height() -> float:
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * drop_height, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return drop_height
	return maxf((hit["position"] as Vector3).y - global_position.y - 0.4, 2.0)


func _make_rock() -> Node3D:
	var rock := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK_COLOR
	mat.roughness = 1.0
	for spec in [[Vector3(0.7, 0.5, 0.6), Vector3.ZERO, Vector3(10, 20, 0)],
			[Vector3(0.45, 0.4, 0.5), Vector3(0.3, 0.2, -0.1), Vector3(0, 35, 25)],
			[Vector3(0.4, 0.35, 0.35), Vector3(-0.25, -0.1, 0.2), Vector3(30, 0, 15)]]:
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		var view := MeshInstance3D.new()
		view.mesh = mesh
		view.material_override = mat
		view.position = spec[1]
		view.rotation_degrees = spec[2]
		rock.add_child(view)
	return rock
