extends TestCase
## The samurai armour's thrust (SamuraiArmor.thrust_hits): in front within
## reach, not beside it, not out of reach, not a storey up.


func test_the_thrust_reaches_three_metres_in_a_narrow_cone() -> void:
	var forward := Vector3(0, 0, -1)
	assert_true(SamuraiArmor.thrust_hits(forward, Vector3(0, 0, -3.0), SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC))
	assert_false(SamuraiArmor.thrust_hits(forward, Vector3(0, 0, -4.0), SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC), "4 m: out of reach")
	assert_true(SamuraiArmor.thrust_hits(forward, Vector3(0, 0, -2.5).rotated(Vector3.UP, deg_to_rad(20.0)), SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC))
	assert_false(SamuraiArmor.thrust_hits(forward, Vector3(0, 0, -2.5).rotated(Vector3.UP, deg_to_rad(40.0)), SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC), "40 degrees off: the yari passes him")
	assert_false(SamuraiArmor.thrust_hits(forward, Vector3(0, 1.4, -2.5), SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC), "a storey up")
	assert_false(SamuraiArmor.thrust_hits(forward, Vector3.ZERO, SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_HALF_ARC))


func test_its_numbers() -> void:
	assert_almost_eq(SamuraiArmor.THRUST_WINDUP, 0.8, 0.001, "a 0.8 s telegraph")
	assert_almost_eq(SamuraiArmor.THRUST_DAMAGE, 20.0, 0.001)
	assert_almost_eq(SamuraiArmor.THRUST_RANGE, 2.6, 0.001, "the brain starts the thrust at 2.6 m")
	assert_gt(SamuraiArmor.THRUST_REACH, SamuraiArmor.THRUST_RANGE, "the lunge carries it further than it starts")
	assert_true(SamuraiArmor.GLINT_AT > 0.5 and SamuraiArmor.GLINT_AT < 0.6, "the tip glints past the middle of the telegraph")
