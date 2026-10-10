class_name GameSettings
extends Node
## Player options (autoload "Settings"). Loads settings.cfg (it lives next to
## the save, see SavePaths), applies every option live and announces changes
## through settings_changed (key &"" = everything changed). This is the only
## place that changes the window mode; F11 goes through toggle_fullscreen().
## A change is written to settings.cfg SAVE_DELAY seconds after the last one
## (sliders change on every step), and at the latest when the window is
## closed or the game quits.
## The exported game also keeps the window mode in override.cfg next to the
## exe: the engine reads that file before it opens the window, so a game
## set to a window does not flash up in fullscreen first. (Graj.bat reads
## the mode from settings.cfg for the same reason.)

signal settings_changed(key: StringName)

## Turn per mouse pixel (radians) at sensitivity 1.0.
const BASE_TURN := 0.0022
## Size of the window when switching back to windowed mode.
const WINDOWED_SIZE := Vector2i(1600, 900)
## Seconds after the last change before settings.cfg is written.
const SAVE_DELAY := 0.75
const STARTUP_FILE := "override.cfg"

var data := SettingsData.new()
## Bus volumes of the layout (the SFX bus keeps its headroom under the slider).
var _base_volume_db: Dictionary = {}
## Where F11 returns to from fullscreen.
var _windowed_mode: int = SettingsData.WindowMode.MAXIMIZED
## A change not written to settings.cfg yet.
var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.ignore_time_scale = true
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	for key in SettingsData.VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(SettingsData.VOLUME_BUSES[key])
		_base_volume_db[key] = AudioServer.get_bus_volume_db(bus) if bus >= 0 else 0.0
	reload()


func _exit_tree() -> void:
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func get_value(key: StringName) -> Variant:
	return data.get_value(key)


## Changes one option and applies it at once. With [param persist]
## settings.cfg is written now; without it (menus) a moment later.
func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	var before: Variant = data.get_value(key)
	if not data.set_value(key, value):
		push_warning("Settings: rejected %s = %s" % [key, value])
		return
	var changed: bool = data.get_value(key) != before
	if changed:
		_apply(key)
		settings_changed.emit(key)
		if key == &"graphics_quality":
			# a preset brings its render scale (the slider stays free after)
			set_value(&"render_scale", GraphicsQuality.preset(data.graphics_quality)["render_scale"], persist)
	if persist:
		save()
	elif changed:
		_schedule_save()


## Writes settings.cfg now (a delayed write still waiting is dropped).
func save() -> bool:
	_dirty = false
	if _save_timer != null:
		_save_timer.stop()
	var config := ConfigFile.new()
	data.to_config(config)
	var ok := SaveFile.write_text(SavePaths.settings_file(), config.encode_to_text())
	_write_startup_window()
	return ok


## Writes settings.cfg if a change is still waiting to be written.
func flush() -> void:
	if _dirty:
		save()


func has_unsaved_changes() -> bool:
	return _dirty


## Reads settings.cfg again (its .tmp or .bak copy when it is broken;
## defaults when there is none) and applies it. Unwritten changes are lost.
func reload() -> void:
	_cancel_save()
	data = SettingsData.new()
	var text := SaveFile.read_text(SavePaths.settings_file(), func(candidate: String) -> bool:
		return ConfigFile.new().parse(candidate) == OK)
	var config := ConfigFile.new()
	if text != "" and config.parse(text) == OK:
		data.from_config(config)
	if not config.has_section_key(SettingsData.SECTION, "graphics_quality"):
		data.graphics_quality = GraphicsQuality.detect()
	apply_all()
	settings_changed.emit(&"")


## Back to the defaults: written now with [param persist], else not at all.
func reset_to_defaults(persist: bool = false) -> void:
	_cancel_save()
	data = SettingsData.new()
	data.graphics_quality = GraphicsQuality.detect()
	apply_all()
	settings_changed.emit(&"")
	if persist:
		save()


func apply_all() -> void:
	for key in SettingsData.keys():
		_apply(key)


## F11: fullscreen <-> the windowed mode used before.
func toggle_fullscreen() -> void:
	var mode := data.window_mode
	if mode == SettingsData.WindowMode.FULLSCREEN or mode == SettingsData.WindowMode.EXCLUSIVE:
		set_value(&"window_mode", _windowed_mode)
	else:
		_windowed_mode = mode
		set_value(&"window_mode", SettingsData.WindowMode.FULLSCREEN)


