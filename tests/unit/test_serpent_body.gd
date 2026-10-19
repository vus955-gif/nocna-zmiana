extends TestCase
## The Two-headed Serpent's spine as pure logic (SerpentBody): segments
## 0.75 m apart that follow their leader through the same points, a body
## that follows the terrain and bridges steps, necks of constant length
## bent toward wherever the heads are, the body reversing to lead with the
## other head, vertical arches that keep the spacing, the tail bent aside
## to sweep.

const STEP := 0.05

var body: SerpentBody


func before_each() -> void:
	body = SerpentBody.new()
	body.height_at = func(_at: Vector3) -> float: return 0.0


func _flat(x: float, z: float) -> Vector3:
	return Vector3(x, 0.0, z)


## Lays it straight along +X with the leader (end A's neck root) at x = 0.
func _lay_straight() -> void:
	var path := PackedVector3Array()
	for i in 81:
		path.append(_flat(-40.0 + i * 0.5, 0.0))
	body.lay(path)


func _spacing_ok(message: String, first: int = -1, last: int = -1) -> void:
	if first < 0:
		first = 0
	if last < 0:
		last = body.count
	for j in range(first + 1, last + 1):
		var gap := body.joints[j].distance_to(body.joints[j - 1])
		assert_almost_eq(gap, SerpentBody.SPACING, 0.02, "%s: joints %d-%d %.3f m apart" % [message, j - 1, j, gap])


func _distance_to_polyline(point: Vector3, line: PackedVector3Array) -> float:
	var best := INF
	for i in range(1, line.size()):
		best = minf(best, Geometry3D.get_closest_point_to_segment(point, line[i - 1], line[i]).distance_to(point))
	return best


func test_the_radius_profile_is_the_models_stretched_over_the_longer_body() -> void:
	var radii := SerpentBody.radius_profile(45)
	assert_eq(radii.size(), 46, "one radius per joint")
	assert_almost_eq(radii[0], 0.4, 0.001, "the necks are thin")
	assert_almost_eq(radii[45], 0.4, 0.001)
	assert_gt(radii[22], 0.51, "the middle is the fattest")
	assert_lt(radii[22], 0.525)
	for k in 7:
		assert_eq(SerpentBody.model_segment(k, 45), k + 1, "the first seven are the model's 1..7")
		assert_eq(SerpentBody.model_segment(45 - 7 + k, 45), 8 + k, "the last seven are the model's 8..14")
	for k in range(7, 38):
		var original := SerpentBody.model_segment(k, 45)
		assert_true(original == 7 or original == 8, "the middle copies the fattest two (%d -> %d)" % [k, original])
	assert_ne(SerpentBody.model_segment(7, 45), SerpentBody.model_segment(8, 45), "alternating")


func test_laid_straight_the_joints_are_spaced_and_lie_on_their_radius() -> void:
	_lay_straight()
	assert_eq(body.joints.size(), body.count + 1)
	assert_almost_eq(body.leader().x, 0.0, 0.001, "the leader (end A's neck root) at the path's end")
	var ground := body.ground_joints()
	_spacing_ok("lying", ground.x, ground.y)
	for j in range(ground.x, ground.y + 1):
		assert_almost_eq(body.joints[j].y, body.radii[j], 0.001, "joint %d rides on its radius" % j)
		assert_almost_eq(body.joints[j].z, 0.0, 0.001)
	assert_almost_eq(body.joints[ground.y].x, -body.lying_length(), 0.01, "the trailing neck root at the body's lying length")


func test_every_segment_follows_the_leader_through_the_same_points() -> void:
	_lay_straight()
	var visited := PackedVector3Array()
	for i in 81:
		visited.append(_flat(-40.0 + i * 0.5, 0.0))
	# a turn north, then east again: an S on the floor
	var course := PackedVector3Array([_flat(3.0, 0.0), _flat(5.0, -1.0), _flat(6.0, -3.0), _flat(6.0, -7.0), _flat(7.0, -9.0), _flat(9.0, -10.0), _flat(14.0, -10.0)])
	var at := body.leader()
	for goal in course:
		while at.distance_to(goal) > STEP:
			at = at.move_toward(goal, STEP)
			body.advance(at)
			visited.append(Vector3(at.x, 0.0, at.z))
	var ground := body.ground_joints()
	_spacing_ok("after the S", ground.x, ground.y)
	var lead := body.leader()
	assert_almost_eq(lead.x, 14.0, 0.06)
	assert_almost_eq(lead.z, -10.0, 0.06)
	for j in range(ground.x, ground.y + 1):
		var on_ground := Vector3(body.joints[j].x, 0.0, body.joints[j].z)
		assert_lt(_distance_to_polyline(on_ground, visited), 0.03, "joint %d on the leader's trail" % j)


