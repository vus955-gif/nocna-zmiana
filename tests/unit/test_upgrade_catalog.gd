extends TestCase
## The upgrade catalog against the design table (section 3).

const DESIGN := {
	&"health": [25, 50, 90],
	&"stamina": [20, 45, 80],
	&"battery": [20, 45],
	&"fists": [25, 55],
	&"taser_charge": [40],
	&"taser_chain": [70],
	&"pistol_damage": [50],
	&"pistol_mag": [40],
	&"shotgun_spread": [50],
	&"shotgun_slug": [80],
	&"pockets": [30, 60],
	&"second_wind": [120],
	&"dust_magnet": [25, 50],
	&"keen_ear": [40],
	&"gatling_spin": [50],
	&"gatling_belt": [45],
	&"flare_burn": [45],
	&"flare_twin": [70],
	# Floor I (design 8.1)
	&"rifle_bolt": [60],
	&"rifle_expand": [80],
	&"harpoon_reel": [55],
	&"harpoon_barbs": [75],
	&"hwacha_fuse": [60],
	&"hwacha_volley": [90],
}


func test_twenty_four_upgrades_with_thirty_two_levels() -> void:
	var levels := 0
	for entry in UpgradeCatalog.all():
		levels += entry.max_level()
	assert_eq(UpgradeCatalog.all().size(), 24)
	assert_eq(levels, 32)


func test_prices_match_the_design() -> void:
	for id in DESIGN:
		var entry := UpgradeCatalog.find(id)
		assert_not_null(entry, str(id))
		if entry == null:
			continue
		assert_eq(Array(entry.prices), DESIGN[id], str(id))
		for level in entry.max_level():
			assert_eq(UpgradeCatalog.price(id, level), DESIGN[id][level])


func test_price_is_minus_one_at_max_level() -> void:
	assert_eq(UpgradeCatalog.price(&"health", 3), -1)
	assert_eq(UpgradeCatalog.price(&"shotgun_slug", 1), -1)
	assert_eq(UpgradeCatalog.price(&"no_such_upgrade", 0), -1)
	assert_eq(UpgradeCatalog.max_level(&"no_such_upgrade"), 0)


func test_categories_follow_the_weapons() -> void:
	assert_eq(UpgradeCatalog.find(&"fists").weapon(), &"")
	assert_eq(UpgradeCatalog.find(&"taser_chain").weapon(), &"taser")
	assert_eq(UpgradeCatalog.find(&"pistol_mag").weapon(), &"pistol")
	for entry in UpgradeCatalog.all():
		assert_true(UpgradeCatalog.CATEGORIES.has(entry.category), str(entry.id))


func test_names_and_descriptions_are_translated() -> void:
	for entry in UpgradeCatalog.all():
		assert_ne(tr(entry.name_key()), entry.name_key())
		assert_ne(tr(entry.desc_key()), entry.desc_key())
	for category in UpgradeCatalog.CATEGORIES:
		var key := UpgradeCatalog.category_key(category)
		assert_ne(tr(key), key)
