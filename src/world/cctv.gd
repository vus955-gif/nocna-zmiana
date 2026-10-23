class_name Cctv
extends Node3D
## The museum's closed-circuit television: the cameras (in the lobby six:
## hall, gallery, armory, diorama, balcony, staff corridor; on Floor I every
## camera the level gives, [member camera_specs], the hub's first), the
## monitor wall of the security booth with the live pictures of the first
## WALL_FEEDS and a status screen, the console on the desk and its
## full-screen view (CctvView), which pages through all of them.
## Cost: the feeds render only while the guard is in the security booth
## (and not in the full-screen view, which has its own camera), one feed at
## a time in turn, FEED_FPS pictures a second each, 320x240, no MSAA, no
## positional shadows, no fog, no moon (its shadow cascades per camera).
## Anywhere else the cameras cost nothing.
## A MOTION tag marks the feeds of rooms where an exhibit (or the T-Rex) is
## awake. The wall is the art's monitor bank (ArtLibrary "cctv_bank", each
## screen's own material showing its feed) on the booth's rack, or a
## greybox of six monitors when the model is off.

signal view_opened
signal view_closed
## The full-screen view closed because the window lost its focus: the game
## should pause (nothing else stops the night while the player is away).
signal pause_requested

## Pictures per second of each wall feed.
const FEED_FPS := 6.0
## Monitors on the wall: the first cameras have a feed there.
const WALL_FEEDS := 6
## Room the monitor wall is seen from.
const WATCH_ROOM := &"security"
## Seconds between the checks of where the guard is and what moves.
const CHECK_INTERVAL := 0.25
const MOTION_INTERVAL := 0.5
## Monitor layout on the wall (the wall piece's frame: origin at its base,
## -Z its front, so the guard facing it has +X on his left): three columns
## (1 2 3 / 4 5 6 from his left), two rows, the status screen on his right
## and the indicator lamps on his left.
const MONITOR := Vector3(0.9, 0.66, 0.3)
const SCREEN := Vector2(0.72, 0.54)
const COLUMNS: Array[float] = [1.0, 0.0, -1.0]
const ROWS: Array[float] = [1.96, 1.28]
const STATUS_AT := Vector3(-1.98, 1.64, 0.0)
const LEDS_AT := Vector3(1.98, 1.62, 0.0)
const STATUS_SIZE := Vector2i(256, 192)
## Rooms listed by name on the status screen; past that, "+n more".
const STATUS_ROOMS := 4
## With a [member log_source] the status screen turns its page every this
## many seconds: motion, then the shift's log (plan 2026-10-21-opowiesc-muzeum).
const STATUS_PAGE := 5.0
const SCREEN_SHADER := preload("res://src/world/cctv_screen.gdshader")
## The art's monitor bank stands on the rack at desk height, centred.
const BANK_MODEL := &"cctv_bank"
const BANK_BASE := 0.78
## Emission of a bank screen showing its feed (the art's CRT default), and
## of its standby picture before the first frame.
const BANK_GLOW := 1.6
const BANK_STANDBY := 0.35

static var _materials: Dictionary = {}

## The level (the lobby, Floor I: any Level with room_at(), markers and a
## layout).
var level: Level
## The cameras to hang (empty: the lobby's six, CctvCatalog.cameras()).
var camera_specs: Array[CctvCatalog.Camera] = []
## The room the monitor wall is watched from.
var watch_room: StringName = WATCH_ROOM
## Returns the guard (or null).
var guard_source: Callable
var game: PersistentState = null
var run: NightState = null
## Seconds of the night for the clock burnt into the feeds (the game points
## it at its night clock; RunState.time when unset).
var clock_seconds: Callable = Callable()
var cameras: Array[CctvCatalog.Camera] = []
var feeds: Array[CctvFeed] = []
## Screen meshes on the wall, one per feed (greybox wall only).
var screens: Array[MeshInstance3D] = []
## The art's monitor bank (null: the greybox monitors) and its screens'
## own materials, one per feed.
var bank: Node3D = null
var bank_screens: Array[BaseMaterial3D] = []
var view: CctvView
var console: CctvConsole
var environment: Environment
## The wall feeds are running (the guard is in the booth, not in the view).
var active: bool = false
## Room id -> true while an exhibit is awake there.
var motion_rooms: Dictionary = {}
## -> the shift's log for the status screen's second page (PackedStringArray;
## ShiftLog.lines); unset: the motion page only.
var log_source: Callable = Callable()
## room id -> true when the room's wing is at rest (its feed says so); unset: never.
var calm_source: Callable = Callable()

