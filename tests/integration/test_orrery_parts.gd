extends TestCase
## The Great Orrery's parts on a bare floor (no museum): its rig (the model
## with the moons, Earth's Moon and Saturn's rings cut out on axes of their
## own, petals opening outward, tiers carrying their planets), the moves
## (backlash, pendulum moons), the rolling planets and the solar flares.

const G := preload("res://src/game/floor1/guardians/orrery_geometry.gd")

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(60.0, 1.0, 60.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)


func after_each() -> void:
	world.free()


static func _triangles(mesh: Mesh) -> int:
	var count := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		count += index.size() / 3 if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


## The world box of [param view]'s mesh.
static func _world_box(view: MeshInstance3D) -> AABB:
	return view.global_transform * view.mesh.get_aabb()


func test_a_mesh_is_partitioned_by_its_triangles_in_its_own_space() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())
	var pieces := MeshShards.partition(mesh, func(c: Vector3) -> int: return 0 if c.x < -0.3 else (1 if c.x < 0.3 else 2), 3, "test_thirds")
	assert_eq(pieces.size(), 3)
	var total := 0
	for piece: MeshShards.Piece in pieces:
		assert_not_null(piece)
		total += _triangles(piece.mesh)
		assert_eq(piece.center, Vector3.ZERO, "left in the mesh's space")
	assert_eq(total, _triangles(mesh), "every triangle in one piece")
	assert_lt((pieces[2] as MeshShards.Piece).mesh.get_aabb().position.x, 0.3, "the right third starts near x 0.3")
	assert_gt((pieces[2] as MeshShards.Piece).mesh.get_aabb().position.x, 0.0)
	assert_eq(MeshShards.partition(mesh, func(_c: Vector3) -> int: return 0, 3, "test_thirds"), pieces, "cached")
	var halves := MeshShards.split(mesh, func(c: Vector3) -> bool: return c.y > 0.0, "test_halves")
	assert_eq(_triangles((halves[0] as MeshShards.Piece).mesh) + _triangles((halves[1] as MeshShards.Piece).mesh), _triangles(mesh))


func test_the_rig_has_every_part_and_its_moons_hang_on_their_rods() -> void:
	var rig := OrreryRig.create(world)
	assert_false(rig.greybox, "the model is in the project")
	if rig.greybox:
		return
	for name in ["planetarium", "sun_glow", "sun_core", "tier_low", "tier_mid", "tier_high"]:
		assert_not_null(rig.part(name), name)
	assert_eq(rig.planets.size(), 6)
	assert_eq(rig.petals.size(), 6)
	assert_eq(rig.moons.size(), 10)
	var tier := rig.tiers[G.HIGH] as MeshInstance3D
	var moon_triangles := 0
	for m in 10:
		var view := rig.moon_views[m]
		assert_not_null(view.mesh, "moon %d cut out" % m)
		if view.mesh == null:
			continue
		moon_triangles += _triangles(view.mesh)
		assert_almost_eq(rig.moons[m].position.distance_to(G.moon_pivot(m)), 0.0, 0.001, "its pivot on the rod's top")
		var box := view.mesh.get_aabb()
		var center := box.get_center()
		var want := G.moon_center(m)
		assert_lt(Vector2(center.x - want.x, center.z - want.z).length(), 0.05, "moon %d is the moon at %s" % [m, want])
		assert_almost_eq(box.end.y, G.moon_pivot(m).y, 0.03, "its rod reaches the beam")
		assert_almost_eq(box.position.y, want.y - G.MOON_SIZE, 0.03, "its ball hangs low")
	var source := ArtLibrary.exhibit(&"planetarium")
	var whole := source.find_child("tier_high", true, false) as MeshInstance3D
	assert_eq(_triangles(tier.mesh) + moon_triangles, _triangles(whole.mesh), "no triangle lost or doubled")
	source.free()
	assert_lt(tier.mesh.get_aabb().position.y, -0.1, "the beam and its hub stay")
	assert_gt(tier.mesh.get_aabb().position.y + G.PIVOT[G.HIGH], G.BEAM[G.HIGH].x - 0.2, "no moon left in the beam's mesh")
	assert_not_null(rig.earth_moon_view, "Earth's Moon on its crank")
	assert_not_null(rig.saturn_rings_view, "Saturn's rings")
	if rig.earth_moon_view != null:
		var moon := rig.earth_moon_view.mesh.get_aabb()
		assert_lt(moon.get_center().distance_to(G.EARTH_MOON * Vector3(0.6, 0.5, 0.6)), 0.4, "out on the crank: %s" % moon)
		assert_gt((rig.planets[2] as MeshInstance3D).mesh.get_aabb().position.x, -0.45, "Earth alone is round")
	if rig.saturn_rings_view != null:
		assert_gt(rig.saturn_rings_view.mesh.get_aabb().size.x, 1.9, "rings 2 m across")
		assert_lt((rig.planets[5] as MeshInstance3D).mesh.get_aabb().size.x, 1.05, "Saturn alone is round")


