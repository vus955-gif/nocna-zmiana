extends TestCase
## The Settings autoload: live application and persistence.

var player: Player


func after_each() -> void:
	Settings.reset_to_defaults(false)


func _spawn_player() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	player = Player.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)


func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


func test_volume_is_relative_to_the_bus_layout() -> void:
	var base := _bus_db(&"SFX")
	assert_lt(base, 0.0, "the layout keeps SFX headroom")
	Settings.set_value(&"volume_sfx", 0.5, false)
	assert_almost_eq(_bus_db(&"SFX"), base + linear_to_db(0.5), 0.01)
	Settings.set_value(&"volume_sfx", 1.0, false)
	assert_almost_eq(_bus_db(&"SFX"), base, 0.01, "full volume = the layout's level")


func test_zero_volume_mutes_the_bus() -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	Settings.set_value(&"volume_music", 0.0, false)
	assert_true(AudioServer.is_bus_mute(bus))
	Settings.set_value(&"volume_music", 0.3, false)
	assert_false(AudioServer.is_bus_mute(bus))


func test_changes_emit_settings_changed() -> void:
	var calls := watch(Settings.settings_changed)
	Settings.set_value(&"fov", 90.0, false)
	Settings.set_value(&"fov", 90.0, false)
	assert_eq(calls.size(), 1, "only real changes are announced")
	if calls.size() == 1:
		assert_eq(calls[0][0], &"fov")


func test_camera_fov_follows_the_setting_live() -> void:
	_spawn_player()
	assert_eq(player.camera.base_fov, 70.0)
	Settings.set_value(&"fov", 100.0, false)
	assert_eq(player.camera.base_fov, 100.0)


func test_turn_speed_follows_sensitivity_and_invert_y() -> void:
	_spawn_player()
	Settings.set_value(&"mouse_sensitivity", 2.0, false)
	assert_almost_eq(player.mouse_sensitivity, GameSettings.BASE_TURN * 2.0, 0.000001)
	player.look(Vector2(0, 10))
	var down := player.head.rotation.x
	assert_lt(down, 0.0, "mouse down looks down")
	player.head.rotation.x = 0.0
	Settings.set_value(&"invert_y", true, false)
	player.look(Vector2(0, 10))
	assert_almost_eq(player.head.rotation.x, -down, 0.0001, "inverted")


func test_settings_are_saved_next_to_the_save_file() -> void:
	Settings.set_value(&"fov", 88.0)
	var path := SavePaths.settings_file()
	assert_eq(path.get_base_dir(), SavePaths.save_file().get_base_dir())
	assert_true(FileAccess.file_exists(path))
	Settings.reset_to_defaults(false)
	Settings.reload()
	assert_eq(Settings.data.fov, 88.0, "read back from settings.cfg")
	DirAccess.remove_absolute(path)


func test_render_scale_and_upscaler_reach_the_viewport() -> void:
	var root := get_tree().root
	Settings.set_value(&"render_scale", 0.75, false)
	Settings.set_value(&"upscaler", SettingsData.Upscaler.FSR2, false)
	assert_almost_eq(root.scaling_3d_scale, 0.75)
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2)
	Settings.reset_to_defaults(false)
	assert_almost_eq(root.scaling_3d_scale, 1.0)
	assert_eq(root.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)


func test_toggle_fullscreen_flips_the_window_mode_setting() -> void:
	Settings.set_value(&"window_mode", SettingsData.WindowMode.WINDOWED, false)
	Settings.toggle_fullscreen()
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.FULLSCREEN)
	Settings.toggle_fullscreen()
	assert_eq(Settings.data.window_mode, SettingsData.WindowMode.WINDOWED, "back to the mode before")
	DirAccess.remove_absolute(SavePaths.settings_file())


func test_menu_changes_are_written_a_moment_later() -> void:
	Settings.set_value(&"fov", 95.0, false)
	assert_false(FileAccess.file_exists(SavePaths.settings_file()), "not on every slider step")
	assert_true(Settings.has_unsaved_changes())
	await get_tree().create_timer(GameSettings.SAVE_DELAY + 0.3).timeout
	assert_false(Settings.has_unsaved_changes())
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))
	Settings.reset_to_defaults(false)
	Settings.reload()
	assert_eq(Settings.data.fov, 95.0)


func test_closing_the_window_writes_waiting_changes() -> void:
	Settings.set_value(&"volume_music", 0.4, false)
	Settings.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_false(Settings.has_unsaved_changes())
	Settings.reset_to_defaults(false)
	Settings.reload()
	assert_almost_eq(Settings.data.volume_music, 0.4)


func test_resetting_to_defaults_without_saving_drops_a_waiting_write() -> void:
	Settings.set_value(&"fov", 100.0, false)
	Settings.reset_to_defaults(false)
	assert_false(Settings.has_unsaved_changes())
	await get_tree().create_timer(GameSettings.SAVE_DELAY + 0.3).timeout
	assert_false(FileAccess.file_exists(SavePaths.settings_file()))


func test_broken_settings_file_is_recovered_from_its_copies() -> void:
	Settings.set_value(&"fov", 80.0)
	Settings.set_value(&"fov", 90.0)   # 80 is the .bak copy now
	var file := FileAccess.open(SavePaths.settings_file(), FileAccess.WRITE)
	file.close()   # cut off to nothing, as by a crash mid-write
	Settings.reload()
	assert_eq(Settings.data.fov, 80.0, "from settings.cfg.bak")
	DirAccess.remove_absolute(SavePaths.settings_file())
	var tmp := FileAccess.open(SavePaths.settings_file() + ".tmp", FileAccess.WRITE)
	tmp.store_string("[settings]\nfov=105.0\n")
	tmp.close()
	Settings.reload()
	assert_eq(Settings.data.fov, 105.0, "an interrupted write is finished")
	assert_true(FileAccess.file_exists(SavePaths.settings_file()))


func test_the_window_mode_is_kept_for_the_next_start_only_by_the_exported_game() -> void:
	assert_eq(GameSettings.startup_file(), "", "not in editor builds or tests")
	assert_eq(GameSettings.engine_window_mode(SettingsData.WindowMode.WINDOWED), DisplayServer.WINDOW_MODE_WINDOWED)
	assert_eq(GameSettings.engine_window_mode(SettingsData.WindowMode.MAXIMIZED), DisplayServer.WINDOW_MODE_MAXIMIZED)
	assert_eq(GameSettings.engine_window_mode(SettingsData.WindowMode.FULLSCREEN), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(GameSettings.engine_window_mode(SettingsData.WindowMode.EXCLUSIVE), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
