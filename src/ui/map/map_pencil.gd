class_name MapPencil
extends RefCounted
## The night guard's pencil on the leaflet (design 9.1), drawn on a
## MapCanvas over the print: graphite lines that wobble a little and run
## past the corners like a quick hand, a second fainter pass beside each
## stroke, light diagonal hatching inside the rooms he drew in himself.
## - the rooms he pencilled in (staff and service rooms, the basement, the
##   roof, the secret rooms he found), their doors and stairs,
## - his notes (MapModel.marks): a tick in every room visited, a loop round
##   every haven, little sketches of what he found (a gun, a key, a fuse, a
##   lightning bolt, a seal, a crystal shard, a note, a chess piece, a star
##   for a secret), "!" at a guardian's arena (crossed out once he fell),
##   "?" with the lock's sketch at a closed gate (chain, boards, seal,
##   power, crack, rope, hook, bolt, grate),
## - tonight's goal: a curved arrow and a ring at its place with "here!",
## - in the key's notes box: "Tonight:" with the goal, and his own key.
## Every wobble comes from a seed of what is drawn, so the same state draws
## the same lines (the renderer keeps them; tests compare them).

const WOBBLE := 0.75
const STEP := 7.0
const OVERSHOOT := 3.0
## Sketch sizes (px).
const ICON := 1.0
const TICK_GAP := 12.0
const GOAL_REACH := 78.0
const HAND_NOTE := 22


static func draw(canvas: MapCanvas, model: MapModel, projection: MapProjection, tab: StringName) -> void:
	canvas.set_layer(&"pencil")
	for room in model.rooms_on(tab, MapModel.Look.PENCIL):
		_room(canvas, room, projection)
	for door in model.doors:
		if door.tab == tab and door.look == MapModel.Look.PENCIL:
			_door(canvas, door, projection)
	for flight in model.flights:
		if flight.look == MapModel.Look.PENCIL and flight.tabs.has(tab):
			var rng := _rng(String(flight.id))
			var color := Color(MapStyle.PENCIL, 0.55)
			MapDrawing.stairs(_Shaky.new(canvas, rng), projection.rect_to_sheet(flight.rect), flight.ascend, projection.length(MapDrawing.TREAD), color, 1.1)
	for mark in model.marks_on(tab):
		_mark(canvas, model, mark, projection)
	if model.goal.placed and model.goal.tab == tab:
		var busy := PackedVector2Array()
		for mark in model.marks_on(tab):
			if mark.kind != MapModel.MarkKind.TICK:
				busy.append(projection.to_sheet(mark.at))
		for room in model.rooms_on(tab):
			if room.look != MapModel.Look.HIDDEN:
				busy.append(projection.to_sheet(room.anchor))
		goal_arrow(canvas, projection.to_sheet(model.goal.at), String(model.goal.step), busy)
	notes(canvas, model, tab)


# --- strokes ---------------------------------------------------------------------------

## A hand-drawn line from [param a] to [param b]: past both ends a little,
## wobbling, with a fainter second pass beside it.
static func stroke(canvas: MapCanvas, a: Vector2, b: Vector2, rng: RandomNumberGenerator, width: float = MapStyle.PENCIL_WIDTH, color: Color = MapStyle.PENCIL, overshoot: float = OVERSHOOT) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var start := a - dir * rng.randf_range(0.0, overshoot)
	var end := b + dir * rng.randf_range(overshoot * 0.3, overshoot)
	path(canvas, PackedVector2Array([start, end]), rng, width, color)


## A hand-drawn line through [param points] (wobbling, a fainter pass).
static func path(canvas: MapCanvas, points: PackedVector2Array, rng: RandomNumberGenerator, width: float = MapStyle.PENCIL_WIDTH, color: Color = MapStyle.PENCIL, amplitude: float = WOBBLE) -> void:
	var shaky := wobble(points, rng, amplitude)
	canvas.polyline(shaky, color, width)
	var shift := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
	var second := PackedVector2Array()
	for point in shaky:
		second.append(point + shift)
	canvas.polyline(second, Color(color, color.a * 0.32), width * 0.7)


