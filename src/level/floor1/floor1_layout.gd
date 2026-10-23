class_name Floor1Layout
extends RefCounted
## Floor I as data: one module per zone (src/level/floor1/zones/<zone>.gd,
## each with static func build(layout: LevelLayout) -> void) adds its rooms,
## pieces, stairs, lights, spawn slots, loot, markers and internal gates
## inside its Floor1Plan boxes; then the junctions between zones are added
## here (openings + their gates), with the room on each side found at the
## junction. No build logic: LevelBuilder turns the result into nodes.
## A module never adds a junction opening itself and never touches another
## zone's rooms.

const Booth := preload("res://src/level/floor1/zones/booth.gd")
const Entrance := preload("res://src/level/floor1/zones/entrance.gd")
const Court := preload("res://src/level/floor1/zones/court.gd")
const NorthHall := preload("res://src/level/floor1/zones/north_hall.gd")
const Egypt := preload("res://src/level/floor1/zones/egypt.gd")
const Assyria := preload("res://src/level/floor1/zones/assyria.gd")
const Greece := preload("res://src/level/floor1/zones/greece.gd")
const Enlightenment := preload("res://src/level/floor1/zones/enlightenment.gd")
const Asia := preload("res://src/level/floor1/zones/asia.gd")
const Americas := preload("res://src/level/floor1/zones/americas.gd")
const Basement := preload("res://src/level/floor1/zones/basement.gd")
const Roof := preload("res://src/level/floor1/zones/roof.gd")
## The story layer: markers only, in rooms the zones built (labels, curios,
## the staff's trails; plan 2026-10-21-opowiesc-muzeum).
const Story := preload("res://src/level/floor1/zones/story.gd")

## Problems found while putting the floor together (a junction without a
## room on one side...); empty for a sound layout. Tests read it.
static var problems: PackedStringArray = []


static func create() -> LevelLayout:
	problems = PackedStringArray()
	var layout := LevelLayout.new()
	layout.id = &"floor1"
	for zone in Floor1Plan.ZONES:
		var first_room := layout.rooms.size()
		build_zone(layout, zone)
		for i in range(first_room, layout.rooms.size()):
			var room := layout.rooms[i]
			if room.zone == &"":
				room.zone = zone
			elif room.zone != zone:
				_problem("room %s of module %s claims zone %s" % [room.id, zone, room.zone])
	for slot in layout.spawn_slots:
		var room := layout.room(slot.room)
		slot.zone = room.zone if room != null else &""
	add_junctions(layout)
	Story.build(layout)
	return layout


## Runs the module of [param zone] on [param layout].
static func build_zone(layout: LevelLayout, zone: StringName) -> void:
	match zone:
		&"booth":
			Booth.build(layout)
		&"entrance":
			Entrance.build(layout)
		&"court":
			Court.build(layout)
		&"north_hall":
			NorthHall.build(layout)
		&"egypt":
			Egypt.build(layout)
		&"assyria":
			Assyria.build(layout)
		&"greece":
			Greece.build(layout)
		&"enlightenment":
			Enlightenment.build(layout)
		&"asia":
			Asia.build(layout)
		&"americas":
			Americas.build(layout)
		&"basement":
			Basement.build(layout)
		&"roof":
			Roof.build(layout)
		_:
			_problem("no module for zone %s" % zone)


## Adds every Floor1Plan junction as an opening between the rooms found on
## its two sides (room A in zone_a) and, for a gated junction, its GateSpec
## (a BOLT opens from the room on its bolt area's side).
static func add_junctions(layout: LevelLayout) -> void:
	for j in Floor1Plan.junctions():
		var room_a := junction_room(layout, j, j.zone_a)
		var room_b := junction_room(layout, j, j.zone_b)
		if room_a == &"" or room_b == &"":
			_problem("junction %s: no room on the %s side" % [j.id, j.zone_a if room_a == &"" else j.zone_b])
			continue
		var kind := RoomGraph.Kind.GATE if j.gate != &"" else RoomGraph.Kind.OPEN
		var passage := layout.add_opening(j.id, j.rect, j.floor_y, j.top_y, room_a, room_b, j.style, kind)
		if j.style == OpeningSpec.DoorStyle.GATE:
			passage.face_room = room_a
		if j.gate == &"":
			continue
		var plan := Floor1Plan.gate(j.gate)
		var bolt_room: StringName = &""
		if plan.kind == GateSpec.Kind.BOLT:
			bolt_room = room_a if plan.bolt_area == j.area_a else room_b
		layout.add_gate(plan.id, plan.kind, j.id, plan.requirement, plan.label_key, bolt_room)


## The room of [param zone] right behind junction [param j] (&"" = none).
static func junction_room(layout: LevelLayout, j: Floor1Plan.Junction, zone: StringName) -> StringName:
	var point := j.point_in(zone)
	if point == Vector3.INF:
		return &""
	var room_id := layout.room_at(point)
	var room := layout.room(room_id)
	if room == null or room.zone != zone:
		return &""
	return room_id


## What NightDirector needs to know about Floor I: the generic description
## (graph, havens as start rooms, slots, loot, secret rooms) plus the rooms
## that must stay reachable (every progress pickup, guardian and haven) and
## the finale's room. No crystal cases, no fuse draw: Floor I's fuses are
## permanent key items (Floor1Plan.PICKUPS).
static func describe(layout: LevelLayout) -> LevelDescription:
	var description := LevelDescription.from_layout(layout)
	description.objective_rooms = objective_rooms(layout)
	description.boss_room = layout.marker_rooms.get(Floor1Plan.TREX_MARKER, &"")
	return description


## The rooms the night needs: every progress pickup, guardian and the
## T-Rex's pedestal lie in one (the switchboard's, the astrolabe's...).
static func objective_rooms(layout: LevelLayout) -> Array[StringName]:
	var objectives: Array[StringName] = []
	var wanted: Array[StringName] = [Floor1Plan.TREX_MARKER]
	for pickup in Floor1Plan.pickups():
		wanted.append(pickup.marker)
	for guardian in Floor1Plan.guardians():
		wanted.append(guardian.marker)
	for marker in wanted:
		var room: StringName = layout.marker_rooms.get(marker, &"")
		if room != &"" and not objectives.has(room):
			objectives.append(room)
	return objectives


## Rooms counting for progress area [param area].
static func rooms_of_area(layout: LevelLayout, area: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for room in layout.rooms:
		if room.progress_area() == area:
			found.append(room.id)
	return found


## Rooms of [param zone].
static func rooms_of_zone(layout: LevelLayout, zone: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for room in layout.rooms:
		if room.zone == zone:
			found.append(room.id)
	return found


static func _problem(text: String) -> void:
	problems.append(text)
	push_warning("Floor1Layout: " + text)
