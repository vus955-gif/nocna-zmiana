extends TestCase
## FuDogMoves (design pietro-1-projekt 5.5): which move the bronze Fu dog
## starts (the paw up close, the roar or the charge from the front, the
## charge from afar), the roar's cone, the charge's early steer, and the
## pair that charges one at a time and never at a staggered guard.


func test_up_close_and_in_front_it_paws() -> void:
	assert_eq(FuDogMoves.choose(2.0, 10.0, true, true, 0.5, 0.4), FuDogMoves.Move.PAW)
	assert_eq(FuDogMoves.choose(2.5, 45.0, false, false, 0.5, 0.4), FuDogMoves.Move.PAW, "the paw needs no roar and no leave to charge")
	assert_eq(FuDogMoves.choose(2.0, 70.0, false, false, 0.5, 0.4), FuDogMoves.Move.NONE, "beside it: it turns first")


func test_in_the_roar_cone_it_roars_or_charges_by_the_roll() -> void:
	assert_eq(FuDogMoves.choose(5.0, 20.0, true, true, 0.3, 0.4), FuDogMoves.Move.ROAR, "a low roll roars")
	assert_eq(FuDogMoves.choose(5.0, 20.0, true, true, 0.7, 0.4), FuDogMoves.Move.CHARGE, "a high roll charges")
	assert_eq(FuDogMoves.choose(5.0, 20.0, true, true, 0.5, 0.6), FuDogMoves.Move.ROAR, "the lioness roars more (bias 0.6)")
	assert_eq(FuDogMoves.choose(5.0, 20.0, true, false, 0.9, 0.4), FuDogMoves.Move.ROAR, "its mate charging: it roars instead")
	assert_eq(FuDogMoves.choose(3.5, 20.0, true, true, 0.9, 0.4), FuDogMoves.Move.ROAR, "too close for a charge: the roar")
	assert_eq(FuDogMoves.choose(5.0, 60.0, true, true, 0.3, 0.4), FuDogMoves.Move.CHARGE, "outside the roar's cone: the charge")


func test_from_afar_it_charges() -> void:
	assert_eq(FuDogMoves.choose(9.0, 0.0, true, true, 0.5, 0.4), FuDogMoves.Move.CHARGE)
	assert_eq(FuDogMoves.choose(12.0, 0.0, false, true, 0.5, 0.4), FuDogMoves.Move.CHARGE)
	assert_eq(FuDogMoves.choose(13.0, 0.0, true, true, 0.5, 0.4), FuDogMoves.Move.NONE, "beyond the charge: it walks")
	assert_eq(FuDogMoves.choose(5.0, 20.0, false, false, 0.5, 0.4), FuDogMoves.Move.NONE, "no roar ready, no leave to charge")
	assert_eq(FuDogMoves.choose(9.0, 0.0, false, false, 0.5, 0.4), FuDogMoves.Move.NONE)


func test_the_roar_reaches_six_metres_in_a_cone() -> void:
	var mouth := Vector3(0, 1.6, -1.6)
	var forward := Vector3(0, 0, -1)
	assert_true(FuDogMoves.roar_hits(mouth, forward, Vector3(0, 0, -6.5)), "5 m in front")
	assert_false(FuDogMoves.roar_hits(mouth, forward, Vector3(0, 0, -8.6)), "7 m: too far")
	assert_true(FuDogMoves.roar_hits(mouth, forward, mouth + Vector3(0, -1.6, -4.0).rotated(Vector3.UP, deg_to_rad(30.0))), "30 degrees off")
	assert_false(FuDogMoves.roar_hits(mouth, forward, mouth + Vector3(0, -1.6, -4.0).rotated(Vector3.UP, deg_to_rad(60.0))), "60 degrees off")
	assert_false(FuDogMoves.roar_hits(mouth, forward, Vector3(0, 0, 3.0)), "behind")


func test_the_charge_steers_only_a_little_and_only_at_first() -> void:
	var direction := Vector3(0, 0, -1)
	var guard := Vector3(5, 0, -5)   # 45 degrees off
	var turned := FuDogMoves.charge_turn(direction, guard, 0.0, 0.1)
	assert_almost_eq(turned.angle_to(direction), FuDogMoves.TURN_RATE * 0.1, 0.002, "at most 0.5 rad/s")
	assert_gt(turned.x, 0.0, "toward him")
	var late := FuDogMoves.charge_turn(direction, guard, FuDogMoves.TURN_TIME + 0.01, 0.1)
	assert_eq(late, direction, "after 0.3 s it runs straight")
	var small := FuDogMoves.charge_turn(direction, Vector3(0.1, 0, -5), 0.0, 0.1)
	assert_lt(small.angle_to(Vector3(0.1, 0, -5).normalized()), 0.001, "a small correction is taken whole")


func test_a_pair_charges_one_at_a_time_and_never_at_a_staggered_guard() -> void:
	var lion := Node3D.new()
	var lioness := Node3D.new()
	var pair := FuDogMoves.Pair.new(lion, lioness)
	assert_eq(pair.other(lion), lioness)
	assert_eq(pair.other(lioness), lion)
	assert_true(pair.may_charge(lion, false))
	pair.begin_charge(lion)
	assert_false(pair.may_charge(lioness, false), "one at a time")
	assert_true(pair.may_charge(lion, false), "the charger keeps its leave")
	pair.end_charge(lion)
	assert_true(pair.may_charge(lioness, false))
	assert_false(pair.may_charge(lioness, true), "never while the guard reels")
	assert_almost_eq(pair.roar_bias(lion), FuDogMoves.LION_ROAR_BIAS, 0.001)
	assert_almost_eq(pair.roar_bias(lioness), FuDogMoves.LIONESS_ROAR_BIAS, 0.001, "the lioness roars more")
	pair.begin_charge(lioness)
	lioness.free()
	assert_true(pair.may_charge(lion, false), "a charger that fell frees the leave")
	lion.free()
