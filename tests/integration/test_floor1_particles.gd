extends TestCase
## The loose pages of the library and the cherry petals of the garden
## (Floor1LightRecipe.make_pages / make_petals) fade in at birth and out at
## death. ParticleProcessMaterial.alpha_curve reads only the RED channel of
## its texture, so a white gradient there is a constant 1 and the leaves pop
## in and out; the fade lives in color_ramp (like the embers' and the dust's)
## and the leaves' materials blend, or the alpha would never show.

const SPEC := {"room": &"test_room", "box": AABB(Vector3.ZERO, Vector3(4.0, 4.0, 4.0)), "amount": 8}


func _fades(particles: GPUParticles3D, what: String) -> void:
	var process := particles.process_material as ParticleProcessMaterial
	assert_not_null(process, "%s have a process material" % what)
	if process == null:
		return
	var ramp := process.color_ramp as GradientTexture1D
	assert_not_null(ramp, "%s fade through a colour ramp" % what)
	if ramp != null:
		assert_almost_eq(ramp.gradient.sample(0.0).a, 0.0, 0.01, "%s are clear at birth" % what)
		assert_almost_eq(ramp.gradient.sample(1.0).a, 0.0, 0.01, "%s are clear at death" % what)
		assert_gt(ramp.gradient.sample(0.5).a, 0.9, "%s are solid in mid-life" % what)
	assert_true(process.alpha_curve == null, "%s have no alpha curve (a white gradient there is a constant 1)" % what)
	var mesh := particles.draw_pass_1
	assert_not_null(mesh, "%s have a mesh" % what)
	if mesh == null:
		return
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	assert_not_null(material, "%s have a plain material" % what)
	if material != null:
		assert_ne(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "%s blend, or their fading would not show" % what)
		assert_true(material.vertex_color_use_as_albedo, "%s take the ramp's alpha from the vertex colour" % what)


func test_petals_fade_in_and_out() -> void:
	var petals := Floor1LightRecipe.make_petals(SPEC)
	_fades(petals, "petals")
	petals.free()


func test_pages_fade_in_and_out() -> void:
	var pages := Floor1LightRecipe.make_pages(SPEC)
	_fades(pages, "pages")
	pages.free()


## (The night's QA, 19.10, in the window: the petals were flat rectangles -
## up close, round the General's feint, a shower of pink squares.) A petal
## is petal-shaped: its texture clear in the corners, solid in the middle,
## the garden's falling ones and the General's storm alike.
func _petal_shaped(mesh: Mesh, what: String) -> void:
	assert_not_null(mesh, "%s have a mesh" % what)
	if mesh == null:
		return
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	assert_not_null(material, "%s have a plain material" % what)
	if material == null:
		return
	assert_ne(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "%s cut their shape out" % what)
	var texture := material.albedo_texture
	assert_not_null(texture, "%s have a shape" % what)
	if texture == null:
		return
	var image := texture.get_image()
	var w := image.get_width() - 1
	var h := image.get_height() - 1
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
		assert_lt(image.get_pixelv(corner).a, 0.1, "%s: clear in the corner %s" % [what, str(corner)])
	assert_gt(image.get_pixel(w / 2, h / 2).a, 0.9, "%s: solid in the middle" % what)


func test_petals_are_petal_shaped_not_squares() -> void:
	var petals := Floor1LightRecipe.make_petals(SPEC)
	_petal_shaped(petals.draw_pass_1, "the garden's petals")
	petals.free()
	_petal_shaped(PetalStorm._petal_mesh(), "the General's storm")
