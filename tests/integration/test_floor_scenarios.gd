extends TestCase
## The rooms' fight scenarios on the real Floor I (plan
## 2026-10-22-projekt-starc): the beats play in their order where the data
## says, the cast of a beat to come waits held (and on its waiting point),
## a beat wakes its cast after its telegraph, the clock stands while the
## guard is away and while a guardian fights, a pickup plays its beat (and
## the ones before it) at once, the armoury's bell tolls on its own, a
## scenario switched off leaves its room as today, and a night freed and
## built again goes on from the first beat not played.

const NIGHT := 2
## Where the guard stands in each scenario's room (floor points).
const INSIDE := {
	&"greece_nereid": Vector3(-70.0, 0.0, 12.0),
	&"assyria_nimrud": Vector3(-66.0, 0.0, -46.0),
	&"asia_armor": Vector3(38.0, 0.0, -64.5),
}
## Far from every scenario: the Great Court.
const AWAY := Vector3(0.0, 0.0, 8.0)

var museum: Museum
var scenarios: FloorScenarios
var played: Array = []


func before_each() -> void:
	Museum.level_id = &"floor1"
	played.clear()


func after_each() -> void:
	ScenarioCatalog.use(null)
	if is_instance_valid(museum):
		museum.free()


## The first seed whose night NIGHT gives every beat of [param id] its cast
## (and the beats with a waiting point a staged exhibit).
func _seed_for(id: StringName) -> int:
	var layout := Floor1Layout.create()
	var catalog := ScenarioCatalog.active()
	var spec := catalog.find(id)
	for night_seed in range(1, 400):
		GameState.new_game()
		GameState.seed_base = night_seed
		GameState.night = NIGHT
		var cast := ScenarioCast.plan(FloorNight.plan(GameState, layout), layout, catalog)
		var full := true
		var beats: Array = spec["beats"]
		for b in beats.size():
			var slots := cast.slots_of(id, b)
			if slots.is_empty() or (beats[b]["from"] != &"" and not cast.staged.has(slots[0])):
				full = false
		if full:
			return night_seed
	return -1


func _start(night_seed: int) -> void:
	GameState.new_game()
	GameState.seed_base = night_seed
	GameState.night = NIGHT
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	_hook()


func _hook() -> void:
	scenarios = museum.floor_game.scenarios
	scenarios.beat_played.connect(func(id: StringName, beat: StringName) -> void: played.append([id, beat]))


func _go(at: Vector3) -> void:
	museum.player.global_position = at


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001:
		scenarios.advance(FloorScenarios.CHECK)
		t += FloorScenarios.CHECK


func _beats(id: StringName) -> Array:
	return played.filter(func(p: Array) -> bool: return p[0] == id).map(func(p: Array) -> StringName: return p[1])


func _actors(id: StringName, beat: int) -> Array[Enemy]:
	return scenarios.cast_of(scenarios.cast.slots_of(id, beat))


func test_the_nereids_play_contact_porch_and_flank_in_order() -> void:
	var night_seed := _seed_for(&"greece_nereid")
	assert_gt(night_seed, 0, "a night casts every beat of the Nereid hall")
	await _start(night_seed)
	var contact := _actors(&"greece_nereid", 0)
	var porch := _actors(&"greece_nereid", 1)
	var flank := _actors(&"greece_nereid", 2)
	assert_false(contact.is_empty() or porch.is_empty() or flank.is_empty(), "every beat has its cast")
	for exhibit in contact:
		assert_false(exhibit.held, "first contact is not held")
	for exhibit in porch + flank:
		assert_true(exhibit.held, "%s waits for its beat" % exhibit.name)
		assert_eq(exhibit.brain.state, EnemyBrain.State.DORMANT)
	var point: Array = ScenarioCatalog.active().find(&"greece_nereid")["points"][&"metopes_door"]
	assert_lt(Vector2(flank[0].global_position.x - point[0].x, flank[0].global_position.z - point[0].z).length(), 1.5,
			"the flank waits behind the metopes door")
	assert_eq(museum.floor_level.layout.room_at(flank[0].global_position + Vector3.UP * 0.5), &"greece_metopes")
	_run(3.0)
	assert_eq(played, [], "nothing before the guard comes in")
	_go(INSIDE[&"greece_nereid"])
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"greece_nereid"), [&"contact"])
	for exhibit in contact:
		if not exhibit.starts_awake:
			assert_eq(exhibit.brain.state, EnemyBrain.State.DORMANT, "the telegraph comes first")
	assert_eq(scenarios.waking(), 1, "its wake is on its way")
	_run(0.8)
	for exhibit in contact:
		assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "after its lead the contact is awake")
	for exhibit in porch:
		assert_true(exhibit.held, "the porch still waits")
	_run(5.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch"], "the porch after 5 s")
	_run(1.0)
	for exhibit in porch:
		assert_false(exhibit.held)
		assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "the busts on the porch open fire from above")
	_run(8.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch", &"flank"], "then the flank")
	_run(1.0)
	assert_ne(flank[0].brain.state, EnemyBrain.State.DORMANT, "the flank comes in")
	assert_true(GameState != null and RunState.is_used(FloorScenarios.used_id(&"greece_nereid", &"flank")), "each beat is kept with the night")


func test_the_flank_never_waits_by_the_door_the_guard_came_in_through() -> void:
	await _start(_seed_for(&"greece_nereid"))
	var spec := ScenarioCatalog.active().find(&"greece_nereid")
	var flank: Enemy = _actors(&"greece_nereid", 2)[0]
	var metopes: Vector3 = spec["points"][&"metopes_door"][0]
	var bassae: Vector3 = spec["points"][&"bassae_door"][0]
	assert_lt(flank.global_position.distance_to(metopes), 1.0, "it waits by the metopes door")
	# the guard comes in from the metopes, looking into the hall
	museum.player.rotation.y = 0.0
	museum.player.head.rotation = Vector3.ZERO
	_go(Vector3(-72.0, 0.0, 24.0))
	await physics_frames(1)
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"greece_nereid"), [&"contact"])
	assert_lt(flank.global_position.distance_to(bassae), 1.0, "behind his back it went round to the Bassae door")
	assert_lt(flank.home.distance_to(bassae), 1.0, "and that is its post now")
	assert_true(flank.held, "still waiting for its beat")
	_run(13.2)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch", &"flank"])