var _status: SubViewport
var _status_lines: Label
var _status_log: Label = null
var _page_time: float = 0.0
var _next: int = 0
var _render_left: float = 0.0
var _check_left: float = 0.0
var _motion_left: float = 0.0
var _signal: Array[float] = []
var _leds: Array[MeshInstance3D] = []
var _housing_leds: Array[MeshInstance3D] = []
var _time: float = 0.0


func _ready() -> void:
	if game == null:
		game = GameState
	if run == null:
		run = RunState
	environment = make_environment()
	# the moon on its own render layer, which the security cameras leave out
	# (the guard's camera and any other see every layer)
	for moon in NightModifiers.moons(level):
		moon.layers = CctvFeed.MOON_LAYER
	cameras = camera_specs if not camera_specs.is_empty() else CctvCatalog.cameras()
	for spec in cameras:
		_build_housing(spec)
		if feeds.size() >= WALL_FEEDS:
			continue
		var feed := CctvFeed.make(spec, environment)
		add_child(feed)
		feeds.append(feed)
		_signal.append(0.0)
	_build_wall()
	view = CctvView.new()
	view.name = "CctvView"
	view.run = run
	view.clock_seconds = night_seconds
	view.setup(cameras, environment)
	add_child(view)
	view.opened.connect(func() -> void: view_opened.emit())
	view.closed.connect(func() -> void: view_closed.emit())
	view.pause_requested.connect(func() -> void: pause_requested.emit())
	_build_console()


## The level's room at [param point] (&"" for a level without rooms).
func _room_at(point: Vector3) -> StringName:
	return level.call(&"room_at", point) if level.has_method(&"room_at") else &""


## The level's markers ({} for a level without them).
func _markers() -> Dictionary:
	var found: Variant = level.get(&"markers")
	return found if found is Dictionary else {}


## The cameras' "infrared" look: a pale ambient lifts the dark rooms, no
## fog, no glow, no screen-space effects (cheap, and readable in a blackout).
static func make_environment() -> Environment:
	var look := Environment.new()
	look.background_mode = Environment.BG_COLOR
	look.background_color = Color(0.015, 0.018, 0.02)
	look.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	look.ambient_light_color = Color(0.6, 0.66, 0.64)
	look.ambient_light_energy = 0.55
	look.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	look.tonemap_exposure = 1.25
	look.glow_enabled = false
	look.fog_enabled = false
	look.volumetric_fog_enabled = false
	look.ssao_enabled = false
	look.ssil_enabled = false
	look.ssr_enabled = false
	look.sdfgi_enabled = false
	return look


## Opens the full-screen view on camera [param index] (the last one when -1).
func open_view(index: int = -1) -> void:
	view.motion_rooms = motion_rooms
	view.open(index)


func guard() -> Player:
	return guard_source.call() as Player if guard_source.is_valid() else null


func _process(delta: float) -> void:
	_time += delta
	_page_time += delta
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_set_active(_guard_watching() and not view.is_open)
	_motion_left -= delta
	if _motion_left <= 0.0 and (active or view.is_open):
		_motion_left = MOTION_INTERVAL
		_scan_motion()
		_update_status()
	for i in _housing_leds.size():
		_housing_leds[i].visible = fmod(_time + i * 0.37, 2.0) < 1.0
	if not active:
		return
	for i in _leds.size():
		_leds[i].visible = fmod(_time * (0.7 + (i % 5) * 0.23) + i * 0.61, 1.0) < 0.62
	_render_left -= delta
	if _render_left <= 0.0:
		# keep the average rate (frames rarely divide the interval evenly)
		var interval := 1.0 / (FEED_FPS * feeds.size())
		_render_left = maxf(_render_left + interval, 0.0)
		var feed := feeds[_next]
		feed.set_motion(bool(motion_rooms.get(feed.spec.room, false)))
		feed.set_calm(calm_source.is_valid() and bool(calm_source.call(feed.spec.room)))
		feed.render_once(CctvCatalog.clock_text(night_seconds()))
		_next = (_next + 1) % feeds.size()
	for i in feeds.size():
		if feeds[i].has_picture and _signal[i] < 1.0:
			_signal[i] = minf(_signal[i] + delta * 3.0, 1.0)
			_show_signal(i)