func mouse_turn_per_pixel() -> float:
	return BASE_TURN * data.mouse_sensitivity


## Where the exported game keeps the window mode for the next start ("" =
## not kept: editor builds, tests, redirected or fallback saves).
static func startup_file() -> String:
	if not OS.has_feature("template") or SavePaths.is_test_run() or SavePaths.is_redirected() or SavePaths.uses_user_dir():
		return ""
	return OS.get_executable_path().get_base_dir().path_join(STARTUP_FILE)


## The engine's display/window/size/mode for a WindowMode.
static func engine_window_mode(mode: int) -> DisplayServer.WindowMode:
	match mode:
		SettingsData.WindowMode.WINDOWED:
			return DisplayServer.WINDOW_MODE_WINDOWED
		SettingsData.WindowMode.MAXIMIZED:
			return DisplayServer.WINDOW_MODE_MAXIMIZED
		SettingsData.WindowMode.EXCLUSIVE:
			return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_FULLSCREEN


func _schedule_save() -> void:
	_dirty = true
	if _save_timer != null:
		_save_timer.start(SAVE_DELAY)


func _cancel_save() -> void:
	_dirty = false
	if _save_timer != null:
		_save_timer.stop()


func _apply(key: StringName) -> void:
	if SettingsData.VOLUME_BUSES.has(key):
		_apply_volume(key)
		return
	match key:
		&"window_mode":
			_apply_window_mode()
		&"vsync":
			if _display_enabled():
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
		&"max_fps":
			Engine.max_fps = data.max_fps
		&"render_scale", &"upscaler":
			_apply_render_scale()
		&"language":
			TranslationServer.set_locale(data.language)
		&"graphics_quality":
			GraphicsQuality.apply_all(get_tree() if is_inside_tree() else null, data.graphics_quality)


func _apply_volume(key: StringName) -> void:
	var bus := AudioServer.get_bus_index(SettingsData.VOLUME_BUSES[key])
	if bus < 0:
		return
	var level: float = data.get_value(key)
	AudioServer.set_bus_mute(bus, level <= 0.0)
	if level > 0.0:
		AudioServer.set_bus_volume_db(bus, float(_base_volume_db.get(key, 0.0)) + linear_to_db(level))


func _apply_window_mode() -> void:
	if not _display_enabled():
		return
	var wanted := engine_window_mode(data.window_mode)
	if DisplayServer.window_get_mode() == wanted:
		if wanted == DisplayServer.WINDOW_MODE_WINDOWED:
			_fit_window(false)
		return
	DisplayServer.window_set_mode(wanted)
	if wanted == DisplayServer.WINDOW_MODE_WINDOWED:
		_fit_window(true)


## Gives a window the windowed size, centred ([param always]), or only
## shrinks one that does not fit the screen.
func _fit_window(always: bool) -> void:
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := _windowed_size(area)
	var current := DisplayServer.window_get_size()
	if not always and current.x <= area.size.x and current.y <= area.size.y:
		return
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


static func _windowed_size(area: Rect2i) -> Vector2i:
	return Vector2i(mini(WINDOWED_SIZE.x, area.size.x), mini(WINDOWED_SIZE.y, area.size.y))


## Keeps the window mode in override.cfg next to the exported game's exe.
func _write_startup_window() -> void:
	var path := startup_file()
	if path == "":
		return
	var config := ConfigFile.new()
	var mode := engine_window_mode(data.window_mode)
	config.set_value("display", "window/size/mode", mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED and _display_enabled():
		var size := _windowed_size(DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()))
		config.set_value("display", "window/size/window_width_override", size.x)
		config.set_value("display", "window/size/window_height_override", size.y)
	if config.save(path) != OK:
		push_warning("Settings: could not write " + path)


func _apply_render_scale() -> void:
	var root := get_tree().root
	match data.upscaler:
		SettingsData.Upscaler.FSR:
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		SettingsData.Upscaler.FSR2:
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_:
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = data.render_scale


## Window changes only for a real window and never in test/scenario runs
## (the scenario sets its own window size). Runs with redirected saves
## (--save-dir, NZ_SAVE_DIR) still apply them.
func _display_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not SavePaths.is_test_run()
