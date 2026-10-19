extends TestCase
## The save keeps the world (QA #51; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md): a
## night played on Floor I - exhibits destroyed, loot taken, the till key,
## weapons, fuses, chess pieces, notes and secrets found, gates broken open
## by their real locks, guardians fallen - then left through the menu, the
## game started afresh (a new GameState read from the file) and the night
## continued: the world (Floor1WorldSnapshot) is the one left behind, but
## for what a resumed night does by design (EXPECTED). Death and dawn: the
## next night built from the file is the one the running game would build.
## At several points of the play order and of a fight.

## Differences a resumed night has by design: [class, text of its state,
## why] (Floor1WorldSnapshot.differences).
const EXPECTED := [
	["NotePaper", "note_key", "Heniek's sticky note about the till key is left out once the key is found"],
	["SecretCache", "present", "a found secret's loose stone is not laid again (the secret is the guard's, in the save)"],
	["TicketDrawer", "\"has_key\":false", "the emptied till drawer is shut again (it says it is empty)"],
]

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


## GameState after the first [param steps] steps of the HUD's play order
## (what the rules give: weapons, items, seals, shards, guardians, gates,
## flags), on night [param night], saved.
func _progress(steps: int, night: int = 2) -> void:
	GameState.new_game()
	var progress := FloorProgress.new()
	var order := Floor1Route.hud_order()
	for k in mini(steps, order.size()):
		Floor1Route.open_what_he_can(progress)
		ProgressRules.apply(progress, order[k])
	Floor1Route.open_what_he_can(progress)
	GameState.weapons.assign(progress.weapons)
	GameState.items.assign(progress.items)
	GameState.seals.assign(progress.seals)
	GameState.shards.assign(progress.shards)
	GameState.guardians_defeated.assign(progress.guardians)
	GameState.gates_open.assign(progress.gates_open)
	GameState.flags.assign(progress.flags)
	GameState.pistol_key = progress.weapons.has(&"pistol")
	GameState.night = night
	GameState.save_game()


## A night's worth of doing things in the museum, through the game's own
## objects: exhibits destroyed, loot taken, and of every kind of thing the
## guard takes or finds with E the first two (the till key, weapons, fuses,
## chess pieces, notes, secrets, artifacts), a gate's lock broken.
func _play() -> void:
	var guard := museum.player
	var killed := 0
	for exhibit in museum.exhibits():
		if killed >= 3 or not exhibit.has_meta(Museum.SLOT_META) or exhibit is Raptor:
			continue
		exhibit.take_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BALLISTIC, guard))
		killed += 1
	await physics_frames(2)
	var taken := 0
	for node in museum.pickups_root.get_children():
		var loot := node as Pickup
		if loot != null and loot.active and taken < 2:
			loot.active = false
			loot.taken.emit()
			taken += 1
	var used := {}
	for node in museum.find_children("*", "Interactable", true, false):
		var thing := node as Interactable
		var kind: String = Floor1WorldSnapshot._kind(thing)
		if not kind in ["TicketDrawer", "WeaponPickup", "ProgressPickup", "NotePaper", "SecretCache", "ArtifactPickup"]:
			continue
		if int(used.get(kind, 0)) >= 2 or not thing.enabled or not is_instance_valid(thing) or thing.is_queued_for_deletion():
			continue
		used[kind] = int(used.get(kind, 0)) + 1
		thing.interact(guard)
		await physics_frames(1)
		if museum.floor_game.world.reader.is_open:
			museum.floor_game.world.reader.close()
	# a minute of the night out of the haven, so its clock runs
	museum.player.global_position = Vector3(0, 0.05, 45)
	museum.watch.clock.elapsed += 60.0
	# a gate's lock broken open, the first one shut
	for gate_id: StringName in museum.floor_game.gates.locks:
		var lock: Node = museum.floor_game.gates.lock_of(gate_id)
		if is_instance_valid(lock) and lock.has_method(&"open") and not bool(lock.get(&"is_open")) and not GameState.is_gate_open(gate_id):
			lock.call(&"open")
			break
	await physics_frames(3)


