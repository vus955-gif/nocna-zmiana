extends TestCase
## The ambient story in the game (plan 2026-10-21-akustyka-ambient): what
## StoryLayer plays and where, the silences it keeps (havens, a sleeping
## guardian, the voice), rain, the clocks stopping, the night's phase, and
## that the zone's far sounds respect the same silences. A level of three
## rooms in a row: a (where the camera stands) | b | booth_security (a haven).

var camera: Camera3D
var level: _Level


class _Level:
	extends Node3D
	var layout := LevelLayout.new()

	func room_at(point: Vector3) -> StringName:
		return layout.room_at(point)


func before_each() -> void:
	await get_tree().process_frame   # (a first test: the runner's own scene_changed comes a frame late)
	Ambience.reset()
	Ambience.enabled = true
	level = _Level.new()
	level.layout.add_room(&"a", [Rect2(0.0, 0.0, 10.0, 10.0)] as Array[Rect2], 0.0, 4.0, Color.WHITE)
	level.layout.add_room(&"b", [Rect2(10.0, 0.0, 10.0, 10.0)] as Array[Rect2], 0.0, 4.0, Color.WHITE)
	var haven := level.layout.add_room(&"booth_security", [Rect2(20.0, 0.0, 6.0, 10.0)] as Array[Rect2], 0.0, 3.0, Color.WHITE)
	haven.haven = true
	level.layout.add_opening(&"ab", Rect2(9.8, 4.0, 0.4, 2.0), 0.0, 3.0, &"a", &"b")
	level.layout.add_opening(&"bs", Rect2(19.8, 4.0, 0.4, 2.0), 0.0, 3.0, &"b", &"booth_security")
	add_child(level)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.global_position = Vector3(3.0, 1.6, 5.0)
	Ambience.set_active(true)
	Events.night_started.emit(3, &"none")


func after_each() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = false
	Ambience.reset()
	Ambience.enabled = false


func _entry(id: StringName) -> Dictionary:
	return Ambience.story_layer.story.story(id)


func _far_players() -> Array[AudioStreamPlayer3D]:
	var found: Array[AudioStreamPlayer3D] = []
	for child in Ambience.get_children():
		if child is AudioStreamPlayer3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


func test_a_story_plays_in_3d_on_the_ambience_bus_which_the_voice_ducks() -> void:
	Ambience.set_zone(&"egypt")
	var player := Ambience.story_layer.tell(_entry(&"whispers"))
	assert_not_null(player)
	if player == null:
		return
	assert_eq(player.bus, &"Ambience")
	assert_not_null(VoiceDirector.duck_effect(player.bus), "the voice ducks what the story plays")
	assert_eq(player.area_mask, 0, "its space is baked in")
	assert_eq(player.get_meta(&"story"), &"whisper")
	var d := player.global_position.distance_to(camera.global_position)
	assert_true(d > 2.0 and d < 8.0, "whispers come close (%.1f m)" % d)
	var start := player.global_position
	await physics_frames(30)
	assert_gt(player.global_position.distance_to(start), 0.05, "...and move round the guard")


func test_steps_next_door_sound_in_the_next_room() -> void:
	Ambience.set_zone(&"north_hall")
	var player := Ambience.story_layer.tell(_entry(&"phantom_steps"))
	assert_not_null(player)
	if player != null:
		assert_eq(level.room_at(Ambience.story_layer.last_told["at"]), &"b", "in the room next door, not here")


func test_the_radio_plays_on_the_booth_desk_and_nowhere_without_a_booth() -> void:
	Ambience.set_zone(&"booth")
	var player := Ambience.story_layer.tell(_entry(&"radio"))
	assert_not_null(player)
	if player != null:
		assert_eq(level.room_at(Ambience.story_layer.last_told["at"]), &"booth_security")
	level.layout = LevelLayout.new()
	assert_eq(Ambience.story_layer.tell(_entry(&"radio")), null, "a level without the booth")


func test_an_exhibit_shifts_where_it_sleeps_in_its_own_material() -> void:
	var figure := WaxFigure.new()
	figure.position = Vector3(15.0, 0.0, 5.0)
	add_child(figure)
	await physics_frames(2)
	Ambience.set_zone(&"gallery")
	Ambience.story_layer.tell(_entry(&"exhibit_shift"))
	assert_eq(Ambience.story_layer.last_told.get("sound"), &"shift_soft", "wax sounds soft")
	assert_almost_eq((Ambience.story_layer.last_told["at"] as Vector3).x, 15.0, 0.01)
	figure.material_kind = ExhibitMaterial.Kind.MARBLE
	assert_eq(StoryLayer.material_of(figure), "stone")
	figure.material_kind = ExhibitMaterial.Kind.METAL
	assert_eq(StoryLayer.material_of(figure), "metal")
	assert_eq(StoryLayer.material_of(null), "stone", "no exhibit near: a stone one somewhere")
	figure.queue_free()


