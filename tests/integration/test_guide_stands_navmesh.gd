extends TestCase
## The audio-guide stands of Floor I (AudioguideStand, one by every stop's
## exhibit) are solid - a StaticBody3D the guard walks into - and belong to
## the exhibits' walkable navigation like every other solid thing the night
## puts down (the Lamassu's plinth, the mummies' coffins, the Centaur's
## metope): the navmesh goes round them. Found by the playthrough bot (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md, P5): the navmesh ran
## through every stand, and the one at the astrolabe stands in the mouth of
## the north gap between the card catalogue's arcs - ways planned there
## walked into it. They stay what the voice plays through (E on a stand
## plays its stop), each where its marker puts it, and the guard still gets
## onto the astrolabe's dais.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _museum() -> void:
	GameState.new_game()
	GameState.seed_base = 1
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(3)
	var waited := 0
	while museum.floor_level.navigation.is_baking() and waited < 600:
		await physics_frames(1)
		waited += 1
	await physics_frames(3)


func _stands() -> Array[AudioguideStand]:
	var found: Array[AudioguideStand] = []
	for node in get_tree().get_nodes_in_group(AudioguideStand.GROUP):
		if museum.is_ancestor_of(node):
			found.append(node as AudioguideStand)
	return found


func _stand(station: StringName) -> AudioguideStand:
	for stand in _stands():
		if stand.station == station:
			return stand
	return null


func _walk_closest(point: Vector3) -> Vector3:
	var best := Vector3.INF
	for region in museum.floor_level.navigation.regions:
		var found := NavigationServer3D.region_get_closest_point(region.get_rid(), point)
		if best == Vector3.INF or found.distance_to(point) < best.distance_to(point):
			best = found
	return best


static func _flat_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var s := Vector2(a.x, a.z)
	var e := Vector2(b.x, b.z)
	var along := e - s
	var t := 0.0 if along.length_squared() < 0.000001 else clampf((p - s).dot(along) / along.length_squared(), 0.0, 1.0)
	return p.distance_to(s + along * t)


func test_every_stand_is_built_where_its_marker_is_and_cut_out_of_the_navmesh() -> void:
	await _museum()
	var stands := _stands()
	var markers: Array = museum.floor_level.markers.keys().filter(func(id: StringName) -> bool: return String(id).begins_with("audioguide_"))
	assert_gt(markers.size(), 10, "a stand for every stop")
	assert_eq(stands.size(), markers.size(), "every stand is built and found")
	for stand in stands:
		var marker: Transform3D = museum.floor_level.markers[StringName("audioguide_" + String(stand.station))]
		assert_lt(stand.global_position.distance_to(marker.origin), 0.01, "the %s stand where its marker is" % stand.station)
		assert_lt(stand.global_basis.z.distance_to(marker.basis.z.normalized()), 0.01, "the %s stand faces as its marker" % stand.station)
		var middle := stand.global_position + Vector3.UP * 0.1
		var closest := _walk_closest(middle)
		var off := Vector2(closest.x - middle.x, closest.z - middle.z).length()
		assert_gt(off, 0.45, "the navmesh keeps off the %s stand at %s (nearest %.2f m)" % [stand.station, stand.global_position, off])


func test_a_way_past_a_stand_goes_round_it() -> void:
	await _museum()
	var stand := _stand(&"rosetta")
	assert_not_null(stand)
	if stand == null:
		return
	var map := museum.get_world_3d().navigation_map
	var side := stand.global_basis.x.normalized()
	var from := NavigationServer3D.map_get_closest_point(map, stand.global_position + side * 2.2)
	var to := NavigationServer3D.map_get_closest_point(map, stand.global_position - side * 2.2)
	assert_gt(Vector2(from.x - to.x, from.z - to.z).length(), 3.0, "the two ends on either side of it")
	var way := NavigationServer3D.map_get_path(map, from, to, true, LevelNavigation.WALK_LAYER)
	assert_gt(way.size(), 1, "a way past it")
	for i in range(1, way.size()):
		var clear := _flat_to_segment(stand.global_position, way[i - 1], way[i])
		assert_gt(clear, 0.4, "the way past the stand keeps off it (%.2f m)" % clear)


func test_e_on_a_stand_still_plays_its_stop() -> void:
	await _museum()
	var stands := _stands()
	for stand in stands:
		assert_true(stand.is_inside_tree(), "%s in the scene" % stand.station)
		assert_true(AudioguideStand.STOPS.has(stand.station), "%s has its stop" % stand.station)
		assert_eq(stand.collision_layer, Layers.INTERACT, "%s answers the guard's E" % stand.station)
	var stand := _stand(&"rosetta")
	assert_not_null(stand)
	if stand == null:
		return
	stand.interact(museum.player)
	await physics_frames(2)
	assert_true(stand.is_speaking(), "E on the stand plays its stop")
	stand.interact(museum.player)
	await physics_frames(2)
	assert_false(stand.is_speaking(), "E again stops it")


func test_the_guard_still_gets_onto_the_astrolabes_dais() -> void:
	await _museum()
	var space := museum.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var cast := PhysicsShapeQueryParameters3D.new()
	cast.shape = capsule
	cast.collision_mask = Layers.WORLD
	var free_ways := 0
	for bearing: float in [0.0, 90.0, 180.0, 270.0]:
		for slant: float in [-6.0, 0.0, 6.0]:
			var a := deg_to_rad(bearing + slant)
			var outside := Vector3(sin(a) * 4.8, 0.05, -cos(a) * 4.8)
			var onto := Vector3(sin(a) * 1.5, 0.55, -cos(a) * 1.5)
			cast.transform = Transform3D(Basis.IDENTITY, outside + Vector3.UP * 1.3)
			cast.motion = onto - outside
			if space.cast_motion(cast)[0] >= 0.999:
				free_ways += 1
				break
	assert_gt(free_ways, 1, "the guard walks onto the dais through %d of the catalogue's four gaps" % free_ways)
