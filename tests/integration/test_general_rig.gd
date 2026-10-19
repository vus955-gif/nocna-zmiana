extends TestCase
## The General's body on a bare floor (no museum): the model's parts,
## markers and pivots (the cuirass without the stray ring at the floor), both
## fists on the hilt in every frame of the sword and through every attack
## of the moves (<= 3 cm), the point over the helmet in jodan, the feet on
## the floor by IK, the bow in the fist with its string drawn to the nock,
## the greybox with the same chains, the armour hanging on its stand and
## flying together, the draw out of the scabbard.

const FRAMES := {
	"chudan": [GeneralMoves.CHUDAN_GRIP, GeneralMoves.CHUDAN_DIR], "jodan": [GeneralMoves.JODAN_GRIP, GeneralMoves.JODAN_DIR],
	"thrust": [GeneralMoves.THRUST_GRIP, GeneralMoves.THRUST_DIR], "cut_start": [GeneralMoves.CUT_START_GRIP, GeneralMoves.CUT_START_DIR],
	"cut_end": [GeneralMoves.CUT_END_GRIP, GeneralMoves.CUT_END_DIR], "low_left": [GeneralMoves.LOW_LEFT_GRIP, GeneralMoves.LOW_LEFT_DIR],
	"chiburi": [GeneralMoves.CHIBURI_GRIP, GeneralMoves.CHIBURI_DIR], "kesa": [GeneralMoves.KESA_GRIP, GeneralMoves.KESA_DIR],
	"hasso": [GeneralMoves.HASSO_GRIP, GeneralMoves.HASSO_DIR], "planted": [GeneralMoves.PLANTED_GRIP, GeneralMoves.PLANTED_DIR],
	"dropped": [GeneralMoves.DROPPED_GRIP, GeneralMoves.DROPPED_DIR],
}
const STEP := 1.0 / 60.0

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)


func after_each() -> void:
	world.free()


func _rig() -> GeneralRig:
	return GeneralRig.create(world)


## How far fist [param side]'s grip point lies off the hilt (m).
func _off_hilt(rig: GeneralRig, pose: GeneralRig.Pose, side: int) -> float:
	var hilt := rig.hilt_segment(pose)
	var fist := rig.fist_point(side)
	return fist.distance_to(Geometry3D.get_closest_point_to_segment(fist, hilt[0], hilt[1]))


## A pose with the sword in [param frame] (torso space), the fists on it.
func _framed(rig: GeneralRig, frame: String, torso: Vector3 = Vector3.ZERO) -> GeneralRig.Pose:
	var pose := GeneralRig.Pose.new()
	pose.pelvis.y -= GeneralMoves.STANCE_DROP
	pose.torso = torso
	var xform := rig.torso_xform(pose)
	pose.sword_grip = xform * (FRAMES[frame][0] as Vector3)
	pose.sword_dir = (xform.basis * (FRAMES[frame][1] as Vector3)).normalized()
	return pose


func test_the_model_has_its_parts_markers_and_pivots_and_no_ring_at_the_floor() -> void:
	var rig := _rig()
	assert_false(rig.greybox, "the Blender model")
	for part_name in GeneralRig.PART_NAMES + GeneralRig.MARKERS:
		assert_not_null(rig.part(part_name), part_name)
	assert_lt(rig.rest_point("pelvis").distance_to(Vector3(0.0, 1.292, 0.0)), 0.02, "the pelvis")
	assert_lt(rig.rest_point("head").distance_to(Vector3(0.0, 2.203, 0.0)), 0.02, "the head")
	assert_lt(rig.rest_point("face").distance_to(Vector3(0.0, 2.414, -0.109)), 0.02, "the face")
	assert_lt(rig.rest_point("back").distance_to(Vector3(0.0, 1.768, 0.381)), 0.02, "the back")
	assert_lt(rig.grip_rest.distance_to(Vector3(0.095, 1.537, -0.49)), 0.02, "the grip")
	assert_lt(rig.blade_axis_rest.angle_to(Vector3(0.039, 0.635, -0.771)), 0.03, "the blade's line")
	assert_almost_eq(rig.blade_length, 1.78, 0.03)
	assert_almost_eq(rig.arm_reach(0), 0.881, 0.02, "the left arm")
	assert_almost_eq(rig.arm_reach(1), 0.775, 0.02, "the right arm")
	assert_almost_eq(rig.leg_reach(0), 1.123, 0.02, "a leg")
	# the cuirass's mesh ends at the hips: the gilt ring is at the back now,
	# not at the floor between the legs
	var torso := rig.part("torso") as MeshInstance3D
	assert_not_null(torso)
	if torso != null:
		assert_gt(torso.get_aabb().position.y, -0.6, "nothing of the cuirass hangs down to the floor (%.2f)" % torso.get_aabb().position.y)
	# the bow's string was cut out and the limbs made
	assert_eq(rig.part("bow").find_children("bow_limb_*", "MeshInstance3D", false, false).size(), 2, "two limbs")
	assert_eq(rig.part("bow").find_children("bowstring_*", "MeshInstance3D", false, false).size(), 2, "two string segments")


