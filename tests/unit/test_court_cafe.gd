extends TestCase
## The court café's layout (plan 2026-10-10-kawiarnia-zmeczenie, 2.3): the
## counter in the north-west corner with the barista's aisle free behind it
## (the kit splits its collision), the flap shutting the aisle's one open
## end, the machine, slate and urn on the counter and the back bar, the
## note and the loot moved, and nothing else standing in the café.

const Court := preload("res://src/level/floor1/zones/court.gd")
## The model's native size (ArtLibrary.KIT_COURT) and Floor1Art's stretch limits.
const MODEL := Vector3(4.06, 2.90, 2.28)
const CAFE_MARKERS: Array[StringName] = [&"cafe_machine", &"cafe_slate", &"cafe_urn", &"note_court_1"]

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func _piece(kit: StringName) -> PieceSpec:
	for piece in layout.pieces:
		if piece.kit == kit and piece.room == &"court":
			return piece
	return null


## The barista's aisle in world space (the counter is not turned).
func _aisle() -> AABB:
	var counter := _piece(&"cafe_counter")
	var local := LevelKit.cafe_aisle(counter.size)
	return AABB(local.position + counter.position, local.size)


func _front(marker: StringName) -> Vector3:
	return -(layout.markers[marker] as Transform3D).basis.z


func test_the_counter_stands_in_the_north_west_corner() -> void:
	var counter := _piece(&"cafe_counter")
	assert_not_null(counter)
	var foot := counter.footprint()
	assert_almost_eq(foot.position.x, -30.0, 0.1, "its west end by the west wall")
	assert_almost_eq(foot.position.y, -30.0, 0.05, "its back bar against the north wall")
	assert_lt(counter.size.x / MODEL.x, 1.3 + 0.001, "within the model's stretch along")
	assert_lt(counter.size.z / MODEL.z, 1.15 + 0.001, "within the model's stretch in depth")
	assert_eq(counter.yaw, 0.0, "its front to the court")
	assert_true(counter.collide)


func test_the_kit_leaves_the_baristas_aisle_free() -> void:
	var counter := _piece(&"cafe_counter")
	var shapes := LevelKit.collision_shapes(&"cafe_counter", counter.size)
	assert_eq(shapes.size(), 2, "the front counter and the back bar")
	var aisle := LevelKit.cafe_aisle(counter.size)
	assert_gt(aisle.size.z, 1.0, "room for the guard (0.8 m wide)")
	assert_true(aisle.position.z > -counter.size.z * 0.5 and aisle.end.z < counter.size.z * 0.5, "inside the counter's depth")
	var tall := 0.0
	for shape in shapes:
		var box := shape.shape as BoxShape3D
		var solid := AABB(shape.position - box.size * 0.5, box.size)
		assert_false(solid.intersects(aisle.grow(-0.01)), "the aisle is free of %s" % solid)
		assert_almost_eq(box.size.x, counter.size.x, 0.001, "the whole length")
		tall = maxf(tall, solid.end.y)
		shape.free()
	assert_almost_eq(tall, LevelKit.CAFE_BACK_BAR_HEIGHT, 0.001, "the back bar's shelves stop a body too")
	# the greybox shows the same two blocks
	var look := LevelKit.visual(&"cafe_counter", counter.size, Color.GRAY)
	assert_gt(look.find_children("*", "MeshInstance3D", true, false).size(), 0)
	look.free()


func test_the_flap_shuts_the_aisles_open_end() -> void:
	var counter := _piece(&"cafe_counter")
	var flap := _piece(&"cafe_flap")
	assert_not_null(flap)
	var aisle := _aisle()
	var foot := flap.footprint()
	assert_almost_eq(foot.position.x, counter.footprint().end.x, 0.01, "against the counter's east end")
	assert_lt(foot.position.y, aisle.position.z + 0.01, "spans the aisle's depth (north)")
	assert_gt(foot.end.y, aisle.end.z - 0.01, "spans the aisle's depth (south)")
	assert_almost_eq(flap.yaw, -PI * 0.5, 0.001, "its front to the court")
	assert_almost_eq(flap.size.y, counter.size.y, 0.001, "counter height")
	assert_true(flap.collide, "shut, it stops a body")
	# the west end is the court's west wall: nothing else opens the aisle
	assert_lt(aisle.position.x, -29.9)


