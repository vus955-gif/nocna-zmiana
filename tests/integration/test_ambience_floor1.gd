extends TestCase
## Ambience on Floor I: Events.room_entered picks the zone (and a sub-zone
## by the room's name), zones and nodes keep their priorities, every zone
## has its beds and one-shots, the new reverb presets have their buses and
## a level's rooms get reverb from their zone.

const FLOOR_ZONES: Array[StringName] = [&"court", &"entrance", &"booth", &"egypt", &"assyria", &"greece", &"enlightenment",
	&"asia", &"americas", &"north_hall", &"basement", &"roof"]

var camera: Camera3D


class _Room:
	extends RefCounted
	var id: StringName
	var zone: StringName
	var parts: Array[Rect2] = []
	var floor_y: float = 0.0
	var ceiling_y: float = 10.0


class _Layout:
	extends RefCounted
	var rooms: Array = []


class _Level:
	extends Node
	var layout := _Layout.new()


func before_each() -> void:
	Ambience.reset()
	Ambience.enabled = true
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true


func after_each() -> void:
	Ambience.reset()
	Ambience.enabled = false


func test_every_floor_zone_has_beds_and_one_shots() -> void:
	for zone in FLOOR_ZONES:
		assert_true(Ambience.ZONES.has(zone), "%s has a mix" % zone)
		assert_gt((Ambience.ZONES.get(zone, {}) as Dictionary).size(), 1, "%s mixes several beds" % zone)
		assert_true(Ambience.ZONE_SHOTS.has(zone), "%s has distant sounds" % zone)
		assert_true(Ambience.ZONE_REVERB.has(zone), "%s has a reverb" % zone)
	for zone: StringName in Ambience.SUB_ZONES:
		for word: String in Ambience.SUB_ZONES[zone]:
			var sub: StringName = Ambience.SUB_ZONES[zone][word]
			assert_true(Ambience.ZONES.has(sub), String(sub))
			assert_true(Ambience.ZONE_SHOTS.has(sub), String(sub))
			assert_eq(MusicDirector.wing_of_zone(sub), MusicDirector.wing_of_zone(zone), "a sub-zone stays in its wing")


func test_room_entered_brings_the_zone_in() -> void:
	Ambience.set_active(true)
	Events.room_entered.emit(&"great_gallery", &"egypt", true)
	assert_eq(Ambience.zone, &"egypt")
	Ambience.advance(Ambience.FADE + 0.1)
	assert_almost_eq(Ambience.levels[&"stone_deep"], 1.0, 0.001)
	assert_almost_eq(Ambience.levels[&"sand_trickle"], db_to_linear(-3.0), 0.001)
	assert_true((Ambience.players[&"crack_wind"] as AudioStreamPlayer).playing)
	Events.room_entered.emit(&"great_court", &"court", false)
	assert_eq(Ambience.zone, &"court")
	Ambience.advance(Ambience.FADE + 0.1)
	assert_eq(Ambience.levels[&"stone_deep"], 0.0, "Egypt's stone is gone")
	assert_almost_eq(Ambience.levels[&"glass_wind"], 1.0, 0.001, "the glass roof's wind")


func test_a_rooms_name_picks_a_sub_zone() -> void:
	Ambience.set_active(true)
	Events.room_entered.emit(&"japanese_garden", &"asia", true)
	assert_eq(Ambience.zone, &"asia_garden")
	Events.room_entered.emit(&"boiler_room", &"basement", false)
	assert_eq(Ambience.zone, &"basement_boiler")
	Events.room_entered.emit(&"hall_of_clocks", &"enlightenment", false)
	assert_eq(Ambience.zone, &"enlightenment_clocks")
	Events.room_entered.emit(&"korean_room", &"asia", false)
	assert_eq(Ambience.zone, &"asia")
	assert_eq(Ambience.floor_zone(&"tomb_of_nakht", &"egypt"), &"egypt_tomb")


func test_a_zone_node_and_a_manual_choice_beat_the_event() -> void:
	Ambience.set_active(true)
	Events.room_entered.emit(&"great_gallery", &"egypt", false)
	var area := AmbienceZone.make(&"booth", AABB(Vector3(-5, -1, -5), Vector3(10, 4, 10)))
	add_child(area)
	Ambience.refresh()
	assert_eq(Ambience.zone, &"booth", "a placed zone is more specific")
	Ambience.set_zone(&"roof")
	assert_eq(Ambience.zone, &"roof")
	Ambience.set_zone(&"")
	area.queue_free()
	await get_tree().process_frame
	Ambience.refresh()
	assert_eq(Ambience.zone, &"egypt", "the event's zone again")


