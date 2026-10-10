class_name MapStyle
extends RefCounted
## The look of the paper museum map (design 9.1): the sheet and its panels,
## the folds, the print palette of each zone (a visitor leaflet in the
## wings' colours), the printed inks, the guard's pencil and the red of
## "you are here". Sizes are sheet pixels (the sheet is drawn 1:1 and then
## scaled on screen by MapView).

## The open leaflet: A-series proportions, folded in three across and once
## along (creases at FOLDS_X and FOLD_Y).
const SHEET := Vector2(2400.0, 1700.0)
const FOLDS_X: Array[float] = [800.0, 1600.0]
const FOLD_Y := 850.0
## Where the floor plan, the legend and the title go.
const HEADER_AREA := Rect2(50.0, 36.0, 2300.0, 176.0)
const MAP_AREA := Rect2(50.0, 236.0, 1750.0, 1424.0)
const LEGEND_AREA := Rect2(1836.0, 236.0, 514.0, 1424.0)
## Metres of plain paper kept round the floor inside MAP_AREA.
const MAP_MARGIN := 3.0

## Paper and inks.
const PAPER := Color(0.93, 0.91, 0.85)
const INK := Color(0.16, 0.15, 0.14)
const INK_SOFT := Color(0.4, 0.37, 0.34)
## The printed building mass: everything that is not a public gallery.
const MASS := Color(0.79, 0.77, 0.73)
const MASS_EDGE := Color(0.62, 0.6, 0.56)
## The faint footprint printed on the basement and roof pages.
const GHOST := Color(0.5, 0.48, 0.45, 0.5)
## "You are here" and the staff-only notice.
const RED := Color(0.8, 0.13, 0.1)
## How much of the paper shows through the printed colours.
const PRINT_ALPHA := 0.9

## The guard's pencil (graphite; the shader adds the grain).
const PENCIL := Color(0.23, 0.24, 0.28, 0.86)
const PENCIL_LIGHT := Color(0.23, 0.24, 0.28, 0.32)
const PENCIL_WIDTH := 1.7
## Hatching of the rooms the guard pencilled in.
const HATCH_SPACING := 7.0
const HATCH_ALPHA := 0.2

## Type sizes (sheet px).
const TITLE_SIZE := 66
const SUBTITLE_SIZE := 26
const PAGE_SIZE := 40
const WING_SIZE := 34
const ROOM_SIZE := 15
const LEGEND_SIZE := 21
const LEGEND_TITLE_SIZE := 24
const SMALL_SIZE := 15
const HAND_SIZE := 21
## Room names show once their type is at least this tall on screen (px).
const NAME_MIN_SCREEN := 10.5

## Print palette of each zone: [fill, edge, wing-name ink]. The wings keep
## the design's colours (10.1): Egypt sand, Assyria slate blue, Greece white
## and blue, the Enlightenment green and brass, Asia lacquer red, the
## Americas turquoise, the court pale stone.
const ZONE_PRINT := {
	&"court": [Color(0.88, 0.85, 0.77), Color(0.6, 0.56, 0.48), Color(0.52, 0.47, 0.38)],
	&"entrance": [Color(0.86, 0.82, 0.72), Color(0.6, 0.55, 0.45), Color(0.5, 0.45, 0.36)],
	&"north_hall": [Color(0.84, 0.82, 0.76), Color(0.58, 0.55, 0.5), Color(0.48, 0.45, 0.4)],
	&"egypt": [Color(0.91, 0.77, 0.5), Color(0.66, 0.48, 0.22), Color(0.6, 0.4, 0.14)],
	&"assyria": [Color(0.67, 0.73, 0.81), Color(0.33, 0.41, 0.53), Color(0.26, 0.34, 0.47)],
	&"greece": [Color(0.88, 0.92, 0.96), Color(0.2, 0.4, 0.68), Color(0.2, 0.38, 0.66)],
	&"enlightenment": [Color(0.66, 0.76, 0.6), Color(0.6, 0.48, 0.2), Color(0.3, 0.42, 0.26)],
	&"asia": [Color(0.88, 0.5, 0.43), Color(0.56, 0.14, 0.11), Color(0.55, 0.12, 0.1)],
	&"americas": [Color(0.5, 0.79, 0.76), Color(0.12, 0.43, 0.42), Color(0.08, 0.36, 0.35)],
}
## The wings named in big letters on the plan, and listed in the legend.
const NAMED_ZONES: Array[StringName] = [&"court", &"egypt", &"assyria", &"greece", &"enlightenment", &"asia", &"americas"]


static func fill(zone: StringName) -> Color:
	return _print(zone)[0]


static func edge(zone: StringName) -> Color:
	return _print(zone)[1]


static func wing_ink(zone: StringName) -> Color:
	return _print(zone)[2]


static func _print(zone: StringName) -> Array:
	return ZONE_PRINT.get(zone, ZONE_PRINT[&"north_hall"])
