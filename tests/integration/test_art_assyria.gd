extends TestCase
## Floor I, Assyrian wing art (docs/art/kit-pietro1-asyria.md): the Lamassu
## guardian's joint chains, markers and size, the flat relief enemies (thin
## slabs, the eye on the face), the relief slabs on the wall plane with
## their theme sets, the awakening slabs, the frieze datum, the torch frame,
## the Balawat leaves with the seal socket and the Khorsabad Gate.
## Godot axes: Blender (x, y, z) arrives as (x, z, -y); models face -Z.


func _spawn(id: StringName, swap: Dictionary = {}) -> Node3D:
	var node := ArtLibrary.instance(id, swap)
	add_child(node)
	return node


func _kit(id: String, texture_set: String = "") -> Node3D:
	var node := ArtKit.model(id, texture_set)
	add_child(node)
	return node


func _bounds(node: Node, only: String = "") -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if only != "" and String(child.name) != only:
			continue
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


func _parent_is(node: Node, part: String, parent: String) -> bool:
	var child := node.find_child(part, true, false)
	return child != null and child.get_parent() != null and String(child.get_parent().name) == parent


func _between(value: float, low: float, high: float, message: String) -> void:
	assert_true(value >= low and value <= high, "%s (%.3f not in %.2f..%.2f)" % [message, value, low, high])


func _marker(node: Node, name: String) -> Vector3:
	var m := node.find_child(name, true, false) as Node3D
	return m.global_position if m != null else Vector3(INF, INF, INF)


