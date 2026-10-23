extends TestCase
## Room acoustics as data (data/audio/acoustics.json, plan
## 2026-10-21-akustyka-ambient): every profile has its reverb preset and bus
## with the file's settings, the occlusion buses exist, every room of Floor I
## gets a profile that suits its space.


func test_every_profile_names_a_preset_and_every_preset_has_a_profile() -> void:
	var seen := {}
	for id in Acoustics.profiles():
		var preset := Acoustics.preset_of(id)
		assert_true(preset >= 0, "%s names a ReverbZone preset" % id)
		assert_eq(Acoustics.profile_of_preset(preset), id)
		seen[preset] = true
	for preset: int in ReverbZone.BUSES:
		assert_true(seen.has(preset), "preset %d has a profile" % preset)
		assert_true(ReverbZone.AMOUNTS.has(preset) and ReverbZone.LISTENER.has(preset), "preset %d is complete" % preset)


func test_the_new_spaces_have_presets() -> void:
	assert_eq(Acoustics.preset_of(&"store"), ReverbZone.Preset.STORE)
	assert_eq(Acoustics.preset_of(&"steel"), ReverbZone.Preset.STEEL)
	assert_eq(Acoustics.preset_of(&"open"), ReverbZone.Preset.OPEN)


func test_every_reverb_bus_carries_its_profile() -> void:
	for id in Acoustics.profiles():
		var bus := AudioServer.get_bus_index(ReverbZone.BUSES[Acoustics.preset_of(id)])
		assert_true(bus >= 0, "%s has its bus" % id)
		if bus < 0:
			continue
		assert_eq(AudioServer.get_bus_send(bus), &"SFXReturn", "%s: tails return beside the SFX bus" % id)
		var reverb := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
		assert_not_null(reverb, "%s: a reverb first" % id)
		if reverb == null:
			continue
		var wanted: Dictionary = Acoustics.profile(id)["bus"]
		for key: String in wanted:
			assert_almost_eq(float(reverb.get(key)), float(wanted[key]), 0.0001, "%s.%s from the data" % [id, key])
		assert_eq(reverb.dry, 0.0, "%s: wet only" % id)


func test_a_big_hall_rings_longer_than_a_storeroom() -> void:
	var tails := {}
	for id in Acoustics.profiles():
		tails[id] = float(Acoustics.profile(id)["tail"]["rt60"])
	assert_gt(tails[&"vast"], tails[&"hall"])
	assert_gt(tails[&"hall"], tails[&"room"])
	assert_gt(tails[&"room"], tails[&"store"])
	assert_gt(tails[&"steel"], tails[&"library"], "steel rings, books soak it up")
	assert_gt(float(Acoustics.profile(&"vast")["tail_db"]), float(Acoustics.profile(&"store")["tail_db"]), "a big hall's tail is louder")


func test_the_occlusion_buses_filter_into_the_sfx_bus() -> void:
	var last_cutoff := INF
	var last_gain := 0.0
	for level: Dictionary in Acoustics.data()["occlusion"]:
		var bus := AudioServer.get_bus_index(StringName(level["bus"]))
		assert_true(bus >= 0, String(level["bus"]))
		if bus < 0:
			continue
		assert_eq(AudioServer.get_bus_send(bus), &"SFX", "the SFX slider covers it")
		assert_almost_eq(AudioServer.get_bus_volume_db(bus), float(level["gain_db"]), 0.001)
		var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
		assert_not_null(filter, "a low-pass first")
		if filter != null:
			assert_almost_eq(filter.cutoff_hz, float(level["cutoff_hz"]), 0.01)
			assert_lt(filter.cutoff_hz, last_cutoff, "more walls, darker")
			last_cutoff = filter.cutoff_hz
		assert_lt(float(level["gain_db"]), last_gain, "more walls, quieter")
		last_gain = float(level["gain_db"])


func test_the_room_table_names_real_rooms_and_every_room_has_a_profile() -> void:
	var layout := Floor1Layout.create()
	var ids := {}
	for room in layout.rooms:
		ids[room.id] = true
		assert_ne(Acoustics.profile_of_room(room.id, room.zone), &"", "%s has a profile" % room.id)
	for room_id: String in Acoustics.data()["rooms"]:
		assert_true(ids.has(StringName(room_id)), "the table's %s is a room of Floor I" % room_id)
		var entry: Array = Acoustics.data()["rooms"][room_id]
		assert_true(Acoustics.profiles().has(StringName(entry[0])), "%s: known profile %s" % [room_id, entry[0]])


