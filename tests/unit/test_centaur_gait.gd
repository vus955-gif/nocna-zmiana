extends TestCase
## The Centaur's legs as pure timing (CentaurGait): standing it stands,
## galloping it beats four times a stride in the transverse order, trotting
## in diagonal pairs; a standing hoof never slides, a swinging one lifts;
## turning on the spot steps the hooves back under; gaits change without
## the hooves jumping.

const FL := 0
const FR := 1
const BL := 2
const BR := 3
const STEP := 1.0 / 60.0

var gait: CentaurGait
var yaw: float = 0.0
var at := Vector3.ZERO
var clock: float = 0.0
## [time, leg] of every touchdown.
var falls: Array = []


func before_each() -> void:
	gait = CentaurGait.new()
	yaw = 0.0
	at = Vector3.ZERO
	clock = 0.0
	falls = []
	gait.touchdown.connect(func(leg: int) -> void: falls.append([clock, leg]))
	gait.place(_body())


func _body() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _forward() -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


## [param seconds] at [param speed] m/s, turning [param turn] rad/s; calls
## [param each] (Callable(previous hooves)) every frame when given.
func _run(seconds: float, speed: float, turn: float = 0.0, each: Callable = Callable()) -> void:
	for i in roundi(seconds / STEP):
		var before: Array[Vector3] = []
		for leg in 4:
			before.append(gait.hoof(leg))
		var standing: Array[bool] = []
		for leg in 4:
			standing.append(gait.standing(leg))
		yaw += turn * STEP
		var velocity := _forward() * speed
		at += velocity * STEP
		clock += STEP
		gait.update(STEP, _body(), velocity)
		if each.is_valid():
			each.call(before, standing)


func test_standing_still_every_hoof_stands_on_its_rest() -> void:
	_run(2.0, 0.0)
	for leg in 4:
		assert_true(gait.standing(leg), "leg %d stands" % leg)
		var rest := _body() * Vector3(CentaurGait.NEUTRAL[leg].x, 0.0, CentaurGait.NEUTRAL[leg].z)
		assert_lt(Vector2(gait.hoof(leg).x - rest.x, gait.hoof(leg).z - rest.z).length(), 0.01)
		assert_almost_eq(gait.hoof(leg).y, CentaurGait.HOOF_HEIGHT, 0.001)
	assert_eq(falls.size(), 0, "no steps")


func test_a_gallop_beats_four_times_a_stride_in_the_transverse_order() -> void:
	_run(3.0, 10.0)
	assert_almost_eq(gait.gait, 3.0, 0.01, "a gallop at 10 m/s")
	falls.clear()
	var period := 1.0 / gait.frequency
	_run(period * 3.0, 10.0)
	# one stride from the first left-hind landing
	var start := -1
	for i in falls.size():
		if int(falls[i][1]) == BL:
			start = i
			break
	assert_true(start >= 0, "the left hind lands")
	var stride: Array = falls.slice(start, start + 4)
	var order: Array = stride.map(func(entry: Array) -> int: return int(entry[1]))
	assert_eq(order, [BL, BR, FL, FR], "hind, hind, fore, fore (right lead)")
	var span := float(stride[3][0]) - float(stride[0][0])
	assert_lt(span, period * 0.8, "then a moment of flight")
	for i in range(1, 4):
		assert_gt(float(stride[i][0]) - float(stride[i - 1][0]), 0.015, "four distinct beats")


func test_a_trot_lands_in_diagonal_pairs() -> void:
	_run(3.0, 3.2)
	assert_almost_eq(gait.gait, 1.0, 0.05, "a trot at 3.2 m/s")
	falls.clear()
	_run(2.0, 3.2)
	var last := {}
	for entry: Array in falls:
		last[int(entry[1])] = float(entry[0])
	assert_lt(absf(float(last[FL]) - float(last[BR])), 0.04, "left fore with right hind")
	assert_lt(absf(float(last[FR]) - float(last[BL])), 0.04, "right fore with left hind")
	assert_gt(absf(float(last[FL]) - float(last[FR])), 0.15, "the two pairs apart")


func test_a_standing_hoof_never_slides_and_a_swinging_one_lifts() -> void:
	var slid := [0.0]
	var highest := [0.0]
	var farthest := [0.0]
	var check := func(before: Array[Vector3], stood: Array[bool]) -> void:
		for leg in 4:
			if stood[leg] and gait.standing(leg):
				slid[0] = maxf(slid[0], before[leg].distance_to(gait.hoof(leg)))
			highest[0] = maxf(highest[0], gait.hoof(leg).y)
			if gait.standing(leg):
				var local := _body().affine_inverse() * gait.hoof(leg)
				farthest[0] = maxf(farthest[0], absf(local.z - CentaurGait.NEUTRAL[leg].z))
	_run(2.0, 10.0, 0.0, check)
	_run(2.0, 9.0, 1.2, check)
	_run(1.5, 15.5, 0.0, check)
	assert_lt(slid[0], 0.0001, "planted hooves stay put in the world")
	assert_gt(highest[0], CentaurGait.HOOF_HEIGHT + 0.15, "swinging hooves lift")
	assert_lt(farthest[0], CentaurGait.MAX_SWEEP * 0.5 + 0.15, "a standing hoof stays under its leg")


func test_turning_on_the_spot_steps_the_hooves_back_under() -> void:
	_run(1.5, 0.0, PI * 0.5 / 1.5)
	assert_gt(falls.size(), 2, "it stepped round")
	_run(1.5, 0.0)
	for leg in 4:
		assert_true(gait.standing(leg))
		var rest := _body() * Vector3(CentaurGait.NEUTRAL[leg].x, 0.0, CentaurGait.NEUTRAL[leg].z)
		assert_lt(Vector2(gait.hoof(leg).x - rest.x, gait.hoof(leg).z - rest.z).length(), CentaurGait.SETTLE + 0.01,
				"leg %d back under its shoulder or hip" % leg)


func test_from_a_walk_to_a_gallop_the_hooves_never_jump() -> void:
	var jump := [0.0]
	var check := func(before: Array[Vector3], _stood: Array[bool]) -> void:
		for leg in 4:
			jump[0] = maxf(jump[0], before[leg].distance_to(gait.hoof(leg)))
	for i in 60:
		_run(0.05, 0.2 * i, 0.0, check)
	assert_gt(gait.gait, 2.9, "galloping at the end")
	assert_lt(jump[0], 0.45, "no hoof leaps between two frames")
	# and a lead change in a turn the other way
	_run(1.5, 10.0, -1.0, check)
	assert_almost_eq(gait.lead, 1.0, 0.001, "right lead turning right")
	_run(1.5, 10.0, 1.0, check)
	assert_almost_eq(gait.lead, -1.0, 0.001, "left lead turning left")
	assert_lt(jump[0], 0.45)
