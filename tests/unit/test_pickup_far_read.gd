extends TestCase
## Pickups read from afar (the light pass of 19.10; visual QA e1: at 15 m in
## the shade or a dark room the pickups were only coloured dots and the
## medkit could not be told apart): beyond ~10 m a pickup's rim grows, its
## body glows faintly in its kind's colour and the medkit's red cross
## brightens; up close nothing changes. Exhibits keep their rims as they
## were.


func test_a_pickup_reads_stronger_from_afar_and_the_same_up_close() -> void:
	for tex_name: String in ArtLibrary.PICKUP_RIM:
		var mat := ArtLibrary.exhibit_material(tex_name)
		var fade: Vector2 = mat.get_shader_parameter(&"far_fade")
		assert_gt(fade.x, 8.0, "%s: up close (and to 8 m) the rim stays as it was" % tex_name)
		assert_lt(fade.y, 15.5, "%s: the full far read by 15 m" % tex_name)
		assert_gt(fade.y, fade.x + 3.0, "%s: it grows in gently" % tex_name)
		assert_gt(float(mat.get_shader_parameter(&"far_rim")), 0.5, "%s: the rim grows from afar" % tex_name)
		var body := float(mat.get_shader_parameter(&"far_body"))
		assert_gt(body, 0.05, "%s: its body takes on its colour from afar" % tex_name)
		assert_lt(body, 0.4, "%s: a faint glow, not a lamp (not arcade)" % tex_name)


func test_the_medkits_cross_brightens_from_afar() -> void:
	var medkit := ArtLibrary.exhibit_material("medkit")
	assert_not_null(medkit.get_shader_parameter(&"emit_tex"), "the medkit's red cross is its emission map")
	var cross := float(medkit.get_shader_parameter(&"far_emit"))
	assert_gt(cross, 1.0, "the red cross glows brighter from afar (%.1f)" % cross)
	for tex_name: String in ["ammo_pistol", "ammo_shells"]:
		var ammo := ArtLibrary.exhibit_material(tex_name)
		assert_lt(float(ammo.get_shader_parameter(&"far_emit") if ammo.get_shader_parameter(&"far_emit") != null else 0.0), cross,
			"only the medkit's mark (%s keeps its print)" % tex_name)


func test_an_exhibit_keeps_its_rim() -> void:
	for tex_name: String in ["mummy", "wolf", "knight"]:
		var mat := ArtLibrary.exhibit_material(tex_name)
		var far: Variant = mat.get_shader_parameter(&"far_rim")
		assert_true(far == null or float(far) == 0.0, "%s: no far read (an enemy is not a pickup)" % tex_name)
		var body: Variant = mat.get_shader_parameter(&"far_body")
		assert_true(body == null or float(body) == 0.0, "%s: no body glow" % tex_name)


func test_the_shader_reads_far() -> void:
	var code := ArtLibrary.EXHIBIT_SHADER.code
	var include := (load("res://src/style/exhibit.gdshaderinc") as ShaderInclude).code
	assert_true(code.contains("exhibit.gdshaderinc"), "the exhibit shader includes the shared body")
	for uniform_name: String in ["far_fade", "far_rim", "far_body", "far_emit"]:
		assert_true(include.contains("uniform") and include.contains(uniform_name), "the shared body has %s" % uniform_name)
