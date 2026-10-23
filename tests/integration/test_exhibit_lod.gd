extends TestCase
## Far from the guard (plan 2026-10-21-wydajnosc-cpu): an exhibit awake on
## its calm business in a room more than PerceptionWorld.ROUTINE_HOPS
## passages from the guard's is ticked every Enemy.LOD_FRAMES frames with the
## time since its last tick - it walks its round as ever, at a fraction of
## the cost; near him, or in a world without rooms, every frame. A row of
## rooms a .. e along +Z, 10 m each; the guard in a.

const ROOMS: Array[StringName] = [&"a", &"b", &"c", &"d", &"e"]

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 25), Vector3(60, 1, 70), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 2)
	target.rotation.y = PI   # looking along +Z, down the row
	add_child(target)


func after_each() -> void:
	Enemy.doze_enabled = true


func _rooms() -> void:
	var graph := RoomGraph.new()
	for i in ROOMS.size() - 1:
		graph.add_door(StringName("%s%s" % [ROOMS[i], ROOMS[i + 1]]), ROOMS[i], ROOMS[i + 1])
	PerceptionWorld.configure(Callable(), func(point: Vector3) -> StringName:
		return ROOMS[clampi(floori(point.z / 10.0), 0, ROOMS.size() - 1)], graph, Callable())


## A wax figure awake on a round of three points in the room at
## [param z]: how it walked, frame by frame (state, place).
func _round(dozing: bool, z: float, frames: int, rooms: bool = true) -> Dictionary:
	await get_tree().process_frame
	Enemy.doze_enabled = dozing
	PerceptionWorld.reset()
	if rooms:
		_rooms()
	seed(99)
	var figure := WaxFigure.new()
	figure.position = Vector3(-4, 0, z)
	figure.target = target
	figure.starts_awake = true
	figure.patrol_route = PackedVector3Array([Vector3(-4, 0, z), Vector3(4, 0, z), Vector3(4, 0, z + 4)])
	figure.brain.rng.seed = 5
	add_child(figure)
	var states: Array[int] = []
	var places: Array[Vector3] = []
	var lod_frames := 0
	for frame in frames:
		await get_tree().physics_frame
		states.append(figure.brain.state)
		places.append(figure.global_position)
		if figure.dozing():
			lod_frames += 1
	var out := {"states": states, "places": places, "lod_frames": lod_frames, "doze_ticks": figure.doze_ticks}
	figure.queue_free()
	await get_tree().physics_frame
	return out


func test_far_from_the_guard_a_patrol_is_ticked_a_few_times_a_second() -> void:
	var run := await _round(true, 45.0, 240)   # room e: four passages off
	assert_gt(run["lod_frames"], 200, "it leaves the per-frame step (%d of 240 frames)" % run["lod_frames"])
	var per_second: float = run["doze_ticks"] / 4.0
	assert_lt(per_second, 60.0 / Enemy.LOD_FRAMES + 2.0, "ticked %.1f times a second" % per_second)
	assert_gt(per_second, 60.0 / Enemy.LOD_FRAMES - 3.0, "but still ticked (%.1f)" % per_second)


func test_far_from_the_guard_it_walks_its_round_as_ever() -> void:
	var ticked := await _round(false, 45.0, 600)
	var lod := await _round(true, 45.0, 600)
	assert_eq(ticked["lod_frames"], 0)
	var states_a: Array = ticked["states"]
	var states_b: Array = lod["states"]
	var places_a: Array = ticked["places"]
	var places_b: Array = lod["places"]
	var differ := 0
	var worst := 0.0
	for frame in 600:
		if states_a[frame] != states_b[frame]:
			differ += 1
		worst = maxf(worst, (places_a[frame] as Vector3).distance_to(places_b[frame]))
	assert_lt(differ, 4 * Enemy.LOD_FRAMES + 1, "the same states but for a frame or three at a change (%d frames differ)" % differ)
	assert_lt(worst, 0.2, "never more than a step apart (%.3f m)" % worst)
	var end_a: Vector3 = places_a[599]
	var end_b: Vector3 = places_b[599]
	assert_lt(end_a.distance_to(end_b), 0.12, "and where it ends up: %s / %s" % [end_a, end_b])


