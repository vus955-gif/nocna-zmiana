extends TestCase


func test_each_material_has_its_own_sounds() -> void:
	var seen := {}
	for kind in ExhibitMaterial.Kind.values():
		var hit := ExhibitMaterial.hit_sound(kind)
		var broken := ExhibitMaterial.break_sound(kind)
		assert_false(seen.has(hit), "duplicate " + str(hit))
		assert_false(seen.has(broken), "duplicate " + str(broken))
		seen[hit] = true
		seen[broken] = true
	assert_eq(seen.size(), ExhibitMaterial.Kind.size() * 2)


func test_wax_and_linen_take_fire_double() -> void:
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.WAX, DamageInfo.Kind.FIRE), 2.0)
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.LINEN, DamageInfo.Kind.FIRE), 2.0)
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.LINEN, DamageInfo.Kind.BALLISTIC), 1.0)
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.MARBLE, DamageInfo.Kind.FIRE), 1.0)


func test_wood_throws_chips_and_does_not_burn_double() -> void:
	assert_eq(ExhibitMaterial.hit_sound(ExhibitMaterial.Kind.WOOD), &"hit_wood")
	assert_eq(ExhibitMaterial.break_sound(ExhibitMaterial.Kind.WOOD), &"break_wood")
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.WOOD, DamageInfo.Kind.FIRE), 1.0)
	assert_true(Sfx.SOUNDS.has(&"hit_wood") and Sfx.SOUNDS.has(&"break_wood") and Sfx.SOUNDS.has(&"fu_scrape"))
