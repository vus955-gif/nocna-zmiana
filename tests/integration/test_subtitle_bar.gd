extends TestCase

var bar: SubtitleBar


func before_each() -> void:
	bar = SubtitleBar.new()
	add_child(bar)


func after_each() -> void:
	TranslationServer.set_locale("pl")


func test_a_line_shows_who_speaks_and_what_in_the_game_language() -> void:
	TranslationServer.set_locale("pl")
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_true(bar.is_showing())
	assert_eq(bar.speaker_text(), tr("VOICE_SPEAKER_HENIEK"))
	assert_true(tr("VO_HENIEK_NIGHT_1").begins_with(bar.current_text().substr(0, 10)))
	assert_true(bar.current_text().begins_with("Młody?"))
	TranslationServer.set_locale("en")
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_true(bar.current_text().begins_with("Kid?"))


func test_the_system_and_the_guide_have_their_own_labels_and_colour() -> void:
	bar.show_line(&"VO_SYSTEM_CLOSING_1", &"pa", 10.0)
	assert_eq(bar.speaker_text(), tr("VOICE_SPEAKER_SYSTEM"))
	var system_colour := bar.speaker_colour()
	bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 10.0)
	assert_eq(bar.speaker_text(), tr("VOICE_SPEAKER_GUIDE"))
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_ne(bar.speaker_colour(), system_colour, "Heniek is warm, the System cold")


func test_long_lines_come_in_parts_timed_by_length() -> void:
	var parts := SubtitleBar.split("One two three. Four five six seven. Eight nine.", 20)
	assert_eq(parts.size(), 3)
	assert_eq(parts[0], "One two three.")
	var ends := SubtitleBar.timings(parts, 9.0)
	assert_almost_eq(ends[ends.size() - 1], 9.0, 0.001)
	assert_true(ends[0] < ends[1] and ends[1] < ends[2])
	assert_eq(SubtitleBar.split("Short.", 20), PackedStringArray(["Short."]))
	assert_eq(SubtitleBar.split("One two three. Four five.", 200).size(), 1, "fits in one part")


func test_the_bar_follows_the_parts_and_hides_at_the_end() -> void:
	bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 12.0)
	var first := bar.current_text()
	bar.advance(11.0)
	assert_ne(bar.current_text(), first, "a later part")
	bar.clear_line(&"VO_HENIEK_NIGHT_1")
	assert_true(bar.is_showing(), "another line's end does not clear this one")
	bar.clear_line(&"VO_GUIDE_ROSETTA_A")
	assert_false(bar.is_showing())


func test_subtitles_off_hides_the_bar() -> void:
	Settings.set_value(&"subtitles", false)
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_false(bar.is_showing())
	Settings.set_value(&"subtitles", true)


func test_the_director_feeds_its_own_bar() -> void:
	var own: SubtitleBar = null
	for child in VoiceDirector.get_children():
		if child is SubtitleBar:
			own = child
	assert_not_null(own, "VoiceDirector carries a SubtitleBar")
	if own == null:
		return
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	Events.night_started.emit(1, &"")
	for i in 50:
		VoiceDirector.advance(0.1)
	assert_true(own.is_showing())
	assert_eq(own.speaker_text(), tr("VOICE_SPEAKER_HENIEK"))
	VoiceDirector.reset()
	VoiceDirector.enabled = false
	assert_false(own.is_showing(), "a reset clears the bar")


func test_toggling_subtitles_mid_line_takes_effect_at_once() -> void:
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	assert_true(bar.is_showing())
	Settings.set_value(&"subtitles", false)
	assert_false(bar.is_showing(), "off: hidden at once")
	Settings.set_value(&"subtitles", true)
	assert_true(bar.is_showing(), "on again: the line is still up")
	bar.clear_line(&"VO_HENIEK_NIGHT_1")
	Settings.set_value(&"subtitles", false)
	Settings.set_value(&"subtitles", true)
	assert_false(bar.is_showing(), "no line: nothing to show")
