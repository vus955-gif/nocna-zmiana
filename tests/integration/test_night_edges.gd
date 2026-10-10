extends TestCase
## The night's goal at its edges: dawn or death in the middle of the flight
## or the fight, quitting half-way and coming back, havens next to the
## arena, the fight's supplies, the janitor's key on a sealed hall, the
## roar's calls, and what a resumed night tells the music.

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


## The night without its exhibits (a guard teleported through awake rooms
## could fall before the goal is reached).
func _museum(keep_exhibits: bool = false) -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	if not keep_exhibits:
		for exhibit in museum.enemies_root.get_children():
			exhibit.free()
	museum.player.health.max_health = 100000.0
	museum.player.health.heal(100000.0)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


## A new game on night [param night] whose draw passes [param wanted].
func _game_where(night: int, wanted: Callable) -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 600:
		GameState.seed_base = 7000 + base
		if wanted.call(NightDirector.plan(GameState.night_seed(), night, description)):
			return
	fail("no seed draws the night wanted")


func _crystal_in_the_hall(config: NightConfig) -> bool:
	return config.crystal_case == &"crystal_case_hall"


## Both fuses in, the guard 1.8 m from the beating crystal: it bursts out.
func _to_flight() -> void:
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(2.0)
	var crystal := museum.objective.crystal
	var toward := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.global_position = _floor_under(crystal.global_position + toward * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05
	await physics_frames(4)


## Follows the flying crystal until it lodges in the T-Rex.
func _to_the_fight() -> void:
	await _to_flight()
	for i in 60 * 45:
		if not is_instance_valid(museum.objective.crystal):
			break
		if i % 6 == 0:
			museum.player.global_position = _floor_under(museum.objective.crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	museum.player.global_position = Vector3(0, 0.1, 12)
	await physics_frames(3)


func _dawn() -> void:
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.05
	await physics_frames(3)


func _resume() -> void:
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(3)


# --- dawn -----------------------------------------------------------------

func test_dawn_stops_the_crystal_in_its_flight() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_flight()
	assert_eq(museum.objective.stage, NightObjective.Stage.FLIGHT)
	var woke := watch(Events.boss_awakened)
	await _dawn()
	var crystal := museum.objective.crystal
	var held := crystal.global_position
	for i in 60 * 3:
		museum.player.global_position = _floor_under(crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	assert_eq(museum.objective.process_mode, Node.PROCESS_MODE_DISABLED, "the goal stands still at dawn")
	assert_lt(crystal.global_position.distance_to(held), 0.01, "the crystal hangs where dawn found it")
	assert_eq(woke.size(), 0, "the T-Rex sleeps on")
	assert_eq(museum.objective.stage, NightObjective.Stage.FLIGHT)


func test_a_boss_killed_after_dawn_does_not_count() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_the_fight()
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS)
	await _dawn()
	var night_after_dawn := GameState.night
	var boss := museum.objective.boss
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await physics_frames(5)
	assert_eq(GameState.stats["bosses"], 0, "no victory after dawn")
	assert_false(GameState.demo_complete)
	assert_eq(GameState.night, night_after_dawn, "the night moved on once, at dawn")
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS, "no way down opens")


func test_dawn_takes_the_guards_hands_at_once_and_no_dust_goes_astray() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	museum.player.global_position = Vector3(0, 0.1, 30)
	RunState.add_dust(20, false)
	await _dawn()
	assert_false(GameInput.gameplay_input(), "no more input from the guard at 6:00")
	assert_eq(GameState.run_dust, 20)
	# a mote right in front of him stays where it is: it could not be saved
	var motes := museum.dust_dropper.drop(museum.player.global_position + Vector3(0.0, 1.0, -0.5), 9)
	await _seconds(1.5)
	assert_eq(RunState.dust, 20, "nothing collected after the save")
	assert_eq(GameState.run_dust, 20)
	assert_true(is_instance_valid(motes[0]))
	var healthy := museum.player.health.current
	museum.player.health.apply_damage(10.0)
	museum._on_haven_entered(museum.player, &"security")
	assert_lt(museum.player.health.current, healthy, "no haven rests the guard after dawn")
	museum._on_terminal_opened(museum.player)
	assert_false(museum.upgrade_menu.is_open, "and no terminal opens")


# --- death and quitting in the middle -------------------------------------

func test_death_in_the_fight_ends_the_night_and_the_fallen_boss_does_not_count() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_the_fight()
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS)
	museum.player.health.apply_damage(museum.player.health.current + 1.0)
	await physics_frames(2)
	assert_eq(GameState.night, 3, "death moved the night on")
	assert_eq(GameState.night_progress, {}, "nothing of it is resumed")
	var boss := museum.objective.boss
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await physics_frames(3)
	assert_eq(GameState.stats["bosses"], 0)
	assert_false(GameState.demo_complete)


