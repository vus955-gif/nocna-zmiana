extends TestCase


func test_impact_adds_a_particle_burst() -> void:
	var before := Fx.get_child_count()
	Fx.impact(Vector3.ZERO, Vector3.UP, ExhibitMaterial.Kind.WAX)
	assert_eq(Fx.get_child_count(), before + 1)


func test_debris_is_capped() -> void:
	var plan := GibPlanner.plan(ExhibitMaterial.Kind.WAX, 1000.0, 60.0, false)
	for i in 20:
		Fx.shatter(Vector3.ZERO, ExhibitMaterial.Kind.WAX, plan, Vector3.FORWARD)
	assert_gt(Fx.chunk_count(), 0)
	assert_true(Fx.chunk_count() <= Fx.MAX_CHUNKS, "chunks %d" % Fx.chunk_count())


func test_hitstop_slows_time_then_restores_it() -> void:
	Fx.hitstop(0.05)
	assert_lt(Engine.time_scale, 1.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_tracer_arc_flash_and_hole_spawn_nodes() -> void:
	var before := Fx.get_child_count()
	Fx.tracer(Vector3.ZERO, Vector3(0, 0, -5))
	Fx.arc(Vector3.ZERO, Vector3(0, 0, -3))
	Fx.flash(Vector3.ZERO, Color.WHITE, 1.0, 3.0, 0.1)
	Fx.bullet_hole(Vector3(0, 0, -5), Vector3(0, 0, 1))
	assert_gt(Fx.get_child_count(), before + 3)


func test_missing_sound_is_ignored() -> void:
	var before := Sfx.get_child_count()
	Sfx.play(&"no_such_sound")
	Sfx.play_at(&"no_such_sound", Vector3.ZERO)
	assert_eq(Sfx.get_child_count(), before)


func test_bullet_hole_needs_a_surface_normal() -> void:
	var before := Fx.get_child_count()
	Fx.bullet_hole(Vector3(0, 0, -5), Vector3.ZERO)   # ray started inside a shape
	assert_eq(Fx.get_child_count(), before)


func test_overlapping_hitstops_restore_the_time_scale_they_found() -> void:
	Engine.time_scale = 0.5
	Fx.hitstop(0.05)
	Fx.hitstop(0.1)   # must not remember the frozen scale as "before"
	assert_lt(Engine.time_scale, 0.5)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 0.5)


func test_shorter_hitstop_does_not_cut_a_longer_one_short() -> void:
	Fx.hitstop(0.4)
	Fx.hitstop(0.05)
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_lt(Engine.time_scale, 1.0, "the long hitstop is still running")
	await get_tree().create_timer(0.4, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_effects_do_not_expire_while_the_game_is_paused() -> void:
	Fx.tracer(Vector3.ZERO, Vector3(0, 0, -5))   # lives 0.05 s
	var tracer := Fx.get_child(Fx.get_child_count() - 1)
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	var survived := is_instance_valid(tracer) and not tracer.is_queued_for_deletion()
	get_tree().paused = false
	assert_true(survived)


func test_scene_change_clears_every_effect() -> void:
	assert_true(get_tree().scene_changed.is_connected(Fx.clear), "Fx listens for scene changes")
	Fx.impact(Vector3.ZERO, Vector3.UP)
	Fx.tracer(Vector3.ZERO, Vector3(0, 0, -5))
	get_tree().scene_changed.emit()
	for child in Fx.get_children():
		assert_true(child.is_queued_for_deletion(), "left behind: " + str(child))


func test_bursts_share_process_materials_and_face_the_normal() -> void:
	Fx.impact(Vector3.ZERO, Vector3.UP, ExhibitMaterial.Kind.WAX)
	Fx.impact(Vector3(1, 0, 0), Vector3.RIGHT, ExhibitMaterial.Kind.WAX)
	var first := Fx.get_child(Fx.get_child_count() - 2) as GPUParticles3D
	var second := Fx.get_child(Fx.get_child_count() - 1) as GPUParticles3D
	assert_eq(first.process_material, second.process_material)
	assert_true(second.transform.basis.y.is_equal_approx(Vector3.RIGHT), "burst points along the normal")
	assert_true(second.transform.origin.is_equal_approx(Vector3(1, 0, 0)))
