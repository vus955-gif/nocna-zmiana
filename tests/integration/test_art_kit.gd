extends TestCase
## Lobby architecture kit: every kit model loads dressed (baked pixel
## materials, tile fields, glass), keeps its triangle budget, pivot and
## facing (origin = centre of the base, front -Z, wall runs on the wall plane
## at z = 0 with nothing behind it), the texture sets and tile textures exist
## at 64 px/m, ArtKit fits runs, dresses walls and maps greybox pieces, and
## the light recipe builds. (Godot axes: models face -Z.)

## Triangle budgets by model id prefix (first match wins).
const BUDGETS := [
	# Floor I, Greek wing (prefixes unique to the wing; docs/art/kit-pietro1-grecja.md)
	["gr_column", 6000], ["gr_metope", 5000], ["gr_portal", 2500], ["gr_ped_", 9500], ["cast_", 4500],
	["nereid_", 17000], ["vase_", 2000],
	["hall_column", 8000], ["hall_arch", 2000], ["chandelier", 6000], ["grate_leaf", 6000], ["grate_frame", 4000],
	["hall_cornice", 3000], ["ticket_booth", 3500], ["info_desk", 3000], ["vent_grille", 3000],
	["stair_balustrade", 3000], ["balustrade", 2500], ["gallery_top", 2000], ["corridor_pipes", 2000],
	["bench_hall", 2000], ["weapon_rack", 1500], ["door_", 1200], ["hall_coffer", 300],
	["skylight", 1500], ["egypt_column", 4000], ["egypt_seal_door", 2500], ["khorsabad_gate", 26000], ["asy_tablet_shelf", 1500],
	["asia_eaves", 3500], ["asia_dado", 2200], ["asia_doorframe", 2400], ["asia_moon_gate", 1600],
	["asia_case", 1600], ["asia_lattice", 1400], ["teahouse", 4000], ["cherry_tree", 7000],
	["", 1200],
]
## Size of a free-standing piece: model -> Vector3 (x, y, z) it must fit.
const SIZES := {
	"hall_column": Vector3(2.0, 14.0, 2.0), "trex_pedestal": Vector3(12.25, 1.22, 6.25),
	"ticket_booth": Vector3(4.5, 2.8, 3.5), "info_desk": Vector3(8.0, 2.0, 3.0),
	"bench_hall": Vector3(3.0, 0.52, 0.7), "fuse_box": Vector3(1.0, 1.4, 0.8),
	"locker_05m": Vector3(0.5, 2.02, 0.56), "balcony_pier": Vector3(0.9, 5.6, 0.9),
	"balustrade_2m": Vector3(2.0, 1.1, 0.3),
}
## Pieces that are not symmetric about their origin in X (side fittings).
const OFF_CENTRE: Array[String] = ["fuse_box"]
## Wall runs: prefix -> [datum, height]; "floor" = rests on y 0, "top" =
## hangs from y 0, "centre" = straddles it.
const RUNS := {
	"hall_plinth_": ["floor", 1.0], "hall_upper_base_": ["floor", 0.35], "hall_string_": ["top", 0.45],
	"hall_cornice_": ["top", 1.5], "gallery_base_": ["floor", 1.21], "gallery_top_": ["top", 0.94],
	"skirting_": ["floor", 0.15], "diorama_base_": ["floor", 0.45], "armory_top_": ["top", 0.32],
	"diorama_top_": ["top", 0.7], "security_rail_": ["centre", 0.1], "corridor_pipes_": ["top", 0.6],
	"balcony_fascia_": ["top", 0.8],
	"asia_dado_": ["floor", 1.1], "asia_eaves_": ["top", 1.05], "asia_wallcap_": ["floor", 0.55],
}


func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _triangles(node: Node) -> int:
	var count := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


func _budget(id: String) -> int:
	if ArtLibrary.KIT_COURT.has(StringName(id)):
		return int(ArtLibrary.KIT_COURT[StringName(id)][1])
	if ArtLibrary.KIT_ENLIGHTENMENT.has(StringName(id)):
		return int(ArtLibrary.KIT_ENLIGHTENMENT[StringName(id)][1])
	if ArtLibrary.KIT_AMERICAS.has(StringName(id)):
		return int(ArtLibrary.KIT_AMERICAS[StringName(id)][1])
	for entry: Array in BUDGETS:
		if id.begins_with(entry[0]):
			return entry[1]
	return 1200


