extends TestCase
## The guardians' arenas read the zones' markers (W3-W5): each guardian
## gets its named points (the Lamassu's relief slabs, the Serpent's loop);
## the relief warriors step off the walls in the Lamassu's phase 2 (once a
## night); the Serpent glides its tracks and passes its light in phase 2; the rope of the
## Planetarium's portcullis hangs on its counterweight marker; the arena
## grilles drop on the door markers facing into the arena; and nothing can
## be sniped from outside an arena (the Planetarium's observers' gallery).

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _put_guard(at: Vector3) -> void:
	museum.player.global_position = at + Vector3.UP * 0.05
	museum.player.velocity = Vector3.ZERO
	museum.player.heal(1000.0)


func _marker(id: StringName) -> Transform3D:
	return museum.floor_level.markers[id]


func _markers_like(prefix: String) -> Array:
	return museum.floor_level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with(prefix))


func _hit(guardian: Guardian, amount: float) -> void:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, museum.player)
	info.weapon = &"rifle_hunt"
	info.position = guardian.global_position + Vector3.UP * 2.0
	guardian.take_damage(info)


func _guardian(id: StringName) -> Guardian:
	return museum.floor_game.guardians.guardians.get(id)


## Wakes [param id] with the guard on its arena's start line.
func _wake(id: StringName) -> Guardian:
	var guardian := _guardian(id)
	_put_guard(_marker(StringName("arena_%s_start" % id)).origin)
	await _seconds(0.3)
	return guardian


func test_each_guardian_gets_its_arenas_points() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := _guardian(&"lamassu")
	var serpent := _guardian(&"serpent")
	assert_eq((lamassu.points.get(&"relief", []) as Array).size(), _markers_like("lamassu_relief_").size())
	assert_gt(_markers_like("lamassu_relief_").size(), 0, "the zone marks the relief slabs")
	var path: Array = serpent.points.get(&"path", [])
	assert_eq(path.size(), _markers_like("serpent_path_").size())
	if path.size() > 1:
		assert_eq((path[1] as Transform3D).origin, _marker(&"serpent_path_2").origin, "in the numbers' order")
	assert_false(lamassu.points.has(&"start"), "no arena_ markers among them")


func test_the_relief_warriors_step_off_the_walls_in_the_lamassus_phase_two() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var lamassu := await _wake(&"lamassu")
	assert_true(lamassu.is_fighting())
	var before := museum.exhibits().size()
	_hit(lamassu, lamassu.max_health * 0.4)
	assert_eq(lamassu.phase, 2)
	var reliefs := _markers_like("lamassu_relief_")
	var called := museum.exhibits().slice(before)
	assert_eq(called.size(), reliefs.size(), "one warrior from each relief")
	for exhibit: Enemy in called:
		assert_true(exhibit.summoned)
		assert_ne(exhibit.brain.state, EnemyBrain.State.DORMANT, "awake at once")
		assert_eq(museum.floor_level.room_at(exhibit.global_position + Vector3.UP * 0.5), &"assyria_courtyard")
	# fled and fought again the same night: the walls are bare now
	lamassu.reset_fight()
	await _seconds(0.3)
	_hit(lamassu, lamassu.max_health * 0.4)
	assert_eq(museum.exhibits().size(), before + reliefs.size(), "once a night")


func test_the_serpent_leaves_its_ring_swaps_its_roles_in_phase_two_and_rests_when_calmed() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var serpent := await _wake(&"serpent") as Serpent
	assert_not_null(serpent, "the real Serpent stands in its temple")
	if serpent == null:
		return
	assert_true(serpent.is_fighting())
	assert_true(serpent.kinematic, "it moves itself along its tracks")
	var rest := serpent.body.leader()
	assert_gt(serpent.course.nodes.size(), 20, "its tracks come from the zone's markers")
	# awake, it glides off its ring down toward the guard
	for i in 60 * 8:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
	var leader := serpent.body.leader()
	assert_gt(leader.distance_to(rest), 3.0, "it left its resting ring")
	assert_eq(museum.floor_level.room_at(leader + Vector3.UP * 0.5), &"americas_temple", "and stays in its arena")
	for j in range(serpent.body.ground_joints().x, serpent.body.ground_joints().y + 1):
		var joint := serpent.body.joints[j]
		assert_eq(museum.floor_level.room_at(joint + Vector3.UP * 0.5), &"americas_temple", "joint %d in the arena" % j)
	# phase 2: the light passes to the other head, then it glides faster
	_hit(serpent, serpent.max_health * 0.4)
	assert_eq(serpent.phase, 2)
	var swapped := watch(serpent.brain.roles_swapped)
	for i in 60 * 6:
		museum.player.heal(1000.0)
		await get_tree().physics_frame
		if swapped.size() > 0:
			break
	assert_eq(swapped.size(), 1, "the roles swapped")
	assert_eq(serpent.brain.spitter, SerpentBody.End.B)
	serpent.reset_fight()
	assert_false(serpent.is_fighting(), "calmed")
	assert_lt(serpent.body.leader().distance_to(rest), 0.5, "back on its ring")
	assert_eq(serpent.brain.spitter, SerpentBody.End.A)


func test_nothing_is_sniped_from_the_observers_gallery() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var planetarium := _guardian(&"planetarium")
	var lookout := museum.floor_level.layout.room(&"enlightenment_observatory")
	assert_not_null(lookout)
	var part := lookout.parts[0]
	_put_guard(Vector3(part.get_center().x, lookout.floor_y, part.get_center().y))
	await _seconds(0.3)
	assert_eq(museum.floor_level.room_at(museum.player.global_position + Vector3.UP * 0.5), &"enlightenment_observatory")
	var hints := watch(Events.hint_requested)
	_hit(planetarium, 300.0)
	assert_almost_eq(planetarium.health.fraction(), 1.0, 0.001, "a shot from the gallery does nothing")
	assert_eq(planetarium.state, Guardian.State.DORMANT, "and wakes nothing")
	assert_eq(hints.size(), 1, "the guard is told why")
	var fighting := await _wake(&"planetarium")
	_hit(fighting, 300.0)
	assert_lt(fighting.health.fraction(), 1.0, "in the arena it counts")


func test_the_planetarium_portcullis_rope_hangs_on_its_counterweight() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var rope := museum.floor_game.gates.lock_of(&"rope_planetarium")
	assert_not_null(rope)
	assert_lt(rope.global_position.distance_to(_marker(&"planetarium_counterweight").origin), 0.05)


func test_the_arena_grilles_drop_on_the_door_markers_facing_in() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var keeper := museum.floor_game.guardians
	await _wake(&"planetarium")
	var doors := _markers_like("arena_planetarium_door_")
	assert_eq((keeper.sealed.get(&"planetarium", []) as Array).size(), doors.size(), "every way in shut")
	for id: StringName in doors:
		var shut := keeper._door_near(id)
		if shut != null:
			assert_true(shut.locked, "%s: its door locked" % id)
			continue
		var grille: ArenaGrille = keeper.grilles.get(id)
		assert_not_null(grille, "%s: a grille" % id)
		if grille == null:
			continue
		assert_true(grille.is_down)
		assert_gt(grille.global_basis.z.dot(_marker(id).basis.z), 0.99, "%s faces the way its marker does" % id)
