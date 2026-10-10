extends TestCase
## Footsteps: cadence, surfaces, landings, voices and the Foley autoload
## attaching them to walkers.


func after_each() -> void:
	Foley.enabled = false


func _walker(profile: StringName = &"guard") -> Footsteps:
	var body := CharacterBody3D.new()
	add_child(body)
	return Footsteps.attach(body, profile)


func _floor(meta: Variant = null, group: StringName = &"", material_name: String = "") -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	if meta != null:
		floor_body.set_meta(&"surface", meta)
	if group != &"":
		floor_body.add_to_group(group)
	if material_name != "":
		var material := PhysicsMaterial.new()
		material.resource_name = material_name
		floor_body.physics_material_override = material
	add_child(floor_body)
	return floor_body


func _walk(steps: Footsteps, seconds: float, speed: float, dt: float = 1.0 / 60.0) -> int:
	var count := 0
	var t := 0.0
	while t < seconds:
		if steps.advance(dt, speed, true):
			count += 1
		t += dt
	return count


func test_walking_cadence_follows_the_stride() -> void:
	var steps := _walker()
	var walk := _walk(steps, 10.0, 5.5)
	assert_almost_eq(float(walk), 10.0 * steps.cadence(5.5), 1.5, "about 2.3 steps a second")
	assert_true(walk >= 20 and walk <= 26, "%d steps in 10 s of walking" % walk)


func test_running_steps_are_faster_and_longer() -> void:
	var steps := _walker()
	assert_gt(steps.stride_for(8.5), steps.stride_for(5.5), "longer strides")
	assert_gt(steps.cadence(8.5), steps.cadence(5.5), "quicker steps")
	var run := _walk(steps, 10.0, 8.5)
	steps._moving = false
	var walk := _walk(steps, 10.0, 5.5)
	assert_gt(float(run), float(walk))


func test_no_steps_when_standing_or_airborne() -> void:
	var steps := _walker()
	assert_eq(_walk(steps, 3.0, 0.5), 0, "too slow")
	var airborne := 0
	for i in 180:
		if steps.advance(1.0 / 60.0, 6.0, false):
			airborne += 1
	assert_eq(airborne, 0, "in the air")


func test_the_first_step_comes_soon_after_setting_off() -> void:
	var steps := _walker()
	var first := -1.0
	var t := 0.0
	while t < 2.0 and first < 0.0:
		if steps.advance(1.0 / 60.0, 5.5, true):
			first = t
		t += 1.0 / 60.0
	assert_true(first >= 0.0 and first < 0.3, "first step after %.2f s" % first)


func test_exhibits_have_their_own_pace() -> void:
	var knight := _walker(&"knight")
	var wolf := _walker(&"wolf")
	assert_true(knight.cadence(2.0) > 1.2 and knight.cadence(2.0) < 2.5, "knight %.2f steps/s" % knight.cadence(2.0))
	assert_true(wolf.cadence(6.5) > 3.0 and wolf.cadence(6.5) < 5.0, "wolf %.2f steps/s" % wolf.cadence(6.5))
	var raptor := _walker(&"raptor")
	assert_true(raptor.cadence(7.5) > 2.8 and raptor.cadence(7.5) < 4.5, "raptor %.2f steps/s" % raptor.cadence(7.5))


func test_surface_tags_on_the_floor_choose_the_sound() -> void:
	var cases := [[_floor.bind(&"wood"), &"wood"], [_floor.bind(&"parquet"), &"wood"],
		[_floor.bind(null, &"surface_metal"), &"metal"], [_floor.bind(null, &"", "carpet"), &"carpet"],
		[_floor.bind(&"marble"), &"stone"], [_floor.bind(), &"stone"]]
	for case: Array in cases:
		var floor_body: StaticBody3D = (case[0] as Callable).call()
		var steps := _walker()
		steps.body.position = Vector3(0, 0.05, 0)
		await physics_frames(2)
		assert_eq(steps.probe_surface(), case[1], "floor tagged for " + String(case[1]))
		floor_body.queue_free()
		steps.body.queue_free()
		await physics_frames(1)


