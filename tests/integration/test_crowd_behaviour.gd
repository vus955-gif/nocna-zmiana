extends TestCase
## Crowds, busts and exhibits on a navmesh (review 2b-1, part B): melee
## fighters wait their turn instead of milling, the attack ring stays on
## one floor and needs sight, a hovering bust finds its way and fires, the
## spawner never wakes what was drawn dormant, facing works under a turned
## parent, and the level sets the kill plane.

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


func _floor(size: float = 50.0) -> void:
	Greybox.box(region, Vector3(0, -0.5, 0), Vector3(size, 1, size), Color.GRAY)


func _bake() -> void:
	region.bake_navigation_mesh(false)
	await physics_frames(6)


func _fast_forward() -> void:
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD


func _spawn(kind: GDScript, at: Vector3, parent: Node = self) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = target
	parent.add_child(enemy)
	return enemy


func test_more_melee_attackers_than_ring_places_wait_without_milling() -> void:
	_floor()
	await _bake()
	var crowd: Array[Enemy] = []
	for i in 16:
		var angle := TAU * i / 16.0
		crowd.append(_spawn(WaxFigure, Vector3(cos(angle), 0, sin(angle)) * (9.0 + (i % 3))))
	await physics_frames(2)
	for enemy in crowd:
		enemy.summoned = true   # a crowd called in (past the hunter cap) fills the ring
		enemy.brain.wake()
	_fast_forward()
	await physics_frames(12 * _ticks)
	var sidesteps := 0
	var last := {}
	for enemy in crowd:
		last[enemy] = enemy._detour_time
	for frame in 5 * _ticks:
		await get_tree().physics_frame
		for enemy in crowd:
			if enemy._detour_time > last[enemy] + 0.01:
				sidesteps += 1
			last[enemy] = enemy._detour_time
	assert_lt(sidesteps, 4, "a waiting crowd stands its ground (was dozens of sidesteps)")
	var near := crowd.filter(func(e: Enemy) -> bool: return e.global_position.distance_to(target.global_position) < 3.2).size()
	assert_gt(near, 8, "the ring around the guard is full")


func test_the_attack_ring_stays_on_the_targets_floor() -> void:
	target.position = Vector3(0, 6, 0)   # the guard on a balcony
	var below := _spawn(WaxFigure, Vector3(2.5, 0, 0))
	var beside := _spawn(WaxFigure, Vector3(-2.0, 6, 0.5))
	await physics_frames(2)
	var from_below := EnemyCrowd.chase_goal(below, target, true, below.brain.attack_range)
	assert_eq(from_below, target.global_position, "no place on the ring through the floor")
	var from_beside := EnemyCrowd.chase_goal(beside, target, true, beside.brain.attack_range)
	assert_ne(from_beside, target.global_position, "the one up there takes a place")
	assert_lt(from_beside.distance_to(target.global_position), beside.brain.attack_range)
	EnemyCrowd.release(beside)


func test_the_attack_ring_needs_sight_of_the_target() -> void:
	var wax := _spawn(WaxFigure, Vector3(2.5, 0, 0))
	await physics_frames(2)
	assert_eq(EnemyCrowd.chase_goal(wax, target, true, wax.brain.attack_range, false), target.global_position)
	assert_ne(EnemyCrowd.chase_goal(wax, target, true, wax.brain.attack_range, true), target.global_position)
	EnemyCrowd.release(wax)


func test_a_hovering_bust_follows_the_navmesh_and_fires() -> void:
	_floor(60.0)
	# a wall between them: the bust has to go round it
	Greybox.box(region, Vector3(0, 2, 0), Vector3(12, 4, 1), Color.GRAY)
	await _bake()
	target.position = Vector3(0, 0, -12)
	var bust := _spawn(Bust, Vector3(0, 0.05, 14)) as Bust
	var strikes := watch(bust.brain.strike)
	await physics_frames(2)
	bust.brain.wake()
	_fast_forward()
	await physics_frames(25 * _ticks)
	assert_true(bust._target_reachable, "its lifted path reaches the guard's floor")
	assert_gt(strikes.size(), 0, "it came round the wall and fired")


func test_a_bust_fires_at_a_guard_the_walkers_cannot_reach() -> void:
	_floor()
	Greybox.box(region, Vector3(0, 0.75, -10), Vector3(4, 1.5, 4), Color.GRAY)   # a platform, no ramp
	await _bake()
	target.position = Vector3(0, 1.5, -10)
	var bust := _spawn(Bust, Vector3(0, 0.05, 1))
	var strikes := watch(bust.brain.strike)
	await physics_frames(2)
	bust.brain.wake()
	_fast_forward()
	await physics_frames(6 * _ticks)
	assert_gt(strikes.size(), 0, "a ranged exhibit is not held back by the reachability gate")