## [param points] resampled every STEP px and pushed sideways by two slow
## waves (a hand, not noise).
static func wobble(points: PackedVector2Array, rng: RandomNumberGenerator, amplitude: float = WOBBLE) -> PackedVector2Array:
	var f1 := rng.randf_range(0.025, 0.06)
	var f2 := rng.randf_range(0.12, 0.22)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var result := PackedVector2Array()
	var travelled := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var count := maxi(1, ceili(length / STEP))
		for j in count:
			var t := float(j) / count
			var s := travelled + length * t
			var push := amplitude * sin(s * f1 + p1) + amplitude * 0.35 * sin(s * f2 + p2)
			result.append(a.lerp(b, t) + side * push)
		travelled += length
	if points.size() > 0:
		var last := points[points.size() - 1]
		var end_push := amplitude * sin(travelled * f1 + p1) + amplitude * 0.35 * sin(travelled * f2 + p2)
		var tail := points[points.size() - 1] - points[maxi(points.size() - 2, 0)]
		var tail_side := Vector2(-tail.y, tail.x).normalized() if tail.length() > 0.001 else Vector2.ZERO
		result.append(last + tail_side * end_push)
	return result


## A loop round [param center] ([param radii] px), a little more than one
## turn, its radius breathing.
static func loop(canvas: MapCanvas, center: Vector2, radii: Vector2, rng: RandomNumberGenerator, width: float = 1.8, turns: float = 1.12) -> void:
	var start := rng.randf() * TAU
	var points := PackedVector2Array()
	var count := maxi(24, int(36 * turns * clampf(maxf(radii.x, radii.y) / 20.0, 1.0, 4.0)))
	var breathe := rng.randf_range(0.05, 0.1)
	var phase := rng.randf() * TAU
	for i in count + 1:
		var t := start + TAU * turns * i / count
		var swell := 1.0 + breathe * sin(t * 2.0 + phase) + 0.04 * float(i) / count
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y) * swell)
	path(canvas, points, rng, width, MapStyle.PENCIL, 0.35)


## Pencil text: the guard's hand, slightly askew.
static func write(canvas: MapCanvas, at: Vector2, words: String, size: int, rng: RandomNumberGenerator, color: Color = MapStyle.PENCIL) -> void:
	canvas.text(at, words, MapFonts.HAND, size, color, rng.randf_range(-0.035, 0.03))


## The seeded hand for [param key] (the same key, the same wobble).
static func rng_for(key: String) -> RandomNumberGenerator:
	return _rng(key)


static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	return rng


# --- rooms, doors ------------------------------------------------------------------------

static func _room(canvas: MapCanvas, room: MapModel.Room, projection: MapProjection) -> void:
	var rng := _rng(String(room.id))
	if room.round:
		var center := projection.to_sheet(room.bounds().get_center())
		var radius := projection.length(room.radius())
		loop(canvas, center, Vector2(radius, radius), rng, MapStyle.PENCIL_WIDTH, 1.04)
		return
	if room.upper:
		for segment in room.outline:
			MapDrawing.dashed(canvas, projection.to_sheet(segment[0]), projection.to_sheet(segment[1]), MapStyle.PENCIL, 1.3, 5.0, 4.0)
		return
	for segment in room.outline:
		stroke(canvas, projection.to_sheet(segment[0]), projection.to_sheet(segment[1]), rng)
	hatch(canvas, room, projection, rng)


