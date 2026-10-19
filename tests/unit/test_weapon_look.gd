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


func test_every_finish_belongs_to_one_weapon_and_has_its_colours() -> void:
	assert_eq(WeaponLook.LOOKS.size(), 8, "one finish for every firearm and the taser")
	var weapons: Array[StringName] = []
	for look: StringName in WeaponLook.LOOKS:
		var spec: Dictionary = WeaponLook.LOOKS[look]
		var weapon: StringName = spec["weapon"]
		assert_true(Loadout.WEAPON_PATHS.has(weapon), "%s: %s is a weapon" % [look, weapon])
		assert_false(weapons.has(weapon), "%s: one finish per weapon" % look)
		weapons.append(weapon)
		assert_true(spec["tint"] is Color and spec["accent"] is Color, str(look))
		var tint: Color = spec["tint"]
		assert_gt(maxf(tint.r, maxf(tint.g, tint.b)), 0.45, "%s: a tint that leaves the texture readable" % look)
		assert_gt(float(spec["roughness"]), 0.0, str(look))
		assert_true(float(spec["metallic"]) >= 0.0 and float(spec["metallic"]) <= 1.0, str(look))
		assert_true(WeaponLook.SIGNATURE.has(weapon), "%s glows on a signature part" % look)
	for mod: StringName in WeaponLook.MODS:
		var spec: Dictionary = WeaponLook.MODS[mod]
		assert_true(Loadout.WEAPON_PATHS.has(spec["weapon"]), "%s: %s is a weapon" % [mod, spec["weapon"]])
		assert_true(String(spec["part"]).begins_with(WeaponLook.MOD_PREFIX), "%s names its part" % mod)
	assert_eq(WeaponLook.MODS.size(), 3)


func test_finishes_and_mods_are_read_from_the_levels() -> void:
	var levels := {WeaponLook.look_key(&"shotgun", &"faience"): 1, WeaponLook.mod_key(&"shotgun_choke"): 1,
			WeaponLook.mod_key(&"rifle_peep"): 1, WeaponLook.look_key(&"pistol", &"founder"): 0,
			&"look_hwacha_nonsense": 1}
	assert_eq(WeaponLook.look_of(&"shotgun", levels), &"faience")
	assert_eq(WeaponLook.look_of(&"pistol", levels), &"", "a level of 0 is no finish")
	assert_eq(WeaponLook.look_of(&"hwacha", levels), &"", "only finishes of the table")
	assert_eq(WeaponLook.look_of(&"rifle_hunt", levels), &"")
	assert_eq(WeaponLook.look_of(&"fist", levels), &"")
	assert_eq(WeaponLook.mods_of(&"shotgun", levels), [&"shotgun_choke"] as Array[StringName])
	assert_eq(WeaponLook.mods_of(&"rifle_hunt", levels), [&"rifle_peep"] as Array[StringName])
	assert_eq(WeaponLook.mods_of(&"harpoon", levels).size(), 0)
	assert_eq(WeaponLook.look_key(&"shotgun", &"faience"), &"look_shotgun_faience")
	assert_eq(WeaponLook.mod_key(&"rifle_peep"), &"mod_rifle_peep")


func test_the_look_key_changes_with_a_finish_or_a_mod() -> void:
	var before := WeaponLook.key(&"shotgun", {})
	assert_ne(WeaponLook.key(&"shotgun", {&"look_shotgun_faience": 1}), before)
	assert_ne(WeaponLook.key(&"shotgun", {&"mod_shotgun_choke": 1}), before)
	assert_eq(WeaponLook.key(&"shotgun", {&"look_pistol_founder": 1, &"mod_rifle_peep": 1}), before, "another weapon's")
	assert_eq(WeaponLook.key(&"fist", {&"look_shotgun_faience": 1}), WeaponLook.key(&"fist", {}))
