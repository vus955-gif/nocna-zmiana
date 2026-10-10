extends TestCase
## The night's goal, part one: the fuses, the fuse box, the power cut, the
## jammed grate and the beating crystal - and what a resumed night keeps.

var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	return museum


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _lights_on(rooms: Array[StringName]) -> Array[bool]:
	var states: Array[bool] = []
	for node in museum.lobby.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MAIN) and rooms.has(node.get_meta(&"room")):
			states.append((node as Light3D).visible)
	return states


## Puts the guard 1 m in front of [param target] looking at it and waits
## for it to come into focus.
func _look_at(target: Node3D, height: float, distance: float = 1.0) -> Interactable:
	var front := -target.global_transform.basis.z
	front.y = 0.0
	front = front.normalized()
	var stand := target.global_position + front * distance
	var query := PhysicsRayQueryParameters3D.create(stand + Vector3.UP, stand + Vector3.DOWN * 4.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	stand.y = (hit["position"] as Vector3).y + 0.05 if not hit.is_empty() else stand.y
	museum.player.global_position = stand
	var aim := target.global_position + Vector3.UP * height - (stand + Vector3.UP * museum.player.eye_height)
	museum.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	for i in 30:
		await physics_frames(1)
		if museum.player.interactor.focus == target:
			break
	return museum.player.interactor.focus


func _take_both_fuses() -> void:
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	await physics_frames(1)


func test_the_fuses_lie_on_their_drawn_points_and_the_goal_says_so() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var objective := museum.objective
	assert_eq(objective.stage, NightObjective.Stage.FUSES)
	assert_eq(objective.fuse_pickups.size(), 2)
	for wing: StringName in museum.night.fuses:
		var marker: Transform3D = museum.lobby.markers[museum.night.fuses[wing]]
		assert_lt((objective.fuse_pickups[wing] as Node3D).global_position.distance_to(marker.origin), 0.01)
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FUSES") % 0)
	assert_eq(museum.hud.fuse_counts(), [0, 0] as Array[int])


func test_the_guard_can_reach_a_fuse_on_its_crate_and_the_fuse_box() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var fuse: FusePickup = museum.objective.fuse_pickups.values()[0]
	assert_eq(await _look_at(fuse, 0.05, 1.0), fuse)
	assert_eq(await _look_at(museum.objective.fuse_box, 0.45, 1.1), museum.objective.fuse_box)


func test_a_fuse_goes_into_the_pocket() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var fuse: FusePickup = museum.objective.fuse_pickups[&"A"]
	fuse.interact(museum.player)
	await physics_frames(1)
	assert_false(is_instance_valid(fuse))
	assert_eq(RunState.fuses_carried, 1)
	assert_true(RunState.is_used(&"fuse_A"))
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FUSES") % 1)
	assert_eq(museum.hud.fuse_counts(), [1, 0] as Array[int])
	assert_eq(museum.hud.toast_text(), (tr("HUD_FUSE_TAKEN") % 1).to_upper())


func test_the_fuse_box_wants_fuses() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var box := museum.objective.fuse_box
	assert_eq(box.prompt(), tr("PROMPT_FUSE_BOX_EMPTY"))
	var refused := watch(box.refused)
	box.interact(museum.player)
	assert_eq(refused.size(), 1)
	assert_eq(museum.hud.toast_text(), tr("HUD_NO_FUSES").to_upper())
	assert_eq(RunState.fuses, 0)


func test_both_fuses_cut_the_power_jam_the_grate_and_wake_the_crystal() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	var cuts := watch(Events.power_cut)
	await _take_both_fuses()
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FUSE_BOX"))
	var box := museum.objective.fuse_box
	assert_eq(box.prompt(), tr("PROMPT_FUSE_BOX"))
	box.interact(museum.player)
	assert_eq(RunState.fuses, 2)
	assert_eq(RunState.fuses_carried, 0)
	assert_eq(cuts.size(), 1)
	await _seconds(1.6)
	for lit in _lights_on([&"hall", &"balcony"] as Array[StringName]):
		assert_false(lit, "the hall goes dark")
	assert_true(_lights_on([&"gallery"] as Array[StringName]).all(func(lit: bool) -> bool: return lit), "only the hall")
	for node in museum.lobby.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.EMERGENCY):
			assert_true((node as Light3D).visible, "the red lamps stay")
	var grate: Door = museum.lobby.doors[&"grate"]
	assert_true(grate.is_jammed)
	assert_false(grate.is_open)
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING)
	assert_eq(museum.objective.crystal.phase, CrystalRelic.Phase.PULSING)
	assert_eq(RunState.crystal_phase, NightState.CrystalPhase.PULSING)
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_PULSE"))
	assert_eq(museum.hud.fuse_counts(), [-1, -1] as Array[int], "the fuse icons go")
	var on_disk := PersistentState.new()
	add_child(on_disk)
	assert_true(on_disk.load_game(), "the power cut is saved")
	assert_true((on_disk.night_progress.get("used", []) as Array).has("fuse_box_2"))


func test_one_fuse_at_a_time_works_too() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var box := museum.objective.fuse_box
	(museum.objective.fuse_pickups[&"A"] as FusePickup).interact(museum.player)
	box.interact(museum.player)
	assert_eq(RunState.fuses, 1)
	assert_eq(museum.hud.toast_text(), (tr("HUD_FUSE_IN") % 1).to_upper())
	assert_eq(museum.hud.fuse_counts(), [0, 1] as Array[int])
	assert_eq(museum.objective.stage, NightObjective.Stage.FUSES)
	(museum.objective.fuse_pickups[&"B"] as FusePickup).interact(museum.player)
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FUSE_BOX"))
	box.interact(museum.player)
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING)
	assert_false(box.enabled, "a full box is done")


func test_the_crystal_beats_after_the_power_cut() -> void:
	GameState.new_game()
	_museum()
	await physics_frames(2)
	var crystal := museum.objective.crystal
	var marker: Transform3D = museum.lobby.markers[museum.night.crystal_case]
	assert_lt(crystal.global_position.distance_to(marker.origin), 0.01, "in the drawn case")
	assert_eq(crystal.phase, CrystalRelic.Phase.DORMANT)
	await _take_both_fuses()
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(1.2)
	var light := crystal.get_child(1) as OmniLight3D
	assert_true(light.visible)
	var energies := {}
	for i in 12:
		await physics_frames(5)
		energies[snappedf(light.light_energy, 0.1)] = true
	assert_gt(energies.size(), 3, "it pulses")


func test_a_resumed_night_keeps_its_fuses_and_its_power_cut() -> void:
	GameState.new_game()
	GameState.save_game()
	_museum()
	await physics_frames(2)
	(museum.objective.fuse_pickups[&"A"] as FusePickup).interact(museum.player)
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	assert_false(museum.objective.fuse_pickups.has(&"A"), "the fuse taken stays taken")
	assert_eq(RunState.fuses_carried, 1, "and is still in the pocket")
	assert_eq(museum.hud.objective_text(), tr("NIGHT_OBJ_FUSES") % 1)
	(museum.objective.fuse_pickups[&"B"] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)
	await _seconds(1.6)
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	_museum()
	await physics_frames(2)
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING, "the power is still out")
	assert_eq(RunState.fuses, 2)
	assert_true((museum.lobby.doors[&"grate"] as Door).is_jammed)
	assert_eq(museum.objective.crystal.phase, CrystalRelic.Phase.PULSING)
	for lit in _lights_on([&"hall"] as Array[StringName]):
		assert_false(lit)
