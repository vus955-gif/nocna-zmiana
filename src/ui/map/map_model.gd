class_name MapModel
extends RefCounted
## What the paper museum map shows (design 9.1), worked out from the level
## layout and the guard's progress (MapState); pure data, no nodes.
## - Tabs: the ground floor, the basement and the roof (by height); a
##   stairwell shows on every floor it joins.
## - Rooms: the visitors' leaflet prints only the public rooms of the ground
##   floor. Staff, service, basement and roof rooms are pencilled in by the
##   guard once he has been there (a haven he knows, too). Secret rooms are
##   never printed: they stay blank until the guard finds them, then he
##   pencils them in like the rest.
## - Doors, flights of stairs and pictograms (information, cafe, shop,
##   cloakroom, tickets, the entrance) follow the rooms they belong to; the
##   wings' names go over their printed rooms.
## - Marks: the guard's pencil notes - a tick in every room visited, a
##   circle round every haven known, little icons for what he found
##   (weapons, key items, seals, shards, notes, chess pieces, secrets), an
##   exclamation mark at every guardian's arena he has seen (crossed out once
##   the guardian fell), a question mark with the lock's kind at every closed
##   gate he has seen.
## - Goal: tonight's goal and, when its step has one, its place.

const GROUND := &"ground"
const BASEMENT := &"basement"
const ROOF := &"roof"
const TABS: Array[StringName] = [GROUND, BASEMENT, ROOF]
const TAB_KEYS := {GROUND: &"MAP_TAB_GROUND", BASEMENT: &"MAP_TAB_BASEMENT", ROOF: &"MAP_TAB_ROOF"}
## Heights splitting the floors (m): the basement lies below, the roof
## above. A sunken hall a few steps down (the Nineveh lions, -3 m) is still
## the ground floor; the basement and roof zones are their pages whatever
## the height (a catwalk over the boiler stays in the basement).
const BASEMENT_BELOW := -4.0
const ROOF_ABOVE := 15.0

enum Look { PRINTED, PENCIL, HIDDEN }
enum MarkKind { TICK, HAVEN, WEAPON, SEAL, SHARD, ITEM, NOTE, CHESS, SECRET, GUARDIAN, GATE }

## Piece kits printed as pictograms -> pictogram id.
const PICTO_KITS := {
	&"info_desk": &"info", &"cafe_counter": &"cafe", &"shop_front": &"shop",
	&"cloakroom_counter": &"cloakroom", &"ticket_booth": &"tickets",
}
## The main doors (printed as the entrance).
const ENTRANCE_MARKER := &"museum_exit"
## Seals and shards are drawn beside their guardian's mark (m, along x).
const SEAL_OFFSET := Vector2(2.6, 0.6)
const SHARD_OFFSET := Vector2(-2.6, 0.6)
## A wing's name runs up its side when it is this much taller than wide.
const TALL_WING := 1.5
## Meta on the layout keeping its rooms' label points (room id -> Vector2).
const ANCHORS_META := &"map_anchors"
## A room this far over the floor of its page that lies over another room
## is an upper room (m).
const UPPER_FLOOR := 2.0
## Label anchors: candidate points per side of a room's largest part, and
## the room (m) they keep from a pictogram.
const ANCHOR_GRID := 11
const PICTO_CLEARANCE := 3.5


