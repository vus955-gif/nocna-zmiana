class_name MapRecorder
extends MapCanvas
## MapCanvas into a list of operations: what the tests look at and what the
## windowless previews draw (to_json() -> tools/map/render_preview.py).
## Every operation is a Dictionary with "op" (rect, poly, line, lines, disc,
## text, tex), its geometry in sheet pixels, "c" (colour [r, g, b, a]) and
## "layer".

var ops: Array[Dictionary] = []


func rect(area: Rect2, color: Color) -> void:
	_add({"op": "rect", "r": [area.position.x, area.position.y, area.size.x, area.size.y], "c": _rgba(color)})


func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		_add({"op": "poly", "pts": _flat(points), "c": _rgba(color)})


func polyline(points: PackedVector2Array, color: Color, width: float, closed: bool = false) -> void:
	if points.size() >= 2:
		_add({"op": "line", "pts": _flat(points), "c": _rgba(color), "w": width, "closed": closed})


func lines(pairs: PackedVector2Array, color: Color, width: float) -> void:
	if pairs.size() >= 2:
		_add({"op": "lines", "pts": _flat(pairs), "c": _rgba(color), "w": width})


func circle(center: Vector2, radius: float, color: Color) -> void:
	_add({"op": "disc", "p": [center.x, center.y], "r": radius, "c": _rgba(color)})


func text(at: Vector2, words: String, font: StringName, size: int, color: Color, angle: float = 0.0) -> void:
	_add({"op": "text", "p": [at.x, at.y], "t": words, "f": String(font), "fam": MapFonts.family(font),
		"bold": MapFonts.is_bold(font), "s": size, "c": _rgba(color), "a": angle,
		"w": MapFonts.width(font, words, size)})


func label(words: String) -> void:
	_add({"op": "label", "t": words})


func texture(area: Rect2, id: StringName, modulate: Color = Color.WHITE) -> void:
	_add({"op": "tex", "r": [area.position.x, area.position.y, area.size.x, area.size.y], "id": String(id), "c": _rgba(modulate)})


func to_json() -> String:
	return JSON.stringify({"sheet": [MapStyle.SHEET.x, MapStyle.SHEET.y], "ops": ops})


# --- queries (tests) --------------------------------------------------------------

## Operations of [param layer_name] (all when &"").
func ops_on(layer_name: StringName = &"") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in ops:
		if layer_name == &"" or StringName(entry["layer"]) == layer_name:
			found.append(entry)
	return found


## Filled rectangles, polygons and discs (of [param layer_name]) covering
## [param point].
func fills_at(point: Vector2, layer_name: StringName = &"") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in ops_on(layer_name):
		match String(entry["op"]):
			"rect":
				var r: Array = entry["r"]
				if Rect2(r[0], r[1], r[2], r[3]).grow(0.001).has_point(point):
					found.append(entry)
			"poly":
				if Geometry2D.is_point_in_polygon(point, _points(entry["pts"])):
					found.append(entry)
			"disc":
				var p: Array = entry["p"]
				if Vector2(p[0], p[1]).distance_to(point) <= float(entry["r"]):
					found.append(entry)
	return found


## The texts drawn (of [param layer_name]), letter-spaced words whole.
func texts(layer_name: StringName = &"") -> PackedStringArray:
	var found: PackedStringArray = []
	for entry in ops_on(layer_name):
		if String(entry["op"]) == "text" or String(entry["op"]) == "label":
			found.append(String(entry["t"]))
	return found


## Line and text operations (of [param layer_name]) with a point within
## [param radius] of [param point].
func marks_near(point: Vector2, radius: float, layer_name: StringName = &"") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in ops_on(layer_name):
		var kind := String(entry["op"])
		var points := PackedVector2Array()
		if kind == "line" or kind == "lines" or kind == "poly":
			points = _points(entry["pts"])
		elif kind == "text" or kind == "disc":
			var p: Array = entry["p"]
			points.append(Vector2(p[0], p[1]))
		for at in points:
			if at.distance_to(point) <= radius:
				found.append(entry)
				break
	return found


## The points of a line operation.
static func points_of(entry: Dictionary) -> PackedVector2Array:
	return _points(entry["pts"])


func _add(entry: Dictionary) -> void:
	entry["layer"] = String(layer)
	ops.append(entry)


static func _rgba(color: Color) -> Array:
	return [snappedf(color.r, 0.0001), snappedf(color.g, 0.0001), snappedf(color.b, 0.0001), snappedf(color.a, 0.0001)]


static func _flat(points: PackedVector2Array) -> Array:
	var flat: Array = []
	for point in points:
		flat.append(snappedf(point.x, 0.01))
		flat.append(snappedf(point.y, 0.01))
	return flat


static func _points(flat: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	return points
