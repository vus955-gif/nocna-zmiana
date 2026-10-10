extends TestCase
## The soundtrack of a night in the real lobby (the Museum scene): the
## music and the ambience follow the night's goal, its clock and its
## modifier through the Events hooks; the lobby's rooms give the ambience
## its zones, its reverb and the guard's footsteps their floors.
## Music and Ambience are switched on by hand (automation is off in test
## runs); the scene swap they would see is stood in by set_scene_kind() /
## set_active() (NightMood covers what a real swap keeps).

const S := MusicDirector.State
const STAGE := NightObjective.Stage

var museum: Museum


func before_each() -> void:
	Music.reset()
	Music.enabled = true
	Ambience.reset()
	Ambience.enabled = true


func after_each() -> void:
	if is_instance_valid(museum):
		museum.free()
	Music.reset()
	Music.enabled = false
	Ambience.reset()
	Ambience.enabled = false


## The night without its exhibits (the music would hear them hunting).
func _museum() -> Museum:
	museum = (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	_clear_exhibits()
	Music.set_scene_kind(AudioContext.GAME)
	Ambience.set_active(true)
	return museum


func _clear_exhibits() -> void:
	for exhibit in museum.enemies_root.get_children():
		exhibit.free()
	Music._look_around()   # its last look would still count them


func _seconds(time: float) -> void:
	await physics_frames(roundi(time * Engine.physics_ticks_per_second))


func _targets() -> Dictionary:
	return Music.director.layer_targets()


## A new game on night [param night] with the crystal in the hall's case
## (a short flight) and, if given, [param modifier].
func _game(night: int, modifier: StringName = &"") -> void:
	var description := LobbyLayout.describe(LobbyLayout.create())
	GameState.new_game()
	GameState.night = night
	for base in 600:
		GameState.seed_base = base
		var plan := NightDirector.plan(GameState.night_seed(), night, description)
		if plan.crystal_case == &"crystal_case_hall" and (modifier == &"" or plan.modifier == modifier):
			return
	fail("no seed for night %d with %s" % [night, modifier])


func _floor_under(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := museum.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else at


func _cut_the_power() -> void:
	for wing: StringName in museum.objective.fuse_pickups.keys():
		(museum.objective.fuse_pickups[wing] as FusePickup).interact(museum.player)
	museum.objective.fuse_box.interact(museum.player)


func _approach_the_crystal() -> void:
	var crystal := museum.objective.crystal
	var toward_hall := Vector3(-crystal.global_position.x, 0.0, -crystal.global_position.z).normalized()
	museum.player.global_position = _floor_under(crystal.global_position + toward_hall * 1.8 + Vector3.UP * 0.5) + Vector3.UP * 0.05
	await physics_frames(3)


func _follow_the_crystal() -> bool:
	for i in 60 * 40:
		var crystal := museum.objective.crystal
		if crystal == null or not is_instance_valid(crystal):
			return true
		if i % 6 == 0:
			museum.player.global_position = _floor_under(crystal.global_position + Vector3(0.0, -0.5, 1.5)) + Vector3.UP * 0.05
		await get_tree().physics_frame
	return false


## Stands the guard in the middle of [param room]'s first part (his head,
## the listener, comes along at once).
func _stand_in(room: RoomSpec) -> Vector3:
	var part := room.parts[0]
	var at := Vector3(part.get_center().x, room.floor_y + 0.1, part.get_center().y)
	museum.player.respawn(at, 0.0)
	return at


func test_every_lobby_room_has_its_zone_its_reverb_and_its_floor() -> void:
	_game(2)
	_museum()
	await physics_frames(2)
	var layout := museum.lobby.layout
	var zones := Ambience.build_reverb(AudioContext.level(get_tree()))
	var parts := 0
	for room in layout.rooms:
		parts += room.parts.size()
	assert_eq(AudioContext.level(get_tree()), museum.lobby, "the audio finds the museum's level")
	assert_eq(zones.size(), parts, "a reverb zone for every part of every room")
	var steps := Foley.attach(museum.player)
	assert_not_null(steps, "the guard gets his footsteps")
	for room in layout.rooms:
		assert_true(Ambience.ROOM_ZONES.has(room.id), "%s has an ambience zone" % room.id)
		assert_true(Surface.ROOM_SURFACES.has(room.id), "%s has a floor" % room.id)
		assert_ne(Surface.normalize(Surface.ROOM_SURFACES.get(room.id)), &"", "%s: a known floor word" % room.id)
		var at := _stand_in(room)
		await physics_frames(1)
		assert_eq(museum.lobby.room_at(at), room.id, "%s: standing in it" % room.id)
		Ambience.refresh()
		assert_eq(Ambience.zone, Ambience.ROOM_ZONES[room.id], "%s: its room tone" % room.id)
		Ambience._update_listener_zone()
		var reverb := Ambience._listener_zone
		assert_not_null(reverb, "%s: the listener is in a reverb zone" % room.id)
		if reverb != null:
			var preset: int = (Ambience.ROOM_REVERB.get(room.id, Ambience.ROOM_REVERB_DEFAULT) as Array)[0]
			assert_eq(reverb.preset, preset, "%s: its acoustics" % room.id)
		if steps != null:
			assert_eq(steps.probe_surface(), Surface.of_room(room.id), "%s: its floor under the guard's feet" % room.id)


func test_the_floors_sound_like_the_art_kit_tiles_them() -> void:
	for room: StringName in ArtKit.ROOMS:
		var tiles := String(ArtKit.style(room).get("floor", ""))
		assert_ne(tiles, "", "%s has floor tiles" % room)
		# "marble_hall", "flagstone", "linoleum"...: the material is the first word
		var material := Surface.normalize(tiles.get_slice("_", 0))
		assert_ne(material, &"", "%s: %s is a known floor" % [room, tiles])
		assert_eq(Surface.of_room(room), material, "%s sounds like its %s" % [room, tiles])
	assert_eq(Surface.of_room(&"hall"), Surface.STONE, "marble")
	assert_eq(Surface.of_room(&"security"), Surface.STONE, "linoleum")
	assert_eq(Surface.of_room(&"closet"), Surface.WOOD, "boards")


func test_the_night_goal_tells_its_story_in_music_and_room_tone() -> void:
	_game(1)
	_museum()
	await physics_frames(2)
	var night := Music.director.night
	assert_eq(night.night, 1)
	assert_eq(night.stage, STAGE.FUSES)
	assert_eq(Music.state(), S.EXPLORE)
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK, "the first night walks softly")
	museum.player.global_position = Vector3(0, 0.1, 10)
	await physics_frames(2)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"grand_hall")
	assert_eq(Ambience.targets[&"dread"], 0.0)
	# both fuses in: the relay, the lamps die, the music holds its breath
	var cuts := watch(Events.power_cut)
	_cut_the_power()
	assert_eq(cuts.size(), 1)
	assert_true(Music.director.hushed())
	assert_eq(Music.state(), S.TENSION)
	assert_true(Ambience.power_cut_in(&"grand_hall"))
	assert_gt(Ambience.targets[&"dread"], 0.0, "the hall's blackout bed")
	assert_almost_eq(Ambience.targets[&"mains_hum"], db_to_linear(float(Ambience.EMERGENCY_LAYERS[&"mains_hum"])), 0.001)
	await _seconds(1.0)
	assert_lt(Music.levels[&"explore"], MusicDirector.HUSH_LEVEL + 0.01, "near silence")
	await _seconds(MusicDirector.HUSH_TIME)
	assert_false(Music.director.hushed())
	assert_eq(_targets()[&"explore_tension"], MusicDirector.POWER_TENSION, "then the tension stem")
	# the crystal flies: tension in full
	await _approach_the_crystal()
	assert_eq(museum.objective.stage, NightObjective.Stage.FLIGHT)
	assert_eq(Music.state(), S.TENSION)
	assert_eq(_targets()[&"explore_tension"], 1.0)
	# the T-Rex wakes: the boss track, its hi stem from phase 2
	assert_true(await _follow_the_crystal(), "the crystal arrived")
	await physics_frames(2)
	assert_eq(Music.state(), S.BOSS)
	assert_eq(_targets()[&"boss_hi"], 0.0)
	var boss := museum.objective.boss
	museum.player.global_position = Vector3(0, 0.1, 12)
	boss.brain.set_health_fraction(0.5)
	assert_eq(Music.director.boss_phase, 2, "the T-Rex's own phase signal reaches the music")
	assert_eq(_targets()[&"boss_hi"], 1.0)
	# it falls: the victory sting, then a quiet walk to the stairs
	boss.take_zone_damage(DamageInfo.make(99999.0, DamageInfo.Kind.BALLISTIC, museum.player), TRexBrain.Zone.CRYSTAL)
	assert_eq(Music.state(), S.VICTORY)
	assert_true((Music.stings[&"victory_sting"] as AudioStreamPlayer).playing)
	_clear_exhibits()   # whatever the roar called would keep the music tense
	await _seconds(MusicDirector.VICTORY_TIME + 0.5)
	assert_eq(Music.state(), S.EXPLORE)
	assert_eq(_targets()[&"explore"], MusicDirector.QUIET_WALK)
	assert_eq(_targets()[&"explore_tension"], 0.0)


