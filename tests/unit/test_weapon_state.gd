extends TestCase


func _magazine_weapon() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_gun"
	data.cooldown = 0.2
	data.ammo_mode = WeaponData.AmmoMode.MAGAZINE
	data.ammo_type = &"bullets"
	data.magazine_size = 3
	data.reload_time = 1.0
	data.start_reserve = 4
	data.max_reserve = 10
	return data


func _battery_weapon() -> WeaponData:
	var data := WeaponData.new()
	data.id = &"test_zapper"
	data.cooldown = 0.1
	data.ammo_mode = WeaponData.AmmoMode.BATTERY
	data.battery_max = 100.0
	data.battery_cost = 33.0
	data.battery_recharge_per_sec = 20.0
	data.battery_recharge_delay = 0.5
	return data


func test_starts_with_full_magazine_and_reserve() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_eq(state.magazine, 3)
	assert_eq(state.reserve, 4)


func test_firing_uses_a_round_and_starts_cooldown() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_true(state.can_fire())
	state.fire()
	assert_eq(state.magazine, 2)
	assert_false(state.can_fire())
	state.tick(0.21)
	assert_true(state.can_fire())


func test_empty_magazine_cannot_fire() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 0
	assert_false(state.can_fire())
	assert_false(state.has_ammo_for_shot())


func test_reload_moves_rounds_from_reserve_after_reload_time() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 1
	assert_true(state.start_reload())
	assert_true(state.is_reloading())
	assert_false(state.can_fire())
	state.tick(0.5)
	assert_eq(state.magazine, 1)
	state.tick(0.6)
	assert_false(state.is_reloading())
	assert_eq(state.magazine, 3)
	assert_eq(state.reserve, 2)


func test_reload_with_short_reserve_takes_what_is_left() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 0
	state.reserve = 1
	state.start_reload()
	state.tick(1.1)
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 0)


func test_no_reload_when_full_or_reserve_empty() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_false(state.start_reload(), "full")
	state.magazine = 1
	state.reserve = 0
	assert_false(state.start_reload(), "no reserve")


func test_cancel_reload_keeps_magazine() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.magazine = 1
	state.start_reload()
	state.cancel_reload()
	state.tick(2.0)
	assert_eq(state.magazine, 1)


func test_add_ammo_caps_at_max_reserve() -> void:
	var state := WeaponState.new(_magazine_weapon())
	assert_eq(state.add_ammo(4), 4)
	assert_eq(state.add_ammo(5), 2)
	assert_eq(state.reserve, 10)


func test_battery_gives_three_shots_then_recharges_after_delay() -> void:
	var state := WeaponState.new(_battery_weapon())
	for i in 3:
		assert_true(state.can_fire(), "shot %d" % i)
		state.fire()
		state.tick(0.11)
	assert_false(state.can_fire(), "battery drained")
	state.tick(0.3)
	assert_false(state.can_fire(), "still waiting")
	state.tick(1.8)
	assert_true(state.can_fire(), "recharged")


func test_battery_weapon_ignores_ammo_pickups() -> void:
	var state := WeaponState.new(_battery_weapon())
	assert_eq(state.add_ammo(10), 0)


func test_state_works_on_its_own_copy_of_the_data() -> void:
	var loaded: WeaponData = load("res://src/weapons/data/pistol.tres")
	var state := WeaponState.new(loaded)
	assert_ne(state.data, loaded)
	state.data.damage = 999.0
	assert_eq(loaded.damage, 20.0, "the shared .tres stays untouched")
	assert_eq(state.data.id, &"pistol")


func test_cooldown_ends_on_the_frame_it_runs_out() -> void:
	var data := _magazine_weapon()
	data.cooldown = 0.1
	var state := WeaponState.new(data)
	state.fire()
	for i in 6:   # exactly 0.1 s at 60 Hz
		state.tick(1.0 / 60.0)
	assert_true(state.can_fire())


func test_zero_reload_time_reloads_at_once() -> void:
	var data := _magazine_weapon()
	data.reload_time = 0.0
	var state := WeaponState.new(data)
	state.magazine = 0
	assert_true(state.start_reload())
	assert_false(state.is_reloading())
	assert_eq(state.magazine, 3)
	assert_eq(state.reserve, 1)


func test_add_ammo_never_takes_away() -> void:
	var state := WeaponState.new(_magazine_weapon())
	state.reserve = 12   # above max_reserve (10)
	assert_eq(state.add_ammo(5), 0)
	assert_eq(state.reserve, 12)


func test_apply_upgrades_rebuilds_the_copy_from_the_base() -> void:
	var pistol := WeaponState.new(load("res://src/weapons/data/pistol.tres"))
	pistol.apply_upgrades({&"pistol_damage": 1})
	pistol.apply_upgrades({&"pistol_damage": 1})
	assert_almost_eq(pistol.data.damage, 26.0, 0.001, "applied once, not stacked")
	pistol.apply_upgrades({})
	assert_eq(pistol.data.damage, 20.0)
	assert_eq(pistol.base.damage, 20.0)


func test_toggle_alt_unloads_and_reloads() -> void:
	var shotgun := WeaponState.new(load("res://src/weapons/data/shotgun.tres"))
	shotgun.apply_upgrades({&"shotgun_slug": 1})
	assert_eq(shotgun.magazine, 2)
	assert_eq(shotgun.reserve, 10)
	assert_eq(shotgun.shot_data().pellets, 10)
	assert_true(shotgun.toggle_alt())
	assert_true(shotgun.use_alt)
	assert_eq(shotgun.shot_data().pellets, 1)
	assert_eq(shotgun.magazine, 0)
	assert_true(shotgun.is_reloading())
	shotgun.tick(2.0)
	assert_eq(shotgun.magazine, 2)
	assert_eq(shotgun.reserve, 10, "the unloaded shells went back")


func test_toggle_alt_needs_the_slug_upgrade() -> void:
	var shotgun := WeaponState.new(load("res://src/weapons/data/shotgun.tres"))
	assert_false(shotgun.has_alt())
	assert_false(shotgun.toggle_alt())
	assert_eq(shotgun.magazine, 2)
