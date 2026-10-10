extends Node
## Measures the hitches of a night (not part of the headless suite): the
## first seconds of a night (shaders and pipelines the first frames need)
## and the first fight in the hall (debris of every exhibit kind, the
## gatling, the flare gun, the shotgun), each with its frame times and the
## renderer's pipeline compilations (Performance PIPELINE_COMPILATIONS_*;
## DRAW ones stall the frame they happen in), plus the script cost of the
## physics tick in a hall fight (EnemyCrowd, the exhibits' AI). The guard
## carries every weapon. With --warm the night start runs Fx.warm_up()
## first, as Museum._ready does at the end of the scene build.
##   bash tools/run_hitch.sh [--warm]     -> tests/_out/hitch/hitch.json

const OUT_DIR := "res://tests/_out/hitch/"
const WATCHDOG_SECONDS := 180.0
## A frame slower than this (ms) counts as a hitch.
const HITCH_MS := 33.0
const MONITORS := {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var museum: Museum
## What the probe did in the frame before (kept with each hitch).
var _note := ""
var _warm := false
var _dry := false
var _result := {}


func _ready() -> void:
	Museum.level_id = &"lobby"   # a lobby scenario (the game plays Floor I)
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	_warm = OS.get_cmdline_user_args().has("--warm")
	_dry = DisplayServer.get_name() == "headless"
	GameInput.capture_allowed = false
	if not _dry:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _frames(5)
	_result["warm_up"] = _warm
	_result["window"] = str(DisplayServer.window_get_size())
	await _night_start()
	await _fight()
	await _crowd_tick()
	print("hitch probe: ", JSON.stringify(_result))
	var file := FileAccess.open(OUT_DIR.path_join("hitch%s.json" % ("_warm" if _warm else "")), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_result, "  "))
		file.close()
	Sfx.quit_cleanly(0)


func _on_watchdog() -> void:
	print("MISSED: the hitch probe did not finish in time")
	Sfx.quit_cleanly(1)


## A new game on night 2 (crystal in the hall, no modifier) with every
## weapon found; the build is timed, then the first 5 s.
func _night_start() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = 2
	for base in 600:
		GameState.seed_base = 3000 + base
		var config := NightDirector.plan(GameState.night_seed(), 2, description)
		if config.crystal_case == &"crystal_case_hall" and config.modifier == &"none":
			break
	for id in [&"pistol", &"shotgun", &"gatling", &"flare"]:
		GameState.add_weapon(id)
	RunState.reset()
	var counts := _counts()
	var begin := Time.get_ticks_usec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	var built := Time.get_ticks_usec()
	if _warm:
		Fx.warm_up(museum, museum.player.camera)
	var warmed := Time.get_ticks_usec()
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	_result["build_ms"] = (built - begin) / 1000.0
	_result["warm_up_call_ms"] = (warmed - built) / 1000.0
	_result["night_start"] = await _sample(5.0, counts)


