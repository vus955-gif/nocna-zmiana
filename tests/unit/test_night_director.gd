extends TestCase

var lobby: LevelDescription


func before_each() -> void:
	lobby = LobbyLayout.describe(LobbyLayout.create())


func test_the_same_seed_gives_the_same_night() -> void:
	for night in [1, 2, 5]:
		var a := NightDirector.plan(424242, night, lobby).to_dict()
		var b := NightDirector.plan(424242, night, lobby).to_dict()
		assert_eq(a, b, "night %d" % night)
	var seen := {}
	for night_seed in 10:
		seen[str(NightDirector.plan(night_seed, 3, lobby).to_dict())] = true
	assert_gt(seen.size(), 8, "different seeds, different nights")


func test_night_one_has_no_modifier_and_no_locked_door() -> void:
	for night_seed in 100:
		var config := NightDirector.plan(night_seed, 1, lobby)
		assert_eq(config.modifier, &"none")
		assert_eq(config.locked_door, &"")
		assert_false(config.artifacts.has(NightDirector.JANITOR_KEY), "no key without a locked door")


func test_every_objective_stays_reachable_for_200_seeds() -> void:
	var locked := 0
	for night_seed in 200:
		for night in [2, 3, 4, 5]:
			var config := NightDirector.plan(night_seed * 7919 + night, night, lobby)
			var closed: Array[StringName] = []
			if config.locked_door != &"":
				locked += 1
				assert_true(lobby.lockable_doors.has(config.locked_door))
				closed.append(config.locked_door)
			if not lobby.objectives_reachable(closed):
				fail("seed %d night %d cuts an objective off with %s" % [night_seed, night, config.locked_door])
			var crystal_room := lobby.room_of(config.crystal_case)
			for start in lobby.start_rooms:
				var seen := lobby.graph.reachable(start, closed, lobby.graph.doors_of_room(start))
				assert_true(seen.has(crystal_room))
				for fuse: StringName in config.fuses.values():
					assert_true(seen.has(lobby.room_of(fuse)))
	assert_almost_eq(locked / 800.0, NightDirector.LOCK_CHANCE, 0.06, "about 60% of later nights lock a door")


func test_a_door_that_would_cut_off_an_objective_is_never_locked() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"loop_a", &"start", &"hall", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"loop_b", &"start", &"hall", RoomGraph.Kind.LOCKABLE)
	graph.add_door(&"bridge", &"hall", &"wing", RoomGraph.Kind.LOCKABLE)
	var level := LevelDescription.new()
	level.graph = graph
	level.lockable_doors = graph.doors_of_kind(RoomGraph.Kind.LOCKABLE)
	level.start_rooms = [&"start"] as Array[StringName]
	level.objective_rooms = [&"hall", &"wing"] as Array[StringName]
	assert_eq(NightDirector.safe_doors(level), [&"loop_a", &"loop_b"] as Array[StringName])
	for night_seed in 200:
		assert_ne(NightDirector.plan(night_seed, 3, level).locked_door, &"bridge")


func test_modifiers_follow_the_design_odds() -> void:
	var counts := {}
	var runs := 2000
	for night_seed in runs:
		var modifier := NightDirector.plan(night_seed * 31 + 7, 4, lobby).modifier
		counts[modifier] = counts.get(modifier, 0) + 1
	for entry: Array in NightDirector.MODIFIERS:
		assert_almost_eq(counts.get(entry[0], 0) / float(runs), entry[1] / 100.0, 0.05, str(entry[0]))


func test_every_encounter_room_gets_one_set_with_matching_kinds() -> void:
	var config := NightDirector.plan(99, 2, lobby)
	assert_eq(config.encounter_sets.keys(), lobby.encounter_rooms())
	for spawn in config.spawns:
		var slot := lobby.spawn_slots[spawn.slot]
		assert_eq(slot.set_id, config.encounter_sets[slot.room], "only the chosen set")
		assert_true(slot.kinds.has(spawn.kind))
		if spawn.watcher:
			# the room's watcher (NightDirector.watchers): a sleeper's slot, kept awake
			assert_true(slot.dormant and not spawn.dormant, "a watcher is a sleeper woken to keep watch")
		else:
			assert_eq(spawn.dormant, slot.dormant)
	var sets_seen := {}
	for night_seed in 60:
		var hall_set: int = NightDirector.plan(night_seed, 2, lobby).encounter_sets[&"hall"]
		sets_seen[hall_set] = true
	assert_eq(sets_seen.size(), lobby.sets_in(&"hall").size(), "every hall set comes up")


