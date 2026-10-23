class_name UpgradeMenu
extends CanvasLayer
## The upgrade terminal's screen: every upgrade grouped by category with its
## level pips and price, the chosen one's details on the right and the
## carried Dust on top. Keyboard (arrows or W/S, Enter/Space to buy, Esc or E
## to leave) and mouse (hover, click). While open the game is paused and the
## guard takes no input.

signal closed

const ROW_HEIGHT := 54
const LIST_WIDTH := 700
const DETAILS_WIDTH := 500

## The persistent and night state being shown (GameState / RunState).
var game: PersistentState = null
var run: NightState = null
var is_open: bool = false
## &"buy" or &"deny" after the last purchase attempt.
var last_feedback: StringName = &""

var _rows: Array[Button] = []
var _row_ids: Array[StringName] = []
var _names: Dictionary = {}
var _pips: Dictionary = {}
var _prices: Dictionary = {}
var _price_icons: Dictionary = {}
var _selected: int = 0
var _paused_here: bool = false
var _dust_label: Label
var _title: Label
var _category: Label
var _level: Label
var _description: Label
var _status: Label
var _buy: Button
var _details: VBoxContainer
var _root: Control = null
var _rebuild_pending: bool = false
var _shake_tween: Tween = null
## Where the details column sits when not shaking.
var _shake_origin: float = 0.0


## Level pips: filled for bought levels, rings for the rest.
class Pips extends Control:
	var total: int = 1
	var filled: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_levels(filled_levels: int, total_levels: int) -> void:
		filled = filled_levels
		total = total_levels
		custom_minimum_size = Vector2(total * 20, 20)
		queue_redraw()

	func _draw() -> void:
		for i in total:
			var center := Vector2(10 + i * 20, size.y * 0.5)
			if i < filled:
				draw_circle(center, 6.0, UiTheme.ACCENT)
			else:
				draw_arc(center, 5.5, 0.0, TAU, 20, UiTheme.MUTED, 1.5, true)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Shows the menu for this game and night; pauses the game.
func open(game_state: PersistentState, run_state: NightState) -> void:
	if is_open:
		return
	game = game_state
	run = run_state
	_rebuild()   # a language change still waiting
	is_open = true
	visible = true
	last_feedback = &""
	_paused_here = not get_tree().paused
	get_tree().paused = true
	GameInput.push_ui(self)
	_refresh()
	select(_selected)
	_scroll_home()


## With the first row selected the list stands at its top, its category's
## caption in view (the focus alone scrolls it a little too far on opening).
func _scroll_home() -> void:
	if _selected != 0 or _rows.is_empty():
		return
	var scroll := _rows[0].get_parent().get_parent() as ScrollContainer
	if scroll != null:
		scroll.set_deferred(&"scroll_vertical", 0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_viewport().gui_release_focus()
	if _paused_here:
		get_tree().paused = false
	GameInput.pop_ui(self)
	Sfx.play_ui(&"ui_back")
	closed.emit()


func selected_id() -> StringName:
	return _row_ids[_selected]


func select(index: int) -> void:
	_selected = clampi(index, 0, _rows.size() - 1)
	if is_open and not _rows[_selected].has_focus():
		_rows[_selected].grab_focus()
	_show_details()


## Tries to buy the next level of the selected upgrade.
func buy_selected() -> bool:
	var id := selected_id()
	if game != null and run != null and game.buy_upgrade(id, run):
		last_feedback = &"buy"
		Sfx.play_ui(&"buy")
		_refresh()
		_status.text = tr("TERMINAL_INSTALLED")
		_status.add_theme_color_override("font_color", UiTheme.GOOD)
		_pulse(_rows[_selected])
		return true
	last_feedback = &"deny"
	Sfx.play_ui(&"deny")
	_shake(_details)
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _root != null and not _rebuild_pending:
		# every text again in the new language, but not now: the change is
		# announced while the tree walks this node's children
		_rebuild_pending = true
		_rebuild.call_deferred()


## Builds the screen again (texts in the current language).
func _rebuild() -> void:
	if not _rebuild_pending:
		return
	_rebuild_pending = false
	_root.queue_free()
	_rows.clear()
	_row_ids.clear()
	_build()
	_refresh()
	if is_open:
		select(_selected)


func _build() -> void:
	var root := Control.new()
	_root = root
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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(LIST_WIDTH + DETAILS_WIDTH + 150, 820)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(40.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(_build_header())
	column.add_child(UiTheme.rule())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 48)
	column.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_details())
	column.add_child(UiTheme.rule())
	column.add_child(_build_hints())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.add_child(UiTheme.caption(tr("TERMINAL_SUBTITLE").to_upper()))
	titles.add_child(UiTheme.heading(tr("TERMINAL_TITLE").to_upper(), 46))
	header.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var dust := HBoxContainer.new()
	dust.add_theme_constant_override("separation", 12)
	dust.alignment = BoxContainer.ALIGNMENT_END
	dust.add_child(DustIcon.make(1.3))
	_dust_label = UiTheme.label("0", 44, UiTheme.DUST, UiTheme.strong_font())
	dust.add_child(_dust_label)
	var dust_caption := UiTheme.caption(tr("TERMINAL_DUST").to_upper())
	dust_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dust.add_child(dust_caption)
	header.add_child(dust)
	return header


