extends TestCase
## The exhibits' ecology (backlog #8, #24, #25) in a greybox world: graded
## reactions to what happens round them (a shot brings some, not all; a
## fallen neighbour draws the ones that gather; a door opening calls the
## guards; a blast sends the skittish fleeing; nothing re-wakes a whole
## floor), and the routines of the calm (stirring in their sleep when
## nobody looks, with the LOD that keeps them still far from the guard).

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(160, 1, 160), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 70)   # far away, out of everyone's sight
	add_child(target)


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


## An exhibit at [param at] facing [param toward] (null = -Z), asleep
## unless [param awake]; its die seeded with [param seed] (reactions roll
## on it), so a test reads the same every run.
func _exhibit(kind: GDScript, at: Vector3, toward: Variant = null, awake: bool = false, seed_value: int = 1) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = target
	enemy.starts_awake = awake
	enemy.brain.rng.seed = seed_value
	add_child(enemy)
	if toward != null:
		enemy.face(toward)
	return enemy


func _count(exhibits: Array, state: EnemyBrain.State) -> int:
	return exhibits.filter(func(e: Enemy) -> bool: return e.brain.state == state).size()


## A die seed whose first roll lies above (or below) [param limit]: the
## exhibit rolls it on the first noise it hears.
func _seed_rolling(above: bool, limit: float) -> int:
	var dice := RandomNumberGenerator.new()
	for candidate in range(1, 2000):
		dice.seed = candidate
		var roll := dice.randf()
		if roll > limit if above else roll < limit:
			return candidate
	return 1


# --- reactions to events -----------------------------------------------------------

func test_a_shot_brings_some_of_the_nearby_figures_not_all() -> void:
	var figures: Array[Enemy] = []
	for i in 6:
		var angle := TAU * i / 6.0
		figures.append(_exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * 15.0, Vector3.ZERO, false, 11 + i))
	await physics_frames(2)
	var heard := PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"pistol"), &"pistol")
	assert_eq(heard, 6, "every figure heard it (15 m of 18)")
	await _seconds(1.2)
	var investigating := _count(figures, EnemyBrain.State.INVESTIGATE)
	assert_gt(investigating, 0, "at least the nearest comes to look")
	assert_lt(investigating, ReactionRules.INVESTIGATE_CAP + 1, "never more than %d" % ReactionRules.INVESTIGATE_CAP)
	assert_gt(_count(figures, EnemyBrain.State.DORMANT), 0, "the others turned their heads and settled again")
	assert_eq(_count(figures, EnemyBrain.State.HUNT), 0, "a noise is never a hunt")


func test_the_investigators_are_the_nearest_ones() -> void:
	var near := _exhibit(WaxFigure, Vector3(0, 0, -3), Vector3.ZERO, false, 3)
	var far: Array[Enemy] = []
	for i in 5:
		far.append(_exhibit(WaxFigure, Vector3(-8 + 4 * i, 0, -16), Vector3.ZERO, false, 20 + i))
	await physics_frames(2)
	PerceptionWorld.noise(Vector3.ZERO, 18.0, &"pistol")
	await _seconds(1.2)
	assert_eq(near.brain.state, EnemyBrain.State.INVESTIGATE, "3 m away: it comes whatever it rolled")
	assert_lt(_count(far, EnemyBrain.State.INVESTIGATE), ReactionRules.INVESTIGATE_CAP, "the far ones fill at most the places left")


