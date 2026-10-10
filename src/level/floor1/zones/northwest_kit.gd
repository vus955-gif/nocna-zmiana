extends RefCounted
## Helpers the north-west wings share (zones/assyria.gd, zones/americas.gd;
## plan docs/superpowers/plans/2026-10-03-p1-w4-asyria-ameryki.md): reliefs
## flat on a wall, walkable slabs and their railings (the Lion Hunt
## gallery), tiers of a stepped platform and fire bowls. Pure layout data.
## The gates, lairs, spots, sconces, red lamps and cameras come from the
## west wings' kit (west_kit.gd), the moon group and the walkers from the
## hub's (hub_kit.gd).

## Thickness of a walkable slab (kit &"balcony").
const SLAB := 0.4
const RAIL_HEIGHT := 1.1
const RAIL_THICKNESS := 0.15
## The fire in a bowl (design 10.1: the Americas are lit by fire).
const FIRE := Color(1.0, 0.5, 0.2)


## A relief (a carved slab, a bronze band, a frieze) flat on a wall, no
## collision: [param at] is the middle of its lower edge against the wall,
## [param yaw] turns its face into the room (west wall -PI/2, east wall
## PI/2, north wall PI, south wall 0).
static func relief(layout: LevelLayout, at: Vector3, width: float, height: float, yaw: float, room: StringName) -> PieceSpec:
	return layout.add_piece(&"relief", at, Vector3(width, height, 0.1), room, yaw, false)


## A walkable slab over [param rect] whose top is at [param top].
static func slab(layout: LevelLayout, rect: Rect2, top: float, room: StringName) -> PieceSpec:
	var middle := rect.get_center()
	return layout.add_piece(&"balcony", Vector3(middle.x, top - SLAB, middle.y), Vector3(rect.size.x, SLAB, rect.size.y), room)


## A railing [param length] m long centred at [param at] (its foot), along
## x (yaw 0) or along z (yaw PI/2).
static func rail(layout: LevelLayout, at: Vector3, length: float, yaw: float, room: StringName) -> void:
	layout.add_piece(&"railing", at, Vector3(length, RAIL_HEIGHT, RAIL_THICKNESS), room, yaw)


## One solid tier of a stepped platform over [param rect], from
## [param base] up to [param top].
static func tier(layout: LevelLayout, kit: StringName, rect: Rect2, base: float, top: float, room: StringName) -> PieceSpec:
	var middle := rect.get_center()
	return layout.add_piece(kit, Vector3(middle.x, base, middle.y), Vector3(rect.size.x, top - base, rect.size.y), room)


## A flight of [param rise] metres over [param rect] at the plan's slope.
static func flight(layout: LevelLayout, flight_id: StringName, rect: Rect2, bottom: float, top: float, ascend: Vector2, low_room: StringName, high_room: StringName) -> StairsSpec:
	var stairs := layout.add_stairs(flight_id, rect, bottom, top, ascend, low_room, high_room)
	stairs.step_rise = Floor1Plan.STAIR_RISE
	return stairs


## A fire bowl standing on the floor at [param at] and its warm light just
## over the flames (the bowl is the fixture).
static func fire(layout: LevelLayout, at: Vector3, room: StringName, energy: float = 1.6, reach: float = 7.0) -> LightSpec:
	layout.add_piece(&"brazier", at, Vector3(0.8, 1.0, 0.8), room)
	return layout.add_light(LightSpec.MAIN, at + Vector3(0, 1.3, 0), FIRE, energy, reach, room)
