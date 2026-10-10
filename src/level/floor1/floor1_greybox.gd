class_name Floor1Greybox
extends RefCounted
## Helpers the Floor I zone modules share: rectangles from corners, rooms in
## their zone's tint, doors, a straight service stairwell, a switchback
## stair tower and a plain ceiling lamp. Pure layout data (no nodes).
## Every flight uses Floor1Plan.STAIR_SLOPE (navigation-safe, 20.6 deg).

## Head room over the top of a stairwell.
const HEADROOM := 3.0
## Landing slabs of a tower (kit &"balcony"): thickness.
const SLAB := 0.4
## A ceiling lamp hangs this far under the ceiling.
const LAMP_DROP := 0.6
const LAMP_COLOR := Color(1.0, 0.84, 0.62)


## Rect2 from two corners (x0, z0) - (x1, z1).
static func r(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## A room in [param zone]'s colour. [param area] only for rooms behind an
## internal gate (Floor1Plan.SUB_AREAS).
static func room(layout: LevelLayout, room_id: StringName, rects: Array[Rect2], floor_y: float, ceiling_y: float, zone: StringName, name_key: StringName = &"", public: bool = true, area: StringName = &"") -> RoomSpec:
	var spec := layout.add_room(room_id, rects, floor_y, ceiling_y, Floor1Plan.zone_color(zone))
	spec.zone = zone
	spec.name_key = name_key
	spec.public = public
	spec.zone_area = area
	return spec


## One-rectangle room.
static func box(layout: LevelLayout, room_id: StringName, rect: Rect2, floor_y: float, ceiling_y: float, zone: StringName, name_key: StringName = &"", public: bool = true, area: StringName = &"") -> RoomSpec:
	return room(layout, room_id, [rect] as Array[Rect2], floor_y, ceiling_y, zone, name_key, public, area)


## A passage between two rooms of the same zone.
static func door(layout: LevelLayout, opening_id: StringName, rect: Rect2, floor_y: float, top_y: float, room_a: StringName, room_b: StringName, style: OpeningSpec.DoorStyle = OpeningSpec.DoorStyle.NONE, kind: RoomGraph.Kind = RoomGraph.Kind.OPEN) -> OpeningSpec:
	return layout.add_opening(opening_id, rect, floor_y, top_y, room_a, room_b, style, kind)


## Length of a flight rising [param rise] metres.
static func run_for(rise: float) -> float:
	return rise / Floor1Plan.STAIR_SLOPE


## A straight stairwell room over [param rect]: its floor at [param low_y]
## (the bottom landing), one flight rising along [param ascend] (a unit axis
## vector) to [param high_y], and a solid landing block at the top end
## [param top_landing] metres long. The bottom landing gets what is left
## (at least 2 m). Ceiling: high_y + HEADROOM.
static func stairwell(layout: LevelLayout, room_id: StringName, rect: Rect2, low_y: float, high_y: float, ascend: Vector2, zone: StringName, top_landing: float = 3.0, name_key: StringName = &"ROOM_SERVICE_STAIRS") -> RoomSpec:
	var spec := box(layout, room_id, rect, low_y, high_y + HEADROOM, zone, name_key, false)
	var run := run_for(high_y - low_y)
	var along_x := absf(ascend.x) > absf(ascend.y)
	var length := rect.size.x if along_x else rect.size.y
	assert(length >= run + top_landing + 2.0, "stairwell %s is too short" % room_id)
	var up := ascend.x if along_x else ascend.y
	# coordinates along the axis: the top end is where the flight arrives
	var low_end := rect.position.x if along_x else rect.position.y
	var high_end := rect.end.x if along_x else rect.end.y
	var top_from := high_end - top_landing if up > 0.0 else low_end
	var flight_from := top_from - run if up > 0.0 else low_end + top_landing
	var flight_rect := _span(rect, along_x, flight_from, flight_from + run)
	var landing_rect := _span(rect, along_x, top_from, top_from + top_landing)
	var flight := layout.add_stairs(StringName("%s_flight" % room_id), flight_rect, low_y, high_y, ascend, room_id, room_id)
	flight.step_rise = Floor1Plan.STAIR_RISE
	var middle := landing_rect.get_center()
	layout.add_piece(&"landing", Vector3(middle.x, low_y, middle.y), Vector3(landing_rect.size.x, high_y - low_y, landing_rect.size.y), room_id)
	return spec


## A switchback stair tower over [param rect]: [param flights] flights in
## two lanes side by side (split across the long axis), each rising
## (high - low) / flights, joined by landing slabs over both lanes at the
## ends. The first flight starts on the tower floor in lane
## [param first_lane] (0 = the lane at the smaller coordinate) and climbs
## towards the larger coordinate when [param first_up] is true. The top
## landing lies at the start end for an even number of flights, else at
## the far end (see top_landing_rect()).
static func tower(layout: LevelLayout, room_id: StringName, rect: Rect2, low_y: float, high_y: float, flights: int, first_lane: int, first_up: bool, zone: StringName) -> RoomSpec:
	var spec := box(layout, room_id, rect, low_y, high_y + HEADROOM, zone, &"ROOM_SERVICE_STAIRS", false)
	var rise := (high_y - low_y) / flights
	var run := run_for(rise)
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var landing := (length - run) * 0.5
	assert(landing >= 2.0, "tower %s is too short" % room_id)
	var start := rect.position.x if along_x else rect.position.y
	var across := rect.position.y if along_x else rect.position.x
	var width := rect.size.y if along_x else rect.size.x
	for i in flights:
		var lane := first_lane if i % 2 == 0 else 1 - first_lane
		var up := first_up if i % 2 == 0 else not first_up
		var lane_from := across + lane * width * 0.5
		var flight_rect := _lane(along_x, start + landing, start + landing + run, lane_from, lane_from + width * 0.5)
		var axis := Vector2(1, 0) if along_x else Vector2(0, 1)
		var flight := layout.add_stairs(StringName("%s_flight_%d" % [room_id, i + 1]), flight_rect, low_y + rise * i, low_y + rise * (i + 1), axis if up else -axis, room_id, room_id)
		flight.step_rise = Floor1Plan.STAIR_RISE
		# a landing slab over both lanes where the flight arrives
		var end_from := start + landing + run if up else start
		var slab_rect := _lane(along_x, end_from, end_from + landing, across, across + width)
		var top := low_y + rise * (i + 1)
		var middle := slab_rect.get_center()
		layout.add_piece(&"balcony", Vector3(middle.x, top - SLAB, middle.y), Vector3(slab_rect.size.x, SLAB, slab_rect.size.y), room_id)
	return spec


## Floor-plan rectangle of the top landing of tower(...) with the same
## arguments.
static func top_landing_rect(rect: Rect2, flights: int, high_y: float, low_y: float, first_up: bool) -> Rect2:
	var run := run_for((high_y - low_y) / flights)
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var landing := (length - run) * 0.5
	var start := rect.position.x if along_x else rect.position.y
	var last_up := first_up if (flights - 1) % 2 == 0 else not first_up
	var end_from := start + landing + run if last_up else start
	var across := rect.position.y if along_x else rect.position.x
	var width := rect.size.y if along_x else rect.size.x
	return _lane(along_x, end_from, end_from + landing, across, across + width)


## A plain lamp in the middle of [param room_id] under its ceiling.
static func lamp(layout: LevelLayout, room_id: StringName, energy: float = 1.2) -> void:
	var spec := layout.room(room_id)
	var middle := spec.parts[0].get_center()
	var reach := clampf(maxf(spec.parts[0].size.x, spec.parts[0].size.y) * 0.6, 6.0, 24.0)
	layout.add_light(LightSpec.MAIN, Vector3(middle.x, spec.ceiling_y - LAMP_DROP, middle.y), LAMP_COLOR, energy, reach, room_id)


static func _span(rect: Rect2, along_x: bool, from: float, to: float) -> Rect2:
	if along_x:
		return Rect2(from, rect.position.y, to - from, rect.size.y)
	return Rect2(rect.position.x, from, rect.size.x, to - from)


static func _lane(along_x: bool, from: float, to: float, side_from: float, side_to: float) -> Rect2:
	if along_x:
		return Rect2(from, side_from, to - from, side_to - side_from)
	return Rect2(side_from, from, side_to - side_from, to - from)
