extends TestCase
## EnvRules: what a hit does to the museum's reactive props and when a
## tool goes off (plan docs/superpowers/plans/2026-10-21-srodowisko-walka.md).


func _hit(amount: float, weapon: StringName = &"", kind: DamageInfo.Kind = DamageInfo.Kind.BALLISTIC) -> DamageInfo:
	var info := DamageInfo.make(amount, kind)
	info.weapon = weapon
	if FeelProfile.has(weapon):
		info.impact = FeelProfile.of(weapon).hit_weight
	return info


func _blast(amount: float = 20.0, weapon: StringName = &"flare") -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.FIRE)
	info.weapon = weapon
	info.explosive = true
	return info


func test_every_fall_that_can_hurt_is_warned_for_at_least_the_games_telegraph() -> void:
	assert_true(EnvRules.MIN_WARNING >= 0.6, "the game's rule: >= 0.6 s")
	assert_true(EnvRules.TOOL_WARNING >= EnvRules.MIN_WARNING)
	assert_true(EnvRules.PROP_WARNING >= EnvRules.MIN_WARNING)
	assert_true(EnvRules.TOOL_WARNING > EnvRules.PROP_WARNING, "a heavy tool creaks longer than a lamp")


func test_glass_breaks_to_any_real_hit_but_not_to_a_taser_arc_or_a_burning_tick() -> void:
	assert_true(EnvRules.breaks_glass(_hit(20.0, &"pistol")))
	assert_true(EnvRules.breaks_glass(_hit(7.0, &"gatling")))
	assert_true(EnvRules.breaks_glass(_hit(15.0, &"fists", DamageInfo.Kind.BLUNT)))
	assert_true(EnvRules.breaks_glass(_blast()))
	assert_false(EnvRules.breaks_glass(_hit(4.0, &"taser", DamageInfo.Kind.ELECTRIC)), "an arc crackles on glass")
	var tick := _hit(3.0, &"hwacha", DamageInfo.Kind.FIRE)
	tick.periodic = true
	assert_false(EnvRules.breaks_glass(tick))
	assert_false(EnvRules.breaks_glass(_hit(0.0, &"pistol")))


func test_a_bulb_bursts_at_once_a_hanging_lamp_swings_then_falls() -> void:
	assert_true(EnvRules.lamp_falls(&"bulb", 20.0, _hit(20.0, &"pistol")), "one round puts a bare bulb out")
	assert_false(EnvRules.lamp_falls(&"ceiling_lamp", 20.0, _hit(20.0, &"pistol")), "a pendant swings")
	assert_true(EnvRules.lamp_falls(&"ceiling_lamp", 40.0, _hit(20.0, &"pistol")), "the second round brings it down")
	assert_true(EnvRules.lamp_falls(&"ceiling_lamp", 9.0, _hit(9.0, &"shotgun")), "a full shotgun blast at once")
	assert_true(EnvRules.lamp_falls(&"lantern", 14.0, _blast(14.0)), "a blast tears it down")
	assert_false(EnvRules.lamp_falls(&"lantern", 7.0, _hit(7.0, &"gatling")))
	assert_true(EnvRules.lamp_bursts(&"bulb"), "a bulb has nothing to fall with")
	assert_false(EnvRules.lamp_bursts(&"ceiling_lamp"))
	assert_gt(EnvRules.swing_speed(_hit(9.0, &"shotgun")), EnvRules.swing_speed(_hit(20.0, &"pistol")), "heavier hits swing it further")
	assert_gt(EnvRules.swing_speed(_hit(7.0, &"gatling")), 0.0)
	assert_lt(EnvRules.swing_speed(_blast(100.0)), EnvRules.MAX_SWING + 0.0001)


func test_a_bust_topples_off_its_plinth_to_a_heavy_hit_or_enough_small_ones() -> void:
	assert_false(EnvRules.bust_topples(20.0, _hit(20.0, &"pistol")))
	assert_true(EnvRules.bust_topples(40.0, _hit(20.0, &"pistol")), "two rounds")
	assert_true(EnvRules.bust_topples(15.0, _hit(15.0, &"fists", DamageInfo.Kind.BLUNT)), "a punch knocks it off")
	assert_true(EnvRules.bust_topples(9.0, _hit(9.0, &"shotgun")))
	assert_true(EnvRules.bust_topples(5.0, _blast(5.0)))
	assert_false(EnvRules.bust_topples(14.0, _hit(7.0, &"gatling")))


