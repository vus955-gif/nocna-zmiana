extends TestCase
## The arms of the two-handed first-person weapons (the owner's playtest
## notes 1 and 3: the fore hand bent as if broken, the rifle's clip floating
## in with no hand): every hand carries its arm markers, every wrist is
## within human limits at rest and through every pose the rig animates (the
## shotgun's break, the gatling's crank, the rifle's bolt and reload), and
## the rifle's reload is done by the left hand with the clip in it.

const TWO_HANDED: Array[StringName] = [&"rifle_hunt", &"shotgun", &"harpoon", &"gatling", &"hwacha"]
const SIDES := ["l", "r"]

var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	var user := Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _rig(id: StringName) -> ViewmodelRig:
	holder.give(load("res://src/weapons/data/%s.tres" % id))
	holder.select_id(id)
	var rig := holder.view_of(id) as ViewmodelRig
	assert_not_null(rig, "vm_%s is a model rig" % id)
	return rig


func _check_wrists(rig: ViewmodelRig, when: String) -> void:
	for side in SIDES:
		var angles := rig.wrist_angles(side)
		assert_true(ViewmodelRig.wrist_within_limits(angles), "%s hand_%s %s: flexion %.0f, deviation %.0f" % [rig.model_id, side, when, angles.x, angles.y])


## True when a point of the rig's model (root space) shows in a 16:9 frame
## drawn with the viewmodel field of view from the holder's eye (the holder
## sits at the camera), [param margin] of the frame's half size inside its
## edges.
func _in_frame(rig: ViewmodelRig, point: Vector3, margin: float = 0.0) -> bool:
	var at: Vector3 = rig.transform * rig.model.transform * point
	var depth := -at.z
	if depth <= 0.01:
		return false
	var half_h := depth * tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	var half_w := half_h * 16.0 / 9.0
	return absf(at.x) < half_w * (1.0 - margin) and absf(at.y) < half_h * (1.0 - margin)


func test_every_two_handed_weapon_carries_its_arms() -> void:
	for id in TWO_HANDED:
		var rig := _rig(id)
		if rig == null:
			continue
		assert_eq(rig.arm_sides().size(), 2, "%s has both arms" % id)
		for side in SIDES:
			for part in ["hand_", "sleeve_", "Wrist_", "Grip_", "Elbow_"]:
				assert_not_null(rig.part_node(StringName(part + side)), "%s has %s%s" % [id, part, side])
			var hand := rig.part_node(StringName("hand_" + side)) as MeshInstance3D
			var wrist := rig.part_node(StringName("Wrist_" + side))
			var grip := rig.part_node(StringName("Grip_" + side))
			var sleeve := rig.part_node(StringName("sleeve_" + side))
			if hand == null or wrist == null or grip == null or sleeve == null:
				continue
			# the markers sit on the hand, the wrist's Y runs up the hand
			# toward its grip, the sleeve pivots where the wrist is
			assert_eq(wrist.get_parent(), hand, "Wrist_%s on the hand" % side)
			assert_eq(grip.get_parent(), hand, "Grip_%s on the hand" % side)
			var to_grip := grip.position - wrist.position
			assert_gt(wrist.basis.y.dot(to_grip), 0.05, "%s Wrist_%s: Y points up the hand to the grip" % [id, side])
			assert_lt(absf(wrist.basis.x.dot(to_grip)), 0.025, "%s Wrist_%s: X is across the hand" % [id, side])
			var wrist_root := hand.transform * wrist.transform
			assert_eq(sleeve.get_parent(), hand.get_parent(), "%s sleeve_%s beside its hand" % [id, side])
			assert_lt(sleeve.position.distance_to(wrist_root.origin), 0.002, "%s sleeve_%s pivots at the wrist" % [id, side])
			assert_true(grip.basis.is_conformal() and grip.basis.determinant() > 0.0, "%s Grip_%s: a right-handed hand frame" % [id, side])


func test_every_wrist_is_within_limits_at_rest() -> void:
	for id in TWO_HANDED:
		var rig := _rig(id)
		if rig == null:
			continue
		await physics_frames(3)
		_check_wrists(rig, "at rest")
		# the sleeve runs from the wrist to the rest elbow, which is out of the frame
		for side in SIDES:
			var line := rig.arm_line(side)
			var elbow := rig.part_node(StringName("Elbow_" + side))
			assert_lt(line[1].distance_to(elbow.position), 0.01, "%s sleeve_%s points at its elbow at rest" % [id, side])
			assert_false(_in_frame(rig, line[1], -0.1), "%s elbow_%s out of the frame" % [id, side])


