extends TestCase
## Switching weapons in the hands (owner's note 45, plan
## 2026-10-21-animacje-fpp): the weapon in hand goes down out of the frame
## before the next comes up, the next is ready to fire at once (a shot
## hurries the switch), and put away every weapon is wholly under the frame.

var holder: WeaponHolder


func before_each() -> void:
	var user := Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	user.add_child(holder)


func _give(id: StringName) -> Node3D:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	return holder.view_of(id)


func _under_the_frame(view: Node3D) -> bool:
	return FpCheck.under_frame(holder, view)


func test_put_away_every_weapon_is_wholly_under_the_frame() -> void:
	for id in WeaponHolder.SLOT_ORDER:
		var view := _give(id)
		holder.select_id(id)
		await physics_frames(2)
		var pose: Array = ViewmodelMotion.holster_pose(ViewmodelMotion.grip_of(id))
		view.position = WeaponHolder.REST + (pose[0] as Vector3) * WeaponSwitch.HIDE_AT
		view.rotation = Vector3(0.0, WeaponHolder.AIM_YAW, 0.0) + (pose[1] as Vector3) * WeaponSwitch.HIDE_AT
		assert_true(_under_the_frame(view), "%s is out of sight when it is hidden" % id)
		view.position = WeaponHolder.REST
		view.rotation = Vector3(0.0, WeaponHolder.AIM_YAW, 0.0)
		assert_false(_under_the_frame(view), "%s at rest is in sight" % id)


func test_the_old_weapon_goes_down_before_the_new_one_comes_up() -> void:
	var pistol := _give(&"pistol")
	var shotgun := _give(&"shotgun")
	await physics_frames(30)
	assert_lt((pistol.position - WeaponHolder.REST).length(), 0.002, "the pistol is up")
	holder.select_id(&"shotgun")
	assert_eq(holder.current_state().data.id, &"shotgun", "the switch is at once for the logic")
	assert_true(pistol.visible, "the pistol is still in sight, going down")
	assert_true(_under_the_frame(shotgun), "the shotgun waits under the frame")
	var pistol_gone := -1
	var shotgun_seen := -1
	for i in 60:
		await get_tree().process_frame
		if pistol_gone < 0 and not pistol.visible:
			pistol_gone = i
		if shotgun_seen < 0 and not _under_the_frame(shotgun):
			shotgun_seen = i
	assert_gt(pistol_gone, 2, "the pistol takes a few frames to go")
	assert_lt(pistol_gone, 12, "and is gone in its holster time")
	assert_true(shotgun_seen >= pistol_gone, "the shotgun shows only once the pistol is gone (%d, %d)" % [pistol_gone, shotgun_seen])
	assert_lt((shotgun.position - WeaponHolder.REST).length(), 0.002, "the shotgun is up: %s" % shotgun.position)
	assert_almost_eq(shotgun.rotation.x, 0.0, 0.003)


func test_the_switch_moves_without_a_jump() -> void:
	var pistol := _give(&"pistol")
	var gatling := _give(&"gatling")
	await physics_frames(30)
	var views := [pistol, gatling]
	holder.select_id(&"gatling")
	var last := []
	for view: Node3D in views:
		last.append(view.transform)
	var widest := 0.0
	var widest_turn := 0.0
	for i in 60:
		await get_tree().process_frame
		for k in views.size():
			var view: Node3D = views[k]
			var before: Transform3D = last[k]
			if view.visible:
				widest = maxf(widest, view.position.distance_to(before.origin))
				widest_turn = maxf(widest_turn, view.basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion()))
			last[k] = view.transform
	assert_lt(widest, 0.12, "a motion, not a jump (%.3f m in a frame)" % widest)
	assert_lt(widest_turn, 0.3, "(%.3f rad in a frame)" % widest_turn)


func test_a_shot_during_the_switch_puts_the_old_weapon_out_of_the_way() -> void:
	var pistol := _give(&"pistol")
	var shotgun := _give(&"shotgun")
	await physics_frames(30)
	holder.select_id(&"shotgun")
	await get_tree().process_frame
	assert_true(holder.try_fire(), "the shotgun fires at once")
	assert_false(pistol.visible, "the pistol is out of the way")
	for i in 14:
		await get_tree().process_frame
	assert_lt((shotgun.position - WeaponHolder.REST).length(), 0.03, "and the shotgun up quickly")


func test_the_upgrade_inspection_still_plays_when_the_weapon_is_drawn() -> void:
	_give(&"pistol")
	var rig := _give(&"shotgun") as ViewmodelRig
	assert_not_null(rig, "a model rig, not a greybox stand-in")
	if rig == null:
		return
	await physics_frames(2)
	holder.apply_upgrades({&"shotgun_spread": 1})
	holder.select_id(&"shotgun")
	# (review L2) not while it is still under the frame: once it is up
	var frames := 0
	while holder._switch.lower(&"shotgun") >= 0.5 and frames < 60:
		assert_eq(rig.inspecting(), 0.0, "frame %d: not looked over under the frame" % frames)
		await get_tree().process_frame
		frames += 1
	assert_gt(frames, 3, "the pistol went down and the shotgun came up first")
	for i in 2:
		await get_tree().process_frame
	assert_gt(rig.inspecting(), ViewmodelRig.INSPECT_TIME - 0.1, "looked over as soon as it is up")


