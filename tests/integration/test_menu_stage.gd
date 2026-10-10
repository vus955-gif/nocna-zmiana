extends TestCase
## The main menu's live scene (MenuStage): the level builds without errors
## (greybox for the quick checks, dressed once), the sleeping T-Rex stands
## on its pedestal, the culler keeps only the court, the entrance hall and
## Egypt's first rooms lit, the loop cuts through black and is continuous,
## every shot of the rail is in the building, clear of walls and sees its
## subject, the life of the stage runs, and the stage gives itself up when
## the art is off, the build takes too long or frames come too slowly.

var stage: MenuStage


func after_each() -> void:
	MuseumFloorLevel.dress_default = false
	ArtLibrary.models_enabled = true
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.HIGH)


## A built stage in the tree (greybox unless [param art]).
func _stage(art: bool = false) -> MenuStage:
	stage = MenuStage.new()
	stage.dressed = art
	add_child(stage)
	var started := Time.get_ticks_msec()
	var ok := stage.build()
	print("  menu stage (%s): %s in %d ms" % ["art" if art else "greybox", "built" if ok else "FAILED: " + stage.fail_reason, Time.get_ticks_msec() - started])
	assert_true(ok, "the stage builds: " + stage.fail_reason)
	return stage


func test_it_builds_without_the_game_and_without_navigation() -> void:
	_stage()
	assert_not_null(stage.level)
	assert_not_null(stage.camera)
	assert_true(stage.camera.current, "the stage's camera is the view")
	assert_true(stage.level.navigation == null, "no navigation is baked")
	assert_eq(stage.shots.size(), 4)
	assert_eq(get_tree().get_nodes_in_group(&"player").size(), 0, "no guard")
	assert_eq(get_tree().get_nodes_in_group(&"enemies").size(), 0, "no exhibits")
	assert_gt(stage.level.structure.get_child_count(), 100, "the floor is there")


func test_the_trex_sleeps_on_its_pedestal() -> void:
	_stage()
	assert_not_null(stage.trex)
	assert_true(stage.trex.is_dormant(), "asleep")
	var marker: Transform3D = stage.level.markers[Floor1Plan.TREX_MARKER]
	assert_lt(stage.trex.position.distance_to(marker.origin), 0.2, "on the pedestal's top")
	assert_true(stage.trex.target == null, "nobody to hunt")
	# a few physics steps: it stays on its pedestal and stays asleep
	for i in 20:
		await get_tree().physics_frame
	assert_lt(stage.trex.global_position.distance_to(marker.origin), 0.3, "it does not fall or wander")
	assert_true(stage.trex.is_dormant())


func test_the_dressed_stage_culls_everything_outside_its_rooms() -> void:
	MuseumFloorLevel.dress_default = true
	_stage(true)
	assert_lt(stage.build_msec, MenuStage.BUILD_BUDGET_MSEC, "within the budget")
	var culler := stage.level.culler
	assert_not_null(culler, "the dressed level has its culler")
	assert_eq(culler.only_rooms, MenuStage.MENU_ROOMS)
	stage.show_shot(0, 0.0)
	for far: StringName in [&"north_hall", &"egypt_tombs", &"egypt_colossus", &"basement_workshop", &"assyria_gate_hall"]:
		if stage.level.layout.room(far) != null:
			assert_true(culler.is_culled(far), "%s is switched off" % far)
	for near: StringName in [&"court", &"entrance_hall", &"egypt_vestibule"]:
		assert_false(culler.is_culled(near), "%s stays on" % near)
	# the far zones really have lamps to switch off (the culler is not idle)
	var total := 0
	var left := 0
	for node in stage.level.lights.get_children():
		if node is Light3D and not node is DirectionalLight3D:
			var room: StringName = node.get_meta(&"room", &"")
			total += 1
			if MenuStage.MENU_ROOMS.has(room):
				left += 1
	print("  lamps on the floor %d, in the menu's rooms %d" % [total, left])
	assert_gt(total - left, left, "most of the floor's lamps are outside the menu's rooms")
	# the egypt shot sits at the far end of the rail: its gallery is lit there
	var egypt := stage.shots.size() - 1
	stage.show_shot(egypt, stage.shots[egypt].seconds * 0.8)
	assert_false(culler.is_culled(&"egypt_gallery"), "the gallery is lit for its glimpse")
	await physics_frames(4)   # the colliders register, the T-Rex poses itself
	var space := get_viewport().find_world_3d().direct_space_state
	var problems := MenuStageCheck.shot_problems(stage, space)
	assert_eq(problems.size(), 0, "every shot flies clear of the walls and sees its subject: " + "; ".join(problems))
	var framing := MenuStageCheck.trex_problems(stage)
	assert_eq(framing.size(), 0, "the T-Rex stays in frame: " + "; ".join(framing))


