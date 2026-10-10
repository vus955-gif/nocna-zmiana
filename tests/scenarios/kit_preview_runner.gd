extends Node
## Windowed check of the lobby architecture kit (not part of the headless
## suite). Builds LobbyKitPreview (the real lobby level, dressed with the
## kit by LevelArt, lit with LobbyLightRecipe), renders it at 1920x1080 in
## an offscreen
## SubViewport from scripted camera positions, saves the screenshots to
## tests/_out/kit/ and measures the frame rate.
## Usage: bash tools/run_kit_preview.sh [--shots=wide,stair] [--perf=0]
##        [--preset=low/medium/high/ultra] [--dressing=0]
## The small window only mirrors the offscreen view (its own 3D is off), so
## the FPS figure is the cost of the 1080p frame alone.

const OUT_DIR := "res://tests/_out/kit/"
const SIZE := Vector2i(1920, 1080)
## name: [camera position, look-at point, vertical fov, blackout + flashlight]
const SHOTS := {
	"wide": [Vector3(11.5, 1.7, 19.5), Vector3(-9.0, 4.2, -9.0), 72.0, false],
	"hall_north": [Vector3(4.0, 1.7, 12.0), Vector3(-1.0, 5.0, -20.0), 70.0, false],
	"balcony": [Vector3(-16.2, 7.65, -3.0), Vector3(4.0, 5.2, -12.0), 72.0, false],
	"stair": [Vector3(-11.5, 1.6, 21.3), Vector3(-16.0, 4.2, 8.0), 66.0, false],
	"stair_east": [Vector3(11.0, 1.7, 17.0), Vector3(15.5, 3.0, 10.0), 66.0, false],
	"doorway": [Vector3(-11.0, 1.7, 1.2), Vector3(-26.0, 2.6, 0.0), 62.0, false],
	"gallery": [Vector3(-22.5, 1.7, 8.5), Vector3(-36.0, 2.6, -6.0), 70.0, false],
	"trex": [Vector3(3.5, 1.6, -4.4), Vector3(-1.5, 2.6, -13.0), 66.0, false],
	"security": [Vector3(3.6, 1.65, 55.0), Vector3(-3.5, 1.2, 61.0), 70.0, false],
	"diorama": [Vector3(1.5, 1.7, 25.5), Vector3(-7.0, 3.2, 40.0), 70.0, false],
	"armory": [Vector3(22.0, 1.7, 10.0), Vector3(36.0, 3.0, -6.0), 70.0, false],
	"signs": [Vector3(-6.0, 2.2, 3.0), Vector3(-14.0, 5.0, -0.5), 55.0, false],
	"booth": [Vector3(-7.5, 1.7, 21.0), Vector3(-9.5, 1.6, 15.5), 60.0, false],
	"blackout": [Vector3(11.5, 1.7, 19.5), Vector3(-9.0, 4.2, -9.0), 72.0, true],
}

var preview: LobbyKitPreview
var view: SubViewport
var camera: Camera3D
var flashlight: SpotLight3D
var _mirror: TextureRect
var _shots: PackedStringArray = []
var _perf := true
var _preset := "high"
var _dressing := true
## "sdfgi" (the recipe) or "none" (to compare cost and leaks)
var _gi := "sdfgi"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--perf=0":
			_perf = false
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
		elif arg == "--dressing=0":
			_dressing = false
		elif arg.begins_with("--gi="):
			_gi = arg.trim_prefix("--gi=")
	if _shots.is_empty():
		_shots = PackedStringArray(SHOTS.keys())
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().disable_3d = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE).close()
	view = SubViewport.new()
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_4X
	view.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	view.positional_shadow_atlas_size = 4096
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var t0 := Time.get_ticks_msec()
	preview = (load("res://src/style/lobby_kit_preview.tscn") as PackedScene).instantiate() as LobbyKitPreview
	preview.with_player = false
	preview.dressing = _dressing
	view.add_child(preview)
	var build_ms := Time.get_ticks_msec() - t0
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 200.0
	view.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.15, -0.1, 0.0)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 24.0
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)
	_mirror = TextureRect.new()
	_mirror.texture = view.get_texture()
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mirror.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mirror)
	# the game's graphics preset (low, medium, high, ultra) on the level and the offscreen view
	var presets := {"low": GraphicsQuality.Quality.LOW, "medium": GraphicsQuality.Quality.MEDIUM,
		"high": GraphicsQuality.Quality.HIGH, "ultra": GraphicsQuality.Quality.ULTRA}
	GraphicsQuality.apply_all(get_tree(), presets.get(_preset, GraphicsQuality.Quality.HIGH))
	GraphicsQuality.apply_viewport(view)
	if _gi == "none":
		preview.env.sdfgi_enabled = false
	var stats := preview.stats()
	print("kit preview built in %d ms: %d meshes, %d triangles, %d lights; greybox kits: %s"
		% [build_ms, stats["meshes"], stats["triangles"], stats["lights"], preview.greybox_kits.keys()])
	_place(SHOTS[_shots[0]] if SHOTS.has(_shots[0]) else SHOTS["wide"])
	await _frames(150)   # shaders compile, SDFGI and fog settle, probes render
	var report := {"shots": [], "stats": stats, "build_ms": build_ms, "preset": _preset}
	for shot_name in _shots:
		if not SHOTS.has(shot_name):
			print("unknown shot: ", shot_name)
			continue
		_place(SHOTS[shot_name])
		await _frames(60)
		await _save(shot_name)
		report["shots"].append(shot_name)
	if _perf:
		for shot_name in ["wide", "balcony", "doorway"]:
			_place(SHOTS[shot_name])
			await _frames(40)
			report["fps_" + shot_name] = await _measure(4.0)
		print("FPS at 1920x1080 (preset=%s): wide %.0f, balcony %.0f, doorway %.0f"
			% [_preset, report["fps_wide"], report["fps_balcony"], report["fps_doorway"]])
	var file := FileAccess.open(OUT_DIR.path_join("report_%s.json" % _preset), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	_mirror.texture = null
	view.queue_free()
	await _frames(5)
	get_tree().quit(0)


func _place(shot: Array) -> void:
	camera.position = shot[0]
	camera.look_at(shot[1], Vector3.UP)
	camera.fov = shot[2]
	var dark: bool = shot[3]
	preview.set_main_lights(not dark)
	flashlight.visible = dark


func _measure(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		frames += 1
	return frames / seconds


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var suffix := ("" if _preset == "high" else "_" + _preset) + ("" if _gi == "sdfgi" else "_" + _gi)
	var path := OUT_DIR.path_join("%s%s.png" % [shot_name, suffix])
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
