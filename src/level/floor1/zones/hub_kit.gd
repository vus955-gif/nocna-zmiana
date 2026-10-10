extends RefCounted
## Helpers the hub's zone modules share (workstream W2: court, entrance,
## booth, north_hall; plan docs/superpowers/plans/2026-10-03-p1-w2-hub.md):
## bearings round the Reading Room drum, markers that look at something
## (CCTV lenses), wing signs in the colour of the zone they lead to, and
## lamps with their fixtures. Pure layout data, no nodes.
##
## Bearings are degrees clockwise from north (-Z) seen from above: 0 north,
## 90 east, 180 south, 270 west. A piece standing on bearing b with its
## front (-Z) facing outwards has yaw -b (radians).

const WARM := Color(1.0, 0.8, 0.55)
const TUBE := Color(0.85, 0.95, 0.88)
const RED := Color(1.0, 0.12, 0.08)
## Moonlight through the glass roof and the windows (design 10.1: the court's
## cold moon in the fog).
const MOON := Color(0.6, 0.7, 1.0)
const GREEN_SHADE := Color(0.75, 1.0, 0.62)
const BRONZE := Color(0.42, 0.31, 0.18)
## Moonlight has no fuse: the moon pools live in the moon group (a blackout
## or a power cut leaves them on; a full moon brightens them).
const MOON_GROUP := LightSpec.MOON


## Unit floor-plan direction of [param degrees] (y = 0).
static func direction(degrees: float) -> Vector3:
	var a := deg_to_rad(degrees)
	return Vector3(sin(a), 0.0, -cos(a))


## The tangent at [param degrees] (clockwise, y = 0).
static func tangent(degrees: float) -> Vector3:
	var a := deg_to_rad(degrees)
	return Vector3(cos(a), 0.0, sin(a))


## The point [param radius] m out on [param degrees] at height [param y].
static func at_bearing(radius: float, degrees: float, y: float = 0.0) -> Vector3:
	return direction(degrees) * radius + Vector3.UP * y


## Yaw of a piece on [param degrees] whose front (-Z) faces outwards.
static func yaw_out(degrees: float) -> float:
	return -deg_to_rad(degrees)


## Yaw of a piece on [param degrees] whose front (-Z) faces the centre.
static func yaw_in(degrees: float) -> float:
	return PI - deg_to_rad(degrees)


## A marker at [param at] whose -Z looks at [param target] (a CCTV lens).
static func look_marker(layout: LevelLayout, marker_id: StringName, at: Vector3, target: Vector3, room_id: StringName) -> void:
	layout.add_marker(marker_id, at, room_id)
	layout.markers[marker_id] = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)


## A plate over a doorway (or on a post) in the colour of [param zone], the
## zone it points to, plus its marker (origin = the plate's base centre,
## -Z = the face people read). No collision.
static func wing_sign(layout: LevelLayout, marker_id: StringName, at: Vector3, width: float, yaw: float, room_id: StringName, zone: StringName) -> PieceSpec:
	var piece := layout.add_piece(&"sign_wing_portal", at, Vector3(width, 0.7, 0.08), room_id, yaw, false)
	piece.tint = Floor1Plan.zone_color(zone)
	layout.add_marker(marker_id, at, room_id, yaw)
	return piece


## A lamp with an optional fixture turned by [param yaw].
static func lamp(layout: LevelLayout, group: StringName, at: Vector3, color: Color, energy: float, reach: float, room_id: StringName, fixture: StringName = &"", yaw: float = 0.0, shadow: bool = false) -> LightSpec:
	var light := layout.add_light(group, at, color, energy, reach, room_id, fixture, shadow)
	light.fixture_yaw = yaw
	return light


## A spot light at [param at] aimed at [param target].
static func spot(layout: LevelLayout, group: StringName, at: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float, room_id: StringName, shadow: bool = false) -> LightSpec:
	var light := layout.add_light(group, at, color, energy, reach, room_id, &"", shadow)
	light.kind = LightSpec.Kind.SPOT
	light.direction = (target - at).normalized()
	light.spot_angle = angle
	return light


## Adds dormant slots at [param spots] (x, z on the floor at [param y]),
## each facing [param look_at] (x, z), and returns their indices in
## LevelLayout.spawn_slots.
static func slots(layout: LevelLayout, room_id: StringName, set_id: int, kinds: Array[StringName], spots: Array, y: float = 0.0, look_at: Vector2 = Vector2.ZERO) -> Array[int]:
	var added: Array[int] = []
	for spot: Vector2 in spots:
		layout.add_spawn(Vector3(spot.x, y, spot.y), room_id, set_id, kinds, true, facing(spot, look_at))
		added.append(layout.spawn_slots.size() - 1)
	return added


## Yaw that turns a front (-Z) standing at [param from] towards [param to].
static func facing(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y) if d.length() > 0.01 else 0.0


## One awake exhibit walking [param route] (floor points), its patrol and
## its slot (set [param set_id]).
static func walker(layout: LevelLayout, patrol_id: StringName, room_id: StringName, set_id: int, kinds: Array[StringName], route: PackedVector3Array, loop: bool = true) -> SpawnSlot:
	layout.add_patrol(patrol_id, room_id, route, loop)
	var slot := layout.add_spawn(route[0], room_id, set_id, kinds, false)
	slot.patrol = patrol_id
	return slot
