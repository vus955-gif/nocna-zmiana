extends TestCase
## The game scene on the museum lobby (built inside the test, so it emits
## signals instead of changing scenes). The booth (security haven) spans
## x -5..5, z 54..62; the staff corridor north of it leads out.

## A spot just outside the booth and one inside it.
const OUTSIDE := Vector3(0, 0.1, 50)
const INSIDE := Vector3(0, 0.1, 57)

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


func _find(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)


func test_sandbox_level_fulfils_the_level_contract() -> void:
	var level := SandboxLevel.new()
	add_child(level)
	level.build()
	assert_true(level.haven_spots.has(&"security"))
	var zone: AABB = level.haven_zones[&"security"]
	assert_true(zone.has_point(level.player_start.origin), "the night starts in the booth")
	var terminal: Transform3D = level.haven_spots[&"security"]
	assert_true(zone.grow(0.5).has_point(terminal.origin), "the terminal stands in the booth")
	assert_gt(level.spawn_slots.size(), 5)
	assert_gt(level.loot_spots.size(), 3)
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = Layers.WORLD
	for slot in level.spawn_slots:
		assert_false(zone.has_point(slot.position), "no exhibit in the haven")
		assert_false(slot.kinds.is_empty())
		query.transform = Transform3D(Basis.IDENTITY, slot.position + Vector3.UP * 1.05)
		assert_true(space.intersect_shape(query, 1).is_empty(), "slot %s is clear" % slot.position)
	level.free()


func test_the_night_is_the_directors_draw_on_the_lobby() -> void:
	GameState.new_game()
	GameState.night = 3
	_museum()
	await physics_frames(2)
	assert_true(museum.level is LobbyLevel)
	var expected := NightDirector.plan(GameState.night_seed(), 3, LobbyLayout.describe(LobbyLayout.create()))
	assert_eq(museum.night.to_dict(), expected.to_dict())
	assert_eq(museum.lobby.night, museum.night, "the lobby was built for it (locked door before the first bake)")
	if museum.night.locked_door != &"":
		assert_true((museum.lobby.doors[museum.night.locked_door] as Door).locked)
	var stand_ins := get_tree().get_nodes_in_group(&"level_kit").filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"trex")
	assert_eq(stand_ins.size(), 0, "the pedestal waits for the live boss")


func test_night_starts_in_the_booth_with_fists_and_taser() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var zone: AABB = museum.level.haven_zones[&"security"]
	assert_true(zone.has_point(museum.player.global_position))
	assert_eq(museum.player.weapons.owned.size(), 1)
	assert_eq(museum.player.weapons.current_state().data.id, &"taser")
	assert_true(RunState.running)
	assert_true(museum.hud.show_dust)
	assert_eq(museum.havens.keys().size(), 2, "the booth and the hidden closet")
	assert_eq(_find(museum, "UpgradeTerminal").size(), 2)


func test_exhibits_are_the_nights_draw() -> void:
	GameState.new_game()
	GameState.night = 2
	_museum()
	await physics_frames(2)
	assert_eq(museum.exhibits().size(), NightSpawner.exhibit_count(museum.night) + museum.night.portraits.size())
	var drawn := {}
	for entry in museum.night.spawns:
		drawn[entry.slot] = entry
	for node in museum.enemies_root.get_children():
		var exhibit := node as Enemy
		if exhibit is Portrait:
			continue
		var slot: int = exhibit.get_meta(Museum.SLOT_META)
		assert_true(drawn.has(slot))
		var entry: NightConfig.Spawn = drawn[slot]
		assert_eq(exhibit.brain.state == EnemyBrain.State.DORMANT, entry.dormant, "slot %d" % slot)
		assert_lt(exhibit.global_position.distance_to(museum.level.spawn_slots[slot].position), RaptorPack.SPREAD + 0.6)
		if entry.kind == &"bust":
			assert_true(exhibit is Bust)


func test_loot_is_the_nights_draw() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var consumables := 0
	for spot: int in museum.night.loot:
		if Museum.LOOT_TYPES.has(museum.night.loot[spot]):
			consumables += 1
			var pickup := museum.pickups_root.get_node_or_null("Loot_%d" % spot) as Pickup
			assert_not_null(pickup, "spot %d" % spot)
			if pickup != null:
				assert_eq(pickup.type, Museum.LOOT_TYPES[museum.loot_for_guard(museum.night.loot[spot])])
	assert_gt(consumables, 5)
	assert_eq(_find(museum.pickups_root, "Pickup").size(), consumables, "artifacts are left to the artifacts feature")
	assert_eq(museum.artifact_spots().size(), museum.night.artifacts.size())


func test_saved_lantern_is_placed() -> void:
	GameState.lantern = {"active": true, "position": [2.0, 0.0, 10.0], "dust": 17}
	_museum()
	assert_not_null(museum.lantern)
	assert_eq(museum.lantern.dust, 17)
	assert_eq(museum.lantern.position, Vector3(2, 0, 10))


