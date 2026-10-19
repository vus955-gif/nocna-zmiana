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


## A death comment of [param speaker] waits in the queue (or is on air).
func _death_queued(speaker: String) -> bool:
	for key in VoiceDirector.catalog.keys_for_event(&"death"):
		if String(VoiceDirector.catalog.speaker_of(key)) == speaker and VoiceDirector.queue.has(key):
			return true
	return false


func test_a_death_is_commented_by_turns_once_a_night() -> void:
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_true(_death_queued("heniek"), "Heniek's turn first")
	assert_false(_death_queued("system"))
	assert_eq(GameState.voice_state.get("death_turn"), "system")
	assert_eq(GameState.voice_state.get("death_night"), 2)
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_false(_death_queued("system"), "at most one comment per night")
	Events.player_died.emit()
	Events.night_started.emit(3, &"")
	assert_true(_death_queued("system"), "the System's turn")
	assert_eq(GameState.voice_state.get("death_turn"), "heniek")


func test_a_speaker_out_of_death_lines_passes_the_turn() -> void:
	for key in VoiceDirector.catalog.keys_for_event(&"death"):
		if String(VoiceDirector.catalog.speaker_of(key)) == "heniek":
			GameState.mark_voice_heard(key)
	Events.player_died.emit()
	Events.night_started.emit(2, &"")
	assert_true(_death_queued("system"), "Heniek has nothing left: the System speaks")
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


func test_the_cafe_events_queue_their_lines() -> void:
	_inject(&"VO_TEST_CAFE_IN", {"speaker": "heniek", "event": "cafe_entered"})
	_inject(&"VO_TEST_CAFE_WILD", {"speaker": "heniek", "event": "cafe_haywire"})
	Events.cafe_entered.emit()
	assert_true(VoiceDirector.queue.has(&"VO_TEST_CAFE_IN"), "stepping behind the counter")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_CAFE_WILD"))
	Events.cafe_haywire.emit()
	assert_true(VoiceDirector.queue.has(&"VO_TEST_CAFE_WILD"), "the machine gone haywire")


func test_a_coffee_line_waits_for_its_kind() -> void:
	_inject(&"VO_TEST_ESPRESSO", {"speaker": "heniek", "event": "coffee_drunk", "kind": "espresso"})
	_inject(&"VO_TEST_LARGE", {"speaker": "heniek", "event": "coffee_drunk", "kind": "large"})
	_inject(&"VO_TEST_ANY_COFFEE", {"speaker": "heniek", "event": "coffee_drunk"})
	Events.coffee_drunk.emit(&"large")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_LARGE"))
	assert_true(VoiceDirector.queue.has(&"VO_TEST_ANY_COFFEE"), "a rule without a kind fits every cup")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_ESPRESSO"), "the espresso line stays out")
	VoiceDirector.queue.clear()
	Events.coffee_drunk.emit(&"espresso")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_ESPRESSO"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_LARGE"))
	VoiceDirector.queue.clear()
	Events.coffee_drunk.emit(&"special")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_ESPRESSO"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_LARGE"))
	assert_true(VoiceDirector.queue.has(&"VO_TEST_ANY_COFFEE"))


func test_injected_lines_do_not_outlive_a_reset() -> void:
	_inject(&"VO_TEST_GONE", {"speaker": "heniek", "event": "power_cut"})
	VoiceDirector.reset()
	assert_false(VoiceDirector.catalog.lines.has("VO_TEST_GONE"))


# --- G2: the payloads of the new events (plan 2026-10-19-glos-g2-kwestie) -------

func test_the_nights_modifier_selects_its_line() -> void:
	_inject(&"VO_TEST_MOON", {"speaker": "heniek", "event": "night_started", "modifier": "full_moon"})
	Events.night_started.emit(2, &"blackout")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_MOON"))
	Events.night_started.emit(2, &"full_moon")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_MOON"))


func test_a_room_and_a_haven_select_their_lines() -> void:
	_inject(&"VO_TEST_READING", {"speaker": "heniek", "event": "room_entered", "room": "court_reading"})
	_inject(&"VO_TEST_HAVEN", {"speaker": "heniek", "event": "room_entered", "kind": "haven"})
	Events.room_entered.emit(&"court_south", &"court", true)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_READING"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_HAVEN"))
	Events.room_entered.emit(&"court_reading", &"court", true)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_READING"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_HAVEN"))
	Events.room_entered.emit(&"egypt_conservator", &"egypt", true)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_HAVEN"), "the conservator's room is a haven")


func test_a_gate_selects_its_line() -> void:
	_inject(&"VO_TEST_GATE", {"speaker": "system", "event": "gate_opened", "gate": "seal_khorsabad"})
	Events.gate_opened.emit(&"bolt_greece_entrance")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_GATE"))
	Events.gate_opened.emit(&"seal_khorsabad")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_GATE"))