## The views in sight now.
func _shown(ids: Array) -> Array:
	var out := []
	for id: StringName in ids:
		if holder.view_of(id).visible:
			out.append(id)
	return out


## A storm of switches (A, B, C and back to A within a few frames): every
## view in sight is the one in hand or one on its way down, and once the
## storm has passed exactly one view is in sight - the one in hand, up.
func test_a_storm_of_switches_leaves_one_view_the_one_in_hand() -> void:
	var ids := [&"pistol", &"shotgun", &"gatling"]
	for id: StringName in ids:
		_give(id)
	await physics_frames(30)
	assert_eq(_shown(ids), [&"pistol"])
	var order := [&"shotgun", &"gatling", &"pistol", &"gatling", &"shotgun", &"pistol"]
	for id: StringName in order:
		holder.select_id(id)
		for i in 2:
			await get_tree().process_frame
			for shown: StringName in _shown(ids):
				assert_true(shown == holder.current_state().data.id or holder._switch.holstering().has(shown), "%s in sight: in hand or going down" % shown)
	for i in 60:
		await get_tree().process_frame
	assert_eq(holder.current_state().data.id, &"pistol")
	assert_eq(_shown(ids), [&"pistol"], "one view in sight, the one in hand")
	assert_false(holder._switch.busy(), "the switch is over")
	assert_lt((holder.view_of(&"pistol").position - WeaponHolder.REST).length(), 0.002, "and it is up")


## Switching away mid-reload cancels the reload (no rounds lost or gained)
## and the old weapon goes out of sight.
func test_a_switch_during_a_reload_cancels_it_and_puts_the_weapon_away() -> void:
	var pistol := _give(&"pistol")
	_give(&"shotgun")
	await physics_frames(30)
	var state := holder.state_of(&"pistol")
	state.magazine = 3
	state.reserve = 24
	assert_true(holder.try_reload())
	for i in 20:
		await get_tree().process_frame
	assert_true(state.is_reloading())
	holder.select_id(&"shotgun")
	assert_false(state.is_reloading(), "the reload is cancelled")
	assert_eq(state.magazine, 3, "no rounds gained")
	assert_eq(state.reserve, 24, "none lost")
	for i in roundi(ViewmodelMotion.holster_time(&"pistol") * 60.0) + 4:
		await get_tree().process_frame
	assert_false(pistol.visible, "the pistol is put away")


## A weapon put away half-posed - a break-action open mid-reload, a first
## look cut short - comes back at rest on its next draw, not half-posed
## (review L1); while it goes down it keeps its pose (no pop in the frame).
func test_a_weapon_put_away_half_posed_comes_back_at_rest() -> void:
	_give(&"pistol")
	for id in [&"shotgun", &"flare"]:
		var rig := _give(id) as ViewmodelRig
		assert_not_null(rig, "a model rig, not a greybox stand-in")
		if rig == null:
			continue
		holder.select_id(id)
		await physics_frames(30)
		var state := holder.state_of(id)
		state.magazine = 0
		state.reserve = maxi(state.reserve, 4)
		assert_true(holder.try_reload())
		for i in roundi(state.data.reload_time * 60.0 * 0.5):
			await get_tree().process_frame
		var hinge := rig.part_node(&"barrels" if id == &"shotgun" else &"barrel")
		var open := hinge.rotation.x
		assert_lt(open, -0.4, "%s: broken open mid-reload" % id)
		holder.select_id(&"pistol")
		await get_tree().process_frame
		assert_lt(hinge.rotation.x, open * 0.7, "%s: no pop as it goes down" % id)
		for i in roundi(ViewmodelMotion.holster_time(id) * 60.0) + 4:
			await get_tree().process_frame
		assert_false(rig.visible)
		holder.select_id(id)
		await get_tree().process_frame
		assert_almost_eq(hinge.rotation.x, 0.0, 0.01, "%s: drawn again shut" % id)
		assert_lt(rig.model.transform.origin.distance_to(rig._framing_xform.origin), 0.002, "%s: and at rest in the hands" % id)
		holder.select_id(&"pistol")
		await physics_frames(30)
	# a first look cut short by the switch
	var pistol := holder.view_of(&"pistol") as ViewmodelRig
	assert_not_null(pistol)
	if pistol == null:
		return
	holder.select_id(&"pistol")
	await physics_frames(40)
	pistol.look_over()
	for i in 20:
		await get_tree().process_frame
	holder.select_id(&"shotgun")
	for i in roundi(ViewmodelMotion.holster_time(&"pistol") * 60.0) + 4:
		await get_tree().process_frame
	assert_false(pistol.visible)
	holder.select_id(&"pistol")
	assert_eq(pistol.looking_over(), 0.0, "the cut look is over, not picked up again")
	await get_tree().process_frame
	assert_lt(pistol.model.transform.origin.distance_to(pistol._framing_xform.origin), 0.002, "drawn again at rest")
