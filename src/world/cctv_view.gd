class_name CctvView
extends CanvasLayer
## The camera console's full-screen view: one camera at a time on the whole
## screen, in the monitors' look (scanlines, grain, a burst of snow when
## the channel changes), with the camera's name, a blinking REC, the night
## clock, a MOTION warning and the channels along the bottom, six to a page
## (more cameras: the page's number shown, the arrows go on to the next
## page). Switch with 1-6 (on the page), the arrows (or A/D), the mouse
## wheel or a click on a channel; E or Esc leaves. The game does not stop
## (the night clock runs: watching is a risk), but the guard takes no input
## while it is open.
## The main 3D view is switched off meanwhile (nobody sees it) and one
## 640x480 camera renders at FPS instead.
## The view snaps shut on its own when the guard is hurt (he is back at
## the desk to see what hit him), when he dies, at dawn, and when the
## window loses its focus (then it asks for the pause menu: an open view
## would keep the night running unseen).

signal opened
signal closed
## Closed for a lost focus: the game should pause now.
signal pause_requested

const PICTURE := Vector2i(640, 480)
const FPS := 15.0
const SWITCH_TIME := 0.28
const DIGITS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
## Channels on one page of the bottom row.
const PAGE := 6

var is_open: bool = false
## Index into [member cameras] of the camera on screen.
var index: int = 0
var cameras: Array[CctvCatalog.Camera] = []
## Room id -> true while an exhibit moves there (the Cctv keeps it).
var motion_rooms: Dictionary = {}
var run: NightState = null
## Seconds of the night for the clock (set by Cctv; RunState.time when unset).
var clock_seconds: Callable = Callable()
var picture: SubViewport
var lens: Camera3D
## Frames rendered for the view (tests).
var renders: int = 0

var _environment: Environment
var _was_3d_disabled: bool = false
var _static: float = 0.0
var _render_left: float = 0.0
var _time: float = 0.0
var _root: Control
var _screen: TextureRect
var _material: ShaderMaterial
var _frame: Control
var _title: Label
var _subtitle: Label
var _rec: Label
var _clock: Label
var _motion: Label
var _tabs: HBoxContainer
var _page: Label
var _hint: Label


func setup(camera_list: Array[CctvCatalog.Camera], look: Environment) -> void:
	cameras = camera_list
	_environment = look


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if run == null:
		run = RunState
	picture = SubViewport.new()
	picture.name = "Picture"
	picture.size = PICTURE
	picture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	picture.msaa_3d = Viewport.MSAA_DISABLED
	picture.positional_shadow_atlas_size = 1024
	picture.audio_listener_enable_3d = false
	picture.gui_disable_input = true
	add_child(picture)
	lens = Camera3D.new()
	lens.name = "Lens"
	lens.cull_mask = CctvFeed.CULL_MASK
	lens.environment = _environment
	lens.near = 0.08
	lens.far = 80.0
	picture.add_child(lens)
	lens.current = true
	_build()
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(snap_shut)
	Events.dawn_broke.connect(snap_shut)


func _exit_tree() -> void:
	if is_open:
		_restore_main_view()
	if is_open or is_holding_input():
		GameInput.pop_ui(self)


## Shows camera [param start] (an index) full screen and takes the input.
func open(start: int = -1) -> void:
	if is_open or cameras.is_empty():
		return
	is_open = true
	visible = true
	GameInput.push_ui(self)
	var main := get_viewport()
	_was_3d_disabled = main.disable_3d
	main.disable_3d = true
	select(index if start < 0 else start, false)
	_static = 1.0
	_render_left = 0.0
	WorldSounds.ui(&"cctv_switch")
	_layout.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	picture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_restore_main_view()
	GameInput.pop_ui_on_release(self)
	WorldSounds.ui(&"cctv_switch", -6.0)
	closed.emit()


## True while the input is still held back after closing (E / Esc down).
func is_holding_input() -> bool:
	return GameInput.is_releasing(self)


## Closes at once and hands the input straight back (nothing pressed shut
## it, so there is no key to wait for).
func snap_shut() -> void:
	if not is_open:
		return
	close()
	GameInput.pop_ui(self)


func _on_player_damaged(_amount: float, _from: Vector3) -> void:
	snap_shut()


## The window lost its focus while the view was open: shut it and ask for
## the pause menu (which would not open over the view by itself).
func leave_for_pause() -> void:
	if not is_open:
		return
	snap_shut()
	pause_requested.emit()


## Index of the first camera on the current camera's page.
func page_start() -> int:
	return (index / PAGE) * PAGE


## Pages of channels (1 for up to six cameras).
func page_count() -> int:
	return maxi(ceili(cameras.size() / float(PAGE)), 1)


## Puts camera [param to] (wrapping) on screen.
func select(to: int, sound: bool = true) -> void:
	if cameras.is_empty():
		return
	index = wrapi(to, 0, cameras.size())
	var spec := cameras[index]
	lens.transform = spec.transform()
	lens.fov = spec.fov
	_static = 1.0
	_render_left = 0.0
	_refresh_texts()
	if sound and is_open:
		WorldSounds.ui(&"cctv_switch", -3.0)


func current() -> CctvCatalog.Camera:
	return cameras[index] if not cameras.is_empty() else null


func _restore_main_view() -> void:
	if is_inside_tree():
		get_viewport().disable_3d = _was_3d_disabled


