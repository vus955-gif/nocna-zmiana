extends TestCase

var player: Player
var ground: StaticBody3D


func before_each() -> void:
	ground = Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


## Presses [param action] for exactly one physics frame (use with await).
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)


func test_lands_on_the_floor() -> void:
	await physics_frames(10)
	assert_true(player.is_on_floor())


func test_walks_forward_with_input() -> void:
	await physics_frames(5)
	Input.action_press(&"move_forward")
	await physics_frames(30)
	Input.action_release(&"move_forward")
	assert_lt(player.global_position.z, -1.5)


func test_sprint_is_faster_and_spends_stamina() -> void:
	await physics_frames(5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(30)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	assert_lt(player.global_position.z, -2.5)
	assert_lt(player.stamina.current, 100.0)


func test_dash_moves_quickly_and_costs_stamina() -> void:
	await physics_frames(5)
	assert_true(player.dash(Vector3.FORWARD))
	assert_eq(player.stamina.current, 70.0)
	assert_false(player.dash(Vector3.FORWARD), "cooldown")
	await physics_frames(12)
	assert_lt(player.global_position.z, -1.5)


func test_damage_then_death_then_respawn() -> void:
	var damaged := watch(Events.player_damaged)
	var died := watch(Events.player_died)
	player.take_damage(DamageInfo.make(30.0, DamageInfo.Kind.BLUNT))
	assert_eq(player.health.current, 70.0)
	assert_eq(damaged.size(), 1)
	player.take_damage(DamageInfo.make(100.0, DamageInfo.Kind.BLUNT))
	assert_false(player.alive)
	assert_false(player.weapons.enabled)
	assert_eq(died.size(), 1)
	player.take_damage(DamageInfo.make(10.0, DamageInfo.Kind.BLUNT))
	assert_eq(damaged.size(), 2, "the dead take no more hits")
	player.respawn(Vector3(3, 0.05, 3))
	assert_true(player.alive)
	assert_eq(player.health.current, 100.0)
	assert_true(player.weapons.enabled)


func test_only_own_finishers_heal() -> void:
	player.health.apply_damage(40.0)
	var own := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, player)
	Events.enemy_destroyed.emit(null, own, false)
	assert_eq(player.health.current, 60.0)
	Events.enemy_destroyed.emit(null, own, true)
	assert_eq(player.health.current, 75.0)
	var other := DamageInfo.make(15.0, DamageInfo.Kind.BLUNT, null)
	Events.enemy_destroyed.emit(null, other, true)
	assert_eq(player.health.current, 75.0)


func test_camera_listens_to_shake_requests() -> void:
	Events.shake_requested.emit(0.5)
	assert_almost_eq(player.camera.trauma.value, 0.5)


func test_jump_leaves_the_floor() -> void:
	await physics_frames(10)
	await _tap(&"jump")
	await physics_frames(10)
	assert_gt(player.global_position.y, 0.3)


func test_jump_still_works_just_after_leaving_the_floor() -> void:
	await physics_frames(10)
	ground.global_position.y = -50.0   # the floor drops away
	await physics_frames(3)
	assert_false(player.is_on_floor())
	await _tap(&"jump")
	await physics_frames(2)
	assert_gt(player.velocity.y, 0.0, "coyote jump")


func test_no_jump_long_after_leaving_the_floor() -> void:
	await physics_frames(10)
	ground.global_position.y = -50.0
	await physics_frames(20)
	await _tap(&"jump")
	await physics_frames(2)
	assert_lt(player.velocity.y, 0.0, "coyote time is over")


func test_jump_pressed_just_before_landing_happens_on_landing() -> void:
	await physics_frames(10)
	player.global_position.y = 0.8
	for i in 60:
		await physics_frames(1)
		if player.global_position.y < 0.3:
			break
	assert_false(player.is_on_floor(), "still falling")
	await _tap(&"jump")
	var peak := 0.0
	for i in 30:
		await physics_frames(1)
		peak = maxf(peak, player.global_position.y)
	assert_gt(peak, 0.45, "buffered jump")


func test_respawn_leaves_no_dash_or_sprint_behind() -> void:
	await physics_frames(5)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(3)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	assert_true(player.sprinting, "was sprinting")
	assert_true(player.dash(Vector3.FORWARD))
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	player.respawn(Vector3(3, 0.05, 3))
	assert_false(player.sprinting)
	await physics_frames(20)
	var drift := Vector2(player.global_position.x - 3.0, player.global_position.z - 3.0).length()
	assert_lt(drift, 0.1, "no dash carried over")
	assert_true(player.dash(Vector3.FORWARD), "no dash cooldown carried over")