func test_the_loop_cuts_through_black_and_is_continuous() -> void:
	_stage()
	stage.show_shot(0, 0.0)
	stage.start()
	var changes := watch(stage.shot_changed)
	var last := stage.camera.global_position
	var worst_step := 0.0
	var dark_at_cut := 1.0
	var index := stage.shot_index
	var peak := 0.0
	var frames := 0
	# a whole lap and a bit: 60 fps frames of game time
	var lap := 0.0
	for shot in stage.shots:
		lap += shot.seconds + MenuRail.DIP
	while frames < int((lap + 6.0) * 60.0):
		stage._process(1.0 / 60.0)
		frames += 1
		var now := stage.camera.global_position
		if stage.shot_index == index:
			worst_step = maxf(worst_step, now.distance_to(last))
			peak = maxf(peak, stage.dip)
		else:
			dark_at_cut = minf(dark_at_cut, stage.dip)
			index = stage.shot_index
		last = now
		assert_true(now.is_finite(), "finite at frame %d" % frames)
	assert_gt(changes.size(), 3, "it cut at least once a shot")
	assert_gt(dark_at_cut, 0.99, "the cut happens in the black")
	assert_gt(peak, 0.99, "the screen goes fully dark between shots")
	assert_lt(worst_step, 0.06, "within a shot the camera moves a few centimetres a frame")
	assert_true(changes[0][0] == &"drum", "the second shot follows the first")


func test_the_black_is_clear_during_a_shot() -> void:
	_stage()
	stage.show_shot(1, 5.0)
	stage.start()
	for i in 30:
		stage._process(1.0 / 60.0)
	assert_almost_eq(stage.dip, 0.0, 0.0001, "no black in the middle of a shot")
	assert_almost_eq(stage._dip_rect.modulate.a, 0.0, 0.0001)
	stage.show_shot(0, stage.shots[0].seconds - 0.1)
	for i in 20:
		stage._process(1.0 / 60.0)
	assert_gt(stage.dip, 0.05, "the black comes over the end of a shot")


func test_a_far_lamp_stutters_and_comes_back() -> void:
	_stage()
	stage.show_shot(0, 0.0)
	assert_gt(stage._lamps.size(), 3, "the court has lamps to stutter")
	stage.stutter()
	assert_true(stage.is_stuttering())
	var lamp := stage._lamp
	var base := stage._lamp_base
	assert_gt(lamp.global_position.distance_to(stage.camera.global_position), MenuStage.FLICKER_FAR - 0.01, "a distant one")
	var dipped := false
	for i in 240:
		stage._live(1.0 / 60.0)
		dipped = dipped or lamp.light_energy < base * 0.5
	assert_true(dipped, "it dropped out")
	assert_false(stage.is_stuttering(), "and the stutter is over")
	assert_almost_eq(lamp.light_energy, base, 0.0001, "the lamp is back at full strength")


func test_a_cloud_thins_the_moon_and_passes() -> void:
	_stage()
	var moon := stage._moon
	assert_not_null(moon)
	var base := moon.light_energy
	var fog := moon.light_volumetric_fog_energy
	stage._cloud_in = 0.0
	stage._live(1.0 / 60.0)
	var lowest := base
	for i in int((MenuStage.CLOUD_LENGTH + 1.0) * 60.0):
		stage._live(1.0 / 60.0)
		lowest = minf(lowest, moon.light_energy)
	assert_lt(lowest, base * (1.0 - MenuStage.CLOUD_DEPTH * 0.9), "the moon dims under the cloud")
	assert_gt(lowest, base * (1.0 - MenuStage.CLOUD_DEPTH) - 0.001, "but never below the cloud's depth")
	assert_almost_eq(moon.light_energy, base, 0.001, "and shines again after it")
	assert_almost_eq(moon.light_volumetric_fog_energy, fog, 0.001, "the beams in the fog too")


