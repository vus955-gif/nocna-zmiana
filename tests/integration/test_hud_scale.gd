extends TestCase
## The HUD's size option (plan 2026-10-21-dostepnosc): 75..150 % of the
## designed size, applied live and read at start. The layer is scaled and the
## HUD lays itself out in HUD units (Hud.canvas_size = canvas / scale), so at
## every scale and in every window the pieces stay on the screen and clear of
## each other, the edges other layers read are in canvas units, and the
## subtitles keep above the corner plaques.

## The windows the stretch (canvas_items, expand, 1920x1080) turns into canvases
## of 1920x1080, 1920x1536, 1920x1080 and 2560x1080 units (21:9).
const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 1024), Vector2i(1600, 900), Vector2i(2560, 1080)]
const SCALES: Array[float] = [0.75, 1.0, 1.25, 1.5]

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


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame


func _guardian(host: Node, index: int) -> GuardianStub:
	var plan := Floor1Plan.guardians()[index]
	var guardian := GuardianStub.new()
	guardian.plan = plan
	guardian.guardian_id = plan.id
	host.add_child(guardian)
	return guardian


## A HUD at its fullest in [param window] (as in test_hud_style).
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
	var guardian := _guardian(window, 0)
	Events.guardian_awakened.emit(guardian, guardian.guardian_id)
	hud.show_toast(tr("HUD_FUSE_FOUND") % [1, 2])
	hud.show_room_card(tr("ROOM_ENLIGHTENMENT_PORTRAITS"), tr("ZONE_ENLIGHTENMENT"), Floor1Plan.zone_color(&"enlightenment"))
	hud.show_card(tr("HUD_NIGHT") % 2, tr(NightModifiers.title_key(&"blackout")), tr(NightModifiers.detail_key(&"blackout")))
	hud.show_hint(tr("HUD_HINT_FLOOR1_GOAL"))
	return hud


func test_the_option_scales_the_layer_live() -> void:
	var window := _window(Vector2i(1920, 1080))
	var hud := Hud.new()
	window.add_child(hud)
	assert_eq(hud.ui_scale, 1.0, "as designed")
	assert_eq(hud.scale, Vector2.ONE)
	assert_eq(hud.canvas_size(), Vector2(1920, 1080))
	Settings.set_value(&"hud_scale", 1.5, false)
	assert_eq(hud.ui_scale, 1.5)
	assert_eq(hud.scale, Vector2(1.5, 1.5))
	assert_almost_eq(hud.canvas_size().x, 1280.0, 0.01, "a bigger HUD has a smaller canvas in its own units")
	assert_almost_eq(hud.canvas_size().y, 720.0, 0.01)
	await get_tree().process_frame
	assert_eq(hud._root.size, hud.canvas_size(), "the root piece covers the canvas exactly")
	Settings.set_value(&"hud_scale", 0.75, false)
	assert_almost_eq(hud.canvas_size().x, 2560.0, 0.01)
	assert_eq(hud._root.size, hud.canvas_size())
	Settings.set_value(&"hud_scale", 1.0, false)
	assert_eq(hud.scale, Vector2.ONE)
	assert_eq(hud._root.size, Vector2(1920, 1080), "back to the design")


func test_a_new_hud_starts_at_the_saved_size() -> void:
	Settings.set_value(&"hud_scale", 1.25, false)
	var hud := Hud.new()
	_window(Vector2i(1920, 1080)).add_child(hud)
	assert_eq(hud.ui_scale, 1.25)
	assert_eq(hud.scale, Vector2(1.25, 1.25))
	assert_eq(hud._root.size, Vector2(1536, 864))


func test_the_root_follows_the_window() -> void:
	Settings.set_value(&"hud_scale", 1.5, false)
	var window := _window(Vector2i(1920, 1080))
	var hud := Hud.new()
	window.add_child(hud)
	window.size = Vector2i(1280, 1024)   # canvas 1920x1536
	await _settle()
	assert_almost_eq(hud._root.size.x, 1280.0, 0.5, "1920 canvas units / 1.5")
	assert_almost_eq(hud._root.size.y, 1024.0, 0.5)


