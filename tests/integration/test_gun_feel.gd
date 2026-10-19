extends TestCase
## Gun feel (plan 2026-10-19-gun-feel): every weapon kicks its model and the
## camera its own way, both always come back, the aim never drifts and the
## shake keeps to its budget.

var guard: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 0)
	add_child(guard)


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


## A copy of weapon [param id] that fires every frame and never runs dry.
func _rapid(id: StringName) -> WeaponData:
	var data: WeaponData = _weapon(id).duplicate()
	data.cooldown = 0.0
	data.magazine_size = 999
	return data


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## The biggest model kick (back in m, climb in degrees) over [param frames]
## frames after one shot of [param id].
func _kick_of(id: StringName, frames: int = 30) -> Vector2:
	guard.weapons.give(_weapon(id))
	guard.weapons.select_id(id)
	await physics_frames(2)
	await _frames(40)
	assert_true(guard.weapons.try_fire(), "%s fires" % id)
	var top := Vector2.ZERO
	for i in frames:
		await get_tree().process_frame
		var kick := guard.weapons.view_kick()
		top = Vector2(maxf(top.x, kick[WeaponHolder.KICK_BACK]), maxf(top.y, kick[WeaponHolder.KICK_PITCH]))
	return top


func test_the_shotgun_kicks_the_model_far_harder_than_the_pistol() -> void:
	var pistol := await _kick_of(&"pistol")
	await _frames(90)
	var shotgun := await _kick_of(&"shotgun")
	assert_gt(pistol.x, 0.02, "the pistol does kick (%.3f m)" % pistol.x)
	assert_gt(shotgun.x, pistol.x * 2.0, "back: %.3f vs %.3f m" % [shotgun.x, pistol.x])
	assert_gt(shotgun.y, pistol.y * 2.0, "climb: %.1f vs %.1f deg" % [shotgun.y, pistol.y])
	assert_lt(shotgun.x, 0.15, "a shove, not a jerk out of the frame")


func test_the_model_comes_back_to_rest_after_a_shot() -> void:
	await _kick_of(&"rifle_hunt", 2)
	await _frames(120)
	var view := guard.weapons.view_of(&"rifle_hunt")
	assert_lt((view.position - WeaponHolder.REST).length(), 0.002, "back at rest: %s" % view.position)
	assert_almost_eq(view.rotation.x, 0.0, 0.003)
	assert_almost_eq(view.rotation.y, WeaponHolder.AIM_YAW, 0.003)
	assert_almost_eq(view.rotation.z, 0.0, 0.003)


func test_the_camera_kicks_up_comes_back_and_the_aim_never_drifts() -> void:
	guard.head.rotation = Vector3(deg_to_rad(-5.0), 0.3, 0.0)
	var aim := guard.head.rotation
	guard.weapons.give(_weapon(&"shotgun"))
	await physics_frames(2)
	await _frames(30)
	assert_true(guard.weapons.try_fire())
	var top := 0.0
	for i in 20:
		await get_tree().process_frame
		top = maxf(top, rad_to_deg(guard.camera.rotation.x))
	assert_gt(top, 1.5, "the view kicks up (%.2f deg)" % top)
	assert_lt(top, ShakeCamera.KICK_PITCH_MAX + 0.01, "but gently")
	await _frames(90)
	assert_almost_eq(guard.camera.rotation.x, 0.0, deg_to_rad(0.05), "and comes back by itself")
	assert_almost_eq(guard.camera.rotation.y, 0.0, deg_to_rad(0.05))
	assert_true(guard.head.rotation.is_equal_approx(aim), "the aim is where the guard left it")


func test_the_pistol_barely_moves_the_view() -> void:
	guard.weapons.give(_weapon(&"pistol"))
	await physics_frames(2)
	await _frames(30)
	guard.weapons.try_fire()
	var top := 0.0
	for i in 20:
		await get_tree().process_frame
		top = maxf(top, rad_to_deg(guard.camera.rotation.x))
	assert_gt(top, 0.2, "a touch (%.2f deg)" % top)
	assert_lt(top, 0.8, "no more")
	await _frames(20)
	assert_lt(absf(rad_to_deg(guard.camera.rotation.x)), 0.1, "settled before the next shot is due")


func test_a_burst_shakes_and_climbs_only_up_to_its_caps() -> void:
	guard.weapons.give(_rapid(&"shotgun"))
	await physics_frames(2)
	var cap := FeelProfile.of(&"shotgun").shake_cap
	for i in 30:
		guard.weapons.try_fire()
		await get_tree().process_frame
		assert_true(guard.camera.trauma.value <= cap + 0.0001, "shot %d: trauma %.3f" % [i, guard.camera.trauma.value])
		assert_true(guard.camera.kick_angles().x <= ShakeCamera.KICK_PITCH_MAX + 0.0001, "the climb holds")
	assert_gt(guard.camera.trauma.value, cap * 0.6, "a burst does rumble")


func test_a_bigger_shake_than_a_weapons_cap_stays() -> void:
	guard.weapons.give(_weapon(&"pistol"))
	await physics_frames(2)
	guard.camera.add_trauma(0.9)
	var before := guard.camera.trauma.value
	guard.weapons.try_fire()
	assert_almost_eq(guard.camera.trauma.value, before, 0.0001, "a shot never takes shake away")


