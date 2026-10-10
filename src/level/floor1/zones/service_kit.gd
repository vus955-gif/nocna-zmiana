extends RefCounted
## Helpers the service zones share (workstream W5b: zones/basement.gd and
## zones/roof.gd; plan docs/superpowers/plans/2026-10-03-p1-w5b-podziemia-
## dach.md): the group of flickering fluorescent tubes, lamps that never
## shine through a floor slab (spots aimed straight down; low wall lamps
## with a short reach), pipe runs in a wing's colour, deck slabs and
## railings. Pure layout data, no nodes.

## Fluorescent tubes the game may flicker: LevelLighting puts every lamp in
## its LightSpec group and its fitting in "<group>_fixtures", so the game
## finds them by this name (until LightSpec has a constant of its own: a
## request to the controller, with the blackout switching them off too).
const FLICKER := LightSpec.FLICKER
const TUBE := Color(0.85, 0.95, 0.88)
const RED := Color(1.0, 0.12, 0.08)
const MOON := Color(0.6, 0.7, 1.0)
const WARM := Color(1.0, 0.8, 0.55)
## Embers behind a furnace door (fire has no fuse: the emergency group).
const EMBER := Color(1.0, 0.42, 0.12)
## Half-angle of a ceiling lamp's cone: wide, but never upwards.
const CONE := 75.0
const SLAB := 0.4
const RAIL_HEIGHT := 1.1
const RAIL_DEPTH := 0.15
const PIPE := 0.25


## A ceiling tube at [param at] lighting the floor under it (a spot aimed
## down: nothing reaches up through the slab into the rooms above). Tubes
## run along x unless [param along_x] is false; [param flicker] puts it in
## the flickering group.
static func tube(layout: LevelLayout, at: Vector3, room: StringName, reach: float = 4.5, energy: float = 1.2, along_x: bool = true, flicker: bool = false) -> LightSpec:
	var light := down(layout, FLICKER if flicker else LightSpec.MAIN, at, TUBE, energy, reach, room, &"tube_lamp")
	light.fixture_yaw = 0.0 if along_x else PI * 0.5
	return light


## A spot aimed straight down with the wide CONE.
static func down(layout: LevelLayout, group: StringName, at: Vector3, color: Color, energy: float, reach: float, room: StringName, fixture: StringName = &"", angle: float = CONE) -> LightSpec:
	var light := layout.add_light(group, at, color, energy, reach, room, fixture)
	light.kind = LightSpec.Kind.SPOT
	light.direction = Vector3.DOWN
	light.spot_angle = angle
	return light


## A red emergency lamp on a wall (always on); [param yaw] turns the
## fitting away from its wall (west wall -PI/2, east PI/2, north PI, south
## 0). Its short reach ends under the floor above.
static func red(layout: LevelLayout, at: Vector3, yaw: float, room: StringName, reach: float = 2.5) -> LightSpec:
	var light := layout.add_light(LightSpec.EMERGENCY, at, RED, 1.0, reach, room, &"emergency_lamp")
	light.fixture_yaw = yaw
	return light


## A straight pipe under a ceiling between two points at one height (no
## collision), tinted [param tint].
static func pipe(layout: LevelLayout, from: Vector3, to: Vector3, room: StringName, tint: Color, thickness: float = PIPE) -> PieceSpec:
	var middle := (from + to) * 0.5
	var along_x := absf(to.x - from.x) >= absf(to.z - from.z)
	var piece := layout.add_piece(&"pipe", middle - Vector3.UP * thickness * 0.5, Vector3(from.distance_to(to) + thickness, thickness, thickness), room, 0.0 if along_x else PI * 0.5, false)
	piece.tint = tint
	return piece


## A deck slab over [param rect] whose top is at [param top].
static func slab(layout: LevelLayout, rect: Rect2, top: float, room: StringName) -> PieceSpec:
	var middle := rect.get_center()
	return layout.add_piece(&"balcony", Vector3(middle.x, top - SLAB, middle.y), Vector3(rect.size.x, SLAB, rect.size.y), room)


## A railing from [param a] to [param b] (points on the deck, along x or z).
static func rail(layout: LevelLayout, a: Vector3, b: Vector3, room: StringName) -> PieceSpec:
	var along_x := absf(b.x - a.x) >= absf(b.z - a.z)
	return layout.add_piece(&"railing", (a + b) * 0.5, Vector3(a.distance_to(b), RAIL_HEIGHT, RAIL_DEPTH), room, 0.0 if along_x else PI * 0.5)