class Room:
	extends RefCounted
	var id: StringName
	var zone: StringName
	var name_key: StringName
	var parts: Array[Rect2] = []
	## Floors it shows on; main_tab = the floor of its floor.
	var tabs: Array[StringName] = []
	var main_tab: StringName
	var look: Look = Look.HIDDEN
	## Lies over another room (a balcony, a gallery): drawn dashed.
	var upper: bool = false
	## A round room (the Reading Room's drum): drawn as a circle.
	var round: bool = false
	var visited: bool = false
	## Haven id when the room is a haven the guard knows (&"" otherwise).
	var haven: StringName = &""
	var secret: bool = false
	## Where its name (and the tick) goes (world x, z).
	var anchor := Vector2.ZERO
	## Outline of all its parts together (segments, world x, z).
	var outline: Array[PackedVector2Array] = []
	var area: float = 0.0

	func on(tab: StringName) -> bool:
		return tabs.has(tab)

	func bounds() -> Rect2:
		var result := Rect2()
		for i in parts.size():
			result = parts[i] if i == 0 else result.merge(parts[i])
		return result

	## Radius of a round room (m): the circle of the same area.
	func radius() -> float:
		return sqrt(area / PI)

	func covers(flat: Vector2) -> bool:
		for part in parts:
			if flat.x >= part.position.x and flat.x <= part.end.x and flat.y >= part.position.y and flat.y <= part.end.y:
				return true
		return false


class Doorway:
	extends RefCounted
	var id: StringName
	var rect: Rect2
	var tab: StringName
	var look: Look = Look.HIDDEN
	var room_a: StringName
	var room_b: StringName


class Flight:
	extends RefCounted
	var id: StringName
	var rect: Rect2
	## Unit floor-plan direction it climbs.
	var ascend := Vector2.UP
	var tabs: Array[StringName] = []
	var look: Look = Look.HIDDEN


class Picto:
	extends RefCounted
	var kind: StringName
	var at := Vector2.ZERO
	var tab: StringName


class Wing:
	extends RefCounted
	var zone: StringName
	var at := Vector2.ZERO
	## Runs up the page (a tall wing).
	var rotated: bool = false


class Mark:
	extends RefCounted
	var kind: MarkKind
	## The room, haven, pickup, guardian, gate, note, piece or secret id.
	var id: StringName
	var at := Vector2.ZERO
	var tab: StringName
	var room: StringName
	## A defeated guardian's exclamation mark.
	var crossed: bool = false
	## A gate's lock.
	var lock: GateSpec.Kind = GateSpec.Kind.CHAIN
	## A find's item (weapon, key item or flag id).
	var item: StringName


class Goal:
	extends RefCounted
	var key: StringName
	var step: StringName
	var placed: bool = false
	var at := Vector2.ZERO
	var tab: StringName
	var room: StringName


var layout: LevelLayout
var state: MapState
var rooms: Array[Room] = []
var doors: Array[Doorway] = []
var flights: Array[Flight] = []
var pictos: Array[Picto] = []
var wings: Array[Wing] = []
var marks: Array[Mark] = []
var goal: Goal

var _rooms: Dictionary = {}


static func build(from_layout: LevelLayout, from_state: MapState) -> MapModel:
	var model := MapModel.new()
	model.layout = from_layout
	model.state = from_state
	model._build_rooms()
	model._build_doors()
	model._build_flights()
	model._build_pictos()
	model._build_wings()
	model._build_marks()
	model._build_goal()
	return model


# --- tabs ---------------------------------------------------------------------

static func tab_of_height(y: float) -> StringName:
	if y < BASEMENT_BELOW:
		return BASEMENT
	if y > ROOF_ABOVE:
		return ROOF
	return GROUND


## The floors between [param bottom] and [param top] (m), in TABS order.
static func tabs_between(bottom: float, top: float) -> Array[StringName]:
	var found: Array[StringName] = []
	if bottom <= ROOF_ABOVE and top >= BASEMENT_BELOW:
		found.append(GROUND)
	if bottom < BASEMENT_BELOW:
		found.append(BASEMENT)
	if top > ROOF_ABOVE:
		found.append(ROOF)
	return found


## The floors a room shows on: from its floor up to the top of the stairs
## it holds (or down to their foot); a basement or roof room always on its
## zone's page (a basement room on the ground floor's only when its stairs
## climb up to it).
static func room_tabs(from_layout: LevelLayout, room: RoomSpec) -> Array[StringName]:
	var bottom := room.floor_y
	var top := room.floor_y
	for flight in from_layout.stairs:
		if flight.room_low == room.id or flight.room_high == room.id:
			bottom = minf(bottom, flight.bottom_y)
			top = maxf(top, flight.top_y)
	var found := tabs_between(bottom, top)
	var zone_tab: StringName = Floor1Plan.MAP_TABS.get(room.zone, &"")
	if zone_tab == &"":
		return found
	if zone_tab == BASEMENT and top < -0.5:
		found.erase(GROUND)
	if not found.has(zone_tab):
		found.append(zone_tab)
	var ordered: Array[StringName] = []
	for tab in TABS:
		if found.has(tab):
			ordered.append(tab)
	return ordered


