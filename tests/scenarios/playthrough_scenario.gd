extends Node
## The playthrough run (plan docs/superpowers/plans/2026-10-21-przejscie-bota.md,
## owner's #60): a fresh save, then night after night the game scene
## (Museum) with the PlaythroughBot playing it, as SceneFlow would run the
## game - death or dawn -> the next night, the guard walking down into the
## crypt -> the end. Headless only (tools/run_playthrough.sh).
##   --seed=<n>          the game's seed (GameState.seed_base) and the bot's
##   --nights=<n>        give up after this many nights (default 12)
##   --time-scale=<k>    Engine.time_scale (default 4: a step of physics is
##                       k/60 s of game time; 1 = the game's own pace)
##   --grey              Floor I as greybox (the suite's build) instead of dressed
##   --minutes=<m>       give up after this many real minutes (default 150)
##   --until=<step>      stop once this step of progress is done (a part run)
##   --out=<dir>         where the log and the report go (default
##                       res://tests/_out/playthrough/<seed>)
##   --human             the bot plays like a person (PlaythroughBot.human:
##                       a slower view, a straying aim, a moment to react)
## Writes log.jsonl, report.json, report.html; prints a summary line
## ("PLAYTHROUGH ...") and quits with 0 (finished or stopped as asked), 2
## (gave up: nights or minutes ran out).

const SAMPLE_EVERY := PlaythroughLog.SAMPLE_EVERY


## Counts the engine's and the scripts' errors and warnings of the run (any
## thread) and keeps the first few, for the report.
class ErrorCounter:
	extends Logger
	const KEEP := 20
	var errors: int = 0
	var warnings: int = 0
	var first: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		if error_type == 1:   # Logger.ErrorType: ERROR, WARNING, SCRIPT, SHADER
			warnings += 1
		else:
			errors += 1
			if first.size() < KEEP:
				first.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass
## Progress is diffed against the save this often (game s).
const DIFF_EVERY := 1.0
## A night with no new progress, no new room and no new kill for this long
## (game s) is noted as a possible soft lock (once a night).
const STALL_NOTE := 300.0

var seed_value: int = 1
var max_nights: int = 12
var time_scale: float = 4.0
var dressed: bool = true
var max_minutes: float = 150.0
var until: StringName = &""
var out_dir: String = ""
var human: bool = false

var run_log: PlaythroughLog
var errors := ErrorCounter.new()
var museum: Museum = null
var bot: PlaythroughBot = null
var night_index: int = 0
var finished: bool = false

var _night: Dictionary = {}
var _night_clock: float = 0.0
var _sample_left: float = 0.0
var _diff_left: float = 0.0
var _known: Dictionary = {}
var _rooms_seen: int = 0
var _last_change: float = 0.0
var _stall_noted: bool = false
var _ending: bool = false
var _started_msec: int = 0
var _night_started_msec: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--nights="):
			max_nights = arg.trim_prefix("--nights=").to_int()
		elif arg.begins_with("--time-scale="):
			time_scale = maxf(arg.trim_prefix("--time-scale=").to_float(), 0.25)
		elif arg == "--grey":
			dressed = false
		elif arg.begins_with("--minutes="):
			max_minutes = arg.trim_prefix("--minutes=").to_float()
		elif arg.begins_with("--until="):
			until = StringName(arg.trim_prefix("--until="))
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg == "--human":
			human = true
	if out_dir == "":
		out_dir = "res://tests/_out/playthrough/%d" % seed_value
	out_dir = ProjectSettings.globalize_path(out_dir)
	_started_msec = Time.get_ticks_msec()
	OS.add_logger(errors)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameInput.capture_allowed = false
	# deterministic navigation updates (as the test runner has them)
	ProjectSettings.set_setting(&"navigation/world/map_use_async_iterations", false)
	ProjectSettings.set_setting(&"navigation/world/region_use_async_iterations", false)
	NavigationServer3D.map_set_use_async_iterations(get_viewport().find_world_3d().navigation_map, false)
	SavePaths.override_dir = out_dir.path_join("save")
	for file in DirAccess.get_files_at(SavePaths.dir()):
		DirAccess.remove_absolute(SavePaths.dir().path_join(file))
	Settings.reset_to_defaults(false)
	MuseumFloorLevel.dress_default = dressed
	Museum.level_id = &"floor1"
	Engine.time_scale = time_scale
	run_log = PlaythroughLog.new()
	run_log.open(out_dir, seed_value, time_scale, dressed)
	GameState.file_path = ""
	GameState.new_game()
	GameState.seed_base = seed_value
	GameState.save_game()
	RunState.reset()
	print("PLAYTHROUGH seed %d: time x%s, %s floor, up to %d nights%s -> %s" % [seed_value, str(time_scale), "dressed" if dressed else "greybox", max_nights, ", plays like a person" if human else "", out_dir])
	_start_night.call_deferred()


