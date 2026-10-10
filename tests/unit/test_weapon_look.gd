extends TestCase
## Upgrades show on the weapon (design 7.1a): the look table covers every
## weapon upgrade, level by level; parts come and go with the levels; the
## master finish needs every upgrade of the weapon at its top level.

const WEAPONS: Array[StringName] = [&"fist", &"taser", &"pistol", &"shotgun", &"gatling", &"flare",
	&"rifle_hunt", &"harpoon", &"hwacha"]


func test_every_weapon_upgrade_has_a_part_on_every_level() -> void:
	for entry in UpgradeCatalog.all():
		if entry.category == &"guard" and entry.id != &"fists":
			continue
		assert_true(WeaponLook.UPGRADES.has(entry.id), "%s has no look" % entry.id)
		var steps: Array = WeaponLook.UPGRADES.get(entry.id, [])
		assert_eq(steps.size(), entry.max_level(), "one look per level of %s" % entry.id)
		for i in steps.size():
			var shown: Array = (steps[i] as Dictionary).get("show", [])
			assert_gt(shown.size(), 0, "%s level %d shows something" % [entry.id, i + 1])
			for part: String in shown:
				assert_true(part.begins_with(WeaponLook.PART_PREFIX), part)


func test_every_weapon_has_a_signature_part() -> void:
	for weapon in WEAPONS:
		assert_true(WeaponLook.SIGNATURE.has(weapon), str(weapon))
		assert_gt(WeaponLook.upgrades_of(weapon).size(), 0, str(weapon))


func test_nothing_bought_hides_every_upgrade_part() -> void:
	assert_eq(WeaponLook.shown_parts(&"rifle_hunt", {}).size(), 0)
	var hidden := WeaponLook.hidden_parts(&"rifle_hunt", {})
	assert_true(hidden.has("upg_bolt_ball"))
	assert_true(hidden.has("upg_fittings"))
	assert_false(hidden.has("bolt_knob"), "the plain knob is on")


func test_a_level_shows_its_part_and_hides_what_it_replaces() -> void:
	var levels := {&"rifle_bolt": 1}
	assert_true(WeaponLook.shown_parts(&"rifle_hunt", levels).has("upg_bolt_ball"))
	assert_true(WeaponLook.hidden_parts(&"rifle_hunt", levels).has("bolt_knob"))
	assert_true(WeaponLook.hidden_parts(&"rifle_hunt", levels).has("upg_fittings"), "the other one not bought")
	assert_eq(WeaponLook.replaceable_parts(&"rifle_hunt"), PackedStringArray(["bolt_knob"]))


func test_higher_levels_keep_the_lower_ones() -> void:
	var one := WeaponLook.shown_parts(&"fist", {&"fists": 1})
	assert_true(one.has("upg_wraps_l") and one.has("upg_wraps_r"))
	assert_false(one.has("upg_knuckles_l"))
	var two := WeaponLook.shown_parts(&"fists", {&"fists": 2})
	assert_true(two.has("upg_wraps_l") and two.has("upg_knuckles_l") and two.has("upg_knuckles_r"))


func test_other_weapons_upgrades_never_show() -> void:
	var levels := {&"pistol_mag": 1, &"shotgun_spread": 1}
	assert_eq(WeaponLook.shown_parts(&"pistol", levels), PackedStringArray(["upg_mag"]))
	assert_eq(WeaponLook.shown_parts(&"harpoon", levels).size(), 0)


func test_mastery_needs_every_upgrade_at_the_top() -> void:
	assert_false(WeaponLook.mastered(&"hwacha", {}))
	assert_false(WeaponLook.mastered(&"hwacha", {&"hwacha_fuse": 1}))
	assert_true(WeaponLook.mastered(&"hwacha", {&"hwacha_fuse": 1, &"hwacha_volley": 1}))
	assert_false(WeaponLook.mastered(&"fist", {&"fists": 1}), "two levels")
	assert_true(WeaponLook.mastered(&"fist", {&"fists": 2}))
	assert_false(WeaponLook.mastered(&"no_such_weapon", {}))


func test_the_look_key_changes_with_the_levels() -> void:
	var before := WeaponLook.key(&"harpoon", {})
	assert_ne(WeaponLook.key(&"harpoon", {&"harpoon_reel": 1}), before)
	assert_eq(WeaponLook.key(&"harpoon", {&"pistol_mag": 1}), before, "another weapon's upgrade")
