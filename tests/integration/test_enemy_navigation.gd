extends TestCase
## Enemy behaviour on a baked navmesh: hold at the end of the path, never
## sidestep off a ledge, the kill plane and the fall speed cap.

const FAST_FORWARD := 4

var region: NavigationRegion3D
var target: TargetDummy
var _ticks: int
var _max_steps: int


func before_each() -> void:
	_ticks = Engine.physics_ticks_per_second
	_max_steps = Engine.max_physics_steps_per_frame
	region = NavigationRegion3D.new()
	region.navigation_mesh = LevelNavigation.navigation_mesh()
	add_child(region)
	target = TargetDummy.new()
	add_child(target)


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks
	Engine.max_physics_steps_per_frame = _max_steps
	Engine.time_scale = 1.0


func _bake() -> void:
	region.bake_navigation_mesh(false)
	await physics_frames(6)   # the map syncs a few frames after baking


func _fast_forward() -> void:
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD


func _spawn(kind: GDScript, at: Vector3) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = target
	add_child(enemy)
	return enemy


func test_waits_at_the_end_of_the_path_below_a_guard_it_cannot_reach() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	Greybox.box(region, Vector3(9, 1, 0), Vector3(6, 2, 12), Color.GRAY)   # platform, no ramp
	await _bake()
	target.position = Vector3(7, 2, 0)   # the nearest floor is clearly west of it
	var wax := _spawn(WaxFigure, Vector3(-4, 0, 0))
	await physics_frames(2)
	wax.brain.wake()
	_fast_forward()
	await physics_frames(7 * _ticks)   # 9.5 m at 2.4 m/s after waking up
	# a chaser pressing into the platform would side-step every 0.75 s
	var settled := wax.global_position
	var wandered := 0.0
	for frame in 3 * _ticks:
		await get_tree().physics_frame
		wandered = maxf(wandered, wax.global_position.distance_to(settled))
	assert_eq(wax.brain.state, EnemyBrain.State.HUNT)
	assert_lt(wandered, 0.05, "waits where its path ends")
	assert_lt(wax.global_position.x, 5.62, "short of the platform wall (x 5.65 when pressing)")
	assert_gt(wax.global_position.x, 3.0, "but it did come")


func test_a_wolf_does_not_leap_at_a_guard_off_its_navmesh() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	Greybox.box(region, Vector3(6, 0.4, 0), Vector3(6, 0.8, 6), Color.GRAY)   # too high to step on, low enough to leap on
	await _bake()
	target.position = Vector3(6, 0.8, 0)
	var wolf := _spawn(Wolf, Vector3(-3, 0, 0))
	var strikes := watch(wolf.brain.strike)
	await physics_frames(2)
	wolf.brain.wake()
	_fast_forward()
	await physics_frames(4 * _ticks)
	assert_eq(strikes.size(), 0)
	assert_lt(wolf.global_position.y, 0.4, "still on the floor")


func test_a_blocked_chaser_never_sidesteps_off_a_railless_walkway() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(30, 1, 40), Color.GRAY)
	Greybox.box(region, Vector3(0, 1.5, 0), Vector3(2, 1, 24), Color.GRAY)   # walkway, top at y = 2
	await _bake()
	# a crate across the walkway that the navmesh does not know about
	Greybox.box(self, Vector3(0, 3, 0), Vector3(2, 2, 0.3), Color.GRAY)
	_fast_forward()
	for trial in 4:
		# close to one edge, and the first sidestep aims over it (the old
		# behaviour stepped a metre aside and fell off half of the time)
		var side := 1.0 if trial % 2 == 0 else -1.0
		target.position = Vector3(side * 0.8, 2, -9)
		var wax := _spawn(WaxFigure, Vector3(side * 0.75, 2.05, 5))
		wax._detour_side = -side if trial < 2 else side
		await physics_frames(2)
		wax.brain.wake()
		var lowest := wax.global_position.y
		for frame in 8 * _ticks:
			await get_tree().physics_frame
			lowest = minf(lowest, wax.global_position.y)
		assert_gt(lowest, 1.5, "trial %d stayed on the walkway" % trial)
		wax.free()