func test_the_shotgun_break_keeps_the_fore_hands_wrist() -> void:
	var rig := _rig(&"shotgun")
	if rig == null:
		return
	await physics_frames(3)
	var hand := rig.part_node(&"hand_l")
	var rest_pos := hand.position
	var sleeve := rig.part_node(&"sleeve_l")
	var sleeve_rest := sleeve.transform
	holder.try_fire()
	holder.try_fire()
	holder.try_reload()
	var moved := false
	for i in 70:
		await physics_frames(1)
		_check_wrists(rig, "frame %d of the break" % i)
		if hand.position.distance_to(rest_pos) > 0.03:
			moved = true
			assert_gt(sleeve.basis.get_rotation_quaternion().angle_to(sleeve_rest.basis.get_rotation_quaternion()), 0.03, "the sleeve bends at the elbow, not with the barrels")
	assert_true(moved, "the fore hand goes with the barrels")


func test_the_gatling_crank_keeps_the_right_wrist() -> void:
	var rig := _rig(&"gatling")
	if rig == null:
		return
	await physics_frames(3)
	var hand := rig.part_node(&"hand_r")
	var rest_pos := hand.position
	var moved := false
	for i in 90:
		holder.try_fire()
		await physics_frames(1)
		_check_wrists(rig, "frame %d of cranking" % i)
		if hand.position.distance_to(rest_pos) > 0.03:
			moved = true
	assert_true(moved, "the hand rides the crank")


func test_the_rifle_bolt_cycle_keeps_the_right_wrist() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	holder.try_fire()
	for i in 70:
		await physics_frames(1)
		_check_wrists(rig, "frame %d of the bolt cycle" % i)


## (The night's QA, 19.10, in the window: through the bolt cycle the right
## fist on the knob ran large into the frame's bottom right corner.) The
## fist riding the knob stays within the frame, no bigger than at rest by
## much.
func test_the_rifle_bolt_cycle_keeps_the_right_fist_in_the_frame() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	var t := tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	holder.try_fire()
	var shown := 0
	for i in 70:
		await physics_frames(1)
		_check_wrists(rig, "frame %d of the bolt cycle" % i)
		var grip: Vector3 = rig.transform * rig.model.transform * rig.grip_transform("r").origin
		var on := Vector2(grip.x / (-grip.z * t) * 9.0 / 16.0, grip.y / (-grip.z * t))
		if on.y < -1.1:
			continue   # (under the frame: on the trigger, the shot's kick)
		shown += 1
		assert_lt(absf(on.x), 0.95, "frame %d: the fist on the knob within the frame, not past its right edge (%.2f)" % [i, on.x])
		assert_gt(-grip.z, 0.24, "frame %d: and a forearm from the eye, not filling the corner (%.2f m)" % [i, -grip.z])
	assert_gt(shown, 10, "the fist rides the knob up into the frame")


