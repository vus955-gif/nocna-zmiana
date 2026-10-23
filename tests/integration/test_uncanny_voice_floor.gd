extends TestCase
## The uncanny events' voice lines on the real Floor I (plan 2026-10-22-glos-g3):
## an event that brings a line needs a free voice, and firing it queues the
## line (time is not driven here: the queue is looked at, nothing plays).

const SEED := 7   # nights 2-4 without a modifier (no blackout: the lamps are on)

var museum: Museum
var director: UncannyDirector


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()
	VoiceDirector.enabled = false


## The museum is up with the voice off (no night-start lines); then the voice is switched on, clean.
func _start(night: int = 2) -> void:
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = night
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny
	VoiceDirector.enabled = true
	VoiceDirector.reset()


func _go(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


func _clear_exhibits() -> void:
	for exhibit in museum.exhibits():
		exhibit.free()


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director.advance(UncannyDirector.TICK)
		t += UncannyDirector.TICK


func test_an_event_with_a_line_of_its_own_waits_for_a_free_voice() -> void:
	await _start()
	director.phase = NightEscalation.Phase.UNEASY
	var entry := director.catalog.event(&"pa_click")
	assert_true(bool(entry.get("quiet_voice", false)))
	assert_true(director._may(entry), "the voice is free")
	VoiceDirector.queue.push(&"VO_TEST_WAITING", VoiceQueue.NORMAL)
	assert_false(director._may(entry), "a line waits for calm: the click would speak behind it")
	VoiceDirector.reset()
	assert_true(director._may(entry))
	VoiceDirector.queue.since_line = 0.0
	assert_false(director._may(entry), "20 s of quiet after a line are not over")
	VoiceDirector.queue.since_line = VoiceQueue.LINE_GAP
	assert_true(director._may(entry))


func test_an_event_without_the_flag_does_not_mind_the_voice() -> void:
	await _start()
	director.phase = NightEscalation.Phase.UNEASY
	var entry := director.catalog.event(&"far_thud")
	assert_false(entry.has("quiet_voice"))
	VoiceDirector.queue.push(&"VO_TEST_WAITING", VoiceQueue.NORMAL)
	assert_true(director._may(entry), "a waiting line changes nothing for an event that brings none")


func test_the_clicking_speaker_brings_the_closed_museum() -> void:
	await _start()
	_clear_exhibits()
	_go(&"court")
	var entry := director.catalog.event(&"pa_click")
	var target := director._target(entry, &"court")
	assert_false(target.is_empty(), "the court has speakers")
	director._fire(entry, target)
	assert_true(VoiceDirector.queue.has(&"VO_SYSTEM_PA_CLOSED"))
	assert_eq(VoiceDirector.catalog.channel_of(&"VO_SYSTEM_PA_CLOSED"), &"pa", "through the speakers")


func test_the_breath_on_the_channel_brings_the_wrong_voice() -> void:
	await _start()
	_clear_exhibits()
	_go(&"egypt_gallery")
	var entry := director.catalog.event(&"radio_breath")
	director._fire(entry, director._target(entry, &"egypt_gallery"))
	assert_true(VoiceDirector.queue.has(&"VO_HENIEK_RADIO_NOT_ME"))
	assert_eq(VoiceDirector.catalog.channel_of(&"VO_HENIEK_RADIO_NOT_ME"), &"radio", "on the walkie-talkie")


func test_the_lights_going_out_bring_the_announcement() -> void:
	await _start()
	_clear_exhibits()
	var entry := director.catalog.event(&"lamp_out")
	var target: Dictionary = {}
	var where: StringName = &""
	for room in museum.floor_level.layout.rooms:
		target = director._target(entry, room.id)
		if not target.is_empty():
			where = room.id
			break
	assert_false(target.is_empty(), "some hall has lamps and emergency lamps to put out")
	_go(where)
	director._fire(entry, target)
	assert_true(VoiceDirector.queue.has(&"VO_SYSTEM_LAMPS_OUT"))


func test_the_courts_eyes_bring_heniek_a_remark_not_a_second_warning_over_the_first() -> void:
	await _start(1)
	_clear_exhibits()
	_go(&"entrance_hall")
	_go(&"court")
	_run(15.0)
	assert_true(director.fired.has(&"court_eyes"))
	assert_true(VoiceDirector.queue.has(&"VO_HENIEK_EYES"), "queued behind whatever Heniek says about the court")
	assert_true(VoiceDirector.queue.has(&"VO_HENIEK_ZONE_COURT"), "his line about the court is in the queue too, first")
	var order: Array = VoiceDirector.queue.pending.map(func(r: Dictionary) -> StringName: return r.key)
	assert_true(order.find(&"VO_HENIEK_ZONE_COURT") < order.find(&"VO_HENIEK_EYES"), "the court first, then the eyes")
