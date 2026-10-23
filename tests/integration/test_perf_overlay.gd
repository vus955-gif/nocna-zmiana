extends TestCase
## The dev performance overlay (F3): off by default and free then, three
## views, only in dev builds or with the option, the numbers it shows.

var overlay: Node


func before_each() -> void:
	overlay = PerfOverlay
	overlay.debug_build = true
	overlay.set_mode(PerfOverlay.Mode.OFF)


func after_each() -> void:
	overlay.set_mode(PerfOverlay.Mode.OFF)
	overlay.debug_build = OS.is_debug_build()
	PerceptionWorld.profiling = false


func _f3() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F3
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func test_it_is_off_and_free_by_default() -> void:
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF)
	assert_false(overlay.visible)
	assert_false(overlay.is_processing(), "nothing runs while it is off")
	assert_false(overlay._measuring_render, "the renderer is not asked for timings")
	assert_false(PerceptionWorld.profiling, "perception is not timed")
	assert_true(overlay.sections == null, "no stamps, no changed priorities")


func test_f3_steps_through_the_views() -> void:
	await _f3()
	assert_eq(overlay.mode, PerfOverlay.Mode.NUMBERS)
	assert_true(overlay.visible)
	assert_true(overlay.is_processing())
	assert_true(overlay._measuring_render)
	assert_true(PerceptionWorld.profiling)
	assert_false(overlay._systems.visible)
	await _f3()
	assert_eq(overlay.mode, PerfOverlay.Mode.SYSTEMS)
	assert_true(overlay._systems.visible)
	assert_true(overlay.sections != null)
	assert_true(overlay.sections.is_installed())
	assert_eq(overlay.sections.names.size(), MuseumSections.NAMES.size())
	assert_true(overlay.sections.names.has(&"exhibits") and overlay.sections.names.has(&"navigation"), "the game's subsystems")
	await _f3()
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF)
	assert_false(overlay.visible)
	assert_false(overlay.is_processing())
	assert_false(PerceptionWorld.profiling)
	assert_true(overlay.sections == null)


func test_leaving_the_systems_view_puts_every_priority_back() -> void:
	overlay.set_mode(PerfOverlay.Mode.SYSTEMS)
	var claimed: int = overlay.sections.claimed_count()
	assert_gt(claimed, 0.0, "some of the scene's scripts are in sections")
	var before := {}
	for id: int in overlay.sections._claimed:
		var entry: Array = overlay.sections._claimed[id]
		before[entry[0]] = [entry[1], entry[2]]
		assert_true((entry[0] as Node).process_priority >= CpuSections.FIRST_PRIORITY, "%s runs in a section" % entry[0])
	overlay.set_mode(PerfOverlay.Mode.OFF)
	for node: Node in before:
		if is_instance_valid(node):
			assert_eq(node.process_priority, before[node][0], str(node))
			assert_eq(node.process_physics_priority, before[node][1], str(node))


func test_a_release_build_needs_the_option() -> void:
	overlay.debug_build = false
	assert_false(overlay.allowed())
	overlay.cycle()
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF, "F3 does nothing")
	await _f3()
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF)
	Settings.set_value(&"dev_tools", true, false)
	assert_true(overlay.allowed())
	await _f3()
	assert_eq(overlay.mode, PerfOverlay.Mode.NUMBERS)
	Settings.set_value(&"dev_tools", false, false)
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF, "switching the option off takes it down")
	assert_false(overlay.visible)


func test_it_will_not_be_set_on_when_not_allowed() -> void:
	overlay.debug_build = false
	overlay.set_mode(PerfOverlay.Mode.SYSTEMS)
	assert_eq(overlay.mode, PerfOverlay.Mode.OFF)


func test_the_numbers_are_all_written() -> void:
	overlay.set_mode(PerfOverlay.Mode.NUMBERS)
	for i in 5:
		await get_tree().process_frame
	overlay.refresh()
	for row: Array in PerfOverlay.ROWS:
		assert_ne(overlay.value_text(StringName(row[0])), "", "the row %s has a value" % row[0])
	assert_true(overlay.value_text(&"frame").ends_with(" ms"), overlay.value_text(&"frame"))
	assert_true(overlay.value_text(&"script").contains(" ms (max "), overlay.value_text(&"script"))
	assert_true(overlay.value_text(&"physics").contains(" ms (max "), overlay.value_text(&"physics"))
	assert_eq(overlay.value_text(&"render_gpu"), "—", "nothing is measured without a renderer")
	assert_true(overlay._head.text.contains("FPS"), overlay._head.text)
	assert_eq(overlay.value_text(&"lights"), "—", "no level here, no lamps")


