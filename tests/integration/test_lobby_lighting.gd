extends TestCase

var level: LobbyLevel


func before_each() -> void:
	level = LobbyLevel.new()
	add_child(level)
	level.build()


func _lights(group: StringName) -> Array[Light3D]:
	var found: Array[Light3D] = []
	for node in get_tree().get_nodes_in_group(group):
		if node is Light3D:
			found.append(node)
	return found


func test_environment_has_volumetric_fog_and_a_dim_ambient() -> void:
	var worlds := level.lights.get_children().filter(func(n: Node) -> bool: return n is WorldEnvironment)
	assert_eq(worlds.size(), 1)
	if worlds.size() == 1:
		var env: Environment = worlds[0].environment
		assert_true(env.volumetric_fog_enabled)
		# the light recipe keeps the fog in the rooms' own volumes (dust where
		# the air stands, clear sky over the lanterns)
		var volumes := level.lights.get_children().filter(func(n: Node) -> bool: return n is FogVolume)
		assert_true(env.volumetric_fog_density > 0.0 or volumes.size() > 5, "fog in the air or in every room")
		assert_lt(env.ambient_light_energy, 0.6, "dim")


func test_moon_shines_down_with_shadows_through_the_skylights() -> void:
	var moons := get_tree().get_nodes_in_group(&"moon")
	assert_eq(moons.size(), 1)
	if moons.size() == 1:
		var moon: DirectionalLight3D = moons[0]
		assert_true(moon.shadow_enabled)
		assert_lt((moon.global_transform.basis * Vector3.FORWARD).y, -0.7, "steep enough to reach the hall floor")
		assert_gt(moon.light_volumetric_fog_energy, 1.0, "visible shafts")


func test_groups_cover_the_lobby_and_do_not_overlap() -> void:
	var main := _lights(LightSpec.MAIN)
	var emergency := _lights(LightSpec.EMERGENCY)
	var haven := _lights(LightSpec.HAVEN)
	assert_gt(main.size(), 30)
	assert_gt(emergency.size(), 15)
	assert_gt(haven.size(), 2)
	for light in emergency:
		assert_false(main.has(light))
		assert_lt(light.light_color.g, 0.3, "emergency lamps are red")
	var main_rooms := {}
	for light in main:
		main_rooms[light.get_meta(&"room")] = true
	for room in [&"hall", &"balcony", &"gallery", &"armory", &"diorama", &"corridor_w", &"corridor_e"]:
		assert_true(main_rooms.has(room), "main lights in %s" % room)
	for light in main:
		assert_false(level.layout.room(light.get_meta(&"room")).haven, "havens keep their light in a blackout")
	for light in haven:
		assert_true(level.layout.room(light.get_meta(&"room")).haven)


func test_every_lamp_hangs_inside_its_room() -> void:
	for light in _lights(LightSpec.MAIN) + _lights(LightSpec.HAVEN) + _lights(LightSpec.EMERGENCY):
		var room: StringName = light.get_meta(&"room")
		var inside := level.layout.room(room).contains(light.global_position)
		assert_true(inside, "%s lamp at %s" % [room, light.global_position])


func test_exit_signs_hang_clear_of_low_ceilings() -> void:
	for sign in get_tree().get_nodes_in_group(&"emergency_lights_fixtures"):
		if sign.get_meta(&"kit", &"") != &"exit_sign":
			continue
		var room := level.layout.room(sign.get_meta(&"kit_room"))
		var top := (sign as Node3D).global_position.y + 0.18
		assert_lt(top, room.ceiling_y, "sign in %s at %s" % [room.id, (sign as Node3D).global_position])


func test_secret_rooms_do_not_glow_through_their_walls() -> void:
	for light in _lights(LightSpec.MAIN):
		var room := level.layout.room(light.get_meta(&"room"))
		if not room.secret or room.id == &"vent":
			continue
		assert_true(light is SpotLight3D, "%s: a narrow cone" % room.id)
		var spot := light as SpotLight3D
		var floor_radius := (light.global_position.y - room.floor_y) * tan(deg_to_rad(spot.spot_angle))
		for part in room.parts:
			var at := Vector2(light.global_position.x, light.global_position.z)
			assert_true(part.grow(-floor_radius).has_point(at), "%s: the cone stays off the walls" % room.id)


func test_column_lamps_use_cheap_shadows_and_leaky_lamps_keep_out_of_the_fog() -> void:
	for light in _lights(LightSpec.MAIN):
		if light is OmniLight3D and light.shadow_enabled:
			assert_eq((light as OmniLight3D).omni_shadow_mode, OmniLight3D.SHADOW_DUAL_PARABOLOID)
	var sconces := 0
	for fixture in get_tree().get_nodes_in_group(&"main_lights_fixtures"):
		if fixture.get_meta(&"kit", &"") == &"sconce":
			sconces += 1
			assert_eq((fixture.get_meta(&"light") as Light3D).light_volumetric_fog_energy, 0.0, "a wall sconce reaches through its wall")
			assert_eq(fixture.get_meta(&"kit_size"), LevelKit.FIXTURE_SIZES[&"sconce"])
	assert_gt(sconces, 10)


func test_few_shadows_and_every_lamp_fades_with_distance() -> void:
	var shadowed := 0
	for node in level.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.shadow_enabled:
			shadowed += 1
		if light is OmniLight3D or light is SpotLight3D:
			assert_true(light.distance_fade_enabled, str(light.get_path()))
	assert_lt(shadowed, 11)
	assert_gt(shadowed, 4)


func test_doorways_get_exit_signs_on_both_faces() -> void:
	var signs := get_tree().get_nodes_in_group(&"emergency_lights_fixtures").filter(func(n: Node) -> bool: return n.get_meta(&"kit", &"") == &"exit_sign")
	var doorways := level.layout.openings.filter(func(o: OpeningSpec) -> bool: return o.exit_signs)
	assert_eq(signs.size(), doorways.size() * 2)
	assert_eq(doorways.size(), 9)