func test_an_unknown_zone_falls_back() -> void:
	Ambience.set_active(true)
	Events.room_entered.emit(&"somewhere", &"crypt", false)
	assert_eq(Ambience.zone, Ambience.DEFAULT_ZONE)


func test_a_scene_swap_forgets_a_zone_it_did_not_announce() -> void:
	Events.room_entered.emit(&"great_court", &"court", false)
	Ambience._on_scene_changed()
	assert_eq(Ambience.event_zone, &"court", "announced while the scene set up")
	await get_tree().process_frame
	await get_tree().process_frame
	Ambience._on_scene_changed()
	assert_eq(Ambience.event_zone, &"")


func test_floor_one_shots_play_in_their_zone() -> void:
	Ambience.set_active(true)
	Events.room_entered.emit(&"garden", &"asia", true)
	var kinds := {}
	for i in 60:
		kinds[Ambience.pick_shot_kind()] = true
	for kind: StringName in kinds:
		assert_true(Ambience.ZONE_SHOTS[&"asia_garden"].has(kind), "%s belongs to the garden" % kind)
	var shot := Ambience.play_shot(&"bamboo", Vector3(4, 0, -12))
	assert_not_null(shot, "the bamboo has its takes")


func test_every_reverb_preset_has_its_bus() -> void:
	for preset: int in ReverbZone.BUSES:
		var bus := AudioServer.get_bus_index(ReverbZone.BUSES[preset])
		assert_true(bus >= 0, String(ReverbZone.BUSES[preset]))
		if bus < 0:
			continue
		assert_eq(AudioServer.get_bus_send(bus), &"SFXReturn", "tails return beside the SFX bus")
		assert_true(AudioServer.get_bus_effect(bus, 0) is AudioEffectReverb)
		assert_eq((AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb).dry, 0.0, "wet only")
		assert_true(ReverbZone.AMOUNTS.has(preset) and ReverbZone.LISTENER.has(preset))
	var vast := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"ReverbVast"), 0) as AudioEffectReverb
	var library := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"ReverbLibrary"), 0) as AudioEffectReverb
	assert_gt(vast.room_size, library.room_size, "the glass court rings longer than the books")
	assert_gt(library.damping, vast.damping, "books soak the highs")


func test_rooms_take_their_reverb_from_their_zone() -> void:
	assert_eq(Ambience.reverb_for(&"hall")[0], ReverbZone.Preset.HALL, "the lobby's own map first")
	assert_eq(Ambience.reverb_for(&"anything", &"court")[0], ReverbZone.Preset.VAST)
	assert_eq(Ambience.reverb_for(&"great_gallery", &"egypt")[0], ReverbZone.Preset.GALLERY)
	assert_eq(Ambience.reverb_for(&"kings_library", &"enlightenment")[0], ReverbZone.Preset.LIBRARY)
	assert_eq(Ambience.reverb_for(&"japanese_garden", &"asia")[0], ReverbZone.Preset.GARDEN, "a word in the id first")
	assert_eq(Ambience.reverb_for(&"boiler_room", &"basement")[0], ReverbZone.Preset.CONCRETE)
	assert_eq(Ambience.reverb_for(&"north_corridor", &"north_hall")[0], ReverbZone.Preset.CORRIDOR)
	assert_eq(Ambience.reverb_for(&"nowhere")[0], ReverbZone.Preset.ROOM, "no zone: the default")


func test_build_reverb_uses_the_rooms_zone() -> void:
	var level := _Level.new()
	for spec in [[&"great_court", &"court"], [&"japanese_garden", &"asia"], [&"service", &"basement"]]:
		var room := _Room.new()
		room.id = spec[0]
		room.zone = spec[1]
		room.parts = [Rect2(0, 0, 10, 10)]
		level.layout.rooms.append(room)
	add_child(level)
	var made := Ambience.build_reverb(level)
	assert_eq(made.size(), 3)
	if made.size() == 3:
		assert_eq(made[0].preset, ReverbZone.Preset.VAST)
		assert_eq(made[1].preset, ReverbZone.Preset.GARDEN)
		assert_eq(made[2].preset, ReverbZone.Preset.CONCRETE)
	level.queue_free()