## The page a room's floor is on (its zone's page for the basement and roof).
static func main_tab_of(room: RoomSpec) -> StringName:
	return Floor1Plan.MAP_TABS.get(room.zone, tab_of_height(room.floor_y))


## True for a room the visitors' leaflet prints: public, not secret, on the
## ground floor (and not in a zone with its own tab).
static func is_printed(room: RoomSpec) -> bool:
	return room.public and not room.secret and main_tab_of(room) == GROUND


## True for a room drawn as a circle: many parts stacked into a round shape
## (square bounds, about pi/4 of them covered).
static func is_round(room: RoomSpec) -> bool:
	if room.parts.size() < 5:
		return false
	var box := room.bounds()
	if box.size.y <= 0.0 or absf(box.size.x / box.size.y - 1.0) > 0.1:
		return false
	var ratio := room.area() / box.get_area()
	return absf(ratio - PI * 0.25) < 0.08


## The outline of [param parts] together: every part's edges, less the
## stretches where another part lies right outside them (shared or covered
## edges). Segments of two points each.
static func outline(parts: Array[Rect2]) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	const OUT := 0.01
	for i in parts.size():
		var part := parts[i]
		# [fixed coordinate, from, to, along x?, outside sample offset]
		var edges := [
			[part.position.y, part.position.x, part.end.x, true, -OUT],
			[part.end.y, part.position.x, part.end.x, true, OUT],
			[part.position.x, part.position.y, part.end.y, false, -OUT],
			[part.end.x, part.position.y, part.end.y, false, OUT],
		]
		for edge: Array in edges:
			var line: float = edge[0]
			var along_x: bool = edge[3]
			var outside: float = line + float(edge[4])
			var spans: Array[Vector2] = [Vector2(edge[1], edge[2])]
			for j in parts.size():
				if j == i:
					continue
				var other := parts[j]
				var low := other.position.y if along_x else other.position.x
				var high := other.end.y if along_x else other.end.x
				if outside < low or outside > high:
					continue
				var cut := Vector2(other.position.x, other.end.x) if along_x else Vector2(other.position.y, other.end.y)
				spans = _subtract(spans, cut)
			for span in spans:
				if span.y - span.x < 0.001:
					continue
				if along_x:
					segments.append(PackedVector2Array([Vector2(span.x, line), Vector2(span.y, line)]))
				else:
					segments.append(PackedVector2Array([Vector2(line, span.x), Vector2(line, span.y)]))
	return segments


static func _subtract(spans: Array[Vector2], cut: Vector2) -> Array[Vector2]:
	var left: Array[Vector2] = []
	for span in spans:
		if cut.y <= span.x or cut.x >= span.y:
			left.append(span)
			continue
		if cut.x > span.x:
			left.append(Vector2(span.x, cut.x))
		if cut.y < span.y:
			left.append(Vector2(cut.y, span.y))
	return left


# --- queries ----------------------------------------------------------------------

func room(room_id: StringName) -> Room:
	return _rooms.get(room_id)


## Rooms showing on [param tab] (all looks, or only [param look]).
func rooms_on(tab: StringName, look: int = -1) -> Array[Room]:
	var found: Array[Room] = []
	for entry in rooms:
		if entry.on(tab) and (look < 0 or entry.look == look):
			found.append(entry)
	return found


## The guard's notes on [param tab] (all kinds, or only [param kind]).
func marks_on(tab: StringName, kind: int = -1) -> Array[Mark]:
	var found: Array[Mark] = []
	for mark in marks:
		if mark.tab == tab and (kind < 0 or mark.kind == kind):
			found.append(mark)
	return found