func test_a_painting_tilts_further_with_each_hit_and_falls_past_the_limit() -> void:
	var light := EnvRules.painting_tilt(_hit(20.0, &"pistol"))
	assert_gt(light, 1.0)
	assert_gt(EnvRules.painting_tilt(_hit(9.0, &"shotgun")), light, "a heavier hit knocks it further")
	assert_false(EnvRules.painting_falls(light, _hit(20.0, &"pistol")))
	assert_true(EnvRules.painting_falls(EnvRules.PAINTING_FALL_TILT, _hit(20.0, &"pistol")), "tilted past the limit it slips")
	assert_true(EnvRules.painting_falls(0.0, _hit(85.0, &"rifle_hunt")), "a rifle round knocks it off its nail")
	assert_true(EnvRules.painting_falls(0.0, _blast()))


func test_a_banner_tears_down_after_a_few_hits_or_at_once_by_fire_or_a_heavy_hit() -> void:
	assert_false(EnvRules.banner_falls(1, _hit(20.0, &"pistol")))
	assert_false(EnvRules.banner_falls(EnvRules.BANNER_HITS - 1, _hit(20.0, &"pistol")))
	assert_true(EnvRules.banner_falls(EnvRules.BANNER_HITS, _hit(20.0, &"pistol")))
	assert_true(EnvRules.banner_falls(1, _blast()), "fire takes it")
	assert_true(EnvRules.banner_falls(1, _hit(22.0, &"hwacha", DamageInfo.Kind.FIRE)))
	assert_true(EnvRules.banner_falls(1, _hit(85.0, &"rifle_hunt")))


func test_a_shelf_sheds_more_pages_the_harder_it_is_hit() -> void:
	assert_gt(EnvRules.pages_for(_hit(20.0, &"pistol")), 0)
	assert_gt(EnvRules.pages_for(_hit(9.0, &"shotgun")), EnvRules.pages_for(_hit(20.0, &"pistol")))
	assert_gt(EnvRules.pages_for(_blast()), EnvRules.pages_for(_hit(20.0, &"pistol")))
	assert_true(EnvRules.pages_for(_blast(500.0)) <= EnvRules.MAX_PAGES_PER_HIT)


func test_a_tool_goes_off_on_its_tag_at_once_or_on_its_body_after_enough() -> void:
	assert_true(EnvRules.tool_triggered(true, 0.0, _hit(7.0, &"gatling")), "any round on the tag")
	assert_true(EnvRules.tool_triggered(true, 0.0, _hit(4.0, &"taser", DamageInfo.Kind.ELECTRIC)), "even an arc on the bolt")
	assert_false(EnvRules.tool_triggered(false, 20.0, _hit(20.0, &"pistol")), "a round in the body only swings it")
	assert_true(EnvRules.tool_triggered(false, EnvRules.TOOL_BODY_HP, _hit(20.0, &"pistol")), "enough rounds in the body")
	assert_true(EnvRules.tool_triggered(false, 20.0, _blast(20.0)), "a blast beside it")
	var tick := _hit(3.0, &"hwacha", DamageInfo.Kind.FIRE)
	tick.periodic = true
	assert_false(EnvRules.tool_triggered(true, 0.0, tick), "no burning tick sets anything off")


func test_the_guards_own_tool_never_takes_him_below_half_like_his_own_blast() -> void:
	assert_almost_eq(EnvRules.guard_damage(100.0, 100.0, 35.0, true), 35.0)
	assert_almost_eq(EnvRules.guard_damage(60.0, 100.0, 35.0, true), 10.0)
	assert_almost_eq(EnvRules.guard_damage(40.0, 100.0, 35.0, true), 0.0)
	assert_almost_eq(EnvRules.guard_damage(40.0, 100.0, 35.0, false), 35.0, 0.0001, "set off by anyone else: the full blow")
	assert_almost_eq(EnvRules.GUARD_FLOOR, Blast.GUARD_FLOOR, 0.0001, "the same floor as his own blast")


func test_props_are_remembered_for_the_night_under_their_own_prefix() -> void:
	assert_eq(EnvRules.used_id(&"case@egypt_vestibule#0"), &"env:case@egypt_vestibule#0")
	assert_true(String(EnvRules.used_id(&"x")).begins_with(EnvRules.USED_PREFIX))


func test_budgets_are_set() -> void:
	assert_gt(float(EnvRules.ACTIVE_CAP), 4.0)
	assert_gt(float(EnvRules.MAX_PROPS), 100.0)
	assert_true(EnvRules.MAX_ZONES >= EnvRules.MAX_PROPS)
	assert_true(EnvRules.MAX_PIECES_PER_BREAK <= 8, "one break adds at most eight pieces of debris")
