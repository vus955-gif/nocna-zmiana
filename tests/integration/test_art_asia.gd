extends TestCase
## Floor I, Asia wing art (docs/art/kit-pietro1-azja.md): every exhibit,
## garden piece, enemy and the guardian loads dressed with its parts and
## markers, keeps its triangle budget and size; the Fu dog, the ashigaru
## (the knight's rig names) and the General's joint chains; texture sets.
## Godot axes: Blender (x, y, z) arrives as (x, z, -y); every model faces -Z.

## Model id -> [triangle budget, min top, max top] (metres: the AABB's end.y;
## the scroll hangs down from its hook at the origin).
const MODELS := {
	&"buddha_seated": [18000, 6.8, 8.0],
	&"bronze_ding": [2000, 0.7, 0.95],
	&"bronze_gu": [1500, 0.28, 0.36],
	&"vase_blue_white": [1200, 0.38, 0.46],
	&"vase_celadon": [1200, 0.36, 0.44],
	&"moon_jar": [1200, 0.4, 0.48],
	&"scroll_hanging": [400, 0.0, 0.05],
	&"temple_bell": [5500, 4.9, 5.4],
	&"hwacha_display": [5000, 1.0, 2.0],
	&"samurai_armor_stand": [11000, 2.2, 2.7],
	&"garden_rock_a": [600, 1.4, 2.0],
	&"garden_rock_b": [600, 0.4, 1.0],
	&"garden_rock_c": [600, 0.6, 1.2],
	&"garden_rock_d": [600, 0.5, 1.2],
	&"toro_kasuga": [1400, 2.0, 2.2],
	&"toro_yukimi": [1100, 1.05, 1.25],
	&"garden_bridge": [3500, 1.6, 2.0],
	&"garden_pond": [2000, 0.0, 0.6],
	&"cherry_tree": [7000, 5.5, 7.5],
	&"cherry_petals_ground": [20, 0.0, 0.05],
	&"teahouse": [4000, 7.0, 8.2],
	&"teahouse_interior": [2500, 3.4, 3.6],
	&"fu_dog": [13500, 2.1, 3.0],
	&"samurai_ashigaru": [9500, 1.8, 2.05],
	&"samurai_general": [12000, 2.85, 3.15],
}


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


func _pos(node: Node, name: String) -> Vector3:
	return (node.find_child(name, true, false) as Node3D).global_position


func test_every_asia_model_loads_with_parts_size_and_budget() -> void:
	for id: StringName in MODELS:
		assert_true(ArtLibrary.REGISTRY.has(id) or ArtLibrary.KIT.has(id), "%s registered" % id)
		var node := _spawn(id)
		var found := ArtLibrary.parts(node)
		var listed: Array = ArtLibrary.REGISTRY.get(id, ArtLibrary.KIT.get(id, []))
		for part: String in listed:
			assert_true(found.has(part), "%s has %s" % [id, part])
		var spec: Array = MODELS[id]
		assert_lt(_triangles(node), int(spec[0]) + 1, "%s within its budget" % id)
		var box := _bounds(node)
		assert_gt(box.end.y, float(spec[1]) - 0.001, "%s tall enough" % id)
		assert_lt(box.end.y, float(spec[2]) + 0.001, "%s not too tall" % id)
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				assert_not_null(view.get_surface_override_material(i), "%s/%s dressed" % [id, view.name])
		node.queue_free()


func test_texture_sets_swap() -> void:
	for id: StringName in ArtLibrary.ASIA_SETS:
		for texture_set: String in ArtLibrary.ASIA_SETS[id]:
			assert_not_null(ArtLibrary.texture(texture_set, "albedo"), "%s exists" % texture_set)
			var node := _spawn(id, {String(id): texture_set})
			var names := {}
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var view := child as MeshInstance3D
				for i in view.mesh.get_surface_count():
					names[view.get_surface_override_material(i).resource_name] = true
			assert_true(names.has(texture_set), "%s wears %s" % [id, texture_set])
			node.queue_free()


