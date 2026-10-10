class_name SunBeam
extends Node3D
## The Colossus's sun beam: a white-gold core in an orange halo from its
## eyes to whatever it meets first (a column, the throne, a wall, the
## floor), a light and sparks where it burns. fire() casts it through the
## level (layer WORLD only: exhibits, the guard and the Colossus himself do
## not stop it) and returns where it ended and what it hit; the Colossus
## decides the damage (segment_hits_capsule()). World space (top_level).

const CORE_RADIUS := 0.12
const HALO_RADIUS := 0.38
## How close to the guard's body axis the beam must pass to burn him: his
## radius plus the beam's.
const REACH := 0.4 + 0.25
const LENGTH := 60.0
const CORE := Color(1.0, 0.95, 0.78)
const HALO := Color(1.0, 0.55, 0.16)
## Sparks at the burning end every this many seconds.
const SPARK_EVERY := 0.09

var _core: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _halo_mat: StandardMaterial3D
var _spark_timer: float = 0.0
var _time: float = 0.0


func _init() -> void:
	top_level = true
	name = "SunBeam"


func _ready() -> void:
	_core = _cylinder(CORE_RADIUS, GuardianLooks.glow(CORE, 1.0))
	_halo_mat = GuardianLooks.glow(HALO, 0.35)
	_halo = _cylinder(HALO_RADIUS, _halo_mat)
	_light = OmniLight3D.new()
	_light.light_color = HALO
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	add_child(_light)
	hide_beam()


## Burns from [param from] toward [param toward] (up to LENGTH m): returns
## {end: Vector3, collider: Object (null = nothing within LENGTH),
## normal: Vector3}. Shows the beam between the two.
func fire(from: Vector3, toward: Vector3, delta: float = 0.0) -> Dictionary:
	var direction := (toward - from).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var far := from + direction * LENGTH
	var result := {"end": far, "collider": null, "normal": -direction}
	if is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(from, far, Layers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			result["end"] = hit["position"]
			result["collider"] = hit["collider"]
			result["normal"] = hit["normal"]
	_show(from, result["end"], result["normal"], delta)
	return result


func hide_beam() -> void:
	if _core == null:
		return
	_core.visible = false
	_halo.visible = false
	_light.light_energy = 0.0
	_light.visible = false


func is_burning() -> bool:
	return _core != null and _core.visible


## True when the segment [param a] -> [param b] passes within [param reach]
## of a standing body: its axis from [param feet] up [param height] m.
static func segment_hits_capsule(a: Vector3, b: Vector3, feet: Vector3, height: float, reach: float = REACH) -> bool:
	var bottom := feet + Vector3.UP * 0.2
	var top := feet + Vector3.UP * maxf(height - 0.2, 0.2)
	return segment_distance(a, b, bottom, top) <= reach


## Shortest distance between segments [param p1]-[param q1] and
## [param p2]-[param q2].
static func segment_distance(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.000001 and e <= 0.000001:
		return p1.distance_to(p2)
	if a <= 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 0.000001:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denominator := a * e - b * b
			s = clampf((b * f - c * e) / denominator, 0.0, 1.0) if denominator > 0.000001 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


func _show(from: Vector3, to: Vector3, normal: Vector3, delta: float) -> void:
	if _core == null:
		return
	_time += delta
	var run := to - from
	var length := run.length()
	if length < 0.01:
		hide_beam()
		return
	var up := run / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var flicker := 1.0 + 0.08 * sin(_time * 53.0) + 0.05 * sin(_time * 31.0)
	# the cylinder's height (its Y) along the beam, its width flickering
	var stretched := Basis(side * flicker, up * length, side.cross(up).normalized() * flicker)
	for view: MeshInstance3D in [_core, _halo]:
		view.visible = true
		view.global_transform = Transform3D(stretched, from + run * 0.5)
	_halo_mat.albedo_color.a = 0.3 + 0.08 * sin(_time * 23.0)
	_light.visible = true
	_light.global_position = to + normal * 0.6
	_light.light_energy = 4.0 * flicker
	_spark_timer -= delta
	if _spark_timer <= 0.0 and delta > 0.0:
		_spark_timer = SPARK_EVERY
		Fx.impact(to, normal, ExhibitMaterial.Kind.METAL, 1.2)


func _cylinder(radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view

