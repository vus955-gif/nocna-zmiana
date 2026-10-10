extends TestCase
## The gatling's crank, burst spread and belt as pure WeaponState logic
## (60 ticks a second, like the physics).

const DT := 1.0 / 60.0

var gun: WeaponState


func before_each() -> void:
	gun = WeaponState.new(load("res://src/weapons/data/gatling.tres"))


## Ticks [param frames] frames holding the trigger; fires whenever it can.
## Returns the rounds fired.
func _hold(frames: int, shoot: bool = true) -> int:
	var fired := 0
	for i in frames:
		gun.tick(DT)
		gun.pull_trigger()
		if shoot and gun.can_fire():
			gun.fire()
			fired += 1
	return fired


func _release(frames: int) -> void:
	for i in frames:
		gun.tick(DT)


## Frames of holding until the first round goes off (-1: none in 2 s).
func _frames_to_first_round() -> int:
	for i in 120:
		gun.tick(DT)
		gun.pull_trigger()
		if gun.can_fire():
			return i
	return -1


func test_spins_up_for_0_45_s_before_the_first_round() -> void:
	gun.pull_trigger()
	assert_false(gun.can_fire(), "barrels at rest")
	var frames := _frames_to_first_round()
	assert_almost_eq(frames / 60.0, 0.45, 1.5 / 60.0, "spin-up time")
	assert_true(gun.trigger_held())


func test_coasting_for_0_6_s_allows_an_instant_restart() -> void:
	_hold(40)
	_release(30)   # 0.5 s after letting go: still turning
	assert_true(gun.coasting())
	assert_true(gun.spun_up())
	assert_eq(_frames_to_first_round(), 0, "fires at once")


func test_after_coasting_the_barrels_stop_and_spin_up_again() -> void:
	_hold(40)
	_release(40)   # 0.67 s: stopped
	assert_false(gun.coasting())
	assert_eq(gun.spin, 0.0)
	assert_false(gun.spun_up())
	assert_almost_eq(_frames_to_first_round() / 60.0, 0.45, 1.5 / 60.0)


func test_letting_go_before_full_speed_winds_down() -> void:
	_hold(15, false)
	var partial := gun.spin
	assert_gt(partial, 0.3)
	_release(10)
	assert_lt(gun.spin, partial)
	assert_false(gun.coasting(), "only a gun at full speed coasts")


func test_fires_fourteen_rounds_a_second() -> void:
	_hold(27, false)
	var rounds := _hold(60)
	assert_true(rounds >= 13 and rounds <= 15, "rounds in one second: %d" % rounds)
	rounds += _hold(120)
	assert_eq(rounds, 42, "three seconds: 42 rounds")


func test_spread_grows_from_3_to_5_degrees_and_settles_back() -> void:
	var data := gun.data
	assert_almost_eq(gun.spread_for(data), 3.0)
	_hold(27 + 45)   # 0.75 s of fire: half open
	assert_almost_eq(gun.spread_for(data), 4.0, 0.25)
	_hold(60)
	assert_almost_eq(gun.spread_for(data), 5.0, 0.01, "a long burst")
	_release(60)
	assert_almost_eq(gun.spread_for(data), 3.0, 0.01, "back after a pause")


func test_the_empty_box_takes_the_next_belt_in_0_35_s_never_a_reload() -> void:
	assert_eq(gun.magazine, 120)
	assert_eq(gun.reserve, 60)
	assert_false(gun.can_reload(), "no reload on a belt")
	assert_false(gun.start_reload())
	_hold(27, false)
	var fired := 0
	for i in 700:
		gun.tick(DT)
		gun.pull_trigger()
		if gun.can_fire():
			gun.fire()
			fired += 1
		if fired == 120:
			break
	assert_eq(fired, 120)
	assert_true(gun.is_reloading(), "the belt change")
	assert_eq(gun.magazine, 0)
	var waited := 0
	while not gun.can_fire() and waited < 60:
		gun.tick(DT)
		gun.pull_trigger()
		waited += 1
	assert_almost_eq(waited / 60.0, 0.35, 1.5 / 60.0, "a 0.35 s hitch")
	assert_eq(gun.magazine, 60, "the next belt ran in")
	assert_eq(gun.reserve, 0)
	assert_true(gun.spun_up(), "the barrels kept turning")


func test_the_longer_belt_feeds_the_next_one_without_a_pause() -> void:
	gun.apply_upgrades({&"gatling_belt": 1})
	gun.magazine = 1
	gun.reserve = 300
	_hold(30, false)
	assert_true(gun.can_fire())
	gun.fire()
	assert_false(gun.is_reloading(), "no hitch")
	assert_eq(gun.magazine, 200, "a 200-round belt")
	assert_eq(gun.reserve, 100)


func test_an_empty_gun_feeds_a_picked_up_belt() -> void:
	gun.magazine = 0
	gun.reserve = 0
	assert_false(gun.has_ammo_for_shot())
	assert_false(gun.has_ammo_left())
	assert_eq(gun.add_ammo(50), 50)
	assert_true(gun.has_ammo_left())
	for i in 22:
		gun.tick(DT)
	assert_eq(gun.magazine, 50, "in after the belt change")
	assert_eq(gun.reserve, 0)


func test_reserve_is_capped_at_360() -> void:
	gun.reserve = 0
	assert_eq(gun.add_ammo(1000), 360)
