extends TestCase
## Occlusion as numbers (plan 2026-10-21-akustyka-ambient): passages between
## rooms (AcousticGraph) and what a line of sight and the passages make of a
## positional sound (Acoustics.walls_for: 0 clear, 1 obstructed, 2 occluded).


## a - b - c - d in a row (openings), e up the stairs from d, a balcony
## inside a, an island room nobody reaches.
func _layout() -> LevelLayout:
	var layout := LevelLayout.new()
	for i in 5:
		var id := StringName("abcde"[i])
		layout.add_room(id, [Rect2(i * 10.0, 0.0, 10.0, 10.0)] as Array[Rect2], 0.0 if i < 4 else 4.0, 4.0 if i < 4 else 8.0, Color.WHITE)
	layout.add_opening(&"ab", Rect2(9.5, 4.0, 1.0, 2.0), 0.0, 2.5, &"a", &"b")
	layout.add_opening(&"bc", Rect2(19.5, 4.0, 1.0, 2.0), 0.0, 2.5, &"b", &"c")
	layout.add_opening(&"cd", Rect2(29.5, 4.0, 1.0, 2.0), 0.0, 2.5, &"c", &"d")
	layout.add_stairs(&"de", Rect2(36.0, 2.0, 3.0, 6.0), 0.0, 4.0, Vector2(1, 0), &"d", &"e")
	var balcony := layout.add_room(&"balcony", [Rect2(1.0, 1.0, 3.0, 8.0)] as Array[Rect2], 2.0, 4.0, Color.WHITE)
	balcony.carved = false
	layout.add_room(&"island", [Rect2(100.0, 0.0, 5.0, 5.0)] as Array[Rect2], 0.0, 3.0, Color.WHITE)
	return layout


func test_passages_between_rooms() -> void:
	var graph := AcousticGraph.from_layout(_layout())
	assert_eq(graph.hops(&"a", &"a"), 0)
	assert_eq(graph.hops(&"a", &"b"), 1)
	assert_eq(graph.hops(&"a", &"c"), 2)
	assert_eq(graph.hops(&"c", &"a"), 2, "both ways")
	assert_eq(graph.hops(&"a", &"d"), 3)
	assert_eq(graph.hops(&"c", &"e"), 2, "up the stairs too")
	assert_eq(graph.hops(&"a", &"e"), AcousticGraph.FAR, "farther than the walk goes")
	assert_eq(graph.hops(&"a", &"island"), AcousticGraph.FAR)
	assert_eq(graph.hops(&"a", &"nowhere"), AcousticGraph.FAR)


func test_a_balcony_is_its_hall() -> void:
	var graph := AcousticGraph.from_layout(_layout())
	assert_eq(graph.hops(&"balcony", &"a"), 0, "a room inside another is the same space")
	assert_eq(graph.hops(&"balcony", &"b"), 1)
	assert_eq(graph.neighbours(&"a"), [&"b"] as Array[StringName])
	assert_eq(graph.neighbours(&"c"), [&"b", &"d"] as Array[StringName])


func test_walls_from_hops_and_the_line_of_sight() -> void:
	assert_eq(Acoustics.walls_for(0, false), 0, "the same room: no occlusion behind a pillar")
	assert_eq(Acoustics.walls_for(1, true), 0, "seen through the doorway")
	assert_eq(Acoustics.walls_for(1, false), 1, "next door, round the corner: obstructed")
	assert_eq(Acoustics.walls_for(2, false), 2, "two rooms away: occluded")
	assert_eq(Acoustics.walls_for(AcousticGraph.FAR, false), 2)
	assert_eq(Acoustics.walls_for(5, true), 0, "a long line of open doors")
	assert_eq(Acoustics.walls_for(-1, false), 1, "no rooms known: only the ray decides")
	assert_eq(Acoustics.walls_for(-1, true), 0)


func test_each_level_of_occlusion_has_its_bus() -> void:
	assert_true(Acoustics.occlusion_level(0).is_empty(), "nothing in the way")
	assert_eq(StringName(Acoustics.occlusion_level(1)["bus"]), &"SFXObstructed")
	assert_eq(StringName(Acoustics.occlusion_level(2)["bus"]), &"SFXOccluded")
	assert_eq(StringName(Acoustics.occlusion_level(7)["bus"]), &"SFXOccluded", "more walls: the last level")
	assert_true(bool(Acoustics.occlusion_level(1)["keep_room"]), "obstructed: the source's room still rings")
	assert_false(bool(Acoustics.occlusion_level(2)["keep_room"]), "occluded: its room's reverb is lost too")


func test_a_floor_one_graph_reaches_every_room() -> void:
	var layout := Floor1Layout.create()
	var graph := AcousticGraph.from_layout(layout)
	assert_eq(graph.hops(&"court", &"court_balcony"), 0, "the court's balcony")
	assert_eq(graph.hops(&"entrance_hall", &"entrance_gallery"), 0)
	assert_eq(graph.hops(&"basement_boiler", &"basement_boiler_catwalk"), 0)
	var reached := 0
	for room in layout.rooms:
		if not graph.neighbours(room.id).is_empty() or graph.hops(room.id, &"court") < AcousticGraph.FAR:
			reached += 1
	assert_eq(reached, layout.rooms.size(), "no room of Floor I is cut off")
