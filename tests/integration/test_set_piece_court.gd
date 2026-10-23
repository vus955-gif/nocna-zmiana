extends TestCase
## The Great Court's set-piece on the real Floor I (plan
## 2026-10-22-set-piece): "Grandmother's footsteps" - the hall goes dark
## three times, the wax figures the guard does not watch step his way, one
## may reach him and wake after a telegraph; it stops cleanly, it is one
## data entry away from today's night, and it leaves nothing behind.

const SEED := 7   # nights 2-4 without a modifier (the lamps are on)
## The guard's spot on the court's floor, south of the drum, looking north.
const SPOT := Vector3(0.0, 0.0, 16.5)
## Wax figures behind him (south of him: he looks north) and before him.
const BEHIND: Array[Vector3] = [Vector3(-20.0, 0.0, 27.0), Vector3(17.0, 0.0, 27.5), Vector3(-12.0, 0.0, 28.0)]
const BEFORE: Array[Vector3] = [Vector3(-14.0, 0.0, -2.0)]
## The south-west corner, looking north-east, and figures all in his view.
const CORNER := Vector3(-26.0, 0.0, 26.0)
const IN_VIEW: Array[Vector3] = [Vector3(-14.0, 0.0, 14.0), Vector3(-19.0, 0.0, 5.0), Vector3(-6.0, 0.0, 20.0)]

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
	await _build()


func _build() -> void:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny
	director._next_ambient = INF   # no background event in the way


