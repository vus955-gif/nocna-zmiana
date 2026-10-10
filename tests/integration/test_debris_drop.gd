extends TestCase
## Falling ceiling debris: marked at once, hurts only on landing, only inside.

var guard: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 0)
	add_child(guard)


func after_each() -> void:
	GameInput.capture_allowed = true


## Stands in for a boss that has already died.
class DeadBoss extends Node:
	func is_dead() -> bool:
		return true


func _drop(at: Vector3, source: Node = null) -> DebrisDrop:
	var drop := DebrisDrop.create(at, guard, source)
	add_child(drop)
	return drop


func test_lands_after_one_second_and_hurts_a_guard_inside() -> void:
	await physics_frames(5)
	var drop := _drop(Vector3(0.5, 0, 0))
	var landings := watch(drop.landed)
	await physics_frames(54)
	assert_eq(guard.health.current, 100.0, "nothing before it lands")
	assert_eq(landings.size(), 0)
	await physics_frames(10)
	assert_eq(landings.size(), 1)
	assert_eq(guard.health.current, 80.0)


func test_misses_a_guard_outside_the_shadow() -> void:
	await physics_frames(5)
	var drop := _drop(Vector3(2.5, 0, 0))
	var landings := watch(drop.landed)
	await physics_frames(70)
	assert_eq(landings.size(), 1)
	if landings.size() == 1:
		assert_false(landings[0][0])
	assert_eq(guard.health.current, 100.0)


func test_stepping_out_during_the_warning_is_enough() -> void:
	await physics_frames(5)
	_drop(Vector3(0, 0, 0))
	await physics_frames(30)
	guard.global_position = Vector3(3, 0.05, 0)
	await physics_frames(40)
	assert_eq(guard.health.current, 100.0)


func test_debris_of_a_boss_that_is_gone_still_falls_but_hurts_no_one() -> void:
	await physics_frames(5)
	var boss := Node.new()
	add_child(boss)
	var drop := _drop(Vector3(0.5, 0, 0), boss)
	var landings := watch(drop.landed)
	boss.free()
	await physics_frames(70)
	assert_eq(landings.size(), 1, "the rock lands")
	if landings.size() == 1:
		assert_false(landings[0][0])
	assert_eq(guard.health.current, 100.0)


func test_debris_of_a_dead_boss_hurts_no_one() -> void:
	await physics_frames(5)
	var boss := DeadBoss.new()
	add_child(boss)
	var drop := _drop(Vector3(0.5, 0, 0), boss)
	var landings := watch(drop.landed)
	await physics_frames(70)
	assert_eq(landings.size(), 1)
	assert_eq(guard.health.current, 100.0)


func test_a_guard_in_a_haven_is_safe() -> void:
	add_child(Haven.make(&"booth", AABB(Vector3(-2, 0, -2), Vector3(4, 3, 4))))
	await physics_frames(5)
	var drop := _drop(Vector3(0.5, 0, 0))
	var landings := watch(drop.landed)
	await physics_frames(70)
	assert_eq(landings.size(), 1)
	assert_eq(guard.health.current, 100.0)


func test_the_rock_starts_high_and_falls_faster_and_faster() -> void:
	var drop := _drop(Vector3(5, 0, 5))
	await physics_frames(2)
	var rock := drop.get_child(drop.get_child_count() - 1) as Node3D
	var start := rock.position.y
	await physics_frames(20)
	var early := start - rock.position.y
	await physics_frames(20)
	var late := start - rock.position.y - early
	assert_gt(start, 6.0)
	assert_gt(late, early * 1.5)


func test_a_low_ceiling_shortens_the_fall() -> void:
	Greybox.box(self, Vector3(-5, 3.5, -5), Vector3(4, 0.4, 4), Color.GRAY)
	var drop := _drop(Vector3(-5, 0, -5))
	await physics_frames(2)
	var rock := drop.get_child(drop.get_child_count() - 1) as Node3D
	assert_lt(rock.position.y, 3.3)
