extends TestCase
## The guardians' motion kit: keyframe clips with easing curves
## (MotionClip), damped springs for secondary motion (Spring) and limb
## solving (LimbIK: aim a bone, two-bone reach).


func test_a_clip_passes_through_its_keys() -> void:
	var clip := MotionClip.new()
	clip.key(&"raise", 0.0, 0.0).key(&"raise", 0.7, 1.0, MotionClip.IN_OUT).key(&"raise", 1.0, -0.2, MotionClip.IN)
	assert_almost_eq(clip.sample(&"raise", 0.0), 0.0)
	assert_almost_eq(clip.sample(&"raise", 0.7), 1.0)
	assert_almost_eq(clip.sample(&"raise", 1.0), -0.2)
	assert_almost_eq(clip.sample(&"raise", -1.0), 0.0, 0.001, "before the first key: its value")
	assert_almost_eq(clip.sample(&"raise", 5.0), -0.2, 0.001, "after the last key: its value")
	assert_almost_eq(clip.duration(), 1.0)
	assert_true(clip.has(&"raise"))
	assert_false(clip.has(&"lean"))
	assert_almost_eq(clip.sample(&"lean", 0.5, 0.25), 0.25, 0.001, "an unknown channel gives the fallback")


func test_keys_may_come_in_any_order() -> void:
	var clip := MotionClip.new()
	clip.key(&"x", 1.0, 1.0, MotionClip.LINEAR).key(&"x", 0.0, 0.0)
	assert_almost_eq(clip.sample(&"x", 0.25), 0.25)


func test_the_curves_shape_the_way_between_keys() -> void:
	var clip := MotionClip.new()
	for kind: StringName in [&"linear", &"in", &"out", &"in_out", &"back", &"hold"]:
		clip.key(kind, 0.0, 0.0)
	clip.key(&"linear", 1.0, 1.0, MotionClip.LINEAR)
	clip.key(&"in", 1.0, 1.0, MotionClip.IN)
	clip.key(&"out", 1.0, 1.0, MotionClip.OUT)
	clip.key(&"in_out", 1.0, 1.0, MotionClip.IN_OUT)
	clip.key(&"back", 1.0, 1.0, MotionClip.OUT_BACK)
	clip.key(&"hold", 1.0, 1.0, MotionClip.HOLD)
	assert_almost_eq(clip.sample(&"linear", 0.5), 0.5)
	assert_lt(clip.sample(&"in", 0.5), 0.3, "ease in starts slow (a fall that accelerates)")
	assert_gt(clip.sample(&"out", 0.5), 0.7, "ease out ends slow")
	assert_almost_eq(clip.sample(&"in_out", 0.5), 0.5, 0.001)
	assert_lt(clip.sample(&"in_out", 0.1), 0.05)
	var peak := 0.0
	for i in 101:
		peak = maxf(peak, clip.sample(&"back", i / 100.0))
	assert_gt(peak, 1.05, "out-back overshoots before it settles")
	assert_almost_eq(clip.sample(&"back", 1.0), 1.0)
	assert_almost_eq(clip.sample(&"hold", 0.99), 0.0, 0.001, "a hold keeps the previous value")
	assert_almost_eq(clip.sample(&"hold", 1.0), 1.0)


func test_a_spring_settles_on_its_target() -> void:
	var spring := Spring.new(2.0, 1.0)
	var highest := 0.0
	for i in 240:
		highest = maxf(highest, spring.step(1.0, 1.0 / 60.0))
	assert_almost_eq(spring.value, 1.0, 0.01, "settled after 4 s")
	assert_true(highest <= 1.001, "critically damped: no overshoot (%.3f)" % highest)
	var loose := Spring.new(2.0, 0.35)
	highest = 0.0
	for i in 240:
		highest = maxf(highest, loose.step(1.0, 1.0 / 60.0))
	assert_gt(highest, 1.1, "under-damped: it overshoots and settles")
	assert_almost_eq(loose.value, 1.0, 0.05)


