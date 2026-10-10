extends TestCase

var user: Node3D
var holder: WeaponHolder
var dummy: TargetDummy


func before_each() -> void:
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.0, 0)
	user.add_child(holder)
	dummy = TargetDummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	var body := BoxShape3D.new()
	body.size = Vector3(0.8, 1.2, 0.8)
	dummy.add_child(Hurtbox.make(dummy, body, Vector3(0, 0.9, 0)))
	var head := SphereShape3D.new()
	head.radius = 0.25
	dummy.add_child(Hurtbox.make(dummy, head, Vector3(0, 1.8, 0), true))


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


func test_pistol_shot_hits_the_body_for_base_damage() -> void:
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 20.0)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BALLISTIC)
		assert_eq(dummy.hits[0].source, user)
		assert_false(dummy.hits[0].weak_point)


func test_pistol_headshot_doubles_damage() -> void:
	holder.position = Vector3(0, 1.8, 0)
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 40.0)
		assert_true(dummy.hits[0].weak_point)


func test_shotgun_pellets_merge_into_one_hit() -> void:
	dummy.position = Vector3(0, 0, -2.5)
	holder.give(_weapon(&"shotgun"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 90.0)
		assert_almost_eq(dummy.hits[0].knockback, 12.0)


func test_taser_hit_is_electric_and_stuns() -> void:
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.ELECTRIC)
		assert_eq(dummy.hits[0].stun_time, 3.0)


func test_taser_does_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -12)
	holder.give(_weapon(&"taser"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 0)


func test_fists_hit_close_and_can_finish() -> void:
	dummy.position = Vector3(0, 0, -1.3)
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_true(dummy.hits[0].can_finish)
		assert_eq(dummy.hits[0].kind, DamageInfo.Kind.BLUNT)


func test_fists_do_not_hit_through_walls() -> void:
	dummy.position = Vector3(0, 0, -1.3)
	Greybox.box(self, Vector3(0, 1.0, -0.6), Vector3(4, 3, 0.1), Color.GRAY)
	await physics_frames(2)
	assert_true(holder.try_punch(), "the punch is thrown")
	assert_eq(dummy.hits.size(), 0, "the wall takes it")


func test_point_blank_shot_from_inside_the_target_hits() -> void:
	dummy.position = Vector3(0, 0, -0.2)   # the eye is inside the body hurtbox
	holder.give(_weapon(&"pistol"))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		var hit := dummy.hits[0]
		assert_lt(hit.position.z, -0.3, "the hit shows in front of the gun, not at the eye")
		assert_true(hit.normal.is_equal_approx(Vector3(0, 0, 1)), "facing the guard: %s" % hit.normal)
	for child in Fx.get_children():
		assert_false(child is MeshInstance3D and not child.is_queued_for_deletion(), "no trail back to the eye")


func test_fists_do_not_reach_far() -> void:
	dummy.position = Vector3(0, 0, -4)
	await physics_frames(2)
	holder.try_punch()
	assert_eq(dummy.hits.size(), 0)


func test_emptying_the_magazine_starts_a_reload() -> void:
	var data: WeaponData = _weapon(&"pistol").duplicate()
	data.cooldown = 0.0
	var state := holder.give(data)
	await physics_frames(2)
	for i in 12:
		holder.try_fire()
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading())
	assert_false(holder.try_fire())
	state.tick(1.2)
	assert_eq(state.magazine, 12)
	assert_eq(state.reserve, 24)


func test_switching_weapons_cancels_reload() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	holder.give(_weapon(&"shotgun"))
	pistol.magazine = 5
	assert_true(holder.try_reload())
	holder.select_id(&"shotgun")
	assert_false(pistol.is_reloading())
	assert_eq(holder.current_state().data.id, &"shotgun")


func test_slot_order_is_taser_pistol_shotgun() -> void:
	holder.give(_weapon(&"shotgun"))
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	var ids := []
	for state in holder.owned:
		ids.append(state.data.id)
	assert_eq(ids, [&"taser", &"pistol", &"shotgun"])
	assert_eq(holder.current_state().data.id, &"shotgun", "first weapon stays selected")


func test_ammo_pickup_goes_to_the_matching_weapon() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	assert_eq(holder.add_ammo(&"bullets", 10), 10)
	assert_eq(pistol.reserve, 46)
	assert_eq(holder.add_ammo(&"shells", 5), 0, "no shotgun yet")


func test_cycle_wraps_around() -> void:
	holder.give(_weapon(&"taser"))
	holder.give(_weapon(&"pistol"))
	holder.cycle(-1)
	assert_eq(holder.current_state().data.id, &"pistol")
	holder.cycle(1)
	assert_eq(holder.current_state().data.id, &"taser")


func test_disabled_holder_does_not_attack() -> void:
	holder.give(_weapon(&"pistol"))
	holder.enabled = false
	await physics_frames(2)
	assert_false(holder.try_fire())
	assert_false(holder.try_punch())
	assert_eq(dummy.hits.size(), 0)
