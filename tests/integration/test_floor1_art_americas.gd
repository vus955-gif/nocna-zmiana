extends TestCase
## Floor I's Americas and Oceania wing dressed (stage P5; plan
## docs/superpowers/plans/2026-10-10-p5-oprawa-ameryki-dach.md): every room
## wears its kit and has its light recipe, bright enough (the owner's
## playtest found rooms too dark); the Temple of the Serpent's terraces,
## flights, altar house and Sun Disc leave the guardian's arena as it was;
## the halls' exhibits fit their greybox (the harpoon on its stand, the moai
## in its beam, the canoe over the pit), the live exhibits stand on mats
## clear of the props. Built without navigation.

const ZONE := &"americas"
## The wing's exhibition rooms (the lamps burn brighter than the plan there).
const HALLS: Array[StringName] = [&"americas_temple", &"americas_north", &"americas_totems", &"americas_moai",
	&"americas_pacific", &"americas_pit"]
## The live exhibits' bodies in the slot's frame: [radius, height, centre]
## (upright capsules a hand over the floor): a totem (Totem.COLLIDER_RADIUS,
## its five faces' top and its hat), a jaguar warrior.
const BODIES := {
	&"totem": [0.55, 5.1, Vector3(0.0, 2.6, 0.0)],
	&"jaguar": [0.42, 1.9, Vector3(0.0, 1.0, 0.0)],
}
## The physics layer of the stand-in bodies for the props' looks.
const LOOK_LAYER := 1 << 17

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


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


