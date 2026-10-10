extends TestCase
## Projectile: flight, hits on the guard, bursts on walls, shooting it down.

var guard: Player


func before_each() -> void:
	GameInput.capture_allowed = false
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color.GRAY)


func after_each() -> void:
	GameInput.capture_allowed = true


func _launch(from: Vector3, velocity: Vector3, amount: float = 12.0) -> Projectile:
	var shot := Projectile.create(from, velocity, DamageInfo.make(amount, DamageInfo.Kind.BLUNT, null))
	add_child(shot)
	return shot


func _guard_at(at: Vector3) -> Player:
	guard = Player.new()
	guard.position = at
	add_child(guard)
	return guard


func _gone(node: Variant) -> bool:
	return not is_instance_valid(node) or node.is_queued_for_deletion()


func test_starts_where_it_was_created() -> void:
	var shot := _launch(Vector3(1, 2, 3), Vector3(0, 0, -9))
	assert_eq(shot.global_position, Vector3(1, 2, 3))
	assert_true(shot.global_transform.basis.z.dot(Vector3(0, 0, 1)) > 0.99, "faces its flight (-Z forward)")


func test_hits_the_guard_for_its_damage_and_disappears() -> void:
	_guard_at(Vector3(0, 0.05, -5))
	await physics_frames(2)
	var shot := _launch(Vector3(0, 1.1, 0), Vector3(0, 0, -9))
	var ends := watch(shot.finished)
	await physics_frames(60)
	assert_eq(guard.health.current, 88.0)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.HIT)
	assert_true(_gone(shot))


func test_bursts_on_a_wall_without_hurting_anyone_behind_it() -> void:
	Greybox.box(self, Vector3(0, 1.5, -3), Vector3(6, 3, 0.3), Color.GRAY)
	_guard_at(Vector3(0, 0.05, -6))
	await physics_frames(2)
	var shot := _launch(Vector3(0, 1.1, 0), Vector3(0, 0, -9))
	var ends := watch(shot.finished)
	await physics_frames(60)
	assert_eq(guard.health.current, 100.0)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.WALL)
	assert_true(_gone(shot))


func test_one_hit_from_a_weapon_shoots_it_down() -> void:
	var shot := _launch(Vector3(0, 1.5, -6), Vector3(0, 0, 0.5))
	var ends := watch(shot.finished)
	var landed := watch(Events.hit_landed)
	await physics_frames(2)
	var hit := Hitscan.ray(shot.get_world_3d().direct_space_state, Vector3(0, 1.5, 0), Vector3(0, 1.5, -20))
	var hurtbox: Hurtbox = hit.get("hurtbox")
	assert_not_null(hurtbox, "the ray hits the projectile's hurtbox")
	if hurtbox == null:
		return
	assert_eq(hurtbox.receiver, shot)
	var info := DamageInfo.make(20.0, DamageInfo.Kind.BALLISTIC, null)
	info.direction = Vector3(0, 0, -1)
	hurtbox.receiver.take_damage(info)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.SHOT)
	assert_eq(landed.size(), 1)
	if landed.size() == 1:
		assert_true(landed[0][2], "counts as a kill for the hit marker")
	assert_true(_gone(shot))


func test_hurtbox_is_quarter_metre() -> void:
	var shot := _launch(Vector3(0, 1.5, -6), Vector3.ZERO)
	var shape := (shot.hurtbox.get_child(0) as CollisionShape3D).shape as SphereShape3D
	assert_almost_eq(shape.radius, 0.25)


func test_expires_after_its_lifetime() -> void:
	var shot := Projectile.create(Vector3(0, 3, 0), Vector3(0, 9, 0), DamageInfo.make(12.0, DamageInfo.Kind.BLUNT))
	shot.lifetime = 0.25
	add_child(shot)
	var ends := watch(shot.finished)
	await physics_frames(30)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.EXPIRED)
	assert_true(_gone(shot))


func test_passes_out_of_its_shooter() -> void:
	Greybox.box(self, Vector3(0, 1.5, -5), Vector3(6, 3, 0.3), Color.GRAY)
	_guard_at(Vector3(0, 0.05, 0))
	await physics_frames(2)
	var shot := Projectile.create(Vector3(0, 1.1, 0), Vector3(0, 0, -9), DamageInfo.make(12.0, DamageInfo.Kind.BLUNT, guard))
	shot.exclude = [guard.get_rid()]
	add_child(shot)
	var ends := watch(shot.finished)
	await physics_frames(60)
	assert_eq(guard.health.current, 100.0)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.WALL)


func test_gravity_bends_its_path_into_the_floor() -> void:
	var shot := Projectile.create(Vector3(0, 1.5, 0), Vector3(0, 0, -6), DamageInfo.make(12.0, DamageInfo.Kind.BLUNT))
	shot.gravity = 15.0
	add_child(shot)
	var ends := watch(shot.finished)
	await physics_frames(40)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.WALL)


func test_a_dead_shooter_does_not_break_the_hit() -> void:
	_guard_at(Vector3(0, 0.05, -4))
	var shooter := Node3D.new()
	add_child(shooter)
	await physics_frames(2)
	var shot := Projectile.create(Vector3(0, 1.1, 0), Vector3(0, 0, -9), DamageInfo.make(12.0, DamageInfo.Kind.BLUNT, shooter))
	add_child(shot)
	shooter.free()
	await physics_frames(50)
	assert_eq(guard.health.current, 88.0)


func test_dozens_fly_at_once() -> void:
	var shots: Array[Projectile] = []
	for i in 40:
		shots.append(_launch(Vector3(i * 0.5 - 10.0, 2.0, 0), Vector3(0, 0, -9)))
	await physics_frames(10)
	for shot in shots:
		assert_false(_gone(shot))
		assert_lt(shot.global_position.z, -1.0)


func test_does_not_tunnel_when_a_step_ends_flush_against_a_wall() -> void:
	# 9 m/s = 0.15 m per step: after 31 steps the 0.2 m sphere touches the
	# wall face at z = -4.85 exactly, where a plain sweep would ignore it
	Greybox.box(self, Vector3(0, 1.5, -5), Vector3(6, 3, 0.3), Color.GRAY)
	await physics_frames(2)
	var shot := _launch(Vector3(0, 1.1, 0), Vector3(0, 0, -9))
	var ends := watch(shot.finished)
	await physics_frames(60)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0][0], Projectile.End.WALL)
