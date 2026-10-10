extends TestCase
## The harpoon gun (design 7.1): a harpoon on a line at 40 m/s with a
## slight drop; a light exhibit by a wall is pinned to it and breaks there,
## a medium one is pulled 3 m toward the guard and stunned, a heavy one only
## takes the 60 damage; one harpoon loaded, a 1.2 s reload.

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


func _give(levels: Dictionary = {}) -> WeaponState:
	holder.apply_upgrades(levels)
	return holder.give(load("res://src/weapons/data/harpoon.tres"))


func _harpoon() -> Harpoon:
	for child in get_children():
		if child is Harpoon and not child.is_queued_for_deletion():
			return child
	return null


func _exhibit(kind: StringName, z: float, max_health: float = -1.0) -> Enemy:
	var exhibit: Enemy
	match kind:
		&"wolf":
			exhibit = Wolf.new()
		&"knight":
			exhibit = Knight.new()
		_:
			exhibit = WaxFigure.new()
	if max_health > 0.0:
		exhibit.max_health = max_health
	exhibit.position = Vector3(0, 0, z)
	exhibit.target = user
	add_child(exhibit)
	return exhibit


## Lowers the gun to a wolf's height (its body is under the eye line).
func _aim_low() -> void:
	holder.position = Vector3(0, 0.65, 0)


func _alive(exhibit: Variant) -> bool:
	if not is_instance_valid(exhibit):
		return false
	var enemy := exhibit as Enemy
	return not enemy.is_queued_for_deletion() and enemy.brain.state != EnemyBrain.State.DESTROYED


func test_it_flies_40_m_s_with_a_slight_drop_on_a_line() -> void:
	_give()
	await physics_frames(2)
	assert_true(holder.try_fire())
	var harpoon := _harpoon()
	assert_not_null(harpoon, "a harpoon in the air")
	if harpoon == null:
		return
	var start := harpoon.global_position
	await physics_frames(15)
	var flown := harpoon.global_position - start
	assert_almost_eq(-flown.z, 10.0, 0.6, "a quarter second at 40 m/s")
	assert_lt(flown.y, -0.02, "it drops a little")
	assert_gt(flown.y, -0.4, "only a little")
	assert_true(harpoon.line_shown(), "the line runs out behind it")


func test_a_wolf_in_front_of_a_wall_is_pinned_to_it_and_breaks_there() -> void:
	Greybox.box(self, Vector3(0, 2, -8.25), Vector3(10, 4, 0.5), Color.GRAY)   # face at z = -8
	var wolf := _exhibit(&"wolf", -4.0)
	_aim_low()
	var deaths := watch(Events.enemy_destroyed)
	var where: Array[Vector3] = []
	Events.enemy_destroyed.connect(func(enemy: Node, _info: DamageInfo, _finisher: bool) -> void:
		where.append((enemy as Node3D).global_position), CONNECT_ONE_SHOT)
	_give()
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(8)
	var harpoon := _harpoon()
	assert_not_null(harpoon)
	if harpoon != null:
		assert_eq(harpoon.carried(), wolf, "carried along the shaft")
	await physics_frames(50)
	assert_false(_alive(wolf), "pinned exhibits break")
	assert_eq(deaths.size(), 1)
	if not where.is_empty():
		assert_lt(where[0].z, -7.0, "it broke against the wall")
	harpoon = _harpoon()
	assert_not_null(harpoon, "the harpoon stays in the wall")
	if harpoon != null:
		assert_eq(harpoon.phase, Harpoon.Phase.STUCK)
		assert_almost_eq(harpoon.global_position.z, -8.0 - Harpoon.BURY, 0.15)