func test_lamassu_joint_chains_markers_and_size() -> void:
	var lam := _spawn(&"lamassu")
	var chains := {
		"head": "body", "headdress": "head", "wing_l": "body", "wing_r": "body", "wing_l_tip": "wing_l",
		"wing_r_tip": "wing_r", "tail": "body", "face": "head", "crown": "headdress",
	}
	for leg in ["fl", "fr", "bl", "br"]:
		chains["thigh_" + leg] = "body"
		chains["shin_" + leg] = "thigh_" + leg
		chains["hoof_" + leg] = "shin_" + leg
		chains["contact_" + leg] = "hoof_" + leg
	for part: String in chains:
		assert_true(_parent_is(lam, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	var all := _bounds(lam)
	assert_almost_eq(all.position.y, 0.0, 0.03, "hooves on the floor")
	assert_almost_eq(all.end.y, 4.0, 0.15, "about 4 m to the top of the crown")
	assert_lt(_marker(lam, "face").z, -1.5, "the face looks forward (-Z)")
	assert_gt(_marker(lam, "crown").y, 3.4, "the crown marker high on the crown")
	for leg in ["fl", "fr", "bl", "br"]:
		assert_almost_eq(_marker(lam, "contact_" + leg).y, 0.0, 0.02, "contact_%s on the floor" % leg)
	assert_lt(_triangles(lam), 16000, "the guardian's budget")
	assert_not_null(ArtLibrary.texture("lamassu_cracked", "emit"), "the cracked set glows")
	var cracked := ArtLibrary.exhibit(&"lamassu", {"lamassu": "lamassu_cracked"})
	assert_not_null(cracked, "dressed as an exhibit with the cracked set")
	if cracked != null:
		cracked.free()


func test_relief_warrior_is_a_thin_slab_with_the_eye_in_front() -> void:
	var w := _spawn(&"relief_warrior")
	var chains := {"head": "torso", "arm_front": "torso", "arm_back": "torso", "spear": "arm_front",
		"shield": "arm_back", "eye": "head"}
	for part: String in chains:
		assert_true(_parent_is(w, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	var all := _bounds(w)
	assert_almost_eq(all.position.y, 0.0, 0.03, "feet on the floor")
	_between(all.end.y, 1.9, 2.3, "1.9 m to the helmet, the spear above")
	assert_lt(all.size.z, 0.2, "a slab ~0.18 m thick")
	var eye := _marker(w, "eye")
	_between(eye.y, 1.55, 1.75, "the eye at head height")
	assert_lt(eye.z, -0.05, "the eye on the carved face (front, -Z)")
	assert_lt(_triangles(w), 4000, "warrior budget")


func test_relief_lion_parts_like_the_wolf_and_flat() -> void:
	var lion := _spawn(&"relief_lion")
	for part in ["head", "tail", "leg_fl", "leg_fr", "leg_bl", "leg_br"]:
		assert_true(_parent_is(lion, part, "body"), "%s hangs off the body" % part)
	assert_true(_parent_is(lion, "jaw", "head"), "jaw hangs off the head")
	var all := _bounds(lion)
	assert_almost_eq(all.position.y, 0.0, 0.03, "paws on the floor")
	_between(all.end.y, 0.95, 1.3, "about 1 m to the top of the mane and tail")
	assert_lt(all.size.z, 0.18, "a slab")
	assert_lt(_marker(lion, "eye").z, -0.05, "the eye on the carved face")
	assert_lt(_triangles(lion), 4000, "lion budget")


func test_relief_slabs_stand_on_the_wall_plane_and_carry_their_themes() -> void:
	for id in ["asy_relief_2m", "asy_relief_1m", "asy_relief_wake", "asy_relief_wake_lion"]:
		var slab := _kit(id)
		var b := _bounds(slab)
		var w := 1.0 if id.ends_with("1m") or id == "asy_relief_wake" else 2.0
		assert_almost_eq(b.size.x, w, 0.02, "%s width" % id)
		assert_almost_eq(b.position.y, 0.0, 0.01, "%s on the floor" % id)
		assert_almost_eq(b.end.y, 3.0, 0.01, "%s 3 m tall" % id)
		assert_lt(b.end.z, 0.01, "%s nothing behind the wall plane" % id)
		assert_gt(b.position.z, -0.15, "%s 0.12 m proud of the wall" % id)
		slab.queue_free()
	for theme in ["genie_l", "army", "chariot", "hunt", "lions", "text", "plain"]:
		for module in ["2m", "1m"]:
			assert_not_null(ArtLibrary.texture("asy_relief_%s_%s" % [theme, module], "albedo"), "%s %s" % [theme, module])
	for id in ["asy_relief_wake", "asy_relief_wake_lion"]:
		var wake := _kit(id)
		assert_not_null(wake.find_child("figure", true, false), "%s: the figure to hide" % id)
		assert_not_null(ArtLibrary.texture(id, "emit"), "%s: the cracks" % id)
		assert_eq(float(ArtLibrary.EXTRAS[id]["emission"]), 0.0, "%s: dark at rest" % id)
		wake.queue_free()


func test_frieze_torch_and_seal_leaves() -> void:
	var frieze := _kit("asy_frieze_4m")
	var fb := _bounds(frieze)
	assert_almost_eq(fb.position.y, 0.0, 0.01, "the frieze hangs on its bottom datum")
	assert_almost_eq(fb.end.y, 0.62, 0.01, "0.62 m band")
	assert_lt(fb.end.z, 0.01, "on the wall plane")
	frieze.queue_free()
	var torch := _kit("asy_torch")
	assert_lt(_marker(torch, "Light").length(), 0.05, "the light at the origin")
	assert_gt(_bounds(torch).end.z, 0.3, "the mount runs to the wall (+Z)")
	torch.queue_free()
	var leaf := _kit("asy_balawat_leaf_l")
	var lb := _bounds(leaf)
	assert_almost_eq(lb.end.y - lb.position.y, 5.1, 0.25, "a 5 m leaf on its post")
	var socket := _marker(leaf, "SealSocket")
	assert_almost_eq(socket.x, 1.0, 0.05, "the socket on the meeting stile")
	assert_gt(socket.z, 0.1, "on the decorated face (+Z, room A)")
	leaf.queue_free()


func test_khorsabad_gate_frames_the_passage() -> void:
	var gate := _kit("khorsabad_gate")
	for part in ["lamassu_l", "lamassu_r", "lamassu_l_body", "lamassu_r_body", "door_l", "door_r", "seal_socket",
			"SealSocket", "Light_l", "Light_r"]:
		assert_not_null(gate.find_child(part, true, false), "gate has %s" % part)
	var b := _bounds(gate)
	assert_lt(b.end.x, 3.6, "fits the room east of the opening")
	assert_gt(b.position.x, -3.6, "symmetric")
	assert_lt(b.end.y, 9.6, "under the 10 m ceiling")
	assert_lt(b.end.z, 0.05, "nothing in the wall")
	var left := _bounds(gate, "lamassu_l")
	assert_lt(left.end.x, -1.4, "the left statue leaves the passage free")
	assert_gt(left.end.z, -0.6, "its face at the passage mouth")
	var statue := _bounds(gate, "lamassu_l").merge(_bounds(gate, "lamassu_l_body"))
	assert_almost_eq(statue.end.y, 4.75, 0.15, "a 4.5 m statue on its 0.25 m plinth")
	assert_almost_eq(_marker(gate, "seal_socket").x, 0.0, 0.01, "the sun disc between the leaves")
	gate.queue_free()
