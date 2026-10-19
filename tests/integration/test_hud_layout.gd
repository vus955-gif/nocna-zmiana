extends TestCase
## The HUD's top edge on screens of several shapes, in both languages: the
## night's goal on the left never runs under the boss's bar in the middle,
## the bar (a long "NAME - TITLE") stays on the screen, and nothing else of
## the top edge is covered by either.

## Window sizes: the stretch (canvas_items, expand, 1920x1080 base) turns
## them into canvases of 1920x1080, 1920x1080, 1920x1536, 1920x1080 and
## 2560x1080 units.
const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 1024), Vector2i(1280, 720), Vector2i(2560, 1080)]
## Canvas sizes taken literally: narrower than the stretch ever gives.
const CANVASES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 1024), Vector2i(1280, 720)]
const LANGUAGES: Array[String] = ["en", "pl"]
## The goals with the longest text of a language are tried on every bar.
const LONGEST_GOALS := 3

## Every guardian of the floor, and the T-Rex (the night's boss).
var _bosses: Array[Node] = []


func before_each() -> void:
	for plan in Floor1Plan.guardians():
		var guardian := GuardianStub.new()
		guardian.plan = plan
		guardian.guardian_id = plan.id
		add_child(guardian)
		_bosses.append(guardian)
	var trex := Node.new()
	add_child(trex)
	_bosses.append(trex)


func after_each() -> void:
	Settings.reset_to_defaults(false)


## A HUD of the night in a window of [param size] (scaled as the game's).
func _hud_in_window(size: Vector2i) -> Hud:
	var window := Window.new()
	window.size = size
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	add_child(window)
	return _night_hud(window)


## A HUD of the night on a canvas of exactly [param size] units.
func _hud_on_canvas(size: Vector2i) -> Hud:
	var view := SubViewport.new()
	view.size = size
	add_child(view)
	return _night_hud(view)


## The top edge as full as it gets: the night's fuses and shards under the
## goal, the Dust, a room's card.
func _night_hud(host: Node) -> Hud:
	var hud := Hud.new()
	hud.night = 1
	hud.show_dust = true
	host.add_child(hud)
	hud.hide_help()   # as the game does at the start
	hud.enable_floor()
	hud.set_fuses(0, 0)
	hud.set_shards(3, Floor1Plan.SHARD_COUNT)
	hud.show_room_card(tr("GUARDIAN_COLOSSUS"), tr("GUARDIAN_COLOSSUS_TITLE"), Color.GOLD)
	return hud


## The Floor I goals and the night's own in the language now, longest first
## (without the ones with a number in them).
func _longest_goals() -> PackedStringArray:
	var font := UiTheme.strong_font()
	var found: Array[String] = []
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var key := file.get_csv_line()[0]
		if key.begins_with("GOAL_") or key.begins_with("NIGHT_OBJ_"):
			var text := tr(key)
			if not text.contains("%"):
				found.append(text)
	found.sort_custom(func(a: String, b: String) -> bool:
		return font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x)
	return PackedStringArray(found.slice(0, LONGEST_GOALS))


## Wakes [param boss] (a Guardian: through Events.guardian_awakened; any
## other node: the night's boss) and lets the HUD lay itself out.
func _wake(boss: Node) -> void:
	if boss is Guardian:
		Events.guardian_awakened.emit(boss, (boss as Guardian).guardian_id)
	else:
		Events.boss_awakened.emit(boss)
	await get_tree().process_frame
	await get_tree().process_frame


## Every goal of the language now beside the bar of every boss on
## [param hud], on a canvas of [param canvas] units. The room's card (low
## under the bar) is kept clear only on the canvases the stretch gives (a
## [param narrow] one stacks the longest name three lines high).
func _check_every_goal_beside_every_bar(hud: Hud, canvas: Vector2, where: String, narrow: bool = false) -> void:
	var screen := Rect2(Vector2.ZERO, canvas)
	for goal in _longest_goals():
		hud.set_objective(goal)
		for boss in _bosses:
			await _wake(boss)
			var what := "%s, %s, '%s' / '%s'" % [where, TranslationServer.get_locale(), goal, hud.boss_name_text()]
			var goals := hud._night_box.get_global_rect()
			var bar := hud._boss_box.get_global_rect()
			assert_true(hud.boss_bar_shown(), "the bar is up: " + what)
			assert_false(goals.intersects(bar), "goal %s under the bar %s: %s" % [goals, bar, what])
			assert_true(screen.encloses(bar), "the bar %s on the %s canvas: %s" % [bar, canvas, what])
			assert_almost_eq(bar.get_center().x, canvas.x * 0.5, 1.0, "the bar in the middle: " + what)
			assert_false(bar.intersects(hud._dust_box.get_global_rect()), "the bar over the Dust: " + what)
			var card := hud._room_card.get_global_rect()
			assert_false(card.intersects(goals), "the room's card over the goal %s: %s" % [goals, what])
			if not narrow:
				assert_false(card.intersects(bar), "the room's card over the bar %s: %s" % [bar, what])
			# the goal's lines all fit in its label (no line spills onto the rows under it)
			var label := hud._objective_label
			assert_true(label.size.y + 1.0 >= label.get_line_count() * label.get_line_height(), "the goal's lines fit: " + what)
			assert_true(label.get_line_count() <= 4, "the goal in %d lines: %s" % [label.get_line_count(), what])


func test_a_long_goal_keeps_clear_of_the_bar_in_any_window() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		for size in WINDOWS:
			var hud := _hud_in_window(size)
			var canvas := hud.get_viewport().get_visible_rect().size
			await _check_every_goal_beside_every_bar(hud, canvas, "window %s" % size)
			hud.get_viewport().queue_free()


func test_a_long_goal_keeps_clear_of_the_bar_on_a_narrow_canvas() -> void:
	for language in LANGUAGES:
		Settings.set_value(&"language", language, false)
		for size in CANVASES:
			var hud := _hud_on_canvas(size)
			await _check_every_goal_beside_every_bar(hud, Vector2(size), "canvas %s" % size, true)
			hud.get_viewport().queue_free()


func test_the_goal_runs_on_one_line_again_when_the_bar_goes() -> void:
	Settings.set_value(&"language", "en", false)
	var hud := _hud_on_canvas(Vector2i(1920, 1080))
	hud.set_objective(_longest_goals()[0])
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hud._objective_label.get_line_count(), 1, "no bar: one line")
	await _wake(_bosses[0])
	assert_gt(hud._objective_label.get_line_count(), 1, "beside the bar: wrapped")
	hud._boss_box.visible = false   # the bar has faded
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hud._objective_label.get_line_count(), 1, "the bar gone: one line")
	hud.get_viewport().queue_free()