func test_a_fallen_exhibit_draws_the_neighbours_that_gather() -> void:
	var fallen := _exhibit(WaxFigure, Vector3.ZERO, Vector3(0, 0, -10), false, 1)
	var left := _exhibit(WaxFigure, Vector3(-5, 0, 0), Vector3(-5, 0, -10), false, 2)
	var right := _exhibit(WaxFigure, Vector3(5, 0, 0), Vector3(5, 0, -10), false, 3)
	var wolf := _exhibit(Wolf, Vector3(0, 0, 6), Vector3(0, 0, 16), false, 4)   # wolves do not gather
	await physics_frames(2)
	var info := DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC, target)
	info.direction = Vector3(0, 0, 1)
	info.position = fallen.global_position + Vector3.UP
	fallen.take_damage(info)
	assert_true(fallen.is_queued_for_deletion())
	assert_ne(left.brain.state, EnemyBrain.State.DORMANT, "the crash of a neighbour: it turns")
	assert_ne(right.brain.state, EnemyBrain.State.DORMANT)
	await _seconds(1.2)
	var gathered: Array = [left, right].filter(func(e: Enemy) -> bool: return e.brain.state == EnemyBrain.State.INVESTIGATE)
	assert_gt(gathered.size(), 0, "at least one comes to the fallen one")
	for enemy: Enemy in gathered:
		assert_lt(enemy.brain.goal.distance_to(Vector3.ZERO), 0.5, "to where it fell")
	assert_eq(_count([left, right, wolf], EnemyBrain.State.HUNT), 0, "nobody hunts over a fallen friend")


func test_a_door_opening_calls_the_guard_the_figure_only_looks() -> void:
	var spec := OpeningSpec.make(&"test_door", Rect2(-1, -0.25, 2, 0.5), 0.0, 2.5, &"a", &"b", OpeningSpec.DoorStyle.SWING, RoomGraph.Kind.LOCKABLE)
	spec.start_open = false
	var door := Door.make(spec, Transform3D.IDENTITY, Color(0.5, 0.45, 0.4))
	add_child(door)
	var knight := _exhibit(Knight, Vector3(0, 0, 6), Vector3(0, 0, -10), false, 5)
	var figure := _exhibit(WaxFigure, Vector3(3, 0, 6), Vector3(3, 0, -10), false, 6)
	await physics_frames(2)
	knight.brain.rng.seed = _seed_rolling(false, 0.2)   # (the guard answers a door about one time in three)
	assert_false(door.is_open)
	var creaks := watch(Events.door_creaked)
	door.open()
	assert_eq(creaks.size(), 1, "an opening door makes a noise")
	if creaks.size() == 1:
		assert_eq(creaks[0][1], PerceptionRules.DOOR_NOISE)
		assert_eq(creaks[0][2], &"a", "it belongs to the rooms either side of it")
		assert_eq(creaks[0][3], &"b")
	assert_eq(knight.brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_eq(figure.brain.state, EnemyBrain.State.SUSPICIOUS, "it turns its head too")
	await _seconds(1.3)
	assert_eq(knight.brain.state, EnemyBrain.State.INVESTIGATE, "the guard goes to the door")
	assert_lt(Vector2(knight.brain.goal.x, knight.brain.goal.z).length(), 1.0, "to the doorway")
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "the figure looked and settled")
	door.close(true)
	creaks.clear()
	door.open(true)
	assert_eq(creaks.size(), 0, "a door set open at once (the level's scripts) makes no noise")


func test_a_blast_sends_a_swarm_fleeing_then_home() -> void:
	var swarm := _exhibit(ScarabSwarm, Vector3.ZERO, Vector3(0, 0, -10), false, 2)
	await physics_frames(2)
	var noises := watch(Events.noise_made)
	Blast.explode(self, Vector3(0, 0.3, -4), 2.5, 10.0, 5.0, DamageInfo.Kind.FIRE, null)
	assert_eq(noises.size(), 1, "a blast is heard where it bursts")
	if noises.size() == 1:
		assert_eq(noises[0][2], ReactionRules.SOURCE_BLAST)
		assert_eq(noises[0][1], PerceptionRules.BLAST_NOISE)
	assert_eq(swarm.brain.state, EnemyBrain.State.FLEE, "the swarm flees (seed 2 rolls under its skittishness)")
	await _seconds(2.0)
	assert_gt(swarm.global_position.z, 3.0, "away from the blast: %s" % swarm.global_position)
	await _seconds(4.0)
	# a disturbed swarm never heaps up again: home, it streams (PATROL) -
	# here, with no walls round it to stream along, it holds its post
	var state := swarm.brain.state
	assert_true(state == EnemyBrain.State.RETURN or state == EnemyBrain.State.PATROL, "then it goes home (%s)" % EnemyBrain.State.keys()[state])
	if state == EnemyBrain.State.PATROL:
		assert_lt(Vector2(swarm.global_position.x, swarm.global_position.z).length(), EnemyBrain.ARRIVE + 0.3, "back at its post: %s" % swarm.global_position)