## Light diagonal hatching over the room's parts.
static func hatch(canvas: MapCanvas, room: MapModel.Room, projection: MapProjection, rng: RandomNumberGenerator) -> void:
	var pairs := PackedVector2Array()
	# a big open space (the roof's catwalks) is hatched loosely
	var spacing := MapStyle.HATCH_SPACING * clampf(sqrt(room.area) / 14.0, 1.0, 2.4)
	for part in room.parts:
		var box := projection.rect_to_sheet(part).grow(-1.5)
		if box.size.x <= 1.0 or box.size.y <= 1.0:
			continue
		# lines x - y = c run up to the right; c from the top-left corner on
		var c := box.position.x - box.end.y + rng.randf() * spacing
		while c < box.end.x - box.position.y:
			var x0 := maxf(box.position.x, c + box.position.y)
			var x1 := minf(box.end.x, c + box.end.y)
			if x1 - x0 > 2.0:
				var shrink := rng.randf_range(0.0, 2.5)
				var a := Vector2(x0 + shrink, x0 + shrink - c)
				var b := Vector2(x1 - rng.randf_range(0.0, 2.5), x1 - c)
				b.y = b.x - c
				pairs.append_array([a, b])
			c += spacing * rng.randf_range(0.85, 1.15)
	canvas.lines(pairs, Color(MapStyle.PENCIL, MapStyle.HATCH_ALPHA), 1.05)


## A doorway he drew: a small box across the wall.
static func _door(canvas: MapCanvas, door: MapModel.Doorway, projection: MapProjection) -> void:
	var rng := _rng(String(door.id))
	var box := projection.rect_to_sheet(door.rect)
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for i in 4:
		stroke(canvas, corners[i], corners[(i + 1) % 4], rng, 1.2, MapStyle.PENCIL, 1.2)


# --- marks -------------------------------------------------------------------------------

static func _mark(canvas: MapCanvas, model: MapModel, mark: MapModel.Mark, projection: MapProjection) -> void:
	var at := projection.to_sheet(mark.at)
	var rng := _rng("%s/%s" % [mark.kind, mark.id])
	match mark.kind:
		MapModel.MarkKind.TICK:
			tick(canvas, tick_point(model.room(mark.room), projection), rng)
		MapModel.MarkKind.HAVEN:
			var room := model.room(mark.room)
			var box := projection.rect_to_sheet(room.bounds())
			var radii := Vector2(maxf(box.size.x * 0.5 + 9.0, 20.0), maxf(box.size.y * 0.5 + 9.0, 20.0))
			loop(canvas, box.get_center(), radii, rng, 2.0)
		MapModel.MarkKind.WEAPON:
			sketch(canvas, &"gun", at, rng)
		MapModel.MarkKind.ITEM:
			sketch(canvas, item_sketch(mark.item), at, rng)
		MapModel.MarkKind.SEAL:
			sketch(canvas, &"seal", at, rng)
		MapModel.MarkKind.SHARD:
			sketch(canvas, &"shard", at, rng)
		MapModel.MarkKind.NOTE:
			sketch(canvas, &"note", at, rng)
		MapModel.MarkKind.CHESS:
			sketch(canvas, &"chess", at, rng)
		MapModel.MarkKind.SECRET:
			sketch(canvas, &"star", at, rng)
		MapModel.MarkKind.GUARDIAN:
			guardian(canvas, at, mark.crossed, rng)
		MapModel.MarkKind.GATE:
			gate(canvas, at, mark.lock, rng)


## Where a room's tick goes: just left of its name, else on its label point.
static func tick_point(room: MapModel.Room, projection: MapProjection) -> Vector2:
	var block := MapDrawing.name_block(room, projection)
	if block.is_empty() or float(block["angle"]) != 0.0 and absf(float(block["angle"])) > 0.2:
		return projection.to_sheet(room.anchor)
	var rect: Rect2 = block["rect"]
	var pitch: float = block["pitch"]
	return Vector2(rect.position.x - TICK_GAP, rect.position.y + pitch * 0.5)


static func tick(canvas: MapCanvas, at: Vector2, rng: RandomNumberGenerator) -> void:
	var lean := rng.randf_range(-0.12, 0.12)
	var points := PackedVector2Array([Vector2(-6.5, -1.0), Vector2(-2.0, 4.5), Vector2(8.0, -9.0)])
	path(canvas, _place(points, at, lean), rng, 2.1, MapStyle.PENCIL, 0.4)


