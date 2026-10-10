class_name OpeningSpec
extends RefCounted
## A passage through the wall between two rooms: a doorway, an arch, a
## false panel or the grate. [member rect] covers the whole wall thickness;
## its shorter side runs along the passage.

## What fills the passage. NONE = open arch.
enum DoorStyle { NONE, SWING, DOUBLE_SWING, SLIDE, PANEL, GATE }

var id: StringName = &""
var rect := Rect2()
var floor_y: float = 0.0
var top_y: float = 2.6
var room_a: StringName = &""
var room_b: StringName = &""
var door_style: DoorStyle = DoorStyle.NONE
var link: RoomGraph.Kind = RoomGraph.Kind.OPEN
## PANEL / GATE: the room whose wall face the panel sits flush with.
var face_room: StringName = &""
## Doors start open unless they are panels or gates.
var start_open: bool = true
## Red emergency lamp + exit sign over both faces (not on panels / gates).
var exit_signs: bool = true
## PANEL: what the panel looks like (&"false_panel", &"painting_panel",
## &"vent_grille").
var panel_kit: StringName = &"false_panel"


static func make(opening_id: StringName, area: Rect2, bottom: float, top: float, from_room: StringName, to_room: StringName, style: DoorStyle = DoorStyle.NONE, kind: RoomGraph.Kind = RoomGraph.Kind.OPEN) -> OpeningSpec:
	var opening := OpeningSpec.new()
	opening.id = opening_id
	opening.rect = area
	opening.floor_y = bottom
	opening.top_y = top
	opening.room_a = from_room
	opening.room_b = to_room
	opening.door_style = style
	opening.link = kind
	opening.start_open = style != DoorStyle.PANEL and style != DoorStyle.GATE
	opening.exit_signs = opening.start_open
	opening.face_room = from_room
	return opening


## True when the passage runs along x (the rectangle is thinner in x).
func runs_along_x() -> bool:
	return rect.size.x < rect.size.y


## Clear width of the passage (across its direction).
func width() -> float:
	return rect.size.y if runs_along_x() else rect.size.x


## Wall thickness the passage goes through.
func depth() -> float:
	return rect.size.x if runs_along_x() else rect.size.y


func height() -> float:
	return top_y - floor_y


func center() -> Vector3:
	var middle := rect.get_center()
	return Vector3(middle.x, floor_y, middle.y)