func test_the_body_follows_the_ground_and_bridges_a_step() -> void:
	# a terrace 1.5 m up from x = 4 on
	body.height_at = func(at: Vector3) -> float: return 1.5 if at.x > 4.0 else 0.0
	_lay_straight()
	var at := body.leader()
	for i in 240:
		at.x += STEP
		body.advance(at)
	var ground := body.ground_joints()
	_spacing_ok("over the step", ground.x, ground.y)
	var top := body.joints[ground.x]
	assert_almost_eq(top.y, 1.5 + body.radii[ground.x], 0.02, "the leader rides the terrace")
	var low := body.joints[ground.y]
	assert_almost_eq(low.y, body.radii[ground.y], 0.02, "the tail still on the floor")
	var steepest := 0.0
	for j in range(ground.x + 1, ground.y + 1):
		var a := body.joints[j - 1]
		var b := body.joints[j]
		var run := Vector2(a.x - b.x, a.z - b.z).length()
		if run > 0.01:
			steepest = maxf(steepest, absf(a.y - b.y) / run)
	assert_lt(steepest, SerpentBody.MAX_SLOPE + 0.05, "it bridges the step at a slope, never a drop")
	assert_gt(steepest, 0.5, "and does climb it")


func test_the_necks_keep_their_length_wherever_the_heads_go() -> void:
	_lay_straight()
	var frame := body.root_frame(SerpentBody.End.A)
	assert_lt(frame.basis.z.x, -0.99, "end A's frame looks out along the body's line (-Z outward = +X here)")
	for target: Array in [[Vector3(1.8, 1.2, 0.4), Vector3(1.0, 0.0, 0.0)], [Vector3(0.6, 2.2, -0.8), Vector3(0.0, 0.3, -1.0)], [Vector3(2.9, 0.4, 0.0), Vector3(1.0, -0.4, 0.0)]]:
		var wanted: Vector3 = frame * (target[0] as Vector3)
		body.set_head(SerpentBody.End.A, wanted, frame.basis * (target[1] as Vector3))
		body.update()
		var length := 0.0
		for j in range(1, SerpentBody.NECK + 1):
			length += body.joints[j].distance_to(body.joints[j - 1])
		assert_almost_eq(length, SerpentBody.NECK * SerpentBody.SPACING, 0.03, "neck A %.2f m long toward %s" % [length, target[0]])
		assert_lt(body.joints[0].distance_to(wanted), 0.03, "the head reaches %s" % target[0])
		_spacing_ok("neck A", 0, SerpentBody.NECK)
	# out of reach: the head is pulled in along the line, the neck straight
	var far := frame * Vector3(5.0, 0.5, 0.0)
	body.set_head(SerpentBody.End.A, far, frame.basis * Vector3(1.0, 0.0, 0.0))
	body.update()
	var root := body.joints[SerpentBody.NECK]
	assert_almost_eq(body.joints[0].distance_to(root), SerpentBody.NECK * SerpentBody.SPACING, 0.03, "straight out to its full length")
	assert_lt(body.joints[0].distance_to(far), far.distance_to(root), "toward the target")
	_spacing_ok("neck A straight", 0, SerpentBody.NECK)
	# the other end too
	var frame_b := body.root_frame(SerpentBody.End.B)
	assert_gt(frame_b.basis.z.x, 0.99, "end B looks the other way")
	body.set_head(SerpentBody.End.B, frame_b * Vector3(0.0, 1.0, -2.0), frame_b.basis * Vector3.FORWARD)
	body.update()
	_spacing_ok("neck B", body.count - SerpentBody.NECK, body.count)
	assert_gt(body.joints[body.count].y, 0.9, "head B raised")


