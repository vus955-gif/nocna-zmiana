extends TestCase
## Hit feedback on exhibits (plan 2026-10-19-gun-feel): the flinch follows
## the shot, heavy hits stagger, kills crumble or blow apart by weight.

var target: TargetDummy


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	target = TargetDummy.new()
	target.position = Vector3(0, 0, 10)
	add_child(target)


func _wax(at: Vector3 = Vector3.ZERO) -> WaxFigure:
	var wax := WaxFigure.new()
	wax.position = at
	wax.target = target
	add_child(wax)
	return wax


## A hit travelling along [param direction] at chest height, [param impact] heavy.
func _hit(enemy: Enemy, direction: Vector3, impact: float, amount: float = 10.0) -> DamageInfo:
	var info := DamageInfo.make(amount, DamageInfo.Kind.BALLISTIC, target)
	info.direction = direction.normalized()
	info.position = enemy.global_position + Vector3.UP * 1.2
	info.impact = impact
	return info


## Where the head (1.6 m up) is now, moved by the flinch, relative to where it stands.
func _head_shift(enemy: Enemy) -> Vector3:
	var head := Vector3.UP * 1.6
	return enemy.global_basis * (enemy.reaction.transform * head - head)


## The biggest head shift along [param direction] over [param frames] physics frames.
func _lean_along(enemy: Enemy, direction: Vector3, frames: int = 20) -> float:
	var top := -INF
	for i in frames:
		await get_tree().physics_frame
		top = maxf(top, _head_shift(enemy).dot(direction))
	return top


func test_an_exhibit_leans_the_way_the_shot_went() -> void:
	var wax := _wax()
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 0.6))
	assert_gt(await _lean_along(wax, Vector3.FORWARD), 0.08, "its head goes with the shot")
	var other := _wax(Vector3(4, 0, 0))
	await physics_frames(3)
	other.take_damage(_hit(other, Vector3.RIGHT, 0.6))
	assert_gt(await _lean_along(other, Vector3.RIGHT), 0.08, "and with a shot from the side, to that side")


func test_the_lean_follows_the_shot_whichever_way_the_exhibit_faces() -> void:
	var wax := _wax()
	wax.face(Vector3(10, 0, 0))   # turned a quarter round
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.BACK, 0.6))
	assert_gt(await _lean_along(wax, Vector3.BACK), 0.08)


func test_a_heavy_hit_rocks_it_far_more_than_a_light_one() -> void:
	var light := _wax()
	var heavy := _wax(Vector3(4, 0, 0))
	await physics_frames(3)
	light.take_damage(_hit(light, Vector3.FORWARD, 0.3))
	heavy.take_damage(_hit(heavy, Vector3.FORWARD, 1.0))
	var light_lean := 0.0
	var heavy_lean := 0.0
	for i in 20:
		await get_tree().physics_frame
		light_lean = maxf(light_lean, _head_shift(light).dot(Vector3.FORWARD))
		heavy_lean = maxf(heavy_lean, _head_shift(heavy).dot(Vector3.FORWARD))
	assert_gt(light_lean, 0.02, "a pistol round still shows (%.3f m)" % light_lean)
	assert_gt(heavy_lean, light_lean * 2.5, "%.3f vs %.3f m" % [heavy_lean, light_lean])
	assert_lt(heavy_lean, 0.6, "a reel, not a fall")


func test_it_rocks_back_and_stands_still_again() -> void:
	var wax := _wax()
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	await physics_frames(10)
	assert_false(wax.reaction.resting())
	await physics_frames(150)
	assert_true(wax.reaction.resting())
	assert_true(wax.reaction.transform.is_equal_approx(Transform3D.IDENTITY), "upright again")


func test_a_steady_exhibit_barely_rocks() -> void:
	var wax := _wax()
	var knight := Knight.new()
	knight.position = Vector3(4, 0, 0)
	knight.target = target
	add_child(knight)
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	knight.take_damage(_hit(knight, Vector3.FORWARD, 1.0))   # into its back (it faces -Z): no shield
	var wax_lean := 0.0
	var knight_lean := 0.0
	for i in 20:
		await get_tree().physics_frame
		wax_lean = maxf(wax_lean, _head_shift(wax).dot(Vector3.FORWARD))
		knight_lean = maxf(knight_lean, _head_shift(knight).dot(Vector3.FORWARD))
	assert_gt(knight_lean, 0.0, "it does move")
	assert_lt(knight_lean, wax_lean * 0.6)


