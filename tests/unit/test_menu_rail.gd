extends TestCase
## The main menu's camera rail (MenuRail): cubic paths through the control
## points at a steady speed, eased shots, smooth turns, a bounded hand-held
## drift - all pure arithmetic, no scene.

const STEP := 0.05
## Limits of a slow, gentle camera.
const MAX_SPEED := 3.0
const MAX_TURN_DEG := 20.0
## The eye keeps this far from what it looks at (m).
const MIN_FOCUS_DISTANCE := 3.0


func _angle_between(a: Basis, b: Basis) -> float:
	return rad_to_deg((a.inverse() * b).get_rotation_quaternion().get_angle())


func test_the_loop_has_four_shots_with_distinct_names() -> void:
	var shots := MenuRail.shots()
	assert_eq(shots.size(), 4)
	var seen := {}
	for shot in shots:
		assert_false(seen.has(shot.id), "%s is unique" % shot.id)
		seen[shot.id] = true
		assert_gt(shot.seconds, 12.0, "%s runs long enough to be slow" % shot.id)
		assert_gt(shot.eye.size(), 1, "%s has a path" % shot.id)
		assert_gt(shot.focus.size(), 1, "%s has a gaze" % shot.id)
	assert_true(seen.has(&"lattice") and seen.has(&"drum") and seen.has(&"trex") and seen.has(&"egypt"))


func test_the_curve_passes_through_every_control_point() -> void:
	for shot in MenuRail.shots():
		for path: PackedVector3Array in [shot.eye, shot.focus]:
			for i in path.size():
				var at := MenuRail.curve(path, float(i))
				assert_lt(at.distance_to(path[i]), 0.001, "%s passes point %d" % [shot.id, i])


func test_the_path_runs_at_a_steady_speed_by_arc_length() -> void:
	for shot in MenuRail.shots():
		var steps := 120
		var last := shot.eye_at(0.0)
		var lengths: Array[float] = []
		for k in range(1, steps + 1):
			var at := shot.eye_at(float(k) / steps)
			lengths.append(at.distance_to(last))
			last = at
		var mean := shot.eye_length() / steps
		for length in lengths:
			assert_lt(absf(length - mean), mean * 0.12 + 0.002, "%s: an even step along the path" % shot.id)


func test_the_ease_is_monotone_and_never_stands_still() -> void:
	assert_almost_eq(MenuRail.ease_motion(0.0), 0.0)
	assert_almost_eq(MenuRail.ease_motion(1.0), 1.0)
	assert_almost_eq(MenuRail.ease_motion(-3.0), 0.0, 0.0001, "clamped")
	assert_almost_eq(MenuRail.ease_motion(7.0), 1.0, 0.0001, "clamped")
	var last := 0.0
	for k in range(1, 101):
		var at := MenuRail.ease_motion(k / 100.0)
		assert_gt(at, last, "the run only goes forward (%d)" % k)
		last = at
	assert_gt(MenuRail.ease_motion(0.01), 0.003, "it starts moving at once")
	assert_lt(MenuRail.ease_motion(0.01), 0.01, "but gently")


func test_every_shot_is_continuous_slow_and_looks_away_from_the_eye() -> void:
	for shot in MenuRail.shots():
		var last := shot.pose(0.0)
		var worst_speed := 0.0
		var worst_turn := 0.0
		var closest := INF
		var t := STEP
		while t <= shot.seconds + 0.0001:
			var pose := shot.pose(minf(t, shot.seconds))
			assert_true(pose.origin.is_finite() and pose.basis.is_finite(), "%s: finite at %.2f s" % [shot.id, t])
			worst_speed = maxf(worst_speed, pose.origin.distance_to(last.origin) / STEP)
			worst_turn = maxf(worst_turn, _angle_between(last.basis, pose.basis) / STEP)
			var s := MenuRail.ease_motion(t / shot.seconds)
			closest = minf(closest, shot.eye_at(s).distance_to(shot.focus_at(s)))
			last = pose
			t += STEP
		print("  %s: %.1f m path, top speed %.2f m/s, top turn %.1f deg/s, closest gaze %.1f m" % [shot.id, shot.eye_length(), worst_speed, worst_turn, closest])
		assert_lt(worst_speed, MAX_SPEED, "%s moves slowly" % shot.id)
		assert_lt(worst_turn, MAX_TURN_DEG, "%s turns gently" % shot.id)
		assert_gt(closest, MIN_FOCUS_DISTANCE, "%s never looks at something at its nose" % shot.id)


func test_the_view_is_turned_to_put_the_subject_in_the_right_of_the_frame() -> void:
	for shot in MenuRail.shots():
		var pose := shot.pose(shot.seconds * 0.5)
		var s := MenuRail.ease_motion(0.5)
		var to_subject := (shot.focus_at(s) - pose.origin).normalized()
		# the subject is to the camera's right: positive along its x axis
		assert_gt(to_subject.dot(pose.basis.x), 0.05, "%s: the subject sits right of the middle" % shot.id)


func test_the_field_of_view_follows_the_run() -> void:
	for shot in MenuRail.shots():
		assert_almost_eq(shot.fov_at(0.0), shot.fov_from, 0.001)
		assert_almost_eq(shot.fov_at(shot.seconds), shot.fov_to, 0.001)
		assert_gt(shot.fov_at(shot.seconds * 0.5), minf(shot.fov_from, shot.fov_to) - 0.001)
		assert_lt(shot.fov_at(shot.seconds * 0.5), maxf(shot.fov_from, shot.fov_to) + 0.001)


func test_the_hand_is_small_and_never_jumps() -> void:
	var last := MenuRail.handheld(0.0)
	var most := 0.0
	var turn := 0.0
	var step := 0.0
	var t := 0.02
	while t < 240.0:
		var now := MenuRail.handheld(t)
		most = maxf(most, now.origin.length())
		turn = maxf(turn, now.basis.get_euler().length())
		step = maxf(step, now.origin.distance_to(last.origin))
		last = now
		t += 0.02
	assert_lt(most, 0.06, "a few centimetres")
	assert_lt(turn, 0.01, "well under a degree")
	assert_lt(step, 0.002, "smooth from frame to frame")
	assert_gt(most, 0.01, "but there is some life in it")
	assert_eq(MenuRail.handheld(5.0, 0.0).origin, Vector3.ZERO, "strength 0 locks the camera")
	assert_eq(MenuRail.handheld(12.3), MenuRail.handheld(12.3), "no randomness")


func test_a_two_point_path_is_a_straight_line() -> void:
	var line := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)])
	assert_lt(MenuRail.curve(line, 0.5).distance_to(Vector3(5, 0, 0)), 0.001)
	var table := MenuRail.arc_table(line)
	assert_almost_eq(table[table.size() - 1], 10.0, 0.01)
	assert_almost_eq(MenuRail.index_at(table, 0.25, 2), 0.25, 0.01)
