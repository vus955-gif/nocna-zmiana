extends TestCase
## No arena locks the guard in for good (QA #50; plan
## docs/superpowers/plans/2026-10-18-qa-kolizje-softlocki-zapis.md), for
## every wing guardian of Floor I (the real ones, in the game scene):
## walking in wakes it and shuts the arena (its doors lock, grilles drop);
## the shut arena keeps the guard, the guardian's post and the reward's spot
## on one floor (nothing cut in two); outside the arena (the doors slammed
## behind his back) the leash calms it and every door opens again; its fall
## opens them too and lays its seal and shard where he can walk to them,
## recorded and saved at once. And whatever ends a night in the middle of a
## fight - death, dawn, leaving through the menu - the next night (or the
## night resumed) finds the guardian asleep on its post, the arena open.

const NavProbe := preload("res://tests/support/nav_probe.gd")
const LAYERS := LevelNavigation.WALK_LAYER

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


## The guard at [param at] (feet), unharmed by what the fight throws at him
## while the test drives it.
func _put_guard(at: Vector3) -> void:
	museum.player.global_position = at + Vector3.UP * 0.05
	museum.player.velocity = Vector3.ZERO
	museum.player.set(&"_grace", 1.0e9)


func _keeper() -> GuardianKeeper:
	return museum.floor_game.guardians


func _marker(id: String) -> Variant:
	var markers := museum.floor_level.markers
	return (markers[StringName(id)] as Transform3D).origin if markers.has(StringName(id)) else null


## Walks the guard onto the arena's start line (or 4 m in front of the
## guardian); returns the guardian once awake.
func _wake(plan: Floor1Plan.GuardianPlan) -> Guardian:
	var guardian: Guardian = _keeper().guardians[plan.id]
	var start: Variant = _marker("arena_%s_start" % plan.id)
	var at: Vector3 = start if start != null else guardian.global_position - guardian.global_basis.z * 4.0
	_put_guard(at)
	for i in 60:
		await get_tree().physics_frame
		if guardian.is_fighting():
			break
	return guardian


## A point just outside arena [param plan]'s first door (behind the door
## marker, away from the arena), or null.
func _outside(plan: Floor1Plan.GuardianPlan, arena: StringName) -> Variant:
	for id: StringName in museum.floor_level.markers:
		if not String(id).begins_with("arena_%s_door_" % plan.id):
			continue
		var door: Transform3D = museum.floor_level.markers[id]
		for distance: float in [2.0, 3.0, 4.5]:
			for way: Vector3 in [door.basis.z, -door.basis.z]:
				var at := door.origin + Vector3(way.x, 0.0, way.z).normalized() * distance
				var room := museum.floor_level.room_at(at + Vector3.UP * 0.5)
				if room != &"" and room != arena:
					return Vector3(at.x, museum.floor_level.layout.room(room).floor_y, at.z)
	return null


## Every door the fight of [param arena_id] shut is unlocked and open,
## every grille up.
func _arena_open(arena_id: StringName, label: String) -> void:
	assert_false(_keeper().sealed.has(arena_id), "%s: nothing held shut" % label)
	for id: StringName in museum.floor_level.markers:
		if not String(id).begins_with("arena_%s_door_" % arena_id):
			continue
		var grille: ArenaGrille = _keeper().grilles.get(id)
		if grille != null:
			assert_false(grille.is_down, "%s: the grille %s is up" % [label, id])
	for door: Door in museum.floor_level.doors.values():
		if museum.floor_level.layout.gate_of_opening(door.id) == null and door.locked:
			fail("%s: the door %s is still locked" % [label, door.id])


func _map() -> RID:
	return museum.floor_level.walk_region.get_navigation_map()


