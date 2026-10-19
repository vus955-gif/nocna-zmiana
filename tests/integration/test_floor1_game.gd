extends TestCase
## The game scene on Floor I (Museum.level_id = &"floor1"; the runner
## resets it to the lobby after every test): where a night starts, the six
## havens, the room cards and visits, the goal on the HUD, and what dawn,
## death and leaving keep. One floor build per test (the shell carving is
## cached in the process, so only the first build is slow).

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _find(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)


## Puts the guard on the floor at [param at] (feet), alive and well.
func _put_guard(at: Vector3) -> void:
	museum.player.global_position = at + Vector3.UP * 0.05
	museum.player.velocity = Vector3.ZERO
	museum.player.heal(1000.0)


func test_a_new_game_starts_in_the_security_booth_of_floor_one() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	assert_true(museum.level is MuseumFloorLevel, "the game plays Floor I")
	assert_eq(museum.floor_level, museum.level)
	assert_null_node(museum.lobby, "no lobby")
	assert_null_node(museum.objective, "the lobby's night goal stays in the lobby")
	assert_null_node(museum.armory, "the lobby's armory stays in the lobby")
	assert_not_null(museum.floor_game, "Floor I's game is installed")
	var zone: AABB = museum.level.haven_zones[&"security"]
	assert_true(zone.has_point(museum.player.global_position), "the night starts in the booth")
	assert_eq(museum.havens.size(), 6, "six havens")
	assert_eq(_find(museum, "UpgradeTerminal").size(), 6, "a terminal in each")
	assert_not_null(museum.watch, "the night's clock runs on the floor too")
	assert_true(museum.watch.running)
	assert_true(RunState.running)
	assert_eq(museum.exhibits().size(), NightSpawner.exhibit_count(museum.night) + museum.night.portraits.size())


func test_the_lobby_stays_the_test_level() -> void:
	Museum.level_id = &"lobby"
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_true(museum.level is LobbyLevel)
	assert_null_node(museum.floor_game, "no Floor I game in the lobby")
	assert_not_null(museum.objective)


func test_rooms_are_recorded_and_announced_with_a_card_on_the_first_visit() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_true(GameState.rooms_visited.has(&"booth_security"), "the night's first room counts")
	assert_eq(museum.hud.room_card_text(), "", "no card for the room the night starts in")
	var entered := watch(Events.room_entered)
	_put_guard(Vector3(0, 0, 45))
	await _seconds(0.4)
	assert_true(GameState.rooms_visited.has(&"entrance_hall"))
	assert_eq(entered.size(), 1)
	if entered.size() == 1:
		assert_eq(entered[0], [&"entrance_hall", &"entrance", true, null])
	assert_true(museum.hud.room_card_text().begins_with(tr("ROOM_ENTRANCE_HALL").to_upper()), museum.hud.room_card_text())
	_put_guard(Vector3(21, 0, 41.5))
	await _seconds(5.0)
	assert_eq(museum.hud.room_card_text(), "", "the card faded")
	_put_guard(Vector3(0, 0, 45))
	await _seconds(0.4)
	assert_eq(entered.size(), 3, "corridor and hall again")
	assert_eq(entered[2][2], false, "not the first visit")
	assert_eq(museum.hud.room_card_text(), "", "no card the second time")


func test_the_goal_follows_the_progress() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_eq(museum.hud.objective_text(), tr("GOAL_TICKET_KEY"))
	assert_eq(museum.hud.shards_text(), "", "no shards yet")
	var changed := watch(Events.goal_changed)
	GameState.pistol_key = true
	GameState.save_game()
	await physics_frames(2)
	assert_eq(museum.hud.objective_text(), tr("GOAL_PISTOL"))
	assert_eq(changed.size(), 1)
	if changed.size() == 1:
		assert_eq(changed[0][0], &"GOAL_PISTOL")
	GameState.add_shard(&"shard_egypt")
	Events.shard_collected.emit(&"shard_egypt", 1)
	await physics_frames(2)
	assert_eq(museum.hud.shards_text(), tr("GOAL_SHARDS") % [1, Floor1Plan.SHARD_COUNT])


func test_a_haven_found_is_where_the_next_night_starts() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var room: AABB = museum.level.haven_zones[&"conservator"]
	_put_guard(Vector3(room.get_center().x, room.position.y, room.get_center().z))
	await physics_frames(6)
	assert_true(GameState.havens.has(&"conservator"), "the conservator's room is known")
	assert_eq(GameState.start_haven, &"conservator")
	assert_true(museum.hud.card_text().contains(tr("HAVEN_CONSERVATOR").to_upper()), museum.hud.card_text())
	museum.free()
	RunState.reset()
	_museum()
	await physics_frames(3)
	var zone: AABB = museum.level.haven_zones[&"conservator"]
	assert_true(zone.has_point(museum.player.global_position), "the night starts in the conservator's room")


func test_the_wings_met_before_are_remembered() -> void:
	var layout := Floor1Layout.create()
	GameState.new_game()
	GameState.visit_room(&"court")
	GameState.visit_room(&"egypt_gallery")
	GameState.visit_room(&"egypt_tomb")
	GameState.visit_room(&"greece_vases")
	assert_eq(FloorGame.known_wings(GameState, layout), [&"egypt", &"greece"] as Array[StringName])


func assert_null_node(value: Variant, message: String = "") -> void:
	if value != null and is_instance_valid(value):
		fail("expected null. " + message)


## (plan 2026-10-19-glos-g2-kwestie: the System's hourly announcements)
func test_the_clock_strikes_each_full_hour_on_the_bus() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var struck := watch(Events.hour_struck)
	museum.watch.clock.haven_left = 0.0   # the booth's break would hold the clock
	museum.watch.clock.elapsed = NightClock.SECONDS_PER_HOUR - 0.05
	await physics_frames(8)
	assert_eq(struck.size(), 1)
	if struck.size() > 0:
		assert_eq(struck[0][0], 0, "midnight")
