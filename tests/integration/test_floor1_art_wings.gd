extends TestCase
## Floor I's Greek and Enlightenment wings dressed (stage P3; plan
## docs/superpowers/plans/2026-10-03-p3-oprawa-grecja-oswiecenie.md): every
## room wears its kit, the Nereid Monument fits its greybox, the skylights
## carry their laylights, the library's bookcases run from pilaster to
## pilaster with the sconces on those pilasters, the rifle's rack stands
## behind the rifle, the orrery's floor stays clear, the wings' light
## recipes (Greece the brightest, the library's pages), the clocks tick and
## the hidden study's door is a bookcase. Built without navigation.

const Enlightenment := preload("res://src/level/floor1/zones/enlightenment.gd")
const Greece := preload("res://src/level/floor1/zones/greece.gd")
const WINGS: Array[StringName] = [&"greece", &"enlightenment"]

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


func test_every_room_of_both_wings_wears_its_kit() -> void:
	var rooms := 0
	for room in level.layout.rooms:
		if WINGS.has(room.zone):
			rooms += 1
			assert_true(ArtKit.has_style(room.id), "%s has a style of its own" % room.id)
	assert_gt(rooms, 25, "both wings' rooms")
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node.get_meta(&"kit_greybox", false):
			continue
		var spec := level.layout.room(node.get_meta(&"kit_room", &""))
		if spec != null and WINGS.has(spec.zone):
			fail("%s in %s still wears the greybox" % [node.get_meta(&"kit"), spec.id])
	var used := _models(level)
	for id in Floor1ArtGreece.MODELS + Floor1ArtEnlightenment.MODELS:
		assert_true(ArtLibrary.KIT.has(StringName(id)) or ArtLibrary.REGISTRY.has(StringName(id)), "%s is registered" % id)
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its file" % id)
		assert_true(used.has(id), "%s is placed somewhere" % id)


func test_the_nereid_monument_fits_its_greybox() -> void:
	var used := _models(level)
	assert_eq((used.get("nereid_podium", []) as Array).size(), 1, "one podium")
	assert_eq((used.get("nereid_temple", []) as Array).size(), 1, "one temple")
	var temple: Node3D = used["nereid_temple"][0]
	var box := _bounds(temple)
	assert_true(box.end.y <= 14.0, "the temple stays under the hall's 14 m ceiling (%.2f)" % box.end.y)
	assert_true(box.position.x >= -86.55, "its back no deeper than the wall (the Bassae room is behind it): %.2f" % box.position.x)
	# its front columns stand on the greybox's, the corner ones are left out
	var greybox: Array[Vector3] = []
	for spec in level.layout.pieces:
		if spec.kit == &"column" and spec.room == &"greece_nereid_podium":
			greybox.append(spec.position)
	assert_eq(greybox.size(), 4)
	var parts := ArtLibrary.parts(temple)
	for k in 6:
		var column := parts.get("nereid_column_%d" % (k + 1)) as MeshInstance3D
		assert_not_null(column)
		if column == null:
			continue
		if k >= 4:
			assert_false(column.visible, "the corner column %d stays out of the porch" % (k + 1))
			continue
		var at := column.global_position
		var on := greybox.any(func(p: Vector3) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < 0.05)
		assert_true(on, "column %d at %s stands on a greybox column" % [k + 1, at])
		var c := column.global_transform.basis
		assert_almost_eq(c.x.length(), c.z.length(), 0.01, "and is round")
	# the porch's floor where the greybox's is (the stylobate 2 cm over it)
	var podium := level.layout.room(&"greece_nereid_podium")
	var stylobate := temple.global_transform * Vector3(0.0, 0.3, -1.0)
	assert_almost_eq(stylobate.y, podium.floor_y + 0.02, 0.01, "the stylobate's top on the podium's walk")
	var nereids := 0
	for id in ["nereid_a", "nereid_b", "nereid_c"]:
		for node: Node3D in used.get(id, []):
			if level.layout.room_at(node.global_position + Vector3.UP * 0.5) == &"greece_nereid_podium":
				nereids += 1
	assert_eq(nereids, 3, "three Nereids between the columns")


