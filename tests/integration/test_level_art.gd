extends TestCase
## The lobby dressed with the kit (LevelArt, ArtKit, LevelLighting with the
## light recipe): coverage of the kit swap, collisions identical to the
## greybox, the grate's bars, the circuits of the blackout and the power
## cut, and the graphics presets.

## Kit ids that may keep the greybox look in the lobby (none: everything
## the layout places has its model).
const GREYBOX_ALLOWED: Array[StringName] = []

var level: LobbyLevel


func before_each() -> void:
	level = _lobby(true)
	await physics_frames(2)


func after_each() -> void:
	LevelArt.enabled = true
	GraphicsQuality.apply_all(get_tree(), GraphicsQuality.Quality.HIGH)


func _lobby(art: bool) -> LobbyLevel:
	LevelArt.enabled = art
	var lobby := LobbyLevel.new()
	add_child(lobby)
	var started := Time.get_ticks_msec()
	lobby.build()
	var ms := Time.get_ticks_msec() - started
	var meshes := lobby.find_children("*", "MeshInstance3D", true, false).size()
	var multis := lobby.find_children("*", "MultiMeshInstance3D", true, false).size()
	print("  lobby build (%s): %d ms, %d mesh instances, %d multimeshes" % ["art" if art else "greybox", ms, meshes, multis])
	LevelArt.enabled = true
	return lobby


func test_every_piece_wears_the_kit_but_the_documented_ones() -> void:
	var greybox := {}
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit_greybox", false):
			greybox[node.get_meta(&"kit")] = true
	for kit: StringName in greybox:
		assert_true(GREYBOX_ALLOWED.has(kit), "%s still wears the greybox" % kit)
	var meshes := level.find_children("*", "MeshInstance3D", true, false).size()
	var batched := 0
	var batches := level.find_children("*", "MultiMeshInstance3D", true, false)
	for node in batches:
		batched += (node as MultiMeshInstance3D).multimesh.instance_count
	assert_gt(meshes + batched, 1500, "the lobby is dressed")
	assert_true(level.structure.get_node_or_null(^"Dressing") != null, "wall bands, ceilings, floors")


func test_collisions_are_the_greyboxes() -> void:
	var dressed := _shapes(level)
	level.free()
	level = _lobby(false)
	await physics_frames(1)
	var plain := _shapes(level)
	assert_eq(dressed.size(), plain.size(), "as many colliders")
	var differ := 0
	for i in mini(dressed.size(), plain.size()):
		if dressed[i] != plain[i]:
			differ += 1
			if differ < 5:
				fail("collider %s != %s" % [dressed[i], plain[i]])
	assert_eq(differ, 0)


## Every collision shape of the level but the grate's leaves (their bars
## follow the kit's leaf), as sorted strings of kit, position and extent.
func _shapes(root: Node) -> Array:
	var out: Array = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var owner_node := shape.get_parent()
		if owner_node.get_meta(&"kit", &"") == &"grate":
			continue
		var at := shape.global_position.snapped(Vector3.ONE * 0.001)
		var extent := shape.shape.get_debug_mesh().get_aabb().size.snapped(Vector3.ONE * 0.001)
		out.append("%s %s %s" % [owner_node.get_meta(&"kit", owner_node.get_class()), at, extent])
	out.sort()
	return out


func test_shots_fly_between_the_grate_bars_but_not_through_one() -> void:
	var space := level.get_world_3d().direct_space_state
	var gaps := 0
	var bars := 0
	# the leaves meet at x = 0; bars of the east leaf at 1.5 - 1.35 + 0.18 k
	for k in 16:
		var bar := 1.5 - 1.35 + 0.18 * k
		for x in [bar, bar + 0.09]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, -19.0), Vector3(x, 1.5, -25.0), Layers.WORLD)
			var hit := space.intersect_ray(query)
			var through := hit.is_empty() or (hit["position"] as Vector3).z < -22.6
			if x == bar and not through:
				bars += 1
			elif x != bar and through:
				gaps += 1
	assert_eq(bars, 16, "every bar stops a shot")
	assert_gt(gaps, 13, "the gaps between them let shots through")


