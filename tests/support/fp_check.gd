class_name FpCheck
## Checks of first-person poses for the tests (plan 2026-10-21-animacje-fpp):
## where a point of a viewmodel shows in the 16:9 frame (drawn with the
## viewmodel field of view from the holder's eye), whether the near plane
## cuts a model inside the frame, the full sprint carry of a weapon, and how
## far a model moved between two frames.

const NEAR := 0.05


## True when [param point] of [param rig]'s model (root space) shows in the
## frame, [param margin] of the frame's half size inside its edges (a
## negative margin: that much outside them).
static func in_frame(rig: ViewmodelRig, point: Vector3, margin: float = 0.0) -> bool:
	var at: Vector3 = rig.transform * rig.model.transform * point
	return on_screen(at, margin)


## True when [param at] (the holder's space) shows in the frame.
static func on_screen(at: Vector3, margin: float = 0.0) -> bool:
	var depth := -at.z
	if depth <= 0.01:
		return false
	var half_h := depth * tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	var half_w := half_h * 16.0 / 9.0
	return absf(at.x) < half_w * (1.0 - margin) and absf(at.y) < half_h * (1.0 - margin)


## [param node]'s transform in [param holder]'s space.
static func to_holder(holder: Node3D, node: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != holder:
		out = (at as Node3D).transform * out
		at = at.get_parent()
	return out


## True when no vertex of [param view]'s visible meshes shows in the frame:
## all of them under the plane of the frame's bottom edge through the eye
## (so no triangle can reach into the frame either).
static func under_frame(holder: Node3D, view: Node3D) -> bool:
	var t := tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var xf := to_holder(holder, mesh)
		for vertex in mesh.mesh.get_faces():
			var p: Vector3 = xf * vertex
			if p.y >= t * p.z:
				return false
	return true


## Where the near plane cuts [param view]'s visible meshes: the smallest
## max(|x|, |y|) of the cut points in frame units (1 = the frame's edge);
## INF when nothing reaches the near plane. Above 1: every cut lies outside
## the frame (the sleeves run past the eye out of sight).
static func near_cut(holder: Node3D, view: Node3D) -> float:
	var t := tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV) * 0.5)
	var nearest := INF
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var xf := to_holder(holder, mesh)
		var faces := mesh.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			for k in 3:
				var a: Vector3 = xf * faces[i + k]
				var b: Vector3 = xf * faces[i + (k + 1) % 3]
				var da := -a.z - NEAR
				var db := -b.z - NEAR
				if da * db >= 0.0:
					continue
				var p := a.lerp(b, da / (da - db))
				var on := Vector2(p.x / (NEAR * t) * 9.0 / 16.0, p.y / (NEAR * t))
				nearest = minf(nearest, maxf(absf(on.x), absf(on.y)))
	return nearest


## Poses [param view] (weapon [param id]) in its full sprint carry at
## stride phase [param phase], nothing else on.
static func pose_full_carry(holder: WeaponHolder, view: Node3D, id: StringName, phase: float) -> void:
	holder._sprint_pose = 1.0
	holder._bob_time = phase
	holder._pose_view(view, id, WeaponHolder.REST, Vector3(0.0, WeaponHolder.AIM_YAW, 0.0))
	holder._sprint_pose = 0.0


## Every visible mesh of [param view]: name -> its transform in the
## holder's space (compare two of these with moved()).
static func snapshot(holder: Node3D, view: Node3D) -> Dictionary:
	var out := {}
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree() and mesh.mesh != null:
			out[String(mesh.get_path())] = to_holder(holder, mesh)
	return out


## The widest move between two snapshots of the same meshes: [metres of the
## mesh's box centre, radians of its turn, the mesh's name]; a mesh in only
## one of them (shown or hidden meanwhile) does not count.
static func moved(before: Dictionary, after: Dictionary, view: Node3D) -> Array:
	var widest := 0.0
	var widest_turn := 0.0
	var which := ""
	for key: String in after:
		if not before.has(key):
			continue
		var mesh := view.get_node_or_null(NodePath(key)) as MeshInstance3D
		var centre := mesh.get_aabb().get_center() if mesh != null else Vector3.ZERO
		var a: Transform3D = before[key]
		var b: Transform3D = after[key]
		var step := (a * centre).distance_to(b * centre)
		var turn := a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())
		if step > widest:
			widest = step
			which = key.get_file()
		widest_turn = maxf(widest_turn, turn)
	return [widest, widest_turn, which]


## The first frame (index into [param steps], each frame's widest move)
## whose move is a jump: more than [param ratio] times the moves of the
## frames on either side of it (and over [param floor] m) - a motion speeds
## up and slows down, a jump comes out of nowhere; -1 when there is none.
static func spike(steps: Array, ratio: float = 2.5, floor_m: float = 0.02) -> int:
	for i in steps.size():
		var step := float(steps[i])
		if step < floor_m:
			continue
		var before := float(steps[i - 1]) if i > 0 else 0.0
		var after := float(steps[i + 1]) if i + 1 < steps.size() else 0.0
		if step > ratio * maxf(before, after):
			return i
	return -1


## Like moved(), but only what can be seen moves: the corners and the
## centre of each mesh's box, counted where they show in the frame (in
## either snapshot). A long sleeve swinging down out of the frame by the
## elbow does not count, its wrist end in sight does. [metres, radians of
## the turn of a mesh with a point in sight, the mesh's name].
static func moved_in_sight(before: Dictionary, after: Dictionary, view: Node3D) -> Array:
	var widest := 0.0
	var widest_turn := 0.0
	var which := ""
	for key: String in after:
		if not before.has(key):
			continue
		var mesh := view.get_node_or_null(NodePath(key)) as MeshInstance3D
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		var points: Array[Vector3] = [box.get_center()]
		for i in 8:
			points.append(box.get_endpoint(i))
		var a: Transform3D = before[key]
		var b: Transform3D = after[key]
		var seen := false
		for point in points:
			var from := a * point
			var to := b * point
			if not on_screen(from) and not on_screen(to):
				continue
			seen = true
			var step := from.distance_to(to)
			if step > widest:
				widest = step
				which = key.get_file()
		if seen:
			widest_turn = maxf(widest_turn, a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))
	return [widest, widest_turn, which]