func test_calm_nights_keep_about_sixty_percent() -> void:
	var calm_nights := 0
	var kept := 0
	var full := 0
	for night_seed in 400:
		var config := NightDirector.plan(night_seed, 3, lobby)
		if config.modifier != &"calm":
			continue
		calm_nights += 1
		for room: StringName in config.encounter_sets:
			var set_size := lobby.spawn_slots.filter(func(s: SpawnSlot) -> bool: return s.room == room and s.set_id == config.encounter_sets[room]).size()
			var placed := config.spawn_count(room, lobby.spawn_slots)
			assert_eq(placed, maxi(1, roundi(set_size * NightDirector.CALM_KEEP)), "room %s" % room)
			kept += placed
			full += set_size
	assert_gt(calm_nights, 40)
	assert_almost_eq(kept / float(full), 0.6, 0.06)


func test_artifacts_go_to_containers_and_the_always_spots() -> void:
	for night_seed in 200:
		var config := NightDirector.plan(night_seed, 2 + night_seed % 4, lobby)
		assert_true(config.artifacts.size() >= 2 and config.artifacts.size() <= 3, "%d artifacts" % config.artifacts.size())
		for spot in lobby.always_artifact_spots:
			assert_true(NightDirector.ARTIFACTS.has(config.loot.get(spot, &"")), "the secret spots always hold one")
		var artifact_spots := 0
		for spot: int in config.loot:
			var item: StringName = config.loot[spot]
			if NightDirector.ARTIFACTS.has(item):
				artifact_spots += 1
				assert_true(lobby.loot_spots[spot].container, "artifact on a loose spot (seed %d)" % night_seed)
			else:
				assert_true(item in [&"bullets", &"shells", &"rifle", &"flares", &"medkit"])
		assert_eq(artifact_spots, config.artifacts.size())
		if config.artifacts.has(NightDirector.JANITOR_KEY):
			assert_ne(config.locked_door, &"", "the key only comes with a locked door")


func test_consumables_fill_about_sixty_percent_of_the_other_spots() -> void:
	var filled := 0
	var total := 0
	for night_seed in 200:
		var config := NightDirector.plan(night_seed, 2, lobby)
		total += lobby.loot_spots.size() - config.artifacts.size()
		filled += config.loot.size() - config.artifacts.size()
	assert_almost_eq(filled / float(total), NightDirector.LOOT_CHANCE, 0.05)


func test_one_fuse_per_wing_from_its_own_points() -> void:
	var used := {}
	for night_seed in 100:
		var config := NightDirector.plan(night_seed, 2, lobby)
		assert_eq(config.fuses.size(), 2)
		for wing: StringName in config.fuses:
			assert_true((lobby.fuse_points[wing] as Array).has(config.fuses[wing]))
			used[config.fuses[wing]] = true
		assert_true(lobby.crystal_cases.has(config.crystal_case))
	assert_eq(used.size(), 4, "both points of both wings come up")


func test_the_janitors_key_comes_only_with_a_locked_door_in_a_case_he_can_reach() -> void:
	var locked_nights := 0
	var key_nights := 0
	for night_seed in 600:
		var config := NightDirector.plan(night_seed * 104729 + 17, 2 + night_seed % 4, lobby)
		var key_spot := -1
		for spot: int in config.loot:
			if config.loot[spot] == NightDirector.JANITOR_KEY:
				key_spot = spot
		if config.locked_door == &"":
			assert_eq(key_spot, -1, "no key without a locked door")
			continue
		locked_nights += 1
		if key_spot < 0:
			continue
		key_nights += 1
		var spot := lobby.loot_spots[key_spot]
		assert_true(spot.container, "in a display case")
		assert_false(lobby.always_artifact_spots.has(key_spot), "never where an artifact always lies")
		assert_false(lobby.secret_rooms.has(spot.room), "never behind a false panel")
		assert_true(lobby.reachable_from_every_start([config.locked_door] as Array[StringName]).has(spot.room), "reachable with the door shut")
	assert_gt(locked_nights, 150)
	assert_almost_eq(key_nights / float(locked_nights), NightDirector.KEY_CHANCE, 0.08)


