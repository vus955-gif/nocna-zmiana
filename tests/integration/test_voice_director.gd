extends TestCase
## The director with the real catalog (data/voice) and the real recordings.
## Time is driven by VoiceDirector.advance(); the audio driver is a dummy.

var camera: Camera3D


func before_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true


func after_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = false


func _advance(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		VoiceDirector.advance(0.1)
		t += 0.1


func test_the_first_night_starts_with_heniek_on_the_radio() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_eq(started.size(), 1)
	assert_eq(started[0][0], &"VO_HENIEK_NIGHT_1")
	assert_eq(started[0][1], &"radio")
	assert_gt(started[0][2], 10.0, "the recording's length")


func test_a_line_is_heard_once_per_game() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0 + VoiceDirector.catalog.stream(&"VO_HENIEK_NIGHT_1").get_length() + 1.0)
	assert_true(GameState.voice_heard.has(&"VO_HENIEK_NIGHT_1"))
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(10.0)
	for entry in started:
		assert_ne(entry[0], &"VO_HENIEK_NIGHT_1", "not again")


func test_the_system_closes_the_museum_after_heniek() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(80.0)
	var keys := started.map(func(e: Array) -> StringName: return e[0])
	assert_eq(keys, [&"VO_HENIEK_NIGHT_1", &"VO_SYSTEM_CLOSING_1"])
	assert_eq(started[1][1], &"pa")


func test_music_ducks_under_a_line_and_comes_back() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_almost_eq(VoiceDirector.duck_effect(&"Music").volume_db, VoiceDirector.DUCK_MUSIC_DB, 0.01)
	assert_almost_eq(VoiceDirector.duck_effect(&"Ambience").volume_db, VoiceDirector.DUCK_AMBIENCE_DB, 0.01)
	_advance(VoiceDirector.catalog.stream(&"VO_HENIEK_NIGHT_1").get_length() + 2.0)
	assert_almost_eq(VoiceDirector.duck_effect(&"Music").volume_db, 0.0, 0.001)
	assert_almost_eq(VoiceDirector.duck_effect(&"Ambience").volume_db, 0.0, 0.001)


func test_the_guide_plays_the_day_recording_then_the_night_one() -> void:
	var stand := Node3D.new()
	add_child(stand)
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"VO_GUIDE_ROSETTA_A")
	assert_eq(VoiceDirector.current_line(), &"VO_GUIDE_ROSETTA_A")
	VoiceDirector.stop_line()
	GameState.defeat_guardian(&"colossus")
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"VO_GUIDE_ROSETTA_B")


func test_a_second_press_stops_the_guide() -> void:
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	assert_eq(VoiceDirector.play_guide(&"rosetta", stand), &"")
	assert_eq(VoiceDirector.current_line(), &"")


func test_the_guide_cuts_heniek_who_comes_back_later() -> void:
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(5.0)
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	assert_false(GameState.voice_heard.has(&"VO_HENIEK_NIGHT_1"), "cut lines stay unheard")
	_advance(VoiceDirector.catalog.stream(&"VO_GUIDE_ROSETTA_A").get_length() + 25.0)
	assert_eq(started.filter(func(e: Array) -> bool: return e[0] == &"VO_HENIEK_NIGHT_1").size(), 2, "Heniek again from the start")


func test_walking_away_stops_the_guide() -> void:
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	camera.global_position = Vector3(0, 0, VoiceDirector.GUIDE_RANGE + 2.0)
	_advance(0.2)
	assert_eq(VoiceDirector.current_line(), &"")


func test_a_death_is_commented_at_the_next_night_by_turns() -> void:
	# needs a death line per speaker in data — skip quietly until G2 adds them
	if VoiceDirector.catalog.keys_for_event(&"death").is_empty():
		return
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	_advance(5.0)
	assert_eq(GameState.voice_state.get("death_turn"), "system")
	assert_eq(GameState.voice_state.get("death_night"), 2)


func test_destroyed_exhibits_are_counted() -> void:
	for i in 3:
		Events.enemy_destroyed.emit(null, DamageInfo.new(), false)
	assert_eq(GameState.voice_state.get("destroyed"), 3)


func test_a_stall_asks_for_a_hint_only_after_a_long_quiet() -> void:
	var queued := 0
	Events.night_started.emit(1, &"")
	_advance(VoiceDirector.STALL_TIME - 1.0)
	queued = VoiceDirector.stall_nudges
	assert_eq(queued, 0, "no nudge before the stall time")
	_advance(2.0)
	assert_eq(VoiceDirector.stall_nudges, 1)
	_advance(VoiceDirector.STALL_GAP - 10.0)
	assert_eq(VoiceDirector.stall_nudges, 1, "at most one nudge per gap")


func test_pause_freezes_the_line() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	var left := VoiceDirector.line_left()
	assert_gt(left, 0.0)
	get_tree().paused = true
	await physics_frames(30)
	get_tree().paused = false
	assert_almost_eq(VoiceDirector.line_left(), left, 0.001)


func test_disabled_director_stays_quiet() -> void:
	VoiceDirector.enabled = false
	var started := watch(VoiceDirector.line_started)
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_eq(started.size(), 0)


# --- lines injected into the catalog: the rules the shipped data does not use yet ----

func _inject(key: StringName, rule: Dictionary) -> void:
	VoiceDirector.catalog.add_line(key, rule)


