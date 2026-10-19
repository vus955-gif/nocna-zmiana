class_name PlaqueStyle
extends StyleBox
## The museum plaque every HUD piece and menu stands on: a field of dark
## enamel with cut corners (the shape of an exhibit label or a period
## station sign), an engraved double brass rule along its edge and, on the
## big ones, a brass rivet in each corner. A thin dark outline keeps the
## edge readable on pale marble. Drawn as polygons (no texture): sharp at
## any canvas scale, the 1280x1024 window's 2/3 included.
## UiTheme.plaque() makes the house variants; a band along the left edge
## carries a colour of its own (a wing's, a focused menu row's brass).

## The enamel (alpha: how much of the world still shows through).
@export var field: Color = Color(0.05, 0.043, 0.036, 0.86)
## The brass of the rule (alpha 0: no rule).
@export var rim: Color = Color(0.82, 0.6, 0.3)
## The darker line just inside the brass (the engraving).
@export var groove: Color = Color(0.2, 0.14, 0.07, 0.9)
## The dark hairline round the outside (alpha 0: none).
@export var outline: Color = Color(0.0, 0.0, 0.0, 0.55)
## Leg of the cut corners, in canvas units.
@export var cut: float = 7.0
## Width of the brass rule.
@export var rim_width: float = 2.0
## A faint second rule inside the edge (the double rule of an engraved plate).
@export var inner_rule: bool = true
## A brass rivet in each corner.
@export var rivets: bool = false
## How much lighter the field's top edge is than its bottom (a sheen).
@export var sheen: float = 0.05
## A soft shadow under the plaque, in canvas units (0: none).
@export var shadow: float = 0.0
## A colour band along the left edge, inside the rule (alpha 0: none).
@export var band: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var band_width: float = 0.0


func _init() -> void:
	content_margin_left = 16.0
	content_margin_right = 16.0
	content_margin_top = 10.0
	content_margin_bottom = 10.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.4)
	if shadow > 0.0:
		for i in 3:
			var grow := shadow * (i + 1) / 3.0
			var shade := Color(0.0, 0.0, 0.0, 0.16 * (1.0 - i / 3.0))
			rs.canvas_item_add_polygon(to_canvas_item, octagon(rect.grow(grow).grow_individual(0, -grow * 0.4, 0, grow * 0.3), c + grow * 0.6), PackedColorArray([shade]))
	var edge := 0.0
	if outline.a > 0.0:
		_ring(to_canvas_item, rect, c, 1.0, outline)
		edge = 1.0
	if rim.a > 0.0:
		_ring(to_canvas_item, rect.grow(-edge), inset_cut(c, edge), rim_width, rim)
		edge += rim_width
		if groove.a > 0.0:
			_ring(to_canvas_item, rect.grow(-edge), inset_cut(c, edge), 1.0, groove)
			edge += 1.0
	var inside := rect.grow(-edge)
	var inside_cut := inset_cut(c, edge)
	var points := octagon(inside, inside_cut)
	var top := Color(field.lightened(sheen * 2.0), field.a)
	var bottom := Color(field.darkened(sheen), field.a)
	var colors := PackedColorArray()
	for point in points:
		var t := clampf((point.y - inside.position.y) / maxf(inside.size.y, 1.0), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	rs.canvas_item_add_polygon(to_canvas_item, points, colors)
	if band.a > 0.0 and band_width > 0.0 and inside.size.y > inside_cut * 2.0:
		var strip := Rect2(inside.position + Vector2(0.0, inside_cut), Vector2(band_width, inside.size.y - inside_cut * 2.0))
		rs.canvas_item_add_rect(to_canvas_item, strip, band)
	if inner_rule and rim.a > 0.0 and inside.size.x > 24.0 and inside.size.y > 16.0:
		var gap := 3.0
		_ring(to_canvas_item, inside.grow(-gap), inset_cut(inside_cut, gap), 1.0, Color(rim, rim.a * 0.32))
	if rivets and rim.a > 0.0 and rect.size.x > 60.0 and rect.size.y > 44.0:
		var inset := edge + 6.0 + c * 0.25
		for corner in [Vector2(inset, inset), Vector2(rect.size.x - inset, inset), Vector2(inset, rect.size.y - inset), Vector2(rect.size.x - inset, rect.size.y - inset)]:
			rivet(to_canvas_item, rect.position + corner, rim)


## A rivet at [param at]: a dark seat, the brass head, a spark of light.
static func rivet(to_canvas_item: RID, at: Vector2, brass: Color, radius: float = 3.0) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_circle(to_canvas_item, at + Vector2(0.4, 0.6), radius + 0.9, Color(0.0, 0.0, 0.0, 0.6))
	rs.canvas_item_add_circle(to_canvas_item, at, radius, brass.darkened(0.15))
	rs.canvas_item_add_circle(to_canvas_item, at - Vector2(radius, radius) * 0.25, radius * 0.55, brass.lightened(0.35))


## The eight corners of [param rect] with its corners cut by [param leg].
static func octagon(rect: Rect2, leg: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var c := clampf(leg, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])


## The leg of the cut on a rule [param inset] units inside one cut by [param leg]
## (45 degree corners: it shortens by inset * (2 - sqrt 2)).
static func inset_cut(leg: float, inset: float) -> float:
	return maxf(leg - inset * 0.5858, 0.0)


## A band [param width] wide just inside the edge of the octagon of
## [param rect] (cut [param leg]).
static func _ring(to_canvas_item: RID, rect: Rect2, leg: float, width: float, color: Color) -> void:
	if rect.size.x <= width * 2.0 or rect.size.y <= width * 2.0:
		return
	var outer := octagon(rect, leg)
	var inner := octagon(rect.grow(-width), inset_cut(leg, width))
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in 8:
		points.append(outer[i])
		points.append(inner[i])
	for i in 8:
		var a := i * 2
		var b := ((i + 1) % 8) * 2
		indices.append_array([a, b, a + 1, b, b + 1, a + 1])
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_triangle_array(to_canvas_item, indices, points, colors)