func marks_of(kind: MarkKind) -> Array[Mark]:
	var found: Array[Mark] = []
	for mark in marks:
		if mark.kind == kind:
			found.append(mark)
	return found


func mark(kind: MarkKind, id: StringName) -> Mark:
	for entry in marks:
		if entry.kind == kind and entry.id == id:
			return entry
	return null


## True when anything the guard drew lies on [param tab].
func has_pencil_on(tab: StringName) -> bool:
	return not rooms_on(tab, Look.PENCIL).is_empty() or not marks_on(tab).is_empty()


## The room at a world point on [param tab] (the highest floor wins, like
## LevelLayout.room_at; &"" when none).
func room_at(flat: Vector2, tab: StringName) -> StringName:
	var best: Room = null
	for entry in rooms:
		if entry.on(tab) and entry.covers(flat):
			var spec := layout.room(entry.id)
			if best == null or spec.floor_y > layout.room(best.id).floor_y:
				best = entry
	return best.id if best != null else &""


# --- building -----------------------------------------------------------------

func _build_rooms() -> void:
	var haven_rooms := {}
	for plan in Floor1Plan.havens():
		haven_rooms[plan.room] = plan.id
	for spec in layout.rooms:
		var entry := Room.new()
		entry.id = spec.id
		entry.zone = spec.zone
		entry.name_key = spec.name_key
		entry.parts = spec.parts.duplicate()
		entry.tabs = room_tabs(layout, spec)
		entry.main_tab = main_tab_of(spec)
		entry.upper = _is_upper(spec)
		entry.round = is_round(spec)
		entry.secret = spec.secret
		entry.area = spec.area()
		entry.visited = state.rooms_visited.has(spec.id)
		var haven_id: StringName = haven_rooms.get(spec.id, &"")
		if haven_id != &"" and state.havens.has(haven_id):
			entry.haven = haven_id
		if is_printed(spec):
			entry.look = Look.PRINTED
		elif entry.visited or entry.haven != &"":
			entry.look = Look.PENCIL
		else:
			entry.look = Look.HIDDEN
		entry.outline = outline(entry.parts)
		rooms.append(entry)
		_rooms[entry.id] = entry
	# the label points depend on the layout only: worked out once per layout
	var anchors: Dictionary = layout.get_meta(ANCHORS_META, {})
	if anchors.is_empty():
		for entry in rooms:
			anchors[entry.id] = _anchor(entry)
		layout.set_meta(ANCHORS_META, anchors)
	for entry in rooms:
		entry.anchor = anchors.get(entry.id, entry.bounds().get_center())


## The point of the room's largest part farthest from its edges, from
## every other room on its floor (rooms holding it whole aside), from its
## printed pictograms and from its flights of stairs.
func _anchor(entry: Room) -> Vector2:
	var main := entry.parts[0]
	for part in entry.parts:
		if part.get_area() > main.get_area():
			main = part
	if entry.round:
		return entry.bounds().get_center()
	var box := entry.bounds()
	var others: Array[Room] = []
	for other in rooms:
		if other == entry or not other.on(entry.main_tab):
			continue
		var other_box := other.bounds()
		if other_box.encloses(box) or not other_box.grow(2.0).intersects(main):
			continue
		others.append(other)
	var spots: Array[Vector2] = []
	for piece in layout.pieces:
		if piece.room == entry.id and PICTO_KITS.has(piece.kit):
			spots.append(Vector2(piece.position.x, piece.position.z))
	# where the guard's notes will go: the guardians, the progress pickups
	for marker in _note_markers():
		if layout.marker_rooms.get(marker, &"") == entry.id:
			var at: Transform3D = layout.markers[marker]
			spots.append(Vector2(at.origin.x, at.origin.z))
	var flights: Array[Rect2] = []
	for flight in layout.stairs:
		if flight.room_low == entry.id or flight.room_high == entry.id:
			flights.append(flight.rect)
	var best := main.get_center()
	var best_score := -INF
	for i in ANCHOR_GRID:
		for j in ANCHOR_GRID:
			var point := main.position + main.size * Vector2((i + 0.5) / ANCHOR_GRID, (j + 0.5) / ANCHOR_GRID)
			var score := minf(minf(point.x - main.position.x, main.end.x - point.x), minf(point.y - main.position.y, main.end.y - point.y))
			for other in others:
				for part in other.parts:
					score = minf(score, _distance_to_rect(point, part))
			for spot in spots:
				score = minf(score, point.distance_to(spot) - PICTO_CLEARANCE)
			for flight in flights:
				score = minf(score, _distance_to_rect(point, flight) - 1.0)
			# the middle wins a tie
			score -= point.distance_to(main.get_center()) * 0.02
			if score > best_score:
				best_score = score
				best = point
	return best


