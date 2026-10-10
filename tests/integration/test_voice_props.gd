extends TestCase


func after_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = false


func test_a_loudspeaker_joins_the_group_and_plays_after_its_delay() -> void:
	var speaker := Loudspeaker.create(Transform3D.IDENTITY)
	add_child(speaker)
	assert_true(speaker.is_in_group(&"loudspeakers"))
	var stream := VoiceDirector.catalog.stream(&"VO_SYSTEM_CLOSING_1")
	speaker.play_voice(stream, 0.05)
	assert_false(speaker.is_speaking())
	speaker.advance(0.1)
	assert_true(speaker.is_speaking())
	assert_eq(speaker.player.bus, &"VoiceSystem")
	assert_true(speaker.player.area_mask & Layers.REVERB_ZONE != 0, "hears the reverb zones")
	speaker.stop_voice()
	assert_false(speaker.is_speaking())


func test_the_director_plays_the_system_through_the_nearest_loudspeakers() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var near := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(3, 3, 0)))
	var far := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(20, 3, 0)))
	var out_of_range := Loudspeaker.create(Transform3D(Basis.IDENTITY, Vector3(80, 3, 0)))
	for speaker in [near, far, out_of_range]:
		add_child(speaker)
	Events.night_started.emit(1, &"")
	GameState.mark_voice_heard(&"VO_HENIEK_NIGHT_1")   # straight to the System's line
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	Events.night_started.emit(1, &"")
	for i in 300:
		VoiceDirector.advance(0.1)
	assert_eq(VoiceDirector.current_line(), &"VO_SYSTEM_CLOSING_1")
	assert_true(near.is_speaking(), "the nearest plays at once")
	assert_false(out_of_range.is_speaking(), "80 m away stays silent")
	for i in 3:
		far.advance(0.1)
	assert_true(far.is_speaking(), "the farther one after its echo delay")


func test_a_stand_is_interactable_and_asks_the_director() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	var stand := AudioguideStand.create(&"rosetta", Transform3D.IDENTITY)
	add_child(stand)
	assert_eq(stand.prompt(), tr("PROMPT_AUDIOGUIDE"))
	assert_eq(stand.collision_layer, Layers.INTERACT)
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"VO_GUIDE_ROSETTA_A")
	assert_true(stand.is_speaking())
	stand.interact(null)
	assert_eq(VoiceDirector.current_line(), &"")
	assert_false(stand.is_speaking())


func test_floor1_places_loudspeakers_and_the_rosetta_stand() -> void:
	var layout := Floor1Layout.create()
	var speakers := layout.markers.keys().filter(func(k: StringName) -> bool: return String(k).begins_with("loudspeaker_"))
	assert_gt(speakers.size(), 2)
	assert_true(layout.markers.has(&"audioguide_rosetta"))
	for id in speakers:
		var at: Transform3D = layout.markers[id]
		assert_true(at.origin.y > 2.5 and at.origin.y < 5.0, "%s hangs high on a wall" % id)
	var stand: Transform3D = layout.markers[&"audioguide_rosetta"]
	assert_lt(stand.origin.distance_to(layout.markers[&"rosetta_stone"].origin), 4.0, "by the stone")


func test_a_stand_is_solid_to_walk_into() -> void:
	var stand := AudioguideStand.create(&"rosetta", Transform3D.IDENTITY)
	add_child(stand)
	var body: StaticBody3D = null
	for child in stand.get_children():
		if child is StaticBody3D:
			body = child
	assert_not_null(body, "a StaticBody3D under the stand")
	if body:
		assert_true(body.collision_layer & Layers.WORLD != 0, "on the world layer")
		assert_gt(body.get_child_count(), 0, "with a shape")
