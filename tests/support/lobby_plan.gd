extends SceneTree
## Headless floor plan of the lobby (no window): draws the carved shell,
## passages, balcony, stairs, pieces, spawn slots, loot and markers into
## tests/_out/lobby/plan.png and prints a room table plus a coarse text map.
## Run: bash tools/run_lobby.sh plan

const PX := 8.0   # pixels per metre
const ORIGIN := Vector2(-46, -28)
const SIZE_M := Vector2(92, 92)
const KIND_COLORS := {&"wax": Color(1.0, 0.85, 0.3), &"wolf": Color(0.75, 0.45, 0.2), &"knight": Color(0.55, 0.75, 1.0), &"bust": Color(1, 1, 1)}
const LINK_COLORS := {
	RoomGraph.Kind.OPEN: Color(0.3, 0.9, 0.3),
	RoomGraph.Kind.LOCKABLE: Color(1.0, 0.6, 0.1),
	RoomGraph.Kind.SECRET: Color(0.8, 0.3, 1.0),
	RoomGraph.Kind.GATE: Color(1.0, 0.15, 0.15),
}

var image: Image


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var layout := LobbyLayout.create()
	image = Image.create_empty(int(SIZE_M.x * PX), int(SIZE_M.y * PX), false, Image.FORMAT_RGB8)
	image.fill(Color(0.05, 0.05, 0.07))
	var builder := LevelBuilder.new(layout, null, null, null)
	var boxes := ShellCarver.carve(builder.shell_volumes())
	for box in boxes:
		if box.kit in [&"floor", &"threshold", &"slab"]:
			_rect(Rect2(box.aabb.position.x, box.aabb.position.z, box.aabb.size.x, box.aabb.size.z), builder.tint_of(box.walk_owner).darkened(0.45))
	for passage in layout.openings:
		_rect(passage.rect, LINK_COLORS[passage.link].darkened(0.2))
	for box in boxes:
		if box.kit == &"wall" and not box.above_all:
			_rect(Rect2(box.aabb.position.x, box.aabb.position.z, box.aabb.size.x, box.aabb.size.z), Color(0.72, 0.72, 0.75))
	for part in layout.room(&"balcony").parts:
		_rect(part, Color(0.35, 0.55, 0.9), 0.35)
	for flight in layout.stairs:
		_rect(flight.rect, Color(0.9, 0.9, 0.5), 0.45)
		var steps := flight.step_count()
		for i in steps:
			var t := float(i) / steps
			if flight.ascend.y != 0.0:
				var z := lerpf(flight.rect.end.y, flight.rect.position.y, t) if flight.ascend.y < 0.0 else lerpf(flight.rect.position.y, flight.rect.end.y, t)
				_rect(Rect2(flight.rect.position.x, z - 0.03, flight.rect.size.x, 0.06), Color(0.3, 0.3, 0.2))
	for room in layout.rooms:
		for well in room.skylights:
			_frame(well, Color(0.6, 0.8, 1.0))
	for piece in layout.pieces:
		if piece.kit in [&"balcony", &"railing"]:
			continue
		_frame(piece.footprint(), Color(1, 1, 1) if piece.collide else Color(0.5, 0.5, 0.55))
	for slot in layout.spawn_slots:
		var color: Color = KIND_COLORS.get(slot.kinds[0], Color.WHITE)
		_dot(Vector2(slot.position.x, slot.position.z), 0.35, color if slot.dormant else Color(1, 0.2, 0.2))
	for spot in layout.loot_spots:
		_rect(Rect2(spot.position.x - 0.2, spot.position.z - 0.2, 0.4, 0.4), Color(1, 0.3, 0.9) if spot.container else Color(0.3, 1, 0.5))
	for id: StringName in layout.markers:
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		_rect(Rect2(at.x - 0.35, at.z - 0.05, 0.7, 0.1), Color(0.2, 1, 1))
		_rect(Rect2(at.x - 0.05, at.z - 0.35, 0.1, 0.7), Color(0.2, 1, 1))
	_dot(Vector2(layout.player_start.origin.x, layout.player_start.origin.z), 0.6, Color(0.2, 1, 0.2))
	for id: StringName in layout.haven_spots:
		var spot: Vector3 = (layout.haven_spots[id] as Transform3D).origin
		_dot(Vector2(spot.x, spot.z), 0.5, Color(0.3, 0.5, 1))
	var out := ProjectSettings.globalize_path("res://tests/_out/lobby/")
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	image.save_png(out.path_join("plan.png"))
	print("saved ", out.path_join("plan.png"))
	_room_table(layout)
	_text_map(layout, boxes)
	quit()


