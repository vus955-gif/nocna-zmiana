extends TestCase
## Exhibit perception in a greybox world (design pietro-1-projekt 7.2 and
## 12): the sight cone and the close sense, sleeping eyes, darkness and the
## flashlight, flares, hearing through open and closed doors, shots, losing
## track, the search and the way home, chain waking, the hunter cap, the
## leash and the territory, the suspicion's feedback, patrols and the
## guard's own noises. PerceptionWorld is configured per test (the runner
## resets it).

const FAST_FORWARD := 4

var target: TargetDummy
## Light of the whole world (0 dark .. 1 lit) and the doors' state, read by
## the callables handed to PerceptionWorld.
var light_level: float = 1.0
var doors_open := {}
var _ticks: int
var _max_steps: int


func before_each() -> void:
	_ticks = Engine.physics_ticks_per_second
	_max_steps = Engine.max_physics_steps_per_frame
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(160, 1, 160), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 70)   # far away, out of everyone's sight
	add_child(target)


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks
	Engine.max_physics_steps_per_frame = _max_steps
	Engine.time_scale = 1.0


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _fast_forward() -> void:
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD


## The whole world at [member light_level] (no rooms).
func _lighting() -> void:
	PerceptionWorld.configure(func(_point: Vector3) -> float: return light_level, Callable(), null, Callable())


## West (x < 0) and east rooms joined by passage "door" (open while
## doors_open says so), at [member light_level].
func _two_rooms() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"door", &"west", &"east")
	doors_open[&"door"] = true
	PerceptionWorld.configure(
		func(_point: Vector3) -> float: return light_level,
		func(point: Vector3) -> StringName: return &"west" if point.x < 0.0 else &"east",
		graph,
		func(passage: StringName) -> bool: return doors_open.get(passage, true))


## An exhibit at [param at] facing [param toward] (a point; null = -Z),
## asleep unless [param awake] (then it stands guard at its post).
func _exhibit(kind: GDScript, at: Vector3, toward: Variant = null, awake: bool = false, who: Node3D = null) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = who if who != null else target
	enemy.starts_awake = awake
	add_child(enemy)
	if toward != null:
		enemy.face(toward)
	return enemy


func _guard(at: Vector3) -> Player:
	var guard := Player.new()
	guard.position = at
	add_child(guard)
	return guard


func _hit(on: Enemy, from: Node3D) -> void:
	var info := DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC, from)
	info.direction = (on.global_position - from.global_position).normalized()
	info.position = on.global_position + Vector3.UP
	on.take_damage(info)


# --- sight -----------------------------------------------------------------------

func test_it_sees_in_front_not_behind_and_senses_close_by() -> void:
	target.position = Vector3.ZERO
	var ahead := _exhibit(WaxFigure, Vector3(0, 0, 10), Vector3.ZERO, true)
	var turned_away := _exhibit(WaxFigure, Vector3(10, 0, 0), Vector3(20, 0, 0), true)
	var close_behind := _exhibit(WaxFigure, Vector3(0, 0, -2.5), Vector3(0, 0, -10), true)
	await _seconds(0.5)
	assert_true(ahead.brain.is_alerted(), "10 m ahead: seen")
	assert_eq(turned_away.brain.state, EnemyBrain.State.PATROL, "10 m behind it: unseen")
	assert_true(close_behind.brain.is_alerted(), "2.5 m behind it: sensed")


func test_a_sleeping_exhibit_sees_less_far() -> void:
	target.position = Vector3.ZERO
	var far := _exhibit(WaxFigure, Vector3(0, 0, 15), Vector3.ZERO)
	var near := _exhibit(WaxFigure, Vector3(11, 0, 0), Vector3.ZERO)
	var awake := _exhibit(WaxFigure, Vector3(-15, 0, 0), Vector3.ZERO, true)
	await _seconds(0.5)
	assert_eq(far.brain.state, EnemyBrain.State.DORMANT, "asleep: 15 m is too far (lit: %.1f m)" % (PerceptionRules.LIT_RANGE * PerceptionRules.DORMANT_SCALE))
	assert_ne(near.brain.state, EnemyBrain.State.DORMANT, "asleep, 11 m: seen")
	assert_true(awake.brain.is_alerted(), "awake, 15 m: seen")


