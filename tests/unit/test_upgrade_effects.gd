extends TestCase
## Upgrade levels -> the guard's numbers and weapon copies.


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func test_no_upgrades_means_base_numbers() -> void:
	var none := {}
	assert_eq(UpgradeEffects.max_health(none), 100.0)
	assert_eq(UpgradeEffects.stamina_max(none), 100.0)
	assert_eq(UpgradeEffects.stamina_regen(none), 30.0)
	assert_eq(UpgradeEffects.battery_capacity(none), 120.0)
	assert_eq(UpgradeEffects.finisher_heal(none), 15.0)
	var pistol := _weapon(&"pistol").duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(pistol, none)
	assert_eq(pistol.damage, 20.0)
	assert_eq(pistol.magazine_size, 12)


func test_guard_numbers_per_level() -> void:
	assert_eq(UpgradeEffects.max_health({&"health": 1}), 120.0)
	assert_eq(UpgradeEffects.max_health({&"health": 3}), 160.0)
	assert_eq(UpgradeEffects.stamina_max({&"stamina": 2}), 140.0)
	assert_almost_eq(UpgradeEffects.stamina_regen({&"stamina": 1}), 34.5)
	assert_almost_eq(UpgradeEffects.stamina_regen({&"stamina": 3}), 43.5)
	assert_eq(UpgradeEffects.battery_capacity({&"battery": 1}), 180.0)
	assert_eq(UpgradeEffects.battery_capacity({&"battery": 2}), 240.0)
	assert_almost_eq(UpgradeEffects.fist_damage_multiplier({&"fists": 2}), 1.8)
	assert_almost_eq(UpgradeEffects.finisher_heal({&"fists": 1}), 18.75)
	assert_eq(UpgradeEffects.max_health({&"health": 9}), 160.0, "levels beyond the catalog are capped")


func test_weapon_copies_get_upgrades_and_the_tres_stays_untouched() -> void:
	var levels := {&"pistol_damage": 1, &"pistol_mag": 1, &"taser_charge": 1, &"taser_chain": 1, &"shotgun_spread": 1, &"fists": 1}
	var copies := {}
	for id in [&"pistol", &"taser", &"shotgun", &"fists"]:
		var copy := _weapon(id).duplicate() as WeaponData
		UpgradeEffects.apply_to_weapon(copy, levels)
		copies[id] = copy
	assert_almost_eq(copies[&"pistol"].damage, 26.0)
	assert_eq(copies[&"pistol"].magazine_size, 18)
	assert_almost_eq(copies[&"taser"].battery_recharge_per_sec, 35.2)
	assert_eq(copies[&"taser"].chain_range, 5.0)
	assert_almost_eq(copies[&"shotgun"].spread_deg, 4.55)
	assert_almost_eq(copies[&"fists"].damage, 21.0)
	assert_eq(_weapon(&"pistol").damage, 20.0, "pistol.tres untouched")
	assert_eq(_weapon(&"pistol").magazine_size, 12)
	assert_eq(_weapon(&"taser").chain_range, 0.0)
	assert_eq(_weapon(&"shotgun").spread_deg, 7.0)
	assert_eq(_weapon(&"fists").damage, 15.0)


func test_slug_builds_a_one_ray_profile() -> void:
	var shotgun := _weapon(&"shotgun").duplicate() as WeaponData
	assert_eq(UpgradeEffects.alt_profile(shotgun), null, "no slugs without the upgrade")
	UpgradeEffects.apply_to_weapon(shotgun, {&"shotgun_slug": 1})
	var slug := UpgradeEffects.alt_profile(shotgun)
	assert_not_null(slug)
	if slug != null:
		assert_eq(slug.pellets, 1)
		assert_eq(slug.damage, 70.0)
		assert_eq(slug.spread_deg, 0.0)
		assert_eq(slug.weak_point_multiplier, 2.0)
		assert_eq(slug.ammo_type, &"shells", "same shells")


func test_secret_bonus_steps_add_to_the_guard_numbers() -> void:
	assert_eq(UpgradeEffects.max_health({&"bonus_health": 2}), 120.0)
	assert_eq(UpgradeEffects.max_health({&"health": 1, &"bonus_health": 1}), 130.0, "on top of the bought level")
	assert_eq(UpgradeEffects.stamina_max({&"bonus_stamina": 1}), 110.0)
	assert_eq(UpgradeEffects.stamina_regen({&"bonus_stamina": 3}), 30.0, "a step is capacity only")
	assert_eq(UpgradeEffects.battery_capacity({&"bonus_battery": 1}), 140.0)
	assert_eq(UpgradeEffects.battery_capacity({&"battery": 1, &"bonus_battery": 2}), 220.0, "seconds added after the upgrade's factor")
	assert_almost_eq(UpgradeEffects.reserve_factor({&"bonus_pockets": 2}), 1.2)
	assert_almost_eq(UpgradeEffects.reserve_factor({&"pockets": 1, &"bonus_pockets": 1}), 1.35)
	assert_eq(UpgradeEffects.spare_ammo(20, {&"bonus_pockets": 1}), 22)
	assert_almost_eq(UpgradeEffects.dust_magnet_radius({&"bonus_magnet": 1}), DustMote.MAGNET_RADIUS + 1.5)
	assert_eq(UpgradeEffects.max_health({&"bonus_health": -3}), 100.0, "junk counts for nothing")
	assert_eq(UpgradeEffects.max_health({&"bonus_health": 2.0}), 120.0, "a float from a save")


func test_secret_mods_change_how_the_weapons_work() -> void:
	var shotgun := _weapon(&"shotgun").duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(shotgun, {&"mod_shotgun_choke": 1, &"shotgun_slug": 1})
	assert_eq(shotgun.pierce_targets, 2, "the carver's choke: shot goes on through the first target")
	assert_eq(UpgradeEffects.alt_profile(shotgun).pierce_targets, 2, "slugs too")
	var rifle := _weapon(&"rifle_hunt").duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(rifle, {&"mod_rifle_peep": 1})
	assert_true(rifle.lock_breaker, "the peep sight: a round snaps a chain link")
	assert_eq(rifle.pierce_targets, 3, "nothing else changes")
	var harpoon := _weapon(&"harpoon").duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(harpoon, {&"mod_harpoon_line": 1})
	assert_true(harpoon.line_return, "the return line")
	for id in [&"shotgun", &"rifle_hunt", &"harpoon"]:
		var plain := _weapon(id).duplicate() as WeaponData
		UpgradeEffects.apply_to_weapon(plain, {&"mod_shotgun_choke": 0})
		assert_false(plain.lock_breaker, "%s plain" % id)
		assert_false(plain.line_return, "%s plain" % id)
		assert_eq(plain.pierce_targets, _weapon(id).pierce_targets, "%s plain" % id)
	assert_false(_weapon(&"rifle_hunt").lock_breaker, "rifle_hunt.tres untouched")
	assert_eq(_weapon(&"shotgun").pierce_targets, 1, "shotgun.tres untouched")
	assert_true(UpgradeEffects.has_mod({&"mod_rifle_peep": 1}, &"rifle_peep"))
	assert_false(UpgradeEffects.has_mod({&"mod_rifle_peep": 0}, &"rifle_peep"))
	assert_false(UpgradeEffects.has_mod({}, &"rifle_peep"))