func test_a_blocked_chaser_on_open_floor_still_steps_aside() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	await _bake()
	Greybox.box(self, Vector3(0, 1.5, -1.5), Vector3(8, 3, 0.2), Color.GRAY)   # unknown to the navmesh
	target.position = Vector3(0, 0, -8)
	var wax := _spawn(WaxFigure, Vector3(0, 0, 0))
	await physics_frames(2)
	wax.brain.wake()
	var widest := 0.0
	for frame in 240:
		await get_tree().physics_frame
		widest = maxf(widest, absf(wax.global_position.x))
	assert_gt(widest, 0.6)


func test_an_exhibit_that_falls_out_of_the_level_is_destroyed_and_reported() -> void:
	var wax := _spawn(WaxFigure, Vector3(0, -29.5, 0))
	var destroyed := watch(Events.enemy_destroyed)
	await physics_frames(30)
	assert_eq(destroyed.size(), 1)
	if destroyed.size() == 1:
		assert_eq(destroyed[0][0], wax)
		assert_false(destroyed[0][2], "not a finisher")
		assert_eq((destroyed[0][1] as DamageInfo).amount, 0.0, "no damage, no dust")
	assert_true(not is_instance_valid(wax) or wax.is_queued_for_deletion())


func test_falling_speed_is_capped() -> void:
	var wax := _spawn(WaxFigure, Vector3(0, 900, 0))
	_fast_forward()
	await physics_frames(4 * _ticks)
	assert_gt(wax.velocity.y, -Enemy.MAX_FALL_SPEED - 0.01)
	assert_lt(wax.velocity.y, -Enemy.MAX_FALL_SPEED + 1.0, "it did reach the cap")


## (plan 2026-10-21-wydajnosc-cpu) A walk to a point that stays put keeps
## the path it planned - no A* across the whole floor every repath interval
## - and plans anew for a new point or when the navigation map changes.
## A wax figure on a calm round on open floor (the guard far out of sight),
## once it walks to the far end of it, 40 m off; its plans are counted in
## [member plans].
var plans: Array = []


func _walking_figure() -> WaxFigure:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(50, 1, 20), Color.GRAY)
	await _bake()
	target.position = Vector3(0, 0, 300)
	var wax: WaxFigure = WaxFigure.new()
	wax.position = Vector3(-20, 0, 0)
	wax.target = target
	wax.starts_awake = true
	wax.patrol_route = PackedVector3Array([Vector3(-20, 0, 0), Vector3(20, 0, 0)])
	add_child(wax)
	plans = watch(wax.nav.path_changed)
	for frame in 10 * _ticks:   # (it may hold the first post a while)
		await get_tree().physics_frame
		if wax.brain.walking() and wax.velocity.length() > 0.1:
			break
	assert_eq(wax.brain.state, EnemyBrain.State.PATROL)
	assert_true(wax.brain.walking(), "on its way to the far end")
	await physics_frames(15)
	return wax


func test_a_walk_to_a_still_point_keeps_its_path_until_the_point_or_the_map_changes() -> void:
	var wax := await _walking_figure()
	var first := plans.size()
	assert_gt(first, 0, "it planned its walk")
	var from := wax.global_position
	await physics_frames(3 * _ticks)   # 12 repath intervals of 0.25 s
	assert_gt(wax.global_position.distance_to(from), 2.0, "it walked on")
	assert_lt(plans.size() - first, 2, "the same point: the same path (%d plans more)" % (plans.size() - first))
	var before_bake := plans.size()
	region.bake_navigation_mesh(false)   # a door opening, say: a new map
	await physics_frames(30)
	assert_gt(plans.size(), before_bake, "a new map: a new plan")


func test_pushed_off_its_line_it_plans_the_walk_anew_from_where_it_ends_up() -> void:
	var wax := await _walking_figure()
	var before := plans.size()
	wax.shove(Vector3(0, 0, 9))   # the harpoon's pull, a blast: ~1.3 m aside, well inside the agent's own 5 m
	await physics_frames(30)   # the push has died down
	assert_gt(absf(wax.global_position.z), 0.8, "it was pushed aside (%.2f m)" % wax.global_position.z)
	var pushed_to := wax.global_position
	await physics_frames(roundi(Enemy.REPATH_INTERVAL * 1.3 * 60.0) + 2)
	assert_gt(plans.size(), before, "pushed: a new plan")
	var path := wax.nav.get_current_navigation_path()
	assert_false(path.is_empty())
	if not path.is_empty():
		var start := path[0]
		assert_lt(Vector2(start.x - pushed_to.x, start.z - pushed_to.z).length(), 0.7,
				"planned from where the push left it (%s, it stood at %s)" % [start, pushed_to])


