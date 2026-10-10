extends TestCase
## The Lamassu's parts on a bare floor (no museum): its rig (the carved
## piece at rest, the greybox with the same parts, four legs by IK with the
## contacts on their points, knees forward and hocks back, the wings
## spreading, the cracked set, the crown and a wing tip breaking off), its
## plinth (half a metre of alabaster with a collider), its arena's markers
## in the palace courtyard (six covers, the reward), and its choreography
## (the stomp lands on its point, the stunned face hangs low, the gust
## raises the wings, the pawing hoof).

const FL := 0
const FR := 1
const BL := 2
const BR := 3

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 1.0, 120.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)


func after_each() -> void:
	world.free()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD))


func _rig() -> LamassuRig:
	var holder := Node3D.new()
	holder.name = "Body"
	world.add_child(holder)
	return LamassuRig.create(holder)


# --- the rig ----------------------------------------------------------------------

func test_at_rest_it_is_the_carved_piece_and_the_greybox_has_its_parts() -> void:
	var rig := _rig()
	for part_name in LamassuRig.PART_NAMES:
		assert_not_null(rig.part(part_name), part_name)
	for marker in ["face", "crown", "contact_fl", "contact_fr", "contact_bl", "contact_br"]:
		assert_not_null(rig.part(marker), marker)
	var before := {}
	for part_name in LamassuRig.PART_NAMES:
		before[part_name] = rig.part(part_name).global_position
	var face := rig.face_point()
	var pose := LamassuRig.Pose.new()
	rig.apply(pose, 1.0 / 60.0)
	for part_name in LamassuRig.PART_NAMES:
		assert_lt(rig.part(part_name).global_position.distance_to(before[part_name]), 0.01, "%s stays as carved" % part_name)
	assert_lt(rig.face_point().distance_to(face), 0.01, "the face where the sculptor put it")
	assert_gt(rig.face_point().y, 2.9, "a tall figure: the face high up")
	for leg in 4:
		assert_almost_eq(rig.contact(leg).y, 0.0, 0.03, "contact %d on the floor" % leg)
	var grey := LamassuRig._make_greybox()
	var names := {}
	for node in grey.find_children("*", "Node3D", true, false):
		names[String(node.name)] = true
	for part_name in LamassuRig.PART_NAMES + ["face", "crown", "contact_fl", "contact_fr", "contact_bl", "contact_br"]:
		assert_true(names.has(part_name), "greybox %s" % part_name)
	# the same chains
	for pair: Array in [["head", "body"], ["headdress", "head"], ["wing_l_tip", "wing_l"], ["shin_fl", "thigh_fl"],
			["hoof_bl", "shin_bl"], ["contact_br", "hoof_br"], ["face", "head"], ["crown", "headdress"]]:
		var child := grey.find_child(pair[0], true, false)
		assert_eq(String(child.get_parent().name), pair[1], "greybox %s under %s" % [pair[0], pair[1]])
	grey.free()


func test_ik_plants_the_contacts_on_their_points_knees_forward_hocks_back_soles_level() -> void:
	var rig := _rig()
	var pose := LamassuRig.Pose.new()
	pose.legs_ik = 1.0
	pose.body = LamassuRig.BODY_REST + Vector3(0.0, -0.16, 0.0)
	pose.body_turn = Vector3(-0.08, 0.0, 0.03)
	# the hooves a little spread, one a step forward
	pose.contacts[FL] = LamassuGait.NEUTRAL[FL] + Vector3(-0.08, 0.0, -0.3)
	pose.contacts[FR] = LamassuGait.NEUTRAL[FR] + Vector3(0.08, 0.0, 0.2)
	pose.contacts[BL] = LamassuGait.NEUTRAL[BL] + Vector3(-0.1, 0.0, 0.25)
	pose.contacts[BR] = LamassuGait.NEUTRAL[BR] + Vector3(0.1, 0.0, -0.2)
	rig.apply(pose, 1.0 / 60.0)
	for leg in 4:
		var got := rig.contact(leg)
		assert_lt(got.distance_to(pose.contacts[leg]), 0.03, "contact %d on its point (off %.3f)" % [leg, got.distance_to(pose.contacts[leg])])
		# the sole level with the floor
		var up := rig.part("hoof_" + LamassuRig.LEGS[leg]).global_basis.y
		assert_gt(up.y, 0.98, "hoof %d level" % leg)
	for leg in 4:
		var root := rig.part("thigh_" + LamassuRig.LEGS[leg]).global_position
		var joint := rig.part("shin_" + LamassuRig.LEGS[leg]).global_position
		var fetlock := rig.part("hoof_" + LamassuRig.LEGS[leg]).global_position
		var line := (fetlock - root).normalized()
		var side := (joint - root) - line * (joint - root).dot(line)
		var forward := -world.global_basis.z
		if leg < 2:
			assert_gt(side.dot(forward), 0.005, "the fore knee %d bends forward" % leg)
		else:
			assert_lt(side.dot(forward), -0.005, "the hock %d bends back" % leg)
	# a lifted hoof curls back
	pose.contacts[FL].y = 0.3
	pose.hoof_pitch[FL] = -0.9
	rig.apply(pose, 1.0 / 60.0)
	var hoof := rig.part("hoof_fl")
	var toe := rig.part("contact_fl").global_position - hoof.global_position
	assert_gt(toe.z, 0.0, "the toe trails behind the fetlock")


