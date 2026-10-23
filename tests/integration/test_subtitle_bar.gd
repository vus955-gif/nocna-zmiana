extends TestCase

var bar: SubtitleBar


func before_each() -> void:
	bar = SubtitleBar.new()
	add_child(bar)


func after_each() -> void:
	TranslationServer.set_locale("pl")
	Settings.reset_to_defaults(false)


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


# --- Accessibility (plan 2026-10-21-dostepnosc) -------------------------------

## The point size of the line and of the speaker's name.
func _sizes() -> Vector2i:
	return Vector2i(bar._text.get_theme_font_size(&"font_size"), bar._who.get_theme_font_size(&"font_size"))


func test_medium_is_the_size_the_bar_was_designed_in() -> void:
	assert_eq(Settings.data.subtitle_size, SettingsData.SubtitleSize.MEDIUM)
	assert_eq(_sizes(), Vector2i(26, 22))
	assert_eq(bar._text.custom_minimum_size.x, 1100.0)


func test_the_size_option_changes_the_text_live_and_keeps_the_order() -> void:
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	var seen: Array[Vector2i] = []
	for size in [SettingsData.SubtitleSize.SMALL, SettingsData.SubtitleSize.MEDIUM, SettingsData.SubtitleSize.LARGE]:
		Settings.set_value(&"subtitle_size", size, false)
		seen.append(_sizes())
	assert_lt(seen[0].x, seen[1].x, "small < medium")
	assert_lt(seen[1].x, seen[2].x, "medium < large")
	assert_gt(seen[2].x, 34, "large is large (a third more than the design)")
	assert_true(seen[0].y >= Hud.MIN_TEXT and seen[0].x >= Hud.MIN_TEXT, "even small stays at the HUD's smallest text")
	assert_true(bar.is_showing(), "a line in progress goes on")


func test_a_new_bar_starts_in_the_saved_size() -> void:
	Settings.set_value(&"subtitle_size", SettingsData.SubtitleSize.LARGE, false)
	var fresh := SubtitleBar.new()
	add_child(fresh)
	assert_eq(fresh._text.get_theme_font_size(&"font_size"), SubtitleBar.SIZES[SettingsData.SubtitleSize.LARGE]["text"])
	fresh.free()


## A large line still fits the screen (its width is kept to the canvas), is
## centred, stands over the foot BOTTOM and grows up from it.
func test_a_large_line_stays_on_the_screen_centred_and_grows_up() -> void:
	TranslationServer.set_locale("en")
	Settings.set_value(&"subtitle_size", SettingsData.SubtitleSize.LARGE, false)
	bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 20.0)
	var long := tr("VO_GUIDE_ROSETTA_A").left(SubtitleBar.MAX_CHARS)
	bar._parts = PackedStringArray([long + " " + long])
	bar._ends = PackedFloat32Array([20.0])
	for i in 4:
		await get_tree().process_frame
	var view := bar._panel.get_viewport_rect().size
	var rect := bar._panel.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, view).encloses(rect), "the bar %s on the screen %s" % [rect, view])
	assert_almost_eq(rect.get_center().x, view.x * 0.5, 1.0, "centred")
	assert_almost_eq(rect.end.y, view.y - SubtitleBar.BOTTOM, 1.0, "the foot stays put")
	assert_lt(bar._text.get_line_count(), 5, "a line of two parts takes at most four rows")
	Settings.set_value(&"subtitle_size", SettingsData.SubtitleSize.SMALL, false)
	for i in 4:
		await get_tree().process_frame
	assert_lt(bar._panel.get_global_rect().size.x, rect.size.x, "small is narrower than large")


func test_the_backing_is_off_by_default_and_follows_the_option() -> void:
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	await get_tree().process_frame
	assert_false(bar._backing.visible, "no backing by default")
	Settings.set_value(&"subtitle_backing", 0.5, false)
	assert_true(bar._backing.visible)
	assert_almost_eq(bar._backing.color.a, 0.5 * SubtitleBar.BACKING_ALPHA, 0.001, "half of the most it gets")
	assert_eq(Color(bar._backing.color, 1.0), Color.BLACK, "dark")
	Settings.set_value(&"subtitle_backing", 1.0, false)
	assert_almost_eq(bar._backing.color.a, SubtitleBar.BACKING_ALPHA, 0.001)
	Settings.set_value(&"subtitle_backing", 0.0, false)
	assert_false(bar._backing.visible, "and off again")


func test_the_backing_sits_behind_the_plaque_and_a_little_wider() -> void:
	Settings.set_value(&"subtitle_backing", 0.8, false)
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	for i in 3:
		await get_tree().process_frame
	assert_lt(bar._backing.get_index(), bar._panel.get_index(), "drawn before (under) the plaque")
	var back := bar._backing.get_global_rect()
	var plaque := bar._panel.get_global_rect()
	assert_true(back.encloses(plaque), "the backing %s covers the plaque %s" % [back, plaque])
	assert_almost_eq(back.size.x, plaque.size.x + 2.0 * SubtitleBar.BACKING_PAD, 1.0)
	bar.clear_line(&"VO_HENIEK_NIGHT_1")
	assert_false(bar._backing.visible, "no line, no backing")


func test_the_backing_follows_a_line_in_two_rows() -> void:
	TranslationServer.set_locale("en")
	Settings.set_value(&"subtitle_backing", 1.0, false)
	bar.show_line(&"QA_SHORT", &"radio", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var one_row := bar._backing.get_global_rect().size.y
	bar.show_line(&"VO_HENIEK_NIGHT_1", &"radio", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(bar._backing.get_global_rect().size.y, one_row + 20.0, "the backing grows with the plaque")


## Contrast of the line on what it stands on: over white marble the plaque
## alone gives WCAG AA; a full backing gives AAA (7:1) over anything.
func test_the_text_reads_over_white_marble_and_far_better_with_the_backing() -> void:
	var text := UiTheme.TEXT
	var style := bar._panel.get_theme_stylebox(&"panel") as PlaqueStyle
	var plain := UiTheme.contrast(text, UiTheme.over(style.field, Color.WHITE))
	assert_gt(plain, 4.5, "plaque alone over marble: %.1f:1" % plain)
	var backed_ground := UiTheme.over(style.field, UiTheme.over(Color(Color.BLACK, SubtitleBar.BACKING_ALPHA), Color.WHITE))
	var backed := UiTheme.contrast(text, backed_ground)
	assert_gt(backed, 7.0, "with the full backing over marble: %.1f:1" % backed)
	assert_gt(backed, plain, "the backing helps")


## The speaker is told by the name printed on the plaque as well as by its
## colour: every voice has its own label (no two alike), never empty.
func test_every_voice_is_named_on_the_plaque_not_only_coloured() -> void:
	var names := {}
	for channel in SubtitleBar.LABELS:
		bar.show_line(&"QA_SHORT", channel, 10.0)
		var shown := bar.speaker_text()
		assert_ne(shown.strip_edges(), "", "%s is named" % channel)
		assert_false(names.has(shown), "'%s' is used by two voices" % shown)
		names[shown] = channel
	assert_eq(names.size(), SubtitleBar.LABELS.size())


## Both languages name them (a missing translation would print the key).
func test_the_voices_have_names_in_both_languages() -> void:
	for locale in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for channel in SubtitleBar.LABELS:
			bar.show_line(&"QA_SHORT", channel, 10.0)
			assert_false(bar.speaker_text().begins_with("VOICE_"), "%s in %s: '%s'" % [channel, locale, bar.speaker_text()])
