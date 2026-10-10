extends TestCase
## The flashlight battery: drain, slow recharge, empty cut-off, flicker.


func test_full_battery_lasts_120_seconds() -> void:
	var battery := FlashlightBattery.new()
	assert_true(battery.set_on(true))
	battery.tick(119.0)
	assert_true(battery.on)
	battery.tick(1.5)
	assert_false(battery.on, "ran dry")
	assert_eq(battery.charge, 0.0)


func test_recharges_twice_as_slow_when_off() -> void:
	var battery := FlashlightBattery.new()
	battery.set_on(true)
	battery.tick(60.0)
	assert_almost_eq(battery.fraction(), 0.5)
	battery.set_on(false)
	battery.tick(60.0)
	assert_almost_eq(battery.fraction(), 0.75, 0.001, "60 s off gives back 30 s of light")
	battery.tick(1000.0)
	assert_eq(battery.fraction(), 1.0)


func test_empty_battery_turns_the_light_off_until_recharged() -> void:
	var battery := FlashlightBattery.new()
	battery.set_on(true)
	battery.tick(200.0)
	assert_false(battery.on)
	assert_false(battery.set_on(true), "too weak to light")
	battery.tick(FlashlightBattery.BASE_CAPACITY * FlashlightBattery.RELIGHT_AT / FlashlightBattery.RECHARGE_RATIO + 0.1)
	assert_true(battery.set_on(true))


func test_flickers_below_15_percent() -> void:
	var battery := FlashlightBattery.new()
	battery.set_on(true)
	battery.tick(100.0)
	assert_false(battery.is_flickering(), "17% left")
	battery.tick(4.0)
	assert_true(battery.is_flickering(), "13% left")
	battery.set_on(false)
	assert_false(battery.is_flickering(), "a dark light does not flicker")
	assert_true(battery.is_low())


func test_capacity_change_keeps_the_charge_fraction() -> void:
	var battery := FlashlightBattery.new()
	battery.set_on(true)
	battery.tick(30.0)
	battery.set_capacity(180.0)
	assert_almost_eq(battery.fraction(), 0.75)
	assert_almost_eq(battery.charge, 135.0)