func test_spread_wings_lift_their_tips_up_and_out_and_a_beat_brings_them_forward() -> void:
	var rig := _rig()
	var pose := LamassuRig.Pose.new()
	rig.apply(pose, 0.0)
	var rest_l := rig.part("wing_l_tip").global_position
	var rest_r := rig.part("wing_r_tip").global_position
	var rest_end := rig.wing_end(0)
	assert_gt(rest_end.z, rest_l.z + 0.5, "folded, the wing lies back along the body")
	pose.wing_spread = [1.2, 1.2]
	pose.wing_tip = [0.4, 0.4]
	rig.apply(pose, 0.0)
	var spread_l := rig.part("wing_l_tip").global_position
	var spread_r := rig.part("wing_r_tip").global_position
	assert_lt(spread_l.x, rest_l.x - 0.3, "the left tip goes out to the left")
	assert_gt(spread_r.x, rest_r.x + 0.3, "the right tip goes out to the right")
	assert_lt(rig.wing_end(0).x, rest_end.x - 0.6, "the left wing's end far out")
	assert_gt(rig.wing_end(1).x, -rest_end.x + 0.6, "the right wing's end far out")
	pose.wing_raise = [1.0, 1.0]
	rig.apply(pose, 0.0)
	var raised_end := rig.wing_end(0)
	assert_gt(raised_end.y, rest_end.y + 0.8, "raised, the wing's end high up")
	assert_gt(rig.wing_end(1).y, rest_end.y + 0.8, "both of them")
	pose.wing_beat = [1.0, 1.0]
	rig.apply(pose, 0.0)
	var beat_end := rig.wing_end(0)
	assert_lt(beat_end.z, raised_end.z - 0.5, "a beat brings the wing forward")
	assert_lt(rig.wing_end(1).z, raised_end.z - 0.5, "both of them")


func test_the_cracked_set_the_crown_and_a_wing_tip_break_off_and_come_back() -> void:
	var rig := _rig()
	var pose := LamassuRig.Pose.new()
	rig.apply(pose, 0.0)
	assert_false(rig.cracked)
	rig.crack(true)
	assert_true(rig.cracked)
	if not rig.greybox:
		var sets := {}
		for view in rig.meshes:
			for i in view.mesh.get_surface_count():
				var mat := view.get_active_material(i)
				if mat != null:
					sets[mat.resource_name] = true
		assert_true(sets.has("lamassu_cracked"), "the cracked set shows: %s" % str(sets.keys()))
		assert_false(sets.has("lamassu"), "the clean set is gone")
	var crown := rig.drop_crown(Vector3(0.0, 3.0, -2.0))
	assert_not_null(crown, "the crown falls as a body")
	assert_true(crown is RigidBody3D)
	assert_false(rig.part("headdress").visible)
	assert_false(rig.crown_on)
	assert_eq(rig.drop_crown(Vector3.ZERO), null, "only once")
	var tip := rig.drop_wing_tip(0, Vector3(-2.0, 2.0, 0.0))
	assert_not_null(tip, "the wing tip breaks off")
	assert_false(rig.part("wing_l_tip").visible)
	assert_true(rig.part("wing_r_tip").visible, "the other stays")
	rig.restore()
	assert_true(rig.part("headdress").visible)
	assert_true(rig.part("wing_l_tip").visible)
	assert_false(rig.cracked, "whole and clean again")


# --- the plinth and the arena ------------------------------------------------------