func test_the_rifle_reload_is_done_by_the_left_hand_with_the_clip_in_it() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	var hand := rig.part_node(&"hand_l")
	var clip := rig.part_node(&"clip") as MeshInstance3D
	var rest_hand: Transform3D = hand.transform
	var clip_rest: Transform3D = rig.rest["clip"]
	var clip_len := clip.get_aabb().size.y
	var state := holder.current_state()
	state.magazine = 0
	assert_true(holder.try_reload())
	var frames := roundi(state.data.reload_time * 60.0)
	var left_fore_end := false
	var held_frames := 0
	var inserted := false
	var flicked := false
	var lowest := 0.0
	for i in frames + 2:
		await physics_frames(1)
		var p := state.reload_progress()
		_check_wrists(rig, "reload %.2f" % p)
		var line := rig.arm_line("l")
		assert_false(_in_frame(rig, line[1], -0.1), "reload %.2f: the left elbow stays out of the frame" % p)
		assert_true(_in_frame(rig, rig.grip_transform("l").origin) or p < 0.4 or p > 0.9, "reload %.2f: the hand works in view" % p)
		lowest = minf(lowest, hand.position.y - rest_hand.origin.y)
		if hand.position.distance_to(rest_hand.origin) > 0.15:
			left_fore_end = true
		if rig.clip_held():
			held_frames += 1
			assert_true(clip.visible, "reload %.2f: the clip in the hand shows" % p)
			# the clip's top sits in the fist, just inside its little-finger edge
			var top := clip.transform * Vector3(0.0, clip_len, 0.0)
			var grip := rig.grip_transform("l").origin
			assert_lt(top.distance_to(grip), 0.04, "reload %.2f: the clip's top is in the fist (%.3f m from its grip)" % [p, top.distance_to(grip)])
			assert_gt(clip.transform.basis.y.dot(grip - top), 0.0, "reload %.2f: the clip hangs down from the fist" % p)
			if clip.transform.origin.distance_to(clip_rest.origin) < 0.004 and clip.transform.basis.y.dot(Vector3.UP) > 0.99:
				inserted = true
		elif clip.visible:
			flicked = true
			assert_gt(clip.transform.origin.distance_to(clip_rest.origin), 0.02, "reload %.2f: the flicked clip is away from the guides" % p)
	assert_true(left_fore_end, "the hand leaves the fore-end")
	assert_lt(lowest, -0.2, "the hand reaches down out of the frame for the clip")
	assert_gt(held_frames, 20, "the clip rides in the hand for a good while")
	assert_true(inserted, "the clip stands straight in the charger guides at the insert")
	assert_true(flicked, "the empty clip is flicked away")
	assert_false(clip.visible, "the clip is gone at the end")
	await physics_frames(2)
	assert_lt(hand.position.distance_to(rest_hand.origin), 0.01, "the hand is back under the fore-end")
	assert_lt(hand.basis.get_rotation_quaternion().angle_to(rest_hand.basis.get_rotation_quaternion()), 0.03, "and holds it as before")


## Where a mesh part of the rig shows in the 16:9 frame (normalised: -1..1
## both ways, +y up): its box's corners projected with the viewmodel field of
## view from the holder's eye.
func _frame_box(rig: ViewmodelRig, node: Node3D) -> Rect2:
	var to_root := Transform3D.IDENTITY
	var walker := node
	while walker != null and walker != rig:
		to_root = walker.transform * to_root
		walker = walker.get_parent() as Node3D
	var box := (node as MeshInstance3D).get_aabb()
	var t := tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	var out := Rect2()
	for i in 8:
		var corner := box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var at: Vector3 = rig.transform * to_root * corner
		var on := Vector2(at.x / (-at.z * t) * 9.0 / 16.0, at.y / (-at.z * t))
		out = Rect2(on, Vector2.ZERO) if i == 0 else out.expand(on)
	return out


## (The night's QA, 19.10, in the window: lifted to the eye for the reload,
## the action came to a third of a metre from it and the left fist at the
## guides filled half the screen, hiding the clip; at the pouch the fist's
## top showed at the bottom edge.)
func test_the_rifle_reload_keeps_the_fist_a_fair_size_under_the_eye_line() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	var hand := rig.part_node(&"hand_l")
	var state := holder.current_state()
	state.magazine = 0
	holder.try_reload()
	var at_action := 0
	var at_pouch := 0
	for i in roundi(state.data.reload_time * 60.0):
		await physics_frames(1)
		var p := state.reload_progress()
		var box := _frame_box(rig, hand)
		if p >= ViewmodelRig.RELOAD_KEYS[3] and p <= ViewmodelRig.RELOAD_KEYS[6]:
			at_action += 1
			var grip: Vector3 = rig.transform * rig.model.transform * rig.grip_transform("l").origin
			assert_gt(-grip.z, 0.5, "reload %.2f: the action half a metre out (%.2f)" % [p, -grip.z])
			assert_lt(grip.y, 0.0, "reload %.2f: the fist under the eye line (%.2f)" % [p, grip.y])
			assert_lt(box.size.y, 0.9, "reload %.2f: the fist's box under 45%% of the frame's height (%.2f)" % [p, box.size.y * 0.5])
			assert_gt(box.end.y, -0.75, "reload %.2f: and up in the frame (top at %.2f)" % [p, box.end.y])
		elif p >= ViewmodelRig.RELOAD_KEYS[1] and p <= ViewmodelRig.RELOAD_KEYS[2]:
			at_pouch += 1
			assert_lt(box.end.y, -0.98, "reload %.2f: the fist all under the frame at the pouch (top at %.2f)" % [p, box.end.y])
	assert_gt(at_action, 10, "frames at the action checked")
	assert_gt(at_pouch, 5, "frames at the pouch checked")


