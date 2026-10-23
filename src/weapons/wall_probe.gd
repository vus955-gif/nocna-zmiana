class_name WallProbe
extends RefCounted
## How near the building is to the weapon in hand (owner's note 46, plan
## 2026-10-21-animacje-fpp). The viewmodel is drawn with its depth squashed
## to the eye (BaseMaterial3D.z_clip_scale: a wall never covers it), but a
## wall nearer than its muzzle would show the gun as if it went through.
## Two sphere casts from the eye along the building (Layers.WORLD: walls,
## doors, cases; never an exhibit, which is a target): straight ahead, and
## toward where the gun's muzzle shows on screen at the camera's field of
## view (the gun is drawn with its own narrower one, so at FOV 110 its
## corner of the screen shows the world further right and lower than at
## FOV 70). The nearest hit's depth along the view gives [member want]
## (0 from the weapon's reach out, 1 as near as the guard gets);
## [member pull] follows it on a critically damped spring, so the weapon
## eases back and forth without a jump.

## The casts' radius (m): a gun's thickness, so they do not slip past a
## door frame.
const RADIUS := 0.05
## As near as the guard's eye gets to a wall (his capsule's radius is 0.4).
const FULL_AT := 0.42
## The pull's spring (rad/s): about a fifth of a second to settle.
const OMEGA := 13.0

var want: float = 0.0
var pull: float = 0.0
var _speed: float = 0.0
var _query: PhysicsShapeQueryParameters3D = null


## Casts from [param eye] (the camera's transform) and sets [member want]:
## [param gun_point] is the weapon's muzzle at rest in the eye's space (as
## the viewmodel draws it, field of view ArtLibrary.VIEWMODEL_FOV),
## [param start] the depth (m) from which a wall starts to pull,
## [param fov] the camera's field of view (degrees). Returns want.
func measure(space: PhysicsDirectSpaceState3D, eye: Transform3D, gun_point: Vector3, start: float, fov: float) -> float:
	var depth := _depth_along(space, eye, Vector3.FORWARD, start)
	var on_screen := screen_point(gun_point, fov)
	if on_screen.z < -0.05:
		depth = minf(depth, _depth_along(space, eye, on_screen.normalized(), start))
	want = want_for(depth, start)
	return want


## Eases [member pull] toward [member want].
func ease(delta: float) -> void:
	var accel := OMEGA * OMEGA * (want - pull) - 2.0 * OMEGA * _speed
	_speed += accel * delta
	pull = clampf(pull + _speed * delta, 0.0, 1.0)


func reset() -> void:
	want = 0.0
	pull = 0.0
	_speed = 0.0


## 0 for a wall at [param start] m or further, 1 at FULL_AT or nearer,
## smooth between.
static func want_for(depth: float, start: float) -> float:
	if depth >= start:
		return 0.0
	return smoothstep(0.0, 1.0, (start - depth) / maxf(start - FULL_AT, 0.01))


## [param point] of the viewmodel (eye space, drawn with
## ArtLibrary.VIEWMODEL_FOV) moved to where the world camera with
## [param fov] shows the same spot on screen (as
## WeaponHolder.on_screen_like_the_view).
static func screen_point(point: Vector3, fov: float) -> Vector3:
	var k := tan(deg_to_rad(fov) * 0.5) / tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	return Vector3(point.x * k, point.y * k, point.z)


## Depth along the view (m) of the building first met along
## [param direction] (eye space, unit) out to depth [param start]; INF when
## nothing is that near.
func _depth_along(space: PhysicsDirectSpaceState3D, eye: Transform3D, direction: Vector3, start: float) -> float:
	var ahead := maxf(-direction.z, 0.05)
	var length := start / ahead
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = RADIUS
		_query.shape = sphere
		_query.collision_mask = Layers.WORLD
		_query.collide_with_areas = false
	var world_dir := (eye.basis * direction).normalized()
	_query.transform = Transform3D(Basis.IDENTITY, eye.origin)
	_query.motion = world_dir * length
	var fractions := space.cast_motion(_query)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return INF
	return (fractions[0] * length + RADIUS) * ahead
