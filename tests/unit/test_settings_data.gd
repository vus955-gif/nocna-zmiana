extends TestCase
## Option values, defaults, ranges and the settings.cfg format.


func test_defaults_match_the_design() -> void:
	var data := SettingsData.new()
	assert_eq(data.fov, 70.0)
	assert_eq(data.mouse_sensitivity, 1.0)
	assert_false(data.invert_y)
	for key in SettingsData.VOLUME_BUSES:
		assert_eq(data.get_value(key), 1.0, str(key))
	assert_eq(data.window_mode, SettingsData.WindowMode.FULLSCREEN)
	assert_true(data.vsync)
	assert_eq(data.max_fps, 0)
	assert_eq(data.render_scale, 1.0)
	assert_eq(data.upscaler, SettingsData.Upscaler.BILINEAR)
	assert_eq(data.language, "pl")
	assert_false(data.show_fps)


func test_values_are_clamped_to_their_ranges() -> void:
	var data := SettingsData.new()
	data.set_value(&"fov", 200.0)
	assert_eq(data.fov, 110.0)
	data.set_value(&"fov", 10)
	assert_eq(data.fov, 70.0)
	data.set_value(&"mouse_sensitivity", -1.0)
	assert_eq(data.mouse_sensitivity, SettingsData.SENSITIVITY_MIN)
	data.set_value(&"volume_sfx", 3.0)
	assert_eq(data.volume_sfx, 1.0)
	data.set_value(&"render_scale", 0.1)
	assert_eq(data.render_scale, 0.5)
	data.set_value(&"window_mode", 42)
	assert_eq(data.window_mode, SettingsData.WindowMode.FULLSCREEN)
	data.set_value(&"language", "xx")
	assert_eq(data.language, "pl")
	data.set_value(&"max_fps", -5)
	assert_eq(data.max_fps, 0)


func test_config_round_trip_keeps_every_value() -> void:
	var data := SettingsData.new()
	data.set_value(&"mouse_sensitivity", 1.7)
	data.set_value(&"invert_y", true)
	data.set_value(&"fov", 95.0)
	data.set_value(&"volume_music", 0.25)
	data.set_value(&"window_mode", SettingsData.WindowMode.WINDOWED)
	data.set_value(&"vsync", false)
	data.set_value(&"max_fps", 144)
	data.set_value(&"render_scale", 0.75)
	data.set_value(&"upscaler", SettingsData.Upscaler.FSR2)
	data.set_value(&"language", "en")
	data.set_value(&"show_fps", true)
	var config := ConfigFile.new()
	data.to_config(config)
	var text := config.encode_to_text()
	var parsed := ConfigFile.new()
	assert_eq(parsed.parse(text), OK)
	var loaded := SettingsData.new()
	loaded.from_config(parsed)
	for key in SettingsData.keys():
		assert_eq(loaded.get_value(key), data.get_value(key), str(key))


func test_wrong_types_in_the_file_fall_back_to_defaults() -> void:
	var config := ConfigFile.new()
	config.set_value(SettingsData.SECTION, "fov", "wide")
	config.set_value(SettingsData.SECTION, "invert_y", 1)
	config.set_value(SettingsData.SECTION, "volume_sfx", [0.5])
	config.set_value(SettingsData.SECTION, "max_fps", 60)
	var data := SettingsData.new()
	data.from_config(config)
	assert_eq(data.fov, 70.0)
	assert_false(data.invert_y)
	assert_eq(data.volume_sfx, 1.0)
	assert_eq(data.max_fps, 60, "valid entries still load")


func test_unknown_keys_are_rejected() -> void:
	var data := SettingsData.new()
	assert_false(data.set_value(&"god_mode", true))
	assert_eq(data.get_value(&"god_mode"), null)


func test_nan_and_infinity_are_rejected() -> void:
	var data := SettingsData.new()
	assert_false(data.set_value(&"fov", NAN))
	assert_false(data.set_value(&"mouse_sensitivity", INF))
	assert_false(data.set_value(&"volume_music", -INF))
	assert_eq(data.fov, 70.0)
	assert_eq(data.mouse_sensitivity, 1.0)
	var config := ConfigFile.new()
	assert_eq(config.parse("[settings]\nfov=nan\nrender_scale=inf\n"), OK)
	data.from_config(config)
	assert_eq(data.fov, 70.0, "a hand-edited nan keeps the default")
	assert_eq(data.render_scale, 1.0)