## The guard stands in the booth, in view of the wall.
func _guard_watching() -> bool:
	var player := guard()
	return player != null and player.alive and _room_at(player.global_position + Vector3.UP * 0.5) == watch_room


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on:
		_render_left = 0.0


## Feed [param i]'s picture comes in (a fade from snow; on the art's bank
## from dark, in place of the standby picture).
func _show_signal(i: int) -> void:
	if bank != null:
		var screen := bank_screens[i]
		if _signal[i] > 0.0 and screen.albedo_texture != feeds[i].get_texture():
			screen.albedo_texture = feeds[i].get_texture()
			screen.emission_texture = feeds[i].get_texture()
		screen.emission_energy_multiplier = BANK_GLOW * _signal[i]
		return
	(screens[i].material_override as ShaderMaterial).set_shader_parameter(&"signal_strength", _signal[i])


## The guard's first-person weapons need nothing here: they live on render
## layer 20 only (Viewmodels.first_person_layer), which the feeds leave out.
func _scan_motion() -> void:
	motion_rooms.clear()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var state := enemy.brain.state
		if state == EnemyBrain.State.DORMANT or state == EnemyBrain.State.DESTROYED:
			continue
		_mark_motion(enemy.global_position)
	# the T-Rex off its pedestal moves too
	for node in get_tree().get_nodes_in_group(&"boss"):
		var boss := node as TRex
		if boss != null and is_instance_valid(boss) and not boss.is_dormant() and not boss.is_dead():
			_mark_motion(boss.global_position)
	view.motion_rooms = motion_rooms


func _mark_motion(at: Vector3) -> void:
	var room := _room_at(at + Vector3.UP * 0.5)
	if room != &"":
		motion_rooms[room] = true


# --- the wall ----------------------------------------------------------------

## The wall piece's frame (origin at its base centre, -Z its front) and
## size; the level's cctv_wall piece when there is one (its greybox look is
## replaced by the monitors), else the cctv_wall marker.
func _wall_frame() -> Array:
	var marker: Variant = _markers().get(&"cctv_wall")
	var near: Vector3 = marker.origin if marker != null else Vector3(0.0, 1.5, 61.35)
	for node in get_tree().get_nodes_in_group(&"level_kit"):
		var piece := node as Node3D
		if piece != null and piece.get_meta(&"kit", &"") == &"cctv_wall" and level.is_ancestor_of(piece) and piece.global_position.distance_to(near) < 3.0:
			var look := piece.get_node_or_null(^"Visual") as Node3D
			if look != null:
				look.visible = false
			return [piece.global_transform, piece.get_meta(&"kit_size", Vector3(5.0, 2.4, 0.6))]
	var size := Vector3(5.0, 2.4, 0.6)
	var at: Transform3D = marker if marker != null else Transform3D(Basis.IDENTITY, near)
	return [Transform3D(at.basis, at.origin + at.basis * Vector3(0.0, -1.5, size.z * 0.5)), size]


func _build_wall() -> void:
	var found := _wall_frame()
	var frame: Transform3D = found[0]
	var size: Vector3 = found[1]
	var wall := Node3D.new()
	wall.name = "MonitorWall"
	wall.transform = frame
	add_child(wall)
	var rack := _solid(Color(0.08, 0.08, 0.09), 0.7, 0.3)
	_box(wall, size, Vector3(0.0, size.y * 0.5, 0.0), rack)
	var front := -size.z * 0.5
	if not _build_bank(wall, front):
		_build_monitors(wall, front)
	_build_status(wall, front)
	_build_leds(wall, front)