func test_reversing_keeps_the_body_where_it_lies_and_leads_with_the_other_head() -> void:
	_lay_straight()
	var before := body.joints.duplicate()
	body.reverse()
	assert_eq(body.lead, SerpentBody.End.B)
	var ground := body.ground_joints()
	for j in range(ground.x, ground.y + 1):
		assert_lt(body.joints[j].distance_to(before[j]), 0.02, "joint %d stays put" % j)
	assert_almost_eq(body.leader().x, -body.lying_length(), 0.02, "end B's neck root leads now")
	# it glides on west: end B's root moves, end A's root follows
	var at := body.leader()
	for i in 60:
		at.x -= STEP
		body.advance(at)
	assert_almost_eq(body.leader().x, -body.lying_length() - 3.0, 0.02)
	assert_almost_eq(body.joints[SerpentBody.NECK].x, -3.0, 0.03, "end A's root followed by the same distance")
	_spacing_ok("reversed", ground.x, ground.y)


func test_arches_lift_the_body_and_keep_the_spacing() -> void:
	_lay_straight()
	body.arches = [[6.0, 1.3, 2.4]]
	body.update()
	var ground := body.ground_joints()
	var highest := 0.0
	var where := 0
	for j in range(ground.x, ground.y + 1):
		if body.joints[j].y > highest:
			highest = body.joints[j].y
			where = j
	assert_gt(highest, 1.3 + 0.4, "the arch's top about 1.3 m over the belly line")
	assert_almost_eq(body.s_of_joint(where), 6.0, 0.8, "the arch where it was asked for (the lifted body slides back a little)")
	_spacing_ok("arched", ground.x, ground.y)
	assert_almost_eq(body.joints[ground.x].y, body.radii[ground.x], 0.001, "the leader's root still on the floor")
	# the lifted body takes in its slack from the trailing end
	assert_gt(body.joints[ground.y].x, -body.lying_length() + 0.2, "the tail drew in")


func test_the_tail_bends_aside_to_sweep() -> void:
	_lay_straight()
	var ground := body.ground_joints()
	var tip_before := body.joints[ground.y]
	body.sweep = 1.0
	body.update()
	_spacing_ok("swept", ground.x, ground.y)
	var tip := body.joints[ground.y]
	assert_gt(absf(tip.z - tip_before.z), 2.0, "the tip swung far aside")
	assert_lt(body.joints[ground.y - SerpentBody.SWEEP_JOINTS].distance_to(tip_before + Vector3(SerpentBody.SWEEP_JOINTS * SerpentBody.SPACING, 0.0, 0.0)), 0.02, "the base of the sweep stays")
	body.sweep = -1.0
	body.update()
	assert_lt((body.joints[ground.y].z - tip_before.z) * (tip.z - tip_before.z), 0.0, "the other way round")
	body.sweep = 0.0
	body.update()
	assert_lt(body.joints[ground.y].distance_to(tip_before), 0.02, "straight again")


func test_segment_transforms_run_from_end_a_toward_end_b() -> void:
	_lay_straight()
	for k in body.count:
		var xform := body.segment_transform(k)
		assert_lt(xform.origin.distance_to(body.joints[k]), 0.001, "segment %d pivots on joint %d" % [k, k])
		var along := (body.joints[k + 1] - body.joints[k]).normalized()
		assert_gt(xform.basis.z.dot(along), 0.999, "segment %d's +Z toward the next joint" % k)
		assert_almost_eq(xform.basis.determinant(), 1.0, 0.01, "orthonormal")
		if k >= SerpentBody.NECK and k < body.count - SerpentBody.NECK:
			assert_gt(xform.basis.y.y, 0.99, "no roll on the floor")