static func item_sketch(item: StringName) -> StringName:
	match item:
		&"pistol_key":
			return &"key"
		&"fuse_basement", &"fuse_assyria":
			return &"fuse"
		&"power_north":
			return &"bolt"
		&"astrolabe":
			return &"astrolabe"
	return &"star"


## A little drawing [param kind] centred on [param at].
static func sketch(canvas: MapCanvas, kind: StringName, at: Vector2, rng: RandomNumberGenerator, scale: float = ICON) -> void:
	var lean := rng.randf_range(-0.15, 0.15)
	var width := 1.6
	for shape: Array in sketch_shapes(kind):
		var points := PackedVector2Array()
		for point: Vector2 in shape:
			points.append(point * scale)
		path(canvas, _place(points, at, lean), rng, width, MapStyle.PENCIL, 0.3)


## The strokes of each little drawing (px, about 20 across).
static func sketch_shapes(kind: StringName) -> Array:
	match kind:
		&"gun":
			return [[Vector2(-10, -3), Vector2(9, -3), Vector2(9, 1), Vector2(-1, 1), Vector2(-3, 8), Vector2(-8, 8), Vector2(-7, 1), Vector2(-10, 1), Vector2(-10, -3)],
				[Vector2(-1, 1), Vector2(0, 4), Vector2(-3, 4)]]
		&"key":
			return [_ring(Vector2(-6, 0), 3.8, 10), [Vector2(-2.2, 0), Vector2(9, 0)], [Vector2(5, 0), Vector2(5, 3.5)], [Vector2(8, 0), Vector2(8, 3.5)]]
		&"fuse":
			return [[Vector2(-8, -3.5), Vector2(8, -3.5), Vector2(8, 3.5), Vector2(-8, 3.5), Vector2(-8, -3.5)], [Vector2(-4.5, -3.5), Vector2(-4.5, 3.5)], [Vector2(4.5, -3.5), Vector2(4.5, 3.5)], [Vector2(-11, 0), Vector2(-8, 0)], [Vector2(8, 0), Vector2(11, 0)]]
		&"bolt":
			return [[Vector2(2, -10), Vector2(-4, 1), Vector2(1, 1), Vector2(-3, 10), Vector2(5, -2), Vector2(0, -2), Vector2(4, -10)]]
		&"astrolabe":
			return [_ring(Vector2.ZERO, 8.0, 14), _ring(Vector2.ZERO, 4.0, 10), [Vector2(-9, 0), Vector2(9, 0)], [Vector2(0, -9), Vector2(0, 9)]]
		&"seal":
			var rays: Array = [_ring(Vector2.ZERO, 7.5, 14), _ring(Vector2.ZERO, 2.6, 8)]
			for i in 8:
				var t := TAU * i / 8.0
				rays.append([Vector2(cos(t), sin(t)) * 3.8, Vector2(cos(t), sin(t)) * 5.8])
			return rays
		&"shard":
			return [[Vector2(0, -11), Vector2(4.5, -3), Vector2(3, 8), Vector2(0, 11), Vector2(-3, 8), Vector2(-4.5, -3), Vector2(0, -11)], [Vector2(0, -11), Vector2(0.5, 11)]]
		&"note":
			return [[Vector2(-6, -8), Vector2(3, -8), Vector2(6.5, -4.5), Vector2(6.5, 8), Vector2(-6, 8), Vector2(-6, -8)], [Vector2(3, -8), Vector2(3, -4.5), Vector2(6.5, -4.5)],
				[Vector2(-3.5, -1), Vector2(4, -1)], [Vector2(-3.5, 2.5), Vector2(4, 2.5)], [Vector2(-3.5, 5.5), Vector2(1.5, 5.5)]]
		&"chess":
			return [_ring(Vector2(0, -6.5), 3.0, 9), [Vector2(-2.5, -3.5), Vector2(-2, 2), Vector2(-5.5, 6), Vector2(-6, 9), Vector2(6, 9), Vector2(5.5, 6), Vector2(2, 2), Vector2(2.5, -3.5)], [Vector2(-4, 2), Vector2(4, 2)]]
		&"star":
			return [[Vector2(0, -9), Vector2(0, 9)], [Vector2(-7.8, -4.5), Vector2(7.8, 4.5)], [Vector2(-7.8, 4.5), Vector2(7.8, -4.5)]]
	return [[Vector2(-5, 0), Vector2(5, 0)]]