func test_the_greybox_has_the_same_parts() -> void:
	var enabled := ArtLibrary.models_enabled
	ArtLibrary.models_enabled = false
	var rig := OrreryRig.create(world)
	ArtLibrary.models_enabled = enabled
	assert_true(rig.greybox)
	for name in ["sun_glow", "sun_core", "tier_low", "tier_mid", "tier_high", "earth_moon", "saturn_rings", "moon_pivot_0", "moon_pivot_9"]:
		assert_not_null(rig.part(name), name)
	for k in 6:
		assert_not_null(rig.part("planet_%d" % (k + 1)))
		assert_not_null(rig.part("socket_%d" % (k + 1)))
		assert_not_null(rig.part("sun_shell_%d" % (k + 1)))
	rig.apply(OrreryRig.Pose.new(), 0.1)
	assert_lt(rig.part("planet_2").global_position.distance_to(G.socket(1) + Vector3.UP * G.PIVOT[G.LOW]), 0.01, "Venus on her socket")


func test_a_turned_tier_carries_its_planets_and_moons() -> void:
	var rig := OrreryRig.create(world)
	var pose := OrreryRig.Pose.new()
	pose.tier_yaw[G.HIGH] = PI * 0.5
	rig.apply(pose, 0.016)
	var jupiter := rig.planets[4].global_position
	var want := Basis(Vector3.UP, PI * 0.5) * G.socket(4) + Vector3.UP * G.PIVOT[G.HIGH]
	assert_lt(jupiter.distance_to(want), 0.01, "Jupiter rode round: %s vs %s" % [jupiter, want])
	var moon := rig.moons[3].global_position
	assert_lt(moon.distance_to(Basis(Vector3.UP, PI * 0.5) * G.moon_pivot(3) + Vector3.UP * G.PIVOT[G.HIGH]), 0.01)
	assert_lt(rig.planets[0].global_position.distance_to(G.socket(0) + Vector3.UP * G.PIVOT[G.LOW]), 0.01, "Mercury stays: another tier")
	# a swinging moon: its ball moves the way it swings, the rod's top stays
	pose.moon_swing[3] = Vector2(0.3, 0.0)
	rig.apply(pose, 0.016)
	var forward := Basis(Vector3.UP, PI * 0.5) * Vector3.UP.cross(G.arm_direction(G.HIGH, 0))
	var ball := rig.moon_views[3].global_transform * rig.moon_views[3].mesh.get_aabb().get_center()
	var straight := Basis(Vector3.UP, PI * 0.5) * G.moon_center(3) + Vector3.UP * G.PIVOT[G.HIGH]
	assert_gt((ball - straight).dot(forward), 0.1, "swung forward")


func test_the_petals_open_outward() -> void:
	var rig := OrreryRig.create(world)
	var pose := OrreryRig.Pose.new()
	rig.apply(pose)
	var shut: Array[float] = []
	for k in 6:
		var box := _world_box(rig.petals[k] as MeshInstance3D)
		shut.append(Vector2(box.get_center().x, box.get_center().z).length())
		pose.petals[k] = G.PETAL_OPEN
	rig.apply(pose)
	for k in 6:
		var box := _world_box(rig.petals[k] as MeshInstance3D)
		var open := Vector2(box.get_center().x, box.get_center().z).length()
		assert_gt(open, shut[k] + 0.5, "petal %d folds out (%.2f -> %.2f)" % [k + 1, shut[k], open])
		assert_lt(box.get_center().y, G.SUN_HEIGHT, "and down past the core")