func test_a_new_state_plans_at_once_even_for_the_same_point() -> void:
	var wax := await _walking_figure()
	await physics_frames(2)
	var before := plans.size()
	wax._on_state_changed(EnemyBrain.State.PATROL, EnemyBrain.State.PATROL)   # (what every state change does)
	await physics_frames(2)
	assert_gt(plans.size(), before, "a state change plans at once")


func test_a_kept_path_still_tells_whether_it_reaches_its_point() -> void:
	var wax := await _walking_figure()
	wax._target_reachable = false   # (as if the last plan had ended short)
	await physics_frames(roundi(Enemy.REPATH_INTERVAL * 1.3 * 60.0) + 2)
	assert_true(wax._target_reachable, "the path kept reaches its point: said again at every repath")


func test_a_moving_goal_is_planned_every_interval() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(50, 1, 30), Color.GRAY)
	await _bake()
	target.position = Vector3(0, 0, -8)
	var wax := _spawn(WaxFigure, Vector3(0, 0, 8))
	wax.summoned = true   # it always knows where he is
	await physics_frames(2)
	wax.brain.wake()
	await physics_frames(30)
	var count := watch(wax.nav.path_changed)
	for frame in 2 * _ticks:
		await get_tree().physics_frame
		var t := frame / float(_ticks)
		target.position = Vector3(12.0 * sin(t * 1.5), 0, -8.0 + 4.0 * cos(t * 1.5))   # he keeps moving
	assert_true(wax.brain.is_hunting(), "it hunts him")
	assert_gt(count.size(), 5, "a moving goal: a plan every interval (%d in 2 s)" % count.size())


func test_an_exhibit_standing_awake_falls_when_its_floor_goes() -> void:
	var floor := Greybox.box(self, Vector3(0, -0.5, 0), Vector3(6, 1, 6), Color.GRAY)
	Greybox.box(self, Vector3(0, -6.5, 0), Vector3(30, 1, 30), Color.GRAY)   # the floor below
	target.position = Vector3(0, 0, 300)
	var wax: WaxFigure = WaxFigure.new()
	wax.target = target
	wax.starts_awake = true
	add_child(wax)
	wax.brain.roam_radius = 0.0   # it holds its post: awake, standing still
	await physics_frames(60)
	assert_eq(wax.brain.state, EnemyBrain.State.PATROL)
	assert_true(wax.velocity.is_zero_approx() and wax.is_on_floor(), "awake and standing still: no slide most ticks")
	var height := wax.global_position.y
	floor.free()   # a trapdoor, a floor that goes
	await physics_frames(60)
	assert_lt(wax.global_position.y, height - 1.0, "it fell (%.2f -> %.2f)" % [height, wax.global_position.y])


func test_a_crowd_of_melee_exhibits_spreads_around_the_guard() -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)
	await _bake()
	target.position = Vector3.ZERO
	var crowd: Array[Enemy] = []
	for i in 12:
		var angle := TAU * i / 12.0
		crowd.append(_spawn(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * (12.0 + (i % 3))))
	await physics_frames(2)
	for exhibit in crowd:
		exhibit.summoned = true   # a crowd called in (past the hunter cap)
		exhibit.brain.wake()
	_fast_forward()
	await physics_frames(12 * _ticks)
	var near := crowd.filter(func(e: Enemy) -> bool: return e.global_position.distance_to(target.position) < 3.2)
	assert_eq(near.size(), 12, "everyone gathered round")
	var closest_pair := INF
	for a in crowd:
		for b in crowd:
			if a != b:
				closest_pair = minf(closest_pair, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
	assert_gt(closest_pair, 0.6, "nobody stands inside another")
	var attackers := crowd.filter(func(e: Enemy) -> bool: return e.global_position.distance_to(target.position) < 1.7)
	assert_true(attackers.size() >= 6 and attackers.size() <= EnemyCrowd.RING_SLOTS, "%d in the front row" % attackers.size())
