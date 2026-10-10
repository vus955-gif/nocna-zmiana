extends TestCase

var dummy: TargetDummy
var head: Hurtbox


func before_each() -> void:
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	head = Hurtbox.make(dummy, sphere, Vector3(0, 1.5, 0), true)
	dummy.add_child(head)


func test_ray_reports_the_hurtbox_it_hits() -> void:
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	assert_eq(hit.get("hurtbox"), head)
	assert_almost_eq(hit["position"].z, -5.7, 0.01)


func test_walls_block_rays() -> void:
	Greybox.box(self, Vector3(0, 1.5, -3), Vector3(4, 3, 0.5), Color.GRAY)
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	assert_true(hit.get("hurtbox") == null)
	assert_almost_eq(hit["position"].z, -2.75, 0.01)


func test_spread_stays_inside_the_cone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var forward := Vector3(0, 0, -1)
	var widest := 0.0
	for i in 500:
		var dir := Hitscan.spread_direction(forward, 7.0, rng)
		widest = maxf(widest, rad_to_deg(forward.angle_to(dir)))
		if absf(dir.length() - 1.0) > 0.0001:
			fail("direction not normalized")
			break
	assert_true(widest <= 7.0001, "widest %s" % widest)
	assert_gt(widest, 5.0)


func test_zero_spread_is_exact() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(Hitscan.spread_direction(Vector3(0, 0, -1), 0.0, rng), Vector3(0, 0, -1))


func test_sphere_sweep_finds_close_hurtboxes_only() -> void:
	var near := TargetDummy.new()
	near.position = Vector3(0, 0, -1)
	add_child(near)
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	var near_box := Hurtbox.make(near, box, Vector3(0, 1.5, 0))
	near.add_child(near_box)
	await physics_frames(2)
	var found := Hitscan.sphere_hurtboxes(near.get_world_3d().direct_space_state, Vector3(0, 1.5, -1.2), 0.7)
	assert_eq(found.size(), 1)
	if found.size() == 1:
		assert_eq(found[0], near_box)


func test_ray_starting_inside_a_hurtbox_hits_it() -> void:
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, -6), Vector3(0, 1.5, -20))
	assert_eq(hit.get("hurtbox"), head)


func test_trigger_areas_never_stop_a_shot() -> void:
	# both areas keep the default layer 1 (= WORLD); the shot starts inside one
	add_child(_area(Vector3(0, 0, 0), Vector3(6, 6, 6)))
	add_child(_area(Vector3(0, 1.5, -4), Vector3(4, 4, 0.5)))
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var hit := Hitscan.ray(space, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	assert_eq(hit.get("hurtbox"), head, "the head behind both areas is hit")


func _area(at: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	area.add_child(shape)
	area.position = at
	return area


## A zone of an exact mesh reports one overlap per triangle: a sphere
## sweep must still find every zone in reach, each once.
func test_a_sweep_finds_small_zones_next_to_mesh_zones() -> void:
	var dense := SphereMesh.new()
	dense.radius = 0.5
	dense.height = 1.0
	dense.radial_segments = 32
	dense.rings = 16
	var zones: Array[Hurtbox] = []
	for i in 3:
		var bone := Hurtbox.make(dummy, dense.create_trimesh_shape(), Vector3(-1.0 + i, 1.0, -6.0))
		add_child(bone)
		zones.append(bone)
	for i in 3:
		var small := SphereShape3D.new()
		small.radius = 0.12
		var gem := Hurtbox.make(dummy, small, Vector3(-0.5 + 0.5 * i, 1.6, -5.4), true)
		add_child(gem)
		zones.append(gem)
	await physics_frames(2)
	var space := dummy.get_world_3d().direct_space_state
	var found := Hitscan.sphere_hurtboxes(space, Vector3(0, 1.2, -5.8), 2.5)
	for zone in zones:
		assert_true(found.has(zone), "every zone in reach")
	var unique := {}
	for zone in found:
		unique[zone] = true
	assert_eq(unique.size(), found.size(), "each zone once")
	for i in found.size() - 1:
		assert_true(found[i].global_position.distance_to(Vector3(0, 1.2, -5.8)) <= found[i + 1].global_position.distance_to(Vector3(0, 1.2, -5.8)), "closest first")


## A flare's blast between the T-Rex's leg and a wax figure burns the wax
## figure in full (fire: double) as well as the bones.
func test_a_blast_next_to_the_trex_still_reaches_the_wax_figure() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	var rex := TRex.new()
	rex.position = Vector3(0, 0, -10)
	add_child(rex)
	await physics_frames(4)
	var leg := Vector3.ZERO
	for zone in rex.skeleton.hurtboxes:
		if String(zone.get_parent().name).begins_with("shin"):
			leg = zone.global_position
			break
	var wax := WaxFigure.new()
	wax.target = dummy
	wax.position = Vector3(leg.x + 2.0, 0, leg.z)
	add_child(wax)
	await physics_frames(3)
	wax.set_physics_process(false)
	rex.set_physics_process(false)
	var before := wax.health.current
	var hit := Blast.explode(self, Vector3(leg.x + 1.0, 1.0, leg.z), 2.5, 20.0, 6.0, DamageInfo.Kind.FIRE, null)
	assert_almost_eq(before - wax.health.current, 40.0, 0.01, "the wax figure takes the whole blast, twice for fire")
	assert_true(hit.any(func(receiver: Node) -> bool: return receiver is TRexZone), "and the bones are hit too")