## Markers where the guard's sketches are sure to go (the guardians' arenas
## and the progress pickups): room names keep clear of them.
func _note_markers() -> Array[StringName]:
	var found: Array[StringName] = []
	for plan in Floor1Plan.guardians():
		if layout.markers.has(plan.marker):
			found.append(plan.marker)
	for pickup in Floor1Plan.pickups():
		if layout.markers.has(pickup.marker):
			found.append(pickup.marker)
	return found


## True when [param spec] lies over a room of a lower floor on its own page
## (a balcony, a stair tower over the booth): drawn dashed.
func _is_upper(spec: RoomSpec) -> bool:
	if not spec.carved:
		return true
	if spec.floor_y < UPPER_FLOOR:
		return false
	var box := spec.bounds()
	var page := main_tab_of(spec)
	for other in layout.rooms:
		if other == spec or main_tab_of(other) != page or other.floor_y >= spec.floor_y:
			continue
		for part in other.parts:
			for own in spec.parts:
				if part.intersection(own).get_area() > 1.0:
					return true
	return false


## Distance from [param point] to [param rect] (negative inside).
static func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx := maxf(rect.position.x - point.x, point.x - rect.end.x)
	var dy := maxf(rect.position.y - point.y, point.y - rect.end.y)
	if dx <= 0.0 and dy <= 0.0:
		return maxf(dx, dy)
	return Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()


func _build_doors() -> void:
	for opening in layout.openings:
		var door := Doorway.new()
		door.id = opening.id
		door.rect = opening.rect
		door.tab = opening_tab(opening)
		door.room_a = opening.room_a
		door.room_b = opening.room_b
		var a := room(opening.room_a)
		var b := room(opening.room_b)
		if a == null or b == null:
			continue
		var hidden_way := opening.door_style == OpeningSpec.DoorStyle.PANEL or opening.link == RoomGraph.Kind.SECRET
		if a.look == Look.PRINTED and b.look == Look.PRINTED and not hidden_way:
			door.look = Look.PRINTED
		elif a.look != Look.HIDDEN and b.look != Look.HIDDEN:
			door.look = Look.PENCIL
		doors.append(door)


func _build_flights() -> void:
	for spec in layout.stairs:
		var flight := Flight.new()
		flight.id = spec.id
		flight.rect = spec.rect
		flight.ascend = spec.ascend
		var low := room(spec.room_low)
		var high := room(spec.room_high)
		if low == null or high == null:
			continue
		# the floors it climbs through that its rooms show on
		for tab in tabs_between(spec.bottom_y, spec.top_y):
			if low.on(tab) or high.on(tab):
				flight.tabs.append(tab)
		if low.look == Look.PRINTED and high.look == Look.PRINTED:
			flight.look = Look.PRINTED
		elif low.look != Look.HIDDEN and high.look != Look.HIDDEN:
			flight.look = Look.PENCIL
		flights.append(flight)


