extends TestCase
## Floor I's roof dressed (stage P5; plan
## docs/superpowers/plans/2026-10-10-p5-oprawa-ameryki-dach.md section 4):
## every room wears its kit and has its light recipe. Built without
## navigation.

const ZONE := &"roof"
## The roof's mesh nodes and distinct meshes (pieces and heroes) at most.
const MAX_ROOF_NODES := 540
const MAX_ROOF_MESHES := 330

## The tests that change the level (blackouts, culling, quality presets, parts
## taken away) build their own; all the others look at one built for the file
## (TestCase.shared_fixture: the runner fails a test that changed it).
const OWN_LEVEL: Array[StringName] = [
	&"test_the_court_glows_up_through_the_glass_and_the_moon_has_no_fuse",
]

var level: MuseumFloorLevel


func before_each() -> void:
	level = DressedFloor.build(self) if OWN_LEVEL.has(current_test) else await shared_fixture(&"dressed_floor", DressedFloor.build)


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


## The rooms of the roof.
func _rooms() -> Array[RoomSpec]:
	var out: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if room.zone == ZONE:
			out.append(room)
	return out


func test_every_room_of_the_roof_has_a_style_and_a_light_recipe() -> void:
	var rooms := _rooms()
	assert_eq(rooms.size(), 5, "the tower, the catwalks, the plant deck, the loft and the shed")
	var recipe := Floor1LightRecipe.create(level.layout)
	for room in rooms:
		assert_true(ArtKit.has_style(room.id), "%s has a style of its own" % room.id)
		assert_true(Floor1Art.ROOM_STYLES.has(room.id), "%s is a Floor I room the art knows" % room.id)
		assert_true(recipe.rooms.has(recipe.key(room.id)), "%s has its light recipe" % room.id)
	# the night outside is thin: the moon's pools carry it, no indoor haze
	for room_id in [&"roof_catwalks", &"roof_plant"]:
		assert_lt(float(Floor1LightRecipe.ROOMS[room_id]["fog"]), 0.006, "%s's night air is clear" % room_id)


## Model id -> nodes of it under [param root].
func _models(root: Node) -> Dictionary:
	var out := {}
	for node in root.find_children("*", "Node3D", true, false):
		var path := String(node.scene_file_path)
		if path.begins_with("res://assets/models/"):
			var id := path.get_file().trim_suffix(".glb")
			if not out.has(id):
				out[id] = []
			(out[id] as Array).append(node)
	return out


func _heroes() -> Node:
	return level.structure.get_node(^"Dressing/Floor1Heroes")


## World bounds of [param node]'s visible meshes (its own too).
func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	var views := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		views.append(node)
	for child in views:
		var view := child as MeshInstance3D
		if not view.is_visible_in_tree() or view.mesh == null:
			continue
		var box := view.global_transform * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## The level_kit nodes of [param kit] in the roof's rooms.