func test_a_secret_is_told_by_its_tier_and_its_count() -> void:
	_inject(&"VO_TEST_GREAT", {"speaker": "system", "event": "secret_found", "kind": "great"})
	_inject(&"VO_TEST_FIRST", {"speaker": "heniek", "event": "secret_found", "count": 1})
	Events.secret_found.emit(&"secret_court_1", SecretRewards.Tier.SMALL, 1)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_FIRST"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_GREAT"))
	VoiceDirector.queue.clear()
	Events.secret_found.emit(&"secret_egypt_3", SecretRewards.Tier.GREAT, 2)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_GREAT"))
	assert_false(VoiceDirector.queue.has(&"VO_TEST_FIRST"))


func test_tiredness_and_the_hour_select_their_lines() -> void:
	_inject(&"VO_TEST_TIRED", {"speaker": "heniek", "event": "fatigue_rose", "count": 1})
	_inject(&"VO_TEST_FOUR", {"speaker": "system", "event": "hour_struck", "hour": 4})
	Events.fatigue_rose.emit(2)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_TIRED"))
	Events.fatigue_rose.emit(1)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_TIRED"))
	Events.hour_struck.emit(1)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_FOUR"))
	Events.hour_struck.emit(4)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_FOUR"))


func test_standing_still_is_noticed_once_a_night() -> void:
	_inject(&"VO_TEST_IDLE", {"speaker": "system", "event": "idle", "once": false})
	var started := watch(VoiceDirector.line_started)
	# queued or already said (the injected line has no recording: 1.5 s on air)
	var noticed := func() -> int:
		var said := started.filter(func(e: Array) -> bool: return e[0] == &"VO_TEST_IDLE").size()
		return said + (1 if VoiceDirector.queue.has(&"VO_TEST_IDLE") and said == 0 else 0)
	Events.night_started.emit(1, &"")
	_advance(VoiceDirector.IDLE_TIME - 5.0)
	camera.global_position = Vector3(3, 0, 0)   # a few steps: the count starts again
	_advance(VoiceDirector.IDLE_TIME - 5.0)
	assert_eq(noticed.call(), 0, "he moved in between")
	_advance(10.0)
	assert_eq(noticed.call(), 1, "two minutes on one spot")
	_advance(VoiceDirector.IDLE_TIME + 30.0)
	assert_eq(noticed.call(), 1, "once a night")


func test_standing_still_in_a_haven_is_not_noticed() -> void:
	_inject(&"VO_TEST_IDLE", {"speaker": "system", "event": "idle", "once": false})
	var started := watch(VoiceDirector.line_started)
	var noticed := func() -> int:
		var said := started.filter(func(e: Array) -> bool: return e[0] == &"VO_TEST_IDLE").size()
		return said + (1 if VoiceDirector.queue.has(&"VO_TEST_IDLE") and said == 0 else 0)
	var haven := Haven.make(&"booth", AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4)))
	add_child(haven)   # the camera stands inside it, at the origin
	Events.night_started.emit(1, &"")
	_advance(VoiceDirector.IDLE_TIME + 30.0)
	assert_eq(noticed.call(), 0, "two minutes in a refuge are not noticed")
	haven.set_active(false)   # out of the refuge: the count starts now
	_advance(VoiceDirector.IDLE_TIME - 5.0)
	assert_eq(noticed.call(), 0, "the count starts outside")
	_advance(10.0)
	assert_eq(noticed.call(), 1, "two minutes outside")


func test_dawn_speaks_at_once_over_what_was_on_air() -> void:
	_inject(&"VO_TEST_DAWN", {"speaker": "heniek", "event": "dawn_broke", "priority": 2})
	Events.night_started.emit(1, &"")
	_advance(5.0)
	assert_eq(VoiceDirector.current_line(), &"VO_HENIEK_NIGHT_1")
	Events.dawn_broke.emit()
	_advance(0.2)
	var now := VoiceDirector.current_line()
	assert_eq(VoiceDirector.catalog.line(now).get("event", ""), "dawn_broke", "no wait for calm or a gap: %s" % now)
	assert_false(GameState.voice_heard.has(&"VO_HENIEK_NIGHT_1"), "the cut line stays unheard")


func test_a_stray_hit_after_dawn_does_not_hold_the_dawn_line_back() -> void:
	_inject(&"VO_TEST_DAWN", {"speaker": "heniek", "event": "dawn_broke", "priority": 2})
	Events.night_started.emit(1, &"")
	_advance(5.0)
	Events.dawn_broke.emit()
	Events.player_damaged.emit(10.0, Vector3.ZERO)
	_advance(0.2)
	var now := VoiceDirector.current_line()
	assert_eq(VoiceDirector.catalog.line(now).get("event", ""), "dawn_broke", "still on air at once, no calm to wait for: %s" % now)