func _build_pictos() -> void:
	for piece in layout.pieces:
		var kind: StringName = PICTO_KITS.get(piece.kit, &"")
		var holder := room(piece.room)
		if kind == &"" or holder == null or holder.look != Look.PRINTED:
			continue
		var picto := Picto.new()
		picto.kind = kind
		picto.at = Vector2(piece.position.x, piece.position.z)
		picto.tab = tab_of_height(piece.position.y)
		pictos.append(picto)
	if layout.markers.has(ENTRANCE_MARKER):
		var at: Transform3D = layout.markers[ENTRANCE_MARKER]
		var picto := Picto.new()
		picto.kind = &"entrance"
		picto.at = Vector2(at.origin.x, at.origin.z)
		picto.tab = tab_of_height(at.origin.y)
		pictos.append(picto)


## Each named wing over the middle of its printed rooms (a tall wing's name
## runs up the page). Where that middle falls in more than one room or in
## none, the name sits at its largest room's label point instead.
func _build_wings() -> void:
	for zone in MapStyle.NAMED_ZONES:
		var printed: Array[Room] = []
		for entry in rooms:
			if entry.zone == zone and entry.look == Look.PRINTED and entry.on(GROUND) and not entry.upper:
				printed.append(entry)
		if printed.is_empty():
			continue
		var box := printed[0].bounds()
		var largest := printed[0]
		for entry in printed:
			box = box.merge(entry.bounds())
			if entry.area > largest.area:
				largest = entry
		var wing := Wing.new()
		wing.zone = zone
		wing.at = box.get_center()
		wing.rotated = box.size.y > box.size.x * TALL_WING
		var holders := 0
		for entry in printed:
			if entry.covers(wing.at):
				holders += 1
		if holders != 1:
			wing.at = largest.anchor
			wing.rotated = false
		wings.append(wing)


func _build_marks() -> void:
	# ticks in the rooms visited, on every floor the room shows on
	for entry in rooms:
		if entry.visited and entry.look != Look.HIDDEN:
			for tab in entry.tabs:
				_add_mark(MarkKind.TICK, entry.id, entry.anchor, tab, entry.id)
	# circles round the havens known
	for plan in Floor1Plan.havens():
		var holder := room(plan.room)
		if holder != null and holder.haven != &"":
			_add_mark(MarkKind.HAVEN, plan.id, holder.bounds().get_center(), holder.main_tab, holder.id)
	# what he found
	for pickup in Floor1Plan.pickups():
		var found := false
		match pickup.kind:
			&"weapon":
				found = state.weapons.has(pickup.id)
			&"flag":
				found = state.flags.has(pickup.id)
			_:
				found = state.items.has(pickup.id)
		if found:
			var kind := MarkKind.WEAPON if pickup.kind == &"weapon" else MarkKind.ITEM
			var mark := _mark_at_marker(kind, pickup.id, pickup.marker)
			if mark != null:
				mark.item = pickup.id
	for note in state.notes:
		_mark_at_marker(MarkKind.NOTE, note, _note_marker(note))
	for piece in state.chess_found:
		_mark_at_marker(MarkKind.CHESS, piece, piece)
	for secret in state.secrets:
		_mark_at_marker(MarkKind.SECRET, secret, secret)
	# the guardians he has seen, crossed out once fallen, with their spoils
	for plan in Floor1Plan.guardians():
		if not layout.markers.has(plan.marker):
			continue
		var arena: StringName = layout.marker_rooms.get(plan.marker, &"")
		var defeated := state.guardians_defeated.has(plan.id)
		if not defeated and not state.rooms_visited.has(arena):
			continue
		var mark := _mark_at_marker(MarkKind.GUARDIAN, plan.id, plan.marker)
		mark.crossed = defeated
		if plan.seal != &"" and state.seals.has(plan.seal):
			var seal := _add_mark(MarkKind.SEAL, plan.seal, mark.at + SEAL_OFFSET, mark.tab, mark.room)
			seal.item = plan.seal
		if plan.shard != &"" and state.shards.has(plan.shard):
			var shard := _add_mark(MarkKind.SHARD, plan.shard, mark.at + SHARD_OFFSET, mark.tab, mark.room)
			shard.item = plan.shard
	# the closed gates he has seen
	for gate in layout.gates:
		if state.gates_open.has(gate.id):
			continue
		var place := _gate_place(gate)
		if place.is_empty():
			continue
		var seen: StringName = &""
		for side: StringName in place["rooms"]:
			if state.rooms_visited.has(side):
				seen = side
				break
		if seen == &"":
			continue
		var mark := _add_mark(MarkKind.GATE, gate.id, place["at"], place["tab"], seen)
		mark.lock = gate.kind


