extends TestCase
## Floor I Americas and Oceania wing art (docs/art/kit-pietro1-ameryki.md):
## every kit piece and decor exhibit loads dressed at its native size within
## its triangle budget (ArtLibrary.KIT_AMERICAS), the Totem's stacked faces
## (a chain, eyes, face and mouth markers), the jaguar warrior's joints, the
## Two-headed Serpent's segment chain with its plating and hinged heads, the
## moai on its turntable with the ring at its back, the war canoe's rig and
## rings, the whaling display's weapon spots, the fire fixtures' lights and
## the wing's room styles. (Godot axes: models face -Z.)


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


func _parent_is(root: Node, part: String, parent: String) -> bool:
	var child := root.find_child(part, true, false)
	return child != null and child.get_parent() != null and String(child.get_parent().name) == parent


func test_every_piece_loads_at_its_size_within_budget() -> void:
	assert_gt(ArtLibrary.KIT_AMERICAS.size(), 40, "the wing's kit has its forty-odd pieces")
	for id: StringName in ArtLibrary.KIT_AMERICAS:
		assert_true(ArtLibrary.KIT.has(id), "%s registered in KIT" % id)
		assert_true(ArtLibrary.has_model(id), "%s has a model file" % id)
		var node := ArtKit.model(String(id))
		var entry: Array = ArtLibrary.KIT_AMERICAS[id]
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


func test_tiles_and_texture_sets() -> void:
	for tile: String in ["am_red_wall", "am_frieze", "am_stone_blocks", "basalt_americas", "am_woven_mat",
			"boards_pacific", "am_tapa", "am_ceiling"]:
		var tex := ArtLibrary.texture(tile, "albedo")
		assert_not_null(tex, "tile %s" % tile)
		if tex != null:
			assert_almost_eq(fmod(tex.get_width() / 64.0, 0.5), 0.0, 0.001, "%s on the 0.5 m grid" % tile)
	assert_eq(ArtLibrary.texture("am_frieze", "albedo").get_height(), 64, "the frieze tile is one metre tall")
	for texture_set: String in ArtLibrary.KIT_SETS[&"tapa_hanging"]:
		assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s print" % texture_set)


func test_wall_runs_and_temple_frames() -> void:
	var dado := ArtKit.model("americas_dado_4m")
	var d := _bounds(dado)
	assert_almost_eq(d.position.y, 0.0, 0.01, "the dado stands on the floor")
	assert_lt(d.end.z, 0.005, "nothing behind the wall plane")
	dado.free()
	var cornice := ArtKit.model("americas_cornice_4m")
	assert_almost_eq(_bounds(cornice).end.y, 0.0, 0.01, "the cornice hangs from the ceiling datum")
	cornice.free()
	var frieze := ArtKit.model("americas_frieze_4m")
	var tile := false
	for child in frieze.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i) as ShaderMaterial
			tile = tile or (mat != null and mat.shader == ArtLibrary.ARCH_TILE_SHADER)
	assert_true(tile, "the frieze face is the world-mapped carved band")
	frieze.free()
	var tier := ArtKit.model("temple_tier_4m")
	var tb := _bounds(tier)
	assert_almost_eq(tb.end.y, 1.5, 0.01, "a terrace face is 1.5 m, its coping flush with the top")
	assert_lt(tb.position.z, -0.45, "the talud reaches out from the box face")
	tier.free()
	var stair := ArtKit.model("temple_stair")
	var sb := _bounds_of(stair, "temple_stair")
	assert_almost_eq(sb.end.y, 2.16, 0.05, "the balustrades' crowns over the 1.5 m flight")
	assert_lt(sb.position.z, -3.9, "the flight climbs toward -Z")
	assert_gt(_bounds(stair).end.z, 0.5, "the serpent heads look out from the foot")
	stair.free()
	for id in ["temple_shrine", "americas_brazier", "americas_torch_lamp"]:
		var node := ArtLibrary.model(id)
		assert_not_null(node.find_child("Light", true, false), "%s has a Light marker" % id)
		node.free()
	var brazier := ArtLibrary.model("americas_brazier")
	assert_almost_eq(_at(brazier, "Light").y, 1.3, 0.01, "the fire's light where the greybox puts it")
	assert_true(_parent_is(brazier, "flame", "americas_brazier"), "the flame is its own part")
	brazier.free()


