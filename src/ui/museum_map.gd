class_name MuseumMap
extends CanvasLayer
## The paper museum map (design 9.1, key M; the pad's View / Select; also
## from the pause menu): a folded visitor leaflet of Floor I that the night
## guard annotates in pencil. While it is open the game is paused and the
## guard takes no input (GameInput stack); M, Esc or the pad's B put it
## down (the input comes back once those keys are up, like the note reader).
## - Opens on the guard's floor, centred on him (a red "you are here" arrow
##   showing where he looks), a little closer than the whole sheet.
## - Tabs: the ground floor, the basement and the roof (Q / E, Tab, 1-3, the
##   pad's shoulder buttons, a click on a tab).
## - Moves smoothly: drag with any mouse button, WASD / arrows / the left
##   stick; zoom with the wheel (about the cursor), + / -, the pad's
##   triggers; Space (pad Y) glides back to the guard. The rooms' names fade
##   in as the type grows readable, the wings' big names fade out.
## - Cheap: the paper and the wear are textures, every layer is drawn once
##   per tab (MapSheetLayer: the renderer keeps it), a frame only moves the
##   sheet and pulses the arrow's ring.
## Floor I installs it (install()); MuseumMap.poster() is the same print for
## the walls of the havens.

signal opened
signal closed

## Over the pause menu (60), which opens it, under the note reader (65).
const LAYER := 62
const OPEN_TIME := 0.22
## Screen px per second the keys and the stick move the sheet.
const PAN_SPEED := 900.0
## Zoom per wheel notch, and per second of a held key or trigger.
const WHEEL_STEP := 1.18
const ZOOM_SPEED := 2.2
## The arrow's ring pulses this often (s).
const PULSE_TIME := 1.6
## The help panel's line about the map.
const HELP_KEY := "HUD_HELP_MAP"

var layout: LevelLayout
var game: PersistentState
## Returns the guard (a Node3D; its head, when it has one, gives the facing).
var guard_source: Callable
## Tonight's draw (its locked door shuts a junction for the goal).
var night: NightConfig = null
## False while the map may not open (the guard is dying, dawn, the end).
var can_open: Callable = func() -> bool: return true

var is_open: bool = false
var tab: StringName = MapModel.GROUND
var view := MapView.new()
var model: MapModel = null
var projection := MapProjection.floor1()
## Where the guard was when the map opened: sheet point, floor-plan facing,
## floor tab.
var guard_point := Vector2.ZERO
var guard_facing := Vector2.UP
var guard_tab: StringName = MapModel.GROUND

## Layout key -> the poster scene (MuseumMap.poster()).
static var _posters: Dictionary = {}

var _root: Control
var _sheet: Control
var _layers: Dictionary = {}
var _pulse: Control
var _chrome: MapSheetLayer
var _paused_here: bool = false
var _dragging: bool = false
var _dragged: float = 0.0
var _unfold: float = 1.0
var _clock: float = 0.0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if game == null:
		game = GameState
	if layout == null:
		layout = Floor1Layout.create()
	_build()


func _exit_tree() -> void:
	if is_open and _paused_here and is_inside_tree():
		get_tree().paused = false
	if is_open or GameInput.is_releasing(self):
		GameInput.pop_ui(self)


## The wall poster for [param of_layout] (WorldFeatures hangs it on every
## museum_map_* marker): a scene whose root is a MapPoster - the printed
## leaflet in a frame with a red "you are here" sticker where it hangs. One
## scene per layout and language; the print itself is drawn once.
static func poster(of_layout: LevelLayout) -> PackedScene:
	var key := MapPoster.key_of(of_layout)
	MapPoster.remember(key, of_layout)
	if not _posters.has(key):
		var board := MapPoster.new()
		board.name = "MuseumMapPoster"
		board.layout_key = key
		var scene := PackedScene.new()
		scene.pack(board)
		board.free()
		_posters[key] = scene
	return _posters[key]