func _spawn(id: String, texture_set: String = "") -> Node3D:
	var node := ArtKit.model(id, texture_set)
	add_child(node)
	return node


func test_every_kit_model_loads_dressed_within_budget() -> void:
	assert_gt(ArtLibrary.KIT.size(), 100, "the kit has its hundred-odd pieces")
	for id: StringName in ArtLibrary.KIT:
		var node := _spawn(String(id))
		assert_not_null(node, String(id))
		if node == null:
			continue
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has meshes" % id)
		for child in meshes:
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				var mat := view.get_surface_override_material(i)
				assert_not_null(mat, "%s/%s surface %d dressed" % [id, view.name, i])
				var baked := mat as ORMMaterial3D
				if baked != null:
					assert_eq(baked.texture_filter, ArtLibrary.FILTER, "%s crisp texels" % id)
					assert_not_null(baked.albedo_texture, "%s albedo" % id)
					assert_not_null(baked.orm_texture, "%s orm" % id)
				var shader := mat as ShaderMaterial
				if shader != null:
					assert_true(shader.shader in [ArtLibrary.GLASS_SHADER, ArtLibrary.ARCH_TILE_SHADER], "%s: glass or a tile field" % id)
					if shader.shader == ArtLibrary.ARCH_TILE_SHADER:
						assert_not_null(shader.get_shader_parameter(&"albedo_tex"), "%s tile texture" % id)
		var found := ArtLibrary.parts(node)
		for part: String in ArtLibrary.KIT[id]:
			assert_true(found.has(part), "%s has part %s" % [id, part])
		assert_lt(_triangles(node), _budget(String(id)) + 1, "%s within its triangle budget" % id)
		node.queue_free()


func test_texture_sets_swap_onto_the_same_mesh() -> void:
	for id: StringName in ArtLibrary.KIT_SETS:
		for texture_set: String in ArtLibrary.KIT_SETS[id]:
			var node := _spawn(String(id), texture_set)
			var names := {}
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var view := child as MeshInstance3D
				for i in view.mesh.get_surface_count():
					var mat := view.get_surface_override_material(i)
					if mat != null:
						names[mat.resource_name] = true
			assert_true(names.has(texture_set), "%s wears %s" % [id, texture_set])
			assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s albedo exists" % texture_set)
			node.queue_free()


func test_room_fields_are_64_px_per_metre_tiles_on_the_half_metre_grid() -> void:
	for room: StringName in ArtKit.ROOMS:
		var style := ArtKit.style(room)
		for role in ["wall", "wall_upper", "floor", "ceiling", "reveal", "threshold", "stair", "well"]:
			if not style.has(role):
				continue
			var tex := ArtLibrary.texture(String(style[role]), "albedo")
			assert_not_null(tex, "%s %s texture %s" % [room, role, style[role]])
			if tex == null:
				continue
			var metres := Vector2(tex.get_width(), tex.get_height()) / 64.0
			assert_almost_eq(fmod(metres.x, 0.5), 0.0, 0.001, "%s tiles on the 0.5 m grid (x)" % style[role])
			assert_almost_eq(fmod(metres.y, 0.5), 0.0, 0.001, "%s tiles on the 0.5 m grid (y)" % style[role])
			assert_not_null(ArtLibrary.texture(String(style[role]), "normal"), "%s normal map" % style[role])
			var mat := ArtKit.field(room, StringName(role)) as ShaderMaterial
			assert_not_null(mat, "%s %s field material" % [room, role])


