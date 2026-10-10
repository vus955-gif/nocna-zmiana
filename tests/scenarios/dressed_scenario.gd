extends Node
## Visual and performance check of the dressed lobby in the real game (not
## part of the headless suite): the Museum with the lobby kit, the light
## recipe and a graphics preset, staged through the game's test hooks.
##   bash tools/run_dressed.sh shots [--preset=high] [--only=a,b]
##       screenshots -> tests/_out/dressed/ (1920x1080 window)
##   bash tools/run_dressed.sh perf [--preset=high]
##       frame rate of the hall: lit with its exhibits awake, and the boss
##       fight after the power cut with ~40 exhibits -> perf_<preset>.json
## Silent (Dummy audio) and windowed; run it only while nobody uses the PC.

const OUT_DIR := "res://tests/_out/dressed/"
const WATCHDOG_SECONDS := 420.0
const PRESETS := {"low": GraphicsQuality.Quality.LOW, "medium": GraphicsQuality.Quality.MEDIUM,
	"high": GraphicsQuality.Quality.HIGH, "ultra": GraphicsQuality.Quality.ULTRA}
## Static views of the first night: [camera, look-at].
const VIEWS := {
	"hall_entrance": [Vector3(0.0, 1.75, 20.8), Vector3(0.0, 4.0, -10.0)],
	"hall_wide": [Vector3(11.5, 1.7, 19.5), Vector3(-9.0, 4.2, -9.0)],
	"hall_balcony": [Vector3(-16.2, 7.65, -3.0), Vector3(4.0, 5.2, -12.0)],
	"trex": [Vector3(3.5, 1.6, -4.4), Vector3(-1.5, 2.6, -13.0)],
	"hall_north": [Vector3(4.0, 1.7, 12.0), Vector3(-1.0, 5.0, -20.0)],
	"stairs": [Vector3(-11.5, 1.6, 21.3), Vector3(-16.0, 4.2, 8.0)],
	"booth": [Vector3(-7.5, 1.7, 21.0), Vector3(-9.5, 1.6, 15.5)],
	"doorway": [Vector3(-11.0, 1.7, 1.2), Vector3(-26.0, 2.6, 0.0)],
	"gallery": [Vector3(-22.5, 1.7, 8.5), Vector3(-36.0, 2.6, -6.0)],
	"gallery_paintings": [Vector3(-27.0, 1.8, 3.0), Vector3(-31.0, 2.1, -14.0)],
	"armory": [Vector3(22.0, 1.7, 10.0), Vector3(36.0, 3.0, -6.0)],
	"diorama": [Vector3(1.5, 1.7, 25.5), Vector3(-7.0, 3.2, 40.0)],
	"security": [Vector3(3.6, 1.65, 55.0), Vector3(-3.5, 1.2, 61.0)],
	"fuse_box": [Vector3(5.4, 1.6, -19.6), Vector3(4.5, 1.5, -21.8)],
	"grate": [Vector3(2.5, 1.7, -16.0), Vector3(0.0, 2.2, -22.5)],
	"chandelier": [Vector3(7.0, 1.7, 8.0), Vector3(0.0, 9.0, 18.0)],
	"armory_racks": [Vector3(30.5, 1.7, 3.0), Vector3(30.0, 2.0, -14.0)],
	"diorama_trees": [Vector3(-1.0, 1.7, 30.0), Vector3(-11.0, 2.5, 39.0)],
	"gallery_west": [Vector3(-24.0, 1.7, -2.0), Vector3(-40.0, 3.0, 2.0)],
	"gallery_to_hall": [Vector3(-38.5, 1.7, 0.6), Vector3(10.0, 3.0, -2.0)],
	"security_to_hall": [Vector3(0.3, 1.65, 57.0), Vector3(0.0, 2.0, 0.0)],
}

var museum: Museum
var camera: Camera3D
var _mode := "shots"
var _preset := "high"
var _only: PackedStringArray = []
var _log: Array = []
var _build_ms: int = 0


func _ready() -> void:
	Museum.level_id = &"lobby"   # a lobby scenario (the game plays Floor I)
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--preset="):
			_preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
	GameInput.capture_allowed = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Settings.set_value(&"graphics_quality", PRESETS.get(_preset, GraphicsQuality.Quality.HIGH), false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	if _mode == "perf":
		await _perf()
	else:
		await _shots()
	var file := FileAccess.open(OUT_DIR.path_join("log_%s.json" % _preset), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_log, "  "))
		file.close()
	Sfx.quit_cleanly(0)


