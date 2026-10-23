extends TestCase
## RoomCuller on a change of the camera's room (plan
## 2026-10-21-wydajnosc-cpu): only the rooms whose state changes are
## touched; the entered room and those next to it come on at once (no pop),
## the rest - rooms two passages away coming on, the far ones going off - a
## few per frame after. A row of seven rooms, R0 .. R6, each with a lamp and
## dust, depth 2.

const ROOMS := 7

var layout: LevelLayout
var culler: RoomCuller
var root: Node3D
var camera: Camera3D
var motes: Dictionary = {}


func before_each() -> void:
	layout = LevelLayout.new()
	var rects: Array[Rect2] = []
	for i in ROOMS:
		rects = [Rect2(i * 10.0, 0.0, 10.0, 10.0)]
		layout.add_room(_room(i), rects, 0.0, 3.0, Color.GRAY)
		if i > 0:
			layout.add_opening(StringName("door_%d" % i), Rect2(i * 10.0 - 0.25, 4.0, 0.5, 2.0), 0.0, 2.5, _room(i - 1), _room(i))
	root = Node3D.new()
	add_child(root)
	for i in ROOMS:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(i * 10.0 + 5.0, 2.5, 5.0)
		lamp.set_meta(&"room", _room(i))
		root.add_child(lamp)
		var dust := GPUParticles3D.new()
		dust.position = Vector3(i * 10.0 + 5.0, 1.5, 5.0)
		dust.set_meta(&"room", _room(i))
		dust.emitting = true
		root.add_child(dust)
		motes[_room(i)] = dust
	culler = RoomCuller.new()
	culler.enabled = false
	add_child(culler)
	culler.setup(layout, [root] as Array[Node])
	culler.depth = 2
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true


func _room(i: int) -> StringName:
	return StringName("r%d" % i)


func _at(i: int) -> Vector3:
	return Vector3(i * 10.0 + 5.0, 1.7, 5.0)


func _lit() -> String:
	var out := ""
	for i in ROOMS:
		out += "-" if culler.is_culled(_room(i)) else str(i)
	return out


func test_a_room_change_touches_only_the_rooms_that_change() -> void:
	culler.update_from(_at(2))
	assert_eq(_lit(), "01234--")
	var before := culler.rooms_switched
	culler.update_from(_at(3))
	assert_eq(_lit(), "-12345-", "R0 off, R5 on")
	assert_eq(culler.rooms_switched - before, 2, "two rooms switched, not all seven")
	before = culler.rooms_switched
	culler.update_from(_at(3))
	assert_eq(culler.rooms_switched - before, 0, "the same room again: nothing")
	assert_false(motes[&"r0"].emitting, "the far dust stops")
	assert_true(motes[&"r5"].emitting, "the near dust burns")


func test_walking_in_lights_the_room_at_once_the_far_ones_follow() -> void:
	culler.spread_budget_usec = 0   # one room a frame off the queue
	culler.enabled = true
	camera.global_position = _at(0)
	await physics_frames(20)
	assert_eq(_lit(), "012----")
	# three rooms on at once (a sprint through short rooms): R3 and R4 come
	# on, R5 too but two passages away, R0 goes off
	camera.global_position = _at(3)
	var seen: Array[String] = []
	for i in 30:
		await get_tree().process_frame
		if seen.is_empty() or seen.back() != _lit():
			seen.append(_lit())
	assert_eq(seen.back(), "-12345-", "in the end R1 .. R5")
	# the first change already had R2 .. R4 on (the entered room and its
	# neighbours: no pop), R5 (two passages) came a frame later, R0 off after
	var first := seen[1] if seen.size() > 1 else seen[0]
	assert_true(first.contains("234"), "the entered room and its neighbours at once: %s" % [seen])
	assert_false(first.contains("5"), "two passages away waits its turn: %s" % [seen])
	assert_gt(seen.size(), 2, "spread over frames: %s" % [seen])


func test_turning_back_before_the_queue_is_done_leaves_nothing_wrong() -> void:
	culler.spread_budget_usec = 0
	culler.enabled = true
	camera.global_position = _at(0)
	await physics_frames(20)
	camera.global_position = _at(4)
	await physics_frames(20)
	camera.global_position = _at(0)
	await physics_frames(20)
	assert_eq(_lit(), "012----", "back where it started")
	for i in ROOMS:
		assert_eq(motes[_room(i)].emitting, i <= 2, "dust of R%d" % i)
