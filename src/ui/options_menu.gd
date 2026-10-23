class_name OptionsMenu
extends Control
## Every player option in one scrollable panel, grouped into controls,
## video, sound and interface. Changes apply live and Settings writes them a
## moment later (at the latest when the menu closes, Back or Esc, or the
## game quits). Works over the main menu and the pause menu.
## With a game going (a save, or a night in progress) a last section shows
## the game's difficulty: changed between nights (the main menu) it is
## saved at once; changed during a night ([member in_night]) the exhibits'
## sight follows at once and their strength and the loot from the next
## night (a note says so), saved with the night's next save.

signal closed

var rows: Array[OptionRow] = []
## The row that opens the keys' panel (not a setting: kept apart from
## [member rows]) and the panel.
var keys_row: OptionRow
var keys_panel: KeyBindingsPanel
## The game's difficulty (not a setting: kept apart from [member rows]).
var difficulty_row: OptionRow
## Opened from the pause menu: a night is in progress.
var in_night: bool = false

var _texts := UiTexts.new()
var _scroll: ScrollContainer
var _back: Button
var _reset: Button
var _game_section: VBoxContainer
var _difficulty_note: Label


func _ready() -> void:
	theme = UiTheme.theme()
	# anchors and offsets: added to a parent that has its size already
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open() -> void:
	visible = true
	for row in rows:
		row.refresh()
	keys_row.refresh()
	_game_section.visible = in_night or GameState.has_save()
	difficulty_row.refresh()
	_refresh_note()
	_scroll.scroll_vertical = 0
	rows[0].grab_focus()


func close() -> void:
	if not visible:
		return
	if keys_panel.visible:
		keys_panel.close()
	Settings.flush()
	visible = false
	Sfx.play_ui(&"ui_back")
	closed.emit()


func reset_to_defaults() -> void:
	Settings.reset_to_defaults(true)   # the keys go back too
	for row in rows:
		row.refresh()
	keys_row.refresh()
	Sfx.play_ui(&"ui_confirm")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _scroll != null:
		_texts.refresh()
		for row in rows:
			row.refresh()
		keys_row.refresh()
		if difficulty_row != null:
			difficulty_row.refresh()
			_refresh_note()


## The game's difficulty changes: the save's, the exhibits' sight now.
func set_difficulty(shift: StringName) -> void:
	if not DifficultyRules.IDS.has(shift) or GameState.difficulty == shift:
		return
	GameState.difficulty = shift
	PerceptionWorld.set_difficulty(DifficultyRules.index(shift))
	if not in_night:
		GameState.save_game()
	_refresh_note()