func test_a_held_exhibit_hears_no_shot_but_a_hit_wakes_it() -> void:
	await _start(_seed_for(&"greece_nereid"))
	var bust: Enemy = _actors(&"greece_nereid", 1)[0]
	PerceptionWorld.noise(bust.global_position + Vector3(2.0, 0.0, 0.0), 30.0)
	assert_eq(bust.brain.state, EnemyBrain.State.DORMANT, "a shot next to it does not fold its beat into this one")
	assert_true(bust.held)
	var info := DamageInfo.make(1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	info.position = bust.global_position + Vector3.UP
	bust.take_damage(info)
	assert_ne(bust.brain.state, EnemyBrain.State.DORMANT, "a hit wakes it as ever")
	assert_false(bust.held, "and awake it hears as any exhibit")


func test_the_clock_stands_while_the_guard_is_away_and_while_a_guardian_fights() -> void:
	await _start(_seed_for(&"greece_nereid"))
	scenarios.fight_check = func() -> bool: return true
	_go(INSIDE[&"greece_nereid"])
	_run(10.0)
	assert_eq(played, [], "nothing plays during a guardian's fight")
	scenarios.fight_check = func() -> bool: return false
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"greece_nereid"), [&"contact"])
	_go(AWAY)
	_run(30.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact"], "the next beat waits for the guard to come back")
	_go(INSIDE[&"greece_nereid"])
	_run(5.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch"])


func test_the_porch_wakes_when_the_guard_climbs_onto_it() -> void:
	await _start(_seed_for(&"greece_nereid"))
	_go(INSIDE[&"greece_nereid"])
	_run(FloorScenarios.CHECK)
	_go(Vector3(-82.5, 4.5, 12.0))
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"greece_nereid"), [&"contact"], "never two beats in one wave")
	_run(FloorScenarios.MIN_GAP)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch"], "the podium is the porch's own trigger, as the ambush's was")


