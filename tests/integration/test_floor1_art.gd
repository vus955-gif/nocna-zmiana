extends TestCase
## Floor I dressed (stage P2: the hub and Egypt; plan docs/superpowers/plans/
## 2026-10-03-p2-oprawa-hol-egipt.md): every dressed room has a style of its
## own, the dressed zones wear the kit (the rest stays greybox), every model
## the floor places is registered, the collisions are the greybox's, and the
## hero pieces are all there. Built without navigation (looks only).

## Kit ids that may keep the greybox look in the dressed zones: the
## invisible stair ramps' railings are collision only anyway.
const GREYBOX_ALLOWED: Array[StringName] = []

var level: MuseumFloorLevel


func before_each() -> void:
	level = _floor(true)


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


func _floor(art: bool) -> MuseumFloorLevel:
	MuseumFloorLevel.dress_default = art
	var floor_level := MuseumFloorLevel.new()
	floor_level.bake_navigation = false
	add_child(floor_level)
	var started := Time.get_ticks_msec()
	floor_level.build()
	var meshes := floor_level.find_children("*", "MeshInstance3D", true, false).size()
	print("  floor I build (%s): %d ms, %d mesh instances" % ["art" if art else "greybox", Time.get_ticks_msec() - started, meshes])
	return floor_level


func _dressed(room: StringName) -> bool:
	var spec := level.layout.room(room)
	return spec != null and MuseumFloorLevel.ART_ZONES.has(spec.zone)


func test_every_dressed_room_has_a_style_of_its_own() -> void:
	var count := 0
	for room in level.layout.rooms:
		if not MuseumFloorLevel.ART_ZONES.has(room.zone):
			continue
		count += 1
		assert_true(ArtKit.has_style(room.id), "%s has its own style (not the fallback)" % room.id)
	assert_gt(count, 25, "the hub and Egypt have their rooms")


func test_the_dressed_zones_wear_the_kit_and_the_rest_stays_greybox() -> void:
	var greybox := {}
	var elsewhere := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node) or not node.get_meta(&"kit_greybox", false):
			continue
		var room: StringName = node.get_meta(&"kit_room", &"")
		if _dressed(room):
			greybox["%s@%s" % [node.get_meta(&"kit"), room]] = true
		else:
			elsewhere += 1
	for key: String in greybox:
		var kit := StringName(key.get_slice("@", 0))
		assert_true(GREYBOX_ALLOWED.has(kit), "%s still wears the greybox" % key)
	var all_dressed := Floor1Plan.ZONES.all(func(zone: StringName) -> bool: return MuseumFloorLevel.ART_ZONES.has(zone))
	if all_dressed:
		assert_eq(elsewhere, 0, "every zone is dressed: nothing of the floor stays greybox")
	else:
		assert_gt(elsewhere, 100, "the zones not dressed yet stay greybox")
	assert_not_null(level.structure.get_node_or_null(^"Dressing/Floor1Heroes"), "the hero pieces are there")


func test_every_model_placed_is_registered_and_on_disk() -> void:
	for id in Floor1Art.MODELS:
		var known := ArtLibrary.KIT.has(StringName(id)) or ArtLibrary.REGISTRY.has(StringName(id))
		assert_true(known, "%s is registered in ArtLibrary" % id)
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its model file" % id)
	var used := {}
	for node in level.find_children("*", "Node3D", true, false):
		var path := String(node.scene_file_path)
		if path.begins_with("res://assets/models/"):
			used[path.get_file().trim_suffix(".glb")] = true
	assert_gt(used.size(), 60, "the floor uses the kits")
	for id: String in used:
		assert_true(ArtLibrary.has_model(StringName(id)), "%s placed by the art has its model file" % id)
	for id in Floor1Art.MODELS:
		if id in ["egypt_seal_door_l", "egypt_seal_door_r"]:
			continue   # the Khorsabad Gate's leaves: SealGate places them in the game
		assert_true(used.has(id), "%s is placed somewhere" % id)


func test_collisions_are_the_greyboxes() -> void:
	# (but the pieces whose collision is drawn from their look: QA Q7,
	# Floor1Art.FIT_COLLISION / HERO_FIT - each of those listed there)
	var fitted := {}
	for node in level.find_children("*", "StaticBody3D", true, false):
		if node.get_meta(&"kit_fitted", false):
			var spec := PieceSpec.new()
			spec.kit = node.get_meta(&"kit", &"")
			spec.room = node.get_meta(&"kit_room", &"")
			assert_true(Floor1Art.fits_collision(spec) or Floor1Art.HERO_FIT.has("%s@%s" % [spec.kit, spec.room]), "%s in %s fitted only when listed" % [spec.kit, spec.room])
			fitted[(node as Node3D).global_position.snapped(Vector3.ONE * 0.001)] = String(spec.kit)
	assert_gt(fitted.size(), 40, "the fitted pieces")
	var dressed := _shapes(level, fitted)
	level.free()
	level = _floor(false)
	var plain := _shapes(level, fitted)
	assert_eq(dressed.size(), plain.size(), "as many colliders")
	var differ := 0
	for i in mini(dressed.size(), plain.size()):
		if dressed[i] != plain[i]:
			differ += 1
			if differ < 5:
				fail("collider %s != %s" % [dressed[i], plain[i]])
	assert_eq(differ, 0)


