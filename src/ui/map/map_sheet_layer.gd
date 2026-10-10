class_name MapSheetLayer
extends Control
## One layer of the paper map on screen (the paper, the print, the wear, the
## names, the pencil...): draws itself through [member painter] onto a
## MapCanvasItem when asked (queue_redraw), never per frame - the renderer
## keeps what it drew, and moving or zooming the sheet only moves the layer.

## Called with a MapCanvas to draw the layer.
var painter: Callable
## Texture id -> Texture2D for the canvas (MapDrawing.textures()).
var textures: Dictionary = {}
## How many times the layer has drawn itself (tests: no work per frame).
var draws: int = 0


static func make(layer_name: String, paint: Callable, size_px: Vector2, with_textures: Dictionary = {}) -> MapSheetLayer:
	var layer := MapSheetLayer.new()
	layer.name = layer_name
	layer.painter = paint
	layer.textures = with_textures
	layer.size = size_px
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


func _draw() -> void:
	if not painter.is_valid():
		return
	draws += 1
	var canvas := MapCanvasItem.on(self)
	canvas.textures = textures
	painter.call(canvas)