func test_a_haven_is_quiet_and_its_beds_dip() -> void:
	Ambience.set_zone(&"booth")
	Ambience.advance(Ambience.FADE + 0.1)
	camera.global_position = Vector3(23.0, 1.6, 5.0)
	Ambience.story_layer.tick(Ambience.POLL)
	assert_true(Ambience.story_layer.story.in_haven)
	assert_true(Ambience.story_layer.story.silent())
	Ambience.advance(3.0)
	var dip := float(AmbientStory.data()["silence"]["haven_beds_db"])
	assert_almost_eq(Ambience.dip_db, dip, 0.01)
	var bed := Ambience.players[&"fluorescent"] as AudioStreamPlayer
	assert_almost_eq(bed.volume_db, dip, 0.05, "the beds go down")
	for i in 400:
		Ambience.tick_shots(0.25)
	assert_eq(_far_players().size(), 0, "no far sound in a haven")
	camera.global_position = Vector3(3.0, 1.6, 5.0)
	Ambience.story_layer.tick(Ambience.POLL)
	Ambience.advance(3.0)
	assert_almost_eq(Ambience.dip_db, 0.0, 0.01, "back out: the beds come back")
	for i in 400:
		Ambience.tick_shots(0.25)
	assert_gt(_far_players().size(), 0, "outside, the building stirs again")


func test_the_room_before_a_sleeping_guardian_holds_its_breath() -> void:
	var keeper := GuardianStub.new()
	keeper.arena_room = &"b"
	keeper.position = Vector3(15.0, 0.0, 5.0)
	add_child(keeper)
	Ambience.set_zone(&"assyria")
	Ambience.story_layer.tick(Ambience.POLL)
	assert_eq(Ambience.story_layer.story.guardian, AmbientStory.GUARDIAN_NEAR, "its arena is next door")
	camera.global_position = Vector3(12.0, 1.6, 5.0)
	Ambience.story_layer.tick(Ambience.POLL)
	assert_eq(Ambience.story_layer.story.guardian, AmbientStory.GUARDIAN_ARENA)
	Ambience.advance(4.0)
	assert_almost_eq(Ambience.dip_db, float(AmbientStory.data()["silence"]["guardian_arena_beds_db"]), 0.01)
	keeper.state = Guardian.State.FIGHT
	Ambience.story_layer.tick(Ambience.POLL)
	assert_eq(Ambience.story_layer.story.guardian, AmbientStory.GUARDIAN_NONE, "awake: the music takes over")
	keeper.free()


func test_nothing_starts_under_a_line_of_the_voice() -> void:
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	Events.night_started.emit(1, &"")
	for i in 50:
		VoiceDirector.advance(0.1)
	assert_ne(VoiceDirector.current_line(), &"", "Heniek speaks")
	Ambience.story_layer.tick(Ambience.POLL)
	assert_true(Ambience.story_layer.story.voice)
	assert_true(Ambience.story_layer.story.silent())
	for i in 200:
		Ambience.tick_shots(0.25)
	assert_eq(_far_players().size(), 0, "the far sounds wait for the line")
	assert_almost_eq(VoiceDirector.duck_effect(&"Ambience").volume_db, VoiceDirector.DUCK_AMBIENCE_DB, 0.01,
			"and the ambience is ducked under it as before")


func test_rain_on_a_rainy_night_falls_on_the_court_glass() -> void:
	Ambience.story_layer.raining = true
	Ambience.set_zone(&"court")
	Ambience._process(Ambience.POLL + 0.01)
	assert_true(Ambience.rain)
	assert_almost_eq(Ambience.targets[&"rain_glass"], 1.0, 0.001, "the court's glass roof")
	Ambience.set_zone(&"entrance")
	assert_almost_eq(Ambience.targets[&"rain_glass"], db_to_linear(-14.0), 0.001, "heard through the entrance hall")
	Ambience.set_zone(&"egypt")
	assert_eq(Ambience.targets[&"rain_glass"], 0.0, "not in the stone wings")
	Ambience.story_layer.raining = false
	Ambience.set_zone(&"court")
	Ambience._process(Ambience.POLL + 0.01)
	assert_eq(Ambience.targets[&"rain_glass"], 0.0, "a dry night")


func test_the_clocks_stop_for_a_moment() -> void:
	Ambience.set_zone(&"enlightenment_clocks")
	Ambience.advance(Ambience.FADE * 2.0)
	var clocks := Ambience.players[&"clocks"] as AudioStreamPlayer
	var normal := clocks.volume_db
	Ambience.story_layer.tell(_entry(&"clocks_stop"))
	Ambience.advance(0.3)
	assert_lt(clocks.volume_db, normal - 50.0, "all the clocks stop at once")
	Ambience.advance(float(_entry(&"clocks_stop")["seconds"]) + 0.5)
	assert_almost_eq(clocks.volume_db, normal, 0.05, "and tick on")


func test_the_phase_follows_the_night() -> void:
	var story := Ambience.story_layer.story
	assert_eq(story.phase, AmbientStory.CALM)
	Events.hour_struck.emit(1)
	assert_eq(story.phase, AmbientStory.UNEASY)
	Events.witching_hour.emit()
	assert_eq(story.phase, AmbientStory.WITCHING)
	Events.hour_struck.emit(2)
	assert_eq(story.phase, AmbientStory.WITCHING, "never back within a night")
	Events.hour_struck.emit(5)
	assert_eq(story.phase, AmbientStory.PREDAWN)
	Events.night_started.emit(4, &"none")
	assert_eq(Ambience.story_layer.story.phase, AmbientStory.CALM, "a new night starts calm")


func test_a_guardians_fall_hushes_and_the_dawn_ends_the_story() -> void:
	Events.guardian_defeated.emit(&"colossus")
	assert_true(Ambience.story_layer.story.silent(), "the hall rests after the fall")
	Ambience.set_zone(&"court")
	Events.dawn_broke.emit()
	Ambience.story_layer.tick(Ambience.POLL)
	assert_eq(Ambience.story_layer.story.zone, &"", "after dawn the story is over")
