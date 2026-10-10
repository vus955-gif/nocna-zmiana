class_name CctvFeed
extends SubViewport
## One security camera's live picture: a small SubViewport with its own
## Camera3D in the shared world and the burnt-in overlay of a real CCTV
## recorder (camera number and name, a blinking REC, the night clock, a red
## MOTION tag). It never renders by itself (UPDATE_DISABLED): the Cctv asks
## for one frame at a time (render_once), a few times a second, only while
## someone can see it. No MSAA, no positional shadows, its own cheap
## "infrared" environment without fog.

const SIZE := Vector2i(320, 240)
## Render layer 20: the guard's viewmodels (their own FOV would draw them
## over every wall in a camera's picture).
const VIEWMODEL_LAYER := 1 << 19
## Render layer 19: the moon (Cctv puts it there). Its shadow cascades,
## drawn again for every camera that sees it, made a feed's picture cost
## about a third more (booth measurement, 1.10); the cameras' own pale
## "infrared" ambient lights their rooms instead.
const MOON_LAYER := 1 << 18
## Everything but the viewmodels and the moon.
const CULL_MASK := 0xFFFFF & ~VIEWMODEL_LAYER & ~MOON_LAYER

var spec: CctvCatalog.Camera
var camera: Camera3D
## Frames asked for so far.
var renders: int = 0
## A frame was asked for at least once (the screen shows snow before).
var has_picture: bool = false
var motion: bool = false

var _name_label: Label
var _rec_label: Label
var _time_label: Label
var _motion_label: Label
var _blink: bool = false
var _environment: Environment


static func make(camera_spec: CctvCatalog.Camera, look: Environment, picture: Vector2i = SIZE) -> CctvFeed:
	var feed := CctvFeed.new()
	feed.name = "Feed_%d" % camera_spec.number
	feed.spec = camera_spec
	feed.size = picture
	feed._environment = look
	return feed


func _init() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	msaa_3d = Viewport.MSAA_DISABLED
	screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	use_taa = false
	positional_shadow_atlas_size = 0
	use_occlusion_culling = false
	transparent_bg = false
	audio_listener_enable_3d = false
	gui_disable_input = true


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Lens"
	camera.transform = spec.transform()
	camera.fov = spec.fov
	camera.near = 0.08
	camera.far = 80.0
	camera.cull_mask = CULL_MASK
	camera.environment = _environment
	add_child(camera)
	camera.current = true
	_build_overlay()


## Asks for one frame with [param clock] on it.
func render_once(clock: String) -> void:
	_blink = not _blink
	_time_label.text = clock
	_rec_label.modulate.a = 1.0 if _blink else 0.25
	_motion_label.visible = motion
	render_target_update_mode = SubViewport.UPDATE_ONCE
	renders += 1
	has_picture = true


func set_motion(on: bool) -> void:
	motion = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _name_label != null:
		_name_label.text = _title()
		_rec_label.text = tr("CCTV_REC")
		_motion_label.text = "▲ " + tr("CCTV_MOTION").to_upper()


func _title() -> String:
	return (tr("CCTV_CAM_LABEL") % spec.number + "  " + tr(spec.name_key())).to_upper()


func _build_overlay() -> void:
	var root := Control.new()
	root.name = "Overlay"
	root.size = Vector2(size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_name_label = _label(root, Vector2(10, 7), 14, Color(0.92, 0.95, 0.9))
	_name_label.text = _title()
	_rec_label = _label(root, Vector2(size.x - 62, 7), 14, Color(1.0, 0.25, 0.2))
	_rec_label.text = tr("CCTV_REC")
	_time_label = _label(root, Vector2(size.x - 82, size.y - 25), 14, Color(0.92, 0.95, 0.9))
	_motion_label = _label(root, Vector2(10, size.y - 25), 14, Color(1.0, 0.3, 0.22))
	_motion_label.text = "▲ " + tr("CCTV_MOTION").to_upper()
	_motion_label.visible = false


static func _label(parent: Control, at: Vector2, font_size: int, color: Color) -> Label:
	var settings := LabelSettings.new()
	settings.font = UiTheme.strong_font()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	var label := Label.new()
	label.label_settings = settings
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
