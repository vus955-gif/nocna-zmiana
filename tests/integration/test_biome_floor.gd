extends TestCase
## The biome mechanics on the built Floor I (plan 2026-10-21-mechaniki-
## biomow): every wing's devices stand where their data puts them, against
## the real walls, and the game installs them with the floor.

var level: MuseumFloorLevel
var player: Player
var biomes: BiomeMechanics
var museum: Museum


func after_each() -> void:
	if is_instance_valid(level):
		level.free()
	if is_instance_valid(museum):
		museum.free()


func _build() -> void:
	level = MuseumFloorLevel.new()
	add_child(level)
	level.build()
	await physics_frames(3)
	player = Player.new()
	player.position = Vector3(0, 0.05, 20)
	add_child(player)
	biomes = BiomeMechanics.new()
	add_child(biomes)
	biomes.setup(level, func() -> Player: return player)
	await physics_frames(2)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return level.get_world_3d().direct_space_state.intersect_ray(query)


func test_the_tomb_traps_stand_on_their_walls() -> void:
	await _build()
	var traps := biomes.of_kind(TombTrap)
	assert_eq(traps.size(), TombTrap.PLACES.size(), "every trap of the plan")
	for device in traps:
		var trap := device as TombTrap
		var eye := trap.mouth + Vector3.UP * 1.05
		var behind := _ray(eye + trap.direction * 0.3, eye - trap.direction * 0.4)
		assert_false(behind.is_empty(), "%s: a wall right behind the mouth" % trap.name)
		var ahead := _ray(eye + trap.direction * 0.05, eye + trap.direction * 3.0)
		assert_true(ahead.is_empty(), "%s: the lane opens into the room" % trap.name)
		assert_eq(level.room_at(trap.plate_at + Vector3.UP * 0.3), trap.room, "%s: its plate in its room" % trap.name)


func test_the_bells_hang_in_their_halls() -> void:
	await _build()
	var bells := biomes.of_kind(TempleBell)
	assert_eq(bells.size(), TempleBell.PLACES.size())
	for device in bells:
		var bell := device as TempleBell
		assert_eq(level.room_at(bell.under() + Vector3.UP * 0.5), bell.room, "%s: over its room's floor" % bell.name)
		assert_not_null(bell.rope, "%s: its rope or log" % bell.name)
		var grip := bell.rope.global_position
		assert_true(_ray(grip + Vector3.UP * 0.4, grip + Vector3.DOWN * 0.4).is_empty(), "%s: nothing solid round its grip" % bell.name)


func test_the_fire_bowls_hold_their_lamps_and_the_totems_read_the_wing() -> void:
	await _build()
	var fires := biomes.of_kind(SacredFire)
	assert_eq(fires.size(), 5)
	for device in fires:
		var fire := device as SacredFire
		assert_not_null(fire.light, "%s: its lamp on the built level" % fire.name)
		assert_true(fire.room != &"americas_temple", "%s: not the Serpent's arena" % fire.name)
	var sights := biomes.of_kind(TotemSight)
	assert_eq(sights.size(), 1)
	if sights.size() == 1:
		var sight := sights[0] as TotemSight
		assert_true(sight.rooms.has(&"americas_totems"))
		assert_false(sight.rooms.has(&"americas_temple"), "the arena keeps its own rules")
		assert_gt(sight.fires.size(), fires.size(), "the torches burn too")
		(fires[0] as SacredFire).douse()
		assert_almost_eq((fires[0] as SacredFire).light.light_energy, 0.0, 0.001, "the doused bowl's lamp goes dark")
		assert_true((fires[0] as SacredFire).light.visible, "by its energy: its switch is the power's")


func test_the_helios_beam_crosses_the_nereid_hall_to_every_mark() -> void:
	await _build()
	var lamps := biomes.of_kind(HeliosLamp)
	assert_eq(lamps.size(), 1)
	var mirrors := biomes.of_kind(BronzeMirror)
	assert_eq(mirrors.size(), 2)
	if lamps.size() != 1:
		return
	var lamp := lamps[0] as HeliosLamp
	assert_true(_ray(lamp.origin(), lamp.aim).is_empty() or (_ray(lamp.origin(), lamp.aim)["position"] as Vector3).distance_to(lamp.aim) < 0.7, "the lamp sees its mirror")
	for device in mirrors:
		var mirror := device as BronzeMirror
		for mark in mirror.marks:
			var hit := _ray(mirror.center(), mark)
			var reach := mirror.center().distance_to(mark)
			var free := reach if hit.is_empty() else mirror.center().distance_to(hit["position"])
			assert_gt(free, reach * 0.85, "%s: the way to %s is clear (%.1f of %.1f m)" % [mirror.name, mark, free, reach])
	lamp.strike()
	await physics_frames(2)
	assert_gt(lamp.path.size(), 2.0, "the struck beam meets the east mirror and goes on")
	if lamp.path.size() > 2:
		assert_lt(lamp.path[1].distance_to((mirrors[0] as BronzeMirror).center()), 0.05)
		var landed := level.room_at(lamp.path[2] + (lamp.path[1] - lamp.path[2]).normalized() * 0.5)
		assert_true(landed in [&"greece_nereid", &"greece_bassae"], "it lands in the hall or through the Bassae door (%s)" % landed)


