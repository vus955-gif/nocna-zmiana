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


## A part of a mirror-image model (the lioness: the model's x is flipped) flies
## as a body with a proper turn; the mirror rides on the mesh that is seen.
func test_a_mirrored_model_part_flies_as_a_body_with_a_proper_turn() -> void:
	Fx.clear()
	await physics_frames(1)
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.3)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var shard := MeshShards.whole(mesh)
	var materials: Array[Material] = []
	var xform := Transform3D(Basis(Vector3.UP, 0.7) * Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3(2.0, 1.0, -3.0))
	var body := Fx.piece(shard, materials, xform, Vector3.ZERO)
	assert_gt(body.transform.basis.determinant(), 0.0, "the physics body is never mirrored")
	assert_true(body.transform.basis.is_conformal(), "nor scaled")
	var view := body.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
	assert_lt(view.transform.basis.determinant(), 0.0, "the mesh carries the mirror")
	for corner in [Vector3(0.2, 0.1, 0.15), Vector3(-0.2, -0.1, 0.15), Vector3(0.0, 0.1, -0.15)]:
		var shown: Vector3 = body.transform * (view.transform * corner)
		assert_true(shown.is_equal_approx(xform * corner), "what is seen is where the part was: %s vs %s" % [str(shown), str(xform * corner)])
	# an unmirrored part is as it was: the view keeps the (positive) scale
	var plain := Fx.piece(shard, materials, Transform3D(Basis(Vector3.UP, 0.7), Vector3(2.0, 1.0, -3.0)), Vector3.ZERO)
	var plain_view := plain.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
	assert_gt(plain.transform.basis.determinant(), 0.0)
	assert_gt(plain_view.transform.basis.determinant(), 0.0)
	Fx.clear()
