extends TestCase
## ReliefMoves: flatness, the thrown spear's arc, the warrior's choice of
## move, sidesteps, the wall's cooldown and the places along the wall.


func test_a_hit_on_the_edge_does_half() -> void:
	var facing := Vector3.FORWARD
	assert_eq(ReliefMoves.edge_factor(facing, Vector3.BACK), 1.0, "on the carved face")
	assert_eq(ReliefMoves.edge_factor(facing, Vector3.FORWARD), 1.0, "on its back (flat too)")
	assert_eq(ReliefMoves.edge_factor(facing, Vector3.RIGHT), 0.5, "on the edge")
	assert_eq(ReliefMoves.edge_factor(facing, Basis(Vector3.UP, deg_to_rad(70.0)) * Vector3.BACK), 0.5, "70 degrees off")
	assert_eq(ReliefMoves.edge_factor(facing, Basis(Vector3.UP, deg_to_rad(40.0)) * Vector3.BACK), 1.0, "40 degrees off")


func test_the_spear_lands_where_it_is_thrown() -> void:
	var from := Vector3(0, 1.6, 0)
	var to := Vector3(3, 1.2, -9)
	var launch: Variant = ReliefMoves.throw_velocity(from, to)
	assert_not_null(launch)
	var v: Vector3 = launch
	assert_almost_eq(v.length(), ReliefMoves.THROW_SPEED, 0.01)
	# fly it
	var at := from
	var closest := INF
	for i in 300:
		v.y -= ReliefMoves.THROW_GRAVITY / 120.0
		at += v / 120.0
		closest = minf(closest, at.distance_to(to))
	assert_lt(closest, 0.15, "it comes down on him")
	assert_gt(v.y, -100.0)


func test_out_of_reach_there_is_no_throw() -> void:
	assert_eq(ReliefMoves.throw_velocity(Vector3.ZERO, Vector3(0, 0, -60)), null)


func test_it_throws_at_range_and_strikes_up_close() -> void:
	var moves := ReliefMoves.new()
	assert_eq(moves.planned(10.0), ReliefMoves.Move.THROW)
	assert_eq(moves.planned(1.5), ReliefMoves.Move.STRIKE)
	assert_eq(moves.attack_range(10.0), ReliefMoves.THROW_RANGE.y)
	moves.thrown()
	assert_eq(moves.planned(10.0), ReliefMoves.Move.STRIKE, "the spear grows back first")
	assert_eq(moves.attack_range(10.0), ReliefMoves.STRIKE_RANGE)
	moves.tick(ReliefMoves.THROW_COOLDOWN + 0.01)
	assert_eq(moves.planned(10.0), ReliefMoves.Move.THROW)


func test_sidesteps_and_the_wall_have_cooldowns() -> void:
	var moves := ReliefMoves.new()
	assert_true(moves.sidestep())
	assert_false(moves.sidestep())
	moves.tick(ReliefMoves.SIDESTEP_COOLDOWN)
	assert_true(moves.sidestep())
	assert_true(moves.sink())
	moves.tick(7.9)
	assert_false(moves.sink(), "once every 8 s")
	moves.tick(0.2)
	assert_true(moves.sink())


func test_the_guard_aiming_at_it() -> void:
	var eye := Vector3(0, 1.6, 0)
	assert_true(ReliefMoves.aimed_at(eye, Vector3.FORWARD, Vector3(0.3, 1.4, -10)))
	assert_false(ReliefMoves.aimed_at(eye, Vector3.FORWARD, Vector3(3, 1.4, -10)))


func test_places_along_the_wall_away_from_the_guard_first() -> void:
	var spots := ReliefMoves.slide_spots(Vector3.ZERO, Vector3.BACK, Vector3(-5, 0, 3))
	assert_eq(spots.size(), 2)
	assert_almost_eq(spots[0].distance_to(Vector3.ZERO), 6.0, 0.001)
	assert_almost_eq(absf(spots[0].z), 0.0, 0.001, "along the wall")
	assert_gt(spots[0].x, 0.0, "away from the guard first")
