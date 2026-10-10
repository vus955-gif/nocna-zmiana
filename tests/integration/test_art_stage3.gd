extends TestCase
## Stage 3 art (the expansion, docs/superpowers/specs/2026-10-01-rozbudowa-projekt.md):
## the Gatling and its museum display, the flare pistol, its round and
## the emergency cabinet, the raptor skeleton, the portrait with its ten
## canvases and movable eyes, the new pickups. Parts, pivots, markers,
## sizes and triangle budgets gameplay relies on.
## (Godot axes: Blender (x, y, z) arrives as (x, z, -y).)


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


## Triangles of every mesh under [param node] (whose name starts with
## [param prefix]; "" = all).
func _triangles(node: Node, prefix: String = "") -> int:
	var count := 0
	for child in node.find_children(prefix + "*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			count += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


func _material_names(node: Node) -> Dictionary:
	var out := {}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		for i in view.mesh.get_surface_count():
			var mat := view.get_surface_override_material(i)
			if mat != null:
				out[mat.resource_name] = mat
	return out


func _depth(node: Node, root: Node) -> int:
	var depth := 0
	while node != null and node != root:
		node = node.get_parent()
		depth += 1
	return depth


func test_gatling_viewmodel_parts_and_markers() -> void:
	var gun := _spawn(&"vm_gatling")
	var muzzle := gun.get_node_or_null(^"Muzzle") as Node3D
	assert_not_null(muzzle, "Muzzle is a direct child (WeaponHolder finds it there)")
	if muzzle != null:
		assert_lt(muzzle.position.distance_to(Vector3(0.0, -0.028, -0.788)), 0.01, "muzzle at the top barrel's end")
	var barrels := gun.find_child("barrels", true, false) as Node3D
	assert_lt(Vector2(barrels.position.x, barrels.position.y + 0.06).length(), 0.001,
		"barrels pivot on their spin axis (x 0, y -0.06, along Z)")
	var bar_box := _box(gun, "barrels")
	assert_almost_eq(bar_box.get_center().x, 0.0, 0.005, "cluster centred on the axis (x)")
	assert_almost_eq(bar_box.get_center().y, -0.06, 0.005, "cluster centred on the axis (y)")
	var crank := gun.find_child("crank", true, false) as Node3D
	assert_lt(crank.position.distance_to(Vector3(0.1, -0.06, -0.03)), 0.005, "crank pivot on its shaft")
	var knob := gun.find_child("CrankKnob", true, false) as Node3D
	assert_true(knob != null and knob.get_parent() == crank, "CrankKnob turns with the crank")
	var hand := gun.find_child("hand_r", true, false) as Node3D
	assert_lt(hand.global_position.distance_to(knob.global_position), 0.005, "right hand pivot on the knob")
	var bar := _box(gun, "barrels")
	assert_lt(bar.position.z, -0.6, "barrels reach forward")
	for child in gun.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "viewmodel casts no shadow")
		var mat := mesh.get_surface_override_material(0) as BaseMaterial3D
		assert_true(mat.use_fov_override, "viewmodel FOV")
	# the upgrade parts (design 7.1a, hidden until bought) come on top
	var upgrades := _triangles(gun, WeaponLook.PART_PREFIX)
	assert_lt(_triangles(gun) - upgrades, 8500, "Gatling viewmodel budget")
	assert_lt(upgrades, 1600, "its upgrade parts")
	gun.queue_free()


func test_gatling_display_chain_and_plaque() -> void:
	var exhibit := _spawn(&"gatling_display")
	var all := _bounds(exhibit)
	assert_almost_eq(all.position.y, 0.0, 0.02, "plinth on the floor")
	var gun := _box(exhibit, "gun")
	assert_gt(gun.get_center().y, 0.8, "the gun sits on its tripod")
	var chain := exhibit.find_child("chain", true, false) as MeshInstance3D
	assert_not_null(chain, "the chain is its own mesh (can be broken off)")
	assert_true(_box(exhibit, "chain").intersects(gun), "the chain is wound round the gun")
	assert_lt(_triangles(exhibit), 10000, "display budget")
	exhibit.queue_free()