## The art's monitor bank on the rack's front at desk height, its six
## screens showing the feeds (dark until each first picture). False when
## the model is off or does not carry a screen per feed.
func _build_bank(wall: Node3D, front: float) -> bool:
	var model := ArtLibrary.try_instance(BANK_MODEL)
	if model == null:
		return false
	var found: Array[BaseMaterial3D] = []
	for i in feeds.size():
		var screen := PropArt.screen(model, "cctv_screen_%d" % feeds[i].spec.number)
		if screen == null:
			model.free()
			return false
		# the art's standby picture, dim, until the camera's first frame
		screen.emission_energy_multiplier = BANK_STANDBY
		found.append(screen)
	model.name = "MonitorBank"
	# the model faces +Z with its back on its origin; the wall's front is -Z
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, BANK_BASE, front))
	wall.add_child(model)
	# what it stands on: a shelf of the rack behind the desk
	var foot := Vector3(1.6, BANK_BASE, 0.6)
	_box(wall, foot, Vector3(0.0, BANK_BASE * 0.5, front - foot.z * 0.5), _solid(Color(0.08, 0.08, 0.09), 0.7, 0.3))
	bank = model
	bank_screens = found
	return true


## Greybox: six CRT boxes in two rows of three, each with a screen quad.
func _build_monitors(wall: Node3D, front: float) -> void:
	var plastic := _solid(Color(0.19, 0.19, 0.2), 0.55, 0.1)
	var bezel := _solid(Color(0.11, 0.11, 0.12), 0.6, 0.1)
	for row in ROWS.size():
		for column in COLUMNS.size():
			var i := row * COLUMNS.size() + column
			if i >= feeds.size():
				break
			var middle := Vector3(COLUMNS[column], ROWS[row], front - MONITOR.z * 0.5)
			_box(wall, MONITOR, middle, plastic)
			var face_z := front - MONITOR.z
			_frame_box(wall, Vector3(middle.x, middle.y, face_z - 0.004), SCREEN + Vector2(0.05, 0.05), bezel)
			var screen := _screen_mesh(wall, Vector3(middle.x, middle.y, face_z - 0.012), SCREEN)
			var material := ShaderMaterial.new()
			material.shader = SCREEN_SHADER
			material.set_shader_parameter(&"feed", feeds[i].get_texture())
			material.set_shader_parameter(&"signal_strength", 0.0)
			material.set_shader_parameter(&"seed", i * 0.173)
			screen.material_override = material
			screen.name = "Screen_%d" % feeds[i].spec.number
			screens.append(screen)
			_number(wall, feeds[i].spec.number, Vector3(middle.x - MONITOR.x * 0.5 + 0.035, middle.y - SCREEN.y * 0.5 + 0.02, face_z - 0.006))


func _build_status(wall: Node3D, front: float) -> void:
	_status = SubViewport.new()
	_status.name = "Status"
	_status.size = STATUS_SIZE
	_status.disable_3d = true
	_status.transparent_bg = false
	_status.gui_disable_input = true
	_status.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_status)
	var back := ColorRect.new()
	back.color = Color(0.01, 0.04, 0.02)
	back.size = Vector2(STATUS_SIZE)
	_status.add_child(back)
	var settings := LabelSettings.new()
	settings.font = UiTheme.device_font()
	settings.font_size = 17
	settings.font_color = Color(0.45, 1.0, 0.55)
	settings.line_spacing = 2.0
	_status_lines = Label.new()
	_status_lines.label_settings = settings
	_status_lines.position = Vector2(14, 10)
	_status_lines.size = Vector2(STATUS_SIZE) - Vector2(28, 20)
	_status.add_child(_status_lines)
	# the shift's log page: a size smaller, its eight lines fit the screen
	var small := settings.duplicate() as LabelSettings
	small.font_size = 15
	small.line_spacing = 1.0
	_status_log = Label.new()
	_status_log.name = "Log"
	_status_log.label_settings = small
	_status_log.position = Vector2(14, 8)
	_status_log.size = Vector2(STATUS_SIZE) - Vector2(28, 16)
	_status_log.visible = false
	_status.add_child(_status_log)
	var housing := Vector3(0.6, 0.5, 0.28)
	var middle := Vector3(STATUS_AT.x, STATUS_AT.y, front - housing.z * 0.5)
	_box(wall, housing, middle, _solid(Color(0.19, 0.19, 0.2), 0.55, 0.1))
	var screen := _screen_mesh(wall, Vector3(middle.x, middle.y, front - housing.z - 0.01), Vector2(0.48, 0.36))
	var material := ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter(&"feed", _status.get_texture())
	material.set_shader_parameter(&"colour_kept", 1.0)
	material.set_shader_parameter(&"tint", Color(1.0, 1.0, 1.0))
	material.set_shader_parameter(&"lines", 192.0)
	screen.material_override = material
	screen.name = "StatusScreen"
	_update_status()


