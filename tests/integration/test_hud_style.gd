extends TestCase
## The HUD in the house style (plan 2026-10-19-styl-hud), at its fullest,
## in both languages, in a 1920x1080 and a 1280x1024 window: every piece
## stands on a museum plaque, no text is smaller than Hud.MIN_TEXT, every
## text reads on its plaque even over white marble, and the pieces keep
## clear of each other - the bugs the "before" screenshots showed (the
## toast over the boss's bar, the room's card and the hint strip off
## centre, a two-line subtitle over the hint, the night's card over a
## discovery's banner) stay fixed.

const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 1024)]
const LANGUAGES: Array[String] = ["en", "pl"]

var _windows: Array[Window] = []


func after_each() -> void:
	for window in _windows:
		if is_instance_valid(window):
			window.queue_free()
	_windows.clear()
	Settings.reset_to_defaults(false)


func _window(size: Vector2i) -> Window:
	var window := Window.new()
	window.size = size
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	add_child(window)
	_windows.append(window)
	return window


func _guardian(host: Node, index: int) -> GuardianStub:
	var plan := Floor1Plan.guardians()[index]
	var guardian := GuardianStub.new()
	guardian.plan = plan
	guardian.guardian_id = plan.id
	host.add_child(guardian)
	return guardian


## A HUD at its fullest in [param window]: the night with its clock, a long
## goal, the fuses and the shards, the Dust, a guardian's bar with the
## longest name, a toast, a room's card, the night's card and a hint.
func _full_hud(window: Window) -> Hud:
	var hud := Hud.new()
	hud.night = 1
	hud.show_dust = true
	window.add_child(hud)
	hud.hide_help()
	hud.enable_floor()
	hud.set_clock("23:47")
	hud.set_objective(tr("GOAL_GUARDIAN_ENLIGHTENMENT"))
	hud.set_fuses(1, 0)
	hud.set_shards(3, Floor1Plan.SHARD_COUNT)
	var longest := 0
	for i in Floor1Plan.guardians().size():
		var plan := Floor1Plan.guardians()[i]
		if (tr(plan.name_key) + tr(plan.title_key)).length() > (tr(Floor1Plan.guardians()[longest].name_key) + tr(Floor1Plan.guardians()[longest].title_key)).length():
			longest = i
	var guardian := _guardian(window, longest)
	Events.guardian_awakened.emit(guardian, guardian.guardian_id)
	hud.show_toast(tr("HUD_FUSE_FOUND") % [1, 2])
	hud.show_room_card(tr("ROOM_ENLIGHTENMENT_PORTRAITS"), tr("ZONE_ENLIGHTENMENT"), Floor1Plan.zone_color(&"enlightenment"))
	hud.show_card(tr("HUD_NIGHT") % 2, tr(NightModifiers.title_key(&"blackout")), tr(NightModifiers.detail_key(&"blackout")))
	hud.show_hint(tr("HUD_HINT_FLOOR1_GOAL"))
	return hud


func _settle() -> void:
	for i in 40:   # the stack glides into place
		await get_tree().process_frame


## Every visible label of [param node]'s tree.
func _labels(node: Node, into: Array[Label] = []) -> Array[Label]:
	for child in node.get_children():
		if child is Label and (child as Label).is_visible_in_tree() and (child as Label).text != "":
			into.append(child)
		_labels(child, into)
	return into


## The plaque [param label] stands on (null: none).
func _plaque_of(label: Control) -> PlaqueStyle:
	var node := label.get_parent()
	while node != null and node is Control:
		if node is PanelContainer:
			return (node as PanelContainer).get_theme_stylebox(&"panel") as PlaqueStyle
		node = node.get_parent()
	return null


func test_every_piece_of_the_hud_stands_on_a_plaque() -> void:
	var hud := _full_hud(_window(Vector2i(1920, 1080)))
	await _settle()
	var pieces := {"vitals": hud._vitals, "weapon": hud._arms, "night": hud._night_plate, "toast": hud._toast_plate,
		"prompt": hud._prompt, "hint": hud._hint, "room": hud._room_card, "boss name": hud._boss_plate, "help": hud._help,
		"dust": hud._dust_label.get_parent().get_parent()}
	for piece in pieces:
		var style := (pieces[piece] as Control).get_theme_stylebox(&"panel")
		assert_true(style is PlaqueStyle, "%s on a plaque, not %s" % [piece, str(style)])
	for label in _labels(hud):
		if label == hud._card_title or label == hud._card_subtitle or label == hud._card_detail or label == hud._death_label or label == hud._dust_gain or label == hud._fps_label:
			continue   # the cinematic card and the floating "+n" stand on the scene (outlined)
		assert_not_null(_plaque_of(label), "'%s' on a plaque" % label.text)


