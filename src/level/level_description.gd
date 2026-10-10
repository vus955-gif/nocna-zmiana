class_name LevelDescription
extends RefCounted
## What NightDirector needs to know about a level, without any nodes: the
## room graph and its lockable doors, where nights start, which rooms hold
## objectives, the encounter sets (spawn slots), the loot spots and the
## candidate places for the crystal and the fuses.

var graph: RoomGraph
var lockable_doors: Array[StringName] = []
## Havens a night may start in.
var start_rooms: Array[StringName] = []
## Rooms that must stay reachable from every start room.
var objective_rooms: Array[StringName] = []
var spawn_slots: Array[SpawnSlot] = []
var loot_spots: Array[LootSpot] = []
## Marker ids of the display cases the crystal may lie in.
var crystal_cases: Array[StringName] = []
## Wing id -> Array of fuse point marker ids (one is chosen per wing).
var fuse_points: Dictionary = {}
## Marker id -> room id.
var marker_rooms: Dictionary = {}
## Loot spot indices that always hold an artifact (the secret chamber's
## pedestal, the locked case in the hall).
var always_artifact_spots: Array[int] = []
## Rooms behind false panels (nothing that must be found lies there).
var secret_rooms: Array[StringName] = []
## Where the crystal flies to when it wakes (the boss's room).
var boss_room: StringName = &""
## Marker ids of the wall spots a painting hangs on (some wake as portraits).
var portrait_spots: Array[StringName] = []
# --- zones (Floor I; empty in the lobby) ---
## Room id -> its floor area (m2) and its zone id.
var room_areas: Dictionary = {}
var room_zones: Dictionary = {}
## Zone id -> about this many exhibits per 100 m2 of a room's floor at most
## (the director trims a bigger drawn set to room_limit(), see there;
## ALWAYS_SET slots are not counted).
var zone_density: Dictionary = {}
## Doors that count as open when a locked door is checked (Floor I: the
## gates open or openable tonight). With any listed, a door is safe only
## when shutting it cuts no room off from any start room (cuts_off()).
var always_open: Array[StringName] = []


## The generic part of a description: graph, lockable doors, havens as
## start rooms, slots, loot and marker rooms.
static func from_layout(layout: LevelLayout) -> LevelDescription:
	var description := LevelDescription.new()
	description.graph = layout.graph()
	description.lockable_doors = description.graph.doors_of_kind(RoomGraph.Kind.LOCKABLE)
	for room in layout.rooms:
		if room.haven:
			description.start_rooms.append(room.id)
		if room.secret:
			description.secret_rooms.append(room.id)
	description.spawn_slots = layout.spawn_slots
	description.loot_spots = layout.loot_spots
	description.marker_rooms = layout.marker_rooms
	return description


## How many exhibits a drawn set places in [param room] on average at
## most (-1: no limit, a room without a zone density): its area times its
## zone's density. NightDirector draws the night's cap from it (its whole
## part, and one more with the chance of its fraction), so a small room of
## a calm zone may stand empty.
func room_limit(room: StringName) -> float:
	var zone: StringName = room_zones.get(room, &"")
	if not zone_density.has(zone) or not room_areas.has(room):
		return -1.0
	return float(room_areas[room]) * float(zone_density[zone]) / 100.0


## The most a drawn set places in [param room] on any night (-1: no limit):
## room_limit() rounded, at least one.
func room_cap(room: StringName) -> int:
	var limit := room_limit(room)
	return -1 if limit < 0.0 else maxi(1, roundi(limit))


## True when shutting [param door] leaves a room unreachable that some
## start room reaches with it open (doors in [member always_open] and a
## start haven's own doors count as open).
func cuts_off(door: StringName) -> bool:
	for start in start_rooms:
		var opened: Array[StringName] = graph.doors_of_room(start)
		opened.append_array(always_open)
		var before := graph.reachable(start, [], opened)
		var after := graph.reachable(start, [door] as Array[StringName], opened)
		if after.size() < before.size():
			return true
	return false


## Rooms with spawn slots, in the order their first slot appears.
func encounter_rooms() -> Array[StringName]:
	var rooms: Array[StringName] = []
	for slot in spawn_slots:
		if not rooms.has(slot.room):
			rooms.append(slot.room)
	return rooms


## Encounter set ids of a room, ascending.
func sets_in(room: StringName) -> Array[int]:
	var ids: Array[int] = []
	for slot in spawn_slots:
		if slot.room == room and not ids.has(slot.set_id):
			ids.append(slot.set_id)
	ids.sort()
	return ids


func room_of(marker: StringName) -> StringName:
	return marker_rooms.get(marker, &"")


## The doors the crystal flies through from [param case_marker] to the
## boss room (all doors open; [] when it lies in the boss room already).
func crystal_route(case_marker: StringName) -> Array[StringName]:
	if boss_room == &"" or graph == null:
		return []
	return graph.route(room_of(case_marker), boss_room)


## Rooms the guard can reach from every start room while [param closed]
## doors are shut (a start haven's own false panel counts as open).
func reachable_from_every_start(closed: Array[StringName]) -> Dictionary:
	var common: Dictionary = {}
	var first := true
	for start in start_rooms:
		var seen := graph.reachable(start, closed, graph.doors_of_room(start))
		if first:
			common = seen
			first = false
		else:
			for room: StringName in common.keys():
				if not seen.has(room):
					common.erase(room)
	return common


## True when, with [param closed] doors shut, every objective room can be
## reached from every start room. A haven's own false panel counts as open
## (the guard starting there opens it from inside).
func objectives_reachable(closed: Array[StringName]) -> bool:
	for start in start_rooms:
		var opened: Array[StringName] = graph.doors_of_room(start)
		var seen := graph.reachable(start, closed, opened)
		for room in objective_rooms:
			if not seen.has(room):
				return false
	return true
