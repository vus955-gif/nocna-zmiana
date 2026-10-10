extends TestCase
## Floor I's basement dressed (stage P3; plan docs/superpowers/plans/2026-10-03-
## p3-oprawa-podziemia.md): every room of the service level has a style of
## its own and wears the kit (no piece keeps the greybox look), the models the
## basement places are registered and on disk, the boiler hall's props are
## there (boilers with fire doors that stay lit in a blackout, flues, pipes in
## the wings' colours, the gantry's open stairs), the haze, the shadow budget,
## the steam and the room-graph culling work. Built without navigation.

const ZONE := &"basement"

var level: MuseumFloorLevel


func before_each() -> void:
	MuseumFloorLevel.dress_default = true
	level = MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()


func after_each() -> void:
	MuseumFloorLevel.dress_default = false


func _rooms() -> Array[RoomSpec]:
	var out: Array[RoomSpec] = []
	for room in level.layout.rooms:
		if room.zone == ZONE:
			out.append(room)
	return out


func _pieces(kit: StringName) -> Array[Node]:
	var out: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if level.is_ancestor_of(node) and node.get_meta(&"kit", &"") == kit and ZONE == _zone_of(node.get_meta(&"kit_room", &"")):
			out.append(node)
	return out


func _zone_of(room: StringName) -> StringName:
	var spec := level.layout.room(room)
	return spec.zone if spec != null else &""


func test_the_basement_is_a_dressed_zone_with_a_style_for_every_room() -> void:
	assert_true(MuseumFloorLevel.ART_ZONES.has(ZONE), "the basement is among the dressed zones")
	var rooms := _rooms()
	assert_eq(rooms.size(), 21, "the service level's rooms")
	for room in rooms:
		assert_true(Floor1Art.ROOM_STYLES.has(room.id), "%s has a Floor I style" % room.id)
		assert_true(ArtKit.has_style(room.id), "%s has its own style (not the fallback)" % room.id)


func test_no_basement_piece_keeps_the_greybox_look() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not level.is_ancestor_of(node):
			continue
		var room: StringName = node.get_meta(&"kit_room", &"")
		if _zone_of(room) != ZONE:
			continue
		count += 1
		assert_false(node.get_meta(&"kit_greybox", false), "%s in %s is dressed" % [node.get_meta(&"kit"), room])
	assert_gt(count, 150, "the basement's pieces, shell and fittings")


func test_the_models_the_basement_places_are_registered_and_on_disk() -> void:
	var used := {}
	for node in level.find_children("*", "Node3D", true, false):
		var path := String(node.scene_file_path)
		if path.begins_with("res://assets/models/"):
			used[path.get_file().trim_suffix(".glb")] = true
		elif node is MultiMeshInstance3D and node.has_meta(&"model"):
			used[node.get_meta(&"model")] = true   # racks and cabinets are drawn in batches
	for id in BasementArt.MODELS:
		assert_true(ArtLibrary.has_model(StringName(id)), "%s has its model file" % id)
	for id in ["cast_shelf", "asy_tablet_shelf", "shelf_unit", "lib_filing_cabinet", "gr_plinth_block", "bust",
			"vase_amphora_bf", "cast_torso", "sign_room", "corridor_pipes_4m", "skirting_4m", "tube_lamp", "emergency_lamp"]:
		assert_true(used.has(id), "%s is placed in the basement or beside it" % id)