func _pieces(kit: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or node.get_meta(&"kit", &"") != kit:
			continue
		var spec := level.layout.room(node.get_meta(&"kit_room", &""))
		if spec != null and spec.zone == ZONE:
			out.append(node as Node3D)
	return out


func test_the_roof_wears_its_kit() -> void:
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node.get_meta(&"kit_greybox", false):
			continue
		var spec := level.layout.room(node.get_meta(&"kit_room", &""))
		if spec != null and spec.zone == ZONE:
			fail("%s in %s still wears the greybox" % [node.get_meta(&"kit"), spec.id])
	var used := _models(level)
	for id in Floor1ArtRoof.MODELS:
		assert_true(ArtLibrary.KIT.has(StringName(id)) or ArtLibrary.REGISTRY.has(StringName(id)), "%s is registered" % id)
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its file" % id)
		assert_true(used.has(id), "%s is placed somewhere" % id)


func test_the_outer_dome_sits_on_the_drum_under_its_lantern() -> void:
	var domes: Array = _models(_heroes()).get("rr_dome_outer", [])
	assert_eq(domes.size(), 1, "the Reading Room's leaded dome")
	if domes.is_empty():
		return
	var dome := _bounds(domes[0])
	assert_lt(absf(dome.position.y - (Floor1ArtRoof.ROOF_Y + 2.5)), 0.05, "on the drum's top (%.2f)" % dome.position.y)
	assert_lt(absf(dome.end.y - Floor1ArtRoof.DOME_TOP), 0.05, "its crown at %.2f" % dome.end.y)
	var drums := _pieces(&"dome_drum")
	assert_eq(drums.size(), 16, "the drum's sixteen segments")
	var lanterns: Array[Node3D] = []
	for piece in _pieces(&"dome_lantern"):
		if piece.get_node(^"Visual").find_children("*", "MeshInstance3D", true, false).size() > 0:
			lanterns.append(piece)
	assert_eq(lanterns.size(), 1, "one lantern drawn (the greybox has two crossed boxes)")
	var red := Vector3.INF
	for spec in level.layout.lights:
		if spec.room == &"roof_catwalks" and spec.group == LightSpec.EMERGENCY and Vector2(spec.position.x, spec.position.z).length() < 0.1:
			red = spec.position
	assert_true(red.is_finite(), "the red warning lamp over the dome")
	if not lanterns.is_empty():
		var lantern := _bounds(lanterns[0].get_node(^"Visual"))
		assert_lt(absf(lantern.position.y - dome.end.y), 0.08, "the lantern stands on the dome's crown (%.2f)" % lantern.position.y)
		assert_lt(lantern.end.y, red.y - 0.1, "its spire under the warning lamp (%.2f)" % lantern.end.y)


func test_every_roof_railing_is_steel_with_posts_and_a_hand_rail() -> void:
	# (the tower's flights keep their invisible railings: its walls close them)
	var rails := _pieces(&"railing").filter(func(n: Node3D) -> bool: return n.get_meta(&"kit_room") == &"roof_catwalks")
	assert_gt(rails.size(), 30, "the gutter's, the catwalks' and the ring's railings")
	for rail: Node3D in rails:
		var look := rail.get_node(^"Visual")
		var size: Vector3 = rail.get_meta(&"kit_size")
		# the rods it is made of: posts at both ends and at most POST_STEP apart,
		# the hand rail at 1.05 m over them
		var posts: Array[float] = []
		var hand := 0.0
		for rod: Array in Floor1ArtRoof.railing_rods(size):
			var a: Vector3 = rod[0]
			var b: Vector3 = rod[1]
			if absf(a.x - b.x) < 0.001 and b.y - a.y > 0.9:
				posts.append(a.x)
			elif absf(a.y - b.y) < 0.001 and b.x - a.x > size.x * 0.9:
				hand = maxf(hand, a.y)
		assert_gt(posts.size(), 1, "posts along the railing at %s" % rail.global_position)
		posts.sort()
		assert_lt(posts[0] + size.x * 0.5, 0.06, "a post at its start")
		assert_lt(size.x * 0.5 - posts[posts.size() - 1], 0.06, "a post at its end")
		for i in range(1, posts.size()):
			assert_lt(posts[i] - posts[i - 1], Floor1ArtRoof.POST_STEP + 0.001, "posts at most %.0f m apart" % Floor1ArtRoof.POST_STEP)
		assert_almost_eq(hand, Floor1ArtRoof.RAIL_TOP, 0.001, "the hand rail at 1.05 m")
		# drawn as one steel mesh (one draw, one resource) in its box
		var views := look.find_children("*", "MeshInstance3D", true, false)
		assert_eq(views.size(), 1, "a railing is one mesh at %s" % rail.global_position)
		var view := views[0] as MeshInstance3D
		assert_eq(view.material_override, Floor1ArtRoof.steel(), "of painted steel")
		var to_rail := rail.global_transform.affine_inverse()
		var box := to_rail * view.global_transform * view.get_aabb()
		assert_true(box.end.y > 1.0 and box.end.y <= size.y, "its hand rail at 1.05 m in its box (%.2f)" % box.end.y)
		var out := maxf(maxf(absf(box.position.z), absf(box.end.z)) - size.z * 0.5, maxf(absf(box.position.x), absf(box.end.x)) - size.x * 0.5)
		assert_lt(out, 0.02, "in the railing's box (%.3f)" % out)


func test_the_roof_shares_its_meshes() -> void:
	# the first build made every rod its own node and its own mesh (350 of
	# each in the railings alone, and as many bars in the glass fields): a
	# railing is one merged mesh, railings of one size share it
	var sizes := {}
	var meshes := {}
	for rail in _pieces(&"railing"):
		var views := rail.get_node(^"Visual").find_children("*", "MeshInstance3D", true, false)
		if views.is_empty():
			continue   # the tower's flights keep their invisible railings
		var size: Vector3 = rail.get_meta(&"kit_size")
		sizes[Vector3i((size * 1000.0).round())] = true
		for view in views:
			meshes[(view as MeshInstance3D).mesh] = true
	assert_gt(sizes.size(), 3, "railings of several sizes")
	assert_lt(meshes.size(), sizes.size() + 1, "one mesh a size (%d meshes, %d sizes)" % [meshes.size(), sizes.size()])
	# and the whole roof (pieces and heroes) stays well under its first count
	# of 927 mesh nodes over 768 distinct meshes (493 over 297 now: the glazing
	# bars are one mesh a field as well)
	var nodes := 0
	var distinct := {}
	var roots: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and String(node.get_meta(&"kit_room", &"")).begins_with("roof_"):
			roots.append(node)
	for group in _heroes().get_children():
		if String(group.get_meta(&"kit_room", &"")).begins_with("roof_"):
			roots.append(group)
	for root in roots:
		for view in root.find_children("*", "MeshInstance3D", true, false):
			if (view as MeshInstance3D).mesh != null:
				nodes += 1
				distinct[(view as MeshInstance3D).mesh] = true
	assert_lt(nodes, MAX_ROOF_NODES, "mesh nodes on the roof (%d)" % nodes)
	assert_lt(distinct.size(), MAX_ROOF_MESHES, "distinct meshes on the roof (%d)" % distinct.size())


func test_the_glass_fields_are_clear_with_their_glazing_bars() -> void:
	var panes := _pieces(&"roof_glass")
	assert_eq(panes.size(), 8, "two glass fields a quarter")
	for pane in panes:
		var look := pane.get_node(^"Visual")
		var size: Vector3 = pane.get_meta(&"kit_size")
		var glass := 0
		var bars: MeshInstance3D = null
		for child in look.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			assert_eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "nothing of the glass field shades the court")
			if view.material_override == LevelKit.glass():
				glass += 1
			elif view.get_parent().name == "Glazing":
				assert_true(bars == null, "the angles and the bars are one mesh")
				bars = view
		assert_eq(glass, 1, "a clear pane")
		# steel angles round it and glazing bars across (a slab each), drawn as one mesh
		assert_gt(Floor1ArtRoof.glazing_slabs(size).size(), 6, "angles and bars over %s" % size)
		assert_not_null(bars, "the glazing")
		if bars == null:
			continue
		assert_eq(bars.material_override, Floor1ArtRoof.steel(), "of painted steel")
		var box := bars.get_aabb()
		# (the angles are centred on the field's edges: 0.06 wide)
		assert_lt(absf(box.size.x - (size.x + 0.06)), 0.001, "across the whole field (%.3f of %.3f)" % [box.size.x, size.x])
		assert_lt(absf(box.size.z - (size.z + 0.06)), 0.001, "and along it (%.3f of %.3f)" % [box.size.z, size.z])
		assert_gt(box.position.y, size.y - 0.001, "on the glass, not in it")
		assert_lt(box.end.y, size.y + 0.051, "a hand over it at most")


