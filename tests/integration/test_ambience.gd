extends TestCase
## The Ambience autoload: zone beds, blackout, zone priority, room mapping,
## one-shots, reverb zones and the listener's room on the SFX bus.

var camera: Camera3D


func before_each() -> void:
	Ambience.reset()
	Ambience.enabled = true
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true


func after_each() -> void:
	Ambience.reset()
	Ambience.enabled = false


func _level(layer: StringName) -> float:
	return Ambience.levels[layer]


func test_a_zone_brings_its_layers_up() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"security")
	assert_eq(Ambience.zone, &"security")
	Ambience.advance(Ambience.FADE + 0.1)
	assert_almost_eq(_level(&"fluorescent"), 1.0, 0.001)
	assert_almost_eq(_level(&"clock"), 1.0, 0.001)
	assert_almost_eq(_level(&"gallery_room"), db_to_linear(-4.0), 0.001)
	assert_eq(_level(&"hall_air"), 0.0)
	var buzz := Ambience.players[&"fluorescent"] as AudioStreamPlayer
	assert_true(buzz.playing)
	assert_eq(buzz.bus, &"Ambience")


func test_zones_crossfade() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"corridor")
	Ambience.advance(Ambience.FADE + 0.1)
	Ambience.set_zone(&"grand_hall")
	Ambience.advance(Ambience.FADE * 0.5)
	assert_gt(_level(&"hall_air"), 0.2, "the hall comes in")
	assert_gt(_level(&"hvac"), 0.2, "while the corridor goes")
	Ambience.advance(Ambience.FADE)
	assert_eq(_level(&"hvac"), 0.0)
	assert_false((Ambience.players[&"hvac"] as AudioStreamPlayer).playing, "a silent bed stops")


func test_blackout_kills_electric_layers_and_brings_dread() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"security")
	Ambience.set_blackout(true)
	for layer in Ambience.ELECTRIC:
		assert_eq(Ambience.targets[layer], 0.0, String(layer) + " has no power")
	assert_gt(Ambience.targets[&"dread"], 0.0)
	assert_gt(Ambience.targets[&"clock"], 0.0, "the clock is wound, not wired")
	Ambience.set_blackout(false)
	assert_eq(Ambience.targets[&"dread"], 0.0)
	assert_gt(Ambience.targets[&"fluorescent"], 0.0)


func test_the_world_recedes_while_the_guard_is_down() -> void:
	var guard := Player.new()
	add_child(guard)
	Ambience.set_active(true)
	Ambience.set_zone(&"gallery")
	assert_eq(Ambience.zone, &"gallery")
	guard.alive = false
	Ambience.refresh()
	assert_eq(Ambience.zone, &"", "silence under the death screen")
	guard.alive = true
	Ambience.refresh()
	assert_eq(Ambience.zone, &"gallery", "back after a respawn")


func test_a_blackout_modifier_drawn_mid_scene_changes_the_beds() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"security")
	Ambience._modifier_seen = RunState.modifier
	RunState.modifier = &"blackout"
	Ambience._poll = 0.0
	Ambience._process(0.01)
	assert_true(Ambience.blackout)
	assert_eq(Ambience.targets[&"fluorescent"], 0.0, "the tubes go dark")
	assert_gt(Ambience.targets[&"dread"], 0.0)
	RunState.modifier = &"none"


func test_nothing_plays_outside_a_game_scene() -> void:
	Ambience.set_active(false)
	Ambience.set_zone(&"gallery")
	assert_eq(Ambience.zone, &"")
	Ambience.advance(1.0)
	for layer in Ambience.LAYERS:
		assert_eq(_level(layer), 0.0)


func test_ambience_zones_around_the_listener_win_by_priority() -> void:
	Ambience.set_active(true)
	assert_eq(Ambience.zone, Ambience.DEFAULT_ZONE, "no zone, no rooms: the default")
	var wide := AmbienceZone.make(&"grand_hall", AABB(Vector3(-20, -1, -20), Vector3(40, 10, 40)))
	add_child(wide)
	var small := AmbienceZone.make(&"security", AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4)), 5)
	add_child(small)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"security", "the higher priority wins")
	camera.position = Vector3(10, 1, 0)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"grand_hall")
	Ambience.set_zone(&"corridor")
	assert_eq(Ambience.zone, &"corridor", "a manual zone beats areas")
	Ambience.set_zone(&"")
	assert_eq(Ambience.zone, &"grand_hall", "back to automatic")
	assert_eq(wide.collision_layer, 0, "zones take no part in physics")
	assert_false(wide.monitoring)


