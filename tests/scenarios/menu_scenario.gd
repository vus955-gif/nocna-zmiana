extends Node
## The live main menu (docs/superpowers/plans/2026-10-03-menu-zywa-scena.md)
## in the real window: the title screen over the dressed Great Court, shot
## by shot. Not part of the headless suite.
##   bash tools/run_menu_shots.sh shots [--preset=high] [--only=lattice,trex]
##       silent 1920x1080 window: the static fallback, then each shot at three
##       moments with the menu on top (and once without it), the black between
##       two shots -> tests/_out/menu/<shot>_<n>.png, metrics_<preset>.json
##       (mean luminance, near-black share, and the brightness of the left
##       third where the title stands; DARK when the mean is under DARK_MEAN)
##   bash tools/run_menu_shots.sh perf [--preset=high]
##       frame rate in the middle of each shot (the loop running) -> perf_<preset>.json
##   bash tools/run_menu_shots.sh dry
##       no window (headless): the menu builds its scene, every shot is checked
##       against the built floor (in a room, out of the walls, its subject in
##       sight, the T-Rex in frame), the lamps / shadows / motes the culling
##       leaves on in each shot are counted -> dry_<preset>.json; exit 1 on a problem
## Silent (Dummy audio). The windowed modes only while nobody uses the PC.

const OUT_DIR := "res://tests/_out/menu/"
const WATCHDOG_SECONDS := 420.0
const PRESETS := {"low": GraphicsQuality.Quality.LOW, "medium": GraphicsQuality.Quality.MEDIUM,
	"high": GraphicsQuality.Quality.HIGH, "ultra": GraphicsQuality.Quality.ULTRA}
const DARK_MEAN := 0.05
const NEAR_BLACK := 0.04
## The moments of each shot that are shot (share of its length).
const MOMENTS: Array[float] = [0.06, 0.5, 0.94]
## Frames the picture settles for after the camera was put somewhere.
const SETTLE_FRAMES := 30

var menu: MainMenu
var _mode := "shots"
var _preset := "high"
var _only: PackedStringArray = []
var _metrics: Array = []
var _failures: int = 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
	MuseumFloorLevel.dress_default = true
	GameInput.capture_allowed = false
	if _mode != "dry":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Settings.set_value(&"graphics_quality", PRESETS.get(_preset, GraphicsQuality.Quality.HIGH), false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	GameState.new_game()
	GameState.night = 2
	GameState.run_dust = 340
	GameState.save_game()
	menu = (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	menu.live_scene = true
	add_child(menu)
	await _frames(1)
	if _mode == "shots":
		await _capture("static_fallback")
	var started := Time.get_ticks_msec()
	var live: bool = await menu.stage_settled
	var settle_ms := Time.get_ticks_msec() - started
	if not live:
		print("MISSED: the live scene was given up (%s)" % ("no stage" if menu.stage == null else menu.stage.fail_reason))
		_failures += 1
	else:
		print("menu scene: built in %d ms, settled %d ms after the first frame (preset %s)" % [menu.stage.build_msec, settle_ms, _preset])
		await _seconds(MainMenu.REVEAL_TIME + 0.4)
		menu.stage.running = false
		match _mode:
			"perf":
				await _perf()
			"dry":
				await _dry()
			_:
				await _shots()
	var file := FileAccess.open(OUT_DIR.path_join("%s_%s.json" % ["dry" if _mode == "dry" else "metrics", _preset]), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"preset": _preset, "build_ms": menu.stage.build_msec if live else -1, "shots": _metrics}, "  "))
		file.close()
	Sfx.quit_cleanly(1 if _failures > 0 else 0)


