extends TestCase
## Shots and blasts ring in their room (plan 2026-10-21-akustyka-ambient):
## the guard's own shot gets the tail of the room he stands in (flat, on
## SFXReturn), a positional blast the tail of the room it bursts in (3D, at
## the blast); throttled, a few at a time; nothing outside every reverb zone.

var camera: Camera3D


func before_each() -> void:
	Ambience.reset()
	Ambience.enabled = true
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0.0, 1.6, 0.0)


func after_each() -> void:
	Sfx.stop_all()
	Ambience.reset()
	Ambience.enabled = false


func _zone(preset: ReverbZone.Preset, box: AABB) -> ReverbZone:
	var zone := ReverbZone.make(preset, box)
	add_child(zone)
	return zone


func _tails() -> Array[Node]:
	return Ambience.acoustics.tails()


func test_a_shot_in_the_court_rings_long_and_in_a_storeroom_claps() -> void:
	var court := _zone(ReverbZone.Preset.VAST, AABB(Vector3(-20, -1, -20), Vector3(40, 20, 40)))
	Sfx.play(&"pistol")
	assert_eq(_tails().size(), 1, "the shot's tail")
	if _tails().size() == 1:
		var tail := _tails()[0] as AudioStreamPlayer
		assert_not_null(tail, "the guard's tail is flat")
		assert_eq(tail.get_meta(&"tail"), &"vast_crack")
		assert_eq(tail.bus, &"SFXReturn", "beside the SFX bus: not through the listener's reverb again")
		assert_almost_eq(tail.volume_db, float(Acoustics.profile(&"vast")["tail_db"]), 0.001)
	court.free()
	_zone(ReverbZone.Preset.STORE, AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4)))
	Ambience.advance(1.0)
	Sfx.play(&"shotgun")
	var last := _tails()[-1]
	assert_eq(last.get_meta(&"tail"), &"store_boom", "a shotgun in a storeroom")
	var court_tail := load(Acoustics.TAIL_DIR + "tail_vast_crack.ogg") as AudioStream
	assert_gt(court_tail.get_length(), ((last as AudioStreamPlayer).stream as AudioStream).get_length() * 4.0)


func test_no_room_no_tail() -> void:
	Sfx.play(&"pistol")
	assert_eq(_tails().size(), 0, "outside every reverb zone (sandbox, menus)")
	Sfx.play(&"reload")
	_zone(ReverbZone.Preset.HALL, AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20)))
	Sfx.play(&"reload")
	assert_eq(_tails().size(), 0, "a reload rings nowhere")
	Sfx.play_ui(&"ui_confirm")
	assert_eq(_tails().size(), 0)


func test_a_quieter_shot_has_a_quieter_tail() -> void:
	_zone(ReverbZone.Preset.HALL, AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20)))
	Sfx.play(&"pistol", -6.0)
	assert_eq(_tails().size(), 1)
	if _tails().size() == 1:
		assert_almost_eq((_tails()[0] as AudioStreamPlayer).volume_db, float(Acoustics.profile(&"hall")["tail_db"]) - 6.0, 0.001)


func test_tails_are_throttled_and_few() -> void:
	_zone(ReverbZone.Preset.HALL, AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20)))
	Sfx.play(&"pistol")
	Sfx.play(&"pistol")
	assert_eq(_tails().size(), 1, "two shots in one moment: one tail")
	var cap := int(Acoustics.data()["tail_voices"])
	for i in cap + 4:
		Ambience.advance(float(Acoustics.data()["tail_gap"]) + 0.01)
		Sfx.play(&"pistol")
	assert_eq(_tails().size(), cap, "at most tail_voices at once")


func test_a_blast_rings_in_its_own_room() -> void:
	_zone(ReverbZone.Preset.STORE, AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6)))
	_zone(ReverbZone.Preset.GALLERY, AABB(Vector3(10, -1, -5), Vector3(20, 8, 10)))
	Sfx.play_at(&"flare_blast", Vector3(18.0, 0.5, 0.0))
	assert_eq(_tails().size(), 1)
	if _tails().size() == 1:
		var tail := _tails()[0] as AudioStreamPlayer3D
		assert_not_null(tail, "a positional tail")
		assert_eq(tail.get_meta(&"tail"), &"gallery_blast", "the gallery's tail, not the storeroom's")
		assert_almost_eq(tail.global_position.x, 18.0, 0.01)
		assert_eq(tail.area_mask, 0, "the tail is the room: no zone reverb on top")
		assert_eq(tail.bus, &"SFXReturn")


func test_a_positional_tail_never_swells_up_close() -> void:
	# AudioStreamPlayer3D boosts a near source above its level (max_db defaults
	# to +3 dB): a room's tail must stay at the level the data gave it.
	_zone(ReverbZone.Preset.HALL, AABB(Vector3(-5, -1, -5), Vector3(10, 4, 10)))
	Sfx.play_at(&"flare_blast", Vector3(0.5, 1.0, 0.0))
	assert_eq(_tails().size(), 1)
	if _tails().size() == 1:
		var tail := _tails()[0] as AudioStreamPlayer3D
		assert_not_null(tail, "a positional tail")
		assert_true(tail.max_db <= 0.0, "no near-field boost on a tail (max_db %s)" % tail.max_db)


func test_the_gatling_rings_through_weapon_fired() -> void:
	_zone(ReverbZone.Preset.CONCRETE, AABB(Vector3(-10, -1, -10), Vector3(20, 5, 20)))
	Events.weapon_fired.emit(&"gatling")
	Events.weapon_fired.emit(&"gatling")
	assert_eq(_tails().size(), 1, "its own pace")
	if _tails().size() == 1:
		assert_eq(_tails()[0].get_meta(&"tail"), &"concrete_crack")
	Ambience.advance(0.2)
	Events.weapon_fired.emit(&"gatling")
	assert_eq(_tails().size(), 2)
	Events.weapon_fired.emit(&"pistol")
	assert_eq(_tails().size(), 2, "the pistol rings through its sound, not here")


func test_off_in_test_runs_and_gone_with_the_scene() -> void:
	_zone(ReverbZone.Preset.HALL, AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20)))
	Ambience.enabled = false
	Sfx.play(&"pistol")
	Events.weapon_fired.emit(&"gatling")
	assert_eq(_tails().size(), 0)
	Ambience.enabled = true
	Sfx.play(&"pistol")
	assert_eq(_tails().size(), 1)
	Ambience.stop_all()
	assert_eq(_tails().size(), 0)