func test_near_the_guard_every_frame() -> void:
	var near := await _round(true, 15.0, 120)   # room b: next door
	assert_eq(near["lod_frames"], 0, "within %d passages it is ticked every frame" % PerceptionWorld.ROUTINE_HOPS)
	var roomless := await _round(true, 45.0, 120, false)
	assert_eq(roomless["lod_frames"], 0, "without rooms (an arena) never")


func test_the_guard_walking_up_brings_it_back_to_every_frame() -> void:
	await get_tree().process_frame
	_rooms()
	var figure := WaxFigure.new()
	figure.position = Vector3(-4, 0, 45)
	figure.target = target
	figure.starts_awake = true
	figure.patrol_route = PackedVector3Array([Vector3(-4, 0, 45), Vector3(4, 0, 45)])
	add_child(figure)
	await physics_frames(30)
	assert_true(figure.dozing(), "far: a few ticks a second")
	target.position = Vector3(0, 0, 32)   # room d, next door
	await physics_frames(Enemy.LOD_FRAMES + 2)
	assert_false(figure.dozing(), "the guard next door: every frame again")
	assert_true(figure.is_physics_processing())


func test_far_patrols_awake_together_are_ticked_on_different_frames() -> void:
	await get_tree().process_frame
	_rooms()
	var figures: Array[Enemy] = []
	for i in 8:
		var figure := WaxFigure.new()
		figure.position = Vector3(-14 + i * 4, 0, 45)
		figure.target = target
		figure.starts_awake = true
		figure.patrol_route = PackedVector3Array([figure.position, figure.position + Vector3(0, 0, 3)])
		add_child(figure)
		figures.append(figure)
	await physics_frames(30)
	var busiest := 0
	var ticks := 0
	var last := 0
	for figure in figures:
		last += figure.doze_ticks
	for frame in 120:
		await get_tree().physics_frame
		var now := 0
		for figure in figures:
			now += figure.doze_ticks
		busiest = maxi(busiest, now - last)
		ticks += now - last
		last = now
	assert_gt(ticks, 8 * 120 / Enemy.LOD_FRAMES - 16, "all of them ticked (%d ticks)" % ticks)
	assert_lt(busiest, 8 / Enemy.LOD_FRAMES + 2, "a share of them a frame, not all eight on one (%d at most)" % busiest)


func test_a_noise_reaches_a_far_patrol_at_once() -> void:
	await get_tree().process_frame
	_rooms()
	var figure := WaxFigure.new()
	figure.position = Vector3(-4, 0, 45)
	figure.target = target
	figure.starts_awake = true
	figure.patrol_route = PackedVector3Array([Vector3(-4, 0, 45), Vector3(4, 0, 45)])
	add_child(figure)
	await physics_frames(30)
	assert_true(figure.dozing())
	figure.hear(Vector3(0, 0, 44), &"e")
	assert_eq(figure.brain.state, EnemyBrain.State.SUSPICIOUS, "it turns to the noise in the same frame")
	assert_false(figure.dozing())


func test_the_phases_count_again_with_every_level() -> void:
	PerceptionWorld.reset()   # a level's perception set up (or dropped): the count starts again
	var first := WaxFigure.new()
	add_child(first)
	var second := WaxFigure.new()
	add_child(second)
	PerceptionWorld.reset()
	var again := WaxFigure.new()
	add_child(again)
	assert_eq(first._lod_phase, 0)
	assert_eq(second._lod_phase, 1)
	assert_eq(again._lod_phase, 0, "the same night built again: the same phases in the same order")
	for figure in [first, second, again]:
		figure.free()
