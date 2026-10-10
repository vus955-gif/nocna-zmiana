extends TestCase
## The Centaur's parts on a bare floor (no museum): the metope he sleeps in
## (cracks, bursts into blocks, a stump stays, whole again when restored),
## his arena's markers in the Parthenon gallery, his rig and moves (hooves
## on the floor at a gallop, the rear, the throw's wind-up and release), his
## javelin (lands on its mark, hurts who stands there, a plinth stops it).

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


# --- the metope ---------------------------------------------------------------------

func test_the_metope_cracks_bursts_into_blocks_and_leaves_a_stump() -> void:
	var metope := CentaurMetope.make(Transform3D.IDENTITY)
	world.add_child(metope)
	await physics_frames(2)
	assert_true(metope.is_in_group(CentaurMetope.GROUP))
	assert_eq(metope.collision_layer, Layers.WORLD)
	var hit := _ray(Vector3(2.0, 2.5, -0.2), Vector3(-3.0, 2.5, -0.2))
	assert_false(hit.is_empty(), "the slab stands at his left")
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).x, CentaurMetope.FACE_X + 0.06, 0.08, "its face toward him")
	assert_almost_eq(metope.cover_height(), CentaurMetope.TOP, 0.01)
	metope.strain(0.8)
	assert_true((metope.find_child("Cracks", false, false) as Node3D).visible, "cracks of light as he strains")
	var bursts := watch(metope.burst_open)
	metope.burst(Vector3(-1.0, 0.0, 0.0))
	assert_eq(bursts.size(), 1)
	assert_true(metope.broken)
	assert_false((metope.find_child("Cracks", false, false) as Node3D).visible)
	var blocks := world.find_children("*", "RigidBody3D", false, false)
	assert_gt(blocks.size(), 8, "heavy blocks fly")
	for body: RigidBody3D in blocks:
		assert_eq(body.collision_layer, Layers.DEBRIS)
	assert_almost_eq(metope.cover_height(), CentaurMetope.ROWS[1], 0.01, "a stump stays")
	await physics_frames(2)
	assert_true(_ray(Vector3(2.0, 2.5, -0.2), Vector3(-3.0, 2.5, -0.2)).is_empty(), "nothing up there now")
	assert_false(_ray(Vector3(2.0, 0.6, -0.2), Vector3(-3.0, 0.6, -0.2)).is_empty(), "the stump stops a charge")
	metope.restore()
	assert_false(metope.broken)
	assert_almost_eq(metope.cover_height(), CentaurMetope.TOP, 0.01, "whole again")
	var fallen := CentaurMetope.make(Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)), true)
	world.add_child(fallen)
	assert_almost_eq(fallen.cover_height(), CentaurMetope.ROWS[1], 0.01, "after his fall: the empty stump")


func test_his_arena_markers_lie_in_the_parthenon_gallery() -> void:
	var layout := Floor1Layout.create()
	var post: Transform3D = layout.markers[&"guardian_centaur"]
	assert_eq(layout.marker_rooms[&"guardian_centaur"], &"greece_parthenon")
	var facing := -post.basis.z
	assert_lt(absf(facing.x), 0.05, "side on to the arena's mouth (west)")
	var left := -post.basis.x
	assert_gt(left.x, 0.9, "his metope at his left, east of him: seen from the mouth")
	for id: StringName in [&"arena_centaur_reward", &"centaur_lapith_1", &"centaur_lapith_2", &"centaur_lapith_3", &"centaur_lapith_4"]:
		assert_true(layout.markers.has(id), str(id))
		assert_eq(layout.marker_rooms.get(id, &""), &"greece_parthenon", str(id))
	var ends := {}
	for i in 4:
		var at: Vector3 = (layout.markers[StringName("centaur_lapith_%d" % (i + 1))] as Transform3D).origin
		ends[at.x < post.origin.x] = true
	assert_eq(ends.size(), 2, "Lapiths at both pediment ends")


# --- the rig and its moves ----------------------------------------------------------

## A rig in the world with its moves, gait and an awake brain: [holder,
## rig, moves, gait, brain].
func _rigged() -> Array:
	var holder := Node3D.new()
	holder.name = "Body"
	world.add_child(holder)
	var rig := CentaurRig.create(holder)
	var moves := CentaurMoves.new(rig)
	var gait := CentaurGait.new()
	var brain := CentaurBrain.new()
	brain.seed_with(2)
	gait.place(holder.global_transform)
	brain.wake()
	var kit := [holder, rig, moves, gait, brain]
	_drive(kit, CentaurBrain.WAKE_TIME + 0.05, 0.0, 0.0)
	return kit