func test_a_medium_exhibit_is_pulled_three_metres_and_stunned() -> void:
	var figure := _exhibit(&"wax", -9.0, 140.0)
	_give()
	await physics_frames(10)
	var before := figure.global_position
	holder.try_fire()
	await physics_frames(18)
	assert_true(_alive(figure))
	assert_almost_eq(figure.health.current, 80.0, 0.01, "60 damage")
	assert_eq(figure.brain.state, EnemyBrain.State.STUNNED, "stunned")
	await physics_frames(40)
	var moved := figure.global_position - before
	assert_almost_eq(moved.z, 3.0, 0.7, "pulled toward the guard")
	assert_almost_eq(moved.x, 0.0, 0.3)


func test_a_wolf_out_in_the_open_is_not_pinned() -> void:
	var wolf := _exhibit(&"wolf", -6.0)
	_aim_low()
	var where: Array[Vector3] = []
	Events.enemy_destroyed.connect(func(enemy: Node, _info: DamageInfo, _finisher: bool) -> void:
		where.append((enemy as Node3D).global_position), CONNECT_ONE_SHOT)
	_give()
	await physics_frames(10)
	holder.try_fire()
	await physics_frames(14)
	var harpoon := _harpoon()
	assert_true(harpoon == null or harpoon.carried() == null, "nothing to pin it to")
	assert_false(_alive(wolf), "60 damage is more than a wolf has")
	if not where.is_empty():
		assert_almost_eq(where[0].z, -6.0, 1.0, "it broke where it stood")


func test_a_knight_only_takes_the_damage() -> void:
	var knight := _exhibit(&"knight", -6.0)   # facing away: no shield in the way
	_give()
	await physics_frames(10)
	var before := knight.global_position
	holder.try_fire()
	await physics_frames(30)
	assert_almost_eq(knight.health.current, knight.health.max_health - 60.0, 0.01)
	assert_ne(knight.brain.state, EnemyBrain.State.STUNNED, "not stunned")
	assert_lt(knight.global_position.distance_to(before), 0.6, "not pulled")


func test_one_harpoon_loaded_and_a_reload_of_1_2_s() -> void:
	var state := _give()
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 12)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading())
	await physics_frames(roundi(1.2 * 60.0) - 3)
	assert_eq(state.magazine, 0, "not yet")
	await physics_frames(6)
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 11)


func test_the_reel_reloads_in_0_7_s() -> void:
	var state := _give({&"harpoon_reel": 1})
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(roundi(0.7 * 60.0) + 3)
	assert_eq(state.magazine, 1)


func test_barbs_pin_a_heavier_figure() -> void:
	Greybox.box(self, Vector3(0, 2, -8.25), Vector3(10, 4, 0.5), Color.GRAY)
	var figure := _exhibit(&"wax", -5.0, 85.0)
	_give({&"harpoon_barbs": 1})
	await physics_frames(10)
	holder.try_fire()
	await physics_frames(60)
	assert_false(_alive(figure), "pinned with barbs")


func test_a_harpoon_stuck_in_a_wall_stays_a_while() -> void:
	Greybox.box(self, Vector3(0, 2, -6.25), Vector3(10, 4, 0.5), Color.GRAY)
	_give()
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(20)
	var harpoon := _harpoon()
	assert_not_null(harpoon)
	if harpoon == null:
		return
	assert_eq(harpoon.phase, Harpoon.Phase.STUCK)
	assert_eq(harpoon.host(), null, "in the wall")
	await physics_frames(60)
	assert_false(harpoon.line_shown(), "the line is let go")
	assert_true(is_instance_valid(harpoon), "it stays")


func test_the_line_starts_where_the_gun_shows_on_screen() -> void:
	var camera := Camera3D.new()
	camera.fov = 75.0
	add_child(camera)
	camera.current = true
	await physics_frames(1)
	var moved := holder.on_screen_like_the_view(Vector3(0.1, -0.1, -0.5))
	var k := tan(deg_to_rad(37.5)) / tan(deg_to_rad(ArtLibrary.VIEWMODEL_FOV * 0.5))
	assert_almost_eq(moved.x, 0.1 * k, 0.001, "spread out like the wider world view")
	assert_almost_eq(moved.y, -0.1 * k, 0.001)
	assert_almost_eq(moved.z, -0.5, 0.001, "same depth")
