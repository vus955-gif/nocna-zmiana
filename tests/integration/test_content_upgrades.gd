extends TestCase
## The expansion's eight upgrades on real weapons and a real guard, their
## persistence, and the terminal listing all of them (24 with Floor I).

func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func _state(id: StringName, levels: Dictionary) -> WeaponState:
	var state := WeaponState.new(_weapon(id))
	state.apply_upgrades(levels)
	return state


func test_deep_pockets_grow_every_reserve_by_a_quarter_per_level() -> void:
	var expected := {&"pistol": [150, 188, 225], &"shotgun": [50, 63, 75], &"gatling": [360, 450, 540], &"flare": [8, 10, 12]}
	for id in expected:
		for level in 3:
			assert_eq(_state(id, {&"pockets": level}).data.max_reserve, expected[id][level], "%s level %d" % [id, level])
	assert_eq(_state(&"taser", {&"pockets": 2}).data.max_reserve, 0, "a battery has no reserve")
	assert_eq(_weapon(&"pistol").max_reserve, 150, "the shared resource is untouched")


func test_greased_crank_spins_up_in_0_2_s() -> void:
	var gun := _state(&"gatling", {&"gatling_spin": 1})
	var frames := 0
	for i in 60:
		gun.tick(1.0 / 60.0)
		gun.pull_trigger()
		if gun.can_fire():
			frames = i
			break
	assert_almost_eq(frames / 60.0, 0.2, 1.5 / 60.0)


func test_longer_belt_holds_200_from_the_next_belt_on() -> void:
	var gun := _state(&"gatling", {})
	gun.reserve = 400
	gun.apply_upgrades({&"gatling_belt": 1})
	assert_eq(gun.data.magazine_size, 200)
	assert_eq(gun.magazine, 120, "the belt in the gun stays")
	gun.magazine = 1
	gun.spin = 1.0
	gun.fire()
	assert_eq(gun.magazine, 200, "the next belt is a long one")


func test_magnesium_burns_8_s_and_lights_20_s() -> void:
	var data := _state(&"flare", {&"flare_burn": 1}).data
	assert_eq(data.burn_time, 8.0)
	assert_eq(data.light_time, 20.0)
	var light := FlareLight.stick(self, Vector3.ZERO, Vector3.UP, null, data, null)
	assert_eq(light.light_time, 20.0)
	assert_eq(light.burn_time, 8.0)


func test_twin_barrel_holds_two_flares() -> void:
	var user := Node3D.new()
	add_child(user)
	var holder := WeaponHolder.new()
	holder.user = user
	user.add_child(holder)
	holder.apply_upgrades({&"flare_twin": 1})
	var state := holder.give(_weapon(&"flare"))
	state.reserve = 4
	assert_eq(state.magazine, 2)
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_false(state.is_reloading(), "one more in the barrel")
	await physics_frames(30)
	assert_true(holder.try_fire())
	assert_true(state.is_reloading(), "both fired: reload")


func test_dust_magnet_pulls_from_9_m() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	var guard := Player.new()
	add_child(guard)
	assert_eq(guard.dust_magnet_radius, 6.0)
	guard.apply_upgrades({&"dust_magnet": 1})
	assert_eq(guard.dust_magnet_radius, 9.0)
	guard.apply_upgrades({&"dust_magnet": 2})
	assert_eq(guard.dust_magnet_radius, 12.0)
	guard.apply_upgrades({&"dust_magnet": 1})
	var values: Array[int] = [2]
	var motes := DustMote.burst(self, Vector3(0, 1.1, -8), values, guard)
	var collected := watch(motes[0].collected)
	await physics_frames(150)
	assert_eq(collected.size(), 1, "flew 8 m to him")


func test_without_the_magnet_dust_8_m_away_waits() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	var guard := Player.new()
	add_child(guard)
	var values: Array[int] = [2]
	var motes := DustMote.burst(self, Vector3(0, 1.1, -8), values, guard)
	var collected := watch(motes[0].collected)
	await physics_frames(150)
	assert_eq(collected.size(), 0)


func test_second_wind_saves_once_a_night_with_a_second_of_grace() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	var guard := Player.new()
	add_child(guard)
	guard.apply_upgrades({&"second_wind": 1})
	assert_true(guard.second_wind_ready())
	guard.take_damage(DamageInfo.make(150.0, DamageInfo.Kind.BLUNT))
	assert_true(guard.alive, "the killing blow leaves him standing")
	assert_eq(guard.health.current, 1.0)
	assert_true(guard.invulnerable())
	assert_true(RunState.is_used(Player.SECOND_WIND), "used for tonight")
	var fx: SecondWindFx = null
	for child in guard.get_children():
		if child is SecondWindFx:
			fx = child
	assert_not_null(fx, "the world greys out")
	guard.take_damage(DamageInfo.make(30.0, DamageInfo.Kind.BLUNT))
	assert_eq(guard.health.current, 1.0, "a second of grace")
	await physics_frames(65)
	assert_false(guard.invulnerable())
	guard.take_damage(DamageInfo.make(30.0, DamageInfo.Kind.BLUNT))
	assert_false(guard.alive, "only once a night")


func test_second_wind_survives_continue_but_not_a_new_night() -> void:
	RunState.mark_used(Player.SECOND_WIND)
	var snapshot := NightRules.progress_snapshot(GameState, RunState)
	assert_true((snapshot["used"] as Array).has("second_wind"), "saved with the night")
	RunState.begin_night(7)
	assert_false(RunState.is_used(Player.SECOND_WIND), "a new night brings it back")