func test_the_witching_hour_and_dawn_in_the_lobby() -> void:
	_game(3, &"full_moon")
	_museum()
	await physics_frames(2)
	museum.player.global_position = Vector3(0, 0.1, 50)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.MOON_TENSION, "a full moon: a little tension")
	var rang := watch(Events.witching_hour)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() - 0.2
	await _seconds(0.5)
	assert_eq(rang.size(), 1)
	assert_true(Music.director.night.witching)
	assert_true(Ambience.night.witching)
	assert_eq(_targets()[&"explore_tension"], MusicDirector.WITCHING_TENSION, "the denser layer from 3:00")
	var dawned := watch(Events.dawn_broke)
	museum.watch.clock.elapsed = NightClock.seconds_to_dawn() - 0.2
	await _seconds(0.5)
	assert_eq(dawned.size(), 1)
	assert_eq(Music.state(), S.SILENT)
	assert_true(Music.levels[&"explore"] > 0.0, "fading, not cut")
	await _seconds(Music.DAWN_FADE)
	assert_false(Music.is_family_playing(&"explore"), "the music is gone")
	assert_eq(Ambience.targets[&"dread"], 0.0)
	var birds := Ambience._birds
	assert_not_null(birds, "birds at dawn")
	if birds != null:
		assert_true(birds.playing)