func test_the_boiler_hall_props() -> void:
	var boilers := _pieces(&"boiler")
	assert_eq(boilers.size(), 2, "two Cornish boilers")
	var doors := _pieces(&"furnace_door")
	assert_eq(doors.size(), 2, "a fire door on each")
	for door in doors:
		var near := false
		for boiler in boilers:
			var front := (boiler as Node3D).global_position + Vector3(0.0, 0.0, 2.0)
			near = near or Vector2((door as Node3D).global_position.x - front.x, (door as Node3D).global_position.z - front.z).length() < 0.15
		assert_true(near, "the fire door stands on a boiler's iron front")
		# fire has no fuse: the embers do not go out with the main lamps
		var look := door.get_node_or_null(^"Visual")
		assert_not_null(look)
		assert_true(LevelKit.is_lit(look), "the slit glows")
	var circuit := level.lights.get_node_or_null(^"Glow_basement_boiler")
	if circuit != null:
		for target: Node in circuit.get_meta(&"lit_targets", []):
			assert_ne(target.get_parent().get_meta(&"kit", &""), &"furnace_door", "the fire doors are not on the mains' circuit")
	assert_eq(_pieces(&"flue").size(), 2, "a flue on each boiler")
	assert_gt(_pieces(&"pipe").size(), 14, "the wings' pipes, the steam main, the switchboard's conduits")
	# the gantry: a deck, posts, rails and open stairs (a drawn flight, not the marble kit)
	assert_gt(_pieces(&"balcony").size(), 1, "the gantry's deck")
	assert_gt(_pieces(&"balcony_post").size(), 4, "its posts")
	var stairs := level.structure.find_children("Stairs", "Node3D", true, false)
	var drawn := 0
	for node in stairs:
		if _zone_of(node.get_parent().get_parent().get_meta(&"kit_room", &"")) == ZONE:
			drawn += 1
			assert_eq(node.get_child_count() > 4, true, "treads, stringers, rails")
	assert_gt(drawn, 0, "the gantry's stairs are drawn")


func test_each_wings_pipe_is_painted_in_its_colour() -> void:
	var seen := {}
	for node in _pieces(&"pipe"):
		var tint: Color = node.get_meta(&"kit_tint", Color.BLACK)
		var zone := Floor1Art.zone_of_tint(tint)
		if zone != &"":
			seen[zone] = true
		var look := node.get_node(^"Visual")
		assert_eq(look.find_children("*", "MeshInstance3D", true, false).size(), 1, "the pipe")
		assert_eq(look.find_children("*", "MultiMeshInstance3D", true, false).size(), 2, "its collars and brackets, in batches")
	for wing in [&"egypt", &"assyria", &"americas", &"asia", &"greece", &"enlightenment", &"booth"]:
		assert_true(seen.has(wing), "a %s pipe runs from its door" % wing)


func test_the_wing_door_plates_name_their_wings_and_the_booth_way() -> void:
	var markers := level.layout.markers
	for wing in [&"egypt", &"assyria", &"greece", &"enlightenment", &"americas", &"asia", &"booth"]:
		assert_true(markers.has(StringName("sign_basement_%s_1" % wing)), "a plate over the %s door" % wing)
	var plates := 0
	for node in _pieces(&"sign_wing_portal"):
		var look := node.get_node(^"Visual")
		if look.find_children("*", "MeshInstance3D", true, false).size() > 0:
			plates += 1
	assert_eq(plates, 14, "every plate has its sign (the wings' and the booth's)")


func test_shadows_and_haze_in_the_service_rooms() -> void:
	var recipe := Floor1LightRecipe.create()
	var used := {}
	var fog := {}
	var probes := {}
	for node in level.lights.get_children():
		var room: StringName = node.get_meta(&"room", &"")
		if _zone_of(room) != ZONE:
			continue
		if node is Light3D and not node is DirectionalLight3D and (node as Light3D).shadow_enabled:
			var key := recipe.key(room)
			used[key] = int(used.get(key, 0)) + 1
		elif node is FogVolume:
			fog[room] = true
		elif node is ReflectionProbe:
			probes[room] = true
	for room in _rooms():
		if not room.carved:
			continue
		assert_true(Floor1LightRecipe.ROOMS.has(recipe.key(room.id)), "%s has a recipe entry" % room.id)
		assert_true(fog.has(room.id), "%s has its haze" % room.id)
	for key: StringName in used:
		assert_true(int(used[key]) <= 2, "%s casts %d shadows (at most 2)" % [key, used[key]])
	for room in [&"basement_boiler", &"basement_crossing", &"basement_switchboard", &"basement_corridor_north"]:
		assert_true(probes.has(room), "%s keeps the night sky out of its steel with a probe" % room)
	assert_false(probes.has(&"basement_reserve"), "the stores' paint needs no probe")
	assert_gt(int(used.get(&"basement_boiler", 0)), 0, "the gantry's bulbs cast the rails' shadows")
	assert_gt(int(used.get(&"basement_workshop", 0)), 0, "the restorer's desk lamps")
	# thin and cold: never a milky haze under the tubes
	for room: StringName in Floor1LightRecipe.ROOMS:
		if String(room).begins_with("basement_"):
			assert_true(float((Floor1LightRecipe.ROOMS[room] as Dictionary)["fog"]) <= 0.025, "%s keeps the haze thin" % room)