func test_no_hud_text_is_smaller_than_the_minimum() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		var hud := _full_hud(_window(Vector2i(1280, 1024)))
		await _settle()
		hud._help.visible = true
		for label in _labels(hud) + [hud._help_hint, hud._fps_label, hud._room_card.zone]:
			var size: int = label.label_settings.font_size if label.label_settings != null else label.get_theme_font_size(&"font_size")
			assert_true(size >= Hud.MIN_TEXT, "'%s' at %d (%s)" % [label.text.left(30), size, language])


## WCAG on the worst ground: the plaque's enamel laid over white marble.
## Body text 4.5:1, large or bold text 3:1; the faint numbers of weapons
## not found yet are meant to be faint.
func test_every_text_reads_on_its_plaque_over_marble() -> void:
	var hud := _full_hud(_window(Vector2i(1920, 1080)))
	hud._help.visible = true
	await _settle()
	for label in _labels(hud):
		var style := _plaque_of(label)
		if style == null:
			continue
		var color := label.label_settings.font_color if label.label_settings != null else label.get_theme_color(&"font_color")
		if color == Hud.SLOT_EMPTY:
			continue
		color = Color(color, color.a * label.modulate.a)
		var ground := UiTheme.over(style.field, Color.WHITE)
		var settings := label.label_settings
		var large := settings != null and (settings.font_size >= 24 or settings.font == UiTheme.number_font() or settings.font is FontVariation and (settings.font as FontVariation).base_font == UiTheme.strong_font())
		var least := 3.0 if large else 4.5
		var ratio := UiTheme.contrast(UiTheme.over(color, ground), ground)
		assert_gt(ratio, least, "'%s': %.2f:1 over marble" % [label.text.left(30), ratio])


func test_the_top_middle_stacks_without_overlaps_in_every_window_and_language() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		for size in WINDOWS:
			var hud := _full_hud(_window(size))
			await _settle()
			var canvas := hud.get_viewport().get_visible_rect().size
			var where := "%s, window %s" % [language, size]
			var boss := hud._boss_box.get_global_rect()
			var toast := hud._toast_plate.get_global_rect()
			var room := hud._room_card.get_global_rect()
			var card := hud._card.get_global_rect()
			var goal := hud._night_plate.get_global_rect()
			assert_true(hud.boss_bar_shown(), where)
			assert_false(toast.intersects(boss), "the toast %s under the bar %s: %s" % [toast, boss, where])
			assert_false(room.intersects(toast), "the room's card %s under the toast %s: %s" % [room, toast, where])
			assert_false(room.intersects(boss), "the room's card under the bar: " + where)
			assert_false(card.intersects(room), "the night's card %s under the room's %s: %s" % [card, room, where])
			assert_false(goal.intersects(boss), "the night's plaque %s beside the bar %s: %s" % [goal, boss, where])
			for piece in [toast, room, card, hud._hint.get_global_rect()]:
				assert_almost_eq(piece.get_center().x, canvas.x * 0.5, 1.0, "centred %s: %s" % [piece, where])
			assert_gt(hud.top_middle_bottom(), room.end.y - 1.0, "the stack's bottom is the room card's: " + where)


