extends TestCase
## NightDirector on Floor I's zones (pure, no scene): the same seed draws the
## same night, ALWAYS_SET slots stand every night, a drawn set is trimmed to
## its room's density, a wing whose guardian fell keeps about 55% of its
## exhibits, night 1 is gentle on the way booth -> entrance hall -> Great
## Court, a locked door is never the only way anywhere, and the difficulty
## scales the loot. Synthetic layouts for the rules, the real floor for the
## floor's own numbers.

const WAX: Array[StringName] = [&"wax"]
const WOLF: Array[StringName] = [&"wolf"]


func _room(layout: LevelLayout, id: StringName, rect: Rect2, zone: StringName) -> RoomSpec:
	var parts: Array[Rect2] = [rect]
	var room := layout.add_room(id, parts, 0.0, 4.0, Color.GRAY)
	room.zone = zone
	return room


## A haven, a corridor and three rooms of [param zone] in a row.
func _wing(zone: StringName = &"egypt", side: float = 40.0) -> LevelLayout:
	var layout := LevelLayout.new()
	_room(layout, &"haven", Rect2(-10, 0, 8, 8), &"booth").haven = true
	_room(layout, &"corridor", Rect2(0, 0, 10, 4), &"entrance")
	layout.add_opening(&"d_haven", Rect2(-2, 1, 2, 2), 0.0, 2.6, &"haven", &"corridor", OpeningSpec.DoorStyle.SWING)
	var previous := &"corridor"
	for i in 3:
		var id := StringName("hall_%d" % i)
		_room(layout, id, Rect2(12 + i * (side + 2), 0, side, side), zone)
		layout.add_opening(StringName("d_%d" % i), Rect2(10 + i * (side + 2), 1, 2, 2), 0.0, 2.6, previous, id, OpeningSpec.DoorStyle.SWING)
		previous = id
	return layout


func _plan(layout: LevelLayout, night_seed: int, night: int = 2, weakened: Array[StringName] = []) -> NightConfig:
	return NightDirector.plan(night_seed, night, MuseumFloorLevel.describe_layout(layout), weakened)


func _count_in(config: NightConfig, layout: LevelLayout, rooms: Array) -> int:
	return config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return rooms.has(layout.spawn_slots[s.slot].room)).size()


func test_the_same_seed_draws_the_same_night_on_the_floor() -> void:
	var layout := Floor1Layout.create()
	GameState.new_game()
	GameState.seed_base = 4242
	GameState.night = 3
	var first := FloorNight.plan(GameState, layout).to_dict()
	var again := FloorNight.plan(GameState, Floor1Layout.create()).to_dict()
	assert_eq(again, first, "same seed, same night")
	GameState.seed_base = 4243
	assert_ne(FloorNight.plan(GameState, layout).to_dict(), first, "another seed, another night")


func test_always_set_slots_stand_every_night() -> void:
	var layout := _wing()
	for i in 4:
		layout.add_spawn(Vector3(20 + i * 2, 0, 10), &"hall_0", i % 2, WAX)
	var always := layout.add_spawn(Vector3(25, 0, 20), &"hall_0", SpawnSlot.ALWAYS_SET, WAX)
	var index := layout.slot_index(always)
	for night_seed in range(1, 21):
		var config := _plan(layout, night_seed)
		var slots := config.spawns.map(func(s: NightConfig.Spawn) -> int: return s.slot)
		assert_true(slots.has(index), "seed %d: the ALWAYS_SET slot stands" % night_seed)
		# a calm night keeps one of the set's two (the set piece always stays)
		assert_eq(slots.size(), 2 if config.modifier == &"calm" else 3, "seed %d: one set of two plus the set piece" % night_seed)
		assert_ne(config.encounter_sets[&"hall_0"], SpawnSlot.ALWAYS_SET)


func test_a_drawn_set_is_trimmed_to_its_rooms_density() -> void:
	# 10 x 10 m of Egypt: a set of five places one with the chance of the
	# room's limit (area x density), never more
	var layout := _wing(&"egypt", 10.0)
	for i in 5:
		layout.add_spawn(Vector3(13 + i * 1.5, 0, 5), &"hall_0", 0, WAX)
	var description := MuseumFloorLevel.describe_layout(layout)
	var limit := 100.0 * float(MuseumFloorLevel.ZONE_DENSITY[&"egypt"]) / 100.0
	assert_almost_eq(description.room_limit(&"hall_0"), limit, 0.001)
	assert_eq(description.room_cap(&"hall_0"), 1)
	assert_eq(description.room_cap(&"nowhere"), -1, "no zone: no cap")
	var seen := {}
	var placed := 0
	var nights := 60
	for night_seed in range(1, nights + 1):
		var config := _plan(layout, night_seed)
		var here := config.spawns.filter(func(s: NightConfig.Spawn) -> bool: return layout.spawn_slots[s.slot].room == &"hall_0")
		assert_true(here.size() <= 1, "seed %d: never more than the cap" % night_seed)
		placed += here.size()
		for spawn: NightConfig.Spawn in here:
			seen[spawn.slot] = true
	assert_almost_eq(float(placed) / nights, limit, 0.2, "on average the room's limit")
	assert_gt(seen.size(), 2, "which one stands changes from night to night")
	# the lobby has no densities: its sets stay whole
	assert_eq(LobbyLayout.describe(LobbyLayout.create()).room_cap(&"hall"), -1)


