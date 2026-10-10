extends TestCase
## The night's goal, part two: the crystal bursts out and flies (waiting
## for the guard), wakes the T-Rex, the hall shuts, supplies and summoned
## wax figures, the boss falls, the grate rolls aside and the dark below
## ends the demo. Also the epilogue night after the demo was won.

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


## The night without its exhibits: this is about the goal, and a guard
## teleported through awake rooms could fall before it is reached.
func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	for exhibit in museum.enemies_root.get_children():
		exhibit.free()
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## A new game on night [param night] whose crystal lies in [param case].
func _game_with_crystal_in(case_marker: StringName, night: int = 2) -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 400:
		GameState.seed_base = base
		if NightDirector.plan(GameState.night_seed(), night, description).crystal_case == case_marker:
			return
	fail("no seed puts the crystal in " + case_marker)


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _cut_the_power() -> void:
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(1.6)


## The guard walks up to the beating crystal (within 3 m).
func _approach_the_crystal() -> void:
	var crystal := museum.objective.crystal
	var toward_hall := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.global_position = _floor_under(crystal.global_position + toward_hall * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05
	await physics_frames(3)


## Follows the flying crystal (stays under it) until it arrives.
func _follow_the_crystal() -> bool:
	for i in 60 * 40:
		var crystal := museum.objective.crystal
		if crystal == null or not is_instance_valid(crystal):
			return true
		if i % 6 == 0:
			museum.player.global_position = _floor_under(crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	return false


func test_the_crystal_bursts_out_waits_for_the_guard_and_wakes_the_boss() -> void:
	_game_with_crystal_in(&"crystal_case_gallery")
	_museum()
	await physics_frames(2)
	var boss := museum.objective.boss
	assert_true(boss.is_dormant())
	assert_false(museum.hud.boss_bar_shown())
	await _cut_the_power()
	var crystal := museum.objective.crystal
	var glass := crystal.case_glass
	assert_gt(glass.size(), 0, "the case's panes are known")
	await _approach_the_crystal()
	assert_eq(museum.objective.stage, NightObjective.Stage.FLIGHT)
	assert_eq(RunState.crystal_phase, NightState.CrystalPhase.FLYING)
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FOLLOW"))
	for pane in glass:
		assert_false(pane.visible, "the glass burst")
	# the guard runs off: it waits in the air
	await _seconds(1.5)
	museum.player.global_position = Vector3(0, 0.1, 57)
	await physics_frames(10)
	var held := crystal.global_position
	await _seconds(1.0)
	assert_true(crystal.is_waiting())
	assert_lt(crystal.global_position.distance_to(held), 0.05, "no further while he is away")
	# he follows: it flies on to the ribs
	var woke := watch(Events.boss_awakened)
	assert_true(await _follow_the_crystal(), "the crystal arrived")
	await physics_frames(2)
	assert_false(boss.is_dormant(), "the T-Rex woke")
	assert_eq(woke.size(), 1)
	assert_eq(museum.objective.stage, NightObjective.Stage.BOSS)
	assert_eq(RunState.crystal_phase, NightState.CrystalPhase.EMBEDDED)
	assert_true(boss.skeleton.crystal_present)
	assert_true(museum.hud.boss_bar_shown())
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_BOSS"))
	assert_eq(museum.objective.supplies().size(), 4, "ammo and a medkit for the fight")


func test_the_hall_shuts_for_the_fight_and_the_roar_calls_wax_figures() -> void:
	_game_with_crystal_in(&"crystal_case_hall")
	_museum()
	await physics_frames(2)
	await _cut_the_power()
	await _approach_the_crystal()
	assert_true(await _follow_the_crystal())
	museum.player.global_position = Vector3(0, 0.1, 10)
	await _seconds(1.5)
	for id in NightObjective.HALL_DOORS:
		var door: Door = museum.lobby.doors[id]
		assert_true(door.locked, "%s locked" % id)
		assert_false(door.is_open, "%s shut" % id)
	var called := museum.objective.summon_wax(4)
	assert_gt(called.size(), 0)
	assert_lt(called.size(), 5)
	for node in called:
		var wax := node as Enemy
		assert_true(wax is WaxFigure)
		assert_ne(wax.brain.state, EnemyBrain.State.DORMANT)
		assert_eq(museum.lobby.room_at(wax.global_position + Vector3.UP * 0.2), &"hall")
	var before := museum.objective.supplies().size()
	museum.objective.boss.phase_changed.emit(2)
	assert_gt(museum.objective.supplies().size(), before, "more supplies at phase 2")


func test_the_fallen_boss_opens_the_way_down_and_the_dark_ends_the_demo() -> void:
	_game_with_crystal_in(&"crystal_case_armory")
	GameState.save_game()
	_museum()
	await physics_frames(2)
	await _cut_the_power()
	await _approach_the_crystal()
	assert_true(await _follow_the_crystal())
	museum.player.global_position = Vector3(0, 0.1, 12)
	await physics_frames(3)
	var boss := museum.objective.boss
	boss.take_zone_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	assert_true(boss.is_dead())
	assert_true(GameState.demo_complete)
	assert_eq(GameState.stats["bosses"], 1)
	assert_eq(RunState.crystal_phase, NightState.CrystalPhase.BROKEN)
	assert_eq(museum.objective.stage, NightObjective.Stage.DESCEND)
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_DESCEND"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.demo_complete, "saved at once")
	await _seconds(NightObjective.GRATE_DELAY + 3.0)
	for id in NightObjective.HALL_DOORS:
		var door: Door = museum.lobby.doors[id]
		assert_false(door.locked)
		assert_true(door.is_open)
	var grate: Door = museum.lobby.doors[&"grate"]
	assert_true(grate.is_open, "the grate rolled aside")
	assert_true(museum.objective.exit.armed)
	var ended := watch(museum.demo_end_requested)
	# down the stairs into the dark
	museum.player.global_position = Vector3(0, 0.1, -24.0)
	await physics_frames(3)
	assert_eq(ended.size(), 0, "not yet at the top of the stairs")
	museum.player.global_position = Vector3(0, -2.0, -31.5)
	await physics_frames(8)
	assert_eq(ended.size(), 1)
	assert_eq(museum.objective.stage, NightObjective.Stage.DONE)


func test_the_woken_t_rex_comes_down_off_its_pedestal_for_the_guard() -> void:
	_game_with_crystal_in(&"crystal_case_hall")
	_museum()
	await physics_frames(2)
	museum.player.health.max_health = 100000.0
	museum.player.health.heal(100000.0)
	var boss := museum.objective.boss
	boss.wake()
	museum.player.global_position = Vector3(0, 0.1, 10)
	var lowest := boss.global_position.y
	var nearest := INF
	for i in 60 * 12:
		await get_tree().physics_frame
		museum.player.health.heal(100000.0)
		lowest = minf(lowest, boss.global_position.y)
		nearest = minf(nearest, Vector2(boss.global_position.x, boss.global_position.z).distance_to(Vector2(0, 10)))
	assert_lt(lowest, 0.6, "down on the hall floor (the pedestal is 1.2 m)")
	assert_lt(nearest, 9.0, "it came for the guard")


func test_after_the_demo_a_night_is_its_epilogue() -> void:
	GameState.new_game()
	GameState.demo_complete = true
	_museum()
	await physics_frames(3)
	assert_null_boss()
	assert_eq(museum.objective.stage, NightObjective.Stage.DESCEND)
	assert_true((museum.lobby.doors[&"grate"] as Door).is_open)
	assert_true(museum.objective.exit.armed)
	assert_eq(museum.objective.fuse_pickups.size(), 0)


func assert_null_boss() -> void:
	assert_true(museum.objective.boss == null, "no boss after the demo")
