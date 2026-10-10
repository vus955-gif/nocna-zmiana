extends TestCase
## Stage 2 art: every registered model loads dressed, keeps the part names
## and joint pivots gameplay will animate, and fits the hurtboxes and
## greybox positions of src/enemies and src/weapons/viewmodels.gd.
## (Godot axes: Blender (x, y, z) arrives as (x, z, -y); models face -Z.)


func _spawn(id: StringName) -> Node3D:
	var node := ArtLibrary.instance(id)
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


func test_every_registered_model_loads_with_its_parts_and_materials() -> void:
	for id in ArtLibrary.REGISTRY:
		var node := _spawn(id)
		assert_not_null(node, String(id))
		var found := ArtLibrary.parts(node)
		for part in ArtLibrary.REGISTRY[id]:
			assert_true(found.has(part), "%s has part %s" % [id, part])
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			for i in view.mesh.get_surface_count():
				var raw := view.get_surface_override_material(i)
				if raw is ShaderMaterial and raw.resource_name == "glass":
					continue                # panes use the glass shader
				var mat := raw as BaseMaterial3D
				assert_not_null(mat, "%s/%s surface %d dressed" % [id, view.name, i])
				if mat != null:
					assert_eq(mat.texture_filter, ArtLibrary.FILTER, "%s crisp texels" % id)
					assert_not_null(mat.albedo_texture, "%s albedo" % id)
		node.queue_free()


func test_wolf_joints_and_head_weak_point() -> void:
	var wolf := _spawn(&"wolf")
	var body := wolf.find_child("body", true, false)
	var head := wolf.find_child("head", true, false) as Node3D
	assert_true(head != null and head.get_parent() == body, "head hangs off the body")
	var jaw := wolf.find_child("jaw", true, false)
	assert_true(jaw != null and jaw.get_parent() == head, "jaw hangs off the head")
	for leg in ["leg_fl", "leg_fr", "leg_bl", "leg_br", "tail"]:
		var node := wolf.find_child(leg, true, false)
		assert_true(node != null and node.get_parent() == body, "%s is a child of the body" % leg)
	# weak point: sphere r 0.2 at (0, 0.82, -0.62) in src/enemies/wolf.gd
	var h := _box(wolf, "head")
	assert_almost_eq(h.get_center().y, 0.82, 0.1, "head centre height")
	assert_almost_eq(h.get_center().z, -0.62, 0.1, "head in front")
	var all := _bounds(wolf)
	assert_almost_eq(all.position.y, 0.0, 0.03, "paws on the floor")
	assert_lt(all.end.y, 1.05, "no taller than the capsule allows (ears included)")
	assert_lt(absf(all.position.x), 0.3, "fits the body hurtbox width")
	var fl := wolf.find_child("leg_fl", true, false) as Node3D
	assert_lt(fl.global_position.x, 0.0, "front-left leg on the left (-X)")
	assert_lt(fl.global_position.z, 0.0, "front legs in front (-Z)")
	wolf.queue_free()


func test_knight_parts_plates_and_weak_point() -> void:
	var knight := _spawn(&"knight")
	var h := _box(knight, "head")
	assert_almost_eq(h.get_center().y, 1.8, 0.08, "helmet centred on the 1.8 m weak point")
	var shield := _box(knight, "shield")
	assert_almost_eq(shield.get_center().x, -0.1, 0.12, "shield on the left")
	assert_almost_eq(shield.get_center().y, 1.1, 0.12, "shield height")
	assert_lt(shield.get_center().z, -0.3, "shield in front")
	assert_gt(shield.size.y, 0.85, "shield covers the torso")
	var arm_l := knight.find_child("arm_l", true, false)
	assert_true(knight.find_child("shield", true, false).get_parent() == arm_l, "shield strapped to the left arm")
	var weapon := _box(knight, "weapon")
	assert_lt(weapon.position.z, -1.0, "sword held forward")
	var plates := 0
	for child in knight.find_children("plate_*", "MeshInstance3D", true, false):
		plates += 1
	assert_eq(plates, 6, "six plates can fly off")
	var all := _bounds(knight)
	assert_almost_eq(all.position.y, 0.0, 0.03, "stands on the floor")
	assert_lt(all.end.y, 2.05, "fits the 2 m capsule")
	knight.queue_free()