## Floor I's map: built for [param floor_game]'s museum (its layout, save,
## guard and night), opened by M or from the pause menu, and the help panel
## learns its key.
static func install(floor_game: FloorGame) -> MuseumMap:
	var museum := floor_game.museum
	var map := MuseumMap.new()
	map.name = "MuseumMap"
	map.layout = floor_game.level.layout
	map.game = museum.game
	map.night = museum.night
	map.guard_source = func() -> Node3D: return museum.player
	map.can_open = func() -> bool: return is_instance_valid(museum.pause_menu) and museum.pause_menu.allowed
	museum.add_child(map)
	# the label places are worked out now, while the night fades in, not on
	# the first M
	map.refresh()
	MapDrawing.wing_names(MapCanvas.new(), map.model, map.projection, MapModel.GROUND)
	museum.pause_menu.museum_map = map
	if not museum.hud.help_keys.has(HELP_KEY):
		museum.hud.help_keys.append(HELP_KEY)
		museum.hud.notification(NOTIFICATION_TRANSLATION_CHANGED)
	return map


## Shows the map (on [param at_tab], or on the guard's floor); pauses the
## game and takes the input.
func open(at_tab: StringName = &"") -> void:
	if is_open or not can_open.call():
		return
	refresh()
	tab = at_tab if MapModel.TABS.has(at_tab) else guard_tab
	view.resize(_screen_size())
	if tab == guard_tab:
		view.look_at(guard_point, view.open_zoom())
	else:
		view.look_at(MapStyle.SHEET * 0.5, view.open_zoom())
	view.snap()
	is_open = true
	visible = true
	_paused_here = not get_tree().paused
	get_tree().paused = true
	GameInput.push_ui(self)
	_dragging = false
	_unfold = 0.0
	_redraw()
	_apply_view()
	WorldSounds.ui(&"paper")
	opened.emit()


## Puts the map down. The guard gets the input back when M / Esc / the
## mouse buttons are up again.
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_dragging = false
	if _paused_here:
		get_tree().paused = false
	GameInput.pop_ui_on_release(self)
	WorldSounds.ui(&"paper", -6.0)
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## The map's picture of the progress and of the guard, worked out again.
func refresh() -> void:
	model = MapModel.build(layout, MapState.from_game(game, closed_junctions()))
	_read_guard()


func set_tab(next: StringName) -> void:
	if not MapModel.TABS.has(next) or next == tab:
		return
	tab = next
	if is_open:
		_redraw()
		WorldSounds.ui(&"paper", -10.0)


## The next floor tab ([param step] = -1: the previous one), wrapping.
func next_tab(step: int = 1) -> void:
	var index := MapModel.TABS.find(tab)
	set_tab(MapModel.TABS[wrapi(index + step, 0, MapModel.TABS.size())])


## Glides back to the guard (to his floor first).
func center_on_guard() -> void:
	set_tab(guard_tab)
	view.look_at(guard_point, maxf(view.target_zoom, view.open_zoom()))


## The guard's place on the sheet (px).
func guard_sheet_point() -> Vector2:
	return guard_point


## Tonight's shut junctions (the locked door, when it is one).
func closed_junctions() -> Array[StringName]:
	var shut: Array[StringName] = []
	if night != null and Floor1Plan.junction(night.locked_door) != null:
		shut.append(night.locked_door)
	return shut


## The sheet layer [param layer_name] (tests).
func sheet_layer(layer_name: StringName) -> MapSheetLayer:
	return _layers.get(layer_name)


## Where a floor tab sits on screen (canvas px).
func tab_rect(of_tab: StringName) -> Rect2:
	return MapDrawing.tab_rects(_screen_size())[MapModel.TABS.find(of_tab)]


# --- input -------------------------------------------------------------------------------

## M opens it from play (no menu over the game).
func _unhandled_input(event: InputEvent) -> void:
	if is_open or not event.is_action_pressed(&"map") or event.is_echo():
		return
	if GameInput.top_ui() != null:
		return
	open()
	if is_open:
		get_viewport().set_input_as_handled()


