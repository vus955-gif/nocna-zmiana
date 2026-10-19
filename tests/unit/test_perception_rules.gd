extends TestCase
## PerceptionRules: the pure geometry and numbers of exhibit perception
## (design: pietro-1-projekt 7.2).


func test_light_bands_give_the_three_ranges() -> void:
	assert_eq(PerceptionRules.sight_range(1.0), 22.0)
	assert_eq(PerceptionRules.sight_range(0.3), 12.0)
	assert_eq(PerceptionRules.sight_range(0.05), 7.0)
	assert_almost_eq(PerceptionRules.sight_range(0.3, 16.0), 16.0 * 12.0 / 22.0, 0.001, "an exhibit's own lit range scales the bands")


func test_the_band_edges() -> void:
	assert_eq(PerceptionRules.sight_range(PerceptionRules.LIT_LEVEL), 22.0)
	assert_eq(PerceptionRules.sight_range(PerceptionRules.LIT_LEVEL - 0.01), 12.0)
	assert_eq(PerceptionRules.sight_range(PerceptionRules.DIM_LEVEL), 12.0)
	assert_eq(PerceptionRules.sight_range(PerceptionRules.DIM_LEVEL - 0.01), 7.0)


func test_the_cone_is_120_degrees_in_front() -> void:
	var ahead := Vector3.FORWARD
	assert_true(PerceptionRules.in_cone(ahead, Vector3(0, 0, -5), 120.0))
	assert_true(PerceptionRules.in_cone(ahead, Vector3(4, 0, -3), 120.0), "53 degrees off")
	assert_false(PerceptionRules.in_cone(ahead, Vector3(5, 0, -2), 120.0), "68 degrees off")
	assert_true(PerceptionRules.in_cone(ahead, Vector3(5, 0, -2), 160.0), "a bust's wide cone")
	assert_false(PerceptionRules.in_cone(ahead, Vector3(0, 0, 5), 120.0), "behind")
	assert_true(PerceptionRules.in_cone(ahead, Vector3(0, 3, -1), 120.0), "height does not count, only the floor plan")


func test_seeing_combines_range_cone_and_the_close_sense() -> void:
	var ahead := Vector3.FORWARD
	assert_true(PerceptionRules.sees(ahead, Vector3(0, 0, -10), 120.0, 12.0, 3.5))
	assert_false(PerceptionRules.sees(ahead, Vector3(0, 0, -13), 120.0, 12.0, 3.5), "out of range")
	assert_false(PerceptionRules.sees(ahead, Vector3(0, 0, 8), 120.0, 12.0, 3.5), "behind")
	assert_true(PerceptionRules.sees(ahead, Vector3(0, 0, 3), 120.0, 12.0, 3.5), "behind, but close enough to sense")
	assert_false(PerceptionRules.sees(ahead, Vector3(0, 0, 3), 120.0, 2.0, 3.5), "the close sense never reaches past the range")


func test_weapon_noise_radii() -> void:
	assert_eq(PerceptionRules.weapon_noise(&"fists"), 6.0)
	assert_eq(PerceptionRules.weapon_noise(&"taser"), 6.0)
	assert_eq(PerceptionRules.weapon_noise(&"pistol"), 18.0)
	assert_eq(PerceptionRules.weapon_noise(&"rifle_hunt"), 24.0)
	assert_eq(PerceptionRules.weapon_noise(&"shotgun"), 22.0)
	assert_eq(PerceptionRules.weapon_noise(&"harpoon"), 12.0)
	assert_eq(PerceptionRules.weapon_noise(&"gatling"), 30.0)
	assert_eq(PerceptionRules.weapon_noise(&"hwacha"), 30.0)
	assert_eq(PerceptionRules.weapon_noise(&"flare"), 15.0)
	assert_eq(PerceptionRules.weapon_noise(&"unknown_gun"), PerceptionRules.DEFAULT_WEAPON_NOISE)


## Review 19.10: the flare's little burst was heard 30 m round like a rocket's.
func test_a_blast_is_heard_as_far_as_it_is_loud() -> void:
	assert_eq(PerceptionRules.blast_noise(&"flare"), 15.0, "a flare's burst is small")
	assert_eq(PerceptionRules.blast_noise(&"hwacha"), 30.0)
	assert_eq(PerceptionRules.blast_noise(&""), PerceptionRules.BLAST_NOISE, "any other explosion: the big bang")
	assert_eq(PerceptionRules.BLAST_NOISE, 30.0)
	assert_eq(PerceptionRules.blast_noise(&"flare"), PerceptionRules.weapon_noise(&"flare"), "no louder than the shot that fired it")