func test_totem_stacks_its_faces() -> void:
	var totem := ArtLibrary.instance(&"totem")
	assert_true(_parent_is(totem, "block_1", "totem"), "the first face sits on the stump")
	for k in range(2, 6):
		assert_true(_parent_is(totem, "block_%d" % k, "block_%d" % (k - 1)), "block %d on block %d" % [k, k - 1])
	for k in range(1, 6):
		assert_true(_parent_is(totem, "eyes_%d" % k, "block_%d" % k), "eyes %d in their face" % k)
		assert_true(_parent_is(totem, "face_%d" % k, "block_%d" % k), "face marker %d" % k)
		assert_true(_parent_is(totem, "mouth_%d" % k, "block_%d" % k), "mouth marker %d" % k)
		var pivot := _at(totem, "block_%d" % k)
		assert_almost_eq(pivot.y, 0.35 + 0.85 * (k - 1), 0.01, "block %d pivots at its bottom" % k)
		assert_lt(_at(totem, "mouth_%d" % k).z, -0.5, "mouth %d in front" % k)
		var face := _at(totem, "face_%d" % k)
		assert_gt(face.y, pivot.y, "face %d above its pivot" % k)
		assert_lt(face.y, pivot.y + 0.85, "face %d inside its block" % k)
	assert_almost_eq(_at(totem, "cap").y, 4.6, 0.01, "the hat rests on the fifth face")
	assert_true(_parent_is(totem, "cap", "totem"), "the hat can slide down the stump's child list")
	var b := _bounds(totem)
	assert_almost_eq(b.end.y, 5.14, 0.08, "about 5.1 m with the hat")
	assert_lt(_triangles(totem), 8000, "totem budget")
	totem.free()