func test_quitting_during_the_flight_comes_back_to_the_beating_crystal() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_flight()
	assert_eq(museum.objective.stage, NightObjective.Stage.FLIGHT)
	await _resume()
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING)
	assert_eq(museum.objective.crystal.phase, CrystalRelic.Phase.PULSING)
	assert_true(museum.objective.boss.is_dormant())


func test_quitting_during_the_fight_starts_it_over_without_its_supplies() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_the_fight()
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS)
	assert_eq(museum.objective.supplies().size(), 4)
	museum.objective.boss.phase_changed.emit(2)
	assert_eq(museum.objective.supplies().size(), 6)
	await _resume()
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING, "the fight starts over")
	assert_true(museum.objective.boss.is_dormant())
	for id in NightObjective.HALL_DOORS:
		assert_false((museum.lobby.doors[id] as Door).locked, "%s open again" % id)
	await _to_the_fight()
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS)
	assert_eq(museum.objective.supplies().size(), 0, "the first supplies came once tonight")
	museum.objective.boss.phase_changed.emit(2)
	assert_eq(museum.objective.supplies().size(), 0, "so did the second")
	museum.objective.boss.phase_changed.emit(3)
	assert_eq(museum.objective.supplies().size(), 3, "the third phase was never reached before")


# --- the fight ------------------------------------------------------------

func test_no_haven_rests_the_guard_while_the_boss_is_awake() -> void:
	_game_where(2, _crystal_in_the_hall)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _to_the_fight()
	museum.player.health.apply_damage(50.0)
	var hurt := museum.player.health.current
	museum._on_haven_entered(museum.player, &"closet")
	assert_eq(museum.player.health.current, hurt, "no healing next to the arena")
	assert_eq(museum.hud.toast_text(), tr("HUD_NO_REST_BOSS").to_upper())


func test_the_fights_supplies_are_ammo_for_the_guns_he_has() -> void:
	_game_where(2, _crystal_in_the_hall)
	_museum()
	await physics_frames(2)
	# fists and the taser only: medkits instead of ammo
	assert_eq(museum.supply_for_guard(&"bullets"), &"medkit")
	assert_eq(museum.supply_for_guard(&"shells"), &"medkit")
	assert_eq(museum.supply_for_guard(&"medkit"), &"medkit")
	museum.player.weapons.give(load("res://src/weapons/data/shotgun.tres"))
	assert_eq(museum.supply_for_guard(&"bullets"), &"shells", "shells for the shotgun he has")
	assert_eq(museum.supply_for_guard(&"shells"), &"shells")
	museum.player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	assert_eq(museum.supply_for_guard(&"bullets"), &"bullets")
	await _to_the_fight()
	var kinds := {}
	for pickup: Pickup in museum.objective.supplies():
		kinds[pickup.type] = true
	assert_true(kinds.has(Pickup.Type.BULLETS) and kinds.has(Pickup.Type.SHELLS) and kinds.has(Pickup.Type.MEDKIT))


func test_the_janitors_key_opens_no_hall_door_while_the_hall_is_sealed() -> void:
	_game_where(3, func(config: NightConfig) -> bool: return _crystal_in_the_hall(config) and NightObjective.HALL_DOORS.has(config.locked_door))
	_museum()
	await physics_frames(2)
	var door: Door = museum.lobby.doors[museum.night.locked_door]
	assert_true(door.locked, "tonight's locked door is one of the hall's")
	RunState.artifacts.append(ArtifactCatalog.JANITOR_KEY)
	await _to_the_fight()
	var latch := museum.features.latches[0]
	assert_true(latch.held, "held for the fight")
	latch.interact(museum.player)
	assert_true(door.locked, "the key does not turn")
	assert_false(door.is_open)
	var boss := museum.objective.boss
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await physics_frames(2)
	assert_false(latch.held, "let go after the fight")
	latch.interact(museum.player)
	assert_false(door.locked, "now it turns")