func test_starting_the_night_in_the_haven_is_no_rest() -> void:
	_museum()
	await physics_frames(6)
	assert_false(GameState.has_save(), "no save at the door")
	assert_eq(museum.hud.toast_text(), "", "no \"game saved\" at the start")


## Out of the booth, hurt, carrying Dust, then back in.
func _walk_back_into_the_booth() -> void:
	museum.player.global_position = OUTSIDE
	museum.player.health.apply_damage(40.0)
	RunState.add_dust(9, false)
	await physics_frames(4)
	museum.player.global_position = INSIDE
	await physics_frames(4)


func test_entering_the_haven_heals_and_saves() -> void:
	_museum()
	await physics_frames(4)
	RunState.time += Museum.REST_COOLDOWN   # half a minute into the night
	await _walk_back_into_the_booth()
	assert_eq(museum.player.health.current, museum.player.health.max_health)
	assert_eq(museum.hud.toast_text(), tr("HUD_SAVED").to_upper())
	var saved := PersistentState.new()
	add_child(saved)
	saved.load_game()
	assert_eq(saved.run_dust, 9)
	assert_eq(saved.start_haven, &"security")


func test_the_haven_rests_at_most_once_per_cooldown() -> void:
	_museum()
	await physics_frames(4)
	RunState.time += Museum.REST_COOLDOWN
	await _walk_back_into_the_booth()
	assert_eq(museum.player.health.current, 100.0, "the first visit heals")
	RunState.time += Museum.REST_COOLDOWN * 0.5
	await _walk_back_into_the_booth()
	assert_eq(museum.player.health.current, 60.0, "stepping out and in again does not")
	RunState.time += Museum.REST_COOLDOWN * 0.5
	await _walk_back_into_the_booth()
	assert_eq(museum.player.health.current, 100.0, "half a minute later it does")


func test_weapons_are_lowered_in_the_haven() -> void:
	GameState.add_weapon(&"pistol")
	_museum()
	await physics_frames(4)
	var pistol := museum.player.weapons.state_of(&"pistol")
	assert_true(museum.player.weapons.sheltered())
	Input.action_press(&"fire")
	await physics_frames(6)
	Input.action_release(&"fire")
	assert_eq(pistol.magazine, pistol.data.magazine_size, "no shot from the booth")
	museum.player.global_position = OUTSIDE
	await physics_frames(3)
	assert_false(museum.player.weapons.sheltered())
	Input.action_press(&"fire")
	await physics_frames(3)
	Input.action_release(&"fire")
	assert_lt(pistol.magazine, pistol.data.magazine_size, "outside it fires")


func test_a_failed_save_shows_a_warning_instead_of_saved() -> void:
	_museum()
	await physics_frames(4)
	GameState.file_path = SavePaths.dir().path_join("missing_folder/deeper/save.json")
	RunState.time += Museum.REST_COOLDOWN
	await _walk_back_into_the_booth()
	assert_eq(museum.hud.toast_text(), tr("HUD_SAVE_FAILED").to_upper())
	GameState.file_path = ""


func test_continue_resumes_the_night() -> void:
	GameState.new_game()
	GameState.add_weapon(&"pistol")
	GameState.save_game()
	_museum()
	await physics_frames(3)
	var exhibits := museum.exhibits().size()
	var loot := _find(museum.pickups_root, "Pickup").size()
	# two exhibits destroyed (not raptors: a pack's slot goes with its last
	# raptor), one box of loot taken, hurt, a few shots fired
	var gone: Array[int] = []
	var singles := museum.exhibits().filter(func(exhibit: Enemy) -> bool: return exhibit.has_meta(Museum.SLOT_META) and not exhibit is Raptor)
	for node in singles.slice(0, 2):
		gone.append(int(node.get_meta(Museum.SLOT_META)))
		(node as Enemy).take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BALLISTIC, museum.player))
	# a box of bullets (the guard has the pistol; a medkit would wait for a wound)
	var boxes := _find(museum.pickups_root, "Pickup").filter(func(node: Node) -> bool: return (node as Pickup).type == Pickup.Type.BULLETS)
	var box := boxes[0] as Pickup
	museum.player.global_position = box.global_position + Vector3.DOWN * 0.3
	await physics_frames(4)
	museum.player.health.apply_damage(35.0)
	var pistol := museum.player.weapons.state_of(&"pistol")
	pistol.magazine = 5
	pistol.reserve = 17
	museum.quit_to_menu()
	museum.free()
	# Continue: the same night, as it was left
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(3)
	assert_eq(GameState.night, 1)
	assert_eq(museum.exhibits().size(), exhibits - 2)
	for node in museum.exhibits():
		if node.has_meta(Museum.SLOT_META):
			assert_false(gone.has(int(node.get_meta(Museum.SLOT_META))), "destroyed exhibits stay gone")
	assert_eq(_find(museum.pickups_root, "Pickup").size(), loot - 1, "taken loot stays taken")
	assert_eq(museum.player.health.current, 65.0)
	pistol = museum.player.weapons.state_of(&"pistol")
	assert_eq([pistol.magazine, pistol.reserve], [5, 17])
	# death: the next night (a new draw) is full again
	NightRules.on_death(GameState, RunState, Vector3.ZERO)
	assert_eq(GameState.night_progress, {})
	museum.free()
	_museum()
	await physics_frames(3)
	assert_eq(museum.exhibits().size(), NightSpawner.exhibit_count(museum.night) + museum.night.portraits.size())
	var drawn_loot := museum.night.loot.values().filter(func(item: StringName) -> bool: return Museum.LOOT_TYPES.has(item)).size()
	assert_eq(_find(museum.pickups_root, "Pickup").size(), drawn_loot)
	assert_eq(museum.player.health.current, museum.player.health.max_health)