## The floor of [param guardian]'s post: where it stands, or for the
## Lamassu (asleep up on its plinth, a stone the exhibits walk round) the
## court in front of the plinth where it steps down.
static func _post_floor(guardian: Guardian) -> Vector3:
	var bull := guardian as Lamassu
	if bull != null and is_instance_valid(bull.plinth):
		return bull.plinth.step_off_point()
	return guardian.home.origin


## True when the navmesh joins [param a] and [param b] (each snapped to it
## within 1.5 m).
func _joined(a: Vector3, b: Vector3) -> bool:
	var map := _map()
	var start := NavigationServer3D.map_get_closest_point(map, a)
	var goal := NavigationServer3D.map_get_closest_point(map, b)
	if start.distance_to(a) > 1.5 or goal.distance_to(b) > 1.5:
		return false
	return NavProbe.connected(map, start, goal, LAYERS)


func _rebaked() -> void:
	await physics_frames(2)
	while museum.floor_level.navigation.is_baking():
		await get_tree().physics_frame
	await physics_frames(2)


func test_every_arena_shuts_holds_its_fight_lets_a_fleeing_guard_go_and_opens_at_the_fall() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var keeper := _keeper()
	for plan in Floor1Plan.guardians():
		var label := String(plan.id)
		var guardian := await _wake(plan)
		assert_true(guardian.is_fighting(), "%s wakes when the guard walks in" % label)
		var shut: Array = keeper.sealed.get(plan.id, [])
		assert_gt(shut.size(), 0, "%s: its arena shuts" % label)
		for node: Variant in shut:
			if node is Door:
				assert_true((node as Door).locked, "%s: door %s locked" % [label, (node as Door).id])
			elif node is ArenaGrille:
				assert_true((node as ArenaGrille).is_down, "%s: a grille down" % label)
		# the shut arena: the guard, the post and the reward spot on one floor
		await _rebaked()
		var guard := museum.player.global_position
		var reward := keeper.reward_spot(plan, guardian.home.origin)
		assert_true(_joined(guard, _post_floor(guardian)), "%s: shut in with the guardian's post" % label)
		assert_true(_joined(guard, reward), "%s: shut in with the reward's spot %s" % [label, reward])
		# the doors slammed behind his back: the leash calms it, all opens
		var outside: Variant = _outside(plan, guardian.arena_room)
		assert_not_null(outside, "%s: a point outside its door" % label)
		if outside != null:
			_put_guard(outside)
			await _seconds(Guardian.LEASH_TIME + 0.6)
			assert_eq(guardian.state, Guardian.State.DORMANT, "%s calms with the guard outside" % label)
			_arena_open(plan.id, "%s calmed" % label)
		# its fall: all opens, the seal and shard lie where he walks
		guardian = await _wake(plan)
		var fell := watch(guardian.defeated)
		guardian.health.apply_damage(guardian.health.current)
		guardian.call(&"_die", DamageInfo.make(1.0, DamageInfo.Kind.BALLISTIC, museum.player))
		await physics_frames(3)
		assert_eq(fell.size(), 1, "%s falls" % label)
		assert_true(GameState.is_guardian_defeated(plan.id), "%s recorded" % label)
		_arena_open(plan.id, "%s fallen" % label)
		await _rebaked()
		var rewards := keeper.get_children().filter(func(n: Node) -> bool: return n is ProgressPickup and (n as Node3D).global_position.distance_to(reward) < 1.5)
		assert_eq(rewards.size(), int(plan.seal != &"") + int(plan.shard != &""), "%s: its seal and shard lie on the reward spot" % label)
		for pickup: Node3D in rewards:
			assert_true(_joined(museum.player.global_position, pickup.global_position), "%s: its reward %s walked to" % [label, pickup.name])
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game())
	for plan in Floor1Plan.guardians():
		assert_true(on_disk.is_guardian_defeated(plan.id), "%s's fall saved at once" % plan.id)
	on_disk.free()