func test_leaving_the_game_scene_silences_and_forgets_the_night() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_ne(VoiceDirector.current_line(), &"")
	VoiceDirector._on_scene_changed()   # the running scene here is no game scene
	assert_eq(VoiceDirector.current_line(), &"")
	assert_false(VoiceDirector.queue.has(&"VO_SYSTEM_CLOSING_1"), "the queue is cleared")
	_inject(&"VO_TEST_TIME", {"speaker": "system", "event": "night_time", "at": 1.0})
	_advance(3.0)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_TIME"), "no night runs after the scene change")


func test_hitstop_does_not_slow_the_director() -> void:
	Events.night_started.emit(1, &"")
	_advance(5.0)
	var left := VoiceDirector.line_left()
	Engine.time_scale = 0.25
	await physics_frames(12)
	Engine.time_scale = 1.0
	# a dozen frames (the runner fits 12-15 process frames round 12 physics frames) of REAL time,
	# not the scaled 0.05-0.06 s
	var elapsed := left - VoiceDirector.line_left()
	assert_true(elapsed > 0.15 and elapsed < 0.35, "real time: %.3f s" % elapsed)


func test_a_cut_radio_line_does_not_play_under_the_guide() -> void:
	Events.night_started.emit(1, &"")
	_advance(4.1)   # Heniek started, the click is still playing
	assert_eq(VoiceDirector.current_line(), &"VO_HENIEK_NIGHT_1")
	var stand := Node3D.new()
	add_child(stand)
	VoiceDirector.play_guide(&"rosetta", stand)
	_advance(0.5)
	assert_false(VoiceDirector._radio.playing, "the cut line's radio stays quiet")
	assert_eq(VoiceDirector.current_line(), &"VO_GUIDE_ROSETTA_A")


func test_a_death_is_commented_by_turns_with_injected_lines() -> void:
	_inject(&"VO_TEST_DEATH_H", {"speaker": "heniek", "event": "death"})
	_inject(&"VO_TEST_DEATH_S", {"speaker": "system", "event": "death"})
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_DEATH_H"), "Heniek's turn first")
	assert_eq(GameState.voice_state.get("death_turn"), "system")
	assert_eq(GameState.voice_state.get("death_night"), 2)
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_DEATH_S"), "at most one comment per night")
	Events.player_died.emit()
	Events.night_started.emit(3, &"")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_DEATH_S"), "the System's turn")
	assert_eq(GameState.voice_state.get("death_turn"), "heniek")


func test_a_speaker_out_of_death_lines_passes_the_turn() -> void:
	_inject(&"VO_TEST_DEATH_H", {"speaker": "heniek", "event": "death"})
	_inject(&"VO_TEST_DEATH_S", {"speaker": "system", "event": "death"})
	GameState.mark_voice_heard(&"VO_TEST_DEATH_H")
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_DEATH_S"), "Heniek has nothing left: the System speaks")
	assert_eq(GameState.voice_state.get("death_turn"), "heniek")


func test_a_night_time_line_fires_at_its_second_once_per_night() -> void:
	_inject(&"VO_TEST_TIME", {"speaker": "system", "event": "night_time", "at": 30.0, "night_min": 1})
	Events.night_started.emit(1, &"")
	_advance(29.0)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_TIME"))
	_advance(2.0)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_TIME"))
	VoiceDirector.queue.clear()
	_advance(5.0)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_TIME"), "fired once this night")


func test_a_destroyed_threshold_fires_on_the_count() -> void:
	_inject(&"VO_TEST_LOSSES_3", {"speaker": "system", "event": "destroyed", "count": 3})
	for i in 2:
		Events.enemy_destroyed.emit(null, DamageInfo.new(), false)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_LOSSES_3"))
	Events.enemy_destroyed.emit(null, DamageInfo.new(), false)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_LOSSES_3"))


func test_a_stall_nudge_fits_the_current_goal() -> void:
	_inject(&"VO_TEST_STALL_X", {"speaker": "heniek", "event": "stall", "goal": "GOAL_X"})
	_inject(&"VO_TEST_STALL_Y", {"speaker": "heniek", "event": "stall", "goal": "GOAL_Y"})
	Events.night_started.emit(1, &"")
	Events.goal_changed.emit(&"GOAL_X")
	_advance(VoiceDirector.STALL_TIME + 1.0)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_STALL_X"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_STALL_Y"))


func test_room_and_guardian_payloads_select_the_lines() -> void:
	_inject(&"VO_TEST_EGYPT", {"speaker": "heniek", "event": "room_entered", "zone": "egypt"})
	_inject(&"VO_TEST_COLOSSUS", {"speaker": "heniek", "event": "guardian_awakened", "guardian": "colossus"})
	Events.room_entered.emit(&"egypt_vestibule", &"egypt", false)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_EGYPT"), "only the first visit")
	Events.room_entered.emit(&"assyria_hall", &"assyria", true)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_EGYPT"))
	Events.room_entered.emit(&"egypt_vestibule", &"egypt", true)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_EGYPT"))
	Events.guardian_awakened.emit(null, &"centaur")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_COLOSSUS"))
	Events.guardian_awakened.emit(null, &"colossus")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_COLOSSUS"))


func test_injected_lines_do_not_outlive_a_reset() -> void:
	_inject(&"VO_TEST_GONE", {"speaker": "heniek", "event": "power_cut"})
	VoiceDirector.reset()
	assert_false(VoiceDirector.catalog.lines.has("VO_TEST_GONE"))