func _start_night() -> void:
	night_index += 1
	seed(GameState.mix_seed(seed_value, GameState.night) ^ 0x5bd1e995)
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	bot = PlaythroughBot.new()
	bot.human = human
	bot.setup(museum, GameState.mix_seed(seed_value, GameState.night))
	museum.add_child(bot)
	bot.event.connect(_on_bot_event)
	museum.next_night_requested.connect(_on_next_night, CONNECT_ONE_SHOT)
	museum.demo_end_requested.connect(_on_demo_end, CONNECT_ONE_SHOT)
	Events.player_died.connect(_on_died)
	_night_clock = 0.0
	_sample_left = 0.0
	_diff_left = DIFF_EVERY
	_known = _progress_lists()
	_rooms_seen = GameState.rooms_visited.size()
	_last_change = 0.0
	_stall_noted = false
	_ending = false
	_night_started_msec = Time.get_ticks_msec()
	_night = {"night": GameState.night, "start_haven": String(GameState.start_haven), "dust_start": RunState.dust,
			"steps": [], "zones": {}, "deaths": 0, "exhibits": museum.exhibits().size()}
	_event(&"night_start", {"haven": String(GameState.start_haven), "dust": RunState.dust, "exhibits": museum.exhibits().size(),
			"modifier": String(museum.night.modifier), "weapons": _strings(GameState.weapons), "upgrades": GameState.upgrades.duplicate()})


func _physics_process(delta: float) -> void:
	if museum == null or not is_instance_valid(museum) or get_tree().paused or _ending:
		return
	if (Time.get_ticks_msec() - _started_msec) / 60000.0 > max_minutes:
		_give_up("the real-time limit (%d min) ran out" % int(max_minutes))
		return
	var guard := museum.player
	if not is_instance_valid(guard) or museum.night_over():
		return
	_night_clock += delta
	run_log.total += delta
	var zone := String(museum.floor_level.zone_at(guard.global_position + Vector3.UP * 0.5))
	var zones: Dictionary = _night["zones"]
	zones[zone] = float(zones.get(zone, 0.0)) + delta
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left = SAMPLE_EVERY
		_sample(guard, zone)
	_diff_left -= delta
	if _diff_left <= 0.0:
		_diff_left = DIFF_EVERY
		_diff_progress()
	if not _stall_noted and _night_clock - _last_change > STALL_NOTE:
		_stall_noted = true
		_event(&"softlock", {"why": "no new progress, room or kill for %s" % PlaythroughLog.duration(STALL_NOTE), "task": String(bot.task.get("key", "")), "area": String(bot.area), "at": PlaythroughBot._v(guard.global_position)})


