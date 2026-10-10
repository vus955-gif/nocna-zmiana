extends TestCase
## The flare gun: arc, sticking, 12 s of light, burning (wax double), the
## 2.5 m blast, the guard's capped self-damage, one flare in the barrel.

## A solid exhibit stand-in: a body the flare can stick to, a hit zone the
## blast finds, and a record of every hit.
class BodyDummy extends CharacterBody3D:
	var hits: Array[DamageInfo] = []

	func _init() -> void:
		collision_layer = Layers.ENEMY
		collision_mask = 0
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 0.9
		add_child(collider)
		var zone := BoxShape3D.new()
		zone.size = Vector3(0.8, 1.6, 0.8)
		add_child(Hurtbox.make(self, zone, Vector3(0, 0.9, 0)))

	func take_damage(info: DamageInfo) -> void:
		hits.append(info)

	func total() -> float:
		var sum := 0.0
		for hit in hits:
			sum += hit.amount
		return sum


var user: Node3D
var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color.GRAY)
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _flare_data() -> WeaponData:
	return load("res://src/weapons/data/flare.tres")


func _dummy(at: Vector3) -> BodyDummy:
	var dummy := BodyDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


func _first(type: Variant) -> Node:
	for child in get_children() + user.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			return child
	return null


func test_flare_flies_28_m_s_on_a_light_arc() -> void:
	holder.give(_flare_data())
	await physics_frames(2)
	assert_true(holder.try_fire())
	var flare := _first(Flare) as Flare
	assert_not_null(flare, "a flare is in the air")
	if flare == null:
		return
	var start := flare.global_position
	await physics_frames(30)
	var flown := flare.global_position - start
	assert_almost_eq(-flown.z, 14.0, 0.8, "half a second at 28 m/s")
	assert_almost_eq(flown.y, -0.75, 0.2, "it drops on a light arc")


func test_sticks_to_a_wall_and_glows_12_s() -> void:
	Greybox.box(self, Vector3(0, 2, -8), Vector3(10, 4, 0.5), Color.GRAY)
	holder.give(_flare_data())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(30)
	var light := _first(FlareLight) as FlareLight
	assert_not_null(light, "stuck on the wall")
	if light == null:
		return
	assert_almost_eq(light.global_position.z, -7.75, 0.2, "at the wall")
	assert_eq(light.host, null)
	assert_false(light.burning(), "a wall does not burn")
	assert_gt(light.light.light_energy, 2.0, "bright")
	assert_false(light.light.shadow_enabled, "cheap: no shadows")
	await physics_frames(60 * 10)
	assert_true(is_instance_valid(light), "still lit after 10 s")
	await physics_frames(60 * 2 + 5)
	assert_false(is_instance_valid(light) and not light.is_queued_for_deletion(), "out after 12 s")


func test_sticks_to_an_exhibit_follows_it_and_burns_6_per_second_for_5_s() -> void:
	var dummy := _dummy(Vector3(0, 0, -6))
	holder.give(_flare_data())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(20)
	var light := _first(FlareLight) as FlareLight
	assert_not_null(light)
	if light == null:
		return
	assert_eq(light.host, dummy, "stuck on the exhibit")
	assert_eq(dummy.hits.size(), 1, "the blast hit it")
	assert_eq(dummy.hits[0].amount, 20.0)
	assert_eq(dummy.hits[0].kind, DamageInfo.Kind.FIRE)
	var offset := light.global_position - dummy.global_position
	dummy.position += Vector3(3, 0, 0)
	await physics_frames(2)
	assert_true((light.global_position - dummy.global_position).is_equal_approx(offset), "rides along")
	await physics_frames(60 * 6)
	assert_almost_eq(dummy.total() - 20.0, 30.0, 0.01, "6 per second for 5 s")
	assert_false(light.burning())
	assert_true(is_instance_valid(light), "the light outlasts the burning")


func test_wax_melts_twice_as_fast_in_fire_only() -> void:
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.WAX, DamageInfo.Kind.FIRE), 2.0)
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.WAX, DamageInfo.Kind.BALLISTIC), 1.0)
	assert_eq(ExhibitMaterial.fire_factor(ExhibitMaterial.Kind.MARBLE, DamageInfo.Kind.FIRE), 1.0)
	var figure := WaxFigure.new()
	figure.max_health = 500.0
	figure.position = Vector3(0, 0, -4)
	add_child(figure)
	await physics_frames(2)
	Blast.explode(self, figure.global_position + Vector3(0, 1, 0.5), 2.5, 20.0, 0.0, DamageInfo.Kind.FIRE, user)
	assert_almost_eq(figure.health.current, 460.0, 0.01, "20 fire = 40 on wax")


func test_blast_reaches_2_5_m_and_pushes_away() -> void:
	var near := _dummy(Vector3(2, 0, 0))
	var far := _dummy(Vector3(3.6, 0, 0))
	await physics_frames(2)
	var hit := Blast.explode(self, Vector3(0, 0.9, 0), 2.5, 20.0, 6.0, DamageInfo.Kind.FIRE, user)
	assert_true(hit.has(near))
	assert_false(hit.has(far))
	assert_eq(near.hits.size(), 1)
	assert_eq(far.hits.size(), 0)
	if near.hits.size() == 1:
		assert_eq(near.hits[0].amount, 20.0)
		assert_gt(near.hits[0].direction.x, 0.9, "pushed away from the blast")
		assert_eq(near.hits[0].knockback, 6.0)