func test_the_plinth_is_half_a_metre_of_stone_with_a_collider() -> void:
	var plinth := LamassuPlinth.make(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, -3.0)))
	world.add_child(plinth)
	await physics_frames(2)
	assert_true(plinth.is_in_group(LamassuPlinth.GROUP))
	assert_eq(plinth.collision_layer, Layers.WORLD)
	var hit := _ray(Vector3(4.0, 3.0, -3.0), Vector3(4.0, -1.0, -3.0))
	assert_false(hit.is_empty(), "something under the bull")
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).y, LamassuPlinth.HEIGHT, 0.02, "its top half a metre up")
	var front := _ray(Vector3(4.0, 0.25, -3.0 - LamassuPlinth.SIZE.z * 0.5 - 1.0), Vector3(4.0, 0.25, -3.0))
	assert_false(front.is_empty(), "a front face")
	assert_true(_ray(Vector3(4.0, 0.25, -3.0 - LamassuPlinth.SIZE.z * 0.5 - 1.0), Vector3(4.0, 0.25, -3.0 - LamassuPlinth.SIZE.z * 0.5 - 0.3)).is_empty(), "nothing in front of it")
	assert_almost_eq(plinth.top(), LamassuPlinth.HEIGHT, 0.001)


func test_the_courtyard_marks_six_covers_and_the_reward() -> void:
	var layout := Floor1Layout.create()
	var covers: Array = layout.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("lamassu_cover_"))
	assert_eq(covers.size(), 6, "four genii and two cedars")
	for id: StringName in covers:
		assert_eq(layout.marker_rooms[id], &"assyria_courtyard", str(id))
		var at: Vector3 = (layout.markers[id] as Transform3D).origin
		var found := false
		for piece in layout.pieces:
			if (piece.kit == &"pedestal" or piece.kit == &"column") and Vector2(piece.position.x - at.x, piece.position.z - at.z).length() < 0.1:
				found = true
		assert_true(found, "%s stands on a pedestal or a column" % id)
	assert_true(layout.markers.has(&"arena_lamassu_reward"))
	assert_eq(layout.marker_rooms[&"arena_lamassu_reward"], &"assyria_courtyard")
	var post: Vector3 = (layout.markers[&"guardian_lamassu"] as Transform3D).origin
	var reward: Vector3 = (layout.markers[&"arena_lamassu_reward"] as Transform3D).origin
	assert_gt(reward.distance_to(post), 4.0, "the reward lies out in the court, not on the plinth")


# --- the choreography ----------------------------------------------------------------

## A rig in the world with its moves, gait and an awake brain: [holder,
## rig, moves, gait, brain].
func _rigged() -> Array:
	var holder := Node3D.new()
	holder.name = "Body"
	world.add_child(holder)
	var rig := LamassuRig.create(holder)
	var moves := LamassuMoves.new(rig)
	var gait := LamassuGait.new()
	var brain := LamassuBrain.new()
	brain.seed_with(3)
	gait.place(holder.global_transform)
	moves.guard = Vector3(0.0, 1.5, -30.0)
	brain.wake()
	var kit := [holder, rig, moves, gait, brain]
	_drive(kit, LamassuBrain.WAKE_TIME + 0.05, 0.0, 0.0)
	return kit


## Drives [param kit] for [param seconds]: the body runs at [param speed]
## along its facing turning [param turn] rad/s, the gait in [param mode];
## calls [param each] (Callable) every frame when given.
func _drive(kit: Array, seconds: float, speed: float, turn: float, mode: LamassuGait.Mode = LamassuGait.Mode.STAND, each: Callable = Callable()) -> void:
	var holder: Node3D = kit[0]
	var rig: LamassuRig = kit[1]
	var moves: LamassuMoves = kit[2]
	var gait: LamassuGait = kit[3]
	var brain: LamassuBrain = kit[4]
	var step := 1.0 / 60.0
	for i in roundi(seconds / step):
		var turned := Basis(Vector3.UP, turn * step) * holder.global_basis
		var velocity := turned * Vector3.FORWARD * speed
		holder.global_transform = Transform3D(turned, holder.global_position + velocity * step)
		var flat := Vector2(moves.guard.x, moves.guard.z)
		brain.update(step, flat.length(), atan2(-moves.guard.x, -moves.guard.z))
		var wanted := mode
		if speed > 0.2 and mode == LamassuGait.Mode.STAND:
			wanted = LamassuGait.Mode.WALK
		gait.update(step, holder.global_transform, velocity, turn, wanted)
		rig.apply(moves.compose(brain, gait, holder.global_transform, step), step)
		if each.is_valid():
			each.call()


