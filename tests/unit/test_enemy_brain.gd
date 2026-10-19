extends TestCase
## EnemyBrain: the exhibit state machine (design pietro-1-projekt 7.2).
## The brain stands at the origin; the guard is placed through brain.guard.

var brain: EnemyBrain


func before_each() -> void:
	brain = EnemyBrain.new()
	brain.reaction_time = 0.8
	brain.attack_range = 2.0
	brain.windup = 0.6
	brain.recovery = 0.7
	brain.rng.seed = 7
	brain.guard = Vector3(0, 0, -8)


# --- noticing -----------------------------------------------------------

func test_stays_dormant_until_it_sees_the_target() -> void:
	brain.update(1.0, false, INF)
	assert_eq(brain.state, EnemyBrain.State.DORMANT)
	brain.update(0.1, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_eq(brain.last_known, Vector3(0, 0, -8))


func test_sight_makes_it_suspicious_then_it_hunts() -> void:
	brain.update(0.1, true, 8.0)
	brain.update(0.5, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS, "the suspicion lasts its reaction time")
	brain.update(0.31, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)


func test_a_glimpse_is_enough_to_hunt() -> void:
	brain.update(0.1, true, 8.0)
	brain.update(0.9, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT, "it saw him: it hunts, with a moment of memory")


func test_a_noise_is_investigated_never_hunted() -> void:
	brain.hear(Vector3(10, 0, 0))
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.INVESTIGATE)
	assert_eq(brain.goal, Vector3(10, 0, 0))
	assert_eq(brain.last_known, Vector3(10, 0, 0))


func test_a_noise_out_of_its_bounds_only_turns_its_head() -> void:
	brain.hear(Vector3(40, 0, 0), false)
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.DORMANT)


func test_seen_while_investigating_means_hunted_at_once() -> void:
	brain.hear(Vector3(10, 0, 0))
	brain.update(0.81, false, INF)
	brain.update(0.1, true, 8.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)


func test_wake_is_the_full_alarm() -> void:
	brain.wake()
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_true(brain.knows_guard(), "it knows where the guard is")
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_eq(brain.last_known, Vector3(0, 0, -8))


func test_a_hit_tells_it_where_from() -> void:
	brain.alarm(Vector3(3, 0, 3))
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)
	assert_eq(brain.last_known, Vector3(3, 0, 3))
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)


# --- hunting and losing track ----------------------------------------------