func test_the_machine_slate_and_urn_stand_on_the_counter() -> void:
	var counter := _piece(&"cafe_counter")
	var aisle := _aisle()
	for id in CAFE_MARKERS:
		assert_true(layout.markers.has(id), str(id))
		assert_eq(layout.marker_rooms[id], &"court", str(id))
	var machine := (layout.markers[&"cafe_machine"] as Transform3D).origin
	var slate := (layout.markers[&"cafe_slate"] as Transform3D).origin
	var urn := (layout.markers[&"cafe_urn"] as Transform3D).origin
	var note := (layout.markers[&"note_court_1"] as Transform3D).origin
	var foot := counter.footprint()
	for at: Vector3 in [machine, slate, note]:
		assert_true(foot.has_point(Vector2(at.x, at.z)), "%s over the counter" % at)
		assert_gt(at.z, aisle.end.z, "on the front counter, not in the aisle")
		assert_almost_eq(at.y, counter.size.y, 0.1, "on the counter's top")
	assert_true(foot.has_point(Vector2(urn.x, urn.z)))
	assert_lt(urn.z, aisle.position.z, "the urn on the back bar")
	assert_almost_eq(urn.y, 0.94, 0.05, "on the back bar's top")
	assert_lt(_front(&"cafe_machine").z, -0.9, "the machine's levers face the barista (north)")
	assert_gt(_front(&"cafe_slate").z, 0.9, "the slate reads from the court")
	assert_gt(_front(&"cafe_urn").z, 0.9, "the urn's tap to the aisle")
	assert_gt(absf(note.x - machine.x), 0.45, "the note is not under the machine")
	assert_gt(absf(note.x - slate.x), 0.45, "nor under the slate")


func test_nothing_else_stands_in_the_cafe_and_the_loot_waits_behind_the_counter() -> void:
	var counter := _piece(&"cafe_counter")
	var flap := _piece(&"cafe_flap")
	var cafe := counter.footprint().merge(flap.footprint()).grow(0.4)
	# (the basement runs under the court: only the court's own rooms count)
	for slot in layout.spawn_slots:
		if layout.room(slot.room).zone == &"court":
			assert_false(cafe.has_point(Vector2(slot.position.x, slot.position.z)), "no exhibit at %s" % slot.position)
	for patrol in layout.patrols:
		if layout.room(patrol.room).zone != &"court":
			continue
		for at in patrol.points:
			assert_false(cafe.has_point(Vector2(at.x, at.z)), "no patrol point at %s" % at)
	for id: StringName in layout.markers:
		if CAFE_MARKERS.has(id) or layout.room(layout.marker_rooms[id]).zone != &"court":
			continue
		var at := (layout.markers[id] as Transform3D).origin
		if at.y > 2.5:
			continue   # the corner's camera, up on the wall
		assert_false(cafe.has_point(Vector2(at.x, at.z)), "%s stays out of the café" % id)
	var aisle := _aisle()
	var behind := 0
	for spot in layout.loot_spots:
		var flat := Vector2(spot.position.x, spot.position.z)
		if not cafe.has_point(flat) or layout.room(spot.room).zone != &"court":
			continue
		assert_true(counter.footprint().has_point(flat) and spot.position.z < aisle.position.z, "the café's loot stands on the back bar: %s" % spot.position)
		assert_almost_eq(spot.position.y, 0.94, 0.05)
		behind += 1
	assert_eq(behind, 1, "one box of loot behind the counter")
