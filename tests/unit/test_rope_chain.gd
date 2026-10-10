extends TestCase
## RopeChain: the Verlet rope behind the mummy's bandage whip and its loose
## strips (hangs, keeps its lengths, lags behind its root, follows targets).

const DT := 1.0 / 60.0


func _settle(rope: RopeChain, root: Vector3, frames: int) -> void:
	for i in frames:
		rope.step(DT, root)


func test_hangs_straight_down_under_its_root() -> void:
	var root := Vector3(1, 2, 3)
	var rope := RopeChain.hanging(root, 4, 0.2)
	rope.points[4] += Vector3(0.3, 0.0, 0.0)   # nudged: it must settle again
	_settle(rope, root, 120)
	var tip := rope.points[rope.points.size() - 1]
	assert_almost_eq(tip.x, root.x, 0.02)
	assert_almost_eq(tip.z, root.z, 0.02)
	assert_almost_eq(tip.y, root.y - 0.8, 0.02)
	assert_almost_eq(rope.span(), 0.8, 0.0001)


func test_keeps_its_lengths_when_the_root_is_jerked() -> void:
	var rope := RopeChain.hanging(Vector3.ZERO, 4, 0.2)
	var root := Vector3.ZERO
	for i in 30:
		root += Vector3(0.06, 0.03 * sin(i), -0.04)
		rope.step(DT, root)
	for i in 4:
		assert_almost_eq(rope.points[i].distance_to(rope.points[i + 1]), 0.2, 0.01, "segment %d" % i)
	assert_true(rope.points[0].is_equal_approx(root), "the root stays pinned")


func test_the_tip_lags_behind_a_root_that_moves_sideways() -> void:
	var rope := RopeChain.hanging(Vector3.ZERO, 4, 0.2)
	_settle(rope, Vector3.ZERO, 30)
	var root := Vector3(0.4, 0.0, 0.0)
	_settle(rope, root, 3)
	var tip := rope.points[4]
	var first := rope.points[1]
	assert_gt(absf(tip.x - root.x), absf(first.x - root.x), "the tip trails further than the first joint")
	assert_lt(tip.x, root.x - 0.1, "it has not caught up yet")


func test_pull_toward_brings_points_onto_their_targets() -> void:
	var rope := RopeChain.hanging(Vector3.ZERO, 4, 0.2)
	var targets := PackedVector3Array()
	var weights := PackedFloat32Array()
	for i in 5:
		targets.append(Vector3(0, 0, -0.2 * i))
		weights.append(1.0)
	for i in 30:
		rope.pull_toward(targets, weights, DT, 40.0)
		rope.step(DT, Vector3.ZERO)
	assert_almost_eq(rope.points[4].z, -0.8, 0.05, "straight out in front")
	assert_almost_eq(rope.points[4].y, 0.0, 0.05)


func test_longer_lengths_unroll_the_rope() -> void:
	var rope := RopeChain.hanging(Vector3.ZERO, 4, 0.2)
	for i in 4:
		rope.lengths[i] = 0.3
	_settle(rope, Vector3.ZERO, 120)
	assert_almost_eq(rope.points[4].y, -1.2, 0.03)
	assert_almost_eq(rope.span(), 1.2, 0.0001)


func test_direction_of_a_hanging_segment_points_down() -> void:
	var rope := RopeChain.hanging(Vector3.ZERO, 2, 0.5)
	assert_true(rope.direction(0).is_equal_approx(Vector3.DOWN))
	assert_true(rope.direction(1).is_equal_approx(Vector3.DOWN))


func test_it_lies_on_its_floor_instead_of_sinking_through() -> void:
	var rope := RopeChain.hanging(Vector3(0, 0.5, 0), 4, 0.2)
	rope.floor_y = 0.0
	_settle(rope, Vector3(0, 0.5, 0), 120)
	var lowest := INF
	for point in rope.points:
		assert_true(point.y >= -0.0001, "above the floor: %s" % point)
		lowest = minf(lowest, point.y)
	assert_almost_eq(lowest, 0.0, 0.01, "what is too long lies on it")