## The guard in the hall with the exhibits awake: overkill on one exhibit
## of every kind (torn debris), plain kills, the gatling at the crowd, a
## flare and the shotgun. 6 s.
func _fight() -> void:
	museum.player.global_position = Vector3(0, 0.1, 8)
	var counts := _counts()
	var weapons := museum.player.weapons
	var plan := [[&"gatling", 2.0], [&"flare", 0.6], [&"shotgun", 0.6], [&"pistol", 0.4]]
	var kinds := {}
	for exhibit in museum.exhibits():
		exhibit.brain.wake()
	var start := Time.get_ticks_usec()
	var report := _new_report()
	var last := start
	var step := 0
	var step_end := 0.0
	var killed := 0
	while Time.get_ticks_usec() - start < 6000000:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var seconds := (now - start) / 1000000.0
		_track(report, (now - last) / 1000.0)
		last = now
		museum.player.health.heal(1000000.0)
		# kill one exhibit of each kind, torn apart, over the first seconds
		if killed < 8 and int(seconds * 4.0) > killed:
			for exhibit in museum.exhibits():
				var kind: StringName = (exhibit.get_script() as Script).get_global_name()
				if kinds.has(kind) or exhibit.is_queued_for_deletion():
					continue
				kinds[kind] = true
				_note = "torn %s" % kind
				var info := DamageInfo.make(exhibit.health.current * 4.0, DamageInfo.Kind.BALLISTIC, museum.player)
				info.direction = Vector3(0, 0, -1)
				info.position = exhibit.global_position + Vector3.UP
				exhibit.take_damage(info)
				break
			killed += 1
		# aim at the nearest exhibit and fire the planned weapon
		var nearest := _nearest()
		if nearest != null:
			var eye := museum.player.camera.global_position
			var aim := nearest.global_position + Vector3.UP * 0.9 - eye
			museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
		if step < plan.size():
			if step_end <= 0.0:
				weapons.select_id(plan[step][0])
				_note = "fires %s" % plan[step][0]
				var state := weapons.current_state()
				if state != null:
					state.magazine = state.data.magazine_size
					state.reserve = state.data.max_reserve
				step_end = seconds + float(plan[step][1])
			weapons.try_fire()
			if _note == "":
				_note = "firing %s" % plan[step][0]
			if seconds >= step_end:
				step += 1
				step_end = 0.0
	_result["fight"] = _finish(report, counts)


## Script time of the physics tick with the hall's exhibits chasing the
## guard (no firing): 4 s, after a second to close in.
func _crowd_tick() -> void:
	for exhibit in museum.exhibits():
		exhibit.brain.wake()
	museum.player.global_position = Vector3(0, 0.1, 6)
	await _seconds(1.0)
	var total := 0.0
	var worst := 0.0
	var ticks := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 4000000:
		await get_tree().physics_frame
		museum.player.health.heal(1000000.0)
		var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		total += physics_ms
		worst = maxf(worst, physics_ms)
		ticks += 1
	_result["crowd_tick"] = {
		"exhibits": museum.exhibits().size(),
		"chasing": museum.exhibits().filter(func(e: Enemy) -> bool: return e.brain.state == EnemyBrain.State.HUNT or e.brain.state == EnemyBrain.State.ATTACK).size(),
		"physics_tick_ms_avg": total / maxf(ticks, 1),
		"physics_tick_ms_worst": worst,
	}


func _nearest() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for exhibit in museum.exhibits():
		var d := exhibit.global_position.distance_to(museum.player.global_position)
		if d < best_distance and not exhibit.is_queued_for_deletion():
			best_distance = d
			best = exhibit
	return best


func _sample(seconds: float, counts: Dictionary) -> Dictionary:
	var report := _new_report()
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		_track(report, (now - last) / 1000.0)
		last = now
	return _finish(report, counts)


func _new_report() -> Dictionary:
	return {"frames": 0, "worst_ms": 0.0, "hitches": 0, "frames_over_ms": [], "total_ms": 0.0}


func _track(report: Dictionary, ms: float) -> void:
	report["frames"] += 1
	report["total_ms"] += ms
	report["worst_ms"] = maxf(report["worst_ms"], ms)
	if ms > HITCH_MS:
		report["hitches"] += 1
		(report["frames_over_ms"] as Array).append("%.1f %s" % [ms, _note])
	_note = ""


func _finish(report: Dictionary, counts: Dictionary) -> Dictionary:
	var now := _counts()
	var compiled := {}
	for key in MONITORS:
		compiled[key] = int(now[key] - counts[key])
	report["pipeline_compilations"] = compiled
	report["average_ms"] = report["total_ms"] / maxf(report["frames"], 1)
	report.erase("total_ms")
	return report


func _counts() -> Dictionary:
	var out := {}
	for key in MONITORS:
		out[key] = Performance.get_monitor(MONITORS[key])
	return out


func _seconds(time: float) -> void:
	await get_tree().create_timer(time, false).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
