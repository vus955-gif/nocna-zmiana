class_name RoarWave
extends Node3D
## The visible wave of a Fu dog's roar: RINGS translucent rings that leave
## the mouth one after another, rush forward along the roar, widen to the
## cone's mouth and fade (LIFE s), with a warm flash at the mouth. Frees
## itself when done. Meshes and materials are shared.

const RINGS := 3
const RING_GAP := 0.07
const LIFE := 0.45
## How far the rings travel (m) and how wide they get (m, radius).
const REACH := 5.5
const WIDTH := 2.4
const COLOR := Color(1.0, 0.82, 0.55)

static var _ring_mesh: TorusMesh = null
static var _ring_material: StandardMaterial3D = null

var _rings: Array[MeshInstance3D] = []
var _age: float = 0.0


## A wave from [param from] along [param forward] (world), under [param parent].
static func spawn(parent: Node, from: Vector3, forward: Vector3) -> RoarWave:
	var wave := RoarWave.new()
	var look := Vector3(forward.x, 0.0, forward.z)
	look = look.normalized() if look.length_squared() > 0.0001 else Vector3.FORWARD
	parent.add_child(wave)
	wave.global_transform = Transform3D(Basis.looking_at(look, Vector3.UP), from)
	Fx.flash(from, COLOR, 2.2, 4.5, 0.3)
	return wave


func _ready() -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.82
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 8
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ring_material.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.45)
		_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_material.no_depth_test = false
	for i in RINGS:
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh
		ring.material_override = _ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the torus lies in XZ; stood up it faces along the roar (-Z)
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3.ONE * 0.05
		add_child(ring)
		_rings.append(ring)


func _process(delta: float) -> void:
	_age += delta
	var done := true
	for i in RINGS:
		var ring := _rings[i]
		var t := (_age - i * RING_GAP) / LIFE
		if t < 0.0:
			ring.visible = false
			done = false
			continue
		if t >= 1.0:
			ring.visible = false
			continue
		done = false
		ring.visible = true
		var out := 1.0 - (1.0 - t) * (1.0 - t)
		ring.position = Vector3(0.0, 0.0, -REACH * out)
		var radius := 0.12 + WIDTH * out
		ring.scale = Vector3(radius, radius, radius * (1.0 - 0.6 * t))
		ring.transparency = t * t
	if done:
		queue_free()