## "!" at a guardian's arena in a loop; crossed out once he fell.
static func guardian(canvas: MapCanvas, at: Vector2, crossed: bool, rng: RandomNumberGenerator) -> void:
	var size := 36
	MapFonts.centered(canvas, at + Vector2(0, -2), "!", MapFonts.HAND, size, MapStyle.PENCIL, rng.randf_range(-0.08, 0.08))
	loop(canvas, at, Vector2(17, 19), rng, 1.9, 1.08)
	if crossed:
		stroke(canvas, at + Vector2(-17, -19), at + Vector2(17, 19), rng, 2.2, MapStyle.PENCIL, 4.0)
		stroke(canvas, at + Vector2(17, -19), at + Vector2(-17, 19), rng, 2.2, MapStyle.PENCIL, 4.0)


## "?" at a closed gate with a sketch of its lock beside it.
static func gate(canvas: MapCanvas, at: Vector2, lock: GateSpec.Kind, rng: RandomNumberGenerator) -> void:
	MapFonts.centered(canvas, at + Vector2(-8, -1), "?", MapFonts.HAND, 28, MapStyle.PENCIL, rng.randf_range(-0.1, 0.1))
	var lean := rng.randf_range(-0.12, 0.12)
	for shape: Array in lock_shapes(lock):
		path(canvas, _place(PackedVector2Array(shape), at + Vector2(12, 0), lean), rng, 1.5, MapStyle.PENCIL, 0.25)


## The strokes of each lock's sketch (px, about 16 across).
static func lock_shapes(lock: GateSpec.Kind) -> Array:
	match lock:
		GateSpec.Kind.CHAIN:
			return [_oval(Vector2(-3.5, 0), Vector2(4.5, 3), 10), _oval(Vector2(3.5, 0), Vector2(4.5, 3), 10)]
		GateSpec.Kind.BOARDS:
			return [[Vector2(-8, -6), Vector2(8, 4)], [Vector2(-8, -3), Vector2(8, 7)], [Vector2(-8, 6), Vector2(8, -4)], [Vector2(-8, 3), Vector2(8, -7)]]
		GateSpec.Kind.SEAL:
			return [_ring(Vector2.ZERO, 7.0, 12), _ring(Vector2.ZERO, 2.5, 8)]
		GateSpec.Kind.POWER:
			return [[Vector2(2, -9), Vector2(-3, 1), Vector2(1, 1), Vector2(-2, 9), Vector2(4, -2), Vector2(0, -2), Vector2(3, -9)]]
		GateSpec.Kind.CRACKED:
			return [[Vector2(-1, -9), Vector2(2, -4), Vector2(-2, 0), Vector2(2, 4), Vector2(0, 9)], [Vector2(2, -4), Vector2(6, -6)], [Vector2(-2, 0), Vector2(-6, 2)]]
		GateSpec.Kind.ROPE:
			return [[Vector2(0, -9), Vector2(2, -5), Vector2(-1, -1), Vector2(1, 3)], _ring(Vector2(1, 6), 3.0, 8)]
		GateSpec.Kind.HOOK:
			return [[Vector2(2, -9), Vector2(2, 3), Vector2(1, 6), Vector2(-2, 7), Vector2(-4.5, 5.5), Vector2(-5, 2.5)], _ring(Vector2(2, -9), 2.0, 6)]
		GateSpec.Kind.BOLT:
			return [[Vector2(-8, -3.5), Vector2(1, -3.5), Vector2(1, 3.5), Vector2(-8, 3.5), Vector2(-8, -3.5)], [Vector2(1, 0), Vector2(8, 0)], [Vector2(-3.5, 0), Vector2(-3.5, -6)]]
		GateSpec.Kind.EVENT:
			return [[Vector2(-6, -8), Vector2(6, -8), Vector2(6, 8), Vector2(-6, 8), Vector2(-6, -8)], [Vector2(-2, -8), Vector2(-2, 8)], [Vector2(2, -8), Vector2(2, 8)], [Vector2(-6, 0), Vector2(6, 0)]]
	return [[Vector2(-5, 0), Vector2(5, 0)]]