func _process(delta: float) -> void:
	if not is_open:
		return
	_time += delta
	_static = maxf(_static - delta / SWITCH_TIME, 0.0)
	_material.set_shader_parameter(&"switch_static", _static * _static)
	_render_left -= delta
	if _render_left <= 0.0:
		_render_left = maxf(_render_left + 1.0 / FPS, 0.0)
		picture.render_target_update_mode = SubViewport.UPDATE_ONCE
		renders += 1
	_clock.text = CctvCatalog.clock_text(float(clock_seconds.call()) if clock_seconds.is_valid() else run.time)
	_rec.modulate.a = 1.0 if fmod(_time, 1.0) < 0.6 else 0.2
	_motion.visible = bool(motion_rooms.get(cameras[index].room, false)) and fmod(_time, 0.8) < 0.55


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if WorldInput.closes(event):
		close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and DIGITS.has(key.physical_keycode):
		var number := page_start() + DIGITS.find(key.physical_keycode)
		if number < cameras.size():
			select(number)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"weapon_next"):
		select(index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"weapon_prev"):
		select(index - 1)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			if _title != null:
				_refresh_texts()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if GameInput.pause_on_focus_loss:
				leave_for_pause()


func _refresh_texts() -> void:
	if _title == null or cameras.is_empty():
		return
	var spec := cameras[index]
	_title.text = (tr("CCTV_CAM_LABEL") % spec.number + "   " + tr(spec.name_key())).to_upper()
	_subtitle.text = tr("CCTV_TITLE").to_upper()
	_rec.text = tr("CCTV_REC")
	_motion.text = "▲ " + tr("CCTV_MOTION_LONG").to_upper()
	_hint.text = (tr("CCTV_HINT") % [GameInput.key_label(&"interact"), GameInput.key_label(&"pause")]).to_upper()
	var start := page_start()
	for i in _tabs.get_child_count():
		var tab := _tabs.get_child(i) as Button
		var at := start + i
		tab.visible = at < cameras.size()
		if not tab.visible:
			continue
		tab.text = "%d  %s" % [cameras[at].number, tr(cameras[at].name_key()).to_upper()]
		tab.button_pressed = at == index
	_page.visible = page_count() > 1
	_page.text = (tr("CCTV_PAGE") % [index / PAGE + 1, page_count()]).to_upper()


## The picture keeps 4:3 in the middle; the texts sit on its corners.
func _layout() -> void:
	var screen := _root.size if _root.size.x > 0.0 else Vector2(1920, 1080)
	var height := screen.y
	var width := minf(height * 4.0 / 3.0, screen.x)
	height = width * 3.0 / 4.0
	_frame.position = ((screen - Vector2(width, height)) * 0.5).round()
	_frame.size = Vector2(width, height)


func _build() -> void:
	_root = Control.new()
	_root.name = "CctvView"
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.resized.connect(_layout)
	var black := ColorRect.new()
	black.color = Color(0.0, 0.0, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(black)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)
	_screen = TextureRect.new()
	_screen.texture = picture.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/world/cctv_view.gdshader")
	_screen.material = _material
	_frame.add_child(_screen)
	var top := VBoxContainer.new()
	top.position = Vector2(40, 30)
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(top)
	_subtitle = _label(18, Color(0.85, 0.95, 0.88, 0.7), UiTheme.spaced_font(4))
	top.add_child(_subtitle)
	_title = _label(34, Color(0.94, 0.97, 0.92), UiTheme.spaced_font(3))
	top.add_child(_title)
	var corner := VBoxContainer.new()
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 30)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(corner)
	_rec = _label(30, Color(1.0, 0.25, 0.2), UiTheme.strong_font())
	_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_rec)
	_clock = _label(30, Color(0.94, 0.97, 0.92), UiTheme.spaced_font(2))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(_clock)
	_motion = _label(30, Color(1.0, 0.3, 0.22), UiTheme.spaced_font(3))
	_motion.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 104)
	_motion.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_motion.visible = false
	_frame.add_child(_motion)
	var band := ColorRect.new()
	band.color = Color(0.0, 0.0, 0.0, 0.5)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -104.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(band)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 10)
	_frame.add_child(bottom)
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 6)
	bottom.add_child(_tabs)
	for i in mini(cameras.size(), PAGE):
		_tabs.add_child(_tab(i))
	_page = _label(16, Color(0.85, 0.95, 0.88, 0.7), UiTheme.spaced_font(3))
	_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_page)
	_hint = _label(18, Color(0.85, 0.95, 0.88, 0.8), UiTheme.spaced_font(3))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	_refresh_texts()


func _tab(i: int) -> Button:
	var tab := Button.new()
	tab.toggle_mode = true
	tab.focus_mode = Control.FOCUS_NONE
	tab.add_theme_font_override("font", UiTheme.spaced_font(2))
	tab.add_theme_font_size_override("font_size", 17)
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	idle.border_color = Color(0.85, 0.95, 0.88, 0.2)
	idle.set_border_width_all(1)
	idle.set_content_margin_all(8)
	idle.content_margin_left = 12
	idle.content_margin_right = 12
	var lit := idle.duplicate() as StyleBoxFlat
	lit.bg_color = Color(UiTheme.ACCENT, 0.22)
	lit.border_color = UiTheme.ACCENT
	for state in ["normal", "focus", "disabled"]:
		tab.add_theme_stylebox_override(state, idle)
	for state in ["hover", "pressed", "hover_pressed"]:
		tab.add_theme_stylebox_override(state, lit)
	tab.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88, 0.75))
	tab.add_theme_color_override("font_pressed_color", UiTheme.ACCENT)
	tab.add_theme_color_override("font_hover_pressed_color", UiTheme.ACCENT)
	tab.add_theme_color_override("font_hover_color", UiTheme.TEXT)
	tab.pressed.connect(func() -> void: select(page_start() + i))
	return tab


static func _label(font_size: int, color: Color, font: Font) -> Label:
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 5
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	var label := Label.new()
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
