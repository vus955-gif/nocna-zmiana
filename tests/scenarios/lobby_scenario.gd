extends Node
## Windowed visual check of the lobby (not part of the headless suite).
## Usage: bash tools/run_lobby.sh shots|perf
## - shots: builds the lobby with a fixed night, dormant exhibits standing
##   as scale references, and saves views to tests/_out/lobby/ (1280x720),
## - perf: ~30 awake exhibits chase a stand-in guard in the main hall while
##   the camera looks over the hall from the diorama door; prints and saves
##   the average frame rate and draw calls.
## Run with --headless (bash tools/run_lobby.sh dry) it stages everything
## without capturing anything: a logic check that needs no window.

const OUT_DIR := "res://tests/_out/lobby/"
const NIGHT_SEED := 7
const NIGHT := 2
## name -> [camera position, look-at point]
const VIEWS := {
	"hall_entrance": [Vector3(0, 1.7, 20.5), Vector3(0, 4.0, -10)],
	"hall_stairs": [Vector3(4, 1.7, -4), Vector3(-16, 3.0, 14)],
	"hall_balcony": [Vector3(-16, 7.7, -18.5), Vector3(4, 1.5, 8)],
	"hall_from_trex": [Vector3(6, 2.2, -16), Vector3(0, 3.0, 20)],
	"gallery": [Vector3(-21, 1.7, 1), Vector3(-40, 2.0, -2)],
	"armory": [Vector3(21, 1.7, -1), Vector3(40, 2.0, 2)],
	"diorama": [Vector3(0, 1.7, 25), Vector3(0, 1.0, 44)],
	"security": [Vector3(0.5, 1.7, 54.6), Vector3(-0.5, 1.0, 61)],
	"closet": [Vector3(0, 7.7, -22.4), Vector3(0, 7.0, -26)],
}

var level: LobbyLevel
var camera: Camera3D
var _scenario := "shots"
var _dry := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			_scenario = arg.trim_prefix("--scenario=")
	GameInput.capture_allowed = false   # leave the cursor to the desktop
	_dry = DisplayServer.get_name() == "headless"
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var config := NightDirector.plan(NIGHT_SEED, NIGHT, LobbyLayout.describe(LobbyLayout.create()))
	level = LobbyLevel.new()
	level.night = config
	add_child(level)
	level.build()
	camera = Camera3D.new()
	camera.fov = 75.0
	add_child(camera)
	camera.current = true
	match _scenario:
		"shots":
			await _shots(config)
		"perf":
			await _perf()
		_:
			print("Unknown scenario: ", _scenario)
	Sfx.quit_cleanly(0)


func _shots(config: NightConfig) -> void:
	var exhibits := Node3D.new()
	add_child(exhibits)
	# no guard in the scene: exhibits have no target and stand still
	NightSpawner.spawn(config, level.spawn_slots, exhibits)
	await _frames(90)   # shaders, fog history
	for view: String in VIEWS:
		var pose: Array = VIEWS[view]
		camera.global_position = pose[0]
		camera.look_at(pose[1])
		await _frames(20)
		await _shot(view)
	# top-down plan: orthographic, roofs off
	level.set_roof_visible(false)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	camera.global_position = Vector3(0, 80, 18)
	camera.look_at(Vector3(0, 0, 18), Vector3.FORWARD)
	camera.far = 200.0
	await _frames(20)
	await _shot("overview")


func _perf() -> void:
	var guard := TargetDummy.new()
	guard.position = Vector3(0, 0, 0)
	guard.add_to_group(&"player")
	add_child(guard)
	var exhibits := Node3D.new()
	add_child(exhibits)
	var count := 0
	for ring in 3:
		for i in 10:
			var angle := TAU * i / 10.0 + ring * 0.3
			var enemy := NightSpawner.make([&"wax", &"wolf", &"knight"][(i + ring) % 3])
			enemy.position = Vector3(cos(angle) * (8.0 + ring * 3.0), 0.05, 4.0 + sin(angle) * (6.0 + ring * 2.0))
			enemy.target = guard
			exhibits.add_child(enemy)
			count += 1
	await _frames(30)
	for enemy in exhibits.get_children():
		(enemy as Enemy).brain.wake()
	camera.global_position = Vector3(0, 1.7, 20.5)
	camera.look_at(Vector3(0, 3.0, -6))
	await _frames(120)
	var start := Time.get_ticks_usec()
	var frames := 0
	var slowest := 0.0
	var last := start
	var span := 1000000 if _dry else 5000000
	while Time.get_ticks_usec() - start < span:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		slowest = maxf(slowest, (now - last) / 1000.0)
		last = now
		frames += 1
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	var result := {
		"exhibits": count,
		"window": str(DisplayServer.window_get_size()),
		"average_fps": frames / seconds,
		"slowest_frame_ms": slowest,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("lobby perf%s: " % (" (dry, no rendering)" if _dry else ""), JSON.stringify(result))
	if _dry:
		return
	var file := FileAccess.open(OUT_DIR.path_join("perf.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()


func _shot(label: String) -> void:
	if _dry:
		print("dry: staged ", label, " from ", camera.global_position)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