func test_in_the_dark_a_knight_misses_the_guard_until_his_flashlight_comes_on() -> void:
	light_level = 0.0
	_lighting()
	var guard := _guard(Vector3(0, 0.05, 0))
	var knight := _exhibit(Knight, Vector3(0, 0, -10), Vector3.ZERO, false, guard)
	await _seconds(1.5)
	assert_eq(knight.brain.state, EnemyBrain.State.DORMANT, "10 m in the dark: unseen")
	assert_true(guard.set_flashlight(true))
	await _seconds(0.6)
	assert_ne(knight.brain.state, EnemyBrain.State.DORMANT, "the flashlight gives him away")
	assert_true(knight.brain.spotted(), "seen, not just heard")


func test_half_dark_shortens_sight() -> void:
	light_level = 0.3
	_lighting()
	target.position = Vector3.ZERO
	var at_14 := _exhibit(WaxFigure, Vector3(0, 0, 14), Vector3.ZERO, true)
	var at_10 := _exhibit(WaxFigure, Vector3(10, 0, 0), Vector3.ZERO, true)
	await _seconds(0.5)
	assert_eq(at_14.brain.state, EnemyBrain.State.PATROL, "half-dark: 12 m")
	assert_true(at_10.brain.is_alerted())


func test_a_flare_by_the_guard_lights_him_up() -> void:
	light_level = 0.0
	_lighting()
	var guard := _guard(Vector3(0, 0.05, 0))
	var knight := _exhibit(Knight, Vector3(0, 0, -10), Vector3.ZERO, false, guard)
	await _seconds(1.0)
	assert_eq(knight.brain.state, EnemyBrain.State.DORMANT)
	FlareLight.stick(self, Vector3(0.6, 0.05, 0), Vector3.UP, null, load("res://src/weapons/data/flare.tres") as WeaponData, guard)
	await _seconds(0.6)
	assert_gt(PerceptionWorld.guard_light(guard), PerceptionRules.LIT_LEVEL)
	assert_ne(knight.brain.state, EnemyBrain.State.DORMANT, "seen by the flare's light")


func test_the_difficulty_scales_sight_and_the_cap() -> void:
	target.position = Vector3.ZERO
	var wax := _exhibit(WaxFigure, Vector3(0, 0, 20), Vector3.ZERO, true)
	await physics_frames(2)
	assert_almost_eq(wax.sight_reach(), 22.0, 0.01)
	PerceptionWorld.set_difficulty(0)
	assert_almost_eq(wax.sight_reach(), 22.0 * 0.75, 0.01)
	assert_eq(PerceptionWorld.hunter_cap, 8)
	PerceptionWorld.set_difficulty(2)
	assert_almost_eq(wax.sight_reach(), 22.0 * 1.15, 0.01)
	assert_eq(PerceptionWorld.hunter_cap, 10)


# --- hearing -----------------------------------------------------------------------

func test_a_noise_carries_through_an_open_door_not_a_closed_one() -> void:
	_two_rooms()
	var listener := _exhibit(WaxFigure, Vector3(8, 0, 0))
	await physics_frames(2)
	doors_open[&"door"] = false
	Events.noise_made.emit(Vector3(-2, 0, 0), 18.0, &"test")
	assert_eq(listener.brain.state, EnemyBrain.State.DORMANT, "a closed door stops it")
	doors_open[&"door"] = true
	Events.noise_made.emit(Vector3(-2, 0, 0), 18.0, &"test")
	assert_eq(listener.brain.state, EnemyBrain.State.SUSPICIOUS, "10 m through one open door (18 x 0.6 = 10.8 m)")
	assert_false(listener.brain.spotted(), "heard, not seen")
	await _seconds(1.0)
	assert_eq(listener.brain.state, EnemyBrain.State.INVESTIGATE, "it goes to look, it does not hunt")
	assert_eq(listener.brain.goal, Vector3(-2, 0, 0))


