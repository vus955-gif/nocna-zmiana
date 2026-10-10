class_name ArtifactIcon
extends Control
## One artifact on the HUD: a dark brass-edged tile with the artifact drawn
## in a few strokes (scarab, monocle, coin, candle, tooth, key) in its own
## colour. It pops in when it appears.

const SIZE := 52.0

var artifact_id: StringName = &""
var _pop: float = 1.0


static func make(id: StringName) -> ArtifactIcon:
	var icon := ArtifactIcon.new()
	icon.artifact_id = id
	icon.custom_minimum_size = Vector2(SIZE, SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = ""
	return icon


## Plays the pop-in (a new artifact).
func pop() -> void:
	_pop = 0.0


func _process(delta: float) -> void:
	if _pop < 1.0:
		_pop = minf(_pop + delta * 3.0, 1.0)
		pivot_offset = size * 0.5
		var overshoot := 1.0 + 0.35 * sin(_pop * PI) * (1.0 - _pop * 0.5)
		scale = Vector2.ONE * lerpf(0.4, 1.0, minf(_pop * 2.0, 1.0)) * overshoot
		modulate.a = minf(_pop * 3.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var tile := StyleBoxFlat.new()
	tile.bg_color = Color(0.05, 0.045, 0.04, 0.78)
	tile.border_color = Color(UiTheme.ACCENT, 0.55)
	tile.set_border_width_all(2)
	tile.set_corner_radius_all(6)
	draw_style_box(tile, box)
	var c := size * 0.5
	var tint := ArtifactCatalog.color(artifact_id)
	var gold := Color(0.9, 0.7, 0.32)
	match artifact_id:
		ArtifactCatalog.SCARAB:
			_oval(c + Vector2(0, 3), Vector2(11, 14), tint)
			draw_circle(c + Vector2(0, -12), 5.5, gold)
			draw_line(c + Vector2(0, -8), c + Vector2(0, 16), gold, 2.0)
			for side in [-1.0, 1.0]:
				for y in [-4.0, 3.0, 10.0]:
					draw_line(c + Vector2(side * 10, y), c + Vector2(side * 17, y - 3), gold, 2.0)
		ArtifactCatalog.MONOCLE:
			draw_circle(c + Vector2(-3, -3), 11.0, Color(0.7, 0.85, 1.0, 0.25))
			draw_arc(c + Vector2(-3, -3), 12.0, 0.0, TAU, 32, tint, 3.0, true)
			for i in 5:
				draw_circle(c + Vector2(8 + i * 2.5, 8 + i * 3.2), 1.6, tint)
		ArtifactCatalog.FOUNTAIN_COIN:
			draw_circle(c, 14.0, tint.darkened(0.25))
			draw_arc(c, 14.0, 0.0, TAU, 32, tint, 2.0, true)
			draw_arc(c, 9.5, 0.0, TAU, 32, tint.lightened(0.2), 1.5, true)
			draw_line(c + Vector2(0, -6), c + Vector2(0, 6), tint.lightened(0.3), 2.0)
		ArtifactCatalog.CANDLE_STUB:
			draw_rect(Rect2(c + Vector2(-7, -2), Vector2(14, 17)), Color(0.93, 0.87, 0.72))
			draw_line(c + Vector2(0, -2), c + Vector2(0, -7), Color(0.1, 0.1, 0.1), 1.5)
			var flame := PackedVector2Array([c + Vector2(0, -21), c + Vector2(5, -11), c + Vector2(0, -6), c + Vector2(-5, -11)])
			draw_colored_polygon(flame, tint)
			draw_circle(c + Vector2(0, -11), 2.5, Color(1.0, 0.95, 0.7))
		ArtifactCatalog.WOLF_TOOTH:
			var fang := PackedVector2Array([c + Vector2(-8, -12), c + Vector2(8, -12), c + Vector2(5, 0), c + Vector2(-1, 16), c + Vector2(-4, 2)])
			draw_colored_polygon(fang, tint)
			draw_arc(c + Vector2(0, -15), 8.0, PI, TAU, 16, Color(0.55, 0.36, 0.2), 2.0, true)
		ArtifactCatalog.JANITOR_KEY:
			draw_arc(c + Vector2(-10, 0), 7.0, 0.0, TAU, 20, tint, 3.0, true)
			draw_line(c + Vector2(-3, 0), c + Vector2(15, 0), Color(0.72, 0.7, 0.66), 3.0)
			draw_line(c + Vector2(13, 0), c + Vector2(13, 7), Color(0.72, 0.7, 0.66), 3.0)
			draw_line(c + Vector2(8, 0), c + Vector2(8, 5), Color(0.72, 0.7, 0.66), 3.0)
		_:
			draw_circle(c, 10.0, tint)


func _oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