func test_nothing_re_wakes_the_whole_floor() -> void:
	var crowd: Array[Enemy] = []
	for i in 20:
		var angle := TAU * i / 20.0
		var radius := 12.0 + 13.0 * (i % 4) / 3.0
		crowd.append(_exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * radius, Vector3.ZERO, false, 40 + i))
	await physics_frames(2)
	PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"gatling"), &"gatling")
	await _seconds(1.5)
	assert_lt(_count(crowd, EnemyBrain.State.INVESTIGATE), ReactionRules.INVESTIGATE_CAP + 1, "at most three come to look")
	assert_eq(_count(crowd, EnemyBrain.State.HUNT), 0)
	assert_gt(_count(crowd, EnemyBrain.State.DORMANT), 14, "the rest looked up and sleep on")


func test_a_burst_of_fire_gets_no_more_up_than_one_shot() -> void:
	var crowd: Array[Enemy] = []
	for i in 20:
		var angle := TAU * i / 20.0
		var radius := 12.0 + 13.0 * (i % 4) / 3.0
		crowd.append(_exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * radius, Vector3.ZERO, false, 70 + i))
	await physics_frames(2)
	for shot in 12:   # three seconds of gatling fire from one spot
		PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"gatling"), &"gatling")
		await _seconds(0.25)
	await _seconds(1.5)
	var up := _count(crowd, EnemyBrain.State.INVESTIGATE) + _count(crowd, EnemyBrain.State.SEARCH)
	assert_gt(up, 0, "some came to look")
	assert_lt(up, ReactionRules.INVESTIGATE_CAP + 1, "never more than %d over the burst (%d)" % [ReactionRules.INVESTIGATE_CAP, up])
	assert_eq(_count(crowd, EnemyBrain.State.HUNT), 0)
	assert_gt(_count(crowd, EnemyBrain.State.DORMANT), 14, "the rest looked up and sleep on")
	await _seconds(ReactionRules.SEND_WINDOW)
	var sleepers: Array = crowd.filter(func(e: Enemy) -> bool: return e.brain.state == EnemyBrain.State.DORMANT)
	PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"gatling"), &"gatling")
	await _seconds(1.2)
	assert_gt(_count(sleepers, EnemyBrain.State.INVESTIGATE), 0, "a while later a new shot gets a sleeper up again")


## A lone exhibit of [param kind] [param distance] m from a noise of
## [param source] ([param radius] m) whose die rolls too high to bother: what
## it does about it.
func _lone_answer(kind: GDScript, source: StringName, radius: float, distance: float) -> EnemyBrain.State:
	PerceptionWorld.reset()
	var exhibit := _exhibit(kind, Vector3(0, 0, distance), Vector3(0, 0, distance + 10.0), false, 1)
	await physics_frames(2)
	exhibit.brain.rng.seed = _seed_rolling(true, 0.97)
	PerceptionWorld.noise(Vector3.ZERO, radius, source)
	await _seconds(1.5)
	var state := exhibit.brain.state
	exhibit.free()
	return state


func test_a_shot_still_sends_the_nearest_a_door_or_a_fall_does_not() -> void:
	assert_eq(await _lone_answer(WaxFigure, &"pistol", 18.0, 17.0), EnemyBrain.State.INVESTIGATE, "a shot: the lone listener comes whatever it rolled")
	# a knight 6 m from a door and a figure 10 m from a fall, both rolling high:
	# they only look (the old rule made the nearest curious one walk over every time)
	assert_ne(await _lone_answer(Knight, ReactionRules.SOURCE_DOOR, PerceptionRules.DOOR_NOISE, 6.0), EnemyBrain.State.INVESTIGATE, "a door forces nobody")
	assert_ne(await _lone_answer(WaxFigure, ReactionRules.SOURCE_FALL, PerceptionRules.FALL_NOISE, 10.0), EnemyBrain.State.INVESTIGATE, "a crash forces nobody")


