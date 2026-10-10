extends TestCase
## Floor I Enlightenment wing art (docs/art/kit-pietro1-oswiecenie.md): every
## piece of the King's Library and cabinets kit loads dressed at its native
## size within its triangle budget (ArtLibrary.KIT_ENLIGHTENMENT), the Great
## Orrery's rig (three tiers on the axis at their heights, six planets on
## their tiers, the opening sun) and the flying book's hinges are where the
## catalogue says, the gameplay markers (weapon_spot, terminal_spot, the
## diorama's animal spots, lamp lights) are in place, and ArtKit knows the
## wing's room styles. (Godot axes: models face -Z.)


func _xf(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != root and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _bounds(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := _xf(mesh, root) * mesh.get_aabb()
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
			count += index.size() / 3
	return count


func _at(root: Node, name: String) -> Vector3:
	var node := root.find_child(name, true, false)
	assert_not_null(node, "node %s" % name)
	return _xf(node, root).origin if node != null else Vector3.INF


func test_every_piece_loads_at_its_size_within_budget() -> void:
	assert_gt(ArtLibrary.KIT_ENLIGHTENMENT.size(), 50, "the wing's kit has its fifty-odd pieces")
	for id: StringName in ArtLibrary.KIT_ENLIGHTENMENT:
		assert_true(ArtLibrary.KIT.has(id), "%s registered in KIT" % id)
		assert_true(ArtLibrary.has_model(id), "%s has a model file" % id)
		var node := ArtKit.model(String(id))
		var entry: Array = ArtLibrary.KIT_ENLIGHTENMENT[id]
		var native: Vector3 = entry[0]
		var size := _bounds(node).size
		for axis in 3:
			assert_almost_eq(size[axis], native[axis], 0.05 + native[axis] * 0.02, "%s size on axis %d" % [id, axis])
		assert_lt(_triangles(node), int(entry[1]) + 1, "%s within its budget" % id)
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				assert_not_null(view.get_surface_override_material(i), "%s/%s dressed" % [id, view.name])
		var found := ArtLibrary.parts(node)
		for part: String in ArtLibrary.KIT[id]:
			assert_true(found.has(part), "%s has %s" % [id, part])
		node.free()


func test_texture_sets_exist() -> void:
	for id: StringName in [&"lib_bookcase_a_2m", &"lib_bookcase_b_2m", &"lib_bookcase_c_2m", &"lib_cornice_4m",
			&"lib_portal_4x4_5", &"lib_sign"]:
		for texture_set: String in ArtLibrary.KIT_SETS[id]:
			assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s albedo" % texture_set)
	for texture_set: String in ArtLibrary.ENLIGHTENMENT_SETS[&"flying_book"]:
		assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s albedo" % texture_set)
		assert_not_null(ArtLibrary.texture(texture_set, "emit"), "%s eyes glow" % texture_set)
	for tile: String in ["parquet_chevron", "enl_mahogany", "enl_bookside", "enl_oak_boards"]:
		var tex := ArtLibrary.texture(tile, "albedo")
		assert_not_null(tex, "tile %s" % tile)
		if tex != null:
			assert_almost_eq(fmod(tex.get_width() / 64.0, 0.5), 0.0, 0.001, "%s on the 0.5 m grid" % tile)


func test_orrery_rig() -> void:
	var orrery := ArtLibrary.instance(&"planetarium")
	for part: String in ArtLibrary.REGISTRY[&"planetarium"]:
		assert_not_null(orrery.find_child(part, true, false), "orrery has %s" % part)
	var heights := {"tier_low": 0.45, "tier_mid": 1.6, "tier_high": 2.8}
	for tier: String in heights:
		var at := _at(orrery, tier)
		assert_almost_eq(Vector2(at.x, at.z).length(), 0.0, 0.001, "%s pivots on the axis" % tier)
		assert_almost_eq(at.y, float(heights[tier]), 0.01, "%s height" % tier)
	var planet_tier := {1: "tier_low", 2: "tier_low", 3: "tier_mid", 4: "tier_mid", 5: "tier_high", 6: "tier_high"}
	for k: int in planet_tier:
		var planet := orrery.find_child("planet_%d" % k, true, false)
		assert_eq(String(planet.get_parent().name), planet_tier[k], "planet_%d rides %s" % [k, planet_tier[k]])
		assert_true(_at(orrery, "socket_%d" % k).is_equal_approx(_at(orrery, "planet_%d" % k)), "socket_%d" % k)
	# the low arm can be jumped (its girder's top under 0.6 m away from the planet rods), the
	# high arm leaves head room (its girder's underside over 2.6 m)
	var low := _bounds_of_part(orrery, "tier_low")
	assert_gt(low.size.x, 9.5, "the low arm sweeps 10 m")
	assert_almost_eq(_at(orrery, "sun_core").y, 5.0, 0.01, "the sun's core")
	var saturn := _bounds_of_part(orrery, "planet_6")
	assert_gt(maxf(saturn.size.x, saturn.size.z), saturn.size.y * 1.4, "Saturn wears its rings")
	assert_lt(_triangles(orrery), 16000, "the orrery within its budget")
	orrery.free()


func _bounds_of_part(root: Node, part: String) -> AABB:
	var mesh := root.find_child(part, true, false) as MeshInstance3D
	return _xf(mesh, root) * mesh.get_aabb()


func test_flying_book_hinges_and_eyes() -> void:
	var book := ArtLibrary.exhibit(&"flying_book", {"flying_book": "flying_book_green"})
	assert_not_null(book, "the flying book loads as an exhibit")
	var l := _at(book, "cover_l")
	var r := _at(book, "cover_r")
	assert_almost_eq(l.x, -0.026, 0.002, "left hinge")
	assert_almost_eq(r.x, 0.026, 0.002, "right hinge")
	assert_eq(String(book.find_child("cover_l", true, false).get_parent().name), "body", "covers hang on the spine")
	assert_lt(_at(book, "eye_l").z, -0.03, "the eyes look forward (-Z)")
	assert_lt(_triangles(book), 800, "a light enemy")
	var size := _bounds(book).size
	assert_almost_eq(size.y, 0.33, 0.02, "a quarto, 0.33 m")
	book.free()


func test_gameplay_markers() -> void:
	var rack := ArtLibrary.model("lib_rifle_rack")
	var spot := _at(rack, "weapon_spot")
	assert_almost_eq(spot.y, 1.55, 0.02, "the rifle lies at chest height")
	assert_gt(_at(rack, "Light").y, 2.0, "the picture lamp over the opening")
	assert_lt(_at(rack, "Light").z, -0.3, "hanging out in front of the cabinet")
	rack.free()
	var desk := ArtLibrary.model("lib_office_desk")
	assert_almost_eq(_at(desk, "terminal_spot").y, 0.76, 0.01, "terminal on the desk top")
	desk.free()
	var base := ArtLibrary.model("lib_diorama_base")
	assert_almost_eq(_at(base, "animal_spot_1").y, 0.33, 0.01, "the wolf's ground")
	assert_almost_eq(_at(base, "animal_spot_2").y, 0.33, 0.01, "the raptor's ground")
	base.free()
	for lamp: String in ["lib_lamp_reading", "lib_lamp_wall", "lib_lamp_pendant", "lib_lamp_standard"]:
		var node := ArtLibrary.model(lamp)
		assert_true(_at(node, "Light").is_equal_approx(Vector3.ZERO), "%s: light at the origin" % lamp)
		assert_not_null(ArtLibrary.texture(lamp, "emit"), "%s glows" % lamp)
		node.free()
	var stair := ArtLibrary.model("lib_stair_spiral")
	assert_almost_eq(_at(stair, "stair_top").y, 4.0, 0.01, "the spiral reaches the walkway")
	stair.free()


func test_room_styles() -> void:
	for room: StringName in [&"enlightenment_library", &"enlightenment_cabinet", &"enlightenment_portraits",
			&"enlightenment_clocks", &"enlightenment_librarian", &"enlightenment_planetarium"]:
		assert_true(ArtKit.ROOMS.has(room), "style %s" % room)
		var s := ArtKit.style(room)
		for role in ["wall", "floor", "ceiling", "reveal"]:
			assert_not_null(ArtLibrary.texture(String(s[role]), "albedo"), "%s %s field" % [room, role])
	var cornice := ArtKit.dress_wall({"room": &"enlightenment_library", "length": 14.0, "height": 10.0})
	assert_gt(cornice.get_child_count(), 0, "the library's walls get their cornice")
	cornice.free()
	var piece := ArtKit.piece(&"lib_globe_terrestrial", Vector3(1.18, 1.45, 1.18), &"enlightenment_cabinet")
	assert_not_null(piece, "pieces named by their model id are dressed")
	if piece != null:
		piece.free()
