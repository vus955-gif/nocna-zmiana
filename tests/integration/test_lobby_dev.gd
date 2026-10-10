extends TestCase
## The lobby dev viewer runs headless: builds a night, places the guard and
## the exhibits, and its dev keys work.

var dev: LobbyDev


func before_each() -> void:
	GameInput.capture_allowed = false
	dev = (load("res://src/level/lobby_dev.tscn") as PackedScene).instantiate() as LobbyDev
	add_child(dev)
	await physics_frames(3)


func after_each() -> void:
	GameInput.capture_allowed = true


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	dev._unhandled_input(event)


func test_a_night_is_built_with_the_guard_on_the_chair() -> void:
	assert_not_null(dev.level)
	assert_eq(dev.level.room_at(dev.player.global_position + Vector3.UP * 0.1), &"security")
	assert_eq(dev.enemies.get_child_count(), NightSpawner.exhibit_count(dev.config))
	assert_gt(dev.config.spawns.size(), 15)


func test_next_night_rebuilds_everything_once() -> void:
	var first_night := dev.night
	_press(KEY_F5)
	await physics_frames(3)
	assert_eq(dev.night, first_night + 1)
	assert_eq(get_tree().get_nodes_in_group(&"moon").size(), 1, "the old lobby is gone")
	assert_eq(dev.enemies.get_child_count(), NightSpawner.exhibit_count(dev.config))


func test_dev_keys() -> void:
	_press(KEY_F6)
	assert_true(dev.enemies.get_children().all(func(e: Enemy) -> bool: return e.brain.state != EnemyBrain.State.DORMANT))
	_press(KEY_F7)
	assert_true(get_tree().get_nodes_in_group(LightSpec.MAIN).all(func(l: Node3D) -> bool: return not l.visible), "blackout preview")
	_press(KEY_F7)
	assert_true(get_tree().get_nodes_in_group(LightSpec.MAIN).all(func(l: Node3D) -> bool: return l.visible))
	_press(KEY_F8)
	assert_eq(dev.level.room_at(dev.player.global_position + Vector3.UP * 0.2), LobbyDev.TOUR[1])
	_press(KEY_F9)
	assert_false(dev._roofs)


func test_the_windowed_lobby_scenario_script_loads() -> void:
	var script := load("res://tests/scenarios/lobby_scenario.gd") as GDScript
	assert_not_null(script)
	assert_true(script != null and script.can_instantiate())
