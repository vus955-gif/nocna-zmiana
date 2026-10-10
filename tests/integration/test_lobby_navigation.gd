extends TestCase
## Exhibits finding their way around the built lobby.

const FAST_FORWARD := 8

var level: LobbyLevel
var target: TargetDummy
var _ticks: int
var _max_steps: int


func before_each() -> void:
	_ticks = Engine.physics_ticks_per_second
	_max_steps = Engine.max_physics_steps_per_frame
	level = LobbyLevel.new()
	add_child(level)
	level.build()
	target = TargetDummy.new()
	add_child(target)
	await physics_frames(6)   # the navigation map syncs a few frames after baking


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks
	Engine.max_physics_steps_per_frame = _max_steps
	Engine.time_scale = 1.0


func _spawn(kind: GDScript, at: Vector3) -> Enemy:
	var enemy: Enemy = kind.new()
	enemy.position = at
	enemy.target = target
	add_child(enemy)
	return enemy


## Runs up to [param seconds] of game time; stops early once every exhibit
## came within [param reach] of the target. Returns each one's closest
## distance. The exhibits are summoned: they always know where the target
## is (this is about finding the way, not about seeing).
func _chase(exhibits: Array[Enemy], seconds: float, reach: float) -> Dictionary:
	var closest := {}
	for exhibit in exhibits:
		exhibit.summoned = true
		exhibit.brain.wake()
		closest[exhibit] = INF
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD
	for frame in int(seconds * _ticks):
		await get_tree().physics_frame
		var waiting := 0
		for exhibit in exhibits:
			closest[exhibit] = minf(closest[exhibit], exhibit.global_position.distance_to(target.global_position))
			if closest[exhibit] > reach:
				waiting += 1
		if waiting == 0:
			break
	return closest


