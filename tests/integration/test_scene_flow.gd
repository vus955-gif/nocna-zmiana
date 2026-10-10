extends TestCase
## Scene paths and the fade overlay (no real scene swap inside the runner).


func test_scene_paths_exist() -> void:
	for path in [SceneFlow.MAIN_MENU, SceneFlow.MUSEUM, SceneFlow.SANDBOX, SceneFlow.DEMO_END]:
		assert_true(ResourceLoader.exists(path), path)


func test_main_scene_is_the_main_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), SceneFlow.MAIN_MENU)


func test_fade_overlay_starts_clear() -> void:
	assert_eq(SceneFlow.fade_level(), 0.0)
	assert_false(SceneFlow.busy)


func test_screens_built_by_tests_are_not_running() -> void:
	var node := Node.new()
	add_child(node)
	assert_false(SceneFlow.is_running(node))
	assert_false(SceneFlow.is_running(null))


## The real SceneFlow with the swap itself replaced: the new scene goes
## under the test instead of replacing the test runner.
class TestFlow extends "res://src/core/scene_flow.gd":
	var stage: Node = null
	var swapped: Node = null
	## What the input stack and the cursor looked like at the swap.
	var ui_at_swap: Variant = "unset"
	var gameplay_at_swap: bool = true

	func _swap(scene: Node) -> void:
		ui_at_swap = GameInput.top_ui()
		gameplay_at_swap = GameInput._gameplay_scene
		swapped = scene
		stage.add_child(scene)
		await get_tree().process_frame


## Reacts to a key (to see whether input gets through during a swap).
class KeyWatcher extends Node:
	var keys: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			keys += 1


func _flow() -> TestFlow:
	var flow := TestFlow.new()
	flow.stage = self
	add_child(flow)
	return flow


func test_goto_fades_swaps_and_fades_back_one_at_a_time() -> void:
	var flow := _flow()
	var changed := watch(flow.changed)
	var watcher := KeyWatcher.new()
	add_child(watcher)
	var menu := Node.new()
	GameInput.set_gameplay_scene(true)
	GameInput.push_ui(menu)
	get_tree().paused = true
	assert_true(flow.goto(SceneFlow.DEMO_END))
	assert_true(flow.busy)
	assert_false(flow.goto(SceneFlow.MAIN_MENU), "one change at a time")
	assert_false(flow.quit(), "no quitting in the middle either")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	Input.parse_input_event(up)
	assert_eq(watcher.keys, 0, "input is swallowed during the change")
	await flow.changed
	assert_eq(changed.size(), 1)
	assert_eq(changed[0][0], SceneFlow.DEMO_END)
	assert_eq(flow.ui_at_swap, null, "every menu let go before the swap")
	assert_false(flow.gameplay_at_swap, "the cursor was released first")
	assert_false(get_tree().paused)
	assert_true(flow.swapped is DemoEnd)
	while flow.busy:
		await get_tree().process_frame
	assert_eq(flow.fade_level(), 0.0)
	flow.swapped.free()
	menu.free()


func test_goto_refuses_what_is_no_scene() -> void:
	var flow := _flow()
	assert_false(flow.goto("res://no/such/scene.tscn"))
	assert_false(flow.busy)
	assert_eq(flow.fade_level(), 0.0)


func test_callers_leave_nothing_half_done_while_a_change_runs() -> void:
	GameState.new_game()
	var museum := (load(SceneFlow.MUSEUM) as PackedScene).instantiate() as Museum
	add_child(museum)
	var quits := watch(museum.quit_requested)
	SceneFlow.busy = true
	museum.quit_to_menu()
	museum.quit_game()
	SceneFlow.busy = false
	assert_eq(quits.size(), 0)
	assert_true(RunState.running, "the night was not ended by a refused quit")
	museum.quit_to_menu()
	assert_eq(quits.size(), 1)
	museum.free()


func test_a_night_starts_under_the_loading_screen_with_a_tip() -> void:
	Museum.level_id = &"floor1"
	GameState.new_game()
	GameState.night = 3
	var flow := _flow()
	var shown := [false, ""]
	assert_true(flow.goto(SceneFlow.MUSEUM))
	while flow.busy and not flow.loading.visible:
		await get_tree().process_frame
	shown[0] = flow.loading.visible
	shown[1] = flow.loading._night.text
	assert_true(shown[0], "the loading screen over the fade")
	assert_eq(shown[1], (tr("HUD_NIGHT") % 3).to_upper())
	assert_true(flow.loading.tip_key.begins_with("TIP_") or flow.loading.tip_key == "LOADING_TIP_NONE")
	assert_eq(flow.loading._tip.text, tr(flow.loading.tip_key))
	await flow.changed
	assert_false(flow.loading.visible, "gone once the museum stands")
	assert_true(flow.swapped is Museum)
	assert_true(ShellCarver.is_carved(LevelBuilder.new((flow.swapped as Museum).floor_level.layout, null, null, null).shell_volumes()), "the shell was made before the build")
	while flow.busy:
		await get_tree().process_frame
	flow.swapped.free()
	Museum.level_id = &"lobby"


func test_the_tips_are_read_from_the_translations() -> void:
	var keys := LoadingScreen.tip_keys()
	var in_csv := 0
	for line in FileAccess.get_file_as_string("res://locale/strings.csv").split("\n"):
		if RegEx.create_from_string("^TIP_[0-9]+,").search(line) != null:
			in_csv += 1
	assert_eq(keys.size(), in_csv, "every TIP_n there is")
	if keys.size() > 1:
		var last := LoadingScreen.pick_tip()
		for i in 20:
			var next := LoadingScreen.pick_tip()
			assert_ne(next, last, "never the same tip twice in a row")
			last = next
