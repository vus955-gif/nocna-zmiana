extends TestCase
## ProgressRules over Floor1Plan (design 4.2-4.3): what the first night
## reaches, the critical path step by step through goal(), other orders the
## design allows, guardians behind their keys, bolts that open from one side
## only, soft locks, and random play-throughs that always reach the end.


func _empty() -> FloorProgress:
	return FloorProgress.new()


func _after(steps: Array) -> FloorProgress:
	var progress := _empty()
	for step: StringName in steps:
		assert_true(ProgressRules.can_do(progress, step), "%s can be done after %s" % [step, steps.slice(0, steps.find(step))])
		ProgressRules.apply(progress, step)
	return progress


func test_the_first_night_reaches_the_hub_egypt_greece_and_the_enlightenment() -> void:
	var reached := ProgressRules.reachable_areas(_empty())
	# the roof too: its door at the top of the Enlightenment's tower is bolted
	# on the Enlightenment's side
	for area: StringName in [&"booth", &"entrance", &"court", &"egypt", &"enlightenment", &"greece", &"basement", &"roof"]:
		assert_true(reached.has(area), "%s on night 1" % area)
	for area: StringName in [&"assyria", &"north_hall", &"asia", &"americas", &"reading_room", &"planetarium", &"crypt", &"asia_garden", &"americas_temple"]:
		assert_false(reached.has(area), "%s is locked on night 1" % area)


func test_every_area_is_in_the_area_graph() -> void:
	var everything := ProgressRules.finish(_empty())
	var reached := ProgressRules.reachable_areas(everything)
	for area in Floor1Plan.areas():
		assert_true(reached.has(area), "%s reachable at the end" % area)


func test_the_goal_walks_the_critical_path_in_order() -> void:
	var progress := _empty()
	var expected: Array = ProgressRules.STEPS.map(func(row: Array) -> StringName: return row[0])
	var walked: Array = []
	for i in 40:
		var step := ProgressRules.next_step(progress)
		if step == &"":
			break
		assert_eq(ProgressRules.goal(progress), _goal_key(step), "goal for %s" % step)
		assert_false(ProgressRules.is_soft_locked(progress), "no soft lock before %s" % step)
		walked.append(step)
		ProgressRules.apply(progress, step)
	assert_eq(walked, expected, "the design's order (3.4)")
	assert_true(ProgressRules.is_complete(progress))
	assert_eq(ProgressRules.goal(progress), ProgressRules.GOAL_EPILOGUE)


func test_first_goals_lead_to_a_gun() -> void:
	assert_eq(ProgressRules.goal(_empty()), &"GOAL_TICKET_KEY")
	assert_eq(ProgressRules.goal(_after([&"pistol_key"])), &"GOAL_PISTOL")
	var migrated := _empty()
	migrated.weapons = [&"pistol", &"shotgun"]
	assert_eq(ProgressRules.goal(migrated), &"GOAL_FLARE", "a guard who has the pistol needs no key")
	assert_eq(ProgressRules.goal(_after([&"pistol_key", &"pistol", &"flare"])), &"GOAL_SHOTGUN")


func test_greece_first_opens_the_gatling() -> void:
	var progress := _after([&"pistol_key", &"pistol", &"centaur"])
	assert_true(progress.seals.has(&"seal_owl"))
	assert_true(progress.shards.has(&"shard_greece"))
	assert_true(ProgressRules.can_do(progress, &"gatling"), "the Owl Seal opens the Reading Room")
	assert_false(ProgressRules.can_do(progress, &"lamassu"), "Assyria still needs the Sun Seal")
	assert_false(ProgressRules.is_soft_locked(progress))


func test_the_enlightenment_first_gives_the_star_key() -> void:
	assert_false(ProgressRules.can_do(_empty(), &"planetarium"), "the rope needs the rifle")
	var progress := _after([&"rifle_hunt", &"planetarium"])
	assert_true(progress.seals.has(&"star_key"))
	assert_true(ProgressRules.is_reachable(progress, &"north_hall"), "the North Gate opens")
	assert_false(ProgressRules.is_reachable(progress, &"asia"), "the shutters need power")
	assert_false(ProgressRules.is_reachable(progress, &"americas"))
	assert_false(ProgressRules.is_soft_locked(progress))