func test_a_sound_sleeper_sleeps_through_the_soft_noises_but_not_a_shot() -> void:
	var figure := _exhibit(WaxFigure, Vector3(0, 0, 5), Vector3(0, 0, 15), false, 1)
	figure.sound_asleep = 60.0   # the gentle start of night 1
	await physics_frames(2)
	for soft: Array in [[ReactionRules.SOURCE_DOOR, PerceptionRules.DOOR_NOISE], [ReactionRules.SOURCE_FALL, PerceptionRules.FALL_NOISE],
			[&"sprint", PerceptionRules.STEP_NOISE], [&"landing", PerceptionRules.STEP_NOISE]]:
		figure.brain.rng.seed = _seed_rolling(false, 0.05)   # a roll that would bring it
		PerceptionWorld.noise(Vector3.ZERO, soft[1], soft[0])
		assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "%s: it sleeps soundly through it" % soft[0])
	PerceptionWorld.noise(Vector3.ZERO, 18.0, &"pistol")
	assert_ne(figure.brain.state, EnemyBrain.State.DORMANT, "a shot wakes it as ever")


## Review 19.10: the flare's small burst woke everything within 30 m.
func test_a_flares_burst_is_heard_15_m_round_a_rockets_30() -> void:
	var near := _exhibit(WaxFigure, Vector3(0, 0, 10), Vector3(0, 0, -10), false, 1)
	var far := _exhibit(WaxFigure, Vector3(0, 0, 22), Vector3(0, 0, -10), false, 2)
	await physics_frames(2)
	var noises := watch(Events.noise_made)
	Blast.explode(self, Vector3(0, 0.3, 0), 2.5, 5.0, 0.0, DamageInfo.Kind.FIRE, null, Vector3.FORWARD, &"flare")
	assert_eq(noises.size(), 1)
	if noises.size() == 1:
		assert_eq(noises[0][1], 15.0, "a flare's burst is heard 15 m round")
		assert_eq(noises[0][2], ReactionRules.SOURCE_BLAST)
	assert_ne(near.brain.state, EnemyBrain.State.DORMANT, "10 m: heard")
	assert_eq(far.brain.state, EnemyBrain.State.DORMANT, "22 m: lighting a gallery with a flare wakes nobody there")
	noises.clear()
	Blast.explode(self, Vector3(0, 0.3, 0), 2.5, 5.0, 0.0, DamageInfo.Kind.FIRE, null, Vector3.FORWARD, &"hwacha")
	if noises.size() == 1:
		assert_eq(noises[0][1], 30.0, "a rocket's 30 m")
	assert_ne(far.brain.state, EnemyBrain.State.DORMANT, "a rocket is heard at 22 m")


## The listeners that cannot answer (a wreck, stone, a hunt on) must not
## take the one place a plain noise always has for a visitor: a lone sleeper
## far off (low closeness, a roll that would not bring it) is the one who
## comes. [param busy] makes the exhibit near the shot unable to.
func _far_sleeper_answer(busy: Callable) -> EnemyBrain.State:
	var blocker := _exhibit(WaxFigure, Vector3(0, 0, 4), Vector3(0, 0, -10), false, 3)
	var sleeper := _exhibit(WaxFigure, Vector3(0, 0, 17), Vector3(0, 0, 27), false, 4)
	await physics_frames(2)
	await busy.call(blocker)
	sleeper.brain.rng.seed = _seed_rolling(true, 0.97)
	PerceptionWorld.noise(Vector3.ZERO, 18.0, &"pistol")
	await _seconds(1.0)
	return sleeper.brain.state


func test_a_frozen_exhibit_does_not_take_the_visitors_place() -> void:
	var state := await _far_sleeper_answer(func(blocker: Enemy) -> void: blocker.freeze())
	assert_eq(state, EnemyBrain.State.INVESTIGATE, "the stone one near the shot leaves the looking to the only one who can")


func test_a_hunter_does_not_take_the_visitors_place() -> void:
	var state := await _far_sleeper_answer(func(blocker: Enemy) -> void:
		blocker.brain.wake()
		await _seconds(1.2)
		assert_true(blocker.brain.is_hunting(), "(it hunts)"))
	assert_eq(state, EnemyBrain.State.INVESTIGATE, "a hunter has nothing to look into")


