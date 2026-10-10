extends TestCase
## What a harpoon does to an exhibit (design 7.1): light ones by a wall are
## pinned, medium ones pulled, heavy ones only hurt.


func _data(levels: Dictionary = {}) -> WeaponData:
	var data := (load("res://src/weapons/data/harpoon.tres") as WeaponData).duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(data, levels)
	return data


func test_a_light_exhibit_with_a_wall_behind_is_pinned() -> void:
	assert_eq(HarpoonRules.verdict(35.0, 0.0, 4.0, _data()), HarpoonRules.Verdict.PIN, "a wolf")
	assert_eq(HarpoonRules.verdict(60.0, 0.0, 6.0, _data()), HarpoonRules.Verdict.PIN, "a wax figure, at the limit")


func test_without_a_wall_in_reach_a_light_exhibit_is_pulled() -> void:
	assert_eq(HarpoonRules.verdict(35.0, 0.0, 6.5, _data()), HarpoonRules.Verdict.PULL)
	assert_eq(HarpoonRules.verdict(35.0, 0.0, INF, _data()), HarpoonRules.Verdict.PULL)


func test_a_medium_exhibit_is_pulled_even_by_a_wall() -> void:
	assert_eq(HarpoonRules.verdict(75.0, 0.0, 2.0, _data()), HarpoonRules.Verdict.PULL, "a wax figure under a full moon")
	assert_eq(HarpoonRules.verdict(150.0, 0.0, 2.0, _data()), HarpoonRules.Verdict.PULL)


func test_a_heavy_exhibit_only_takes_the_damage() -> void:
	assert_eq(HarpoonRules.verdict(180.0, 0.85, 2.0, _data()), HarpoonRules.Verdict.DAMAGE, "a knight")
	assert_eq(HarpoonRules.verdict(151.0, 0.0, INF, _data()), HarpoonRules.Verdict.DAMAGE, "too big")
	assert_eq(HarpoonRules.verdict(50.0, 0.9, INF, _data()), HarpoonRules.Verdict.DAMAGE, "too hard to move")


func test_barbs_pin_up_to_90() -> void:
	var barbed := _data({&"harpoon_barbs": 1})
	assert_eq(barbed.pin_max_health, 90.0)
	assert_eq(HarpoonRules.verdict(75.0, 0.0, 3.0, barbed), HarpoonRules.Verdict.PIN)
	assert_eq(HarpoonRules.verdict(91.0, 0.0, 3.0, barbed), HarpoonRules.Verdict.PULL)


func test_the_pull_slides_three_metres_on_the_floor() -> void:
	var speed := HarpoonRules.pull_speed(3.0)
	assert_almost_eq(speed * speed / (2.0 * Enemy.GROUND_FRICTION), 3.0, 0.001)
	assert_eq(HarpoonRules.pull_speed(0.0), 0.0)