func test_a_night_on_the_whole_floor_holds_about_126_exhibits() -> void:
	# the zones' densities are tuned to this (measured: 126 on average over
	# 300 seeds, 122 with the calm nights in; the first design had 176)
	var layout := Floor1Layout.create()
	var description := MuseumFloorLevel.describe_layout(layout)
	var nights := 60
	var total := 0
	for night_seed in range(1, nights + 1):
		total += NightDirector.plan(night_seed * 7919, 2, description).spawns.size()
	var average := float(total) / nights
	assert_true(average > 110.0 and average < 140.0, "exhibits a night on average: %.1f" % average)


func test_a_wing_whose_guardian_fell_keeps_about_55_percent() -> void:
	var layout := _wing(&"egypt", 40.0)
	for room: StringName in [&"hall_0", &"hall_1", &"hall_2"]:
		var rect := layout.room(room).parts[0]
		for i in 6:
			layout.add_spawn(Vector3(rect.position.x + 3 + i * 4, 0, 10), room, 0, WAX)
	layout.add_spawn(Vector3(5, 0, 2), &"corridor", 0, WAX)
	var zones: Array[StringName] = [&"egypt"]
	var halls := [&"hall_0", &"hall_1", &"hall_2"]
	# densities that keep every drawn set whole (the halls' 6, the corridor's 1)
	var description := MuseumFloorLevel.describe_layout(layout)
	description.zone_density = {&"egypt": 1.0, &"entrance": 5.0}
	for night_seed in range(1, 11):
		var whole := NightDirector.plan(night_seed, 2, description)
		var weak := NightDirector.plan(night_seed, 2, description, zones)
		if whole.modifier == &"calm":
			continue   # a calm night thins the rooms on its own
		assert_eq(_count_in(whole, layout, halls), 18)
		assert_eq(_count_in(weak, layout, halls), roundi(18 * NightDirector.WEAKENED_KEEP), "seed %d" % night_seed)
		assert_eq(_count_in(weak, layout, [&"corridor"]), 1, "another zone keeps its exhibits")
	var game := PersistentState.new()
	game.defeat_guardian(&"colossus")
	game.defeat_guardian(&"trex")
	assert_eq(FloorNight.weakened_zones(game), [&"egypt"] as Array[StringName])
	game.free()


func test_night_one_is_gentle_from_the_booth_to_the_great_court() -> void:
	var layout := Floor1Layout.create()
	GameState.new_game()
	var description := FloorNight.describe_tonight(GameState, layout)
	var way := NightDirector.first_way(description)
	assert_eq(way, [&"booth_corridor", &"entrance_hall", &"court"] as Array[StringName], "the way out of the booth")
	# wolves everywhere on that way: night 1 makes them wax and puts all but
	# two to sleep; night 2 leaves them
	var first_added := layout.spawn_slots.size()
	for room: StringName in way:
		var rect := layout.room(room).bounds()
		for i in 3:
			layout.add_spawn(Vector3(rect.get_center().x + i, 0, rect.get_center().y), room, SpawnSlot.ALWAYS_SET, WOLF, false)
	for night_seed in range(1, 11):
		GameState.seed_base = night_seed * 977
		GameState.night = 1
		var config := FloorNight.plan(GameState, layout)
		var awake := 0
		for spawn in config.spawns:
			if not way.has(layout.spawn_slots[spawn.slot].room):
				continue
			assert_ne(spawn.kind, &"wolf", "no wolves on the way, seed %d" % night_seed)
			assert_ne(spawn.kind, &"raptor")
			if not spawn.dormant:
				awake += 1
		assert_true(awake <= NightDirector.GENTLE_AWAKE, "at most two awake, seed %d (%d)" % [night_seed, awake])
		GameState.night = 2
		var later := FloorNight.plan(GameState, layout)
		var wolves := later.spawns.filter(func(s: NightConfig.Spawn) -> bool: return s.kind == &"wolf" and s.slot >= first_added)
		assert_eq(wolves.size(), 9, "night 2 is not gentle")


