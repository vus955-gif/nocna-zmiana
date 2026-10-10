extends TestCase
## MummyMoves: which attack the mummy starts (bandage lash or claws), the
## lash's reach, cone and pull, the fire panic and the climb out of a tomb.


func test_a_ready_lash_is_planned_in_its_band() -> void:
	var moves := MummyMoves.new()
	assert_eq(moves.planned(3.5), MummyMoves.Move.LASH)
	assert_eq(moves.planned(4.6), MummyMoves.Move.LASH)
	assert_eq(moves.planned(1.5), MummyMoves.Move.CLAW, "too close for the whip")
	assert_eq(moves.planned(5.0), MummyMoves.Move.CLAW, "out of the whip's reach: it walks on")


func test_the_brain_range_follows_the_lash() -> void:
	var moves := MummyMoves.new()
	assert_eq(moves.attack_range(3.5), MummyMoves.LASH_MAX)
	assert_eq(moves.attack_range(8.0), MummyMoves.LASH_MAX, "it starts the lash as soon as he is in reach")
	assert_eq(moves.attack_range(2.0), MummyMoves.CLAW_RANGE, "inside the whip's band: claws")
	moves.lash_struck()
	assert_eq(moves.attack_range(3.5), MummyMoves.CLAW_RANGE, "after a lash only the claws")
	assert_eq(moves.planned(3.5), MummyMoves.Move.CLAW)


func test_the_lash_comes_back_after_its_cooldown() -> void:
	var moves := MummyMoves.new()
	moves.lash_struck()
	moves.tick(MummyMoves.LASH_COOLDOWN - 0.1)
	assert_eq(moves.planned(3.5), MummyMoves.Move.CLAW)
	moves.tick(0.2)
	assert_eq(moves.planned(3.5), MummyMoves.Move.LASH)


func test_timings_per_move() -> void:
	var moves := MummyMoves.new()
	assert_eq(moves.windup(MummyMoves.Move.LASH), 0.6, "the design's 0.6 s telegraph")
	assert_eq(moves.windup(MummyMoves.Move.CLAW), MummyMoves.CLAW_WINDUP)
	assert_gt(moves.recovery(MummyMoves.Move.LASH), moves.recovery(MummyMoves.Move.CLAW), "the whip coils back slowly: an opening")


func test_lash_cone_and_reach() -> void:
	var moves := MummyMoves.new()
	var facing := Vector3.FORWARD
	assert_true(moves.lash_hits(facing, Vector3(0, 0, -3.5)))
	assert_true(moves.lash_hits(facing, Basis(Vector3.UP, deg_to_rad(10.0)) * Vector3(0, 0, -3.5)))
	assert_false(moves.lash_hits(facing, Basis(Vector3.UP, deg_to_rad(30.0)) * Vector3(0, 0, -3.5)), "stepped out of its line")
	assert_false(moves.lash_hits(facing, Vector3(0, 0, -5.5)), "backed out of reach")
	assert_true(moves.lash_hits(facing, Vector3(0, 1.0, -3.0)), "height does not matter")


func test_pull_brings_him_to_the_claws_but_not_into_the_body() -> void:
	assert_almost_eq(MummyMoves.pull_distance(4.6), 3.0, 0.001, "3 m at most")
	assert_almost_eq(MummyMoves.pull_distance(3.6), 2.4, 0.001, "stops 1.2 m short")
	assert_almost_eq(MummyMoves.pull_distance(1.0), 0.0, 0.001)


func test_fire_panics_with_a_cooldown() -> void:
	var moves := MummyMoves.new()
	assert_true(moves.catch_fire(), "first fire: panic")
	assert_true(moves.panicking())
	moves.tick(1.0)
	assert_false(moves.catch_fire(), "already burning and running")
	moves.tick(1.1)
	assert_false(moves.panicking(), "2 s of panic")
	assert_false(moves.catch_fire(), "not again so soon")
	moves.tick(3.0)
	assert_true(moves.catch_fire(), "5 s after the last panic")


func test_panic_runs_away_from_the_guard_with_swerves() -> void:
	var moves := MummyMoves.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var away := Vector3(1, 0, 0)
	var turned := false
	for i in 40:
		var heading := moves.panic_heading(away, rng)
		assert_almost_eq(heading.length(), 1.0, 0.001)
		assert_almost_eq(heading.y, 0.0, 0.001)
		assert_gt(heading.dot(away), 0.5, "always away from him")
		if heading.dot(away) < 0.95:
			turned = true
	assert_true(turned, "it zigzags")


func test_climbing_out_of_a_coffin_and_a_sarcophagus() -> void:
	assert_almost_eq(MummyMoves.rise_length(MummyMoves.Tomb.COFFIN), 1.4, 0.001)
	assert_almost_eq(MummyMoves.rise_length(MummyMoves.Tomb.SARCOPHAGUS), 1.9, 0.001)
	for style in [MummyMoves.Tomb.COFFIN, MummyMoves.Tomb.SARCOPHAGUS]:
		var before := Vector3.ZERO
		var length := MummyMoves.rise_length(style)
		for i in 21:
			var phases := MummyMoves.rise_phases(style, length * i / 20.0)
			assert_true(phases.x >= before.x and phases.y >= before.y and phases.z >= before.z, "phases only grow")
			before = phases
		assert_true(before.is_equal_approx(Vector3.ONE), "all done at the end")
	var early := MummyMoves.rise_phases(MummyMoves.Tomb.COFFIN, 0.2)
	assert_gt(early.x, 0.0, "the lid moves first")
	assert_eq(early.y, 0.0)
	assert_eq(early.z, 0.0)