## Drives [param kit] for [param seconds]: the body runs at [param speed]
## along its facing turning [param turn] rad/s; calls [param each] (Callable)
## every frame when given.
func _drive(kit: Array, seconds: float, speed: float, turn: float, each: Callable = Callable()) -> void:
	var holder: Node3D = kit[0]
	var rig: CentaurRig = kit[1]
	var moves: CentaurMoves = kit[2]
	var gait: CentaurGait = kit[3]
	var brain: CentaurBrain = kit[4]
	var step := 1.0 / 60.0
	for i in roundi(seconds / step):
		var turned := Basis(Vector3.UP, turn * step) * holder.global_basis
		var velocity := turned * Vector3.FORWARD * speed
		holder.global_transform = Transform3D(turned, holder.global_position + velocity * step)
		var flat := Vector2(moves.guard.x, moves.guard.z)
		brain.update(step, flat.length(), atan2(-moves.guard.x, -moves.guard.z))
		gait.update(step, holder.global_transform, velocity)
		rig.apply(moves.compose(brain, gait, holder.global_transform, step), step)
		if each.is_valid():
			each.call()


func test_at_rest_it_is_the_carved_piece_and_the_greybox_has_its_parts() -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	var rig := CentaurRig.create(holder)
	for part_name in CentaurRig.PART_NAMES:
		assert_not_null(rig.part(part_name), part_name)
	assert_not_null(rig.part("chest"), "the weak point's marker")
	assert_not_null(rig.left_javelin, "a second javelin for phase 3")
	var head := rig.part("head").global_position
	assert_gt(head.y, 2.5, "a tall figure")
	var grey := CentaurRig._make_greybox()
	var names := {}
	for node in grey.find_children("*", "Node3D", true, false):
		names[String(node.name)] = true
	for part_name in CentaurRig.PART_NAMES:
		assert_true(names.has(part_name), "greybox %s" % part_name)
	grey.free()


func test_galloping_and_turning_its_standing_hooves_are_on_the_floor_and_the_legs_bend_right() -> void:
	var kit := _rigged()
	var rig: CentaurRig = kit[1]
	var gait: CentaurGait = kit[3]
	var off := [0.0]
	var knees := [0, 0]
	var check := func() -> void:
		for leg in 4:
			if gait.standing(leg):
				var hoof := rig.part("hoof_" + CentaurRig.LEGS[leg]).global_position
				off[0] = maxf(off[0], absf(hoof.y - CentaurGait.HOOF_HEIGHT))
		# a fore knee in front of the line from the elbow to the fetlock, a hock behind it
		var forward := -(kit[0] as Node3D).global_basis.z
		for leg in [0, 2]:
			var root := rig.part("leg_" + CentaurRig.LEGS[leg]).global_position
			var knee := rig.part("knee_" + CentaurRig.LEGS[leg]).global_position
			var fetlock := rig.part("hoof_" + CentaurRig.LEGS[leg]).global_position
			var line := (fetlock - root).normalized()
			var side := (knee - root) - line * (knee - root).dot(line)
			if side.length() > 0.02:
				knees[0 if leg == 0 else 1] += 1 if side.dot(forward) * (1.0 if leg == 0 else -1.0) > 0.0 else -1
	# (the guard far behind it: it runs, it picks no attack)
	(kit[2] as CentaurMoves).guard = Vector3(0.0, 1.5, 45.0)
	for i in 60:
		_drive(kit, 1.0 / 60.0, 10.0 * i / 60.0, 0.0, check)
	_drive(kit, 2.0, 10.0, 0.0, check)
	_drive(kit, 2.0, 9.0, 1.1, check)
	assert_lt(off[0], 0.08, "standing hooves on the floor (worst %.3f m off)" % off[0])
	assert_gt(knees[0], 0, "the fore knee bends forward")
	assert_gt(knees[1], 0, "the hock bends back")


func test_turning_left_at_a_gallop_it_banks_left() -> void:
	var kit := _rigged()
	var rig: CentaurRig = kit[1]
	(kit[2] as CentaurMoves).guard = Vector3(0.0, 1.5, 45.0)
	_drive(kit, 1.5, 9.5, 0.0)
	_drive(kit, 1.5, 9.5, 1.2)
	var barrel := rig.part("barrel")
	var right := barrel.global_basis.x
	assert_gt(right.y, 0.08, "its right side up, its left down: into the turn")


func test_rearing_it_stands_on_its_hind_hooves_and_strikes_its_mark() -> void:
	var kit := _rigged()
	var rig: CentaurRig = kit[1]
	var moves: CentaurMoves = kit[2]
	var brain: CentaurBrain = kit[4]
	moves.guard = Vector3(0.0, 1.5, -3.0)
	brain.force_attack(CentaurBrain.Attack.KICK)
	var top := [0.0, 0.0, 0.0]
	_drive(kit, CentaurBrain.stage_length(CentaurBrain.Attack.KICK, CentaurBrain.Stage.TELEGRAPH, 1) * 0.66, 0.0, 0.0)
	var nose := -rig.part("barrel").global_basis.z
	assert_gt(nose.y, 0.5, "the barrel up on end")
	for leg in [2, 3]:
		assert_lt(absf(rig.part("hoof_" + CentaurRig.LEGS[leg]).global_position.y - CentaurGait.HOOF_HEIGHT), 0.08, "hind hooves on the floor")
	for leg in [0, 1]:
		assert_gt(rig.part("hoof_" + CentaurRig.LEGS[leg]).global_position.y, 1.0, "fore hooves in the air")
	while brain.stage == CentaurBrain.Stage.TELEGRAPH:
		_drive(kit, 1.0 / 60.0, 0.0, 0.0)
	for leg in [0, 1]:
		var hoof := rig.part("hoof_" + CentaurRig.LEGS[leg]).global_position
		assert_lt(hoof.y, CentaurGait.HOOF_HEIGHT + 0.12, "down on the floor at the blow")
		assert_lt(absf(-hoof.z - CentaurBrain.KICK_REACH), 0.35, "on the mark in front")
	top[0] = 1.0


