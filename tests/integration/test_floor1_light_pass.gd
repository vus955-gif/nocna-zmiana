extends TestCase
## The light pass of 19.10 (plan
## docs/superpowers/plans/2026-10-19-swiatlo-parteru.md; the owner's
## playtest: "the basement is very dark (acceptable), but some ground-floor
## sections are definitely too dark"): the dark rooms of the ground floor
## burn their lamps brighter and wash their floors - soft spots down onto
## the floor, the bounce of the room's own lamps the renderer leaves out -
## without shadows or haze, never through the floor into a room below; the
## basement keeps its darkness.

## The ground-floor rooms the night's tour measured darker than ~0.045 in
## mean luminance (a black floor under lamps that light walls and ceilings).
const DARK_ROOMS: Array[StringName] = [&"egypt_vestibule", &"egypt_gallery", &"egypt_tomb_passage",
	&"egypt_tombs", &"egypt_tomb_hall", &"north_hall", &"enlightenment_cabinet", &"enlightenment_portraits",
	&"assyria_gate", &"assyria_balawat", &"assyria_library", &"assyria_lions", &"asia_porcelain", &"asia_armor",
	&"americas_north", &"americas_temple"]

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func test_the_dark_rooms_burn_their_lamps_brighter() -> void:
	var recipe := Floor1LightRecipe.create(layout)
	for id in DARK_ROOMS:
		assert_not_null(layout.room(id), "%s is a room of the floor" % id)
		var entry: Dictionary = recipe.rooms.get(recipe.key(id), {})
		assert_true(float(entry.get("lamp_energy", 1.0)) >= 1.25, "%s's lamps burn brighter than the plan (%s)" % [id, entry.get("lamp_energy", 1.0)])


func test_every_dark_room_washes_its_whole_floor() -> void:
	var washes := Floor1LightRecipe.floor_washes(layout)
	assert_gt(washes.size(), DARK_ROOMS.size() - 1, "at least a wash a room (%d)" % washes.size())
	for id in DARK_ROOMS:
		var room := layout.room(id)
		if room == null:
			continue
		for part in room.parts:
			# the middle of the part and four points halfway to its corners
			var middle := part.get_center()
			var spots: Array[Vector2] = [middle]
			for corner: Vector2 in [part.position, part.position + Vector2(part.size.x, 0.0), part.end, part.position + Vector2(0.0, part.size.y)]:
				spots.append(middle.lerp(corner, 0.5))
			for spot in spots:
				assert_true(_lit(washes, room, spot), "%s's floor at %s lies under a wash" % [id, spot])


## True when a wash of [param room] lights the floor at [param spot]: within
## its lit disc (a little wider than it hangs high) and reaching past the
## floor under it (the light fades out towards its range).
func _lit(washes: Array, room: RoomSpec, spot: Vector2) -> bool:
	for wash: Dictionary in washes:
		if wash["room"] != room.id:
			continue
		var at: Vector3 = wash["position"]
		var high := at.y - room.floor_y
		if Vector2(at.x, at.z).distance_to(spot) <= high * 1.5 and float(wash["range"]) >= high * 1.15:
			return true
	return false


func test_the_washes_are_soft_fills_aimed_at_the_floor() -> void:
	var fill: Dictionary = Floor1LightRecipe.FIXTURES[&"fill"]
	assert_false(fill["shadow"], "a fill casts no shadow (the budget stays the rooms')")
	assert_eq(float(fill["fog"]), 0.0, "and lights no dust")
	for wash: Dictionary in Floor1LightRecipe.floor_washes(layout):
		assert_eq(wash.get("rule", &""), &"fill", "%s's wash is a fill" % wash["room"])
		assert_false(wash.get("shadow", false), "without a shadow")
		assert_eq(wash.get("group", LightSpec.MAIN), LightSpec.MAIN, "on the room's mains (a blackout puts it out)")
		assert_eq(wash.get("fixture", &""), &"", "with no fitting to see (it is bounce)")
		assert_lt((wash["direction"] as Vector3).angle_to(Vector3.DOWN), 0.01, "aimed straight down")
		assert_gt(float(wash["angle"]), 55.0, "wide")
		var room := layout.room(wash["room"])
		var at: Vector3 = wash["position"]
		assert_lt(at.y, room.ceiling_y, "under %s's ceiling" % room.id)
		assert_gt(at.y - room.floor_y, 2.5, "over the guard's head")


func test_no_wash_reaches_into_a_room_under_the_floor() -> void:
	for wash: Dictionary in Floor1LightRecipe.floor_washes(layout):
		var room := layout.room(wash["room"])
		var at: Vector3 = wash["position"]
		var reach: float = wash["range"]
		for other in layout.rooms:
			if other.ceiling_y > room.floor_y + 0.01:
				continue
			var depth := at.y - other.ceiling_y
			if depth >= reach:
				continue
			var radius := sqrt(reach * reach - depth * depth)
			var middle := Vector2(at.x, at.z)
			for part in other.parts:
				var nearest := Vector2(clampf(middle.x, part.position.x, part.end.x), clampf(middle.y, part.position.y, part.end.y))
				assert_true(middle.distance_to(nearest) >= radius, "%s's wash at %s lights %s under the floor" % [room.id, at, other.id])


func test_the_basement_the_havens_and_the_secrets_wash_nothing() -> void:
	for id: StringName in Floor1LightRecipe.FLOOR_WASHES:
		var room := layout.room(id)
		assert_not_null(room, "%s is a room of the floor" % id)
		if room == null:
			continue
		assert_ne(room.zone, &"basement", "%s: the basement stays dark" % id)
		assert_false(room.secret, "%s: a secret room keeps its own light" % id)
		assert_false(room.haven, "%s: a haven keeps its own light" % id)
		assert_true(room.floor_y > Floor1Plan.BASEMENT_Y + 1.0, "%s is above the basement" % id)
