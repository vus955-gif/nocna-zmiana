class_name MapCanvasItem
extends MapCanvas
## MapCanvas onto a CanvasItem: the paper map's primitives as draw calls
## (call it from the item's _draw()). The renderer keeps the recorded list
## until the item asks for a redraw, so a layer costs nothing per frame.

var item: CanvasItem
## Texture id -> Texture2D.
var textures: Dictionary = {}


static func on(target: CanvasItem) -> MapCanvasItem:
	var canvas := MapCanvasItem.new()
	canvas.item = target
	return canvas


func rect(area: Rect2, color: Color) -> void:
	item.draw_rect(area, color)


## Filled, with an antialiased rim of its own colour (polygons have none).
func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	item.draw_colored_polygon(points, color)
	var rim := points.duplicate()
	rim.append(points[0])
	item.draw_polyline(rim, color, 0.8, true)


func polyline(points: PackedVector2Array, color: Color, width: float, closed: bool = false) -> void:
	if points.size() < 2:
		return
	var path := points
	if closed:
		path = points.duplicate()
		path.append(points[0])
	item.draw_polyline(path, color, width, true)


func lines(pairs: PackedVector2Array, color: Color, width: float) -> void:
	if pairs.size() >= 2:
		item.draw_multiline(pairs, color, width, true)


func circle(center: Vector2, radius: float, color: Color) -> void:
	item.draw_circle(center, radius, color, true, -1.0, true)


func text(at: Vector2, words: String, font: StringName, size: int, color: Color, angle: float = 0.0) -> void:
	if angle == 0.0:
		item.draw_string(MapFonts.font(font), at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		return
	item.draw_set_transform(at, angle)
	item.draw_string(MapFonts.font(font), Vector2.ZERO, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
	item.draw_set_transform(Vector2.ZERO)


func texture(area: Rect2, id: StringName, modulate: Color = Color.WHITE) -> void:
	var picture := textures.get(id) as Texture2D
	if picture != null:
		item.draw_texture_rect(picture, area, false, modulate)