func test_lantern_lands_on_the_floor_not_on_an_exhibit() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var block := StaticBody3D.new()   # an exhibit's back to stand on
	block.collision_layer = Layers.ENEMY
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.2, 2.0)
	shape.shape = box
	block.add_child(shape)
	block.position = Vector3(5.0, 1.1, 5.0)
	museum.add_child(block)
	museum.player.global_position = Vector3(8.0, 0.1, 5.0)
	await physics_frames(12)
	var floor_spot := museum.player.last_floor_position
	museum.player.global_position = Vector3(5.0, 2.4, 5.0)
	await physics_frames(20)
	assert_true(museum.player.is_on_floor(), "standing on it")
	assert_eq(museum.player.last_floor_position, floor_spot, "an exhibit is no floor")
	museum.player.global_position = INSIDE
	await physics_frames(12)
	assert_eq(museum.player.last_floor_position, floor_spot, "neither is the haven")
	museum.free()
	GameState.lantern = {"active": true, "position": [5.0, 2.4, 5.0], "dust": 9}   # an old save
	_museum()
	await physics_frames(3)
	assert_almost_eq(museum.lantern.global_position.y, 0.0, 0.05, "dropped onto the floor")


func test_the_level_uses_the_museum_game_state() -> void:
	var game := PersistentState.new()
	add_child(game)
	game.add_weapon(&"pistol")
	var level := SandboxLevel.new()
	level.game = game
	add_child(level)
	level.build()
	var weapons := _find(level, "WeaponPickup").map(func(node: Node) -> StringName: return (node as WeaponPickup).weapon_id)
	assert_false(weapons.has(&"pistol"), "found in this game")
	assert_true(weapons.has(&"shotgun"))
	level.free()


func test_the_death_screen_hides_the_cursor() -> void:
	_museum()
	await physics_frames(3)
	museum.player.global_position = Vector3(5, 0.1, 5)
	await physics_frames(6)
	var next := watch(museum.next_night_requested)
	museum.player.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BLUNT))
	assert_eq(GameInput.wanted_mouse_mode(), Input.MOUSE_MODE_HIDDEN)
	await get_tree().create_timer(Museum.DEATH_DELAY + DeathScreen.FADE_TIME + DeathScreen.CLOCK_TIME + 0.6).timeout
	assert_eq(next.size(), 1)


func test_quit_to_menu_saves_carried_dust() -> void:
	_museum()
	await physics_frames(2)
	RunState.add_dust(30, false)
	var quit := watch(museum.quit_requested)
	museum.quit_to_menu()
	assert_eq(quit.size(), 1)
	var saved := PersistentState.new()
	add_child(saved)
	saved.load_game()
	assert_eq(saved.run_dust, 30)


func test_death_drops_the_lantern_and_asks_for_the_next_night() -> void:
	_museum()
	await physics_frames(3)
	museum.player.global_position = Vector3(5, 0.1, 5)
	await physics_frames(12)   # lands first
	RunState.add_dust(21, false)
	var next := watch(museum.next_night_requested)
	museum.player.take_damage(DamageInfo.make(999.0, DamageInfo.Kind.BLUNT))
	assert_eq(GameState.night, 2)
	assert_eq(GameState.lantern["dust"], 21)
	assert_false(GameInput.gameplay_input())
	await get_tree().create_timer(Museum.DEATH_DELAY + DeathScreen.FADE_TIME + DeathScreen.CLOCK_TIME + 0.6).timeout
	assert_eq(next.size(), 1)
	var lantern_at: Array = GameState.lantern["position"]
	assert_almost_eq(lantern_at[0], 5.0, 0.2)


func test_night_reload_leaves_no_nodes_behind() -> void:
	await get_tree().process_frame
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 2:
		_museum()
		await physics_frames(3)
		museum.free()
		await get_tree().process_frame
	await get_tree().process_frame
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	assert_lt(after - before, 5.0, "nodes before %d, after %d" % [before, after])