func _on_watchdog() -> void:
	print("MISSED: the menu scenario did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(label: String) -> bool:
	return _only.is_empty() or _only.has(label)


func _shots() -> void:
	var stage := menu.stage
	await _seconds(2.0)   # SDFGI, fog history, probes
	for index in stage.shots.size():
		var shot := stage.shots[index]
		if not _wanted(String(shot.id)):
			continue
		for n in MOMENTS.size():
			stage.show_shot(index, shot.seconds * MOMENTS[n])
			await _frames(SETTLE_FRAMES)
			await _capture("%s_%d" % [shot.id, n + 1])
		# the scene without the menu on top
		stage.show_shot(index, shot.seconds * 0.5)
		_menu_visible(false)
		await _frames(SETTLE_FRAMES)
		await _capture("%s_scene" % shot.id)
		_menu_visible(true)
	if _wanted("dip"):
		# the end of a shot, the black, the start of the next, the loop running
		stage.show_shot(0, stage.shots[0].seconds - 0.4)
		stage.running = true
		for n in 4:
			await _seconds(0.3)
			await _capture("dip_%d" % (n + 1))
		stage.running = false


func _perf() -> void:
	var stage := menu.stage
	await _seconds(2.0)
	var result := {"preset": _preset, "window": str(DisplayServer.window_get_size()), "build_ms": stage.build_msec,
		"adapter": RenderingServer.get_video_adapter_name(), "views": {}}
	for index in stage.shots.size():
		var shot := stage.shots[index]
		if not _wanted(String(shot.id)):
			continue
		stage.show_shot(index, shot.seconds * 0.3)
		stage.running = true
		await _frames(40)
		result["views"][String(shot.id)] = await _measure(4.0, String(shot.id))
		stage.running = false
	print("menu perf: ", JSON.stringify(result))
	var file := FileAccess.open(OUT_DIR.path_join("perf_%s.json" % _preset), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()


func _measure(seconds: float, label: String) -> Dictionary:
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var times: Array[float] = []
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		frames += 1
	times.sort()
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	var out := {
		"average_fps": frames / elapsed,
		"p99_frame_ms": times[int(times.size() * 0.99)] if not times.is_empty() else 0.0,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("%s [%s]: %.0f FPS (p99 %.1f ms), %d draw calls, %d primitives" % [label, _preset, out["average_fps"], out["p99_frame_ms"], out["draw_calls"], out["primitives"]])
	return out


## Headless: the shots against the built floor, what the culling leaves on.
func _dry() -> void:
	var stage := menu.stage
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().find_world_3d().direct_space_state
	var problems := MenuStageCheck.shot_problems(stage, space)
	problems.append_array(MenuStageCheck.trex_problems(stage))
	for text in problems:
		print("PROBLEM ", text)
		_failures += 1
	for shot in stage.shots:
		for moment in [0.0, 0.5, 1.0]:
			var index := stage.shots.find(shot)
			stage.show_shot(index, shot.seconds * moment)
			var room := stage.level.room_at(stage.camera.global_position)
			var near: Dictionary = stage.level.culler.update_from(stage.camera.global_position) if stage.level.culler != null else {}
			var lamps := 0
			var shadows := 0
			var motes := 0
			for node in stage.level.lights.get_children():
				var node_room: StringName = node.get_meta(&"room", &"")
				if not near.has(node_room):
					continue
				if node is Light3D and not node is DirectionalLight3D:
					lamps += 1
					if (node as Light3D).shadow_enabled and (node as Node3D).global_position.distance_to(stage.camera.global_position) < 50.0:
						shadows += 1
				elif node is GPUParticles3D:
					motes += (node as GPUParticles3D).amount
			var entry := {"view": "%s@%.0f%%" % [shot.id, moment * 100.0], "room": room, "rooms_on": near.size(), "lamps_on": lamps, "shadows_near": shadows, "motes": motes}
			_metrics.append(entry)
			print("%-14s %-18s rooms %2d  lamps %3d  shadows %2d  motes %4d" % [entry["view"], room, near.size(), lamps, shadows, motes])
	print("menu dry: %d shots, %d problems, scene built in %d ms" % [stage.shots.size(), _failures, stage.build_msec])


func _menu_visible(shown: bool) -> void:
	for child in menu.get_children():
		if child is Control and child != menu.options and child != menu.confirm and child != menu.difficulty:
			(child as Control).visible = shown


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var suffix := "" if _preset == "high" else "_" + _preset
	var path := OUT_DIR.path_join("%s%s.png" % [label, suffix])
	image.save_png(path)
	var metrics := brightness(image)
	metrics["view"] = label
	metrics["dark"] = metrics["mean"] < DARK_MEAN and not label.begins_with("dip")
	_metrics.append(metrics)
	print("saved %s  mean %.3f  left %.3f  near-black %.0f%%%s" % [ProjectSettings.globalize_path(path), metrics["mean"], metrics["left"], float(metrics["near_black"]) * 100.0, "  DARK" if metrics["dark"] else ""])


## Mean luminance (Rec. 709 on the sRGB values), the share of near-black
## pixels and the mean of the left third, over a 480 x 270 copy.
static func brightness(image: Image) -> Dictionary:
	var small := image.duplicate() as Image
	small.convert(Image.FORMAT_RGB8)
	small.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var left := 0.0
	var black := 0
	var count := small.get_width() * small.get_height()
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			total += l
			if x < 160:
				left += l
			if l < NEAR_BLACK:
				black += 1
	return {"mean": total / count, "near_black": float(black) / count, "left": left / (160.0 * small.get_height())}


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