func test_no_door_on_the_crystals_flight_is_ever_locked() -> void:
	var checked := 0
	for night_seed in 800:
		var config := NightDirector.plan(night_seed * 7919 + 3, 2 + night_seed % 4, lobby)
		if config.locked_door == &"":
			continue
		checked += 1
		assert_false(lobby.crystal_route(config.crystal_case).has(config.locked_door), "seed %d locks %s on the way from %s" % [night_seed, config.locked_door, config.crystal_case])
	assert_gt(checked, 200)
	assert_eq(lobby.crystal_route(&"crystal_case_gallery"), [&"door_hall_gallery"] as Array[StringName])
	assert_eq(lobby.crystal_route(&"crystal_case_armory"), [&"door_hall_armory"] as Array[StringName])


func test_two_to_four_paintings_are_portraits_that_wake() -> void:
	var counts := {}
	var used := {}
	for night_seed in 200:
		var config := NightDirector.plan(night_seed, 1 + night_seed % 5, lobby)
		assert_true(config.portraits.size() >= NightDirector.PORTRAITS.x and config.portraits.size() <= NightDirector.PORTRAITS.y)
		var seen := {}
		for spot in config.portraits:
			assert_true(lobby.portrait_spots.has(spot))
			assert_false(seen.has(spot), "each spot once")
			seen[spot] = true
			used[spot] = true
		counts[config.portraits.size()] = true
		assert_eq(NightDirector.plan(night_seed, 1 + night_seed % 5, lobby).portraits, config.portraits, "the same seed, the same portraits")
	assert_eq(counts.size(), 3, "two, three or four")
	assert_eq(used.size(), lobby.portrait_spots.size(), "any painting may be one")
	# drawn last: the rest of the night is what it was without them
	var plain := LobbyLayout.describe(LobbyLayout.create())
	plain.portrait_spots = [] as Array[StringName]
	var with_them := NightDirector.plan(4242, 3, lobby)
	var without := NightDirector.plan(4242, 3, plain)
	assert_true(without.portraits.is_empty())
	assert_eq(without.fuses, with_them.fuses)
	assert_eq(without.loot, with_them.loot)
	assert_eq(without.spawns.size(), with_them.spawns.size())


func test_too_few_loot_spots_never_break_the_draw() -> void:
	var graph := RoomGraph.new()
	graph.add_door(&"d", &"start", &"hall", RoomGraph.Kind.OPEN)
	var tiny := LevelDescription.new()
	tiny.graph = graph
	tiny.start_rooms = [&"start"] as Array[StringName]
	tiny.objective_rooms = [&"hall"] as Array[StringName]
	tiny.spawn_slots = [SpawnSlot.make(Vector3.ZERO, &"hall", 0, [&"wax"] as Array[StringName])] as Array[SpawnSlot]
	tiny.loot_spots = [LootSpot.make(Vector3.ZERO, &"hall", false)] as Array[LootSpot]
	for night_seed in 20:
		var config := NightDirector.plan(night_seed, 3, tiny)
		assert_lt(config.artifacts.size(), 2, "one spot holds one thing at most")
		assert_lt(config.loot.size(), 2)
	# every night draws on a fresh description: still one warning
	var before := NightDirector.warnings.size()
	for night_seed in 5:
		var again := LevelDescription.new()
		again.graph = graph
		again.start_rooms = tiny.start_rooms
		again.objective_rooms = tiny.objective_rooms
		again.spawn_slots = tiny.spawn_slots
		again.loot_spots = tiny.loot_spots
		NightDirector.plan(night_seed, 3, again)
	assert_eq(NightDirector.warnings.size(), before, "warned once, not every night")
	assert_eq(Array(NightDirector.warnings).filter(func(text: String) -> bool: return text.contains("only 1 loot spots")).size(), 1)


## A seed from a bug report must give the same night in any run of the game
## (golden values: update them only when the draw order changes on purpose).
func test_known_seeds_give_known_nights() -> void:
	var first := NightDirector.plan(12345, 3, lobby)
	assert_eq([first.modifier, first.crystal_case, first.locked_door, first.fuses[&"A"], first.fuses[&"B"]], [&"blackout", &"crystal_case_hall", &"", &"fuse_a_2", &"fuse_b_1"])
	var second := NightDirector.plan(777, 3, lobby)
	assert_eq([second.modifier, second.crystal_case, second.locked_door, second.fuses[&"A"], second.fuses[&"B"]], [&"full_moon", &"crystal_case_gallery", &"door_corridor_w_diorama", &"fuse_a_1", &"fuse_b_1"])