## World positions of every vertex of [param node]'s visible meshes (its
## own too, when it is one).
func _world_vertices(node: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	var views := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		views.append(node)
	for child in views:
		var view := child as MeshInstance3D
		if view.mesh == null or not view.is_visible_in_tree():
			continue
		var xf := view.global_transform
		for s in view.mesh.get_surface_count():
			for v in (view.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(xf * v)
	return out


## The level_kit nodes of [param kit] in [param room].
func _pieces(kit: StringName, room: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == kit and node.get_meta(&"kit_room", &"") == room:
			out.append(node as Node3D)
	return out


## The temple's flights.
func _flights() -> Array[StairsSpec]:
	var out: Array[StairsSpec] = []
	for flight in level.layout.stairs:
		if flight.room_low == &"americas_temple":
			out.append(flight)
	return out


## The look of [param flight] (the stairs piece over its middle).
func _flight_look(flight: StairsSpec) -> Node3D:
	var middle := flight.frame() * Vector3(0.0, 0.0, -flight.run() * 0.5)
	for node in _pieces(&"stairs", flight.room_low):
		if node.global_position.distance_to(middle) < 0.05:
			return node.get_node_or_null(^"Visual") as Node3D
	return null


## The rooms of the wing.
func _rooms() -> Array[RoomSpec]:
	var out: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if room.zone == ZONE:
			out.append(room)
	return out


func test_every_room_of_the_wing_has_a_style_and_a_light_recipe() -> void:
	var rooms := _rooms()
	assert_eq(rooms.size(), 11, "the wing's eleven rooms")
	var recipe := Floor1LightRecipe.create(level.layout)
	for room in rooms:
		assert_true(ArtKit.has_style(room.id), "%s has a style of its own" % room.id)
		assert_true(Floor1Art.ROOM_STYLES.has(room.id), "%s is a Floor I room the art knows" % room.id)
		assert_true(recipe.rooms.has(recipe.key(room.id)), "%s has its light recipe" % room.id)
	for room_id in HALLS:
		var entry: Dictionary = recipe.rooms[recipe.key(room_id)]
		assert_true(float(entry.get("lamp_energy", 1.0)) >= 1.25, "%s's lamps burn brighter than the plan (not too dark)" % room_id)
	var egypt_darkest := 0.0
	for key: StringName in Floor1LightRecipe.ROOMS:
		if String(key).begins_with("egypt_"):
			egypt_darkest = maxf(egypt_darkest, float(Floor1LightRecipe.ROOMS[key]["fog"]))
	for room_id in HALLS:
		assert_lt(float(Floor1LightRecipe.ROOMS[room_id]["fog"]), egypt_darkest, "%s's air is thinner than Egypt's tombs" % room_id)


func test_the_temples_flights_have_stone_steps_heads_on_their_lowest_steps_and_alfardas_on_their_rails() -> void:
	var flights := _flights()
	assert_eq(flights.size(), 4, "four flights up the terraces")
	var rail_meshes: Array[MeshInstance3D] = []
	for flight in flights:
		var look := _flight_look(flight)
		assert_not_null(look, "%s wears the temple's flight" % flight.id)
		if look == null:
			continue
		var stairs := look.get_child(0)
		var steps := 0
		for child in stairs.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
				steps += 1
		assert_eq(steps, flight.step_count(), "%s: a stone block for each step" % flight.id)
		var heads: Array = _models(look).get("temple_stair", [])
		assert_eq(heads.size(), 1, "%s: the serpent heads" % flight.id)
		if heads.is_empty():
			continue
		var parts := ArtLibrary.parts(heads[0])
		assert_true((parts["temple_stair"] as MeshInstance3D).mesh == null, "the model's own flight is not drawn (the steps are)")
		assert_true((parts["serpent_heads"] as MeshInstance3D).is_visible_in_tree(), "its heads are")
		# the heads lie on the lowest steps along the pitch: over the nosing line,
		# nothing in front of the foot, beside the flight at most a head's width
		var to_flight := flight.frame().affine_inverse()
		var r := (flight.top_y - flight.bottom_y) / flight.step_count()
		var t := flight.run() / flight.step_count()
		var worst_low := INF
		var front := -INF
		var aside := 0.0
		var back := INF
		for v in _world_vertices(parts["serpent_heads"]):
			var p := to_flight * v
			worst_low = minf(worst_low, p.y - (r - p.z * r / t))
			front = maxf(front, p.z)
			back = minf(back, p.z)
			aside = maxf(aside, absf(p.x) - flight.width() * 0.5)
		assert_gt(worst_low, -0.01, "%s: the heads lie on the steps, not in them (%.3f)" % [flight.id, worst_low])
		assert_lt(front, 0.01, "%s: nothing of them in front of the flight's foot (%.2f)" % [flight.id, front])
		assert_gt(back, -3.0 * t - 0.01, "%s: on the lowest three steps (%.2f)" % [flight.id, back])
		assert_lt(aside, 0.35, "%s: hardly beside the flight (%.2f)" % [flight.id, aside])
		for child in look.find_children("*", "MeshInstance3D", true, false):
			if child.get_parent().get_meta(&"alfarda", false):
				rail_meshes.append(child as MeshInstance3D)
	# every invisible railing of the flights has its alfarda in its box
	var rails := _pieces(&"railing", &"americas_temple")
	assert_eq(rails.size(), 8, "two railings a flight")
	for rail in rails:
		var size: Vector3 = rail.get_meta(&"kit_size")
		var to_rail := rail.global_transform.affine_inverse()
		var found := false
		for view in rail_meshes:
			var lo := Vector3.INF
			var hi := -Vector3.INF
			for v in _world_vertices(view):
				var p := to_rail * v
				lo = lo.min(p)
				hi = hi.max(p)
			if hi.x - lo.x < 0.01:
				continue
			var inside := lo.x >= -size.x * 0.5 - 0.035 and hi.x <= size.x * 0.5 + 0.035 and hi.y <= size.y + 0.01
			if inside and lo.z <= -size.z * 0.5 + 0.05 and hi.z >= size.z * 0.5 - 0.05 and hi.y >= size.y - 0.05:
				found = true
		assert_true(found, "the railing at %s is drawn as an alfarda in its box" % rail.global_position)


func test_the_terraces_faces_stand_into_their_stone() -> void:
	var tiers := _pieces(&"temple_tier", &"americas_temple")
	assert_eq(tiers.size(), 2, "the two terraces")
	for tier in tiers:
		var look := tier.get_node(^"Visual")
		var size: Vector3 = tier.get_meta(&"kit_size")
		var models := _models(look)
		assert_eq((models.get("temple_tier_corner", []) as Array).size(), 4, "a carved corner on each corner")
		var runs := 0
		for id in ["temple_tier_4m", "temple_tier_2m", "temple_tier_1m"]:
			runs += (models.get(id, []) as Array).size()
		assert_gt(runs, 5, "carved faces round the terrace")
		var to_tier := tier.global_transform.affine_inverse()
		var out := 0.0
		var high := -INF
		for v in _world_vertices(look):
			var p := to_tier * v
			out = maxf(out, maxf(absf(p.x) - size.x * 0.5, absf(p.z) - size.z * 0.5))
			high = maxf(high, p.y)
		assert_lt(out, 0.3, "the faces stand at most 0.3 m before the terrace's collision (%.2f)" % out)
		assert_gt(out, 0.2, "and they show (%.2f)" % out)
		assert_lt(high, size.y + 0.01, "nothing over its top (%.3f)" % high)


func test_the_altar_house_the_altars_and_the_fire_bowls_fill_their_boxes() -> void:
	var counts := {&"shrine": 1, &"altar": 2, &"brazier": 4, &"plinth": 1}
	for kit: StringName in counts:
		var pieces := _pieces(kit, &"americas_temple")
		assert_eq(pieces.size(), counts[kit], "%s pieces in the temple" % kit)
		for piece in pieces:
			var size: Vector3 = piece.get_meta(&"kit_size")
			var to_piece := piece.global_transform.affine_inverse()
			var out := 0.0
			var high := -INF
			var vertices := _world_vertices(piece.get_node(^"Visual"))
			assert_gt(vertices.size(), 20, "%s at %s has its look" % [kit, piece.global_position])
			for v in vertices:
				var p := to_piece * v
				out = maxf(out, maxf(absf(p.x) - size.x * 0.5, absf(p.z) - size.z * 0.5))
				high = maxf(high, p.y)
			assert_lt(out, 0.04, "%s at %s stays in its box (%.3f)" % [kit, piece.global_position, out])
			if kit != &"brazier":
				assert_lt(high, size.y + 0.05, "%s at %s no taller than its box (%.2f)" % [kit, piece.global_position, high])
	var bowls: Array = _models(level).get("americas_brazier", [])
	assert_gt(bowls.size(), 8, "fire bowls all over the wing")
	for bowl: Node3D in bowls:
		if not bowl.get_meta(&"fallen_bowl", false):
			assert_true((ArtLibrary.parts(bowl)["flame"] as Node3D).is_visible_in_tree(), "a bowl burns")


func test_the_sun_disc_hangs_high_on_the_east_wall() -> void:
	var stones: Array = _models(_heroes()).get("sun_stone", [])
	assert_eq(stones.size(), 1, "one Sun Disc")
	if stones.is_empty():
		return
	var parts := ArtLibrary.parts(stones[0])
	assert_true((parts["sun_stone"] as MeshInstance3D).mesh == null, "its cradle left out")
	var disc := parts["sun_stone_disc"] as MeshInstance3D
	var box := disc.global_transform * disc.get_aabb()
	assert_gt(box.position.y, 2.4, "over everybody's head (%.2f)" % box.position.y)
	assert_lt(absf(box.end.x - Floor1ArtAmericas.WALL_X), 0.03, "its back on the east wall (%.3f)" % box.end.x)
	assert_lt(box.size.x, 0.7, "flat against it")
	assert_eq(level.layout.room_at(box.get_center() + Vector3(-1.0, 0.0, 0.0)), &"americas_temple", "facing into the temple")


func test_nothing_new_stands_on_the_arena_floor() -> void:
	# The arena's floor is the greybox's: the platform and its four flights, the
	# side altars, the corner bowls. Whatever the dressing draws over it, by the
	# pieces' real extents (not their centres: a run of stone or a wide base with
	# its middle off the floor still fills it), stands in one of those places
	# (a hand's width over for the terraces' faces, the bowls' rims, the serpent
	# heads at the flights' feet) - no new prop, no hero model of its own.
	var temple := level.layout.room(&"americas_temple")
	var hall := temple.parts[0]
	var inset := hall.grow(-0.7)
	var places: Array[Rect2] = []
	for spec in level.layout.pieces:
		if spec.room == temple.id and spec.size.y > 0.1:
			places.append(spec.footprint().grow(0.4))
	for flight in _flights():
		var corners: Array[Vector2] = []
		for end: float in [0.0, -flight.run()]:
			for side: float in [-1.0, 1.0]:
				var at := flight.frame() * Vector3(side * flight.width() * 0.5, 0.0, end)
				corners.append(Vector2(at.x, at.z))
		var rect := Rect2(corners[0], Vector2.ZERO)
		for corner in corners:
			rect = rect.expand(corner)
		places.append(rect.grow(0.4))
	assert_gt(places.size(), 10, "the platform, its flights, the altars, the bowls and the altar house")
	var seen := 0
	var low := 0
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if not view.is_visible_in_tree() or view.mesh == null:
			continue
		var box := view.global_transform * view.get_aabb()
		var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if not hall.intersects(foot):
			continue
		seen += 1
		# (over the temple's floor and under head height: the Sun Disc, the
		# rafters and the rooms over and under the hall are others')
		if box.end.y < 0.05 or box.position.y > 2.4 or not inset.intersects(foot):
			continue
		low += 1
		var on_floor := foot.intersection(inset)
		assert_true(places.any(func(place: Rect2) -> bool: return place.encloses(on_floor)), "%s (%s) stands on the arena's floor" % [view.get_path(), box])
	assert_gt(seen, 100, "the temple's meshes")
	assert_gt(low, 20, "and those of them standing on its floor (%d)" % low)


func test_the_serpents_markers_are_the_greyboxes() -> void:
	var plain := Floor1Layout.create()
	var compared := 0
	for marker: StringName in plain.markers:
		if not String(marker).contains("serpent"):
			continue
		compared += 1
		assert_true(level.layout.markers.has(marker), "%s kept" % marker)
		if level.layout.markers.has(marker):
			var a: Transform3D = plain.markers[marker]
			var b: Transform3D = level.layout.markers[marker]
			assert_lt(a.origin.distance_to(b.origin), 0.001, "%s where it was" % marker)
	assert_gt(compared, 30, "the Serpent's tracks, ring, summit and arena markers")


func test_the_wing_wears_its_kit() -> void:
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node.get_meta(&"kit_greybox", false):
			continue
		var spec := level.layout.room(node.get_meta(&"kit_room", &""))
		if spec != null and spec.zone == ZONE:
			fail("%s in %s still wears the greybox" % [node.get_meta(&"kit"), spec.id])
	var used := _models(level)
	for id in Floor1ArtAmericas.MODELS:
		assert_true(ArtLibrary.KIT.has(StringName(id)) or ArtLibrary.REGISTRY.has(StringName(id)), "%s is registered" % id)
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its file" % id)
		assert_true(used.has(id), "%s is placed somewhere" % id)


func test_the_harpoon_gun_lies_on_its_stand() -> void:
	var stands: Array = _models(level).get("harpoon_stand", [])
	assert_eq(stands.size(), 1, "the harpoon gun's stand")
	if stands.is_empty():
		return
	var stand: Node3D = stands[0]
	var spot := ArtLibrary.parts(stand).get("weapon_spot") as Node3D
	var marker: Transform3D = level.layout.markers[&"weapon_harpoon"]
	assert_lt(spot.global_position.distance_to(marker.origin), 0.02, "its forks under the weapon's marker (the pickup lies there)")
	assert_gt(absf(stand.global_basis.x.normalized().dot(Vector3.RIGHT)), 0.99, "the forks along X, as the gun lies")
	var racks: Array = _models(level).get("whaling_rack", [])
	assert_eq(racks.size(), 1, "the whaling display on the north wall")
	if not racks.is_empty():
		var box := _bounds(racks[0])
		assert_lt(box.position.z - (-85.5), 0.05, "its back on the wall (%.3f)" % box.position.z)


func test_the_moai_stands_on_its_plinth_with_its_face_in_the_beam() -> void:
	var heads: Array = _models(level).get("moai", [])
	assert_eq(heads.size(), 1, "one moai")
	if heads.is_empty():
		return
	var moai: Node3D = heads[0]
	var parts := ArtLibrary.parts(moai)
	var plinth := Rect2(-40.5 - 1.6, -56.6 - 1.6, 3.2, 3.2)
	var base := parts["moai_plinth"] as MeshInstance3D
	var box := base.global_transform * base.get_aabb()
	assert_true(plinth.grow(0.03).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "the model's plinth fills the greybox plinth (%s)" % box)
	var statue := parts["moai"] as MeshInstance3D
	var body := statue.global_transform * statue.get_aabb()
	var greybox := Rect2(-40.5 - 1.2, -56.6 - 1.0, 2.4, 2.0)
	assert_true(greybox.grow(0.3).encloses(Rect2(body.position.x, body.position.z, body.size.x, body.size.z)), "the statue in the greybox moai's box (%s)" % body)
	assert_gt(body.end.y, 4.5, "towering (%.2f)" % body.end.y)
	var face := (parts["face"] as Node3D).global_position
	var lit := false
	for spec in level.layout.lights:
		if spec.room == &"americas_moai" and spec.kind == LightSpec.Kind.SPOT and spec.shadow:
			var to_face := (face - spec.position).normalized()
			lit = lit or rad_to_deg(acos(clampf(to_face.dot(spec.direction.normalized()), -1.0, 1.0))) < 8.0
	assert_true(lit, "its face in the uplight's beam (%s)" % face)


func test_the_war_canoe_hangs_over_the_pit_on_its_rope() -> void:
	var canoes: Array = _models(level).get("war_canoe", [])
	assert_eq(canoes.size(), 1, "the war canoe")
	if canoes.is_empty():
		return
	var pit := level.layout.room(&"americas_pit")
	var box := _bounds(canoes[0])
	assert_true(pit.parts[0].grow(0.02).encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)), "over the pit (%s)" % box)
	assert_gt(box.position.y, 5.0, "high over the gallery's floor")
	var top := (ArtLibrary.parts(canoes[0])["rope_top"] as Node3D).global_position
	assert_lt(absf(top.y - (pit.ceiling_y - Floor1ArtAmericas.ROPE_GAP)), 0.05, "its rope reaching the ceiling (%.2f)" % top.y)


func test_the_ancestor_posts_and_bark_cloths_stand_flat_on_the_pacific_walls() -> void:
	var gallery := level.layout.room(&"americas_pacific").parts[0]
	var posts: Array = _models(_heroes()).get("pacific_post", [])
	assert_eq(posts.size(), Floor1ArtAmericas.POSTS.size(), "the ancestor posts")
	var tapas := 0
	for model in posts + (_models(_heroes()).get("tapa_hanging", []) as Array):
		var box := _bounds(model)
		# the depth off the nearest wall face
		var depth := minf(minf(box.end.x - gallery.position.x, gallery.end.x - box.position.x), minf(box.end.z - gallery.position.y, gallery.end.y - box.position.z))
		assert_lt(depth, 0.32, "%s at %s no deeper than a relief on its wall (%.2f)" % [model.name, (model as Node3D).global_position, depth])
		assert_lt(box.end.y, 9.6, "under the rafters (%.2f)" % box.end.y)
		if String(model.scene_file_path).contains("tapa"):
			tapas += 1
			assert_gt(box.position.y, 1.45, "a bark cloth hangs over the dado (%.2f)" % box.position.y)
	assert_eq(tapas, Floor1ArtAmericas.TAPAS.size(), "bark cloths on the walls")


func test_every_sconce_of_the_halls_is_fire_on_a_bracket() -> void:
	var sconces := 0
	for light in level.layout.lights:
		if String(light.room).begins_with("americas_") and light.fixture == &"sconce":
			sconces += 1
	var torches := 0
	for node in level.lights.get_children():
		if String(node.get_meta(&"kit_room", &"")).begins_with("americas_") and node.get_meta(&"kit", &"") == &"sconce" and _models(node).has("americas_torch_lamp"):
			torches += 1
	assert_gt(sconces, 4)
	assert_eq(torches, sconces, "a fire bowl on a bracket for every sconce")


## World bounds of [param node]'s visible meshes.
func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if not view.is_visible_in_tree() or view.mesh == null:
			continue
		var box := view.global_transform * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func test_live_slots_stand_on_their_mats_clear_of_the_props() -> void:
	var mats: Array[Node3D] = []
	for node in _heroes().find_children("ExhibitMat_*", "Node3D", true, false):
		if String(node.get_parent().get_meta(&"kit_room", &"")).begins_with("americas_"):
			mats.append(node as Node3D)
	# the props' looks (no collision of their own): a stand-in body per box on
	# a layer of its own lets the exhibits' capsules be queried against them
	var stand_ins := StaticBody3D.new()
	stand_ins.collision_layer = LOOK_LAYER
	stand_ins.collision_mask = 0
	add_child(stand_ins)
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or node.get_meta(&"kit_role", &"") != &"prop":
			continue
		if not String(node.get_meta(&"kit_room", &"")).begins_with("americas_"):
			continue
		var look := (node as Node).get_node_or_null(^"Visual")
		if look == null:
			continue
		for child in look.find_children("*", "MeshInstance3D", true, false):
			var view := child as MeshInstance3D
			if not view.visible or view.mesh == null:
				continue
			var box := view.global_transform * view.get_aabb()
			var form := BoxShape3D.new()
			form.size = box.size.max(Vector3.ONE * 0.01)
			var shape := CollisionShape3D.new()
			shape.shape = form
			shape.position = box.get_center()
			stand_ins.add_child(shape)
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var standing := 0
	for slot in level.layout.spawn_slots:
		if not Floor1ArtAmericas.MAT_ROOMS.has(slot.room) or slot.patrol != &"" or not slot.dormant:
			continue
		var kind := &"jaguar" if slot.kinds.has(&"jaguar") else (&"totem" if slot.kinds.has(&"totem") else &"")
		if kind == &"":
			continue
		standing += 1
		var at := slot.position
		assert_true(mats.any(func(m: Node3D) -> bool: return m.global_position.distance_to(at) < 0.05), "a display mat under the slot at %s" % at)
		var body: Array = BODIES[kind]
		var capsule := CapsuleShape3D.new()
		capsule.radius = float(body[0])
		capsule.height = float(body[1])
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = Layers.WORLD | LOOK_LAYER
		query.transform = Transform3D(Basis(Vector3.UP, slot.yaw), at) * Transform3D(Basis.IDENTITY, body[2])
		for hit in space.intersect_shape(query, 4):
			var what: Object = hit["collider"]
			var label: String = "a prop's look" if what == stand_ins else String(what.get_meta(&"kit", what.name))
			fail("the %s at %s has %s in its body (r %.2f)" % [kind, at, label, capsule.radius])
	assert_gt(standing, 15, "the halls' standing exhibits")
	assert_eq(mats.size(), standing, "one mat per standing exhibit")


func test_embers_and_smoke_over_every_fire_bowl_and_dust_in_the_halls() -> void:
	var bowls: Array[Vector3] = []
	for spec in level.layout.pieces:
		if spec.kit == &"brazier" and String(spec.room).begins_with("americas_"):
			bowls.append(spec.position + Vector3.UP * Floor1ArtAmericas.BOWL_FLAME)
	assert_eq(bowls.size(), 9, "nine fire bowls in the wing")
	var embers: Array[Vector3] = []
	var smoke: Array[Vector3] = []
	var dust := {}
	for node in level.lights.get_children():
		if not node is GPUParticles3D:
			continue
		var spec := level.layout.room(node.get_meta(&"room", &""))
		if spec == null or spec.zone != ZONE:
			continue
		assert_true(node.is_in_group(GraphicsQuality.PARTICLES), "%s follows the presets" % node.name)
		var at := (node as Node3D).global_position
		if node.get_meta(&"embers", false):
			embers.append(at)
		elif node.get_meta(&"smoke", false):
			smoke.append(at)
		else:
			dust[spec.id] = true
	for flame in bowls:
		assert_true(embers.any(func(p: Vector3) -> bool: return p.distance_to(flame) < 0.05), "embers rise off the bowl at %s" % flame)
		assert_true(smoke.any(func(p: Vector3) -> bool: return Vector2(p.x - flame.x, p.z - flame.z).length() < 0.05 and p.y > flame.y), "smoke over the bowl at %s" % flame)
	assert_eq(smoke.size(), bowls.size(), "smoke only over the bowls")
	assert_true(embers.any(func(p: Vector3) -> bool: return p.distance_to(Floor1ArtAmericas.PIT_EMBERS) < 0.05), "the fallen fire's embers glow in the pit")
	for room in [&"americas_temple", &"americas_north", &"americas_totems", &"americas_pacific"]:
		assert_true(dust.has(room), "smoke and dust float in %s" % room)


func test_the_fires_go_out_in_a_blackout_and_the_temples_moon_stays() -> void:
	var bowls: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == &"brazier" and String(node.get_meta(&"kit_room", &"")).begins_with("americas_"):
			bowls.append((node as Node).get_node(^"Visual") as Node3D)
	assert_eq(bowls.size(), 9)
	for look in bowls:
		assert_true(LevelKit.is_lit(look), "a bowl burns at night")
	NightModifiers.apply(level, &"blackout", RunState)
	for look in bowls:
		assert_false(LevelKit.is_lit(look), "the bowl at %s goes out with the power (it is on its hall's circuit)" % look.global_position)
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
		if level.is_ancestor_of(node) and String(node.get_meta(&"kit_room", &"")).begins_with("americas_") and node.has_meta(&"light"):
			assert_false(LevelKit.is_lit(node), "%s goes dark" % node.get_meta(&"kit_room"))
	var skies := 0
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON) and node.get_meta(&"room", &"") == &"americas_temple":
			skies += 1
			assert_true((node as Light3D).visible, "the moon over the temple has no fuse")
	assert_eq(skies, 2, "the moon's shaft on the altar and the cold sky down the well")
	# no embers and no smoke over a bowl that has gone out (nor over the fallen one)
	var fires := 0
	for node in level.lights.get_children():
		if node is GPUParticles3D and (node.get_meta(&"embers", false) or node.get_meta(&"smoke", false)) and String(node.get_meta(&"room", &"")).begins_with("americas_"):
			fires += 1
			assert_false((node as GPUParticles3D).emitting, "%s over %s stops with its flame" % [node.name, node.get_meta(&"room")])
	assert_eq(fires, 9 * 2 + 1, "embers and smoke over nine bowls and the fallen one's embers")