func test_level_rooms_map_to_zones_and_reverb() -> void:
	var level := _FakeLevel.new()
	add_child(level)
	Ambience.set_active(true)
	camera.position = Vector3(0, 1, 0)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"grand_hall", "the hall")
	camera.position = Vector3(30, 1, 0)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"corridor", "a corridor")
	var zones := Ambience.build_reverb(level)
	assert_eq(zones.size(), 2)
	var hall := zones[0]
	assert_eq(hall.reverb_bus_name, &"ReverbHall")
	assert_true(hall.reverb_bus_enabled)
	assert_eq(hall.collision_layer, Layers.REVERB_ZONE, "own layer: rays never see it")
	assert_true(hall.contains(Vector3(0, 1, 0)))
	assert_false(hall.contains(Vector3(0, 20, 0)), "above the ceiling")
	assert_eq(zones[1].reverb_bus_name, &"ReverbCorridor")


func test_reverb_buses_return_past_the_listener_reverb_at_the_sfx_level() -> void:
	var tails := AudioServer.get_bus_index(Ambience.RETURN_BUS)
	assert_gt(tails, 0, "the return bus")
	assert_eq(AudioServer.get_bus_send(tails), &"Master", "not through SFX (its listener reverb)")
	for preset: int in ReverbZone.BUSES:
		var bus := AudioServer.get_bus_index(ReverbZone.BUSES[preset])
		assert_gt(bus, 0, String(ReverbZone.BUSES[preset]))
		assert_eq(AudioServer.get_bus_send(bus), Ambience.RETURN_BUS)
		assert_true(AudioServer.get_bus_effect(bus, 0) is AudioEffectReverb)
		assert_gt(bus, tails, "sends go left")
	var sfx := AudioServer.get_bus_index(&"SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(tails), AudioServer.get_bus_volume_db(sfx), 0.01, "at the SFX level")
	Settings.set_value(&"volume_sfx", 0.5, false)
	assert_almost_eq(AudioServer.get_bus_volume_db(tails), AudioServer.get_bus_volume_db(sfx), 0.01, "the SFX slider moves the tails too")
	Settings.set_value(&"volume_sfx", 0.0, false)
	assert_true(AudioServer.is_bus_mute(tails), "and mutes them")
	Settings.set_value(&"volume_sfx", 1.0, false)
	assert_false(AudioServer.is_bus_mute(tails))


func test_the_listeners_room_lends_the_sfx_bus_its_reverb() -> void:
	Ambience.set_active(true)
	var hall := ReverbZone.make(ReverbZone.Preset.HALL, AABB(Vector3(-10, -1, -10), Vector3(20, 10, 20)))
	add_child(hall)
	Ambience._update_listener_zone()
	Ambience.advance(1.0)
	var effect := Ambience.listener_reverb()
	assert_not_null(effect)
	if effect != null:
		assert_almost_eq(effect.wet, float(ReverbZone.LISTENER[ReverbZone.Preset.HALL][2]), 0.01)
		assert_almost_eq(effect.room_size, float(ReverbZone.LISTENER[ReverbZone.Preset.HALL][0]), 0.001)
	Ambience.reset()
	var sfx := AudioServer.get_bus_index(&"SFX")
	for i in AudioServer.get_bus_effect_count(sfx):
		assert_ne(AudioServer.get_bus_effect(sfx, i), effect, "reset removes it")


func test_sfx_voices_hear_the_reverb_zones() -> void:
	Sfx.play_at(&"block", Vector3.ZERO)
	var voice := Sfx.get_child(Sfx.get_child_count() - 1) as AudioStreamPlayer3D
	assert_not_null(voice)
	if voice != null:
		assert_eq(voice.area_mask & Layers.REVERB_ZONE, Layers.REVERB_ZONE)
	Sfx.stop_all()


func test_one_shots_play_around_the_listener() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"gallery")
	var kinds := {}
	for i in 60:
		kinds[Ambience.pick_shot_kind()] = true
	for kind: StringName in kinds:
		assert_true(Ambience.ZONE_SHOTS[&"gallery"].has(kind), "gallery shot " + kind)
	var shot := Ambience.play_shot(&"creak")
	assert_not_null(shot)
	if shot != null:
		assert_eq(shot.bus, &"Ambience")
		assert_eq(shot.area_mask, 0, "space baked in")
		var distance := shot.position.distance_to(camera.global_position)
		assert_true(distance >= Ambience.SHOT_DISTANCE.x - 0.01 and distance <= Ambience.SHOT_DISTANCE.y + 4.1, "%.1f m" % distance)
	for i in Ambience.MAX_SHOTS + 3:
		Ambience.play_shot(&"thud")
	var count := 0
	for child in Ambience.get_children():
		if child is AudioStreamPlayer3D:
			count += 1
	assert_eq(count, Ambience.MAX_SHOTS, "capped")
	Ambience.stop_all()
	for child in Ambience.get_children():
		assert_false(child is AudioStreamPlayer3D and not child.is_queued_for_deletion())


