extends TestCase
## Floor I court art (docs/art/kit-pietro1-dziedziniec.md): every piece of
## the Great Court, Reading Room and entrance hall kit loads dressed, keeps
## its native size and triangle budget (ArtLibrary.KIT_COURT), the drum
## pieces share the drum-centre frame, glass casts no shadow, the markers
## gameplay reads are where the catalogue says, and ArtKit knows the three
## new room styles. (Godot axes: models face -Z.)


func _spawn(id: String, texture_set: String = "") -> Node3D:
	var node := ArtKit.model(id, texture_set)
	add_child(node)
	return node


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


func test_every_court_piece_loads_at_its_size_within_budget() -> void:
	assert_gt(ArtLibrary.KIT_COURT.size(), 40, "the court kit has its forty-odd pieces")
	for id: StringName in ArtLibrary.KIT_COURT:
		assert_true(ArtLibrary.KIT.has(id), "%s registered in KIT" % id)
		assert_true(ArtLibrary.has_model(id), "%s has a model file" % id)
		var node := _spawn(String(id))
		var entry: Array = ArtLibrary.KIT_COURT[id]
		var native: Vector3 = entry[0]
		var size := _bounds(node).size
		for axis in 3:
			assert_almost_eq(size[axis], native[axis], 0.05 + native[axis] * 0.02, "%s size on axis %d" % [id, axis])
		assert_lt(_triangles(node), int(entry[1]) + 1, "%s within its budget" % id)
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				assert_not_null(view.get_surface_override_material(i), "%s/%s dressed" % [id, view.name])
		node.queue_free()


func test_drum_pieces_share_the_drum_centre_frame() -> void:
	# outer face 12.26 m north of the centre, inner face 11.2, the crowning
	# cornice out to ~13.3 under the roof ring (r 13.0)
	var wall := _box_of("rr_drum_wall")
	assert_almost_eq(wall.end.z, -11.2, 0.02, "the drum wall's inner face")
	assert_almost_eq(wall.position.z, -13.31, 0.05, "the coping reaches under the roof ring")
	assert_almost_eq(wall.end.y, 21.65, 0.02, "the drum's top, where the roof ring sits")
	var books := _box_of("rr_bookcase")
	assert_almost_eq(books.position.z, -11.2, 0.02, "bookcases stand against the inner face")
	var dome := _box_of("rr_dome_sector")
	assert_almost_eq(dome.end.y, 19.87, 0.05, "the dome stops at the oculus")
	var roof := _box_of("court_roof_q")
	assert_almost_eq(roof.position.z, -30.35, 0.05, "the roof quarter reaches the north wall")
	assert_almost_eq(roof.end.y, 22.42, 0.05, "the roof rises to the drum ring")
	var balcony := _box_of("court_balcony_seg")
	assert_almost_eq(balcony.end.z, -12.26, 0.02, "the balcony leans on the drum face")


func _box_of(id: String) -> AABB:
	var node := _spawn(id)
	var box := _bounds(node)
	node.queue_free()
	return box


func test_glass_lets_the_moon_through() -> void:
	for pair: Array in [["court_roof_q", "court_roof_q_glass"], ["rr_oculus", "rr_oculus_glass"],
			["cafe_counter", "cafe_counter_glass"]]:
		var node := _spawn(pair[0])
		var glass := node.find_child(pair[1], true, false) as MeshInstance3D
		assert_not_null(glass, "%s has its glass" % pair[0])
		if glass != null:
			assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % pair[1])
		var steel := node.find_child(pair[0], true, false) as MeshInstance3D
		assert_ne(steel.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts the shadow" % pair[0])
		node.queue_free()


func test_markers_gameplay_reads() -> void:
	var astro := _spawn("astrolabe")
	var parts := ArtLibrary.parts(astro)
	for k in 6:
		var shard := parts.get("Shard_%d" % (k + 1)) as Node3D
		assert_not_null(shard, "shard cradle %d" % (k + 1))
		if shard != null:
			var p := shard.global_position
			assert_almost_eq(Vector2(p.x, p.z).length(), 1.5, 0.02, "cradle %d on the horizon ring" % (k + 1))
			assert_almost_eq(p.y, 2.57, 0.02, "cradle %d height" % (k + 1))
	assert_almost_eq((parts["Core"] as Node3D).global_position.y, 2.35, 0.02, "the core at the sphere's centre")
	for ring in ["ring_outer", "ring_middle", "ring_inner"]:
		assert_almost_eq((parts[ring] as Node3D).global_position.y, 2.35, 0.02, "%s pivots at the centre" % ring)
	astro.queue_free()
	var desk := _spawn("rr_desk")
	assert_eq(desk.find_children("Light_*", "Node3D", true, false).size(), 3, "three desk lamps")
	desk.queue_free()
	var door := _spawn("rr_drum_door")
	var lantern := door.find_child("Light_L", true, false) as Node3D
	assert_almost_eq(lantern.global_position.z, -12.76, 0.02, "lanterns hang outside the portal")
	door.queue_free()


func test_texture_sets_of_the_wayfinding() -> void:
	for id: StringName in [&"sign_wing", &"sign_wing_portal"]:
		assert_eq((ArtLibrary.KIT_SETS[id] as Array).size(), 5, "%s: five more wings" % id)
		for texture_set: String in ArtLibrary.KIT_SETS[id]:
			assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s painted" % texture_set)


func test_room_styles_and_pieces() -> void:
	for room: StringName in [&"court", &"reading_room", &"entrance"]:
		assert_true(ArtKit.ROOMS.has(room), "style %s" % room)
		assert_not_null(ArtKit.field(room, &"floor"), "%s floor field" % room)
		assert_not_null(ArtKit.field(room, &"wall"), "%s wall field" % room)
	# 3 m coffers in the entrance hall: a 9 x 6 m ceiling takes 3 x 2
	var ceiling := ArtKit.dress_ceiling(&"entrance", Vector2(9.0, 6.0))
	assert_eq(ceiling.get_child_count(), 6, "entrance coffers on the 3 m module")
	ceiling.free()
	var column := ArtKit.piece(&"column", Vector3(1.72, 12.0, 1.72), &"entrance")
	assert_not_null(column.find_child("entrance_column", true, false), "Doric columns in the entrance")
	column.free()
	var bench := ArtKit.piece(&"court_bench", Vector3(4.5, 0.47, 0.56), &"court")
	add_child(bench)
	assert_almost_eq(_bounds(bench).size.x, 4.5, 0.05, "a court piece named by its id fits its size")
	bench.queue_free()
