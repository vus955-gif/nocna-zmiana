extends TestCase
## Floor I, Greek wing art (docs/art/kit-pietro1-grecja.md): the hoplite and
## centaur rigs (joint chains, markers, sizes), the javelin, the Nereid
## Monument's stacking, the frieze runs (datum, length, varied slabs), the
## room styles. Godot axes: Blender (x, y, z) arrives as (x, z, -y); every
## model faces -Z.


func _spawn(id: StringName, swap: Dictionary = {}) -> Node3D:
	var node := ArtLibrary.instance(id, swap)
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


func _parent_is(node: Node, part: String, parent: String) -> bool:
	var child := node.find_child(part, true, false)
	return child != null and child.get_parent() != null and String(child.get_parent().name) == parent


func _triangles(node: Node) -> int:
	var count := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


func test_hoplite_rig_shield_spear_and_face() -> void:
	var h := _spawn(&"hoplite")
	var chains := {"head": "torso", "plate_crest": "head", "arm_l": "torso", "forearm_l": "arm_l",
		"shield": "forearm_l", "arm_r": "torso", "forearm_r": "arm_r", "spear": "forearm_r", "shin_l": "leg_l",
		"shin_r": "leg_r", "plate_greave_l": "shin_l", "plate_greave_r": "shin_r", "face": "head",
		"spear_tip": "spear"}
	for part: String in chains:
		assert_true(_parent_is(h, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	for root_part in ["torso", "leg_l", "leg_r"]:
		assert_true(h.find_child(root_part, true, false).get_parent() == h, "%s is a root part" % root_part)
	var all := _bounds(h)
	assert_gt(all.end.y, 1.88, "about 1.95 m with the crest")
	assert_lt(all.end.y, 2.02, "about 1.95 m with the crest")
	assert_almost_eq(all.position.y, 0.0, 0.03, "on the floor")
	var parts := ArtLibrary.parts(h)
	var face := parts["face"] as Node3D
	assert_almost_eq(face.global_position.y, 1.715, 0.05, "the face at helmet height")
	assert_lt(face.global_position.z, -0.05, "the face on the front of the helmet")
	var tip := parts["spear_tip"] as Node3D
	assert_lt(tip.global_position.z, -1.5, "the spear points forward, about 2 m out")
	var shield := h.find_child("shield", true, false) as MeshInstance3D
	var sb := shield.global_transform * shield.get_aabb()
	assert_lt(sb.get_center().x, 0.0, "the shield on the left arm")
	assert_lt(sb.get_center().z, -0.3, "the shield carried in front")
	assert_gt(sb.size.y, 0.8, "the aspis is about 0.9 m across")
	assert_lt(_triangles(h), 14000, "hoplite budget")
	h.queue_free()
	var chips := _spawn(&"marble_chips")
	assert_eq(chips.find_children("chip_*", "MeshInstance3D", true, false).size(), 6, "six chips")
	chips.queue_free()


func test_centaur_legs_arms_markers_and_size() -> void:
	var c := _spawn(&"centaur")
	for leg in ["fl", "fr", "bl", "br"]:
		assert_true(_parent_is(c, "leg_" + leg, "barrel"), "leg_%s on the body" % leg)
		assert_true(_parent_is(c, "knee_" + leg, "leg_" + leg), "knee_%s on its leg" % leg)
		assert_true(_parent_is(c, "hoof_" + leg, "knee_" + leg), "hoof_%s on its knee" % leg)
	for side in ["l", "r"]:
		assert_true(_parent_is(c, "arm_" + side, "torso"), "arm_%s on the torso" % side)
		assert_true(_parent_is(c, "forearm_" + side, "arm_" + side), "forearm_%s on the arm" % side)
		assert_true(_parent_is(c, "wrist_" + side, "forearm_" + side), "wrist_%s on the forearm" % side)
	var chains := {"torso": "barrel", "neck": "torso", "tail_1": "barrel", "tail_2": "tail_1", "slab": "barrel",
		"javelin": "wrist_r", "chest": "torso", "head": "neck", "hand_r": "wrist_r"}
	for part: String in chains:
		assert_true(_parent_is(c, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	var all := _bounds(c)
	assert_gt(all.end.y, 2.8, "about 3 m tall")
	assert_lt(all.end.y, 3.15, "about 3 m tall")
	assert_almost_eq(all.position.y, 0.0, 0.05, "hooves on the floor")
	var parts := ArtLibrary.parts(c)
	var chest := parts["chest"] as Node3D
	var head := parts["head"] as Node3D
	assert_gt(head.global_position.y, chest.global_position.y + 0.3, "the head above the chest")
	assert_lt(chest.global_position.z, -0.6, "the man's chest is at the front of the horse body")
	assert_gt((parts["hand_r"] as Node3D).global_position.y, 2.3, "the javelin hand raised to throw")
	assert_lt(_triangles(c), 26000, "guardian budget")
	c.queue_free()
	var jav := _spawn(&"javelin")
	var tip := ArtLibrary.parts(jav)["tip"] as Node3D
	assert_lt(tip.global_position.z, -1.0, "the spare javelin points along -Z")
	assert_almost_eq(tip.global_position.x, 0.0, 0.01, "on its axis")
	jav.queue_free()


func test_nereid_monument_stacks_to_eleven_metres() -> void:
	var podium := _spawn(&"nereid_podium")
	var pb := _bounds(podium)
	assert_almost_eq(pb.end.y, 4.4, 0.05, "the podium is 4.4 m high")
	assert_almost_eq(pb.position.y, 0.0, 0.02, "on the floor")
	var temple := _spawn(&"nereid_temple")
	temple.position.y = 4.4
	var tb := _bounds(temple)
	assert_gt(tb.end.y, 10.8, "the monument rises about 11.2 m (akroterion)")
	assert_lt(tb.end.y, 11.6, "the monument rises about 11.2 m (akroterion)")
	assert_lt(absf(tb.get_center().x), 0.2, "centred")
	for k in range(1, 7):
		assert_not_null(temple.find_child("nereid_column_%d" % k, true, false), "column %d" % k)
	for id in [&"nereid_a", &"nereid_b", &"nereid_c", &"nereid_d"]:
		var n := _spawn(id)
		var nb := _bounds(n)
		assert_almost_eq(nb.position.y, 0.0, 0.03, "%s stands on its plinth" % id)
		assert_gt(nb.end.y, 1.6, "%s is life size and more" % id)
		assert_lt(nb.size.x, 1.7, "%s fits between the columns" % id)
		n.queue_free()
	podium.queue_free()
	temple.queue_free()


func test_frieze_runs_vary_their_slabs() -> void:
	for id in [&"gr_frieze_4m", &"gr_frieze_2m", &"gr_frieze_1m", &"gr_frieze_05m"]:
		var band := _spawn(id)
		var b := _bounds(band)
		assert_almost_eq(b.position.y, 0.0, 0.01, "%s rests on its datum" % id)
		assert_almost_eq(b.end.y, 1.19, 0.02, "%s is 1.19 m tall" % id)
		assert_lt(b.end.z, 0.005, "%s: nothing behind the wall plane" % id)
		band.queue_free()
	var holder := Node3D.new()
	add_child(holder)
	ArtKit.run(holder, "gr_frieze_", 0.0, 16.0, 1.45)
	var sets := {}
	for child in holder.find_children("*", "MeshInstance3D", true, false):
		var mat := (child as MeshInstance3D).get_surface_override_material(0)
		if mat != null:
			sets[mat.resource_name] = true
	assert_gt(sets.size(), 2, "a 16 m frieze shows several different slabs")
	holder.queue_free()


func test_greek_room_styles_and_vase_cases() -> void:
	for room in [&"greece_gallery", &"greece_nereid", &"greece_metopes", &"greece_vases", &"greece_bassae",
			&"greece_casts"]:
		var style := ArtKit.style(room)
		assert_true(style.has("wall") and style.has("bands"), "%s has a style" % room)
		assert_not_null(ArtKit.field(room, &"wall"), "%s wall field" % room)
	var case := _spawn(&"vase_case_wall_2m")
	var parts := ArtLibrary.parts(case)
	assert_almost_eq((parts["Shelf_1"] as Node3D).global_position.y, 1.45, 0.02, "middle shelf height")
	assert_lt((parts["Shelf_1"] as Node3D).global_position.z, -0.1, "the shelves stand in front of the wall")
	case.queue_free()
	for id in [&"vase_amphora_bf", &"vase_krater", &"vase_kylix", &"vase_lekythos"]:
		var v := _spawn(id)
		var vb := _bounds(v)
		assert_almost_eq(vb.position.y, 0.0, 0.01, "%s stands on its foot" % id)
		assert_lt(vb.end.y, 0.85, "%s is vase sized" % id)
		v.queue_free()
