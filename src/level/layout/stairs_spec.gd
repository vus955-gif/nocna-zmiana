class_name StairsSpec
extends RefCounted
## A straight flight of stairs. Visual steps are separate from collision:
## walkers slide on an invisible ramp through the step nosings, so nobody
## has to climb a step taller than the navigation climb limit.

var id: StringName = &""
## Floor-plan footprint of the steps (x, z).
var rect := Rect2()
var bottom_y: float = 0.0
var top_y: float = 3.0
## Direction of ascent on the floor plan (unit, along x or z).
var ascend := Vector2(0.0, -1.0)
var room_low: StringName = &""
var room_high: StringName = &""
## Railings on the left / right side (seen walking up).
var rail_left: bool = true
var rail_right: bool = true
## Target riser height; the real one divides the rise evenly.
var step_rise: float = 0.2


static func make(stairs_id: StringName, area: Rect2, bottom: float, top: float, up: Vector2, low_room: StringName, high_room: StringName) -> StairsSpec:
	var stairs := StairsSpec.new()
	stairs.id = stairs_id
	stairs.rect = area
	stairs.bottom_y = bottom
	stairs.top_y = top
	stairs.ascend = up.normalized()
	stairs.room_low = low_room
	stairs.room_high = high_room
	return stairs


func step_count() -> int:
	return maxi(int(round((top_y - bottom_y) / step_rise)), 1)


## Length of the flight along the ascent.
func run() -> float:
	return rect.size.y if absf(ascend.y) > absf(ascend.x) else rect.size.x


## Width across the ascent.
func width() -> float:
	return rect.size.x if absf(ascend.y) > absf(ascend.x) else rect.size.y


## Transform whose origin is the middle of the bottom front edge and whose
## -Z points up the flight.
func frame() -> Transform3D:
	var yaw := atan2(-ascend.x, -ascend.y)
	var middle := rect.get_center() - ascend * (run() * 0.5)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(middle.x, bottom_y, middle.y))