func test_asleep_it_is_the_carved_piece() -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	var rig := LamassuRig.create(holder)
	var before := {}
	for part_name in LamassuRig.PART_NAMES:
		before[part_name] = rig.part(part_name).global_position
	var moves := LamassuMoves.new(rig)
	var gait := LamassuGait.new()
	gait.place(holder.global_transform)
	var brain := LamassuBrain.new()
	for i in 30:
		rig.apply(moves.compose(brain, gait, holder.global_transform, 1.0 / 60.0), 1.0 / 60.0)
	for part_name in LamassuRig.PART_NAMES:
		assert_lt(rig.part(part_name).global_position.distance_to(before[part_name]), 0.01, "%s as carved" % part_name)
	assert_almost_eq(moves.pose.eyes, 0.0, 0.001, "eyes dark")


func test_walking_the_body_settles_onto_the_hooves_and_the_contacts_stay_down() -> void:
	var kit := _rigged()
	var rig: LamassuRig = kit[1]
	var gait: LamassuGait = kit[3]
	var moves: LamassuMoves = kit[2]
	moves.guard = Vector3(0.0, 1.5, 40.0)   # far behind: it walks, picks nothing
	var off := [0.0]
	var lowest := [LamassuRig.BODY_REST.y]
	var knees := [0]
	var check := func() -> void:
		for leg in 4:
			if gait.planted(leg):
				off[0] = maxf(off[0], absf(rig.contact(leg).y))
		lowest[0] = minf(lowest[0], rig.part("body").global_position.y)
		var forward := -(kit[0] as Node3D).global_basis.z
		var root := rig.part("thigh_fl").global_position
		var knee := rig.part("shin_fl").global_position
		var fetlock := rig.part("hoof_fl").global_position
		var line := (fetlock - root).normalized()
		var side := (knee - root) - line * (knee - root).dot(line)
		if side.length() > 0.01:
			knees[0] += 1 if side.dot(forward) > 0.0 else -1
	for i in 30:
		_drive(kit, 1.0 / 60.0, 1.9 * i / 30.0, 0.0, LamassuGait.Mode.WALK, check)
	_drive(kit, 3.0, 1.9, 0.0, LamassuGait.Mode.WALK, check)
	_drive(kit, 2.0, 1.6, 0.5, LamassuGait.Mode.WALK, check)
	assert_lt(off[0], 0.06, "planted contacts on the floor (worst %.3f m off)" % off[0])
	assert_lt(lowest[0], LamassuRig.BODY_REST.y - 0.04, "the body settles onto spread legs")
	assert_gt(knees[0], 0, "the fore knee bends forward")


func test_the_stomp_rears_then_brings_the_fore_hooves_down_on_its_point() -> void:
	var kit := _rigged()
	var rig: LamassuRig = kit[1]
	var moves: LamassuMoves = kit[2]
	var brain: LamassuBrain = kit[4]
	moves.guard = Vector3(0.0, 1.5, -3.0)
	brain.force_attack(LamassuBrain.Attack.STOMP)
	var point := moves.stomp_point
	_drive(kit, LamassuBrain.stage_length(LamassuBrain.Attack.STOMP, LamassuBrain.Stage.TELEGRAPH, 1) * 0.6, 0.0, 0.0, LamassuGait.Mode.HOLD)
	var nose := -rig.part("body").global_basis.z
	assert_gt(nose.y, 0.4, "the body up on end")
	for leg in [BL, BR]:
		assert_lt(absf(rig.contact(leg).y), 0.08, "hind contact %d on the floor" % leg)
	for leg in [FL, FR]:
		assert_gt(rig.contact(leg).y, 0.8, "fore contact %d in the air" % leg)
	while brain.stage == LamassuBrain.Stage.TELEGRAPH:
		_drive(kit, 1.0 / 60.0, 0.0, 0.0, LamassuGait.Mode.HOLD)
	_drive(kit, 1.0 / 60.0, 0.0, 0.0, LamassuGait.Mode.HOLD)
	for leg in [FL, FR]:
		var at := rig.contact(leg)
		assert_lt(at.y, 0.12, "fore contact %d down at the blow" % leg)
		assert_lt(Vector2(at.x - point.x, at.z - point.z).length(), 0.6, "contact %d by the stomp point" % leg)
	var between := (rig.contact(FL) + rig.contact(FR)) * 0.5
	assert_lt(Vector2(between.x - point.x, between.z - point.z).length(), 0.35, "the hooves on the point")


