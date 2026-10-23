extends Node
## CPU profile of a night in the dressed Floor I museum (not part of the
## headless suite): the real game staged through test hooks, run headless
## with --fixed-fps 60 (every frame is exactly one 1/60 s physics tick, so
## "per tick" and "per frame" are the same thing) and timed by subsystem
## with CpuSections (see its comment for what that does and does not count).
## Music, ambience, foley and the voice are switched on (they are off in
## scenario runs); the audio driver is the dummy one, nothing is heard.
## Segments, one after another in the same night:
##   hub_idle      the guard stands in the security booth, every exhibit asleep
##   walk          sprinting from the booth through the court into Egypt's
##                 gallery with the flashlight on (rooms wake, culling follows)
##   fight_hall    the thickest knot of exhibits awake and hunting him, the
##                 pistol, shotgun and gatling at them (debris, effects, deaths)
##   colossus      the Egypt wing guardian awake, the gatling at him
##   trex          the T-Rex awake, in his second phase, the gatling at him
## Result: tests/_out/cpu_profile.json and a table on stdout. GPU time is
## not measurable headless: the F3 overlay shows it in a window.
##   bash tools/run_cpu_profile.sh [--quick] [--only=walk,trex] [--seed=57]
## The night is drawn from --seed (default SEED): runs compare the same
## exhibits in the same places.

const OUT_FILE := "res://tests/_out/cpu_profile.json"
const WATCHDOG_SECONDS := 900.0
const TICKS_PER_SECOND := 60
## Ticks run before a segment is measured (state settles, pools fill), and
## once before the first one (music families load, the night's first moments).
const SETTLE_TICKS := 45
const PREROLL_TICKS := 180
const SEGMENT_SECONDS := {"hub_idle": 8.0, "walk": 26.0, "fight_hall": 14.0, "colossus": 10.0, "trex": 10.0}
const QUICK_FACTOR := 0.25
## Where the sprint goes (feet, y = floor): booth, entrance hall, the court,
## Egypt's vestibule and its long gallery (the tour's verified viewpoints).
const WALK_PATH: Array[Vector3] = [Vector3(33.0, 0.1, 45.5), Vector3(14.5, 0.1, 42.0), Vector3(0.0, 0.1, 34.0),
		Vector3(-10.0, 0.1, 22.0), Vector3(-14.0, 0.1, 18.0), Vector3(-33.5, 0.1, 27.5), Vector3(-42.0, 0.1, 27.0),
		Vector3(-42.0, 0.1, -10.0)]
const FIGHT_EXHIBITS := 30
const SEED := 57
const WEAPONS: Array[StringName] = [&"pistol", &"shotgun", &"gatling", &"flare"]

var museum: Museum
var sections: CpuSections
var _quick := false
var _seed: int = SEED
var _only: PackedStringArray = []
var _result := {}
var _segments: Array = []
var _build_ms: int = 0
## The step of the segment being played, run in every physics tick (the
## way the game's own input is: in _physics_process), its tick number and
## the segment's tick count.
var _step: Callable = Callable()
var _tick: int = 0
var _ticks: int = 0
## Per-tick timing from the tree's own signals (the engine's Performance
## monitors keep the worst frame of the last second, not the frame): the
## physics frame starts at physics_frame, the idle frame at process_frame,
## with no rendering in between or after (headless).
var _recording := false
var _stamp_physics: int = 0
var _stamp_frame: int = 0
var _physics_us := PackedFloat32Array()
var _idle_us := PackedFloat32Array()


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	get_tree().physics_frame.connect(_on_physics_frame)
	get_tree().process_frame.connect(_on_process_frame)
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick":
			_quick = true
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	Museum.level_id = &"floor1"
	MuseumFloorLevel.dress_default = true
	GameInput.capture_allowed = false
	# the systems a scenario run leaves off, as in the game
	Music.enabled = true
	Music.blocking_loads = false
	Ambience.enabled = true
	Foley.enabled = true
	VoiceDirector.enabled = true
	await _frames(5)
	await _open()
	await _install_sections()
	Music.set_scene_kind(AudioContext.GAME)
	await _frames(PREROLL_TICKS)
	await _run()
	_finish()
	Sfx.quit_cleanly(0)


