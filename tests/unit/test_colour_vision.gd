extends TestCase
## The colour-blind palettes (ColourVision, plan 2026-10-21-dostepnosc
## section 4), checked by the same numbers they were chosen by: Machado et
## al. 2009 simulation in linear RGB, CIE76 dE after it, WCAG contrast seen
## through it. The weapon colours of every mode stay apart as the player of
## that mode sees them (and for everybody else at the table), apart from
## the white medkit, legible on the HUD's enamel, and still their weapon's
## colour; the HUD's roles read apart in each group and the bars stand out
## of their channel.

const MODES_CVD: Array[int] = [ColourVision.DEUTERANOPIA, ColourVision.PROTANOPIA, ColourVision.TRITANOPIA]
## Smallest dE of two weapon colours (with the medkit) in a mode's own
## palette seen in that mode / seen normally, and of the standard palette.
const MIN_OWN := 25.0
const MIN_NORMAL := 18.0
## Every pair of a HUD role group seen in its mode (two fixed colours that
## only the shape parts excepted), and the bars against their channel.
const MIN_ROLE := 40.0
const MIN_BAR_CONTRAST := 3.0
## Text (the slot digits) on the enamel.
const MIN_TEXT_CONTRAST := 4.5
## Hue window round the standard colour (degrees).
const HUE_WINDOW := 30.0
## The HUD's enamel and its bars' channel, opaque (UiTheme; alpha left out).
const ENAMEL := Color(0.05, 0.043, 0.036)
const CHANNEL := Color(0.025, 0.02, 0.018)


func _palette(mode: int) -> Dictionary:
	var out := {}
	for id: StringName in WeaponPalette.COLORS:
		out[id] = ColourVision.weapon(id, WeaponPalette.COLORS[id], mode)
	out[&"medkit"] = WeaponPalette.MEDKIT_COLOR
	return out


## [smallest dE, pair] of the colours of [param palette] seen in [param seen].
func _closest(palette: Dictionary, seen: int) -> Array:
	var keys := palette.keys()
	var best := INF
	var pair := ""
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var d := ColourVision.delta_e(palette[keys[i]], palette[keys[j]], seen)
			if d < best:
				best = d
				pair = "%s/%s" % [keys[i], keys[j]]
	return [best, pair]


func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


func test_the_simulation_matches_the_tools_measurements() -> void:
	# tools/accessibility/cvd.py measured the standard palette (with the medkit): 22.0 / 14.4 / 2.4 / 5.2
	var standard := _palette(ColourVision.NORMAL)
	assert_almost_eq(_closest(standard, ColourVision.NORMAL)[0], 22.0, 0.1, "normal vision")
	assert_almost_eq(_closest(standard, ColourVision.DEUTERANOPIA)[0], 14.4, 0.1, "deuteranopia")
	assert_almost_eq(_closest(standard, ColourVision.PROTANOPIA)[0], 2.4, 0.1, "protanopia")
	assert_almost_eq(_closest(standard, ColourVision.TRITANOPIA)[0], 5.2, 0.1, "tritanopia")
	# fixed points: black and white are seen as they are; a pure red loses most of its light without L cones
	for mode in ColourVision.MODES:
		assert_lt(ColourVision.delta_e(Color.WHITE, ColourVision.simulate(Color.WHITE, mode)), 1.0, "white stays white (%d)" % mode)
		assert_lt(ColourVision.delta_e(Color.BLACK, ColourVision.simulate(Color.BLACK, mode)), 0.01, "black stays black (%d)" % mode)
	assert_lt(ColourVision.luminance(ColourVision.simulate(Color.RED, ColourVision.PROTANOPIA)), ColourVision.luminance(Color.RED), "protanopia darkens red")
	assert_almost_eq(ColourVision.lab(Color.WHITE).x, 100.0, 0.01, "L* of white")
	assert_almost_eq(ColourVision.contrast_seen(Color.WHITE, Color.BLACK), 21.0, 0.01, "WCAG's 21:1")


