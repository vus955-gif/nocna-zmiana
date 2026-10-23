extends TestCase
## The guard's blows and his reach in the hands (owner's note 45, plan
## 2026-10-21-animacje-fpp): a handgun (or no weapon) leaves the left fist
## free for a jab on an arc, a long gun bashes and a heavy piece shoves
## (never a second left hand beside the one on the fore-end); using
## something (E) sends the left hand out, a two-handed weapon going out of
## the frame first. Elbows stay out of the frame, nothing reaches the eye.

var guard: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 0)
	add_child(guard)


func after_each() -> void:
	Input.action_release(&"interact")


func _arm(id: StringName) -> Node3D:
	guard.weapons.give(load("res://src/weapons/data/%s.tres" % id))
	guard.weapons.select_id(id)
	return guard.weapons.view_of(id)


func test_a_jab_beside_a_handgun_shows_the_left_fist_on_its_arc() -> void:
	var pistol := _arm(&"pistol")
	await physics_frames(30)
	var fist := guard.weapons.view_of(&"fist")
	assert_false(fist.visible, "the fist waits out of sight")
	assert_true(guard.weapons.try_punch())
	var shown := 0
	var hit_seen := false
	var pulled := 0.0
	for i in 24:
		await get_tree().process_frame
		if fist.visible:
			shown += 1
			if fist.position.distance_to(WeaponHolder.FIST_HIT) < 0.03:
				hit_seen = true
		pulled = maxf(pulled, pistol.position.z - WeaponHolder.REST.z)
	assert_gt(shown, 10, "the fist is out for the blow")
	assert_true(hit_seen, "and lands on the hit")
	assert_gt(pulled, 0.02, "the pistol is pulled back as the shoulders turn")
	assert_false(fist.visible, "then it is gone")


func test_with_no_weapon_the_fist_still_jabs() -> void:
	await physics_frames(5)
	var fist := guard.weapons.view_of(&"fist")
	assert_true(guard.weapons.try_punch())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(fist.visible, "the left fist")


func test_a_long_gun_bashes_with_no_second_left_hand() -> void:
	for id in [&"shotgun", &"rifle_hunt", &"harpoon", &"gatling", &"hwacha"]:
		var view := _arm(id)
		await physics_frames(40)
		guard.weapons.fists._cooldown = 0.0
		var fist := guard.weapons.view_of(&"fist")
		var rest := view.position
		assert_true(guard.weapons.try_punch(), "%s: the blow" % id)
		var forward := 0.0
		var nearest_cut := INF
		for i in 24:
			await get_tree().process_frame
			assert_false(fist.visible, "%s: no free left fist" % id)
			forward = maxf(forward, rest.z - view.position.z)
			var rig := view as ViewmodelRig
			if rig != null:
				for side in rig.arm_sides():
					assert_false(FpCheck.in_frame(rig, rig.arm_line(side)[1], -0.1), "%s frame %d: elbow_%s out of the frame" % [id, i, side])
			nearest_cut = minf(nearest_cut, FpCheck.near_cut(guard.weapons, view))
		assert_gt(forward, 0.07, "%s: driven forward (%.3f m)" % [id, forward])
		assert_gt(nearest_cut, 1.2, "%s: nothing reaches the eye (%.2f)" % [id, nearest_cut])
		await physics_frames(20)


## The fist view's state (WeaponState) is private: fire() starts its cooldown.
func test_using_something_sends_the_left_hand_out() -> void:
	var pistol := _arm(&"pistol")
	var thing := Interactable.new()
	thing.add_box(Vector3(0.6, 0.6, 0.2))
	thing.position = Vector3(0, 1.65, -1.4)
	add_child(thing)
	await physics_frames(30)
	var fist := guard.weapons.view_of(&"fist")
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	var reached := false
	var made_way := 0.0
	for i in 30:
		await get_tree().process_frame
		if fist.visible and FpCheck.on_screen(fist.position, 0.2):
			reached = true
		made_way = maxf(made_way, pistol.position.x - WeaponHolder.REST.x)
	assert_true(reached, "the hand reaches out under the crosshair")
	assert_gt(made_way, 0.01, "the pistol makes way")
	await physics_frames(10)
	assert_false(fist.visible, "and comes back")


func test_nothing_to_use_no_reach() -> void:
	_arm(&"pistol")
	await physics_frames(30)
	Input.action_press(&"interact")
	await physics_frames(1)
	Input.action_release(&"interact")
	await physics_frames(5)
	assert_false(guard.weapons.view_of(&"fist").visible)


func test_reaching_with_a_two_handed_weapon_never_shows_two_left_hands() -> void:
	var view := _arm(&"shotgun") as ViewmodelRig
	await physics_frames(40)
	var fist := guard.weapons.view_of(&"fist")
	guard.weapons.reach()
	var reached := false
	for i in 60:
		await get_tree().process_frame
		var free_hand := fist.visible and FpCheck.on_screen(fist.position, -0.15)
		if free_hand:
			reached = true
			assert_true(FpCheck.under_frame(guard.weapons, view), "frame %d: the shotgun (and its fore hand) is out of sight" % i)
	assert_true(reached)
	await physics_frames(20)
	assert_lt((view.position - WeaponHolder.REST).length(), 0.003, "the shotgun is back in the hands")


func test_a_shot_during_a_reach_brings_the_weapon_back_quickly() -> void:
	var view := _arm(&"shotgun")
	await physics_frames(40)
	guard.weapons.reach()
	for i in 12:
		await get_tree().process_frame
	assert_true(guard.weapons.try_fire())
	for i in 16:
		await get_tree().process_frame
	assert_lt((view.position - WeaponHolder.REST).length(), 0.05, "up again for the fight")


## E pressed twice and a blow thrown during a reach (the review's M1): the
## weapon and the free fist move on without a jump, and a two-handed
## weapon never shows beside the free hand.
func test_e_twice_and_a_blow_during_a_reach_never_pop_the_weapon() -> void:
	for id in [&"pistol", &"shotgun"]:
		var view := _arm(id)
		await physics_frames(40)
		guard.weapons.fists._cooldown = 0.0
		var fist := guard.weapons.view_of(&"fist")
		var weapon_steps := []
		var fist_steps := []
		var last := FpCheck.snapshot(guard.weapons, view)
		var fist_was := fist.position
		var fist_shown := fist.visible
		guard.weapons.reach()
		for i in 90:
			if i == 18:
				guard.weapons.reach()   # E again at 0.3 s
			if i == 30:
				assert_true(guard.weapons.try_punch(), "%s: the blow" % id)   # 0.5 s in
			await get_tree().process_frame
			var now := FpCheck.snapshot(guard.weapons, view)
			weapon_steps.append(FpCheck.moved_in_sight(last, now, view)[0])
			last = now
			fist_steps.append(fist.position.distance_to(fist_was) if fist.visible and fist_shown else 0.0)
			fist_was = fist.position
			fist_shown = fist.visible
			if id == &"shotgun" and fist.visible and FpCheck.on_screen(fist.position, -0.15):
				assert_true(FpCheck.under_frame(guard.weapons, view), "frame %d: the shotgun is out of sight while the free hand shows" % i)
		var spike := FpCheck.spike(weapon_steps)
		assert_eq(spike, -1, "%s: the weapon jumps at frame %d" % [id, spike])
		spike = FpCheck.spike(fist_steps)
		assert_eq(spike, -1, "%s: the fist jumps at frame %d" % [id, spike])
		await physics_frames(40)
		assert_false(fist.visible, "%s: the hand is back" % id)
		assert_lt((view.position - WeaponHolder.REST).length(), 0.003, "%s: back in the hands" % id)
