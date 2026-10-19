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


## (The night's QA, 19.10, in the window: a line long enough for two rows
## grew the bar downward over the HUD's hint strip under it.)
func test_a_line_in_two_rows_grows_the_bar_upward_and_keeps_it_centred() -> void:
	TranslationServer.set_locale("en")
	bar.show_line(&"QA_SHORT", &"radio", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var view := bar._panel.get_viewport_rect().size
	var one_row := bar._panel.get_global_rect()
	assert_almost_eq(one_row.end.y, view.y - SubtitleBar.BOTTOM, 1.0, "one row: the bar's foot %d px over the bottom" % SubtitleBar.BOTTOM)
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var two_rows := bar._panel.get_global_rect()
	assert_gt(two_rows.size.y, one_row.size.y + 20.0, "the long line takes two rows")
	assert_almost_eq(two_rows.end.y, view.y - SubtitleBar.BOTTOM, 1.0, "two rows: the foot stays put, the bar grows up")
	assert_almost_eq(two_rows.get_center().x, view.x * 0.5, 1.0, "centred")
	bar.show_line(&"QA_SHORT", &"radio", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(bar._panel.get_global_rect().size.y, one_row.size.y, 1.0, "back to one row: the bar shrinks again")


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


func test_during_dawn_the_bar_sits_above_the_dawn_card() -> void:
	var own: SubtitleBar = null
	for child in VoiceDirector.get_children():
		if child is SubtitleBar:
			own = child
	assert_not_null(own, "VoiceDirector carries a SubtitleBar")
	if own == null:
		return
	var dawn := DawnScreen.new()
	add_child(dawn)
	VoiceDirector.reset()
	VoiceDirector.enabled = true
	Events.night_started.emit(1, &"")
	Events.dawn_broke.emit()
	for i in 3:
		VoiceDirector.advance(0.1)
	assert_true(own.is_showing(), "the dawn line is on air")
	assert_gt(own.layer, dawn.layer, "the dawn card's veil does not cover the line's end")
	VoiceDirector.reset()
	assert_eq(own.layer, SubtitleBar.LAYER, "back under the menus once the night is over")
	VoiceDirector.enabled = false
