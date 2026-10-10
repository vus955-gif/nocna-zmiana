extends TestCase
## Floor I's night as a whole: the gentle first minutes on the way out of
## the booth (design 7.2: "after leaving the booth at most 2 exhibits hunt
## within 30 m for the first 60 s"), the perception wired to the floor,
## the night from the booth to the Seal of the Sun (end to end), the
## finale, and what death and dawn keep.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	museum.player.global_position = at + Vector3.UP * 0.05
	museum.player.velocity = Vector3.ZERO
	museum.player.heal(1000.0)


func test_the_floor_configures_the_exhibits_perception() -> void:
	GameState.new_game()
	GameState.difficulty = &"double"
	_museum()
	await physics_frames(2)
	assert_true(PerceptionWorld.has_rooms(), "rooms from the floor's layout")
	assert_eq(PerceptionWorld.room_at(Vector3(0, 1, 45)), &"entrance_hall")
	assert_eq(PerceptionWorld.room_graph().has_room(&"egypt_gallery"), true)
	assert_almost_eq(PerceptionWorld.sight_scale, PerceptionRules.DIFFICULTY[2][0], 0.001, "the double shift sees further")
	assert_false(PerceptionWorld.is_door_open(museum.floor_level.layout.gate(&"seal_khorsabad").opening), "a shut gate stops noise")


func test_leaving_the_booth_on_the_first_night_draws_no_horde() -> void:
	for game_seed in [20261003, 91]:
		GameState.new_game()
		GameState.seed_base = game_seed
		_museum()
		await physics_frames(10)
		var way := NightDirector.first_way(museum.floor_level.describe())
		assert_eq(way, [&"booth_corridor", &"entrance_hall", &"court"] as Array[StringName])
		for exhibit in museum.exhibits():
			if way.has(exhibit.home_room):
				assert_false(exhibit is Wolf or exhibit is Raptor, "no wolves or raptors on the way out")
				if exhibit.brain.state == EnemyBrain.State.DORMANT:
					assert_gt(exhibit.sound_asleep, 0.0, "the sleepers on the way sleep soundly")
		var most := await _walk_out(60.0)
		print("  Floor I night 1, game %d: at most %d hunting within 30 m in the first 60 s" % [game_seed, most])
		assert_lt(most, 3, "seed %d: %d exhibits hunted him at once" % [game_seed, most])
		museum.free()
		await physics_frames(2)


func test_the_second_night_is_not_gentle() -> void:
	GameState.new_game()
	GameState.night = 2
	_museum()
	await physics_frames(2)
	var soundly := museum.exhibits().filter(func(e: Enemy) -> bool: return e.sound_asleep > 0.0)
	assert_eq(soundly.size(), 0)


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _hit(target: Object, amount: float, weapon: StringName = &"shotgun") -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = weapon
	info.position = (target as Node3D).global_position + Vector3.UP * 2.0
	target.call(&"take_damage", info)