func test_a_tier_lags_its_drive_then_swings_past_and_its_moons_trail() -> void:
	var rig := OrreryRig.create(world)
	var drives: Array[OrreryDrive] = []
	for t in 3:
		drives.append(OrreryDrive.new(OrreryBrain.RATE[t]))
	var moves := OrreryMoves.new(rig, drives)
	var brain := OrreryBrain.new()
	brain.wake()
	for i in roundi(OrreryBrain.WAKE_TIME * 60.0) + 2:
		brain.update(1.0 / 60.0, 8.0)
	drives[G.HIGH].target = 1.6
	var lag := 0.0
	var trail := 0.0
	for i in 40:
		drives[G.HIGH].step(1.0 / 60.0)
		var pose := moves.compose(brain, 1.0 / 60.0)
		lag = minf(lag, wrapf(pose.tier_yaw[G.HIGH] - drives[G.HIGH].angle, -PI, PI))
		trail = minf(trail, pose.moon_swing[2].x)
	assert_lt(lag, -0.01, "the tier lags its drive as it speeds up")
	assert_lt(trail, -0.05, "the moons trail")
	drives[G.HIGH].target = 0.0
	var ahead := 0.0
	var past := 0.0
	for i in 150:
		drives[G.HIGH].step(1.0 / 60.0)
		var pose := moves.compose(brain, 1.0 / 60.0)
		if drives[G.HIGH].steady():
			ahead = maxf(ahead, wrapf(pose.tier_yaw[G.HIGH] - drives[G.HIGH].angle, -PI, PI))
		past = maxf(past, pose.moon_swing[2].x)
	assert_gt(ahead, 0.005, "it swings past where it stopped (backlash)")
	assert_gt(past, 0.05, "the moons swing on past")


# --- hazards -------------------------------------------------------------------------

## A guard stand-in: it counts what hurts it (feet on its origin).
class Dummy:
	extends Node3D
	var taken: float = 0.0
	var hits: int = 0
	var alive := true

	func take_damage(info: DamageInfo) -> void:
		taken += info.amount
		hits += 1


func _dummy(at: Vector3) -> Dummy:
	var dummy := Dummy.new()
	world.add_child(dummy)
	dummy.global_position = at
	return dummy


func _ball_view(radius: float) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())
	view.mesh = mesh
	world.add_child(view)
	return view


func _roll(at: Vector3, velocity: Vector3, radius: float, guard: Node3D) -> RollingPlanet:
	var view := _ball_view(radius)
	view.global_position = at
	var views: Array[MeshInstance3D] = [view]
	var planet := RollingPlanet.make(views, view.global_transform, velocity, radius)
	planet.target = guard
	world.add_child(planet)
	view.queue_free()
	return planet


func test_a_planet_shot_off_rolls_and_hurts_who_stands_in_its_way_once() -> void:
	var guard := _dummy(Vector3(4.0, 0.0, 0.0))
	var planet := _roll(Vector3(0.0, 1.2, 0.0), Vector3(5.0, 0.0, 0.0), 0.35, guard)
	await physics_frames(70)
	assert_true(is_instance_valid(planet))
	assert_lt(absf(planet.global_position.y - 0.35), 0.1, "on the floor, rolling")
	assert_gt(planet.global_position.x, 3.0, "it went on")
	assert_eq(guard.hits, 1, "it ran him over once")
	assert_almost_eq(guard.taken, RollingPlanet.DAMAGE, 0.01)
	await physics_frames(30)
	assert_eq(guard.hits, 1, "not twice")


