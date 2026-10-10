extends TestCase
## LayoutIllumination: how lit a point is from a layout's lamps (the
## perception's light model, design pietro-1-projekt 7.2).


## A 20 x 20 m hall with a warm lamp in the middle and a moonlit skylight in
## its north-west corner; east of it a side room with a lamp near the
## shared wall and a red emergency lamp.
func _layout() -> LevelLayout:
	var layout := LevelLayout.new()
	var hall := layout.add_room(&"hall", [Rect2(-10, -10, 20, 20)] as Array[Rect2], 0.0, 8.0, Color.GRAY)
	hall.skylights.append(Rect2(-10, -10, 3, 3))
	layout.add_room(&"side", [Rect2(10, -10, 10, 20)] as Array[Rect2], 0.0, 4.0, Color.GRAY)
	layout.add_light(LightSpec.MAIN, Vector3(0, 3, 0), Color(1, 0.8, 0.55), 1.5, 10.0, &"hall")
	layout.add_light(LightSpec.MAIN, Vector3(12, 2, -6), Color(1, 0.8, 0.55), 1.5, 8.0, &"side")
	layout.add_light(LightSpec.EMERGENCY, Vector3(15, 2, 5), Color(1, 0.12, 0.08), 1.0, 6.0, &"side")
	return layout


func test_lit_under_a_lamp_dark_far_from_it() -> void:
	var light := LayoutIllumination.from_layout(_layout())
	assert_gt(light.at(Vector3(0, 1, 0)), PerceptionRules.LIT_LEVEL)
	assert_lt(light.at(Vector3(-9, 1, 9)), PerceptionRules.DIM_LEVEL)
	assert_true(light.at(Vector3(0, 1, 0)) <= 1.0, "never above 1")


func test_light_fades_with_distance() -> void:
	var light := LayoutIllumination.from_layout(_layout())
	assert_gt(light.at(Vector3(2, 1, 0)), light.at(Vector3(6, 1, 0)))
	assert_gt(light.at(Vector3(6, 1, 0)), light.at(Vector3(9, 1, 0)))


func test_a_lamp_without_power_gives_nothing() -> void:
	var off := func(group: StringName, _room: StringName) -> bool: return group != LightSpec.MAIN
	assert_lt(LayoutIllumination.from_layout(_layout(), off).at(Vector3(0, 1, 0)), PerceptionRules.DIM_LEVEL)


func test_power_is_asked_per_room() -> void:
	var hall_off := func(_group: StringName, room: StringName) -> bool: return room != &"hall"
	var light := LayoutIllumination.from_layout(_layout(), hall_off)
	assert_lt(light.at(Vector3(0, 1, 0)), PerceptionRules.DIM_LEVEL)
	assert_gt(light.at(Vector3(12, 1, -6)), PerceptionRules.LIT_LEVEL, "the side room keeps its power")


func test_lamps_do_not_shine_through_walls() -> void:
	# 2.7 m from the side room's lamp, but in the hall behind the wall
	assert_lt(LayoutIllumination.from_layout(_layout()).at(Vector3(9.5, 1, -6)), PerceptionRules.DIM_LEVEL)


func test_a_red_emergency_lamp_is_half_dark() -> void:
	var level := LayoutIllumination.from_layout(_layout()).at(Vector3(15, 1, 6))
	assert_gt(level, PerceptionRules.DIM_LEVEL)
	assert_lt(level, PerceptionRules.LIT_LEVEL)


func test_moonlight_falls_under_a_skylight() -> void:
	var light := LayoutIllumination.from_layout(_layout())
	assert_almost_eq(light.at(Vector3(-8.5, 1, -8.5)), LayoutIllumination.MOON_LEVEL, 0.01)
	light.moon_level = 0.0
	assert_almost_eq(light.at(Vector3(-8.5, 1, -8.5)), 0.0, 0.01, "no moon")


func test_a_spot_lights_only_its_cone() -> void:
	var spot := LightSpec.make(LightSpec.MAIN, Vector3(0, 6, 0), Color.WHITE, 2.0, 12.0, &"hall")
	spot.kind = LightSpec.Kind.SPOT
	spot.direction = Vector3.DOWN
	spot.spot_angle = 20.0
	assert_gt(LayoutIllumination.contribution(spot, Vector3(0, 1, 0)), PerceptionRules.LIT_LEVEL)
	assert_eq(LayoutIllumination.contribution(spot, Vector3(5, 1, 0)), 0.0, "outside the cone")


func test_a_balcony_inside_the_hall_shares_its_light() -> void:
	var layout := _layout()
	var balcony := layout.add_room(&"balcony", [Rect2(-10, -10, 3, 20)] as Array[Rect2], 4.0, 8.0, Color.GRAY)
	balcony.carved = false
	layout.add_light(LightSpec.MAIN, Vector3(-6, 5.5, 0), Color(1, 0.8, 0.55), 1.0, 7.0, &"hall")
	var light := LayoutIllumination.from_layout(layout)
	assert_gt(light.at(Vector3(-8.5, 5, 0)), PerceptionRules.DIM_LEVEL, "the hall's lamp lights the balcony over it")


func test_outside_every_room_all_lamps_count() -> void:
	assert_gt(LayoutIllumination.from_layout(_layout()).at(Vector3(0, 9, 0)), PerceptionRules.DIM_LEVEL)


func test_power_read_from_the_lamps_in_the_scene() -> void:
	var root := Node3D.new()
	add_child(root)
	var lamp := OmniLight3D.new()
	lamp.add_to_group(LightSpec.MAIN)
	lamp.set_meta(&"room", &"hall")
	root.add_child(lamp)
	var powered := LayoutIllumination.powered_by_nodes(root)
	assert_true(powered.call(LightSpec.MAIN, &"hall"))
	lamp.visible = false
	assert_false(powered.call(LightSpec.MAIN, &"hall"), "a dark lamp has no power")
	assert_true(powered.call(LightSpec.MAIN, &"side"), "no lamp node for that room: powered")
	root.free()