## Heard before the GUI and the game: nothing under the map gets the input.
func _input(event: InputEvent) -> void:
	if not is_open:
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	if event.is_action_pressed(&"map") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		close()
		return
	var key := event as InputEventKey
	if key != null and key.pressed:
		_on_key(key)
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		match pad.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				next_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				next_tab(1)
			JOY_BUTTON_Y, JOY_BUTTON_RIGHT_STICK:
				center_on_guard()
		return
	var local := _root.make_input_local(event)
	var button := local as InputEventMouseButton
	if button != null:
		_on_mouse_button(button)
		return
	var motion := local as InputEventMouseMotion
	if motion != null and _dragging:
		_dragged += motion.relative.length()
		view.pan_screen(motion.relative)


func _on_key(key: InputEventKey) -> void:
	match key.physical_keycode:
		KEY_Q, KEY_PAGEUP:
			next_tab(-1)
		KEY_E, KEY_PAGEDOWN:
			next_tab(1)
		KEY_TAB:
			next_tab(-1 if key.shift_pressed else 1)
		KEY_1, KEY_2, KEY_3:
			set_tab(MapModel.TABS[key.physical_keycode - KEY_1])
		KEY_SPACE, KEY_HOME, KEY_C:
			center_on_guard()
		KEY_EQUAL, KEY_KP_ADD:
			view.zoom_at(_screen_size() * 0.5, WHEEL_STEP)
		KEY_MINUS, KEY_KP_SUBTRACT:
			view.zoom_at(_screen_size() * 0.5, 1.0 / WHEEL_STEP)


func _on_mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if button.pressed:
				view.zoom_at(button.position, WHEEL_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				view.zoom_at(button.position, 1.0 / WHEEL_STEP)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if button.pressed:
				if button.button_index == MOUSE_BUTTON_LEFT:
					for each in MapModel.TABS:
						if tab_rect(each).has_point(button.position):
							set_tab(each)
							return
				_dragging = true
				_dragged = 0.0
			else:
				_dragging = false


func _process(delta: float) -> void:
	if not is_open:
		return
	# the keys and sticks that are held move and zoom the sheet smoothly
	var pan := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if pan.length() > 0.05:
		view.pan_screen(-pan * PAN_SPEED * delta)
	var zooming := _held_zoom()
	if absf(zooming) > 0.05:
		view.zoom_at(_screen_size() * 0.5, exp(zooming * ZOOM_SPEED * delta))
	view.step(delta)
	_unfold = minf(_unfold + delta / OPEN_TIME, 1.0)
	_clock += delta
	_apply_view()


## -1..1: held + / - keys and the pad's triggers (right zooms in).
func _held_zoom() -> float:
	var amount := 0.0
	if Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD):
		amount += 1.0
	if Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT):
		amount -= 1.0
	for device in Input.get_connected_joypads():
		amount += Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		var stick := -Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(stick) > 0.2:
			amount += stick
	return clampf(amount, -1.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_open:
		_redraw()


# --- drawing --------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "MuseumMap"
	_root.theme = UiTheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.resized.connect(_on_resized)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.012, 0.011, 0.012, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.size = MapStyle.SHEET
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sheet)
	var textures := MapDrawing.textures()
	_add_layer(&"shadow", func(canvas: MapCanvas) -> void: MapDrawing.shadow(canvas))
	_add_layer(&"paper", func(canvas: MapCanvas) -> void: MapDrawing.paper(canvas), textures)
	_add_layer(&"print", func(canvas: MapCanvas) -> void:
		if model != null:
			MapDrawing.print_page(canvas, model, projection, tab))
	_add_layer(&"wear", func(canvas: MapCanvas) -> void: MapDrawing.wear(canvas), textures)
	_add_layer(&"wings", func(canvas: MapCanvas) -> void:
		if model != null:
			MapDrawing.wing_names(canvas, model, projection, tab))
	_add_layer(&"names", func(canvas: MapCanvas) -> void:
		if model != null:
			MapDrawing.room_names(canvas, model, projection, tab))
	var pencil := _add_layer(&"pencil", func(canvas: MapCanvas) -> void:
		if model != null:
			MapPencil.draw(canvas, model, projection, tab))
	pencil.material = _graphite()
	_add_layer(&"here", func(canvas: MapCanvas) -> void:
		if model != null and tab == guard_tab:
			MapDrawing.here(canvas, guard_point, guard_facing))
	_pulse = Control.new()
	_pulse.name = "Pulse"
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.draw.connect(func() -> void:
		_pulse.draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 48, MapStyle.RED, 2.5, true))
	_sheet.add_child(_pulse)
	_chrome = MapSheetLayer.make("Chrome", _paint_chrome, _screen_size())
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_chrome)


