extends TestCase
## Every objective of every night can be reached on foot and used: on the
## real navmesh (walk layer) with any door the director may lock shut, the
## guard gets from outside the booth to each fuse point, the fuse box and
## each crystal case; standing in front of a fuse he can focus it (E), and
## by each crystal case his chest comes within the crystal's reach.

## Outside the security booth, where every night's walk begins.
const FROM := Vector3(0.0, 0.0, 48.0)

var level: LobbyLevel
var bed: WorldTestbed


func after_each() -> void:
	if is_instance_valid(level):
		level.free()
	if is_instance_valid(bed):
		bed.free()


## A night with [param door] locked (none: a first night).
func _night_with_locked(door: StringName, description: LevelDescription) -> NightConfig:
	if door == &"":
		return NightDirector.plan(1, 1, description)
	for night_seed in 800:
		var config := NightDirector.plan(night_seed, 3, description)
		if config.locked_door == door:
			return config
	return null


func _front(marker: Transform3D, distance: float) -> Vector3:
	var front := -marker.basis.z
	front.y = 0.0
	return marker.origin + front.normalized() * distance


## How close (flat metres) a walk from FROM ends to [param marker] (INF when
## no path ends near its floor).
func _walk_to(map: RID, marker: Transform3D) -> float:
	var from := NavigationServer3D.map_get_closest_point(map, FROM)
	var best := INF
	for d in [0.9, 1.3, 1.8]:
		var goal := NavigationServer3D.map_get_closest_point(map, _front(marker, d))
		var path := NavigationServer3D.map_get_path(map, from, goal, true, LevelNavigation.WALK_LAYER)
		if path.is_empty():
			continue
		var end := path[path.size() - 1]
		if absf(end.y - (marker.origin.y - 1.0)) < 2.5:
			best = minf(best, Vector2(end.x - marker.origin.x, end.z - marker.origin.z).length())
	return best


func test_every_objective_is_walkable_with_any_door_the_director_locks() -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	var doors: Array[StringName] = [&""]
	doors.append_array(NightDirector.safe_doors(description))
	assert_gt(doors.size(), 3)
	for door in doors:
		var config := _night_with_locked(door, description)
		assert_not_null(config, "a night locks " + door)
		if config == null:
			continue
		level = LobbyLevel.new()
		level.night = config
		add_child(level)
		level.build()
		for i in 240:
			if not level.navigation.is_baking():
				break
			await physics_frames(1)
		await physics_frames(3)
		var map := level.walk_region.get_navigation_map()
		var targets := {&"fuse_box": level.markers[&"fuse_box"]}
		for wing: StringName in LobbyLayout.FUSE_POINTS:
			for point: StringName in LobbyLayout.FUSE_POINTS[wing]:
				targets[point] = level.markers[point]
		for case_marker in LobbyLayout.CRYSTAL_CASES:
			targets[case_marker] = level.markers[case_marker]
		for id: StringName in targets:
			var reached := _walk_to(map, targets[id])
			assert_lt(reached, 2.4, "locked %s: %s nearest reachable %.2f m" % [door if door != &"" else &"none", id, reached])
		level.free()
		await physics_frames(2)


func _look_at(target: Node3D, height: float, distance: float) -> Node:
	var front := -target.global_transform.basis.z
	front.y = 0.0
	front = front.normalized()
	var stand := target.global_position + front * distance
	var query := PhysicsRayQueryParameters3D.create(stand + Vector3.UP, stand + Vector3.DOWN * 4.0, Layers.WORLD)
	var hit := bed.get_world_3d().direct_space_state.intersect_ray(query)
	stand.y = (hit["position"] as Vector3).y + 0.05 if not hit.is_empty() else stand.y
	bed.player.global_position = stand
	var aim := target.global_position + Vector3.UP * height - (stand + Vector3.UP * bed.player.eye_height)
	bed.player.head.rotation = Vector3(atan2(aim.y, Vector2(aim.x, aim.z).length()), atan2(-aim.x, -aim.z), 0.0)
	for i in 30:
		await physics_frames(1)
		if bed.player.interactor.focus == target:
			break
	return bed.player.interactor.focus


func test_every_fuse_can_be_focused_and_every_crystal_case_reached() -> void:
	bed = WorldTestbed.new()
	add_child(bed)
	bed.setup()
	await physics_frames(3)
	GameInput.clear_ui()
	for wing: StringName in LobbyLayout.FUSE_POINTS:
		for point: StringName in LobbyLayout.FUSE_POINTS[wing]:
			var fuse := FusePickup.new()
			fuse.wing = wing
			fuse.transform = bed.level.markers[point]
			bed.add_child(fuse)
			await physics_frames(1)
			var focused := false
			for d in [0.8, 1.0, 1.3]:
				if await _look_at(fuse, 0.05, d) == fuse:
					focused = true
					break
			assert_true(focused, "fuse on %s can be taken" % point)
			fuse.free()
	var space := bed.get_world_3d().direct_space_state
	for case_marker in LobbyLayout.CRYSTAL_CASES:
		var crystal: Vector3 = (bed.level.markers[case_marker] as Transform3D).origin
		var best := INF
		for step in 16:
			for r in [0.9, 1.2, 1.6, 2.0]:
				var p := crystal + Vector3(cos(TAU * step / 16.0), 0.0, sin(TAU * step / 16.0)) * float(r)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.2, p + Vector3.DOWN * 4.0, Layers.WORLD))
				if hit.is_empty() or (hit["position"] as Vector3).y > crystal.y - 0.5:
					continue   # nothing to stand on, or the top of the case itself
				best = minf(best, ((hit["position"] as Vector3) + Vector3.UP * 1.2).distance_to(crystal))
		assert_lt(best, CrystalRelic.REACH, "%s: the guard's chest gets within %.1f m (%.2f)" % [case_marker, CrystalRelic.REACH, best])
