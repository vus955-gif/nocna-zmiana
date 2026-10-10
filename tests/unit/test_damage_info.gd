extends TestCase


func test_make_fills_amount_kind_and_source() -> void:
	var source := Node.new()
	add_child(source)
	var info := DamageInfo.make(12.5, DamageInfo.Kind.ELECTRIC, source)
	assert_eq(info.amount, 12.5)
	assert_eq(info.kind, DamageInfo.Kind.ELECTRIC)
	assert_eq(info.source, source)


func test_defaults_are_harmless() -> void:
	var info := DamageInfo.new()
	assert_eq(info.stun_time, 0.0)
	assert_eq(info.knockback, 0.0)
	assert_false(info.weak_point)
	assert_false(info.can_finish)
	assert_false(info.blocked)