## What the chosen difficulty means, and (in a night) when it takes hold.
func _refresh_note() -> void:
	var text := tr(DifficultyDialog.detail_key(GameState.difficulty))
	if in_night:
		text += "\n" + tr("OPT_DIFFICULTY_NIGHT_NOTE")
	_difficulty_note.text = text


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = UiTheme.SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 880)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(40.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(_texts.bind(UiTheme.caption(""), "OPT_SUBTITLE", true))
	column.add_child(_texts.bind(UiTheme.heading("", 46), "OPT_TITLE", true))
	column.add_child(UiTheme.rule())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	_scroll.add_child(list)
	_section(list, "OPT_SECTION_CONTROLS")
	_add(list, OptionRow.slider(&"mouse_sensitivity", "OPT_SENSITIVITY", SettingsData.SENSITIVITY_MIN, SettingsData.SENSITIVITY_MAX, 0.05, func(v: float) -> String: return "%.2f" % v))
	_add(list, OptionRow.toggle(&"invert_y", "OPT_INVERT_Y"))
	_add(list, OptionRow.slider(&"fov", "OPT_FOV", SettingsData.FOV_MIN, SettingsData.FOV_MAX, 1.0, func(v: float) -> String: return "%d°" % roundi(v)))
	_add(list, OptionRow.slider(&"screen_shake", "OPT_SCREEN_SHAKE", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"head_bob", "OPT_HEAD_BOB", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.toggle(&"sprint_toggle", "OPT_SPRINT_TOGGLE"))
	keys_row = OptionRow.action("OPT_KEYS", _keys_summary)
	keys_row.activated.connect(open_keys)
	list.add_child(keys_row)
	_section(list, "OPT_SECTION_VIDEO")
	_add(list, OptionRow.choice(&"window_mode", "OPT_WINDOW_MODE", [
		[SettingsData.WindowMode.WINDOWED, "OPT_WINDOW_WINDOWED"],
		[SettingsData.WindowMode.MAXIMIZED, "OPT_WINDOW_MAXIMIZED"],
		[SettingsData.WindowMode.FULLSCREEN, "OPT_WINDOW_FULLSCREEN"],
		[SettingsData.WindowMode.EXCLUSIVE, "OPT_WINDOW_EXCLUSIVE"],
	]))
	_add(list, OptionRow.toggle(&"vsync", "OPT_VSYNC"))
	var limits: Array = []
	for fps in SettingsData.FPS_CHOICES:
		limits.append([fps, "OPT_FPS_UNLIMITED" if fps == 0 else str(fps)])
	_add(list, OptionRow.choice(&"max_fps", "OPT_MAX_FPS", limits))
	_add(list, OptionRow.slider(&"render_scale", "OPT_RENDER_SCALE", SettingsData.RENDER_SCALE_MIN, SettingsData.RENDER_SCALE_MAX, 0.05, _percent))
	_add(list, OptionRow.choice(&"upscaler", "OPT_UPSCALER", [
		[SettingsData.Upscaler.BILINEAR, "OPT_UPSCALER_BILINEAR"],
		[SettingsData.Upscaler.FSR, "OPT_UPSCALER_FSR"],
		[SettingsData.Upscaler.FSR2, "OPT_UPSCALER_FSR2"],
	]))
	var quality := OptionRow.choice(&"graphics_quality", "OPT_GRAPHICS", [
		[GraphicsQuality.Quality.LOW, "OPT_GRAPHICS_LOW"],
		[GraphicsQuality.Quality.MEDIUM, "OPT_GRAPHICS_MEDIUM"],
		[GraphicsQuality.Quality.HIGH, "OPT_GRAPHICS_HIGH"],
		[GraphicsQuality.Quality.ULTRA, "OPT_GRAPHICS_ULTRA"],
	])
	# a preset brings its render scale: show it on that row too
	quality.value_changed.connect(func(_key: StringName) -> void:
		for row in rows:
			row.refresh())
	_add(list, quality)
	_section(list, "OPT_SECTION_AUDIO")
	_add(list, OptionRow.slider(&"volume_master", "OPT_VOLUME_MASTER", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"volume_sfx", "OPT_VOLUME_SFX", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"volume_music", "OPT_VOLUME_MUSIC", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"volume_ambience", "OPT_VOLUME_AMBIENCE", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"volume_voice", "OPT_VOLUME_VOICE", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.slider(&"volume_ui", "OPT_VOLUME_UI", 0.0, 1.0, 0.05, _percent))
	_section(list, "OPT_SECTION_INTERFACE")
	_add(list, OptionRow.choice(&"language", "OPT_LANGUAGE", [["pl", "LANG_PL"], ["en", "LANG_EN"]]))
	_add(list, OptionRow.toggle(&"show_fps", "OPT_SHOW_FPS"))
	_add(list, OptionRow.toggle(&"subtitles", "OPT_SUBTITLES"))
	_add(list, OptionRow.toggle(&"dev_tools", "OPT_DEV_TOOLS"))
	_section(list, "OPT_SECTION_ACCESS")
	_add(list, OptionRow.slider(&"hud_scale", "OPT_HUD_SCALE", SettingsData.HUD_SCALE_MIN, SettingsData.HUD_SCALE_MAX, 0.05, _percent))
	_add(list, OptionRow.choice(&"subtitle_size", "OPT_SUBTITLE_SIZE", [
		[SettingsData.SubtitleSize.SMALL, "OPT_SUBTITLE_SIZE_SMALL"],
		[SettingsData.SubtitleSize.MEDIUM, "OPT_SUBTITLE_SIZE_MEDIUM"],
		[SettingsData.SubtitleSize.LARGE, "OPT_SUBTITLE_SIZE_LARGE"],
	]))
	_add(list, OptionRow.slider(&"subtitle_backing", "OPT_SUBTITLE_BACKING", 0.0, 1.0, 0.05, _percent))
	_add(list, OptionRow.toggle(&"reduce_flashing", "OPT_REDUCE_FLASHING"))
	_add(list, OptionRow.choice(&"colour_vision", "OPT_COLOUR_VISION", [
		[SettingsData.ColourVisionMode.NORMAL, "OPT_COLOUR_VISION_NORMAL"],
		[SettingsData.ColourVisionMode.DEUTERANOPIA, "OPT_COLOUR_VISION_DEUTERANOPIA"],
		[SettingsData.ColourVisionMode.PROTANOPIA, "OPT_COLOUR_VISION_PROTANOPIA"],
		[SettingsData.ColourVisionMode.TRITANOPIA, "OPT_COLOUR_VISION_TRITANOPIA"],
	]))
	_game_section = VBoxContainer.new()
	_game_section.add_theme_constant_override("separation", 2)
	list.add_child(_game_section)
	_section(_game_section, "OPT_SECTION_GAME")
	var shifts: Array = []
	for id in DifficultyRules.IDS:
		shifts.append([id, DifficultyDialog.name_key(id)])
	difficulty_row = OptionRow.bound_choice("OPT_DIFFICULTY", shifts, func() -> StringName: return GameState.difficulty, set_difficulty)
	_game_section.add_child(difficulty_row)
	_difficulty_note = UiTheme.label("", 20, UiTheme.MUTED)
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note_margin := MarginContainer.new()
	note_margin.add_theme_constant_override("margin_left", 26)
	note_margin.add_theme_constant_override("margin_right", 22)
	note_margin.add_child(_difficulty_note)
	_game_section.add_child(note_margin)
	column.add_child(UiTheme.rule())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 24)
	_reset = UiTheme.menu_button("", 26)
	_texts.bind(_reset, "OPT_RESET")
	_reset.pressed.connect(reset_to_defaults)
	footer.add_child(_reset)
	var hints := UiTheme.caption("", 18)
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_texts.bind(hints, "OPT_HINTS", true))
	_back = UiTheme.menu_button("", 26)
	_texts.bind(_back, "OPT_BACK")
	_back.pressed.connect(close)
	footer.add_child(_back)
	column.add_child(footer)
	keys_panel = KeyBindingsPanel.new()
	add_child(keys_panel)
	keys_panel.closed.connect(_on_keys_closed)


## The keys' panel opens over the options.
func open_keys() -> void:
	Sfx.play_ui(&"ui_confirm", -4.0)
	keys_panel.open()


func _on_keys_closed() -> void:
	keys_row.refresh()
	keys_row.grab_focus()


func _keys_summary() -> Array:
	var changed := not Settings.data.bindings.is_default()
	return [tr("OPT_KEYS_CUSTOM") if changed else tr("OPT_KEYS_DEFAULT"), changed]


func _section(list: VBoxContainer, key: String) -> void:
	if list.get_child_count() > 0 or list == _game_section:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 12)
		list.add_child(gap)
	list.add_child(_texts.bind(UiTheme.caption("", 18), key, true))


func _add(list: VBoxContainer, row: OptionRow) -> void:
	rows.append(row)
	list.add_child(row)


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