func test_a_night_from_the_booth_to_the_seal_of_the_sun() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	museum.player.health.max_health = 100000.0
	museum.player.health.heal(100000.0)
	await physics_frames(3)
	var floor_game := museum.floor_game
	var pickups := floor_game.pickups
	assert_eq(museum.hud.objective_text(), tr("GOAL_TICKET_KEY"))
	# the till key in the entrance hall, the pistol in the booth's locker
	_put_guard(Vector3(-8, 0, 38))
	await _seconds(0.4)
	pickups.drawer.interact(museum.player)
	_put_guard(Vector3(36, 0, 42))
	await _seconds(0.4)
	pickups.locker.interact(museum.player)
	await physics_frames(2)
	pickups.pistol.interact(museum.player)
	assert_true(GameState.has_weapon(&"pistol"))
	# through the Great Court into Egypt: the shotgun on the main path
	_put_guard(Vector3(0, 0, 20))
	await _seconds(0.4)
	assert_true(GameState.rooms_visited.has(&"court"))
	var shotgun: WeaponPickup = pickups.weapons[&"shotgun"]
	_put_guard(_floor_under(shotgun.global_position + Vector3(0, 0.5, 1.5)))
	await _seconds(0.4)
	shotgun.interact(museum.player)
	assert_true(GameState.has_weapon(&"shotgun"))
	assert_true(RunState.is_used(FloorEncounters.used_id(&"egypt_camp")), "the camp's sleepers woke")
	# the Colossus in his hall: a shot into the uraeus (his weak point) fells him
	var colossus: Guardian = floor_game.guardians.guardians[&"colossus"]
	var woke := watch(Events.guardian_awakened)
	_put_guard(colossus.global_position - colossus.global_basis.z * 8.0)
	await _seconds(0.4)
	assert_eq(woke.size(), 1)
	var info := DamageInfo.make(colossus.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"shotgun"
	colossus.take_zone_damage(info, &"uraeus")
	assert_true(GameState.is_guardian_defeated(&"colossus"))
	for pickup in floor_game.guardians.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup):
		(pickup as ProgressPickup).interact(museum.player)
	assert_true(GameState.seals.has(&"seal_sun"))
	assert_eq(GameState.shards, [&"shard_egypt"] as Array[StringName])
	await physics_frames(2)
	assert_eq(museum.hud.shards_text(), tr("GOAL_SHARDS") % [1, Floor1Plan.SHARD_COUNT])
	# the Seal of the Sun opens the Khorsabad Gate for good
	var opened := watch(Events.gate_opened)
	var gate := floor_game.gates.lock_of(&"seal_khorsabad") as SealGate
	_put_guard(_floor_under(gate.global_position - gate.global_basis.z * 1.5 + Vector3.UP))
	await physics_frames(2)
	gate.use(museum.player)
	assert_eq(opened.size(), 1)
	assert_true(GameState.is_gate_open(&"seal_khorsabad"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	for done: bool in [on_disk.has_weapon(&"pistol"), on_disk.has_weapon(&"shotgun"), on_disk.is_guardian_defeated(&"colossus"),
			on_disk.seals.has(&"seal_sun"), on_disk.is_gate_open(&"seal_khorsabad")]:
		assert_true(done, "everything is in the save")
	on_disk.free()
	await _seconds(2.0)
	var door := museum.floor_level.doors[museum.floor_level.layout.gate(&"seal_khorsabad").opening] as Door
	assert_true(door.is_open, "the gate's door stands open")
	assert_ne(museum.hud.objective_text(), tr("GOAL_GUARDIAN_EGYPT"), "the goal moved past the Colossus")


func test_the_finale_from_the_astrolabe_to_the_end_of_floor_one() -> void:
	GameState.new_game()
	for plan in Floor1Plan.guardians():
		GameState.defeat_guardian(plan.id)
		GameState.add_shard(plan.shard)
		if plan.seal != &"":
			GameState.add_seal(plan.seal)
	GameState.open_gate(&"gate_reading_room")
	# everything before the astrolabe done
	GameState.pistol_key = true
	for weapon in FloorCompletion.WEAPONS:
		GameState.add_weapon(weapon)
	GameState.add_item(&"fuse_basement")
	GameState.add_item(&"fuse_assyria")
	GameState.set_flag(&"power_north")
	GameState.save_game()
	_museum()
	museum.player.health.max_health = 100000.0
	museum.player.health.heal(100000.0)
	await physics_frames(3)
	var finale := museum.floor_game.finale
	assert_eq(finale.stage, FloorFinale.Stage.ASTROLABE)
	assert_eq(museum.hud.objective_text(), tr("GOAL_ASTROLABE"))
	assert_true(finale.boss.is_dormant())
	_put_guard(finale.astrolabe.global_position + Vector3(0, 0, 2.5))
	await physics_frames(2)
	finale.astrolabe.interact(museum.player)
	assert_true(GameState.has_flag(&"astrolabe"))
	await physics_frames(4)
	assert_eq(finale.stage, FloorFinale.Stage.FLIGHT, "the guard stands by: the crystal flies at once")
	var woke := watch(Events.boss_awakened)
	var arrived := false
	for i in 60 * 45:
		if not is_instance_valid(finale.crystal):
			arrived = true
			break
		if i % 6 == 0:
			museum.player.global_position = _floor_under(finale.crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
			museum.player.heal(1000.0)
		await get_tree().physics_frame
	assert_true(arrived, "the crystal reached the ribs")
	assert_eq(woke.size(), 1, "the T-Rex woke")
	assert_eq(finale.stage, FloorFinale.Stage.BOSS)
	assert_true(museum.floor_game.blocks_rest())
	var keeper := museum.floor_game.guardians
	var doors := museum.floor_level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("arena_trex_door_"))
	assert_eq((keeper.sealed.get(&"trex", []) as Array).size(), doors.size(), "every doorway of the court shut for the fight")
	if museum.floor_level.markers.has(&"arena_trex_supply_1"):
		assert_eq(keeper._supplies.get_child_count(), 4, "the first supplies on markers 1-4")
	_put_guard(Vector3(0, 0, -5))
	await _seconds(3.5)
	museum.player.heal(1000.0)
	var boss := finale.boss
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	assert_true(boss.is_dead())
	assert_true(GameState.is_guardian_defeated(&"trex"))
	assert_false(keeper.sealed.has(&"trex"), "the court opens again")
	for grille: ArenaGrille in keeper.grilles.values():
		assert_false(grille.is_down)
	await _seconds(FloorFinale.GRATE_DELAY + 2.0)
	assert_true(GameState.is_gate_open(&"grate_crypt"), "the grate is open for good")
	assert_eq(museum.hud.objective_text(), tr("GOAL_DESCEND"))
	var ended := watch(museum.demo_end_requested)
	_put_guard((museum.floor_level.markers[Floor1Plan.EXIT_MARKER] as Transform3D).origin)
	await physics_frames(6)
	assert_eq(ended.size(), 1, "the dark ends Floor I")
	assert_true(GameState.has_flag(ProgressRules.COMPLETE_FLAG))
	var screen := (load(SceneFlow.DEMO_END) as PackedScene).instantiate() as DemoEnd
	add_child(screen)
	assert_true(screen.values.has("completion"), "the floor's end screen")
	assert_true(screen.values.has("chess"))
	assert_gt(int(String(screen.values["completion"].text).trim_suffix("%")), 10)
	screen.free()


func test_after_the_t_rex_every_night_is_an_epilogue() -> void:
	GameState.new_game()
	GameState.defeat_guardian(&"trex")
	GameState.open_gate(&"grate_crypt")
	_museum()
	await physics_frames(2)
	var finale := museum.floor_game.finale
	assert_null_node(finale.boss, "no boss")
	assert_eq(finale.stage, FloorFinale.Stage.DESCEND)
	assert_true(finale.exit.armed, "the way down waits")


func test_death_on_the_floor_keeps_the_progress() -> void:
	GameState.new_game()
	GameState.open_gate(&"boards_staff_stairs")
	GameState.add_weapon(&"pistol")
	GameState.save_game()
	_museum()
	await physics_frames(3)
	_put_guard(Vector3(0, 0, 45))
	await physics_frames(12)
	RunState.add_dust(21, false)
	var next := watch(museum.next_night_requested)
	museum.player.take_damage(DamageInfo.make(9999.0, DamageInfo.Kind.BLUNT))
	assert_eq(GameState.night, 2)
	assert_eq(GameState.lantern["dust"], 21, "the Dust waits in the lantern")
	await get_tree().create_timer(Museum.DEATH_DELAY + DeathScreen.FADE_TIME + DeathScreen.CLOCK_TIME + 0.6).timeout
	assert_eq(next.size(), 1)
	museum.free()
	RunState.reset()
	_museum()
	await physics_frames(3)
	assert_true(museum.havens[&"security"].contains(museum.player.global_position), "the next night starts in the booth")
	assert_true(museum.player.weapons.has_weapon(&"pistol"))
	assert_true(bool(museum.floor_game.gates.lock_of(&"boards_staff_stairs").get(&"is_open")), "the boards stay broken")


func test_dawn_on_the_floor_freezes_the_night() -> void:
	GameState.new_game()
	GameState.discover_haven(&"conservator")
	GameState.start_haven = &"conservator"
	_museum()
	await physics_frames(3)
	_put_guard(Vector3(-44, 0, 12))   # out in the gallery: the clock runs
	await physics_frames(3)
	var dawned := watch(Events.dawn_broke)
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.2
	await _seconds(0.5)
	assert_eq(dawned.size(), 1)
	for exhibit in museum.exhibits():
		assert_true(exhibit.is_frozen())
	for guardian: Guardian in museum.floor_game.guardians.guardians.values():
		assert_true(guardian.is_frozen(), "the guardians too")
	assert_eq(museum.floor_game.finale.boss.process_mode, Node.PROCESS_MODE_DISABLED, "and the T-Rex")
	assert_eq(GameState.night, 2)
	assert_eq(GameState.start_haven, &"conservator", "the next night starts where the last rest was")


func test_a_night_left_is_resumed_on_the_floor() -> void:
	GameState.new_game()
	GameState.night = 2
	_museum()
	await physics_frames(3)
	var before := museum.exhibits().size()
	var victim: Enemy = museum.exhibits().filter(func(e: Enemy) -> bool: return e.has_meta(Museum.SLOT_META) and not e is Raptor)[0]
	var slot := int(victim.get_meta(Museum.SLOT_META))
	victim.take_damage(DamageInfo.make(9999.0, DamageInfo.Kind.BALLISTIC, museum.player))
	await physics_frames(2)
	assert_true(RunState.killed_slots.has(slot))
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	_museum()
	await physics_frames(3)
	assert_eq(museum.exhibits().size(), before - 1, "what was destroyed stays gone")


func assert_null_node(value: Variant, message: String = "") -> void:
	if value != null and is_instance_valid(value):
		fail("expected null. " + message)


## Walks the guard out of the booth, through the entrance hall into the
## Great Court and up and down its south side at a walk; returns the most
## exhibits hunting within 30 m of him at once.
func _walk_out(seconds: float) -> int:
	var guard := museum.player
	var path: Array[Vector3] = [Vector3(32, 0.1, 44), Vector3(29, 0.1, 42), Vector3(22, 0.1, 42), Vector3(15, 0.1, 42),
			Vector3(8, 0.1, 40), Vector3(0, 0.1, 33), Vector3(0, 0.1, 25), Vector3(0, 0.1, 18), Vector3(-8, 0.1, 18),
			Vector3(8, 0.1, 18), Vector3(0, 0.1, 18)]
	var at := guard.global_position
	var leg := 0
	var step := guard.walk_speed / Engine.physics_ticks_per_second
	var most := 0
	for frame in roundi(seconds * Engine.physics_ticks_per_second):
		var goal := path[leg]
		var to := goal - at
		if to.length() <= step:
			at = goal
			leg = (leg + 1) if leg < path.size() - 1 else 7   # then pace the court's south side
		else:
			at += to.normalized() * step
		guard.global_position = at
		guard.velocity = Vector3.ZERO
		guard.heal(1000.0)
		await get_tree().physics_frame
		var hunting := 0
		for exhibit in museum.exhibits():
			if exhibit.brain.is_hunting() and exhibit.global_position.distance_to(guard.global_position) <= PerceptionRules.HUNT_RADIUS:
				hunting += 1
		most = maxi(most, hunting)
	return most
