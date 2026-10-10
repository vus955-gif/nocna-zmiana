extends TestCase
## Floor I, Egypt wing art (docs/art/kit-pietro1-egipt.md): the Colossus of
## Ramesses rig (joint chains, markers, plates over the cracks, the throne
## apart), the mummy rig and its whip, the scarabs' budget, exhibit parts and
## markers, the kit's datums and texture sets. Godot axes: Blender (x, y, z)
## arrives as (x, z, -y); every model faces -Z.


func _spawn(id: StringName, swap: Dictionary = {}) -> Node3D:
	var node := ArtLibrary.instance(id, swap)
	add_child(node)
	return node


func _box(node: Node, part: String) -> AABB:
	var mesh := node.find_child(part, true, false) as MeshInstance3D
	if mesh == null:
		return AABB()
	return mesh.global_transform * mesh.get_aabb()


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


func _parent_is(node: Node, part: String, parent: String) -> bool:
	var child := node.find_child(part, true, false)
	return child != null and child.get_parent() != null and String(child.get_parent().name) == parent


func test_colossus_joint_chains_and_markers() -> void:
	var kolos := _spawn(&"colossus")
	var chains := {
		"thigh_l": "pelvis", "thigh_r": "pelvis", "shin_l": "thigh_l", "shin_r": "thigh_r", "foot_l": "shin_l",
		"foot_r": "shin_r", "torso": "pelvis", "head": "torso", "eyes": "head", "uraeus": "head",
		"upperarm_l": "torso", "upperarm_r": "torso", "forearm_l": "upperarm_l", "forearm_r": "upperarm_r",
		"palm_l": "forearm_l", "palm_r": "forearm_r", "eye_l": "head", "eye_r": "head", "hand_l": "palm_l",
		"hand_r": "palm_r",
	}
	for part: String in chains:
		assert_true(_parent_is(kolos, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	for k in range(1, 4):
		assert_true(_parent_is(kolos, "chest_plate_%d" % k, "torso"), "plate %d on the torso" % k)
		assert_true(_parent_is(kolos, "crack_%d" % k, "torso"), "crack %d in the torso" % k)
		var plate := _box(kolos, "chest_plate_%d" % k)
		var crack := _box(kolos, "crack_%d" % k)
		assert_lt(absf(plate.get_center().x - crack.get_center().x), plate.size.x * 0.5, "plate %d over its crack (x)" % k)
		assert_lt(absf(plate.get_center().y - crack.get_center().y), plate.size.y * 0.5, "plate %d over its crack (y)" % k)
		assert_lt(plate.position.z, crack.position.z, "plate %d in front of its crack" % k)
	var all := _bounds(kolos)
	assert_gt(all.end.y, 8.5, "about 9 m to the crown")
	assert_lt(all.end.y, 9.4, "about 9 m to the crown")
	var parts := ArtLibrary.parts(kolos)
	var eye_l := parts["eye_l"] as Node3D
	var eye_r := parts["eye_r"] as Node3D
	assert_lt(eye_l.global_position.x, -0.1, "the left eye is on the colossus's left (-X)")
	assert_gt(eye_r.global_position.x, 0.1, "right eye")
	assert_gt(eye_l.global_position.y, 6.5, "eyes in the face")
	assert_lt(eye_l.global_position.z, -0.4, "eyes on the front of the face")
	var uraeus := parts["uraeus"] as Node3D
	assert_gt(uraeus.global_position.y, eye_l.global_position.y + 0.2, "uraeus above the eyes")
	assert_lt(uraeus.global_position.z, -0.5, "uraeus on the brow, facing out")
	var hand := parts["hand_l"] as Node3D
	assert_lt(hand.global_position.y, 4.0, "slam contact under the palm")
	assert_lt(hand.global_position.z, -1.5, "the hand rests forward, on the knee")
	var pelvis := parts["pelvis"] as Node3D
	assert_almost_eq(pelvis.position.y, 3.3, 0.01, "hip joint 3.3 m up")
	assert_lt(_triangles(kolos), 32000, "colossus budget")
	kolos.queue_free()
	var throne := _spawn(&"colossus_throne")
	var tp := ArtLibrary.parts(throne)
	for marker in ["swarm_l", "swarm_r"]:
		assert_true(tp.has(marker), "throne marker %s" % marker)
	assert_lt((tp["swarm_l"] as Node3D).global_position.x, -1.5, "left swarm hole on the throne's left side")
	var tb := _bounds(throne)
	assert_almost_eq(tb.position.y, 0.0, 0.02, "throne on the floor")
	assert_lt(tb.end.y, 6.0, "the back pillar stays below the head")
	throne.queue_free()


func test_mummy_rig_whip_and_weak_point() -> void:
	var mummy := _spawn(&"mummy")
	for leg in ["leg_l", "leg_r", "torso"]:
		assert_true(mummy.find_child(leg, true, false).get_parent() == mummy, "%s is a root part" % leg)
	assert_true(_parent_is(mummy, "head", "torso"), "head on the torso")
	assert_true(_parent_is(mummy, "forearm_r", "arm_r"), "forearm on the arm")
	assert_true(_parent_is(mummy, "whip_1", "forearm_r"), "the whip hangs from the right forearm")
	for k in range(2, 5):
		assert_true(_parent_is(mummy, "whip_%d" % k, "whip_%d" % (k - 1)), "whip segment %d chained" % k)
	var w1 := mummy.find_child("whip_1", true, false) as Node3D
	var w4 := mummy.find_child("whip_4", true, false) as Node3D
	assert_lt(w4.global_position.y, w1.global_position.y - 0.5, "the whip hangs down in the rest pose")
	var weak := mummy.find_child("WeakPoint", true, false) as Node3D
	assert_true(weak != null and weak.get_parent().name == &"head", "weak point rides the head")
	assert_almost_eq(weak.global_position.y, 1.63, 0.05, "head centre 1.63 m")
	var eyes := mummy.find_child("EyeGlow", true, false) as Node3D
	assert_lt(eyes.global_position.z, -0.05, "eyes on the front")
	var all := _bounds(mummy)
	assert_gt(all.end.y, 1.72, "about 1.8 m")
	assert_lt(all.end.y, 1.9, "about 1.8 m")
	assert_almost_eq(all.position.y, 0.0, 0.03, "feet on the floor")
	assert_lt(_triangles(mummy), 9000, "mummy budget")
	mummy.queue_free()
	var debris := _spawn(&"mummy_debris")
	assert_eq(ArtLibrary.parts(debris).size(), 5, "three scraps and two bones")
	debris.queue_free()


func test_scarabs_are_tiny_and_cheap() -> void:
	for id: StringName in [&"scarab", &"scarab_flying"]:
		var bug := _spawn(id)
		var box := _bounds(bug)
		assert_gt(box.size.z, 0.04, "%s about 6 cm long" % id)
		assert_lt(box.size.z, 0.08, "%s about 6 cm long" % id)
		assert_lt(_triangles(bug), 200, "%s fits a swarm of 40" % id)
		assert_eq(bug.find_children("*", "MeshInstance3D", true, false).size(), 1, "%s is one mesh (MultiMesh)" % id)
		bug.queue_free()


func test_exhibit_parts_markers_and_sets() -> void:
	var sarc := _spawn(&"sarcophagus")
	assert_true(_parent_is(sarc, "lid", "sarcophagus"), "the lid is its own part")
	var spawn := sarc.find_child("MummySpawn", true, false) as Node3D
	assert_lt(spawn.global_position.y, _box(sarc, "lid").position.y, "the mummy lies under the lid")
	sarc.queue_free()
	var coffin := _spawn(&"coffin")
	var lid := coffin.find_child("lid", true, false) as Node3D
	assert_almost_eq(lid.global_position.y, 0.12, 0.02, "the lid pivots on its bottom edge")
	assert_lt(lid.global_position.z, -0.15, "on the front of the case")
	coffin.queue_free()
	var rack := _spawn(&"camp_rifle_rack")
	var spot := rack.find_child("weapon_spot", true, false) as Node3D
	assert_gt(spot.global_position.y, 0.7, "the shotgun's place is on the cradle")
	rack.queue_free()
	var case_ := _spawn(&"rosetta_case")
	var stone_spot := case_.find_child("StoneSpot", true, false) as Node3D
	assert_almost_eq(stone_spot.global_position.y, 0.62, 0.01, "the stone stands on the plinth")
	var glass := case_.find_child("rosetta_case_glass", true, false) as MeshInstance3D
	assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the vitrine casts no shadow")
	case_.queue_free()
	var stone := _spawn(&"rosetta_stone")
	var sb := _bounds(stone)
	assert_almost_eq(sb.size.y, 1.12, 0.05, "the Rosetta Stone is 1.12 m tall")
	stone.queue_free()
	var row := _spawn(&"sekhmet")
	assert_true(_parent_is(row, "head", "sekhmet"), "Sekhmet's head can turn")
	row.queue_free()
	for id: StringName in ArtLibrary.EGYPT_SETS:
		for texture_set: String in ArtLibrary.EGYPT_SETS[id]:
			assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s texture set" % texture_set)
			var node := _spawn(id, {String(id): texture_set})
			var names := {}
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var view := child as MeshInstance3D
				for i in view.mesh.get_surface_count():
					names[view.get_surface_override_material(i).resource_name] = true
			assert_true(names.has(texture_set), "%s wears %s" % [id, texture_set])
			node.queue_free()


func test_kit_datums_columns_and_the_seal_gate() -> void:
	var dado := ArtKit.model("egypt_dado_4m")
	add_child(dado)
	var d := _bounds(dado)
	assert_almost_eq(d.position.y, 0.0, 0.01, "dado stands on the floor")
	assert_almost_eq(d.end.y, 1.2, 0.02, "dado 1.2 m")
	assert_lt(d.end.z, 0.005, "nothing behind the wall plane")
	assert_almost_eq(d.size.x, 4.0, 0.03, "4 m module")
	dado.queue_free()
	var cornice := ArtKit.model("egypt_cornice_4m")
	add_child(cornice)
	var c := _bounds(cornice)
	assert_almost_eq(c.end.y, 0.0, 0.01, "cornice hangs from the ceiling datum")
	assert_lt(c.position.z, -0.6, "cornice projects into the room")
	cornice.queue_free()
	var frieze := ArtKit.model("egypt_frieze_4m")
	add_child(frieze)
	var tile := false
	for child in frieze.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i) as ShaderMaterial
			tile = tile or (mat != null and mat.shader == ArtLibrary.ARCH_TILE_SHADER)
	assert_true(tile, "the frieze face is the world-mapped hieroglyph band")
	frieze.queue_free()
	for id in ["egypt_column", "egypt_column_open"]:
		var col := ArtKit.model(id)
		add_child(col)
		assert_almost_eq(_bounds(col).end.y, 11.0, 0.05, "%s reaches 11 m" % id)
		col.queue_free()
	var leaf := ArtKit.model("egypt_seal_door_l")
	add_child(leaf)
	var socket := leaf.find_child("SealSocket", true, false) as Node3D
	assert_gt(socket.global_position.z, 0.1, "the seal socket on the decorated face (+Z, room A)")
	assert_almost_eq(socket.global_position.x, 1.5, 0.02, "on the meeting edge")
	leaf.queue_free()
	var boards := ArtKit.model("egypt_boarded_doorway")
	add_child(boards)
	for k in range(1, 9):
		assert_not_null(boards.find_child("plank_%d" % k, true, false), "plank %d can be knocked off" % k)
	boards.queue_free()
	for id in ["egypt_torch_lamp", "egypt_spotlight", "camp_lamp"]:
		var lamp := ArtLibrary.model(id)
		add_child(lamp)
		assert_not_null(lamp.find_child("Light", true, false), "%s has a Light marker" % id)
		lamp.queue_free()
