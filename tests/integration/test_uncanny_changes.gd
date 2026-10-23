extends TestCase
## The museum changes behind the guard's back (plan
## 2026-10-21-eskalacja-nocy, task 7; backlog #35): a room he left changes
## while he is away and not looking, never if he comes back first; the
## rooms visited on earlier nights have changed by nightfall; a resumed
## night shows the very same changes (QA #51).

const SEED := 7   # nights 2-4 without a modifier (no blackout: the lamps are on)

var museum: Museum
var director: UncannyDirector


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _build() -> void:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	director = museum.floor_game.uncanny


func _start(night: int = 2, visited: Array[StringName] = []) -> void:
	GameState.new_game()
	GameState.seed_base = SEED
	GameState.night = night
	GameState.rooms_visited.assign(visited)
	await _build()


func _go(room: StringName) -> void:
	var at := UncannyRules.room_point(museum.floor_level.layout, room)
	museum.player.global_position = Vector3(at.x, at.y - 1.1, at.z)
	museum.floor_game.rooms.check()


func _run(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		director.advance(UncannyDirector.TICK)
		t += UncannyDirector.TICK


func _changes(id: StringName) -> Array:
	return UncannyRules.changes(RunState.used).filter(func(c: Array) -> bool: return c[0] == id)


func _piece(change: Array) -> Node3D:
	var index := String(change[1]).get_slice(":", 0).to_int()
	return UncannyEffects.find_piece(museum.floor_level, museum.floor_level.layout.pieces[index])


func _painting(spot: String) -> WallPainting:
	return UncannyEffects.painting_at(museum.paintings_root, (museum.floor_level.layout.markers[StringName(spot)] as Transform3D).origin)


func test_a_room_left_changes_while_the_guard_is_away() -> void:
	await _start()
	director.chance_scale = 0.0
	_go(&"egypt_gallery")
	_go(&"egypt_vestibule")
	assert_true(director.force_change(&"egypt_gallery", &"gone_statue"), "a statue there may go")
	_go(&"enlightenment_library")
	_run(30.0)
	assert_eq(_changes(&"gone_statue").size(), 0, "not yet: he has not been away long")
	_run(35.0)
	var made := _changes(&"gone_statue")
	assert_eq(made.size(), 1, "the statue is gone")
	var statue := _piece(made[0])
	assert_not_null(statue)
	assert_true(UncannyEffects.is_hidden(statue) and not statue.visible, "its pedestal stands empty")
	assert_true(director.fired.has(&"gone_statue"))


func test_coming_back_first_changes_nothing() -> void:
	await _start()
	_go(&"north_hall")
	_go(&"court")
	assert_true(director.force_change(&"north_hall", &"bust_turned"))
	_run(20.0)
	_go(&"north_hall")
	assert_eq(director.pending_in(&"north_hall"), &"", "he came back: it will not happen")
	_run(60.0)
	assert_eq(_changes(&"bust_turned").size(), 0)


func test_nothing_changes_before_his_eyes() -> void:
	await _start()
	_go(&"enlightenment_portraits")
	_go(&"enlightenment_service_stairs")
	assert_true(director.force_change(&"enlightenment_portraits", &"bench_turned"))
	var change: Dictionary = director._pending[&"enlightenment_portraits"]
	var point: Vector3 = change["target"]["point"]
	# he stands next door, looking straight at the bench
	var guard := museum.player
	guard.global_position = point + (Vector3(guard.global_position.x, point.y, guard.global_position.z) - point).normalized() * 8.0
	guard.camera.look_at(point, Vector3.UP)
	assert_true(director._guard_sees(point), "he looks at it")
	_run(60.0)
	assert_eq(_changes(&"bench_turned").size(), 0, "not while he looks")
	guard.camera.look_at(guard.camera.global_position * 2.0 - point, Vector3.UP)
	assert_false(director._guard_sees(point), "he looks away")
	_run(1.0)
	assert_eq(_changes(&"bench_turned").size(), 1, "the moment he looks away")


func test_a_change_waits_for_a_calm_moment() -> void:
	await _start()
	director.chance_scale = 0.0
	for exhibit in museum.exhibits():
		exhibit.free()
	_go(&"egypt_gallery")
	_go(&"egypt_vestibule")
	assert_true(director.force_change(&"egypt_gallery", &"gone_statue"))
	_go(&"enlightenment_library")
	# an exhibit hunts him: nothing changes meanwhile
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
	_run(65.0)
	assert_eq(_changes(&"gone_statue").size(), 0, "not while he is hunted")
	assert_eq(director.pending_in(&"egypt_gallery"), &"gone_statue", "it waits")
	hunter.free()
	# a wing guardian or the T-Rex fights: the same
	var finale := museum.floor_game.finale
	var stage := finale.stage
	finale.stage = FloorFinale.Stage.BOSS
	assert_true(museum.floor_game.blocks_rest(), "a fight is on")
	_run(5.0)
	assert_eq(_changes(&"gone_statue").size(), 0, "not in the middle of a fight")
	finale.stage = stage
	_run(2.0)
	assert_eq(_changes(&"gone_statue").size(), 1, "the moment it is calm")


func test_a_resumed_night_shows_the_same_changes() -> void:
	await _start()
	GameState.save_game()
	director.chance_scale = 0.0   # only the changes asked for
	for plan: Array in [[&"egypt_gallery", &"gone_statue"], [&"north_hall", &"bust_turned"], [&"court", &"sitter_gone"], [&"enlightenment_portraits", &"painting_looks_away"], [&"egypt_vestibule", &"room_dark"]]:
		_go(plan[0])
		_go(&"booth_corridor")
		assert_true(director.force_change(plan[0], plan[1]), "%s in %s" % [plan[1], plan[0]])
		_go(&"enlightenment_library")
		_run(65.0)
		assert_eq(_changes(plan[1]).size(), 1, "%s made" % plan[1])
	assert_not_null(_piece(_changes(&"gone_statue")[0]), "the statue's piece")
	var bust := _piece(_changes(&"bust_turned")[0])
	var bust_yaw := bust.global_basis.get_euler().y
	var sitter_spot := String(_changes(&"sitter_gone")[0][1])
	var looking_spot := String(_changes(&"painting_looks_away")[0][1])
	var look := PaintingGaze.look_of(_painting(looking_spot))
	assert_true(PaintingArt.SCENE_IDS.has(_painting(sitter_spot).painting_id), "the sitter walked out")
	assert_ne(look, Vector2.ZERO, "it looks aside")
	assert_eq(museum.floor_game.uncanny.lamps.count(&"egypt_vestibule"), 0, "the vestibule stands dark")
	var before := UncannyRules.changes(RunState.used)
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game(), "the save loads")
	await _build()
	await physics_frames(2)
	assert_eq(UncannyRules.changes(RunState.used), before, "the same changes, no more")
	assert_true(UncannyEffects.is_hidden(_piece(_changes(&"gone_statue")[0])), "the statue is still gone")
	assert_almost_eq(angle_difference(_piece(_changes(&"bust_turned")[0]).global_basis.get_euler().y, bust_yaw), 0.0, 0.001, "the bust still faces the wall")
	assert_true(PaintingArt.SCENE_IDS.has(_painting(sitter_spot).painting_id), "the frame still empty")
	assert_true(PaintingGaze.look_of(_painting(looking_spot)).is_equal_approx(look), "still looking aside")
	assert_eq(director.lamps.count(&"egypt_vestibule"), 0, "still dark")


