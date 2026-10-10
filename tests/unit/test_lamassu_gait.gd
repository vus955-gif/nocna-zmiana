extends TestCase
## The Lamassu's hooves as pure footing (LamassuGait): placed, they stand
## under their contact markers; walking, they lift in the lateral four-beat
## order (left hind, left fore, right hind, right fore) with never fewer
## than three on the floor, a planted hoof never slides and a landing one
## comes down ahead of its rest; stopping, they settle back under the body;
## turning on the spot steps them round; the gallop lifts them in pairs
## (hind, then fore) with a moment of flight; a skid drags them with the
## body; a step on command reaches its point in its time; in the air they
## all tuck up and land together.

const FL := 0
const FR := 1
const BL := 2
const BR := 3
const STEP := 1.0 / 60.0
const M := LamassuGait.Mode

var gait: LamassuGait
var yaw: float = 0.0
var at := Vector3.ZERO
var clock: float = 0.0
## [time, leg] of every lift and every landing.
var lifts: Array = []
var lands: Array = []


func before_each() -> void:
	gait = LamassuGait.new()
	yaw = 0.0
	at = Vector3.ZERO
	clock = 0.0
	lifts = []
	lands = []
	gait.lifted.connect(func(leg: int) -> void: lifts.append([clock, leg]))
	gait.landed.connect(func(leg: int) -> void: lands.append([clock, leg]))
	gait.place(_body())


func _body() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _forward() -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


func _rest(leg: int) -> Vector3:
	return _body() * LamassuGait.NEUTRAL[leg]


func _down() -> int:
	var count := 0
	for leg in 4:
		if gait.planted(leg):
			count += 1
	return count


## [param seconds] at [param speed] m/s in [param mode], turning
## [param turn] rad/s; calls [param each] (Callable(previous feet, previous
## planted flags)) every frame when given.
func _run(seconds: float, speed: float, mode: M, turn: float = 0.0, each: Callable = Callable()) -> void:
	for i in roundi(seconds / STEP):
		var before: Array[Vector3] = []
		var stood: Array[bool] = []
		for leg in 4:
			before.append(gait.feet[leg])
			stood.append(gait.planted(leg))
		yaw += turn * STEP
		var velocity := _forward() * speed
		at += velocity * STEP
		clock += STEP
		gait.update(STEP, _body(), velocity, turn, mode)
		if each.is_valid():
			each.call(before, stood)


func test_placed_every_hoof_stands_under_its_contact_marker() -> void:
	yaw = 0.7
	at = Vector3(3.0, 0.0, -2.0)
	gait.place(_body())
	for leg in 4:
		assert_true(gait.planted(leg), "leg %d planted" % leg)
		assert_lt(gait.feet[leg].distance_to(_rest(leg)), 0.001, "leg %d under its marker" % leg)
	_run(1.0, 0.0, M.STAND)
	assert_eq(lifts.size(), 0, "standing, nothing moves")
	assert_false(gait.stepping)


func test_walking_lifts_the_hooves_laterally_with_three_always_down_and_none_sliding() -> void:
	var fewest := [4]
	var slid := [0.0]
	var check := func(before: Array[Vector3], stood: Array[bool]) -> void:
		fewest[0] = mini(fewest[0], _down())
		for leg in 4:
			if stood[leg] and gait.planted(leg):
				slid[0] = maxf(slid[0], before[leg].distance_to(gait.feet[leg]))
	_run(6.0, 1.9, M.WALK, 0.0, check)
	assert_gt(lifts.size(), 8, "it walked")
	assert_true(fewest[0] >= 3, "never fewer than three hooves down (%d)" % fewest[0])
	assert_lt(slid[0], 0.0001, "a planted hoof never slides")
	# the lateral sequence from the first left-hind lift
	var start := -1
	for i in lifts.size():
		if int(lifts[i][1]) == BL and i + 3 < lifts.size():
			start = i
			break
	assert_true(start >= 0, "the left hind lifts")
	if start >= 0:
		var order: Array = lifts.slice(start, start + 4).map(func(entry: Array) -> int: return int(entry[1]))
		assert_eq(order, [BL, FL, BR, FR], "left hind, left fore, right hind, right fore")
	# a landing hoof comes down ahead of its rest under the body
	var ahead := [0]
	var behind := [0]
	var landing := func(_before: Array[Vector3], stood: Array[bool]) -> void:
		for leg in 4:
			if not stood[leg] and gait.planted(leg):
				var local := _body().affine_inverse() * gait.feet[leg]
				if local.z < LamassuGait.NEUTRAL[leg].z - 0.05:
					ahead[0] += 1
				else:
					behind[0] += 1
	_run(4.0, 1.9, M.WALK, 0.0, landing)
	assert_gt(ahead[0], 0, "hooves land ahead of their rest")
	assert_eq(behind[0], 0, "never behind it")


func test_stopping_the_hooves_settle_under_the_body_and_the_gait_stands() -> void:
	_run(3.0, 1.9, M.WALK)
	_run(2.5, 0.0, M.STAND)
	assert_false(gait.stepping, "the gait stands")
	for leg in 4:
		assert_true(gait.planted(leg))
		var off := gait.feet[leg] - _rest(leg)
		assert_lt(Vector2(off.x, off.z).length(), LamassuGait.SETTLE + 0.01, "leg %d back under its marker" % leg)
		assert_almost_eq(gait.feet[leg].y, 0.0, 0.001, "on the floor")