func test_a_locked_door_is_never_the_only_way_anywhere() -> void:
	var layout := LevelLayout.new()
	_room(layout, &"haven", Rect2(-10, 0, 8, 8), &"booth").haven = true
	_room(layout, &"a", Rect2(0, 0, 8, 8), &"egypt")
	_room(layout, &"b", Rect2(10, 0, 8, 8), &"egypt")
	_room(layout, &"c", Rect2(10, 10, 8, 8), &"egypt")
	_room(layout, &"d", Rect2(0, 10, 8, 8), &"egypt")
	_room(layout, &"e", Rect2(20, 0, 8, 8), &"egypt")
	_room(layout, &"vault", Rect2(-10, 10, 8, 8), &"egypt")
	var lockable := RoomGraph.Kind.LOCKABLE
	var swing := OpeningSpec.DoorStyle.SWING
	layout.add_opening(&"haven_a", Rect2(-2, 2, 2, 2), 0.0, 2.6, &"haven", &"a", swing, lockable)   # the only way out
	layout.add_opening(&"a_b", Rect2(8, 2, 2, 2), 0.0, 2.6, &"a", &"b", swing, lockable)   # a loop a-b-c-d
	layout.add_opening(&"b_c", Rect2(12, 8, 2, 2), 0.0, 2.6, &"b", &"c", swing, lockable)
	layout.add_opening(&"c_d", Rect2(8, 12, 2, 2), 0.0, 2.6, &"c", &"d", swing)
	layout.add_opening(&"d_a", Rect2(2, 8, 2, 2), 0.0, 2.6, &"d", &"a", swing)
	layout.add_opening(&"b_e", Rect2(18, 2, 2, 2), 0.0, 2.6, &"b", &"e", swing, lockable)   # the only way to e
	layout.add_opening(&"d_vault", Rect2(-2, 12, 2, 2), 0.0, 2.6, &"d", &"vault", OpeningSpec.DoorStyle.GATE, RoomGraph.Kind.GATE)
	layout.add_gate(&"vault_gate", GateSpec.Kind.SEAL, &"d_vault", &"seal_sun")
	var description := MuseumFloorLevel.describe_layout(layout)
	description.always_open = [&"d_vault"] as Array[StringName]
	var safe := NightDirector.safe_doors(description)
	assert_eq(safe, [&"a_b", &"b_c"] as Array[StringName], "only doors on the loop")
	assert_false(description.lockable_doors.has(&"d_vault"), "a gate is never the night's door")
	# with the vault's gate open, closing a_b and b_c still leaves it reachable
	for night_seed in range(1, 41):
		var door := NightDirector.plan(night_seed, 3, description).locked_door
		assert_true(door == &"" or safe.has(door), "seed %d locked %s" % [night_seed, door])


func test_the_night_knows_the_known_havens_and_the_openable_gates() -> void:
	var layout := Floor1Layout.create()
	GameState.new_game()
	var description := FloorNight.describe_tonight(GameState, layout)
	assert_eq(description.start_rooms, [&"booth_security"] as Array[StringName], "a new game starts only in the booth")
	assert_true(description.always_open.has(&"j_booth_basement"), "the boards on the staff stairs give to fists")
	assert_false(description.always_open.has(&"j_egypt_assyria"), "the Khorsabad Gate needs the Seal of the Sun")
	assert_true(description.objective_rooms.has(&"egypt_conservator"), "every haven must stay reachable")
	assert_almost_eq(float(description.room_areas[&"entrance_hall"]), layout.room(&"entrance_hall").area(), 0.01)
	assert_eq(description.room_zones[&"egypt_gallery"], &"egypt")
	GameState.discover_haven(&"conservator")
	GameState.add_seal(&"seal_sun")
	description = FloorNight.describe_tonight(GameState, layout)
	assert_eq(description.start_rooms, [&"booth_security", &"egypt_conservator"] as Array[StringName])
	assert_true(description.always_open.has(&"j_egypt_assyria"), "with the seal the gate opens tonight")


func test_the_difficulty_scales_the_loot() -> void:
	var layout := Floor1Layout.create()
	var totals := {}
	for difficulty: StringName in DifficultyRules.IDS:
		var total := 0
		for night_seed in range(1, 21):
			GameState.new_game()
			GameState.seed_base = night_seed * 131
			GameState.night = 2
			GameState.difficulty = difficulty
			total += FloorNight.plan(GameState, layout).loot.size()
		totals[difficulty] = total
	assert_gt(totals[&"calm"], totals[&"night"], str(totals))
	assert_gt(totals[&"night"], totals[&"double"], str(totals))


func test_the_lobby_draws_as_before() -> void:
	# no zones, no ALWAYS_SET: the lobby's nights keep their draws
	var description := LobbyLayout.describe(LobbyLayout.create())
	var config := NightDirector.plan(777, 3, description)
	var again := NightDirector.plan(777, 3, description, [] as Array[StringName], 1.0)
	assert_eq(again.to_dict(), config.to_dict())
	assert_true(description.always_open.is_empty())