func test_both_fists_stay_on_the_hilt_in_every_frame_of_the_sword() -> void:
	var rig := _rig()
	for frame: String in FRAMES:
		for torso: Vector3 in [Vector3.ZERO, Vector3(-0.35, 0.5, 0.1), Vector3(0.2, -0.6, -0.1)]:
			var pose := _framed(rig, frame, torso)
			rig.apply(pose)
			for side in 2:
				assert_lt(_off_hilt(rig, pose, side), 0.03, "%s fist %s on the hilt in %s, torso %s (%.3f)" % ["left" if side == 0 else "right", "", frame, str(torso), _off_hilt(rig, pose, side)])
			assert_lt(rig.tip_point().distance_to(rig.blade_point(pose)), 0.01, "the sword on its frame in %s" % frame)
			# the hilt in the fists: never through the torso
			assert_gt(rig.hilt_segment(pose)[1].z - rig.torso_xform(pose).origin.z, -0.9, frame)


func test_jodan_lifts_the_point_over_the_helmet_chudan_holds_it_at_the_throat() -> void:
	var rig := _rig()
	rig.apply(_framed(rig, "jodan"))
	var tip := rig.tip_point()
	var crown := rig.part("head").global_position.y + 0.5
	assert_gt(tip.y, crown + 0.2, "the point over the helmet (%.2f over %.2f)" % [tip.y, crown])
	assert_gt(tip.z, 0.2, "the blade laid back over the head")
	rig.apply(_framed(rig, "chudan"))
	tip = rig.tip_point()
	assert_true(tip.y > 2.0 and tip.y < 2.9, "chudan: the point at a man's throat and up (%.2f)" % tip.y)
	assert_lt(tip.z, -1.5, "pointing at him")


func test_the_feet_stand_on_the_floor_by_ik_with_the_knees_forward() -> void:
	var rig := _rig()
	var pose := _framed(rig, "chudan")
	pose.feet = GeneralFootwork.NEUTRAL.duplicate()
	rig.apply(pose)
	for leg in 2:
		var foot := rig.part("foot_" + GeneralRig.SIDES[leg]).global_position
		assert_almost_eq(foot.y, GeneralFootwork.FOOT_HEIGHT, 0.015, "foot %d on the floor" % leg)
		assert_lt(Vector2(foot.x - pose.feet[leg].x, foot.z - pose.feet[leg].z).length(), 0.015, "foot %d where the footwork has it" % leg)
		var hip := rig.hip_at(pose, leg)
		var knee := rig.part("shin_" + GeneralRig.SIDES[leg]).global_position
		var along := (foot - hip).normalized()
		var side := (knee - hip) - along * (knee - hip).dot(along)
		assert_lt(side.z, -0.02, "knee %d bends forward (%.3f)" % [leg, side.z])
	# a step forward (the hips sink with it, as in the close cut): still on
	# the floor
	pose.feet[1] += Vector3(0.0, 0.0, -0.3)
	pose.pelvis.y -= 0.08
	rig.apply(pose)
	assert_almost_eq(rig.part("foot_r").global_position.y, GeneralFootwork.FOOT_HEIGHT, 0.02, "the stepping foot still on the floor")