func test_blackout_adds_its_own_shots() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"secret")
	Ambience.set_blackout(true)
	var kinds := {}
	for i in 200:
		kinds[Ambience.pick_shot_kind()] = true
	assert_true(kinds.has(&"groan"), "the building groans in the dark")


# --- the night in the lobby -------------------------------------------------

const STAGE := NightObjective.Stage


func test_a_blackout_night_is_dark_from_its_start() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"security")
	Events.night_started.emit(3, &"blackout")
	assert_true(Ambience.blackout, "the night's modifier, not only RunState's")
	for layer in Ambience.ELECTRIC:
		assert_eq(Ambience.targets[layer], 0.0, String(layer) + " has no power")
	assert_gt(Ambience.targets[&"dread"], 0.0)
	Ambience.set_zone(&"grand_hall")
	assert_eq(Ambience.targets[&"mains_hum"], 0.0, "no emergency hum: the hall was dark all night")
	await get_tree().process_frame
	Events.night_started.emit(4, &"none")
	assert_false(Ambience.blackout, "the next night has its lamps")


func test_the_power_cut_darkens_the_hall_and_its_emergency_circuit_hums() -> void:
	Ambience.set_active(true)
	Events.night_started.emit(2, &"none")
	Events.objective_changed.emit(STAGE.FUSES)
	Ambience.set_zone(&"grand_hall")
	Ambience.advance(Ambience.FADE + 0.1)
	var hum := db_to_linear(float(Ambience.ZONES[&"grand_hall"][&"mains_hum"]))
	assert_almost_eq(Ambience.levels[&"mains_hum"], hum, 0.001)
	assert_eq(Ambience.targets[&"dread"], 0.0)
	Events.objective_changed.emit(STAGE.PULSING)
	Events.power_cut.emit()
	var emergency := db_to_linear(float(Ambience.EMERGENCY_LAYERS[&"mains_hum"]))
	assert_almost_eq(Ambience.targets[&"mains_hum"], emergency, 0.001, "the emergency circuit's thinner hum")
	assert_gt(Ambience.targets[&"dread"], 0.0, "the blackout bed comes in")
	assert_gt(Ambience.targets[&"hall_air"], 0.0, "the air stays")
	Ambience.advance(Ambience.CUT_FADE + 0.05)
	assert_almost_eq(Ambience.levels[&"mains_hum"], emergency, 0.001, "the lamps' hum sags at once")
	assert_lt(Ambience.levels[&"dread"], 0.5, "the dread swells in at its own pace")
	Ambience.advance(Ambience.FADE)
	assert_almost_eq(Ambience.levels[&"dread"], 1.0, 0.001)
	assert_eq(Ambience.shot_gap(), Ambience.BLACKOUT_GAP, "the dark hall stirs more")
	Ambience.set_zone(&"security")
	assert_gt(Ambience.targets[&"fluorescent"], 0.0, "the booth keeps its power")
	assert_eq(Ambience.targets[&"dread"], 0.0)
	assert_eq(Ambience.shot_gap(), Ambience.SHOT_GAP)