## Leaves through the menu, starts the game afresh from the file, continues:
## the snapshot before and after, compared.
func _left_and_resumed(label: String) -> Dictionary:
	museum.quit_to_menu()
	await physics_frames(1)
	var before := Floor1WorldSnapshot.take(museum)
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game(), "%s: the save loads" % label)
	_museum()
	await physics_frames(3)
	var after := Floor1WorldSnapshot.take(museum)
	assert_gt((before["things"] as Dictionary).size(), 50, "%s: the world has its things" % label)
	assert_almost_eq(float(after["clock"]), float(before["clock"]), 2.0, "%s: the night's clock goes on where it was" % label)
	for line in Floor1WorldSnapshot.differences(before, after, EXPECTED):
		fail("%s: %s" % [label, line])
	return after


func test_a_first_night_left_and_resumed_is_the_night_left() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(3)
	await _play()
	assert_eq(RunState.killed_slots.size(), 3, "three exhibits destroyed")
	assert_eq(RunState.taken_loot.size(), 2, "two loot boxes taken")
	assert_true(GameState.pistol_key, "the till key found")
	await _left_and_resumed("the first night")


func test_nights_further_on_left_and_resumed_are_the_nights_left() -> void:
	for steps in [6, 12, 17]:
		_progress(steps)
		_museum()
		await physics_frames(3)
		await _play()
		await _left_and_resumed("after %d steps of the play order" % steps)
		museum.free()
		RunState.reset()


func test_an_epilogue_night_left_and_resumed_is_the_night_left() -> void:
	_progress(Floor1Route.hud_order().size(), 5)
	_museum()
	await physics_frames(3)
	await _play()
	await _left_and_resumed("an epilogue night")


func test_a_night_left_in_a_fight_resumes_with_the_guardian_asleep_and_the_rest_as_left() -> void:
	_progress(4)
	_museum()
	await physics_frames(3)
	await _play()
	var keeper := museum.floor_game.guardians
	var colossus: Guardian = keeper.guardians[&"colossus"]
	var start := (museum.floor_level.markers[&"arena_colossus_start"] as Transform3D).origin
	museum.player.global_position = start + Vector3.UP * 0.05
	museum.player.set(&"_grace", 1.0e9)
	for i in 60:
		await get_tree().physics_frame
		if colossus.is_fighting():
			break
	assert_true(colossus.is_fighting(), "the Colossus fights")
	museum.quit_to_menu()
	await physics_frames(1)
	var before := Floor1WorldSnapshot.take(museum)
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(3)
	var after := Floor1WorldSnapshot.take(museum)
	assert_eq(before["guardians"][&"colossus"], "fighting")
	assert_eq(after["guardians"][&"colossus"], "asleep", "the fight starts over")
	(before["guardians"] as Dictionary)["colossus"] = "asleep"
	# (the fight's doors and grilles stood shut when he left)
	var arena := ["Door", "ArenaGrille"]
	for key: String in (before["things"] as Dictionary).keys():
		if arena.any(func(kind: String) -> bool: return key.begins_with(kind + "@")):
			(before["things"] as Dictionary).erase(key)
			(after["things"] as Dictionary).erase(key)
	for line in Floor1WorldSnapshot.differences(before, after, EXPECTED):
		fail("left in the fight: " + line)
	assert_false(keeper.sealed.has(&"colossus") if is_instance_valid(keeper) else false)
	assert_false(museum.floor_game.guardians.sealed.has(&"colossus"), "the arena open")