## Night, clock, cameras and the rooms where something moves; with a
## [member log_source], every other STATUS_PAGE s the shift's log instead.
func _update_status() -> void:
	if _status_lines == null:
		return
	var log_page := showing_log()
	if _status_log != null and _status_log.visible != log_page:
		_status_log.visible = log_page
		_status_lines.visible = not log_page
		_status.render_target_update_mode = SubViewport.UPDATE_ONCE
	if log_page:
		var log_text := "\n".join(log_source.call() as PackedStringArray)
		if log_text != _status_log.text:
			_status_log.text = log_text
			_status.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var moving: Array[String] = []
	for spec in cameras:
		if motion_rooms.get(spec.room, false):
			moving.append(tr(spec.name_key()).to_upper())
	var lines: Array[String] = [
		(tr("CCTV_STATUS_NIGHT") % game.night).to_upper() + "   " + CctvCatalog.clock_text(night_seconds()).substr(0, 5),
		(tr("CCTV_STATUS_CAMERAS") % [cameras.size(), cameras.size()]).to_upper(),
		"",
		tr("CCTV_STATUS_MOTION").to_upper(),
	]
	if moving.is_empty():
		lines.append("  " + tr("CCTV_STATUS_QUIET").to_upper())
	# the screen has room for STATUS_ROOMS rooms: more fold into "+n"
	var listed := moving.size() if moving.size() <= STATUS_ROOMS else STATUS_ROOMS - 1
	for room_name in moving.slice(0, listed):
		lines.append("  " + room_name)
	if listed < moving.size():
		lines.append("  " + (tr("CCTV_STATUS_MORE") % (moving.size() - listed)).to_upper())
	var text := "\n".join(lines)
	if text != _status_lines.text:
		_status_lines.text = text
		_status.render_target_update_mode = SubViewport.UPDATE_ONCE


## True while the status screen shows the shift's log page.
func showing_log() -> bool:
	return log_source.is_valid() and int(_page_time / STATUS_PAGE) % 2 == 1


## The text on the status screen now.
func status_text() -> String:
	if showing_log() and _status_log != null:
		return _status_log.text
	return _status_lines.text if _status_lines != null else ""


## A rack of blinking indicator lamps on the left of the monitors.
func _build_leds(wall: Node3D, front: float) -> void:
	var panel := Vector3(0.5, 1.2, 0.2)
	var middle := Vector3(LEDS_AT.x, LEDS_AT.y, front - panel.z * 0.5)
	_box(wall, panel, middle, _solid(Color(0.14, 0.14, 0.15), 0.6, 0.2))
	var colours: Array[Color] = [Color(0.3, 1.0, 0.4), Color(1.0, 0.7, 0.2), Color(0.3, 1.0, 0.4), Color(1.0, 0.25, 0.2)]
	for row in 8:
		for column in 3:
			var at := Vector3(middle.x - 0.12 + column * 0.12, middle.y + 0.46 - row * 0.12, front - panel.z - 0.006)
			var colour: Color = colours[(row + column * 3) % colours.size()]
			_leds.append(_box(wall, Vector3(0.035, 0.022, 0.012), at, _glow(colour, 3.0)))
			_box(wall, Vector3(0.05, 0.036, 0.004), at + Vector3(0.0, 0.0, 0.004), _solid(Color(0.05, 0.05, 0.05), 0.8, 0.0))


