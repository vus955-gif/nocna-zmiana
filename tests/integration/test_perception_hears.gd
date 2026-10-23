extends TestCase
## PerceptionWorld.hears(): the same question noise() asks of each listener -
## does this noise reach this exhibit? - answered for one exhibit (the
## biome bells use it to call their guardians the way noise carries).

var target: Node3D


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 40), Color.GRAY)
	target = Node3D.new()
	target.add_to_group(&"player")
	add_child(target)


func after_each() -> void:
	GameInput.capture_allowed = true


func _exhibit(at: Vector3) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.target = target
	wax.position = at
	add_child(wax)
	return wax


## Rooms "a" (x < 10), "b" (10..20) and "c" (from 20), joined a-b and b-c;
## the door b-c is open while [param far_door] says so.
func _rooms(far_door: bool) -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"ab", &"a", &"b")
	graph.add_door(&"bc", &"b", &"c")
	PerceptionWorld.configure(Callable(), func(point: Vector3) -> StringName:
		return &"a" if point.x < 10.0 else (&"b" if point.x < 20.0 else &"c"),
		graph, func(door: StringName) -> bool: return far_door or door != &"bc")


func test_without_rooms_it_is_the_plain_distance() -> void:
	var near := _exhibit(Vector3(10, 0.05, 0))
	var far := _exhibit(Vector3(30, 0.05, 0))
	await physics_frames(2)
	assert_true(PerceptionWorld.hears(near, Vector3.ZERO, 12.0))
	assert_false(PerceptionWorld.hears(far, Vector3.ZERO, 12.0))
	assert_false(PerceptionWorld.hears(near, Vector3.ZERO, 0.0), "a noise of no radius is no noise")


func test_through_open_passages_the_noise_is_damped_and_a_shut_door_stops_it() -> void:
	_rooms(false)
	var here := _exhibit(Vector3(5, 0.05, 0))
	var next := _exhibit(Vector3(14, 0.05, 0))
	var behind := _exhibit(Vector3(22, 0.05, 0))
	await physics_frames(2)
	assert_true(PerceptionWorld.hears(here, Vector3.ZERO, 10.0), "in the room: full strength")
	assert_true(PerceptionWorld.hears(next, Vector3.ZERO, 26.0), "one passage: 14 m is within 26 x the damping")
	assert_false(PerceptionWorld.hears(next, Vector3.ZERO, 20.0), "but not within 20 x the damping")
	assert_false(PerceptionWorld.hears(behind, Vector3.ZERO, 40.0), "the shut door b-c keeps the third room out")
	_rooms(true)
	var behind_again := _exhibit(Vector3(22, 0.05, 1))
	await physics_frames(2)
	assert_true(PerceptionWorld.hears(behind_again, Vector3.ZERO, 80.0), "with the door open it is heard (two passages, damped)")


func test_nobody_it_does_not_reach_is_woken_by_the_noise_itself() -> void:
	_rooms(false)
	for radius in [12.0, 20.0, 26.0, 40.0]:
		var next := _exhibit(Vector3(14, 0.05, 0))
		var behind := _exhibit(Vector3(22, 0.05, 0))
		await physics_frames(2)
		var next_hears := PerceptionWorld.hears(next, Vector3.ZERO, radius)
		var behind_hears := PerceptionWorld.hears(behind, Vector3.ZERO, radius)
		PerceptionWorld.noise(Vector3.ZERO, radius, &"bell")
		if not next_hears:
			assert_eq(next.brain.state, EnemyBrain.State.DORMANT, "radius %s: a noise that did not reach the next room left it asleep" % radius)
		if not behind_hears:
			assert_eq(behind.brain.state, EnemyBrain.State.DORMANT, "radius %s: nor the room behind the shut door" % radius)
		next.queue_free()
		behind.queue_free()
		await physics_frames(2)
