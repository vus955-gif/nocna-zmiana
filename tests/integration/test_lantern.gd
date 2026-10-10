extends TestCase
## The dropped flashlight with the Dust of the last death.

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	RunState.begin_night(1)


func _lantern(dust: int, at: Vector3) -> DroppedLantern:
	GameState.lantern = {"active": true, "position": [at.x, at.y, at.z], "dust": dust}
	var lantern := DroppedLantern.from_save(GameState)
	add_child(lantern)
	return lantern


func test_touching_the_lantern_returns_the_dust() -> void:
	var lantern := _lantern(42, Vector3(0, 0, -6))
	var recovered := watch(Events.lantern_recovered)
	await physics_frames(3)
	assert_eq(RunState.dust, 0, "out of reach")
	player.global_position = Vector3(0, 0.05, -6)
	await physics_frames(3)
	assert_eq(RunState.dust, 42)
	assert_false(GameState.lantern["active"])
	assert_eq(recovered.size(), 1)
	assert_true(not is_instance_valid(lantern) or lantern.is_queued_for_deletion())


func test_dead_guard_does_not_pick_it_up() -> void:
	_lantern(10, Vector3(0, 0, -6))
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	player.global_position = Vector3(0, 0.05, -6)
	await physics_frames(4)
	assert_eq(RunState.dust, 0)
	assert_true(GameState.lantern["active"])


func test_lantern_glows_through_fog() -> void:
	var lantern := _lantern(5, Vector3(3, 0, 3))
	assert_eq(lantern.position, Vector3(3, 0, 3))
	assert_eq(lantern.dust, 5)
	var light: OmniLight3D = null
	for child in lantern.get_children():
		if child is OmniLight3D:
			light = child
	assert_not_null(light)
	if light != null:
		assert_gt(light.light_energy, 1.0)
		assert_gt(light.light_volumetric_fog_energy, 1.0, "a halo in the fog")
	assert_eq(lantern.collision_layer, Layers.PICKUP)


func test_no_lantern_is_placed_without_one_saved() -> void:
	GameState.lantern = {"active": false, "position": [0.0, 0.0, 0.0], "dust": 0}
	assert_eq(DroppedLantern.from_save(GameState), null)