func test_the_rifle_bolt_runs_home_after_the_reload() -> void:
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	var bolt := rig.part_node(&"bolt")
	var bolt_rest: Transform3D = rig.rest["bolt"]
	var state := holder.current_state()
	state.magazine = 0
	holder.try_reload()
	await physics_frames(roundi(state.data.reload_time * 60.0) - 2)
	assert_gt(bolt.position.distance_to(bolt_rest.origin), 0.05, "the bolt is open through the reload")
	await physics_frames(8)
	assert_gt(bolt.position.distance_to(bolt_rest.origin), 0.01, "it starts running home, not snapping shut")
	await physics_frames(30)
	assert_lt(bolt.position.distance_to(bolt_rest.origin), 0.002, "closed")
	assert_lt((bolt.basis.get_euler() - bolt_rest.basis.get_euler()).length(), 0.02, "handle down")
	_check_wrists(rig, "after the reload")


func test_a_cut_reload_brings_the_hand_back_smoothly() -> void:
	_rig(&"shotgun")
	var rig := _rig(&"rifle_hunt")
	if rig == null:
		return
	await physics_frames(3)
	var hand := rig.part_node(&"hand_l")
	var rest_pos := hand.position
	var state := holder.current_state()
	state.magazine = 0
	holder.try_reload()
	await physics_frames(roundi(state.data.reload_time * 60.0 * 0.5))
	var away := hand.position.distance_to(rest_pos)
	assert_gt(away, 0.1, "the hand is at the action")
	holder.select_id(&"shotgun")
	holder.select_id(&"rifle_hunt")
	await physics_frames(1)
	var step := hand.position.distance_to(rest_pos)
	assert_lt(step, away, "coming back")
	assert_gt(step, 0.02, "not snapped")
	await physics_frames(60)
	assert_lt(hand.position.distance_to(rest_pos), 0.005, "back under the fore-end")


## (Plan 2026-10-21-animacje-fpp, owner's note 45: every reload frame by
## frame.) The reloads the arms ride through - the harpoon tipped up, the
## fire-arrow chest jolting as each arrow seats, the gatling hauling in its
## next belt, the shotgun's keyed break - keep every wrist within its
## limits and both elbows out of the frame.
func test_every_two_handed_reload_keeps_the_wrists_and_the_elbows() -> void:
	for id in [&"shotgun", &"rifle_hunt", &"harpoon", &"hwacha", &"gatling"]:
		var rig := _rig(id)
		if rig == null:
			continue
		await physics_frames(40)
		var state := holder.current_state()
		state.magazine = 0
		state.reserve = maxi(state.reserve, state.data.magazine_size * 2)
		if state.data.belt_feed:
			state._feed_belt()
		else:
			assert_true(holder.try_reload(), "%s reloads" % id)
		var frames := roundi((state.data.belt_change_time if state.data.belt_feed else state.data.reload_time) * 60.0) + 20
		for i in frames:
			await physics_frames(1)
			_check_wrists(rig, "reload frame %d" % i)
			for side in SIDES:
				assert_false(_in_frame(rig, rig.arm_line(side)[1], -0.1), "%s reload frame %d: elbow_%s out of the frame" % [id, i, side])
		assert_false(state.is_reloading(), "%s reloaded" % id)


## The whole-weapon motions (the switch, the run, the bash, a wall, the
## first look) turn the model as one piece: the wrists stay as they were
## and the elbows out of the frame.
func test_the_whole_weapon_motions_keep_the_wrists_and_the_elbows() -> void:
	for id in TWO_HANDED:
		var rig := _rig(id)
		if rig == null:
			continue
		await physics_frames(40)
		rig.look_over()
		for i in roundi(rig.first_look_time() * 60.0):
			await physics_frames(1)
			_check_wrists(rig, "first look frame %d" % i)
			for side in SIDES:
				assert_false(_in_frame(rig, rig.arm_line(side)[1], -0.1), "%s first look frame %d: elbow_%s out of the frame" % [id, i, side])