func _px(point: Vector2) -> Vector2i:
	return Vector2i(((point - ORIGIN) * PX).round())


func _rect(area: Rect2, color: Color, alpha: float = 1.0) -> void:
	var a := _px(area.position)
	var b := _px(area.end)
	for y in range(maxi(mini(a.y, b.y), 0), mini(maxi(a.y, b.y), image.get_height())):
		for x in range(maxi(mini(a.x, b.x), 0), mini(maxi(a.x, b.x), image.get_width())):
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(color, alpha))


func _frame(area: Rect2, color: Color) -> void:
	var t := 1.0 / PX
	_rect(Rect2(area.position.x, area.position.y, area.size.x, t), color)
	_rect(Rect2(area.position.x, area.end.y - t, area.size.x, t), color)
	_rect(Rect2(area.position.x, area.position.y, t, area.size.y), color)
	_rect(Rect2(area.end.x - t, area.position.y, t, area.size.y), color)


func _dot(center: Vector2, radius: float, color: Color) -> void:
	var c := _px(center)
	var r := int(radius * PX)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r and c.x + x >= 0 and c.y + y >= 0 and c.x + x < image.get_width() and c.y + y < image.get_height():
				image.set_pixel(c.x + x, c.y + y, color)


func _room_table(layout: LevelLayout) -> void:
	print("room             footprint (m)   area m2  floor  ceiling  slots  loot")
	for room in layout.rooms:
		var bounds := room.parts[0]
		for part in room.parts:
			bounds = bounds.merge(part)
		var slots := layout.spawn_slots.filter(func(s: SpawnSlot) -> bool: return s.room == room.id).size()
		var loot := layout.loot_spots.filter(func(s: LootSpot) -> bool: return s.room == room.id).size()
		print("%-16s %5.1f x %-5.1f   %7.0f  %5.1f  %7.1f  %5d  %4d" % [room.id, bounds.size.x, bounds.size.y, room.area(), room.floor_y, room.ceiling_y, slots, loot])


## Coarse map, one character per 2 m: # wall, . floor, letters = rooms,
## = stairs, + passages.
func _text_map(layout: LevelLayout, boxes: Array[ShellCarver.ShellBox]) -> void:
	var letters := {&"hall": "H", &"gallery": "G", &"armory": "A", &"diorama": "D", &"corridor_w": "c", &"corridor_e": "c", &"staff_corridor": "s", &"security": "S", &"closet": "k", &"secret_chamber": "x", &"shotgun_niche": "x", &"vent": "v", &"undercroft": "u"}
	for zi in range(0, int(SIZE_M.y), 2):
		var line := ""
		for xi in range(0, int(SIZE_M.x), 2):
			var p := Vector3(ORIGIN.x + xi + 1.0, 0.5, ORIGIN.y + zi + 1.0)
			var ch := " "
			var room := layout.room_at(p)
			if room != &"":
				ch = letters.get(room, "?")
			for flight in layout.stairs:
				if flight.room_low != flight.room_high and flight.rect.has_point(Vector2(p.x, p.z)):
					ch = "="
			for passage in layout.openings:
				if passage.rect.grow(0.5).has_point(Vector2(p.x, p.z)) and passage.floor_y < 1.0:
					ch = "+"
			if ch == " ":
				for box in boxes:
					if box.kit == &"wall" and not box.above_all and Rect2(box.aabb.position.x, box.aabb.position.z, box.aabb.size.x, box.aabb.size.z).grow(0.5).has_point(Vector2(p.x, p.z)):
						ch = "#"
						break
			line += ch
		print(line)
