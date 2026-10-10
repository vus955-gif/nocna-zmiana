extends TestCase

var level: LobbyLevel


func before_each() -> void:
	level = LobbyLevel.new()
	add_child(level)
	var started := Time.get_ticks_msec()
	level.build()
	print("  lobby build: %d ms, %d kit pieces" % [Time.get_ticks_msec() - started, get_tree().get_nodes_in_group(&"level_kit").size()])
	await physics_frames(2)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return level.get_world_3d().direct_space_state.intersect_ray(query)


func _hit_y(from: Vector3, to: Vector3) -> float:
	var hit := _ray(from, to)
	return (hit["position"] as Vector3).y if not hit.is_empty() else INF


func test_floors_and_ceilings_stand_at_the_designed_heights() -> void:
	assert_almost_eq(_hit_y(Vector3(-12, 10, 0), Vector3(-12, -5, 0)), 0.0, 0.01, "hall floor")
	assert_almost_eq(_hit_y(Vector3(-16, 10, -10), Vector3(-16, -5, -10)), 6.0, 0.01, "west balcony")
	assert_almost_eq(_hit_y(Vector3(0, 10, -20), Vector3(0, -5, -20)), 6.0, 0.01, "north balcony")
	assert_almost_eq(_hit_y(Vector3(-12, 1, 0), Vector3(-12, 30, 0)), 14.0, 0.01, "hall ceiling")
	assert_almost_eq(_hit_y(Vector3(-30, 1, -12), Vector3(-30, 30, -12)), 7.0, 0.01, "gallery ceiling")
	assert_almost_eq(_hit_y(Vector3(30, 1, -12), Vector3(30, 30, -12)), 7.0, 0.01, "armory ceiling")
	assert_almost_eq(_hit_y(Vector3(0, 1, 34), Vector3(0, 30, 34)), 8.0, 0.01, "diorama ceiling")
	assert_almost_eq(_hit_y(Vector3(-3, 1, 56), Vector3(-3, 30, 56)), 3.0, 0.01, "security ceiling")
	assert_almost_eq(_hit_y(Vector3(0, 8.5, -24.5), Vector3(0, -5, -24.5)), 6.0, 0.01, "closet floor")
	assert_almost_eq(_hit_y(Vector3(-11, 1.2, -11), Vector3(-11, -5, -11)), 0.0, 0.01, "beside the pedestal")
	assert_almost_eq(_hit_y(Vector3(0, 3, -12.5), Vector3(0, -5, -12.5)), 1.2, 0.05, "pedestal top under the skeleton")
	assert_eq(_hit_y(Vector3(0, 10, 0), Vector3(0, 40, 0)), INF, "moonlight through the middle skylight")


func test_wing_doors_open_onto_the_hall() -> void:
	assert_true(_ray(Vector3(-12, 1.5, 0), Vector3(-27, 1.5, 0)).is_empty(), "hall -> gallery")
	assert_true(_ray(Vector3(12, 1.5, 0), Vector3(26, 1.5, 0)).is_empty(), "hall -> armory")
	assert_true(_ray(Vector3(0, 1.5, 18), Vector3(0, 1.5, 30)).is_empty(), "hall -> diorama")
	assert_true(_ray(Vector3(0, 1.5, 40), Vector3(0, 1.5, 58)).is_empty(), "diorama -> security")


func test_doors_are_built_for_every_door_style() -> void:
	for passage in level.layout.openings:
		if passage.door_style == OpeningSpec.DoorStyle.NONE:
			continue
		assert_true(level.doors.has(passage.id), str(passage.id))
	var lockable := level.doors.values().filter(func(d: Door) -> bool: return d.link == RoomGraph.Kind.LOCKABLE)
	assert_eq(lockable.size(), 6)
	for door: Door in lockable:
		assert_true(door.is_open, "%s starts open" % door.id)
	assert_false((level.doors[&"grate"] as Door).is_open)
	assert_false((level.doors[&"panel_closet"] as Door).is_open)


func test_false_panels_hide_the_secret_rooms() -> void:
	assert_false(_ray(Vector3(-37, 1.2, 6.5), Vector3(-43, 1.2, 6.5)).is_empty(), "painting shut")
	(level.doors[&"panel_painting"] as Door).open(true)
	await physics_frames(2)
	assert_true(_ray(Vector3(-37, 1.2, 6.5), Vector3(-43, 1.2, 6.5)).is_empty(), "painting open")


