extends TestCase

var target: TargetDummy
var wolf: Wolf


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, -5)
	add_child(target)
	wolf = Wolf.new()
	wolf.target = target
	add_child(wolf)


func test_pounce_covers_the_distance_and_bites() -> void:
	await physics_frames(2)
	wolf.brain.wake()
	await physics_frames(130)   # (a 0.6 s suspicion, a 0.6 s crouch, the pounce)
	assert_lt(wolf.global_position.distance_to(target.global_position), 2.0)
	assert_gt(target.hits.size(), 0)


func test_two_pistol_shots_kill_a_wolf() -> void:
	var destroyed := watch(Events.enemy_destroyed)
	for i in 2:
		wolf.take_damage(DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, target))
	assert_eq(destroyed.size(), 1)


func test_one_bite_per_pounce() -> void:
	var strikes := watch(wolf.brain.strike)
	await physics_frames(2)
	wolf.brain.wake()
	for i in 180:
		if strikes.size() == 1 and wolf.brain.state == EnemyBrain.State.HUNT:
			break
		await get_tree().physics_frame
	assert_eq(strikes.size(), 1, "one pounce")
	assert_eq(target.hits.size(), 1)


func test_no_bite_while_recovering_from_a_missed_pounce() -> void:
	await physics_frames(2)
	wolf.brain.wake()
	for i in 180:
		if wolf.brain.has_struck() and not wolf.is_on_floor():
			break
		await get_tree().physics_frame
	target.position = Vector3(15, 0, 0)   # dodges while the wolf is in the air
	for i in 120:
		if wolf.is_on_floor():
			break
		await get_tree().physics_frame
	await physics_frames(3)
	assert_true(wolf.brain.has_struck(), "still recovering")
	target.position = wolf.global_position + wolf.global_transform.basis.z * 1.2   # steps in behind it
	await physics_frames(3)
	assert_eq(target.hits.size(), 0)


func test_no_bite_through_the_floor_above() -> void:
	Greybox.box(self, Vector3(0, 3.5, -17.5), Vector3(20, 0.5, 9), Color.GRAY)
	target.position = Vector3(0, 3.75, -14)
	wolf.position = Vector3(0, 0, -12.5)
	await physics_frames(2)
	wolf.brain.wake()
	await physics_frames(120)
	assert_eq(target.hits.size(), 0)


# --- the diorama: prowling and the trail (ecology) ------------------------------------

func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func test_the_guards_trail_is_laid_and_fades() -> void:
	target.position = Vector3(20, 0, 20)   # out of the wolf's sight
	await physics_frames(2)
	assert_eq(PerceptionWorld.trail().size(), 1, "where he stands")
	for i in 120:
		target.position.x -= 0.1   # 12 m in 2 s
		await get_tree().physics_frame
	var crumbs := PerceptionWorld.trail()
	assert_gt(crumbs.size(), 6, "a crumb every %.1f m (%d)" % [PerceptionWorld.TRAIL_STEP, crumbs.size()])
	assert_almost_eq(PerceptionWorld.freshest_crumb(Vector3(8, 0, 20), 3.0).x, 8.0, PerceptionWorld.TRAIL_STEP, "the freshest crumb near the end of his walk")
	assert_eq(PerceptionWorld.freshest_crumb(Vector3(-20, 0, -20), 3.0), Vector3.INF, "none near there")
	await _seconds(PerceptionWorld.TRAIL_LIFE + 1.0)
	assert_eq(PerceptionWorld.trail().size(), 0, "the trail fades")


func test_an_awake_wolf_prowls_its_diorama() -> void:
	target.position = Vector3(0, 0, 40)
	await physics_frames(2)
	assert_almost_eq(wolf.brain.roam_radius, EnemyRoles.roam(&"wolf"), 0.001, "a wolf without a route roams")
	wolf.brain.start_patrol()
	var places: Array[Vector3] = []
	for i in 20 * Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		if wolf.brain.walking() and (places.is_empty() or not places[places.size() - 1].is_equal_approx(wolf.brain.goal)):
			places.append(wolf.brain.goal)
	assert_gt(places.size(), 1, "it prowls from place to place (%d)" % places.size())
	for place in places:
		assert_lt(Vector2(place.x, place.z).length(), EnemyRoles.roam(&"wolf") + 0.01, "within its diorama: %s" % place)
	assert_eq(wolf.brain.state, EnemyBrain.State.PATROL, "calm all the while")


func test_a_prowling_wolf_sniffs_the_trail_of_a_guard_it_cannot_see() -> void:
	Greybox.box(self, Vector3(2.5, 1.5, 0), Vector3(0.3, 3, 40), Color.GRAY)   # a wall between them
	target.position = Vector3(5, 0, -12)
	await physics_frames(2)
	wolf.brain.roam_radius = 0.0   # (it stays where the test says)
	wolf.brain.start_patrol()
	for i in 120:
		target.position.z += 0.2   # he walks past behind the wall, 5 m off
		await get_tree().physics_frame
	# the crumbs he dropped by it are old enough to smell 3 s on, and the
	# nose goes to them every 3 s
	await _seconds(Wolf.SNIFF_MIN_AGE + 4.0)
	assert_true(wolf.sniffing() or wolf.brain.state == EnemyBrain.State.INVESTIGATE or wolf.brain.state == EnemyBrain.State.SEARCH, "on the scent (%s)" % EnemyBrain.State.keys()[wolf.brain.state])
	assert_ne(wolf.brain.state, EnemyBrain.State.HUNT, "it never saw him")
	assert_gt(wolf.brain.last_known.x, 3.5, "it goes to where he walked, not to him: %s" % wolf.brain.last_known)
	assert_true(wolf.brain.quiet, "a sniff wakes nobody")


# --- the nose has limits (review 19.10) -----------------------------------------------

## A wolf with no wandering to do, so that where it stands is where the test says.
func _still_wolf() -> void:
	wolf.brain.roam_radius = 0.0
	wolf.brain.start_patrol()


func test_a_wolf_does_not_smell_the_guard_himself_through_a_wall() -> void:
	# the crumb he is dropping now is not a trail: it was a steady "he is
	# there" through any wall within range
	Greybox.box(self, Vector3(2.5, 1.5, 0), Vector3(0.3, 3, 40), Color.GRAY)
	target.position = Vector3(5, 0, 0)
	await physics_frames(2)
	_still_wolf()
	await _seconds(Wolf.SNIFF_MIN_AGE - 0.6)
	assert_eq(wolf.brain.state, EnemyBrain.State.PATROL, "calm: nothing to sniff yet")
	assert_false(wolf.sniffing())


func test_a_wolf_smells_no_trail_beyond_6_m() -> void:
	Greybox.box(self, Vector3(2.5, 1.5, 0), Vector3(0.3, 3, 40), Color.GRAY)
	target.position = Vector3(8, 0, -6)
	await physics_frames(2)
	_still_wolf()
	for i in 120:
		target.position.z += 0.1   # he walks past, 8 m off
		await get_tree().physics_frame
	await _seconds(8.0)
	assert_eq(wolf.brain.state, EnemyBrain.State.PATROL, "8 m is out of its nose (%.0f m)" % Wolf.SNIFF_RANGE)
	assert_eq(Wolf.SNIFF_RANGE, 6.0)