func _build_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	for category in UpgradeCatalog.CATEGORIES:
		var caption := UiTheme.caption(tr(UpgradeCatalog.category_key(category)).to_upper(), 18)
		if list.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 10)
			list.add_child(gap)
		list.add_child(caption)
		for entry in UpgradeCatalog.all():
			if entry.category == category:
				list.add_child(_build_row(entry))
	return scroll


func _build_row(entry: UpgradeCatalog.Entry) -> Button:
	var row := UiTheme.menu_button("", 26)
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var index := _rows.size()
	_rows.append(row)
	_row_ids.append(entry.id)
	var content := HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 26.0
	content.offset_right = -18.0
	content.add_theme_constant_override("separation", 18)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var title := UiTheme.label(tr(entry.name_key()), 26, UiTheme.TEXT, UiTheme.strong_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(title)
	var pips := Pips.new()
	pips.set_levels(0, entry.max_level())
	content.add_child(pips)
	var price_box := HBoxContainer.new()
	price_box.custom_minimum_size = Vector2(96, 0)
	price_box.alignment = BoxContainer.ALIGNMENT_END
	price_box.add_theme_constant_override("separation", 6)
	price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price := UiTheme.label("", 26, UiTheme.TEXT, UiTheme.strong_font())
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_box.add_child(price)
	var icon := DustIcon.make(0.8)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_box.add_child(icon)
	content.add_child(price_box)
	_names[entry.id] = title
	_pips[entry.id] = pips
	_prices[entry.id] = price
	_price_icons[entry.id] = icon
	row.focus_entered.connect(_on_row_focused.bind(index))
	row.pressed.connect(_on_row_pressed.bind(index))
	return row


func _build_details() -> Control:
	_details = VBoxContainer.new()
	_details.custom_minimum_size = Vector2(DETAILS_WIDTH, 0)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 14)
	_category = UiTheme.caption("")
	_details.add_child(_category)
	_title = UiTheme.label("", 40, UiTheme.TEXT, UiTheme.title_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_title)
	_level = UiTheme.label("", 22, UiTheme.ACCENT, UiTheme.spaced_font(2))
	_details.add_child(_level)
	_details.add_child(UiTheme.rule())
	_description = UiTheme.label("", 27, UiTheme.TEXT)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(DETAILS_WIDTH, 0)
	_details.add_child(_description)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(spacer)
	_status = UiTheme.label("", 23, UiTheme.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_status)
	_buy = UiTheme.menu_button("", 30)
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy.custom_minimum_size = Vector2(0, 64)
	_buy.add_theme_stylebox_override("normal", _buy_style(0.14))
	_buy.add_theme_stylebox_override("hover", _buy_style(0.26))
	_buy.add_theme_stylebox_override("pressed", _buy_style(0.34))
	_buy.add_theme_stylebox_override("disabled", _buy_style(0.04))
	_buy.add_theme_color_override("font_color", UiTheme.ACCENT)
	_buy.pressed.connect(buy_selected)
	_details.add_child(_buy)
	return _details


