extends TestCase


func _hit(amount: float, weapon: StringName = &"", impact: float = 0.0) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC)
	info.weapon = weapon
	info.impact = impact
	return info


func test_a_hit_weighs_what_its_weapon_says() -> void:
	assert_almost_eq(HitFeel.weight(_hit(20.0, &"pistol", 0.3)), 0.3)
	assert_almost_eq(HitFeel.weight(_hit(60.0, &"harpoon")), FeelProfile.of(&"harpoon").hit_weight, 0.0001,
			"a projectile's hit: its weapon's profile")
	var blast := _hit(14.0, &"hwacha")
	blast.explosive = true
	assert_almost_eq(HitFeel.weight(blast), FeelProfile.of(&"hwacha").blast_weight, 0.0001, "a blast: its blast weight")
	assert_almost_eq(HitFeel.weight(_hit(40.0)), 0.5, 0.0001, "an exhibit's blow: by its damage")
	var burn := _hit(6.0, &"flare")
	burn.periodic = true
	assert_eq(HitFeel.weight(burn), 0.0, "a tick of burning weighs nothing")


func test_tiers_from_a_pistol_round_to_a_shotgun_blast() -> void:
	assert_eq(HitFeel.tier(FeelProfile.of(&"pistol").hit_weight), HitFeel.Tier.FLINCH)
	assert_eq(HitFeel.tier(FeelProfile.of(&"gatling").hit_weight), HitFeel.Tier.FLINCH)
	assert_eq(HitFeel.tier(FeelProfile.of(&"fists").hit_weight), HitFeel.Tier.HEAVY)
	assert_eq(HitFeel.tier(FeelProfile.of(&"shotgun").hit_weight), HitFeel.Tier.STAGGER, "every pellet in")
	assert_eq(HitFeel.tier(FeelProfile.of(&"shotgun").hit_weight * 0.3), HitFeel.Tier.FLINCH, "three pellets of ten")
	assert_eq(HitFeel.tier(FeelProfile.of(&"rifle_hunt").hit_weight), HitFeel.Tier.STAGGER)


func test_heavier_hits_lean_further_and_steady_exhibits_less() -> void:
	assert_gt(HitFeel.tilt(1.0, 0.0), HitFeel.tilt(0.3, 0.0) * 2.0)
	assert_lt(HitFeel.tilt(1.0, 0.7), HitFeel.tilt(1.0, 0.0) * 0.6, "a knight barely rocks")
	assert_gt(HitFeel.tilt(0.1, 0.0), 0.0, "even a gatling round shows")
	assert_lt(HitFeel.tilt(1.0, 0.0), HitReaction.MAX_TILT + 0.0001)


func test_only_heavy_hits_stagger_and_only_exhibits_that_give_way() -> void:
	assert_true(HitFeel.staggers(1.0, 0.0))
	assert_true(HitFeel.staggers(0.9, 0.35), "a mummy reels from a harpoon")
	assert_false(HitFeel.staggers(0.3, 0.0), "a pistol round does not")
	assert_false(HitFeel.staggers(1.0, 0.7), "a knight stands")
	assert_false(HitFeel.staggers(1.0, 1.0), "a totem stands")


func test_heavy_kills_stop_time_and_shake_more_than_light_ones() -> void:
	assert_eq(HitFeel.kill_hitstop(0.3, false), 0.0, "a pistol kill just crumbles")
	assert_gt(HitFeel.kill_hitstop(1.0, false), HitFeel.kill_hitstop(0.3, true))
	assert_gt(HitFeel.kill_shake(1.0, true), HitFeel.kill_shake(0.3, true))
	assert_eq(HitFeel.kill_shake(0.12, false), 0.0)
	assert_eq(HitFeel.hit_hitstop(0.3), 0.0)
	assert_gt(HitFeel.hit_hitstop(1.0), 0.0)
	assert_lt(HitFeel.hit_hitstop(1.0), 0.05, "a blink, not a freeze")


func test_a_heavy_kill_throws_the_pieces_back_and_a_light_one_crumbles() -> void:
	var light := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 10.0, 60.0, false, 0.3)
	var heavy := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 10.0, 60.0, false, 1.0)
	assert_gt(heavy.impulse, light.impulse * 1.5, "faster pieces")
	assert_gt(heavy.push, light.push * 2.0, "thrown back along the shot")
	assert_gt(heavy.lift, light.lift)
	assert_lt(light.impulse, 2.5, "a light kill's pieces drop by the body")


func test_a_heavy_weapon_tears_an_exhibit_apart_sooner() -> void:
	# a rifle round through a wax figure with a third of its health left over
	assert_true(GibPlanner.plan(ExhibitMaterial.Kind.WAX, 25.0, 60.0, false, 1.0).gibbed)
	assert_false(GibPlanner.plan(ExhibitMaterial.Kind.WAX, 25.0, 60.0, false, 0.3).gibbed, "a pistol's does not")
	assert_false(GibPlanner.plan(ExhibitMaterial.Kind.WAX, 25.0, 60.0, false).gibbed, "without a force: as ever")
