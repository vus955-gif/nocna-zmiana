extends TestCase
## The Colossus's parts on a bare floor (no museum): the breakable papyrus
## columns, the sun beam (stopped by the first wall, burning a body it
## passes), the shockwave rings (jump them), the throne's collision and
## openings, the telegraph marks on the floor.

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 1.0, 80.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)


func after_each() -> void:
	world.free()


func _debris() -> Array[Node]:
	return Fx.find_children("*", "RigidBody3D", false, false)


func test_a_column_counts_one_hit_per_beam_and_breaks_on_the_third() -> void:
	var column := ColossusColumn.make(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -6.0)))
	world.add_child(column)
	assert_eq(column.stage, ColossusColumn.Stage.INTACT)
	assert_almost_eq(column.cover_height(), ColossusColumn.HEIGHT, 0.01, "floor to ceiling")
	assert_true(column.is_in_group(ColossusColumn.GROUP))
	var at := Vector3(0.0, 2.0, -5.0)
	assert_true(column.beam_hit(1, at))
	assert_false(column.beam_hit(1, at), "one beam counts once however long it burns")
	assert_eq(column.stage, ColossusColumn.Stage.CHIPPED)
	assert_eq(column.look_set(), "", "still the clean stone")
	assert_true(column.beam_hit(2, at))
	assert_eq(column.stage, ColossusColumn.Stage.CRACKED)
	assert_eq(column.look_set(), ColossusColumn.CRACKED_SET, "the cracked texture set")
	var before := _debris().size()
	assert_true(column.beam_hit(3, at))
	assert_eq(column.stage, ColossusColumn.Stage.BROKEN)
	assert_almost_eq(column.cover_height(), ColossusColumn.STUMP_HEIGHT, 0.01, "a stump stays")
	assert_gt(_debris().size(), before + 2, "the shaft falls as physical drums")
	for body: RigidBody3D in _debris():
		assert_eq(body.collision_layer, Layers.DEBRIS)
	assert_false(column.beam_hit(4, at), "nothing more to break")
	assert_eq(column.hits, 3)


func test_the_beam_stops_at_the_first_wall_and_names_it() -> void:
	var column := ColossusColumn.make(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -6.0)))
	world.add_child(column)
	var beam := SunBeam.new()
	world.add_child(beam)
	await physics_frames(2)
	var hit := beam.fire(Vector3(0.0, 6.0, 0.0), Vector3(0.0, 1.0, -12.0), 1.0 / 60.0)
	assert_eq(hit["collider"], column, "the column takes it")
	var end: Vector3 = hit["end"]
	assert_true(end.z > -6.0 and end.z < -4.5, "ends on the column's face: %s" % str(end))
	assert_true(beam.is_burning())
	var open := beam.fire(Vector3(0.0, 6.0, 0.0), Vector3(8.0, 1.0, 0.0), 1.0 / 60.0)
	assert_true(open["collider"] is StaticBody3D and open["collider"] != column, "the floor further on")
	assert_lt((open["end"] as Vector3).y, 0.05)
	beam.hide_beam()
	assert_false(beam.is_burning())


func test_the_beam_burns_a_body_it_passes_and_not_one_beside_it() -> void:
	var eyes := Vector3(0.0, 7.0, 0.0)
	var feet := Vector3(0.0, 0.0, -10.0)
	assert_true(SunBeam.segment_hits_capsule(eyes, Vector3(0.0, 0.0, -12.0), feet, 1.8), "through his chest")
	assert_false(SunBeam.segment_hits_capsule(eyes, Vector3(0.0, 4.0, -14.0), feet, 1.8), "over his head")
	assert_false(SunBeam.segment_hits_capsule(eyes, Vector3(1.4, 0.0, -12.0), feet, 1.8), "a step beside him")
	assert_false(SunBeam.segment_hits_capsule(eyes, Vector3(0.0, 3.0, -6.0), feet, 1.8), "stopped short of him")
	assert_almost_eq(SunBeam.segment_distance(Vector3.ZERO, Vector3(10, 0, 0), Vector3(5, 1, -1), Vector3(5, 1, 1)), 1.0, 0.001)


func test_a_ring_hurts_a_standing_guard_once_and_a_jumping_one_never() -> void:
	var standing := TargetDummy.new()
	var jumping := TargetDummy.new()
	var far := TargetDummy.new()
	for dummy in [standing, jumping, far]:
		world.add_child(dummy)
	standing.global_position = Vector3(4.0, 0.0, 0.0)
	jumping.global_position = Vector3(0.0, 0.7, 4.0)
	far.global_position = Vector3(-9.0, 0.0, 0.0)
	var rings: Array[ShockwaveRing] = []
	for dummy: TargetDummy in [standing, jumping, far]:
		var ring := ShockwaveRing.make(Vector3.ZERO, 7.0, 10.0, 10.0, null, 1.0)
		ring.target = dummy
		world.add_child(ring)
		rings.append(ring)
	await physics_frames(80)
	assert_eq(standing.hits.size(), 1, "once")
	if standing.hits.size() == 1:
		assert_almost_eq(standing.hits[0].amount, 10.0)
		assert_gt(standing.hits[0].direction.x, 0.9, "pushed outward")
	assert_eq(jumping.hits.size(), 0, "jumped over it")
	assert_eq(far.hits.size(), 0, "out of its reach")
	for ring in rings:
		assert_false(is_instance_valid(ring), "gone at its reach")
	assert_true(ShockwaveRing.crosses(3.0, 3.2, 3.1))
	assert_false(ShockwaveRing.crosses(3.0, 3.2, 5.0))


