extends TestCase
## The title screen (built inside the test: it emits navigate instead of
## changing scenes).


func _menu() -> MainMenu:
	var menu := (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	add_child(menu)
	return menu


func test_title_and_buttons() -> void:
	var menu := _menu()
	assert_eq(menu.new_game_button.text, "Nowa gra")
	assert_eq(menu.options_button.text, "Opcje")
	assert_eq(menu.quit_button.text, "Wyjście")
	var titles := menu.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return (label as Label).text == "NOCNA ZMIANA")
	assert_eq(titles.size(), 1)


func test_continue_needs_a_save() -> void:
	var menu := _menu()
	assert_false(menu.continue_button.visible, "no save yet")
	assert_true(menu.new_game_button.has_focus())
	menu.queue_free()
	GameState.new_game()
	GameState.night = 3
	GameState.save_game()
	var again := _menu()
	assert_true(again.continue_button.visible)
	assert_true(again.continue_button.has_focus())
	var going := watch(again.navigate)
	again.continue_button.pressed.emit()
	assert_eq(going.size(), 1)
	if going.size() == 1:
		assert_eq(going[0][0], SceneFlow.MUSEUM)


func test_new_game_without_a_save_asks_only_for_the_shift() -> void:
	var menu := _menu()
	var going := watch(menu.navigate)
	menu.new_game_button.pressed.emit()
	assert_false(menu.confirm.visible)
	assert_true(menu.difficulty.visible, "which shift?")
	assert_true((menu.difficulty.buttons[&"night"] as Button).has_focus(), "the night shift by default")
	assert_eq(going.size(), 0)
	menu.difficulty.choose(&"calm")
	assert_eq(going.size(), 1)
	assert_true(GameState.has_save(), "the new game is written")
	assert_eq(GameState.night, 1)
	assert_eq(GameState.difficulty, &"calm")
	var check := PersistentState.new()
	add_child(check)
	check.load_game()
	assert_eq(check.difficulty, &"calm", "saved with it")
	check.free()


func test_the_shift_can_be_backed_out_of() -> void:
	var menu := _menu()
	var going := watch(menu.navigate)
	menu.new_game_button.pressed.emit()
	menu.difficulty.visible = false
	menu.difficulty.cancelled.emit()
	assert_true(menu._menu.visible)
	assert_true(menu.new_game_button.has_focus())
	assert_eq(going.size(), 0)


func test_the_options_show_the_games_difficulty_between_nights() -> void:
	var menu := _menu()
	menu.options.open()
	assert_false(menu.options._game_section.visible, "no game, no difficulty")
	menu.options.close()
	GameState.new_game()
	GameState.save_game()
	menu.options.open()
	assert_true(menu.options._game_section.visible)
	assert_true(menu.options.difficulty_row._value.text.contains(tr("DIFF_NIGHT")))
	menu.options.difficulty_row.step(1)
	assert_eq(GameState.difficulty, &"double")
	var check := PersistentState.new()
	add_child(check)
	check.load_game()
	assert_eq(check.difficulty, &"double", "saved at once between nights")
	check.free()
	assert_true(menu.options._difficulty_note.text.contains(tr("DIFF_DOUBLE_DETAIL")))


func test_changed_during_a_night_the_sight_follows_at_once() -> void:
	GameState.new_game()
	var options := OptionsMenu.new()
	options.in_night = true
	add_child(options)
	options.open()
	assert_true(options._game_section.visible)
	options.set_difficulty(&"double")
	assert_almost_eq(PerceptionWorld.sight_scale, PerceptionRules.DIFFICULTY[2][0], 0.001)
	assert_true(options._difficulty_note.text.contains(tr("OPT_DIFFICULTY_NIGHT_NOTE")), "the rest from the next night")
	options.set_difficulty(&"night")
	PerceptionWorld.reset()
	options.free()


func test_new_game_over_a_save_asks_first() -> void:
	GameState.new_game()
	GameState.night = 7
	GameState.save_game()
	var menu := _menu()
	var going := watch(menu.navigate)
	menu.new_game_button.pressed.emit()
	assert_true(menu.confirm.visible)
	assert_eq(going.size(), 0)
	menu.confirm._answer(false)
	assert_eq(GameState.night, 7, "cancel keeps the save")
	menu.new_game_button.pressed.emit()
	menu.confirm._answer(true)
	assert_true(menu.difficulty.visible, "then which shift")
	menu.difficulty.choose(&"night")
	assert_eq(going.size(), 1)
	var check := PersistentState.new()
	add_child(check)
	check.load_game()
	assert_eq(check.night, 1, "overwritten")


func test_corrupt_save_shows_a_notice() -> void:
	SaveFile.write_text(SavePaths.save_file(), "{broken")
	var menu := _menu()
	assert_true(menu._notice.visible)
	assert_false(menu.continue_button.visible)
	assert_true(FileAccess.file_exists(SavePaths.save_file() + ".bad"))


func test_options_open_and_come_back() -> void:
	var menu := _menu()
	menu.options_button.pressed.emit()
	assert_true(menu.options.visible)
	menu.options.close()
	assert_false(menu.options.visible)
	assert_true(menu.options_button.has_focus())


func test_quit_goes_through_the_scene_flow() -> void:
	var menu := _menu()
	var going := watch(menu.navigate)
	menu.quit_button.pressed.emit()
	assert_eq(going.size(), 1)
	if going.size() == 1:
		assert_eq(going[0][0], MainMenu.QUIT)


