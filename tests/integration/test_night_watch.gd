extends TestCase
## The clock in the game: the HUD, menus and havens stopping it, the
## witching hour, dawn ending the night without a death, a resumed night
## keeping its time, and the beaten boss stopping it.

const OUTSIDE := Vector3(0, 0.1, 50)

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func test_the_clock_runs_outside_and_stands_in_a_menu() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_eq(museum.hud.clock_text(), "23:00")
	museum.player.global_position = OUTSIDE
	await _seconds(1.0)
	var watch := museum.watch
	assert_gt(watch.clock.elapsed, 0.5)
	watch.clock.elapsed = NightClock.SECONDS_PER_HOUR * 1.5
	await physics_frames(2)
	assert_eq(museum.hud.clock_text(), "0:30")
	var before := watch.clock.elapsed
	museum.pause_menu.open()
	await get_tree().create_timer(1.0, true).timeout
	assert_almost_eq(watch.clock.elapsed, before, 0.05, "a pause stops the night")
	museum.pause_menu.close()


func test_the_booth_gives_a_minutes_rest() -> void:
	GameState.new_game()
	_museum()
	await _seconds(2.0)
	assert_almost_eq(museum.watch.clock.elapsed, 0.0, 0.001, "resting at the start")
	museum.watch.clock.haven_left = 0.5
	await _seconds(1.5)
	assert_gt(museum.watch.clock.elapsed, 0.5, "after the minute it runs on")


func test_the_witching_hour_makes_the_exhibits_faster_and_fiercer() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	museum.player.global_position = OUTSIDE
	var speeds := {}
	for exhibit in museum.exhibits():
		speeds[exhibit] = [exhibit.move_speed, exhibit.attack_damage]
	var rung := watch(Events.witching_hour)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() - 0.1
	await _seconds(0.5)
	assert_eq(rung.size(), 1)
	assert_true(museum.hud.card_text().contains(tr("NIGHT_WITCHING").to_upper()), museum.hud.card_text())
	for exhibit: Enemy in speeds:
		if is_instance_valid(exhibit):
			assert_almost_eq(exhibit.move_speed, speeds[exhibit][0] * 1.2, 0.001)
			assert_almost_eq(exhibit.attack_damage, speeds[exhibit][1] * 1.2, 0.001)
	var called := museum.objective.summon_wax(1)
	for node in called:
		assert_true((node as Enemy).has_meta(&"witching"), "and so are those that come later")


func test_dawn_ends_the_night_without_a_death() -> void:
	GameState.new_game()
	GameState.lantern = {"active": true, "position": [2.0, 0.0, 10.0], "dust": 7}
	GameState.save_game()
	_museum()
	await physics_frames(2)
	museum.player.global_position = OUTSIDE
	RunState.add_dust(33, false)
	(museum.objective.fuse_pickups.values()[0] as FusePickup).interact(museum.player)
	var next := watch(museum.next_night_requested)
	var dawned := watch(Events.dawn_broke)
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.2
	await _seconds(0.5)
	assert_eq(dawned.size(), 1)
	for exhibit in museum.exhibits():
		assert_true(exhibit.is_frozen(), "every exhibit stopped dead")
	assert_true(museum.objective.boss.process_mode == Node.PROCESS_MODE_DISABLED, "the skeleton too")
	assert_eq(GameState.night, 2)
	assert_eq(GameState.run_dust, 33, "the Dust stays with the guard")
	assert_eq(GameState.lantern["dust"], 7, "no new lantern; the old one waits")
	assert_eq(GameState.stats["deaths"], 0)
	assert_eq(GameState.stats["nights"], 1)
	assert_eq(GameState.night_progress, {}, "the fuses and the crystal are gone")
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_eq(on_disk.night, 2)
	assert_eq(on_disk.run_dust, 33)
	await get_tree().create_timer(Museum.DAWN_DELAY + DawnScreen.FADE_TIME + DawnScreen.CARD_TIME + 1.0).timeout
	assert_eq(next.size(), 1, "the next night follows the dawn card")
	assert_true(museum.dawn_screen.text().contains(tr("NIGHT_DAWN").to_upper()))
	museum.free()
	_museum()
	await physics_frames(2)
	assert_eq(RunState.dust, 33, "carried into the next night")
	assert_eq(museum.objective.fuse_pickups.size(), 2)
	assert_eq(museum.hud.clock_text(), "23:00")


func test_a_resumed_night_keeps_its_time() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	museum.watch.clock.elapsed = 812.0
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	assert_almost_eq(museum.watch.clock.elapsed, 812.0, 1.0)
	assert_true(museum.watch.clock.is_witching())
	for exhibit in museum.exhibits():
		assert_true(exhibit.has_meta(&"witching"), "past 3:00 the exhibits start strong")


func test_the_beaten_boss_stops_the_clock() -> void:
	GameState.new_game()
	GameState.demo_complete = true
	_museum()
	await physics_frames(3)
	museum.player.global_position = OUTSIDE
	await _seconds(0.5)
	assert_false(museum.watch.running)
	var before := museum.watch.clock.elapsed
	await _seconds(0.5)
	assert_eq(museum.watch.clock.elapsed, before)
