extends TestCase
## The sleeper fits its coffin (review of the enemy ecology, 19.10: the
## mummy's forearms, hands and loose bandages stuck out through the back and
## sides of the shell). The mummy's whole rest pose (crossed arms, loose
## strips, the hanging whip), asleep under the lid and lying back in the
## open coffin after a hunt, is measured vertex by vertex against the
## coffin's own meshes: a ray from the middle of the case through each
## vertex meets the inner skin of the case (back half) or the outer skin of
## the lid (front half, while it is on); the vertex must lie short of it.
## And the coffin's footprint, bigger for it, still stands clear of the
## level wherever the floor puts an ambush mummy.

## Rigid parts (torso, head, arms, legs) keep this far (m) inside the case's
## inner skin and the lid's outer skin.
const CLEAR_BODY := 0.015
## Loose bandages (strips, whip) keep this far inside the case's outer skin
## (that is: the wall's thickness less this beyond the inner skin) and the
## lid's outer skin.
const CLEAR_LOOSE := 0.01
## Thickness (m) of the case's wall in the model.
const WALL := 0.035
## The mummy part names that are loose bandage.
const LOOSE: Array[String] = ["strip_", "whip_"]

var mummy: Mummy
var tomb: MummyTomb


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _entombed() -> void:
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, 40)   # far off, out of its sight
	add_child(dummy)
	mummy = Mummy.new()
	mummy.entombed = true
	mummy.target = dummy
	add_child(mummy)
	await physics_frames(240)
	tomb = mummy.tomb