func test_a_wreck_does_not_take_the_visitors_place() -> void:
	var state := await _far_sleeper_answer(func(blocker: Enemy) -> void:
		var info := DamageInfo.make(500.0, DamageInfo.Kind.BALLISTIC, target)
		info.direction = Vector3(0, 0, 1)
		info.position = blocker.global_position + Vector3.UP
		blocker.take_damage(info)
		assert_true(blocker.is_queued_for_deletion(), "(it fell)"))
	assert_eq(state, EnemyBrain.State.INVESTIGATE, "the one that just crashed down hears nothing")


## [param count] sleepers on rings round the origin ([param inner] to
## [param outer] m), all facing it.
func _crowd_round_the_origin(count: int, inner: float, outer: float, first_seed: int) -> Array[Enemy]:
	var crowd: Array[Enemy] = []
	for i in count:
		var angle := TAU * i / count
		var radius := inner + (outer - inner) * (i % 4) / 3.0
		crowd.append(_exhibit(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * radius, Vector3.ZERO, false, first_seed + i))
	return crowd


func _up(crowd: Array[Enemy]) -> int:
	return crowd.filter(func(e: Enemy) -> bool: return e.brain.state != EnemyBrain.State.DORMANT).size()


func _hunting(crowd: Array[Enemy]) -> int:
	return crowd.filter(func(e: Enemy) -> bool: return e.brain.is_hunting()).size()


func _waiting(crowd: Array[Enemy]) -> int:
	return crowd.filter(func(e: Enemy) -> bool: return e.brain.waiting()).size()


## The guard fires at his own feet with twenty sleepers in earshot, none of
## them near enough to see him: three come to look (and find him), the rest
## look up and sleep on - hunters and the waiting over the cap together stay
## within the hunter cap.
func test_a_shot_at_the_guard_with_a_crowd_in_earshot_sends_three_and_the_rest_sleep_on() -> void:
	target.position = Vector3.ZERO
	var crowd := _crowd_round_the_origin(20, 24.0, 29.0, 100)
	await physics_frames(2)
	PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"gatling"), &"gatling")
	var most_busy := 0
	for second in 40:
		await _seconds(1.0)
		most_busy = maxi(most_busy, _hunting(crowd) + _waiting(crowd))
		if second == 1:
			assert_lt(_up(crowd), ReactionRules.INVESTIGATE_CAP + 1, "two seconds on: the three sent to look, the others looked up and slept (%d up)" % _up(crowd))
		assert_lt(_up(crowd), 10, "second %d: never the whole floor awake (%d)" % [second + 1, _up(crowd)])
	assert_gt(most_busy, 0, "(they did find him)")
	assert_lt(most_busy, PerceptionWorld.hunter_cap + 1, "hunters and waiters together within the hunter cap (%d)" % most_busy)
	assert_gt(_count(crowd, EnemyBrain.State.DORMANT), 10, "the rest looked up and slept on (%d asleep)" % _count(crowd, EnemyBrain.State.DORMANT))


## The same crowd, near enough to see him once they look up (a shot is
## where he stands): everyone who sees him hunts - up to the cap - or waits
## at the edge; the ones beyond his light sleep on, and nobody roams about.
func test_a_crowd_that_sees_the_shooter_hunts_within_the_cap_and_waits_outside_it() -> void:
	target.position = Vector3.ZERO
	var crowd := _crowd_round_the_origin(20, 14.0, 26.0, 100)
	await physics_frames(2)
	PerceptionWorld.noise(Vector3.ZERO, PerceptionRules.weapon_noise(&"gatling"), &"gatling")
	var most_hunting := 0
	for second in 20:
		await _seconds(1.0)
		most_hunting = maxi(most_hunting, _hunting(crowd))
	assert_lt(most_hunting, PerceptionWorld.hunter_cap + 1, "at most the hunter cap hunt (%d)" % most_hunting)
	assert_eq(_up(crowd), _hunting(crowd) + _waiting(crowd), "the rest of those awake wait at the edge: nobody roams about")
	assert_gt(_count(crowd, EnemyBrain.State.DORMANT), 4, "the ring beyond his light sleeps on (%d asleep)" % _count(crowd, EnemyBrain.State.DORMANT))


