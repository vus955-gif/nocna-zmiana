class_name DeathScreen
extends CanvasLayer
## After the guard falls: the picture fades to black (FADE_TIME), then an
## alarm clock shows 23:00 with the next night's number and a word about the
## dropped flashlight, the alarm rings, and [signal finished] asks for the
## next night. Runs while the game is paused, too.

signal finished

const FADE_TIME := 1.2
## Seconds the clock stays up before the next night loads.
const CLOCK_TIME := 2.8
const CLOCK_COLOR := Color(1.0, 0.36, 0.26)

var _black: ColorRect
var _clock: Control
var _colon: Label
var _night: Label
var _note: Label
var _playing: bool = false
var _time: float = 0.0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Starts the sequence for [param next_night]; [param dropped_dust] is the
## Dust left in the flashlight (0 = nothing was carried).
func play(next_night: int, dropped_dust: int) -> void:
	_night.text = (tr("DEATH_NIGHT") % next_night).to_upper()
	_note.text = tr("DEATH_LANTERN") % dropped_dust if dropped_dust > 0 else tr("DEATH_NOTHING")
	visible = true
	_playing = true
	_time = 0.0
	_black.modulate.a = 0.0
	_clock.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_ring)
	tween.tween_property(_clock, "modulate:a", 1.0, 0.18)
	tween.tween_interval(CLOCK_TIME)
	tween.tween_callback(_finish)


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	# the colon of the clock blinks once a second
	_colon.modulate.a = 1.0 if fmod(_time, 1.0) < 0.6 else 0.15


func _ring() -> void:
	Sfx.play_ui(&"alarm")


func _finish() -> void:
	_playing = false
	finished.emit()


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_black)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	_clock = column
	var digits := HBoxContainer.new()
	digits.alignment = BoxContainer.ALIGNMENT_CENTER
	digits.add_theme_constant_override("separation", 0)
	digits.add_child(_digit("23"))
	_colon = _digit(":")
	digits.add_child(_colon)
	digits.add_child(_digit("00"))
	column.add_child(digits)
	_night = UiTheme.label("", 30, UiTheme.TEXT, UiTheme.spaced_font(10))
	_night.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_night)
	_note = UiTheme.label("", 24, UiTheme.MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)


## A digit of the alarm clock: the guard's own modern clock keeps the
## security equipment's sans (UiTheme.device_font), glowing red.
static func _digit(text: String) -> Label:
	var settings := LabelSettings.new()
	settings.font = UiTheme.device_font()
	settings.font_size = 200
	settings.font_color = CLOCK_COLOR
	settings.shadow_color = Color(CLOCK_COLOR, 0.45)
	settings.shadow_size = 28
	settings.shadow_offset = Vector2.ZERO
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