func test_the_throne_has_a_plinth_a_seat_and_two_openings() -> void:
	var throne := ColossusThrone.make(Transform3D(Basis(Vector3.UP, PI), Vector3(2.0, 0.0, 3.0)))
	world.add_child(throne)
	assert_true(throne.is_in_group(ColossusThrone.GROUP))
	await physics_frames(2)
	var space := world.get_world_3d().direct_space_state
	var plinth := throne.to_global(Vector3(0.0, 0.0, -3.5))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(plinth + Vector3.UP * 5.0, plinth, Layers.WORLD))
	assert_false(hit.is_empty())
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).y, 0.6, 0.05, "the plinth under his feet")
	var seat := throne.to_global(Vector3(0.0, 0.0, -0.5))
	hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(seat + Vector3.UP * 4.5, seat, Layers.WORLD))
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).y, 2.96, 0.1, "the seat")
	assert_eq(throne.body.collision_layer, Layers.WORLD)
	var left := throne.opening(1)
	var right := throne.opening(-1)
	assert_gt(left.distance_to(right), 3.5, "one on each side")
	assert_lt(throne.to_local(left).x, -1.6, "his left is his -X")
	throne.vent(1, 1.0)
	throne.crack()


func test_a_ground_mark_darkens_as_the_blow_comes() -> void:
	var mark := GroundMark.disc(2.4, 1.4)
	world.add_child(mark)
	mark.progress = 0.1
	var early := mark.shadow_alpha()
	mark.progress = 1.0
	assert_gt(mark.shadow_alpha(), early + 0.2, "darker as it comes")
	var band := GroundMark.arc(3.8, 8.0, 1.66, -1.22)
	world.add_child(band)
	var box := (band.get_child(0) as MeshInstance3D).get_aabb()
	assert_gt(box.size.x, 10.0, "the band spans the sweep")
	assert_lt(box.position.z, -7.0, "in front (-Z)")


# --- the rig and its moves --------------------------------------------------------

## A rig in the world, its moves and a brain driving them.
func _rigged() -> Array:
	var holder := Node3D.new()
	holder.name = "Body"
	world.add_child(holder)
	var rig := ColossusRig.create(holder)
	var moves := ColossusMoves.new(rig)
	var brain := ColossusBrain.new()
	brain.seed_with(3)
	return [holder, rig, moves, brain]


## Steps brain, moves and rig together for [param seconds].
func _play(brain: ColossusBrain, moves: ColossusMoves, rig: ColossusRig, seconds: float, distance: float = 8.0) -> void:
	for i in roundi(seconds * 60.0):
		brain.update(1.0 / 60.0, distance, 0.0)
		rig.apply(moves.compose(brain, 1.0 / 60.0), 1.0 / 60.0)


func test_asleep_the_rig_is_the_museum_piece() -> void:
	var got := _rigged()
	var rig: ColossusRig = got[1]
	rig.apply((got[2] as ColossusMoves).compose(got[3], 1.0 / 60.0))
	for name: String in ColossusRig.PART_NAMES:
		var node := rig.part(name)
		assert_not_null(node, name)
		if node != null:
			assert_lt(node.transform.origin.distance_to((rig.rest[name] as Transform3D).origin), 0.001, name)
			assert_lt(node.transform.basis.get_euler().length(), 0.001, name)
	for marker in ["eye_l", "eye_r", "hand_l", "hand_r"]:
		assert_not_null(rig.part(marker), marker)


