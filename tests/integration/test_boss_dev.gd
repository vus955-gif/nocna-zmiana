extends TestCase
## The boss dev arena: armed guard, dormant T-Rex on its pedestal, summons,
## dev keys.

var dev: BossDev


func before_each() -> void:
	GameInput.capture_allowed = false
	dev = (load("res://src/enemies/trex/boss_dev.tscn") as PackedScene).instantiate() as BossDev
	add_child(dev)


func after_each() -> void:
	GameInput.capture_allowed = true


func test_guard_has_every_weapon_with_full_pockets() -> void:
	await physics_frames(3)
	assert_eq(dev.player.weapons.owned.size(), 3)
	for state in dev.player.weapons.owned:
		if state.data.ammo_mode == WeaponData.AmmoMode.MAGAZINE:
			assert_eq(state.reserve, state.data.max_reserve, str(state.data.id))


func test_the_boss_sleeps_on_its_pedestal_in_profile() -> void:
	await physics_frames(40)
	assert_true(dev.boss.is_dormant())
	assert_true(dev.boss.is_on_floor())
	assert_almost_eq(dev.boss.global_position.y, BossDev.PEDESTAL_SIZE.y, 0.1)
	assert_almost_eq(absf(dev.boss.global_basis.z.x), 1.0, 0.01, "faces along the hall's width")


func test_woken_boss_steps_down_and_hunts() -> void:
	await physics_frames(10)
	dev.boss.wake()
	await physics_frames(int((TRexBrain.WAKE_TIME + 1.5) * 60.0))
	assert_lt(dev.boss.global_position.y, 0.3, "off the pedestal")
	assert_true(dev.boss.brain.is_awake())


func test_the_roar_calls_awake_wax_figures_from_the_walls() -> void:
	var called := dev.boss.summon.call(4) as Array
	assert_eq(called.size(), 4)
	assert_eq(dev.exhibits.get_child_count(), 4)
	for figure in called:
		assert_true(figure is WaxFigure)
		assert_ne((figure as WaxFigure).brain.state, EnemyBrain.State.DORMANT)


func test_next_phase_key_walks_the_boss_through_the_fight() -> void:
	dev.boss_to_next_phase()
	assert_eq(dev.boss.phase, 2)
	dev.boss_to_next_phase()
	assert_eq(dev.boss.phase, 3)
	dev.boss_to_next_phase()
	assert_true(dev.boss.is_dead())


func test_reset_brings_a_fresh_dormant_boss() -> void:
	var first := dev.boss
	dev.boss_to_next_phase()
	var second := dev.reset_boss()
	assert_ne(second, first)
	assert_true(second.is_dormant())
	assert_eq(second.health.current, second.max_health)


func test_leaving_the_arena_before_the_respawn_is_harmless() -> void:
	await physics_frames(3)
	var kill := DamageInfo.make(1000.0, DamageInfo.Kind.BLUNT, null)
	dev.player.take_damage(kill)
	assert_false(dev.player.alive)
	remove_child(dev)   # the arena is left while the respawn waits
	await get_tree().create_timer(BossDev.RESPAWN_DELAY + 0.3).timeout
	assert_false(dev.player.alive, "no respawn outside the tree")
	dev.free()


func test_busts_spawn_awake() -> void:
	var bust := dev.spawn_bust(BossDev.BUST_POINTS[0], true)
	assert_ne(bust.brain.state, EnemyBrain.State.DORMANT)
	assert_eq(bust.get_parent(), dev.exhibits)