# --- the live scene behind the menu ---------------------------------------------

func after_each() -> void:
	MuseumFloorLevel.dress_default = false
	ArtLibrary.models_enabled = true
	LevelArt.enabled = true
	TranslationServer.set_locale("pl")


## The labels of [param menu] whose text is [param text].
func _labels_with(menu: MainMenu, text: String) -> Array:
	return menu.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return (label as Label).text == text)


func _live_menu() -> MainMenu:
	var menu := (load(SceneFlow.MAIN_MENU) as PackedScene).instantiate() as MainMenu
	menu.live_scene = true
	add_child(menu)
	return menu


func test_the_subtitle_and_the_version_name_floor_one() -> void:
	var menu := _menu()
	assert_eq(_labels_with(menu, "PIĘTRO I — WIELKI DZIEDZINIEC").size(), 1, "the subtitle under the title")
	assert_eq(_labels_with(menu, "WERSJA DEMONSTRACYJNA  ·  PIĘTRO I").size(), 1, "the version label")
	TranslationServer.set_locale("en")
	menu.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(_labels_with(menu, "FLOOR I — THE GREAT COURT").size(), 1, "and in English")
	assert_eq(_labels_with(menu, "DEMO BUILD  ·  FLOOR I").size(), 1)


func test_a_test_run_keeps_the_static_backdrop_unless_asked() -> void:
	var menu := _menu()
	assert_false(menu.live_scene, "not in a test run by default")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(menu.stage == null)
	assert_true(menu._backdrop.visible)
	assert_almost_eq(menu._backdrop.modulate.a, 1.0, 0.0001)


func test_the_live_scene_builds_behind_the_backdrop_and_the_backdrop_fades_away() -> void:
	var menu := _live_menu()
	assert_true(menu.stage == null, "the screen is drawn first, the scene builds after")
	assert_almost_eq(menu._backdrop.modulate.a, 1.0, 0.0001, "the backdrop covers it")
	var settled := watch(menu.stage_settled)
	await menu.stage_settled
	assert_eq(settled.size(), 1)
	assert_true(settled[0][0] == true, "the scene is live")
	assert_true(menu.stage != null and menu.stage.running, "and runs")
	assert_true(menu.stage.camera.current)
	assert_true(menu.get_child(0) == menu.stage, "the scene is under the interface")
	await get_tree().create_timer(MainMenu.REVEAL_TIME + 0.3).timeout
	assert_almost_eq(menu._backdrop.modulate.a, 0.0, 0.01, "the backdrop is gone")
	assert_false(menu._backdrop.visible, "and no longer drawn")


func test_the_entries_work_over_the_live_scene() -> void:
	var menu := _live_menu()
	await menu.stage_settled
	var going := watch(menu.navigate)
	menu.options_button.pressed.emit()
	assert_true(menu.options.visible, "the options open over it")
	menu.options.close()
	assert_true(menu.options_button.has_focus())
	menu.new_game_button.pressed.emit()
	assert_true(menu.difficulty.visible)
	menu.difficulty.choose(&"night")
	assert_eq(going.size(), 1, "a new game is on its way")
	menu.quit_button.pressed.emit()
	assert_eq(going.size(), 2)
	assert_eq(going[1][0], MainMenu.QUIT)
	assert_true(menu.stage.running, "the scene keeps running behind the dialogs")


func test_without_the_art_the_menu_keeps_its_static_backdrop() -> void:
	MuseumFloorLevel.dress_default = true
	ArtLibrary.models_enabled = false
	var menu := _live_menu()
	var settled := watch(menu.stage_settled)
	await menu.stage_settled
	assert_true(settled[0][0] == false, "no live scene")
	assert_true(menu.stage == null, "given up")
	assert_true(menu._backdrop.visible)
	await get_tree().create_timer(MainMenu.FALLBACK_TIME + 0.3).timeout
	assert_almost_eq(menu._backdrop.modulate.a, 1.0, 0.01, "the old backdrop stands")
	menu.new_game_button.pressed.emit()
	assert_true(menu.difficulty.visible, "the entries work as before")


func test_a_scene_that_runs_too_slowly_is_given_up_and_the_backdrop_returns() -> void:
	var menu := _live_menu()
	await menu.stage_settled
	var stage := menu.stage
	stage.watch_always = true
	await get_tree().create_timer(MainMenu.REVEAL_TIME + 0.3).timeout
	assert_false(menu._backdrop.visible, "the live scene is showing")
	var settled := watch(menu.stage_settled)
	for i in 300:
		stage._process(0.085)
	assert_eq(settled.size(), 1)
	assert_true(settled[0][0] == false)
	assert_true(menu.stage == null)
	assert_true(menu._backdrop.visible, "the backdrop is on its way back")
	await get_tree().create_timer(MainMenu.FALLBACK_TIME + 0.3).timeout
	assert_almost_eq(menu._backdrop.modulate.a, 1.0, 0.01)
	assert_false(is_instance_valid(stage), "the scene is freed")


func test_a_menu_left_before_its_scene_is_built_does_no_harm() -> void:
	var menu := _live_menu()
	menu.free()
	for i in 6:
		await get_tree().process_frame
	var again := _live_menu()
	await again.stage_settled
	again.queue_free()
	await get_tree().process_frame