func test_the_bow_comes_to_the_fist_and_its_string_draws_to_the_nock() -> void:
	var rig := _rig()
	var pose := _framed(rig, "chudan")
	pose.sword_grip = rig.sheathed_grip()
	pose.sword_dir = rig.sheathed_dir()
	pose.hands_on = [0.0, 0.0]
	pose.bow_in_hand = true
	pose.bow_aim = Vector3.FORWARD
	pose.bow_drawn = 1.0
	pose.arrow_in_hand = true
	pose.hand_free[0] = rig.shoulder_at(pose, 0) + Vector3(0.0, 0.05, -0.7)
	pose.hand_free[1] = rig.head_xform(pose) * GeneralMoves.CHEEK
	rig.apply(pose)
	var grip := rig.part("bow_grip").global_position
	assert_lt(grip.distance_to(rig.fist_point(0)), 0.03, "the grip in the left fist (%.3f)" % grip.distance_to(rig.fist_point(0)))
	var nock := rig.nock_point()
	assert_lt(nock.distance_to(rig.fist_point(1)), 0.03, "the arrow's nock in the right fist (%.3f)" % nock.distance_to(rig.fist_point(1)))
	assert_lt(grip.z, nock.z, "the bow held out ahead of the drawn string")
	assert_true(nock.z - grip.z > 0.5 and nock.z - grip.z < 0.9, "a full draw (%.2f m)" % (nock.z - grip.z))
	assert_lt(rig.arrow_line().angle_to(Vector3.FORWARD), 0.3, "the arrow along the aim")
	var strings := rig.part("bow").find_children("bowstring_*", "MeshInstance3D", false, false)
	assert_eq(strings.size(), 2)
	for segment: MeshInstance3D in strings:
		assert_true(segment.visible, "the string shows")
		var half := segment.global_basis.y * 0.5
		var ends := [segment.global_position + half, segment.global_position - half]
		var nearest := minf(ends[0].distance_to(nock), ends[1].distance_to(nock))
		assert_lt(nearest, 0.03, "a string segment ends at the nock")
	# slung on the back again: the string hidden, the bow behind him
	pose.bow_in_hand = false
	rig.apply(pose)
	for segment: MeshInstance3D in strings:
		assert_false(segment.visible)
	assert_gt(rig.part("bow_grip").global_position.z, 0.2, "the bow on the back")


func test_the_greybox_has_the_same_chains_and_markers() -> void:
	ArtLibrary.models_enabled = false
	var rig := _rig()
	ArtLibrary.models_enabled = true
	assert_true(rig.greybox)
	for part_name in GeneralRig.PART_NAMES + GeneralRig.MARKERS:
		assert_not_null(rig.part(part_name), part_name)
	assert_lt(rig.rest_point("face").distance_to(Vector3(0.0, 2.414, -0.109)), 0.02)
	var pose := _framed(rig, "jodan")
	rig.apply(pose)
	for side in 2:
		assert_lt(_off_hilt(rig, pose, side), 0.03, "greybox fist %d on the hilt" % side)


func test_the_armour_hangs_on_its_stand_and_flies_together_feet_first_helmet_last() -> void:
	var rig := _rig()
	var stand := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.2))
	rig.set_stand(stand)
	var pose := _framed(rig, "chudan")
	pose.assembly = 1.0
	rig.apply(pose)
	var home := {}
	for part_name in ["head", "foot_l", "torso", "hand_r"]:
		home[part_name] = rig.part(part_name).global_position
	pose.assembly = 0.0
	rig.apply(pose)
	for part_name in ["head", "foot_l", "torso", "hand_r"]:
		var at: Vector3 = rig.part(part_name).global_position
		assert_gt(at.z, 0.6, "%s hangs on the stand behind the post (%s)" % [part_name, str(at)])
		assert_gt(at.distance_to(home[part_name]), 0.8, "%s off its place" % part_name)
	pose.assembly = 0.4
	rig.apply(pose)
	assert_lt(rig.part("foot_l").global_position.distance_to(home["foot_l"]), 0.05, "the feet home first")
	assert_gt(rig.part("head").global_position.distance_to(home["head"]), 0.8, "the helmet still on the stand")
	pose.assembly = 1.0
	rig.apply(pose)
	for part_name in ["head", "foot_l", "torso", "hand_r"]:
		assert_lt(rig.part(part_name).global_position.distance_to(home[part_name]), 0.01, "%s home" % part_name)