func test_a_sleeper_left_behind_faces_the_door() -> void:
	await _start()
	director.chance_scale = 0.0
	var sleepers := museum.exhibits().filter(func(e: Enemy) -> bool:
		return e.brain.state == EnemyBrain.State.DORMANT and e.home_room == &"entrance_hall" and [&"wax", &"bust"].has(EnemyRoles.kind_of(e)))
	if sleepers.is_empty():
		return   # no wax figure asleep there tonight (the seed's draw)
	_go(&"entrance_hall")
	_go(&"booth_corridor")
	var door := UncannyRules.room_point(museum.floor_level.layout, &"booth_corridor")
	assert_true(director.force_change(&"entrance_hall", &"sleeper_turned", door))
	_go(&"enlightenment_library")
	_run(35.0)
	assert_true(director.fired.has(&"sleeper_turned"), "a figure turned")
	var turned := sleepers.filter(func(e: Enemy) -> bool:
		var to := door - e.global_position
		return is_instance_valid(e) and (-e.global_basis.z).dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.95)
	assert_eq(turned.size(), 1, "one of them faces the door now")
	assert_eq((turned[0] as Enemy).brain.state, EnemyBrain.State.DORMANT, "and sleeps on")


func test_the_nights_changes_come_from_the_seed_and_only_once() -> void:
	var visited: Array[StringName] = [&"egypt_gallery", &"entrance_hall", &"enlightenment_portraits"]
	var game := PersistentState.new()
	add_child(game)
	game.night = 3
	game.rooms_visited.assign(visited)
	var table := UncannyDirector.default_catalog()
	var layout := Floor1Layout.create()
	var base := -1
	for candidate in range(1, 400):
		game.seed_base = candidate
		var drawn := UncannyDirector.night_changes(table, layout, game, [] as Array[StringName], game.night_seed())
		if drawn.any(func(c: StringName) -> bool: return String(c).begins_with("chg_night_statue_gone@")):
			base = candidate
			break
	assert_gt(base, 0, "some night the statue is gone by nightfall")
	game.seed_base = base
	var first := UncannyDirector.night_changes(table, layout, game, [] as Array[StringName], game.night_seed())
	assert_eq(UncannyDirector.night_changes(table, layout, game, [] as Array[StringName], game.night_seed()), first, "the same seed, the same changes")
	game.night = 1
	assert_true(UncannyDirector.night_changes(table, layout, game, [] as Array[StringName], game.night_seed()).is_empty(), "nothing changed before the first night")
	game.night = 3
	game.rooms_visited.clear()
	assert_true(UncannyDirector.night_changes(table, layout, game, [] as Array[StringName], game.night_seed()).is_empty(), "only rooms seen before change")
	game.queue_free()
	# the game draws them at nightfall and keeps them with the night
	GameState.new_game()
	GameState.seed_base = base
	GameState.night = 3
	GameState.rooms_visited.assign(visited)
	GameState.save_game()
	await _build()
	await physics_frames(2)
	assert_true(RunState.is_used(UncannyRules.DRAWN))
	var statue_changes := _changes(&"night_statue_gone")
	assert_eq(statue_changes.size(), 1)
	assert_true(UncannyEffects.is_hidden(_piece(statue_changes[0])), "gone from nightfall")
	var count := UncannyRules.changes(RunState.used).size()
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	await _build()
	await physics_frames(2)
	assert_eq(UncannyRules.changes(RunState.used).size(), count, "a resumed night draws nothing new")
	assert_true(UncannyEffects.is_hidden(_piece(_changes(&"night_statue_gone")[0])))


