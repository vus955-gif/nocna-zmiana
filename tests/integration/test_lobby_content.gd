extends TestCase
## The content pass in the game's lobby: portraits among the paintings, the
## raptor packs, the chained gatling and the fire cabinet with the flare
## gun, ammo for the new guns, and the T-Rex's roar calling raptors.

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _find(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)


## True when [param point] lies inside level geometry (a wall).
func _in_wall(point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = Layers.WORLD
	return not museum.get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


## A night seed base whose night [param night] draws a raptor pack.
func _game_with_a_pack(night: int) -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	for base in 200:
		GameState.new_game()
		GameState.seed_base = 500 + base * 7919
		GameState.night = night
		var config := NightDirector.plan(GameState.night_seed(), night, description)
		if config.spawns.any(func(entry: NightConfig.Spawn) -> bool: return entry.kind == NightSpawner.PACK):
			return


func test_the_nights_portraits_hang_among_plain_paintings() -> void:
	GameState.new_game()
	GameState.night = 2
	_museum()
	await physics_frames(2)
	var spots := museum.lobby.describe().portrait_spots
	assert_eq(spots.size(), 12, "eight in the gallery, four over the side balconies")
	var portraits := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit is Portrait)
	assert_eq(portraits.size(), museum.night.portraits.size())
	assert_true(portraits.size() >= NightDirector.PORTRAITS.x and portraits.size() <= NightDirector.PORTRAITS.y)
	var paintings := _find(museum.paintings_root, "StaticBody3D").filter(func(node: Node) -> bool: return node is WallPainting)
	assert_eq(paintings.size() + portraits.size(), spots.size(), "every spot has its painting")
	var faces := {}
	for node: Node3D in portraits + paintings:
		assert_true(node.get_parent() == museum.enemies_root or node.get_parent() == museum.paintings_root)
		var wall := node.global_transform
		assert_true(_in_wall(wall.origin + wall.basis.z * 0.1), "%s hangs on a wall" % node.name)
		assert_false(_in_wall(wall.origin - wall.basis.z * 0.7), "%s faces the room" % node.name)
		var room := museum.lobby.room_at(wall.origin - wall.basis.z * 0.7 + Vector3.DOWN * 1.9)
		assert_true(room == &"gallery" or room == &"balcony", "%s in %s" % [node.name, room])
		faces[node.get("painting_id")] = true
	assert_gt(faces.size(), 8, "many faces")
	for portrait: Portrait in portraits:
		assert_eq(portrait.brain.state, EnemyBrain.State.DORMANT, "a portrait waits for the guard's eyes")
		assert_true(museum.night.portraits.has(portrait.get_meta(Museum.PORTRAIT_META)))


func test_a_destroyed_portrait_stays_gone_on_continue() -> void:
	GameState.new_game()
	GameState.night = 2
	GameState.save_game()
	_museum()
	await physics_frames(2)
	var portrait: Portrait = museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit is Portrait)[0]
	var spot: StringName = portrait.get_meta(Museum.PORTRAIT_META)
	var count := museum.night.portraits.size()
	portrait.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, museum.player))
	await physics_frames(1)
	assert_true(RunState.is_used(Museum.portrait_id(spot)), "remembered for the night")
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	var left := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit is Portrait)
	assert_eq(left.size(), count - 1)
	for other: Portrait in left:
		assert_ne(other.get_meta(Museum.PORTRAIT_META), spot)
	var paintings := _find(museum.paintings_root, "StaticBody3D").size()
	assert_eq(paintings + left.size(), museum.lobby.describe().portrait_spots.size() - 1, "an empty wall where it hung")


func test_a_packs_slot_is_gone_with_its_last_raptor() -> void:
	_game_with_a_pack(3)
	_museum()
	await physics_frames(2)
	var raptors := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit is Raptor)
	assert_gt(raptors.size(), 2, "a pack tonight")
	if raptors.is_empty():
		return
	var slot: int = raptors[0].get_meta(Museum.SLOT_META)
	var pack := raptors.filter(func(raptor: Enemy) -> bool: return raptor.get_meta(Museum.SLOT_META) == slot)
	assert_true(pack.size() >= RaptorPack.MIN_SIZE and pack.size() <= RaptorPack.MAX_SIZE)
	for i in pack.size():
		(pack[i] as Enemy).take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, museum.player))
		assert_eq(RunState.killed_slots.has(slot), i == pack.size() - 1, "raptor %d of %d" % [i + 1, pack.size()])


func test_a_pack_half_killed_comes_back_without_its_dead_after_continue() -> void:
	_game_with_a_pack(3)
	GameState.save_game()
	_museum()
	await physics_frames(2)
	var raptors := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit is Raptor)
	if raptors.is_empty():
		fail("no pack tonight")
		return
	var slot: int = raptors[0].get_meta(Museum.SLOT_META)
	var pack := raptors.filter(func(raptor: Enemy) -> bool: return raptor.get_meta(Museum.SLOT_META) == slot)
	var size := pack.size()
	for i in 2:
		(pack[i] as Enemy).take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, museum.player))
	assert_eq(Museum.pack_losses(RunState).get(slot, 0), 2)
	var total := museum.exhibits().size()
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	var back := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit.get_meta(Museum.SLOT_META, -1) == slot)
	assert_eq(back.size(), size - 2, "only the raptors still standing come back")
	assert_eq(museum.exhibits().size(), total, "nothing else changed")
	assert_eq(NightSpawner.exhibit_count(museum.night, RunState.killed_slots, Museum.pack_losses(RunState)), museum.exhibits().filter(func(exhibit: Enemy) -> bool: return not exhibit is Portrait).size())
	# the rest of the pack: the slot is gone for good
	for raptor: Enemy in back:
		raptor.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, museum.player))
	assert_true(RunState.killed_slots.has(slot))