func _physics_process(_delta: float) -> void:
	if _step.is_valid():
		_step.call(_tick, _ticks)
		_tick += 1


func _on_physics_frame() -> void:
	var now := Time.get_ticks_usec()
	if _recording and _stamp_frame > 0:
		_idle_us.append(now - _stamp_frame)
	_stamp_physics = now


func _on_process_frame() -> void:
	var now := Time.get_ticks_usec()
	if _recording and _stamp_physics > 0:
		_physics_us.append(now - _stamp_physics)
	_stamp_frame = now


func _on_watchdog() -> void:
	print("MISSED: the CPU profile did not finish in time")
	Sfx.quit_cleanly(1)


func _wanted(label: String) -> bool:
	return _only.is_empty() or _only.has(label)


## A new game on night 1 in Floor I with the art, every weapon found.
func _open() -> void:
	GameState.new_game()
	GameState.seed_base = _seed
	GameState.night = 1
	seed(_seed)
	for id in WEAPONS:
		GameState.add_weapon(id)
	RunState.reset()
	var started := Time.get_ticks_msec()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_build_ms = Time.get_ticks_msec() - started
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	# the end of the night's loading, as in the game (headless: the queued debris is cut now)
	Fx.warm_up(museum, museum.player.camera)
	print("museum built in %d ms (floor I level %d ms, navigation %d ms)" % [_build_ms, museum.floor_level.build_msec, museum.floor_level.bake_msec])
	await _frames(2)


func _install_sections() -> void:
	sections = CpuSections.new()
	sections.keep_samples = true
	add_child(sections)
	# the driver (this node) fires the guard's weapons in its physics callback:
	# its own section, so the shots do not count for the game's subsystems
	sections.add_section(&"driver", func() -> Array: return [self], false)
	MuseumSections.setup(sections, museum)
	var begin := Time.get_ticks_msec()
	sections.install()
	print("sections installed in %d ms, %d nodes in sections" % [Time.get_ticks_msec() - begin, sections.claimed_count()])
	await _frames(2)


func _run() -> void:
	_result = {
		"godot": Engine.get_version_info()["string"],
		"date": Time.get_datetime_string_from_system(),
		"processor": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"dressed": MuseumFloorLevel.dress_default,
		"seed": _seed,
		"build_ms": _build_ms,
		"floor_build_ms": museum.floor_level.build_msec,
		"navigation_bake_ms": museum.floor_level.bake_msec,
		"sections": Array(sections.names),
		"census": _census(),
		"note": "ms per tick at a fixed 60 Hz, no rendering (headless). physics_ms = physics_frame to process_frame (the nodes' _physics_process and the physics server's step), idle_ms = process_frame to the next physics_frame (the nodes' _process, timers, tweens, deferred calls). Sections time the callbacks of a subsystem's nodes between two stamps (CpuSections); unattributed = total - sections.",
		"segments": _segments,
	}
	if _wanted("hub_idle"):
		await _hub_idle()
	if _wanted("walk"):
		await _walk()
	if _wanted("fight_hall"):
		await _fight_hall()
	if _wanted("colossus"):
		await _colossus()
	if _wanted("trex"):
		await _trex()


## What the museum is made of: nodes by class, and the nodes that process
## every frame by their script (or class).
func _census() -> Dictionary:
	var classes := {}
	var processing := {}
	var scripted := 0
	var nodes := museum.find_children("*", "", true, false)
	for node in nodes:
		var kind := node.get_class()
		classes[kind] = int(classes.get(kind, 0)) + 1
		var script := node.get_script() as Script
		if script != null:
			scripted += 1
		if node.is_processing() or node.is_physics_processing():
			var name: String = script.get_global_name() if script != null and script.get_global_name() != &"" else kind
			processing[name] = int(processing.get(name, 0)) + 1
	return {"nodes": nodes.size(), "scripted": scripted, "processing_nodes": _top(processing, 14), "classes": _top(classes, 16)}


## The [param count] biggest entries of a name -> number dictionary.
static func _top(counts: Dictionary, count: int) -> Dictionary:
	var names: Array = counts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var out := {}
	for name: String in names.slice(0, count):
		out[name] = counts[name]
	return out