## Where a gate's lock is: {at, tab, rooms (its sides)}, {} when unknown.
func _gate_place(gate: GateSpec) -> Dictionary:
	if gate.opening != &"":
		var opening := layout.opening(gate.opening)
		if opening == null:
			return {}
		return {"at": opening.rect.get_center(), "tab": opening_tab(opening), "rooms": [opening.room_a, opening.room_b]}
	if gate.marker != &"" and layout.markers.has(gate.marker):
		var at: Transform3D = layout.markers[gate.marker]
		return {"at": Vector2(at.origin.x, at.origin.z), "tab": marker_tab(gate.marker), "rooms": [layout.marker_rooms.get(gate.marker, &"")]}
	return {}


## The marker a note lies at: its own id, or a marker aliased to it.
func _note_marker(note: StringName) -> StringName:
	if layout.markers.has(note):
		return note
	for marker: StringName in WorldFeatures.NOTE_ALIASES:
		if WorldFeatures.NOTE_ALIASES[marker] == note and layout.markers.has(marker):
			return marker
	return &""


func _mark_at_marker(kind: MarkKind, id: StringName, marker: StringName) -> Mark:
	if marker == &"" or not layout.markers.has(marker):
		return null
	var at: Transform3D = layout.markers[marker]
	return _add_mark(kind, id, Vector2(at.origin.x, at.origin.z), marker_tab(marker), layout.marker_rooms.get(marker, &""))


## The page a doorway shows on: its height's, when both its rooms show
## there, else the first page they share.
func opening_tab(opening: OpeningSpec) -> StringName:
	var by_height := tab_of_height(opening.floor_y)
	var a := room(opening.room_a)
	var b := room(opening.room_b)
	if a == null or b == null or (a.on(by_height) and b.on(by_height)):
		return by_height
	for tab in TABS:
		if a.on(tab) and b.on(tab):
			return tab
	return a.main_tab


## The page a marker shows on: its room's floor (a fuse on a gantry in the
## boiler room is in the basement), else its own height.
func marker_tab(marker: StringName) -> StringName:
	var holder := room(layout.marker_rooms.get(marker, &""))
	if holder != null:
		return holder.main_tab
	var at: Transform3D = layout.markers[marker]
	return tab_of_height(at.origin.y)


func _add_mark(kind: MarkKind, id: StringName, at: Vector2, tab: StringName, in_room: StringName) -> Mark:
	var mark := Mark.new()
	mark.kind = kind
	mark.id = id
	mark.at = at
	mark.tab = tab
	mark.room = in_room
	marks.append(mark)
	return mark


func _build_goal() -> void:
	goal = Goal.new()
	goal.key = state.goal_key
	goal.step = state.goal_step
	var marker := goal_marker(goal.step)
	if marker == &"" or not layout.markers.has(marker):
		return
	var at: Transform3D = layout.markers[marker]
	goal.placed = true
	goal.at = Vector2(at.origin.x, at.origin.z)
	goal.tab = marker_tab(marker)
	goal.room = layout.marker_rooms.get(marker, &"")


## The marker where step [param step] happens (&"" = none).
static func goal_marker(step: StringName) -> StringName:
	if step == &"":
		return &""
	var pickup := Floor1Plan.pickup(step)
	if pickup != null:
		return pickup.marker
	var guardian := Floor1Plan.guardian(step)
	if guardian != null:
		return guardian.marker
	match step:
		ProgressRules.TREX:
			return Floor1Plan.TREX_MARKER
		ProgressRules.DESCEND:
			return Floor1Plan.EXIT_MARKER
	return &""
