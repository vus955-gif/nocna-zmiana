extends TestCase
## The voice director hears the night's curve and its uncanny events (plan
## 2026-10-21-eskalacja-nocy): G3 only adds lines - a rule names the phase
## or the event by "kind" (and the room by "room").


func before_each() -> void:
	VoiceDirector.enabled = true
	VoiceDirector.reset()


func after_each() -> void:
	VoiceDirector.enabled = false
	VoiceDirector.reset()


func test_the_events_are_ones_a_rule_may_name() -> void:
	for event in [&"night_phase_changed", &"uncanny_event"]:
		assert_true(event in VoiceCatalog.EVENTS, "%s is an event rules may name" % event)
		assert_true(Events.has_signal(event), "Events.%s exists" % event)


func test_a_rule_on_an_uncanny_event_queues_its_line() -> void:
	VoiceDirector.catalog.add_line(&"VO_TEST_CLOCKS", {"speaker": "heniek", "event": "uncanny_event", "kind": "clocks_backwards"})
	Events.uncanny_event.emit(&"lamp_blink", &"court")
	assert_false(VoiceDirector.queue.has(&"VO_TEST_CLOCKS"), "another event: nothing")
	Events.uncanny_event.emit(&"clocks_backwards", &"enlightenment_clocks")
	assert_true(VoiceDirector.queue.has(&"VO_TEST_CLOCKS"))


func test_a_rule_on_a_phase_queues_its_line() -> void:
	VoiceDirector.catalog.add_line(&"VO_TEST_DAWN_SOON", {"speaker": "system", "event": "night_phase_changed", "kind": "predawn"})
	Events.night_phase_changed.emit(NightEscalation.Phase.WITCHING)
	assert_false(VoiceDirector.queue.has(&"VO_TEST_DAWN_SOON"))
	Events.night_phase_changed.emit(NightEscalation.Phase.PREDAWN)
	assert_true(VoiceDirector.queue.has(&"VO_TEST_DAWN_SOON"))


# --- G3: the four uncanny events' lines (plan 2026-10-22-glos-g3) -----------------------

const MANIFEST := "res://assets/voice/manifest.json"
## Every recording ends with a stretch of silence (Kokoro's own, plus the tool's 0.12 s).
const QUIET_TAIL := 1.2
## event id -> [line key, speaker]
const G3 := {
	"lamp_out": ["VO_SYSTEM_LAMPS_OUT", "system"],
	"pa_click": ["VO_SYSTEM_PA_CLOSED", "system"],
	"radio_breath": ["VO_HENIEK_RADIO_NOT_ME", "heniek"],
	"court_eyes": ["VO_HENIEK_EYES", "heniek"],
}


func _seconds_of(key: String) -> float:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return float((manifest as Dictionary).get(key, {}).get("seconds", 0.0)) if manifest is Dictionary else 0.0


func test_the_four_events_have_their_lines_and_none_waits_for_g3_any_more() -> void:
	var uncanny := UncannyCatalog.load_default()
	var voice := VoiceCatalog.load_default()
	for id: String in G3:
		var key: String = G3[id][0]
		var entry := uncanny.event(StringName(id))
		assert_false(entry.is_empty(), id)
		assert_eq(entry.get("voice", ""), key, "%s points at its line" % id)
		var rule := voice.line(StringName(key))
		assert_eq(rule.get("event", ""), "uncanny_event", key)
		assert_eq(rule.get("kind", ""), id, "%s is the line of exactly this event" % key)
		assert_eq(rule.get("speaker", ""), G3[id][1], key)
	for entry in uncanny.events:
		assert_false(entry.has("g3"), "%s: no line still to record" % entry["id"])


func test_a_voice_link_to_a_line_of_the_event_names_the_event() -> void:
	var uncanny := UncannyCatalog.load_default()
	var voice := VoiceCatalog.load_default()
	for entry in uncanny.events:
		if not entry.has("voice"):
			continue
		var rule := voice.line(StringName(entry["voice"]))
		if rule.get("event", "") == "uncanny_event":
			assert_eq(rule.get("kind", ""), entry["id"], "%s: its line answers to it" % entry["id"])


func test_every_line_of_an_uncanny_event_is_queued_by_the_director() -> void:
	for id: String in G3:
		var key: String = G3[id][0]
		VoiceDirector.reset()
		Events.uncanny_event.emit(StringName(id), &"court")
		assert_true(VoiceDirector.queue.has(StringName(key)), "%s: queued by %s" % [key, id])
		assert_eq(VoiceDirector.queue.pending.size(), 1, "and nothing else")