func test_a_spring_stays_stable_with_a_long_frame() -> void:
	var spring := Spring.new(6.0, 0.5)
	for i in 10:
		spring.step(2.0, 0.25)
	assert_almost_eq(spring.value, 2.0, 0.1, "no blow-up on a hitch")
	spring.reset(0.0)
	assert_almost_eq(spring.value, 0.0)
	assert_almost_eq(spring.velocity, 0.0)
	spring.kick(3.0)
	assert_gt(spring.step(0.0, 1.0 / 60.0), 0.0, "a kick moves it")


func test_aim_turns_a_bone_onto_a_direction() -> void:
	var rest := Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, -0.2)
	var axis := Vector3(0.05, -1.0, -0.2).normalized()
	for direction: Vector3 in [Vector3(0, 0, -1), Vector3(1, -1, 0).normalized(), Vector3(0.2, 0.9, 0.1).normalized()]:
		var turned := LimbIK.aim(rest, axis, direction)
		assert_lt((turned * axis).angle_to(direction), 0.01, str(direction))
		assert_almost_eq(turned.determinant(), 1.0, 0.001, "a pure rotation")
	var same := LimbIK.aim(rest, axis, rest * axis)
	assert_lt((same.get_rotation_quaternion().angle_to(rest.get_rotation_quaternion())), 0.001, "already aimed: no turn")


func test_two_bones_reach_the_distance_asked() -> void:
	for case: Array in [[2.3, 2.32, 3.0], [2.3, 2.32, 4.5], [1.0, 1.0, 1.414], [2.0, 1.0, 1.5]]:
		var l1: float = case[0]
		var l2: float = case[1]
		var reach: float = case[2]
		var angles := LimbIK.two_bone(l1, l2, reach)
		var knee := Vector2(cos(angles.x), sin(angles.x)) * l1
		var end := knee + Vector2(cos(angles.x - angles.y), sin(angles.x - angles.y)) * l2
		assert_almost_eq(end.length(), reach, 0.01, "reach %s" % str(case))
		assert_almost_eq(end.angle(), 0.0, 0.01, "along the reach line")
	var straight := LimbIK.two_bone(2.3, 2.32, 9.0)
	assert_almost_eq(straight.x, 0.0, 0.02, "out of reach: straight")
	assert_almost_eq(straight.y, 0.0, 0.02)


func test_a_joint_bends_toward_its_pole() -> void:
	var root := Vector3(0.2, 1.0, -0.6)
	for case: Array in [[Vector3(0.2, 0.2, -0.4), Vector3.FORWARD], [Vector3(0.2, 0.3, -0.9), Vector3.BACK], [Vector3(0.6, 0.5, -0.2), Vector3.UP]]:
		var end: Vector3 = case[0]
		var pole: Vector3 = case[1]
		var knee := LimbIK.joint(root, end, 0.46, 0.39, pole)
		assert_almost_eq(knee.distance_to(root), 0.46, 0.001, "the first bone's length")
		assert_almost_eq(knee.distance_to(end), 0.39, 0.001, "the second bone's length")
		var line := (end - root).normalized()
		var side := (knee - root) - line * (knee - root).dot(line)
		assert_gt(side.dot(pole), 0.0, "bent toward the pole %s" % str(pole))
	var far := Vector3(0.2, -2.0, -0.6)
	var straight := LimbIK.joint(root, far, 0.46, 0.39, Vector3.FORWARD)
	assert_lt(straight.distance_to(root + Vector3.DOWN * 0.46), 0.01, "out of reach: straight toward the end")


func test_a_lane_mark_runs_as_long_as_asked_and_fills_as_the_charge_comes() -> void:
	var lane := GroundMark.lane(2.0, 12.0)
	lane.progress = 0.05
	var early := lane.shadow_alpha()
	var shadow := lane.get_child(0) as MeshInstance3D
	var short := shadow.scale.z
	lane.progress = 1.0
	assert_gt(lane.shadow_alpha(), early + 0.2, "darker as it comes")
	assert_gt(shadow.scale.z, short + 5.0, "the shadow runs out along the lane")
	var box := shadow.get_aabb()
	assert_almost_eq(box.size.x, 2.0, 0.01, "as wide as asked")
	assert_almost_eq(box.size.z * shadow.scale.z, 12.0, 0.01, "as long as asked")
	lane.length = 7.0
	assert_almost_eq(box.size.z * shadow.scale.z, 7.0, 0.01, "shortened to the first obstacle")
	lane.free()
