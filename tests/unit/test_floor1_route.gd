extends TestCase
## Floor1Route (W7): the play orders, the steps' targets and the time
## model of the walking bot.


func test_the_hud_order_finishes_the_floor() -> void:
	var order := Floor1Route.hud_order()
	assert_eq(order.size(), ProgressRules.step_ids().size(), "every step once")
	assert_eq(order[0], &"pistol_key", "the till key first")
	assert_eq(order[order.size() - 1], ProgressRules.DESCEND, "down into the dark last")
	assert_true(Floor1Route.is_valid(order))
	var unique := {}
	for step in order:
		unique[step] = true
	assert_eq(unique.size(), order.size())
	var shuffled := order.duplicate()
	shuffled.reverse()
	assert_false(Floor1Route.is_valid(shuffled), "the end first is no play-through")


func test_random_orders_are_seeded_and_always_valid() -> void:
	assert_eq(Floor1Route.random_order(7), Floor1Route.random_order(7), "the same seed, the same order")
	var distinct := {}
	for seed_value in 12:
		var order := Floor1Route.random_order(seed_value)
		assert_true(Floor1Route.is_valid(order), "order %d is a play-through" % seed_value)
		assert_eq(order[order.size() - 1], ProgressRules.DESCEND)
		# (the fire-arrow cart is no key: three flares crack the garden wall too)
		assert_gt(order.size(), ProgressRules.step_ids().size() - 2.0, "order %d: every key step" % seed_value)
		distinct[str(order)] = true
	assert_gt(distinct.size(), 3.0, "the orders differ")


func test_every_step_has_a_target_on_the_built_floor() -> void:
	var markers := Floor1Layout.create().markers
	for step in ProgressRules.step_ids():
		var target := Floor1Route.step_target(step, markers)
		assert_false(target.is_empty(), "%s has a target" % step)
		assert_ne(target.get("at", Vector3.INF), Vector3.INF, "%s: its marker %s is on the floor" % [step, target.get("marker", "")])
	assert_eq(Floor1Route.step_target(&"pistol", markers)["marker"], &"pistol_locker")
	assert_eq(Floor1Route.step_target(&"pistol", markers)["kind"], &"use")
	assert_eq(Floor1Route.step_target(&"colossus", markers)["marker"], &"arena_colossus_start")
	assert_eq(Floor1Route.step_target(&"colossus", markers)["kind"], &"floor")
	assert_eq(Floor1Route.step_target(ProgressRules.TREX, markers)["kind"], &"near")
	assert_eq(Floor1Route.step_target(ProgressRules.DESCEND, markers)["marker"], Floor1Plan.EXIT_MARKER)
	assert_eq(Floor1Route.step_seconds(&"colossus"), Floor1Route.GUARDIAN_FIGHT)
	assert_eq(Floor1Route.step_seconds(ProgressRules.TREX), Floor1Route.TREX_FIGHT)
	assert_eq(Floor1Route.step_seconds(&"power_north"), Floor1Route.DEVICE_TIME)


func test_fights_follow_the_directors_draw() -> void:
	assert_almost_eq(Floor1Route.fight_seconds(&"wax"), 60.0 / Floor1Route.DPS + Floor1Route.FIGHT_OVERHEAD)
	assert_almost_eq(Floor1Route.fight_seconds(&"unknown"), Floor1Route.DEFAULT_HP / Floor1Route.DPS + Floor1Route.FIGHT_OVERHEAD)
	var layout := LevelLayout.new()
	var wax: Array[StringName] = [&"wax"]
	var pair: Array[StringName] = [&"wax", &"mummy"]
	for i in 3:
		layout.add_spawn(Vector3(i, 0, 0), &"hall", 0, wax.duplicate())
	layout.add_spawn(Vector3(0, 0, 3), &"hall", 1, pair.duplicate())
	layout.add_spawn(Vector3(0, 0, 5), &"hall", SpawnSlot.ALWAYS_SET, wax.duplicate())
	var description := LevelDescription.new()
	description.room_zones[&"hall"] = &"egypt"
	description.room_areas[&"hall"] = 200.0
	description.zone_density = {&"egypt": 1.0}   # cap 2
	var fights := Floor1Route.room_fights(layout, description)
	var hall: Dictionary = fights[&"hall"]
	assert_almost_eq(float(hall["exhibits"]), 1.0 + 0.5 * 2.0 + 0.5 * 1.0, 0.001, "always 1, set 0 trimmed to 2, set 1 has 1")
	var mixed := (Floor1Route.fight_seconds(&"wax") + Floor1Route.fight_seconds(&"mummy")) * 0.5
	var expected := 2.0 * Floor1Route.fight_seconds(&"wax") + 0.5 * mixed + Floor1Route.ROOM_CLEAR
	assert_almost_eq(float(hall["seconds"]), expected, 0.001)


func test_looking_round_grows_with_the_floor_and_stops() -> void:
	var small := RoomSpec.new()
	small.parts = [Rect2(0, 0, 5, 5)] as Array[Rect2]
	var huge := RoomSpec.new()
	huge.parts = [Rect2(0, 0, 60, 60)] as Array[Rect2]
	assert_almost_eq(Floor1Route.look_seconds(small), Floor1Route.LOOK_BASE + 1.0, 0.001)
	assert_eq(Floor1Route.look_seconds(huge), Floor1Route.LOOK_MAX)


func test_notes_are_read_word_by_word() -> void:
	var words := Floor1Route.note_words()
	assert_gt(float(words.get(&"note_basement_1", 0)), 10.0, "the restorer's job list has a text")
	assert_false(words.has(&"note_zz_missing"))
	assert_almost_eq(Floor1Route.read_seconds(30), Floor1Route.NOTE_BASE + 10.0, 0.001)


func test_the_timeline_runs_in_nights() -> void:
	var timeline := Floor1Route.Timeline.new()
	timeline.spend(&"fight", 100.0, &"egypt")
	var share := timeline.walk({&"egypt": 550.0, &"hub": 550.0})
	assert_almost_eq(share, 1.0, 0.0001)
	assert_almost_eq(timeline.total, 300.0, 0.001, "1100 m at 5.5 m/s")
	assert_almost_eq(float(timeline.by_part[&"egypt"]), 200.0, 0.001)
	assert_almost_eq(timeline.metres, 1100.0, 0.001)
	share = timeline.walk({&"hub": 11000.0})
	assert_almost_eq(share, (Floor1Route.NIGHT_LENGTH - 300.0) / 2000.0, 0.0001, "the walk ends at dawn")
	assert_almost_eq(timeline.left(), 0.0, 0.001)
	timeline.next_night(&"hub")
	assert_eq(timeline.night, 2)
	assert_almost_eq(timeline.clock, Floor1Route.NIGHT_START, 0.001)
	assert_almost_eq(timeline.nights(), 1.0 + Floor1Route.NIGHT_START / Floor1Route.NIGHT_LENGTH, 0.0001)
	assert_eq(Floor1Route.part_of(&"north_hall"), &"hub")
	assert_eq(Floor1Route.part_of(&"roof"), &"roof")