func test_looking_ahead_it_climbs_onto_a_step_and_bridges_off_its_far_side() -> void:
	# a 3 m band 1.5 m up across its way (a flight's side on the terrace)
	body.height_at = func(at: Vector3) -> float: return 1.5 if at.x > 4.0 and at.x < 7.0 else 0.0
	_lay_straight()
	var at := body.leader()
	var sunk := 0.0
	var steepest := 0.0
	for i in 280:
		at.x += STEP
		var ahead := PackedVector3Array()
		for k in range(1, 14):
			ahead.append(at + Vector3(0.1 * k, 0.0, 0.0))
		body.advance(at, ahead)
		var ground := body.ground_joints()
		for j in range(ground.x, ground.y + 1):
			var belly := body.joints[j].y - body.radii[j]
			sunk = maxf(sunk, float(body.height_at.call(body.joints[j])) - belly)
		for j in range(ground.x + 1, ground.y + 1):
			var a := body.joints[j - 1]
			var b := body.joints[j]
			var run := Vector2(a.x - b.x, a.z - b.z).length()
			if run > 0.01:
				steepest = maxf(steepest, absf(a.y - b.y) / run)
	assert_lt(sunk, 0.15, "lifted ahead of the step, never into its side (sunk %.2f m)" % sunk)
	assert_lt(steepest, SerpentBody.MAX_SLOPE + 0.05, "it climbs and comes down at the slope")
	_spacing_ok("over the band", body.ground_joints().x, body.ground_joints().y)
	var bridged := 0.0
	var ground := body.ground_joints()
	for j in range(ground.x, ground.y + 1):
		var joint := body.joints[j]
		if joint.x > 7.0 and joint.x < 8.0:
			bridged = maxf(bridged, joint.y - body.radii[j])
	assert_gt(bridged, 0.3, "and bridges off its far side rather than dropping (%.2f m up)" % bridged)


func test_laid_over_a_step_the_resting_body_humps_over_it_and_lies_flat_elsewhere() -> void:
	body.height_at = func(at: Vector3) -> float: return 1.5 if at.x > 4.0 and at.x < 7.0 else 0.0
	var path := PackedVector3Array()
	for i in 81:
		path.append(_flat(-30.0 + i * 0.5, 0.0))
	body.lay(path)
	var ground := body.ground_joints()
	_spacing_ok("laid over the band", ground.x, ground.y)
	var sunk := 0.0
	var floor_high := 0.0
	for j in range(ground.x, ground.y + 1):
		var joint := body.joints[j]
		var belly := joint.y - body.radii[j]
		sunk = maxf(sunk, float(body.height_at.call(joint)) - belly)
		if joint.x < 2.5 or joint.x > 8.5:
			floor_high = maxf(floor_high, belly)
	assert_lt(sunk, 0.15, "it rests on the step, not in it (sunk %.2f m)" % sunk)
	assert_lt(floor_high, 0.03, "and lies on the floor away from it (%.2f m up)" % floor_high)
	var steepest := 0.0
	for j in range(ground.x + 1, ground.y + 1):
		var a := body.joints[j - 1]
		var b := body.joints[j]
		var run := Vector2(a.x - b.x, a.z - b.z).length()
		if run > 0.01:
			steepest = maxf(steepest, absf(a.y - b.y) / run)
	assert_lt(steepest, SerpentBody.MAX_SLOPE + 0.05, "sloping off it each way")
	assert_gt(steepest, 0.6, "a hump, not a long ramp")


func test_a_slow_leader_lays_as_true_a_trail_as_a_quick_one_and_the_trail_stays_short() -> void:
	_lay_straight()
	var visited := PackedVector3Array()
	for i in 81:
		visited.append(_flat(-40.0 + i * 0.5, 0.0))
	# gliding at 1.2 m/s (0.02 m a frame, under the trail's step) along a wave
	var x := 0.0
	for i in 1500:
		x += 0.02
		var at := _flat(x, 0.25 * sin(TAU * x / 4.5))
		body.advance(at)
		visited.append(at)
	var ground := body.ground_joints()
	_spacing_ok("slowly along the wave", ground.x, ground.y)
	for j in range(ground.x, ground.y + 1):
		var on_ground := Vector3(body.joints[j].x, 0.0, body.joints[j].z)
		assert_lt(_distance_to_polyline(on_ground, visited), 0.004, "joint %d on the leader's wave" % j)
	assert_lt(body._trail.size(), 520, "the old trail is cut away (%d points)" % body._trail.size())
	assert_gt(body._trail.size(), 300, "and what the body needs is kept")
	assert_eq(body._trail.size(), body._trail_len.size(), "a length for every point")
	# a joint is where the trail says: its distance back along it
	assert_almost_eq(body.trail_point(0.0).x, body.leader().x, 0.0001)
	assert_lt(Vector3(body.trail_point(body.lying_length()).x, 0.0, body.trail_point(body.lying_length()).z).distance_to(Vector3(body.joints[ground.y].x, 0.0, body.joints[ground.y].z)), 0.25, "the tail's root about a body's length back along the trail")


