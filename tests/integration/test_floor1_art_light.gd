extends TestCase
## Floor I's light recipe (stage P2, Floor1LightRecipe): the shadow budget of
## every dressed room, lamps in their groups (the blackout, the moon), the
## dust and probes per room, Egypt's spotlights aimed with their beams, the
## room-graph culling (lamps, motes, probes off far away - nodes still
## "visible" for the exhibits' light model), the graphics presets' share of
## the atmosphere, and the moon under the court's glass in the light model.

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.HIGH)


func _lamps() -> Array[Light3D]:
	var out: Array[Light3D] = []
	for node in level.lights.get_children():
		if node is Light3D and not node is DirectionalLight3D:
			out.append(node)
	return out


func test_shadows_stay_within_each_rooms_budget() -> void:
	var recipe := Floor1LightRecipe.create()
	var used := {}
	var total := 0
	for lamp in _lamps():
		if not lamp.shadow_enabled:
			continue
		var room := recipe.key(lamp.get_meta(&"room", &""))
		used[room] = int(used.get(room, 0)) + 1
		total += 1
	for room: StringName in used:
		if not Floor1LightRecipe.ROOMS.has(room):
			continue   # a zone not dressed yet keeps the layout's shadows
		var budget := int((Floor1LightRecipe.ROOMS[room] as Dictionary)["shadowed"])
		assert_true(int(used[room]) <= budget, "%s casts %d shadows (budget %d)" % [room, used[room], budget])
	assert_gt(int(used.get(&"egypt_gallery", 0)), 1, "the gallery's spotlights and the camp lamp cast shadows")
	assert_gt(int(used.get(&"court", 0)), 1, "the court's key lamps cast shadows")
	print("  shadowed lamps: %d over the floor; %s" % [total, used])


func test_every_lamp_has_one_group_and_the_moon_is_unfused() -> void:
	# (the basement's flickering tubes are a group of their own)
	var groups := [LightSpec.MAIN, LightSpec.EMERGENCY, LightSpec.HAVEN, LightSpec.MOON, &"flicker_lights"]
	var shafts := 0
	for lamp in _lamps():
		var count := 0
		for group: StringName in groups:
			if lamp.is_in_group(group):
				count += 1
		assert_eq(count, 1, "%s is in exactly one group" % lamp.name)
		if lamp.get_meta(&"recipe_extra", false) and lamp.is_in_group(LightSpec.MOON) and lamp.get_meta(&"room", &"") == &"egypt_gallery":
			shafts += 1
			assert_gt(lamp.light_volumetric_fog_energy, 2.0, "a moonbeam through a clerestory shows in the dust")
	assert_eq(shafts, Floor1Art.CLERESTORY_Z.size(), "a moonbeam through each clerestory")
	NightModifiers.apply(level, &"blackout", RunState)
	for lamp in _lamps():
		if lamp.is_in_group(LightSpec.MAIN):
			assert_false(lamp.visible, "the blackout puts out %s" % lamp.name)
		elif lamp.is_in_group(LightSpec.MOON):
			assert_true(lamp.visible, "the moon has no fuse")
	# the drum's lanterns (hero pieces) are on the court's mains
	var circuit := level.lights.get_node_or_null(^"Glow_court_heroes")
	assert_not_null(circuit, "the drum's lanterns are on a circuit")
	if circuit != null:
		assert_false(LevelKit.is_lit(circuit), "and go dark in the blackout")


func test_dust_and_probes_in_the_dressed_rooms() -> void:
	var fog := {}
	var probes := {}
	var motes := {}
	for node in level.lights.get_children():
		var room: StringName = node.get_meta(&"room", &"")
		if node is FogVolume:
			fog[room] = true
		elif node is ReflectionProbe:
			probes[room] = true
		elif node is GPUParticles3D:
			motes[room] = true
	for room: StringName in Floor1LightRecipe.ROOMS:
		var spec := level.layout.room(room)
		if spec == null or not spec.carved:
			continue
		assert_true(fog.has(room), "%s has its dust" % room)
		if (Floor1LightRecipe.ROOMS[room] as Dictionary).get("probe", false):
			assert_true(probes.has(room), "%s has its reflection probe" % room)
	for room: StringName in [&"court", &"court_reading", &"egypt_gallery", &"egypt_colossus"]:
		assert_true(motes.has(room), "motes float in %s" % room)
	# (stage P5: the last zones have their recipe too)
	assert_true(fog.has(&"americas_moai") and fog.has(&"roof_catwalks"), "the Americas and the roof have their dust")


func test_egypt_spotlights_aim_with_their_beams() -> void:
	var fittings := 0
	for node in level.lights.get_children():
		if node.get_meta(&"kit", &"") != &"egypt_spotlight":
			continue
		fittings += 1
		var light := node.get_meta(&"light") as SpotLight3D
		assert_not_null(light)
		var aim := -(node as Node3D).global_transform.basis.z
		var beam := -light.global_transform.basis.z
		assert_gt(aim.dot(beam), 0.99, "the spotlight looks where it shines")
		assert_true(node.find_children("*", "MeshInstance3D", true, false).size() > 0, "the museum spotlight model")
	assert_eq(fittings, 11, "eight colossi, two on the throne, the Rosetta Stone")


