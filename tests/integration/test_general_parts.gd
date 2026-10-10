extends TestCase
## The General's parts on a bare floor (no museum): his arena's markers in
## the Japanese garden (the post, the start line, the eave and its perch,
## the reward spot), his arrows (an arc onto the mark in its time, a hit on
## whoever stands there, a rock stopping one).

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 1.0, 120.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)


func after_each() -> void:
	world.free()


func _block(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	body.global_position = at
	return body


# --- the arena -------------------------------------------------------------------

func test_his_arena_markers_lie_in_the_garden_the_perch_on_the_eave() -> void:
	var layout := Floor1Layout.create()
	const ROOM := &"asia_garden"
	for id: StringName in [&"guardian_general", &"arena_general_start", &"arena_general_perch", &"arena_general_reward"]:
		assert_true(layout.markers.has(id), str(id))
		assert_eq(layout.marker_rooms.get(id, &""), ROOM, str(id))
	var post: Transform3D = layout.markers[&"guardian_general"]
	var perch: Transform3D = layout.markers[&"arena_general_perch"]
	var reward: Vector3 = (layout.markers[&"arena_general_reward"] as Transform3D).origin
	assert_true(perch.origin.y >= 3.5, "the perch is up on the eave (%.1f m)" % perch.origin.y)
	var flat := Vector2(perch.origin.x - post.origin.x, perch.origin.z - post.origin.z).length()
	assert_true(flat > 3.0 and flat < 9.0, "the perch over the garden near his post (%.1f m)" % flat)
	var toward := post.origin - perch.origin
	assert_gt((-perch.basis.z).dot(Vector3(toward.x, 0.0, toward.z).normalized()), 0.95, "the perch faces his post")
	# the eave: a slab under the perch, over the guard's head, hugging the
	# tea house (an L round its north-east corner)
	var under: Array = []
	for piece in layout.pieces:
		if piece.room == ROOM and piece.kit == &"balcony":
			under.append(piece)
			assert_true(piece.position.y >= 3.3, "the eave over anybody's head (%.1f)" % piece.position.y)
	assert_eq(under.size(), 2, "two arms of the eave")
	var carries := false
	for piece in under:
		var box: Rect2 = piece.footprint()
		if box.grow(0.05).has_point(Vector2(perch.origin.x, perch.origin.z)):
			carries = true
			assert_almost_eq(piece.position.y + piece.size.y, perch.origin.y, 0.01, "the perch stands on the eave's top")
	assert_true(carries, "the perch stands on the eave")
	# the tea house room lies west and south of the corner the eave wraps
	var teahouse := layout.room(&"asia_teahouse")
	assert_not_null(teahouse)
	if teahouse != null:
		var bounds := teahouse.bounds()
		assert_true(perch.origin.x > bounds.end.x and perch.origin.z > bounds.end.y, "the perch on the garden side of the tea house's north-east corner")
	assert_lt(reward.distance_to(post.origin), 4.0, "the shard falls before his post")
	assert_almost_eq(reward.y, 0.0, 0.01)


# --- the arrows -------------------------------------------------------------------

func test_an_arrows_arc_brings_its_head_onto_the_mark_in_its_time() -> void:
	var from := Vector3(13.6, 5.2, -76.6)
	for to: Vector3 in [Vector3(17.5, 0.0, -70.0), Vector3(8.0, 0.0, -66.0), Vector3(26.0, 0.0, -72.0)]:
		var time := GeneralArrow.flight_time(Vector2(to.x - from.x, to.z - from.z).length())
		assert_true(time >= GeneralBrain.ARROW_FLIGHT.x and time <= GeneralBrain.ARROW_FLIGHT.y, "%.2f s" % time)
		var v := GeneralArrow.launch_velocity(from, to, time, GeneralArrow.GRAVITY)
		var end := from + v * time + Vector3.DOWN * 0.5 * GeneralArrow.GRAVITY * time * time
		assert_lt(end.distance_to(to), 0.001, "on target %s" % str(to))
		assert_gt(v.y, 0.0, "lobbed up its arc")


func test_an_arrow_lands_in_its_mark_and_hurts_who_stands_there() -> void:
	var guard := TargetDummy.new()
	world.add_child(guard)
	guard.global_position = Vector3(0.0, 0.0, -10.0)
	var landed: Array[Vector3] = []
	var arrow := GeneralArrow.make(Vector3(0.0, 4.0, -1.0), Vector3(0.0, 0.0, -10.0), 0.9, GeneralBrain.ARROW_DAMAGE, null, guard)
	arrow.landed.connect(func(at: Vector3) -> void: landed.append(at))
	var mark := GroundMark.disc(GeneralBrain.ARROW_RADIUS)
	world.add_child(mark)
	mark.global_position = Vector3(0.0, 0.0, -10.0)
	arrow.mark = mark
	world.add_child(arrow)
	await physics_frames(70)
	assert_eq(landed.size(), 1, "it came down")
	if landed.size() == 1:
		assert_lt(Vector2(landed[0].x, landed[0].z + 10.0).length(), 0.3, "in its mark")
	assert_true(arrow.stuck, "it sticks in the gravel")
	assert_eq(guard.hits.size(), 1, "the guard who stayed in the mark is hit")
	if not guard.hits.is_empty():
		assert_almost_eq(guard.hits[0].amount, GeneralBrain.ARROW_DAMAGE, 0.01)
	await physics_frames(25)
	assert_false(is_instance_valid(mark), "the mark fades once it landed")
	# one the guard walked out of
	var other := GeneralArrow.make(Vector3(3.0, 4.0, -1.0), Vector3(3.0, 0.0, -10.0), 0.9, GeneralBrain.ARROW_DAMAGE, null, guard)
	world.add_child(other)
	guard.global_position = Vector3(3.0, 0.0, -14.0)
	await physics_frames(70)
	assert_true(other.stuck)
	assert_eq(guard.hits.size(), 1, "off the mark: untouched")
	await physics_frames(roundi(GeneralArrow.STUCK_TIME * 60.0) + 5)
	assert_false(is_instance_valid(arrow), "it crumbles away")


func test_a_rock_stops_an_arrow_short_of_its_mark() -> void:
	_block(Vector3(8.0, 1.2, -8.0), Vector3(2.2, 2.4, 1.8))
	await physics_frames(2)
	var guard := TargetDummy.new()
	world.add_child(guard)
	guard.global_position = Vector3(8.0, 0.0, -10.5)
	var stopped: Array[Vector3] = []
	var arrow := GeneralArrow.make(Vector3(8.0, 1.6, -1.0), Vector3(8.0, 0.0, -10.5), 0.85, GeneralBrain.ARROW_DAMAGE, null, guard)
	arrow.landed.connect(func(at: Vector3) -> void: stopped.append(at))
	world.add_child(arrow)
	await physics_frames(70)
	assert_eq(stopped.size(), 1)
	if stopped.size() == 1:
		assert_gt(stopped[0].z, -9.2, "the rock took it, short of the mark")
	assert_eq(guard.hits.size(), 0, "cover")