func test_vent_shaft_climbs_from_the_diorama_to_the_balcony() -> void:
	for panel in [&"panel_vent_in", &"panel_vent_out"]:
		(level.doors[panel] as Door).open(true)
	await physics_frames(2)
	assert_almost_eq(_hit_y(Vector3(-19, 8, 3.75), Vector3(-19, -5, 3.75)), 6.0, 0.02, "landing")
	assert_almost_eq(_hit_y(Vector3(-19, 8, 23), Vector3(-19, -5, 23)), 0.0, 0.3, "foot of the shaft")
	assert_true(_ray(Vector3(-19, 7, 3.75), Vector3(-15, 7, 3.75)).is_empty(), "out onto the balcony")


func test_description_is_the_same_before_and_after_building() -> void:
	var fresh := LobbyLevel.new()
	var before := fresh.describe()
	fresh.free()
	var after := level.describe()
	assert_eq(before.lockable_doors, after.lockable_doors)
	assert_eq(before.objective_rooms, after.objective_rooms)
	assert_eq(before.spawn_slots.size(), after.spawn_slots.size())


func test_roofs_can_be_hidden_for_the_overview() -> void:
	level.set_roof_visible(false)
	var ceilings := level.structure.get_children().filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"ceiling")
	assert_gt(ceilings.size(), 5)
	assert_true(ceilings.all(func(n: Node3D) -> bool: return not n.visible))


func test_haven_zones_cover_the_security_room_and_the_closet() -> void:
	assert_eq(level.haven_zones.get(&"security"), AABB(Vector3(-5, 0, 54), Vector3(10, 3, 8)))
	assert_eq(level.haven_zones.get(&"closet"), AABB(Vector3(-2, 6, -26), Vector3(4, 3, 3)))
	for id: StringName in level.haven_spots:
		assert_true((level.haven_zones[id] as AABB).grow(0.05).has_point((level.haven_spots[id] as Transform3D).origin), "%s terminal inside its zone" % id)


func test_the_hall_wall_under_the_vent_hatch_is_solid() -> void:
	var across := _ray(Vector3(-17, 2, 3.5), Vector3(-20.5, 2, 3.5))
	assert_false(across.is_empty())
	if not across.is_empty():
		assert_almost_eq((across["position"] as Vector3).x, -18.0, 0.01, "the hall's own wall face")
	assert_almost_eq(_hit_y(Vector3(-18.25, 7, 3.5), Vector3(-18.25, -60, 3.5)), 6.0, 0.01, "the hatch sill")
	var point := PhysicsPointQueryParameters3D.new()
	point.collision_mask = Layers.WORLD
	for y in [0.5, 3.0, 5.2]:
		point.position = Vector3(-18.25, y, 3.5)
		assert_false(level.get_world_3d().direct_space_state.intersect_point(point, 1).is_empty(), "solid under the sill at %.1f m, no drop into the void" % y)


func test_the_open_grate_leaves_the_closet_passage_clear() -> void:
	var panel: Door = level.doors[&"panel_closet"]
	var grate: Door = level.doors[&"grate"]
	panel.open(true)
	grate.jam(true)
	grate.open(true)
	await physics_frames(3)
	assert_true(_ray(Vector3(0, 7, -20.5), Vector3(0, 7, -24.9)).is_empty(), "balcony -> closet at head height")
	assert_true(_ray(Vector3(0, 1.5, -20), Vector3(0, 1.5, -25)).is_empty(), "hall -> undercroft through the open grate")
	assert_almost_eq(_hit_y(Vector3(0, 1, -30), Vector3(0, -10, -30)), LobbyLayout.STAIRWELL_FLOOR * 0.45, 0.6, "stairs down beyond the undercroft")


func test_the_game_level_leaves_the_pedestal_empty_for_the_live_boss() -> void:
	var stand_ins := get_tree().get_nodes_in_group(&"level_kit").filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"trex")
	assert_eq(stand_ins.size(), 1, "the dev lobby shows the skeleton")
	level.free()
	level = LobbyLevel.new()
	level.boss_stand_in = false
	add_child(level)
	level.build()
	stand_ins = get_tree().get_nodes_in_group(&"level_kit").filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"trex" and not n.is_queued_for_deletion())
	assert_eq(stand_ins.size(), 0)


func test_every_piece_knows_its_room_and_role() -> void:
	var missing := 0
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		if not node.has_meta(&"kit_role"):
			missing += 1
		elif node.get_meta(&"kit_role") in [&"floor", &"wall", &"ceiling"] and not node.has_meta(&"kit_room"):
			missing += 1
	assert_eq(missing, 0)
	var faces := level.wall_faces()
	assert_gt(faces.size(), 50)