func test_the_lines_are_heard_once_per_game() -> void:
	GameState.mark_voice_heard(&"VO_HENIEK_EYES")
	Events.uncanny_event.emit(&"court_eyes", &"court")
	assert_false(VoiceDirector.queue.has(&"VO_HENIEK_EYES"), "heard: never again")


func test_an_other_event_does_not_trigger_them() -> void:
	Events.uncanny_event.emit(&"lamp_blink", &"court")
	Events.uncanny_event.emit(&"painting_gaze", &"court")
	assert_true(VoiceDirector.queue.pending.is_empty())


func test_no_uncanny_line_cuts_into_a_fight() -> void:
	var voice := VoiceCatalog.load_default()
	for id: String in G3:
		var rule := voice.line(StringName(G3[id][0]))
		assert_lt(int(rule.get("priority", VoiceQueue.NORMAL)), VoiceQueue.EVENT, "%s: waits for calm, never over a fight" % G3[id][0])


func test_the_line_of_a_moment_is_dropped_when_the_moment_passes_and_the_event_needs_a_free_voice() -> void:
	var uncanny := UncannyCatalog.load_default()
	var voice := VoiceCatalog.load_default()
	for id: String in ["lamp_out", "pa_click", "radio_breath"]:
		var rule := voice.line(StringName(G3[id][0]))
		assert_gt(float(rule.get("expires", 0.0)), 0.0, "%s: expires" % G3[id][0])
		assert_true(float(rule.get("expires", 0.0)) <= 6.0, "%s: a few seconds, not a minute" % G3[id][0])
		assert_true(bool(uncanny.event(StringName(id)).get("quiet_voice", false)), "%s waits for a free voice" % id)
	var eyes := voice.line(&"VO_HENIEK_EYES")
	assert_false(eyes.has("expires"), "the court's remark is true whenever it comes")


func test_the_event_lasts_as_long_as_its_line() -> void:
	var uncanny := UncannyCatalog.load_default()
	var voice := VoiceCatalog.load_default()
	for id: String in ["lamp_out", "pa_click", "radio_breath"]:
		var entry := uncanny.event(StringName(id))
		var rule := voice.line(StringName(G3[id][0]))
		var delay := float(rule.get("delay", 0.0))
		var duration := float(entry.get("duration", 0.0))
		var seconds := _seconds_of(G3[id][0])
		assert_gt(seconds, 0.0, "%s has a recording" % G3[id][0])
		if StringName(entry["effect"]) == &"radio":
			# the channel is released (one click) before Heniek keys it again for the line
			assert_true(duration <= delay, "%s: its own click-out comes before the line starts" % id)
		else:
			# the speaker clicks off / the lamps come back once the speech is over, not before
			assert_true(duration >= delay + seconds - QUIET_TAIL, "%s: the moment covers the speech (%.1f s)" % [id, duration])
			assert_true(duration <= delay + seconds + 0.5, "%s: and does not outlast the line (%.1f s)" % [id, duration])


func test_the_not_heniek_is_the_radio_voice_made_wrong_and_the_other_is_him() -> void:
	var voice := VoiceCatalog.load_default()
	var wrong := voice.line(&"VO_HENIEK_RADIO_NOT_ME")
	var right := voice.line(&"VO_HENIEK_EYES")
	assert_eq(wrong.speaker, "heniek", "same speaker label, same radio bus: the player cannot tell")
	assert_eq(voice.channel_of(&"VO_HENIEK_RADIO_NOT_ME"), &"radio")
	assert_eq(int(wrong.get("level", 0)), 1, "the pipeline's machine intonation, not the System's broken one")
	assert_lt(float(wrong.get("speed", 1.0)), 1.0, "a little slower")
	assert_eq(int(right.get("level", 0)), 0, "the court's warning is plain Heniek")
	for key in ["VO_SYSTEM_LAMPS_OUT", "VO_SYSTEM_PA_CLOSED"]:
		assert_eq(int(voice.line(StringName(key)).level), 2, key + ": the System's everyday level")
	assert_lt(float(voice.line(&"VO_SYSTEM_PA_CLOSED").speed), float(voice.speakers["system"].speed), "the broken closing is slower than the System's usual")
