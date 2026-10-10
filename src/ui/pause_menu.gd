class_name PauseMenu
extends CanvasLayer
## Esc during play: the game pauses and the guard lets go of the input
## (through GameInput, which owns the cursor). Resume, Options, Notes (the
## notes read so far, each opened again in the note reader over this menu;
## only in a game with a reader and once a note was read), Quit to the
## main menu, Quit the game. Losing the window's focus opens it too, so a
## click back into the window never fires a shot. The game scene handles
## the quit requests (it saves first).

signal quit_to_menu_requested
signal quit_game_requested

## The notes panel: its width and the height of its scrolling list.
const NOTES_WIDTH := 900.0
const NOTES_HEIGHT := 600.0

## Show "Night n · Dust d" above the title (the Museum; not the sandbox).
var show_night_info: bool = false
var is_open: bool = false
## Off while the guard is dying or a scene is being swapped.
var allowed: bool = true
## The world's note reader (the Museum sets it; null: no notes entry).
var note_reader: NoteReader = null:
	set(value):
		if is_instance_valid(note_reader) and note_reader.closed.is_connected(_on_note_closed):
			note_reader.closed.disconnect(_on_note_closed)
		note_reader = value
		if is_instance_valid(note_reader):
			note_reader.closed.connect(_on_note_closed)
## Whose notes are listed (GameState when unset).
var game: PersistentState = null
## The paper museum map (Floor I sets it; null: no map entry). It opens
## over this menu and gives the focus back to its entry when put down.
var museum_map: MuseumMap = null:
	set(value):
		if is_instance_valid(museum_map) and museum_map.closed.is_connected(_on_map_closed):
			museum_map.closed.disconnect(_on_map_closed)
		museum_map = value
		if is_instance_valid(museum_map):
			museum_map.closed.connect(_on_map_closed)

var _texts := UiTexts.new()
var _panel: PanelContainer
var _info: Label
var _resume: Button
var _options_button: Button
var _map_button: Button
var _options: OptionsMenu
var _notes_button: Button
var _notes: PanelContainer
var _notes_scroll: ScrollContainer
var _notes_list: VBoxContainer
var _notes_back: Button
## The note open from the list (its button takes the focus back).
var _reading: StringName = &""
var _paused_here: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open() -> void:
	if is_open or not allowed:
		return
	is_open = true
	visible = true
	_panel.visible = true
	_notes.visible = false
	_notes_button.visible = not read_notes().is_empty()
	_map_button.visible = is_instance_valid(museum_map)
	_info.visible = show_night_info
	_refresh_info()
	_paused_here = not get_tree().paused
	get_tree().paused = true
	GameInput.push_ui(self)
	_resume.grab_focus()
	Sfx.play_ui(&"ui_confirm", -4.0)


