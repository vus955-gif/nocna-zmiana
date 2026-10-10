extends TestCase
## Stage 1b art: generated assets import as crisp pixel textures, every
## model loads and gets its baked material, the wax figure keeps the jointed
## layout the game relies on, and the style sample room builds.

const MODELS: Array[String] = [
	"pedestal", "bust", "display_case", "column", "wall_4m", "wall_2m", "wall_window_4m", "window",
	"ceiling_2m", "stanchion", "stanchion_post", "bench", "painting", "sconce", "emergency_light",
	"crystal", "wax_figure",
]


func test_every_texture_imports_lossless_with_mipmaps() -> void:
	var dir := DirAccess.open("res://assets/textures")
	assert_not_null(dir, "assets/textures exists")
	if dir == null:
		return
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		count += 1
		var cfg := ConfigFile.new()
		var err := cfg.load("res://assets/textures/%s.import" % file)
		assert_eq(err, OK, "%s has an .import file" % file)
		if err != OK:
			continue
		assert_eq(cfg.get_value("params", "compress/mode"), 0, "%s lossless" % file)
		assert_eq(cfg.get_value("params", "mipmaps/generate"), true, "%s has mipmaps" % file)
		assert_eq(cfg.get_value("params", "detect_3d/compress_to"), 0, "%s not recompressed" % file)
	assert_gt(count, 40, "texture sets present")


func test_every_model_loads_with_baked_pixel_materials() -> void:
	for model_name in MODELS:
		var node := ArtLibrary.model(model_name)
		assert_not_null(node, model_name)
		if node == null:
			continue
		add_child(node)
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has meshes" % model_name)
		for child in meshes:
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				var mat := view.get_surface_override_material(i)
				assert_not_null(mat, "%s surface %d dressed" % [model_name, i])
				var orm := mat as ORMMaterial3D
				if orm != null:
					assert_eq(orm.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC, model_name)
					assert_not_null(orm.albedo_texture, "%s albedo" % model_name)
					assert_not_null(orm.orm_texture, "%s orm" % model_name)
		node.queue_free()


func test_glass_panes_cast_no_shadow() -> void:
	var window := ArtLibrary.model("window")
	add_child(window)
	var glass := window.find_child("window_glass", true, false) as MeshInstance3D
	assert_not_null(glass, "window_glass node")
	if glass != null:
		assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_true(glass.get_surface_override_material(0) is ShaderMaterial, "glass shader")
	window.queue_free()


func test_wax_figure_is_jointed_for_gibs_and_matches_its_hurtboxes() -> void:
	var figure := ArtLibrary.model("wax_figure")
	add_child(figure)
	var bounds := AABB()
	var first := true
	for part_name in ["torso", "head", "hat", "arm_l", "arm_r", "leg_l", "leg_r"]:
		var part := figure.find_child(part_name, true, false) as MeshInstance3D
		assert_not_null(part, "part %s" % part_name)
		if part == null:
			continue
		var box := part.global_transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	# head weak point: sphere r 0.22 centred at y 1.55 (src/enemies/wax_figure.gd)
	var head := figure.find_child("head", true, false) as MeshInstance3D
	if head != null:
		var head_box := head.global_transform * head.get_aabb()
		assert_almost_eq(head_box.get_center().y, 1.55, 0.1, "head centre height")
		assert_almost_eq(head.position.y, 1.47, 0.01, "neck pivot")
	var arm := figure.find_child("arm_r", true, false) as Node3D
	if arm != null:
		assert_gt(arm.position.x, 0.1, "right arm pivot at the right shoulder")
		assert_almost_eq(arm.position.y, 1.40, 0.01, "shoulder pivot height")
	# fits the body capsule (r 0.35, h 1.75) plus the hat on top
	assert_almost_eq(bounds.position.y, 0.0, 0.03, "stands on the floor")
	assert_gt(bounds.end.y, 1.7, "tall enough")
	assert_lt(bounds.end.y, 1.9, "not taller than the hat allows")
	figure.queue_free()


func test_style_sample_room_builds_and_blackout_switches_lamps() -> void:
	var sample := (load("res://src/style/style_sample.tscn") as PackedScene).instantiate() as StyleSample
	sample.with_player = false
	add_child(sample)
	assert_not_null(sample.figure, "wax figure placed")
	assert_gt(sample.main_lights.size(), 6, "sconces, picture light, case lights")
	assert_true(sample.env.sdfgi_enabled, "SDFGI on")
	assert_true(sample.env.ssr_enabled, "SSR on")
	assert_true(sample.env.volumetric_fog_enabled, "volumetric fog on")
	sample.set_main_lights(false)
	for light in sample.main_lights:
		assert_false(light.visible, "lamp off in blackout")
	assert_true(sample.emergency.visible, "emergency light stays on")
	sample.set_main_lights(true)
	sample.queue_free()
	await get_tree().process_frame
