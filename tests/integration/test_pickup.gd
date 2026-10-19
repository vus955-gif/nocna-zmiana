extends TestCase

var player: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


func _pickup(type: Pickup.Type, amount: int, at: Vector3) -> Pickup:
	var pickup := Pickup.new()
	pickup.type = type
	pickup.amount = amount
	pickup.position = at
	add_child(pickup)
	return pickup


func test_bullets_refill_the_pistol_reserve() -> void:
	var pistol := player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	pistol.reserve = 0
	var box := _pickup(Pickup.Type.BULLETS, 12, Vector3(5, 0.5, 5))
	assert_true(box.apply_to(player))
	assert_eq(pistol.reserve, 12)


func test_medkit_is_not_wasted_at_full_health() -> void:
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(5, 0.5, 5))
	assert_false(kit.apply_to(player))


func test_medkit_heals_a_hurt_guard() -> void:
	player.health.apply_damage(50.0)
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(5, 0.5, 5))
	assert_true(kit.apply_to(player))
	assert_eq(player.health.current, 75.0)


func test_walking_into_a_pickup_uses_it() -> void:
	player.health.apply_damage(50.0)
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(0, 0.5, 0))
	await physics_frames(5)
	assert_false(kit.active)
	assert_eq(player.health.current, 75.0)


func test_standing_on_a_medkit_uses_it_once_hurt() -> void:
	var kit := _pickup(Pickup.Type.MEDKIT, 25, Vector3(0, 0.5, 0))
	await physics_frames(5)
	assert_true(kit.active, "kept while at full health")
	player.health.apply_damage(50.0)
	await physics_frames(3)
	assert_false(kit.active)
	assert_eq(player.health.current, 75.0)


func test_comes_back_after_respawn_time() -> void:
	var box := _used_bullets(0.3)
	await physics_frames(5)
	assert_false(box.active)
	player.position = Vector3(5, 0.05, 5)   # walks away
	await get_tree().create_timer(0.4).timeout
	assert_true(box.active)


func test_zero_respawn_time_means_it_stays_gone() -> void:
	var box := _used_bullets(0.0)
	await physics_frames(5)
	player.position = Vector3(5, 0.05, 5)
	await get_tree().create_timer(0.3).timeout
	assert_false(box.active)


func test_respawn_waits_while_the_game_is_paused() -> void:
	var box := _used_bullets(0.2)
	await physics_frames(5)
	player.position = Vector3(5, 0.05, 5)
	await physics_frames(2)   # physics notices he left before it freezes
	get_tree().paused = true
	await get_tree().create_timer(0.35).timeout
	var came_back := box.active
	get_tree().paused = false
	assert_false(came_back)


## Every kind wears its model with the rim in its own colour (the HUD
## slot's; white for health) and an accent that stays within limits.
func test_every_kind_wears_its_model_with_its_own_rim() -> void:
	for type in Pickup.Type.values():
		var pickup := _pickup(type, 1, Vector3(5, 0.5, 5))
		var model_name: String = Pickup.MODELS[type]
		var mesh := pickup.find_child(model_name, true, false) as MeshInstance3D
		assert_not_null(mesh, "%s model" % model_name)
		if mesh != null:
			var mat := mesh.get_surface_override_material(0) as ShaderMaterial
			assert_eq(mat.get_shader_parameter(&"rim_color"), Pickup.color_of(type), "%s rim" % model_name)
			assert_lt(float(mat.get_shader_parameter(&"rim_strength")), 1.001, "%s rim strength" % model_name)
			assert_lt(float(mat.get_shader_parameter(&"emit_energy")), WeaponPalette.MAX_PICKUP_EMISSION + 0.001, "%s emission" % model_name)
			assert_eq(mesh.get_instance_shader_parameter(&"awake"), 1.0, "%s lit as a pickup" % model_name)
		pickup.queue_free()


## An ammo box at the guard's feet that he uses right away (empty reserve).
func _used_bullets(respawn_time: float) -> Pickup:
	var pistol := player.weapons.give(load("res://src/weapons/data/pistol.tres"))
	pistol.reserve = 0
	var box := Pickup.new()
	box.type = Pickup.Type.BULLETS
	box.respawn_time = respawn_time
	box.position = Vector3(0, 0.5, 0)
	add_child(box)
	return box