func test_far_rooms_are_culled_but_stay_powered() -> void:
	var culler := level.culler
	assert_not_null(culler, "the dressed floor culls by the room graph")
	culler.depth = 2
	var keep := culler.update_from(Vector3(0, 1.7, 22))   # the court, south of the drum
	assert_true(keep.has(&"court") and keep.has(&"court_reading") and keep.has(&"court_balcony"))
	assert_true(keep.has(&"egypt_vestibule") and keep.has(&"egypt_gallery"), "two passages: the gallery")
	assert_false(keep.has(&"egypt_colossus"), "three passages: the Colossus hall")
	assert_true(culler.is_culled(&"egypt_colossus"))
	var powered := LayoutIllumination.powered_by_nodes(level.lights)
	assert_true(powered.call(LightSpec.MAIN, &"egypt_colossus"), "a culled room's lamps still count for the exhibits")
	for node in level.lights.get_children():
		if node.get_meta(&"room", &"") == &"egypt_colossus":
			if node is Light3D:
				assert_true((node as Light3D).visible, "culled on the server only")
			if node is GPUParticles3D:
				assert_false((node as GPUParticles3D).emitting, "far sand stops")
	keep = culler.update_from(Vector3(-42.5, 1.7, -20))
	assert_true(keep.has(&"egypt_colossus"))
	assert_false(culler.is_culled(&"egypt_colossus"), "walking in switches it back on")
	assert_true(culler.is_culled(&"court_reading"), "and the Reading Room off")


func test_presets_carry_the_atmosphere() -> void:
	for quality: int in GraphicsQuality.PRESETS:
		var p: Dictionary = GraphicsQuality.PRESETS[quality]
		for key in ["particles", "probes", "cull_depth"]:
			assert_true(p.has(key), "preset %d sets %s" % [quality, key])
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.LOW)
	for node in get_tree().get_nodes_in_group(GraphicsQuality.PARTICLES):
		assert_false((node as GPUParticles3D).visible, "Low: no motes")
	for node in get_tree().get_nodes_in_group(GraphicsQuality.PROBES):
		assert_false((node as Node3D).visible, "Low: no probes")
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.MEDIUM)
	for node in get_tree().get_nodes_in_group(GraphicsQuality.PARTICLES):
		assert_almost_eq((node as GPUParticles3D).amount_ratio, 0.5, 0.001, "Medium: half the motes")
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.HIGH)
	for node in get_tree().get_nodes_in_group(GraphicsQuality.PARTICLES):
		assert_true((node as GPUParticles3D).visible)


func test_the_light_model_sees_the_moon_under_the_glass() -> void:
	var model := LayoutIllumination.from_layout(level.layout)
	var court := level.layout.room(&"court")
	var well := court.skylights[0]
	var under := Vector3(well.get_center().x, 1.3, well.get_center().y)
	assert_true(model.at(under) >= LayoutIllumination.MOON_LEVEL - 0.001, "moonlight under the glass roof")

## The embers and the smoke over the fires (the Assyrian tripods, the
## Americas' bowls, the fallen bowl in the pit).
func _fires() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for node in level.lights.get_children():
		if node is GPUParticles3D and (node.get_meta(&"embers", false) or node.get_meta(&"smoke", false)):
			out.append(node)
	return out


func test_the_fires_stop_smoking_when_their_flames_go_out() -> void:
	var fires := _fires()
	assert_gt(fires.size(), 20, "embers over the tripods, embers and smoke over the bowls")
	var rooms := {}
	for fire in fires:
		assert_true(fire.emitting, "%s in %s burns at night" % [fire.name, fire.get_meta(&"room")])
		rooms[fire.get_meta(&"room")] = true
	NightModifiers.apply(level, &"blackout", RunState)
	for fire in fires:
		assert_false(fire.emitting, "%s in %s stops with its flame" % [fire.name, fire.get_meta(&"room")])
	# nothing wakes them while the power is out: neither the room-graph culling
	# bringing a room back nor a change of the graphics preset
	for room: StringName in rooms:
		level.culler.set_room(room, false)
		level.culler.set_room(room, true)
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.HIGH)
	for fire in fires:
		assert_false(fire.emitting, "%s in %s stays out" % [fire.name, fire.get_meta(&"room")])
	# the power back: the fires burn again (the sparks of a low preset stay off)
	NightModifiers.set_lights(level, LightSpec.MAIN, true)
	for fire in fires:
		assert_true(fire.emitting, "%s in %s lights again" % [fire.name, fire.get_meta(&"room")])
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.LOW)
	for fire in fires:
		assert_false(fire.emitting, "%s is off on the low preset" % fire.name)


func test_the_fire_emitters_share_their_materials() -> void:
	var process := {}
	var quads := {}
	var meshes := 0
	for fire in _fires():
		process[fire.process_material] = true
		quads[fire.draw_pass_1] = true
		meshes += 1
	assert_gt(meshes, 20, "the fires")
	assert_eq(process.size(), 2, "one process material for the embers and one for the smoke")
	assert_eq(quads.size(), 2, "one quad for each")
