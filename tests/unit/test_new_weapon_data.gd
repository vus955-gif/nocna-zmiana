extends TestCase
## The three Floor I weapons (design 7.1): their numbers in the .tres files,
## slots 6-8 on the number keys and the wheel, the night's starting ammo.

const NEW: Array[StringName] = [&"rifle_hunt", &"harpoon", &"hwacha"]


func _data(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func test_the_expedition_rifle() -> void:
	var data := _data(&"rifle_hunt")
	assert_eq(data.id, &"rifle_hunt")
	assert_eq(data.damage, 85.0)
	assert_eq(data.pierce_targets, 3, "pierces up to three targets")
	assert_eq(data.weak_point_multiplier, 3.0)
	assert_eq(data.cooldown, 1.0, "bolt cycle")
	assert_eq(data.spread_deg, 0.0, "iron sights, no spread")
	assert_eq(data.magazine_size, 5)
	assert_eq(data.start_reserve, 25)
	assert_eq(data.max_reserve, 40)
	assert_eq(data.ammo_type, &"hunt_rounds")
	assert_eq(data.projectile_speed, 0.0, "hitscan")


func test_the_harpoon_gun() -> void:
	var data := _data(&"harpoon")
	assert_eq(data.damage, 60.0)
	assert_eq(data.projectile, &"harpoon")
	assert_eq(data.projectile_speed, 40.0)
	assert_gt(data.projectile_gravity, 0.0, "a slight drop")
	assert_eq(data.pin_max_health, 60.0)
	assert_eq(data.pin_reach, 6.0)
	assert_eq(data.pull_distance, 3.0)
	assert_eq(data.pull_stun, 1.0)
	assert_eq(data.reload_time, 1.2)
	assert_eq(data.magazine_size, 1)
	assert_eq(data.start_reserve, 12)
	assert_eq(data.max_reserve, 20)
	assert_eq(data.ammo_type, &"harpoons")


func test_the_fire_arrow_chest() -> void:
	var data := _data(&"hwacha")
	assert_eq(data.projectile, &"rocket")
	assert_eq(data.volley_count, 6)
	assert_eq(data.volley_spread_deg, 12.0)
	assert_eq(data.volley_interval, 0.08)
	assert_eq(data.damage, 22.0)
	assert_eq(data.blast_damage, 14.0)
	assert_eq(data.blast_radius, 1.8)
	assert_eq(data.damage_kind, DamageInfo.Kind.FIRE, "wax burns double")
	assert_eq(data.reload_time, 2.2)
	assert_eq(data.magazine_size, 1, "one volley loaded")
	assert_eq(data.start_reserve, 6)
	assert_eq(data.max_reserve, 10)
	assert_eq(data.ammo_type, &"rockets")


func test_the_old_weapons_keep_their_defaults() -> void:
	for id in [&"pistol", &"shotgun", &"gatling", &"flare"]:
		var data := _data(id)
		assert_eq(data.pierce_targets, 1, String(id))
		assert_eq(data.volley_count, 0, String(id))
	assert_eq(_data(&"flare").projectile, &"flare")


func test_slots_six_to_eight_are_on_the_number_keys() -> void:
	var keys := [KEY_6, KEY_7, KEY_8]
	for i in 3:
		var action := StringName("weapon_%d" % (i + 6))
		assert_true(InputMap.has_action(action), String(action))
		if not InputMap.has_action(action):
			continue
		var event := InputMap.action_get_events(action)[0] as InputEventKey
		assert_eq(event.physical_keycode, keys[i], String(action))
	assert_eq(WeaponHolder.SLOT_ORDER.slice(5), NEW, "slots 6, 7, 8")


func test_the_dev_spawn_keys_left_the_number_row() -> void:
	for action in [&"spawn_wax", &"spawn_wolf", &"spawn_knight", &"clear_enemies"]:
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			assert_true(key.physical_keycode >= KEY_F1 and key.physical_keycode <= KEY_F12, String(action))


func test_the_wheel_goes_through_all_eight_in_slot_order() -> void:
	var holder := WeaponHolder.new()
	add_child(holder)
	for id in [&"hwacha", &"taser", &"harpoon", &"pistol", &"flare", &"rifle_hunt", &"shotgun", &"gatling"]:
		holder.give(_data(id))
	var seen: Array[StringName] = []
	holder.select_id(&"taser")
	for i in 8:
		seen.append(holder.current_state().data.id)
		holder.cycle(1)
	assert_eq(seen, WeaponHolder.SLOT_ORDER)
	assert_eq(holder.current_state().data.id, &"taser", "wraps round")


func test_a_found_weapon_starts_the_night_with_a_full_load() -> void:
	var guard := Player.new()
	add_child(guard)
	for id in NEW:
		var state := Loadout.grant(guard, id, GameState)
		assert_not_null(state, String(id))
		if state == null:
			continue
		assert_eq(state.magazine, state.data.magazine_size, String(id))
		assert_eq(state.reserve, _data(id).start_reserve, String(id) + " reserve")
