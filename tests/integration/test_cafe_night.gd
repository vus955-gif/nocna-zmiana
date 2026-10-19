extends TestCase
## Fatigue and the café over a night in the game (plan
## 2026-10-10-kawiarnia-zmeczenie): the clock feeds the fatigue, a haven's
## rest brings it down, the save of a night in progress keeps it with the
## caffeine, and the café's own moments.

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


func test_the_clock_feeds_the_fatigue_and_the_night_wears_the_guard_down() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_eq(museum.player.fatigue.night_fraction, 0.0, "23:00")
	museum.player.global_position = OUTSIDE
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() * 0.5
	await physics_frames(2)
	assert_almost_eq(museum.player.fatigue.night_fraction, 0.5, 0.01, "the clock's fraction")
	var before := museum.player.fatigue.level
	await _seconds(2.0)
	assert_gt(museum.player.fatigue.level, before + Fatigue.time_rate(0.5) * 1.5, "the night tires him outside")


func test_a_rest_in_the_booth_brings_the_fatigue_down() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	assert_true(Haven.shelters(museum.player.global_position), "the night starts in the booth")
	museum.player.fatigue.level = 0.2
	await _seconds(2.0)
	assert_lt(museum.player.fatigue.level, 0.2 - Fatigue.REST_PER_SEC * 1.5, "resting")
	assert_gt(museum.player.fatigue.level, 0.2 - Fatigue.REST_PER_SEC * 2.5)


func test_a_resumed_night_keeps_the_fatigue_and_the_caffeine() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	museum.player.fatigue.drink(&"large")
	museum.player.fatigue.level = 0.5
	museum.player.fatigue.buff_left = 100.0
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	assert_almost_eq(museum.player.fatigue.level, 0.5, 0.01)
	assert_eq(museum.player.fatigue.buff, &"large")
	assert_almost_eq(museum.player.fatigue.buff_left, 100.0, 1.0)
	assert_true(museum.player.fatigue.blocks_rise(), "the large coffee still holds the night still")