func test_rooms_sound_like_their_space() -> void:
	var expected := {
		&"court": &"vast", &"enlightenment_planetarium": &"vast", &"entrance_hall": &"hall", &"greece_parthenon": &"hall",
		&"egypt_gallery": &"gallery", &"north_hall": &"gallery", &"asia_korea": &"room", &"booth_security": &"store",
		&"entrance_cloakroom": &"store", &"egypt_tomb_passage": &"corridor", &"enlightenment_library": &"library",
		&"basement_corridor_north": &"concrete", &"basement_boiler": &"steel", &"asia_garden": &"garden", &"roof_catwalks": &"open",
	}
	for room: StringName in expected:
		assert_eq(Acoustics.profile_of_room(room, &""), expected[room], String(room))


func test_reverb_for_reads_the_table_before_the_words_and_zones() -> void:
	var roof: Array = Ambience.reverb_for(&"roof_catwalks", &"roof")
	assert_eq(roof[0], ReverbZone.Preset.OPEN)
	assert_almost_eq(float(roof[1]), 0.15, 0.0001)
	assert_eq(Ambience.reverb_for(&"basement_boiler", &"basement")[0], ReverbZone.Preset.STEEL)
	assert_eq(Ambience.reverb_for(&"hall")[0], ReverbZone.Preset.HALL, "the lobby keeps its own map")
	assert_eq(Ambience.reverb_for(&"some_new_store", &"greece")[0], ReverbZone.Preset.STORE, "a new storeroom by its name")
	assert_eq(Ambience.reverb_for(&"some_new_room", &"roof")[0], ReverbZone.Preset.OPEN, "a new roof room by its zone")
	assert_eq(Ambience.reverb_for(&"some_new_room", &"egypt")[0], ReverbZone.Preset.GALLERY)


func test_shots_and_blasts_name_a_tail_class() -> void:
	var classes: Dictionary = Acoustics.data()["tail_classes"]
	for sound: String in Acoustics.data()["tails"]:
		assert_true(Sfx.SOUNDS.has(StringName(sound)), "%s is a sound of Sfx" % sound)
		assert_true(classes.has(Acoustics.tail_of(StringName(sound))[0]), "%s: known tail class" % sound)
	assert_eq(Acoustics.tail_of(&"pistol")[0], "crack")
	assert_eq(Acoustics.tail_of(&"shotgun")[0], "boom")
	assert_eq(Acoustics.tail_of(&"flare_blast")[0], "blast")
	assert_true(Acoustics.tail_of(&"reload").is_empty(), "a reload rings nowhere")


func test_every_room_tail_is_there_and_plays_once() -> void:
	for id in Acoustics.profiles():
		for kind: String in Acoustics.data()["tail_classes"]:
			var path := Acoustics.TAIL_DIR + "tail_%s_%s.ogg" % [id, kind]
			assert_true(ResourceLoader.exists(path), path)
			if ResourceLoader.exists(path):
				var stream := load(path) as AudioStreamOggVorbis
				assert_false(stream.loop, path + " plays once")
				assert_gt(stream.get_length(), 0.3)
	var vast := load(Acoustics.TAIL_DIR + "tail_vast_crack.ogg") as AudioStream
	var store := load(Acoustics.TAIL_DIR + "tail_store_crack.ogg") as AudioStream
	assert_gt(vast.get_length(), store.get_length() * 4.0, "the court rings, the storeroom claps")


func test_a_tail_freed_while_it_was_listed_is_dropped_without_an_error() -> void:
	# a standalone Acoustics (no Ambience): a tail player can be gone before
	# the list is next tidied (freed with its scene, or finished and freed);
	# tidying must drop it, not fail on the freed object (SCRIPT ERROR)
	var acoustics := Acoustics.new()
	add_child(acoustics)
	var first := acoustics.play_tail("crack", &"hall", 0.0)
	assert_not_null(first, "a hall's crack plays")
	if first == null:
		return
	first.free()
	assert_eq(acoustics.tails().size(), 0, "the freed tail is not listed")
	acoustics.advance(float(Acoustics.data()["tail_gap"]) + 0.01)
	var second := acoustics.play_tail("crack", &"hall", 0.0)
	assert_not_null(second, "the next tail plays")
	assert_eq(acoustics.tails(), [second] as Array[Node], "only the one playing")
	acoustics.stop_all()
	acoustics.free()
