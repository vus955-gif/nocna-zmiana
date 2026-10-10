extends TestCase
## The General's feet (GeneralFootwork): suri-ashi - planted in the world,
## the leading foot slides first and the rear one draws up after it, never
## both off the floor at once, low; standing he does not shuffle; turning on
## the spot he steps round; in a dash the feet are carried along and
## planted again where he lands.

const STEP := 1.0 / 60.0

var feet: GeneralFootwork


func before_each() -> void:
	feet = GeneralFootwork.new()


func _body(at: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _walk(from: Vector3, direction: Vector3, speed: float, seconds: float, yaw: float = 0.0) -> Transform3D:
	var at := from
	var body := _body(at, yaw)
	for i in roundi(seconds / STEP):
		at += direction * speed * STEP
		body = _body(at, yaw)
		feet.update(STEP, body, direction * speed)
		assert_false(not feet.standing(0) and not feet.standing(1), "both feet off the floor at %.2f s" % (i * STEP))
	return body


func test_standing_he_keeps_his_feet_where_they_are() -> void:
	var body := _body(Vector3(3.0, 0.0, -5.0), 0.4)
	feet.place(body)
	var left := feet.foot(0)
	var right := feet.foot(1)
	assert_almost_eq(left.y, GeneralFootwork.FOOT_HEIGHT, 0.001, "ankles over the floor")
	var local_r := body.affine_inverse() * right
	var local_l := body.affine_inverse() * left
	assert_lt(local_r.z, local_l.z, "the right foot leads (chudan)")
	assert_gt(local_r.x, 0.0, "right on the right")
	for i in 120:
		feet.update(STEP, body, Vector3.ZERO)
	assert_lt(feet.foot(0).distance_to(left), 0.001, "no shuffling")
	assert_lt(feet.foot(1).distance_to(right), 0.001)
	assert_false(feet.stepping)


func test_walking_forward_the_leading_foot_slides_first_and_the_feet_keep_up() -> void:
	var start := Vector3(0.0, 0.0, 0.0)
	feet.place(_body(start))
	var order: Array[int] = []
	feet.step.connect(func(foot: int) -> void: order.append(foot))
	var lifted := [-1]
	feet.slide.connect(func(foot: int) -> void:
		if lifted[0] < 0:
			lifted[0] = foot)
	var body := _walk(start, Vector3.FORWARD, 2.0, 4.0)
	assert_eq(lifted[0], 1, "the right (leading) foot slides first going forward")
	assert_gt(order.size(), 6, "steps along the way")
	for foot in 2:
		var local := body.affine_inverse() * feet.foot(foot)
		var rest := GeneralFootwork.NEUTRAL[foot]
		assert_lt(Vector2(local.x - rest.x, local.z - rest.z).length(), GeneralFootwork.TRIGGER + 0.3, "foot %d keeps up" % foot)
		assert_almost_eq(feet.foot(foot).y, GeneralFootwork.FOOT_HEIGHT, 0.06, "low over the gravel")
	assert_true(feet.stepping)


func test_a_slide_lifts_the_foot_a_little_and_lands_it_ahead() -> void:
	feet.place(_body(Vector3.ZERO))
	var highest := 0.0
	var body := _body(Vector3.ZERO)
	var at := Vector3.ZERO
	for i in 90:
		at += Vector3.FORWARD * 1.5 * STEP
		body = _body(at)
		feet.update(STEP, body, Vector3.FORWARD * 1.5)
		for foot in 2:
			highest = maxf(highest, feet.foot(foot).y - GeneralFootwork.FOOT_HEIGHT)
			if not feet.standing(foot):
				assert_true(feet.swing(foot) >= 0.0 and feet.swing(foot) <= 1.0)
	assert_gt(highest, 0.01, "the foot comes off the gravel")
	assert_lt(highest, 0.08, "but barely: a slide, not a step")


func test_turning_on_the_spot_he_steps_round() -> void:
	var at := Vector3(2.0, 0.0, 2.0)
	feet.place(_body(at, 0.0))
	var steps := watch(feet.step)
	var yaw := 0.0
	for i in 120:
		yaw += 1.6 * STEP
		feet.update(STEP, _body(at, yaw), Vector3.ZERO)
		assert_false(not feet.standing(0) and not feet.standing(1), "one foot always down")
	assert_gt(steps.size(), 1, "he stepped round")
	var body := _body(at, yaw)
	for foot in 2:
		var local := body.affine_inverse() * feet.foot(foot)
		var rest := GeneralFootwork.NEUTRAL[foot]
		assert_lt(Vector2(local.x - rest.x, local.z - rest.z).length(), 0.5, "foot %d turned with him" % foot)


func test_a_dash_carries_the_feet_and_plants_them_where_he_lands() -> void:
	feet.place(_body(Vector3.ZERO))
	var at := Vector3.ZERO
	var steps := watch(feet.step)
	for i in 14:
		at += Vector3.FORWARD * 28.0 * STEP
		feet.update(STEP, _body(at), Vector3.FORWARD * 28.0)
		assert_true(feet.carried, "carried along in the dash")
	assert_eq(steps.size(), 0, "no steps in flight")
	var body := _body(at)
	for foot in 2:
		var local := body.affine_inverse() * feet.foot(foot)
		assert_lt(Vector2(local.x - GeneralFootwork.NEUTRAL[foot].x, local.z - GeneralFootwork.NEUTRAL[foot].z).length(), 0.3, "foot %d under him" % foot)
	feet.update(STEP, body, Vector3.ZERO)
	assert_false(feet.carried)
	assert_true(feet.standing(0) and feet.standing(1), "planted on landing")


func test_flown_off_the_floor_the_feet_hang_under_him_whatever_his_speed() -> void:
	feet.place(_body(Vector3.ZERO))
	var at := Vector3.ZERO
	var steps := watch(feet.step)
	# a leap up to the eave: slow along the ground, 1.4 m up at the apex
	for i in 54:
		var k := float(i + 1) / 54.0
		at = Vector3(-3.9 * k, 1.4 * sin(PI * k), -1.6 * k)
		feet.update(STEP, _body(at), Vector3(-3.9, 0.0, -1.6) / 0.9, true)
		assert_true(feet.carried, "carried at %d" % i)
		for foot in 2:
			assert_almost_eq(feet.foot(foot).y, at.y + GeneralFootwork.FOOT_HEIGHT, 0.001, "foot %d hangs under him" % foot)
	assert_eq(steps.size(), 0, "no steps in the air")


func test_the_leading_foot_is_the_one_toward_the_move() -> void:
	feet.place(_body(Vector3.ZERO))
	var lifted := [-1]
	feet.slide.connect(func(foot: int) -> void:
		if lifted[0] < 0:
			lifted[0] = foot)
	_walk(Vector3.ZERO, Vector3.BACK, 1.5, 1.0)
	assert_eq(lifted[0], 0, "stepping back the left (rear) foot goes first")