func test_a_look_is_quiet_an_investigation_rouses_as_before() -> void:
	# a figure that only looks wakes no neighbour; one that goes to look may
	# rouse two (the chain rule stands)
	var looker := _exhibit(WaxFigure, Vector3(0, 0, -16), Vector3.ZERO, false, 7)
	var sleeper := _exhibit(WaxFigure, Vector3(2, 0, -16), Vector3.ZERO, false, 8)
	await physics_frames(2)
	looker.react(Vector3.ZERO, &"", ReactionRules.Reaction.LOOK)
	assert_eq(looker.brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_true(looker.brain.quiet, "a look makes no call")
	assert_eq(sleeper.brain.state, EnemyBrain.State.DORMANT, "and wakes nobody")
	await _seconds(1.0)
	assert_eq(looker.brain.state, EnemyBrain.State.DORMANT)
	assert_false(looker.brain.quiet, "settled: it may call again")


# --- stirring in their sleep (the uncanny), and the LOD ---------------------------------

## The target stands at the origin looking down -Z; a sleeper behind it
## (+Z) is out of its view.
func _sleeper_behind(kind: GDScript, distance: float, seed_value: int = 1) -> Enemy:
	target.position = Vector3.ZERO
	return _exhibit(kind, Vector3(0, 0, distance), Vector3(0, 0, distance + 10.0), false, seed_value)


func test_a_wax_figure_creeps_up_while_the_guard_looks_away() -> void:
	var figure := _sleeper_behind(WaxFigure, 16.0)   # beyond a sleeper's sight (13.2 m lit), within its stir
	await physics_frames(2)
	var start := figure.global_position
	await _seconds(4.0)
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "still asleep: a stir is not a hunt")
	assert_gt(figure.stirs, 3, "it stirred (%d)" % figure.stirs)
	assert_gt(start.z - figure.global_position.z, 0.5, "it crept toward him: %.2f m" % (start.z - figure.global_position.z))
	# a half turn takes nine ticks of STIR_TURN (the ticks come every
	# 0.4-0.6 s): give it the time
	await _seconds(2.0)
	var facing := -figure.global_transform.basis.z
	assert_gt(facing.dot(Vector3(0, 0, -1)), 0.9, "turned to face him")


func test_it_freezes_while_he_looks_at_it() -> void:
	var figure := _sleeper_behind(WaxFigure, 16.0)
	target.rotation.y = PI   # looking up +Z: straight at it
	await physics_frames(2)
	var start := figure.global_transform
	await _seconds(3.0)
	assert_eq(figure.stirs, 0, "watched: not a twitch")
	assert_true(figure.global_transform.origin.is_equal_approx(start.origin))
	assert_true(figure.global_transform.basis.is_equal_approx(start.basis))


func test_the_watched_arc_covers_the_whole_picture() -> void:
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	var arc := Enemy.watch_half_arc(camera)
	var size := camera.get_viewport().get_visible_rect().size
	var wide := rad_to_deg(atan(tan(deg_to_rad(35.0)) * size.x / size.y))
	assert_gt(arc, wide + Enemy.WATCH_MARGIN - 0.1, "the screen's edge and a margin: %.1f deg (%.1f on screen)" % [arc, wide])
	assert_gt(arc, Enemy.WATCH_HALF_ARC - 0.01)
	camera.queue_free()


func test_the_creep_never_goes_far_from_its_post() -> void:
	var figure := _sleeper_behind(WaxFigure, 18.0)
	await physics_frames(2)
	await _seconds(10.0)
	var from_home := Vector2(figure.global_position.x - figure.home.x, figure.global_position.z - figure.home.z).length()
	assert_lt(from_home, Enemy.STIR_REACH + 0.01, "at most %.1f m from its post (%.2f)" % [Enemy.STIR_REACH, from_home])
	assert_gt(from_home, 1.0, "but it did creep")
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT)


