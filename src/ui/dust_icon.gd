class_name DustIcon
extends Control
## A small glowing diamond: the Dust symbol (HUD counter, prices).

var icon_scale: float = 1.0


static func make(scale_factor: float = 1.0) -> DustIcon:
	var icon := DustIcon.new()
	icon.icon_scale = scale_factor
	return icon


func _ready() -> void:
	custom_minimum_size = Vector2(22, 30) * icon_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var s := icon_scale
	draw_colored_polygon(_diamond(c, 9.5 * s, 13.5 * s), Color(0.0, 0.0, 0.0, 0.5))
	draw_colored_polygon(_diamond(c, 7.5 * s, 11.0 * s), UiTheme.DUST)
	draw_colored_polygon(_diamond(c, 3.5 * s, 6.0 * s), Color(1.0, 0.97, 0.88))


static func _diamond(center: Vector2, half_width: float, half_height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -half_height), center + Vector2(half_width, 0),
		center + Vector2(0, half_height), center + Vector2(-half_width, 0),
	])