func test_bust_enemy_glows_from_its_cracks() -> void:
	var bust := _spawn(&"bust_enemy")
	var mesh := bust.find_child("bust", true, false) as MeshInstance3D
	var mat := mesh.get_surface_override_material(0) as BaseMaterial3D
	assert_true(mat.emission_enabled, "crack mask is emissive")
	assert_not_null(mat.emission_texture, "emission texture")
	var owned := ArtLibrary.own_materials(bust)
	assert_gt(owned.size(), 0, "per-instance copies for the telegraph")
	assert_true(mesh.get_surface_override_material(0) != mat, "instance no longer shares the material")
	var plinth := _box(bust, "plinth")
	assert_lt(plinth.end.y, 0.0, "plinth fragment floats under the chest")
	bust.queue_free()


func test_trex_size_budget_and_crystal_socket() -> void:
	var rex := _spawn(&"trex")
	var all := _bounds(rex)
	assert_gt(all.size.z, 10.3, "about 11 m nose to tail")
	assert_lt(all.size.z, 11.7, "about 11 m nose to tail")
	assert_gt(all.end.y, 4.6, "hips about 5 m up")
	assert_lt(all.end.y, 5.6, "hips about 5 m up")
	assert_almost_eq(all.position.y, 0.0, 0.05, "feet on the floor")
	assert_lt(_triangles(rex), 40000, "under the 40k triangle budget")
	var socket := rex.find_child("CrystalSocket", true, false) as Node3D
	assert_not_null(socket, "CrystalSocket marker")
	if socket != null:
		assert_eq(String(socket.get_parent().name), "ribs", "socket rides on the rib cage")
		assert_gt(socket.global_position.y, 2.8, "socket inside the rib cage")
		assert_lt(socket.global_position.y, 3.8, "socket inside the rib cage")
	var tail := rex.find_child("tail_8", true, false)
	var depth := 0
	while tail != null and tail != rex:
		tail = tail.get_parent()
		depth += 1
	assert_gt(depth, 8, "tail is a chain of 8 nested segments under the pelvis")
	rex.queue_free()


func test_viewmodels_keep_greybox_muzzles_and_fov() -> void:
	# greybox muzzle positions from src/weapons/viewmodels.gd
	var muzzles := {&"vm_taser": Vector3(0.0, 0.01, -0.13), &"vm_pistol": Vector3(0.0, 0.01, -0.12),
		&"vm_shotgun": Vector3(0.0, 0.0, -0.48)}
	for id in muzzles:
		var view := _spawn(id)
		var muzzle := view.get_node_or_null(^"Muzzle") as Node3D
		assert_not_null(muzzle, "%s Muzzle is a direct child" % id)
		if muzzle != null:
			assert_lt(muzzle.position.distance_to(muzzles[id]), 0.01, "%s muzzle where the greybox had it" % id)
		for child in view.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % id)
			var mat := mesh.get_surface_override_material(0) as BaseMaterial3D
			assert_true(mat.use_fov_override, "%s own FOV" % id)
			assert_almost_eq(mat.fov_override, 55.0, 0.01, "%s FOV like the greybox" % id)
		view.queue_free()
	var fists := _spawn(&"vm_fists")
	assert_lt((fists.find_child("fist_l", true, false) as Node3D).position.length(), 0.001, "left fist at the origin")
	fists.queue_free()


func test_props_markers_and_screens() -> void:
	var lantern := _spawn(&"lantern")
	var light := lantern.find_child("Light", true, false) as Node3D
	assert_not_null(light, "lantern Light marker")
	assert_gt(light.position.z, 0.05, "light in front of the lens (+Z)")
	lantern.queue_free()
	var locker := _spawn(&"pistol_locker")
	assert_not_null(locker.find_child("Pistol", true, false), "pistol spot")
	var door := locker.find_child("door", true, false) as Node3D
	assert_lt(door.position.x, -0.2, "door pivots on its left hinge")
	locker.queue_free()
	var bank := _spawn(&"cctv_bank")
	var screens := {}
	for child in bank.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_surface_override_material(i) as BaseMaterial3D
			if mat.resource_name.begins_with("cctv_screen"):
				screens[mat.resource_name] = mat
				assert_true(mat.emission_enabled, "screen glows")
	assert_eq(screens.size(), 6, "six separate screen materials")
	bank.queue_free()
	var terminal := _spawn(&"terminal")
	var has_screen := false
	for child in terminal.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			has_screen = has_screen or mesh.get_surface_override_material(i).resource_name == "terminal_screen"
	assert_true(has_screen, "terminal screen slot")
	terminal.queue_free()


func test_dust_mote_billboard() -> void:
	var mat := ArtLibrary.billboard("dust_mote", 4)
	assert_not_null(mat.albedo_texture, "sprite sheet loads")
	assert_eq(mat.albedo_texture.get_width(), 64, "4 frames of 16 px")
	assert_eq(mat.particles_anim_h_frames, 4, "frames")
