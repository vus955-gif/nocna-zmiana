extends TestCase
## The whole night loop without a window: new game -> destroy exhibits ->
## collect Dust -> die -> lantern saved, night 2 -> recover the lantern ->
## haven -> buy an upgrade at the terminal -> it works -> save -> reload ->
## identical state. Museum instances are built inside the test (they ask for
## the next night by signal instead of reloading the scene).

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## Walks (teleports) the guard next to [param exhibits] in turn and
## destroys each, waiting for its Dust to fly over.
func _destroy(exhibits: Array[Enemy]) -> void:
	var guard := museum.player
	for exhibit in exhibits:
		if not is_instance_valid(exhibit):
			continue
		var at := exhibit.global_position
		guard.global_position = at + Vector3(0.0, 0.3, 2.5)
		await physics_frames(2)
		if not is_instance_valid(exhibit):
			continue
		exhibit.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, guard))
		# stand where it stood (next to it may be off a balcony's edge)
		guard.global_position = at + Vector3.UP * 0.3
		await _seconds(1.4)
		guard.heal(1000.0)


func test_full_night_loop() -> void:
	# a new game, night 1
	GameState.new_game()
	GameState.save_game()
	_museum()
	await _seconds(0.3)
	var before := museum.exhibits().size()
	var victims: Array[Enemy] = []
	var exhibit_dust := 0
	for node in museum.enemies_root.get_children():
		var exhibit := node as Enemy
		# enough dormant exhibits for an upgrade later (25 Dust)
		# (wax figures: a knight would block a hit from the wrong side)
		if exhibit is WaxFigure and exhibit.brain.state == EnemyBrain.State.DORMANT and exhibit_dust < 30:
			victims.append(exhibit)
			exhibit_dust += exhibit.dust_value
	await _destroy(victims)
	assert_eq(museum.exhibits().size(), before - victims.size(), "that many fewer exhibits")
	assert_eq(RunState.dust, exhibit_dust, "every mote reached the guard")
	assert_eq(GameState.stats["dust_earned"], exhibit_dust)
	var carried := RunState.dust

	# the guard falls somewhere in the hall
	museum.player.global_position = Vector3(6.0, 0.1, 4.0)
	await physics_frames(12)
	var next := watch(museum.next_night_requested)
	museum.player.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BLUNT))
	await get_tree().create_timer(Museum.DEATH_DELAY + DeathScreen.FADE_TIME + DeathScreen.CLOCK_TIME + 0.6).timeout
	assert_eq(next.size(), 1, "the next night is asked for")
	assert_eq(GameState.night, 2)
	assert_true(GameState.lantern["active"])
	assert_eq(GameState.lantern["dust"], carried)
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_eq(on_disk.night, 2, "death was saved")
	assert_eq(on_disk.lantern["dust"], carried)
	museum.free()

	# night 2: the lantern waits where the guard fell
	_museum()
	await _seconds(0.3)
	assert_eq(RunState.dust, 0, "nothing carried after death")
	assert_not_null(museum.lantern)
	assert_eq(museum.lantern.dust, carried)
	museum.player.global_position = museum.lantern.global_position + Vector3(0.0, 0.1, 0.0)
	await physics_frames(6)
	assert_eq(RunState.dust, carried, "the lantern gave the Dust back")
	assert_false(GameState.lantern["active"])

	# back to the booth a while later: healed and saved
	RunState.time += Museum.REST_COOLDOWN
	museum.player.health.apply_damage(30.0)
	museum.player.global_position = Vector3(0.0, 0.1, 57.0)
	await physics_frames(12)
	assert_eq(museum.player.health.current, 100.0)
	on_disk.load_game()
	assert_eq(on_disk.run_dust, carried)

	# the terminal: buy Fitness (25 Dust; a night with few wax figures tops up)
	if carried < 25:
		RunState.add_dust(25 - carried, false)
		carried = RunState.dust
	var terminal := museum.find_children("*", "UpgradeTerminal", true, false)[0] as UpgradeTerminal
	terminal.interact(museum.player)
	assert_true(museum.upgrade_menu.is_open)
	assert_true(get_tree().paused)
	museum.upgrade_menu.select(museum.upgrade_menu._row_ids.find(&"health"))
	assert_true(museum.upgrade_menu.buy_selected())
	assert_eq(GameState.upgrade_level(&"health"), 1)
	assert_eq(RunState.dust, carried - 25)
	assert_eq(museum.player.health.max_health, 120.0, "the upgrade works at once")
	assert_eq(museum.player.health.current, 120.0)
	museum.upgrade_menu.close()
	assert_false(get_tree().paused)

	# save -> load gives the identical state
	assert_true(NightRules.save_progress(GameState, RunState))
	var reloaded := PersistentState.new()
	add_child(reloaded)
	assert_true(reloaded.load_game())
	var expected := GameState.to_dict()
	var actual := reloaded.to_dict()
	# play time grows with every save; everything else must match exactly
	expected["stats"].erase("play_time")
	actual["stats"].erase("play_time")
	assert_eq(actual, expected)


func test_reloaded_night_restores_upgrades_and_weapons() -> void:
	GameState.new_game()
	GameState.upgrades = {&"health": 2, &"pistol_mag": 1}
	GameState.add_weapon(&"pistol")
	GameState.run_dust = 44
	GameState.save_game()
	GameState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(3)
	assert_eq(museum.player.health.max_health, 140.0)
	assert_eq(museum.player.health.current, 140.0)
	var pistol := museum.player.weapons.state_of(&"pistol")
	assert_not_null(pistol)
	if pistol != null:
		assert_eq([pistol.magazine, pistol.reserve], [18, 24])
	assert_eq(museum.player.weapons.current_state().data.id, &"pistol")
	assert_eq(RunState.dust, 44, "carried Dust survives quitting")