## Tonight's goal: a ring at [param at] and a curved arrow coming in from
## the open side, "here!" at its tail.
static func goal_arrow(canvas: MapCanvas, at: Vector2, key: String, busy: PackedVector2Array = PackedVector2Array()) -> void:
	var rng := _rng("goal/" + key)
	loop(canvas, at, Vector2(13, 12), rng, 2.0, 1.15)
	var from := goal_tail(at, busy)
	var tip := at + (from - at).normalized() * 16.0
	var bend := (tip - from).orthogonal().normalized() * (tip - from).length() * 0.22
	var curve := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var a := from.lerp(from.lerp(tip, 0.5) + bend, t)
		var b := (from.lerp(tip, 0.5) + bend).lerp(tip, t)
		curve.append(a.lerp(b, t))
	path(canvas, curve, rng, 2.0, MapStyle.PENCIL, 0.5)
	var back := (curve[curve.size() - 3] - tip).normalized()
	var side := back.orthogonal()
	stroke(canvas, tip, tip + back * 11.0 + side * 6.0, rng, 2.0, MapStyle.PENCIL, 1.0)
	stroke(canvas, tip, tip + back * 11.0 - side * 6.0, rng, 2.0, MapStyle.PENCIL, 1.0)
	var words := MapDrawing.tr_key(&"MAP_PENCIL_HERE")
	var size := HAND_NOTE + 2
	var text_at := from + (from - at).normalized() * 12.0 - Vector2(MapFonts.width(MapFonts.HAND, words, size) * 0.5, -size * 0.35)
	write(canvas, text_at, words, size, rng)


## Where the goal arrow starts: on the map's area, as far as it can from
## what is written and drawn round the goal ([param busy]: sheet points),
## up and to the left when nothing is in the way.
static func goal_tail(at: Vector2, busy: PackedVector2Array = PackedVector2Array()) -> Vector2:
	var area := MapStyle.MAP_AREA.grow(-40.0)
	var best := at + Vector2(-0.7, -0.7) * GOAL_REACH
	var best_score := -INF
	for i in 8:
		var direction := Vector2.from_angle(-PI * 0.75 + TAU * i / 8.0)
		var tail := at + direction * GOAL_REACH
		if not area.has_point(tail):
			continue
		var clear := 60.0
		for point in busy:
			clear = minf(clear, minf(point.distance_to(tail), point.distance_to(at.lerp(tail, 0.5)) + 8.0))
		var score := clear - i * 0.5
		if score > best_score:
			best_score = score
			best = tail
	return best


