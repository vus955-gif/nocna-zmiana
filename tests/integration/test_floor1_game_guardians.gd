extends TestCase
## The wing guardians on Floor I (greybox mannequins until the real ones):
## each stands on its marker; walking into the arena wakes it (the HUD's
## bar with its name and title, the music's event); every attack is
## announced at least 0.6 s ahead; fleeing the arena calms it; its fall is
## saved, drops its seal and shard (taken: recorded, announced, saved) and
## it never comes back. The greybox stand-in is forced into the Colossus's
## arena here (the registry); the real Colossus has test_colossus.gd.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"
	GuardianKeeper.registry[&"colossus"] = GuardianStub


func after_each() -> void:
	GuardianKeeper.registry.erase(&"colossus")
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


## A point of the Colossus hall [param ahead] m in front of the guardian.
func _in_arena(guardian: Guardian, ahead: float) -> Vector3:
	return guardian.global_position - guardian.global_basis.z * ahead


func _kill(guardian: Guardian) -> void:
	var info := DamageInfo.make(guardian.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"shotgun"
	info.position = guardian.global_position + Vector3.UP * 2.0
	guardian.take_damage(info)


func test_every_guardian_stands_on_its_marker() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	assert_eq(keeper.guardians.size(), Floor1Plan.GUARDIANS.size(), "six guardians")
	for plan in Floor1Plan.guardians():
		var guardian: Guardian = keeper.guardians.get(plan.id)
		assert_not_null(guardian, plan.id)
		if guardian == null:
			continue
		var marker: Transform3D = museum.floor_level.markers[plan.marker]
		if plan.id == &"lamassu":
			# (up on its plinth over the marker)
			var off := guardian.global_position - marker.origin
			assert_lt(Vector2(off.x, off.z).length(), 0.5, plan.id)
			assert_lt(absf(off.y - (guardian as Lamassu).plinth.top()), 0.05, "the Lamassu stands on its plinth")
		else:
			assert_lt(guardian.global_position.distance_to(marker.origin), 0.5, plan.id)
		assert_eq(guardian.arena_room, museum.floor_level.layout.marker_rooms[plan.marker])
		assert_eq(guardian.state, Guardian.State.DORMANT)
	assert_eq(museum.enemies_root.find_children("*", "Guardian", true, false).size(), 0, "guardians are no exhibits")


func test_the_colossus_wakes_in_its_arena_and_announces_its_attacks() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus: GuardianStub = museum.floor_game.guardians.guardians[&"colossus"]
	var woke := watch(Events.guardian_awakened)
	_put_guard(Vector3(-43, 0, -8))   # the gallery: not yet
	await _seconds(0.5)
	assert_eq(woke.size(), 0, "asleep while the guard is outside its hall")
	_put_guard(_in_arena(colossus, 4.0))
	await _seconds(0.3)
	assert_eq(woke.size(), 1, "awake in its hall")
	if woke.size() == 1:
		assert_eq(woke[0][0], colossus)
		assert_eq(woke[0][1], &"colossus")
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_COLOSSUS").to_upper()), museum.hud.boss_name_text())
	assert_true(museum.hud.boss_name_text().contains(tr("GUARDIAN_COLOSSUS_TITLE").to_upper()))
	assert_true(museum.floor_game.blocks_rest(), "no rest during the fight")
	var keeper := museum.floor_game.guardians
	assert_gt(keeper._supplies.get_child_count(), 0, "the first phase's supplies")
	var spots := keeper.supply_spots(&"colossus")
	if not spots.is_empty():
		for supply in keeper._supplies.get_children():
			var nearest := INF
			for spot in spots:
				nearest = minf(nearest, (supply as Node3D).global_position.distance_to(spot))
			assert_lt(nearest, 2.0, "on the arena's supply spots")
	if museum.floor_level.markers.has(&"arena_colossus_start"):
		assert_ne(colossus.wake_point, Vector3.INF, "it wakes past the arena's start line")
	# every attack: announced, then landing no sooner than 0.6 s later
	var announced := {}
	var gaps: Array[float] = []
	colossus.telegraphed.connect(func(kind: StringName) -> void: announced[kind] = Time.get_ticks_msec())
	var clock := [0.0]
	var started := {}
	colossus.telegraphed.connect(func(kind: StringName) -> void: started[kind] = clock[0])
	colossus.struck.connect(func(kind: StringName) -> void:
		if started.has(kind):
			gaps.append(clock[0] - float(started[kind])))
	for i in 60 * 8:
		clock[0] += 1.0 / 60.0
		museum.player.heal(1000.0)
		if i == 60 * 4:
			_put_guard(_in_arena(colossus, 12.0))   # far: the volley
		await get_tree().physics_frame
	assert_gt(gaps.size(), 1, "it attacked")
	for gap in gaps:
		assert_true(gap >= Guardian.MIN_TELEGRAPH - 0.02, "telegraph %.2f s" % gap)
	assert_true(announced.has(&"slam") and announced.has(&"volley"), "both attacks: %s" % str(announced.keys()))


func test_fleeing_the_arena_calms_the_guardian() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var colossus: GuardianStub = museum.floor_game.guardians.guardians[&"colossus"]
	_put_guard(_in_arena(colossus, 5.0))
	await _seconds(0.3)
	var info := DamageInfo.make(colossus.max_health * 0.4, DamageInfo.Kind.BALLISTIC, museum.player)
	colossus.take_damage(info)
	assert_eq(colossus.phase, 2, "below two thirds: phase 2")
	var calmed := watch(colossus.calmed)
	_put_guard(Floor1Plan.junction(&"j_court_egypt").point_in(&"egypt", 2.5, 0.0))   # out of Egypt's front door
	await _seconds(Guardian.LEASH_TIME + 0.5)
	assert_eq(calmed.size(), 1)
	assert_eq(colossus.state, Guardian.State.DORMANT)
	assert_almost_eq(colossus.health.fraction(), 1.0, 0.001, "back to full health")
	assert_false(museum.floor_game.blocks_rest())


func test_a_fallen_guardian_drops_its_seal_and_shard_and_never_comes_back() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var colossus: GuardianStub = keeper.guardians[&"colossus"]
	_put_guard(_in_arena(colossus, 5.0))
	await _seconds(0.3)
	var fell := watch(Events.guardian_defeated)
	var dust_before := RunState.dust
	_kill(colossus)
	await physics_frames(2)
	assert_eq(fell.size(), 1)
	assert_true(GameState.is_guardian_defeated(&"colossus"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.is_guardian_defeated(&"colossus"), "saved at once")
	on_disk.free()
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2, "the seal and the shard")
	var collected := watch(Events.seal_collected)
	var shards := watch(Events.shard_collected)
	for pickup: ProgressPickup in rewards:
		pickup.interact(museum.player)
	assert_true(GameState.seals.has(&"seal_sun"))
	assert_true(GameState.shards.has(&"shard_egypt"))
	assert_eq(collected.size(), 1)
	assert_eq(shards.size(), 1)
	if shards.size() == 1:
		assert_eq(shards[0][1], 1, "the first shard")
	await _seconds(2.0)
	assert_gt(RunState.dust, dust_before, "its Dust")
	# the next night: no Colossus, nothing left to pick up
	museum.free()
	RunState.reset()
	GameState.night += 1
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"colossus"), "a fallen guardian stays fallen")
	assert_eq(museum.floor_game.guardians.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup).size(), 0)


func test_rewards_not_taken_wait_on_the_next_night() -> void:
	GameState.new_game()
	GameState.defeat_guardian(&"lamassu")
	GameState.add_seal(&"seal_wing")
	_museum()
	await physics_frames(2)
	var rewards := museum.floor_game.guardians.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 1, "only the shard is left")
	if rewards.size() == 1:
		assert_eq((rewards[0] as ProgressPickup).pickup_id, &"shard_assyria")
