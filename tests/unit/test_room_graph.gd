extends TestCase

var graph: RoomGraph


## hall - west - south - east - hall (a loop), plus a hidden room off the
## west wing and a gate off the hall.
func before_each() -> void:
	graph = RoomGraph.new()
	graph.add_door(&"hw", &"hall", &"west", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"ws", &"west", &"south", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"se", &"south", &"east", RoomGraph.Kind.OPEN)
	graph.add_door(&"eh", &"east", &"hall", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"panel", &"west", &"hidden", RoomGraph.Kind.SECRET)
	graph.add_door(&"grate", &"hall", &"crypt", RoomGraph.Kind.GATE)
	graph.add_room(&"island")


func test_the_loop_reaches_every_open_room() -> void:
	var seen := graph.reachable(&"south")
	for room in [&"hall", &"west", &"south", &"east"]:
		assert_true(seen.has(room), str(room))
	assert_false(seen.has(&"hidden"), "false panels are shut by default")
	assert_false(seen.has(&"crypt"), "the gate is shut by default")
	assert_false(seen.has(&"island"))


func test_one_closed_door_in_a_loop_cuts_nothing_off() -> void:
	for door in [&"hw", &"ws", &"eh"]:
		var seen := graph.reachable(&"south", [door] as Array[StringName])
		assert_eq(seen.size(), 4, "closing %s" % door)


func test_two_closed_doors_can_cut_a_room_off() -> void:
	assert_false(graph.connected(&"south", &"west", [&"hw", &"ws"] as Array[StringName]))
	assert_true(graph.connected(&"south", &"hall", [&"hw", &"ws"] as Array[StringName]))


func test_secret_and_gate_doors_open_when_listed() -> void:
	assert_true(graph.connected(&"hall", &"hidden", [], [&"panel"] as Array[StringName]))
	assert_true(graph.connected(&"hall", &"crypt", [], [&"grate"] as Array[StringName]))
	assert_false(graph.connected(&"hall", &"hidden", [&"panel"] as Array[StringName], [&"panel"] as Array[StringName]), "closed wins")


func test_unknown_start_reaches_nothing() -> void:
	assert_eq(graph.reachable(&"nowhere").size(), 0)


func test_door_queries() -> void:
	assert_eq(graph.doors_of_kind(RoomGraph.Kind.LOCKABLE), [&"hw", &"ws", &"eh"] as Array[StringName])
	assert_eq(graph.door_rooms(&"se"), [&"south", &"east"] as Array[StringName])
	assert_eq(graph.door_rooms(&"nope"), [] as Array[StringName])
	assert_true(graph.has_room(&"island"))
	assert_eq(graph.rooms().size(), 7)


func test_route_takes_the_fewest_doors_and_goes_round_a_closed_one() -> void:
	assert_eq(graph.route(&"west", &"east"), [&"hw", &"eh"] as Array[StringName], "through the hall")
	assert_eq(graph.route(&"west", &"east", [&"hw"] as Array[StringName]), [&"ws", &"se"] as Array[StringName], "round the loop")
	assert_eq(graph.route(&"hall", &"hidden"), [] as Array[StringName], "the panel is shut")
	assert_eq(graph.route(&"hall", &"hidden", [], [&"panel"] as Array[StringName]), [&"hw", &"panel"] as Array[StringName])
	assert_eq(graph.route(&"hall", &"hall"), [] as Array[StringName])
	assert_eq(graph.route(&"hall", &"island"), [] as Array[StringName])