func test_a_room_whose_sleeper_turned_is_not_turned_again_after_the_night_is_resumed() -> void:
	await _start()
	GameState.save_game()
	director.chance_scale = 0.0
	var kinds := UncannyCatalog.names(director.catalog.event(&"sleeper_turned"), "kinds")
	var home := &""
	for exhibit in museum.exhibits():
		if exhibit.brain.state == EnemyBrain.State.DORMANT and not exhibit.is_frozen() and kinds.has(EnemyRoles.kind_of(exhibit)):
			home = exhibit.home_room
			break
	assert_ne(home, &"", "a figure asleep somewhere tonight")
	var neighbour := UncannyRules.neighbours(museum.floor_level.layout.graph(), home)[0]
	_go(home)
	_go(neighbour)
	assert_true(director.force_change(home, &"sleeper_turned"))
	_go(&"enlightenment_library")
	_run(65.0)
	assert_true(director.fired.has(&"sleeper_turned"), "a figure turned")
	assert_true(RunState.is_used(UncannyRules.change_id(&"sleeper_turned", String(home))), "the room is kept with the night")
	assert_false(director.force_change(home, &"sleeper_turned"), "once a room")
	museum.quit_to_menu()
	museum.free()
	RunState.reset()
	GameState.reset()
	assert_true(GameState.load_game())
	await _build()
	await physics_frames(2)
	var asleep := museum.exhibits().filter(func(e: Enemy) -> bool:
		return e.brain.state == EnemyBrain.State.DORMANT and not e.is_frozen() and e.home_room == home and kinds.has(EnemyRoles.kind_of(e)))
	assert_false(asleep.is_empty(), "a figure sleeps there on the resumed night too")
	assert_false(director.force_change(home, &"sleeper_turned"), "the same room does not turn again")

