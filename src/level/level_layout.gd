class_name LevelLayout
extends RefCounted
## Pure description of a level: rooms, passages, stairs, pieces, lights,
## spawn slots, loot spots and named markers. Layout files (e.g.
## LobbyLayout) fill one of these with numbers; LevelBuilder turns it into
## nodes. Nothing here touches the scene tree.

## Depth of the light well above a skylight opening.
const SKYLIGHT_WELL := 1.5

var id: StringName = &""
var rooms: Array[RoomSpec] = []
var openings: Array[OpeningSpec] = []
var stairs: Array[StairsSpec] = []
var pieces: Array[PieceSpec] = []
var lights: Array[LightSpec] = []
var spawn_slots: Array[SpawnSlot] = []
var loot_spots: Array[LootSpot] = []
## StringName -> Transform3D (origin on the floor / surface, -Z = front).
var markers: Dictionary = {}
## Marker id -> room id.
var marker_rooms: Dictionary = {}
var player_start := Transform3D.IDENTITY
## Haven id -> transform of its upgrade terminal spot.
var haven_spots: Dictionary = {}
## Environment settings read by LevelLighting (fog, ambient, moon...).
var atmosphere: Dictionary = {}
## Floor I locks (GateSpec), patrol routes and ambushes (empty in the lobby).
var gates: Array[GateSpec] = []
var patrols: Array[PatrolSpec] = []
var ambushes: Array[AmbushSpec] = []

var _rooms_by_id: Dictionary = {}


func add_room(room_id: StringName, rects: Array[Rect2], floor_y: float, ceiling_y: float, tint: Color) -> RoomSpec:
	var room := RoomSpec.make(room_id, rects, floor_y, ceiling_y, tint)
	rooms.append(room)
	_rooms_by_id[room_id] = room
	return room


func add_opening(opening_id: StringName, rect: Rect2, floor_y: float, top_y: float, room_a: StringName, room_b: StringName, style: OpeningSpec.DoorStyle = OpeningSpec.DoorStyle.NONE, kind: RoomGraph.Kind = RoomGraph.Kind.OPEN) -> OpeningSpec:
	var opening := OpeningSpec.make(opening_id, rect, floor_y, top_y, room_a, room_b, style, kind)
	openings.append(opening)
	return opening


func add_stairs(stairs_id: StringName, rect: Rect2, bottom_y: float, top_y: float, ascend: Vector2, room_low: StringName, room_high: StringName) -> StairsSpec:
	var flight := StairsSpec.make(stairs_id, rect, bottom_y, top_y, ascend, room_low, room_high)
	stairs.append(flight)
	return flight


func add_piece(kit: StringName, at: Vector3, size: Vector3, room_id: StringName, yaw: float = 0.0, collide: bool = true) -> PieceSpec:
	var piece := PieceSpec.make(kit, at, size, room_id, yaw, collide)
	pieces.append(piece)
	return piece


func add_light(group: StringName, at: Vector3, color: Color, energy: float, reach: float, room_id: StringName, fixture: StringName = &"", shadow: bool = false) -> LightSpec:
	var light := LightSpec.make(group, at, color, energy, reach, room_id, fixture, shadow)
	lights.append(light)
	return light


func add_spawn(at: Vector3, room_id: StringName, set_id: int, kinds: Array[StringName], dormant: bool = true, yaw: float = 0.0) -> SpawnSlot:
	var slot := SpawnSlot.make(at, room_id, set_id, kinds, dormant, yaw)
	spawn_slots.append(slot)
	return slot


func add_loot(at: Vector3, room_id: StringName, container: bool = false) -> LootSpot:
	var spot := LootSpot.make(at, room_id, container)
	loot_spots.append(spot)
	return spot


func add_marker(marker_id: StringName, at: Vector3, room_id: StringName, yaw: float = 0.0) -> void:
	markers[marker_id] = Transform3D(Basis(Vector3.UP, yaw), at)
	marker_rooms[marker_id] = room_id


func add_gate(gate_id: StringName, kind: GateSpec.Kind, blocks: StringName, needs: StringName = GateSpec.NONE, label: StringName = &"", bolt_side: StringName = &"") -> GateSpec:
	var gate := GateSpec.make(gate_id, kind, blocks, needs, label, bolt_side)
	gates.append(gate)
	return gate


func add_patrol(patrol_id: StringName, room_id: StringName, route: PackedVector3Array, is_loop: bool = true) -> PatrolSpec:
	var patrol := PatrolSpec.make(patrol_id, room_id, route, is_loop)
	patrols.append(patrol)
	return patrol


func add_ambush(ambush: AmbushSpec) -> AmbushSpec:
	ambushes.append(ambush)
	return ambush


## Index of [param slot] in spawn_slots (-1 when it is not there).
func slot_index(slot: SpawnSlot) -> int:
	return spawn_slots.find(slot)


func room(room_id: StringName) -> RoomSpec:
	return _rooms_by_id.get(room_id)


func opening(opening_id: StringName) -> OpeningSpec:
	for candidate in openings:
		if candidate.id == opening_id:
			return candidate
	return null


func gate(gate_id: StringName) -> GateSpec:
	for candidate in gates:
		if candidate.id == gate_id:
			return candidate
	return null


## The gate blocking opening [param opening_id] (null when it has none).
func gate_of_opening(opening_id: StringName) -> GateSpec:
	for candidate in gates:
		if candidate.opening == opening_id and opening_id != &"":
			return candidate
	return null


func patrol(patrol_id: StringName) -> PatrolSpec:
	for candidate in patrols:
		if candidate.id == patrol_id:
			return candidate
	return null


func ambush(ambush_id: StringName) -> AmbushSpec:
	for candidate in ambushes:
		if candidate.id == ambush_id:
			return candidate
	return null


## The room a point is in (&"" when none). Where rooms overlap (a balcony
## inside the hall), the one with the highest floor below the point wins.
func room_at(point: Vector3) -> StringName:
	var best: RoomSpec = null
	for candidate in rooms:
		if candidate.contains(point) and (best == null or candidate.floor_y > best.floor_y):
			best = candidate
	return best.id if best != null else &""


## Rooms and the passages / stairs joining them.
func graph() -> RoomGraph:
	var result := RoomGraph.new()
	for candidate in rooms:
		result.add_room(candidate.id)
	for passage in openings:
		result.add_door(passage.id, passage.room_a, passage.room_b, passage.link)
	for flight in stairs:
		if flight.room_low != flight.room_high:
			result.add_door(flight.id, flight.room_low, flight.room_high, RoomGraph.Kind.OPEN)
	return result