# --- segments ---

func _hub_idle() -> void:
	_place(WALK_PATH[0])
	await _measure("hub_idle", _keep_alive)


func _walk() -> void:
	_place(WALK_PATH[0])
	museum.player.set_flashlight(true)
	var state := {"leg": 1, "at": WALK_PATH[0]}
	var speed := museum.player.sprint_speed / TICKS_PER_SECOND
	var step := func(_i: int, _ticks: int) -> void:
		var leg: int = state["leg"]
		var at: Vector3 = state["at"]
		var to: Vector3 = WALK_PATH[leg] - at
		if to.length() <= speed:
			at = WALK_PATH[leg]
			if leg < WALK_PATH.size() - 1:
				state["leg"] = leg + 1
		else:
			at += to.normalized() * speed
			museum.player.head.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)
		state["at"] = at
		museum.player.global_position = at
		museum.player.health.heal(1000000.0)
	await _measure("walk", step)
	museum.player.set_flashlight(false)


func _fight_hall() -> void:
	var exhibits := museum.exhibits()
	if exhibits.is_empty():
		print("cpu profile: no exhibits for the fight")
		return
	# the knot: the exhibit with the most others within 14 m
	var best: Enemy = exhibits[0]
	var best_count := -1
	for exhibit in exhibits:
		var near := 0
		for other in exhibits:
			if exhibit.global_position.distance_to(other.global_position) < 14.0:
				near += 1
		if near > best_count:
			best_count = near
			best = exhibit
	_place(best.global_position + Vector3(0.0, 0.1, 2.0))
	museum.player.set_flashlight(true)
	var hunted := exhibits.duplicate()
	hunted.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_to(museum.player.global_position) < b.global_position.distance_to(museum.player.global_position))
	for i in mini(FIGHT_EXHIBITS, hunted.size()):
		hunted[i].brain.wake()
	var step := func(i: int, ticks: int) -> void:
		museum.player.health.heal(1000000.0)
		var share := float(i) / maxf(ticks, 1)
		_aim_at_nearest()
		_fire(&"gatling" if share < 0.29 or share >= 0.71 else (&"shotgun" if share < 0.5 else &"pistol"))
	await _measure("fight_hall", step)
	museum.player.set_flashlight(false)
	_result["fight_hall_exhibits_woken"] = mini(FIGHT_EXHIBITS, hunted.size())
	_result["fight_hall_knot_size"] = best_count


func _colossus() -> void:
	var keeper := museum.floor_game.guardians
	var colossus: Guardian = keeper.guardians.get(&"colossus") if keeper != null else null
	if colossus == null:
		print("cpu profile: no Colossus")
		return
	_place(colossus.global_position - colossus.global_basis.z * 12.0 + Vector3.UP * 0.05)
	await _guardian_fight("colossus", colossus, Vector3.UP * 5.0)


func _trex() -> void:
	var finale := museum.floor_game.finale
	if finale == null or not is_instance_valid(finale.boss):
		print("cpu profile: no T-Rex")
		return
	_place(Vector3(10.0, 0.1, -8.0))
	finale.boss.wake()
	if finale.has_method(&"_on_boss_phase"):
		finale.call(&"_on_boss_phase", 1)
	await _guardian_fight("trex", finale.boss, Vector3.UP * 3.0)


## The gatling at a big enemy that is awake (its health is topped up: the
## fight must not end).
func _guardian_fight(label: String, boss: Node3D, aim_offset: Vector3) -> void:
	var step := func(_i: int, _ticks: int) -> void:
		museum.player.health.heal(1000000.0)
		var health: Variant = boss.get("health")
		if health != null and health.has_method(&"heal"):
			health.heal(1000000.0)
		var aim := boss.global_position + aim_offset - museum.player.camera.global_position
		museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
		_fire(&"gatling")
	await _measure(label, step)


func _keep_alive(_i: int, _ticks: int) -> void:
	museum.player.health.heal(1000000.0)


# --- measuring ---