## A camera hanging in the room: body, sun hood, lens and a red LED; the
## feed's lens sits at its front.
func _build_housing(spec: CctvCatalog.Camera) -> void:
	var housing := Node3D.new()
	housing.name = "Camera_%d" % spec.number
	housing.transform = spec.transform()
	add_child(housing)
	var shell := _solid(Color(0.78, 0.78, 0.74), 0.5, 0.1)
	var dark := _solid(Color(0.06, 0.06, 0.07), 0.6, 0.3)
	_box(housing, Vector3(0.15, 0.13, 0.32), Vector3(0.0, 0.0, 0.2), shell)
	_box(housing, Vector3(0.18, 0.015, 0.38), Vector3(0.0, 0.08, 0.17), shell)
	_box(housing, Vector3(0.035, 0.26, 0.035), Vector3(0.0, 0.2, 0.3), dark)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.045
	ring.bottom_radius = 0.05
	ring.height = 0.05
	ring.radial_segments = 16
	var lens := MeshInstance3D.new()
	lens.mesh = ring
	lens.material_override = dark
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0.0, 0.0, 0.03)
	housing.add_child(lens)
	_housing_leds.append(_box(housing, Vector3(0.018, 0.018, 0.01), Vector3(0.05, 0.045, 0.036), _glow(Color(1.0, 0.1, 0.06), 4.0)))


func _build_console() -> void:
	console = CctvConsole.new()
	console.name = "CctvConsole"
	var desk: PieceSpec = null
	var layout: LevelLayout = level.get(&"layout")
	for spec in (layout.pieces if layout != null else [] as Array[PieceSpec]):
		if spec.kit == &"desk" and spec.room == watch_room:
			desk = spec
			break
	if desk != null:
		console.transform = desk.transform() * Transform3D(Basis.IDENTITY, Vector3(0.18, desk.size.y, 0.08))
	else:
		var marker: Variant = _markers().get(&"cctv_wall")
		var at: Vector3 = marker.origin if marker != null else Vector3(0.0, 1.5, 61.35)
		console.position = Vector3(at.x, 0.78, at.z - 1.0)
	console.used.connect(open_view)
	add_child(console)


func _screen_mesh(parent: Node3D, at: Vector3, size: Vector2) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.position = at
	screen.rotation.y = PI   # a quad faces +Z; the wall's front is -Z
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(screen)
	return screen


## A thin bezel ring around a screen.
func _frame_box(parent: Node3D, at: Vector3, size: Vector2, material: Material) -> void:
	var edge := 0.03
	_box(parent, Vector3(size.x, edge, 0.01), at + Vector3(0.0, size.y * 0.5, 0.0), material)
	_box(parent, Vector3(size.x, edge, 0.01), at - Vector3(0.0, size.y * 0.5, 0.0), material)
	_box(parent, Vector3(edge, size.y, 0.01), at + Vector3(size.x * 0.5, 0.0, 0.0), material)
	_box(parent, Vector3(edge, size.y, 0.01), at - Vector3(size.x * 0.5, 0.0, 0.0), material)


func _number(parent: Node3D, number: int, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = str(number)
	label.font = UiTheme.device_font()
	label.font_size = 40
	label.pixel_size = 0.0012
	label.outline_size = 0
	label.modulate = Color(0.8, 0.78, 0.7, 0.8)
	label.shaded = true
	label.position = at
	label.rotation.y = PI
	parent.add_child(label)


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view_mesh := MeshInstance3D.new()
	view_mesh.mesh = mesh
	view_mesh.position = at
	view_mesh.material_override = material
	parent.add_child(view_mesh)
	return view_mesh


static func _solid(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := "solid_%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_materials[key] = material
	return _materials[key]


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [color.to_html(), energy]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_materials[key] = material
	return _materials[key]


## Seconds of the night on the clock (see [member clock_seconds]).
func night_seconds() -> float:
	return float(clock_seconds.call()) if clock_seconds.is_valid() else run.time