func _on_watchdog() -> void:
	print("MISSED: the dressed scenario did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(label: String) -> bool:
	return _only.is_empty() or _only.has(label)


## A new game on [param night] whose draw matches [param wanted], then the
## Museum for it (its build time logged).
func _open(night: int, wanted: Callable) -> void:
	if is_instance_valid(museum):
		museum.free()
		await _frames(2)
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 600:
		GameState.seed_base = 3000 + base
		if wanted.call(NightDirector.plan(GameState.night_seed(), night, description)):
			break
	RunState.reset()
	var started := Time.get_ticks_msec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_build_ms = Time.get_ticks_msec() - started
	print("museum built in %d ms (night %d, %s)" % [_build_ms, night, museum.night.modifier])
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	await _frames(2)


func _shots() -> void:
	# the first night: the static views while the exhibits sleep
	await _open(1, func(config: NightConfig) -> bool: return config.crystal_case == &"crystal_case_gallery" and config.modifier == &"none")
	await _seconds(2.0)   # shaders, SDFGI, fog history
	if _wanted("night_start"):
		await _guard_shot("night_start", museum.player.global_position, Vector3(0, 1.2, 54.0))
	museum.player.global_position = Vector3(0, 0.1, 57.5)   # out of every exhibit's sight
	for label: String in VIEWS:
		if _wanted(label):
			await _shot(label, VIEWS[label][0], VIEWS[label][1], 40)
	if _wanted("gatling_display") and museum.armory != null and museum.armory.display != null:
		var display := museum.armory.display
		await _shot("gatling_display", display.global_position - display.global_transform.basis.z * 3.0 + Vector3(0, 1.7, 0.8), display.global_position + Vector3.UP * 1.1)
	if _wanted("flare_cabinet") and museum.armory != null and museum.armory.cabinet != null:
		var cabinet := museum.armory.cabinet
		await _shot("flare_cabinet", cabinet.global_position - cabinet.global_transform.basis.z * 4.5 + Vector3(-1.2, 0.4, 0), cabinet.global_position + Vector3(0, -0.4, 0))
	if _wanted("boss_fight") or _wanted("lights_out") or _wanted("fuse_box_cut"):
		await _boss_fight()
	if _wanted("dawn"):
		await _dawn()
	if _wanted("blackout"):
		await _blackout()


## Fuses in, the power cut, the crystal's flight, the boss awake in the
## dressed hall.
func _boss_fight() -> void:
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(2.2)
	if _wanted("lights_out"):
		await _shot("lights_out", Vector3(9, 2.2, 14), Vector3(0, 2.5, -20))
	if _wanted("fuse_box_cut"):
		await _shot("fuse_box_cut", VIEWS["fuse_box"][0], VIEWS["fuse_box"][1])
	var crystal := museum.objective.crystal
	crystal.burst()
	for i in 60 * 30:
		if not is_instance_valid(museum.objective.crystal):
			break
		museum.player.global_position = _floor_under(museum.objective.crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	var boss := museum.objective.boss
	museum.player.global_position = Vector3(0, 0.1, 12)
	await _seconds(3.5)
	boss.take_zone_damage(DamageInfo.make(boss.health.current * 0.4, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await _seconds(6.0)
	var middle := boss.global_position + Vector3.UP * 2.0
	await _shot("boss_fight", _clear_view(middle, middle + Vector3(9.0, 7.0, 11.0)), middle.lerp(museum.player.global_position, 0.35), 0)
	var guard_at := boss.global_position + (museum.player.global_position - boss.global_position).normalized() * 9.0
	guard_at.y = 0.1
	await _guard_shot("boss_fight_guard", guard_at, boss.global_position + Vector3.UP * 3.0)


func _dawn() -> void:
	await _open(2, func(config: NightConfig) -> bool: return config.modifier == &"none")
	museum.player.global_position = Vector3(0, 0.1, 2)
	for exhibit in museum.exhibits():
		if museum.lobby.room_at(exhibit.global_position + Vector3.UP * 0.2) == &"hall":
			exhibit.brain.wake()
	await _seconds(3.0)
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.1
	await _seconds(2.4)
	await _shot("dawn", Vector3(-8.5, 4.6, 14), Vector3(0, 0.6, 1), 0)


func _blackout() -> void:
	await _open(3, func(config: NightConfig) -> bool: return config.modifier == &"blackout")
	museum.player.global_position = Vector3(0, 0.1, 21.5)
	museum.player.set_flashlight(true)
	await _seconds(1.5)
	await _guard_shot("blackout", Vector3(0, 0.1, 21.5), Vector3(0, 2.0, 0))
	await _guard_shot("blackout_gallery", Vector3(-15, 0.1, 1.0), Vector3(-30, 1.8, -3.0))


## The hall's frame rate: lit with its exhibits awake, then the boss fight
## in the dark with about 40 exhibits (the summons topped up).
func _perf() -> void:
	await _open(2, func(config: NightConfig) -> bool: return config.crystal_case == &"crystal_case_hall" and config.modifier == &"none")
	var result := {"preset": _preset, "window": str(DisplayServer.window_get_size()), "build_ms": _build_ms,
		"render_scale": Settings.get_value(&"render_scale"), "adapter": RenderingServer.get_video_adapter_name()}
	await _seconds(2.0)
	museum.player.global_position = Vector3(0, 0.1, 16)
	for exhibit in museum.exhibits():
		if museum.lobby.room_at(exhibit.global_position + Vector3.UP * 0.2) in [&"hall", &"balcony"]:
			exhibit.brain.wake()
	await _seconds(2.0)
	result["hall_lit"] = await _measure(6.0, "hall_lit")
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(2.0)
	museum.objective.crystal.burst()
	for i in 60 * 20:
		if not is_instance_valid(museum.objective.crystal):
			break
		museum.player.global_position = _floor_under(museum.objective.crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	var boss := museum.objective.boss
	museum.player.global_position = Vector3(0, 0.1, 8)
	for exhibit in museum.exhibits():
		exhibit.brain.wake()
	var missing := 40 - museum.exhibits().size()
	if missing > 0:
		museum.objective.summon_wax(missing)
	await _seconds(3.5)
	boss.take_zone_damage(DamageInfo.make(boss.health.current * 0.4, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await _seconds(3.0)
	result["boss_fight"] = await _measure(8.0, "boss_fight")
	print("dressed perf: ", JSON.stringify(result))
	var file := FileAccess.open(OUT_DIR.path_join("perf_%s.json" % _preset), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()


## Average and worst frame over [param seconds] through the guard's eyes,
## turning slowly over the hall.
func _measure(seconds: float, label: String) -> Dictionary:
	museum.player.camera.current = true
	museum.player.head.rotation = Vector3(0.1, 0.0, 0.0)
	await _frames(30)
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var slowest := 0.0
	var times: Array[float] = []
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		times.append(ms)
		slowest = maxf(slowest, ms)
		last = now
		frames += 1
		museum.player.health.heal(1000000.0)
		museum.player.head.rotation.y = sin((now - start) / 1000000.0 * 0.5) * 0.6
	times.sort()
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	var out := {
		"average_fps": frames / elapsed,
		"p99_frame_ms": times[int(times.size() * 0.99)] if not times.is_empty() else 0.0,
		"slowest_frame_ms": slowest,
		"exhibits": museum.exhibits().size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("%s [%s]: %.0f FPS (p99 %.1f ms), %d exhibits, %d draw calls" % [label, _preset, out["average_fps"], out["p99_frame_ms"], out["exhibits"], out["draw_calls"]])
	return out


func _shot(label: String, from: Vector3, at: Vector3, settle: int = 20) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	camera.reset_physics_interpolation()
	camera.current = true
	museum.hud.visible = false
	await _frames(settle)
	await _capture(label)
	museum.hud.visible = true


func _clear_view(subject: Vector3, wanted: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(subject, wanted, Layers.WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return (hit["position"] as Vector3) + (subject - wanted).normalized() * 0.4


func _guard_shot(label: String, from: Vector3, at: Vector3) -> void:
	museum.player.global_position = from
	var eye := from + Vector3.UP * museum.player.eye_height
	var aim := at - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	museum.player.camera.current = true
	await _frames(30)
	museum.hud._vignette.modulate.a = 0.0
	await _capture(label)


func _capture(label: String) -> void:
	_log.append({"moment": label, "camera": str(get_viewport().get_camera_3d().global_position)})
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var suffix := "" if _preset == "high" else "_" + _preset
	var path := OUT_DIR.path_join("%s%s.png" % [label, suffix])
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
