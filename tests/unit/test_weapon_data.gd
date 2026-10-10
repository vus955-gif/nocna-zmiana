extends TestCase

const IDS: Array[StringName] = [&"fists", &"taser", &"pistol", &"shotgun"]


func test_all_weapon_files_load_with_matching_ids() -> void:
	for id in IDS:
		var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
		assert_not_null(data, str(id))
		if data != null:
			assert_eq(data.id, id)
			assert_ne(data.display_name, "")


func test_synergy_numbers() -> void:
	var fists: WeaponData = load("res://src/weapons/data/fists.tres")
	var taser: WeaponData = load("res://src/weapons/data/taser.tres")
	var pistol: WeaponData = load("res://src/weapons/data/pistol.tres")
	assert_true(fists.can_finish, "fists finish stunned exhibits")
	assert_gt(taser.stun_time, 0.0)
	assert_eq(taser.damage_kind, DamageInfo.Kind.ELECTRIC)
	assert_gt(pistol.weak_point_multiplier, 1.0)
	assert_eq(int(taser.battery_max / taser.battery_cost), 3)