func test_step_sets_per_profile_and_surface() -> void:
	var guard := _walker()
	assert_eq(guard.step_set(Surface.WOOD), &"step_wood")
	assert_eq(guard.step_set(Surface.METAL), &"step_metal")
	var wolf := _walker(&"wolf")
	assert_eq(wolf.step_set(Surface.STONE), &"wolf", "claws on hard floors")
	assert_eq(wolf.step_set(Surface.CARPET), &"wolf_soft", "pads on carpet")
	assert_eq(_walker(&"knight").step_set(Surface.CARPET), &"knight")


func test_aliases_and_kits_and_rooms() -> void:
	assert_eq(Surface.normalize("Grate"), Surface.METAL)
	assert_eq(Surface.normalize(&"concrete"), Surface.STONE)
	assert_eq(Surface.normalize("lava"), &"")
	var piece := Node3D.new()
	piece.set_meta(&"kit", &"balcony")
	add_child(piece)
	assert_eq(Surface.of(piece, Vector3.ZERO), Surface.STONE, "the balcony is the hall's limestone slab")
	assert_eq(Surface.of(null, Vector3.ZERO), Surface.STONE, "nothing known: stone")


func test_landing_sounds_only_after_a_real_fall() -> void:
	var steps := _walker()
	var landings := watch(steps.landed)
	steps.land(2.0)
	assert_eq(landings.size(), 0, "a hop")
	steps.land(9.0)
	assert_eq(landings.size(), 1, "a drop")


func test_the_guard_hears_his_steps_flat_and_exhibits_in_3d() -> void:
	var guard := _walker()
	assert_true(guard.is_flat())
	for voice in guard.get_children():
		assert_true(voice is AudioStreamPlayer)
		assert_eq(voice.get(&"bus"), &"SFX")
	var wolf := _walker(&"wolf")
	for voice in wolf.get_children():
		assert_true(voice is AudioStreamPlayer3D)
		assert_eq((voice as AudioStreamPlayer3D).area_mask & Layers.REVERB_ZONE, Layers.REVERB_ZONE)


func test_a_step_plays_and_reports_the_surface() -> void:
	_floor(&"metal")
	var steps := _walker()
	steps.body.position = Vector3(0, 0.05, 0)
	await physics_frames(2)
	var reports := watch(steps.stepped)
	steps.step(5.5)
	assert_eq(reports.size(), 1)
	assert_eq(steps.surface, Surface.METAL)
	var playing := 0
	for voice in steps.get_children():
		if voice.get(&"playing"):
			playing += 1
	assert_eq(playing, 1)
	for voice in steps.get_children():
		voice.call(&"stop")


func test_steps_stop_when_the_game_quits() -> void:
	var steps := _walker()
	steps.step(5.5)
	Sfx.quitting.emit()
	for voice in steps.get_children():
		assert_false(voice.get(&"playing"), "silenced")
	assert_false(steps.is_physics_processing(), "no more steps")
	Music._quitting = false
	Ambience._quitting = false


func test_foley_gives_walkers_the_right_profile() -> void:
	var guard := Player.new()
	assert_eq(Foley.profile_for(guard), &"guard")
	guard.free()
	var cases := [[&"wax", WaxFigure.new()], [&"wolf", Wolf.new()], [&"knight", Knight.new()], [&"raptor", Raptor.new()],
		[&"", Bust.new()], [&"", Portrait.new()]]
	for case: Array in cases:
		var body: Node = case[1]
		assert_eq(Foley.profile_for(body), case[0], body.get_class())
		body.free()
	var plain := CharacterBody3D.new()
	assert_eq(Foley.profile_for(plain), &"")
	plain.free()


func test_foley_shrugs_off_a_body_freed_before_its_turn() -> void:
	var body := CharacterBody3D.new()
	add_child(body)
	body.free()
	Foley._attach_later(body)   # what the deferred call gets: no script error
	Foley._attach_later(null)
	assert_true(true)


func test_foley_attaches_once_when_enabled() -> void:
	Foley.enabled = true
	var wolf := Wolf.new()
	add_child(wolf)
	await get_tree().process_frame
	var steps := wolf.get_node_or_null(^"Footsteps") as Footsteps
	assert_not_null(steps, "attached on entering the tree")
	if steps != null:
		assert_eq(steps.profile, &"wolf")
	assert_eq(Foley.attach(wolf), null, "never twice")
	Foley.enabled = false
	var knight := Knight.new()
	add_child(knight)
	await get_tree().process_frame
	assert_true(knight.get_node_or_null(^"Footsteps") == null, "disabled: nothing attached")