func test_respawn_restores_the_eye_height() -> void:
	await physics_frames(5)
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	await physics_frames(6)   # the death drop has begun
	player.respawn(Vector3(3, 0.05, 3))
	assert_almost_eq(player.head.global_position.x, 3.0, 0.01, "head moved at once")
	assert_almost_eq(player.head.global_position.y, 0.05 + player.eye_height, 0.01, "head at eye height at once")
	await physics_frames(40)   # longer than the death drop
	assert_almost_eq(player.head.global_position.y - player.global_position.y, player.eye_height, 0.02, "the drop does not resume")


func test_flashlight_key_uses_the_battery() -> void:
	await physics_frames(2)
	await _tap(&"flashlight")
	await get_tree().process_frame
	assert_true(player.battery.on)
	assert_true(player.flashlight.visible)
	await physics_frames(30)
	assert_lt(player.battery.charge, FlashlightBattery.BASE_CAPACITY, "lit, it drains")
	await _tap(&"flashlight")
	await get_tree().process_frame
	assert_false(player.flashlight.visible)


func test_drained_flashlight_goes_dark() -> void:
	player.set_flashlight(true)
	player.battery.tick(FlashlightBattery.BASE_CAPACITY + 1.0)
	await get_tree().process_frame
	assert_false(player.flashlight.visible)
	assert_false(player.set_flashlight(true), "no light from an empty battery")


func test_last_floor_position_follows_the_ground() -> void:
	await physics_frames(5)
	player.global_position = Vector3(4, 0.05, -3)
	await physics_frames(5)
	assert_almost_eq(player.last_floor_position.x, 4.0, 0.05)
	assert_almost_eq(player.last_floor_position.z, -3.0, 0.05)
	ground.global_position.y = -50.0   # the floor drops away
	await physics_frames(2)
	player.global_position = Vector3(8, 0.05, 8)
	await physics_frames(10)
	assert_almost_eq(player.last_floor_position.x, 4.0, 0.05, "falling does not count")


# --- fatigue (plan 2026-10-10-kawiarnia-zmeczenie) ------------------------------

func test_sprinting_and_dashing_tire_the_guard() -> void:
	await physics_frames(5)
	assert_eq(player.fatigue.level, 0.0, "no clock runs here: fresh")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(30)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var after_sprint := player.fatigue.level
	assert_gt(after_sprint, Fatigue.SPRINT_PER_SEC * 0.3, "half a second of sprint")
	await physics_frames(30)
	assert_almost_eq(player.fatigue.level, after_sprint, 0.0001, "walking adds nothing")
	assert_true(player.dash(Vector3.FORWARD))
	assert_almost_eq(player.fatigue.level, after_sprint + Fatigue.DASH, 0.0001)


func test_fatigue_holds_the_stamina_bar_down() -> void:
	await physics_frames(5)
	player.fatigue.level = 1.0
	player.stamina.current = 100.0
	await physics_frames(2)
	assert_almost_eq(player.stamina.capacity_factor, 1.0 - Fatigue.CAPACITY_LOSS, 0.0001)
	assert_almost_eq(player.stamina.current, 70.0, 0.5, "the top of the bar is gone")
	assert_almost_eq(player.stamina.regen_factor, 1.0 - Fatigue.REGEN_LOSS, 0.0001)


func test_a_haven_refill_keeps_the_fatigue_but_a_respawn_clears_it() -> void:
	await physics_frames(5)
	player.fatigue.level = 0.6
	player.fatigue.drink(&"espresso")
	player.refill()
	assert_almost_eq(player.fatigue.level, 0.3, 0.0001, "rest and coffee bring it down, not the medkit")
	assert_true(player.fatigue.caffeinated())
	player.take_damage(DamageInfo.make(500.0, DamageInfo.Kind.BLUNT))
	player.respawn(Vector3(3, 0.05, 3))
	assert_eq(player.fatigue.level, 0.0, "a new night, a fresh guard")
	assert_false(player.fatigue.caffeinated())


func test_tiredness_reaching_a_stage_is_told_on_the_bus() -> void:
	await physics_frames(2)
	var told := watch(Events.fatigue_rose)
	player.fatigue.level = Fatigue.THRESHOLD + 0.01
	await physics_frames(2)
	assert_eq(told.size(), 1, "once")
	if told.size() > 0:
		assert_eq(told[0][0], 1, "stage 1: tired")
