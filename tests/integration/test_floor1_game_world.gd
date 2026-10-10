extends TestCase
## Floor I's world in the game: the weapons on their markers (the shotgun
## on the main path in Egypt, the pistol behind the till key and the gun
## locker, the flare gun in the fire cabinet, the gatling's chained case),
## the fuses as key items, the ambush at the shotgun, patrol routes, the
## difficulty's exhibit stats.

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


func _marker(id: StringName) -> Vector3:
	return (museum.floor_level.markers[id] as Transform3D).origin


func test_the_weapons_lie_on_their_markers() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var pickups := museum.floor_game.pickups
	var shotgun: WeaponPickup = pickups.weapons.get(&"shotgun")
	assert_not_null(shotgun, "the shotgun lies in Egypt")
	if shotgun != null:
		assert_lt(shotgun.global_position.distance_to(_marker(&"weapon_shotgun")), 0.1)
		assert_eq(museum.floor_level.room_at(shotgun.global_position + Vector3.UP * 0.2), &"egypt_gallery", "on the main path")
	assert_not_null(pickups.drawer, "the till drawer")
	assert_true(pickups.drawer.has_key, "with the key in a new game")
	assert_not_null(pickups.locker, "the gun locker")
	assert_not_null(pickups.cabinet, "the fire cabinet")
	assert_not_null(pickups.display, "the gatling's chained case")
	assert_eq(museum.floor_game.gates.lock_of(&"chain_gatling"), pickups.display, "its chain is the gate")
	for id: StringName in [&"rifle_hunt", &"harpoon", &"hwacha"]:
		assert_eq(pickups.weapons.has(id), FloorPickups.knows_weapon(id), "%s only when the build has it" % id)
	assert_eq(pickups.items.size(), 2, "both fuses")


func test_the_pistol_comes_from_the_till_key_and_the_locker() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var pickups := museum.floor_game.pickups
	pickups.locker.interact(museum.player)
	assert_null(pickups.pistol, "no key: the locker stays shut")
	pickups.drawer.interact(museum.player)
	assert_true(GameState.pistol_key)
	pickups.locker.interact(museum.player)
	await physics_frames(2)
	assert_not_null(pickups.pistol, "the pistol in the open locker")
	pickups.pistol.interact(museum.player)
	assert_true(GameState.has_weapon(&"pistol"))
	assert_eq(museum.player.weapons.current_state().data.id, &"pistol")
	await physics_frames(2)
	assert_eq(museum.hud.objective_text(), tr("GOAL_FLARE"), "the goal moved on")


func test_taking_the_shotgun_springs_the_camp_ambush() -> void:
	GameState.new_game()
	GameState.night = 2
	_museum()
	await physics_frames(2)
	var ambush := museum.floor_level.layout.ambush(&"egypt_camp")
	assert_not_null(ambush)
	var sleepers := museum.exhibits().filter(func(e: Enemy) -> bool:
		return e.has_meta(NightSpawner.SLOT_META) and ambush.slots.has(int(e.get_meta(NightSpawner.SLOT_META))))
	for exhibit: Enemy in sleepers:
		assert_eq(exhibit.brain.state, EnemyBrain.State.DORMANT)
	var shotgun: WeaponPickup = museum.floor_game.pickups.weapons[&"shotgun"]
	museum.player.global_position = shotgun.global_position + Vector3(0, -0.85, 1.2)
	await physics_frames(2)
	shotgun.interact(museum.player)
	assert_true(GameState.has_weapon(&"shotgun"))
	assert_true(RunState.is_used(FloorEncounters.used_id(&"egypt_camp")))
	for exhibit: Enemy in sleepers:
		if is_instance_valid(exhibit):
			assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "the camp's sleepers wake")


func test_a_fuse_is_a_key_item_for_good() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var fuse: ProgressPickup = museum.floor_game.pickups.items[&"fuse_basement"]
	fuse.interact(museum.player)
	assert_true(GameState.has_item(&"fuse_basement"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.has_item(&"fuse_basement"), "saved at once")
	on_disk.free()
	museum.free()
	RunState.reset()
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.pickups.items.has(&"fuse_basement"), "never there again")


func test_patrols_walk_their_routes() -> void:
	var layout := Floor1Layout.create()
	var patrol := PatrolSpec.make(&"p", &"court", PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, 5)]), false)
	assert_eq(FloorEncounters.route_of(patrol), PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, 5), Vector3(5, 0, 0)]), "there and back")
	var walker := -1
	for i in layout.spawn_slots.size():
		if layout.spawn_slots[i].patrol != &"":
			walker = i
			break
	assert_gt(walker, -1, "the floor has a patrolling slot")
	var exhibit := WaxFigure.new()
	exhibit.set_meta(NightSpawner.SLOT_META, walker)
	FloorEncounters.tune_from_layout(exhibit, layout)
	assert_eq(exhibit.patrol_route, layout.patrol(layout.spawn_slots[walker].patrol).points)
	exhibit.free()


func test_the_difficulty_tunes_the_exhibits() -> void:
	var calm := WaxFigure.new()
	var double := WaxFigure.new()
	var base_damage := calm.attack_damage
	var base_health := calm.max_health
	DifficultyRules.tune(calm, &"calm")
	DifficultyRules.tune(double, &"double")
	assert_almost_eq(calm.attack_damage, base_damage * 0.6, 0.01)
	assert_almost_eq(double.attack_damage, base_damage * 1.35, 0.01)
	assert_almost_eq(double.max_health, base_health * 1.2, 0.01)
	assert_eq(DifficultyRules.index(&"double"), 2)
	assert_eq(DifficultyRules.index(&"nonsense"), 1)
	calm.free()
	double.free()


func assert_null(value: Variant, message: String = "") -> void:
	if value != null and is_instance_valid(value):
		fail("expected null. " + message)