## (The night's QA, 19.10: after his waking the quiver hung in the air beside
## the stand and the scabbard lay on the gravel, both following him about at
## that offset - the parts no pose drives kept the place their last flight
## frame left them in.)
func test_after_the_assembly_every_part_is_home_the_quiver_and_the_scabbard_too() -> void:
	var rig := _rig()
	rig.set_stand(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.2)))
	var pose := _framed(rig, "chudan")
	pose.assembly = 1.0
	rig.apply(pose)
	var home := {}
	for part_name in GeneralRig.PART_NAMES:
		home[part_name] = rig.part(part_name).global_transform
	# the waking, frame by frame
	for i in 91:
		pose.assembly = i / 90.0
		rig.apply(pose, STEP)
	for part_name in GeneralRig.PART_NAMES:
		var now := rig.part(part_name).global_transform
		var was: Transform3D = home[part_name]
		assert_lt(now.origin.distance_to(was.origin), 0.01, "%s home after the assembly (%.2f m off)" % [part_name, now.origin.distance_to(was.origin)])
		assert_lt(now.basis.get_rotation_quaternion().angle_to(was.basis.get_rotation_quaternion()), 0.02, "%s turned home" % part_name)
	# and they go with him when he moves on
	world.position = Vector3(5.0, 0.0, -3.0)
	rig.apply(pose, STEP)
	for part_name in ["quiver", "saya"]:
		var offset: Vector3 = rig.part(part_name).global_position - world.position
		assert_lt(offset.distance_to((home[part_name] as Transform3D).origin), 0.01, "%s goes with him" % part_name)


# --- the moves ----------------------------------------------------------------------

func _moves_set() -> Array:
	var rig := _rig()
	var moves := GeneralMoves.new(rig)
	var brain := GeneralBrain.new()
	brain.seed_with(3)
	var feet := GeneralFootwork.new()
	feet.place(Transform3D.IDENTITY)
	brain.wake()
	for i in roundi(GeneralBrain.WAKE_TIME / STEP) + 2:
		brain.update(STEP, 8.0, 0.0)
	return [rig, moves, brain, feet]


func test_the_moves_keep_both_fists_on_the_hilt_through_every_attack_and_state() -> void:
	var set := _moves_set()
	var rig: GeneralRig = set[0]
	var moves: GeneralMoves = set[1]
	var brain: GeneralBrain = set[2]
	var feet: GeneralFootwork = set[3]
	moves.guard = Vector3(1.5, 1.5, -6.0)
	var worst := {}
	for kind: GeneralBrain.Attack in [GeneralBrain.Attack.DASH, GeneralBrain.Attack.CLOSE, GeneralBrain.Attack.FEINT]:
		for landed in [false, true]:
			brain.force_attack(kind)
			var glinted := false
			var tip_high := false
			for i in 400:
				if brain.state != GeneralBrain.State.ATTACK:
					break
				if brain.stage == GeneralBrain.Stage.STRIKE and landed:
					brain.dash_landed()
				brain.update(STEP, 6.0, 0.2)
				var pose := moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
				rig.apply(pose, STEP)
				if moves.glint > 0.5:
					glinted = true
				if rig.tip_point().y > rig.part("head").global_position.y + 0.7:
					tip_high = true
				for side in 2:
					var off := _off_hilt(rig, pose, side)
					var key := "%s/%s" % [GeneralBrain.Attack.keys()[kind], "hit" if landed else "miss"]
					worst[key] = maxf(float(worst.get(key, 0.0)), off)
			if kind != GeneralBrain.Attack.CLOSE:
				assert_true(glinted, "%s: the blade glinted" % GeneralBrain.Attack.keys()[kind])
			assert_true(tip_high, "%s: the point rose over the helmet (jodan)" % GeneralBrain.Attack.keys()[kind])
			for i in 200:
				if brain.state == GeneralBrain.State.GUARD:
					break
				brain.update(STEP, 6.0, 0.2)
	for key: String in worst:
		assert_lt(float(worst[key]), 0.03, "%s: fists on the hilt (worst %.3f)" % [key, float(worst[key])])
	# the stun, the reel, the transformation
	brain.shock()
	var worst_stun := 0.0
	for i in roundi(GeneralBrain.STUN_TIME[0] / STEP) + 2:
		brain.update(STEP, 6.0, 0.2)
		var pose := moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
		rig.apply(pose, STEP)
		for side in 2:
			worst_stun = maxf(worst_stun, _off_hilt(rig, pose, side))
	assert_lt(worst_stun, 0.03, "stunned: fists on the hilt (%.3f)" % worst_stun)
	brain.stun_immunity = 0.0
	brain.shock()
	brain.finish()
	var worst_reel := 0.0
	for i in roundi(GeneralBrain.REEL_TIME / STEP) + 2:
		brain.update(STEP, 6.0, 0.2)
		var pose := moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
		rig.apply(pose, STEP)
		for side in 2:
			worst_reel = maxf(worst_reel, _off_hilt(rig, pose, side))
	assert_lt(worst_reel, 0.03, "reeling: fists on the hilt (%.3f)" % worst_reel)
	brain.set_phase(3)
	brain.can_roof = false
	for i in 200:
		if brain.state == GeneralBrain.State.TRANSFORM:
			break
		brain.update(STEP, 6.0, 0.2)
	assert_eq(brain.state, GeneralBrain.State.TRANSFORM)
	var worst_plant := 0.0
	var planted := false
	for i in roundi(GeneralBrain.TRANSFORM_TIME / STEP):
		brain.update(STEP, 6.0, 0.2)
		var pose := moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
		rig.apply(pose, STEP)
		if rig.tip_point().y < 0.08:
			planted = true
		for side in 2:
			worst_plant = maxf(worst_plant, _off_hilt(rig, pose, side))
	assert_true(planted, "the point goes into the gravel")
	assert_lt(worst_plant, 0.03, "transforming: fists on the hilt (%.3f)" % worst_plant)