func test_the_matrices_are_machados() -> void:
	# a pure primary seen through a mode is that matrix's column (Machado et al. 2009, Table 1, severity 1.0;
	# negative entries clamp to 0), so a typo in any positive entry shows here...
	var columns := {
		ColourVision.PROTANOPIA: [Vector3(0.152286, 0.114503, 0.0), Vector3(1.0, 0.786281, 0.0), Vector3(0.0, 0.099216, 1.0)],
		ColourVision.DEUTERANOPIA: [Vector3(0.367322, 0.280085, 0.0), Vector3(0.860646, 0.672501, 0.042940), Vector3(0.0, 0.047413, 0.968881)],
		ColourVision.TRITANOPIA: [Vector3(1.0, 0.0, 0.004733), Vector3(0.0, 0.930809, 0.691367), Vector3(0.0, 0.147602, 0.303900)],
	}
	var primaries := [Color.RED, Color(0.0, 1.0, 0.0), Color.BLUE]
	for mode: int in columns:
		for i in 3:
			var seen := ColourVision.simulate(primaries[i], mode).srgb_to_linear()
			var expected: Vector3 = columns[mode][i]
			for channel in 3:
				assert_almost_eq(seen[channel], expected[channel], 0.0005, "mode %d, primary %d, channel %d" % [mode, i, channel])
	# ...and a colour no channel of which clamps catches the negative ones (tools/accessibility/cvd.py's numbers)
	var mixed := {
		ColourVision.DEUTERANOPIA: Color(0.71227, 0.65736, 0.40342),
		ColourVision.PROTANOPIA: Color(0.66521, 0.61205, 0.38426),
		ColourVision.TRITANOPIA: Color(0.85965, 0.55523, 0.55019),
	}
	for mode: int in mixed:
		var seen := ColourVision.simulate(Color(0.8, 0.6, 0.4), mode)
		for channel in 3:
			assert_almost_eq(seen[channel], (mixed[mode] as Color)[channel], 0.0005, "mode %d: a warm tan, channel %d" % [mode, channel])


func test_every_mode_has_a_colour_for_every_weapon() -> void:
	for mode in MODES_CVD:
		var table: Dictionary = ColourVision.WEAPONS[mode]
		for id in WeaponHolder.SLOT_ORDER:
			assert_true(table.has(id), "%d: %s" % [mode, id])
		assert_eq(table.size(), WeaponPalette.COLORS.size(), "%d: no unknown weapon" % mode)
		assert_eq(ColourVision.weapon(&"no_such_gun", Color.WHITE, mode), Color.WHITE, "an unknown id keeps its fallback")
	for id: StringName in WeaponPalette.COLORS:
		assert_eq(ColourVision.weapon(id, WeaponPalette.COLORS[id], ColourVision.NORMAL), WeaponPalette.COLORS[id], "the standard palette is the game's")


func test_each_mode_keeps_its_weapons_apart_as_its_player_sees_them() -> void:
	var standard := _palette(ColourVision.NORMAL)
	assert_gt(_closest(standard, ColourVision.NORMAL)[0], MIN_NORMAL, "the standard palette, normally")
	for mode in MODES_CVD:
		var palette := _palette(mode)
		var own: Array = _closest(palette, mode)
		var normal: Array = _closest(palette, ColourVision.NORMAL)
		var before: Array = _closest(standard, mode)
		assert_gt(own[0], MIN_OWN, "%d seen in its mode: %.1f (%s)" % [mode, own[0], own[1]])
		assert_gt(normal[0], MIN_NORMAL, "%d seen normally: %.1f (%s)" % [mode, normal[0], normal[1]])
		assert_gt(own[0], before[0] + 10.0, "%d better than the standard palette in that mode (%.1f -> %.1f)" % [mode, before[0], own[0]])


func test_no_weapon_colour_comes_near_the_white_medkit() -> void:
	for mode in ColourVision.MODES:
		var palette := _palette(mode)
		for id: StringName in WeaponPalette.COLORS:
			for seen in [mode, ColourVision.NORMAL]:
				assert_gt(ColourVision.delta_e(palette[id], WeaponPalette.MEDKIT_COLOR, seen), MIN_NORMAL if mode == ColourVision.NORMAL else MIN_OWN,
						"%d %s vs the medkit (seen %d)" % [mode, id, seen])


func test_the_slot_digit_stays_legible_on_the_enamel() -> void:
	for mode in MODES_CVD:
		var palette := _palette(mode)
		for id: StringName in WeaponPalette.COLORS:
			assert_gt(ColourVision.contrast_seen(palette[id], ENAMEL, mode), MIN_TEXT_CONTRAST, "%d %s in its mode" % [mode, id])
			assert_gt(ColourVision.contrast_seen(palette[id], ENAMEL), MIN_TEXT_CONTRAST, "%d %s normally" % [mode, id])


func test_each_weapon_keeps_its_own_colour_in_every_mode() -> void:
	# a box's baked print keeps the standard colour, its rim takes the mode's: they must still agree
	for mode in MODES_CVD:
		for id: StringName in WeaponPalette.COLORS:
			var colour := ColourVision.weapon(id, WeaponPalette.COLORS[id], mode)
			assert_lt(_hue_gap(colour, WeaponPalette.COLORS[id]), HUE_WINDOW + 1.0, "%d %s: hue" % [mode, id])
			assert_gt(colour.s, 0.45, "%d %s: a hue to read" % [mode, id])
			var own := ColourVision.delta_e(colour, WeaponPalette.COLORS[id])
			for other: StringName in WeaponPalette.COLORS:
				if other != id:
					assert_lt(own, ColourVision.delta_e(colour, WeaponPalette.COLORS[other]), "%d %s: nearer its own colour than %s's" % [mode, id, other])


