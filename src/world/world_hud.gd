class_name WorldHud
extends CanvasLayer
## The world content's own layer over the HUD: a banner for discoveries
## (a secret, an artifact, the locker key, a locked door) under the top
## edge, and the row of the night's artifacts in the top left corner under
## the HUD's block there (set_artifacts(); [member corner_source] tells how
## far down that block reaches: a long goal, the F1 help). Banners queue
## up, so a secret found together with a new haven reads as two calm
## announcements, not one overwritten text.
## Everything waits while the game is paused (a banner raised while a note
## is open shows when the note is put down).

const FADE_IN := 0.25
const HOLD := 2.6
## Hold of a banner while others wait their turn.
const HOLD_BUSY := 1.3
const FADE_OUT := 0.6
const MAX_QUEUE := 4
## Top of the banner (1920x1080 canvas units; the Hud's toast sits above).
const BANNER_TOP := 150.0
const SLIDE := 14.0
## The artifact row: top left, under the Hud's night number and clock,
## the night's goal and the help line (ICONS_AT.y when the HUD does not
## say where its block ends).
const ICONS_AT := Vector2(32.0, 138.0)
const ICONS_GAP := 14.0

## Every banner asked for, oldest first: [caption, title, detail].
var announced: Array[PackedStringArray] = []
## Returns the bottom edge of the HUD's top-left block (Hud.top_left_bottom).
var corner_source: Callable = Callable()

var _queue: Array[PackedStringArray] = []
var _current: PackedStringArray = []
var _time: float = 0.0
var _root: Control
var _banner: PanelContainer
var _caption: Label
var _title: Label
var _detail: Label
var _icons: HBoxContainer
var _shown_artifacts: Array[StringName] = []


func _ready() -> void:
	layer = 12
	_root = Control.new()
	_root.name = "WorldHud"
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_banner()
	_icons = HBoxContainer.new()
	_icons.name = "Artifacts"
	_icons.add_theme_constant_override("separation", 10)
	_icons.position = ICONS_AT
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_icons)


## Shows the night's artifacts as a row of icons (new ones pop in).
func set_artifacts(ids: Array[StringName]) -> void:
	if ids == _shown_artifacts:
		return
	for child in _icons.get_children():
		var icon := child as ArtifactIcon
		if not ids.has(icon.artifact_id):
			_icons.remove_child(icon)
			icon.queue_free()
	for id in ids:
		if not _shown_artifacts.has(id):
			var icon := ArtifactIcon.make(id)
			_icons.add_child(icon)
			icon.pop()
	_shown_artifacts = ids.duplicate()


## The row's top: just under the HUD's top-left block.
func _place_icons() -> void:
	var top := ICONS_AT.y
	if corner_source.is_valid():
		top = float(corner_source.call()) + ICONS_GAP
	_icons.position = Vector2(ICONS_AT.x, top)


## The artifact ids shown in the row, in order.
func shown_artifacts() -> Array[StringName]:
	var ids: Array[StringName] = []
	for child in _icons.get_children():
		if not child.is_queued_for_deletion():
			ids.append((child as ArtifactIcon).artifact_id)
	return ids


## Announces something under the top edge: a small brass [param caption]
## ("SEKRET ODKRYTY (3/6)"), a [param title] in the title face and an
## optional [param detail] line.
func banner(caption: String, title: String, detail: String = "") -> void:
	var entry := PackedStringArray([caption, title, detail])
	announced.append(entry)
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
	_queue.append(entry)
	if _current.is_empty():
		_next()


## Like banner(), unless the same one is on screen or waiting already (a
## guard rattling a locked door does not stack up the same message).
func banner_once(caption: String, title: String, detail: String = "") -> void:
	var entry := PackedStringArray([caption, title, detail])
	if _current == entry or _queue.has(entry):
		return
	banner(caption, title, detail)


## True while a banner is on screen (or waiting its turn).
func is_busy() -> bool:
	return not _current.is_empty() or not _queue.is_empty()


## Caption, title and detail of the banner on screen ([] when none).
func current() -> PackedStringArray:
	return _current


func _process(delta: float) -> void:
	_place_icons()
	if _current.is_empty():
		return
	_time += delta
	var hold := HOLD_BUSY if not _queue.is_empty() else HOLD
	var shown := 1.0
	if _time < FADE_IN:
		shown = _time / FADE_IN
	elif _time > FADE_IN + hold:
		shown = 1.0 - (_time - FADE_IN - hold) / FADE_OUT
	shown = clampf(shown, 0.0, 1.0)
	_banner.modulate.a = shown
	var slide_in := 1.0 - pow(1.0 - clampf(_time / FADE_IN, 0.0, 1.0), 3.0)
	_banner.position.y = BANNER_TOP - SLIDE * (1.0 - slide_in)
	if _time >= FADE_IN + hold + FADE_OUT:
		_current = PackedStringArray()
		_banner.visible = false
		_next()


func _next() -> void:
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	_time = 0.0
	_caption.text = _current[0].to_upper()
	_title.text = _current[1]
	_detail.text = _current[2]
	_detail.visible = _current[2] != ""
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.reset_size()
	_center_banner()


func _center_banner() -> void:
	var width := _root.size.x if _root.size.x > 0.0 else 1920.0
	_banner.position = Vector2((width - _banner.size.x) * 0.5, BANNER_TOP - SLIDE)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.panel_style(0.0)
	style.bg_color = Color(0.035, 0.03, 0.028, 0.84)
	style.content_margin_left = 44.0
	style.content_margin_right = 44.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 18.0
	_banner.add_theme_stylebox_override("panel", style)
	_banner.custom_minimum_size = Vector2(520, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(column)
	_caption = UiTheme.caption("", 20, UiTheme.ACCENT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_caption)
	var rule := UiTheme.rule(140.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)
	_title = UiTheme.label("", 38, UiTheme.TEXT, UiTheme.title_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_detail = UiTheme.label("", 22, UiTheme.MUTED)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(520, 0)
	column.add_child(_detail)
	_banner.visible = false
	_root.add_child(_banner)
