class_name MenuStageCheck
extends RefCounted
## Checks of a built MenuStage against the level it flies over (tests and the
## menu scenario's dry run; the level must have had two physics frames to
## register its colliders):
## - every shot, every [param step] seconds: the eye is in a room or in a
##   passage between two, not in a wall, with 0.4 m of room round it, and its
##   subject is in sight (the first wall on the way to it is further than
##   half the distance, at most 4 m),
## - the T-Rex's bounding box stays in frame through its shot (16:9) and sits
##   right of the middle.

const CLEARANCE := 0.4
const SIGHT := 4.0
## Share of the half-frame the T-Rex's box may fill at most (1 = to the edge).
const FRAME_LIMIT := 0.96


## Problems found along every shot (empty = all well).
static func shot_problems(stage: MenuStage, space: PhysicsDirectSpaceState3D, step: float = 0.5) -> PackedStringArray:
	var found := PackedStringArray()
	var sphere := SphereShape3D.new()
	sphere.radius = CLEARANCE
	for shot in stage.shots:
		var t := 0.0
		while t <= shot.seconds + 0.001:
			var eye := shot.pose(t).origin
			var at := shot.focus_at(MenuRail.ease_motion(t / shot.seconds))
			var where := "%s at %.1f s %s" % [shot.id, t, str(eye.snapped(Vector3.ONE * 0.1))]
			if not inside(stage, eye):
				found.append("%s: outside every room and passage" % where)
			var point := PhysicsPointQueryParameters3D.new()
			point.position = eye
			point.collision_mask = Layers.WORLD
			if not space.intersect_point(point).is_empty():
				found.append("%s: in a wall" % where)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY, eye)
			query.collision_mask = Layers.WORLD
			if not space.intersect_shape(query, 1).is_empty():
				found.append("%s: less than %.1f m from a wall" % [where, CLEARANCE])
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, Layers.WORLD))
			var clear := eye.distance_to(at) if hit.is_empty() else eye.distance_to(hit["position"])
			if clear <= minf(SIGHT, eye.distance_to(at) * 0.5):
				found.append("%s: the subject is hidden %.1f m ahead" % [where, clear])
			t += step
	return found


## True when [param point] lies in a room or in a passage (door, arch) between two.
static func inside(stage: MenuStage, point: Vector3) -> bool:
	if stage.level.room_at(point) != &"":
		return true
	for passage in stage.level.layout.openings:
		if passage.rect.grow(0.01).has_point(Vector2(point.x, point.z)) and point.y >= passage.floor_y and point.y <= passage.top_y:
			return true
	return false


## The T-Rex's bounding box (world), or an empty AABB when it has no meshes.
static func trex_box(stage: MenuStage) -> AABB:
	var box := AABB()
	var first := true
	if stage.trex == null:
		return box
	for node in stage.trex.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Problems with the T-Rex's framing through its shot (poses it by
## show_shot(); leaves the camera at the end of the shot).
static func trex_problems(stage: MenuStage, step: float = 3.0) -> PackedStringArray:
	var found := PackedStringArray()
	var box := trex_box(stage)
	if box.size == Vector3.ZERO:
		found.append("the T-Rex has no meshes")
		return found
	var index := -1
	for i in stage.shots.size():
		if stage.shots[i].id == &"trex":
			index = i
	if index < 0:
		found.append("no T-Rex shot")
		return found
	var t := 0.0
	var seconds := stage.shots[index].seconds
	while t <= seconds + 0.001:
		stage.show_shot(index, t)
		var view := stage.camera.global_transform.affine_inverse()
		var half := tan(deg_to_rad(stage.camera.fov) * 0.5)
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var ahead := true
		for k in 8:
			var corner := box.position + box.size * Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1)
			var local := view * corner
			if local.z > -0.2:
				ahead = false
				continue
			var ndc := Vector2(local.x / -local.z / (half * 16.0 / 9.0), local.y / -local.z / half)
			low = low.min(ndc)
			high = high.max(ndc)
		var where := "the T-Rex at %.1f s" % t
		if not ahead:
			found.append("%s is not ahead of the camera" % where)
		elif low.x < -FRAME_LIMIT or high.x > FRAME_LIMIT or low.y < -FRAME_LIMIT or high.y > FRAME_LIMIT:
			found.append("%s leaves the frame (x %.2f..%.2f, y %.2f..%.2f)" % [where, low.x, high.x, low.y, high.y])
		elif (low.x + high.x) * 0.5 < 0.05:
			found.append("%s is not right of the middle (%.2f)" % [where, (low.x + high.x) * 0.5])
		t += step
	return found