func test_the_americas_through_assyria_before_the_power() -> void:
	var progress := _after([&"colossus", &"lamassu"])
	assert_true(ProgressRules.is_reachable(progress, &"americas"), "the Wing Seal opens the Balawat gates")
	assert_false(ProgressRules.is_reachable(progress, &"asia"))
	assert_false(ProgressRules.guardian_reachable(progress, &"serpent"), "the canoe bridge needs the harpoon")
	progress = _after([&"colossus", &"lamassu", &"harpoon", &"serpent"])
	assert_true(progress.shards.has(&"shard_americas"))
	assert_false(ProgressRules.is_soft_locked(progress))


func test_power_needs_both_fuses_and_opens_both_shutters() -> void:
	var progress := _after([&"fuse_basement"])
	assert_false(ProgressRules.can_do(progress, &"power_north"), "one fuse is not enough")
	progress = _after([&"fuse_basement", &"colossus", &"fuse_assyria", &"power_north", &"rifle_hunt", &"planetarium"])
	assert_true(ProgressRules.is_reachable(progress, &"asia"))
	assert_true(ProgressRules.is_reachable(progress, &"americas"))
	assert_false(ProgressRules.guardian_reachable(progress, &"general"), "the cracked wall needs a blast")
	progress.weapons.append(&"flare")
	assert_true(ProgressRules.guardian_reachable(progress, &"general"), "flares break the wall too")


func test_guardians_wait_behind_their_keys() -> void:
	var start := _empty()
	assert_eq(ProgressRules.reachable_guardians(start), [&"colossus", &"centaur"], "Egypt and Greece on night 1")
	assert_false(ProgressRules.guardian_reachable(start, &"lamassu"))
	assert_true(ProgressRules.guardian_reachable(_after([&"colossus"]), &"lamassu"))
	assert_false(ProgressRules.guardian_reachable(_after([&"colossus"]), &"colossus"), "a defeated guardian never comes back")
	assert_false(ProgressRules.guardian_reachable(start, &"planetarium"))
	assert_false(ProgressRules.guardian_reachable(start, &"general"))
	assert_false(ProgressRules.guardian_reachable(start, &"serpent"))


func test_the_finale_needs_all_six_shards() -> void:
	var progress := ProgressRules.finish(_empty())
	assert_true(ProgressRules.is_complete(progress))
	var five := _empty()
	five.shards = [&"shard_egypt", &"shard_assyria", &"shard_greece", &"shard_enlightenment", &"shard_asia"]
	five.seals = [&"seal_owl", &"star_key"]
	assert_false(ProgressRules.can_do(five, &"astrolabe"), "5/6 shards")
	five.shards.append(&"shard_americas")
	assert_true(ProgressRules.can_do(five, &"astrolabe"))
	ProgressRules.apply(five, &"astrolabe")
	assert_true(ProgressRules.can_do(five, ProgressRules.TREX))
	assert_false(ProgressRules.is_reachable(five, &"crypt"), "the grate opens after the T-Rex")
	ProgressRules.apply(five, ProgressRules.TREX)
	assert_true(ProgressRules.is_reachable(five, &"crypt"))
	assert_true(ProgressRules.available_steps(five).has(ProgressRules.DESCEND))


func test_a_bolt_opens_from_its_side_only() -> void:
	var progress := _empty()
	assert_false(ProgressRules.can_open(progress, &"bolt_basement_egypt", &"basement"))
	assert_true(ProgressRules.can_open(progress, &"bolt_basement_egypt", &"egypt"))
	progress.gates_open.append(&"bolt_basement_egypt")
	assert_true(ProgressRules.can_open(progress, &"bolt_basement_egypt", &"basement"), "open for good")
	# a guard starting in the basement workshop gets out only through the bolts he drew
	var below := ProgressRules.reachable_areas(_empty(), ProgressRules.start_area(&"workshop"))
	assert_true(below.has(&"booth"), "the staff stairs (boards) lead back up")
	assert_false(below.has(&"asia"), "Asia's bolt is shut from the basement side")


