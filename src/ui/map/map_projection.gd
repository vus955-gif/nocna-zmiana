class_name MapProjection
extends RefCounted
## The paper map's projection: world floor-plan points (x, z in metres,
## -Z = north) to sheet pixels and back. One uniform scale, north up, the
## floor centred in its area of the sheet.

## The world rectangle shown (x, z), margin included.
var world := Rect2()
## Where it lies on the sheet (px).
var area := Rect2()
## Sheet pixels per metre.
var scale: float = 1.0


## [param world_rect] (x, z) grown by [param margin] m, fitted into
## [param into] (sheet px) at one scale and centred.
static func fit(world_rect: Rect2, into: Rect2, margin: float = MapStyle.MAP_MARGIN) -> MapProjection:
	var projection := MapProjection.new()
	projection.world = world_rect.grow(margin)
	projection.scale = minf(into.size.x / projection.world.size.x, into.size.y / projection.world.size.y)
	var used := projection.world.size * projection.scale
	projection.area = Rect2(into.position + (into.size - used) * 0.5, used)
	return projection


## Floor I's map area on the leaflet.
static func floor1() -> MapProjection:
	return fit(Floor1Plan.bounds(), MapStyle.MAP_AREA)


func to_sheet(flat: Vector2) -> Vector2:
	return area.position + (flat - world.position) * scale


func to_world(sheet: Vector2) -> Vector2:
	return world.position + (sheet - area.position) / scale


func rect_to_sheet(rect: Rect2) -> Rect2:
	return Rect2(to_sheet(rect.position), rect.size * scale)


## A world point (its x and z) on the sheet.
func point(at: Vector3) -> Vector2:
	return to_sheet(Vector2(at.x, at.z))


## Metres to sheet pixels.
func length(metres: float) -> float:
	return metres * scale
