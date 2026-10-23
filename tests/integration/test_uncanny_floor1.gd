extends TestCase
## The night's escalation on the real Floor I (plan
## 2026-10-21-eskalacja-nocy, task 6): the director follows the clock's
## phases, plays its ambient events only in a quiet moment and as often as
## the curve says, and the rooms' own moments once (a night, or a game).

const SEED := 7   # nights 2-4 without a modifier (no blackout: the lamps are on)

var museum: Museum
var director: UncannyDirector


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _start(night: int = 2) -> void:
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = night
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny


## The guard stands in the middle of [param room] (the tracker told).
func _go(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


func _clear_exhibits() -> void:
	for exhibit in museum.exhibits():
		exhibit.free()


func _hour(hours_after_23: float) -> void:
	museum.watch.clock.elapsed = hours_after_23 * NightClock.SECONDS_PER_HOUR
	director.advance(UncannyDirector.TICK)


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director.advance(UncannyDirector.TICK)
		t += UncannyDirector.TICK


func test_the_director_follows_the_clocks_phases() -> void:
	var phases := watch(Events.night_phase_changed)
	await _start()
	assert_not_null(director, "Floor I has its director")
	assert_eq(phases.size(), 1, "the night's phase is announced at its start")
	assert_eq(phases[0][0], NightEscalation.Phase.CALM)
	_hour(2.5)
	assert_eq(phases[-1][0], NightEscalation.Phase.UNEASY, "1:30")
	_hour(4.0)
	assert_eq(phases[-1][0], NightEscalation.Phase.WITCHING, "3:00")
	_hour(6.5)
	assert_eq(director.phase, NightEscalation.Phase.PREDAWN, "5:30")
	assert_eq(phases.size(), 4, "each change once")


func test_an_ambient_event_comes_in_a_quiet_moment_and_the_next_when_the_curve_says() -> void:
	await _start()
	_clear_exhibits()
	_go(&"egypt_gallery")
	_hour(4.5)
	var events := watch(Events.uncanny_event)
	var ambient: Array[StringName] = []
	for attempt in 8:
		director._next_ambient = director._time
		_run(UncannyDirector.MIN_GAP + 0.5)
		ambient.assign(director.fired.filter(func(id: StringName) -> bool: return director.catalog.event(id)["trigger"] == "ambient"))
		if not ambient.is_empty():
			break
	assert_false(ambient.is_empty(), "something uncanny happened")
	var first := director.catalog.event(ambient[0])
	assert_gt(UncannyRules.weight(first, NightEscalation.Phase.WITCHING), 0.0, "one of the witching hour's")
	assert_eq(events.size(), director.fired.size(), "announced")
	var low := NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, museum.night.modifier, 0.0)
	var high := NightEscalation.gap(NightEscalation.Phase.WITCHING, 2, museum.night.modifier, 1.0)
	var wait := director.next_in()
	assert_true(wait >= low - UncannyDirector.MIN_GAP - 1.0 and wait <= high + 0.01, "the next comes after the curve's gap (%.1f in %.0f..%.0f)" % [wait, low, high])


func test_nothing_happens_in_a_haven() -> void:
	await _start()
	_clear_exhibits()
	assert_true(Haven.shelters(museum.player.global_position), "the night starts in the booth")
	director._next_ambient = 0.0
	_run(30.0)
	assert_true(director.fired.is_empty(), "the booth is a refuge")
	assert_false(director.is_quiet())


func test_nothing_happens_while_an_exhibit_hunts_the_guard() -> void:
	await _start()
	_clear_exhibits()
	_go(&"egypt_gallery")
	await physics_frames(2)
	var hunter := WaxFigure.new()
	hunter.position = museum.player.global_position + Vector3(0.0, 0.1, -3.0)
	hunter.target = museum.player
	hunter.starts_awake = true
	museum.enemies_root.add_child(hunter)
	hunter.face(museum.player.global_position)
	museum.player.set(&"_grace", 1.0e9)
	for i in 120:
		await get_tree().physics_frame
		if PerceptionWorld.hunters_near(museum.player.global_position) > 0:
			break
	assert_gt(PerceptionWorld.hunters_near(museum.player.global_position), 0, "it hunts him")
	assert_false(director.is_quiet(), "no uncanny moment in a fight")
	director._next_ambient = 0.0
	_run(5.0)
	assert_true(director.fired.is_empty())


func test_the_clock_room_runs_backwards_once_a_night_and_its_thought_once_a_game() -> void:
	await _start()
	_clear_exhibits()
	_hour(2.5)
	_go(&"enlightenment_library")
	_go(&"enlightenment_clocks")
	_run(25.0)
	assert_true(director.fired.has(&"clocks_backwards"), "the clocks ran backwards")
	assert_true(GameState.has_seen_uncanny(&"text_clocks_backwards"), "the guard's thought, once")
	assert_eq(UncannyRules.fired_count(RunState.used, &"clocks_backwards"), 1, "kept with the night")
	_go(&"enlightenment_library")
	_go(&"enlightenment_clocks")
	_run(25.0)
	assert_eq(director.fired.count(&"clocks_backwards"), 1, "once a night")