func test_wall_runs_sit_on_the_wall_plane_with_their_datum_at_the_origin() -> void:
	for prefix: String in RUNS:
		var sizes: Array = ArtKit.RUN_SIZES.get(prefix, ArtKit.RUN)
		for w: float in sizes:
			var id := prefix + String(ArtKit.RUN_TAG[w])
			var node := _spawn(id)
			var box := _bounds(node)
			var spec: Array = RUNS[prefix]
			assert_almost_eq(box.size.x, w, 0.03, "%s spans its length" % id)
			assert_almost_eq(box.get_center().x, 0.0, 0.02, "%s centred on its origin" % id)
			assert_lt(box.end.z, 0.2 if prefix == "balcony_fascia_" else 0.005, "%s: nothing behind the wall plane" % id)
			assert_lt(box.position.z, -0.01, "%s decorated on the room side (-Z)" % id)
			match spec[0]:
				"floor":
					assert_almost_eq(box.position.y, 0.0, 0.01, "%s rests on its datum" % id)
					assert_almost_eq(box.end.y, spec[1], 0.03, "%s height" % id)
				"top":
					assert_almost_eq(box.end.y, 0.0, 0.01, "%s hangs from its datum" % id)
					assert_almost_eq(box.position.y, -float(spec[1]), 0.12, "%s height" % id)
				"centre":
					assert_almost_eq(box.get_center().y, 0.0, 0.01, "%s centred on its datum" % id)
			node.queue_free()


func test_free_standing_pieces_are_centred_on_the_floor_and_face_minus_z() -> void:
	for id: String in SIZES:
		if not ArtLibrary.KIT.has(StringName(id)):
			continue
		var node := _spawn(id)
		var box := _bounds(node)
		var size: Vector3 = SIZES[id]
		assert_almost_eq(box.position.y, 0.0, 0.02, "%s stands on the floor" % id)
		assert_lt(box.size.x, size.x + 0.02, "%s width" % id)
		assert_lt(box.size.y, size.y + 0.02, "%s height" % id)
		assert_lt(box.size.z, size.z + 0.02, "%s depth" % id)
		if not OFF_CENTRE.has(id):
			assert_lt(absf(box.get_center().x), 0.05 * size.x + 0.02, "%s centred in x" % id)
		node.queue_free()
	var column := _spawn("hall_column")
	assert_almost_eq(_bounds(column).end.y, 14.0, 0.02, "the grand column reaches the 14 m ceiling")
	column.queue_free()
	# the front is -Z: the fuse box lever and lamps, the booth's drawer and
	# the plaque's face all stand on the -Z side
	var fuse := _spawn("fuse_box")
	var parts := ArtLibrary.parts(fuse)
	assert_lt((parts["lamp_red"] as Node3D).global_position.z, -0.1, "fuse box lamp on the front")
	# seen from the front (looking along +Z) the viewer's right is -X
	assert_lt((parts["lever"] as Node3D).global_position.x, -0.3, "lever on the right-hand side")
	fuse.queue_free()
	var booth := _spawn("ticket_booth")
	assert_lt((ArtLibrary.parts(booth)["drawer"] as Node3D).global_position.z, -1.4, "ticket drawer at the front")
	booth.queue_free()
	var plaque := _spawn("plaque_trex")
	var pb := _bounds(plaque)
	assert_almost_eq(pb.end.z, 0.0, 0.005, "plaque back on the face it hangs on")
	assert_lt(pb.position.z, -0.01, "plaque face toward -Z")
	plaque.queue_free()


func test_stairs_pieces_match_the_lobby_flights() -> void:
	var step := _spawn("stair_step_4m")
	var sb := _bounds(step)
	assert_almost_eq(sb.end.y, LobbyLayout.STAIRS_RISE, 0.002, "step rise 0.15")
	assert_almost_eq(sb.position.z, -0.4, 0.01, "tread 0.40 runs up the flight (-Z)")
	assert_gt(sb.end.z, 0.02, "nosing overhangs the riser")
	step.queue_free()
	var stringer := _spawn("stair_stringer_4m")
	var gb := _bounds(stringer)
	assert_almost_eq(gb.size.z, 4.0, 0.02, "stringer module covers 4 m of run")
	assert_almost_eq(gb.size.y, 1.5 + 0.47, 0.03, "rises 1.5 m (10 steps) over it")
	stringer.queue_free()
	# the grand flights in the hall: 40 steps of 0.15 x 0.40 (the stairs down
	# behind the grate are wide too, but short: not part of this check)
	var layout := LobbyLayout.create()
	var grand := 0
	for flight in layout.stairs:
		if flight.width() < 3.0 or flight.room_low != &"hall":
			continue
		grand += 1
		assert_eq(flight.step_count(), 40, "grand flight has 40 steps")
		assert_almost_eq(flight.run() / flight.step_count(), 0.4, 0.001, "tread 0.40")
		var node := ArtKit.stairs(flight.width(), flight.top_y - flight.bottom_y, flight.run(), flight.step_count(), flight.rail_left, flight.rail_right)
		add_child(node)
		var nb := _bounds(node)
		assert_almost_eq(nb.end.y, 7.0, 0.3, "balustrade over the top step")
		assert_lt(nb.position.z, -15.9, "reaches the top of the run")
		node.queue_free()
	assert_eq(grand, 2, "both grand flights (west and east) checked")


