extends TestCase

## The knight looks toward -Z. An attacker in front shoots toward +Z.
const FACING := Vector3(0, 0, -1)
const FROM_FRONT := Vector3(0, 0, 1)


func test_blocks_a_hit_from_the_front() -> void:
	assert_true(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.BALLISTIC, false))


func test_hit_from_behind_gets_through() -> void:
	assert_false(ShieldGuard.blocks(FACING, Vector3(0, 0, -1), DamageInfo.Kind.BALLISTIC, false))


func test_hit_from_the_side_gets_through() -> void:
	assert_false(ShieldGuard.blocks(FACING, Vector3(1, 0, 0), DamageInfo.Kind.BALLISTIC, false))


func test_front_arc_is_seventy_degrees_each_way() -> void:
	var inside := FROM_FRONT.rotated(Vector3.UP, deg_to_rad(60.0))
	var outside := FROM_FRONT.rotated(Vector3.UP, deg_to_rad(80.0))
	assert_true(ShieldGuard.blocks(FACING, inside, DamageInfo.Kind.BLUNT, false))
	assert_false(ShieldGuard.blocks(FACING, outside, DamageInfo.Kind.BLUNT, false))


func test_electricity_passes_through_the_shield() -> void:
	assert_false(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.ELECTRIC, false))


func test_a_stunned_knight_cannot_block() -> void:
	assert_false(ShieldGuard.blocks(FACING, FROM_FRONT, DamageInfo.Kind.BALLISTIC, true))


func test_steep_shot_from_above_passes_over_the_shield() -> void:
	var steep := Vector3(0, -0.8, 0.6)
	var shallow := Vector3(0, -0.5, 0.866)
	assert_false(ShieldGuard.blocks(FACING, steep, DamageInfo.Kind.BALLISTIC, false))
	assert_true(ShieldGuard.blocks(FACING, shallow, DamageInfo.Kind.BALLISTIC, false))
