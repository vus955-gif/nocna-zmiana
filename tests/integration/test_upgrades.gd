extends TestCase
## Upgrades on a live guard and on real shots.

var user: Node3D
var holder: WeaponHolder


func before_each() -> void:
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.0, 0)
	user.add_child(holder)


func _weapon(id: StringName) -> WeaponData:
	return load("res://src/weapons/data/%s.tres" % id)


## A dummy exhibit with a body (centre at 0.9 m) and a head (1.8 m).
func _dummy(at: Vector3) -> TargetDummy:
	var dummy := TargetDummy.new()
	dummy.position = at
	dummy.add_to_group(&"enemies")
	add_child(dummy)
	var body := BoxShape3D.new()
	body.size = Vector3(0.8, 1.2, 0.8)
	dummy.add_child(Hurtbox.make(dummy, body, Vector3(0, 0.9, 0)))
	var head := SphereShape3D.new()
	head.radius = 0.25
	dummy.add_child(Hurtbox.make(dummy, head, Vector3(0, 1.8, 0), true))
	return dummy


func test_guard_gets_health_stamina_battery_and_finisher_upgrades() -> void:
	var player := Player.new()
	add_child(player)
	player.health.apply_damage(10.0)
	player.apply_upgrades({&"health": 2, &"stamina": 1, &"battery": 1, &"fists": 1})
	assert_eq(player.health.max_health, 140.0)
	assert_eq(player.health.current, 130.0, "the extra 40 comes at once")
	assert_eq(player.stamina.maximum, 120.0)
	assert_almost_eq(player.stamina.regen_per_sec, 34.5)
	assert_eq(player.battery.capacity, 180.0)
	assert_almost_eq(player.finisher_heal, 18.75)
	assert_almost_eq(player.weapons.fists.data.damage, 21.0)


func test_taser_arc_jumps_to_a_second_enemy_within_5_m() -> void:
	holder.apply_upgrades({&"taser_chain": 1})
	holder.give(_weapon(&"taser"))
	var first := _dummy(Vector3(0, 0, -4))
	var near := _dummy(Vector3(3, 0, -4))
	var far := _dummy(Vector3(-5.5, 0, -4))
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(first.hits.size(), 1)
	assert_eq(near.hits.size(), 1, "the arc jumped")
	assert_eq(far.hits.size(), 0, "only one jump, to the nearest")
	if near.hits.size() == 1:
		assert_eq(near.hits[0].kind, DamageInfo.Kind.ELECTRIC)
		assert_gt(near.hits[0].stun_time, 0.0)
		assert_eq(near.hits[0].source, user)


func test_no_arc_jump_without_the_upgrade() -> void:
	holder.give(_weapon(&"taser"))
	_dummy(Vector3(0, 0, -4))
	var near := _dummy(Vector3(2, 0, -4))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(near.hits.size(), 0)


func test_arc_does_not_jump_through_walls() -> void:
	holder.apply_upgrades({&"taser_chain": 1})
	holder.give(_weapon(&"taser"))
	_dummy(Vector3(0, 0, -4))
	var hidden := _dummy(Vector3(3, 0, -4))
	Greybox.box(self, Vector3(1.6, 1.5, -4), Vector3(0.2, 3, 3), Color.GRAY)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(hidden.hits.size(), 0)


func test_point_blank_arc_jumps_from_the_target_not_from_the_muzzle() -> void:
	holder.apply_upgrades({&"taser_chain": 1})
	holder.give(_weapon(&"taser"))
	# a long display case the taser is jammed into: its middle is 1.9 m ahead
	var case := TargetDummy.new()
	case.add_to_group(&"enemies")
	add_child(case)
	var long := BoxShape3D.new()
	long.size = Vector3(0.8, 1.2, 4.0)
	case.add_child(Hurtbox.make(case, long, Vector3(0, 0.9, -1.9)))
	var behind := _dummy(Vector3(0, 0, 3.5))   # 3.6 m from the muzzle, 5.4 m from the case
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(case.hits.size(), 1, "the point-blank hit lands")
	assert_eq(behind.hits.size(), 0, "no arc to something behind the guard")


