extends TestCase

## Seconds of game time the chase test may take (the slowest knight needs
## about half a minute from the far corner).
const CHASE_TIME := 40.0
## The chase test runs this many times faster than real time. The physics
## step stays 1/60 s, only more steps run per second.
const FAST_FORWARD := 8

var region: NavigationRegion3D
var _ticks: int
var _max_steps: int


func before_each() -> void:
	_ticks = Engine.physics_ticks_per_second
	_max_steps = Engine.max_physics_steps_per_frame
	region = NavigationRegion3D.new()
	add_child(region)
	SandboxArena.build(region)


func after_each() -> void:
	Engine.physics_ticks_per_second = _ticks
	Engine.max_physics_steps_per_frame = _max_steps
	Engine.time_scale = 1.0


func test_navigation_bakes_into_many_polygons() -> void:
	region.bake_navigation_mesh(false)
	assert_gt(region.navigation_mesh.get_polygon_count(), 10)


func test_floor_and_mezzanine_are_solid_at_expected_heights() -> void:
	await physics_frames(2)
	var space := region.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 10, 12), Vector3(0, -10, 12), Layers.WORLD))
	assert_almost_eq(floor_hit.get("position", Vector3.ONE * 99.0).y, 0.0, 0.01)
	var mezzanine_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-10, 10, -18), Vector3(-10, -10, -18), Layers.WORLD))
	assert_almost_eq(mezzanine_hit.get("position", Vector3.ONE * 99.0).y, SandboxArena.MEZZANINE_Y, 0.01)


## Waits until the navigation map has taken in the freshly baked mesh: its
## iteration id moved on and it finds the arena floor. At most
## [param max_frames] physics frames (the sync is asynchronous and may lag).
func _await_nav_sync(max_frames: int = 120) -> void:
	var map := region.get_navigation_map()
	var baked_at := NavigationServer3D.map_get_iteration_id(map)
	var probe := Vector3(0, 0, 12)
	for i in max_frames:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != baked_at \
				and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 0.5:
			return
	fail("the navigation map did not sync within %d frames" % max_frames)


func test_ramp_connects_floor_and_mezzanine() -> void:
	region.bake_navigation_mesh(false)
	await _await_nav_sync()
	var goal := Vector3(-10, SandboxArena.MEZZANINE_Y, -18)
	var path := NavigationServer3D.map_get_path(region.get_navigation_map(), Vector3(0, 0, 12), goal, true)
	assert_gt(path.size(), 1)
	if path.size() > 0:
		assert_lt(path[path.size() - 1].distance_to(goal), 1.0)


## Awake exhibits from every ground spawn point find their way up the ramp
## to a guard on the mezzanine instead of getting stuck on the way.
func test_exhibits_reach_a_guard_on_the_mezzanine() -> void:
	region.bake_navigation_mesh(false)
	var guard := TargetDummy.new()
	guard.position = Vector3(6, SandboxArena.MEZZANINE_Y, -18)
	add_child(guard)
	var exhibits: Array[Enemy] = []
	for base in Sandbox.SPAWN_POINTS:
		if base.y > 1.0:
			continue   # already up there
		var kinds: Array[Enemy] = [Wolf.new(), WaxFigure.new(), Knight.new()]
		for i in kinds.size():
			var exhibit := kinds[i]
			exhibit.position = base + Vector3(0, 0, 1.2 * (i - 1))
			exhibit.target = guard
			add_child(exhibit)
			exhibits.append(exhibit)
	await _await_nav_sync()
	var closest := {}
	for exhibit in exhibits:
		exhibit.summoned = true   # an arena wave (Sandbox.spawn): it knows where the guard is
		exhibit.brain.wake()
		closest[exhibit] = INF
	Engine.physics_ticks_per_second = _ticks * FAST_FORWARD
	Engine.max_physics_steps_per_frame = _max_steps * FAST_FORWARD
	Engine.time_scale = FAST_FORWARD
	for frame in int(CHASE_TIME * _ticks):
		await get_tree().physics_frame
		var waiting := 0
		for exhibit in exhibits:
			closest[exhibit] = minf(closest[exhibit], exhibit.global_position.distance_to(guard.global_position))
			if closest[exhibit] > 3.0:
				waiting += 1
		if waiting == 0:
			break
	var stuck := exhibits.filter(func(exhibit: Enemy) -> bool: return closest[exhibit] > 3.0)
	for exhibit in stuck:
		print("  stuck: %s at %s" % [exhibit.get_script().get_global_name(), exhibit.global_position])
	assert_eq(stuck.filter(func(exhibit: Enemy) -> bool: return exhibit is Wolf).size(), 0, "every wolf gets there")
	assert_lt(stuck.size(), 2, "nearly everyone gets there")
