extends Node
## Audio check (not part of the headless suite): drives Music, Ambience and
## the guard's Footsteps through a night in the real Museum, reached by a
## real scene swap (so the autoloads set themselves up as in the game: the
## night's mood, the reverb zones from the lobby's rooms, the guard's
## footsteps), and measures the buses while it runs: menu theme, the walk,
## room zones and floors, the power cut, the crystal's flight, the T-Rex,
## victory, the witching hour, dawn, the next night (another real swap), a
## fight and its decay, death.
## Usage: bash tools/run_audio.sh   (Dummy audio driver: silent; SOUND=1
## to hear it). Prints a table and writes tests/_out/audio/report.txt.

const OUT_DIR := "res://tests/_out/audio/"
const BUSES: Array[StringName] = [&"Music", &"Ambience", &"SFX"]
## Room -> a spot on its floor (lobby coordinates).
const ROOMS := {&"security": Vector3(0, 0.1, 58), &"hall": Vector3(0, 0.1, 10), &"gallery": Vector3(-30, 0.1, 0),
	&"armory": Vector3(30, 0.1, 0), &"corridor_w": Vector3(-32, 0.1, 22), &"diorama": Vector3(0, 0.1, 34),
	&"balcony": Vector3(-16, 6.1, -9)}

var museum: Museum
var lines: PackedStringArray = []
var missed: int = 0


