extends TestCase
## The fire-arrow chest (design 7.1): a volley of six small rockets 0.08 s
## apart in a 12 degree fan; each one 22 fire + a 1.8 m blast of 14 (wax
## burns double); one volley loaded, 2.2 s to reload, six in reserve; the
## guard's own blast follows the flare's rule.

## A target with a hit zone that records every hit.
class Dummy extends TargetDummy:
	func _init() -> void:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.8, 1.8, 0.6)
		add_child(Hurtbox.make(self, shape, Vector3(0, 0.9, 0)))

	func total() -> float:
		var sum := 0.0
		for hit in hits:
			sum += hit.amount
		return sum


var user: Node3D
var holder: WeaponHolder


func before_each() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color.GRAY)
	user = Node3D.new()
	add_child(user)
	holder = WeaponHolder.new()
	holder.user = user
	holder.position = Vector3(0, 1.5, 0)
	user.add_child(holder)


func _data() -> WeaponData:
	return load("res://src/weapons/data/hwacha.tres")


## The chest with a single rocket a shot (to count one rocket's hits).
func _single() -> WeaponData:
	var data := _data().duplicate() as WeaponData
	data.volley_count = 1
	return data


func _rockets() -> Array[HwachaRocket]:
	var out: Array[HwachaRocket] = []
	for child in get_children():
		if child is HwachaRocket and not child.is_queued_for_deletion():
			out.append(child)
	return out


func test_a_volley_is_six_rockets_in_under_half_a_second() -> void:
	holder.give(_data())
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(_rockets().size(), 1, "the first one leaves at once")
	await physics_frames(10)
	assert_between(_rockets().size(), 2, 5, "the rest follow")
	await physics_frames(20)
	assert_eq(_rockets().size(), 6)
	assert_eq(holder.volley_left(), 0)


func test_the_volley_fans_out_12_degrees() -> void:
	holder.give(_data())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(30)
	var angles: Array[float] = []
	for rocket in _rockets():
		angles.append(rad_to_deg(atan2(rocket.velocity.x, -rocket.velocity.z)))
	angles.sort()
	assert_eq(angles.size(), 6)
	if angles.size() == 6:
		assert_almost_eq(angles[5] - angles[0], 12.0, 1.0, "the whole fan")
		assert_almost_eq(angles[0] + angles[5], 0.0, 1.0, "centred on the crosshair")


func test_one_rocket_hits_for_22_and_bursts_for_14() -> void:
	var dummy := Dummy.new()
	dummy.position = Vector3(0, 0, -6)
	add_child(dummy)
	holder.give(_single())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(20)
	assert_eq(dummy.hits.size(), 2, "the arrow and its blast")
	assert_eq(dummy.total(), 36.0)
	for hit in dummy.hits:
		assert_eq(hit.kind, DamageInfo.Kind.FIRE)
		assert_true(hit.explosive)
		assert_eq(hit.weapon, &"hwacha")


func test_wax_burns_double_and_keeps_burning() -> void:
	var figure := WaxFigure.new()
	figure.max_health = 500.0
	figure.position = Vector3(0, 0, -6)
	add_child(figure)
	holder.give(_single())
	await physics_frames(5)
	holder.try_fire()
	await physics_frames(14)
	assert_almost_eq(figure.health.current, 500.0 - 72.0, 0.01, "(22 + 14) x 2")
	var burn := figure.find_child("Burn", false, false) as Burn
	assert_not_null(burn, "it caught fire")
	await physics_frames(130)
	assert_almost_eq(figure.health.current, 500.0 - 72.0 - 12.0, 0.01, "3 a second for 2 s, x 2")


func test_the_blast_reaches_1_8_m() -> void:
	Greybox.box(self, Vector3(0, 2, -8.25), Vector3(10, 4, 0.5), Color.GRAY)
	var near := Dummy.new()
	near.position = Vector3(1.2, 0, -7.6)
	add_child(near)
	var far := Dummy.new()
	far.position = Vector3(3.0, 0, -7.6)
	add_child(far)
	holder.give(_single())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(20)
	assert_eq(near.total(), 14.0, "in the blast")
	assert_eq(far.hits.size(), 0, "out of it")


func test_the_guards_own_blast_never_takes_him_below_half() -> void:
	var guard := Player.new()
	guard.position = Vector3(0, 0, 0)
	add_child(guard)
	Greybox.box(self, Vector3(0, 2, -1.5), Vector3(6, 4, 0.5), Color.GRAY)
	await physics_frames(3)
	guard.weapons.give(_data())
	guard.weapons.select_id(&"hwacha")
	assert_true(guard.weapons.try_fire())
	await physics_frames(40)
	assert_lt(guard.health.current, guard.health.max_health, "it hurts")
	assert_gt(guard.health.current, guard.health.max_health * 0.5 - 0.01, "but never below half")


func test_one_volley_loaded_a_2_2_s_reload_six_in_reserve() -> void:
	var state := holder.give(_data())
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 6)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(state.magazine, 0)
	assert_true(state.is_reloading())
	assert_false(holder.try_fire(), "one volley at a time")
	await physics_frames(roundi(2.2 * 60.0) + 3)
	assert_eq(state.magazine, 1)
	assert_eq(state.reserve, 5)


func test_the_bigger_volley_fires_nine() -> void:
	holder.apply_upgrades({&"hwacha_volley": 1})
	holder.give(_data())
	await physics_frames(2)
	holder.try_fire()
	await physics_frames(45)
	assert_eq(_rockets().size(), 9)


func assert_between(value: int, low: int, high: int, message: String = "") -> void:
	if value < low or value > high:
		fail("expected %d..%d, got %d. %s" % [low, high, value, message])
