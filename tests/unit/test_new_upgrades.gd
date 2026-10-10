extends TestCase
## The six Floor I upgrades (design 8.1) change only the copy of their
## weapon's numbers; the .tres files stay as they are.


func _upgraded(id: StringName, levels: Dictionary) -> WeaponData:
	var data := (load("res://src/weapons/data/%s.tres" % id) as WeaponData).duplicate() as WeaponData
	UpgradeEffects.apply_to_weapon(data, levels)
	return data


func test_lighter_bolt_cycles_in_0_7_s() -> void:
	assert_eq(_upgraded(&"rifle_hunt", {}).cooldown, 1.0)
	assert_eq(_upgraded(&"rifle_hunt", {&"rifle_bolt": 1}).cooldown, 0.7)


func test_expanding_bullet_hits_weak_points_x4() -> void:
	assert_eq(_upgraded(&"rifle_hunt", {&"rifle_expand": 1}).weak_point_multiplier, 4.0)


func test_the_reel_reloads_in_0_7_s() -> void:
	assert_eq(_upgraded(&"harpoon", {&"harpoon_reel": 1}).reload_time, 0.7)


func test_barbs_pin_up_to_90() -> void:
	assert_eq(_upgraded(&"harpoon", {&"harpoon_barbs": 1}).pin_max_health, 90.0)


func test_quick_fuse_reloads_in_1_5_s() -> void:
	assert_eq(_upgraded(&"hwacha", {&"hwacha_fuse": 1}).reload_time, 1.5)


func test_bigger_volley_is_nine() -> void:
	assert_eq(_upgraded(&"hwacha", {&"hwacha_volley": 1}).volley_count, 9)


func test_the_resources_never_change() -> void:
	_upgraded(&"hwacha", {&"hwacha_volley": 1, &"hwacha_fuse": 1})
	_upgraded(&"rifle_hunt", {&"rifle_bolt": 1, &"rifle_expand": 1})
	var hwacha: WeaponData = load("res://src/weapons/data/hwacha.tres")
	var rifle: WeaponData = load("res://src/weapons/data/rifle_hunt.tres")
	assert_eq(hwacha.volley_count, 6)
	assert_eq(hwacha.reload_time, 2.2)
	assert_eq(rifle.cooldown, 1.0)
	assert_eq(rifle.weak_point_multiplier, 3.0)


func test_bought_before_the_weapon_is_found_it_works_once_found() -> void:
	var holder := WeaponHolder.new()
	add_child(holder)
	holder.apply_upgrades({&"harpoon_reel": 1, &"hwacha_volley": 1})
	assert_eq(holder.give(load("res://src/weapons/data/harpoon.tres")).data.reload_time, 0.7)
	assert_eq(holder.give(load("res://src/weapons/data/hwacha.tres")).data.volley_count, 9)


func test_pockets_raise_the_new_reserves() -> void:
	assert_eq(_upgraded(&"rifle_hunt", {&"pockets": 2}).max_reserve, 60)
	assert_eq(_upgraded(&"harpoon", {&"pockets": 1}).max_reserve, 25)
	assert_eq(_upgraded(&"hwacha", {&"pockets": 2}).max_reserve, 15)
