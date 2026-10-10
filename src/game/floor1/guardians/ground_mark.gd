class_name GroundMark
extends Node3D
## A telegraph drawn on the floor (the guardians' warnings, readable from
## the guard's eye level): a dark shadow that deepens and a hot rim that
## brightens as [member progress] goes 0 -> 1 (the attack lands at 1).
## - disc(): the shadow of a hand coming down (a disc, stretched into a
##   palm by [param stretch]); the rim closes in from half again its size;
## - arc(): a band of a ring between two radii and two bearings (0 = the
##   mark's -Z, positive toward its -X), where a sweep will pass;
## - lane(): a straight lane from the mark's origin along its -Z, where a
##   charge will run; the shadow fills it from its start to its far end as
##   the moment comes, and [member length] may change while it shows (the
##   lane ends at the first obstacle).
## Lives in world space (top_level): place it with global_transform after
## add_child(); a mover (the guardian) never drags it along.

const SHADOW := Color(0.02, 0.01, 0.0)
const RIM := Color(1.0, 0.42, 0.12)
## Segments of a full circle.
const SEGMENTS := 40
const RIM_WIDTH := 0.12

## 0 (it just appeared) .. 1 (it lands now).
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_refresh()

## A lane's length (m): the lane's shadow and side rims stretch to it, its
## end bar moves with it.
var length: float = 1.0:
	set(value):
		length = maxf(value, 0.1)
		_refresh()

var _shadow_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _rim: MeshInstance3D
var _end: MeshInstance3D
var _disc := false
var _lane := false
var _fade: Tween


## A palm's shadow of [param radius] (stretched [param stretch] times
## along its -Z).
static func disc(radius: float, stretch: float = 1.0) -> GroundMark:
	var mark := GroundMark.new()
	mark._disc = true
	mark._build(_sector(0.0, radius, -PI, PI), _ring(radius - RIM_WIDTH, radius))
	mark._shadow.scale = Vector3(1.0, 1.0, stretch)
	mark._rim.scale = Vector3(1.0, 1.0, stretch)
	return mark


## A band from radius [param inner] to [param outer], from bearing
## [param from] to [param to] (rad).
static func arc(inner: float, outer: float, from: float, to: float) -> GroundMark:
	var mark := GroundMark.new()
	var low := minf(from, to)
	var high := maxf(from, to)
	var edges := _sector(inner, inner + RIM_WIDTH, low, high)
	_append(edges, _sector(outer - RIM_WIDTH, outer, low, high))
	mark._build(_sector(inner, outer, low, high), edges)
	return mark


## A lane [param width] wide and [param lane_length] long from the mark's
## origin along its -Z (a charge's path).
static func lane(width: float, lane_length: float) -> GroundMark:
	var mark := GroundMark.new()
	mark._lane = true
	var half := width * 0.5
	var sides := _rect(-half, -half + RIM_WIDTH, 0.0, -1.0)
	_append(sides, _rect(half - RIM_WIDTH, half, 0.0, -1.0))
	mark._build(_rect(-half, half, 0.0, -1.0), sides)
	mark._end = mark._view(_rect(-half, half, RIM_WIDTH * 0.5, -RIM_WIDTH * 0.5), mark._rim_mat, 0.03)
	mark.length = lane_length
	return mark


func _init() -> void:
	top_level = true
	name = "GroundMark"


## Fades away over [param seconds] and frees itself.
func vanish(seconds: float = 0.3) -> void:
	if _fade != null:
		return
	_fade = create_tween()
	_fade.tween_method(func(alpha: float) -> void:
		_shadow_mat.albedo_color.a = alpha * _shadow_alpha()
		_rim_mat.albedo_color.a = alpha, 1.0, 0.0, seconds)
	_fade.tween_callback(queue_free)


## The shadow's opacity now (tests read it).
func shadow_alpha() -> float:
	return _shadow_mat.albedo_color.a


func _build(shadow: ArrayMesh, rim: ArrayMesh) -> void:
	_shadow_mat = GuardianLooks.shade(SHADOW, 0.0)
	_rim_mat = GuardianLooks.glow(RIM, 0.0, true)
	_shadow = _view(shadow, _shadow_mat, 0.025)
	_rim = _view(rim, _rim_mat, 0.03)
	_refresh()


func _view(mesh: ArrayMesh, material: Material, lift: float) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position.y = lift
	add_child(view)
	return view


func _shadow_alpha() -> float:
	return lerpf(0.12, 0.62, progress * progress)


func _refresh() -> void:
	if _shadow_mat == null or _fade != null:
		return
	_shadow_mat.albedo_color.a = _shadow_alpha()
	# the rim pulses faster as the moment comes
	_rim_mat.albedo_color.a = lerpf(0.25, 1.0, progress)
	if _disc:
		var closing := lerpf(1.5, 1.0, MotionClip.eased(MotionClip.OUT, progress))
		_rim.scale = Vector3(closing, 1.0, closing * _shadow.scale.z)
	elif _lane:
		# the shadow runs out along the lane toward its end
		_shadow.scale = Vector3(1.0, 1.0, length * lerpf(0.2, 1.0, MotionClip.eased(MotionClip.OUT, progress)))
		_rim.scale = Vector3(1.0, 1.0, length)
		if _end != null:
			_end.position.z = -length


## A flat band (XZ plane, normal up) from radius [param r0] to [param r1],
## bearing [param a0] to [param a1].
static func _sector(r0: float, r1: float, a0: float, a1: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var steps := maxi(2, ceili(SEGMENTS * (a1 - a0) / TAU))
	for i in steps:
		var b0 := lerpf(a0, a1, float(i) / steps)
		var b1 := lerpf(a0, a1, float(i + 1) / steps)
		var d0 := Vector3(-sin(b0), 0.0, -cos(b0))
		var d1 := Vector3(-sin(b1), 0.0, -cos(b1))
		for corner: Vector3 in [d0 * r0, d1 * r0, d1 * r1, d0 * r0, d1 * r1, d0 * r1]:
			tool.add_vertex(corner)
	return tool.commit()


static func _ring(r0: float, r1: float) -> ArrayMesh:
	return _sector(r0, r1, -PI, PI)


## A flat rectangle (XZ plane, normal up) from x0 to x1 and z0 to z1.
static func _rect(x0: float, x1: float, z0: float, z1: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var a := Vector3(x0, 0.0, z0)
	var b := Vector3(x1, 0.0, z0)
	var c := Vector3(x1, 0.0, z1)
	var d := Vector3(x0, 0.0, z1)
	for corner: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(corner)
	return tool.commit()


## Adds [param more]'s triangles to [param mesh] (one surface each).
static func _append(mesh: ArrayMesh, more: ArrayMesh) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, more.surface_get_arrays(0))