func test_a_blackout_power_cut_lights_no_lamp_for_its_stutter() -> void:
	_game_where(2, func(config: NightConfig) -> bool: return config.modifier == &"blackout")
	_museum()
	await physics_frames(2)
	var lamps: Array[Light3D] = []
	for node in museum.lobby.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MAIN) and NightObjective.DARK_ROOMS.has(node.get_meta(&"room")):
			lamps.append(node)
	assert_gt(lamps.size(), 3)
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	for i in 60:
		for lamp in lamps:
			if lamp.visible:
				fail("a lamp lit up on a blackout night (frame %d)" % i)
				return
		await get_tree().physics_frame
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING)


# --- the roar ---------------------------------------------------------------

func test_what_the_roar_calls_is_worth_one_dust() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	museum.player.global_position = Vector3(0, 0.1, 10)
	for exhibit in museum.objective.summon_raptors(3) + museum.objective.summon_wax(2):
		assert_eq((exhibit as Enemy).dust_value, NightObjective.SUMMONED_DUST)


func test_the_roar_never_lands_a_pack_on_another() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	museum.player.global_position = Vector3(0, 0.1, 0)
	var centres: Array[Vector3] = []
	for i in NightObjective.RAPTOR_SPOTS.size() + 2:
		var pack := museum.objective.summon_raptors(3)
		if pack.is_empty():
			continue
		var centre := Vector3.ZERO
		for raptor: Enemy in pack:
			centre += raptor.global_position
		centre /= pack.size()
		for other in centres:
			assert_gt(Vector2(centre.x - other.x, centre.z - other.z).length(), 3.0, "two packs on one corner")
		centres.append(centre)
	assert_eq(centres.size(), NightObjective.RAPTOR_SPOTS.size(), "one pack per free corner, then none")
	assert_gt(museum.objective.summon(3).size(), 0, "the roar calls wax figures when no corner is free")


# --- a resumed night --------------------------------------------------------

func test_a_resumed_night_tells_the_music_the_power_is_out_and_the_hour_late() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(2.0)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() + 30.0
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	# the soundtrack's contract (NightMood): a museum announces its stage and
	# a witching hour already rung while it sets up, in the frame of its
	# night_started; power_cut is the moment the fuses go in, not a state
	var heard: Array[String] = []
	Events.night_started.connect(func(_night: int, _modifier: StringName) -> void: heard.append("night@%d" % Engine.get_process_frames()))
	Events.objective_changed.connect(func(stage: int) -> void: heard.append("stage%d@%d" % [stage, Engine.get_process_frames()]))
	Events.power_cut.connect(func() -> void: heard.append("power_cut"))
	Events.witching_hour.connect(func() -> void: heard.append("witching@%d" % Engine.get_process_frames()))
	var frame := Engine.get_process_frames()
	_museum()
	await physics_frames(3)
	assert_true(heard.has("night@%d" % frame), str(heard))
	assert_true(heard.has("stage%d@%d" % [NightObjective.Stage.PULSING, frame]), "the power is out: " + str(heard))
	assert_true(heard.has("witching@%d" % frame), "past 3:00: " + str(heard))
	assert_false(heard.has("power_cut"), "no second power cut on Continue: " + str(heard))


func test_full_moon_and_the_witching_hour_each_count_once() -> void:
	_game_where(3, func(config: NightConfig) -> bool: return config.modifier == &"full_moon")
	GameState.save_game()
	_museum(true)
	await physics_frames(2)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() + 10.0
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum(true)
	await physics_frames(3)
	var moon := NightModifiers.FULL_MOON_STATS
	var hour := NightWatch.WITCHING_BOOST
	var checked := 0
	var called := museum.objective.summon_wax(1)
	for exhibit in museum.exhibits():
		var base := NightSpawner.make(&"wax") if exhibit is WaxFigure else exhibit.get_script().new() as Enemy
		assert_almost_eq(exhibit.max_health, base.max_health * moon, 0.001, "%s health" % exhibit.name)
		assert_almost_eq(exhibit.attack_damage, base.attack_damage * moon * hour, 0.001, "%s damage" % exhibit.name)
		assert_almost_eq(exhibit.move_speed, base.move_speed * hour, 0.001, "%s speed" % exhibit.name)
		base.free()
		checked += 1
	assert_gt(checked, 5)
	assert_eq(called.size(), 1)
