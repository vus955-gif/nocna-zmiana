extends TestCase
## The content pass's sounds: registered, generated, and the two gatling
## loops really loop (the import sets loop_mode forward).

const LOOPS: Array[StringName] = [&"gatling_spin", &"gatling_rattle"]


func test_loops_are_imported_as_forward_loops() -> void:
	for sound in LOOPS:
		var stream := load("res://assets/sfx/%s.wav" % sound) as AudioStreamWAV
		assert_not_null(stream, str(sound))
		if stream != null:
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, str(sound))


func test_one_shots_do_not_loop() -> void:
	for sound in [&"gatling_crank", &"gatling_stop", &"flare_fire", &"heartbeat"]:
		var stream := load("res://assets/sfx/%s.wav" % sound) as AudioStreamWAV
		assert_not_null(stream, str(sound))
		if stream != null:
			assert_ne(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, str(sound))


func test_rattle_loop_is_one_second_of_fourteen_rounds() -> void:
	var stream := load("res://assets/sfx/gatling_rattle.wav") as AudioStream
	assert_almost_eq(stream.get_length(), 1.0, 0.01)