func _sample(guard: Player, zone: String) -> void:
	var ammo := {}
	var share_sum := 0.0
	var share_n := 0
	for state in guard.weapons.owned:
		if state.data.ammo_mode != WeaponData.AmmoMode.MAGAZINE:
			continue
		var rounds := state.magazine + state.reserve
		ammo[String(state.data.id)] = rounds
		var start_load := state.data.magazine_size + int(Loadout.START_RESERVE.get(state.data.id, state.data.start_reserve))
		share_sum += float(rounds) / maxf(float(start_load), 1.0)
		share_n += 1
	var awake := 0
	for exhibit in museum.exhibits():
		if exhibit.brain.state != EnemyBrain.State.DORMANT:
			awake += 1
	run_log.sample({"t": snappedf(run_log.total, 0.1), "night": GameState.night, "clock": snappedf(_night_clock, 0.1),
		"health": snappedf(guard.health.current, 0.1), "health_max": guard.health.max_health,
		"health_share": snappedf(guard.health.current / maxf(guard.health.max_health, 1.0), 0.01), "dust": RunState.dust,
		"ammo": ammo, "ammo_share": snappedf(share_sum / maxf(share_n, 1), 0.01), "zone": zone,
		"room": String(museum.floor_level.layout.room_at(guard.global_position + Vector3.UP * 0.5)),
		"awake": awake, "task": String(bot.task.get("key", "")), "phase": String(bot.task.get("phase", "")),
		"nav": PlaythroughNav.Status.keys()[bot.nav.status], "at": PlaythroughBot._v(guard.global_position), "foe": PlaythroughBot._describe(bot.foe) if is_instance_valid(bot.foe) else "",
		"fatigue": snappedf(guard.fatigue.effect(), 0.01)})


## Every permanent list of the save that marks progress.
func _progress_lists() -> Dictionary:
	return {"weapon": GameState.weapons.duplicate(), "item": GameState.items.duplicate(), "seal": GameState.seals.duplicate(),
		"shard": GameState.shards.duplicate(), "guardian": GameState.guardians_defeated.duplicate(), "gate": GameState.gates_open.duplicate(),
		"flag": GameState.flags.duplicate(), "haven": GameState.havens.duplicate(), "key": [&"pistol_key"] if GameState.pistol_key else []}


func _diff_progress() -> void:
	var now := _progress_lists()
	var reached := false
	for kind: String in now:
		for entry in now[kind]:
			if (_known.get(kind, []) as Array).has(entry):
				continue
			var step := String(entry)
			if kind == "key":
				step = "pistol_key"
			_event(&"progress", {"what": "%s %s" % [kind, String(entry)], "step": step if ProgressRules.step_ids().has(StringName(step)) or kind == "key" else ""})
			if ProgressRules.step_ids().has(StringName(step)) or kind == "key":
				(_night["steps"] as Array).append(step)
			_last_change = _night_clock
			if until != &"" and StringName(step) == until:
				reached = true
	_known = now
	if GameState.rooms_visited.size() > _rooms_seen:
		_rooms_seen = GameState.rooms_visited.size()
		_last_change = _night_clock
	if reached:
		# after _known is up to date: the night's end diffs the progress once
		# more (before, that found the step again and stopped again, round
		# and round - a stack overflow)
		_stop("reached %s" % until)


func _on_bot_event(kind: StringName, data: Dictionary) -> void:
	if kind == &"fight" or kind == &"task_done":
		_last_change = _night_clock if kind == &"fight" else _last_change
	_event(kind, data)


func _event(kind: StringName, data: Dictionary) -> void:
	run_log.event(kind, data, int(_night.get("night", GameState.night)), _night_clock)
	if kind in [&"night_start", &"death", &"night_end", &"progress", &"softlock", &"task_failed", &"shop"]:
		print("  [n%d %s] %s %s" % [int(_night.get("night", GameState.night)), PlaythroughReport._clock(_night_clock), kind, JSON.stringify(data)])


func _on_died() -> void:
	if museum == null or bot == null:
		return
	var guard := museum.player
	var at := guard.global_position
	_night["deaths"] = int(_night["deaths"]) + 1
	_event(&"death", {"by": String(bot.last_damage().get("by", "?")), "last_hit": bot.last_damage(), "at": PlaythroughBot._v(at),
		"zone": String(museum.floor_level.zone_at(at + Vector3.UP * 0.5)), "room": String(museum.floor_level.layout.room_at(at + Vector3.UP * 0.5)),
		"task": String(bot.task.get("key", "")), "foe": PlaythroughBot._describe(bot.foe) if is_instance_valid(bot.foe) else "",
		"dust_dropped": int(GameState.lantern.get("dust", 0)) if bool(GameState.lantern.get("active", false)) else 0})