func test_noise_carries_through_open_passages_only() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"d1", &"a", &"b")
	graph.add_door(&"d2", &"b", &"c")
	var open := func(_door: StringName) -> bool: return true
	var rooms := PerceptionRules.hearing_rooms(graph, &"a", open)
	assert_eq(rooms[&"a"], 1.0)
	assert_almost_eq(rooms[&"b"], 0.6, 0.0001)
	assert_almost_eq(rooms[&"c"], 0.36, 0.0001)
	var shut := func(door: StringName) -> bool: return door != &"d2"
	assert_false(PerceptionRules.hearing_rooms(graph, &"a", shut).has(&"c"), "a closed door blocks")
	assert_true(PerceptionRules.hearing_rooms(graph, &"a", shut).has(&"b"))


func test_noise_takes_the_shortest_way_and_fades_out() -> void:
	var graph := RoomGraph.new()
	for i in 6:
		graph.add_door(StringName("d%d" % i), StringName("r%d" % i), StringName("r%d" % (i + 1)))
	graph.add_door(&"short", &"r0", &"r2")
	var rooms := PerceptionRules.hearing_rooms(graph, &"r0", Callable())
	assert_almost_eq(rooms[&"r2"], 0.6, 0.0001, "through the short way")
	assert_false(rooms.has(&"r6"), "too many passages: nothing carries")


func test_a_noise_is_heard_within_its_damped_radius() -> void:
	assert_true(PerceptionRules.heard(10.0, 18.0, 0.6))
	assert_false(PerceptionRules.heard(11.0, 18.0, 0.6))
	assert_false(PerceptionRules.heard(1.0, 18.0, 0.0), "no way through")


func test_territory_is_home_and_open_neighbours() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"d1", &"hall", &"gallery", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"d2", &"hall", &"diorama")
	graph.add_door(&"p", &"gallery", &"secret", RoomGraph.Kind.SECRET)
	graph.add_door(&"g", &"gallery", &"crypt", RoomGraph.Kind.GATE)
	var rooms := PerceptionRules.territory(graph, &"gallery")
	assert_true(rooms.has(&"gallery") and rooms.has(&"hall"))
	assert_false(rooms.has(&"diorama"), "a third room is outside")
	assert_false(rooms.has(&"secret"), "never through a false panel")
	assert_false(rooms.has(&"crypt"), "never through a gate")
	assert_eq(PerceptionRules.territory(null, &"hall"), [&"hall"] as Array[StringName])
	assert_true(PerceptionRules.territory(graph, &"").is_empty(), "no home room: no rooms")


func test_leash_and_rooms() -> void:
	var home := Vector3.ZERO
	var rooms: Array[StringName] = [&"a", &"b"]
	assert_false(PerceptionRules.out_of_bounds(Vector3(20, 0, 0), home, 28.0, &"b", rooms))
	assert_true(PerceptionRules.out_of_bounds(Vector3(29, 0, 0), home, 28.0, &"b", rooms))
	assert_false(PerceptionRules.out_of_bounds(Vector3(20, 9, 0), home, 28.0, &"b", rooms), "the leash is measured on the floor plan")
	assert_true(PerceptionRules.out_of_bounds(Vector3(5, 0, 0), home, 28.0, &"c", rooms), "a third room")
	assert_false(PerceptionRules.out_of_bounds(Vector3(5, 0, 0), home, 28.0, &"", rooms), "unknown room: the distance decides")
	assert_false(PerceptionRules.out_of_bounds(Vector3(5, 0, 0), home, 28.0, &"c", [] as Array[StringName]), "no territory: the distance decides")
	assert_false(PerceptionRules.out_of_bounds(Vector3(500, 0, 0), home, INF, &"a", rooms), "no leash")


func test_patrol_route_stays_in_the_home_room() -> void:
	var room_of := func(point: Vector3) -> StringName: return &"hall" if absf(point.x) < 10.0 and absf(point.z) < 4.0 else &"other"
	var route := PerceptionRules.patrol_route(Vector3.ZERO, &"hall", room_of)
	assert_gt(route.size(), 1)
	assert_eq(route[0], Vector3.ZERO, "it starts at its post")
	for point in route:
		assert_eq(room_of.call(point), &"hall")
	assert_eq(PerceptionRules.patrol_route(Vector3.ZERO, &"hall", room_of), route, "the same post, the same route")


func test_no_rooms_no_route() -> void:
	assert_true(PerceptionRules.patrol_route(Vector3.ZERO, &"", Callable()).is_empty())
	var nowhere := func(_point: Vector3) -> StringName: return &"elsewhere"
	assert_true(PerceptionRules.patrol_route(Vector3.ZERO, &"hall", nowhere).is_empty())