## Dust lying uncollected when the night is left through the menu lies
## where it lay when the night is continued (QA Q10), and is his to pick up.
func test_dust_lying_when_the_night_is_left_lies_there_when_it_is_resumed() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(3)
	# a burst far from the guard (in the entrance hall; he is in the booth)
	var at := Vector3(0.0, 1.2, 42.0)
	assert_gt(museum.player.global_position.distance_to(at), 20.0, "far from the guard")
	museum.dust_dropper.drop(at, 9)
	await physics_frames(60)
	var lying := Floor1WorldSnapshot.lying_motes(museum)
	assert_gt(lying.size(), 1, "the motes lie there")
	var places: Array[Vector3] = []
	var worth := 0
	for mote in lying:
		places.append(mote.global_position)
		worth += mote.value
	assert_eq(worth, 9)
	var carried := RunState.dust
	museum.quit_to_menu()
	await physics_frames(1)
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game(), "the save loads")
	_museum()
	await physics_frames(3)
	var back := Floor1WorldSnapshot.lying_motes(museum)
	assert_eq(back.size(), places.size(), "every mote is back")
	var back_worth := 0
	for mote in back:
		back_worth += mote.value
		var nearest := INF
		for place in places:
			nearest = minf(nearest, place.distance_to(mote.global_position))
		assert_lt(nearest, 0.3, "a mote where one lay (%s)" % mote.global_position.snapped(Vector3.ONE * 0.1))
	assert_eq(back_worth, worth, "worth what they were")
	assert_eq(RunState.dust, carried, "nothing collected on the way")
	# he walks up to them: they are his
	museum.player.global_position = Vector3(0.0, 0.05, 45.0)
	await physics_frames(90)
	assert_eq(RunState.dust, carried + worth, "collected")
	assert_eq(Floor1WorldSnapshot.lying_motes(museum).size(), 0)


## What a night ends with ([param ending]: "death" or "dawn") carried over
## by the save alone: the next night built straight on (the game's memory)
## and the one built from the file after a fresh start are the same.
func _next_night_from_the_file(ending: String) -> void:
	_progress(8)
	_museum()
	await physics_frames(3)
	await _play()
	var weapons := GameState.weapons.duplicate()
	var items := GameState.items.duplicate()
	var chess := GameState.chess_found.duplicate()
	var night := GameState.night
	match ending:
		"death":
			museum.player.take_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BLUNT))
		"dawn":
			museum.player.global_position = Vector3(-44, 0.05, 12)
			await physics_frames(2)
			museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.1
			await physics_frames(20)
	assert_eq(GameState.night, night + 1, "the %s ends the night" % ending)
	museum.free()
	RunState.reset()
	_museum()
	await physics_frames(3)
	var straight_on := Floor1WorldSnapshot.take(museum)
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game(), "the save loads")
	_museum()
	await physics_frames(3)
	var from_file := Floor1WorldSnapshot.take(museum)
	for line in Floor1WorldSnapshot.differences(straight_on, from_file, EXPECTED):
		fail("the night after the %s: %s" % [ending, line])
	# nothing he picked up is lost
	for id in weapons:
		assert_true(GameState.has_weapon(id), "the %s keeps the weapon %s" % [ending, id])
	for id in items:
		assert_true(GameState.has_item(id), "the %s keeps %s" % [ending, id])
	for id in chess:
		assert_true(GameState.chess_found.has(id), "the %s keeps the chess piece %s" % [ending, id])


func test_the_night_after_a_death_is_the_one_the_save_holds() -> void:
	await _next_night_from_the_file("death")


func test_the_night_after_dawn_is_the_one_the_save_holds() -> void:
	await _next_night_from_the_file("dawn")


