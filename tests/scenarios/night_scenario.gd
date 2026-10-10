extends Node
## Visual check of a whole night in the game (not part of the headless
## suite). Plays the Museum through its test hooks and saves screenshots to
## tests/_out/night/ (1920x1080 window):
## night_start, hall_exhibits, fuse_box, lights_out, crystal_pulsing,
## crystal_flight, boss_waking, boss_fight, grate_open, dawn_freeze,
## blackout, plus the dawn card. --mode=perf measures the frame rate of a
## busy fight in the hall instead (perf.json). Under --headless everything
## is staged and nothing captured (a logic check), and the fight is timed
## by its script cost per physics tick (frame rates mean nothing without
## rendering).
##   bash tools/run_night.sh shots | perf | dry

const OUT_DIR := "res://tests/_out/night/"
const WATCHDOG_SECONDS := 240.0

var museum: Museum
var camera: Camera3D
var _mode := "shots"
var _dry := false
var _log: Array = []


func _ready() -> void:
	Museum.level_id = &"lobby"   # a lobby scenario (the game plays Floor I)
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	_dry = DisplayServer.get_name() == "headless"
	GameInput.capture_allowed = false
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 300.0
	add_child(camera)
	if _mode == "perf":
		# the headroom, not the monitor's refresh rate
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		await _perf()
	else:
		await _night()
		await _dawn()
		await _blackout()
		await _content()
		if _dry:
			await _perf()
	var file := FileAccess.open(OUT_DIR.path_join("night.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_log, "  "))
		file.close()
	Sfx.quit_cleanly(0)


func _on_watchdog() -> void:
	print("MISSED: the night scenario did not finish in time")
	Sfx.quit_cleanly(1)


## A new game on [param night] whose draw matches [param wanted] (a
## Callable taking the NightConfig), then the Museum for it.
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
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	# the guard only holds the camera: he must not fall
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	await _frames(2)


func _night() -> void:
	await _open(1, func(config: NightConfig) -> bool: return config.crystal_case == &"crystal_case_gallery")
	await _seconds(1.5)   # shaders, fog history; the night's card is up
	await _guard_shot("night_start", museum.player.global_position, Vector3(0, 1.2, 54.0))
	# the hall with its exhibits, from the diorama door
	await _shot("hall_exhibits", Vector3(0, 1.8, 20.5), Vector3(0, 3.5, -8))
	await _seconds(3.5)   # the night's card fades
	# both fuses, then the fuse box
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	var box := museum.objective.fuse_box
	await _guard_shot("fuse_box", box.global_position + Vector3(0.6, -0.4, 2.2), box.global_position + Vector3(0, 0.45, 0))
	box.interact(museum.player)
	await _seconds(2.2)
	await _shot("lights_out", Vector3(9, 2.2, 14), Vector3(0, 2.5, -20))
	# the beating crystal in its case (the guard stays back)
	var crystal := museum.objective.crystal
	museum.player.global_position = Vector3(-26, 0.1, 6)
	await _seconds(0.6)
	await _shot("crystal_pulsing", crystal.global_position + Vector3(3.2, 0.6, 1.4), crystal.global_position)
	# the flight: the guard walks up, then follows it
	var toward := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.global_position = _floor_under(crystal.global_position + toward * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05
	_log_state("burst")
	var shot_taken := false
	for i in 60 * 30:
		if not is_instance_valid(museum.objective.crystal):
			break
		var at := museum.objective.crystal.global_position
		if i % 6 == 0:
			museum.player.global_position = _floor_under(at + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		if not shot_taken and at.x > -30.0 and at.x < -23.0:
			shot_taken = true
			# behind and beside it, looking the way it flies: the trail between
			var ahead := (Vector3(-18.0, 2.4, 0.0) - at).normalized()
			var side := ahead.cross(Vector3.UP).normalized()
			await _shot("crystal_flight", _clear_view(at, at - ahead * 4.0 + side * 2.2 + Vector3.UP * 0.6), at + ahead * 2.0, 0)
		await get_tree().physics_frame
	_log_state("arrived")
	var boss := museum.objective.boss
	museum.player.global_position = Vector3(0, 0.1, 12)
	await _seconds(0.9)
	var chest := boss.global_position + Vector3.UP * 3.2
	await _shot("boss_waking", _clear_view(chest, chest + Vector3(-6.5, -0.6, 8.5)), chest, 0)
	await _seconds(3.0)
	# the fight: phase 2 (the roar calls wax figures), a wide shot
	boss.take_zone_damage(DamageInfo.make(boss.health.current * 0.4, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await _seconds(6.0)
	var middle := boss.global_position + Vector3.UP * 2.0
	await _shot("boss_fight", _clear_view(middle, middle + Vector3(9.0, 7.0, 11.0)), middle.lerp(museum.player.global_position, 0.35), 0)
	var guard_at := boss.global_position + (museum.player.global_position - boss.global_position).normalized() * 9.0
	guard_at.y = 0.1
	await _guard_shot("boss_fight_guard", guard_at, boss.global_position + Vector3.UP * 3.0)
	boss.take_zone_damage(DamageInfo.make(boss.health.current + 1.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	_log_state("boss dead")
	museum.player.global_position = Vector3(0, 0.1, 14)
	await _seconds(NightObjective.GRATE_DELAY + 3.2)
	for exhibit in museum.exhibits():
		exhibit.queue_free()   # nobody in the way of the view down
	await _shot("grate_open", Vector3(1.8, 2.0, -15.5), Vector3(0, -0.5, -30))
	_log_state("grate")


func _dawn() -> void:
	await _open(2, func(config: NightConfig) -> bool: return config.modifier == &"none")
	museum.player.global_position = Vector3(0, 0.1, 2)
	for exhibit in museum.exhibits():
		if museum.lobby.room_at(exhibit.global_position + Vector3.UP * 0.2) == &"hall":
			exhibit.brain.wake()
	museum.objective.summon_wax(5)   # a few more on their way to him
	await _seconds(3.2)
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.1
	await _seconds(2.2)
	await _shot("dawn_freeze", Vector3(-8.5, 4.6, 14), Vector3(0, 0.6, 1), 0)
	await _seconds(Museum.DAWN_DELAY + DawnScreen.FADE_TIME)
	await _shot("dawn_card", camera.global_position, Vector3(0, 1, -10), 0)
	_log_state("dawn")


func _blackout() -> void:
	await _open(3, func(config: NightConfig) -> bool: return config.modifier == &"blackout")
	museum.player.global_position = Vector3(0, 0.1, 21.5)
	museum.player.head.rotation = Vector3(0.05, 0.0, 0.0)
	museum.player.set_flashlight(true)
	await _seconds(1.0)
	await _guard_shot("blackout", Vector3(0, 0.1, 21.5), Vector3(0, 2.0, 0))
	_log_state("blackout " + String(museum.night.modifier))


## The content pass in the lobby: a portrait on the gallery's north wall
## (asleep among paintings, then pushed out of its wall), the raptor pack of
## the hall, the chained gatling, the fire cabinet with the flare gun.
func _content() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	var north: Array[StringName] = [&"portrait_1", &"portrait_3", &"portrait_5"]
	await _open(3, func(config: NightConfig) -> bool:
		var pack := config.spawns.any(func(entry: NightConfig.Spawn) -> bool:
			return entry.kind == NightSpawner.PACK and description.spawn_slots[entry.slot].room == &"hall")
		return pack and config.modifier == &"none" and config.portraits.any(func(id: StringName) -> bool: return north.has(id)))
	museum.player.global_position = Vector3(0, 0.1, 56)   # out of every exhibit's sight
	await _seconds(1.0)
	await _shot("gallery_paintings", Vector3(-27.0, 1.8, 3.0), Vector3(-31.0, 2.1, -14.0))
	var portrait: Portrait = null
	for exhibit in museum.exhibits():
		if exhibit is Portrait and north.has(exhibit.get_meta(Museum.PORTRAIT_META)):
			portrait = exhibit
	if portrait != null:
		var wall := portrait.global_transform
		museum.player.global_position = _floor_under(wall.origin - wall.basis.z * 5.0 + Vector3.UP) + Vector3.UP * 0.1
		await _seconds(Portrait.TRACK_TIME + 1.2)
		await _shot("portrait_awake", wall.origin - wall.basis.z * 3.4 + wall.basis.x * 1.6 - Vector3.UP * 0.3, wall.origin - wall.basis.z * 0.3, 2)
	museum.player.global_position = Vector3(0, 0.1, 56)
	await _seconds(0.5)
	var raptors := museum.exhibits().filter(func(exhibit: Enemy) -> bool:
		return exhibit is Raptor and museum.lobby.room_at(exhibit.global_position + Vector3.UP * 0.2) == &"hall")
	if not raptors.is_empty():
		var center := Vector3.ZERO
		for raptor: Raptor in raptors:
			center += raptor.global_position
		center /= raptors.size()
		await _shot("raptor_pack", _clear_view(center + Vector3.UP * 0.6, center + Vector3(3.2, 1.6, 3.4)), center + Vector3.UP * 0.6)
	var display := museum.armory.display
	await _shot("gatling_display", display.global_position - display.global_transform.basis.z * 3.0 + Vector3(0, 1.7, 0.8), display.global_position + Vector3.UP * 1.1)
	var cabinet := museum.armory.cabinet
	await _shot("flare_cabinet", cabinet.global_position - cabinet.global_transform.basis.z * 2.4 + Vector3(-0.6, 0.3, 0), cabinet.global_position)
	_log_state("content")


## The fight in the hall, awake: the boss, the summons and the hall's
## exhibits, seen by the guard. Average and worst frame time, and what the
## scripts cost: milliseconds of physics processing per tick and of
## processing per frame (the only figures a headless run can give).
func _perf() -> void:
	await _open(2, func(config: NightConfig) -> bool: return config.crystal_case == &"crystal_case_hall" and config.modifier == &"none")
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
	await _seconds(3.5)
	boss.take_zone_damage(DamageInfo.make(boss.health.current * 0.4, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	await _seconds(3.0)
	museum.player.head.rotation = Vector3(0.1, 0.0, 0.0)
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var slowest := 0.0
	var process_ms := 0.0
	var tick_costs: Array[float] = []
	var on_tick := func() -> void: tick_costs.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	get_tree().physics_frame.connect(on_tick)
	while Time.get_ticks_usec() - start < (2000000 if _dry else 8000000):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		slowest = maxf(slowest, (now - last) / 1000.0)
		last = now
		frames += 1
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		museum.player.health.heal(1000000.0)
		# turn slowly to look over the fight
		museum.player.head.rotation.y = sin((now - start) / 1000000.0 * 0.5) * 0.6
	get_tree().physics_frame.disconnect(on_tick)
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	var tick_total := 0.0
	var tick_worst := 0.0
	for cost in tick_costs:
		tick_total += cost
		tick_worst = maxf(tick_worst, cost)
	var result := {
		"exhibits": museum.exhibits().size(),
		"boss_state": boss.brain.state if is_instance_valid(boss) else -1,
		"physics_ticks": tick_costs.size(),
		"script_ms_per_tick": snappedf(tick_total / maxf(tick_costs.size(), 1.0), 0.001),
		"script_ms_worst_tick": snappedf(tick_worst, 0.001),
		"process_ms_per_frame": snappedf(process_ms / maxf(frames, 1.0), 0.001),
	}
	if not _dry:
		result["window"] = str(DisplayServer.window_get_size())
		result["average_fps"] = frames / seconds
		result["slowest_frame_ms"] = slowest
		result["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		result["objects"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		result["primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("night perf%s: " % (" (dry: script time, no rendering)" if _dry else ""), JSON.stringify(result))
	var file := FileAccess.open(OUT_DIR.path_join("perf.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()


## A screenshot through the scenario's own camera from [param from] to
## [param at] (the game keeps running; [param settle] frames first). The
## HUD is hidden: these are views of the world, not of the guard.
func _shot(label: String, from: Vector3, at: Vector3, settle: int = 20) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	camera.reset_physics_interpolation()   # a cut, not a glide from the last view
	camera.current = true
	museum.hud.visible = false
	await _frames(settle)
	await _capture(label)
	museum.hud.visible = true


## [param wanted] pulled towards [param subject] until nothing solid lies
## between them (a camera never ends up inside a wall).
func _clear_view(subject: Vector3, wanted: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(subject, wanted, Layers.WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return (hit["position"] as Vector3) + (subject - wanted).normalized() * 0.4


## A screenshot through the guard's eyes: he stands at [param from] and
## looks at [param at].
func _guard_shot(label: String, from: Vector3, at: Vector3) -> void:
	museum.player.global_position = from
	var eye := from + Vector3.UP * museum.player.eye_height
	var aim := at - eye
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	museum.player.camera.current = true
	await _frames(20)
	museum.hud._vignette.modulate.a = 0.0   # the invulnerable stand-in took hits
	await _capture(label)


func _capture(label: String) -> void:
	_log_state(label)
	if _dry:
		print("dry: staged ", label)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join("%s.png" % label)
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _log_state(label: String) -> void:
	var entry := {"moment": label}
	var eye := get_viewport().get_camera_3d()
	if eye != null:
		entry["camera"] = str(eye.global_position)
		entry["camera_is_scenarios"] = eye == camera
	if is_instance_valid(museum):
		entry["stage"] = museum.objective.stage if museum.objective != null else -1
		entry["clock"] = museum.hud.clock_text()
		entry["goal"] = museum.hud.objective_text()
		entry["exhibits"] = museum.exhibits().size()
	_log.append(entry)


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