func test_with_screen_shake_off_the_view_holds_still() -> void:
	guard.camera.shake_scale = 0.0
	guard.weapons.give(_weapon(&"shotgun"))
	await physics_frames(2)
	await _frames(10)
	guard.weapons.try_fire()
	for i in 20:
		await get_tree().process_frame
		assert_almost_eq(guard.camera.rotation.x, 0.0, 0.00001)
		assert_almost_eq(guard.camera.h_offset, 0.0, 0.00001)


## The widest the view got over [param frames] frames (degrees over the
## base FOV).
func _fov_swell(frames: int) -> float:
	var top := 0.0
	for i in frames:
		await get_tree().process_frame
		top = maxf(top, guard.camera.fov - guard.camera.base_fov)
	return top


func test_a_shotgun_blast_punches_the_fov_scaled_by_the_shake_option() -> void:
	guard.weapons.give(_rapid(&"shotgun"))
	await physics_frames(2)
	await _frames(30)
	guard.camera.shake_scale = 1.0
	guard.weapons.try_fire()
	var full := await _fov_swell(10)
	assert_gt(full, 0.8, "a punch you see (%.2f deg)" % full)
	await _frames(30)
	guard.camera.shake_scale = 0.5
	guard.weapons.try_fire()
	var half := await _fov_swell(10)
	assert_almost_eq(half, full * 0.5, 0.05, "half the shake, half the punch (%.2f vs %.2f deg)" % [half, full])
	await _frames(30)
	guard.camera.shake_scale = 0.0
	guard.weapons.try_fire()
	var none := await _fov_swell(10)
	assert_almost_eq(none, 0.0, 0.00001, "shake off: the view stays at its FOV")


func test_with_screen_shake_off_a_dash_and_a_stagger_leave_the_fov_alone() -> void:
	guard.camera.shake_scale = 0.0
	await physics_frames(5)
	assert_true(guard.dash(Vector3.FORWARD))
	assert_almost_eq(await _fov_swell(10), 0.0, 0.00001, "no widening on the dash")
	await _frames(60)
	guard.stagger(0.5)
	assert_true(guard.staggered())
	assert_almost_eq(await _fov_swell(10), 0.0, 0.00001, "no widening when he reels")
	await _frames(60)
	guard.camera.shake_scale = 1.0
	guard.stagger(0.5)
	assert_gt(await _fov_swell(3), 3.0, "with the option on it does widen")


func test_a_blast_close_by_shakes_and_pushes_the_view_a_far_one_does_not() -> void:
	await physics_frames(2)
	await _frames(5)
	guard.camera.feel_blast(guard.camera.global_position + Vector3(30.0, 0.0, 0.0), 2.5)
	assert_almost_eq(guard.camera.trauma.value, 0.0, 0.0001, "too far to feel")
	guard.camera.feel_blast(guard.camera.global_position + Vector3(2.0, 0.0, -2.0), 2.5)
	assert_gt(guard.camera.trauma.value, 0.15, "close: it shakes")
	assert_true(guard.camera.trauma.value <= ShakeCamera.BLAST_CAP, "within the blasts' budget")
	await _frames(6)
	assert_gt(guard.camera.rotation.x, 0.0, "the view is pushed up")
	await _frames(90)
	assert_almost_eq(guard.camera.rotation.x, 0.0, deg_to_rad(0.05), "and settles")


func test_a_sprint_carries_the_weapon_low_and_a_shot_brings_it_up() -> void:
	guard.weapons.give(_weapon(&"pistol"))
	await physics_frames(5)
	var view := guard.weapons.view_of(&"pistol")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(40)
	assert_true(guard.sprinting)
	assert_lt(view.position.y, WeaponHolder.REST.y - 0.025, "lowered for the run")
	guard.weapons.try_fire()
	await physics_frames(12)
	assert_gt(view.position.y, WeaponHolder.REST.y - 0.015, "up again to shoot")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func test_every_arrow_of_a_volley_kicks() -> void:
	guard.weapons.give(_weapon(&"hwacha"))
	await physics_frames(2)
	await _frames(30)
	var before := guard.weapons.kicks_given
	guard.weapons.try_fire()
	await physics_frames(40)
	var count := _weapon(&"hwacha").volley_count
	assert_eq(guard.weapons.kicks_given - before, count, "the chest ripples: one kick per arrow")


# --- the view on the move ------------------------------------------------------

## The lowest and highest the eyes go (camera offset, m) and the most roll
## seen, walking forward [param frames] process frames.
func _walk_view(frames: int, sprint: bool = false) -> Dictionary:
	var low := 0.0
	var high := 0.0
	var side := 0.0
	var roll := 0.0
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint")
	for i in frames:
		await get_tree().process_frame
		low = minf(low, guard.camera.position.y)
		high = maxf(high, guard.camera.position.y)
		side = maxf(side, absf(guard.camera.position.x))
		roll = maxf(roll, absf(guard.camera.rotation.z))
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	return {"low": low, "high": high, "side": side, "roll": roll}