func test_the_regulator_keeps_the_wings_time_but_not_the_rotundas() -> void:
	await _build()
	var clocks := biomes.of_kind(Regulator)
	assert_eq(clocks.size(), 1)
	if clocks.size() != 1:
		return
	var regulator := clocks[0] as Regulator
	for room: StringName in [&"enlightenment_library", &"enlightenment_library_gallery", &"enlightenment_cabinet", &"enlightenment_clocks", &"enlightenment_portraits"]:
		assert_true(regulator.rooms.has(room), "%s keeps its time" % room)
	assert_false(regulator.rooms.has(&"enlightenment_planetarium"), "the Orrery's rotunda keeps its own")
	var eye := regulator.at + Vector3.UP * 1.5
	assert_false(_ray(eye + regulator.face * 0.5, eye - regulator.face * 0.3).is_empty(), "a wall right behind its case")
	assert_true(_ray(eye + regulator.face * 0.4, eye + regulator.face * 2.5).is_empty(), "room in front of it")


func test_the_nets_hang_under_their_ceilings_over_their_floors() -> void:
	await _build()
	var nets := biomes.of_kind(HuntingNet)
	assert_eq(nets.size(), HuntingNet.PLACES.size())
	for device in nets:
		var net := device as HuntingNet
		var down := _ray(net.at - Vector3.UP * 0.7, net.at - Vector3.UP * 20.0)
		assert_false(down.is_empty(), "%s: a floor under it" % net.name)
		if not down.is_empty():
			assert_almost_eq((down["position"] as Vector3).y, net.floor_y, 0.3, "%s: it falls to its own floor, nothing in between" % net.name)
		var up := _ray(net.at + Vector3.UP * 0.3, net.at + Vector3.UP * 20.0)
		assert_false(up.is_empty(), "%s: a ceiling over it" % net.name)
		if not up.is_empty():
			assert_almost_eq((up["position"] as Vector3).y, net.ceiling_y, 0.6, "%s: its ropes reach the ceiling" % net.name)


func test_the_steam_vents_sit_on_the_corridors_walls() -> void:
	await _build()
	var vents := biomes.of_kind(SteamVent)
	assert_eq(vents.size(), SteamVent.PLACES.size())
	for device in vents:
		var vent := device as SteamVent
		var eye := vent.at + Vector3.UP * 1.2
		assert_false(_ray(eye + vent.direction * 0.3, eye - vent.direction * 0.3).is_empty(), "%s: a wall behind it" % vent.name)
		assert_true(_ray(eye + vent.direction * 0.2, eye + vent.direction * (vent.across - 0.4)).is_empty(), "%s: the corridor open across" % vent.name)
		var down := _ray(vent.at + vent.direction * 1.5 + Vector3.UP, vent.at + vent.direction * 1.5 + Vector3.DOWN)
		assert_false(down.is_empty(), "%s: a floor under its plume" % vent.name)


func test_each_wings_rule_is_told_once_ever_where_it_works() -> void:
	level = MuseumFloorLevel.new()
	add_child(level)
	level.build()
	await physics_frames(3)
	player = Player.new()
	player.position = Vector3(0, 0.05, 20)
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
	biomes = BiomeMechanics.new()
	add_child(biomes)
	biomes.setup(level, func() -> Player: return player, null, hud)
	for wing: StringName in [&"egypt", &"asia", &"americas", &"greece", &"enlightenment", &"assyria", &"basement"]:
		assert_true(biomes.hint_rooms.values().has(wing), "%s's rule has its rooms" % wing)
		for locale in ["pl", "en"]:
			TranslationServer.set_locale(locale)
			var line := TranslationServer.translate(BiomeMechanics.hint_key(wing))
			assert_ne(line, BiomeMechanics.hint_key(wing), "%s: told in %s" % [wing, locale])
			assert_lt(line.length(), 120.0, "%s: one short line in %s" % [wing, locale])
	TranslationServer.set_locale("pl")
	assert_true(biomes.hint_rooms.has(&"enlightenment_library"), "the regulator's beat rules the whole wing")
	player.global_position = Vector3(-52.75, 0.05, -9.0)
	await physics_frames(roundi(BiomeMechanics.HINT_CHECK * 60.0) + 5)
	assert_true(GameState.has_flag(&"hint_biome_egypt"), "told in the tomb passage")
	assert_eq(hud._hint_label.text, tr("HINT_BIOME_EGYPT"))
	hud.show_hint("", 0.1)
	player.global_position = Vector3(0, 0.05, 20)
	await physics_frames(40)
	player.global_position = Vector3(-52.75, 0.05, -9.0)
	await physics_frames(40)
	assert_eq(hud._hint_label.text, "", "once ever")


func test_the_game_installs_them_with_the_floor() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	await physics_frames(2)
	var installed := museum.floor_game.biomes
	assert_not_null(installed, "the floor's game has its biome mechanics")
	if installed == null:
		return
	assert_eq(installed.level, museum.floor_level)
	assert_eq(installed.guard(), museum.player)
	assert_eq(installed.of_kind(TombTrap).size(), TombTrap.PLACES.size())
	assert_eq(installed.of_kind(TempleBell).size(), TempleBell.PLACES.size())
	assert_eq(installed.of_kind(SacredFire).size(), 5)
	assert_true(Events.dawn_broke.is_connected(installed.freeze), "dawn stops them")
