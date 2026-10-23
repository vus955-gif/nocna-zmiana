extends TestCase
## Carrying the weapon on the run (owner's note 45, plan
## 2026-10-21-animacje-fpp): a handgun pulled in low and canted, a long gun
## across the body, a heavy piece low at the hip, rocking with the stride;
## a shot brings it up. In the full carry no elbow comes into the frame and
## nothing reaches the eye.

var guard: Player


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 120), Color.GRAY)
	guard = Player.new()
	guard.position = Vector3(0, 0.05, 40)
	add_child(guard)


func after_each() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


## The view's pose after [param frames] physics frames of sprinting.
func _sprint(frames: int) -> void:
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await physics_frames(frames)


func test_each_grip_is_carried_its_own_way() -> void:
	var poses := {}
	for id in [&"pistol", &"shotgun", &"gatling"]:
		guard.weapons.give(_weapon(id))
		guard.weapons.select_id(id)
		guard.global_position = Vector3(0, 0.05, 40)
		await physics_frames(40)
		await _sprint(45)
		assert_true(guard.sprinting, "%s: sprinting" % id)
		var view := guard.weapons.view_of(id)
		poses[id] = [view.position, view.rotation]
		Input.action_release(&"move_forward")
		Input.action_release(&"sprint")
		await physics_frames(40)
	var pistol: Array = poses[&"pistol"]
	var shotgun: Array = poses[&"shotgun"]
	var gatling: Array = poses[&"gatling"]
	for id in poses:
		assert_lt((poses[id][0] as Vector3).y, WeaponHolder.REST.y - 0.03, "%s lowered for the run" % id)
	assert_gt((pistol[1] as Vector3).z, 0.15, "the handgun canted in (roll %.2f)" % (pistol[1] as Vector3).z)
	assert_gt((shotgun[1] as Vector3).y, WeaponHolder.AIM_YAW + 0.25, "the long gun swung across the body (yaw %.2f)" % (shotgun[1] as Vector3).y)
	assert_lt((gatling[0] as Vector3).y, WeaponHolder.REST.y - 0.06, "the heavy piece low at the hip (%.3f)" % (gatling[0] as Vector3).y)


func test_the_carry_rocks_with_the_stride() -> void:
	guard.weapons.give(_weapon(&"shotgun"))
	await physics_frames(30)
	await _sprint(40)
	var view := guard.weapons.view_of(&"shotgun")
	var lowest := 9.0
	var highest := -9.0
	for i in 60:
		await get_tree().process_frame
		lowest = minf(lowest, view.rotation.z)
		highest = maxf(highest, view.rotation.z)
	assert_gt(highest - lowest, 0.05, "it rocks from side to side (%.3f rad)" % (highest - lowest))
	assert_lt(highest - lowest, 0.3, "but it is not thrown about")


func test_starting_and_stopping_a_run_moves_without_a_jump() -> void:
	guard.weapons.give(_weapon(&"rifle_hunt"))
	await physics_frames(30)
	var view := guard.weapons.view_of(&"rifle_hunt")
	var last := view.transform
	var widest := 0.0
	var widest_turn := 0.0
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 120:
		if i == 60:
			Input.action_release(&"sprint")
		await get_tree().process_frame
		widest = maxf(widest, view.position.distance_to(last.origin))
		widest_turn = maxf(widest_turn, view.basis.get_rotation_quaternion().angle_to(last.basis.get_rotation_quaternion()))
		last = view.transform
	assert_lt(widest, 0.02, "no jump (%.3f m in a frame)" % widest)
	assert_lt(widest_turn, 0.08, "(%.3f rad in a frame)" % widest_turn)


## Every weapon in its full carry at the widest of its rock: the elbows of
## a two-handed weapon stay out of the frame and no part is cut by the
## near plane inside the frame.
func test_in_the_full_carry_no_elbow_shows_and_nothing_reaches_the_eye() -> void:
	var holder := guard.weapons
	for id in WeaponHolder.SLOT_ORDER:
		holder.give(_weapon(id))
		holder.select_id(id)
		await physics_frames(30)
		var view := holder.view_of(id)
		for phase in [0.0, PI * 0.5, PI * 1.5]:
			FpCheck.pose_full_carry(holder, view, id, phase)
			var rig := view as ViewmodelRig
			if rig != null:
				for side in rig.arm_sides():
					var elbow: Vector3 = rig.arm_line(side)[1]
					assert_false(FpCheck.in_frame(rig, elbow, -0.1), "%s elbow_%s at phase %.1f" % [id, side, phase])
			var cut := FpCheck.near_cut(holder, view)
			assert_gt(cut, 1.2, "%s at phase %.1f: nothing cut by the near plane inside the frame (%.2f)" % [id, phase, cut])