func test_blast_does_not_go_through_walls() -> void:
	var hidden := _dummy(Vector3(2, 0, 0))
	Greybox.box(self, Vector3(1, 1, 0), Vector3(0.2, 3, 3), Color.GRAY)
	await physics_frames(2)
	Blast.explode(self, Vector3(0, 0.9, 0), 2.5, 20.0, 6.0, DamageInfo.Kind.FIRE, user)
	assert_eq(hidden.hits.size(), 0)


func test_own_blast_never_takes_the_guard_below_half() -> void:
	var guard := Player.new()
	add_child(guard)
	await physics_frames(2)
	var feet := guard.global_position + Vector3(0.3, 0.05, 0)
	Blast.explode(self, feet, 2.5, 20.0, 6.0, DamageInfo.Kind.FIRE, guard)
	assert_eq(guard.health.current, 80.0, "a shot at his feet hurts")
	for i in 3:
		Blast.explode(self, feet, 2.5, 20.0, 6.0, DamageInfo.Kind.FIRE, guard)
	assert_eq(guard.health.current, 50.0, "never below half")
	assert_true(guard.alive)
	var stranger := Blast.explode(self, feet, 2.5, 20.0, 0.0, DamageInfo.Kind.FIRE, null)
	assert_true(stranger.has(guard))
	assert_eq(guard.health.current, 30.0, "someone else's blast hurts in full")


func test_one_flare_in_the_barrel_then_a_1_4_s_reload() -> void:
	var state := holder.give(_flare_data())
	assert_eq(state.magazine, 1)
	assert_eq(state.data.max_reserve, 8)
	state.reserve = 3
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading(), "reloads by itself")
	assert_false(holder.try_fire())
	await physics_frames(80)
	assert_true(state.is_reloading(), "1.33 s: still loading")
	await physics_frames(6)
	assert_false(state.is_reloading())
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 2)


func test_at_most_eight_flares_burn_at_once() -> void:
	var data := _flare_data()
	var lights: Array[FlareLight] = []
	for i in 10:
		lights.append(FlareLight.stick(self, Vector3(i, 0, -3), Vector3.UP, null, data, user))
	await physics_frames(2)
	var fading := lights.filter(func(f: FlareLight) -> bool: return f.time_left() <= FlareLight.FADE)
	assert_eq(fading.size(), 2, "the two oldest fade out early")
	assert_true(fading.has(lights[0]) and fading.has(lights[1]))


func test_flare_drops_to_the_floor_when_its_exhibit_breaks() -> void:
	var dummy := _dummy(Vector3(0, 0, -4))
	await physics_frames(2)
	var light := FlareLight.stick(self, Vector3(0, 1.4, -3.6), Vector3.BACK, dummy, _flare_data(), user)
	await physics_frames(2)
	dummy.queue_free()
	await physics_frames(60)
	assert_true(is_instance_valid(light))
	assert_almost_eq(light.global_position.y, 0.03, 0.05, "on the floor")
	assert_false(light.burning())


## Burn ticks fall straight down on the host, marked as damage over time
## (no hit marker): a knight's shield never stops them, never clanks.
func test_burning_gets_past_a_shield_without_markers_or_clanks() -> void:
	var dummy := _dummy(Vector3(0, 0, -4))
	await physics_frames(2)
	FlareLight.stick(self, Vector3(0, 1.4, -3.6), Vector3.BACK, dummy, _flare_data(), user)
	await physics_frames(40)
	assert_gt(dummy.hits.size(), 0)
	for tick in dummy.hits:
		assert_true(tick.periodic, "a tick of damage over time")
		assert_eq(tick.direction, Vector3.DOWN)
	var knight := Knight.new()
	knight.position = Vector3(4, 0, -4)
	add_child(knight)
	knight.face(Vector3(4, 0, 4))   # its shield toward the flare
	await physics_frames(2)
	var markers := watch(Events.hit_landed)
	var health := knight.health.current
	FlareLight.stick(self, knight.global_position + Vector3(0, 1.2, 0.45), Vector3.BACK, knight, _flare_data(), user)
	await physics_frames(60 * 6)
	assert_almost_eq(health - knight.health.current, 30.0, 0.01, "the whole burn gets past the shield")
	assert_eq(markers.size(), 0, "no hit markers, no clanks")


## The ninth flare dims the oldest one early, but a flare burning an
## exhibit burns on to its end in the dark.
func test_a_ninth_flare_dims_the_oldest_but_its_burn_goes_on() -> void:
	var dummy := _dummy(Vector3(0, 0, -4))
	await physics_frames(2)
	var data := _flare_data()
	var oldest := FlareLight.stick(self, Vector3(0, 1.4, -3.6), Vector3.BACK, dummy, data, user)
	await physics_frames(2)
	for i in FlareLight.MAX_LIT:
		FlareLight.stick(self, Vector3(i - 4.0, 0, -8), Vector3.UP, null, data, user)
	await physics_frames(2)
	assert_lt(oldest.time_left(), FlareLight.FADE + 0.01, "its light fades early")
	await physics_frames(60 * 6)
	assert_almost_eq(dummy.total(), 30.0, 0.01, "6 per second for the whole 5 s")
	assert_false(is_instance_valid(oldest), "then it goes out")


## A flare still flying when the guard is gone (a night left, a scene
## swap) lands without a shooter: no error, nobody credited.
func test_a_flare_outliving_its_shooter_lands_cleanly() -> void:
	var shooter := Node3D.new()
	add_child(shooter)
	var flare := Flare.launch(Vector3(0, 1.5, 0), Vector3(0, 0, -28), _flare_data(), shooter)
	add_child(flare)
	shooter.free()
	await physics_frames(90)
	var light := _first(FlareLight) as FlareLight
	assert_not_null(light, "it stuck to the floor or a wall")
	if light != null:
		assert_eq(light.source, null)
