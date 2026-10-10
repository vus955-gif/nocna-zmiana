extends TestCase
## The end-of-demo screen.


func test_shows_the_stats() -> void:
	GameState.night = 6
	GameState.stats = {"deaths": 5, "nights": 5, "dust_earned": 640, "play_time": 3725.0, "bosses": 1}
	GameState.secrets = [&"painting", &"vent"]
	var screen := (load(SceneFlow.DEMO_END) as PackedScene).instantiate() as DemoEnd
	add_child(screen)
	assert_eq(screen.values["nights"].text, "6")
	assert_eq(screen.values["deaths"].text, "5")
	assert_eq(screen.values["time"].text, "1:02")
	assert_eq(screen.values["dust"].text, "640")
	assert_eq(screen.values["secrets"].text, "2 / 6")
	var going := watch(screen.navigate)
	screen.back_button.pressed.emit()
	assert_eq(going.size(), 1)
	if going.size() == 1:
		assert_eq(going[0][0], SceneFlow.MAIN_MENU)
	assert_true(screen.epilogue == null, "the demo's end tells no tale of the floor below")


func test_the_end_of_floor_one_tells_what_lies_below() -> void:
	GameState.set_flag(ProgressRules.COMPLETE_FLAG)
	var screen := (load(SceneFlow.DEMO_END) as PackedScene).instantiate() as DemoEnd
	add_child(screen)
	assert_not_null(screen.epilogue)
	assert_eq(screen.epilogue.text, tr("END_FLOOR1_EPILOGUE"))
	assert_gt(screen.epilogue.text.length(), 100, "a paragraph")
	Settings.set_value(&"language", "en", false)
	await get_tree().process_frame
	assert_true(screen.epilogue.text.begins_with("The crystal"), "follows the language")
	Settings.set_value(&"language", "pl", false)
	screen.free()