func test_a_small_planet_is_jumped() -> void:
	var guard := _dummy(Vector3(3.0, 0.7, 0.0))
	var planet := _roll(Vector3(0.0, 0.25, 0.0), Vector3(5.0, 0.0, 0.0), 0.25, guard)
	for i in 70:
		guard.global_position = Vector3(3.0, 0.7, 0.0)
		await get_tree().physics_frame
	assert_eq(guard.hits, 0, "over Mercury")
	assert_true(is_instance_valid(planet))


func test_it_bounces_off_a_wall_and_breaks_when_shot() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 3.0, 8.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	wall.global_position = Vector3(4.0, 1.5, 0.0)
	var planet := _roll(Vector3(0.0, 0.4, 0.0), Vector3(6.0, 0.0, 0.0), 0.4, null)
	var turned := false
	for i in 90:
		await get_tree().physics_frame
		if planet.linear_velocity.x < -0.5:
			turned = true
			break
	assert_true(turned, "back off the wall")
	var broke := watch(planet.shattered)
	var debris_before := Fx.find_children("*", "RigidBody3D", false, false).size()
	var shot := DamageInfo.make(RollingPlanet.BREAK_DAMAGE * 0.6, DamageInfo.Kind.BALLISTIC)
	shot.position = planet.global_position
	planet.take_damage(shot)
	assert_eq(broke.size(), 0, "one bullet only dents it")
	planet.take_damage(shot)
	assert_eq(broke.size(), 1, "two break it")
	await physics_frames(2)
	assert_false(is_instance_valid(planet))
	var debris := Fx.find_children("*", "RigidBody3D", false, false)
	assert_gt(debris.size(), debris_before, "brass pieces")
	for body: RigidBody3D in debris:
		assert_eq(body.collision_layer, Layers.DEBRIS)


func test_a_flare_lands_on_its_mark_and_burns_who_stays_there() -> void:
	var near := _dummy(Vector3(6.6, 0.0, 0.5))
	var info := DamageInfo.make(SolarFlare.DAMAGE, DamageInfo.Kind.FIRE)
	var flare := SolarFlare.launch(Vector3(0.0, 5.0, 0.0), Vector3(6.0, 0.0, 0.0), 1.4, info, near)
	world.add_child(flare)
	await physics_frames(3)
	assert_not_null(flare.mark)
	assert_true(is_instance_valid(flare.mark) and flare.mark.is_inside_tree(), "marked from the moment it leaves")
	assert_lt(flare.mark.global_position.distance_to(Vector3(6.0, 0.0, 0.0)), 0.01)
	var landed := [Vector3.INF]
	flare.finished.connect(func(_r: Projectile.End) -> void: landed[0] = flare.global_position)
	for i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(flare):
			break
	assert_false(is_instance_valid(flare), "it came down")
	var down: Vector3 = landed[0]
	assert_lt(Vector2(down.x - 6.0, down.z).length(), 0.5, "on its mark: %s" % down)
	assert_eq(near.hits, 1)
	assert_almost_eq(near.taken, SolarFlare.DAMAGE, 0.01)


func test_a_flare_spares_who_stepped_out_and_none_shot_down_burns() -> void:
	var away := _dummy(Vector3(9.0, 0.0, 0.0))
	var info := DamageInfo.make(SolarFlare.DAMAGE, DamageInfo.Kind.FIRE)
	var flare := SolarFlare.launch(Vector3(0.0, 5.0, 0.0), Vector3(6.0, 0.0, 0.0), 1.4, info, away)
	world.add_child(flare)
	for i in 120:
		await get_tree().physics_frame
	assert_eq(away.hits, 0, "three metres off the mark")
	var under := _dummy(Vector3(6.0, 0.0, 0.0))
	var shot_down := SolarFlare.launch(Vector3(0.0, 5.0, 0.0), Vector3(6.0, 0.0, 0.0), 1.4, info, under)
	world.add_child(shot_down)
	await physics_frames(30)
	var bullet := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC)
	bullet.direction = Vector3.FORWARD
	shot_down.take_damage(bullet)
	for i in 100:
		await get_tree().physics_frame
	assert_eq(under.hits, 0, "burst in the air")
