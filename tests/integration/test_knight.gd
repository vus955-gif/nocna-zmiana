extends TestCase

var knight: Knight


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	knight = Knight.new()
	add_child(knight)


## A 20-damage hit travelling along [param travel].
func _shot(kind: DamageInfo.Kind, travel: Vector3) -> DamageInfo:
	var info := DamageInfo.make(20.0, kind, null)
	info.direction = travel
	info.position = knight.global_position + Vector3.UP
	if kind == DamageInfo.Kind.ELECTRIC:
		info.stun_time = 3.0
	return info


func test_frontal_shot_is_blocked() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_true(info.blocked)
	assert_eq(knight.health.current, 180.0)


func test_shot_from_behind_lands() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1)))
	assert_eq(knight.health.current, 160.0)


func test_taser_from_the_front_stuns_and_opens_the_guard() -> void:
	knight.take_damage(_shot(DamageInfo.Kind.ELECTRIC, Vector3(0, 0, 1)))
	assert_true(knight.brain.is_stunned())
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, 1))
	knight.take_damage(info)
	assert_false(info.blocked)
	assert_eq(knight.health.current, 140.0)


func test_steep_shot_from_a_balcony_gets_past_the_shield() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, -0.8, 0.6))
	knight.take_damage(info)
	assert_false(info.blocked)
	assert_eq(knight.health.current, 160.0)


func test_heavy_armour_resists_knockback() -> void:
	var info := _shot(DamageInfo.Kind.BALLISTIC, Vector3(0, 0, -1))
	info.knockback = 10.0
	knight.take_damage(info)
	assert_almost_eq(knight._external.length(), 3.0, 0.01)


func test_no_strike_through_a_thin_wall() -> void:
	Greybox.box(self, Vector3(0, 1.5, -0.85), Vector3(6, 3, 0.2), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, -1.55)
	add_child(target)
	knight.target = target
	await physics_frames(2)
	knight.brain.wake()
	await physics_frames(150)
	assert_eq(target.hits.size(), 0)