func test_jaguar_warrior_joints() -> void:
	var jag := ArtLibrary.instance(&"jaguar")
	var chains := {"torso": "pelvis", "head": "torso", "arm_l": "torso", "arm_r": "torso", "forearm_l": "arm_l",
		"forearm_r": "arm_r", "club": "forearm_r", "shield": "forearm_l", "thigh_l": "pelvis", "thigh_r": "pelvis",
		"shin_l": "thigh_l", "shin_r": "thigh_r", "foot_l": "shin_l", "foot_r": "shin_r", "tail_1": "pelvis",
		"tail_2": "tail_1", "face": "head", "club_tip": "club"}
	for part: String in chains:
		assert_true(_parent_is(jag, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	var b := _bounds(jag)
	assert_gt(b.end.y, 1.75, "about 1.8 m")
	assert_lt(b.end.y, 1.92, "about 1.8 m")
	assert_almost_eq(b.position.y, 0.0, 0.03, "feet on the floor")
	assert_almost_eq(_at(jag, "pelvis").y, 0.95, 0.01, "hips at 0.95 m")
	assert_lt(_at(jag, "face").z, -0.1, "the face looks out of the maw, forward")
	assert_lt(_at(jag, "arm_l").x, 0.0, "left arm on -X")
	assert_gt(_at(jag, "club").x, 0.0, "club in the right hand")
	assert_lt(_at(jag, "club_tip").y, 0.2, "the club hangs down at rest")
	assert_lt(_triangles(jag), 11000, "jaguar budget")
	jag.free()


func test_two_headed_serpent_rig() -> void:
	var snake := ArtLibrary.instance(&"serpent")
	assert_eq(String(snake.find_child("segment_1", true, false).get_parent().name), String(snake.name),
		"segment_1 is the root")
	for k in range(2, 15):
		assert_true(_parent_is(snake, "segment_%d" % k, "segment_%d" % (k - 1)), "segment %d chained" % k)
	for k in range(1, 15):
		assert_true(_parent_is(snake, "tiles_%d" % k, "segment_%d" % k), "plating %d rides its segment" % k)
		assert_true(_parent_is(snake, "seg_%d" % k, "segment_%d" % k), "seg_%d marker" % k)
		assert_almost_eq(_at(snake, "segment_%d" % k).z, -5.25 + 0.75 * (k - 1), 0.01, "segment %d pivot" % k)
		var tiles := _bounds_of(snake, "tiles_%d" % k)
		var core := _bounds_of(snake, "segment_%d" % k)
		# (only the gold band at the joint stands 1.2 cm proud of the plating)
		assert_gt(tiles.end.y, core.end.y - 0.03, "plating %d covers its core" % k)
		assert_gt(tiles.size.x, core.size.x - 0.06, "plating %d wraps the flanks" % k)
	assert_true(_parent_is(snake, "skull_a", "segment_1"), "head A on the first segment")
	assert_true(_parent_is(snake, "skull_b", "segment_14"), "head B on the last")
	assert_true(_parent_is(snake, "jaw_a", "skull_a"), "jaw A hinged in head A")
	assert_true(_parent_is(snake, "jaw_b", "skull_b"), "jaw B hinged in head B")
	assert_lt(_at(snake, "mouth_a").z, -6.8, "head A looks -Z")
	assert_gt(_at(snake, "mouth_b").z, 6.8, "head B looks +Z")
	assert_true(_parent_is(snake, "head_a", "skull_a"), "head_a marker in the skull")
	assert_true(_parent_is(snake, "mouth_b", "skull_b"), "mouth_b marker in the skull")
	var b := _bounds(snake)
	assert_gt(b.size.z, 13.5, "about 14 m long")
	assert_lt(b.size.z, 15.0, "about 14 m long")
	assert_gt(b.position.y, -0.06, "lies on the floor")
	assert_lt(_triangles(snake), 20000, "serpent budget")
	snake.free()


func _bounds_of(root: Node, part: String) -> AABB:
	var mesh := root.find_child(part, true, false) as MeshInstance3D
	return _xf(mesh, root) * mesh.get_aabb()


func test_moai_turns_on_its_plinth() -> void:
	var moai := ArtLibrary.instance(&"moai")
	assert_true(_parent_is(moai, "moai", "moai_plinth"), "the head stands on its plinth")
	var pivot := _at(moai, "moai")
	assert_almost_eq(pivot.y, 1.2, 0.01, "the turntable on the plinth top")
	assert_almost_eq(Vector2(pivot.x, pivot.z).length(), 0.0, 0.001, "turns about the plinth's axis")
	assert_true(_parent_is(moai, "hook_ring", "moai"), "the ring turns with the head")
	assert_gt(_at(moai, "hook_ring").z, 0.8, "the ring at the back (+Z)")
	assert_lt(_at(moai, "face").z, -0.2, "the face looks -Z")
	var b := _bounds(moai)
	assert_almost_eq(b.end.y, 3.73, 0.05, "2.45 m of statue over the 1.2 m plinth")
	moai.free()


func test_war_canoe_rig() -> void:
	var canoe := ArtLibrary.instance(&"war_canoe")
	assert_true(_parent_is(canoe, "sling", "war_canoe"), "the sling rides the canoe")
	assert_true(_parent_is(canoe, "rope_main", "sling"), "the main rope rides the sling")
	assert_true(_parent_is(canoe, "rope_top", "rope_main"), "rope_top at the rope's end")
	assert_almost_eq(_at(canoe, "rope_main").y, 2.6, 0.01, "the rope's pivot at its bottom (the beam)")
	assert_lt(_at(canoe, "hook_ring").z, -6.0, "the bow ring at the -Z end")
	assert_gt(_at(canoe, "hook_ring_stern").z, 6.0, "the stern ring")
	assert_almost_eq(_at(canoe, "deck").y, 0.5, 0.01, "the walking deck")
	var b := _bounds(canoe)
	assert_gt(b.size.z, 12.0, "a 12 m hull")
	assert_almost_eq(b.position.y, 0.0, 0.02, "keel at the origin")
	assert_lt(_triangles(canoe), 9000, "canoe budget")
	canoe.free()


func test_whaling_display_holds_the_harpoon() -> void:
	var rack := ArtLibrary.instance(&"whaling_rack")
	var spot := _at(rack, "weapon_spot")
	assert_almost_eq(spot.y, 0.62, 0.02, "the cradle in the rack")
	assert_lt(spot.z, -0.1, "in front of the board")
	assert_lt(_bounds(rack).end.z, 0.005, "the rack hangs on the wall plane")
	rack.free()
	var stand := ArtLibrary.instance(&"harpoon_stand")
	assert_almost_eq(_at(stand, "weapon_spot").y, 1.06, 0.01, "on the fork")
	stand.free()


func test_room_styles() -> void:
	for room: StringName in [&"americas_temple", &"americas_north", &"americas_totems", &"americas_moai",
			&"americas_pacific", &"americas_pit", &"americas_moai_hideout", &"americas_workshop"]:
		assert_true(ArtKit.ROOMS.has(room), "style %s" % room)
		var s := ArtKit.style(room)
		for role in ["wall", "floor", "ceiling", "reveal"]:
			assert_not_null(ArtLibrary.texture(String(s[role]), "albedo"), "%s %s field" % [room, role])
	var wall := ArtKit.dress_wall({"room": &"americas_temple", "length": 12.0, "height": 12.0})
	assert_gt(wall.get_child_count(), 0, "the temple's walls get their bands")
	wall.free()
	var piece := ArtKit.piece(&"sun_stone", Vector3(3.6, 4.05, 1.1), &"americas_temple")
	assert_not_null(piece, "pieces named by their model id are dressed")
	if piece != null:
		piece.free()
