extends TestCase
## Hanging lamps of the reactive layer (plan docs/superpowers/plans/
## 2026-10-21-srodowisko-walka.md): a hit swings a pendant and its light,
## it settles and sleeps again; enough brings it down after a creak of at
## least the game's telegraph, with a mark on the floor, onto whatever
## stands under it; a bulb bursts at once; a paper lantern flutters down;
## a lamp shot down stays dark - for every switch of its circuit, for the
## exhibits' light model and for a resumed night.

var bed: EnvTestbed


func before_each() -> void:
	bed = EnvTestbed.new()
	add_child(bed)
	bed.setup()


func after_each() -> void:
	if is_instance_valid(bed):
		bed.free()


func _lamps() -> Array[EnvLamp]:
	var out: Array[EnvLamp] = []
	for each in bed.env.props:
		if each is EnvLamp:
			out.append(each)
	return out


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func test_every_hanging_lamp_gets_a_prop_and_wall_lamps_do_not() -> void:
	bed.lamp(&"ceiling_lamp", Vector3(0.0, 6.0, -6.0))
	bed.lamp(&"bulb", Vector3(4.0, 3.0, -6.0))
	bed.lamp(&"sconce", Vector3(-4.0, 2.5, -14.6))
	bed.lamp(&"emergency_lamp", Vector3(-6.0, 2.5, -14.6))
	bed.piece(&"lantern", Vector3(8.0, 5.0, -6.0), Vector3(0.6, 0.9, 0.6), 0.0, false)
	bed.lamp(&"", Vector3(8.0, 5.4, -6.0))
	bed.install_env()
	var kinds := {}
	for lamp in _lamps():
		kinds[lamp.kind] = lamp
	assert_eq(_lamps().size(), 3)
	assert_true(kinds.has(&"ceiling_lamp") and kinds.has(&"bulb") and kinds.has(&"lantern"))
	if kinds.has(&"lantern"):
		assert_not_null((kinds[&"lantern"] as EnvLamp).light, "the lantern's own lamp found beside it")


func test_a_round_swings_a_pendant_and_its_light_then_it_settles_and_sleeps() -> void:
	var light := bed.lamp(&"ceiling_lamp", Vector3(0.0, 6.0, -6.0))
	var fixture := bed.fixture_of(light)
	var rest := fixture.global_transform
	var light_rest := light.global_position
	bed.install_env()
	var lamp := _lamps()[0]
	lamp.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 6.2, -6.0), Vector3.FORWARD))
	await _seconds(0.3)
	assert_false(lamp.is_down)
	assert_true(lamp.is_physics_processing(), "it swings")
	assert_false(fixture.global_transform.is_equal_approx(rest), "the fixture swings")
	assert_lt(fixture.global_position.z, rest.origin.z, "away from the shot (-Z)")
	assert_false(light.global_position.is_equal_approx(light_rest), "its light swings along")
	await _seconds(12.0)
	assert_true(fixture.global_transform.is_equal_approx(rest), "settled back")
	assert_false(lamp.is_physics_processing(), "asleep again")


func test_enough_brings_a_pendant_down_after_a_creak_onto_what_stands_under_it() -> void:
	var light := bed.lamp(&"ceiling_lamp", Vector3(0.0, 6.0, -6.0))
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	var aside := bed.dummy(Vector3(3.0, 0.0, -6.0))
	bed.install_env()
	var lamp := _lamps()[0]
	lamp.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 6.2, -6.0)))
	lamp.take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 6.2, -6.0)))
	assert_eq(lamp.phase, EnvProp.Phase.WARNING, "it creaks first")
	var marks := lamp.find_children("*", "GroundMark", true, false)
	assert_eq(marks.size(), 1, "its spot marked on the floor")
	await _seconds(EnvRules.MIN_WARNING - 0.05)
	assert_eq(under.hits.size(), 0, "nothing lands within the telegraph")
	assert_true(light.visible, "lit while it creaks")
	await _seconds(2.0)
	assert_true(lamp.is_down)
	assert_eq(under.hits.size(), 1, "it lands on the exhibit under it")
	if under.hits.size() == 1:
		assert_almost_eq(under.hits[0].amount, float(EnvLamp.CRUSH[&"ceiling_lamp"][0]), 0.01)
		assert_eq(under.hits[0].source, bed.player, "credited to the guard")
	assert_eq(aside.hits.size(), 0)
	assert_false(light.visible, "dark")
	assert_lt(bed.fixture_of(light).global_position.y, 0.5, "on the floor")


