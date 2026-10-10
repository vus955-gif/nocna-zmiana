extends TestCase
## The Great Orrery's measurements and the guard's capsule against its arms
## (OrreryGeometry): the low arm is jumped, the gap under the high arm is
## stood in, the middle arm is kept away from; a tier's drive (OrreryDrive)
## spins up with weight and turns round through a stop.

const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")
## The guard's capsule (Player: CapsuleShape3D 0.4 x 1.8).
const R := 0.4
const H := 1.8

var _all: Array[bool] = [true, true, true, true, true, true]


## Feet [param radius] m out along arm [param arm] of [param tier] (model
## space, the tier at rest), [param up] m above the floor, [param aside] m
## across the arm.
func _on_arm(tier: int, radius: float, up: float = 0.0, arm: int = 0, aside: float = 0.0) -> Vector3:
	var along := G.arm_direction(tier, arm)
	return along * radius + Vector3.UP.cross(along) * aside + Vector3.UP * up


func _hits(tier: int, feet: Vector3, planets: Array[bool] = _all) -> bool:
	return G.tier_hits_rest(tier, feet, R, H, planets)


func test_the_arms_lie_where_the_model_has_them() -> void:
	assert_almost_eq(G.PIVOT[G.LOW], 0.45, 0.001)
	assert_almost_eq(G.BEAM[G.LOW].y, 0.55, 0.001, "the low beam's top: under the jump's apex")
	assert_lt(G.BEAM[G.LOW].y + G.TIP.y, G.JUMP_APEX, "its tip block too")
	assert_almost_eq(G.BEAM[G.HIGH].x, 2.65, 0.001, "the high beam's underside")
	assert_gt(G.BEAM[G.HIGH].x, H + G.JUMP_APEX - 0.05, "a jumping guard fits under the high beam")
	# Venus rides the low tier's first arm at its end (model: planet_2 at (4.75, 0.85, 0) on the tier)
	var venus := G.socket(1)
	assert_almost_eq(venus.x, 4.75, 0.01)
	assert_almost_eq(venus.y, 0.85, 0.01)
	var jupiter := G.socket(4)
	assert_almost_eq(jupiter.x, -2.25, 0.01, "Jupiter at 120 degrees on the high tier")
	assert_almost_eq(jupiter.z, -3.897, 0.01)
	assert_eq(G.planet_tier(4), G.HIGH)
	# the moons hang in pairs of five, the rods from the beam's underside
	assert_eq(G.moon_count(), 10)
	var moon := G.moon_center(3)
	assert_almost_eq(Vector2(moon.x, moon.z).length(), 3.3, 0.01)
	assert_almost_eq(moon.y + G.PIVOT[G.HIGH], 1.3, 0.01)
	assert_almost_eq(G.moon_pivot(3).y + G.PIVOT[G.HIGH], G.BEAM[G.HIGH].x, 0.01, "hung from the beam")


func test_the_low_arm_is_jumped_not_stood_in() -> void:
	assert_true(_hits(G.LOW, _on_arm(G.LOW, 3.5)), "standing in its way")
	assert_false(_hits(G.LOW, _on_arm(G.LOW, 3.5, 0.6)), "feet over the beam")
	assert_false(_hits(G.LOW, _on_arm(G.LOW, 4.9, 0.65, 1)), "over its tip block too")
	assert_true(_hits(G.LOW, _on_arm(G.LOW, 3.5, 0.5)), "a jump too low clips it")
	assert_true(_hits(G.LOW, _on_arm(G.LOW, 4.75, 0.6)), "Venus rides there: no jumping her")
	var venus_off := _all.duplicate()
	venus_off[1] = false
	assert_false(_hits(G.LOW, _on_arm(G.LOW, 4.75, 0.6), venus_off), "once she is shot off the beam is clear")
	assert_true(_hits(G.LOW, _on_arm(G.LOW, 2.4, 0.6, 1)), "Mercury rides the other arm")
	assert_false(_hits(G.LOW, _on_arm(G.LOW, 5.6)), "beyond its reach")
	assert_false(_hits(G.LOW, _on_arm(G.LOW, 3.5, 0.0, 0, 0.6)), "beside it")


func test_under_the_high_arm_the_gap_is_safe() -> void:
	for radius in [3.9, 4.15, 4.4]:
		assert_false(_hits(G.HIGH, _on_arm(G.HIGH, radius)), "standing in the gap at %.2f m" % radius)
		assert_false(_hits(G.HIGH, _on_arm(G.HIGH, radius, G.JUMP_APEX)), "even jumping there at %.2f m" % radius)
	for radius in [1.2, 1.9, 2.6, 3.3, 5.0]:
		assert_true(_hits(G.HIGH, _on_arm(G.HIGH, radius)), "a hanging moon at %.1f m" % radius)
		assert_true(_hits(G.HIGH, _on_arm(G.HIGH, radius, 0.0, 1)), "on the other arm too at %.1f m" % radius)
	assert_false(_hits(G.HIGH, _on_arm(G.HIGH, 5.7)), "beyond the last moon")