func test_walking_bobs_the_eyes_gently_and_never_rolls_the_view() -> void:
	await physics_frames(10)
	var walk := await _walk_view(90)
	var height: float = walk["high"] - walk["low"]
	assert_gt(height, 0.006, "a bob you feel (%.4f m)" % height)
	assert_lt(height, Player.BOB_HEIGHT + 0.002, "and no more (%.4f m)" % height)
	assert_lt(walk["side"], Player.BOB_SIDE + 0.001, "barely a sway")
	assert_lt(walk["roll"], 0.0001, "no drunk camera")
	await _frames(60)
	assert_lt(guard.camera.position.length(), 0.002, "standing: the view settles")


func test_a_sprint_bobs_a_little_more_and_widens_the_view() -> void:
	await physics_frames(10)
	var run := await _walk_view(90, true)
	assert_lt(run["high"] - run["low"], Player.BOB_SPRINT_HEIGHT + 0.002)
	assert_gt(run["high"] - run["low"], Player.BOB_HEIGHT * 0.8)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(60)
	assert_gt(guard.camera.fov, Settings.data.fov + Player.SPRINT_FOV * 0.7, "a wider view on the run")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	await _frames(90)
	assert_almost_eq(guard.camera.fov, Settings.data.fov, 0.1, "back when he stops")


func test_head_bob_off_keeps_the_eyes_level() -> void:
	Settings.set_value(&"head_bob", 0.0, false)
	assert_eq(guard.head_bob_scale, 0.0, "the option reaches the guard")
	await physics_frames(10)
	var walk := await _walk_view(60, true)
	assert_almost_eq(walk["low"], 0.0, 0.00001)
	assert_almost_eq(walk["high"], 0.0, 0.00001)
	assert_almost_eq(guard.camera.fov, Settings.data.fov, 0.01, "no sprint widening either")


func test_screen_shake_option_reaches_the_camera() -> void:
	Settings.set_value(&"screen_shake", 0.25, false)
	assert_almost_eq(guard.camera.shake_scale, 0.25, 0.0001)


func test_a_landing_dips_the_eyes_and_they_spring_back() -> void:
	guard.global_position = Vector3(0, 3.0, 0)
	guard.reset_physics_interpolation()
	var low := 0.0
	for i in 90:
		await get_tree().process_frame
		low = minf(low, guard.camera.position.y)
	assert_lt(low, -0.02, "a dip on landing (%.3f m)" % low)
	assert_gt(low, -Player.LANDING_DIP_MAX - 0.005, "never a slam")
	await _frames(60)
	assert_lt(absf(guard.camera.position.y), 0.002, "and back up")


# --- the muzzle -------------------------------------------------------------------

func test_a_shot_flashes_at_the_muzzle_only_for_a_moment() -> void:
	guard.weapons.give(_weapon(&"pistol"))
	await physics_frames(2)
	await _frames(5)
	var muzzle := guard.weapons.muzzle_of(&"pistol")
	assert_not_null(muzzle)
	assert_false(muzzle.flash_showing())
	guard.weapons.try_fire()
	assert_true(muzzle.flash_showing(), "the fire star")
	assert_eq(muzzle.flashes, 1)
	await _frames(8)
	assert_false(muzzle.flash_showing(), "gone within a few frames")


func test_the_pistol_throws_a_casing_with_every_shot() -> void:
	guard.weapons.give(_weapon(&"pistol"))
	await physics_frames(2)
	guard.weapons.try_fire()
	assert_eq(guard.weapons.muzzle_of(&"pistol").casings_thrown, 1)


func test_the_rifle_throws_its_casing_when_the_bolt_runs_back() -> void:
	guard.weapons.give(_weapon(&"rifle_hunt"))
	await physics_frames(2)
	await _frames(5)
	var muzzle := guard.weapons.muzzle_of(&"rifle_hunt")
	guard.weapons.try_fire()
	assert_eq(muzzle.casings_thrown, 0, "not at the shot")
	await _frames(60)
	assert_eq(muzzle.casings_thrown, 1, "out with the bolt")


func test_the_shotgun_throws_its_spent_shells_when_it_breaks_open() -> void:
	guard.weapons.give(_weapon(&"shotgun"))
	await physics_frames(2)
	await _frames(5)
	var muzzle := guard.weapons.muzzle_of(&"shotgun")
	guard.weapons.try_fire()
	await physics_frames(20)
	guard.weapons.try_fire()   # the second barrel: an empty gun reloads by itself
	assert_eq(muzzle.casings_thrown, 0, "a break action keeps its shells until it opens")
	await _frames(40)
	assert_eq(muzzle.casings_thrown, 2, "both shells pop out")


func test_heavier_guns_flash_bigger() -> void:
	var pistol := FeelProfile.of(&"pistol")
	assert_gt(FeelProfile.of(&"shotgun").flash_size, pistol.flash_size * 1.8)
	assert_gt(FeelProfile.of(&"rifle_hunt").flash_size, pistol.flash_size * 1.4)
	assert_gt(FeelProfile.of(&"shotgun").light_energy, pistol.light_energy)
