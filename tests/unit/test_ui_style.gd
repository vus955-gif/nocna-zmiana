extends TestCase
## The house style's parts (plan 2026-10-19-styl-hud): one serif of the
## museum's century with lining figures, the plaque's cut-corner geometry,
## the contrast rule, the brass instruments' trail and pulse.


func _names(font: Font) -> PackedStringArray:
	var base := font
	while base is FontVariation:
		base = (base as FontVariation).base_font
	return (base as SystemFont).font_names if base is SystemFont else PackedStringArray()


func test_the_text_the_numbers_and_the_labels_are_the_museums_serif() -> void:
	for font in [UiTheme.body_font(), UiTheme.strong_font(), UiTheme.number_font(), UiTheme.italic_font(), UiTheme.spaced_font(4), UiTheme.title_font(), UiTheme.small_caps_font(2)]:
		assert_eq(_names(font)[0], "Georgia", "a 19th-century Scotch Roman: %s" % str(font))
	assert_eq(_names(UiTheme.device_font())[0], "Bahnschrift", "the CCTV keeps its security monitor's sans")


## Georgia's figures are old-style by default ("23:47" would bob up and
## down): every face the HUD writes numbers with asks for lining ones.
func test_numbers_are_set_in_lining_figures() -> void:
	for font in [UiTheme.body_font(), UiTheme.strong_font(), UiTheme.italic_font(), UiTheme.spaced_font(6), UiTheme.spaced_title_font(12), UiTheme.small_caps_font(2)]:
		var variation := font as FontVariation
		assert_not_null(variation)
		if variation != null:
			assert_eq(int(variation.opentype_features.get("lnum", 0)), 1, "lining figures in %s" % str(font))


## The figures really change: shaped with the variation, "0369" uses other
## glyphs than the plain face's old-style ones.
func test_the_lining_feature_reaches_the_glyphs() -> void:
	var ts := TextServerManager.get_primary_interface()
	var glyphs := func(font: Font) -> Array:
		var line := TextLine.new()
		line.add_string("0369", font, 30)
		var out := []
		for glyph in ts.shaped_text_get_glyphs(line.get_rid()):
			out.append(glyph["index"])
		return out
	var plain := (UiTheme.strong_font() as FontVariation).base_font
	assert_ne(glyphs.call(UiTheme.number_font()), glyphs.call(plain), "lining, not old-style")
	assert_ne(glyphs.call(UiTheme.spaced_font(6)), glyphs.call(plain), "the spaced capitals too")


func test_the_plaques_corners_are_cut_at_45_degrees() -> void:
	var points := PlaqueStyle.octagon(Rect2(10, 20, 100, 40), 8.0)
	assert_eq(points.size(), 8)
	assert_eq(points[0], Vector2(18, 20))
	assert_eq(points[2], Vector2(110, 28))
	assert_eq(points[4], Vector2(102, 60))
	assert_eq(points[7], Vector2(10, 28))
	# a rule inset by d keeps its diagonal parallel: the leg shortens by d * (2 - sqrt 2)
	assert_almost_eq(PlaqueStyle.inset_cut(8.0, 2.0), 8.0 - 2.0 * (2.0 - sqrt(2.0)), 0.01)
	assert_eq(PlaqueStyle.inset_cut(1.0, 5.0), 0.0, "never negative")
	assert_eq(PlaqueStyle.octagon(Rect2(0, 0, 10, 6), 20.0)[0], Vector2(3, 0), "a cut never longer than half the short side")


func test_every_plaque_variant_draws_and_keeps_its_margins() -> void:
	var host := Control.new()
	add_child(host)
	host.size = Vector2(400, 120)
	for kind in UiTheme.Plaque.values():
		var style := UiTheme.plaque(kind)
		assert_true(style is PlaqueStyle)
		assert_gt(style.get_margin(SIDE_LEFT), 0.0, "content inside the rule (%d)" % kind)
		style.draw(host.get_canvas_item(), Rect2(Vector2.ZERO, host.size))
		style.draw(host.get_canvas_item(), Rect2(0, 0, 3, 3))   # degenerate: nothing, no error
	var panel := UiTheme.panel_style(40.0)
	assert_eq(panel.get_margin(SIDE_TOP), 40.0)
	assert_true(panel.rivets, "a menu's plaque is riveted")
	var copy := panel.duplicate() as PlaqueStyle
	assert_eq(copy.cut, panel.cut, "a copy keeps the shape")
	host.free()


