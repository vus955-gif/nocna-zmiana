extends TestCase
## Dust per kill, the finisher bonus and the split into motes.


func test_exhibits_carry_their_dust_values() -> void:
	var expected := {WaxFigure: 3, Wolf: 4, Knight: 8, Bust: 5}
	for kind in expected:
		var exhibit: Enemy = kind.new()
		assert_eq(exhibit.dust_value, expected[kind], exhibit.get_script().get_global_name())
		exhibit.free()


func test_finisher_multiplies_and_rounds_up() -> void:
	assert_eq(DustRules.kill_value(3, false), 3)
	assert_eq(DustRules.kill_value(3, true), 5)
	assert_eq(DustRules.kill_value(4, true), 6)
	assert_eq(DustRules.kill_value(8, true), 12)
	assert_eq(DustRules.kill_value(0, true), 0)


func test_split_gives_one_to_four_motes_that_sum_up() -> void:
	for total in range(1, 40):
		var motes := DustRules.split(total)
		assert_true(motes.size() >= 1 and motes.size() <= DustRules.MAX_MOTES, "count for %d" % total)
		var sum := 0
		for value in motes:
			sum += value
			assert_gt(value, 0)
		assert_eq(sum, total)
	assert_eq(DustRules.split(3).size(), 1, "a wax figure drops one mote")
	assert_eq(DustRules.split(8).size(), 3, "a knight drops three")
	assert_eq(DustRules.split(0).size(), 0)


func test_boss_carries_a_hundred_and_splits_into_more_motes() -> void:
	var boss := TRex.new()
	assert_eq(boss.dust_value, 100)
	boss.free()
	var motes := DustRules.split(100, DustRules.BOSS_MOTES)
	assert_eq(motes.size(), DustRules.BOSS_MOTES)
	var sum := 0
	for value in motes:
		sum += value
	assert_eq(sum, 100)


func test_night_multipliers_apply_after_the_finisher() -> void:
	var run := NightState.new()
	run.set_multiplier(&"full_moon", 1.5)
	assert_eq(run.scaled_dust(DustRules.kill_value(8, true)), 18)
	assert_eq(run.scaled_dust(DustRules.kill_value(3, false)), 5)
	run.free()