func test_heavy_hits_stagger_light_ones_do_not() -> void:
	var wax := _wax()
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 0.3))
	assert_false(wax.staggered(), "a pistol round")
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	assert_true(wax.staggered(), "a shotgun blast")
	await physics_frames(roundi(HitFeel.STAGGER_TIME * 60.0) + 2)
	assert_false(wax.staggered(), "only for a moment")


func test_a_knight_is_never_staggered() -> void:
	var knight := Knight.new()
	knight.target = target
	add_child(knight)
	await physics_frames(3)
	var info := _hit(knight, Vector3.FORWARD, 1.0)
	knight.take_damage(info)
	assert_false(info.blocked, "a hit in the back")
	assert_false(knight.staggered())


func test_no_stagger_lock_a_second_heavy_hit_soon_after_does_not_stagger_again() -> void:
	var wax := _wax()
	wax.max_health = 500.0
	wax.health.max_health = 500.0
	wax.health.reset()
	await physics_frames(3)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	await physics_frames(roundi(HitFeel.STAGGER_TIME * 60.0) + 2)
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	assert_false(wax.staggered(), "it has its feet again")
	await physics_frames(roundi(HitFeel.STAGGER_COOLDOWN * 60.0))
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	assert_true(wax.staggered(), "a while later it can be staggered again")


func test_a_stagger_stops_its_legs() -> void:
	var wax := _wax()
	wax.summoned = true
	wax.max_health = 500.0
	wax.health.max_health = 500.0
	wax.health.reset()
	wax.brain.wake()
	await physics_frames(120)   # it notices, then hunts
	var from := wax.global_position
	await physics_frames(18)
	var walking := Vector2(wax.global_position.x - from.x, wax.global_position.z - from.z).length()
	assert_gt(walking, 0.3, "it walks at the guard")
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0))
	from = wax.global_position
	await physics_frames(18)
	var reeling := Vector2(wax.global_position.x - from.x, wax.global_position.z - from.z).length()
	assert_lt(reeling, walking * 0.4, "%.2f m staggered vs %.2f m walking" % [reeling, walking])


func test_a_heavy_hit_knocks_chips_off_a_light_one_does_not() -> void:
	var wax := _wax()
	wax.max_health = 500.0
	wax.health.max_health = 500.0
	wax.health.reset()
	await physics_frames(3)
	var before := Fx.chunk_count()
	wax.take_damage(_hit(wax, Vector3.FORWARD, 0.3, 20.0))
	assert_eq(Fx.chunk_count(), before, "a pistol round: dust only")
	wax.take_damage(_hit(wax, Vector3.FORWARD, 1.0, 60.0))
	assert_gt(Fx.chunk_count(), before, "a heavy hit: wax lumps fly")


## Mean speed along [param direction] of the debris flying now.
func _debris_speed(direction: Vector3) -> float:
	var total := 0.0
	var count := 0
	for child in Fx.get_children():
		var body := child as RigidBody3D
		if body == null or body.is_queued_for_deletion():
			continue
		total += body.linear_velocity.dot(direction)
		count += 1
	return total / count if count > 0 else 0.0


func test_a_heavy_kill_blows_it_back_a_light_one_crumbles() -> void:
	var wax := _wax()
	await physics_frames(3)
	wax.health.current = 1.0
	wax.take_damage(_hit(wax, Vector3.FORWARD, 0.3, 20.0))
	var crumble := _debris_speed(Vector3.FORWARD)
	Fx.clear()
	await physics_frames(2)
	var other := _wax(Vector3(4, 0, 0))
	await physics_frames(3)
	other.health.current = 1.0
	other.take_damage(_hit(other, Vector3.FORWARD, 1.0, 20.0))
	var blown := _debris_speed(Vector3.FORWARD)
	assert_gt(blown, 2.0, "thrown back along the shot (%.2f m/s)" % blown)
	assert_gt(blown, crumble * 2.0, "%.2f vs %.2f m/s" % [blown, crumble])
