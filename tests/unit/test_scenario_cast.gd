extends TestCase
## The rooms' fight scenarios as data and their cast (plan
## 2026-10-22-projekt-starc; pure, no scene): the file fits the real floor,
## the catalog refuses what would break a fight (a telegraph under 0.6 s, a
## beat that could wait for ever, a crowd), and the cast only orders the
## exhibits the night drew - the same night the same cast, nothing added,
## sleepers only after the first beat, waiting points only for kinds that
## may leave their post - and one data entry switches a scenario off.

const SCENARIOS: Array[StringName] = [&"greece_nereid", &"assyria_nimrud", &"asia_armor"]

var layout: LevelLayout


func before_each() -> void:
	layout = Floor1Layout.create()


func after_each() -> void:
	ScenarioCatalog.use(null)


## The guardians' arenas (no scenario plays there).
func _arenas() -> Array[StringName]:
	var rooms: Array[StringName] = []
	for guardian in Floor1Plan.guardians():
		var room: StringName = layout.marker_rooms.get(guardian.marker, &"")
		if room != &"":
			rooms.append(room)
	return rooms


func _night(night_seed: int, night: int) -> NightConfig:
	GameState.new_game()
	GameState.seed_base = night_seed
	GameState.night = night
	return FloorNight.plan(GameState, layout)


func test_the_file_fits_the_floor() -> void:
	var catalog := ScenarioCatalog.load_default()
	assert_eq(catalog.errors, PackedStringArray(), "the file reads clean")
	assert_eq(catalog.problems(layout, _arenas()), PackedStringArray(), "every room, ambush, point, sound and bell exists")
	var ids: Array[StringName] = []
	for scenario in catalog.enabled():
		ids.append(scenario["id"])
		assert_true((scenario["beats"] as Array).size() >= 3, "%s: a scenario has at least three beats" % scenario["id"])
	assert_eq(ids, SCENARIOS, "the three gold rooms play")
	assert_false(_arenas().is_empty(), "the arenas are known")


func test_the_catalog_refuses_a_short_telegraph_a_beat_without_an_end_and_a_crowd() -> void:
	var beat := {"id": "a", "count": 1, "lead": 0.8}
	var base := {"id": "x", "rooms": ["greece_vases"], "beats": [beat]}
	var short := base.duplicate(true)
	short["beats"][0]["lead"] = 0.4
	assert_true(ScenarioCatalog.from_data({"scenarios": [short]}).scenarios.is_empty(), "a lead under 0.6 s")
	var crowd := base.duplicate(true)
	crowd["beats"][0]["count"] = 5
	assert_true(ScenarioCatalog.from_data({"scenarios": [crowd]}).scenarios.is_empty(), "more than three at a beat")
	var role := base.duplicate(true)
	role["beats"][0]["roles"] = ["boss"]
	assert_true(ScenarioCatalog.from_data({"scenarios": [role]}).scenarios.is_empty(), "an unknown role")
	var endless := base.duplicate(true)
	endless["beats"].append({"id": "b", "down": 1, "lead": 0.8})
	var catalog := ScenarioCatalog.from_data({"scenarios": [endless]})
	assert_eq(catalog.scenarios.size(), 1)
	assert_true(Array(catalog.problems(layout)).any(func(p: String) -> bool: return p.contains("needs 'after'")),
			"a beat after the first needs a clock: nothing waits for ever")
	var pickup_only := base.duplicate(true)
	pickup_only["beats"].append({"id": "b", "pickup": "fuse_assyria", "lead": 0.8})
	assert_true(Array(ScenarioCatalog.from_data({"scenarios": [pickup_only]}).problems(layout)).any(func(p: String) -> bool: return p.contains("needs 'after'")),
			"a pickup beat needs a clock too: the guard may never take the item")
	var arena := base.duplicate(true)
	arena["rooms"] = ["greece_parthenon"]
	assert_false(ScenarioCatalog.from_data({"scenarios": [arena]}).problems(layout, _arenas()).is_empty(), "never in an arena")
	var haven := base.duplicate(true)
	haven["rooms"] = ["greece_cast_store"]
	assert_false(ScenarioCatalog.from_data({"scenarios": [haven]}).problems(layout, _arenas()).is_empty(), "never in a haven")


func test_a_waiting_point_inside_the_dressing_is_refused() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ScenarioCatalog.PATH))
	var nereid: Dictionary = data["scenarios"][0]
	nereid["points"]["metopes_door"] = [-75.0, 0.0, 28.6, 0.0]   # on the metopes' bench
	var problems := ScenarioCatalog.from_data(data).problems(layout, _arenas())
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("stands in a bench")), "%s" % [problems])