func test_the_roof_hatch_needs_a_precise_shot() -> void:
	assert_false(ProgressRules.can_open(_empty(), &"rope_roof_hatch", &"entrance"))
	assert_true(ProgressRules.can_open(_after([&"pistol_key", &"pistol"]), &"rope_roof_hatch", &"entrance"))
	var tower: Array[StringName] = [&"j_roof_enlightenment"]
	assert_false(ProgressRules.is_reachable(_empty(), &"roof", ProgressRules.START_AREA, tower), "without the tower, only the hatch")
	assert_true(ProgressRules.is_reachable(_after([&"pistol_key", &"pistol"]), &"roof", ProgressRules.START_AREA, tower))


func test_nights_start_in_the_last_haven() -> void:
	assert_eq(ProgressRules.start_area(&"security"), &"booth")
	assert_eq(ProgressRules.start_area(&"teahouse"), &"asia_garden")
	assert_eq(ProgressRules.start_area(&"nowhere"), &"booth")
	var late := _after([&"rifle_hunt", &"planetarium", &"fuse_basement", &"colossus", &"fuse_assyria", &"power_north", &"hwacha", &"general"])
	var reached := ProgressRules.reachable_areas(late, ProgressRules.start_area(&"teahouse"))
	assert_true(reached.has(&"court"), "from the tea house back to the court")


func test_no_soft_lock_from_any_haven_in_any_state_of_the_critical_path() -> void:
	# a night starts in a haven the guard reached before: at every state of
	# the path, from every haven he could have reached by then
	var progress := _empty()
	var checked := 0
	for row: Array in ProgressRules.STEPS:
		var reached := ProgressRules.reachable_areas(progress)
		for haven in Floor1Plan.havens():
			if reached.has(haven.area):
				assert_false(ProgressRules.is_soft_locked(progress, haven.area), "stuck in %s before %s" % [haven.id, row[0]])
				checked += 1
		ProgressRules.apply(progress, row[0])
	assert_gt(checked, 60)


func test_a_junction_shut_for_good_would_be_a_soft_lock() -> void:
	var closed: Array[StringName] = [&"j_court_egypt"]
	assert_false(ProgressRules.is_reachable(_empty(), &"egypt", ProgressRules.START_AREA, closed))
	assert_true(ProgressRules.is_soft_locked(_empty(), ProgressRules.START_AREA, closed), "Egypt is the only way to the Sun Seal")
	var other: Array[StringName] = [&"j_basement_asia"]
	assert_false(ProgressRules.is_soft_locked(_empty(), ProgressRules.START_AREA, other), "a shortcut is never needed")


func test_random_play_throughs_always_finish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	for run in 40:
		var progress := _empty()
		var steps := 0
		while steps < 60:
			var options := ProgressRules.available_steps(progress)
			if options.is_empty():
				break
			ProgressRules.apply(progress, options[rng.randi_range(0, options.size() - 1)])
			steps += 1
			assert_false(ProgressRules.is_soft_locked(progress), "run %d step %d" % [run, steps])
		assert_true(ProgressRules.is_complete(progress), "run %d finished (stuck after %d steps)" % [run, steps])
		assert_eq(steps, ProgressRules.STEPS.size(), "every step once, optional ones too")


func test_progress_from_the_save() -> void:
	var game := PersistentState.new()
	game.pistol_key = true
	game.weapons = [&"pistol"]
	game.seals = [&"seal_sun"]
	game.gates_open = [&"boards_tomb"]
	game.guardians_defeated = [&"colossus"]
	game.shards = [&"shard_egypt"]
	game.items = [&"fuse_basement"]
	game.flags = [&"power_north"]
	var progress := FloorProgress.from_game(game)
	game.free()
	assert_true(progress.items.has(&"pistol_key"), "the bool key becomes an item")
	assert_true(progress.items.has(&"fuse_basement"))
	assert_true(ProgressRules.is_done(progress, &"colossus"))
	assert_true(ProgressRules.is_done(progress, &"power_north"))
	assert_true(ProgressRules.is_reachable(progress, &"assyria"))


func _goal_key(step: StringName) -> StringName:
	for row: Array in ProgressRules.STEPS:
		if row[0] == step:
			return row[1]
	return &""