func test_the_passage_muffles_a_noise() -> void:
	_two_rooms()
	var through := _exhibit(WaxFigure, Vector3(10, 0, 0))
	var same_room := _exhibit(WaxFigure, Vector3(-14, 0, 0))
	await physics_frames(2)
	assert_eq(PerceptionWorld.noise(Vector3(-2, 0, 0), 15.0), 1, "12 m in the room hears; 12 m through the door (9 m) does not")
	assert_eq(through.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(same_room.brain.state, EnemyBrain.State.SUSPICIOUS)


func test_a_shot_is_heard_where_the_guard_stands() -> void:
	light_level = 0.0
	_lighting()
	var guard := _guard(Vector3(0, 0.05, 0))
	var listener := _exhibit(WaxFigure, Vector3(0, 0, 14), Vector3(0, 0, 30), false, guard)
	await physics_frames(2)
	Events.weapon_fired.emit(&"fists")
	assert_eq(listener.brain.state, EnemyBrain.State.DORMANT, "a punch carries 6 m")
	Events.weapon_fired.emit(&"pistol")
	assert_eq(listener.brain.state, EnemyBrain.State.SUSPICIOUS, "a pistol shot carries 18 m")
	await _seconds(1.0)
	assert_eq(listener.brain.state, EnemyBrain.State.INVESTIGATE, "in the dark it comes to look")
	assert_lt(listener.brain.goal.distance_to(guard.global_position), 0.2)


func test_a_noise_from_a_haven_carries_nowhere() -> void:
	add_child(Haven.make(&"booth", AABB(Vector3(-3, 0, -3), Vector3(6, 3, 6))))
	var listener := _exhibit(WaxFigure, Vector3(0, 0, 8))
	await physics_frames(2)
	Events.noise_made.emit(Vector3(0, 0.1, 0), 20.0, &"test")
	assert_eq(listener.brain.state, EnemyBrain.State.DORMANT)


func test_a_noise_beyond_its_bounds_only_turns_its_head() -> void:
	var listener := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	await physics_frames(2)
	Events.noise_made.emit(Vector3(0, 0, 31), 40.0, &"test")
	assert_eq(listener.brain.state, EnemyBrain.State.SUSPICIOUS)
	await _seconds(1.2)
	assert_eq(listener.brain.state, EnemyBrain.State.DORMANT, "31 m from home: past the 28 m leash")
	assert_gt(-listener.global_transform.basis.z.z, 0.8, "it turned toward the sound and keeps looking there")


# --- losing track ---------------------------------------------------------------------

func test_lost_sight_means_a_search_then_the_way_home() -> void:
	var wall := Greybox.box(self, Vector3(4, 1.5, -9), Vector3(10, 3, 0.4), Color.GRAY)   # a wall
	var wax := _exhibit(WaxFigure, Vector3.ZERO)
	var states := watch(wax.brain.state_changed)
	target.position = Vector3(-3, 0, -6)
	await _seconds(2.0)
	assert_eq(wax.brain.state, EnemyBrain.State.HUNT)
	target.position = Vector3(2, 0, -11)   # behind the wall
	wax._look()   # (the next sight check, without waiting up to 0.2 s for it)
	await _seconds(1.8)
	assert_eq(wax.brain.state, EnemyBrain.State.SEARCH, "lost him: it searches")
	assert_lt(wax.brain.last_known.distance_to(Vector3(-3, 0, -6)), EnemyBrain.EXTRAPOLATE + 0.01, "near where it last saw him")
	target.position = Vector3(0, 0, -80)   # gone for good
	# The wall did its work (it blocked his sight). There is no navmesh here,
	# so a search that ends behind it would have only the stuck sidestep to
	# find a way round: a dice roll (the search points and the sidestep's
	# side are random), lost in a few runs of a hundred. Home is a straight walk.
	wall.queue_free()
	_fast_forward()
	for i in 45 * _ticks:
		await get_tree().physics_frame
		if wax.brain.state == EnemyBrain.State.DORMANT:
			break
	var went: Array = states.map(func(change: Array) -> EnemyBrain.State: return change[1])
	assert_true(went.has(EnemyBrain.State.RETURN), "it went home")
	assert_eq(wax.brain.state, EnemyBrain.State.DORMANT, "and sleeps there")
	assert_lt(Vector2(wax.global_position.x, wax.global_position.z).length(), 1.5)


# --- chain waking ---------------------------------------------------------------------

func test_chain_waking_rouses_two_in_its_room_and_they_come_to_look() -> void:
	light_level = 0.0
	_two_rooms()
	target.position = Vector3(-6, 0, 18)
	var waker := _exhibit(WaxFigure, Vector3(-1, 0, 0))
	var neighbours: Array[Enemy] = []
	for at in [Vector3(-3, 0, 0), Vector3(-1, 0, 3), Vector3(-1, 0, -3.5), Vector3(-4.5, 0, 2.5)]:
		neighbours.append(_exhibit(WaxFigure, at))
	var next_door := _exhibit(WaxFigure, Vector3(1, 0, 0))   # the nearest, but in the east room
	await physics_frames(3)
	_hit(waker, target)
	var woken := neighbours.filter(func(e: Enemy) -> bool: return e.brain.state != EnemyBrain.State.DORMANT)
	assert_eq(woken.size(), PerceptionRules.CHAIN_MAX, "at most two")
	assert_eq(next_door.brain.state, EnemyBrain.State.DORMANT, "not through into the next room")
	for enemy: Enemy in woken:
		assert_true(enemy.brain.quiet, "woken by a neighbour: quiet")
		assert_false(enemy.brain.spotted())
	await _seconds(1.2)
	for enemy: Enemy in woken:
		assert_eq(enemy.brain.state, EnemyBrain.State.INVESTIGATE, "they come to look, they do not hunt")
	var still := neighbours.filter(func(e: Enemy) -> bool: return e.brain.state == EnemyBrain.State.DORMANT)
	assert_eq(still.size(), neighbours.size() - PerceptionRules.CHAIN_MAX, "and wake nobody else")


func test_a_noise_brings_the_suspicion_sound_not_the_call_out() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var waker := _exhibit(WaxFigure, Vector3(0, 0, -3))
	_exhibit(WaxFigure, Vector3(2, 0, -3))
	_exhibit(WaxFigure, Vector3(-2, 0, -3))
	await physics_frames(2)
	Sfx.stop_all()
	Events.noise_made.emit(Vector3(0, 0, -8), 10.0, &"test")
	var sounds := Sfx.get_children().map(func(node: Node) -> String:
		var player := node as AudioStreamPlayer3D
		return player.stream.resource_path.get_file() if player != null and player.stream != null else "")
	assert_true(sounds.has("suspicion.wav"), "a noise: the suspicion sound")
	assert_false(sounds.has("notice.wav"), "nobody saw the guard")
	assert_eq(waker.eye_glow(), 2.0, "its eyes flare")


# --- the hunter cap ----------------------------------------------------------------------

func test_at_most_eight_hunt_at_once() -> void:
	target.position = Vector3.ZERO
	var ring: Array[Enemy] = []
	for i in 12:
		var angle := TAU * i / 12.0
		ring.append(_exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * 12.0, Vector3.ZERO, true))
	var most := 0
	for frame in 3 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		most = maxi(most, PerceptionWorld.hunters_near(target.global_position))
	assert_eq(most, PerceptionRules.HUNTER_CAP, "eight hunt, never more")
	var waiting := ring.filter(func(e: Enemy) -> bool: return e.brain.state == EnemyBrain.State.INVESTIGATE)
	assert_eq(waiting.size(), 12 - PerceptionRules.HUNTER_CAP, "the rest wait")
	for enemy: Enemy in waiting:
		assert_gt(enemy.global_position.distance_to(target.global_position), 8.5, "at the edge")