func test_the_moai_room_is_dark_by_design_but_not_black_and_the_ring_has_its_beam() -> void:
	var fills := 0.0
	var beams := 0
	var heads: Array = _models(level).get("moai", [])
	assert_eq(heads.size(), 1, "one moai")
	if heads.is_empty():
		return
	var ring := (ArtLibrary.parts(heads[0])["hook_ring"] as Node3D).global_position
	assert_lt(ring.distance_to(Floor1ArtAmericas.MOAI_RING), 0.1, "the lamps are aimed at the ring where the model has it (%s)" % ring)
	for node in level.lights.get_children():
		if not node is Light3D or node.get_meta(&"room", &"") != &"americas_moai" or not node.get_meta(&"recipe_extra", false):
			continue
		var lamp := node as Light3D
		if not lamp.is_in_group(LightSpec.MAIN):
			continue
		if lamp is SpotLight3D and lamp.global_position.y < 1.0:
			var spot := lamp as SpotLight3D
			var to_ring := (ring - spot.global_position)
			if to_ring.length() < spot.spot_range and rad_to_deg(acos(clampf(to_ring.normalized().dot(-spot.global_basis.z), -1.0, 1.0))) < spot.spot_angle:
				beams += 1
		elif lamp.light_color != Floor1ArtAmericas.UPLIGHT:
			fills += lamp.light_energy
	assert_gt(beams, 1, "the iron ring on the plinth's back stands in the beam of the lamps behind it (%d)" % beams)
	# the fills and the bounce: windowed, 0.9 of fill (1.35 in the world) left
	# the head view at 0.014 (a third of Egypt's too-dark gallery); 15 in the
	# world (10 of recipe, x1.5 of the room's lamp energy) measured 0.046
	assert_gt(fills, 9.0, "the room's fills and bounce light it (%.1f)" % fills)


func test_the_exhibit_mats_share_their_meshes() -> void:
	var meshes := {}
	var mats := 0
	for hall in _heroes().find_children("ExhibitMats_americas_*", "Node3D", true, false):
		for mat in hall.get_children():
			mats += 1
			for child in mat.get_children():
				if child is MeshInstance3D:
					meshes[(child as MeshInstance3D).mesh] = true
	assert_gt(mats, 15, "a mat under every standing exhibit")
	# (a jaguar's mat: a slab and a plait; a totem's: a disc and a ring; the
	# plaque is a model with meshes of its own)
	assert_lt(meshes.size(), 5, "one set of meshes for them all (%d meshes, %d mats)" % [meshes.size(), mats])
