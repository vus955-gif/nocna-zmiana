extends TestCase
## A whole night without a window, driven through test hooks: the guard
## starts in the booth, takes both fuses, puts them in the fuse box, walks up
## to the beating crystal, follows its flight to the T-Rex, the boss wakes
## and falls (killed through its damage API), the grate opens, the guard
## walks down into the dark and the demo's end screen shows the night. Plus
## a smoke run over many drawn nights.

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


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


## Teleports the guard next to [param target] (on the floor, [param
## distance] m in front of it) and keeps him alive.
func _go_to(target: Node3D, distance: float = 1.2) -> void:
	var front := -target.global_transform.basis.z
	front.y = 0.0
	museum.player.global_position = _floor_under(target.global_position + front.normalized() * distance + Vector3.UP * 0.6) + Vector3.UP * 0.05
	museum.player.heal(1000.0)
	await physics_frames(3)


func test_a_whole_night_from_the_booth_to_the_end_of_the_demo() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	# a guard who cannot fall: the test walks him through awake rooms
	museum.player.health.max_health = 100000.0
	museum.player.health.heal(100000.0)
	await _seconds(0.5)
	var objective := museum.objective
	assert_true(museum.havens[&"security"].contains(museum.player.global_position), "the night starts in the booth")
	assert_eq(objective.stage, NightObjective.Stage.FUSES)
	# the fuses, one per wing
	for wing: StringName in objective.fuse_pickups.keys():
		var fuse: FusePickup = objective.fuse_pickups[wing]
		await _go_to(fuse, 1.0)
		fuse.interact(museum.player)
		await physics_frames(2)
	assert_eq(RunState.fuses_carried, 2)
	# the fuse box by the grate
	await _go_to(objective.fuse_box, 1.2)
	objective.fuse_box.interact(museum.player)
	await _seconds(1.8)
	assert_eq(objective.stage, NightObjective.Stage.PULSING)
	assert_true((museum.lobby.doors[&"grate"] as Door).is_jammed)
	# the crystal: walk up to it, then follow it
	var crystal := objective.crystal
	var toward_hall := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.global_position = _floor_under(crystal.global_position + toward_hall * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05
	await physics_frames(4)
	assert_eq(objective.stage, NightObjective.Stage.FLIGHT)
	var woke := watch(Events.boss_awakened)
	var arrived := false
	for i in 60 * 45:
		if not is_instance_valid(objective.crystal):
			arrived = true
			break
		if i % 6 == 0:
			museum.player.global_position = _floor_under(objective.crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
			museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_true(arrived, "the crystal reached the ribs")
	assert_eq(woke.size(), 1, "the T-Rex woke")
	assert_eq(objective.stage, NightObjective.Stage.BOSS)
	assert_true(museum.hud.boss_bar_shown())
	# the fight, cut short through the boss's damage API
	museum.player.global_position = Vector3(0, 0.1, 12)
	await _seconds(3.5)   # the wake-up roar and the jump off the pedestal
	museum.player.heal(1000.0)
	var boss := objective.boss
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	assert_true(boss.is_dead())
	assert_true(GameState.demo_complete)
	assert_eq(GameState.stats["bosses"], 1)
	# over to the bones: the Dust flies in
	var bones := boss.global_position
	museum.player.global_position = _floor_under(bones + Vector3(0.0, 1.0, 4.0)) + Vector3.UP * 0.05
	await _seconds(2.5)
	assert_gt(RunState.dust, 90, "the boss's Dust flew to the guard")
	await _seconds(NightObjective.GRATE_DELAY + 3.0)
	assert_true((museum.lobby.doors[&"grate"] as Door).is_open)
	assert_false(museum.watch.running, "the clock stopped with the boss")
	# down the stairs into the dark
	var ended := watch(museum.demo_end_requested)
	museum.player.heal(1000.0)
	museum.player.global_position = Vector3(0, 0.1, -25.0)
	await physics_frames(4)
	museum.player.global_position = Vector3(0, -2.0, -31.5)
	await physics_frames(8)
	assert_eq(ended.size(), 1, "the dark ends the demo")
	# the end screen shows this game
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.demo_complete)
	assert_eq(on_disk.stats["bosses"], 1)
	var screen := (load(SceneFlow.DEMO_END) as PackedScene).instantiate() as DemoEnd
	add_child(screen)
	assert_eq(screen.values["nights"].text, "1")
	assert_eq(screen.values["deaths"].text, "0")
	screen.free()


func test_many_drawn_nights_build_and_spawn_cleanly() -> void:
	var built := 0
	var exhibits := 0
	var started := Time.get_ticks_msec()
	for night in range(1, 6):
		for n in 20:
			GameState.new_game()
			GameState.seed_base = 1000 + n * 7919 + night * 131
			GameState.night = night
			RunState.reset()
			_museum()
			await physics_frames(1)
			assert_eq(museum.exhibits().size(), NightSpawner.exhibit_count(museum.night) + museum.night.portraits.size(), "night %d seed %d" % [night, n])
			assert_eq(museum.objective.fuse_pickups.size(), 2)
			assert_not_null(museum.objective.crystal)
			assert_true(museum.havens[&"security"].contains(museum.player.global_position))
			exhibits += museum.exhibits().size()
			built += 1
			museum.free()
	print("  %d nights built, %d exhibits, %.1f s" % [built, exhibits, (Time.get_ticks_msec() - started) / 1000.0])
	assert_eq(built, 100)
