class_name MapCanvas
extends RefCounted
## What the paper map is drawn on: a handful of primitives in sheet pixels
## (filled rectangles and polygons, antialiased lines, discs, text on its
## baseline, a texture). MapDrawing and MapPencil draw through it, so the
## same drawing goes to the screen (MapCanvasItem: CanvasItem draw calls)
## and to a list of operations (MapRecorder: tests and the windowless
## previews). This base draws nothing.

## The sheet layer being drawn (&"print", &"pencil"...): the recorder tags
## its operations with it.
var layer: StringName = &""


func set_layer(layer_name: StringName) -> void:
	layer = layer_name


func rect(_area: Rect2, _color: Color) -> void:
	pass


func polygon(_points: PackedVector2Array, _color: Color) -> void:
	pass


## An antialiased line through [param points].
func polyline(_points: PackedVector2Array, _color: Color, _width: float, _closed: bool = false) -> void:
	pass


## Separate segments: points taken in pairs.
func lines(_pairs: PackedVector2Array, _color: Color, _width: float) -> void:
	pass


func circle(_center: Vector2, _radius: float, _color: Color) -> void:
	pass


## [param text] with its baseline starting at [param at], turned by
## [param angle] (radians) about that point. [param font] is a MapFonts id.
func text(_at: Vector2, _text: String, _font: StringName, _size: int, _color: Color, _angle: float = 0.0) -> void:
	pass


## What the next few operations spell (letter-spaced words are drawn letter
## by letter): only the recorder keeps it, for tests.
func label(_words: String) -> void:
	pass


## A texture (by MapDrawing texture id) stretched over [param area].
func texture(_area: Rect2, _id: StringName, _modulate: Color = Color.WHITE) -> void:
	pass