func test_edges_given_to_other_layers_are_in_canvas_units() -> void:
	for hud_scale in SCALES:
		Settings.set_value(&"hud_scale", hud_scale, false)
		var window := _window(Vector2i(1920, 1080))
		var hud := _full_hud(window)
		await _settle()
		var stack := hud._room_card.get_global_rect().end.y
		assert_almost_eq(hud.top_middle_bottom(), stack * hud_scale, 1.5, "top middle in canvas units at %s" % hud_scale)
		assert_almost_eq(hud.hint_clearance(), (hud.canvas_size().y - hud._hint.get_global_rect().position.y) * hud_scale, 1.5, "hint strip at %s" % hud_scale)
		assert_gt(hud.hint_clearance(), (Hud.HINT_BOTTOM + hud._hint.get_global_rect().size.y) * hud_scale - 1.5, "never lower than the strip's design")
		var left := hud._night_plate.get_global_rect().end.y
		assert_almost_eq(hud.top_left_bottom(), left * hud_scale, 1.5, "top left at %s" % hud_scale)
		assert_gt(hud.bottom_clearance(), (Hud.MARGIN + 100.0) * hud_scale, "the corner plaques reach up at %s" % hud_scale)


func test_every_piece_stays_on_the_screen_and_clear_at_every_size_in_every_window() -> void:
	for hud_scale in SCALES:
		Settings.set_value(&"hud_scale", hud_scale, false)
		for size in WINDOWS:
			var hud := _full_hud(_window(size))
			hud._help.visible = false
			await _settle()
			var screen := Rect2(Vector2.ZERO, hud.canvas_size())
			var where := "scale %s, window %s (canvas %s)" % [hud_scale, size, hud.canvas_size()]
			var pieces := {"vitals": hud._vitals, "night": hud._night_plate, "boss": hud._boss_box, "toast": hud._toast_plate,
				"room": hud._room_card, "card": hud._card, "hint": hud._hint, "dust": hud._dust_box}
			for piece in pieces:
				var rect := (pieces[piece] as Control).get_global_rect()
				assert_true(screen.grow(0.5).encloses(rect), "%s %s on the screen %s: %s" % [piece, rect, screen, where])
			var boss := hud._boss_box.get_global_rect()
			var night := hud._night_plate.get_global_rect()
			var toast := hud._toast_plate.get_global_rect()
			var room := hud._room_card.get_global_rect()
			var card := hud._card.get_global_rect()
			var dust := hud._dust_box.get_global_rect()
			assert_false(night.intersects(boss), "night %s beside the bar %s: %s" % [night, boss, where])
			assert_false(toast.intersects(boss), "toast under the bar: " + where)
			assert_false(room.intersects(toast), "room card under the toast: " + where)
			assert_false(room.intersects(boss), "room card under the bar: " + where)
			assert_false(card.intersects(room), "the night's card %s under the room's %s: %s" % [card, room, where])
			assert_false(card.intersects(night), "the night's card clear of the night's plaque: " + where)
			assert_false(dust.intersects(boss), "the dust beside the bar: " + where)
			assert_false(dust.intersects(room), "the dust clear of the room card: " + where)
			assert_false(hud._hint.get_global_rect().intersects(hud._room_card.get_global_rect()), "hint clear of the room card: " + where)


func test_the_corner_plaques_keep_apart_from_the_hint_and_the_middle_at_every_size() -> void:
	for hud_scale in SCALES:
		Settings.set_value(&"hud_scale", hud_scale, false)
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
			player.weapons.select_id(&"shotgun")
			player.weapons.current_state().use_alt = true   # the longest name line
			hud.show_hint(tr("HUD_HINT_FLOOR1_GOAL"))
			await _settle()
			var canvas := hud.canvas_size()
			var where := "scale %s, window %s (canvas %s)" % [hud_scale, size, canvas]
			var arms := hud._arms.get_global_rect()
			var vitals := hud._vitals.get_global_rect()
			var hint := hud._hint.get_global_rect()
			assert_true(Rect2(Vector2.ZERO, canvas).grow(0.5).encloses(arms), "the weapon's plaque %s on screen: %s" % [arms, where])
			assert_true(Rect2(Vector2.ZERO, canvas).grow(0.5).encloses(vitals), "the vitals on screen: " + where)
			assert_gt(arms.position.x, canvas.x * 0.5 + 120.0, "the weapon's plaque clear of the crosshair: " + where)
			assert_lt(vitals.end.x, canvas.x * 0.5 - 120.0, "the vitals clear of the crosshair: " + where)
			assert_false(hint.intersects(arms), "the hint %s over the weapon's plaque %s: %s" % [hint, arms, where])
			assert_false(hint.intersects(vitals), "the hint %s over the vitals %s: %s" % [hint, vitals, where])