func test_far_from_the_guard_the_routine_sleeps() -> void:
	var near := _exhibit(WaxFigure, Vector3(0, 0, 40), Vector3(0, 0, 50))   # 30 m from the target at z = 70
	var far := _exhibit(WaxFigure, Vector3(0, 0, 20), Vector3(0, 0, 30))    # 50 m
	await physics_frames(2)
	await _seconds(2.0)
	assert_gt(near.routine_ticks, 2, "within %.0f m its routine ticks" % Enemy.ROUTINE_RANGE)
	assert_eq(far.routine_ticks, 0, "beyond it nothing ticks (LOD)")


func test_rooms_far_from_the_guards_sleep_too() -> void:
	# a row of rooms a | b | c | d along +Z (8 m each); the guard in a
	var graph := RoomGraph.new()
	graph.add_door(&"ab", &"a", &"b")
	graph.add_door(&"bc", &"b", &"c")
	graph.add_door(&"cd", &"c", &"d")
	PerceptionWorld.configure(Callable(), func(point: Vector3) -> StringName:
		return [&"a", &"b", &"c", &"d"][clampi(floori(point.z / 8.0), 0, 3)], graph, Callable())
	target.position = Vector3(0, 0, 2)
	var two_rooms_off := _exhibit(WaxFigure, Vector3(0, 0, 20), Vector3(0, 0, 30))     # c: 2 passages
	var three_rooms_off := _exhibit(WaxFigure, Vector3(3, 0, 28), Vector3(3, 0, 38))   # d: 3 passages
	await physics_frames(2)
	await _seconds(2.0)
	assert_gt(two_rooms_off.routine_ticks, 2, "%d passages from the guard: it ticks" % PerceptionWorld.ROUTINE_HOPS)
	assert_eq(three_rooms_off.routine_ticks, 0, "further off (26 m, within %.0f m): it does not" % Enemy.ROUTINE_RANGE)


func test_a_bust_turns_on_its_plinth_but_stays_put() -> void:
	var bust := _sleeper_behind(Bust, 16.0)
	await physics_frames(2)
	var start := bust.global_position
	await _seconds(4.0)
	assert_eq(bust.brain.state, EnemyBrain.State.DORMANT)
	assert_gt(bust.stirs, 3)
	await _seconds(2.0)   # the rest of its half turn (see above)
	assert_lt(Vector2(bust.global_position.x - start.x, bust.global_position.z - start.z).length(), 0.05, "a plinth goes nowhere")
	var facing := -bust.global_transform.basis.z
	assert_gt(facing.dot(Vector3(0, 0, -1)), 0.9, "but its head came round")


func test_within_its_sight_it_holds_still() -> void:
	# 10 m off, his back to it: turning round it would see him (13.2 m lit
	# asleep), so it does not turn - a sleeper's eyes stay where they were
	var figure := _sleeper_behind(WaxFigure, 10.0)
	await physics_frames(2)
	var start := figure.global_transform
	await _seconds(3.0)
	assert_eq(figure.stirs, 0, "within %.1f m of sight it holds still" % figure.sight_reach())
	assert_true(figure.global_transform.basis.is_equal_approx(start.basis), "still facing away")
	assert_eq(figure.brain.state, EnemyBrain.State.DORMANT, "and never saw him")


func test_nothing_creeps_up_on_a_haven() -> void:
	# the guard shelters in a haven (out of reach: no sight, no attacks - and
	# no sleeper sidling up to wait at its door)
	var haven := Haven.make(&"booth", AABB(Vector3(-3, 0, -3), Vector3(6, 3, 6)))
	add_child(haven)
	var figure := _sleeper_behind(WaxFigure, 16.0)   # where it would stir (see above)
	await physics_frames(2)
	var start := figure.global_transform
	await _seconds(3.0)
	assert_eq(figure.stirs, 0, "the guard is in a haven")
	assert_true(figure.global_transform.origin.is_equal_approx(start.origin))


func test_a_sound_sleeper_lies_still() -> void:
	var figure := _sleeper_behind(WaxFigure, 16.0)
	figure.sound_asleep = 60.0   # the gentle start of night 1
	await physics_frames(2)
	await _seconds(3.0)
	assert_eq(figure.stirs, 0)
