extends TestCase
## JaguarMoves (design pietro-1-projekt 5.6): which attack the jaguar
## warrior starts, the pounce that lands short of the guard, the phases of
## the club combination after landing, the club's cone and the recovery.


func test_which_move_by_distance() -> void:
	assert_eq(JaguarMoves.choose(1.5), JaguarMoves.Move.CLUB)
	assert_eq(JaguarMoves.choose(2.7), JaguarMoves.Move.CLUB, "too close for a pounce: the club")
	assert_eq(JaguarMoves.choose(3.0), JaguarMoves.Move.POUNCE)
	assert_eq(JaguarMoves.choose(5.0), JaguarMoves.Move.POUNCE)
	assert_eq(JaguarMoves.choose(7.0), JaguarMoves.Move.POUNCE)
	assert_eq(JaguarMoves.choose(8.0), JaguarMoves.Move.NONE, "out of reach: it closes in")


## Flies the leap [param run] (m/s, horizontal) with [param lift] in steps
## of a sixtieth until it is back on the floor; where it lands.
func _land(from: Vector3, run: Vector3, lift: float, gravity: float) -> Vector3:
	var at := from
	var vy := lift
	var dt := 1.0 / 60.0
	for i in 600:
		at += (run + Vector3.UP * vy) * dt
		vy -= gravity * dt
		if at.y <= from.y and vy < 0.0:
			break
	return at


func test_the_leap_lands_short_of_the_guard() -> void:
	var from := Vector3.ZERO
	var to := Vector3(0, 0, -5)
	var run := JaguarMoves.leap(from, to, JaguarMoves.LIFT, Enemy.GRAVITY, JaguarMoves.MAX_SPEED)
	assert_almost_eq(run.y, 0.0, 0.001, "horizontal")
	var landed := _land(from, run, JaguarMoves.LIFT, Enemy.GRAVITY)
	var short := landed.distance_to(Vector3(to.x, 0.0, to.z))
	assert_almost_eq(short, JaguarMoves.STOP_SHORT, 0.3, "lands %.2f m before him (a frame of overshoot)" % short)
	assert_lt(landed.z, 0.0, "toward him")
	var airtime := JaguarMoves.airtime(JaguarMoves.LIFT, Enemy.GRAVITY)
	assert_almost_eq(airtime, 2.0 * JaguarMoves.LIFT / Enemy.GRAVITY, 0.001)
	var far := JaguarMoves.leap(from, Vector3(0, 0, -7), JaguarMoves.LIFT, Enemy.GRAVITY, JaguarMoves.MAX_SPEED)
	assert_almost_eq(far.length(), JaguarMoves.MAX_SPEED, 0.001, "never faster than the cap")
	var slow := JaguarMoves.leap(from, Vector3(0, 0, -1.6), JaguarMoves.LIFT, Enemy.GRAVITY, JaguarMoves.MAX_SPEED)
	assert_gt(slow.length(), 0.0, "a hop at least")


func test_the_phases_after_landing_follow_in_order() -> void:
	assert_eq(JaguarMoves.phase_after_landing(-0.1), JaguarMoves.Phase.AIR)
	assert_eq(JaguarMoves.phase_after_landing(0.0), JaguarMoves.Phase.SETTLE)
	assert_eq(JaguarMoves.phase_after_landing(JaguarMoves.SETTLE - 0.01), JaguarMoves.Phase.SETTLE)
	assert_eq(JaguarMoves.phase_after_landing(JaguarMoves.SETTLE + 0.01), JaguarMoves.Phase.SWING)
	assert_eq(JaguarMoves.phase_after_landing(JaguarMoves.SETTLE + JaguarMoves.SWING + 0.01), JaguarMoves.Phase.STUCK)
	assert_eq(JaguarMoves.phase_after_landing(JaguarMoves.SETTLE + JaguarMoves.SWING + JaguarMoves.STUCK + 0.01), JaguarMoves.Phase.DONE)
	assert_almost_eq(JaguarMoves.swing_time(), JaguarMoves.SETTLE + JaguarMoves.SWING, 0.001, "the blow lands at the end of the swing")


func test_the_club_hits_in_front_within_reach() -> void:
	var facing := Vector3(0, 0, -1)
	assert_true(JaguarMoves.swing_hits(facing, Vector3(0, 0, -2.0), JaguarMoves.SWING_REACH, JaguarMoves.SWING_HALF_ARC))
	assert_true(JaguarMoves.swing_hits(facing, Vector3(0, 0, -2.0).rotated(Vector3.UP, deg_to_rad(45.0)), JaguarMoves.SWING_REACH, JaguarMoves.SWING_HALF_ARC))
	assert_false(JaguarMoves.swing_hits(facing, Vector3(0, 0, -2.0).rotated(Vector3.UP, deg_to_rad(70.0)), JaguarMoves.SWING_REACH, JaguarMoves.SWING_HALF_ARC), "beside it")
	assert_false(JaguarMoves.swing_hits(facing, Vector3(0, 0, -2.8), JaguarMoves.SWING_REACH, JaguarMoves.SWING_HALF_ARC), "too far")
	assert_false(JaguarMoves.swing_hits(facing, Vector3(0, 1.2, -2.0), JaguarMoves.SWING_REACH, JaguarMoves.SWING_HALF_ARC), "a guard a storey up is out of the club's reach")


func test_the_recoveries_cover_the_whole_combination() -> void:
	var pounce := JaguarMoves.pounce_recovery(JaguarMoves.LIFT, Enemy.GRAVITY)
	var combination := JaguarMoves.airtime(JaguarMoves.LIFT, Enemy.GRAVITY) + JaguarMoves.SETTLE + JaguarMoves.SWING + JaguarMoves.STUCK
	assert_true(pounce >= combination, "flight, settling, the blow and the club stuck in the floor")
	assert_lt(pounce, combination + 0.5, "and not much more")
	assert_almost_eq(JaguarMoves.club_recovery(), JaguarMoves.SWING + JaguarMoves.STUCK, 0.001)
	assert_almost_eq(JaguarMoves.windup(JaguarMoves.Move.POUNCE), 0.6, 0.001, "the 0.6 s crouch")
	assert_almost_eq(JaguarMoves.windup(JaguarMoves.Move.CLUB), 0.6, 0.001, "the 0.6 s raise")