func test_the_frame_signals_are_listened_to_only_while_it_is_up() -> void:
	assert_false(get_tree().physics_frame.is_connected(overlay._on_physics_frame))
	assert_false(RenderingServer.frame_pre_draw.is_connected(overlay._on_pre_draw))
	overlay.set_mode(PerfOverlay.Mode.NUMBERS)
	assert_true(get_tree().physics_frame.is_connected(overlay._on_physics_frame))
	assert_true(get_tree().process_frame.is_connected(overlay._on_process_frame))
	assert_true(RenderingServer.frame_pre_draw.is_connected(overlay._on_pre_draw))
	overlay.set_mode(PerfOverlay.Mode.SYSTEMS)
	overlay.set_mode(PerfOverlay.Mode.OFF)
	assert_false(get_tree().physics_frame.is_connected(overlay._on_physics_frame))
	assert_false(get_tree().process_frame.is_connected(overlay._on_process_frame))
	assert_false(RenderingServer.frame_pre_draw.is_connected(overlay._on_pre_draw))


func test_the_graph_gets_the_frames() -> void:
	overlay.set_mode(PerfOverlay.Mode.NUMBERS)
	for i in 6:
		await get_tree().process_frame
	overlay.refresh()
	var seen := 0
	for ms in overlay._graph.frames:
		if ms > 0.0:
			seen += 1
	assert_gt(seen, 3.0)


func test_the_ai_row_counts_the_awake_exhibits() -> void:
	Greybox.box(self, Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color.GRAY)
	var target := TargetDummy.new()
	target.position = Vector3(0, 0, -8)
	add_child(target)
	for i in 4:
		var wax := WaxFigure.new()
		wax.target = target
		wax.position = Vector3(i * 2.0, 0, 10)
		add_child(wax)
		if i < 2:
			wax.brain.state = EnemyBrain.State.HUNT
	overlay.set_mode(PerfOverlay.Mode.NUMBERS)
	overlay.refresh()
	assert_eq(overlay.value_text(&"ai"), "2 · 2  z 4")


func test_the_place_follows_the_room_the_guard_enters() -> void:
	overlay._room = &""   # (an earlier test's guard may have walked somewhere: a scene change forgets it)
	overlay._zone = &""
	overlay.set_mode(PerfOverlay.Mode.NUMBERS)
	overlay.refresh()
	assert_eq(overlay.value_text(&"place"), "—")
	Events.room_entered.emit(&"egypt_gallery", &"egypt", true)
	overlay.refresh()
	assert_eq(overlay.value_text(&"place"), "egypt_gallery · egypt")


func test_the_systems_view_lists_the_dearest_subsystems() -> void:
	overlay.set_mode(PerfOverlay.Mode.SYSTEMS)
	for i in 8:
		await get_tree().process_frame
	overlay.refresh()
	var first: Dictionary = overlay._system_rows[0]
	assert_true((first["box"] as Control).visible)
	assert_ne((first["title"] as Label).text, "")
	assert_true((first["ms"] as Label).text.contains("·"), (first["ms"] as Label).text)
	assert_true(overlay._system_rest.text.begins_with("Razem"), overlay._system_rest.text)


func test_compact_counts() -> void:
	assert_eq(PerfOverlay.compact(950), "950")
	assert_eq(PerfOverlay.compact(12345), "12.3k")
	assert_eq(PerfOverlay.compact(2500000), "2.5 M")


func test_the_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["OPT_DEV_TOOLS", "PERF_HINT_NUMBERS", "PERF_HINT_SYSTEMS", "PERF_SYSTEMS", "PERF_SYSTEMS_NONE", "PERF_SYS_REST"]
	for row: Array in PerfOverlay.ROWS:
		keys.append(row[1])
	for section in MuseumSections.NAMES:
		keys.append("PERF_SYS_" + String(section).to_upper())
	for locale in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s in %s" % [key, locale])
	TranslationServer.set_locale("pl")


func test_the_option_shows_in_the_options_menu() -> void:
	var menu := OptionsMenu.new()
	add_child(menu)
	menu.open()
	var found := false
	for row in menu.rows:
		found = found or row.key == &"dev_tools"
	assert_true(found)
	assert_false(Settings.data.dev_tools, "off by default")