func test_arc_jumps_only_to_exhibits() -> void:
	holder.apply_upgrades({&"taser_chain": 1})
	holder.give(_weapon(&"taser"))
	_dummy(Vector3(0, 0, -4))
	var prop := TargetDummy.new()   # something with a hurtbox that is no exhibit
	prop.position = Vector3(2, 0, -4)
	add_child(prop)
	var body := BoxShape3D.new()
	body.size = Vector3(0.8, 1.2, 0.8)
	prop.add_child(Hurtbox.make(prop, body, Vector3(0, 0.9, 0)))
	await physics_frames(2)
	holder.try_fire()
	assert_eq(prop.hits.size(), 0)
	var shot := Projectile.new()
	assert_false(WeaponHolder.chain_target(shot), "a flying shard takes no arc")
	shot.free()
	assert_true(WeaponHolder.chain_target(_dummy(Vector3(0, 0, 20))), "exhibits do")


func test_slug_fires_one_heavy_ray() -> void:
	holder.apply_upgrades({&"shotgun_slug": 1})
	holder.position = Vector3(0, 1.8, 0)
	var shotgun := holder.give(_weapon(&"shotgun"))
	var dummy := _dummy(Vector3(0, 0, -6))
	shotgun.toggle_alt()
	shotgun.tick(2.0)
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_eq(dummy.hits[0].amount, 140.0, "70 x2 on the head")


func test_holding_reload_toggles_slugs_and_tapping_reloads() -> void:
	holder.apply_upgrades({&"shotgun_slug": 1})
	var shotgun := holder.give(_weapon(&"shotgun"))
	var step := 1.0 / 60.0
	shotgun.magazine = 1
	holder.reload_key(true, true, step)
	holder.reload_key(false, false, step)
	assert_true(shotgun.is_reloading(), "a tap reloads")
	assert_false(shotgun.use_alt)
	shotgun.tick(2.0)
	holder.reload_key(true, true, step)
	for i in 30:
		holder.reload_key(true, false, step)
	assert_true(shotgun.use_alt, "holding switched to slugs")
	assert_eq(shotgun.magazine, 0, "slugs are being loaded")
	holder.reload_key(false, false, step)
	shotgun.tick(2.0)
	assert_eq(shotgun.magazine, 2)


func test_pistol_magazine_upgrade_reloads_to_18() -> void:
	holder.apply_upgrades({&"pistol_mag": 1})
	var pistol := holder.give(_weapon(&"pistol"))
	assert_eq(pistol.magazine, 18, "a new pistol comes full")
	pistol.magazine = 3
	pistol.start_reload()
	pistol.tick(2.0)
	assert_eq(pistol.magazine, 18)


func test_upgrades_bought_mid_night_reach_owned_weapons() -> void:
	var pistol := holder.give(_weapon(&"pistol"))
	assert_eq(pistol.data.damage, 20.0)
	holder.apply_upgrades({&"pistol_damage": 1})
	assert_almost_eq(pistol.data.damage, 26.0)
	var dummy := _dummy(Vector3(0, 0, -6))
	await physics_frames(2)
	holder.try_fire()
	if dummy.hits.size() == 1:
		assert_almost_eq(dummy.hits[0].amount, 26.0)


func test_stronger_fists_hit_harder() -> void:
	holder.apply_upgrades({&"fists": 2})
	var dummy := _dummy(Vector3(0, 0, -1.2))
	await physics_frames(2)
	assert_true(holder.try_punch())
	assert_eq(dummy.hits.size(), 1)
	if dummy.hits.size() == 1:
		assert_almost_eq(dummy.hits[0].amount, 27.0)