func test_the_corner_plaques_keep_to_their_corners() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		for size in WINDOWS:
			var window := _window(size)
			Greybox.box(window, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
			var player := Player.new()
			window.add_child(player)
			var hud := Hud.new()
			hud.player = player
			hud.night = 1
			hud.show_dust = true
			window.add_child(hud)
			for id in WeaponHolder.SLOT_ORDER:
				var data := load("res://src/weapons/data/%s.tres" % id) as WeaponData
				if data != null:
					player.weapons.give(data)
			var canvas := hud.get_viewport().get_visible_rect().size
			var screen := Rect2(Vector2.ZERO, canvas)
			for id in WeaponHolder.SLOT_ORDER:
				if player.weapons.state_of(id) == null:
					continue
				player.weapons.select_id(id)
				for alt in [false, true]:
					player.weapons.current_state().use_alt = alt
					await _settle()
					var arms := hud._arms.get_global_rect()
					var vitals := hud._vitals.get_global_rect()
					var where := "%s, %s, window %s ('%s')" % [id, language, size, hud._weapon_label.text]
					assert_true(screen.encloses(arms), "the weapon's plaque %s on screen: %s" % [arms, where])
					assert_true(screen.encloses(vitals), "the vitals on screen: " + where)
					assert_gt(arms.position.x, canvas.x * 0.5 + 120.0, "the weapon's plaque clear of the crosshair: " + where)
					assert_lt(vitals.end.x, canvas.x * 0.5 - 120.0, "the vitals clear of the crosshair: " + where)


func test_a_two_line_subtitle_stays_above_the_hint() -> void:
	for size in WINDOWS:
		var window := _window(size)
		var hud := Hud.new()
		window.add_child(hud)
		var bar := SubtitleBar.new()
		window.add_child(bar)
		Settings.set_value(&"subtitles", true, false)
		bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 20.0)
		var long := tr("VO_GUIDE_ROSETTA_A").left(SubtitleBar.MAX_CHARS)
		bar._parts = PackedStringArray([long + " " + long])
		bar._ends = PackedFloat32Array([20.0])
		await _settle()
		var canvas := hud.get_viewport().get_visible_rect().size
		var subtitle := bar._panel.get_global_rect()
		assert_gt(bar._text.get_line_count(), 1, "a long line: two lines")
		assert_almost_eq(subtitle.end.y, canvas.y - SubtitleBar.BOTTOM, 1.0, "no hint: it grows up from its own bottom edge")
		for hint_key in ["HUD_HINT_FUSES", "HUD_HINT_FLOOR1_GOAL", "LOCKER_LOCKED_DETAIL"]:
			hud.show_hint(tr(hint_key) + " " + tr(hint_key))   # a long note: three lines
			await _settle()
			subtitle = bar._panel.get_global_rect()
			var hint := hud._hint.get_global_rect()
			assert_false(subtitle.intersects(hint), "the subtitle %s over the hint %s (window %s)" % [subtitle, hint, size])
			assert_almost_eq(subtitle.get_center().x, canvas.x * 0.5, 1.0, "centred")
			assert_almost_eq(hint.end.y, canvas.y - Hud.HINT_BOTTOM, 1.0, "the hint's bottom edge")
		hud._hint_left = 0.0
		await _settle()
		assert_almost_eq(bar._panel.get_global_rect().end.y, canvas.y - SubtitleBar.BOTTOM, 1.0, "the hint gone: back down")


func test_the_nights_card_keeps_under_a_discoverys_banner() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		for size in WINDOWS:
			var window := _window(size)
			var hud := _full_hud(window)
			var world := WorldHud.new()
			window.add_child(world)
			world.top_source = hud.top_middle_bottom
			hud.below_source = world.banner_bottom
			world.banner(tr("SECRET_FOUND") % [3, 12], tr("PROMPT_SECRET_PLAQUE"), tr("HUD_HINT_FLOOR1_GOAL"))
			await _settle()
			var banner := world._banner.get_global_rect()
			var card := hud._card.get_global_rect()
			var where := "%s, window %s" % [language, size]
			assert_false(card.intersects(banner), "the card %s under the banner %s: %s" % [card, banner, where])
			assert_false(banner.intersects(hud._room_card.get_global_rect()), "the banner under the room's card: " + where)
			assert_false(banner.intersects(hud._boss_box.get_global_rect()), "the banner under the bar: " + where)


func test_a_warning_turns_the_toast_red() -> void:
	var hud := Hud.new()
	add_child(hud)
	hud.show_warning("x")
	var style := hud._toast_plate.get_theme_stylebox(&"panel") as PlaqueStyle
	assert_eq(hud._toast.label_settings.font_color, UiTheme.DANGER)
	assert_eq(Color(style.rim, 1.0), UiTheme.EMERGENCY, "the rule in the emergency red")
	hud.show_toast("y")
	assert_eq(hud._toast.label_settings.font_color, Hud.TOAST_COLOR)
	assert_eq(Color(style.rim, 1.0), UiTheme.BRASS, "brass again")
	hud.free()


func test_the_state_icons_show_caffeine_and_fatigue() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
	var player := Player.new()
	add_child(player)
	var hud := Hud.new()
	hud.player = player
	add_child(hud)
	await physics_frames(2)
	await get_tree().process_frame
	assert_eq(hud._caffeine_icon.modulate.a, 0.0, "no coffee: no cup")
	assert_eq(hud._tired_icon.modulate.a, 0.0, "fresh: no drooping eye")
	player.fatigue.drink(&"espresso")
	player.fatigue.level = 1.0
	for i in 90:
		await get_tree().process_frame
	assert_gt(hud._caffeine_icon.modulate.a, 0.5, "the cup while the caffeine lasts")
	assert_gt(hud._tired_icon.modulate.a, 0.9, "the eye while fatigue eats the bar")
	hud.free()
	player.free()


func test_the_room_card_wears_its_wings_colour() -> void:
	var hud := Hud.new()
	add_child(hud)
	hud.show_room_card("A", "B", Color(0.7, 0.22, 0.18))
	assert_eq(hud._room_card.band_color(), Color(0.7, 0.22, 0.18))
	assert_eq(hud.room_card_text(), "A | B")
	hud.free()