func test_a_slam_brings_the_palm_down_on_its_shadow_even_far_off() -> void:
	for target: Vector3 in [Vector3(0.0, 0.0, -5.5), Vector3(1.5, 0.0, -9.0), Vector3(-2.0, 0.0, -12.5), Vector3(-9.0, 0.0, -5.0)]:
		var got := _rigged()
		var rig: ColossusRig = got[1]
		var moves: ColossusMoves = got[2]
		var brain: ColossusBrain = got[3]
		brain.wake()
		_play(brain, moves, rig, ColossusBrain.WAKE_TIME + 0.05)
		var bearing := atan2(-target.x, -target.z)
		moves.slam_point = target
		moves.side = ColossusBrain.arm_for(bearing)
		brain.force_attack(ColossusBrain.Attack.SLAM)
		var arm := "hand_l" if moves.side > 0 else "hand_r"
		var rest_height := rig.part(arm).global_position.y
		var telegraph := ColossusBrain.stage_length(ColossusBrain.Attack.SLAM, ColossusBrain.Stage.TELEGRAPH, 1)
		_play(brain, moves, rig, telegraph * 0.62)
		assert_gt(rig.part(arm).global_position.y, rest_height + 1.5, "raised high before the blow (%s)" % str(target))
		while brain.stage == ColossusBrain.Stage.TELEGRAPH:
			_play(brain, moves, rig, 1.0 / 60.0)
		var hand := rig.part(arm).global_position
		assert_lt(Vector2(hand.x - target.x, hand.z - target.z).length(), 0.45, "on the shadow (%s): %s" % [str(target), str(hand)])
		assert_lt(hand.y, 0.5, "on the floor")
		var widest := 0.0
		for gap: float in rig.gaps[0 if moves.side > 0 else 1]:
			widest = maxf(widest, gap)
		if target.length() > 8.0:
			assert_gt(widest, 0.5, "the joints part to reach that far")
		(got[0] as Node3D).free()


func test_the_low_sweep_passes_along_the_floor_in_front() -> void:
	var got := _rigged()
	var rig: ColossusRig = got[1]
	var moves: ColossusMoves = got[2]
	var brain: ColossusBrain = got[3]
	brain.wake()
	_play(brain, moves, rig, ColossusBrain.WAKE_TIME + 0.05)
	moves.side = -1
	brain.force_attack(ColossusBrain.Attack.SWEEP)
	_play(brain, moves, rig, ColossusBrain.stage_length(ColossusBrain.Attack.SWEEP, ColossusBrain.Stage.TELEGRAPH, 1) + 0.3)
	assert_true(moves.sweep_low, "down on the floor mid-sweep")
	var hand := rig.part("hand_r").global_position
	assert_lt(hand.y, 0.8, "low: jump it")
	var radius := Vector2(hand.x, hand.z).length()
	assert_true(radius > 6.0 and radius < 8.6, "out in the band: %.2f" % radius)
	assert_gt(rig.part("forearm_r").global_position.distance_to(Vector3.ZERO), 3.0)


func test_standing_up_it_towers_over_its_planted_feet() -> void:
	var got := _rigged()
	var rig: ColossusRig = got[1]
	var moves: ColossusMoves = got[2]
	var brain: ColossusBrain = got[3]
	brain.wake()
	_play(brain, moves, rig, ColossusBrain.WAKE_TIME + 0.05)
	brain.set_phase(3)
	_play(brain, moves, rig, ColossusBrain.PHASE_SHIFT_TIME + 0.05)
	assert_eq(brain.state, ColossusBrain.State.STAND_UP)
	var seat_foot := rig.part("foot_l").global_position
	_play(brain, moves, rig, 1.5)
	assert_lt(rig.part("foot_l").global_position.distance_to(seat_foot), 0.05, "the feet stay on the plinth while it pushes up")
	while brain.state == ColossusBrain.State.STAND_UP and brain.state_time() < ColossusBrain.STAND_UP_TIME - 0.03:
		_play(brain, moves, rig, 1.0 / 60.0)
	assert_eq(brain.state, ColossusBrain.State.STAND_UP, "the last moment of the rise")
	var pelvis := rig.part("pelvis").global_position
	assert_almost_eq(pelvis.y, ColossusMoves.STAND_HIPS, 0.06, "hips at a standing height")
	assert_almost_eq(pelvis.z, ColossusMoves.STAND_PELVIS.z, 0.06, "a stride in front of the throne")
	for i in 2:
		var ankle := rig.part("foot_" + ("l" if i == 0 else "r")).global_position
		assert_lt(ankle.distance_to(ColossusMoves.STAND_FEET[i]), 0.1, "foot %d on the floor: %s" % [i, str(ankle)])
	var crown := rig.part("head").global_position.y + 2.88
	assert_gt(crown, 10.0, "about 10.7 m tall")
	(got[0] as Node3D).free()


func test_its_chest_plates_break_off_and_come_back() -> void:
	var got := _rigged()
	var rig: ColossusRig = got[1]
	rig.apply((got[2] as ColossusMoves).compose(got[3], 1.0 / 60.0))
	var before := _debris().size()
	assert_true(rig.detach_plate(2, Vector3(0.0, 1.0, -2.0)))
	assert_false(rig.detach_plate(2, Vector3.ZERO), "only once")
	assert_false(rig.part("chest_plate_2").visible)
	assert_eq(_debris().size(), before + 1, "it falls as a stone")
	rig.restore_plates()
	assert_true(rig.part("chest_plate_2").visible)
	assert_eq(rig.plates_on, [true, true, true] as Array[bool])
