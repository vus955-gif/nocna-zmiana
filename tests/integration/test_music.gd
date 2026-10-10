extends TestCase
## The Music autoload: routing, crossfades, family sync, pause, events,
## stings. Automation is off in test runs; each test drives it by hand and
## leaves it silent.

const S := MusicDirector.State


func before_each() -> void:
	Music.reset()
	Music.enabled = true


func after_each() -> void:
	Music.reset()
	Music.enabled = false
	get_tree().paused = false


func _advance(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(step, left)
		Music.director.update(dt, 0, 0, false)
		Music.advance(dt)
		left -= dt


func _player(layer: StringName) -> AudioStreamPlayer:
	return Music.players[layer] as AudioStreamPlayer


func test_every_layer_and_sting_plays_on_the_music_bus() -> void:
	for layer: StringName in Music.players:
		var player := _player(layer)
		assert_not_null(player, String(layer))
		if player != null:
			assert_eq(player.bus, &"Music")
			assert_not_null(player.stream, String(layer) + " has its file")
	for sting in Music.STINGS:
		var player := Music.stings[sting] as AudioStreamPlayer
		assert_eq(player.bus, &"Music")
		assert_not_null(player.stream)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")), &"Master")


func test_menu_theme_fades_in_and_keeps_playing_through_a_pause() -> void:
	Music.set_scene_kind(AudioContext.MENU)
	_advance(0.05)
	assert_true(_player(&"menu").playing, "started")
	assert_lt(_player(&"menu").volume_db, -10.0, "starts quiet")
	_advance(Music.FADE_IN[&"menu"])
	assert_almost_eq(Music.levels[&"menu"], 1.0, 0.001)
	assert_almost_eq(_player(&"menu").volume_db, 0.0, 0.01)
	get_tree().paused = true
	assert_true(_player(&"menu").can_process(), "menu music plays on in a paused tree")
	assert_false(_player(&"explore").can_process(), "game music pauses with the game")


func test_volume_curve_is_equal_power() -> void:
	assert_eq(Music.volume_db(0.0), Music.SILENT_DB)
	assert_almost_eq(Music.volume_db(1.0), 0.0, 0.001)
	assert_almost_eq(Music.volume_db(0.5), -3.01, 0.02)


func test_combat_crossfades_from_the_walk_and_back() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	assert_almost_eq(Music.levels[&"explore"], 1.0, 0.001)
	assert_true(Music.is_family_playing(&"explore"))
	assert_true(_player(&"explore_tension").playing, "the tension stem runs in sync, silent")
	assert_almost_eq(Music.levels[&"explore_tension"], 0.0, 0.001)
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	assert_eq(Music.state(), S.COMBAT)
	_advance(0.2)
	assert_gt(Music.levels[&"combat"], 0.5, "combat hits fast")
	assert_lt(Music.levels[&"explore"], 1.0, "the walk fades")
	assert_true(Music.is_family_playing(&"combat"))
	_advance(Music.FADE_OUT[&"explore"] + 0.1)
	assert_false(Music.is_family_playing(&"explore"), "a silent family stops")
	_advance(MusicDirector.COMBAT_HOLD)
	assert_eq(Music.state(), S.TENSION, "the fight decays")
	_advance(Music.FADE_OUT[&"combat"] + 0.1)
	assert_false(Music.is_family_playing(&"combat"))
	assert_true(Music.is_family_playing(&"explore"), "the walk is back")
	assert_gt(Music.levels[&"explore_tension"], 0.5, "with tension on top")


func test_a_hot_fight_brings_the_hi_stem() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	for i in 6:
		Music.director.on_combat(MusicDirector.KILL_HEAT)
	_advance(Music.FADE_IN[&"combat_hi"] + 0.1)
	assert_almost_eq(Music.levels[&"combat_hi"], 1.0, 0.001)
	assert_true(_player(&"combat_hi").playing)


func test_game_music_freezes_while_paused() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(1.0)
	var level: float = Music.levels[&"explore"]
	get_tree().paused = true
	Music._process(0.5)
	assert_almost_eq(Music.levels[&"explore"], level, 0.0001, "no fading while paused")
	assert_false(_player(&"explore").can_process(), "the stream is paused with the game")
	Music.director.on_combat(MusicDirector.HIT_HEAT)
	var since := Music.director.since_combat()
	Music._process(0.5)
	assert_almost_eq(Music.director.since_combat(), since, 0.0001, "combat timers freeze")
	get_tree().paused = false


func test_events_drive_the_state_only_when_enabled() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	var info := DamageInfo.make(10.0, DamageInfo.Kind.BLUNT)
	Events.hit_landed.emit(null, info, false)
	assert_eq(Music.state(), S.COMBAT)
	Music.reset()
	Music.enabled = false
	Music.director.set_mode(AudioContext.GAME)
	Events.player_damaged.emit(5.0, Vector3.ZERO)
	assert_eq(Music.state(), S.EXPLORE, "disabled: events ignored")


func test_death_plays_the_sting_and_silences_the_night() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(1.0)
	Events.player_died.emit()
	assert_eq(Music.state(), S.SILENT)
	assert_true((Music.stings[&"death_sting"] as AudioStreamPlayer).playing, "death sting")
	_advance(Music.DEATH_FADE + 0.1)
	assert_false(Music.is_family_playing(&"explore"))


func test_a_guard_respawned_in_place_brings_the_night_back() -> void:
	var guard := Player.new()
	add_child(guard)
	Music.set_scene_kind(AudioContext.GAME)
	Events.player_died.emit()
	assert_eq(Music.state(), S.SILENT)
	Music._look_around()
	assert_eq(Music.state(), S.EXPLORE, "the guard stands (a sandbox respawn): back to the walk")


func test_boss_track_phases_and_victory() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	var boss := _FakeBoss.new()
	add_child(boss)
	Events.boss_awakened.emit(boss)
	assert_eq(Music.state(), S.BOSS)
	_advance(1.0)
	assert_true(Music.is_family_playing(&"boss"))
	assert_almost_eq(Music.levels[&"boss_hi"], 0.0, 0.001)
	boss.phase_changed.emit(2)
	_advance(Music.FADE_IN[&"boss_hi"] + 0.1)
	assert_almost_eq(Music.levels[&"boss_hi"], 1.0, 0.001, "phase 2")
	Events.boss_defeated.emit(boss)
	assert_eq(Music.state(), S.VICTORY)
	assert_true((Music.stings[&"victory_sting"] as AudioStreamPlayer).playing)
	_advance(MusicDirector.VICTORY_TIME + 0.2)
	assert_eq(Music.state(), S.EXPLORE)


func test_a_boss_node_leaving_the_tree_ends_its_music() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	var boss := _FakeBoss.new()
	add_child(boss)
	Events.boss_awakened.emit(boss)
	assert_eq(Music.state(), S.BOSS)
	remove_child(boss)
	boss.free()
	assert_eq(Music.state(), S.EXPLORE)


func test_resync_pulls_a_drifted_stem_back() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	_advance(0.2)
	var walk := _player(&"explore")
	var tension := _player(&"explore_tension")
	assert_true(walk.playing and tension.playing)
	tension.seek(walk.get_playback_position() + 3.0)
	assert_eq(Music.resync(), 1, "one stem moved")
	assert_almost_eq(tension.get_playback_position(), walk.get_playback_position(), 0.05)
	assert_eq(Music.resync(), 0, "in sync: nothing to do")


func test_awake_exhibits_near_the_camera_count_as_threats() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var near := WaxFigure.new()
	near.position = Vector3(0, 0, -6)
	add_child(near)
	var far := WaxFigure.new()
	far.position = Vector3(0, 0, -80)
	add_child(far)
	var asleep := WaxFigure.new()
	asleep.position = Vector3(20, 0, 0)   # in range, but beyond the wake radius of the one woken
	add_child(asleep)
	near.brain.wake()
	far.brain.wake()
	Music._look_around()
	assert_eq(Music._nearby, 1, "only the awake exhibit in range")
	assert_eq(Music._engaged, 1, "6 m away is a fight")


func test_exhibits_turned_to_stone_at_dawn_are_no_threat() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var near := WaxFigure.new()
	near.position = Vector3(0, 0, -6)
	add_child(near)
	near.brain.wake()
	near.freeze()
	Music._look_around()
	assert_eq(Music._nearby, 0, "a statue again")
	assert_eq(Music._engaged, 0)


func test_a_family_without_its_lead_file_is_not_restarted_every_frame() -> void:
	var walk := _player(&"explore")
	var stream := walk.stream
	walk.stream = null
	Music.set_scene_kind(AudioContext.GAME)
	_advance(0.5)
	assert_false(_player(&"explore_tension").playing, "no family start without its lead")
	walk.stream = stream


func test_stop_all_leaves_nothing_playing() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	Music.director.on_combat(MusicDirector.KILL_HEAT)
	_advance(0.5)
	Music.stop_all()
	for layer: StringName in Music.players:
		assert_false(_player(layer).playing, String(layer))
		assert_eq(Music.levels[layer], 0.0)


func test_quitting_stops_every_player_before_the_engine_goes() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	Music.director.on_combat(MusicDirector.KILL_HEAT)
	_advance(0.5)
	Ambience.enabled = true
	Ambience.set_active(true)
	Ambience.set_zone(&"security")
	Ambience.advance(1.0)
	Ambience.play_shot(&"creak", Vector3(0, 0, -15))
	Sfx.quitting.emit()
	for layer: StringName in Music.players:
		assert_false(_player(layer).playing, "music " + layer)
	for layer: StringName in Ambience.players:
		assert_false((Ambience.players[layer] as AudioStreamPlayer).playing, "bed " + layer)
	for child in Ambience.get_children():
		assert_false(child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing, "one-shot")
	Music._quitting = false
	Ambience._quitting = false
	Ambience.reset()
	Ambience.enabled = false


func test_scene_kind_needs_the_guard_inside_the_scene() -> void:
	var scene := Node3D.new()
	add_child(scene)
	assert_eq(AudioContext.scene_kind(scene), AudioContext.OFF)
	var body := Node3D.new()
	body.add_to_group(&"player")
	scene.add_child(body)
	assert_eq(AudioContext.scene_kind(scene), AudioContext.GAME)
	assert_eq(AudioContext.scene_kind(null), AudioContext.OFF)


# --- the night in the lobby -------------------------------------------------

const STAGE := NightObjective.Stage


func test_the_power_cut_drops_the_walk_to_near_silence_then_brings_tension() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	Events.night_started.emit(2, &"none")
	Events.objective_changed.emit(STAGE.FUSES)
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	assert_almost_eq(Music.levels[&"explore"], 1.0, 0.001)
	Events.objective_changed.emit(STAGE.PULSING)
	Events.power_cut.emit()
	assert_eq(Music.state(), S.TENSION)
	_advance(Music.HUSH_FADE + 0.05)
	assert_almost_eq(Music.levels[&"explore"], MusicDirector.HUSH_LEVEL, 0.001, "near silence within HUSH_FADE s")
	assert_lt(_player(&"explore").volume_db, -20.0)
	assert_true(Music.is_family_playing(&"explore"), "hushed, not stopped: the stems stay in sync")
	_advance(MusicDirector.HUSH_TIME - Music.HUSH_FADE)
	assert_false(Music.director.hushed())
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	assert_almost_eq(Music.levels[&"explore"], 1.0, 0.001, "the walk is back")
	assert_almost_eq(Music.levels[&"explore_tension"], MusicDirector.POWER_TENSION, 0.001, "with the tension stem")
	Events.objective_changed.emit(STAGE.FLIGHT)
	_advance(Music.FADE_IN[&"explore_tension"] + 0.1)
	assert_almost_eq(Music.levels[&"explore_tension"], 1.0, 0.001, "the crystal flies: tension in full")


func test_the_witching_hour_keeps_its_layer_for_the_rest_of_the_night() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	Events.night_started.emit(2, &"none")
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	assert_almost_eq(Music.levels[&"explore_tension"], 0.0, 0.001)
	Events.witching_hour.emit()
	assert_eq(Music.state(), S.EXPLORE)
	_advance(Music.FADE_IN[&"explore_tension"] + 0.1)
	assert_almost_eq(Music.levels[&"explore_tension"], MusicDirector.WITCHING_TENSION, 0.001)
	Music.director.on_combat(MusicDirector.KILL_HEAT)
	_advance(MusicDirector.COMBAT_HOLD + MusicDirector.TENSION_HOLD + Music.FADE_OUT[&"explore_tension"] + 1.0)
	assert_eq(Music.state(), S.EXPLORE, "after a fight")
	assert_almost_eq(Music.levels[&"explore_tension"], MusicDirector.WITCHING_TENSION, 0.001, "the layer stays")


func test_dawn_fades_all_music_out_over_a_few_seconds() -> void:
	Music.set_scene_kind(AudioContext.GAME)
	Events.night_started.emit(2, &"full_moon")
	_advance(Music.FADE_IN[&"explore"] + 0.1)
	Events.dawn_broke.emit()
	assert_eq(Music.state(), S.SILENT)
	_advance(Music.DAWN_FADE * 0.5)
	assert_almost_eq(Music.levels[&"explore"], 0.5, 0.02, "slowly: half way after half the time")
	assert_true(Music.is_family_playing(&"explore"))
	_advance(Music.DAWN_FADE * 0.5 + 0.1)
	assert_false(Music.is_family_playing(&"explore"), "gone")
	for sting in Music.STINGS:
		assert_false((Music.stings[sting] as AudioStreamPlayer).playing, "no sting of its own: the dawn chime is Sfx's")


func test_night_events_are_ignored_when_disabled() -> void:
	Music.enabled = false
	Music.director.set_mode(AudioContext.GAME)
	Events.night_started.emit(1, &"calm")
	Events.power_cut.emit()
	Events.dawn_broke.emit()
	assert_eq(Music.state(), S.EXPLORE)
	assert_eq(Music.director.night.night, 0)
	assert_false(Music.director.hushed())


func test_a_scene_swap_forgets_a_night_it_did_not_announce() -> void:
	Events.night_started.emit(3, &"full_moon")
	Events.objective_changed.emit(STAGE.PULSING)
	Music._on_scene_changed()   # the running scene here is no game scene
	assert_eq(Music.director.night.night, 0)
	assert_false(Music.director.night.power_out())


class _FakeBoss:
	extends Node
	signal phase_changed(phase: int)