func test_a_night_resumed_with_the_power_out_starts_dark() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"grand_hall")
	# the museum sets up: its objective first, then the night (one frame)
	Events.objective_changed.emit(STAGE.PULSING)
	Events.night_started.emit(2, &"none")
	assert_true(Ambience.night.power_out())
	assert_gt(Ambience.targets[&"dread"], 0.0)
	assert_eq(Ambience._cut_left, 0.0, "no cut moment, no quick fade")


func test_from_the_witching_hour_the_building_stirs_more_often() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"gallery")
	Events.night_started.emit(2, &"none")
	assert_eq(Ambience.shot_gap(), Ambience.SHOT_GAP)
	Ambience._shot_timer = 60.0
	Events.witching_hour.emit()
	assert_eq(Ambience.shot_gap(), Ambience.WITCHING_GAP)
	assert_lt(Ambience._shot_timer, Ambience.WITCHING_GAP.y + 0.01, "the next stir comes sooner")


func test_dawn_takes_the_dread_away_and_lets_far_birds_in() -> void:
	Ambience.set_active(true)
	Ambience.set_zone(&"grand_hall")
	Events.night_started.emit(3, &"blackout")
	assert_gt(Ambience.targets[&"dread"], 0.0)
	Events.dawn_broke.emit()
	assert_eq(Ambience.targets[&"dread"], 0.0, "the night's menace is over")
	assert_gt(Ambience.targets[&"hall_air"], 0.0, "the room stays")
	Ambience._shot_timer = 0.0
	Ambience._process(0.01)
	for child in Ambience.get_children():
		assert_false(child is AudioStreamPlayer3D, "no more stirring at dawn")
	assert_true(Ambience._birds == null or not Ambience._birds.playing, "not at once")
	Ambience._process(Ambience.DAWN_BIRDS_DELAY)
	var birds := Ambience._birds
	assert_not_null(birds)
	if birds != null:
		assert_true(birds.playing, "birds beyond the skylights")
		assert_eq(birds.bus, &"Ambience")
		assert_almost_eq(birds.volume_db, Ambience.DAWN_BIRDS_DB, 0.01)
		assert_eq((birds.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "once")
	Events.dawn_broke.emit()
	assert_lt(Ambience._birds_in, 0.0, "one dawn, one song")
	Ambience.reset()
	assert_true(birds == null or not birds.playing, "a reset silences them")


func test_a_scene_swap_forgets_a_night_it_did_not_announce() -> void:
	Events.night_started.emit(3, &"blackout")
	Events.objective_changed.emit(STAGE.PULSING)
	Ambience._on_scene_changed()   # the running scene here is no game scene
	assert_eq(Ambience.night.night, 0, "a menu has no night")
	assert_false(Ambience.night.power_out())
	assert_false(Ambience.blackout)


func test_night_events_are_ignored_when_disabled() -> void:
	Ambience.enabled = false
	Events.night_started.emit(3, &"blackout")
	Events.power_cut.emit()
	assert_eq(Ambience.night.night, 0)
	assert_false(Ambience.blackout)
	Ambience.enabled = true


## A level stand-in: two rooms (hall, corridor) with room_at() and a layout.
class _FakeLevel:
	extends Node3D
	var layout := _Layout.new()

	func room_at(point: Vector3) -> StringName:
		for room: _Room in layout.rooms:
			for part in room.parts:
				if part.has_point(Vector2(point.x, point.z)):
					return room.id
		return &""


class _Layout:
	extends RefCounted
	var rooms: Array = [_Room.make(&"hall", Rect2(-20, -20, 40, 40), 0.0, 14.0), _Room.make(&"corridor_e", Rect2(20, -2, 20, 4), 0.0, 3.5)]


class _Room:
	extends RefCounted
	var id: StringName
	var parts: Array[Rect2] = []
	var floor_y: float = 0.0
	var ceiling_y: float = 3.0

	static func make(room_id: StringName, rect: Rect2, floor_height: float, ceiling: float) -> _Room:
		var room := _Room.new()
		room.id = room_id
		room.parts = [rect]
		room.floor_y = floor_height
		room.ceiling_y = ceiling
		return room
