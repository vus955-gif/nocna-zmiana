extends TestCase
## Asia's temple bells (plan 2026-10-21-mechaniki-biomow, mechanic 5) in a
## sandbox: a shot (or a pull on its rope) rings a hanging bell; the ring
## is a loud noise at the bell, the bronze Fu dogs within earshot always
## come to it, whoever is awake under it reels for a moment, it hums a while
## before it rings again, and dawn silences it.

const HANG := Vector3(0.0, 5.0, 0.0)

var host: BiomeMechanics
var bell: TempleBell
var player: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 14)
	add_child(player)
	host = BiomeMechanics.new()
	host.guard_source = func() -> Player: return player
	add_child(host)
	bell = TempleBell.create({"hang": HANG, "scale": 0.6, "ceiling": 8.0, "floor": 0.0})
	host.adopt(bell, &"asia_test_bell", &"")
	await physics_frames(3)


func after_each() -> void:
	GameInput.capture_allowed = true


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _shot() -> void:
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, player)
	info.weapon = &"pistol"
	info.position = bell.center()
	info.direction = Vector3(0, 0, -1)
	bell.take_damage(info)


func test_a_shot_rings_it_and_the_ring_is_a_loud_noise_at_the_bell() -> void:
	var noises := watch(Events.noise_made)
	_shot()
	assert_eq(bell.rings, 1)
	var heard := noises.filter(func(args: Array) -> bool: return args[2] == TempleBell.NOISE_SOURCE)
	assert_eq(heard.size(), 1)
	if heard.size() == 1:
		assert_lt((heard[0][0] as Vector3).distance_to(bell.center()), 0.5, "the noise is the bell's, not the guard's")
		assert_almost_eq(float(heard[0][1]), TempleBell.LURE_RADIUS, 0.01)
	assert_gt(TempleBell.LURE_RADIUS, 20.0, "it carries through the hall")


func test_the_fu_dogs_within_earshot_come_to_it() -> void:
	var dog := FuDog.new()
	dog.target = player
	dog.position = Vector3(12, 0.05, -6)
	add_child(dog)
	await physics_frames(5)
	assert_eq(dog.brain.state, EnemyBrain.State.DORMANT)
	_shot()
	await physics_frames(2)
	assert_ne(dog.brain.state, EnemyBrain.State.DORMANT, "the temple's bell calls its guardian")
	assert_lt(Vector2(dog.brain.last_known.x, dog.brain.last_known.z).distance_to(Vector2(HANG.x, HANG.z)), 1.0, "to the bell, not to the guard")


## Rooms along x: the bell's hall "a" (x < 8), "b" (8..16), "c" (16..24) and
## "d" (from 24), joined a-b, b-c and c-d; the door c-d stands shut.
func _rooms() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"ab", &"a", &"b")
	graph.add_door(&"bc", &"b", &"c")
	graph.add_door(&"cd", &"c", &"d")
	PerceptionWorld.configure(Callable(), func(point: Vector3) -> StringName:
		return &"a" if point.x < 8.0 else (&"b" if point.x < 16.0 else (&"c" if point.x < 24.0 else &"d")),
		graph, func(door: StringName) -> bool: return door != &"cd")


func _dog(at: Vector3) -> FuDog:
	var dog := FuDog.new()
	dog.target = player
	dog.position = at
	add_child(dog)
	return dog


func test_only_the_dogs_that_hear_it_as_any_noise_would_carry_come() -> void:
	_rooms()
	var next_door := _dog(Vector3(12, 0.05, 0))   # b, one door off: 12 m is within 26 x 0.6
	var two_rooms := _dog(Vector3(20, 0.05, 0))   # c, two doors off: 20 m is beyond 26 x 0.36
	var shut_off := _dog(Vector3(25, 0.05, 0))    # d, 25 m in a straight line but behind a shut door
	await physics_frames(5)
	for dog in [next_door, two_rooms, shut_off]:
		assert_eq(dog.brain.state, EnemyBrain.State.DORMANT)
	_shot()
	await physics_frames(2)
	assert_ne(next_door.brain.state, EnemyBrain.State.DORMANT, "heard through the door: it comes to its bell")
	assert_eq(two_rooms.brain.state, EnemyBrain.State.DORMANT, "two rooms away the ring is too faint")
	assert_eq(shut_off.brain.state, EnemyBrain.State.DORMANT, "a shut door keeps it out, whatever the straight-line distance")


func test_whoever_is_awake_under_it_reels_and_the_others_do_not() -> void:
	var under := WaxFigure.new()
	under.target = player
	under.position = Vector3(1.5, 0.05, 1.0)
	add_child(under)
	var away := WaxFigure.new()
	away.target = player
	away.position = Vector3(TempleBell.RESONANCE + 2.0, 0.05, 0)
	add_child(away)
	await physics_frames(3)
	under.brain.alarm(player.global_position)
	away.brain.alarm(player.global_position)
	await physics_frames(2)
	_shot()
	assert_true(under.brain.is_stunned(), "the bronze's ring shakes the one beneath it")
	assert_false(away.brain.is_stunned(), "out of its reach")
	assert_gt(TempleBell.DAZE, 1.0)


func test_a_sleeper_or_a_calm_walker_under_it_is_not_dazed_awake() -> void:
	var sleeper := WaxFigure.new()
	sleeper.target = player
	sleeper.position = Vector3(1.0, 0.05, 1.0)
	add_child(sleeper)
	var walker := WaxFigure.new()
	walker.target = player
	walker.position = Vector3(-1.5, 0.05, 1.0)
	add_child(walker)
	await physics_frames(3)
	walker.brain.start_patrol()
	walker.set_physics_process(false)
	sleeper.set_physics_process(false)
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(walker.brain.state, EnemyBrain.State.PATROL)
	_shot()
	assert_false(sleeper.brain.is_stunned(), "a dazed sleeper would wake up hunting")
	assert_false(walker.brain.is_stunned(), "so would one on its calm round: the ring only shakes the awake")
	assert_ne(sleeper.brain.state, EnemyBrain.State.HUNT)
	assert_ne(walker.brain.state, EnemyBrain.State.HUNT)


func test_one_the_ring_itself_woke_is_not_dazed_by_it() -> void:
	var near := WaxFigure.new()
	near.target = player
	near.position = Vector3(0.5, 0.05, 1.0)
	add_child(near)
	await physics_frames(3)
	near.set_physics_process(false)
	_shot()
	await physics_frames(2)
	assert_false(near.brain.is_stunned(), "the ring is what woke it, not what dazes it")


func test_it_hums_before_it_rings_again() -> void:
	_shot()
	_shot()
	assert_eq(bell.rings, 1, "still swinging: a dull knock")
	await _seconds(TempleBell.REARM + 0.2)
	_shot()
	assert_eq(bell.rings, 2)


func test_a_pull_on_its_rope_rings_it() -> void:
	assert_not_null(bell.rope)
	assert_true(bell.rope.can_interact(player))
	bell.rope.interact(player)
	assert_eq(bell.rings, 1)
	assert_false(bell.rope.prompt().is_empty())


func test_dawn_silences_it() -> void:
	host.freeze()
	_shot()
	bell.rope.interact(player)
	assert_eq(bell.rings, 0)
