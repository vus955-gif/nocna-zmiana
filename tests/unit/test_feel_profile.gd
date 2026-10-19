extends TestCase

const WEAPONS: Array[StringName] = [&"fists", &"taser", &"pistol", &"shotgun", &"gatling", &"flare", &"rifle_hunt",
		&"harpoon", &"hwacha"]


func test_every_weapon_has_a_profile_of_its_own() -> void:
	for id in WEAPONS:
		assert_true(FeelProfile.has(id), "%s has a feel profile" % id)
		var profile := FeelProfile.of(id)
		assert_eq(profile.id, id, "the file names its weapon")
	for id in WeaponHolder.SLOT_ORDER:
		assert_true(WEAPONS.has(id), "%s is in this list" % id)


func test_an_unknown_weapon_feels_neutral() -> void:
	assert_false(FeelProfile.has(&"bazooka"))
	assert_not_null(FeelProfile.of(&"bazooka"))
	assert_eq(FeelProfile.of(&"bazooka"), FeelProfile.of(&""))


func test_the_answer_to_has_is_looked_up_once_and_kept() -> void:
	assert_false(FeelProfile.has(&""), "no weapon, no profile")
	assert_false(FeelProfile._known.has(&""), "and not worth keeping")
	for round in 2:
		assert_true(FeelProfile.has(&"shotgun"))
		assert_false(FeelProfile.has(&"bazooka"))
	assert_eq(FeelProfile._known.get(&"shotgun"), true, "kept: no file lookup on every hit")
	assert_eq(FeelProfile._known.get(&"bazooka"), false, "a miss is kept too")


## The numbers a guard feels in a shot, as one row.
func _signature(profile: FeelProfile) -> Array:
	return [profile.kick_back, profile.kick_pitch, profile.kick_frequency, profile.camera_pitch, profile.shake,
			profile.flash_size, profile.hit_weight, profile.tracer_width]


func test_no_two_weapons_feel_the_same() -> void:
	for a in WEAPONS.size():
		for b in range(a + 1, WEAPONS.size()):
			var one := _signature(FeelProfile.of(WEAPONS[a]))
			var other := _signature(FeelProfile.of(WEAPONS[b]))
			assert_ne(one, other, "%s and %s" % [WEAPONS[a], WEAPONS[b]])


func test_the_shotgun_is_brutal_and_the_pistol_quick_and_precise() -> void:
	var pistol := FeelProfile.of(&"pistol")
	var shotgun := FeelProfile.of(&"shotgun")
	assert_gt(shotgun.kick_back, pistol.kick_back * 2.0, "a much bigger shove")
	assert_gt(shotgun.kick_pitch, pistol.kick_pitch * 2.0, "the muzzle climbs much more")
	assert_gt(shotgun.camera_pitch, pistol.camera_pitch * 3.0, "the view kicks")
	assert_gt(shotgun.shake, pistol.shake * 3.0)
	assert_gt(pistol.kick_frequency, shotgun.kick_frequency, "the pistol comes back quicker")
	assert_lt(pistol.sound_jitter, shotgun.sound_jitter + 0.001, "the pistol sounds the same shot after shot")
	assert_gt(shotgun.hit_weight, pistol.hit_weight * 2.0, "and lands much heavier")


func test_the_rifle_is_very_strong_but_slower() -> void:
	var rifle := FeelProfile.of(&"rifle_hunt")
	var shotgun := FeelProfile.of(&"shotgun")
	var pistol := FeelProfile.of(&"pistol")
	assert_gt(rifle.kick_back, shotgun.kick_back, "the biggest shove")
	assert_gt(rifle.camera_pitch, shotgun.camera_pitch, "the biggest view kick")
	assert_lt(rifle.kick_frequency, shotgun.kick_frequency, "and the slowest to come back")
	assert_lt(rifle.camera_frequency, pistol.camera_frequency)
	assert_gt(rifle.hit_weight, 0.9, "every target it pierces staggers")
	assert_gt(rifle.tracer_width, pistol.tracer_width * 2.0, "its trace reads")


func test_the_gatling_buzzes_and_never_piles_up() -> void:
	var gatling := FeelProfile.of(&"gatling")
	for id in WEAPONS:
		if id != &"gatling":
			assert_gt(gatling.kick_frequency, FeelProfile.of(id).kick_frequency, "the fastest spring (%s)" % id)
	assert_lt(gatling.shake_cap, 0.4, "a steady rumble, not full shake")
	assert_lt(gatling.hit_weight, 0.2, "one round barely moves an exhibit")


func test_profiles_stay_within_sane_bounds() -> void:
	for id in WEAPONS:
		var p := FeelProfile.of(id)
		assert_true(p.kick_back >= 0.0 and p.kick_back <= 0.15, "%s kick back %.3f" % [id, p.kick_back])
		assert_true(absf(p.kick_pitch) <= 20.0, "%s muzzle climb" % id)
		assert_true(absf(p.camera_pitch) <= 4.0 and absf(p.camera_yaw) <= 1.0, "%s: a gentle view kick" % id)
		assert_true(p.shake <= p.shake_cap and p.shake_cap <= 0.7, "%s shake within its cap" % id)
		assert_true(p.kick_damping >= 0.4 and p.kick_damping <= 1.0, "%s: no wild wobble" % id)
		assert_true(p.hit_weight >= 0.0 and p.hit_weight <= 1.0, "%s hit weight" % id)
		assert_true(p.fov_punch >= 0.0 and p.fov_punch <= 3.0, "%s fov punch" % id)