## The night after a fight ended by [param ending] (death, dawn, menu): the
## guardian of [param id] asleep on its post, its arena open, the guard in
## a haven.
func _after_the_fight(id: StringName, ending: String) -> void:
	GameState.new_game()
	GameState.night = 2
	GameState.save_game()
	_museum()
	await physics_frames(3)
	var plan := Floor1Plan.guardian(id)
	var guardian := await _wake(plan)
	assert_true(guardian.is_fighting(), "%s awake" % id)
	assert_gt((_keeper().sealed.get(id, []) as Array).size(), 0, "%s: the arena shut" % id)
	var night := GameState.night
	match ending:
		"death":
			museum.player.set(&"_grace", 0.0)
			museum.player.take_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BLUNT))
			assert_eq(GameState.night, night + 1, "death ends the night")
		"dawn":
			museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.1
			await _seconds(0.4)
			assert_true(guardian.is_frozen(), "the guardian turned to stone")
			assert_eq(GameState.night, night + 1, "dawn ends the night")
		"menu":
			museum.quit_to_menu()
	museum.free()
	RunState.reset()
	# a fresh run of the game: what the save says
	GameState.reset()
	assert_true(GameState.load_game(), "the save loads")
	_museum()
	await physics_frames(3)
	var again: Guardian = _keeper().guardians.get(id)
	assert_not_null(again, "%s stands again (%s)" % [id, ending])
	if again != null:
		assert_eq(again.state, Guardian.State.DORMANT, "%s asleep after the %s" % [id, ending])
		var post: Vector3 = (museum.floor_level.markers[plan.marker] as Transform3D).origin
		# (on the floor plan: the Lamassu sleeps up on its plinth)
		assert_lt(Vector2(again.global_position.x - post.x, again.global_position.z - post.z).length(), 0.5, "%s on its post" % id)
	assert_false(GameState.is_guardian_defeated(id), "not counted as fallen")
	_arena_open(id, "%s after the %s" % [id, ending])
	var in_haven := false
	for haven: Haven in museum.havens.values():
		in_haven = in_haven or haven.contains(museum.player.global_position)
	assert_true(in_haven, "the guard starts in a haven after the %s" % ending)


func test_death_in_the_lamassus_fight_leaves_its_arena_open_the_next_night() -> void:
	await _after_the_fight(&"lamassu", "death")


func test_dawn_in_the_centaurs_fight_leaves_its_arena_open_the_next_night() -> void:
	await _after_the_fight(&"centaur", "dawn")


func test_leaving_the_serpents_fight_resumes_with_its_arena_open() -> void:
	await _after_the_fight(&"serpent", "menu")


func test_death_in_the_generals_fight_leaves_its_arena_open_the_next_night() -> void:
	await _after_the_fight(&"general", "death")


func test_a_guardian_lost_out_of_the_world_gives_the_fight_up() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(3)
	var plan := Floor1Plan.guardian(&"colossus")
	var guardian := await _wake(plan)
	assert_true(guardian.is_fighting())
	# knocked through the floor (a physics glitch): the guard shut in the
	# arena could neither win nor leave - the fight gives up instead and
	# the guardian is back on its post (the guard still in the arena wakes
	# it again there: a fight he can win)
	var calmed := watch(guardian.calmed)
	guardian.global_position = guardian.home.origin - Vector3.UP * (Guardian.LOST_DROP + 2.0)
	await _seconds(0.5)
	assert_eq(calmed.size(), 1, "the lost fight is given up")
	assert_lt(guardian.global_position.distance_to(guardian.home.origin), 1.0, "back on its post")
	# and with the guard gone from the arena it stays asleep, the arena open
	guardian.global_position = guardian.home.origin - Vector3.UP * (Guardian.LOST_DROP + 2.0)
	_put_guard(_outside(plan, guardian.arena_room))
	await _seconds(0.5)
	assert_eq(guardian.state, Guardian.State.DORMANT, "asleep")
	_arena_open(&"colossus", "the colossus lost")
