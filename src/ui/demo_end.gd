class_name DemoEnd
extends Control
## The end of the demo (after the T-Rex, stage 2c): thanks, the run's
## statistics from GameState and the way back to the main menu. After Floor
## I (flag floor1_complete) it is the floor's end: how much of it was done
## (FloorCompletion), its secrets and chess pieces, a paragraph of what the
## guard saw going down, and what comes next.

signal navigate(target: String)

var back_button: Button
## The paragraph after Floor I (null at the end of the demo).
var epilogue: Label = null
## Stat key -> the Label showing its value.
var values: Dictionary = {}

var _texts := UiTexts.new()


func _ready() -> void:
	theme = UiTheme.theme()
	# anchors and offsets: added to a parent that has its size already
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameInput.set_gameplay_scene(false)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.04)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.custom_minimum_size = Vector2(760, 0)
	center.add_child(column)
	var floor_done := GameState.has_flag(ProgressRules.COMPLETE_FLAG)
	column.add_child(_texts.bind(UiTheme.caption(""), "END_FLOOR1_SUBTITLE" if floor_done else "DEMO_SUBTITLE", true))
	column.add_child(_texts.bind(UiTheme.heading("", 64), "DEMO_THANKS", true))
	column.add_child(UiTheme.rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	var minutes := int(float(GameState.stats["play_time"]) / 60.0)
	_stat(grid, "nights", "DEMO_NIGHTS", str(maxi(GameState.night, 1)))
	_stat(grid, "deaths", "DEMO_DEATHS", str(GameState.stats["deaths"]))
	_stat(grid, "time", "DEMO_TIME", "%d:%02d" % [minutes / 60, minutes % 60])
	_stat(grid, "dust", "DEMO_DUST", str(GameState.stats["dust_earned"]))
	if floor_done:
		var layout := Floor1Layout.create()
		var parts := FloorCompletion.parts(GameState, layout)
		_stat(grid, "completion", "END_FLOOR1_COMPLETION", "%d%%" % FloorCompletion.percent(GameState, layout))
		var secrets: Array = parts.get("secrets", [0, 0])
		_stat(grid, "secrets", "DEMO_SECRETS", "%d / %d" % [secrets[0], secrets[1]])
		_stat(grid, "rewards", "END_FLOOR1_REWARDS", "%d / %d" % [SecretRewards.claimed(GameState), SecretRewards.total()])
		var chess: Array = parts.get("chess", [0, FloorCompletion.CHESS])
		_stat(grid, "chess", "END_FLOOR1_CHESS", "%d / %d" % [chess[0], chess[1]])
	else:
		_stat(grid, "secrets", "DEMO_SECRETS", "%d / %d" % [LobbySecrets.found(GameState), LobbySecrets.total()])
	column.add_child(UiTheme.rule())
	if floor_done:
		# what the guard saw going down (a short paragraph), then what is next
		epilogue = UiTheme.label("", 26, UiTheme.MUTED)
		epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(_texts.bind(epilogue, "END_FLOOR1_EPILOGUE"))
		column.add_child(_texts.bind(UiTheme.caption(""), "END_FLOOR1_NEXT", true))
	back_button = UiTheme.menu_button("", 32)
	_texts.bind(back_button, "DEMO_BACK")
	back_button.pressed.connect(_on_back)
	column.add_child(back_button)
	back_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_texts.refresh()


func _stat(grid: GridContainer, id: String, key: String, value: String) -> void:
	grid.add_child(_texts.bind(UiTheme.label("", 28, UiTheme.MUTED), key))
	var shown := UiTheme.label(value, 30, UiTheme.TEXT, UiTheme.strong_font())
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(shown)
	values[id] = shown


func _on_back() -> void:
	Sfx.play_ui(&"ui_back")
	if SceneFlow.is_running(self):
		SceneFlow.goto(SceneFlow.MAIN_MENU)
	else:
		navigate.emit(SceneFlow.MAIN_MENU)