func test_the_court_glows_up_through_the_glass_and_the_moon_has_no_fuse() -> void:
	var fields: Array[Rect2] = []
	for spec in level.layout.pieces:
		if spec.kit == &"roof_glass":
			fields.append(spec.footprint())
	var glows := 0
	for node in level.lights.get_children():
		if not node is Light3D or node.get_meta(&"room", &"") != &"roof_catwalks" or not node.get_meta(&"recipe_extra", false):
			continue
		var at := (node as Node3D).global_position
		if node is OmniLight3D:
			glows += 1
			assert_true(fields.any(func(f: Rect2) -> bool: return f.has_point(Vector2(at.x, at.z))), "a glow under a glass field (%s)" % at)
			assert_lt(at.y, Floor1ArtRoof.ROOF_Y, "under the glass")
			assert_false((node as Light3D).shadow_enabled, "without a shadow")
	assert_eq(glows, fields.size(), "the court's warm glow under every glass field")
	NightModifiers.apply(level, &"blackout", RunState)
	var moons := 0
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON) and String(node.get_meta(&"room", &"")).begins_with("roof_"):
			moons += 1
			assert_true((node as Light3D).visible, "the moon over the roof has no fuse")
	assert_gt(moons, 10, "moon pools along the gutters and round the dome")


