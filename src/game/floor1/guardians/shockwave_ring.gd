class_name ShockwaveRing
extends Node3D
## A shockwave rolling out along the floor from an impact (a slammed palm,
## a stomp): a ring of dust and heat growing from [member start_radius] to
## [member reach] at [member speed]. When it passes under the guard it hurts
## him once - unless his feet are more than ColossusBrain.CLEAR_HEIGHT off
## the floor (he jumped it). It never hurts twice and is gone at its reach.
## World space (top_level): place it with make().

signal hit(target: Node3D)

## How thick the ring is (m): a guard this far inside its edge is caught.
const WIDTH := 0.6
## The guard's body radius.
const GUARD_RADIUS := 0.4
const HEIGHT := 0.45
const COLOR := Color(1.0, 0.72, 0.42)

var center := Vector3.ZERO
var start_radius: float = 0.0
var reach: float = 7.0
var speed: float = 10.0
var damage: float = 10.0
var knockback: float = 4.0
## Feet higher than this above the ring's floor clear it.
var clear_height: float = ColossusBrain.CLEAR_HEIGHT
## Who it can hurt, and who made it (the damage's source).
var target: Node3D = null
var source: Node = null

var radius: float = 0.0
var _done := false
var _view: MeshInstance3D
var _material: StandardMaterial3D


static func make(at: Vector3, reach_: float, speed_: float, damage_: float, source_: Node = null, from_radius: float = 0.0) -> ShockwaveRing:
	var ring := ShockwaveRing.new()
	ring.center = at
	ring.reach = reach_
	ring.speed = speed_
	ring.damage = damage_
	ring.source = source_
	ring.start_radius = from_radius
	ring.radius = from_radius
	return ring


## True when a ring growing from [param before] to [param now] (m) passes a
## point [param distance] m from its centre.
static func crosses(before: float, now: float, distance: float) -> bool:
	return distance + GUARD_RADIUS >= before - WIDTH and distance - GUARD_RADIUS <= now


func _init() -> void:
	top_level = true
	name = "ShockwaveRing"


func _ready() -> void:
	global_position = center
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_material = GuardianLooks.glow(COLOR, 0.8)
	_view = MeshInstance3D.new()
	_view.mesh = torus
	_view.material_override = _material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)
	_show()


func _physics_process(delta: float) -> void:
	var before := radius
	radius = minf(radius + speed * delta, reach)
	_check(before)
	_show()
	if radius >= reach:
		queue_free()


func _check(before: float) -> void:
	if _done or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var alive: Variant = target.get(&"alive")
	if alive is bool and not alive:
		return
	var off := target.global_position - center
	var distance := Vector2(off.x, off.z).length()
	if not crosses(before, radius, distance):
		return
	if off.y > clear_height:
		return   # jumped it
	if absf(off.y) > 2.0 or not target.has_method(&"take_damage"):
		return
	_done = true
	var info := DamageInfo.make(damage, DamageInfo.Kind.BLUNT, source)
	var out := Vector3(off.x, 0.0, off.z)
	info.direction = out.normalized() if out.length() > 0.05 else Vector3.FORWARD
	info.knockback = knockback
	info.position = target.global_position
	target.call(&"take_damage", info)
	hit.emit(target)


func _show() -> void:
	if _view == null:
		return
	var size := maxf(radius, 0.05)
	_view.scale = Vector3(size, HEIGHT * 0.5 / 0.09, size)
	_view.position.y = 0.05
	_material.albedo_color.a = 0.85 * (1.0 - radius / reach) + 0.05