## Plays [param step] (called in every physics tick with the tick's number
## and the segment's tick count) for the segment's seconds, after
## SETTLE_TICKS unmeasured ones, and records the segment: the tick's physics
## and idle time (total) and per subsystem, perception, counts.
func _measure(label: String, step: Callable) -> void:
	var seconds: float = SEGMENT_SECONDS[label] * (QUICK_FACTOR if _quick else 1.0)
	_ticks = maxi(roundi(seconds * TICKS_PER_SECOND), 10)
	_step = step
	_tick = 0
	await _frames(SETTLE_TICKS)
	sections.reset()
	_physics_us.clear()
	_idle_us.clear()
	# (read by name: the tool also runs on a branch from before the dozing and the spread culling)
	var culler: Node = museum.floor_level.culler if museum.floor_level != null else null
	var changes_before: int = culler.get(&"room_changes") if culler != null and culler.get(&"room_changes") != null else 0
	if culler != null:
		culler.set(&"worst_check_usec", 0)
	var due_before := _clock_stat(&"due_ticks")
	PerceptionWorld.profiling = true
	PerceptionWorld.stats = {"looks": 0, "rays": 0, "look_usec": 0, "noises": 0}
	_tick = 0
	_recording = true
	await _frames(_ticks)
	_recording = false
	_step = Callable()
	PerceptionWorld.profiling = false
	var stats := PerceptionWorld.stats
	var physics_ms := _milliseconds(_physics_us)
	var idle_ms := _milliseconds(_idle_us)
	var entry := {
		"name": label,
		"seconds": snappedf(_ticks / float(TICKS_PER_SECOND), 0.01),
		"ticks": _ticks,
		"physics_ms": _summary(physics_ms),
		"idle_ms": _summary(idle_ms),
		"tick_ms": snappedf(_mean(physics_ms) + _mean(idle_ms), 0.001),
		"perception": {
			"looks_per_s": snappedf(float(stats["looks"]) / (_ticks / float(TICKS_PER_SECOND)), 0.1),
			"rays_per_s": snappedf(float(stats["rays"]) / (_ticks / float(TICKS_PER_SECOND)), 0.1),
			"look_us_per_tick": snappedf(float(stats["look_usec"]) / _ticks, 0.1),
			"noises": int(stats["noises"]),
		},
		"counts": _counts(),
		"room_culler": {
			"room_changes": (int(culler.get(&"room_changes")) - changes_before) if culler != null and culler.get(&"room_changes") != null else 0,
			"worst_change_ms": snappedf(int(culler.get(&"worst_check_usec")) / 1000.0, 0.001) if culler != null and culler.get(&"worst_check_usec") != null else 0.0,
		},
		"dozing_ticks_per_tick": snappedf(float(_clock_stat(&"due_ticks") - due_before) / _ticks, 0.01),
	}
	var by_section := {}
	var sum_physics := 0.0
	var sum_idle := 0.0
	for section in sections.names:
		var physics := _summary(PackedFloat32Array(sections.samples[section]["physics"]))
		var idle := _summary(PackedFloat32Array(sections.samples[section]["idle"]))
		by_section[section] = {"physics_ms": physics, "idle_ms": idle}
		sum_physics += physics["mean"]
		sum_idle += idle["mean"]
	entry["sections"] = by_section
	entry["unattributed"] = {
		"physics_ms_mean": snappedf(maxf(_mean(physics_ms) - sum_physics, 0.0), 0.001),
		"idle_ms_mean": snappedf(maxf(_mean(idle_ms) - sum_idle, 0.0), 0.001),
	}
	_segments.append(entry)
	_print_segment(entry)