func _ready() -> void:
	Museum.level_id = &"lobby"   # a lobby scenario (the game plays Floor I)
	GameInput.capture_allowed = false
	GameInput.pause_on_focus_loss = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ignore := FileAccess.open(ProjectSettings.globalize_path("res://tests/_out/.gdignore"), FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	Music.enabled = true
	Ambience.enabled = true
	Foley.enabled = true
	_line("%-26s %-9s %-11s %s" % ["phase", "music", "zone", "bus peaks max/mean dB (Music | Ambience | SFX)"])
	await get_tree().process_frame   # after the autoloads' own look at the starting scene
	Music.set_scene_kind(AudioContext.MENU)
	await _sample("menu theme", 5.0)

	# the game: a first night, through a real scene swap (this node stays)
	var stage := Node.new()
	stage.name = "Stage"
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	_new_game(1)
	await _swap_to_museum()
	var night := Music.director.night
	_check(night.night == 1 and night.stage == NightObjective.Stage.FUSES, "the museum's night reached the music (night %d, stage %d)" % [night.night, night.stage])
	_check(Music.state() == MusicDirector.State.EXPLORE, "the walk")
	_check(AudioContext.level(get_tree()) == museum.lobby, "the audio finds the lobby")
	var parts := 0
	for room in museum.lobby.layout.rooms:
		parts += room.parts.size()
	_check(Ambience._auto_reverb.size() == parts, "reverb zones from the lobby's rooms: %d of %d parts" % [Ambience._auto_reverb.size(), parts])
	var steps := museum.player.get_node_or_null(^"Footsteps") as Footsteps
	_check(steps != null, "the guard has his footsteps")
	await _sample("night 1: security room", 6.0)
	var walk := Music.players[&"explore"] as AudioStreamPlayer
	var tension := Music.players[&"explore_tension"] as AudioStreamPlayer
	_line("  stems in sync: explore %.4f s, tension %.4f s (difference %.1f ms)" % [walk.get_playback_position(),
		tension.get_playback_position(), absf(walk.get_playback_position() - tension.get_playback_position()) * 1000.0])
	for room: StringName in [&"hall", &"balcony", &"gallery", &"armory", &"corridor_w", &"diorama", &"security"]:
		museum.player.respawn(ROOMS[room], 0.0)
		await _sample("room: " + String(room), 2.5)
		var floor_kind := steps.probe_surface() if steps != null else &"-"
		_check(Ambience.zone == Ambience.ROOM_ZONES[room], "%s: room tone %s" % [room, Ambience.zone])
		_check(floor_kind == Surface.of_room(room), "%s: floor %s (%s)" % [room, floor_kind, Surface.ROOM_SURFACES[room]])
	museum.player.respawn(ROOMS[&"hall"], PI)
	Input.action_press(&"move_forward")
	await _sample("walking the hall", 4.0)
	Input.action_press(&"sprint")
	await _sample("running the hall", 3.0)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	_line("  footsteps: %s, last surface %s" % [str(steps.steps_taken) if steps != null else "none attached",
		steps.surface if steps != null else &"-"])

	# the night's goal
	museum.player.respawn(ROOMS[&"hall"], PI)
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	_check(Music.director.hushed(), "the power cut hushes the music")
	_check(Ambience.power_cut_in(&"grand_hall"), "the hall's room tone goes dark")
	await _sample("power cut: hush", MusicDirector.HUSH_TIME)
	await _sample("power out: tension", 5.0)
	var crystal := museum.objective.crystal
	var toward_hall := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.respawn(_floor_under(crystal.global_position + toward_hall * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05, 0.0)
	await _sample("crystal flight", 3.0)
	_check(museum.objective.stage == NightObjective.Stage.FLIGHT, "the crystal flies")
	if await _follow_the_crystal():
		await _sample("T-Rex phase 1", 4.0)
		var boss := museum.objective.boss
		boss.brain.set_health_fraction(0.5)
		await _sample("T-Rex phase 2", 4.0)
		_check(Music.levels[&"boss_hi"] > 0.9, "phase 2 brings the hi stem")
		museum.player.respawn(Vector3(0, 0.1, 12), PI)
		boss.take_zone_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
		_clear_exhibits()   # whatever the roar called (the story, not the fight)
		await _sample("victory", MusicDirector.VICTORY_TIME + 0.5)
		await _sample("quiet walk to the stairs", 4.0)
		_check(Music.state() == MusicDirector.State.EXPLORE and Music.director.walk_level() < 1.0, "a quiet walk after the boss")
	else:
		_check(false, "the crystal arrived")

	# the clock: another night (night 3, full moon if drawn), the witching hour, dawn
	_new_game(3, &"full_moon")
	await _swap_to_museum()
	museum.player.respawn(ROOMS[&"gallery"], 0.0)
	await _sample("night 3 (%s)" % museum.night.modifier, 4.0)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() - 0.2
	await _sample("witching hour", 6.0)
	_check(Music.director.night.witching, "the witching hour reached the music")
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.2
	await _sample("dawn", Music.DAWN_FADE + 1.0)
	_check(Music.state() == MusicDirector.State.SILENT and not Music.is_family_playing(&"explore"), "dawn: the music faded away")
	_check(Ambience._birds != null and Ambience._birds.playing, "far birds at dawn")
	# the museum goes on to the next night by itself (SceneFlow, a real swap)
	var old := museum
	var waited := 0.0
	while waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if get_tree().current_scene is Museum and get_tree().current_scene != old:
			break
	museum = get_tree().current_scene as Museum
	_check(museum != null and museum != old, "the next night follows the dawn card")
	if museum != null and museum != old:
		museum.player.health.max_health = 1000000.0
		museum.player.health.heal(1000000.0)
		_clear_exhibits()
		await _sample("next night", 4.0)
		_check(Music.state() == MusicDirector.State.EXPLORE and not Music.director.night.dawn, "the next night walks again")

		museum.player.respawn(ROOMS[&"hall"], 0.0)   # out of the booth: a haven winds fights down twice as fast
		var info := DamageInfo.make(12.0, DamageInfo.Kind.BLUNT)
		for i in 8:
			Events.hit_landed.emit(null, info, i % 3 == 2)
			if i % 3 == 2:
				Events.enemy_destroyed.emit(null, info, false)
			await get_tree().create_timer(0.5).timeout
		await _sample("combat (hot)", 3.0)
		await _sample("combat decaying", MusicDirector.COMBAT_HOLD)
		await _sample("tension after the fight", 4.0)
		await _sample("calm again", MusicDirector.TENSION_HOLD)
		museum.player.take_damage(DamageInfo.make(museum.player.health.current * 10.0, DamageInfo.Kind.BLUNT))
		_check(Music.state() == MusicDirector.State.SILENT and (Music.stings[&"death_sting"] as AudioStreamPlayer).playing, "the death sting")
		await _sample("death", 3.0)

	_line("%d checks missed" % missed)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR + "report.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	GameInput.set_gameplay_scene(false)
	Music.stop_all()
	Ambience.reset()
	Sfx.quit_cleanly(0)


## A new game on [param night] (its draw with the crystal in the hall's
## case and, if one is given and drawn, [param modifier]).
func _new_game(night: int, modifier: StringName = &"") -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 600:
		GameState.seed_base = 5000 + base
		var plan := NightDirector.plan(GameState.night_seed(), night, description)
		if plan.crystal_case == &"crystal_case_hall" and (modifier == &"" or plan.modifier == modifier):
			break
	RunState.reset()


## The Museum in place of the running scene, the way SceneFlow swaps it.
func _swap_to_museum() -> void:
	var next := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	get_tree().change_scene_to_node(next)
	await get_tree().scene_changed
	museum = next
	# the guard only holds the ears: he must not fall; the story, not a fight
	museum.player.health.max_health = 1000000.0
	museum.player.health.heal(1000000.0)
	_clear_exhibits()
	await get_tree().process_frame


## Takes the night's exhibits away (and tells the music at once: its last
## look at them would otherwise count a fight that is gone).
func _clear_exhibits() -> void:
	for exhibit in museum.enemies_root.get_children():
		exhibit.free()
	Music._look_around()


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _follow_the_crystal() -> bool:
	for i in 60 * 40:
		var crystal := museum.objective.crystal
		if crystal == null or not is_instance_valid(crystal):
			return true
		if i % 6 == 0:
			museum.player.global_position = _floor_under(crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		missed += 1
	_line("  %s %s" % ["ok  " if ok else "MISSED", what])


func _sample(label: String, seconds: float) -> void:
	var peaks := {}
	var sums := {}
	var frames := 0
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		frames += 1
		for bus_name in BUSES:
			var bus := AudioServer.get_bus_index(bus_name)
			var level_db := maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.get_bus_peak_volume_right_db(bus, 0))
			level_db = maxf(level_db, -90.0)
			peaks[bus_name] = maxf(float(peaks.get(bus_name, -90.0)), level_db)
			sums[bus_name] = float(sums.get(bus_name, 0.0)) + level_db
	var cells: PackedStringArray = []
	for bus_name in BUSES:
		cells.append("%6.1f/%6.1f" % [peaks.get(bus_name, -90.0), float(sums.get(bus_name, 0.0)) / maxi(frames, 1)])
	_line("%-26s %-9s %-11s %s" % [label, MusicDirector.State.keys()[Music.state()], Ambience.zone, " | ".join(cells)])


func _line(text: String) -> void:
	lines.append(text)
	print(text)
