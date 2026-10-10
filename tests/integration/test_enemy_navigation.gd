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