func test_in_his_guard_the_feet_stand_on_the_floor_and_the_glint_comes_in_time() -> void:
	var set := _moves_set()
	var rig: GeneralRig = set[0]
	var moves: GeneralMoves = set[1]
	var brain: GeneralBrain = set[2]
	var feet: GeneralFootwork = set[3]
	moves.guard = Vector3(0.0, 1.5, -6.0)
	for i in 60:
		brain.update(STEP, 5.0, 0.0)
		feet.update(STEP, Transform3D.IDENTITY, Vector3.ZERO)
		rig.apply(moves.compose(brain, feet, Transform3D.IDENTITY, STEP), STEP)
	for leg in 2:
		assert_almost_eq(rig.part("foot_" + GeneralRig.SIDES[leg]).global_position.y, GeneralFootwork.FOOT_HEIGHT, 0.02, "foot %d on the gravel" % leg)
	assert_true(rig.part("pelvis").global_position.y < GeneralRig.PELVIS_REST.y - 0.04, "the knees bent in kamae")
	# the dash's glint: from its moment, at least 0.7 s before the cut
	brain.force_attack(GeneralBrain.Attack.DASH)
	var first := -1.0
	var clock := 0.0
	while brain.stage == GeneralBrain.Stage.TELEGRAPH:
		brain.update(STEP, 8.0, 0.0)
		clock += STEP
		moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
		if moves.glint > 0.5 and first < 0.0:
			first = clock
	assert_gt(first, 0.0, "it glinted")
	var warning := GeneralBrain.stage_length(GeneralBrain.Attack.DASH, GeneralBrain.Stage.TELEGRAPH, 1)
	assert_true(warning - first >= 0.7 - 0.05, "the glint %.2f s before the cut" % (warning - first))


func test_the_draw_brings_the_blade_out_of_the_scabbard_into_chudan() -> void:
	var rig := _rig()
	var moves := GeneralMoves.new(rig)
	var brain := GeneralBrain.new()
	var feet := GeneralFootwork.new()
	feet.place(Transform3D.IDENTITY)
	rig.set_stand(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.2)))
	# asleep: the sword in the scabbard at the left hip, the fists off it
	var pose := moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
	rig.apply(pose, STEP)
	assert_almost_eq(pose.assembly, 0.0)
	assert_lt(pose.sword_grip.x, -0.2, "the hilt at the left hip")
	assert_gt(_off_hilt(rig, pose, 1), 0.2, "the right fist off the hilt, asleep")
	brain.wake()
	var sheathed_tip := rig.blade_point(pose)
	var out := false
	var right_first := false
	for i in roundi(GeneralBrain.WAKE_TIME / STEP) + 1:
		brain.update(STEP, 8.0, 0.0)
		pose = moves.compose(brain, feet, Transform3D.IDENTITY, STEP)
		rig.apply(pose, STEP)
		if brain.draw_progress() > 0.35 and brain.draw_progress() < 0.6:
			if pose.hands_on[1] > 0.99 and pose.hands_on[0] < 0.01:
				right_first = true
		if rig.blade_point(pose).distance_to(sheathed_tip) > 1.0:
			out = true
	assert_true(right_first, "the right hand draws, the left holds the scabbard")
	assert_true(out, "the blade came out")
	assert_eq(brain.state, GeneralBrain.State.GUARD)
	assert_almost_eq(pose.assembly, 1.0)
	assert_almost_eq(pose.eyes, 1.0, 0.001, "the eyes lit")
	for side in 2:
		assert_lt(_off_hilt(rig, pose, side), 0.03, "fist %d on the hilt in chudan" % side)
	assert_lt(rig.tip_point().z, -1.4, "chudan: the point at the guard")