func test_greek_skylights_and_the_arena_mouth() -> void:
	var expected := 0
	var wells: Array[Rect2] = []
	for room in level.layout.rooms:
		if room.zone != Greece.ZONE:
			continue
		for well in room.skylights:
			wells.append(well)
			expected += maxi(1, int(round(well.size.x / 4.0))) * maxi(1, int(round(well.size.y / 4.0)))
	var frames: Array = _models(_heroes()).get("gr_skylight_4m", [])
	assert_eq(frames.size(), expected, "a laylight in every cell of every Greek light well")
	for frame: Node3D in frames:
		var at := Vector2(frame.global_position.x, frame.global_position.z)
		assert_true(wells.any(func(w: Rect2) -> bool: return w.has_point(at)), "%s lies in a well" % at)
		for glass in frame.find_children("*_glass", "MeshInstance3D", true, false):
			assert_eq((glass as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the moon passes the glass")
	var mouth := _heroes().get_node_or_null(^"ParthenonMouth")
	assert_not_null(mouth, "the Doric lintel over the arena's mouth")
	if mouth != null:
		assert_eq((_models(mouth).get("gr_cornice_doric_4m", []) as Array).size(), 3, "12 m of Doric entablature")


func test_the_library_bookcases_run_from_pilaster_to_pilaster() -> void:
	var root := _heroes().get_node(^"LibraryBookcases")
	var models := _models(root)
	var cases := 0
	var pilasters := 0
	var runs: Array = []
	for tier in 2:
		var upper := tier == 1
		for clear: Array in [Enlightenment.UP_CLEAR_WEST if upper else Enlightenment.LOW_CLEAR_WEST, Enlightenment.UP_CLEAR_EAST if upper else Enlightenment.LOW_CLEAR_EAST]:
			for span in Enlightenment.shelf_spans(clear):
				runs.append([span, upper])
		runs.append([Floor1ArtEnlightenment.SHORT_RUN, upper])
		runs.append([Floor1ArtEnlightenment.SHORT_RUN, upper])
	for run: Array in runs:
		var span: Vector2 = run[0]
		var bays := Enlightenment.bays(span.x, span.y)
		cases += (bays["cases"] as Array).size()
		pilasters += (bays["pilasters"] as Array).size()
		var ends: Array = bays["pilasters"]
		assert_almost_eq(float(ends[0]), span.x + Enlightenment.PILASTER * 0.5, 0.001, "a run starts with a pilaster")
		assert_almost_eq(float(ends[-1]), span.y - Enlightenment.PILASTER * 0.5, 0.001, "and ends with one")
		for entry: Array in bays["cases"]:
			var stretch := float(entry[2]) / float(entry[1])
			assert_true(absf(stretch - 1.0) < 0.15, "a case of %s stretched %.2f" % [span, stretch])
	var placed := 0
	for id: String in models:
		if id.begins_with("lib_bookcase_") and not id.contains("pilaster"):
			placed += (models[id] as Array).size()
	assert_eq(placed, cases, "every bay has its case")
	var placed_pilasters := (models.get("lib_bookcase_pilaster_low", []) as Array).size() + (models.get("lib_bookcase_pilaster_up", []) as Array).size()
	assert_eq(placed_pilasters, pilasters, "and its pilasters")
	assert_gt(placed, 100, "two tiers of bookcases round the library")
	# every case's back on its wall (the greybox shelves stand there)
	for id: String in models:
		if not id.begins_with("lib_bookcase_"):
			continue
		for node: Node3D in models[id]:
			var p := node.global_position
			var on_wall := absf(p.x - 31.0) < 0.01 or absf(p.x - 45.0) < 0.01 or absf(p.z + 36.0) < 0.01 or absf(p.z - 34.0) < 0.01
			assert_true(on_wall, "%s at %s stands on a wall" % [id, p])
	# the gallery's sconces hang on the upper pilasters, a metre out
	var upper_west: Array = []
	var upper_east: Array = []
	for span in Enlightenment.shelf_spans(Enlightenment.UP_CLEAR_WEST):
		upper_west.append_array(Enlightenment.bays(span.x, span.y)["pilasters"])
	for span in Enlightenment.shelf_spans(Enlightenment.UP_CLEAR_EAST):
		upper_east.append_array(Enlightenment.bays(span.x, span.y)["pilasters"])
	var sconces := 0
	for light in level.layout.lights:
		if light.room != &"enlightenment_library_gallery" or light.fixture != &"sconce":
			continue
		sconces += 1
		var pilaster_z: Array = upper_west if light.position.x < 38.0 else upper_east
		assert_true(pilaster_z.any(func(z: float) -> bool: return absf(z - light.position.z) < 0.001), "the sconce at %s hangs on a pilaster" % light.position)
		assert_almost_eq(absf(light.position.x - (31.0 if light.position.x < 38.0 else 45.0)), Enlightenment.SCONCE_OUT, 0.001)
	assert_eq(sconces, 8)


func test_the_rifle_rack_stands_behind_the_rifle() -> void:
	var racks: Array = _models(level).get("lib_rifle_rack", [])
	assert_eq(racks.size(), 1, "one gun cupboard")
	var rifle: Transform3D = level.layout.markers[&"weapon_rifle_hunt"]
	assert_almost_eq(rifle.origin.y, 0.9, 0.001, "the rifle lies on its table")
	if racks.is_empty():
		return
	var rack: Node3D = racks[0]
	var flat := Vector2(rack.global_position.x - rifle.origin.x, rack.global_position.z - rifle.origin.z)
	assert_lt(flat.length(), 1.3, "the cupboard right behind the rifle")
	var box := _bounds(rack)
	assert_almost_eq(box.end.x, 65.0, 0.02, "its back on the cabinet's east wall")
	assert_true(box.position.x > rifle.origin.x, "behind the table, not over the rifle")


func test_the_orrery_floor_stays_clear() -> void:
	var orrery := Enlightenment.ORRERY
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var view := node as MeshInstance3D
		if not view.is_visible_in_tree() or view.mesh == null:
			continue
		var box := view.global_transform * view.get_aabb()
		if box.position.y > 6.0 or box.end.y < 0.05 or box.position.y < -1.0:
			continue
		var nearest := Vector2(clampf(orrery.x, box.position.x, box.end.x), clampf(orrery.z, box.position.z, box.end.z))
		if nearest.distance_to(Vector2(orrery.x, orrery.z)) < 5.6 and box.end.y > 0.05:
			if level.layout.room_at(Vector3(nearest.x, 1.0, nearest.y)) == &"enlightenment_planetarium":
				fail("%s comes into the orrery's ring" % view.get_path())


func test_the_wings_light_recipes() -> void:
	var rooms := Floor1LightRecipe.ROOMS
	var egypt_least := INF
	for key: StringName in rooms:
		if String(key).begins_with("egypt_") and key != &"egypt_service_stairs" and key != &"egypt_service_corridor":
			egypt_least = minf(egypt_least, float(rooms[key]["fog"]))
	for key in [&"greece_parthenon", &"greece_nereid", &"greece_bassae", &"greece_vases", &"greece_metopes"]:
		assert_lt(float(rooms[key]["fog"]), egypt_least, "%s's air is clearer than Egypt's" % key)
		assert_true(float(rooms[key]["lamp_fog"]) <= 0.06, "%s's lamps hardly haze" % key)
	assert_gt(float(rooms[&"enlightenment_library"]["lamp_fog"]), 0.2, "the library's lamps glow in the book dust")
	var pages := 0
	var dust := 0
	var skies := 0
	for node in level.lights.get_children():
		var room: StringName = node.get_meta(&"room", &"")
		if node is GPUParticles3D and room == &"enlightenment_library":
			if node.get_meta(&"pages", false):
				pages += 1
				assert_true(node.is_in_group(GraphicsQuality.PARTICLES), "the pages follow the presets")
			else:
				dust += 1
		if node is SpotLight3D and node.is_in_group(LightSpec.MOON) and node.get_meta(&"recipe_extra", false) and String(room).begins_with("greece_"):
			skies += 1
			assert_false((node as Light3D).shadow_enabled, "the sky casts no shadow")
	assert_eq(pages, 2, "loose pages drift through the library")
	assert_gt(dust, 1, "and its book dust")
	var wells := 0
	for room in level.layout.rooms:
		if room.zone == Greece.ZONE:
			wells += room.skylights.size()
	assert_eq(skies, wells, "a soft sky down every Greek light well")
	# a blackout: the green lamps and the wall lamps go dark, the sky stays
	NightModifiers.apply(level, &"blackout", RunState)
	for node in get_tree().get_nodes_in_group(StringName("%s_fixtures" % LightSpec.MAIN)):
		if level.is_ancestor_of(node) and String(node.get_meta(&"kit_room", &"")).begins_with("enlightenment_") and node.has_meta(&"light"):
			assert_false(LevelKit.is_lit(node), "%s goes dark" % node.get_meta(&"kit_room"))
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MOON):
			assert_true((node as Light3D).visible, "the moon has no fuse")


func test_the_library_gallery_sounds_like_oak() -> void:
	var slabs := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit") == &"balcony" and node.get_meta(&"kit_room") == &"enlightenment_library_gallery":
			slabs += 1
			assert_eq(Surface.of(node, (node as Node3D).global_position), Surface.WOOD)
	assert_eq(slabs, 4, "the gallery's four slabs")


func test_clocks_tick_and_the_culling_stops_them() -> void:
	var spinners: Array[DecorSpinner] = []
	for node in get_tree().get_nodes_in_group(Floor1Art.DECOR_GROUP):
		if level.is_ancestor_of(node) and node.get_meta(&"kit_room", &"") == &"enlightenment_clocks":
			spinners.append(node as DecorSpinner)
	assert_gt(spinners.size(), 4, "the clocks' and the automata's motion")
	var pendulum: Node3D = null
	for spinner in spinners:
		if not spinner.swings.is_empty():
			pendulum = spinner.swings[0][0]
	assert_not_null(pendulum, "a pendulum swings")
	if pendulum == null:
		return
	var rest := pendulum.basis
	await physics_frames(20)
	assert_false(pendulum.basis.is_equal_approx(rest), "and moves")
	level.culler.set_room(&"enlightenment_clocks", false)
	for spinner in spinners:
		assert_eq(spinner.process_mode, Node.PROCESS_MODE_DISABLED, "far away the clockwork stops")


func test_sloanes_study_hides_behind_a_bookcase() -> void:
	var door: Door = level.doors.get(&"enlightenment_gallery_study")
	assert_not_null(door)
	if door == null:
		return
	var ids := _models(door)
	assert_false(ids.has("grate_frame_6m"), "no steel surround")
	assert_false(ids.has("grate_leaf_3m"), "no bars")
	assert_eq((ids.get("lib_bookcase_up_1m", []) as Array).size(), 2, "two leaves of book spines")


## World bounds of [param node]'s visible meshes.
func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if not view.visible:
			continue
		var box := view.global_transform * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
