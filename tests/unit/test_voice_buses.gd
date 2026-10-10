extends TestCase


func test_voice_has_its_buses_under_the_master() -> void:
	for bus in [&"Voice", &"VoiceRadio", &"VoiceSystem"]:
		assert_gt(AudioServer.get_bus_index(bus), 13, "%s comes after the reverb buses" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Voice")), &"Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VoiceRadio")), &"Voice")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"VoiceSystem")), &"Voice")


func test_the_radio_bus_sounds_like_a_walkie_talkie() -> void:
	var index := AudioServer.get_bus_index(&"VoiceRadio")
	var kinds: Array[String] = []
	for i in AudioServer.get_bus_effect_count(index):
		kinds.append(AudioServer.get_bus_effect(index, i).get_class())
	assert_true(kinds.has("AudioEffectHighPassFilter") and kinds.has("AudioEffectLowPassFilter"), str(kinds))
	assert_true(kinds.has("AudioEffectDistortion"), str(kinds))


func test_music_and_ambience_have_a_duck_effect_at_zero() -> void:
	for bus in [&"Music", &"Ambience"]:
		var effect := VoiceDirector.duck_effect(bus)
		assert_not_null(effect, "%s has VoiceDuck" % bus)
		if effect:
			assert_almost_eq(effect.volume_db, 0.0)


func test_the_voice_volume_drives_the_voice_bus() -> void:
	assert_eq(SettingsData.VOLUME_BUSES[&"volume_voice"], &"Voice")
	Settings.set_value(&"volume_voice", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")))
	Settings.set_value(&"volume_voice", 1.0)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Voice")))


func test_subtitles_are_on_by_default() -> void:
	assert_true(SettingsData.new().subtitles)


func test_the_radio_clicks_exist() -> void:
	for sound in [&"radio_click_in", &"radio_click_out"]:
		assert_not_null(Sfx.stream_of(sound), String(sound))
		assert_lt(Sfx.stream_of(sound).get_length(), 0.4)
