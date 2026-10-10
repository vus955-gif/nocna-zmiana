extends TestCase

var queue: VoiceQueue


func before_each() -> void:
	queue = VoiceQueue.new()


func _run(seconds: float, calm := true) -> Array[StringName]:
	var started: Array[StringName] = []
	var t := 0.0
	while t < seconds:
		var key := queue.advance(0.1, calm)
		if key != &"":
			started.append(key)
		t += 0.1
	return started


func test_a_line_waits_for_calm_then_starts() -> void:
	queue.push(&"A", VoiceQueue.NORMAL)
	assert_eq(_run(3.0), [] as Array[StringName], "not before 4 s of calm")
	assert_eq(_run(1.5), [&"A"] as Array[StringName])


func test_one_voice_at_a_time_and_a_gap_after_each_line() -> void:
	queue.push(&"A", VoiceQueue.EVENT)
	queue.push(&"B", VoiceQueue.EVENT)
	assert_eq(_run(5.0), [&"A"] as Array[StringName])
	assert_eq(_run(30.0), [] as Array[StringName], "A is still on air")
	queue.finished()
	assert_eq(_run(19.0), [] as Array[StringName], "20 s of quiet after a line")
	assert_eq(_run(2.0), [&"B"] as Array[StringName])


func test_the_higher_priority_goes_first() -> void:
	queue.push(&"side", VoiceQueue.SIDE)
	queue.push(&"event", VoiceQueue.EVENT)
	assert_eq(_run(5.0), [&"event"] as Array[StringName])


func test_an_event_line_stops_waiting_for_calm_after_10_s() -> void:
	queue.push(&"E", VoiceQueue.EVENT)
	assert_eq(_run(9.5, false), [] as Array[StringName])
	assert_eq(_run(1.0, false), [&"E"] as Array[StringName])


func test_a_side_remark_that_waited_a_minute_is_dropped() -> void:
	queue.push(&"S", VoiceQueue.SIDE)
	_run(61.0, false)
	assert_false(queue.has(&"S"))


func test_side_remarks_are_three_minutes_apart() -> void:
	queue.push(&"S1", VoiceQueue.SIDE)
	assert_eq(_run(5.0), [&"S1"] as Array[StringName])
	queue.finished()
	queue.push(&"S2", VoiceQueue.SIDE)
	assert_eq(_run(55.0), [] as Array[StringName], "still inside the 180 s gap")
	assert_true(queue.has(&"S2"))
	_run(10.0)
	assert_false(queue.has(&"S2"), "it waited more than a minute behind the gap: dropped")


func test_a_delay_holds_a_line_back() -> void:
	queue.push(&"D", VoiceQueue.NORMAL, 20.0)
	assert_eq(_run(19.0), [] as Array[StringName])
	assert_eq(_run(5.0), [&"D"] as Array[StringName])


func test_duplicates_are_ignored() -> void:
	assert_true(queue.push(&"A", VoiceQueue.NORMAL))
	assert_false(queue.push(&"A", VoiceQueue.NORMAL))


func test_an_interrupted_line_comes_back_first() -> void:
	queue.push(&"A", VoiceQueue.EVENT)
	queue.push(&"B", VoiceQueue.EVENT)
	_run(5.0)
	assert_eq(queue.interrupt(), &"A")
	queue.hold(&"guide")
	assert_true(queue.is_speaking())
	queue.finished()
	assert_eq(_run(25.0), [&"A"] as Array[StringName])


func test_clear_forgets_everything() -> void:
	queue.push(&"A", VoiceQueue.EVENT)
	_run(5.0)
	assert_true(queue.is_speaking())
	queue.clear()
	assert_false(queue.is_speaking() or queue.has(&"A"))


func test_rules_match_their_conditions() -> void:
	assert_true(VoiceRules.matches({"night": 1}, {"night": 1}))
	assert_false(VoiceRules.matches({"night": 1}, {"night": 2}))
	assert_true(VoiceRules.matches({"night_min": 2}, {"night": 3}))
	assert_false(VoiceRules.matches({"night_min": 2}, {"night": 1}))
	assert_true(VoiceRules.matches({"zone": "egypt"}, {"zone": &"egypt"}))
	assert_false(VoiceRules.matches({"guardian": "colossus"}, {"guardian": &"centaur"}))
	assert_true(VoiceRules.matches({"count": 3}, {"count": 3}))
	assert_false(VoiceRules.matches({"goal": "GOAL_A"}, {"goal": &"GOAL_B"}))
	assert_false(VoiceRules.matches({"speaker": "system"}, {"speaker": &"heniek"}))
	assert_true(VoiceRules.matches({"speaker": "heniek", "night": 2}, {"night": 2}), "no speaker in payload: any")