func test_ammo_for_a_gun_he_lacks_becomes_ammo_he_can_use() -> void:
	GameState.new_game()
	GameState.add_weapon(&"pistol")
	_museum()
	await physics_frames(2)
	assert_eq(museum.loot_for_guard(&"rifle"), &"bullets")
	assert_eq(museum.loot_for_guard(&"flares"), &"shells")
	assert_eq(museum.loot_for_guard(&"medkit"), &"medkit")
	for pickup: Pickup in _find(museum.pickups_root, "Pickup"):
		assert_false(pickup.type in [Pickup.Type.RIFLE, Pickup.Type.FLARES], "no belts or flares without their guns")
	assert_true(FoundWeapon.give(museum.player, &"gatling"))
	assert_true(FoundWeapon.give(museum.player, &"flare"))
	assert_eq(museum.loot_for_guard(&"rifle"), &"rifle")
	assert_eq(museum.loot_for_guard(&"flares"), &"flares")
	assert_eq(Museum.LOOT_AMOUNTS[&"rifle"], 50)
	assert_eq(Museum.LOOT_AMOUNTS[&"flares"], 3)


func test_the_chained_gatling_and_the_fire_cabinet_stand_in_the_lobby() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var display := museum.armory.display
	var cabinet := museum.armory.cabinet
	assert_not_null(display)
	assert_not_null(cabinet)
	if display == null or cabinet == null:
		return
	assert_eq(museum.lobby.room_at(display.global_position + Vector3.UP * 0.1), &"armory")
	assert_true(museum.lobby.walk_region.is_ancestor_of(display), "the plinth is a navigation obstacle")
	assert_eq(display.state, ChainedDisplay.State.LOCKED)
	var plaque := -display.global_transform.basis.z
	assert_gt(plaque.dot(Vector3.LEFT), 0.9, "the plaque faces the door from the hall")
	var back := cabinet.global_transform
	assert_true(_in_wall(back.origin + back.basis.z * 0.1), "the cabinet hangs on the wall")
	assert_eq(museum.lobby.room_at(back.origin - back.basis.z * 0.5 + Vector3.DOWN * 1.3), &"diorama")
	assert_eq(cabinet.state, EmergencyCabinet.State.CLOSED)
	# the exhibits walk round the plinth (once the rebake is in)
	var started := Time.get_ticks_msec()
	while museum.lobby.navigation.is_baking() and Time.get_ticks_msec() - started < 20000:
		await physics_frames(1)
	await physics_frames(2)
	var map := museum.lobby.walk_region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(30, 0, 10.5), Vector3(30, 0, 3.5), true, LevelNavigation.WALK_LAYER)
	assert_gt(path.size(), 1)
	var footprint := AABB(display.global_position + Vector3(-0.45, -1.0, -0.85), Vector3(0.9, 3.0, 1.7))
	for i in range(1, path.size()):
		for t in 10:
			assert_false(footprint.has_point(path[i - 1].lerp(path[i], t / 10.0)), "the path goes round the plinth")


func test_found_guns_leave_their_places_empty() -> void:
	GameState.new_game()
	GameState.add_weapon(&"gatling")
	GameState.add_weapon(&"flare")
	_museum()
	await physics_frames(2)
	assert_eq(museum.armory.display.state, ChainedDisplay.State.EMPTY)
	assert_eq(museum.armory.cabinet.state, EmergencyCabinet.State.EMPTY)


func test_the_roar_calls_a_raptor_pack_away_from_the_guard() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var objective := museum.objective
	assert_eq(objective.summon(0), [])
	museum.player.global_position = Vector3(-11, 0.1, 18)
	var called := objective.summon_raptors(6)
	assert_eq(called.size(), RaptorPack.MAX_SIZE, "a pack is four at most")
	var sides := {}
	for raptor: Raptor in called:
		assert_eq(raptor.get_parent(), museum.enemies_root)
		assert_ne(raptor.brain.state, EnemyBrain.State.DORMANT, "they come running")
		assert_gt(raptor.global_position.distance_to(museum.player.global_position), NightObjective.SUMMON_DISTANCE - RaptorPack.SPREAD - 0.1)
		assert_eq(museum.lobby.room_at(raptor.global_position + Vector3.UP * 0.2), &"hall")
		sides[raptor.flank_side] = true
	assert_eq(sides.size(), 2)
	# the roar: sometimes raptors, sometimes wax figures
	RunState.rng.seed = 7
	var kinds := {}
	for i in 16:
		for exhibit: Enemy in objective.summon(1):
			kinds[&"raptor" if exhibit is Raptor else &"wax" if exhibit is WaxFigure else &"other"] = true
	assert_true(kinds.has(&"raptor"), "raptors")
	assert_true(kinds.has(&"wax"), "wax figures")
	assert_false(kinds.has(&"other"))