func test_the_blackout_puts_out_kit_lamps_and_glowing_pieces_but_not_the_exits() -> void:
	NightModifiers.apply(level, &"blackout", RunState)
	var fixtures := get_tree().get_nodes_in_group(&"main_lights_fixtures")
	var circuits := 0
	for fixture in fixtures:
		assert_false(LevelKit.is_lit(fixture), "%s is dark" % fixture.get_meta(&"kit"))
		if fixture.get_meta(&"kit") == &"glow_circuit":
			circuits += 1
	assert_gt(circuits, 0, "the booth, desk and newel lamps are on a circuit")
	for fixture in get_tree().get_nodes_in_group(&"emergency_lights_fixtures"):
		assert_true(LevelKit.is_lit(fixture), "%s stays lit" % fixture.get_meta(&"kit"))
	NightModifiers.set_lights(level, LightSpec.MAIN, true)
	for fixture in fixtures:
		assert_true(LevelKit.is_lit(fixture), "%s back on" % fixture.get_meta(&"kit"))


func test_the_power_cut_darkens_the_hall_only() -> void:
	var rooms: Array[StringName] = [&"hall", &"balcony"]
	NightModifiers.set_lights(level, LightSpec.MAIN, false, rooms)
	for fixture in get_tree().get_nodes_in_group(&"main_lights_fixtures"):
		var room: StringName = fixture.get_meta(&"kit_room")
		assert_eq(LevelKit.is_lit(fixture), not rooms.has(room), "%s in %s" % [fixture.get_meta(&"kit"), room])


func test_the_recipe_lights_the_lobby() -> void:
	var fog := level.lights.get_children().filter(func(n: Node) -> bool: return n is FogVolume)
	assert_gt(fog.size(), 6, "a fog volume per room")
	var probes := level.lights.get_children().filter(func(n: Node) -> bool: return n is ReflectionProbe)
	assert_eq(probes.size(), 2, "the marble hall and the gallery")
	var env := NightModifiers.environment(level)
	assert_true(env.sdfgi_enabled, "SDFGI at the default preset")
	assert_eq(env.volumetric_fog_density, 0.0, "fog only in the rooms' volumes")


func test_graphics_presets_apply_live() -> void:
	var env := NightModifiers.environment(level)
	var ambient := env.ambient_light_energy
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.LOW, false)
	assert_false(env.sdfgi_enabled, "Low: no SDFGI")
	assert_false(env.ssr_enabled)
	assert_false(env.ssil_enabled)
	assert_gt(env.ambient_light_energy, ambient * 1.5, "an ambient fill instead")
	for light in get_tree().get_nodes_in_group(GraphicsQuality.SHADOWED):
		assert_false((light as Light3D).shadow_enabled, "Low: no lamp shadows")
	assert_eq(get_tree().root.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_DISABLED)
	assert_almost_eq(Settings.get_value(&"render_scale"), 0.8, 0.01, "the preset's render scale")
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.MEDIUM, false)
	var kept := get_tree().get_nodes_in_group(GraphicsQuality.SHADOWED).filter(func(l: Light3D) -> bool: return l.shadow_enabled)
	assert_gt(kept.size(), 0, "Medium: the hall's column lamps")
	assert_true(env.sdfgi_enabled)
	Settings.set_value(&"graphics_quality", GraphicsQuality.Quality.HIGH, false)
	assert_almost_eq(env.ambient_light_energy, ambient, 0.001, "back to the recipe's ambient")
	for light in get_tree().get_nodes_in_group(GraphicsQuality.SHADOWED):
		assert_true((light as Light3D).shadow_enabled)
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_4X)
	assert_almost_eq(Settings.get_value(&"render_scale"), 1.0, 0.01)