## Design pietro-1-projekt 7.2: night 1 starts gently on the way out of the
## booth - no wolves nor raptors there, at most two awake exhibits.
func test_the_first_night_starts_gently_on_the_way_out() -> void:
	var way := NightDirector.first_way(lobby)
	assert_eq(way, [&"staff_corridor", &"diorama", &"hall"] as Array[StringName])
	for night_seed in 60:
		var config := NightDirector.plan(night_seed, 1, lobby)
		var awake := 0
		for spawn in config.spawns:
			var room := lobby.spawn_slots[spawn.slot].room
			if not way.has(room):
				continue
			assert_false(NightDirector.GENTLE_SWAP.has(spawn.kind), "seed %d: a %s in the %s on night 1" % [night_seed, spawn.kind, room])
			assert_false(spawn.watcher, "seed %d: no watchers on the way out on night 1 (only the level's patrols)" % night_seed)
			if not spawn.dormant:
				awake += 1
		assert_lt(awake, NightDirector.GENTLE_AWAKE + 1, "seed %d: %d awake on the way out" % [night_seed, awake])


func test_later_nights_keep_their_wolves() -> void:
	var wolves := 0
	for night_seed in 30:
		for spawn in NightDirector.plan(night_seed, 2, lobby).spawns:
			if spawn.kind == &"wolf" and lobby.spawn_slots[spawn.slot].room == &"diorama":
				wolves += 1
	assert_gt(wolves, 0, "the gentle start is for night 1 only")


# --- watchers (ecology: one awake per sleeping room) ----------------------------------------

func _three_wax_room() -> LevelDescription:
	var level := LevelDescription.new()
	var kinds: Array[StringName] = [&"wax"]
	for i in 3:
		level.spawn_slots.append(SpawnSlot.make(Vector3(i * 2.0, 0, 0), &"gallery", 0, kinds))
	var pair: Array[StringName] = [&"wax", &"mummy"]
	level.spawn_slots.append(SpawnSlot.make(Vector3(0, 0, 6), &"tombs", SpawnSlot.ALWAYS_SET, pair))
	level.spawn_slots.append(SpawnSlot.make(Vector3(2, 0, 6), &"tombs", SpawnSlot.ALWAYS_SET, pair))
	level.spawn_slots.append(SpawnSlot.make(Vector3(4, 0, 6), &"tombs", SpawnSlot.ALWAYS_SET, pair))
	var busts: Array[StringName] = [&"bust"]
	for i in 3:
		level.spawn_slots.append(SpawnSlot.make(Vector3(i * 2.0, 0, 12), &"study", 0, busts))
	var two: Array[StringName] = [&"knight"]
	for i in 2:
		level.spawn_slots.append(SpawnSlot.make(Vector3(i * 2.0, 0, 18), &"armory", 0, two))
	return level


func test_a_room_of_three_sleepers_gets_one_watcher() -> void:
	var config := NightDirector.plan(99, 2, _three_wax_room())
	var gallery: Array = config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return s.slot < 3)
	assert_eq(gallery.size(), 3)
	var awake: Array = gallery.filter(func(s: NightConfig.Spawn) -> bool: return not s.dormant)
	assert_eq(awake.size(), 1, "one of the three keeps watch")
	assert_true((awake[0] as NightConfig.Spawn).watcher)
	assert_eq(config.to_dict()["spawns"].filter(func(row: Array) -> bool: return row[3]).size(), 1, "to_dict tells which")


func test_ambushes_supports_and_small_rooms_get_no_watcher() -> void:
	var config := NightDirector.plan(99, 2, _three_wax_room())
	for spawn in config.spawns:
		if spawn.slot >= 3 and spawn.slot < 6:
			assert_true(spawn.dormant, "an ambush's mummies sleep in their tombs")
		if spawn.slot >= 6 and spawn.slot < 9:
			assert_true(spawn.dormant, "busts are support: they wait")
		if spawn.slot >= 9:
			assert_true(spawn.dormant, "two knights are too few for a watch")