func test_the_throw_draws_back_then_releases_forward() -> void:
	var kit := _rigged()
	var rig: CentaurRig = kit[1]
	var moves: CentaurMoves = kit[2]
	var brain: CentaurBrain = kit[4]
	moves.guard = Vector3(-6.0, 1.5, -9.0)
	var target := Vector3(-6.0, 0.0, -9.0)
	moves.throw_dir[1] = CentaurJavelin.launch_velocity(Vector3(0.4, 2.6, -0.8), target, 0.9, CentaurJavelin.GRAVITY).normalized()
	brain.force_attack(CentaurBrain.Attack.THROW)
	_drive(kit, CentaurBrain.stage_length(CentaurBrain.Attack.THROW, CentaurBrain.Stage.TELEGRAPH, 1) * 0.9, 0.0, 0.0)
	var shoulder := rig.part("arm_r").global_position
	var hand := rig.part("wrist_r").global_position
	var toward := Vector3(target.x, 0.0, target.z).normalized()
	assert_lt((hand - shoulder).dot(toward), -0.1, "drawn back behind the shoulder")
	var tip_line := -rig.part("javelin").global_basis.z
	assert_gt(tip_line.dot(toward), 0.4, "the javelin points the way it will fly")
	assert_gt(tip_line.y, 0.2, "and up its arc")
	while brain.stage == CentaurBrain.Stage.TELEGRAPH:
		_drive(kit, 1.0 / 60.0, 0.0, 0.0)
	_drive(kit, 2.0 / 60.0, 0.0, 0.0)
	hand = rig.part("wrist_r").global_position
	assert_gt((hand - rig.part("arm_r").global_position).dot(toward), 0.15, "released in front")
	assert_false(rig.part("javelin").visible, "it has left the hand")


# --- the javelin --------------------------------------------------------------------

func test_a_javelins_arc_brings_its_tip_onto_the_target_in_its_time() -> void:
	var from := Vector3(0.4, 2.6, -0.8)
	for to: Vector3 in [Vector3(-6.0, 0.0, -9.0), Vector3(3.0, 0.0, -18.0), Vector3(0.0, 0.0, -5.0)]:
		var time := CentaurJavelin.flight_time(Vector2(to.x - from.x, to.z - from.z).length())
		assert_true(time >= CentaurBrain.JAVELIN_FLIGHT.x and time <= CentaurBrain.JAVELIN_FLIGHT.y)
		var v := CentaurJavelin.launch_velocity(from, to, time, CentaurJavelin.GRAVITY)
		var end := from + v * time + Vector3.DOWN * 0.5 * CentaurJavelin.GRAVITY * time * time
		assert_lt(end.distance_to(to), 0.001, "on target %s" % str(to))
		assert_gt(v.y, 0.0, "thrown up its arc")


func test_a_javelin_sticks_on_its_mark_and_a_plinth_stops_one() -> void:
	var landed: Array[Vector3] = []
	var javelin := CentaurJavelin.make(Vector3(0.0, 2.6, -1.0), Vector3(0.0, 0.0, -10.0), 0.9, 20.0)
	javelin.landed.connect(func(at: Vector3) -> void: landed.append(at))
	world.add_child(javelin)
	await physics_frames(70)
	assert_eq(landed.size(), 1)
	if landed.size() == 1:
		assert_lt(Vector2(landed[0].x, landed[0].z + 10.0).length(), 0.3, "on its mark")
	assert_true(javelin.stuck, "it sticks in the floor")
	# a plinth half way
	var plinth := StaticBody3D.new()
	plinth.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.4, 1.6)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	plinth.add_child(collider)
	world.add_child(plinth)
	plinth.global_position = Vector3(8.0, 0.7, -8.5)
	await physics_frames(2)
	var stopped: Array[Vector3] = []
	var other := CentaurJavelin.make(Vector3(8.0, 2.6, -1.0), Vector3(8.0, 0.0, -10.0), 0.9, 20.0)
	other.landed.connect(func(at: Vector3) -> void: stopped.append(at))
	world.add_child(other)
	await physics_frames(70)
	assert_eq(stopped.size(), 1)
	if stopped.size() == 1:
		assert_gt(stopped[0].z, -9.4, "the plinth took it, short of the mark")