func test_no_second_wind_without_the_upgrade() -> void:
	var guard := Player.new()
	add_child(guard)
	guard.take_damage(DamageInfo.make(150.0, DamageInfo.Kind.BLUNT))
	assert_false(guard.alive)


func _keen_guard() -> Player:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	var guard := Player.new()
	add_child(guard)
	guard.apply_upgrades({&"keen_ear": 1})
	return guard


func _attacker(at: Vector3, guard: Player) -> WaxFigure:
	var figure := WaxFigure.new()
	figure.position = at
	figure.target = guard
	add_child(figure)
	figure.face(guard.global_position)
	figure.brain.wake()
	return figure


func test_keen_ear_points_at_an_attack_from_behind() -> void:
	var guard := _keen_guard()
	assert_not_null(guard.threat_indicator)
	_attacker(Vector3(0.4, 0, 1.3), guard)   # right behind him (he looks at -Z)
	var shown := false
	var bearing := 0.0
	for i in 120:
		await get_tree().physics_frame
		if not guard.threat_indicator.warnings().is_empty():
			shown = true
			bearing = guard.threat_indicator.warnings()[0]["bearing"]
			break
	assert_true(shown, "a warning shows")
	assert_gt(absf(bearing), PI * 0.75, "pointing behind: %.2f" % bearing)


func test_keen_ear_stays_quiet_for_attacks_in_front() -> void:
	var guard := _keen_guard()
	var figure := _attacker(Vector3(0, 0, -1.3), guard)
	for i in 120:
		await get_tree().physics_frame
		assert_true(guard.threat_indicator.warnings().is_empty())
		if figure.brain.has_struck():
			break


## "In front" is what the guard can see: half his view's width and a
## margin. An attack beyond that, though less than 90 degrees round,
## still gets a warning.
func test_keen_ear_warns_of_an_attack_just_out_of_sight() -> void:
	# a 16:9 screen at 70 degrees: 51 degrees to the edge, 61 with the margin
	assert_almost_eq(rad_to_deg(ThreatIndicator.half_view(70.0, 16.0 / 9.0)), 61.2, 0.2)
	assert_almost_eq(rad_to_deg(ThreatIndicator.half_view(90.0, 2.0, true)), 55.0, 0.01, "a horizontal field of view")
	var guard := _keen_guard()
	var edge := guard.threat_indicator.view_half_angle()
	var beyond := edge + deg_to_rad(8.0)
	_attacker(Vector3(sin(beyond), 0, -cos(beyond)) * 1.3, guard)
	var shown := false
	for i in 120:
		await get_tree().physics_frame
		if not guard.threat_indicator.warnings().is_empty():
			shown = true
			break
	assert_true(shown, "just past the edge of the view: out of sight")


func test_keen_ear_stays_quiet_for_an_attack_just_in_sight() -> void:
	var guard := _keen_guard()
	var within := guard.threat_indicator.view_half_angle() - deg_to_rad(15.0)
	var figure := _attacker(Vector3(sin(within), 0, -cos(within)) * 1.3, guard)
	for i in 120:
		await get_tree().physics_frame
		assert_true(guard.threat_indicator.warnings().is_empty())
		if figure.brain.has_struck():
			break


func test_no_indicator_without_keen_ear() -> void:
	var guard := Player.new()
	add_child(guard)
	guard.apply_upgrades({})
	assert_eq(guard.threat_indicator, null)


func test_new_upgrade_levels_are_saved_and_loaded() -> void:
	GameState.new_game()
	var levels := {&"pockets": 2, &"second_wind": 1, &"dust_magnet": 1, &"keen_ear": 1,
			&"gatling_spin": 1, &"gatling_belt": 1, &"flare_burn": 1, &"flare_twin": 1}
	for id in levels:
		GameState.upgrades[id] = levels[id]
	assert_true(GameState.save_game())
	GameState.reset()
	assert_true(GameState.load_game())
	for id in levels:
		assert_eq(GameState.upgrade_level(id), levels[id], str(id))


func test_buying_needs_the_dust_and_respects_max_levels() -> void:
	GameState.new_game()
	RunState.begin_night(1)
	RunState.add_dust(200, false)
	assert_true(GameState.buy_upgrade(&"pockets", RunState))
	assert_true(GameState.buy_upgrade(&"pockets", RunState))
	assert_false(GameState.buy_upgrade(&"pockets", RunState), "maxed at 2")
	assert_eq(RunState.dust, 110)
	assert_false(GameState.buy_upgrade(&"second_wind", RunState), "110 < 120")


func test_the_terminal_lists_all_twenty_four() -> void:
	GameState.new_game()
	RunState.begin_night(1)
	var menu := UpgradeMenu.new()
	add_child(menu)
	menu.open(GameState, RunState)
	assert_eq(menu._row_ids.size(), 24)
	for id in [&"pockets", &"second_wind", &"dust_magnet", &"keen_ear", &"gatling_spin", &"gatling_belt", &"flare_burn", &"flare_twin",
			&"rifle_bolt", &"rifle_expand", &"harpoon_reel", &"harpoon_barbs", &"hwacha_fuse", &"hwacha_volley"]:
		assert_true(menu._row_ids.has(id), str(id))
	menu.select(menu._row_ids.find(&"gatling_belt"))
	assert_true(menu._status.text.contains(tr("WEAPON_GATLING")), "tells he still needs the gatling: " + menu._status.text)
	menu.close()