func test_the_tubes_flicker_and_the_emergency_lamps_stay_red() -> void:
	var flicker := 0
	var red := 0
	for node in level.lights.get_children():
		if not node is Light3D or node is DirectionalLight3D or _zone_of(node.get_meta(&"room", &"")) != ZONE:
			continue
		if node.is_in_group(LightSpec.FLICKER):
			flicker += 1
		elif node.is_in_group(LightSpec.EMERGENCY) and (node as Light3D).light_color.r > 0.9 and (node as Light3D).light_color.g < 0.2:
			red += 1
	assert_gt(flicker, 6, "a few tubes on a bad circuit")
	assert_gt(red, 6, "red lamps at the wings' doors")
	NightModifiers.apply(level, &"blackout", RunState)
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.FLICKER):
			assert_false((node as Light3D).visible, "the blackout puts out %s" % node.name)
			break


func test_steam_rises_in_the_boiler_hall_and_is_culled_far_away() -> void:
	var plumes: Array[GPUParticles3D] = []
	for node in level.lights.get_children():
		if node is GPUParticles3D and String(node.name).begins_with("Steam_"):
			plumes.append(node)
	assert_eq(plumes.size(), 3, "a plume at each steam marker")
	for plume in plumes:
		assert_eq(plume.get_meta(&"room", &""), &"basement_boiler")
		assert_true(plume.is_in_group(GraphicsQuality.PARTICLES), "the preset scales the steam")
		var marker: Vector3 = level.markers[StringName(String(plume.name).trim_prefix("Steam_"))].origin
		assert_true(plume.position.is_equal_approx(marker), "at its marker")
	var culler := level.culler
	culler.depth = 2
	var keep := culler.update_from(Vector3(-16.0, -4.3, 10.0))   # the reserve
	assert_false(keep.has(&"basement_boiler"), "three passages from the reserve")
	assert_true(culler.is_culled(&"basement_boiler"))
	for plume in plumes:
		assert_false(plume.emitting, "far steam stops")
	culler.update_from(Vector3(0.0, -4.3, -20.0))   # the boiler hall
	assert_false(culler.is_culled(&"basement_boiler"))
	for plume in plumes:
		assert_true(plume.emitting, "and rises again")


func test_the_switchboard_is_dressed() -> void:
	var board := Switchboard.new()
	add_child(board)
	var dressing := board.get_node_or_null(^"Dressing")
	assert_not_null(dressing, "gauges, a switch, breakers and cables")
	if dressing != null:
		assert_gt(dressing.get_child_count(), 15)


func test_the_freight_lifts_call_box_hangs_on_the_wall_by_its_marker() -> void:
	var box := level.structure.get_node_or_null(^"Dressing/Floor1Heroes/FreightCallBox") as Node3D
	assert_not_null(box, "the call box")
	if box == null:
		return
	var marker: Transform3D = level.markers[&"basement_freight_lift"]
	assert_true(box.global_position.is_equal_approx(marker.origin), "at the marker")
	var room := level.layout.room_at(box.global_position)
	assert_eq(room, &"basement_tunnel", "in the tunnel, not in a wall")


func test_the_court_does_not_keep_the_boiler_hall_lit() -> void:
	# a guest room (the court's balcony) is hosted by a room that holds it between its
	# own floor and ceiling: the boiler hall under the same footprint is no host
	var culler := level.culler
	culler.depth = 2
	var keep := culler.update_from(Vector3(0.0, 1.7, 22.0))   # the court, south of the drum
	assert_true(keep.has(&"court_balcony"), "the balcony is the court's")
	assert_false(keep.has(&"basement_boiler"), "the boiler hall is not")
	assert_false(keep.has(&"basement_crossing"), "nor the cross")