func test_fill_run_and_free_spans() -> void:
	var exact := ArtKit.fill_run(7.5, [4.0, 2.0, 1.0, 0.5])
	var total := 0.0
	for m: Array in exact:
		assert_eq(float(m[2]), 1.0, "exact lengths are not stretched")
		total += float(m[0]) * float(m[2])
	assert_almost_eq(total, 7.5, 0.001)
	var odd := ArtKit.fill_run(22.15, [2.0, 1.0])
	var sum := 0.0
	for m: Array in odd:
		assert_lt(absf(float(m[2]) - 1.0), ArtKit.MAX_STRETCH + 0.001, "stretch stays small")
		sum += float(m[0]) * float(m[2])
	assert_almost_eq(sum, 22.15, 0.001, "runs fill the length exactly")
	var spans := ArtKit.free_spans(10.0, [[2.0, 4.0], [6.0, 6.1]])
	assert_eq(spans.size(), 3)
	assert_almost_eq(float(spans[1][0]), 4.0, 0.001)


func test_dress_wall_cuts_the_base_at_doors_and_bridges_them_at_the_top() -> void:
	var face := {"room": &"gallery", "length": 12.0, "height": 7.0, "openings": [[4.0, 8.0, 0.0, 4.5]]}
	var node := ArtKit.dress_wall(face)
	add_child(node)
	var base_over_door := false
	var top_over_door := false
	for child in node.get_children():
		var n := child as Node3D
		var box := _bounds(n)
		if box.position.x < 7.9 and box.end.x > 4.1:
			if box.position.y < 1.0:
				base_over_door = true
			if box.position.y > 5.0:
				top_over_door = true
	assert_false(base_over_door, "no wainscot across the doorway")
	assert_true(top_over_door, "the cornice runs over the doorway")
	var hall := ArtKit.dress_wall({"room": &"hall", "length": 26.0, "height": 14.0, "openings": [],
		"soffits": [[0.0, 26.0, 5.6]], "balcony": [[0.0, 26.0]]})
	add_child(hall)
	var string_top := -INF
	for child in hall.get_children():
		if String(child.name).begins_with("hall_string"):
			string_top = maxf(string_top, _bounds(child).end.y)
	assert_almost_eq(string_top, 5.6, 0.02, "the string course drops under the balcony slab")
	node.queue_free()
	hall.queue_free()