func test_a_neck_is_left_alone_while_nothing_moved_and_laid_afresh_when_it_must() -> void:
	_lay_straight()
	var frame := body.root_frame(SerpentBody.End.A)
	var wanted: Vector3 = frame * Vector3(0.6, 2.0, -1.2)
	var look: Vector3 = frame.basis * Vector3(0.3, 0.2, -1.0)
	body.set_head(SerpentBody.End.A, wanted, look)
	body.update()
	var laid := body.joints.duplicate()
	# a hair's breadth (under the neck's epsilon): left as it was
	body.set_head(SerpentBody.End.A, wanted + Vector3(0.0004, 0.0, 0.0), look)
	body.update()
	for j in SerpentBody.NECK:
		assert_eq(body.joints[j], laid[j], "joint %d untouched by a half millimetre" % j)
	# drifting on by 0.4 mm a frame it never lags by more than the epsilon
	var target := wanted
	for i in 100:
		target += Vector3(0.0, 0.0004, 0.0)
		body.set_head(SerpentBody.End.A, target, look)
		body.update()
		assert_lt(body.joints[0].distance_to(target), 0.0015, "the head within a millimetre of its target (frame %d)" % i)
	assert_lt(body.joints[0].distance_to(target), 0.0015)
	_spacing_ok("after the drift", 0, SerpentBody.NECK)
	# a real move lays it afresh
	var before := body.joints[2]
	body.set_head(SerpentBody.End.A, target + Vector3(0.0, 0.0, 0.3), look)
	body.update()
	assert_gt(body.joints[2].distance_to(before), 0.01, "a 30 cm move lays the neck afresh")
	assert_lt(body.joints[0].distance_to(target + Vector3(0.0, 0.0, 0.3)), 0.0015)


func test_a_neck_found_from_the_last_ones_arch_is_the_one_found_cold() -> void:
	var root := Vector3(0.0, 0.5, 0.0)
	var length := float(SerpentBody.NECK) * SerpentBody.SPACING
	var memory := [-1.0]
	var poses := [
		[Vector3(1.8, 1.2, 0.4), Vector3(1.0, 0.0, 0.0)],
		[Vector3(1.82, 1.21, 0.4), Vector3(1.0, 0.0, 0.0)],   # next frame
		[Vector3(0.6, 2.2, -0.8), Vector3(0.0, 0.3, -1.0)],   # a big jump
		[Vector3(2.9, 0.4, 0.0), Vector3(1.0, -0.4, 0.0)],    # nearly full reach
		[Vector3(1.0, 0.9, 1.0), Vector3(0.0, 0.0, 1.0)],
	]
	for pose: Array in poses:
		var head: Vector3 = root + (pose[0] as Vector3)
		var warm := SerpentBody.bend(root, Vector3.RIGHT, head, pose[1], length, SerpentBody.NECK, memory)
		var cold := SerpentBody.bend(root, Vector3.RIGHT, head, pose[1], length, SerpentBody.NECK, [-1.0])
		assert_eq(warm.size(), SerpentBody.NECK + 1)
		for i in warm.size():
			assert_lt(warm[i].distance_to(cold[i]), 0.004, "point %d of the neck toward %s, warm or cold" % [i, pose[0]])
		for i in range(1, warm.size() - 1):
			assert_almost_eq(warm[i].distance_to(warm[i - 1]), SerpentBody.SPACING, 0.01, "link %d" % i)
		assert_lt(warm[SerpentBody.NECK].distance_to(head), 0.002, "on the head")