func test_a_room_with_an_awake_exhibit_keeps_its_draw() -> void:
	var level := _three_wax_room()
	level.spawn_slots[1].dormant = false
	var config := NightDirector.plan(99, 2, level)
	var gallery: Array = config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return s.slot < 3)
	assert_eq(gallery.filter(func(s: NightConfig.Spawn) -> bool: return not s.dormant).size(), 1, "the patrol it had, nobody else")
	assert_false(gallery.any(func(s: NightConfig.Spawn) -> bool: return s.watcher))


## A gallery of [param count] wax sleepers.
func _wax_gallery(count: int) -> LevelDescription:
	var level := LevelDescription.new()
	var kinds: Array[StringName] = [&"wax"]
	for i in count:
		level.spawn_slots.append(SpawnSlot.make(Vector3(i * 2.0, 0, 0), &"gallery", 0, kinds))
	return level


## How many keep watch in a gallery of [param count] wax sleepers on
## [param night], over the seeds whose draw leaves the whole gallery asleep
## (a room with an awake exhibit keeps its draw): one entry per such seed.
func _watchers_in_galleries(count: int, night: int) -> Array[int]:
	var found: Array[int] = []
	for night_seed in 40:
		var config := NightDirector.plan(night_seed, night, _wax_gallery(count))
		var drawn := config.spawns.size()
		var awake_alone := config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return not s.dormant and not s.watcher).size()
		if drawn < count or awake_alone > 0:
			continue
		found.append(config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return s.watcher).size())
	return found


## Review 19.10 (measured on Floor I): three sleepers made a watch on the
## first night too, nearly doubling its exhibits on their feet - the first
## night waits for a room of five.
func test_the_first_night_keeps_watch_only_in_a_room_of_five() -> void:
	assert_eq(NightDirector.watcher_room(1), 5)
	assert_eq(NightDirector.watcher_room(2), 3)
	assert_eq(NightDirector.watcher_room(7), 3)
	var three := _watchers_in_galleries(3, 1)
	var four := _watchers_in_galleries(4, 1)
	var five := _watchers_in_galleries(5, 1)
	var later := _watchers_in_galleries(3, 2)
	assert_gt(three.size() + four.size() + five.size() + later.size(), 20, "(enough seeds leave a whole gallery asleep)")
	for count: int in three + four:
		assert_eq(count, 0, "three or four sleepers, night 1: nobody wakes")
	for count: int in five:
		assert_eq(count, 1, "five, night 1: one keeps watch")
	for count: int in later:
		assert_eq(count, 1, "three, night 2: one keeps watch")


## Saves keep slot indices (night_progress.killed, pack losses) and the
## night is drawn again from its seed; a watcher only stays awake, so an old
## save's slots still name the same exhibits. The rows of to_dict() keep
## their first three fields (slot, kind, dormant) where they were: a reader
## of the old three-field rows reads them the same.
func test_watcher_rows_extend_the_old_three_fields() -> void:
	for night_seed in [5, 777, 12345]:
		var config := NightDirector.plan(night_seed, 3, lobby)
		var rows: Array = config.to_dict()["spawns"]
		assert_eq(rows.size(), config.spawns.size())
		for i in rows.size():
			var row: Array = rows[i]
			var spawn := config.spawns[i]
			assert_eq(row.size(), 4)
			assert_eq(row.slice(0, 3), [spawn.slot, String(spawn.kind), spawn.dormant], "the old fields first, unchanged")
			assert_eq(row[3], spawn.watcher)
			assert_true(lobby.spawn_slots[spawn.slot].kinds.has(spawn.kind), "the slot's own kind: a watcher swaps no kind")


func test_watchers_change_nothing_else_in_the_night() -> void:
	for night_seed in [5, 777, 12345]:
		var with := NightDirector.plan(night_seed, 3, lobby).to_dict()
		var config := NightDirector.plan(night_seed, 3, lobby)
		for spawn in config.spawns:
			if spawn.watcher:
				spawn.dormant = true
				spawn.watcher = false
		var without := config.to_dict()
		with.erase("spawns")
		without.erase("spawns")
		assert_eq(with, without, "seed %d: loot, doors, fuses and portraits as drawn" % night_seed)
	var a := NightDirector.plan(31, 2, lobby).to_dict()
	var b := NightDirector.plan(31, 2, lobby).to_dict()
	assert_eq(a, b, "the same seed picks the same watchers")