static func _milliseconds(microseconds: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for us in microseconds:
		out.append(us / 1000.0)
	return out


static func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()


static func _summary(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	return {
		"mean": snappedf(total / values.size(), 0.001),
		"p95": snappedf(sorted[mini(int(values.size() * 0.95), values.size() - 1)], 0.001),
		"max": snappedf(sorted[values.size() - 1], 0.001),
	}


func _counts() -> Dictionary:
	var ai := PerfStats.ai(get_tree())
	var m := PerfStats.monitors()
	var clock := get_node_or_null(^"/root/ExhibitClock")
	return {"exhibits": ai["exhibits"], "awake": ai["awake"], "hunting": ai["hunting"], "alert": ai["alert"],
		"dozing": clock.call(&"dozing") if clock != null else 0,
		"guardians_fighting": ai["guardians_fighting"], "nodes": m["nodes"], "physics_bodies": m["bodies"],
		"collision_pairs": m["pairs"]}


## A counter of the ExhibitClock autoload (0 without it).
func _clock_stat(stat: StringName) -> int:
	var clock := get_node_or_null(^"/root/ExhibitClock")
	return int(clock.get(stat)) if clock != null else 0


func _print_segment(entry: Dictionary) -> void:
	print("")
	print("== %s  %.1f s  (%d exhibits, %d awake, %d hunting, %d dozing, %d guardians fighting, %d nodes)" % [entry["name"], entry["seconds"],
			entry["counts"]["exhibits"], entry["counts"]["awake"], entry["counts"]["hunting"], entry["counts"]["dozing"], entry["counts"]["guardians_fighting"], entry["counts"]["nodes"]])
	print("   a tick (headless, no rendering): %.2f ms = physics %.2f (p95 %.2f, max %.2f) + idle %.2f (p95 %.2f, max %.2f)" % [
			entry["tick_ms"], entry["physics_ms"]["mean"], entry["physics_ms"]["p95"], entry["physics_ms"]["max"],
			entry["idle_ms"]["mean"], entry["idle_ms"]["p95"], entry["idle_ms"]["max"]])
	var names: Array = (entry["sections"] as Dictionary).keys()
	names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _cost(entry["sections"][a]) > _cost(entry["sections"][b]))
	print("   %-12s %-34s %-34s" % ["subsystem", "physics ms: mean / p95 / max", "idle (_process) ms: mean / p95 / max"])
	for section in names:
		var row: Dictionary = entry["sections"][section]
		print("   %-12s %8.3f / %7.3f / %7.3f      %8.3f / %7.3f / %7.3f" % [section,
				row["physics_ms"]["mean"], row["physics_ms"]["p95"], row["physics_ms"]["max"],
				row["idle_ms"]["mean"], row["idle_ms"]["p95"], row["idle_ms"]["max"]])
	print("   %-12s %8.3f                                %8.3f      (the physics step, timers, tweens, nodes of no section)" % ["unattributed",
			entry["unattributed"]["physics_ms_mean"], entry["unattributed"]["idle_ms_mean"]])
	print("   perception    %.0f looks/s, %.0f rays/s, %.1f us a tick (inside the exhibits' physics time)" % [entry["perception"]["looks_per_s"], entry["perception"]["rays_per_s"], entry["perception"]["look_us_per_tick"]])
	print("   dozing        %d exhibits at the end, %.2f dozing ticks a tick; room culler: %d room changes, worst check %.2f ms" % [entry["counts"]["dozing"],
			entry["dozing_ticks_per_tick"], entry["room_culler"]["room_changes"], entry["room_culler"]["worst_change_ms"]])


static func _cost(row: Dictionary) -> float:
	return float(row["idle_ms"]["mean"]) + float(row["physics_ms"]["mean"])


func _finish() -> void:
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	var file := FileAccess.open(OUT_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_result, "  "))
		file.close()
		print("")
		print("written ", ProjectSettings.globalize_path(OUT_FILE))
	else:
		print("MISSED: could not write ", OUT_FILE)


# --- the guard ---

func _place(feet: Vector3) -> void:
	museum.player.global_position = feet
	museum.player.velocity = Vector3.ZERO


func _nearest() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for exhibit in museum.exhibits():
		if exhibit.brain.state == EnemyBrain.State.DESTROYED:
			continue
		var d := exhibit.global_position.distance_to(museum.player.global_position)
		if d < best_distance:
			best_distance = d
			best = exhibit
	return best


func _aim_at_nearest() -> void:
	var nearest := _nearest()
	if nearest == null:
		return
	var aim := nearest.global_position + Vector3.UP * 0.9 - museum.player.camera.global_position
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)


## Fires [param id] (selected, magazine and reserve refilled).
func _fire(id: StringName) -> void:
	var weapons := museum.player.weapons
	if weapons.current_state() == null or weapons.current_state().data.id != id:
		weapons.select_id(id)
	var state := weapons.current_state()
	if state != null:
		state.magazine = state.data.magazine_size
		state.reserve = state.data.max_reserve
	weapons.try_fire()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