func test_contrast_follows_the_wcag_formula() -> void:
	assert_almost_eq(UiTheme.contrast(Color.WHITE, Color.BLACK), 21.0, 0.01)
	assert_almost_eq(UiTheme.contrast(Color.BLACK, Color.WHITE), 21.0, 0.01)
	assert_almost_eq(UiTheme.contrast(Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5)), 1.0, 0.001)
	assert_eq(UiTheme.over(Color(1, 0, 0, 0.5), Color.BLACK), Color(0.5, 0, 0, 1))


## The house colours keep their roles readable on the enamel even where it
## lies over white marble (the worst case) - text at least 4.5:1 (WCAG AA),
## the bars' fills at least 3:1 against their channel.
func test_the_house_colours_read_on_the_enamel_over_marble() -> void:
	var enamel := UiTheme.over(UiTheme.ENAMEL, Color.WHITE)
	for color in [UiTheme.TEXT, UiTheme.MUTED, UiTheme.ACCENT, UiTheme.DANGER, UiTheme.MOON, UiTheme.DUST, UiTheme.GOOD]:
		assert_gt(UiTheme.contrast(color, enamel), 4.5, "%s on the enamel over marble" % str(color))
	var channel := UiTheme.over(UiTheme.CHANNEL, Color.WHITE)
	for fill in [UiTheme.EMERGENCY, Hud.StaminaBar.FILL, Hud.StaminaBar.EXHAUSTED, Hud.StaminaBar.CAFFEINE, UiTheme.MOON]:
		assert_gt(UiTheme.contrast(fill, channel), 3.0, "the fill %s in its channel" % str(fill))


## A boss bar shows each fall twice: the fill drops at once, a pale trail
## holds a moment and then catches up (rises never trail).
func test_a_fall_leaves_a_trail_that_catches_up() -> void:
	var gauge := HudGauge.make(Vector2(300, 20), UiTheme.EMERGENCY)
	gauge.trail = true
	add_child(gauge)
	gauge.value = 0.6
	assert_almost_eq(gauge.trail_value(), 1.0, 0.001, "the trail stays where the fill was")
	gauge._process(HudGauge.TRAIL_HOLD * 0.5)
	assert_almost_eq(gauge.trail_value(), 1.0, 0.001, "it holds first")
	for i in 120:
		gauge._process(1.0 / 60.0)
	assert_lt(gauge.trail_value(), 1.0, "then it follows")
	for i in 120:
		gauge._process(1.0 / 60.0)
	assert_almost_eq(gauge.trail_value(), 0.6, 0.001, "and meets the fill")
	gauge.value = 0.9
	assert_almost_eq(gauge.trail_value(), 0.9, 0.001, "a rise does not trail")
	var plain := HudGauge.make(Vector2(300, 20), UiTheme.EMERGENCY)
	add_child(plain)
	plain.value = 0.3
	assert_almost_eq(plain.trail_value(), 0.3, 0.001, "no trail unless asked")
	gauge.free()
	plain.free()


func test_a_low_value_pulses_the_mount() -> void:
	var gauge := HudGauge.make(Vector2(300, 20), UiTheme.EMERGENCY)
	gauge.low_pulse = 0.3
	add_child(gauge)
	gauge.value = 0.5
	var seen := 0.0
	for i in 60:
		gauge._process(1.0 / 60.0)
		seen = maxf(seen, gauge.pulse())
	assert_eq(seen, 0.0, "healthy: still")
	gauge.value = 0.2
	for i in 60:
		gauge._process(1.0 / 60.0)
		seen = maxf(seen, gauge.pulse())
	assert_gt(seen, 0.8, "low: the mount pulses")
	gauge.value = 0.0
	assert_eq(gauge.pulse(), 0.0, "empty: nothing left to warn about")
	gauge.free()


func test_the_icons_draw_every_kind() -> void:
	for kind in UiIcons.Kind.values():
		var icon := UiIcons.make(kind, UiTheme.BRASS)
		add_child(icon)
		assert_eq(icon.custom_minimum_size, Vector2(UiIcons.BOX, UiIcons.BOX))
		icon.queue_redraw()
	await get_tree().process_frame
	for child in get_children():
		if child is UiIcons:
			child.free()