func test_turning_on_the_spot_steps_the_hooves_round() -> void:
	_run(2.0, 0.0, M.WALK, PI * 0.5 / 2.0)
	assert_gt(lifts.size(), 2, "it stepped round")
	_run(2.0, 0.0, M.STAND)
	for leg in 4:
		assert_true(gait.planted(leg))
		var off := gait.feet[leg] - _rest(leg)
		assert_lt(Vector2(off.x, off.z).length(), LamassuGait.SETTLE + 0.01, "leg %d under the turned body" % leg)


func test_the_gallop_lifts_in_pairs_with_a_moment_of_flight() -> void:
	var none := [0]
	var check := func(_before: Array[Vector3], _stood: Array[bool]) -> void:
		if _down() == 0:
			none[0] += 1
	_run(3.0, 12.0, M.GALLOP, 0.0, check)
	lifts.clear()
	none[0] = 0
	_run(1.5, 12.0, M.GALLOP, 0.0, check)
	assert_gt(none[0], 5, "moments with no hoof on the floor")
	# every hind lift is followed by the other hind within a beat, and the
	# fore pair comes after the hind pair
	var pairs := 0
	for i in range(lifts.size() - 1):
		var a: Array = lifts[i]
		var b: Array = lifts[i + 1]
		var hinds := (int(a[1]) >= BL) == (int(b[1]) >= BL)
		if hinds and float(b[0]) - float(a[0]) < 0.08:
			pairs += 1
	assert_gt(pairs, 3, "the hooves lift in pairs (%d)" % pairs)
	var start := -1
	for i in lifts.size():
		if int(lifts[i][1]) == BL and i + 3 < lifts.size():
			start = i
			break
	assert_true(start >= 0)
	if start >= 0:
		var order: Array = lifts.slice(start, start + 4).map(func(entry: Array) -> int: return int(entry[1]))
		assert_true(order[0] >= BL and order[1] >= BL and order[2] < BL and order[3] < BL, "hind pair, then fore pair: %s" % str(order))
	assert_gt(gait.frequency, 1.5, "a quick stride at speed")


func test_a_skid_drags_the_hooves_with_the_body() -> void:
	_run(2.0, 12.0, M.GALLOP)
	var locals: Array[Vector3] = []
	_run(STEP, 12.0, M.SKID)
	for leg in 4:
		assert_true(gait.planted(leg), "every hoof down in the skid")
		locals.append(_body().affine_inverse() * gait.feet[leg])
	var moved := [0.0]
	var check := func(before: Array[Vector3], _stood: Array[bool]) -> void:
		for leg in 4:
			moved[0] += before[leg].distance_to(gait.feet[leg])
	_run(0.5, 8.0, M.SKID, 0.0, check)
	assert_gt(moved[0], 1.0, "the hooves slide along")
	for leg in 4:
		var local := _body().affine_inverse() * gait.feet[leg]
		assert_lt(local.distance_to(locals[leg]), 0.02, "leg %d keeps its place under the body" % leg)
	assert_eq(lifts.size() - lands.size(), 0, "no steps in a skid")


func test_a_step_on_command_reaches_its_point_in_its_time() -> void:
	var target := _rest(FL) + Vector3(0.4, -0.5, -1.2)
	gait.step_to(FL, target, 0.6)
	assert_false(gait.planted(FL), "the hoof lifts at once")
	var highest := [0.0]
	var check := func(_before: Array[Vector3], _stood: Array[bool]) -> void:
		highest[0] = maxf(highest[0], gait.feet[FL].y)
	_run(0.3, 0.0, M.HOLD, 0.0, check)
	assert_false(gait.planted(FL), "still in the air half way")
	assert_gt(highest[0], 0.1, "it rises on the way")
	_run(0.32, 0.0, M.HOLD, 0.0, check)
	assert_true(gait.planted(FL), "down in its time")
	assert_lt(gait.feet[FL].distance_to(target), 0.01, "on its point")
	for leg in [FR, BL, BR]:
		assert_lt(gait.feet[leg].distance_to(_rest(leg)), 0.001, "the others held")
	assert_eq(lands.size(), 1)


func test_in_the_air_every_hoof_tucks_up_and_they_land_together() -> void:
	_run(1.0, 0.0, M.STAND)
	at += Vector3(0.0, 2.0, -3.0)
	_run(0.5, 0.0, M.AIR)
	for leg in 4:
		assert_false(gait.planted(leg), "leg %d off the floor" % leg)
		var local := _body().affine_inverse() * gait.feet[leg]
		assert_gt(local.y, 0.3, "leg %d tucked up" % leg)
	lands.clear()
	at.y = 0.0
	_run(STEP, 0.0, M.STAND)
	assert_eq(lands.size(), 4, "all four land at once")
	for leg in 4:
		assert_true(gait.planted(leg))
		assert_lt(gait.feet[leg].distance_to(_rest(leg)), 0.05, "leg %d under the body" % leg)