## The mesh called [param part_name] ("coffin": case and stand, "lid") of the tomb's model.
func _part(part_name: String) -> MeshInstance3D:
	var found := tomb.find_children(part_name, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


## First hit (position, normal, distance) of the ray from [param from]
## along [param along] (tomb space) on [param view]'s mesh; empty for none.
func _hit(view: MeshInstance3D, triangles: TriangleMesh, from: Vector3, along: Vector3) -> Dictionary:
	var to_tomb := tomb.global_transform.affine_inverse() * view.global_transform
	var to_mesh := to_tomb.affine_inverse()
	var local_from := to_mesh * from
	var local_along := (to_mesh.basis * along).normalized()
	var hit: Dictionary = triangles.intersect_ray(local_from, local_along)
	if hit.is_empty():
		return {}
	var at: Vector3 = to_tomb * (hit["position"] as Vector3)
	var normal: Vector3 = (to_tomb.basis * (hit["normal"] as Vector3)).normalized()
	return {"at": at, "normal": normal, "distance": from.distance_to(at)}


## How far (m) inside the coffin's skin [param point] (tomb space) lies,
## looking from the middle of the coffin through it: the case's inner skin
## behind the seam, the lid's outer skin in front of it. Negative: through
## it; INF: no skin that way.
func _room_at(point: Vector3, case_tris: TriangleMesh, lid_tris: TriangleMesh, lid_on: bool) -> float:
	var axis := Vector3(0.0, point.y, 0.0)
	var way := point - axis
	way.y = 0.0
	if way.length() < 0.001:
		return INF
	var behind := point.z >= 0.0
	if not behind and not lid_on:
		return INF   # the lid lies on the floor: nothing in front of the mummy
	# (a hair either side of the seam, off the lid's flat back and the case's rim)
	var start := axis + Vector3(0.0, 0.0, 0.001 if behind else -0.001)
	var hit: Dictionary = _hit(_part("coffin") if behind else _part("lid"), case_tris if behind else lid_tris, start, way)
	if hit.is_empty():
		return -INF
	# the radial gap, slanted skins counted by how squarely the ray meets them
	return (float(hit["distance"]) - start.distance_to(point)) * absf((hit["normal"] as Vector3).dot(way.normalized()))


## Every vertex of the mummy's model in tomb space: [name, point].
func _mummy_points() -> Array:
	var points := []
	var inverse := tomb.global_transform.affine_inverse()
	for child in mummy.rig.model.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		if view.mesh == null:
			continue
		var to_tomb := inverse * view.global_transform
		for surface in view.mesh.get_surface_count():
			var vertices: PackedVector3Array = view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				points.append([String(view.name), to_tomb * vertex])
	return points


## Checks the whole pose; returns the tightest margin per kind of part and
## fails on any vertex through the shell.
func _check_pose(label: String, lid_on: bool) -> void:
	var case_tris := _part("coffin").mesh.generate_triangle_mesh()
	var lid_tris := _part("lid").mesh.generate_triangle_mesh()
	var tightest := {"body": INF, "loose": INF}
	var tightest_at := {}
	var worst := {}
	var count := 0
	for entry: Array in _mummy_points():
		var part_name: String = entry[0]
		var point: Vector3 = entry[1]
		var loose := false
		for prefix in LOOSE:
			loose = loose or part_name.begins_with(prefix)
		var room := _room_at(point, case_tris, lid_tris, lid_on)
		if room == INF:
			continue
		count += 1
		var kind := "loose" if loose else "body"
		# loose cloth may lie in the wall (it is hidden there), not through it
		var margin := room + (WALL if loose and point.z >= 0.0 else 0.0)
		var wanted := CLEAR_LOOSE if loose else CLEAR_BODY
		if margin < float(tightest[kind]):
			tightest[kind] = margin
			tightest_at[kind] = "%s %s" % [part_name, point.snapped(Vector3.ONE * 0.01)]
		if margin < wanted and (not worst.has(part_name) or margin < float(worst[part_name][0])):
			worst[part_name] = [margin, point.snapped(Vector3.ONE * 0.01)]
	assert_gt(count, 1500, "%s: the mummy's mesh was measured" % label)
	for part_name: String in worst:
		fail("%s: %s reaches within %.3f m of / through the shell at %s" % [label, part_name, worst[part_name][0], worst[part_name][1]])
	print("  %s: tightest margins (m): body %.3f (%s), loose %.3f (%s) over %d vertices" % [label, tightest["body"], tightest_at.get("body"), tightest["loose"], tightest_at.get("loose"), count])


func test_the_wall_is_as_thick_as_the_test_assumes() -> void:
	await _entombed()
	var case_tris := _part("coffin").mesh.generate_triangle_mesh()
	var start := Vector3(0.0, 1.0, 0.001)
	var inner: Dictionary = _hit(_part("coffin"), case_tris, start, Vector3(0.0, 0.0, 1.0))
	assert_false(inner.is_empty(), "the back of the case")
	var past: Vector3 = (inner["at"] as Vector3) + Vector3(0.0, 0.0, 0.002)
	var outer: Dictionary = _hit(_part("coffin"), case_tris, past, Vector3(0.0, 0.0, 1.0))
	assert_false(outer.is_empty(), "and its outside")
	assert_almost_eq(float(outer["distance"]) + 0.002, WALL, 0.004, "the wall is 3.5 cm thick")


func test_the_marker_puts_the_sleeper_in_the_middle_of_the_coffin() -> void:
	await _entombed()
	assert_almost_eq(tomb.spawn_point().origin.x, 0.0, 0.005)
	assert_almost_eq(tomb.spawn_point().origin.z, 0.0, 0.005, "the mummy stands on the coffin's axis")
	var local := tomb.global_transform.affine_inverse() * mummy.global_position
	assert_almost_eq(local.x, 0.0, 0.005)
	assert_almost_eq(local.z, 0.0, 0.005)


func test_the_sleeper_lies_inside_the_closed_coffin() -> void:
	await _entombed()
	assert_false(tomb.is_open())
	_check_pose("asleep", true)


func test_the_mummy_lying_back_after_a_hunt_is_inside_the_open_coffin() -> void:
	await _entombed()
	mummy.brain.wake()
	var frames := 0
	while mummy.in_tomb() and frames < 600:
		await get_tree().physics_frame
		frames += 1
	assert_false(mummy.in_tomb(), "it climbed out")
	await physics_frames(30)
	mummy.brain.call("_rest")   # the hunt over and home again: it lies down to rest
	await physics_frames(300)
	assert_true(mummy.in_tomb(), "back in its coffin")
	assert_eq(mummy.brain.state, EnemyBrain.State.DORMANT)
	assert_true(tomb.is_open(), "the lid stays off")
	_check_pose("resting", false)


func test_the_coffins_walls_and_stand_are_as_big_as_the_model() -> void:
	await _entombed()
	var bounds := AABB()
	for child in tomb.find_children("*", "MeshInstance3D", true, false):
		var view := child as MeshInstance3D
		var box := view.global_transform * view.get_aabb()
		bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
	assert_almost_eq(bounds.size.x, MummyTomb.COFFIN_SIZE.x, 0.01, "as wide as its stand (and walls)")
	# (the lid's carved face stands a little out of the front, the stand's post behind)
	assert_almost_eq(bounds.size.y, MummyTomb.COFFIN_SIZE.y, 0.03, "as tall")
	assert_lt(bounds.size.z, MummyTomb.COFFIN_SIZE.z + 0.001, "no deeper than the walls")
	assert_gt(bounds.size.z, MummyTomb.COFFIN_SIZE.z - 0.12, "and not much less")


## Floor I's mummies of an ambush each stand up a coffin at their post
## (Mummy._settle_in_tomb): its footprint (stand and walls, turned to the
## slot's yaw) must not overlap a wall, a case or any piece of the level.
func test_every_ambush_coffin_stands_clear_of_the_level() -> void:
	var level := MuseumFloorLevel.new()
	level.bake_navigation = false
	add_child(level)
	level.build()
	await physics_frames(1)
	var layout := level.layout
	var wanted := {}
	for ambush in layout.ambushes:
		for index in ambush.slots:
			wanted[index] = true
	var shape := BoxShape3D.new()
	var half := MummyTomb.COFFIN_SIZE * 0.5
	shape.size = Vector3(MummyTomb.COFFIN_SIZE.x, MummyTomb.COFFIN_SIZE.y - 0.3, MummyTomb.COFFIN_SIZE.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = Layers.WORLD
	var space := get_viewport().find_world_3d().direct_space_state
	var checked := 0
	for index: int in wanted:
		var slot := layout.spawn_slots[index]
		if not slot.kinds.has(&"mummy"):
			continue
		checked += 1
		# (the box floats over the floor and under the ceiling: only walls and pieces)
		query.transform = Transform3D(Basis(Vector3.UP, slot.yaw), slot.position + Vector3(0.0, half.y + 0.05, 0.0))
		var hits := space.intersect_shape(query, 8)
		var names := []
		for hit: Dictionary in hits:
			names.append(str((hit["collider"] as Node).name))
		assert_eq(hits.size(), 0, "the coffin of the %s mummy at %s (yaw %.2f) stands in %s" % [slot.room, slot.position, slot.yaw, names])
	assert_gt(checked, 3, "Floor I has ambush mummies to check")
	print("  %d ambush coffins checked against the level" % checked)
	level.queue_free()