func test_the_dust_follows_the_camera() -> void:
	_stage()
	stage.show_shot(2, 8.0)
	assert_not_null(stage._dust, "dust at High")
	var ahead := stage.camera.global_position - stage.camera.global_basis.z * 6.0
	assert_lt(stage._dust.global_position.distance_to(ahead), 0.01, "six metres in front of the lens")
	GraphicsQuality.current = GraphicsQuality.Quality.LOW
	var low := MenuStage.new()
	low.dressed = false
	add_child(low)
	assert_true(low.build())
	assert_true(low._dust == null, "Low has no motes")
	assert_eq(low.shots.size(), 4, "every shot still runs")
	low.queue_free()


func test_without_the_art_the_stage_gives_up_and_says_so() -> void:
	ArtLibrary.models_enabled = false
	stage = MenuStage.new()
	add_child(stage)
	var told := watch(stage.failed)
	assert_false(stage.build(), "no art, no live scene")
	assert_ne(stage.fail_reason, "")
	assert_eq(told.size(), 1, "the owner is told")
	assert_true(stage.level == null, "nothing was built")


func test_a_build_over_the_budget_is_thrown_away() -> void:
	stage = MenuStage.new()
	stage.dressed = false
	stage.build_budget_msec = 1
	add_child(stage)
	var told := watch(stage.failed)
	assert_false(stage.build(), "too slow")
	assert_true(stage.fail_reason.contains("took"), stage.fail_reason)
	assert_eq(told.size(), 1)
	assert_false(stage.running)


func test_slow_frames_make_the_stage_give_up() -> void:
	_stage()
	stage.watch_always = true
	stage.show_shot(0, 0.0)
	stage.start()
	var told := watch(stage.failed)
	# 12 FPS for far longer than the watch window
	for i in 200:
		stage._process(0.085)
	assert_eq(told.size(), 1, "told once")
	assert_true(stage.fail_reason.begins_with("frames take"), stage.fail_reason)
	assert_false(stage.running, "and stopped")


func test_a_few_hitches_do_not_make_the_stage_give_up() -> void:
	_stage()
	stage.watch_always = true
	stage.show_shot(0, 0.0)
	stage.start()
	var told := watch(stage.failed)
	# a shader compiling now and then: 0.4 s frames among 60 FPS ones
	for i in 900:
		stage._process(0.4 if i % 40 == 0 else 1.0 / 60.0)
	assert_eq(told.size(), 0, "a hitch is not a slow scene")
	assert_true(stage.running)


func test_fast_frames_keep_the_stage() -> void:
	_stage()
	stage.watch_always = true
	stage.show_shot(0, 0.0)
	stage.start()
	var told := watch(stage.failed)
	for i in 600:
		stage._process(1.0 / 60.0)
	assert_eq(told.size(), 0)
	assert_true(stage.running)


func test_the_view_is_drawn_from_every_shot_before_it_is_shown() -> void:
	_stage()
	var done := [false]
	var warm := func() -> void:
		await stage.prepare_view(3)
		done[0] = true
	warm.call()
	var visited := {}
	var frames := 0
	while not done[0] and frames < 200:
		visited[stage.shot_index] = true
		await get_tree().process_frame
		frames += 1
	assert_true(done[0], "the warm-up ends")
	assert_eq(visited.size(), stage.shots.size(), "every shot was drawn behind the cover")
	assert_eq(stage.shot_index, 0, "it ends where the loop starts")
	assert_almost_eq(stage.shot_time, 0.0, 0.0001)
	assert_lt(stage.camera.global_position.distance_to(stage.shots[0].eye[0]), 0.1, "at the first shot's start")