func test_the_f1_help_fits_the_screen_at_every_size() -> void:
	for hud_scale in SCALES:
		Settings.set_value(&"hud_scale", hud_scale, false)
		for size in WINDOWS:
			var hud := Hud.new()
			hud.night = 1
			_window(size).add_child(hud)
			hud._help.visible = true
			await _settle()
			var screen := Rect2(Vector2.ZERO, hud.canvas_size())
			var rect := hud._help.get_global_rect()
			assert_true(screen.grow(0.5).encloses(rect), "the help %s fits %s at scale %s in %s" % [rect, screen, hud_scale, size])


func test_the_subtitles_keep_above_the_corner_plaques_at_every_size() -> void:
	for hud_scale in SCALES:
		Settings.set_value(&"hud_scale", hud_scale, false)
		for size in WINDOWS:
			var window := _window(size)
			Greybox.box(window, Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color.GRAY)
			var player := Player.new()
			window.add_child(player)
			var hud := Hud.new()
			hud.player = player
			window.add_child(hud)
			var bar := SubtitleBar.new()
			window.add_child(bar)
			Settings.set_value(&"subtitles", true, false)
			bar.show_line(&"VO_GUIDE_ROSETTA_A", &"guide", 20.0)
			var long := tr("VO_GUIDE_ROSETTA_A").left(SubtitleBar.MAX_CHARS)
			bar._parts = PackedStringArray([long + " " + long])
			bar._ends = PackedFloat32Array([20.0])
			await _settle()
			var canvas: Vector2 = hud.get_viewport().get_visible_rect().size
			var subtitle := bar._panel.get_global_rect()
			var arms := hud._arms.get_global_rect()
			var vitals := hud._vitals.get_global_rect()
			var arms_canvas := Rect2(arms.position * hud_scale, arms.size * hud_scale)
			var vitals_canvas := Rect2(vitals.position * hud_scale, vitals.size * hud_scale)
			var where := "scale %s, window %s (canvas %s)" % [hud_scale, size, canvas]
			assert_true(Rect2(Vector2.ZERO, canvas).grow(0.5).encloses(subtitle), "the subtitle %s on screen: %s" % [subtitle, where])
			assert_false(subtitle.intersects(arms_canvas), "the subtitle %s over the weapon's plaque %s: %s" % [subtitle, arms_canvas, where])
			assert_false(subtitle.intersects(vitals_canvas), "the subtitle %s over the vitals %s: %s" % [subtitle, vitals_canvas, where])


## The stretch shrinks a 1920x1080-unit HUD to 2/3 in a 1280x1024 window;
## the option brings it back: the smallest HUD text (the help hint, 20 units)
## shows at 13 real pixels there at the design size and at 20 at 150 %.
func test_the_option_makes_up_for_a_small_window() -> void:
	var shown: Array[float] = []
	for hud_scale in [1.0, 1.5]:
		Settings.set_value(&"hud_scale", hud_scale, false)
		var window := _window(Vector2i(1280, 1024))
		var hud := Hud.new()
		hud.night = 1
		window.add_child(hud)
		var stretch := float(window.size.x) / hud.get_viewport().get_visible_rect().size.x
		shown.append(hud._help_hint.label_settings.font_size * stretch * hud.ui_scale)
	assert_almost_eq(shown[0], 13.33, 0.05, "at the design size the smallest text is 13 px in this window")
	assert_almost_eq(shown[1], 20.0, 0.05, "at 150 % it is 20 px again")