func test_the_gust_raises_the_wings_then_beats_them_forward_with_the_tips_lagging() -> void:
	var kit := _rigged()
	var rig: LamassuRig = kit[1]
	var moves: LamassuMoves = kit[2]
	var brain: LamassuBrain = kit[4]
	var rest_end := rig.wing_end(0)
	moves.guard = Vector3(0.0, 1.5, -6.0)
	brain.force_attack(LamassuBrain.Attack.GUST)
	_drive(kit, LamassuBrain.stage_length(LamassuBrain.Attack.GUST, LamassuBrain.Stage.TELEGRAPH, 1) * 0.92, 0.0, 0.0, LamassuGait.Mode.HOLD)
	var raised := rig.wing_end(0)
	assert_gt(raised.y, rest_end.y + 0.7, "the wing's end high")
	assert_lt(raised.x, rest_end.x - 0.5, "and out")
	assert_gt(rig.wing_end(1).x, -rest_end.x + 0.5, "both wings")
	while brain.stage == LamassuBrain.Stage.TELEGRAPH:
		_drive(kit, 1.0 / 60.0, 0.0, 0.0, LamassuGait.Mode.HOLD)
	_drive(kit, 4.0 / 60.0, 0.0, 0.0, LamassuGait.Mode.HOLD)
	var early_tip: float = moves.pose.wing_tip[0]
	var early_beat: float = moves.pose.wing_beat[0]
	assert_gt(early_beat, 0.3, "the beat under way")
	_drive(kit, 0.25, 0.0, 0.0, LamassuGait.Mode.HOLD)
	var struck := rig.wing_end(0)
	assert_lt(struck.z, raised.z - 0.6, "the wings swept forward")
	assert_gt(moves.pose.wing_tip[0], early_tip + 0.05, "the tips follow a moment late")


func test_stunned_its_face_hangs_low() -> void:
	var kit := _rigged()
	var rig: LamassuRig = kit[1]
	var moves: LamassuMoves = kit[2]
	var brain: LamassuBrain = kit[4]
	moves.guard = Vector3(0.0, 1.5, -12.0)
	var upright := rig.face_point().y
	brain.force_attack(LamassuBrain.Attack.CHARGE)
	while brain.stage == LamassuBrain.Stage.TELEGRAPH:
		_drive(kit, 1.0 / 60.0, 0.0, 0.0, LamassuGait.Mode.HOLD)
	brain.end_charge(true)
	assert_eq(brain.state, LamassuBrain.State.STUNNED)
	_drive(kit, 0.5, 0.0, 0.0, LamassuGait.Mode.STAND)
	assert_lt(rig.face_point().y, 2.4, "the face down within a shot's reach")
	assert_lt(rig.face_point().y, upright - 0.5, "well below its carved height")


func test_pawing_moves_the_right_fore_hoof_and_lowers_the_head() -> void:
	var kit := _rigged()
	var rig: LamassuRig = kit[1]
	var moves: LamassuMoves = kit[2]
	var brain: LamassuBrain = kit[4]
	moves.guard = Vector3(0.0, 1.5, -14.0)
	var face := rig.face_point().y
	brain.force_attack(LamassuBrain.Attack.CHARGE)
	var lowest := [INF]
	var highest := [-INF]
	var pawed := [0]
	var check := func() -> void:
		var hoof := rig.contact(FR)
		lowest[0] = minf(lowest[0], hoof.z)
		highest[0] = maxf(highest[0], hoof.z)
		if moves.pawing:
			pawed[0] += 1
	_drive(kit, LamassuBrain.stage_length(LamassuBrain.Attack.CHARGE, LamassuBrain.Stage.TELEGRAPH, 1) * 0.9, 0.0, 0.0, LamassuGait.Mode.HOLD, check)
	assert_gt(highest[0] - lowest[0], 0.25, "the right fore hoof scrapes back and forth")
	assert_gt(pawed[0], 5, "it touches the floor as it scrapes")
	assert_lt(rig.face_point().y, face - 0.3, "the head down")
	assert_lt(absf(rig.contact(FL).y), 0.08, "the left fore stands")