func close() -> void:
	if not is_open:
		return
	if _options.visible:
		_options.close()
	if is_instance_valid(note_reader) and note_reader.is_open:
		note_reader.close()
	if is_instance_valid(museum_map) and museum_map.is_open:
		museum_map.close()
	_notes.visible = false
	is_open = false
	visible = false
	get_viewport().gui_release_focus()
	if _paused_here:
		get_tree().paused = false
	GameInput.pop_ui(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if is_open:
		if _options.visible or GameInput.top_ui() != self:
			return   # the options menu (or a note over this menu) answers Esc itself
		if _notes.visible:
			_close_notes()
			Sfx.play_ui(&"ui_back")
			get_viewport().set_input_as_handled()
			return
		close()
		Sfx.play_ui(&"ui_back")
		get_viewport().set_input_as_handled()
	elif GameInput.top_ui() == null:
		open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if GameInput.should_pause_unfocused():
				open()
		NOTIFICATION_TRANSLATION_CHANGED:
			if _panel != null:
				_texts.refresh()
				_refresh_info()
				if _notes.visible:
					_fill_notes()


## The notes read so far, in reading order (none without a reader).
func read_notes() -> Array[StringName]:
	if not is_instance_valid(note_reader):
		return []
	return NoteCatalog.read_notes(game if game != null else GameState)


## Shows the list of notes read (the main panel steps aside): a scrolling
## list grouped by the wing (zone) each lies in, each note's title with its
## writer's signature.
func open_notes() -> void:
	if not is_open or read_notes().is_empty():
		return
	var first := _fill_notes()
	_panel.visible = false
	_notes.visible = true
	_notes_scroll.scroll_vertical = 0
	first.grab_focus()
	Sfx.play_ui(&"ui_confirm", -4.0)


## Builds the list anew; returns its first entry.
func _fill_notes() -> Button:
	for child in _notes_list.get_children():
		_notes_list.remove_child(child)
		child.queue_free()
	var first: Button = null
	var group := &"-"
	for id in read_notes():
		var zone := NoteCatalog.zone_of(id)
		if zone != group:
			group = zone
			var key := String(Floor1Plan.zone_name_key(zone)) if zone != &"" else "PAUSE_NOTES_LOBBY"
			var header := UiTheme.caption(tr(key).to_upper() if key != "" else "", 18, UiTheme.ACCENT)
			header.name = "Group_" + (String(zone) if zone != &"" else "lobby")
			_notes_list.add_child(header)
		var entry := UiTheme.menu_button(NoteCatalog.title(id), 26)
		entry.name = String(id)
		entry.custom_minimum_size = Vector2(0, 50)
		entry.pressed.connect(read_note.bind(id))
		var signature := TranslationServer.translate(NoteCatalog.sign_key(id))
		if signature != NoteCatalog.sign_key(id):
			var writer := UiTheme.label(signature, 19, UiTheme.MUTED)
			writer.name = "Signature"
			writer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
			writer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			entry.add_child(writer)
		_notes_list.add_child(entry)
		if first == null:
			first = entry
	return first


## Opens note [param id] from the list in the reader over this menu.
func read_note(id: StringName) -> void:
	if not is_instance_valid(note_reader) or note_reader.is_open:
		return
	_reading = id
	get_viewport().gui_release_focus()
	note_reader.open_note(id)


## Opens the museum map over this menu.
func open_map() -> void:
	if not is_open or not is_instance_valid(museum_map) or museum_map.is_open:
		return
	get_viewport().gui_release_focus()
	museum_map.open()


## The map is put down: its entry takes the focus again.
func _on_map_closed() -> void:
	if is_open and _panel.visible:
		_map_button.grab_focus.call_deferred()


## Titles of the notes the list shows (tests).
func listed_notes() -> Array[String]:
	var titles: Array[String] = []
	for child in _notes_list.get_children():
		if child is Button and not child.is_queued_for_deletion():
			titles.append((child as Button).text)
	return titles


## The list's group headers (tests).
func listed_groups() -> Array[String]:
	var found: Array[String] = []
	for child in _notes_list.get_children():
		if child is Label and not child.is_queued_for_deletion():
			found.append((child as Label).text)
	return found


func notes_shown() -> bool:
	return is_open and _notes.visible


func _close_notes() -> void:
	_notes.visible = false
	_panel.visible = true
	_notes_button.grab_focus()


## The note is put down: its entry takes the focus again.
func _on_note_closed(_id: StringName) -> void:
	if not is_open or not _notes.visible:
		return
	var entry := _notes_list.get_node_or_null(NodePath(String(_reading))) as Button
	if entry != null:
		entry.grab_focus.call_deferred()


## "Night n · Dust d" in the current language.
func _refresh_info() -> void:
	if show_night_info and _info != null:
		_info.text = (tr("PAUSE_INFO") % [GameState.night, RunState.dust]).to_upper()


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = UiTheme.SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(44.0))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_info = UiTheme.caption("")
	column.add_child(_info)
	column.add_child(_texts.bind(UiTheme.heading("", 58), "PAUSE_TITLE", true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)
	_resume = _button(column, "PAUSE_RESUME", close)
	_map_button = _button(column, "PAUSE_MAP", open_map)
	_map_button.visible = false
	_options_button = _button(column, "MENU_OPTIONS", _open_options)
	_notes_button = _button(column, "PAUSE_NOTES", open_notes)
	_notes_button.visible = false
	_button(column, "PAUSE_QUIT_TO_MENU", func() -> void: quit_to_menu_requested.emit())
	_button(column, "PAUSE_QUIT_GAME", func() -> void: quit_game_requested.emit())
	_options = OptionsMenu.new()
	_options.in_night = true
	_options.closed.connect(_on_options_closed)
	root.add_child(_options)
	_build_notes(center)


## The notes panel: a heading, one button per note read, back.
func _build_notes(center: CenterContainer) -> void:
	_notes = PanelContainer.new()
	_notes.name = "Notes"
	_notes.custom_minimum_size = Vector2(NOTES_WIDTH, 0)
	_notes.add_theme_stylebox_override("panel", UiTheme.panel_style(44.0))
	_notes.visible = false
	center.add_child(_notes)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_notes.add_child(column)
	column.add_child(_texts.bind(UiTheme.caption(""), "PAUSE_NOTES_CAPTION", true))
	column.add_child(_texts.bind(UiTheme.heading("", 52), "PAUSE_NOTES", true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap)
	_notes_scroll = ScrollContainer.new()
	_notes_scroll.custom_minimum_size = Vector2(0, NOTES_HEIGHT)
	_notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_notes_scroll.follow_focus = true
	column.add_child(_notes_scroll)
	_notes_list = VBoxContainer.new()
	_notes_list.add_theme_constant_override("separation", 4)
	_notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_scroll.add_child(_notes_list)
	var gap_below := Control.new()
	gap_below.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap_below)
	_notes_back = _button(column, "OPT_BACK", func() -> void:
		_close_notes()
		Sfx.play_ui(&"ui_back"))


func _button(column: VBoxContainer, key: String, action: Callable) -> Button:
	var button := UiTheme.menu_button("", 34)
	button.custom_minimum_size = Vector2(0, 62)
	_texts.bind(button, key)
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _open_options() -> void:
	_panel.visible = false
	_options.open()
	Sfx.play_ui(&"ui_confirm", -4.0)


func _on_options_closed() -> void:
	_panel.visible = true
	_options_button.grab_focus()