func test_flare_pistol_round_and_cabinet() -> void:
	var pistol := _spawn(&"vm_flare")
	var muzzle := pistol.get_node_or_null(^"Muzzle") as Node3D
	assert_not_null(muzzle, "flare Muzzle is a direct child")
	if muzzle != null:
		assert_lt(muzzle.position.distance_to(Vector3(0.0, 0.014, -0.13)), 0.01, "muzzle at the barrel end")
	var barrel := pistol.find_child("barrel", true, false) as Node3D
	assert_lt(barrel.position.distance_to(Vector3(0.0, -0.018, -0.004)), 0.005, "barrel pivots on the hinge pin")
	pistol.queue_free()
	var shot := _spawn(&"flare_round")
	var mat := (shot.find_child("flare_round", true, false) as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
	assert_true(mat.emission_enabled, "the burning tip glows")
	var light := shot.find_child("Light", true, false) as Node3D
	assert_lt(light.position.z, -0.05, "light marker at the tip (flies along -Z)")
	shot.queue_free()
	var cabinet := _spawn(&"emergency_cabinet")
	var box := _bounds(cabinet)
	assert_almost_eq(box.position.y, 0.0, 0.01, "origin at the bottom")
	assert_gt(box.end.z, 0.14, "sticks out of the wall toward +Z")
	assert_gt(box.position.z, -0.01, "nothing behind the wall plane")
	var glass := cabinet.find_child("glass", true, false) as MeshInstance3D
	assert_eq(glass.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the pane casts no shadow")
	assert_true(_box(cabinet, "flare_gun").intersects(box), "the pistol hangs inside")
	assert_lt(_box(cabinet, "flare_gun").end.z, _box(cabinet, "glass").position.z + 0.001, "pistol behind the glass")
	cabinet.queue_free()


func test_raptor_size_joints_budget() -> void:
	var raptor := _spawn(&"raptor")
	var all := _bounds(raptor)
	assert_gt(all.size.z, 2.3, "about 2.4 m snout to tail")
	assert_lt(all.size.z, 2.6, "about 2.4 m snout to tail")
	assert_gt(all.end.y, 0.95, "about 1.1 m tall")
	assert_lt(all.end.y, 1.2, "about 1.1 m tall")
	assert_almost_eq(all.position.y, 0.0, 0.03, "feet on the floor")
	assert_lt(_triangles(raptor), 8000, "under the 8k budget")
	var parent_of := {"spine_1": "pelvis", "spine_2": "spine_1", "ribs": "spine_2", "neck_1": "spine_2",
		"neck_2": "neck_1", "skull": "neck_2", "jaw": "skull", "arm_l": "spine_2", "arm_r": "spine_2",
		"thigh_l": "pelvis", "shin_l": "thigh_l", "foot_l": "shin_l", "thigh_r": "pelvis", "shin_r": "thigh_r",
		"foot_r": "shin_r", "tail_1": "pelvis", "tail_6": "tail_5"}
	for part in parent_of:
		var node := raptor.find_child(part, true, false)
		assert_true(node != null and String(node.get_parent().name) == parent_of[part],
			"%s hangs off %s" % [part, parent_of[part]])
	assert_gt(_depth(raptor.find_child("tail_6", true, false), raptor), 6, "tail is a chain of 6 under the pelvis")
	var weak := raptor.find_child("WeakPoint", true, false) as Node3D
	assert_true(weak != null and String(weak.get_parent().name) == "skull", "WeakPoint rides on the skull")
	var skull := _box(raptor, "skull")
	assert_true(skull.grow(0.01).has_point(weak.global_position), "WeakPoint inside the skull")
	assert_lt(weak.global_position.z, -0.8, "skull in front (-Z)")
	var foot := raptor.find_child("foot_l", true, false) as Node3D
	assert_lt(foot.global_position.x, 0.0, "left foot on the left (-X)")
	raptor.queue_free()


func test_portrait_canvases_eyes_and_mounting() -> void:
	var pic := _spawn(&"portrait")
	var all := _bounds(pic)
	assert_gt(all.position.z, -0.01, "origin on the wall plane, nothing behind it")
	assert_lt(all.end.z, 0.16, "frame depth")
	assert_almost_eq(all.get_center().x, 0.0, 0.02, "hung by its centre")
	var names := _material_names(pic)
	assert_true(names.has("canvas_aristocrat"), "default canvas")
	assert_true(names.has(ArtLibrary.PORTRAIT_EYES_MATERIAL), "eyes material")
	var weak := pic.find_child("WeakPoint", true, false) as Node3D
	assert_lt(weak.global_position.distance_to(Vector3(0.0, 0.195, 0.032)), 0.005, "weak point between the eyes")
	var eyes := _box(pic, "eyes")
	assert_gt(eyes.position.z, _box(pic, "canvas").end.z, "eye patches in front of the canvas")
	var owned := ArtLibrary.own_materials(pic)
	var eye_mat: BaseMaterial3D = null
	for mat in owned:
		if mat.resource_name == ArtLibrary.PORTRAIT_EYES_MATERIAL:
			eye_mat = mat
	assert_not_null(eye_mat, "eyes get their own material copy")
	if eye_mat != null:
		# (setting uv1_offset itself is left to the windowed lineup: the
		# headless dummy renderer reports an error when an instanced
		# material changes)
		assert_true(eye_mat != ArtLibrary.material(ArtLibrary.PORTRAIT_EYES_MATERIAL),
			"sliding one portrait's eyes leaves the others alone")
		assert_true(eye_mat.texture_repeat, "the eye texture may slide (repeat on)")
	owned.clear()
	eye_mat = null
	pic.queue_free()
	# let the instance go before its own material copies (the headless dummy
	# renderer complains when a copy dies first)
	await get_tree().process_frame
	await get_tree().process_frame
	for canvas in ArtLibrary.PORTRAIT_FACES + ArtLibrary.PORTRAIT_SCENES:
		assert_not_null(ArtLibrary.texture(canvas, "albedo"), "%s painted" % canvas)
		var other := _spawn(&"portrait", {"canvas_aristocrat": canvas})
		assert_true(_material_names(other).has(canvas), "%s swaps in" % canvas)
		other.queue_free()
	var last := _spawn(&"portrait")
	assert_lt(_triangles(last), 3000, "portrait budget")
	last.queue_free()


func test_pickups_centred() -> void:
	for id in [&"ammo_rifle", &"ammo_flares"]:
		var pickup := _spawn(id)
		var box := _bounds(pickup)
		assert_lt(box.get_center().length(), 0.08, "%s origin near its centre (spins and bobs)" % id)
		assert_lt(box.size.x, 0.4, "%s pickup size" % id)
		pickup.queue_free()
