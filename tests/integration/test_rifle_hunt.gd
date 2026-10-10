extends TestCase
## The expedition rifle (design 7.1): 85 damage, weak point x3, the round
## goes on through up to three targets (each once), a wall stops it, a
## one-second bolt cycle, five rounds a clip.

## A target with its own hit zones that records every hit.
class Dummy extends TargetDummy:
	func add_zone(size: Vector3, offset: Vector3, weak: bool = false) -> Hurtbox:
		var shape := BoxShape3D.new()
		shape.size = size
		var zone := Hurtbox.make(self, shape, offset, weak)
		add_child(zone)
		return zone

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
	holder.give(load("res://src/weapons/data/rifle_hunt.tres"))


func _dummy(z: float, weak: bool = false) -> Dummy:
	var dummy := Dummy.new()
	dummy.position = Vector3(0, 0, z)
	add_child(dummy)
	dummy.add_zone(Vector3(0.6, 1.8, 0.4), Vector3(0, 0.9, 0), weak)
	return dummy


func test_one_round_deals_85() -> void:
	var dummy := _dummy(-5.0)
	await physics_frames(2)
	assert_true(holder.try_fire())
	assert_eq(dummy.hits.size(), 1)
	assert_eq(dummy.total(), 85.0)
	assert_eq(dummy.hits[0].weapon, &"rifle_hunt")


func test_a_weak_point_takes_three_times() -> void:
	var dummy := _dummy(-5.0, true)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.total(), 255.0)
	assert_true(dummy.hits[0].weak_point)


func test_the_round_goes_through_three_targets_not_four() -> void:
	var row: Array[Dummy] = []
	for z in [-3.0, -5.0, -7.0, -9.0]:
		row.append(_dummy(z))
	await physics_frames(2)
	holder.try_fire()
	for i in 3:
		assert_eq(row[i].total(), 85.0, "target %d, full damage" % (i + 1))
	assert_eq(row[3].hits.size(), 0, "the fourth is safe")


func test_a_wall_stops_the_round() -> void:
	var front := _dummy(-3.0)
	Greybox.box(self, Vector3(0, 2, -4.5), Vector3(4, 4, 0.5), Color.GRAY)
	var behind := _dummy(-6.0)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(front.hits.size(), 1)
	assert_eq(behind.hits.size(), 0, "behind the wall")


func test_two_zones_of_one_target_are_one_hit() -> void:
	var dummy := _dummy(-4.0)
	dummy.add_zone(Vector3(0.3, 0.3, 0.3), Vector3(0, 1.5, 0.5), true)   # a head in front of the chest
	var next := _dummy(-7.0)
	await physics_frames(2)
	holder.try_fire()
	assert_eq(dummy.hits.size(), 1, "one hit for one target")
	assert_true(dummy.hits[0].weak_point, "the first zone the round meets decides")
	assert_eq(next.hits.size(), 1, "and it goes on to the next one")


func test_the_bolt_cycles_in_one_second() -> void:
	await physics_frames(2)
	assert_true(holder.try_fire())
	await physics_frames(56)
	assert_false(holder.try_fire(), "still working the bolt")
	await physics_frames(5)
	assert_true(holder.try_fire(), "ready after a second")


func test_five_rounds_then_a_clip() -> void:
	var state := holder.current_state()
	assert_eq(state.magazine, 5)
	assert_eq(state.reserve, 25)
	await physics_frames(2)
	for i in 5:
		assert_true(holder.try_fire(), "round %d" % (i + 1))
		await physics_frames(61)
	assert_true(state.is_reloading(), "the empty rifle reloads by itself")
	await physics_frames(roundi(2.2 * 60.0) - 61 + 3)
	assert_eq(state.magazine, 5)
	assert_eq(state.reserve, 20)
	assert_eq(state.data.max_reserve, 40)
