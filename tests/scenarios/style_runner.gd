extends Node
## Windowed style-sample check (not part of the headless suite). Builds the
## stage 1b style sample, renders it at 1920x1080 in an offscreen SubViewport
## from scripted camera positions, saves the screenshots to tests/_out/style/
## and measures the frame rate of the wide view.
## Usage: bash tools/run_style.sh [--shots=wide,figure] [--gi=sdfgi|voxel|none]
##        [--preset=high|low] [--perf=0]
## Screenshots are named <shot>.png for the default (sdfgi, high) and
## <shot>_<gi>_<preset>.png otherwise, so comparison runs do not overwrite.
## The small window only mirrors the offscreen view; its own 3D is disabled
## so the FPS figure is the cost of the 1080p frame alone.

const OUT_DIR := "res://tests/_out/style/"
const SIZE := Vector2i(1920, 1080)
## name: [camera position, look-at point, vertical fov, blackout + flashlight]
const SHOTS := {
	"wide": [Vector3(5.3, 1.7, 4.5), Vector3(-2.2, 1.9, -3.2), 70.0, false],
	"marble": [Vector3(1.6, 0.32, 2.0), Vector3(-3.4, 0.7, -4.2), 62.0, false],
	"case": [Vector3(-0.9, 1.45, 1.6), Vector3(-2.4, 1.05, -0.2), 55.0, false],
	"figure": [Vector3(3.2, 1.6, 3.35), Vector3(2.95, 1.42, 2.0), 50.0, false],
	"flashlight": [Vector3(4.3, 1.6, 4.5), Vector3(2.9, 1.35, 2.0), 70.0, true],
	"bust": [Vector3(-3.1, 1.65, 0.3), Vector3(-5.2, 1.45, -2.3), 55.0, false],
	"painting": [Vector3(0.0, 1.6, 0.8), Vector3(0.0, 2.7, -5.0), 60.0, false],
}

var sample: StyleSample
var view: SubViewport
var camera: Camera3D
var flashlight: SpotLight3D
var _mirror: TextureRect
var _shots: PackedStringArray = []
var _gi := "sdfgi"
var _perf := true
## "high" = the sample as built; "low" = the mid-range fallback from the style guide
var _preset := "high"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=").split(",", false)
		elif arg.begins_with("--gi="):
			_gi = arg.trim_prefix("--gi=")
		elif arg == "--perf=0":
			_perf = false
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
	if _shots.is_empty():
		_shots = PackedStringArray(SHOTS.keys())
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().disable_3d = true
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE).close()
	view = SubViewport.new()
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_4X
	view.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	view.positional_shadow_atlas_size = 4096
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	sample = (load("res://src/style/style_sample.tscn") as PackedScene).instantiate() as StyleSample
	sample.with_player = false
	view.add_child(sample)
	camera = Camera3D.new()
	camera.near = 0.03
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
	_setup_gi()
	if _preset == "low":
		StyleSample.apply_low_preset(sample.env)
	_place(SHOTS["wide"])
	await _frames(120)   # shaders compile, GI and fog settle, probe renders
	var report := {"gi": _gi, "shots": []}
	for shot_name in _shots:
		if not SHOTS.has(shot_name):
			print("unknown shot: ", shot_name)
			continue
		_place(SHOTS[shot_name])
		await _frames(45)
		await _save(shot_name)
		report["shots"].append(shot_name)
	if _perf:
		_place(SHOTS["wide"])
		await _frames(30)
		report["fps_wide"] = await _measure(4.0)
		_place(SHOTS["flashlight"])
		await _frames(30)
		report["fps_flashlight"] = await _measure(3.0)
		print("FPS at 1920x1080 (gi=%s, preset=%s): wide %.0f, blackout+flashlight %.0f"
			% [_gi, _preset, report["fps_wide"], report["fps_flashlight"]])
	report["preset"] = _preset
	var file := FileAccess.open(OUT_DIR.path_join("report_%s_%s.json" % [_gi, _preset]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	# release the mirrored viewport texture before quitting. (Godot 4.7.2 still
	# prints "7 RIDs of type Texture were leaked" for any ReflectionProbe at
	# exit; it is an engine warning, harmless, and not treated as a failure.)
	_mirror.texture = null
	view.queue_free()
	await _frames(5)
	get_tree().quit(0)


func _setup_gi() -> void:
	match _gi:
		"voxel":
			sample.env.sdfgi_enabled = false
			var gi := VoxelGI.new()
			gi.size = Vector3(StyleSample.ROOM_W + 1.0, StyleSample.ROOM_H + 1.0, StyleSample.ROOM_D + 1.0)
			gi.position = Vector3(0, StyleSample.ROOM_H * 0.5, 0)
			gi.subdiv = VoxelGI.SUBDIV_128
			sample.add_child(gi)
			var t0 := Time.get_ticks_msec()
			gi.bake()
			print("VoxelGI bake: %d ms" % (Time.get_ticks_msec() - t0))
		"none":
			sample.env.sdfgi_enabled = false


func _place(shot: Array) -> void:
	camera.position = shot[0]
	camera.look_at(shot[1], Vector3.UP)
	camera.fov = shot[2]
	var dark: bool = shot[3]
	sample.set_main_lights(not dark)
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
	var suffix := "" if _gi == "sdfgi" and _preset == "high" else "_%s_%s" % [_gi, _preset]
	var path := OUT_DIR.path_join("%s%s.png" % [shot_name, suffix])
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
