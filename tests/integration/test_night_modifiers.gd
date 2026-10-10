extends TestCase
## Night modifiers on the lobby and in the game: blackout, full moon, calm,
## and the night's card at the start.

var level: LobbyLevel
var museum: Museum


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()
	if is_instance_valid(level):
		level.free()


func _lobby() -> LobbyLevel:
	level = LobbyLevel.new()
	add_child(level)
	level.build()
	return level


func _lights(group: StringName) -> Array[Light3D]:
	var found: Array[Light3D] = []
	for node in level.lights.get_children():
		if node is Light3D and node.is_in_group(group):
			found.append(node)
	return found


## A greybox glow box or a kit lamp (its emissive surfaces) still glowing.
func _lit(fixture: Node) -> bool:
	return LevelKit.is_lit(fixture)


## A new game whose night [param night] draws [param modifier].
func _game_with(modifier: StringName, night: int = 3) -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 400:
		GameState.seed_base = base
		if NightDirector.plan(GameState.night_seed(), night, description).modifier == modifier:
			return
	fail("no seed draws " + modifier)


func test_blackout_darkens_every_main_lamp_but_not_the_emergency_or_haven_ones() -> void:
	_lobby()
	var env := NightModifiers.environment(level)
	var ambient := env.ambient_light_energy
	NightModifiers.apply(level, &"blackout", RunState)
	for light in _lights(LightSpec.MAIN):
		assert_false(light.visible, "%s is out" % light.get_meta(&"room"))
	for light in _lights(LightSpec.EMERGENCY) + _lights(LightSpec.HAVEN):
		assert_true(light.visible)
	var fixtures := get_tree().get_nodes_in_group(&"main_lights_fixtures")
	assert_gt(fixtures.size(), 20)
	for fixture in fixtures:
		assert_false(_lit(fixture), "%s looks dark too" % fixture.get_meta(&"kit"))
	for fixture in get_tree().get_nodes_in_group(&"emergency_lights_fixtures"):
		assert_true(_lit(fixture))
	assert_almost_eq(env.ambient_light_energy, ambient * NightModifiers.BLACKOUT_AMBIENT, 0.001)
	assert_eq(NightModifiers.moons(level)[0].visible, true, "the moon still shines through the skylights")


func test_lights_can_go_out_room_by_room_and_come_back() -> void:
	_lobby()
	var rooms: Array[StringName] = [&"hall", &"balcony"]
	NightModifiers.set_lights(level, LightSpec.MAIN, false, rooms)
	for light in _lights(LightSpec.MAIN):
		var room: StringName = light.get_meta(&"room")
		assert_eq(light.visible, not rooms.has(room), "%s lamp" % room)
	NightModifiers.set_lights(level, LightSpec.MAIN, true, rooms)
	for fixture in get_tree().get_nodes_in_group(&"main_lights_fixtures"):
		assert_true(_lit(fixture))


func test_full_moon_brightens_the_moon_and_the_dust_and_hardens_the_exhibits() -> void:
	_lobby()
	var moon := NightModifiers.moons(level)[0]
	var energy := moon.light_energy
	NightModifiers.apply(level, &"full_moon", RunState)
	assert_almost_eq(moon.light_energy, energy * NightModifiers.MOON_ENERGY, 0.001)
	assert_gt(moon.light_color.b, moon.light_color.r, "bluer")
	assert_almost_eq(RunState.dust_multiplier(), NightModifiers.FULL_MOON_DUST, 0.001)
	var knight := Knight.new()
	var base_health := knight.max_health
	var base_damage := knight.attack_damage
	NightModifiers.tune(knight, &"full_moon")
	add_child(knight)
	assert_almost_eq(knight.health.max_health, base_health * 1.25, 0.001, "set before it entered the tree")
	assert_almost_eq(knight.attack_damage, base_damage * 1.25, 0.001)
	knight.free()


func test_calm_and_none_change_nothing_here() -> void:
	_lobby()
	for modifier in [&"none", &"calm"]:
		NightModifiers.apply(level, modifier, RunState)
		for light in _lights(LightSpec.MAIN):
			assert_true(light.visible)
		assert_almost_eq(RunState.dust_multiplier(), 1.0, 0.001)
		var wax := WaxFigure.new()
		var health := wax.max_health
		NightModifiers.tune(wax, modifier)
		assert_eq(wax.max_health, health)
		wax.free()


func test_a_blackout_night_in_the_game_shows_its_card() -> void:
	_game_with(&"blackout")
	var started := watch(Events.night_started)
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	assert_eq(museum.night.modifier, &"blackout")
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0], [3, &"blackout", null, null])
	var card := museum.hud.card_text()
	assert_true(card.begins_with((tr("HUD_NIGHT") % 3).to_upper()), card)
	assert_true(card.contains(tr("NIGHT_MOD_BLACKOUT").to_upper()), card)
	for node in museum.lobby.lights.get_children():
		if node is Light3D and node.is_in_group(LightSpec.MAIN):
			assert_false((node as Light3D).visible)
	await get_tree().create_timer(Hud.CARD_TIME + 0.2).timeout
	assert_eq(museum.hud.card_text(), "", "the card fades away")


func test_full_moon_exhibits_are_tougher_in_the_game() -> void:
	_game_with(&"full_moon")
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	for node in museum.enemies_root.get_children():
		var exhibit := node as Enemy
		var base := (exhibit.get_script() as GDScript).new() as Enemy
		assert_almost_eq(exhibit.health.max_health, base.max_health * 1.25, 0.01)
		base.free()
	assert_almost_eq(RunState.dust_multiplier(), 1.5, 0.001)
	assert_true(museum.hud.card_text().contains(tr("NIGHT_MOD_FULL_MOON").to_upper()))


func test_modifier_names_are_translated() -> void:
	for modifier in NightModifiers.MODIFIERS:
		var key := NightModifiers.title_key(modifier)
		if key == "":
			continue
		assert_ne(tr(key), key)
		assert_ne(tr(NightModifiers.detail_key(modifier)), NightModifiers.detail_key(modifier))