func test_a_resumed_night_comes_back_dark_and_past_the_witching_hour() -> void:
	_game(2, &"none")
	GameState.save_game()
	_museum()
	await physics_frames(2)
	_cut_the_power()
	await _seconds(1.6)
	museum.watch.clock.elapsed = NightClock.seconds_to_witching() + 30.0
	museum.quit_to_menu()
	museum.free()
	GameState.reset()
	RunState.reset()
	assert_true(GameState.load_game())
	await get_tree().process_frame
	_museum()
	await physics_frames(2)
	assert_eq(museum.objective.stage, NightObjective.Stage.PULSING, "the power is still out")
	var night := Music.director.night
	assert_eq(night.night, 2)
	assert_true(night.power_out())
	assert_true(night.witching, "resumed past 3:00")
	assert_eq(Music.state(), S.TENSION)
	assert_false(Music.director.hushed(), "no hush: no power cut happened now")
	assert_true(Ambience.night.power_out())
	assert_true(Ambience.power_cut_in(&"grand_hall"))


func test_a_blackout_night_is_dark_in_every_room_from_the_start() -> void:
	_game(2, &"blackout")
	_museum()
	await physics_frames(2)
	assert_true(Ambience.blackout)
	for zone_id: StringName in Ambience.ZONES:
		Ambience.set_zone(zone_id)
		for layer in Ambience.ELECTRIC:
			assert_eq(Ambience.targets[layer], 0.0, "%s: %s dark" % [zone_id, layer])
		assert_gt(Ambience.targets[&"dread"], 0.0, String(zone_id))


func test_the_guard_falling_in_the_lobby_plays_the_death_sting() -> void:
	_game(2)
	_museum()
	await physics_frames(2)
	museum.player.global_position = Vector3(0, 0.1, 10)
	await physics_frames(2)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"grand_hall")
	museum.player.take_damage(DamageInfo.make(museum.player.health.max_health * 10.0, DamageInfo.Kind.BLUNT))
	assert_eq(Music.state(), S.SILENT)
	assert_true((Music.stings[&"death_sting"] as AudioStreamPlayer).playing, "the death sting")
	Ambience.refresh()
	assert_eq(Ambience.zone, &"", "the room recedes under the death screen")