func _end_night(end: String) -> void:
	if Events.player_died.is_connected(_on_died):
		Events.player_died.disconnect(_on_died)
	_diff_progress()
	var stats: Dictionary = bot.stats if bot != null else {}
	_night["end"] = end
	_night["clock"] = snappedf(_night_clock, 0.1)
	_night["seconds"] = snappedf(_night_clock, 0.1)
	_night["dust_end"] = GameState.run_dust if end != "death" else 0
	_night["kills"] = int(stats.get("kills", 0))
	_night["damage_taken"] = snappedf(float(stats.get("damage_taken", 0.0)), 0.1)
	_night["bought"] = stats.get("bought", [])
	_night["stuck"] = int(stats.get("stuck", 0))
	_night["stats"] = stats.duplicate()
	_night["fights_by"] = stats.get("fights_by", {})
	if bot != null:
		_night["bot_ms_per_step"] = snappedf(bot.think_usec / 1000.0 / maxf(bot.think_steps, 1), 0.01)
	_night["real_seconds"] = snappedf((Time.get_ticks_msec() - _night_started_msec) / 1000.0, 0.1)
	run_log.night_done(_night)
	_event(&"night_end", {"end": end, "clock": snappedf(_night_clock, 0.1), "kills": _night["kills"], "steps": _night["steps"], "dust": _night["dust_end"],
			"shots": stats.get("shots", 0), "held": stats.get("held", {}), "stuck": _night["stuck"],
			"real_seconds": _night.get("real_seconds", 0.0), "bot_ms_per_step": _night.get("bot_ms_per_step", 0.0)})


func _on_next_night() -> void:
	if _ending:
		return
	var died := int(_night.get("deaths", 0)) > 0
	_end_night("death" if died else "dawn")
	await _clear_museum()
	if night_index >= max_nights:
		_give_up("%d nights played without reaching the end" % max_nights)
		return
	_start_night()


func _on_demo_end() -> void:
	finished = true
	_end_night("finished")
	_finish({"finished": true, "why": "the guard walked down into the crypt"}, 0)


func _stop(why: String) -> void:
	if _ending:
		return
	_ending = true
	_end_night("stopped")
	_finish({"finished": false, "stopped": true, "why": why}, 0)


func _give_up(why: String) -> void:
	if _ending:
		return
	_ending = true
	if museum != null and is_instance_valid(museum) and not _night.is_empty() and not _night.has("end"):
		_end_night("aborted")
	_finish({"finished": false, "why": why}, 2)


func _clear_museum() -> void:
	if museum != null and is_instance_valid(museum):
		museum.queue_free()
	museum = null
	bot = null
	await get_tree().process_frame
	await get_tree().process_frame


func _finish(outcome: Dictionary, code: int) -> void:
	_ending = true
	var steps := 0
	for step in ProgressRules.step_ids():
		if ProgressRules.is_done(FloorProgress.from_game(GameState), step):
			steps += 1
	outcome["steps_done"] = steps
	outcome["steps_total"] = ProgressRules.step_ids().size()
	outcome["deaths"] = int(GameState.stats.get("deaths", 0))
	outcome["nights"] = night_index
	outcome["upgrades"] = GameState.upgrades.duplicate()
	outcome["engine_errors"] = errors.errors
	outcome["engine_warnings"] = errors.warnings
	outcome["first_errors"] = errors.first.duplicate()
	run_log.write_report(outcome)
	run_log.close()
	print("PLAYTHROUGH seed %d: %s after %d nights, %d deaths, %d/%d steps, game %s, real %s -> %s" % [seed_value,
		"FINISHED" if bool(outcome.get("finished", false)) else ("STOPPED" if bool(outcome.get("stopped", false)) else "NOT FINISHED"),
		night_index, int(outcome["deaths"]), steps, int(outcome["steps_total"]), PlaythroughLog.duration(run_log.total),
		PlaythroughLog.duration((Time.get_ticks_msec() - _started_msec) / 1000.0), out_dir.path_join("report.html")])
	Engine.time_scale = 1.0
	await _clear_museum()
	OS.remove_logger(errors)
	Sfx.quit_cleanly(code)


static func _strings(names: Array) -> Array:
	return names.map(func(n: Variant) -> String: return String(n))