func test_a_contact_fallen_before_its_beat_does_not_fold_the_next_one_in() -> void:
	await _start(_seed_for(&"greece_nereid"))
	for exhibit in _actors(&"greece_nereid", 0):
		exhibit.free()
	_go(INSIDE[&"greece_nereid"])
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"greece_nereid"), [&"contact"])
	_run(3.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact"], "'down' counts the falls since the beat before, not the ones before it")
	_run(2.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch"], "the porch on its clock")


func test_a_fuse_owned_already_lets_the_scaffold_wake_after_the_beat_before() -> void:
	var night_seed := _seed_for(&"assyria_nimrud")
	GameState.new_game()
	GameState.seed_base = night_seed
	GameState.night = NIGHT
	GameState.add_item(&"fuse_assyria")
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	_hook()
	assert_false(museum.floor_game.pickups.items.has(&"fuse_assyria"), "no fuse lies on the trolley tonight")
	var scaffold := _actors(&"assyria_nimrud", 2)
	assert_false(scaffold.is_empty())
	_go(INSIDE[&"assyria_nimrud"])
	_run(FloorScenarios.CHECK)
	_run(7.0)
	assert_eq(_beats(&"assyria_nimrud"), [&"contact", &"behind"])
	_run(FloorScenarios.MIN_GAP + 0.2)
	assert_eq(_beats(&"assyria_nimrud"), [&"contact", &"behind", &"fuse"], "the fuse he owns counts as taken")
	_run(1.0)
	for exhibit in scaffold:
		assert_false(exhibit.held, "not held all night")
		assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "the two by the scaffold step out")


func test_the_vault_guard_gives_itself_away_while_its_beat_waits() -> void:
	await _start(_seed_for(&"asia_armor"))
	var director := museum.floor_game.uncanny
	assert_true(scenarios.ambush_waits(&"asia_armor_guard"), "the scenario took the vault's ambush over")
	assert_false(director._ambush_sleepers(&"asia_armor_guard").is_empty(), "its sleepers may foreshadow it")
	_go(INSIDE[&"asia_armor"])
	museum.floor_game.rooms.check()
	assert_true(director.fire_now(&"fs_armor_guard"), "the glint in a helmet plays while the vault waits")
	_run(FloorScenarios.CHECK)
	_run(15.0)
	assert_eq(_beats(&"asia_armor"), [&"contact", &"bell", &"vault"])
	assert_false(scenarios.ambush_waits(&"asia_armor_guard"))
	assert_true(director._ambush_sleepers(&"asia_armor_guard").is_empty(), "once its beat played it tells nothing")


func test_the_long_gallery_and_the_fuse() -> void:
	var night_seed := _seed_for(&"assyria_nimrud")
	assert_gt(night_seed, 0)
	await _start(night_seed)
	var contact := _actors(&"assyria_nimrud", 0)
	var behind := _actors(&"assyria_nimrud", 1)
	assert_false(contact.is_empty() or behind.is_empty())
	assert_lt(contact[0].global_position.x, behind[0].global_position.x, "the far wall shoots first, the one behind comes after")
	assert_false(museum.floor_game.encounters.waiting.any(func(a: AmbushSpec) -> bool: return a.id == &"assyria_fuse"), "the fuse's ambush is the scenario's now")
	_go(INSIDE[&"assyria_nimrud"])
	_run(FloorScenarios.CHECK)
	assert_eq(_beats(&"assyria_nimrud"), [&"contact"])
	museum.floor_game.pickups.taken.emit(&"fuse_assyria")
	assert_eq(_beats(&"assyria_nimrud"), [&"contact", &"behind", &"fuse"], "taking the fuse plays every beat up to it, in order")
	_run(1.0)
	for exhibit in _actors(&"assyria_nimrud", 2):
		assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "the two by the scaffold step out")


func test_the_armoury_bell_tolls_on_its_own() -> void:
	var night_seed := _seed_for(&"asia_armor")
	assert_gt(night_seed, 0)
	await _start(night_seed)
	var bell: TempleBell = null
	for device in museum.floor_game.biomes.devices:
		if device.device_id == &"asia_bell_armor":
			bell = device
	assert_not_null(bell)
	_go(INSIDE[&"asia_armor"])
	_run(FloorScenarios.CHECK)
	assert_eq(bell.rings, 0)
	_run(6.0)
	assert_eq(_beats(&"asia_armor"), [&"contact", &"bell"])
	assert_eq(bell.rings, 1, "the bell over the islands tolled")
	_run(9.0)
	assert_eq(_beats(&"asia_armor"), [&"contact", &"bell", &"vault"], "then the vault's two")


func test_a_scenario_switched_off_leaves_its_room_as_today() -> void:
	var night_seed := _seed_for(&"greece_nereid")
	ScenarioCatalog.use(ScenarioCatalog.load_default().without(&"greece_nereid"))
	await _start(night_seed)
	var layout := museum.floor_level.layout
	assert_true(museum.floor_game.encounters.waiting.any(func(a: AmbushSpec) -> bool: return a.id == &"greece_podium"), "the podium's ambush waits again")
	var in_hall := 0
	for exhibit in museum.exhibits():
		if not exhibit.has_meta(NightSpawner.SLOT_META):
			continue
		var slot := layout.spawn_slots[int(exhibit.get_meta(NightSpawner.SLOT_META))]
		if slot.room != &"greece_nereid" and slot.room != &"greece_nereid_podium":
			continue
		in_hall += 1
		assert_false(exhibit.held, "nobody held")
		if not exhibit.starts_awake:
			assert_lt(Vector2(exhibit.global_position.x - slot.position.x, exhibit.global_position.z - slot.position.z).length(), 0.3, "on its own slot")
	assert_gt(in_hall, 0)
	_go(INSIDE[&"greece_nereid"])
	_run(20.0)
	assert_eq(_beats(&"greece_nereid"), [], "no beat plays")
	assert_true(_beats(&"assyria_nimrud").is_empty())


func test_a_night_freed_and_built_again_goes_on_from_the_next_beat() -> void:
	await _start(_seed_for(&"greece_nereid"))
	_go(INSIDE[&"greece_nereid"])
	_run(FloorScenarios.CHECK)
	_run(5.0)
	assert_eq(_beats(&"greece_nereid"), [&"contact", &"porch"])
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	played.clear()
	_hook()
	assert_eq(scenarios.plays[0].next, 2, "the beats played before stay played")
	for exhibit in _actors(&"greece_nereid", 1):
		assert_false(exhibit.held, "the porch's busts sleep as any exhibit now")
	for exhibit in _actors(&"greece_nereid", 2):
		assert_true(exhibit.held, "the flank still waits")
	_go(INSIDE[&"greece_nereid"])
	_run(8.0)
	assert_eq(_beats(&"greece_nereid"), [&"flank"], "the night goes on from the flank")