func _add_layer(layer_name: StringName, paint: Callable, textures: Dictionary = {}) -> MapSheetLayer:
	var sheet_layer := MapSheetLayer.make(String(layer_name).capitalize(), paint, MapStyle.SHEET, textures)
	_sheet.add_child(sheet_layer)
	_layers[layer_name] = sheet_layer
	return sheet_layer


func _paint_chrome(canvas: MapCanvas) -> void:
	if model == null:
		return
	var pencilled: Array[StringName] = []
	for each in MapModel.TABS:
		if model.has_pencil_on(each):
			pencilled.append(each)
	var hint := MapDrawing.tr_key(&"MAP_HINT") % ["%s / Esc" % GameInput.key_label(&"map"), MapDrawing.tr_key(&"MAP_KEY_SPACE")]
	MapDrawing.chrome(canvas, _screen_size(), tab, guard_tab, pencilled, hint)


static func _graphite() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://src/ui/map/graphite.gdshader")
	material.set_shader_parameter(&"grain", load(MapDrawing.GRAIN_PATH))
	return material


## Every layer that depends on the tab, the progress or the language.
func _redraw() -> void:
	for layer_name: StringName in [&"print", &"wings", &"names", &"pencil", &"here"]:
		(_layers[layer_name] as MapSheetLayer).queue_redraw()
	_chrome.queue_redraw()
	_pulse.visible = tab == guard_tab
	_pulse.position = guard_point


## The sheet where the view has it (unfolding a little on opening), the
## names' and wings' strength for the zoom, the arrow's ring breathing.
func _apply_view() -> void:
	var opening := ease(_unfold, 0.4)
	var shown := view.transform()
	if opening < 1.0:
		var middle := _screen_size() * 0.5
		var grow := lerpf(0.965, 1.0, opening)
		shown = Transform2D(0.0, Vector2(grow, grow), 0.0, middle - middle * grow) * shown
	_sheet.position = shown.origin
	_sheet.scale = shown.get_scale()
	_sheet.modulate.a = opening
	(_layers[&"names"] as CanvasItem).modulate.a = MapView.name_alpha(view.zoom)
	(_layers[&"wings"] as CanvasItem).modulate.a = view.wing_alpha(view.zoom)
	var beat := fmod(_clock / PULSE_TIME, 1.0)
	_pulse.scale = Vector2.ONE * lerpf(0.8, 1.7, beat)
	_pulse.modulate.a = (1.0 - beat) * 0.7


func _read_guard() -> void:
	var guard := guard_source.call() as Node3D if guard_source.is_valid() else null
	if guard == null or not is_instance_valid(guard):
		return
	var at := guard.global_position
	guard_point = projection.point(at)
	guard_tab = page_at(at)
	var looking := guard.global_transform.basis
	var head: Variant = guard.get(&"head") if &"head" in guard else null
	if head is Node3D:
		looking = (head as Node3D).global_transform.basis
	var forward := -looking.z
	guard_facing = Vector2(forward.x, forward.z) if Vector2(forward.x, forward.z).length() > 0.01 else Vector2.UP


## The page of the floor at [param at] (world): the page of the room there
## (its zone's for the basement and the roof), else by height.
func page_at(at: Vector3) -> StringName:
	var inside := layout.room(layout.room_at(at + Vector3.UP * 0.5)) if layout != null else null
	if inside != null:
		return MapModel.main_tab_of(inside)
	return MapModel.tab_of_height(at.y + 0.5)


func _screen_size() -> Vector2:
	if _root != null and _root.size.x > 1.0:
		return _root.size
	return Vector2(1920.0, 1080.0)


func _on_resized() -> void:
	view.resize(_screen_size())
	if _chrome != null:
		_chrome.size = _screen_size()
		_chrome.queue_redraw()
	if is_open:
		_apply_view()