func test_the_courts_eyes_open_once_in_a_game() -> void:
	await _start(1)
	_clear_exhibits()
	_go(&"entrance_hall")
	_go(&"court")
	_run(15.0)
	assert_true(director.fired.has(&"court_eyes"), "the first strange thing")
	assert_true(GameState.has_seen_uncanny(&"court_eyes"))
	var gazing := museum.paintings_root.find_children("Gaze", "Node", true, false)
	assert_gt(gazing.size(), 0, "the court's paintings look at him")
	museum.free()
	RunState.reset()
	GameState.night = 2
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny
	_clear_exhibits()
	_go(&"entrance_hall")
	_go(&"court")
	_run(15.0)
	assert_false(director.fired.has(&"court_eyes"), "never again")


func test_a_resumed_night_keeps_what_fired_and_starts_quietly() -> void:
	await _start()
	GameState.save_game()
	_clear_exhibits()
	_hour(2.5)
	_go(&"enlightenment_library")
	_go(&"enlightenment_clocks")
	_run(25.0)
	assert_true(director.fired.has(&"clocks_backwards"))
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny
	assert_gt(director.next_in(), UncannyDirector.RESUME_QUIET - 1.0, "a resumed night starts quietly")
	_clear_exhibits()
	_go(&"enlightenment_library")
	_go(&"enlightenment_clocks")
	_run(UncannyDirector.RESUME_QUIET + 15.0)
	assert_false(director.fired.has(&"clocks_backwards"), "what fired before the save does not fire again")


func test_a_rooms_moment_waits_for_the_guard_to_stay() -> void:
	await _start()
	_clear_exhibits()
	_hour(2.5)
	_go(&"enlightenment_library")
	_go(&"enlightenment_clocks")
	_go(&"enlightenment_library")   # in and straight out again
	_run(25.0)
	assert_false(director.fired.has(&"clocks_backwards"), "the clocks keep their secret for a guard who stays")


func test_the_lamps_do_not_play_in_a_room_to_fight_in() -> void:
	await _start()
	var arenas := UncannyRules.excluded_rooms(museum.floor_level.layout)
	var checked := 0
	for arena in arenas:
		if director.lamps.count(arena) == 0:
			continue
		checked += 1
		for id in [&"lamp_blink", &"lamp_stutter", &"lamp_brownout", &"lamp_sweep", &"predawn_unrest"]:
			assert_true(director._target(director.catalog.event(id), arena).is_empty(), "%s: not in %s" % [id, arena])
	assert_gt(checked, 1, "arenas with lamps looked at")
	var plain := director._target(director.catalog.event(&"lamp_stutter"), &"egypt_vestibule")
	assert_false(plain.is_empty(), "an ordinary hall still flickers")


func test_a_waking_guardian_or_boss_puts_every_lamp_back() -> void:
	await _start()
	var keeper := Node.new()
	museum.add_child(keeper)
	assert_true(director.lamps.play(&"egypt_vestibule", &"brownout", 6.0))
	assert_true(director.lamps.play(&"egypt_gallery", &"out", 6.0))
	Events.guardian_awakened.emit(keeper, &"colossus")
	assert_false(director.lamps.busy(&"egypt_vestibule"), "the guardian wakes: no effect carries into the fight")
	assert_false(director.lamps.busy(&"egypt_gallery"))
	assert_true(director.lamps.play(&"egypt_vestibule", &"flicker", 6.0))
	Events.boss_awakened.emit(keeper)
	assert_false(director.lamps.busy(&"egypt_vestibule"), "the T-Rex wakes: the same")


func test_a_door_slams_in_the_next_room_never_in_the_guards_own() -> void:
	await _start()
	_clear_exhibits()
	var layout := museum.floor_level.layout
	var graph := layout.graph()
	var slammed := 0
	for spec in layout.rooms:
		var at := UncannyRules.room_point(layout, spec.id)
		museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
		director.room = spec.id
		var door := director._door_to_slam(spec.id)
		if door == null:
			continue
		slammed += 1
		var next := UncannyRules.neighbours(graph, spec.id)
		assert_ne(door.room_a, spec.id, "%s: not a door of his room (%s)" % [spec.id, door.id])
		assert_ne(door.room_b, spec.id, "%s: not a door of his room (%s)" % [spec.id, door.id])
		assert_true(next.has(door.room_a) or next.has(door.room_b), "%s: a door of the next room (%s)" % [spec.id, door.id])
	assert_gt(slammed, 10, "doors slam in many rooms")