func test_every_role_has_a_colour_in_every_mode() -> void:
	for mode in ColourVision.MODES:
		for name: StringName in ColourVision.STANDARD_ROLES:
			var colour := ColourVision.role(name, mode)
			assert_eq(colour.a, 1.0, "%d %s opaque" % [mode, name])
		if ColourVision.ROLES.has(mode):
			for name: StringName in ColourVision.ROLES[mode]:
				assert_true(ColourVision.STANDARD_ROLES.has(name), "%d: %s is a known role" % [mode, name])
		assert_gt(ColourVision.luminance(ColourVision.role(&"stamina_caffeine_peak", mode)), ColourVision.luminance(ColourVision.role(&"stamina_caffeine", mode)),
				"%d: the caffeine pulses up to a paler peak" % mode)
		assert_eq(ColourVision.role(&"boss", mode), ColourVision.role(&"health", mode), "%d: the boss's bar is the health bar's red" % mode)
	assert_eq(ColourVision.role(&"stamina_fill", ColourVision.NORMAL), Hud.StaminaBar.FILL)
	assert_eq(ColourVision.role(&"hit_kill", ColourVision.NORMAL), Hud.KILL_COLOR)
	assert_eq(ColourVision.role(&"health", ColourVision.NORMAL), UiTheme.EMERGENCY)


func _pulse_partners(a: StringName, b: StringName) -> bool:
	for pair: Array in ColourVision.PULSES:
		if pair.has(a) and pair.has(b):
			return true
	return false


func test_each_role_group_reads_apart_in_its_mode() -> void:
	assert_true(ColourVision.ROLE_GROUPS[&"stamina"].has(&"stamina_caffeine_peak"), "the caffeine's peak is checked too")
	for mode in ColourVision.MODES:
		for group: StringName in ColourVision.ROLE_GROUPS:
			var names: Array = ColourVision.ROLE_GROUPS[group]
			for i in names.size():
				for j in range(i + 1, names.size()):
					var a: StringName = names[i]
					var b: StringName = names[j]
					if _pulse_partners(a, b):
						continue   # the two ends of one pulse: one state
					var d := ColourVision.delta_e(ColourVision.role(a, mode), ColourVision.role(b, mode), mode)
					# a plain hit's white and blocked grey never change; their shapes tell them apart
					var least := 30.0 if a == &"hit" and b == &"hit_blocked" else MIN_ROLE
					assert_gt(d, least, "%d %s: %s vs %s %.1f" % [mode, group, a, b, d])


func test_a_pulse_never_passes_near_another_state() -> void:
	# the caffeinated fill swings between its two ends: every point of the swing keeps clear of the plain fill and of exhaustion
	for mode in ColourVision.MODES:
		for pair: Array in ColourVision.PULSES:
			var from := ColourVision.role(pair[0], mode)
			var to := ColourVision.role(pair[1], mode)
			assert_gt(ColourVision.delta_e(from, to, mode), 5.0, "%d: the pulse shows" % mode)
			for step in 11:
				var tone := from.lerp(to, step / 10.0)
				for other in [&"stamina_fill", &"stamina_exhausted"]:
					var d := ColourVision.delta_e(tone, ColourVision.role(other, mode), mode)
					assert_gt(d, MIN_ROLE, "%d: pulse at %d0 %% vs %s %.1f" % [mode, step, other, d])


func test_the_bars_stand_out_of_their_channel_in_every_mode() -> void:
	for mode in ColourVision.MODES:
		for name in ColourVision.BAR_ROLES:
			var colour := ColourVision.role(name, mode)
			for back in [CHANNEL, ENAMEL]:
				assert_gt(ColourVision.contrast_seen(colour, back, mode), MIN_BAR_CONTRAST, "%d %s seen in its mode" % [mode, name])
				assert_gt(ColourVision.contrast_seen(colour, back), MIN_BAR_CONTRAST, "%d %s seen normally" % [mode, name])
	# the protanope's health bar needed it: the standard red is a dark brown to him
	assert_lt(ColourVision.contrast_seen(UiTheme.EMERGENCY, CHANNEL, ColourVision.PROTANOPIA), MIN_BAR_CONTRAST)


func test_the_hit_markers_and_fuses_keep_their_contrast_on_a_dark_room() -> void:
	for mode in ColourVision.MODES:
		for name in [&"hit", &"hit_weak_point", &"hit_kill", &"hit_blocked", &"fuse_carried", &"fuse_inserted"]:
			assert_gt(ColourVision.contrast_seen(ColourVision.role(name, mode), ENAMEL, mode), MIN_BAR_CONTRAST, "%d %s" % [mode, name])