func test_lost_sight_is_remembered_for_a_moment_then_searched() -> void:
	_to_hunt()
	brain.guard = Vector3(3, 0, -9)
	brain.update(1.0, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_true(brain.knows_guard())
	assert_eq(brain.last_known, Vector3(3, 0, -9), "tracked within the memory")
	brain.guard = Vector3(20, 0, -9)
	brain.update(0.6, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	assert_false(brain.knows_guard())
	assert_eq(brain.last_known, Vector3(3, 0, -9), "the last tracked point, not where he went")
	assert_eq(brain.goal, Vector3(3, 0, -9))


func test_it_follows_a_vanished_guard_only_a_short_way() -> void:
	_to_hunt()
	brain.guard = Vector3(0, 0, -38)   # gone 30 m further in a blink
	brain.update(0.5, false, INF)
	assert_eq(brain.last_seen, Vector3(0, 0, -8))
	assert_almost_eq(brain.last_known.distance_to(brain.last_seen), EnemyBrain.EXTRAPOLATE, 0.001, "a short extrapolation, not his real position")
	brain.update(1.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	assert_almost_eq(brain.goal.z, -8.0 - EnemyBrain.EXTRAPOLATE, 0.001)


func test_relentless_follows_him_anywhere() -> void:
	brain.relentless = true
	_to_hunt()
	brain.guard = Vector3(0, 0, -38)
	brain.update(0.5, false, INF)
	assert_eq(brain.last_known, Vector3(0, 0, -38))


func test_search_walks_there_looks_around_then_returns_home_to_sleep() -> void:
	brain.home = Vector3.ZERO
	_to_hunt()
	brain.update(EnemyBrain.MEMORY + 0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	assert_true(brain.walking())
	brain.position = brain.last_known   # arrived
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH, "now it looks around")
	var looked := _seconds_while(EnemyBrain.State.SEARCH, 12.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "then it goes home")
	assert_gt(looked, EnemyBrain.SEARCH_TIME.x - 0.05, "it looked around 6-10 s")
	assert_lt(looked, EnemyBrain.SEARCH_TIME.y + 0.15)
	assert_eq(brain.goal, Vector3.ZERO)
	brain.position = Vector3(0.3, 0, 0)
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "settling at its post")
	brain.update(EnemyBrain.SETTLE_TIME, false, INF)
	assert_eq(brain.state, EnemyBrain.State.DORMANT)


func test_a_search_point_it_cannot_reach_ends_the_walk() -> void:
	brain.home = Vector3(0, 0, 30)
	_to_hunt()
	brain.update(EnemyBrain.MEMORY + 0.1, false, INF)
	for i in 25:
		brain.update(0.1, false, INF)   # never gets closer: stalled
	assert_eq(brain.state, EnemyBrain.State.SEARCH, "stuck on the way: it looks around from there")
	assert_true(brain.looking_around())
	_seconds_while(EnemyBrain.State.SEARCH, 12.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	_seconds_while(EnemyBrain.State.RETURN, 5.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "never stalls into sleep on the way home")


func test_seen_while_searching_or_returning_means_hunted() -> void:
	_to_hunt()
	brain.update(EnemyBrain.MEMORY + 0.1, false, INF)
	brain.update(0.1, true, 9.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	brain.out_of_bounds = true
	brain.update(0.1, true, 9.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	brain.out_of_bounds = false
	brain.update(0.1, true, 9.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)


func test_haven_search_lasts_eight_seconds() -> void:
	_to_hunt()
	brain.guard_sheltered = true
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	assert_eq(brain.goal, Vector3(0, 0, -8), "at the haven's door, where he went in")
	brain.update(7.8, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	brain.update(0.25, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN)


func test_the_hunter_cap_makes_it_wait_at_the_edge() -> void:
	brain.may_hunt = false
	brain.guard = Vector3.ZERO
	brain.position = Vector3(0, 0, 20)
	brain.update(0.1, true, 20.0)
	brain.update(0.81, true, 20.0)
	assert_eq(brain.state, EnemyBrain.State.INVESTIGATE)
	assert_almost_eq(brain.goal.distance_to(Vector3.ZERO), EnemyBrain.WAIT_EDGE, 0.01)
	assert_almost_eq(brain.goal.z, EnemyBrain.WAIT_EDGE, 0.01, "on its own side")
	brain.may_hunt = true
	brain.update(0.1, true, 12.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)


func test_leaving_its_bounds_sends_it_home() -> void:
	brain.home = Vector3(0, 0, 30)
	_to_hunt()
	brain.out_of_bounds = true
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	assert_eq(brain.goal, Vector3(0, 0, 30))
	brain.out_of_bounds = false
	brain.guard_in_bounds = false
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "a guard beyond its leash is let go")
	brain.guard_in_bounds = true
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT, "back in its territory: the hunt is on")


func test_relentless_never_searches_nor_returns() -> void:
	brain.relentless = true
	_to_hunt()
	brain.out_of_bounds = true
	brain.guard_sheltered = true
	brain.update(5.0, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_true(brain.knows_guard())


# --- patrol -----------------------------------------------------------------

func test_a_patroller_walks_its_route_with_pauses() -> void:
	brain.patrol = PackedVector3Array([Vector3.ZERO, Vector3(6, 0, 0), Vector3(-6, 0, 0)])
	brain.start_patrol()
	assert_eq(brain.state, EnemyBrain.State.PATROL)
	brain.update(0.1, false, INF)
	brain.position = brain.goal
	brain.update(0.1, false, INF)
	assert_false(brain.walking(), "a pause at each point")
	brain.update(EnemyBrain.PATROL_PAUSE, false, INF)
	brain.update(0.1, false, INF)
	assert_true(brain.walking())
	var next := brain.goal
	brain.position = next
	brain.update(0.1, false, INF)
	brain.update(EnemyBrain.PATROL_PAUSE + 0.1, false, INF)
	assert_ne(brain.goal, next, "on to the next point")


func test_a_patroller_goes_back_to_patrolling() -> void:
	brain.patrol = PackedVector3Array([Vector3.ZERO, Vector3(6, 0, 0)])
	brain.start_patrol()
	brain.hear(Vector3(3, 0, 0), false)
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.PATROL)


# --- attacks, stun, destroy -------------------------------------------------------

func test_hunt_attacks_only_in_range() -> void:
	_to_hunt()
	brain.update(0.1, true, 5.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	brain.update(0.1, true, 1.5)
	assert_eq(brain.state, EnemyBrain.State.ATTACK)


func test_strike_fires_once_after_windup_then_recovers_to_hunt() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.update(0.5, true, 1.0)
	assert_eq(strikes.size(), 0)
	assert_almost_eq(brain.windup_progress(), 0.5 / 0.6, 0.01)
	brain.update(0.2, true, 1.0)
	assert_eq(strikes.size(), 1)
	assert_true(brain.has_struck())
	brain.update(0.5, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.ATTACK)
	brain.update(0.3, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_eq(strikes.size(), 1)


func test_interrupt_calls_off_a_windup_but_not_a_recovery() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.update(0.3, true, 1.0)
	brain.interrupt()
	assert_eq(brain.state, EnemyBrain.State.HUNT, "the windup is called off")
	brain.update(0.4, true, 5.0)
	assert_eq(strikes.size(), 0, "no strike comes")
	_to_attack()
	brain.update(0.7, true, 1.0)
	assert_true(brain.has_struck())
	brain.interrupt()
	assert_eq(brain.state, EnemyBrain.State.ATTACK, "a struck blow runs its recovery on")


func test_cut_recovery_shortens_a_struck_attacks_recovery() -> void:
	brain.recovery = 2.0
	_to_attack()
	brain.update(0.7, true, 1.0)   # the windup ends: struck, a 2 s recovery begins
	assert_true(brain.has_struck())
	brain.cut_recovery(0.5)
	brain.update(0.4, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.ATTACK, "0.5 s are left")
	brain.update(0.2, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT, "the recovery was cut short")


func test_cut_recovery_never_lengthens_and_leaves_other_states_alone() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.cut_recovery(0.0)
	brain.update(0.4, true, 1.0)
	assert_false(brain.has_struck(), "a windup has no recovery to cut")
	brain.update(0.3, true, 1.0)
	assert_eq(strikes.size(), 1, "the windup ran its course")
	brain.cut_recovery(5.0)   # longer than the 0.7 s left: no change
	brain.update(0.6, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.ATTACK)
	brain.update(0.2, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT, "the 0.7 s recovery ran its course")
	brain.cut_recovery(0.0)
	assert_eq(brain.state, EnemyBrain.State.HUNT, "outside an attack it does nothing")
	brain.stun(1.0)
	brain.cut_recovery(0.0)
	assert_true(brain.is_stunned(), "a stun is not a recovery")


func test_stun_interrupts_windup_and_ends_in_a_hunt() -> void:
	var strikes := watch(brain.strike)
	_to_attack()
	brain.update(0.4, true, 1.0)
	brain.stun(2.0)
	assert_true(brain.is_stunned())
	brain.update(1.0, true, 1.0)
	assert_true(brain.is_stunned())
	brain.update(1.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.HUNT)
	assert_true(brain.knows_guard(), "it knows who stunned it")
	assert_eq(strikes.size(), 0)


func test_restun_keeps_the_longer_time() -> void:
	brain.stun(3.0)
	brain.update(1.0, false, INF)
	brain.stun(0.5)
	brain.update(1.5, false, INF)
	assert_true(brain.is_stunned())


func test_destroyed_is_final() -> void:
	brain.destroy()
	brain.wake()
	brain.hear(Vector3.ONE)
	brain.alarm(Vector3.ONE)
	brain.stun(2.0)
	brain.update(1.0, true, 1.0)
	assert_eq(brain.state, EnemyBrain.State.DESTROYED)


func test_state_changes_are_signalled_once() -> void:
	var changes := watch(brain.state_changed)
	brain.wake()
	brain.wake()
	assert_eq(changes.size(), 1)
	assert_eq(changes[0][0], EnemyBrain.State.DORMANT)
	assert_eq(changes[0][1], EnemyBrain.State.SUSPICIOUS)


func test_state_groups() -> void:
	assert_false(brain.is_awake())
	brain.start_patrol()
	assert_true(brain.is_awake())
	assert_false(brain.is_alerted(), "a patrol is calm")
	brain.hear(Vector3.ONE)
	assert_true(brain.is_alerted())
	assert_false(brain.is_hunting())
	brain.wake()
	brain.update(0.81, true, 8.0)
	assert_true(brain.is_hunting())


## Updates in 0.1 s steps (unseen) while the state stays [param kept], at
## most [param limit] seconds; returns the seconds it took.
func _seconds_while(kept: EnemyBrain.State, limit: float) -> float:
	var waited := 0.0
	while brain.state == kept and waited < limit:
		brain.update(0.1, false, INF)
		waited += 0.1
	return waited


func _to_hunt() -> void:
	brain.update(0.1, true, 8.0)
	brain.update(brain.reaction_time, true, 8.0)


func _to_attack() -> void:
	_to_hunt()
	brain.update(0.01, true, 1.0)


# --- beats, roaming, fleeing (ecology) ------------------------------------------------

func test_a_beat_stands_at_its_posts_facing_them() -> void:
	brain.patrol = PackedVector3Array([Vector3.ZERO, Vector3(8, 0, 0)])
	brain.patrol_dwell = PackedFloat32Array([6.0, 2.0])
	brain.patrol_yaw = PackedFloat32Array([0.5, NAN])
	brain.start_patrol()
	brain.update(0.1, false, INF)   # at its post already
	assert_false(brain.walking(), "it stands at its post")
	assert_almost_eq(brain.post_yaw(), 0.5, 0.001, "facing the post's way")
	brain.update(5.7, false, INF)
	assert_false(brain.walking(), "a post is held 6 s, not the plain pause")
	brain.update(0.3, false, INF)
	assert_true(brain.walking(), "then on along the beat")
	assert_true(is_nan(brain.post_yaw()), "walking: no post to face")
	assert_eq(brain.goal, Vector3(8, 0, 0))
	brain.position = brain.goal
	brain.update(0.1, false, INF)
	assert_false(brain.walking())
	assert_true(is_nan(brain.post_yaw()), "this point has no facing")
	brain.update(2.1, false, INF)
	assert_true(brain.walking(), "the second post is held 2 s")
	assert_eq(brain.goal, Vector3.ZERO)


func test_after_a_look_round_it_goes_back_to_its_beat() -> void:
	brain.patrol = PackedVector3Array([Vector3.ZERO, Vector3(8, 0, 0)])
	brain.patrol_dwell = PackedFloat32Array([6.0, 6.0])
	brain.start_patrol()
	brain.update(0.1, false, INF)
	brain.hear(Vector3(3, 0, -5))
	brain.update(0.81, false, INF)
	assert_eq(brain.state, EnemyBrain.State.INVESTIGATE)
	brain.position = Vector3(3, 0, -5)
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.SEARCH)
	_seconds_while(EnemyBrain.State.SEARCH, 12.0)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	assert_eq(brain.goal, Vector3.ZERO, "the nearest post of its beat")
	brain.position = Vector3.ZERO
	brain.update(0.1, false, INF)
	brain.update(EnemyBrain.SETTLE_TIME, false, INF)
	assert_eq(brain.state, EnemyBrain.State.PATROL)
	brain.update(0.1, false, INF)
	assert_false(brain.walking(), "back on its post, it holds it")


func test_a_roamer_wanders_round_its_post() -> void:
	brain.home = Vector3(10, 0, 10)
	brain.position = brain.home
	brain.roam_radius = 5.0
	brain.start_patrol()
	var goals: Array[Vector3] = []
	var paused := 0
	for i in 400:
		brain.update(0.1, false, INF)
		if brain.walking():
			if goals.is_empty() or not goals[goals.size() - 1].is_equal_approx(brain.goal):
				goals.append(brain.goal)
			brain.position = brain.position.move_toward(brain.goal, 0.3)   # 3 m/s
		else:
			paused += 1
	assert_gt(goals.size(), 2, "several places (%d)" % goals.size())
	for goal in goals:
		assert_lt(Vector2(goal.x - 10.0, goal.z - 10.0).length(), 5.01, "within its roam radius: %s" % goal)
		assert_gt(Vector2(goal.x - 10.0, goal.z - 10.0).length(), 1.0, "not on its post: %s" % goal)
	assert_gt(paused, 20, "it pauses between places")


func test_the_roam_filter_rejects_or_moves_points() -> void:
	brain.roam_radius = 5.0
	brain.roam_filter = func(point: Vector3) -> Variant:
		return null if point.x < 0.0 else Vector3(point.x, 0.0, 0.0)   # only east, and snapped to z = 0
	brain.start_patrol()
	var goals: Array[Vector3] = []
	for i in 300:
		brain.update(0.1, false, INF)
		if brain.walking():
			if goals.is_empty() or not goals[goals.size() - 1].is_equal_approx(brain.goal):
				goals.append(brain.goal)
			brain.position = brain.position.move_toward(brain.goal, 0.3)
	assert_gt(goals.size(), 1)
	for goal in goals:
		assert_true(goal.x >= 0.0 and is_zero_approx(goal.z), "filtered and snapped: %s" % goal)


func test_flee_runs_from_the_point_then_goes_home() -> void:
	brain.flee(Vector3(0, 0, -3))
	assert_eq(brain.state, EnemyBrain.State.FLEE)
	assert_true(brain.walking())
	assert_true(brain.is_active())
	assert_true(brain.is_alerted())
	assert_false(brain.knows_guard())
	assert_almost_eq(brain.pace(), 1.0, 0.001, "it runs")
	assert_almost_eq(brain.goal.z, EnemyBrain.FLEE_DISTANCE, 0.01, "straight away from the blast")
	brain.hear(Vector3(5, 0, 5))
	assert_eq(brain.state, EnemyBrain.State.FLEE, "nothing distracts a fleeing exhibit")
	brain.position = brain.goal
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN, "there, it goes home")
	assert_eq(brain.goal, Vector3.ZERO)
	brain.position = Vector3.ZERO
	brain.update(0.1, false, INF)
	brain.update(EnemyBrain.SETTLE_TIME, false, INF)
	assert_eq(brain.state, EnemyBrain.State.DORMANT)


func test_a_summoned_exhibit_never_flees() -> void:
	# a boss's add (the Colossus's scarabs) fights on: fleeing would end in
	# the walk "home" to where it was poured out, and sleep there
	brain.relentless = true
	brain.wake()
	brain.flee(Vector3(0, 0, -3))
	assert_eq(brain.state, EnemyBrain.State.SUSPICIOUS)


func test_flee_gives_up_after_its_travel_time() -> void:
	brain.flee(Vector3(0, 0, -3))
	var steps := int((EnemyBrain.FLEE_TRAVEL - 0.1) / 0.1)
	for i in steps:
		brain.update(0.1, false, INF)
		brain.position = brain.position.move_toward(brain.goal, 0.05)   # a slow crawl (a crowd in the way): never there
	assert_eq(brain.state, EnemyBrain.State.FLEE)
	brain.update(0.2, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN)


func test_a_flee_blocked_by_a_wall_ends_in_the_walk_home() -> void:
	brain.flee(Vector3(0, 0, -3))
	brain.update(EnemyBrain.STALL_TIME + 0.1, false, INF)   # it never moved: a wall
	assert_eq(brain.state, EnemyBrain.State.RETURN)


func test_a_patroller_flees_and_comes_back_to_its_route() -> void:
	brain.patrol = PackedVector3Array([Vector3.ZERO, Vector3(8, 0, 0)])
	brain.start_patrol()
	brain.flee(Vector3(-2, 0, 0))
	assert_eq(brain.state, EnemyBrain.State.FLEE)
	brain.position = brain.goal
	brain.update(0.1, false, INF)
	assert_eq(brain.state, EnemyBrain.State.RETURN)
	assert_eq(brain.goal, Vector3(8, 0, 0), "the nearest point of its route")