## A save written by another build of the game (older or newer layout,
## edited by hand): ids the floor does not know, indices past its lists, a
## lantern off the map, numbers out of range. It loads into a working
## night - nothing crashes, nothing unknown appears, the guard starts in
## the booth.
func test_a_save_of_another_build_loads_into_a_working_night() -> void:
	var data := {
		"version": PersistentState.VERSION,
		"night": 3,
		"seed_base": 12345,
		"upgrades": {"health": 99, "no_such_upgrade": 2},
		"weapons": ["pistol", "laser_cannon"],
		"pistol_key": true,
		"secrets": ["secret_nowhere"],
		"notes": ["note_nowhere"],
		"havens": ["security", "atlantis"],
		"start_haven": "atlantis",
		"lantern": {"active": true, "position": [9999.0, -9999.0, 9999.0], "dust": 40},
		"stats": {"deaths": -4, "nights": "many", "dust_earned": 10, "play_time": -1.0, "bosses": 0},
		"run_dust": 25,
		"night_progress": {"night": 3, "killed": [0, 99999, -2, "x"], "taken": [1, 99999], "used": ["no_such_thing", 7], "guard": {"health": 1e9, "weapons": {"laser_cannon": {"magazine": 5, "reserve": 5}, "pistol": {"magazine": -3, "reserve": 99999}}}, "dust": [[1.0, 2.0], "x", [0.0, 1.2, 42.0, 99999999], [0.0, 1.2, 42.0, -3], [0.0, 1.2, 42.0, 4], 7]},
		"gates_open": ["no_such_gate", "boards_staff_stairs"],
		"guardians_defeated": ["godzilla"],
		"seals": ["seal_of_nothing"],
		"shards": ["shard_nowhere"],
		"items": ["fuse_nowhere"],
		"flags": ["no_such_flag"],
		"rooms_visited": ["no_such_room"],
		"chess_found": ["chess_99"],
		"voice_heard": ["no_such_line"],
		"voice_state": {"destroyed": "lots"},
		"difficulty": "nightmare",
	}
	assert_true(SaveFile.write_json(GameState.path(), data))
	GameState.reset()
	assert_true(GameState.load_game(), "it loads")
	_museum()
	await physics_frames(5)
	assert_true(museum.havens[&"security"].contains(museum.player.global_position), "the night starts in the booth (its start haven is unknown here)")
	assert_true(museum.player.alive)
	assert_true(museum.player.health.current <= museum.player.health.max_health, "no health past his maximum")
	assert_true(museum.player.weapons.has_weapon(&"pistol"))
	assert_false(museum.player.weapons.has_weapon(&"laser_cannon"), "no weapon the build does not know")
	assert_eq(museum.floor_game.guardians.guardians.size(), Floor1Plan.GUARDIANS.size(), "every guardian stands")
	assert_eq(Floor1WorldSnapshot.dust_lying(museum), {"motes": 1, "value": 4}, "of the Dust it says lies about only the mote that can be")
	assert_true(bool(museum.floor_game.gates.lock_of(&"boards_staff_stairs").get(&"is_open")), "the gate it knows is open")
	await physics_frames(30)
	museum.quit_to_menu()
	assert_true(GameState.load_game(), "and it saves and loads again")


## Broken files: cut off half way, binary junk, empty. Each is moved aside
## (save.json.bad) and a fresh game starts - the game runs a night on it.
func test_a_broken_save_file_is_set_aside_and_a_fresh_night_runs() -> void:
	GameState.new_game()
	GameState.open_gate(&"boards_staff_stairs")
	GameState.save_game()
	var whole := FileAccess.get_file_as_string(GameState.path())
	var junk := PackedByteArray()
	for i in 512:
		junk.append((i * 37 + 11) % 256)
	for broken: Variant in [whole.substr(0, whole.length() / 2), junk, ""]:
		SavePaths.clear_test_dir()
		var file := FileAccess.open(GameState.path(), FileAccess.WRITE)
		if broken is String:
			file.store_string(broken)
		else:
			file.store_buffer(broken)
		file.close()
		GameState.reset()
		assert_false(GameState.load_game(), "a broken save does not load")
		assert_eq(GameState.last_load_error, "corrupt", "it is moved aside")
		assert_true(FileAccess.file_exists(GameState.path() + SaveFile.BAD), "kept as .bad")
	_museum()
	await physics_frames(5)
	assert_true(museum.player.alive, "a fresh night runs")
	assert_true(museum.havens[&"security"].contains(museum.player.global_position))
