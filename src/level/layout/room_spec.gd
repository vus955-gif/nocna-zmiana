class_name RoomSpec
extends RefCounted
## One room of a level layout: one or more floor-plan rectangles sharing a
## floor and a ceiling height. Rectangles use Rect2(x0, z0, width, depth)
## in metres on the 0.5 m grid.

var id: StringName = &""
var parts: Array[Rect2] = []
var floor_y: float = 0.0
var ceiling_y: float = 3.0
## Greybox tint; floors are drawn a bit darker, ceilings a bit lighter.
var tint := Color(0.6, 0.6, 0.6)
## Enemies never path in here (its floor goes to the haven navigation layer).
var haven: bool = false
## Hidden room, reached through a false panel.
var secret: bool = false
## False for a room that lies inside another room's space (a balcony):
## nothing is carved for it, its floor comes from pieces.
var carved: bool = true
## Roof openings (x, z rectangles inside the room) with a light well.
var skylights: Array[Rect2] = []
## Floor I zone the room belongs to (Floor1Plan zone id; &"" in the lobby).
## Floor1Layout fills it in for every room a zone module adds.
var zone: StringName = &""
## Progress area of the room (Floor1Plan area id) when it differs from its
## zone: a room behind an internal gate (the Japanese garden, the reading
## room). &"" = the zone itself; see progress_area().
var zone_area: StringName = &""
## Translation key of the room's name (room card, paper map); &"" = none.
var name_key: StringName = &""
## Printed on the visitors' paper map. Staff, service and secret rooms are
## false: the guard pencils them in once visited (secret rooms never).
var public: bool = true


static func make(room_id: StringName, rects: Array[Rect2], floor_height: float, ceiling_height: float, color: Color) -> RoomSpec:
	var room := RoomSpec.new()
	room.id = room_id
	room.parts = rects
	room.floor_y = floor_height
	room.ceiling_y = ceiling_height
	room.tint = color
	return room


## True when [param point] lies over one of the parts (x, z) and between
## the floor (minus [param below]) and the ceiling.
func contains(point: Vector3, below: float = 0.25) -> bool:
	if point.y < floor_y - below or point.y > ceiling_y:
		return false
	return covers(Vector2(point.x, point.z))


## True when the floor-plan point lies over one of the parts.
func covers(flat: Vector2) -> bool:
	for part in parts:
		if flat.x >= part.position.x and flat.x <= part.end.x and flat.y >= part.position.y and flat.y <= part.end.y:
			return true
	return false


func area() -> float:
	var total := 0.0
	for part in parts:
		total += part.get_area()
	return total


func height() -> float:
	return ceiling_y - floor_y


## The progress area the room counts for (its zone unless set).
func progress_area() -> StringName:
	return zone_area if zone_area != &"" else zone


## Floor-plan bounds of all parts.
func bounds() -> Rect2:
	var result := Rect2()
	for i in parts.size():
		result = parts[i] if i == 0 else result.merge(parts[i])
	return result
