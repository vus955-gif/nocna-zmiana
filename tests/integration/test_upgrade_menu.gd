extends TestCase
## The upgrade terminal and its menu (GameState/RunState autoloads, reset
## by the runner between tests).

var menu: UpgradeMenu


func before_each() -> void:
	menu = UpgradeMenu.new()
	add_child(menu)


func after_each() -> void:
	if menu.is_open:
		menu.close()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _row_of(id: StringName) -> int:
	return menu._row_ids.find(id)


func test_terminal_opens_the_menu_and_pauses() -> void:
	var terminal := UpgradeTerminal.new()
	add_child(terminal)
	terminal.opened.connect(func(_by: Node) -> void: menu.open(GameState, RunState))
	assert_eq(terminal.collision_layer, Layers.INTERACT)
	terminal.interact(null)
	assert_true(menu.is_open)
	assert_true(menu.visible)
	assert_true(get_tree().paused)
	assert_false(GameInput.gameplay_input(), "the guard takes no input")


func test_menu_lists_every_upgrade_with_its_price() -> void:
	menu.open(GameState, RunState)
	assert_eq(menu._rows.size(), UpgradeCatalog.all().size())
	assert_eq((menu._prices[&"health"] as Label).text, "25")
	assert_eq((menu._prices[&"shotgun_slug"] as Label).text, "80")
	assert_eq(menu.selected_id(), &"health")


func test_buying_with_enough_dust() -> void:
	RunState.add_dust(30, false)
	var bought := watch(Events.upgrade_bought)
	menu.open(GameState, RunState)
	menu.select(_row_of(&"health"))
	assert_true(menu.buy_selected())
	assert_eq(menu.last_feedback, &"buy")
	assert_eq(GameState.upgrade_level(&"health"), 1)
	assert_eq(RunState.dust, 5)
	assert_eq(bought.size(), 1)
	assert_eq((menu._prices[&"health"] as Label).text, "50", "next level's price")
	assert_eq(menu._dust_label.text, "5")
	assert_eq((menu._pips[&"health"] as UpgradeMenu.Pips).filled, 1)


func test_buying_is_denied_when_short() -> void:
	RunState.add_dust(10, false)
	menu.open(GameState, RunState)
	menu.select(_row_of(&"health"))
	assert_false(menu.buy_selected())
	assert_eq(menu.last_feedback, &"deny")
	assert_eq(GameState.upgrade_level(&"health"), 0)
	assert_eq(RunState.dust, 10)
	assert_true(menu._buy.disabled)
	assert_eq((menu._prices[&"health"] as Label).get_theme_color("font_color"), UiTheme.DANGER)


func test_maxed_upgrade_shows_max_and_is_denied() -> void:
	GameState.upgrades[&"shotgun_slug"] = 1
	RunState.add_dust(500, false)
	menu.open(GameState, RunState)
	assert_eq((menu._prices[&"shotgun_slug"] as Label).text, tr("TERMINAL_MAX_SHORT"))
	menu.select(_row_of(&"shotgun_slug"))
	assert_false(menu.buy_selected())
	assert_eq(RunState.dust, 500)


func test_keyboard_moves_the_selection() -> void:
	menu.open(GameState, RunState)
	await get_tree().process_frame
	assert_eq(menu._selected, 0)
	await _press(&"ui_down")
	assert_eq(menu.selected_id(), &"stamina")
	await _press(&"ui_up")
	assert_eq(menu.selected_id(), &"health")


func _playing(sound: StringName) -> bool:
	for voice in Sfx.get_children():
		if voice.get_meta(&"sound", &"") == sound and not voice.is_queued_for_deletion():
			return true
	return false


func test_buy_and_deny_sounds() -> void:
	RunState.add_dust(30, false)
	menu.open(GameState, RunState)
	menu.select(_row_of(&"health"))
	menu.buy_selected()
	assert_true(_playing(&"buy"))
	menu.buy_selected()
	assert_true(_playing(&"deny"), "25 left, 50 needed")


func test_closing_unpauses_and_returns_input() -> void:
	var closed := watch(menu.closed)
	menu.open(GameState, RunState)
	await get_tree().process_frame
	await _press(&"ui_cancel")
	assert_false(menu.is_open)
	assert_false(get_tree().paused)
	await physics_frames(2)
	assert_true(GameInput.gameplay_input())
	assert_eq(closed.size(), 1)