func _path_length(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(level.walk_region.get_navigation_map(), from, to, true, LevelNavigation.WALK_LAYER)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	if path.is_empty() or path[path.size() - 1].distance_to(to) > 1.5:
		return INF
	return length


func test_exhibits_come_out_of_the_wings_through_the_doors() -> void:
	target.position = Vector3(-8, 0, 2)
	var exhibits: Array[Enemy] = [_spawn(WaxFigure, Vector3(-30, 0, -12)), _spawn(Knight, Vector3(30, 0, 11)), _spawn(Wolf, Vector3(-33, 0, 12))]
	await physics_frames(2)
	var closest := await _chase(exhibits, 45.0, 2.6)
	for exhibit in exhibits:
		assert_lt(closest[exhibit], 2.6, "%s from its wing" % exhibit.get_script().get_global_name())


func test_exhibits_climb_the_stairs_to_the_balcony() -> void:
	target.position = Vector3(-16, 6, -12)
	var exhibits: Array[Enemy] = [_spawn(WaxFigure, Vector3(0, 0, 16)), _spawn(Wolf, Vector3(8, 0, 12)), _spawn(Knight, Vector3(-4, 0, 12))]
	await physics_frames(2)
	var closest := await _chase(exhibits, 50.0, 2.6)
	for exhibit in exhibits:
		assert_lt(closest[exhibit], 2.6, "%s up the stairs" % exhibit.get_script().get_global_name())
		assert_gt(exhibit.global_position.y, 5.5, "on the balcony")


## Havens the way the Museum makes them from the level's zones.
func _add_havens() -> void:
	for id: StringName in level.haven_zones:
		add_child(Haven.make(id, level.haven_zones[id]))


## Design 7.2: hunters follow the guard to the haven's door, search there
## for 8 s once he is in, then go home.
func test_exhibits_follow_to_the_haven_door_search_it_and_go_home() -> void:
	_add_havens()
	target.position = Vector3(0, 0, 50)   # in the staff corridor, not yet safe
	var exhibits: Array[Enemy] = [_spawn(WaxFigure, Vector3(-3, 0, 38)), _spawn(Knight, Vector3(3, 0, 38)), _spawn(Wolf, Vector3(0, 0, 41))]
	await physics_frames(2)
	for exhibit in exhibits:
		exhibit.brain.wake()
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD
	var deepest := {}
	for exhibit in exhibits:
		deepest[exhibit] = -INF
	for frame in 12 * _ticks:
		await get_tree().physics_frame
		for exhibit in exhibits:
			deepest[exhibit] = maxf(deepest[exhibit], exhibit.global_position.z)
	target.position = Vector3(0, 0, 58.5)   # the guard reaches the security room
	for frame in 4 * _ticks:
		await get_tree().physics_frame
		for exhibit in exhibits:
			deepest[exhibit] = maxf(deepest[exhibit], exhibit.global_position.z)
	for exhibit in exhibits:
		var name := String(exhibit.get_script().get_global_name())
		assert_eq(exhibit.brain.state, EnemyBrain.State.SEARCH, "%s searches at the door" % name)
	for frame in 30 * _ticks:
		await get_tree().physics_frame
		for exhibit in exhibits:
			deepest[exhibit] = maxf(deepest[exhibit], exhibit.global_position.z)
	var security := level.layout.room(&"security").parts[0]
	for exhibit in exhibits:
		var name := String(exhibit.get_script().get_global_name())
		assert_gt(deepest[exhibit], 46.0, "%s followed down the staff corridor" % name)
		assert_lt(deepest[exhibit], security.position.y, "%s stayed out of the haven" % name)
		assert_lt(exhibit.global_position.distance_to(exhibit.home), 2.0, "%s went back home" % name)
		assert_eq(exhibit.brain.state, EnemyBrain.State.DORMANT, "%s sleeps again" % name)


func test_the_haven_is_on_its_own_navigation_layer() -> void:
	assert_gt(level.haven_region.navigation_mesh.get_polygon_count(), 0, "the haven has a mesh for itself")
	assert_eq(level.haven_region.navigation_layers, LevelNavigation.HAVEN_LAYER)
	var walker := Node3D.new()
	walker.position = Vector3(0, 0, 40)
	add_child(walker)
	var agent := NavigationAgent3D.new()
	agent.navigation_layers = LevelNavigation.WALK_LAYER
	walker.add_child(agent)
	await physics_frames(2)
	agent.target_position = Vector3(0, 0, 58.5)
	var end := agent.get_final_position()
	assert_gt(end.z, 50.0, "the path leads down the staff corridor")
	assert_lt(end.z, 54.0, "and ends at the haven door")


func test_haven_walls_close_both_doorways_to_exhibits_only() -> void:
	_add_havens()
	await physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	for pair in [[Vector3(0, 1, 50), Vector3(0, 1, 58)], [Vector3(0, 7, -20.5), Vector3(0, 7, -25)]]:
		var exhibit_ray := PhysicsRayQueryParameters3D.create(pair[0], pair[1], Layers.ENEMY_BLOCK)
		assert_false(space.intersect_ray(exhibit_ray).is_empty(), "exhibits stopped at %s" % pair[1])
	(level.doors[&"panel_closet"] as Door).open(true)
	await physics_frames(2)
	for pair in [[Vector3(0, 1, 50), Vector3(0, 1, 58)], [Vector3(0, 7, -20.5), Vector3(0, 7, -25)]]:
		var world_ray := PhysicsRayQueryParameters3D.create(pair[0], pair[1], Layers.WORLD)
		assert_true(space.intersect_ray(world_ray).is_empty(), "shots, sight and the guard pass to %s" % pair[1])


func test_a_locked_door_cuts_its_route_until_it_opens_again() -> void:
	var hall := Vector3(-12, 0, 0)
	var gallery := Vector3(-26, 0, 2)
	# the map may still hold the previous test's level for a moment
	var direct := INF
	for attempt in 60:
		direct = _path_length(hall, gallery)
		if direct < 20.0:
			break
		await get_tree().physics_frame
	assert_lt(direct, 20.0, "straight through the door")
	var door: Door = level.doors[&"door_hall_gallery"]
	door.lock(true)
	await level.navigation.rebaked
	await physics_frames(6)
	var around := _path_length(hall, gallery)
	assert_gt(around, 60.0, "round through the diorama and the west corridor")
	door.unlock()
	door.open(true)
	await level.navigation.rebaked
	await physics_frames(6)
	assert_almost_eq(_path_length(hall, gallery), direct, 1.0, "the door route is back")