## The guard's notes in the key's notes box: "Tonight:" and the goal (with
## the page it is on when that is not this one), then his own key.
static func notes(canvas: MapCanvas, model: MapModel, tab: StringName) -> void:
	var rng := _rng("notes/" + String(model.goal.key))
	var lines := MapDrawing.notes_lines()
	var x := MapDrawing.KEY_X + 4.0
	var width := MapDrawing.KEY_RIGHT - x - 6.0
	var row := 0
	var size := HAND_NOTE
	if model.goal.key != &"":
		write(canvas, Vector2(x, lines[row] - 5.0), MapDrawing.tr_key(&"MAP_PENCIL_TONIGHT"), size + 1, rng)
		var head := MapFonts.width(MapFonts.HAND, MapDrawing.tr_key(&"MAP_PENCIL_TONIGHT"), size + 1) + 14.0
		var text := MapDrawing.tr_key(model.goal.key)
		if model.goal.placed and model.goal.tab != tab:
			text += " " + MapDrawing.tr_key(&"MAP_PENCIL_GOAL_ON") % MapDrawing.tr_key(MapModel.TAB_KEYS[model.goal.tab])
		var first := MapFonts.wrap(MapFonts.HAND, text, size, width - head)
		var rest := ""
		if not first.is_empty():
			write(canvas, Vector2(x + head, lines[row] - 5.0), first[0], size, rng)
			rest = text.substr(first[0].length()).strip_edges()
		row += 1
		for line in MapFonts.wrap(MapFonts.HAND, rest, size, width):
			if row >= lines.size() - 5:
				break
			write(canvas, Vector2(x + 10.0, lines[row] - 5.0), line, size, rng)
			row += 1
	# his key, on the last lines
	row = maxi(row + 1, lines.size() - 5)
	var keys := [
		[&"tick", &"MAP_PENCIL_KEY_VISITED"], [&"loop", &"MAP_PENCIL_KEY_HAVEN"],
		[&"bang", &"MAP_PENCIL_KEY_GUARDIAN"], [&"query", &"MAP_PENCIL_KEY_GATE"],
		[&"arrow", &"MAP_PENCIL_KEY_GOAL"],
	]
	var columns := 2
	var column_width := width / columns
	for i in keys.size():
		var line_y: float = lines[mini(row + i / columns, lines.size() - 1)]
		var cell_x := x + column_width * (i % columns)
		var symbol := Vector2(cell_x + 14.0, line_y - 11.0)
		match keys[i][0]:
			&"tick":
				tick(canvas, symbol, rng)
			&"loop":
				loop(canvas, symbol, Vector2(12, 9), rng, 1.6)
			&"bang":
				MapFonts.centered(canvas, symbol, "!", MapFonts.HAND, 26, MapStyle.PENCIL)
			&"query":
				MapFonts.centered(canvas, symbol, "?", MapFonts.HAND, 24, MapStyle.PENCIL)
			&"arrow":
				path(canvas, PackedVector2Array([symbol + Vector2(-11, 4), symbol + Vector2(0, -2), symbol + Vector2(9, -1)]), rng, 1.7)
				stroke(canvas, symbol + Vector2(9, -1), symbol + Vector2(3, -6), rng, 1.7, MapStyle.PENCIL, 0.8)
				stroke(canvas, symbol + Vector2(9, -1), symbol + Vector2(3, 4), rng, 1.7, MapStyle.PENCIL, 0.8)
		write(canvas, Vector2(cell_x + 34.0, line_y - 5.0), "— " + MapDrawing.tr_key(keys[i][1]), size - 2, rng)


# --- helpers ----------------------------------------------------------------------------

static func _place(points: PackedVector2Array, at: Vector2, lean: float) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point in points:
		placed.append(at + point.rotated(lean))
	return placed


static func _ring(center: Vector2, radius: float, count: int) -> Array:
	return _oval(center, Vector2(radius, radius), count)


static func _oval(center: Vector2, radii: Vector2, count: int) -> Array:
	var points: Array = []
	for i in count + 1:
		var t := TAU * i / count
		points.append(center + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	return points


## A canvas that hands its lines on with a pencil's wobble (for drawings
## made by MapDrawing helpers, e.g. a flight of stairs in pencil).
class _Shaky:
	extends MapCanvas
	var target: MapCanvas
	var rng: RandomNumberGenerator

	func _init(on: MapCanvas, with_rng: RandomNumberGenerator) -> void:
		target = on
		rng = with_rng
		layer = on.layer

	func lines(pairs: PackedVector2Array, color: Color, width: float) -> void:
		for i in range(0, pairs.size() - 1, 2):
			MapPencil.stroke(target, pairs[i], pairs[i + 1], rng, width, color, 1.5)

	func polyline(points: PackedVector2Array, color: Color, width: float, _closed: bool = false) -> void:
		MapPencil.path(target, points, rng, width, color, 0.4)