func test_fu_dog_rig_and_weak_point() -> void:
	var dog := _spawn(&"fu_dog")
	var chains := {"head": "body", "jaw": "head", "pearl": "head", "leg_fl": "body", "leg_fr": "body",
		"leg_bl": "body", "leg_br": "body", "shin_fl": "leg_fl", "shin_fr": "leg_fr", "shin_bl": "leg_bl",
		"shin_br": "leg_br", "tail": "body", "mouth_ball": "head", "roar": "head"}
	for part: String in chains:
		assert_true(_parent_is(dog, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	assert_true(dog.find_child("ball", true, false).get_parent() == dog, "the embroidered ball is a root part")
	var mouth := _pos(dog, "mouth_ball")
	var roar := _pos(dog, "roar")
	assert_lt(mouth.z, -1.2, "the pearl is in the mouth at the front")
	assert_lt(roar.z, mouth.z, "the roar starts in front of the pearl")
	assert_almost_eq(mouth.y, roar.y, 0.2, "roar at mouth height")
	assert_lt(_pos(dog, "leg_fl").x, 0.0, "the left foreleg is on the dog's left (-X)")
	dog.queue_free()


func test_ashigaru_has_the_knight_rig() -> void:
	var a := _spawn(&"samurai_ashigaru")
	var chains := {"head": "torso", "arm_l": "torso", "arm_r": "torso", "shield": "arm_l", "weapon": "arm_r",
		"plate_pauldron_r": "arm_r", "plate_tasset_l": "torso", "plate_tasset_r": "torso", "plate_poleyn_l": "leg_l",
		"plate_poleyn_r": "leg_r", "face": "head", "spear_tip": "weapon"}
	for part: String in chains:
		assert_true(_parent_is(a, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	for root in ["torso", "leg_l", "leg_r"]:
		assert_true(a.find_child(root, true, false).get_parent() == a, "%s is a root part" % root)
	assert_almost_eq((a.find_child("torso", true, false) as Node3D).position.y, 1.0, 0.01, "waist 1.0 as the knight")
	assert_almost_eq((a.find_child("head", true, false) as Node3D).position.y, 0.62, 0.01, "neck 1.62 (0.62 over the waist)")
	var face := _pos(a, "face")
	assert_almost_eq(face.y, 1.78, 0.06, "the face (weak point) where the knight's head zone is")
	assert_lt(face.z, -0.03, "face on the front")
	assert_lt(_pos(a, "spear_tip").z, -1.6, "the spear points forward")
	var plate := a.find_child("shield", true, false) as MeshInstance3D
	var guard := plate.global_transform * plate.get_aabb()
	assert_lt(guard.get_center().x, -0.1, "the guard plate is on the left")
	assert_lt(guard.position.z, -0.05, "the guard plate is forward of the shoulder")
	a.queue_free()


func test_general_rig_markers_and_size() -> void:
	var g := _spawn(&"samurai_general")
	var chains := {"torso": "pelvis", "head": "torso", "upperarm_l": "torso", "upperarm_r": "torso",
		"forearm_l": "upperarm_l", "forearm_r": "upperarm_r", "hand_l": "forearm_l", "hand_r": "forearm_r",
		"sword": "hand_r", "sode_l": "upperarm_l", "sode_r": "upperarm_r", "saya": "pelvis", "bow": "torso",
		"quiver": "torso", "arrow": "quiver", "thigh_l": "pelvis", "thigh_r": "pelvis", "shin_l": "thigh_l",
		"shin_r": "thigh_r", "foot_l": "shin_l", "foot_r": "shin_r", "kusazuri_f": "pelvis", "kusazuri_b": "pelvis",
		"kusazuri_l": "pelvis", "kusazuri_r": "pelvis", "face": "head", "back": "torso", "blade_tip": "sword",
		"glint": "sword", "bow_grip": "bow", "arrow_nock": "arrow", "saya_mouth": "saya"}
	for part: String in chains:
		assert_true(_parent_is(g, part, chains[part]), "%s hangs off %s" % [part, chains[part]])
	var face := _pos(g, "face")
	assert_gt(face.y, 2.25, "a giant: the face over 2.25 m")
	assert_lt(face.z, -0.05, "face on the front")
	assert_gt(_pos(g, "back").z, 0.3, "the back weak point is behind")
	var tip := _pos(g, "blade_tip")
	assert_lt(tip.z, -1.5, "the nodachi points forward")
	assert_gt(tip.y, 2.2, "in the middle guard: the point at a man's throat height and up")
	assert_gt(_pos(g, "hand_l").z, _pos(g, "hand_r").z, "the left fist behind the right on the grip")
	g.queue_free()


func test_exhibit_markers() -> void:
	var b := _spawn(&"buddha_seated")
	assert_lt(_pos(b, "Offering").z, -1.5, "the offering step is in front")
	assert_true(_parent_is(b, "buddha_head", "buddha_figure"), "head on the figure")
	b.queue_free()
	var h := _spawn(&"hwacha_display")
	var spot := _pos(h, "weapon_spot")
	assert_almost_eq(spot.y, 0.83, 0.05, "the fire chest rests on the cushion")
	assert_lt(spot.z, -0.5, "the dais is in front of the cart")
	h.queue_free()
	var bell := _spawn(&"temple_bell")
	assert_true(_parent_is(bell, "bell", "temple_bell"), "the bell swings in its frame")
	assert_true(_parent_is(bell, "striker", "temple_bell"), "the striker hangs in the frame")
	assert_gt((bell.find_child("bell", true, false) as Node3D).position.y, 2.8, "the bell pivots on its hook pin")
	bell.queue_free()
	var t := _spawn(&"teahouse")
	assert_gt(_pos(t, "roof_perch").y, 6.5, "the General's perch on the ridge")
	t.queue_free()
	var ti := _spawn(&"teahouse_interior")
	var term := _pos(ti, "terminal_spot")
	assert_almost_eq(term.x, -2.6, 0.01, "the terminal by the west wall (asia.gd haven spot)")
	assert_almost_eq(term.z, 0.0, 0.01, "the terminal on the room's axis")
	ti.queue_free()
	var tree := _spawn(&"cherry_tree")
	for k in range(1, 11):
		assert_gt(_pos(tree, "Petals_%d" % k).y, 2.0, "petal emitter %d up in the blossom" % k)
	tree.queue_free()
	for id: StringName in [&"toro_kasuga", &"toro_yukimi"]:
		var lamp := _spawn(id)
		var light := _pos(lamp, "Light")
		assert_gt(light.y, 0.6, "%s light in the fire box" % id)
		lamp.queue_free()