func test_the_catwalk_plates_lie_flat_on_the_roof() -> void:
	var groups := 0
	for name in ["CatwalkPlates", "DeckBridge"]:
		for node in _heroes().find_children(name, "Node3D", true, false):
			groups += 1
			var box := _bounds(node)
			assert_gt(box.position.y, Floor1ArtRoof.ROOF_Y, "%s over the roof" % name)
			assert_lt(box.end.y, Floor1ArtRoof.ROOF_Y + 0.05, "%s flat (%.3f)" % [name, box.end.y])
			# and over the roof's floor: every plate's footprint lies inside the
			# room it is dressed for (no plate hangs over the gutter or a wall)
			var room := level.layout.room(node.get_meta(&"kit_room", &""))
			assert_not_null(room, "%s belongs to a room" % name)
			if room == null:
				continue
			var plates := 0
			for view in node.find_children("*", "MeshInstance3D", true, false):
				var mesh := view as MeshInstance3D
				if mesh.mesh == null:
					continue
				plates += 1
				var footprint := mesh.global_transform * mesh.get_aabb()
				for corner: Vector2 in [Vector2(footprint.position.x, footprint.position.z), Vector2(footprint.end.x, footprint.position.z),
						Vector2(footprint.position.x, footprint.end.z), Vector2(footprint.end.x, footprint.end.z)]:
					assert_true(room.covers(corner), "%s's plate corner %s over %s's floor" % [name, corner, room.id])
			assert_gt(plates, 0, "%s has its plates" % name)
	assert_eq(groups, 2, "the catwalks' plates and the deck's bridge")


func test_the_catwalk_plates_ring_like_steel_underfoot() -> void:
	# the plates are decor over the lead slab (no collision of their own): the
	# steps over their footprint sound as metal, those beside them as stone
	var r := Floor1ArtRoof.ROOF_Y
	var on_plate := [
		[&"roof_catwalks", Vector3(0.0, r, -20.0)], [&"roof_catwalks", Vector3(1.4, r, -16.0)],   # the north spoke
		[&"roof_catwalks", Vector3(20.0, r, 0.0)], [&"roof_catwalks", Vector3(-20.0, r, -1.0)], [&"roof_catwalks", Vector3(0.5, r, 20.0)],   # the others
		[&"roof_catwalks", Vector3(0.0, r, -14.0)], [&"roof_catwalks", Vector3(10.0, r, 10.0)],   # the ring (an octagon)
		[&"roof_plant", Vector3(26.5, r, 33.0)],   # the deck's bridge
	]
	for case: Array in on_plate:
		assert_eq(Surface.of_room_at(case[0], case[1]), Surface.METAL, "plates at %s %s" % [case[0], case[1]])
	var beside := [
		[&"roof_catwalks", Vector3(3.0, r, -20.0)], [&"roof_catwalks", Vector3(0.0, r, -10.0)], [&"roof_catwalks", Vector3(0.0, r, -27.0)],
		[&"roof_catwalks", Vector3(18.0, r, 18.0)], [&"roof_plant", Vector3(35.0, r, 40.0)], [&"roof_plant", Vector3(26.5, r, 40.0)],
		[&"roof_shed", Vector3(-27.5, r, -27.0)], [&"roof_loft", Vector3(19.5, r, 40.0)],
	]
	for case: Array in beside:
		var want := Surface.WOOD if case[0] == &"roof_shed" or case[0] == &"roof_loft" else Surface.STONE
		assert_eq(Surface.of_room_at(case[0], case[1]), want, "no plate at %s %s" % [case[0], case[1]])
	# the plates the art draws are the plates the steps hear: the middle of
	# every plate mesh rings
	var heard := 0
	for name in ["CatwalkPlates", "DeckBridge"]:
		for node in _heroes().find_children(name, "Node3D", true, false):
			for view in node.find_children("*", "MeshInstance3D", true, false):
				var mesh := view as MeshInstance3D
				if mesh.mesh == null or mesh.name == "Ring":
					continue
				var box := mesh.global_transform * mesh.get_aabb()
				var middle := box.get_center()
				assert_eq(Surface.of_room_at(node.get_meta(&"kit_room"), Vector3(middle.x, r, middle.z)), Surface.METAL, "the plate at %s" % middle)
				heard += 1
	assert_eq(heard, 5, "four spokes and the bridge")
	# the real lookup finds the room under the foot as the level says it
	assert_eq(Surface.of(null, Vector3(0.0, r + 0.05, -20.0), get_tree()), Surface.METAL, "steps on the north spoke ring")
