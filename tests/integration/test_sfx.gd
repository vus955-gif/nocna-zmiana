extends TestCase
## Sound service: bus routing, voice limits and hearing range.


func before_each() -> void:
	Sfx.stop_all()


func _last_voice() -> Node:
	return Sfx.get_child(Sfx.get_child_count() - 1)


func _sound_of(voice: Node) -> String:
	var stream: AudioStream = voice.get(&"stream")
	return stream.resource_path.get_file().get_basename()


func test_master_bus_has_one_limiter_and_sfx_bus_feeds_it() -> void:
	var limiters := 0
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			limiters += 1
	assert_eq(limiters, 1, "limiters on Master")
	var sfx := AudioServer.get_bus_index(&"SFX")
	assert_gt(sfx, 0, "SFX bus exists")
	if sfx > 0:
		assert_eq(AudioServer.get_bus_send(sfx), &"Master")
		assert_lt(AudioServer.get_bus_volume_db(sfx), 0.0, "SFX leaves headroom")
	for bus in [&"Music", &"Ambience", &"UI"]:
		assert_gt(AudioServer.get_bus_index(bus), 0, "bus " + bus)


func test_sounds_play_on_the_sfx_bus_and_never_boost() -> void:
	Sfx.play(&"pistol")
	var flat := _last_voice() as AudioStreamPlayer
	Sfx.play_at(&"block", Vector3.ZERO)
	var spatial := _last_voice() as AudioStreamPlayer3D
	assert_not_null(flat)
	assert_not_null(spatial)
	if flat != null:
		assert_eq(flat.bus, &"SFX")
	if spatial != null:
		assert_eq(spatial.bus, &"SFX")
		assert_eq(spatial.max_db, 0.0)


func test_full_voice_pool_steals_the_oldest_voice() -> void:
	for i in Sfx.MAX_VOICES:
		Sfx.play(Sfx.SOUNDS[i % Sfx.SOUNDS.size()])
	assert_eq(Sfx.get_child_count(), Sfx.MAX_VOICES)
	var oldest := Sfx.get_child(0)
	Sfx.play(&"kill")
	assert_eq(Sfx.get_child_count(), Sfx.MAX_VOICES)
	assert_eq(_sound_of(_last_voice()), "kill", "the newest sound plays")
	assert_true(oldest.get_parent() == null, "the oldest voice was stopped")


func test_one_sound_keeps_at_most_a_few_copies() -> void:
	var voices: Array[Node] = []
	for i in Sfx.MAX_COPIES + 2:
		Sfx.play_at(&"punch", Vector3.ZERO)
		voices.append(_last_voice())
	assert_eq(Sfx.get_child_count(), Sfx.MAX_COPIES)
	assert_eq(voices.back().get_parent(), Sfx, "newest copy kept")
	assert_true(voices.front().get_parent() == null, "oldest copy stolen")


## A pack of four raptors hisses all at once: four copies may play.
func test_a_whole_pack_hisses_together() -> void:
	assert_eq(Sfx.max_copies(&"raptor_hiss"), 4)
	for i in 4:
		Sfx.play_at(&"raptor_hiss", Vector3(i, 0, 0))
	assert_eq(Sfx.get_child_count(), 4, "every raptor heard")
	Sfx.play_at(&"raptor_hiss", Vector3.ZERO)
	assert_eq(Sfx.get_child_count(), 4, "a fifth takes the oldest one's place")


func test_positional_sounds_beyond_hearing_range_are_skipped() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	Sfx.play_at(&"block", Vector3(0, 0, -100))
	assert_eq(Sfx.get_child_count(), 0, "too far to hear")
	Sfx.play_at(&"block", Vector3(0, 0, -20))
	assert_eq(Sfx.get_child_count(), 1, "close enough")


func test_every_sound_is_loaded_up_front() -> void:
	for sound in Sfx.SOUNDS:
		assert_true(ResourceLoader.has_cached("res://assets/sfx/%s.wav" % sound), "not loaded: " + sound)


func test_nothing_plays_while_quitting() -> void:
	Sfx._quitting = true
	Sfx.play(&"pistol")
	Sfx.play_at(&"block", Vector3.ZERO)
	Sfx._quitting = false
	assert_eq(Sfx.get_child_count(), 0)


func test_ui_sounds_play_on_the_ui_bus_even_when_paused() -> void:
	get_tree().paused = true
	Sfx.play_ui(&"ui_confirm")
	var voice := _last_voice() as AudioStreamPlayer
	assert_not_null(voice)
	if voice != null:
		assert_eq(voice.bus, &"UI")
		assert_eq(voice.process_mode, Node.PROCESS_MODE_ALWAYS)
		assert_true(voice.can_process(), "plays during the pause")
	get_tree().paused = false


func test_game_sounds_pause_with_the_game() -> void:
	Sfx.play(&"pistol")
	var voice := _last_voice()
	get_tree().paused = true
	assert_false(voice.can_process())
	get_tree().paused = false


func test_the_gatlings_loops_stop_when_the_game_quits() -> void:
	var view := GatlingView.new()
	add_child(view)
	var driver: GatlingDriver = view._driver
	var spin: AudioStreamPlayer = driver._spin_player
	var rattle: AudioStreamPlayer = driver._rattle_player
	spin.play()
	rattle.play()
	Sfx.quitting.emit()
	assert_false(spin.playing, "the whir")
	assert_false(rattle.playing, "the rattle")
	var state := WeaponState.new(load("res://src/weapons/data/gatling.tres") as WeaponData)
	state.spin = 1.0
	driver._update_sound(state, 1.0)
	assert_false(spin.playing, "a turning barrel does not start it again")
	Music._quitting = false
	Ambience._quitting = false


func test_stop_gameplay_keeps_menu_sounds() -> void:
	Sfx.play(&"pistol")
	Sfx.play_ui(&"ui_back")
	Sfx.stop_gameplay()
	assert_eq(Sfx.get_child_count(), 1)
	assert_eq(_sound_of(_last_voice()), "ui_back")