func test_pieces_map_greybox_kit_ids() -> void:
	for kit in [&"column", &"pedestal", &"balcony_post", &"railing", &"ticket_booth", &"info_desk", &"bench",
			&"fuse_box", &"lockers", &"painting", &"grate", &"false_panel", &"painting_panel", &"vent_grille",
			&"skylight", &"rock", &"fence", &"sconce", &"exit_sign", &"emergency_lamp", &"tube_lamp",
			&"ceiling_lamp", &"column_lamp", &"bulb", &"desk_lamp"]:
		var size := Vector3(3.0, 2.0, 0.08) if kit == &"painting" else Vector3(1.6, 14.0, 1.6) if kit == &"column" else Vector3(12, 1.2, 6) if kit == &"pedestal" else Vector3(3.0, 1.1, 0.5)
		var node := ArtKit.piece(kit, size, &"hall")
		assert_not_null(node, "art for %s" % kit)
		if node != null:
			node.free()
	assert_true(ArtKit.piece(&"terminal", Vector3.ONE, &"hall") == null, "no art: keep the greybox")
	for kit in [&"crate", &"desk", &"chair", &"shelf", &"armor_rack", &"bust_plinth", &"plinth", &"sculpture",
			&"case", &"crystal_case", &"plaque", &"cctv_wall", &"weapon_rack", &"banner", &"dead_tree", &"sign_hall"]:
		var prop := ArtKit.piece(kit, Vector3(1.2, 1.8, 1.2), &"gallery")
		assert_not_null(prop, "art for %s" % kit)
		if prop != null:
			prop.free()
	var crystal := ArtKit.piece(&"crystal_case", Vector3(1.2, 1.8, 1.2), &"hall")
	var panes := crystal.find_children("*", "MeshInstance3D", true, false).filter(func(v: MeshInstance3D) -> bool:
		return v.material_override is BaseMaterial3D and (v.material_override as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_gt(panes.size(), 0, "the crystal's case has glass the game can shatter")
	crystal.free()
	var ped := ArtKit.piece(&"pedestal", Vector3(12, 1.2, 6), &"hall")
	add_child(ped)
	var pb := _bounds(ped)
	assert_almost_eq(pb.size.x, 12.24, 0.05, "pedestal fitted to its kit size")
	assert_almost_eq(pb.end.y, 1.21, 0.02, "pedestal top at 1.2 m (the T-Rex stands on it)")
	ped.queue_free()
	var frames := ArtKit.passage(4.0, 4.5, 2.0, &"hall", &"gallery")
	assert_not_null(frames, "wing doorway frames")
	if frames != null:
		assert_eq(frames.get_child_count(), 3, "hall arch, reveal, gallery architrave")
		frames.free()
	var leaf := ArtKit.leaf(&"door_leaf", Vector3(2.0, 4.5, 0.12), OpeningSpec.DoorStyle.DOUBLE_SWING, 1.0, &"hall")
	assert_true(leaf.get_child(0).scene_file_path.ends_with("door_grand_leaf_l.glb"), "hinged at -X: the left leaf")
	leaf.free()


func test_light_recipe_builds_environment_fog_and_probes() -> void:
	var world := LobbyLightRecipe.make_environment()
	var env := world.environment
	assert_true(env.sdfgi_enabled, "SDFGI")
	assert_eq(env.sdfgi_cascades, 4)
	assert_true(env.volumetric_fog_enabled and env.volumetric_fog_density == 0.0, "fog only in volumes")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX)
	world.free()
	var moon := LobbyLightRecipe.make_moon()
	assert_gt(moon.light_volumetric_fog_energy, 5.0, "the moon lights the fog")
	assert_gt(moon.basis.z.y, 0.0, "shines downward (light travels along -Z)")
	moon.free()
	var box := AABB(Vector3(-18, 0, -22), Vector3(36, 14, 44))
	var fog := LobbyLightRecipe.make_fog(&"hall", box)
	assert_almost_eq(fog.size.x, 36.0, 0.01)
	assert_gt((fog.material as FogMaterial).density, 0.0)
	fog.free()
	var probe := LobbyLightRecipe.make_probe(&"hall", box)
	assert_not_null(probe, "the marble hall has a probe")
	if probe != null:
		assert_true(probe.box_projection and probe.interior)
		probe.free()
	assert_true(LobbyLightRecipe.make_probe(&"armory", box) == null, "no probe on flagstones")
	var lamp := OmniLight3D.new()
	assert_true(LobbyLightRecipe.tune(lamp, &"column_lamp", &"hall", 0), "column lamps may cast shadows")
	assert_false(LobbyLightRecipe.tune(lamp, &"column_lamp", &"hall", 99), "until the room's budget is spent")
	assert_lt(lamp.light_volumetric_fog_energy, 0.5, "lamps barely light the fog")
	lamp.free()


func test_preview_dresses_the_whole_lobby() -> void:
	var preview := (load("res://src/style/lobby_kit_preview.tscn") as PackedScene).instantiate() as LobbyKitPreview
	preview.with_player = false
	add_child(preview)
	var stats := preview.stats()
	assert_gt(stats["meshes"], 1500, "the lobby is dressed")
	assert_lt(stats["triangles"], 1500000, "and stays within a sane triangle count")
	assert_gt(preview.main_lights.size(), 40, "layout lamps plus recipe extras")
	for kit in [&"column", &"pedestal", &"ticket_booth", &"info_desk", &"railing", &"balcony_post", &"fuse_box", &"grate", &"lockers", &"painting", &"rock", &"fence"]:
		assert_false(preview.greybox_kits.has(kit), "%s is dressed with the kit" % kit)
	preview.queue_free()
	await get_tree().process_frame
