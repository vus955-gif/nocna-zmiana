extends TestCase
## GuardianKeeper's conventions for the real wing guardians: a guardian's
## script lives at src/game/floor1/guardians/<id>.gd (the registry wins,
## e.g. a test's stand-in); the script may dress its arena (throne,
## columns...) with a static dress_arena(), on every night, even after the
## guardian's fall; the seal and shard lie on arena_<id>_reward when the
## zone has one; hit zones (GuardianZone) pass their name with each hit;
## the difficulty scales a guardian's damage.

const DRESSED := preload("res://tests/support/dressed_guardian.gd")

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	GuardianKeeper.registry.erase(&"colossus")
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func test_a_guardians_script_comes_from_its_folder_unless_registered() -> void:
	assert_eq(GuardianKeeper.script_for(&"no_such_guardian"), null, "no file, no registry: the stub")
	GuardianKeeper.registry[&"colossus"] = DRESSED
	assert_eq(GuardianKeeper.script_for(&"colossus"), DRESSED, "the registry wins")
	assert_eq(GuardianKeeper.GUARDIAN_PATH % "colossus", "res://src/game/floor1/guardians/colossus.gd")


func test_an_arena_is_dressed_by_its_guardian_every_night() -> void:
	GuardianKeeper.registry[&"colossus"] = DRESSED
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var props: Array = keeper.arena_props.get(&"colossus", [])
	assert_eq(props.size(), 1, "the arena's props")
	var seat: Transform3D = museum.floor_level.markers[&"guardian_colossus"]
	if props.size() == 1:
		assert_lt((props[0] as Node3D).global_position.distance_to(seat.origin), 0.01)
	museum.free()
	RunState.reset()
	GameState.defeat_guardian(&"colossus")
	_museum()
	await physics_frames(2)
	assert_false(museum.floor_game.guardians.guardians.has(&"colossus"), "fallen")
	assert_eq((museum.floor_game.guardians.arena_props.get(&"colossus", []) as Array).size(), 1, "its arena still dressed")


func test_rewards_lie_on_the_arenas_reward_spot() -> void:
	GuardianKeeper.registry[&"colossus"] = GuardianStub
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	var guardian: Guardian = keeper.guardians[&"colossus"]
	assert_true(museum.floor_level.markers.has(&"arena_colossus_reward"), "Egypt marks where the seal falls")
	var spot: Vector3 = (museum.floor_level.markers[&"arena_colossus_reward"] as Transform3D).origin
	assert_lt(keeper.reward_spot(Floor1Plan.guardian(&"colossus"), Vector3.ZERO).distance_to(spot), 0.01)
	museum.player.global_position = guardian.global_position - guardian.global_basis.z * 5.0
	await physics_frames(20)
	var info := DamageInfo.make(guardian.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player)
	guardian.take_damage(info)
	await physics_frames(2)
	var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup)
	assert_eq(rewards.size(), 2)
	for pickup: ProgressPickup in rewards:
		assert_lt(Vector2(pickup.global_position.x - spot.x, pickup.global_position.z - spot.z).length(), 1.5, "by the reward spot")


func test_a_zone_passes_its_hits_with_its_name() -> void:
	var guardian: GuardianStub = DRESSED.new()
	add_child(guardian)
	var zone := GuardianZone.make(guardian, &"uraeus")
	guardian.add_child(zone)
	zone.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC))
	guardian.take_damage(DamageInfo.make(5.0, DamageInfo.Kind.BALLISTIC))
	assert_eq(guardian.get(&"zones_hit"), [&"uraeus", &""] as Array[StringName], "the zone's name, then none")
	assert_eq(guardian.hit_zone, &"", "cleared after the hit")
	guardian.free()


func test_the_difficulty_scales_a_guardians_health_and_damage() -> void:
	var guardian := GuardianStub.new()
	DifficultyRules.tune_guardian(guardian, &"double")
	assert_almost_eq(guardian.max_health, 900.0 * 1.2, 0.01)
	assert_almost_eq(guardian.damage_scale, 1.35, 0.001)
	var calm := GuardianStub.new()
	DifficultyRules.tune_guardian(calm, &"calm")
	assert_almost_eq(calm.damage_scale, 0.6, 0.001)
	guardian.free()
	calm.free()