func test_summoned_exhibits_ignore_the_cap() -> void:
	target.position = Vector3.ZERO
	for i in 10:
		var angle := TAU * i / 10.0
		var wax := _exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * 12.0, Vector3.ZERO)
		wax.summoned = true
		wax.brain.wake()
	await _seconds(1.5)
	assert_eq(PerceptionWorld.hunters_near(target.global_position), 10)


# --- leash and territory ---------------------------------------------------------------------

## The target walks away along +X at [param speed] for [param seconds];
## returns how far from home [param enemy] got.
func _lead_away(enemy: Enemy, speed: float, seconds: float) -> float:
	var farthest := 0.0
	var step := speed / Engine.physics_ticks_per_second
	for frame in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		target.position.x += step
		farthest = maxf(farthest, Vector2(enemy.global_position.x, enemy.global_position.z).length())
	return farthest


func test_a_hunter_lets_go_beyond_its_leash() -> void:
	target.position = Vector3(6, 0, 0)
	var wax := _exhibit(WaxFigure, Vector3.ZERO, Vector3(10, 0, 0))
	await _seconds(1.2)
	assert_eq(wax.brain.state, EnemyBrain.State.HUNT)
	_fast_forward()
	var farthest := await _lead_away(wax, 2.0, 25.0)
	assert_lt(farthest, PerceptionRules.LEASH + 1.0, "never past its leash")
	assert_gt(farthest, PerceptionRules.LEASH - 3.0, "but it did follow")
	assert_true(wax.brain.state == EnemyBrain.State.RETURN or wax.brain.state == EnemyBrain.State.DORMANT, "on its way home")