func _go(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


## The guard on the court's floor at [param at], looking along [param look].
func _stand(at: Vector3, look: Vector3) -> void:
	if director.room != &"court":
		_go(&"entrance_hall")
	museum.player.global_position = at
	museum.player.velocity = Vector3.ZERO
	# the head follows the body only on the next frame (top_level): put it there now
	var eye: Variant = museum.player.get(&"_eye")
	museum.player.head.global_position = at + Vector3.UP * (float(eye) if eye != null else 1.6)
	museum.player.head.global_rotation = Vector3(0.0, atan2(-look.x, -look.z), 0.0)
	museum.floor_game.rooms.check()


func assert_null(value: Variant, message: String = "") -> void:
	assert_true(value == null, message if message != "" else "null")


func _both() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append_array(BEHIND)
	out.append_array(BEFORE)
	return out


func _first(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		out.append(BEHIND[i])
	return out


func _clear_exhibits() -> void:
	for exhibit in museum.exhibits():
		exhibit.free()


func _sleepers(spots: Array[Vector3]) -> Array[Enemy]:
	var made: Array[Enemy] = []
	for at in spots:
		var figure := WaxFigure.new()
		figure.position = at
		figure.target = museum.player
		museum.enemies_root.add_child(figure)
		figure.face(at + Vector3(0.0, 0.0, -1.0))
		made.append(figure)
	return made


func _hour(hours_after_23: float) -> void:
	museum.watch.clock.elapsed = hours_after_23 * NightClock.SECONDS_PER_HOUR
	director.advance(UncannyDirector.TICK)


func _run(seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		director.advance(step)
		t += step


## The court at 1:30 with [param spots] asleep and the guard at [param at]
## looking along [param look]: the game started at once.
func _game(spots: Array[Vector3], at: Vector3 = SPOT, look: Vector3 = Vector3(0.0, 0.0, -1.0)) -> Array[Enemy]:
	_clear_exhibits()
	_hour(2.5)
	var made := _sleepers(spots)
	_stand(at, look)
	assert_true(director.fire_now(CourtGame.ID), "the game starts")
	assert_not_null(director.set_piece)
	return made


func _names(beats: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for beat: Array in beats:
		out.append(beat[0])
	return out


func _awake(figures: Array[Enemy]) -> int:
	return figures.filter(func(f: Enemy) -> bool: return is_instance_valid(f) and f.brain.state != EnemyBrain.State.DORMANT).size()


func _all_lamps_at_rest() -> void:
	var lamps := director.lamps
	for room in CourtGame.LAMP_ROOMS:
		assert_false(lamps.busy(room), "%s: no effect left playing" % room)
		for lamp: Light3D in lamps.mains.get(room, []):
			assert_almost_eq(lamp.light_energy, lamps.base_energy(lamp), 0.0001, "%s: its lamp at its own energy" % room)


# --- the beats --------------------------------------------------------------------------

func test_nobody_moves_while_he_watches_them_all_and_the_beats_come_in_order() -> void:
	await _start()
	var figures := _game(IN_VIEW, CORNER, Vector3(1.0, 0.0, -1.0))
	var before: Array[Vector3] = []
	for figure in figures:
		assert_true(figure.guard_watching(), "in his view")
		before.append(figure.global_position)
	_run(14.0)
	assert_null(director.set_piece, "over")
	assert_eq(director.pieces.size(), 1)
	var played: Dictionary = director.pieces[0]
	assert_eq(played["reason"], &"done")
	assert_eq(_names(played["beats"]), [&"warn", &"dark", &"light", &"dark", &"light", &"dark", &"end"] as Array[StringName])
	var times: Array[float] = [0.0, 1.6, 3.6, 6.0, 8.0, 10.4, 12.4]
	for i in times.size():
		assert_almost_eq(float(played["beats"][i][1]), times[i], 0.06, "beat %d on time" % i)
	for i in figures.size():
		assert_true(figures[i].global_position.is_equal_approx(before[i]), "watched: it stood still")
	assert_eq(_awake(figures), 0, "nobody woke")
	assert_null(played["winner"])
	assert_true(GameState.has_seen_uncanny(&"text_court_game_won"), "his thought: nobody moved")
	_all_lamps_at_rest()


func test_the_ones_behind_him_step_closer_in_the_dark_and_never_wake_by_it() -> void:
	await _start()
	var figures := _game(_both())
	var goal := museum.player.global_position
	var before: Array[Vector3] = []
	var watched: Array[bool] = []
	for figure in figures:
		before.append(figure.global_position)
		watched.append(figure.guard_watching())
	assert_false(watched[0] or watched[1] or watched[2], "the three behind him unwatched")
	assert_true(watched[3], "the one before him watched")
	_run(CourtGame.WARN_TIME - 0.1)
	for i in figures.size():
		assert_true(figures[i].global_position.is_equal_approx(before[i]), "nothing moves while the lamps only stutter")
	assert_false(director.is_quiet(), "no other uncanny moment while the game plays")
	_run(CourtGame.DARK_TIME - 0.2)   # into the first dark, its steps taken
	var moved := 0
	for i in figures.size():
		var figure := figures[i]
		var keep := CourtGame.keep_of(figure)
		var was := CourtGame.flat(before[i], goal)
		var now := CourtGame.flat(figure.global_position, goal)
		if watched[i]:
			assert_true(figure.global_position.is_equal_approx(before[i]), "watched: still")
			continue
		assert_true(now <= was + 0.01, "never further")
		assert_true(now >= keep - 0.35, "never nearer than it could see him asleep (%.1f < %.1f)" % [now, keep])
		if now < was - 1.0:
			moved += 1
			var to := (goal - figure.global_position) * Vector3(1, 0, 1)
			assert_gt((-figure.global_basis.z).dot(to.normalized()), 0.9, "it faces him")
			assert_eq(PerceptionWorld.room_at(figure.global_position), &"court", "on the court's floor")
	assert_gt(moved, 0, "the dark brought some of them closer")
	assert_eq(_awake(figures), 0, "none woke by it")


func test_one_figure_at_most_reaches_him_and_calls_out_after_a_telegraph() -> void:
	await _start()
	var figures := _game(_both())
	var goal := museum.player.global_position
	_run(14.0)
	assert_eq(director.pieces.size(), 1)
	var played: Dictionary = director.pieces[0]
	var names := _names(played["beats"])
	assert_eq(played["reason"], &"done")
	var winner: Enemy = played["winner"]
	assert_not_null(winner, "with his back to three of them, one reaches him")
	var light := names.rfind(&"light")
	var wake := names.find(&"wake")
	assert_true(wake > light and light > 0, "the light comes back, then it calls out: %s" % [names])
	var telegraph := float(played["beats"][wake][1]) - float(played["beats"][light][1])
	assert_true(telegraph >= 0.6, "a telegraph of at least 0.6 s (%.2f)" % telegraph)
	assert_eq(names[-1], &"end")
	assert_ne(winner.brain.state, EnemyBrain.State.DORMANT, "it comes for him")
	assert_eq(_awake(figures), 1, "only the one")
	assert_eq(museum.exhibits().size(), figures.size(), "no exhibit more than the court had")
	var near := CourtGame.flat(winner.global_position, goal)
	assert_true(near >= CourtGame.WIN_STAND - 0.35 and near <= CourtGame.WIN_STAND + 0.6, "right behind him (%.1f m)" % near)
	assert_false(winner.guard_watching(), "behind his back")
	_all_lamps_at_rest()


func test_the_same_seed_plays_the_same_game() -> void:
	var runs: Array = []
	for attempt in 2:
		await _start()
		var figures := _game(_both())
		_run(14.0)
		var spots: Array[Vector3] = []
		for figure in figures:
			spots.append(figure.global_position)
		runs.append([_names(director.pieces[0]["beats"]), spots, figures.find(director.pieces[0]["winner"])])
		museum.free()
	assert_eq(runs[0][0], runs[1][0], "the same beats")
	assert_eq(runs[0][2], runs[1][2], "the same winner")
	for i in (runs[0][1] as Array).size():
		assert_true((runs[0][1][i] as Vector3).is_equal_approx(runs[1][1][i]), "figure %d in the same place" % i)


func test_tonights_own_court_plays_it_and_its_ambush_sleeps_on() -> void:
	var played := 0
	for night in [2, 3, 4]:
		await _start(night)
		_hour(2.5)
		_stand(SPOT, Vector3(0.0, 0.0, -1.0))
		if not CourtGame.may_start(director):
			museum.free()
			continue
		var pack: Array[Enemy] = []
		var waiting: Array[int] = []
		for ambush in museum.floor_game.encounters.waiting:
			waiting.append_array(ambush.slots)
		var asleep: Array[Enemy] = []
		for exhibit in museum.exhibits():
			if exhibit.brain.state == EnemyBrain.State.DORMANT:
				asleep.append(exhibit)
				if exhibit.has_meta(Museum.SLOT_META) and waiting.has(int(exhibit.get_meta(Museum.SLOT_META))):
					pack.append(exhibit)
		var pack_at: Array[Vector3] = []
		for exhibit in pack:
			pack_at.append(exhibit.global_position)
		var cast := CourtGame.cast_of(director)
		assert_true((cast[0] as Array).size() <= CourtGame.MAX_WALKERS and (cast[1] as Array).size() <= CourtGame.MAX_TURNERS, "night %d: a few of them" % night)
		assert_true(director.fire_now(CourtGame.ID), "night %d: the game" % night)
		_run(14.0)
		assert_eq(director.pieces[-1]["reason"], &"done", "night %d: played out" % night)
		assert_true(_awake(asleep) <= 1, "night %d: one woke at most" % night)
		for i in pack.size():
			assert_true(pack[i].global_position.is_equal_approx(pack_at[i]), "night %d: an ambush's sleeper stays put" % night)
		_all_lamps_at_rest()
		played += 1
		museum.free()
	assert_gt(played, 0, "some night's court has its figures")


# --- it stops cleanly ---------------------------------------------------------------------

func test_walking_out_of_the_court_stops_it_with_every_lamp_back() -> void:
	await _start()
	var figures := _game(_both())
	_run(CourtGame.WARN_TIME + 0.5)
	assert_true(director.lamps.busy(&"court"), "the hall is dark")
	_go(&"entrance_hall")
	_run(0.2)
	assert_null(director.set_piece, "stopped")
	assert_eq(director.pieces[0]["reason"], &"left")
	_all_lamps_at_rest()
	assert_false(GameState.has_seen_uncanny(CourtGame.ID), "walked through in its first dark: not counted, it may come another night")
	assert_false(GameState.has_seen_uncanny(&"text_court_game"), "its thought with it")
	assert_eq(UncannyRules.fired_count(RunState.used, CourtGame.ID), 1, "tonight's go is spent")
	var spots: Array[Vector3] = []
	for figure in figures:
		spots.append(figure.global_position)
	_run(15.0)
	for i in figures.size():
		assert_true(figures[i].global_position.is_equal_approx(spots[i]), "nothing moves after it stopped")
	assert_eq(_awake(figures), 0)
	# the next night it may come again
	museum.free()
	RunState.reset()
	GameState.night = 3
	await _build()
	_game(_both())
	assert_eq(_names(director.set_piece.beats), [&"warn"] as Array[StringName], "the next night: the game again")


func test_cut_short_after_its_second_dark_it_counts_and_tonight_it_never_comes_again() -> void:
	await _start()
	_game(_both())
	_run(CourtGame.WARN_TIME + CourtGame.DARK_TIME + CourtGame.LIGHT_TIME + 0.2)   # in the second dark
	_go(&"entrance_hall")
	_run(0.2)
	assert_eq(director.pieces[-1]["reason"], &"left")
	assert_true(GameState.has_seen_uncanny(CourtGame.ID), "he saw the heart of it: once a game")
	_all_lamps_at_rest()
	# a game walked through early is not seen, but not again the same night either
	GameState.uncanny_seen.erase(CourtGame.ID)
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	assert_false(director.fire_now(CourtGame.ID), "once a night")


func test_a_fight_a_waking_guardian_or_a_haven_stops_it() -> void:
	await _start()
	_game(_both())
	_run(1.0)
	Events.guardian_awakened.emit(museum, &"colossus")
	_run(0.1)
	assert_null(director.set_piece)
	assert_eq(director.pieces[-1]["reason"], &"fight")
	_all_lamps_at_rest()
	# again, in another game: an exhibit hunting him
	GameState.uncanny_seen.erase(CourtGame.ID)
	RunState.used.clear()
	director._last_event = -INF
	_game(_both())
	var hunter := WaxFigure.new()
	hunter.position = museum.player.global_position + Vector3(0.0, 0.1, -4.0)
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
	_run(0.1)
	assert_null(director.set_piece)
	assert_eq(director.pieces[-1]["reason"], &"fight")
	assert_false(director.fire_now(CourtGame.ID), "and no game while it hunts")


func test_never_in_the_finale_never_without_its_figures_never_on_a_blackout_night() -> void:
	await _start()
	_clear_exhibits()
	_hour(2.5)
	_sleepers(_first(CourtGame.MIN_WALKERS - 1))
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	assert_false(CourtGame.may_start(director), "too few figures to play")
	_sleepers([Vector3(-24.0, 0.0, 18.0)] as Array[Vector3])
	assert_true(CourtGame.may_start(director), "enough now")
	museum.floor_game.finale.stage = FloorFinale.Stage.BOSS
	assert_false(CourtGame.may_start(director), "not with the T-Rex up")
	assert_false(director.fire_now(CourtGame.ID))
	museum.floor_game.finale.stage = FloorFinale.Stage.ASTROLABE
	var entry := director.catalog.event(CourtGame.ID)
	assert_false(UncannyRules.fits_night(entry, 2, &"blackout"), "not on a blackout night")
	assert_true(UncannyRules.in_phase(entry, NightEscalation.Phase.UNEASY) and UncannyRules.in_phase(entry, NightEscalation.Phase.WITCHING))
	assert_false(UncannyRules.in_phase(entry, NightEscalation.Phase.CALM) or UncannyRules.in_phase(entry, NightEscalation.Phase.PREDAWN))
	# the café behind its counter is a haven: no game starts there, and one
	# playing stops when he gets in
	var cafe := museum.floor_game.cafe.zone.get_center()
	cafe.y = museum.floor_game.cafe.zone.position.y + 0.1
	assert_true(Haven.shelters(cafe), "the café's aisle shelters")
	museum.player.global_position = cafe
	assert_false(director.is_quiet(), "the café is a refuge")
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	assert_true(director.fire_now(CourtGame.ID))
	_run(1.0)
	museum.player.global_position = cafe
	_run(0.1)
	assert_null(director.set_piece)
	assert_eq(director.pieces[-1]["reason"], &"haven")
	_all_lamps_at_rest()


func test_with_reduce_flashing_the_hall_never_flashes_more_than_three_times_a_second() -> void:
	var was: bool = Settings.data.reduce_flashing
	Settings.data.reduce_flashing = true
	await _start()
	_game(IN_VIEW, CORNER, Vector3(1.0, 0.0, -1.0))
	var lamps: Array[Light3D] = []
	for room in CourtGame.LAMP_ROOMS:
		for lamp: Light3D in director.lamps.mains.get(room, []):
			if lamp.visible:
				lamps.append(lamp)
	assert_gt(lamps.size(), 4, "the hall's lamps")
	var last: Array[float] = []
	for lamp in lamps:
		last.append(lamp.light_energy)
	var drops: Array[int] = []   # frames where some lamp of the hall began to go darker
	var dropped_before := false
	var frame := 0
	var game := director.set_piece
	while frame < 60 * 5 and is_instance_valid(game) and game.time < CourtGame.WARN_TIME + CourtGame.DARK_TIME + 0.5:
		await get_tree().process_frame
		frame += 1
		var dropped := false
		for i in lamps.size():
			var now := lamps[i].light_energy
			if now < last[i] - 0.05 * director.lamps.base_energy(lamps[i]):
				dropped = true
			last[i] = now
		if dropped and not dropped_before:
			drops.append(frame)   # a darkening over frames running is one flash
		dropped_before = dropped
	Settings.data.reduce_flashing = was
	assert_gt(drops.size(), 0, "the hall does go dark")
	for i in drops.size():
		var within := drops.filter(func(f: int) -> bool: return f >= drops[i] and f < drops[i] + 60).size()
		assert_true(within <= Flashing.MAX_PER_SECOND, "at most three darkenings in a second (%d from frame %d: %s)" % [within, drops[i], drops])


func test_too_few_figures_leave_the_courts_entry_to_the_t_rex_foreshadow() -> void:
	await _start()
	_clear_exhibits()
	_hour(4.5)   # 3:30, the witching hour: the T-Rex's bones may rattle
	_sleepers(_first(CourtGame.MIN_WALKERS - 1))
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	var ids: Array = director._scheduled.map(func(item: Array) -> StringName: return UncannyCatalog.id_of(item[0]))
	assert_true(ids.has(&"court_bones"), "no game to play: the bones get the court (%s)" % [ids])
	assert_false(ids.has(CourtGame.ID))
	director._scheduled.clear()
	_sleepers([Vector3(-24.0, 0.0, 18.0)] as Array[Vector3])
	_go(&"entrance_hall")
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	ids = director._scheduled.map(func(item: Array) -> StringName: return UncannyCatalog.id_of(item[0]))
	assert_true(ids.has(CourtGame.ID), "enough figures: the game first (%s)" % [ids])


# --- the trigger, once a game, the switch ------------------------------------------------

func test_walking_into_the_court_after_one_starts_it_once_a_game() -> void:
	await _start()
	GameState.see_uncanny(&"court_eyes")   # the court's first moment came on an earlier night
	_clear_exhibits()
	_hour(2.5)
	_sleepers(_both())
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	_run(3.0, UncannyDirector.TICK)
	assert_null(director.set_piece, "not at once: a few seconds after he walked in")
	_run(2.0, UncannyDirector.TICK)
	assert_not_null(director.set_piece, "the game")
	assert_true(GameState.has_seen_uncanny(CourtGame.ID), "seen: once a game")
	_run(15.0)
	assert_null(director.set_piece)
	_go(&"entrance_hall")
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	_run(10.0, UncannyDirector.TICK)
	assert_eq(director.pieces.size(), 1, "never again")


func test_its_switch_leaves_the_table_and_the_night_exactly_as_they_were() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UncannyCatalog.PATH))
	var events: Array = data["events"]
	var at := events.find_custom(func(e: Dictionary) -> bool: return e.get("id") == "court_game")
	assert_true(at >= 0, "in the table")
	assert_true(bool(events[at].get("enabled", false)), "on by default")
	var off: Dictionary = data.duplicate(true)
	off["events"][at]["enabled"] = false
	var without: Dictionary = data.duplicate(true)
	(without["events"] as Array).remove_at(at)
	var off_table := UncannyCatalog.from_data(off)
	var without_table := UncannyCatalog.from_data(without)
	assert_false(off_table.has(CourtGame.ID), "switched off: left out")
	assert_eq(off_table.events, without_table.events, "the very table of today")
	# the same night with each: the director draws and plays the same
	var runs: Array = []
	for table in [off_table, without_table]:
		await _start()
		director.catalog = table
		_clear_exhibits()
		_hour(2.5)
		_sleepers(_both())
		_stand(SPOT, Vector3(0.0, 0.0, -1.0))
		director._next_ambient = director._time + 10.0
		_run(30.0, UncannyDirector.TICK)
		runs.append([director._rng.state, director.fired.duplicate(), director.set_piece == null and director.pieces.is_empty()])
		museum.free()
	assert_true(runs[0][2], "no game with the switch off")
	assert_eq(runs[0][0], runs[1][0], "the same draws")
	assert_eq(runs[0][1], runs[1][1], "the same events")


# --- saves, the museum freed ---------------------------------------------------------------

func test_a_save_in_the_middle_cancels_it_cleanly() -> void:
	await _start()
	GameState.save_game()
	_game(_both())
	_run(CourtGame.WARN_TIME + CourtGame.DARK_TIME + 0.5)
	assert_not_null(director.set_piece, "in the middle of it")
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	assert_true(GameState.has_seen_uncanny(CourtGame.ID), "kept as seen")
	await _build()
	assert_null(director.set_piece, "a resumed night plays no half a game")
	_all_lamps_at_rest()
	_clear_exhibits()
	_hour(2.5)
	_sleepers(_both())
	_stand(SPOT, Vector3(0.0, 0.0, -1.0))
	_run(UncannyDirector.RESUME_QUIET + 10.0, UncannyDirector.TICK)
	assert_null(director.set_piece)
	assert_true(director.pieces.is_empty(), "nor the game again")


func test_the_museum_freed_in_the_dark_leaves_nothing_behind() -> void:
	await _start()
	_game(_both())
	_run(CourtGame.WARN_TIME + 0.5)
	assert_true(director.lamps.busy(&"court"))
	museum.free()
	await physics_frames(2)
	GameState.uncanny_seen.erase(CourtGame.ID)
	RunState.reset()
	await _build()
	assert_null(director.set_piece)
	_all_lamps_at_rest()
	_game(_both())
	_run(14.0)
	assert_eq(director.pieces[0]["reason"], &"done", "and it plays again in a museum built afresh")
