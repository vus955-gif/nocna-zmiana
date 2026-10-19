class_name UiIcons
extends Control
## The HUD's small engraved icons, drawn in a few strokes (no textures): a
## heart (health), a coffee cup (caffeine), a drooping eye (fatigue), a
## flashlight (its battery), a cartridge (ammo). Each sits in a box of
## BOX units (scaled by [member icon_scale]) on a dark shadow, so it reads
## on pale marble as on black.

enum Kind { HEART, CUP, TIRED, TORCH, CARTRIDGE }

const BOX := 24.0
const SHADOW := Color(0.0, 0.0, 0.0, 0.6)

var kind: Kind = Kind.HEART
var color: Color = Color.WHITE:
	set(value):
		if value != color:
			color = value
			queue_redraw()
var icon_scale: float = 1.0


static func make(icon_kind: Kind, tint: Color, scale_factor: float = 1.0) -> UiIcons:
	var icon := UiIcons.new()
	icon.kind = icon_kind
	icon.color = tint
	icon.icon_scale = scale_factor
	icon.custom_minimum_size = Vector2(BOX, BOX) * scale_factor
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _draw() -> void:
	var c := size * 0.5
	var s := icon_scale
	# the shadow: the same strokes a little lower and wider
	draw_icon(self, kind, c + Vector2(0.0, 1.5) * s, s * 1.08, SHADOW, true)
	draw_icon(self, kind, c, s, color, false)


## Draws icon [param icon_kind] centred on [param at] onto [param canvas]
## ([param flat]: one colour, no highlights - the shadow pass).
static func draw_icon(canvas: CanvasItem, icon_kind: Kind, at: Vector2, s: float, tint: Color, flat: bool) -> void:
	match icon_kind:
		Kind.HEART:
			_heart(canvas, at, s, tint, flat)
		Kind.CUP:
			_cup(canvas, at, s, tint, flat)
		Kind.TIRED:
			_tired(canvas, at, s, tint, flat)
		Kind.TORCH:
			_torch(canvas, at, s, tint, flat)
		Kind.CARTRIDGE:
			_cartridge(canvas, at, s, tint, flat)


static func _heart(canvas: CanvasItem, c: Vector2, s: float, tint: Color, flat: bool) -> void:
	canvas.draw_circle(c + Vector2(-4.4, -2.6) * s, 5.4 * s, tint)
	canvas.draw_circle(c + Vector2(4.4, -2.6) * s, 5.4 * s, tint)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-9.6, -1.2) * s, c + Vector2(9.6, -1.2) * s, c + Vector2(0.0, 9.8) * s]), tint)
	if not flat:
		canvas.draw_circle(c + Vector2(-5.2, -4.2) * s, 1.7 * s, Color(1.0, 0.92, 0.88, 0.7))


static func _cup(canvas: CanvasItem, c: Vector2, s: float, tint: Color, flat: bool) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-8.0, -3.0) * s, c + Vector2(5.0, -3.0) * s, c + Vector2(3.6, 6.0) * s, c + Vector2(-6.6, 6.0) * s]), tint)
	canvas.draw_arc(c + Vector2(5.4, 1.0) * s, 3.2 * s, -PI * 0.5, PI * 0.5, 10, tint, 2.2 * s)
	canvas.draw_line(c + Vector2(-10.0, 8.2) * s, c + Vector2(8.0, 8.2) * s, tint, 2.0 * s)
	for x in [-4.5, -0.5]:
		var steam := PackedVector2Array()
		for i in 5:
			steam.append(c + Vector2(x + sin(i * 1.4) * 1.3, -5.5 - i * 1.6) * s)
		canvas.draw_polyline(steam, Color(tint, tint.a * 0.75), 1.5 * s)
	if not flat:
		canvas.draw_line(c + Vector2(-6.4, -1.4) * s, c + Vector2(-5.4, 4.6) * s, Color(1.0, 1.0, 1.0, 0.5), 1.2 * s)


static func _tired(canvas: CanvasItem, c: Vector2, s: float, tint: Color, flat: bool) -> void:
	# a drooping eye: the lower lid's curve, the iris half hidden by a heavy upper lid
	var lower := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		lower.append(c + Vector2(lerpf(-10.0, 10.0, t), 1.0 + sin(t * PI) * 5.0) * s)
	canvas.draw_polyline(lower, tint, 2.0 * s)
	if not flat:
		canvas.draw_circle(c + Vector2(0.0, 2.6) * s, 3.4 * s, Color(tint, tint.a * 0.85))
	var lid := PackedVector2Array([c + Vector2(-10.0, 1.0) * s])
	for i in 9:
		var t := i / 8.0
		lid.append(c + Vector2(lerpf(-9.0, 9.0, t), 1.6 - sin(t * PI) * 1.2) * s)
	lid.append(c + Vector2(10.0, 1.0) * s)
	for i in 9:
		var t := 1.0 - i / 8.0
		lid.append(c + Vector2(lerpf(-9.0, 9.0, t), -1.4 - sin(t * PI) * 5.0) * s)
	canvas.draw_colored_polygon(lid, tint)
	for x in [-5.0, 0.0, 5.0]:
		canvas.draw_line(c + Vector2(x, 2.2) * s, c + Vector2(x * 1.15, 5.2) * s, tint, 1.4 * s)


static func _torch(canvas: CanvasItem, c: Vector2, s: float, tint: Color, flat: bool) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-10.0, -2.6) * s, Vector2(10.0, 5.2) * s), tint)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -2.6) * s, c + Vector2(4.0, -5.0) * s, c + Vector2(4.0, 5.0) * s, c + Vector2(0.0, 2.6) * s]), tint)
	for ray in [-0.45, 0.0, 0.45]:
		var dir := Vector2(cos(ray), sin(ray))
		canvas.draw_line(c + (Vector2(5.5, 0.0) + dir * 1.0) * s, c + (Vector2(5.5, 0.0) + dir * 5.5) * s, Color(tint, tint.a * 0.8), 1.5 * s)
	if not flat:
		canvas.draw_rect(Rect2(c + Vector2(-7.0, -1.2) * s, Vector2(2.0, 2.4) * s), Color(0.0, 0.0, 0.0, 0.45))


static func _cartridge(canvas: CanvasItem, c: Vector2, s: float, tint: Color, flat: bool) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-3.4, -3.0) * s, Vector2(6.8, 12.0) * s), tint)
	canvas.draw_rect(Rect2(c + Vector2(-4.2, 8.0) * s, Vector2(8.4, 2.0) * s), tint)
	var tip := Color(tint.darkened(0.25), tint.a) if not flat else tint
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.4, -3.0) * s, c + Vector2(3.4, -3.0) * s, c + Vector2(2.2, -7.8) * s, c + Vector2(0.0, -10.0) * s, c + Vector2(-2.2, -7.8) * s]), tip)
	if not flat:
		canvas.draw_line(c + Vector2(-1.8, -2.0) * s, c + Vector2(-1.8, 7.0) * s, Color(1.0, 1.0, 1.0, 0.45), 1.2 * s)