func test_the_guard_under_a_falling_pendant_takes_a_small_blow() -> void:
	bed.lamp(&"ceiling_lamp", Vector3(0.0, 6.0, -6.0))
	bed.install_env()
	bed.player.global_position = Vector3(0.2, 0.05, -6.0)
	await physics_frames(2)
	var lamp := _lamps()[0]
	var before := bed.player.health.current
	var info := bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 6.2, -6.0))
	lamp.take_damage(info)
	bed.player.global_position = Vector3(0.2, 0.05, -6.0)
	await _seconds(2.0)
	assert_almost_eq(before - bed.player.health.current, float(EnvLamp.CRUSH[&"ceiling_lamp"][1]), 0.01)


func test_a_bulb_bursts_at_once_and_hurts_nobody() -> void:
	var light := bed.lamp(&"bulb", Vector3(0.0, 3.0, -6.0))
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	bed.install_env()
	var lamp := _lamps()[0]
	lamp.take_damage(bed.hit(7.0, &"gatling", Vector3(0.0, 3.0, -6.0)))
	assert_true(lamp.is_down, "dark at the first round")
	assert_false(light.visible)
	assert_false(LevelKit.is_lit(bed.fixture_of(light)), "its glow too")
	await _seconds(1.0)
	assert_eq(under.hits.size(), 0)


func test_a_paper_lantern_flutters_down_without_a_blow() -> void:
	bed.piece(&"lantern", Vector3(0.0, 5.0, -6.0), Vector3(0.6, 0.9, 0.6), 0.0, false)
	var light := bed.lamp(&"", Vector3(0.0, 5.4, -6.0))
	var under := bed.dummy(Vector3(0.0, 0.0, -6.0))
	bed.install_env()
	var lamp := _lamps()[0]
	lamp.take_damage(bed.hit(85.0, &"rifle_hunt", Vector3(0.0, 5.4, -6.0)))
	assert_eq(lamp.phase, EnvProp.Phase.FALLING, "no creak: it cannot hurt")
	await _seconds(2.0)
	assert_true(lamp.is_down)
	assert_eq(under.hits.size(), 0)
	assert_false(light.visible)


func test_a_lamp_shot_down_stays_dark_for_its_circuit_the_exhibits_and_a_resumed_night() -> void:
	var light := bed.lamp(&"bulb", Vector3(0.0, 3.0, -6.0), 2.0, 8.0)
	var other := bed.lamp(&"bulb", Vector3(10.0, 3.0, -6.0), 2.0, 8.0)
	LevelPerception.configure_layout(bed.layout, {}, bed.lights)
	var under := Vector3(0.0, 1.0, -6.0)
	var lit := PerceptionWorld.light_at(under)
	assert_gt(lit, 0.5)
	bed.install_env()
	_lamps()[0].take_damage(bed.hit(20.0, &"pistol", Vector3(0.0, 3.0, -6.0)))
	assert_lt(PerceptionWorld.light_at(under), lit - 0.4, "the exhibits see the room darker")
	NightModifiers.set_lights(bed, LightSpec.MAIN, false)
	NightModifiers.set_lights(bed, LightSpec.MAIN, true)
	assert_false(light.visible, "the circuit switched back on: still dark")
	assert_true(other.visible)
	# the night resumed: dark again from the start
	bed.env.free()
	light.visible = true
	light.remove_meta(&"env_broken")
	bed.install_env()
	assert_false(light.visible)
	assert_true(_lamps()[0].is_down or _lamps()[1].is_down)


func test_a_harpoon_in_a_pendant_comes_down_with_it() -> void:
	var light := bed.lamp(&"ceiling_lamp", Vector3(0.0, 6.0, -6.0))
	var fixture := bed.fixture_of(light)
	bed.install_env()
	var lamp := _lamps()[0]
	var harpoon := Harpoon.launch(Vector3(0.0, 6.2, -3.0), Vector3(0.0, 0.0, -40.0), load("res://src/weapons/data/harpoon.tres"), bed.player)
	bed.add_child(harpoon)
	await _seconds(0.3)
	assert_eq(harpoon.phase, Harpoon.Phase.STUCK, "(control) it sticks in the lamp")
	var offset := harpoon.global_position - fixture.global_position
	assert_lt(offset.length(), 1.0, "(control) in the lamp")
	lamp.come_down()
	await _seconds(EnvRules.PROP_WARNING + 1.2)
	assert_true(lamp.is_down, "(control) it came down")
	assert_true(is_instance_valid(harpoon) and harpoon.phase == Harpoon.Phase.STUCK, "still stuck in it")
	if is_instance_valid(harpoon):
		assert_lt(harpoon.global_position.distance_to(fixture.global_position), 1.0, "it rides the lamp down to the floor")
		assert_lt(harpoon.global_position.y, 2.0, "not hanging in the air where the lamp was")
