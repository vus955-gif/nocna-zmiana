extends TestCase
## The coffins the ambush mummies of Floor I stand up at their posts every
## night (Mummy._settle_in_tomb: solid level geometry) belong to the
## exhibits' walkable navigation like every other solid thing the night
## puts down (a display's plinth, the Lamassu's plinth): the navmesh goes
## round them. Found by the playthrough bot (plan
## docs/superpowers/plans/2026-10-21-przejscie-bota.md, P2): the navmesh ran
## straight through a coffin standing in the Egyptian gallery between a
## plinth and a desk, so a way planned there (the bot's, an exhibit's)
## walked into a gap narrower than the guard.

var museum: Museum


func before_each() -> void:
	Museum.level_id = &"floor1"


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()


func _walk_closest(point: Vector3) -> Vector3:
	var best := Vector3.INF
	for region in museum.floor_level.navigation.regions:
		var found := NavigationServer3D.region_get_closest_point(region.get_rid(), point)
		if best == Vector3.INF or found.distance_to(point) < best.distance_to(point):
			best = found
	return best


func test_a_coffin_stood_up_for_the_night_is_cut_out_of_the_navmesh() -> void:
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
	var tombs: Array[MummyTomb] = []
	for node in get_tree().get_nodes_in_group(MummyTomb.GROUP):
		if museum.is_ancestor_of(node):
			tombs.append(node as MummyTomb)
	assert_gt(tombs.size(), 0, "the ambush mummies sleep in coffins tonight")
	for tomb in tombs:
		var middle := tomb.global_position + Vector3.UP * 0.1
		var closest := _walk_closest(middle)
		var off := Vector2(closest.x - middle.x, closest.z - middle.z).length()
		assert_gt(off, 0.6, "the navmesh keeps off the coffin at %s (nearest %.2f m)" % [tomb.global_position, off])