func _build_hints() -> Control:
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 48)
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_child(UiTheme.caption(tr("TERMINAL_HINT_SELECT").to_upper(), 18))
	hints.add_child(UiTheme.caption(tr("TERMINAL_HINT_BUY").to_upper(), 18))
	hints.add_child(UiTheme.caption((tr("TERMINAL_HINT_CLOSE") % GameInput.key_label(&"interact")).to_upper(), 18))
	return hints


## The buy button: a plaque of brass-washed enamel with the brass rule.
static func _buy_style(wash: float) -> PlaqueStyle:
	var style := UiTheme.plaque(UiTheme.Plaque.CHIP)
	style.field = UiTheme.over(Color(UiTheme.ACCENT, wash), Color(0.05, 0.043, 0.036))
	style.rim = Color(UiTheme.ACCENT, 0.75)
	style.cut = 8.0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


## Updates every row and the details from the current state.
func _refresh() -> void:
	if game == null or run == null:
		return
	_dust_label.text = str(run.dust)
	for entry in UpgradeCatalog.all():
		var level := game.upgrade_level(entry.id)
		var cost := UpgradeCatalog.price(entry.id, level)
		var price: Label = _prices[entry.id]
		(_pips[entry.id] as Pips).set_levels(level, entry.max_level())
		(_price_icons[entry.id] as Control).visible = cost >= 0
		if cost < 0:
			price.text = tr("TERMINAL_MAX_SHORT")
			price.add_theme_color_override("font_color", UiTheme.MUTED)
		else:
			price.text = str(cost)
			price.add_theme_color_override("font_color", UiTheme.TEXT if run.dust >= cost else UiTheme.DANGER)
		(_names[entry.id] as Label).add_theme_color_override("font_color", UiTheme.MUTED if cost < 0 else UiTheme.TEXT)
	_show_details()


func _show_details() -> void:
	if game == null or run == null or _rows.is_empty():
		return
	var entry := UpgradeCatalog.find(selected_id())
	var level := game.upgrade_level(entry.id)
	var cost := UpgradeCatalog.price(entry.id, level)
	_category.text = tr(UpgradeCatalog.category_key(entry.category)).to_upper()
	_title.text = tr(entry.name_key())
	_level.text = (tr("TERMINAL_LEVEL") % [level, entry.max_level()]).to_upper()
	_description.text = tr(entry.desc_key())
	var notes: PackedStringArray = []
	var color := UiTheme.MUTED
	if cost < 0:
		notes.append(tr("TERMINAL_MAXED"))
		color = UiTheme.GOOD
	elif run.dust < cost:
		notes.append(tr("TERMINAL_SHORT") % (cost - run.dust))
		color = UiTheme.DANGER
	var weapon := entry.weapon()
	if weapon != &"" and weapon != &"taser" and not game.has_weapon(weapon):
		notes.append(tr("TERMINAL_NEEDS_WEAPON") % tr(UpgradeCatalog.category_key(weapon)))
	_status.text = "\n".join(notes)
	_status.add_theme_color_override("font_color", color)
	_buy.disabled = cost < 0 or run.dust < cost
	_buy.text = tr("TERMINAL_MAXED").to_upper() if cost < 0 else tr("TERMINAL_BUY") % cost


func _on_row_focused(index: int) -> void:
	if index == _selected:
		_show_details()
		return
	_selected = index
	if is_open:
		Sfx.play_ui(&"ui_move", -6.0)
	_show_details()


func _on_row_pressed(index: int) -> void:
	select(index)
	buy_selected()


func _pulse(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(1.6, 1.4, 1.0), 0.08)
	tween.tween_property(target, "modulate", Color.WHITE, 0.3)


## A short "no" wiggle. A second one during the first starts from the
## resting spot again (it never drifts).
func _shake(target: Control) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		target.position.x = _shake_origin
	else:
		_shake_origin = target.position.x
	_shake_tween = create_tween()
	for offset in [-10.0, 9.0, -6.0, 4.0, 0.0]:
		_shake_tween.tween_property(target, "position:x", _shake_origin + offset, 0.04)