func _shapes(root: Node, fitted: Dictionary = {}) -> Array:
	var out: Array = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var owner_body := shape.get_parent() as Node3D
		if owner_body != null and fitted.get(owner_body.global_position.snapped(Vector3.ONE * 0.001), "") == String(owner_body.get_meta(&"kit", &"")):
			continue
		var at := shape.global_position.snapped(Vector3.ONE * 0.001)
		var extent := shape.shape.get_debug_mesh().get_aabb().size.snapped(Vector3.ONE * 0.001)
		out.append("%s %s %s" % [shape.get_parent().get_meta(&"kit", shape.get_parent().name), at, extent])
	out.sort()
	return out


func test_the_hero_pieces_are_all_there() -> void:
	var counts := {}
	var heroes := level.structure.get_node(^"Dressing/Floor1Heroes")
	var placed := heroes.find_children("*", "Node3D", true, false)
	# (the drum's bookcases and the card catalogue's arcs are the looks of
	# their shelf and catalogue pieces: their collision is drawn from them)
	for node in level.find_children("*", "StaticBody3D", true, false):
		if node.get_meta(&"kit_room", &"") == &"court_reading" and node.get_meta(&"kit", &"") in [&"shelf", &"catalogue"]:
			placed.append_array(node.find_children("*", "Node3D", true, false))
	for node in placed:
		var path := String(node.scene_file_path)
		if path.begins_with("res://assets/models/"):
			var id := path.get_file().trim_suffix(".glb")
			counts[id] = int(counts.get(id, 0)) + 1
	assert_eq(counts.get("court_roof_q", 0), 4, "four quarters of the glass roof")
	assert_eq(int(counts.get("rr_drum_wall", 0)) + int(counts.get("rr_drum_door", 0)), 16, "the drum's 16 segments")
	assert_eq(counts.get("rr_drum_door", 0), 4, "a portal every four segments")
	assert_eq(counts.get("rr_dome_sector", 0), 16, "the dome's 16 sectors")
	assert_eq(int(counts.get("rr_bookcase", 0)) + int(counts.get("rr_bookcase_door", 0)), 16, "bookcases all round")
	assert_eq(counts.get("rr_oculus", 0), 1, "the oculus")
	assert_eq(counts.get("astrolabe", 0), 1, "the astrolabe")
	assert_eq(counts.get("rr_catalogue_arc", 0), 4, "the card catalogue's ring")
	assert_eq(counts.get("court_balcony_seg", 0), 7, "the balcony round the north of the drum")
	assert_eq(counts.get("entrance_mosaic", 0), 1, "the mosaic in the entrance hall")
	var gallery := level.layout.room(&"egypt_gallery")
	var arena := level.layout.room(&"egypt_colossus")
	assert_eq(counts.get("egypt_clerestory_3m", 0), gallery.skylights.size() + 12 + Floor1Art.CLERESTORY_Z.size(),
		"a lattice in every light well, the arena's grid, the clerestories")
	assert_gt(arena.skylights.size(), 0, "the arena keeps its roof well")
	assert_eq(counts.get("egypt_beam_4m", 0), Egypt.BEAMS_Z.size() * 4, "painted beams across the nave")
	assert_eq(counts.get("egypt_portal_great", 0), 1, "the Khorsabad pylon (the sealed gate's portal)")


const Egypt := preload("res://src/level/floor1/zones/egypt.gd")


func test_the_court_sees_the_sky_through_its_glass() -> void:
	await physics_frames(2)
	var court := level.layout.room(&"court")
	assert_eq(court.skylights.size(), 8, "an L of glass in every quarter")
	# the roof's sky: its ceilings have no look and no shadow
	var sky := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"sky", false):
			sky += 1
			var meshes := (node as Node).find_children("*", "MeshInstance3D", true, false)
			assert_eq(meshes.size(), 0, "the sky over the roof draws nothing")
	assert_gt(sky, 0, "the roof's ceilings are the sky")
	# under each glass field the moon has a clear way down: no box between
	# the roof and the floor
	var space := level.get_world_3d().direct_space_state
	for well in court.skylights:
		var middle := well.get_center()
		var query := PhysicsRayQueryParameters3D.create(Vector3(middle.x, 29.5, middle.y), Vector3(middle.x, 22.2, middle.y), Layers.WORLD)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			assert_eq((hit["collider"] as Node).get_meta(&"kit", &""), &"roof_glass", "only the roof's glass over %s" % well)
