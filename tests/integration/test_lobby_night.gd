extends TestCase
## A drawn night applied to the built lobby.

var level: LobbyLevel


func _night_with_locked(door: StringName) -> NightConfig:
	var description := LobbyLayout.describe(LobbyLayout.create())
	for night_seed in 500:
		var config := NightDirector.plan(night_seed, 3, description)
		if config.locked_door == door:
			return config
	return null


func _build(config: NightConfig) -> void:
	level = LobbyLevel.new()
	level.night = config
	add_child(level)
	level.build()


func test_a_night_set_before_building_bakes_with_its_door_locked() -> void:
	var config := _night_with_locked(&"door_hall_gallery")
	assert_not_null(config)
	if config == null:
		return
	_build(config)
	var door: Door = level.doors[&"door_hall_gallery"]
	assert_true(door.locked)
	assert_false(level.navigation.is_baking(), "no second bake needed")
	await physics_frames(8)
	var walker := Node3D.new()
	walker.position = Vector3(-12, 0, 0)
	add_child(walker)
	var agent := NavigationAgent3D.new()
	walker.add_child(agent)
	await physics_frames(2)
	agent.target_position = Vector3(-26, 0, 2)
	agent.get_final_position()
	var path := agent.get_current_navigation_path()
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	assert_gt(length, 60.0, "round through the west corridor")


func test_applying_another_night_moves_the_lock() -> void:
	_build(_night_with_locked(&"door_hall_armory"))
	var other := _night_with_locked(&"door_corridor_w_diorama")
	level.apply_night(other)
	assert_false((level.doors[&"door_hall_armory"] as Door).locked)
	assert_true((level.doors[&"door_hall_armory"] as Door).is_open)
	assert_true((level.doors[&"door_corridor_w_diorama"] as Door).locked)
	assert_true(level.navigation.is_baking(), "the change rebakes the navmesh")


func test_the_spawner_places_the_night_on_its_slots() -> void:
	var config := NightDirector.plan(2026, 2, LobbyLayout.describe(LobbyLayout.create()))
	_build(config)
	var root := Node3D.new()
	add_child(root)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, 58)
	add_child(target)
	var placed := NightSpawner.spawn(config, level.spawn_slots, root, target)
	assert_eq(placed.size(), NightSpawner.exhibit_count(config))
	var by_slot := _by_slot(placed)
	assert_eq(by_slot.size(), config.spawns.size())
	for entry in config.spawns:
		var slot := level.spawn_slots[entry.slot]
		var members: Array = by_slot.get(entry.slot, [])
		assert_eq(members.size(), NightSpawner.pack_size(config, entry.slot) if entry.kind == NightSpawner.PACK else 1)
		for exhibit: Enemy in members:
			var reach := RaptorPack.SPREAD + 0.1 if entry.kind == NightSpawner.PACK else 0.1
			assert_lt(exhibit.global_position.distance_to(slot.position), reach)
			assert_eq(exhibit.brain.state == EnemyBrain.State.DORMANT, entry.dormant)
		if entry.kind == &"bust":
			assert_true(members[0] is Bust)


func _by_slot(placed: Array[Enemy]) -> Dictionary:
	var by_slot := {}
	for exhibit in placed:
		var slot: int = exhibit.get_meta(NightSpawner.SLOT_META)
		if not by_slot.has(slot):
			by_slot[slot] = []
		(by_slot[slot] as Array).append(exhibit)
	return by_slot


## A raptor slot holds a pack of 3-4 (the same pack for the same night),
## flanking both ways, under one slot index.
func test_a_raptor_slot_brings_a_whole_pack() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	var config: NightConfig = null
	for night_seed in 200:
		var drawn := NightDirector.plan(night_seed, 3, description)
		if drawn.spawns.any(func(entry: NightConfig.Spawn) -> bool: return entry.kind == NightSpawner.PACK):
			config = drawn
			break
	assert_not_null(config, "some nights draw a pack")
	if config == null:
		return
	_build(config)
	var root := Node3D.new()
	add_child(root)
	var sizes := {}
	for entry in config.spawns:
		if entry.kind != NightSpawner.PACK:
			continue
		var pack: Array = _by_slot(NightSpawner.spawn(config, level.spawn_slots, root))[entry.slot]
		assert_true(pack.size() >= RaptorPack.MIN_SIZE and pack.size() <= RaptorPack.MAX_SIZE, "%d raptors" % pack.size())
		assert_eq(pack.size(), NightSpawner.pack_size(config, entry.slot), "the same night, the same pack")
		var sides := {}
		for raptor: Enemy in pack:
			assert_true(raptor is Raptor)
			sides[(raptor as Raptor).flank_side] = true
		assert_eq(sides.size(), 2, "half right, half left")
		sizes[pack.size()] = true
		break
	for night_seed in 50:
		var other := NightConfig.new()
		other.night_seed = night_seed
		other.night = 2
		sizes[NightSpawner.pack_size(other, 3)] = true
	assert_eq(_sorted_keys(sizes), [3, 4], "packs of three and of four")


func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