func test_the_spawner_never_wakes_what_the_night_drew_dormant() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	var slots := LobbyLayout.create().spawn_slots
	target.position = Vector3(0, 0, 900)   # nobody sees the guard: only the spawner could wake them
	var wrong := 0
	var checked := 0
	for night_seed in 12:
		var config := NightDirector.plan(night_seed * 31 + 5, 2 + night_seed % 4, description)
		var root := Node3D.new()
		add_child(root)
		var placed := NightSpawner.spawn(config, slots, root, target)
		var drawn := {}
		for entry in config.spawns:
			drawn[entry.slot] = entry
		await physics_frames(1)
		for exhibit in placed:
			checked += 1
			var dormant := exhibit.brain.state == EnemyBrain.State.DORMANT
			if dormant != (drawn[exhibit.get_meta(NightSpawner.SLOT_META)] as NightConfig.Spawn).dormant:
				wrong += 1
		root.free()
	assert_gt(checked, 200)
	assert_eq(wrong, 0, "awake exhibits rouse no dormant neighbour at spawn")


func test_exhibits_face_their_target_under_a_turned_parent() -> void:
	var turned := Node3D.new()
	turned.rotation.y = 1.3
	turned.position = Vector3(3, 0, 2)
	add_child(turned)
	var wax := _spawn(WaxFigure, Vector3.ZERO, turned)
	target.position = Vector3(3, 0, -8)
	await physics_frames(2)
	wax.face(target.global_position)
	var to := (target.global_position - wax.global_position)
	to.y = 0.0
	var forward := -wax.global_transform.basis.z
	assert_gt(forward.dot(to.normalized()), 0.99, "face() turns it in the world")
	wax.brain.wake()
	target.position = Vector3(12, 0, 2)
	await physics_frames(60)
	to = target.global_position - wax.global_position
	to.y = 0.0
	forward = -wax.global_transform.basis.z
	assert_gt(forward.dot(to.normalized()), 0.95, "and keeps facing it while chasing")


func test_the_level_sets_the_kill_plane() -> void:
	var level := Level.new()
	level.kill_plane_y = -5.0
	add_child(level)
	assert_eq(Level.kill_plane(), -5.0)
	var wax := _spawn(WaxFigure, Vector3(0, -6.0, 0))
	var gone := watch(Events.enemy_destroyed)
	await physics_frames(2)
	assert_false(is_instance_valid(wax) and not wax.is_queued_for_deletion(), "below the level's own plane")
	assert_eq(gone.size(), 1)
	level.free()
	assert_eq(Level.kill_plane(), Level.DEFAULT_KILL_PLANE)


## A sleeping exhibit standing on its floor skips its physics step (only
## its eyes keep watching); waking up, or a hit, ends the rest.
func test_a_sleeping_exhibit_on_its_floor_rests() -> void:
	_floor()
	target.position = Vector3(0, 0, 40)   # out of sight range
	var wax := _spawn(WaxFigure, Vector3(0, 0.6, 0))
	assert_false(wax.resting(), "it falls onto its floor first")
	await physics_frames(40)
	assert_true(wax.resting(), "then rests there")
	var settled := wax.global_position
	await physics_frames(20)
	assert_true(wax.global_position.is_equal_approx(settled), "and stays put")
	var push := DamageInfo.make(1.0, DamageInfo.Kind.BLUNT, target)
	push.direction = Vector3(1, 0, 0)
	push.knockback = 4.0
	wax.take_damage(push)
	assert_false(wax.resting(), "a hit wakes it and shoves it")
	await physics_frames(10)
	assert_gt(wax.global_position.x, settled.x + 0.05, "and it slides")


## Every chaser's separation push reads the crowd's positions taken once
## per physics frame.
func test_the_crowd_positions_are_taken_once_per_frame() -> void:
	_floor()
	target.position = Vector3(0, 0, -20)
	var first := _spawn(WaxFigure, Vector3(0, 0, 0))
	var second := _spawn(WaxFigure, Vector3(0.5, 0, 0))
	first.brain.wake()
	second.brain.wake()
	await physics_frames(60)   # both hunt now (after a 0.8 s suspicion)
	var taken := EnemyCrowd.chasers().duplicate()
	assert_eq(taken.size(), 2)
	second.global_position += Vector3(5, 0, 0)
	assert_eq(EnemyCrowd.chasers(), taken, "the same frame: the same snapshot")
	await get_tree().physics_frame
	assert_ne(EnemyCrowd.chasers(), taken, "a new frame: taken again")
	var apart := EnemyCrowd.push_for(first)
	assert_eq(apart, Vector3.ZERO, "five metres apart: no push")