func test_the_middle_arm_is_kept_away_from() -> void:
	assert_true(_hits(G.MID, _on_arm(G.MID, 3.4)), "chest high")
	assert_true(_hits(G.MID, _on_arm(G.MID, 3.4, G.JUMP_APEX)), "no jumping it")
	assert_true(_hits(G.MID, _on_arm(G.MID, 2.0, 0.0, 1)), "near the hub")
	assert_false(_hits(G.MID, _on_arm(G.MID, 4.15)), "farther than its reach and a body")


func test_capsule_tests() -> void:
	var box := AABB(Vector3(0.0, 0.3, -0.1), Vector3(2.0, 0.25, 0.2))
	assert_true(G.capsule_box(Vector3(1.0, 0.0, 0.0), R, H, box), "through it")
	assert_false(G.capsule_box(Vector3(1.0, 0.56, 0.0), R, H, box), "over it")
	assert_true(G.capsule_box(Vector3(1.0, 0.0, 0.45), R, H, box), "its side brushes it")
	assert_false(G.capsule_box(Vector3(1.0, 0.0, 0.55), R, H, box), "a step beside it")
	assert_true(G.capsule_sphere(Vector3.ZERO, R, H, Vector3(0.5, 1.0, 0.0), 0.15), "a moon at the chest")
	assert_false(G.capsule_sphere(Vector3.ZERO, R, H, Vector3(0.6, 1.0, 0.0), 0.15))
	assert_true(G.capsule_segment(Vector3.ZERO, R, H, Vector3(0.3, 3.0, 0.0), Vector3(0.3, 1.5, 0.0), 0.02), "a rod over the head")
	assert_false(G.capsule_segment(Vector3.ZERO, R, H, Vector3(0.3, 3.0, 0.0), Vector3(0.3, 1.9, 0.0), 0.02))


func test_a_tier_spins_up_with_weight_and_turns_round_through_a_stop() -> void:
	var drive := OrreryDrive.new(1.0)
	drive.target = 0.8
	for i in 24:
		drive.step(1.0 / 60.0)
	assert_almost_eq(drive.speed, 0.4, 0.02, "half way after 0.4 s")
	assert_almost_eq(drive.acceleration, 1.0, 0.02, "spinning up")
	for i in 60:
		drive.step(1.0 / 60.0)
	assert_almost_eq(drive.speed, 0.8, 0.001, "at speed")
	assert_almost_eq(drive.acceleration, 0.0, 0.001, "steady")
	var before := drive.angle
	for i in 60:
		drive.step(1.0 / 60.0)
	assert_almost_eq(wrapf(drive.angle - before, -PI, PI), 0.8, 0.01, "a second at 0.8 rad/s")
	drive.target = -0.8
	var crossed := -1.0
	for i in 120:
		drive.step(1.0 / 60.0)
		if crossed < 0.0 and drive.speed <= 0.0:
			crossed = (i + 1) / 60.0
	assert_almost_eq(crossed, 0.8, 0.05, "it stops before it turns round")
	assert_almost_eq(drive.speed, -0.8, 0.001)
	drive.reset(1.0)
	assert_almost_eq(drive.angle, 1.0, 0.001)
	assert_almost_eq(drive.speed, 0.0, 0.001)


## A real jump (5 m/s up, gravity 15) over the low arm turning at
## [param omega] rad/s, the guard [param radius] m out on Mercury's arm
## (Mercury shot off): true when some take-off moment clears its pass.
func _jump_clears(omega: float, radius: float) -> bool:
	var no_planets: Array[bool] = [false, true, true, true, true, true]
	var crossing := 0.6 / omega
	var frames := ceili(1.2 / omega * 60.0)
	for i in 41:
		var take_off := crossing - 0.5 + i * 0.0125
		var hit := false
		# the arm comes from 0.6 rad behind the guard and goes 0.6 rad past him
		for frame in frames:
			var t := frame / 60.0
			var air := t - take_off
			var up := maxf(5.0 * air - 7.5 * air * air, 0.0) if air > 0.0 else 0.0
			var feet := Basis(Vector3.UP, 0.6 - omega * t) * (G.arm_direction(G.LOW, 1) * radius) + Vector3.UP * up
			if G.beams_hit(G.LOW, feet, R, H, no_planets):
				hit = true
				break
		if not hit:
			return true
	return false


func test_a_timed_jump_clears_the_low_arm_at_its_cruise() -> void:
	var cruise := absf(float(OrreryBrain.CRUISE[G.LOW][0]))
	assert_true(_jump_clears(cruise, 3.5), "phase 1 cruise at 3.5 m")
	assert_true(_jump_clears(cruise, 4.5), "and farther out")
	assert_true(_jump_clears(cruise * OrreryBrain.SURGE_FACTOR, 2.0), "a surge anywhere off the drum")
	assert_false(_jump_clears(0.2, 3.5), "a crawling arm cannot be jumped (it only shoves)")
