extends TestCase
## Ambush mummies in their tombs (design pietro-1-projekt 5.1, 7.2): the
## coffin's and the sarcophagus's lids, sleeping inside, climbing out when
## the ambush wakes them, and which spawn slots get a tomb on Floor I.

var mummy: Mummy


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _entombed(at: Vector3, yaw: float, target: Node3D) -> Mummy:
	mummy = Mummy.new()
	mummy.entombed = true
	mummy.position = at
	mummy.rotation.y = yaw
	mummy.target = target
	add_child(mummy)
	return mummy


func _dummy(at: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


func _tomb(style: MummyMoves.Tomb, at: Vector3, yaw: float = 0.0) -> MummyTomb:
	var tomb := MummyTomb.build(style, Transform3D(Basis(Vector3.UP, yaw), at))
	add_child(tomb)
	return tomb


func test_a_coffin_has_its_lid_and_spawn_marker() -> void:
	var tomb := _tomb(MummyMoves.Tomb.COFFIN, Vector3.ZERO)
	assert_not_null(tomb.lid)
	assert_almost_eq(tomb.spawn_point().origin.y, 1.07, 0.05)
	assert_true(tomb.is_in_group(MummyTomb.GROUP))


func test_the_coffin_lid_falls_flat() -> void:
	var tomb := _tomb(MummyMoves.Tomb.COFFIN, Vector3.ZERO)
	tomb.open()
	await physics_frames(60)
	var lid_up := (tomb.global_transform.basis * tomb.lid.transform.basis).y.normalized()
	assert_lt(absf(lid_up.y), 0.2, "the lid lies on the floor")
	assert_lt(lid_up.z, 0.0, "fallen forward")


func test_the_sarcophagus_lid_slides_off() -> void:
	var tomb := _tomb(MummyMoves.Tomb.SARCOPHAGUS, Vector3.ZERO)
	var rest := tomb.lid.global_position
	tomb.open()
	await physics_frames(60)
	assert_gt(tomb.lid.global_position.distance_to(rest), 0.8)


func test_free_near_finds_a_free_tomb_only() -> void:
	var tomb := _tomb(MummyMoves.Tomb.SARCOPHAGUS, Vector3(1.5, 0, 0))
	assert_eq(MummyTomb.free_near(self, Vector3.ZERO, 2.5), tomb)
	assert_null_or(MummyTomb.free_near(self, Vector3(10, 0, 0), 2.5))
	var holder := Node3D.new()
	add_child(holder)
	tomb.occupant = holder
	assert_null_or(MummyTomb.free_near(self, Vector3.ZERO, 2.5))


func assert_null_or(value: Variant) -> void:
	assert_true(value == null, "no tomb")


func test_it_sleeps_inside_its_coffin_blind_to_a_guard_in_front() -> void:
	var dummy := _dummy(Vector3(0, 0, -6))
	_entombed(Vector3.ZERO, 0.0, dummy)
	await physics_frames(180)
	assert_not_null(mummy.tomb, "it stood up its own coffin")
	assert_eq(mummy.tomb.style, MummyMoves.Tomb.COFFIN)
	var local := mummy.tomb.global_transform.affine_inverse() * mummy.global_position
	assert_lt(absf(local.x), MummyTomb.COFFIN_SIZE.x * 0.5)
	assert_lt(absf(local.z), MummyTomb.COFFIN_SIZE.z * 0.5, "inside it")
	assert_eq(mummy.brain.state, EnemyBrain.State.DORMANT, "the lid hides him")


func test_woken_it_climbs_out_of_its_coffin_and_hunts() -> void:
	var dummy := _dummy(Vector3(0, 0, -2.2))
	_entombed(Vector3.ZERO, 0.0, dummy)
	await physics_frames(5)
	mummy.brain.wake()
	await physics_frames(1)
	assert_true(mummy.rising())
	assert_true(mummy.tomb.is_open())
	var hit_while_rising := false
	var frames := 0
	while mummy.rising() and frames < 120:
		await get_tree().physics_frame
		frames += 1
		if not dummy.hits.is_empty():
			hit_while_rising = true
	assert_almost_eq(frames / 60.0, MummyMoves.rise_length(MummyMoves.Tomb.COFFIN), 0.05, "1.4 s to climb out")
	assert_false(hit_while_rising, "no blows while it climbs out")
	assert_false(mummy.rising(), "out after 1.4 s")
	var ahead := -(mummy.tomb.global_transform.affine_inverse() * mummy.global_position).z
	assert_gt(ahead, 0.6, "it stands in front of its coffin")
	assert_true(mummy.brain.is_hunting(), "and hunts")


func test_it_lies_in_a_sarcophagus_by_its_post_and_climbs_out_over_the_side() -> void:
	var tomb := _tomb(MummyMoves.Tomb.SARCOPHAGUS, Vector3(1.0, 0, 0))
	var dummy := _dummy(Vector3(1.0, 0, -6))
	_entombed(Vector3.ZERO, 0.0, dummy)
	await physics_frames(20)
	assert_eq(mummy.tomb, tomb, "the sarcophagus by its post")
	var model_up := mummy.rig.model.global_transform.basis.y.normalized()
	assert_lt(absf(model_up.y), 0.3, "it lies on its back")
	mummy.brain.wake()
	var frames := 0
	while (mummy.rising() or frames == 0) and frames < 160:
		await get_tree().physics_frame
		frames += 1
	assert_almost_eq(frames / 60.0, MummyMoves.rise_length(MummyMoves.Tomb.SARCOPHAGUS), 0.05, "1.9 s to climb out")
	assert_lt(mummy.global_position.distance_to(tomb.exit_point()), 0.25, "beside the sarcophagus")
	model_up = mummy.rig.model.global_transform.basis.y.normalized()
	assert_gt(model_up.y, 0.95, "standing")


func test_floor_ambush_slots_put_their_mummies_in_tombs() -> void:
	var layout := LevelLayout.new()
	var kinds: Array[StringName] = [&"wax", &"mummy"]
	layout.add_spawn(Vector3.ZERO, &"room", SpawnSlot.ALWAYS_SET, kinds)
	layout.add_spawn(Vector3(4, 0, 0), &"room", 0, kinds)
	var woken: Array[int] = [0]
	layout.add_ambush(AmbushSpec.on_area(&"tombs", &"room", Rect2(-1, -1, 2, 2), -1.0, 3.0, woken))
	var ambusher := Mummy.new()
	ambusher.set_meta(NightSpawner.SLOT_META, 0)
	var sleeper := Mummy.new()
	sleeper.set_meta(NightSpawner.SLOT_META, 1)
	FloorEncounters.tune_from_layout(ambusher, layout)
	FloorEncounters.tune_from_layout(sleeper, layout)
	assert_true(ambusher.entombed)
	assert_false(sleeper.entombed, "it sleeps as an exhibit")
	ambusher.free()
	sleeper.free()


func test_a_mummy_slot_now_spawns_a_mummy() -> void:
	var kinds: Array[StringName] = [&"wax", &"mummy"]
	assert_eq(NightSpawner.preferred(kinds, &"wax"), &"mummy")
	var swarm: Array[StringName] = [&"wolf", &"scarabs"]
	assert_eq(NightSpawner.preferred(swarm, &"wolf"), &"scarabs", "the swarm replaces its stand-in")
	var future: Array[StringName] = [&"wolf", &"jaguar"]
	assert_eq(NightSpawner.preferred(future, &"jaguar"), &"wolf", "a kind still to come keeps its stand-in")
	var plain: Array[StringName] = [&"wax"]
	assert_eq(NightSpawner.preferred(plain, &"wax"), &"wax")