func test_a_summoned_hunter_has_no_leash() -> void:
	target.position = Vector3(6, 0, 0)
	var wax := _exhibit(WaxFigure, Vector3.ZERO, Vector3(10, 0, 0))
	wax.summoned = true
	wax.brain.wake()
	_fast_forward()
	var farthest := await _lead_away(wax, 2.0, 25.0)
	assert_gt(farthest, PerceptionRules.LEASH + 10.0)


func test_a_third_room_is_out_of_its_territory() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"ab", &"a", &"b")
	graph.add_door(&"bc", &"b", &"c")
	PerceptionWorld.configure(Callable(), func(point: Vector3) -> StringName:
		return &"a" if point.x < 8.0 else (&"b" if point.x < 16.0 else &"c"), graph, Callable())
	target.position = Vector3(6, 0, 0)
	var wax := _exhibit(WaxFigure, Vector3.ZERO, Vector3(10, 0, 0))
	assert_eq(wax.bounds_rooms(), [&"a", &"b"] as Array[StringName])
	await _seconds(1.2)
	_fast_forward()
	var farthest := await _lead_away(wax, 2.0, 16.0)
	assert_gt(farthest, 12.0, "it followed into the next room")
	assert_lt(farthest, 17.5, "it stops at the third room (x 16), short of its 28 m leash")
	assert_true(wax.brain.state == EnemyBrain.State.RETURN or wax.brain.state == EnemyBrain.State.DORMANT)


# --- feedback, patrols, the guard's noises ------------------------------------------------------

func test_a_suspicious_exhibit_turns_to_what_it_noticed() -> void:
	var wax := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10))
	await physics_frames(2)
	Events.noise_made.emit(Vector3(0, 0, 8), 12.0, &"test")
	assert_eq(wax.brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_eq(wax.eye_glow(), 2.0)
	await _seconds(0.5)
	assert_gt(-wax.global_transform.basis.z.z, 0.8, "it turned round to the sound behind it")


func test_an_awake_exhibit_patrols_its_route() -> void:
	light_level = 0.0
	_lighting()
	var wax := WaxFigure.new()
	wax.position = Vector3.ZERO
	wax.target = target
	wax.starts_awake = true
	wax.patrol_route = PackedVector3Array([Vector3.ZERO, Vector3(6, 0, 0), Vector3(6, 0, 6)])
	add_child(wax)
	var farthest := 0.0
	_fast_forward()
	for frame in 20 * _ticks:
		await get_tree().physics_frame
		farthest = maxf(farthest, wax.global_position.length())
	assert_eq(wax.brain.state, EnemyBrain.State.PATROL)
	assert_gt(farthest, 6.0, "it walked its route")


func test_sprinting_and_landing_make_noise() -> void:
	var guard := _guard(Vector3(0, 0.05, 0))
	var noises := watch(Events.noise_made)
	await physics_frames(12)   # on its feet
	guard.sprinting = true
	guard._make_noise(0.5, true, 0.0)
	assert_eq(noises.size(), 1, "a sprint step")
	if noises.size() == 1:
		assert_eq(noises[0][1], PerceptionRules.STEP_NOISE)
		assert_eq(noises[0][2], &"sprint")
	guard._make_noise(0.1, true, 0.0)
	assert_eq(noises.size(), 1, "one step every %.1f s" % Player.SPRINT_NOISE_INTERVAL)
	guard.sprinting = false
	guard._make_noise(0.1, false, 6.0)
	assert_eq(noises.size(), 2, "a landing")
	if noises.size() == 2:
		assert_eq(noises[1][2], &"landing")