func test_the_world_content_reads_the_floors_markers() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := museum.floor_game.world
	assert_not_null(world)
	assert_true(world.notes.has(NoteCatalog.KEY_NOTE), "Heniek's note about the till key lies in the booth")
	assert_eq(museum.pause_menu.note_reader, world.reader)
	assert_not_null(world.cctv, "the CCTV")
	var markers := museum.floor_level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("cctv_") and id != &"cctv_wall")
	assert_eq(world.cctv.cameras.size(), maxi(markers.size(), CctvCatalog.WALL), "every camera of the floor")
	assert_eq(world.cctv.feeds.size(), Cctv.WALL_FEEDS, "six on the booth's wall")
	for i in Cctv.WALL_FEEDS:
		var zone := museum.floor_level.zone_at(world.cctv.cameras[i].position + Vector3.DOWN * 0.5)
		assert_true(CctvCatalog.HUB_ZONES.has(zone), "wall camera %d watches the hub (%s)" % [i + 1, zone])
	# the console's view pages through all of them
	var view := world.cctv.view
	world.cctv.open_view(world.cctv.cameras.size() - 1)
	assert_eq(view.page_start(), (view.index / CctvView.PAGE) * CctvView.PAGE)
	assert_eq(view.page_count(), ceili(world.cctv.cameras.size() / float(CctvView.PAGE)))
	view.select(view.index + 1)
	assert_eq(view.index, 0, "the arrows wrap round to the first")
	view.close()
	assert_eq(world.cctv.watch_room, &"booth_security")
	museum.player.global_position = Vector3(33, 0.1, 44)
	await physics_frames(20)
	assert_true(world.cctv.active, "the monitor wall runs while the guard is in the booth")
	museum.player.global_position = Vector3(0, 0.1, 45)
	await physics_frames(20)
	assert_false(world.cctv.active)
	# artifacts of the night where the director put them
	var drawn := museum.artifact_spots()
	assert_eq(world.artifacts.size(), drawn.size())


func test_secrets_and_chess_pieces_are_found_for_good() -> void:
	# markers the zone builders will place: a secret by a false panel, a
	# loose stone, a chess piece
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var level := museum.floor_level
	level.layout.add_marker(&"secret_court_1", Vector3(-20, 1.2, 29.9), &"court", PI)
	level.layout.add_marker(&"chess_1", Vector3(-25, 0, 25), &"court")
	level.markers = level.layout.markers
	var world := WorldFeatures.install(level, museum)
	await physics_frames(2)
	assert_eq(world.secrets_total(), level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("secret_")).size())
	var cache := (world.secrets[&"secret_court_1"] as Array)[0] as SecretCache
	assert_not_null(cache, "no panel near: a loose stone")
	var found := watch(world.secret_discovered)
	cache.interact(museum.player)
	assert_true(GameState.secrets.has(&"secret_court_1"))
	assert_eq(found.size(), 1)
	var piece: ProgressPickup = world.chess[&"chess_1"]
	piece.interact(museum.player)
	assert_true(GameState.chess_found.has(&"chess_1"))
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	assert_true(on_disk.secrets.has(&"secret_court_1") and on_disk.chess_found.has(&"chess_1"), "saved")
	on_disk.free()
	var again := WorldFeatures.install(level, museum)
	await physics_frames(2)
	assert_false(again.secrets.has(&"secret_court_1"), "found: nothing to find again")
	assert_false(again.chess.has(&"chess_1"))
	world.free()
	again.free()


func test_a_secret_room_counts_when_the_guard_walks_in() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var world := museum.floor_game.world
	var layout := museum.floor_level.layout
	var cache_room: StringName = layout.marker_rooms[&"secret_egypt_1"]
	assert_true(layout.room(cache_room).secret, "the marker lies in a secret room")
	assert_eq(world.secret_rooms.get(&"secret_egypt_1"), cache_room)
	# the cracked wall of the serdab is a gate: no knock opens it
	var serdab_gate := layout.gate(&"egypt_cracked_serdab")
	for node in world.get_children():
		if node is SecretSwitch:
			assert_ne((node as SecretSwitch).door_id, serdab_gate.opening, "a gate's panel is the lock's business")
	var found := watch(world.secret_discovered)
	museum.player.global_position = (layout.markers[&"secret_egypt_1"] as Transform3D).origin + Vector3.UP * 0.1
	await physics_frames(20)
	assert_true(GameState.secrets.has(&"secret_egypt_1"), "reached: found")
	assert_eq(found.size(), 1)
	assert_false(world.secret_rooms.has(&"secret_egypt_1"))


func test_the_flickering_tubes_stutter_and_go_out_with_the_main_lamps() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lights := museum.floor_level.lights
	var tubes: Array[Light3D] = []
	for node in lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.FLICKER):
			tubes.append(node)
	assert_gt(tubes.size(), 0, "the basement's tubes are on a bad circuit")
	var flicker := lights.get_node_or_null(^"LampFlicker") as LampFlicker
	assert_not_null(flicker)
	if flicker == null:
		return
	var dipped := false
	for i in 60 * 6:
		await get_tree().process_frame
		for tube in tubes:
			if tube.light_energy < flicker.base_energy(tube) * 0.5:
				dipped = true
		if dipped:
			break
	assert_true(dipped, "a tube stutters within a few seconds")
	NightModifiers.set_lights(museum.floor_level, LightSpec.MAIN, false)
	for tube in tubes:
		assert_false(tube.visible, "a blackout puts the tubes out too")
	var powered := LayoutIllumination.powered_by_nodes(lights)
	var room: StringName = tubes[0].get_meta(&"room", &"")
	assert_false(powered.call(LightSpec.FLICKER, room), "and the light model knows it")