func test_the_same_night_casts_the_same_way() -> void:
	var catalog := ScenarioCatalog.load_default()
	var first := ScenarioCast.plan(_night(4242, 3), layout, catalog).to_dict()
	var again := ScenarioCast.plan(_night(4242, 3), Floor1Layout.create(), catalog).to_dict()
	assert_eq(again, first, "same seed and night, same cast")
	var differs := false
	for night_seed in range(1, 12):
		if ScenarioCast.plan(_night(night_seed, 3), layout, catalog).to_dict() != first:
			differs = true
	assert_true(differs, "other nights cast otherwise")


func test_the_cast_only_orders_the_nights_draw() -> void:
	var catalog := ScenarioCatalog.load_default()
	var cast_somewhere := 0
	for night_seed in range(1, 31):
		for night in [1, 2, 4]:
			var config := _night(night_seed, night)
			var before := config.to_dict()
			var count := NightSpawner.exhibit_count(config)
			var cast := ScenarioCast.plan(config, layout, catalog)
			assert_eq(config.to_dict(), before, "the draw is left as it was (seed %d night %d)" % [night_seed, night])
			assert_eq(NightSpawner.exhibit_count(config), count, "nothing added")
			var drawn := {}
			for spawn in config.spawns:
				drawn[spawn.slot] = spawn
			for id: StringName in cast.actors:
				var scenario := catalog.find(id)
				var beats: Array = scenario["beats"]
				for b in beats.size():
					var slots := cast.slots_of(id, b)
					assert_true(slots.size() <= int(beats[b]["count"]), "%s/%s takes at most its count" % [id, beats[b]["id"]])
					for slot in slots:
						cast_somewhere += 1
						assert_true(drawn.has(slot), "slot %d was drawn tonight" % slot)
						assert_true((scenario["rooms"] as Array).has(layout.spawn_slots[slot].room), "slot %d is in the scenario's rooms" % slot)
						if b > 0:
							assert_true((drawn[slot] as NightConfig.Spawn).dormant, "after the first beat only sleepers wait")
						if cast.staged.has(slot):
							assert_true(ScenarioCast.stageable((drawn[slot] as NightConfig.Spawn).kind), "only a kind that may leave its post waits elsewhere")
							var near := ScenarioCatalog.neighbourhood(layout, scenario["rooms"])
							assert_true(near.has(layout.room_at((cast.staged[slot][0] as Vector3) + Vector3.UP * 0.5)), "it waits in or next to its rooms")
	assert_gt(cast_somewhere, 100, "the scenarios do get their casts")


func test_an_absorbed_ambush_plays_as_its_beat() -> void:
	var catalog := ScenarioCatalog.load_default()
	var config := _night(77, 2)
	var cast := ScenarioCast.plan(config, layout, catalog)
	for pair: Array in [[&"greece_nereid", &"greece_podium", 1], [&"assyria_nimrud", &"assyria_fuse", 2], [&"asia_armor", &"asia_armor_guard", 2]]:
		assert_true(cast.absorbed.has(pair[1]), "%s is taken over" % pair[1])
		var ambush: AmbushSpec = null
		for a in layout.ambushes:
			if a.id == pair[1]:
				ambush = a
		var slots := cast.slots_of(pair[0], pair[2])
		slots.sort()
		assert_eq(slots, ambush.slots, "%s's sleepers are its beat" % pair[1])


func test_one_entry_switches_a_scenario_off() -> void:
	var catalog := ScenarioCatalog.load_default()
	var off := catalog.without(&"greece_nereid")
	var config := _night(77, 2)
	var cast := ScenarioCast.plan(config, layout, off)
	assert_false(cast.playing.has(&"greece_nereid"))
	assert_false(cast.absorbed.has(&"greece_podium"), "its ambush is an ambush again")
	for slot: int in cast.beat_of:
		assert_ne(layout.spawn_slots[slot].room, &"greece_nereid", "nobody in the hall is cast")
	assert_true(cast.playing.has(&"assyria_nimrud"), "the others play on")
	var none := ScenarioCatalog.from_data({"off": ["greece_nereid", "assyria_nimrud", "asia_armor"], "scenarios": []})
	assert_true(ScenarioCast.plan(config, layout, none).beat_of.is_empty())


func test_a_scenario_waits_for_its_first_night() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ScenarioCatalog.PATH))
	for scenario: Dictionary in data["scenarios"]:
		scenario["from_night"] = 3.0
	var later := ScenarioCatalog.from_data(data)
	assert_true(ScenarioCast.plan(_night(5, 2), layout, later).playing.is_empty(), "not before night 3")
	assert_eq(ScenarioCast.plan(_night(5, 3), layout, later).playing.size(), 3)


func test_the_cast_is_kept_with_its_night() -> void:
	var config := _night(9, 2)
	var cast := ScenarioCast.of(config, layout)
	assert_true(ScenarioCast.of(config, layout) == cast, "worked out once a night")
